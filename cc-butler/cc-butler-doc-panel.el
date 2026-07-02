;;; cc-butler-doc-panel.el --- Per-session document panel for cc-butler  -*- lexical-binding: t; -*-

;; A Claude Code session is a stream of TUI output that scrolls away — hard to
;; refer back to, and poor for holding the *context* a task needs (the PR under
;; review, the issue it closes, the CI run that just failed, a design doc).
;;
;; This module gives each session its own *document panel*: a right-hand
;; vertical split, child of that session's area, holding one or more rendered
;; documents.  The split nests inside the existing cc-butler layout:
;;
;;   +----------+-------------------------------+
;;   | sessions |  terminal      |   document   |   <- per-session child split
;;   |  list    |  (the session) |    panel     |
;;   +----------+-------------------------------+
;;
;; The panel is *bound to the session*: its document set is keyed by the
;; session's working-dir, so switching to another session and back restores the
;; same documents.  The running Claude opens documents into its own panel by
;; calling the `show_document' MCP tool; the human can also drive it from the
;; session list (see the keymap below).
;;
;; Documents are fetched on demand with the `gh' CLI (PRs, issues, workflow
;; runs) and rendered read-only, or opened straight from a local file.

(require 'cc-butler-session)
(require 'claude-code-ide)
(require 'seq)
(require 'subr-x)
(require 'tab-line)

;;;; ------------------------------------------------------------------
;;;; Per-session document state
;;;; ------------------------------------------------------------------

(defvar cc-butler--docs (make-hash-table :test 'equal)
  "Map a session working-dir to its document-panel state plist.
Keys: :items  -- ordered list of document descriptors (see below);
      :current -- index into :items of the visible document;
      :open   -- whether the panel is shown when the session is previewed.

A document descriptor is a plist:
  :kind  one of the symbols `pr' `issue' `run' `file'
  :ref   the reference string (PR/issue/run number, or a file path)
  :label a short human label for the cycler/echo
  :buffer the buffer rendering the document
  :owned  non-nil when cc-butler created the buffer (so it may kill it).")

(defvar cc-butler--doc-window nil
  "The live window showing the current session's document, or nil.
Always a split to the right of `cc-butler--main-window'; never that window
itself, so tearing the panel down never disturbs the terminal.")

(defun cc-butler--doc-state (dir)
  "Return the document-panel state for session DIR, or nil."
  (gethash dir cc-butler--docs))

(defun cc-butler--current-doc (dir)
  "Return the currently-selected document descriptor for DIR, or nil."
  (let* ((state (cc-butler--doc-state dir))
         (items (and state (plist-get state :items)))
         (idx (and state (plist-get state :current))))
    (and items (nth (min (max 0 (or idx 0)) (1- (length items))) items))))

(defun cc-butler--current-doc-buffer (dir)
  "Return the buffer of DIR's currently-selected document, or nil."
  (let ((doc (cc-butler--current-doc dir)))
    (and doc (buffer-live-p (plist-get doc :buffer)) (plist-get doc :buffer))))

(defun cc-butler--visible-dir ()
  "Return the session working-dir whose terminal occupies the main window."
  (and (window-live-p cc-butler--main-window)
       (cc-butler--dir-for-buffer (window-buffer cc-butler--main-window))))

;;;; ------------------------------------------------------------------
;;;; Document buffers + rendering
;;;; ------------------------------------------------------------------

(define-derived-mode cc-butler-doc-mode special-mode "cc-butler-Doc"
  "Major mode for a cc-butler document buffer (read-only rendered text)."
  (setq-local truncate-lines nil)
  ;; The panel is a side-by-side (partial-width) window; without this, a
  ;; window narrower than `truncate-partial-width-windows' (default 50)
  ;; truncates long lines — e.g. wide table rows — regardless of
  ;; `truncate-lines'.  nil makes wrapping unconditional so nothing is cut.
  (setq-local truncate-partial-width-windows nil)
  (setq-local word-wrap t))

(defun cc-butler--doc-label (kind ref)
  "Return a short human label for a KIND/REF document."
  (pcase kind
    ('pr    (format "PR #%s" ref))
    ('issue (format "issue #%s" ref))
    ('run   (format "run %s" ref))
    ('file  (file-name-nondirectory ref))
    (_      (format "%s %s" kind ref))))

(defun cc-butler--doc-command (kind ref)
  "Return the `gh' argument list that renders a KIND/REF document, or nil."
  (pcase kind
    ('pr    (list "gh" "pr" "view" ref "--comments"))
    ('issue (list "gh" "issue" "view" ref "--comments"))
    ('run   (list "gh" "run" "view" ref))
    (_      nil)))

(defun cc-butler--child-repos (dir)
  "Return the immediate child directories of DIR that are git repos."
  (when (file-directory-p dir)
    (seq-filter (lambda (p)
                  (and (file-directory-p p)
                       (file-directory-p (expand-file-name ".git" p))))
                (directory-files dir t "\\`[^.]"))))

(defun cc-butler--doc-git-dir (dir repo)
  "Resolve the git working directory for a gh document in session DIR.
A topic-workspace root is not itself a repo; the repos live in child
directories.  REPO (a child-repo basename) is honored when given.
Returns one of: (:dir D), (:ambiguous (NAMES...)), or (:badrepo NAME)."
  (cond
   ((and repo (not (string-empty-p repo)))
    (let ((p (file-name-as-directory (expand-file-name repo dir))))
      (if (file-directory-p (expand-file-name ".git" p))
          (list :dir p)
        (list :badrepo repo))))
   ((locate-dominating-file dir ".git")
    (list :dir (file-name-as-directory (locate-dominating-file dir ".git"))))
   (t (let ((kids (cc-butler--child-repos dir)))
        (cond
         ((= (length kids) 1) (list :dir (file-name-as-directory (car kids))))
         (kids (list :ambiguous
                     (mapcar (lambda (p)
                               (file-name-nondirectory (directory-file-name p)))
                             kids)))
         ;; No repo anywhere — let gh run in DIR and report its own error.
         (t (list :dir (file-name-as-directory dir))))))))

(defun cc-butler--doc-make-buffer (name kind ref)
  "Create (or reuse) a `cc-butler-doc-mode' buffer for session NAME / KIND / REF."
  (let ((buf (get-buffer-create (format "*cc-butler-doc:%s:%s-%s*" name kind ref))))
    (with-current-buffer buf
      (unless (derived-mode-p 'cc-butler-doc-mode) (cc-butler-doc-mode)))
    buf))

;; Context carried by each gh document buffer, so its action commands
;; (comment / browse / refresh) know what they are acting on.
(defvar-local cc-butler--doc-buffer-kind nil "This doc buffer's kind symbol.")
(defvar-local cc-butler--doc-buffer-ref nil  "This doc buffer's reference string.")
(defvar-local cc-butler--doc-buffer-cwd nil  "Git working dir gh runs in for this doc.")

(defun cc-butler--strip-ansi (s)
  "Remove ANSI/terminal control sequences (e.g. gh's spinner) from S."
  (let* ((s (replace-regexp-in-string "\x1b\\[[0-9;?]*[A-Za-z]" "" s))
         (s (replace-regexp-in-string "\x1b[][()#][0-9;]*[A-Za-z]?" "" s))
         (s (replace-regexp-in-string "[\x00-\x08\x0b\x0c\x0e-\x1f]" "" s)))
    (replace-regexp-in-string "\r" "" s)))

(defun cc-butler--doc-render (doc dir)
  "Fetch DOC's content (run in DOC's :cwd or DIR) asynchronously into its buffer.
Only meaningful for `gh'-backed kinds; `file' documents are real file
buffers and are not rendered here.  stdout and stderr are captured
separately so the spinner on stderr never pollutes a successful render;
on failure stderr is shown so the error is still visible."
  (let* ((kind (plist-get doc :kind))
         (ref (plist-get doc :ref))
         (buf (plist-get doc :buffer))
         (cmd (cc-butler--doc-command kind ref)))
    (when (and cmd (buffer-live-p buf))
      (with-current-buffer buf
        (setq cc-butler--doc-buffer-kind kind
              cc-butler--doc-buffer-ref ref
              cc-butler--doc-buffer-cwd (file-name-as-directory
                                       (or (plist-get doc :cwd) dir)))
        (let ((inhibit-read-only t))
          (erase-buffer)
          (insert (format "Loading %s…\n" (plist-get doc :label)))))
      (let ((default-directory (file-name-as-directory
                                (or (plist-get doc :cwd) dir)))
            (errbuf (generate-new-buffer " *cc-butler-doc-err*")))
        (ignore-errors
          (make-process
           :name "cc-butler-doc"
           :buffer (generate-new-buffer " *cc-butler-doc-fetch*")
           :stderr errbuf
           :command cmd
           :noquery t
           :sentinel
           (lambda (proc _event)
             (when (memq (process-status proc) '(exit signal))
               (let* ((code (process-exit-status proc))
                      (out (with-current-buffer (process-buffer proc)
                             (buffer-string)))
                      (err (and (buffer-live-p errbuf)
                                (with-current-buffer errbuf (buffer-string))))
                      (clean (cc-butler--strip-ansi (or out "")))
                      (text (cond
                             ((and (eq code 0) (not (string-empty-p (string-trim clean))))
                              clean)
                             ((and err (not (string-empty-p (string-trim
                                                             (cc-butler--strip-ansi err)))))
                              (concat clean (cc-butler--strip-ansi err)))
                             (t (if (string-empty-p (string-trim clean))
                                    "(no output)" clean)))))
                 (when (buffer-live-p (process-buffer proc))
                   (kill-buffer (process-buffer proc)))
                 (when (buffer-live-p errbuf) (kill-buffer errbuf))
                 (when (buffer-live-p buf)
                   (with-current-buffer buf
                     (let ((inhibit-read-only t))
                       (erase-buffer)
                       (insert text)
                       (goto-char (point-min))))))))))))))

(defvar cc-butler-doc-file-mode-map
  (let ((m (make-sparse-keymap)))
    (define-key m (kbd "C-c C-e") #'cc-butler-doc-file-toggle-edit)
    (define-key m (kbd "C-c C-q") #'cc-butler-doc-hide)
    m)
  "Keymap active in file documents shown in the panel.")

(define-minor-mode cc-butler-doc-file-mode
  "Minor mode for a local file shown in a cc-butler document panel.
The file opens read-only (forge-style); `C-c C-e' toggles editability."
  :lighter " cc-butler-Doc"
  :keymap cc-butler-doc-file-mode-map
  (when cc-butler-doc-file-mode
    (setq buffer-read-only t)
    ;; Wrap unconditionally in the narrow side panel (see `cc-butler-doc-mode').
    (setq-local truncate-lines nil)
    (setq-local truncate-partial-width-windows nil)))

(defun cc-butler-doc-file-toggle-edit ()
  "Toggle read-only on a file document so you can edit it in place."
  (interactive)
  (setq buffer-read-only (not buffer-read-only))
  (message "cc-butler doc: %s" (if buffer-read-only "read-only" "editable")))

(defun cc-butler--doc-file-buffer (dir ref)
  "Return a buffer visiting file REF (relative to DIR), or an error buffer.
The file opens read-only via `cc-butler-doc-file-mode'."
  (let ((path (expand-file-name ref (file-name-as-directory dir))))
    (if (file-readable-p path)
        (let ((buf (find-file-noselect path)))
          (with-current-buffer buf (cc-butler-doc-file-mode 1))
          buf)
      (let ((buf (get-buffer-create (format "*cc-butler-doc:%s*" ref))))
        (with-current-buffer buf
          (unless (derived-mode-p 'cc-butler-doc-mode) (cc-butler-doc-mode))
          (let ((inhibit-read-only t))
            (erase-buffer)
            (insert (format "Cannot read file: %s\n" path))))
        buf))))

;;;; ------------------------------------------------------------------
;;;; Mutating the document set
;;;; ------------------------------------------------------------------

(defun cc-butler--doc-add (dir kind ref &optional cwd)
  "Add (or re-select) a KIND/REF document in session DIR's panel.
CWD, when given, is the git working directory gh runs in (for gh kinds in
a multi-repo topic workspace).  Returns the updated state plist; opens the
panel.  A document already present is re-selected (and gh kinds re-fetched)
rather than duplicated."
  (let* ((name (cc-butler--display-name dir))
         (state (or (cc-butler--doc-state dir) (list :items nil :current 0 :open t)))
         (items (plist-get state :items))
         (existing (seq-find (lambda (d)
                               (and (eq (plist-get d :kind) kind)
                                    (equal (plist-get d :ref) ref)))
                             items)))
    (if existing
        (progn
          (when cwd (setq existing (plist-put existing :cwd cwd)))
          (unless (eq kind 'file) (cc-butler--doc-render existing dir))
          (setq state (plist-put state :current (seq-position items existing))))
      (let* ((buf (if (eq kind 'file)
                      (cc-butler--doc-file-buffer dir ref)
                    (cc-butler--doc-make-buffer name kind ref)))
             (doc (list :kind kind :ref ref
                        :label (cc-butler--doc-label kind ref)
                        :cwd cwd
                        :buffer buf :owned (not (eq kind 'file)))))
        (unless (eq kind 'file) (cc-butler--doc-render doc dir))
        (setq items (append items (list doc)))
        (setq state (plist-put (plist-put state :items items)
                               :current (1- (length items))))))
    (setq state (plist-put state :open t))
    (puthash dir state cc-butler--docs)
    (cc-butler--doc-setup-buffer
     (or (and existing (plist-get existing :buffer))
         (cc-butler--current-doc-buffer dir))
     dir)
    state))

;;;; ------------------------------------------------------------------
;;;; Tab line: the session's documents as clickable tabs
;;;; ------------------------------------------------------------------
;;
;; The tab line is attached to the *document window* via its `tab-line-format'
;; window parameter (not `tab-line-mode', which is buffer-local and would leak
;; the tabs into any other window showing the same file).  We reuse tab-line's
;; own renderer/mouse/close machinery by pointing the parameter at
;; `(tab-line-format)', and drive it with buffer-local tab functions set on each
;; document buffer.

(defvar-local cc-butler--doc-session-dir nil
  "The session working-dir a document buffer belongs to (for its tab line).")

(defun cc-butler--doc-tabs ()
  "`tab-line-tabs-function': the current session's ordered document buffers."
  (when-let* ((dir cc-butler--doc-session-dir)
              (items (plist-get (cc-butler--doc-state dir) :items)))
    (seq-filter #'buffer-live-p
                (mapcar (lambda (d) (plist-get d :buffer)) items))))

(defun cc-butler--doc-tab-name (buffer &optional _buffers)
  "`tab-line-tab-name-function': label a document BUFFER by its :label."
  (let* ((dir (buffer-local-value 'cc-butler--doc-session-dir buffer))
         (doc (and dir (seq-find (lambda (d) (eq (plist-get d :buffer) buffer))
                                 (plist-get (cc-butler--doc-state dir) :items)))))
    (format " %s " (or (and doc (plist-get doc :label)) (buffer-name buffer)))))

(defun cc-butler--doc-index-of-buffer (items buffer)
  "Return the index of the doc whose :buffer is BUFFER in ITEMS, or nil."
  (let ((i 0) found)
    (dolist (d items)
      (when (and (not found) (eq (plist-get d :buffer) buffer)) (setq found i))
      (setq i (1+ i)))
    found))

(defun cc-butler--doc-remove-buffer (dir buffer)
  "Drop the document whose buffer is BUFFER from session DIR's panel."
  (let* ((state (cc-butler--doc-state dir))
         (items (plist-get state :items))
         (idx (cc-butler--doc-index-of-buffer items buffer))
         (doc (and idx (nth idx items))))
    (when doc
      (when (and (plist-get doc :owned) (buffer-live-p buffer)) (kill-buffer buffer))
      (setq items (delq doc items))
      (setq state (plist-put state :items items))
      (setq state (plist-put state :current
                             (min (or (plist-get state :current) 0)
                                  (max 0 (1- (length items))))))
      (unless items (setq state (plist-put state :open nil)))
      (puthash dir state cc-butler--docs)
      (cc-butler--doc-refresh-layout dir)
      (message "cc-butler doc: removed %s" (plist-get doc :label)))))

(defun cc-butler--doc-tab-close (tab &optional _)
  "`tab-line-close-tab-function': remove the clicked document TAB (a buffer)."
  (let* ((buf (if (bufferp tab) tab (cdr (assq 'buffer tab))))
         (dir (and (buffer-live-p buf)
                   (buffer-local-value 'cc-butler--doc-session-dir buf))))
    (when dir (cc-butler--doc-remove-buffer dir buf))))

(defun cc-butler--doc-setup-buffer (buffer dir)
  "Prepare document BUFFER of session DIR to render a tab line when shown."
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (setq-local cc-butler--doc-session-dir dir
                  tab-line-tabs-function #'cc-butler--doc-tabs
                  tab-line-tab-name-function #'cc-butler--doc-tab-name
                  tab-line-close-tab-function #'cc-butler--doc-tab-close))))

(defun cc-butler--doc-sync-current (&rest _)
  "Keep a session's :current in step with whatever its panel now shows.
Runs on `window-buffer-change-functions' so selecting a tab (which switches
the doc window's buffer) updates our stored selection."
  (when (window-live-p cc-butler--doc-window)
    (let* ((buf (window-buffer cc-butler--doc-window))
           (dir (and (buffer-live-p buf)
                     (buffer-local-value 'cc-butler--doc-session-dir buf))))
      (when dir
        (let* ((state (cc-butler--doc-state dir))
               (idx (cc-butler--doc-index-of-buffer (plist-get state :items) buf)))
          (when (and idx (not (equal idx (plist-get state :current))))
            (puthash dir (plist-put state :current idx) cc-butler--docs)))))))

(add-hook 'window-buffer-change-functions #'cc-butler--doc-sync-current)

;;;; ------------------------------------------------------------------
;;;; Layout: nest the document split inside the session's main area
;;;; ------------------------------------------------------------------

(defcustom cc-butler-doc-width nil
  "Width, in columns, of the document panel; nil splits the area in half."
  :type '(choice (const :tag "Half" nil) integer)
  :group 'cc-butler)

(defun cc-butler--apply-doc-layout (dir main-win)
  "Reconcile the document split for session DIR around terminal MAIN-WIN.
Show a doc window to the right iff DIR has an open, non-empty panel; tear
it down otherwise.  Bound to `cc-butler-after-preview-functions', so every
preview rebuilds the layout for the session it shows."
  (let* ((state (cc-butler--doc-state dir))
         (open (and state (plist-get state :open) (plist-get state :items)))
         (docbuf (and open (cc-butler--current-doc-buffer dir))))
    (if (not (and open docbuf (window-live-p main-win)))
        (when (window-live-p cc-butler--doc-window)
          (delete-window cc-butler--doc-window)
          (setq cc-butler--doc-window nil))
      (unless (and (window-live-p cc-butler--doc-window)
                   (not (eq cc-butler--doc-window main-win)))
        (setq cc-butler--doc-window
              (ignore-errors
                (split-window main-win
                              (and cc-butler-doc-width (- cc-butler-doc-width))
                              'right))))
      (when (window-live-p cc-butler--doc-window)
        ;; Attach the tab line to the window (not the buffer): it appears only
        ;; in the panel, and reuses tab-line's own renderer/mouse/close.
        (set-window-parameter cc-butler--doc-window 'tab-line-format
                              '(:eval (tab-line-format)))
        (set-window-buffer cc-butler--doc-window docbuf)))))

(add-hook 'cc-butler-after-preview-functions #'cc-butler--apply-doc-layout)

(defun cc-butler--doc-refresh-layout (dir)
  "Rebuild DIR's document split if DIR is the session currently on screen.
Resizes the terminal afterward, since adding/removing the doc window
changes the terminal window's width."
  (when (and dir (equal dir (cc-butler--visible-dir))
             (window-live-p cc-butler--main-window))
    (cc-butler--apply-doc-layout dir cc-butler--main-window)
    (cc-butler--terminal-resize (window-buffer cc-butler--main-window)
                              cc-butler--main-window)))

;;;; ------------------------------------------------------------------
;;;; Interactive commands (driven from the session list or a doc buffer)
;;;; ------------------------------------------------------------------

(defun cc-butler--doc-target-dir ()
  "Return the session to act on: the list entry at point, else the visible one."
  (or (and (derived-mode-p 'cc-butler-mode) (cc-butler--dir-at-point))
      (cc-butler--visible-dir)))

(defun cc-butler--doc-step (dir delta)
  "Move DIR's current document by DELTA (wrapping) and reflect it on screen."
  (let* ((state (cc-butler--doc-state dir))
         (items (and state (plist-get state :items))))
    (if (not (and items (cdr items)))
        (message "cc-butler: no other documents for this session")
      (let* ((n (length items))
             (idx (mod (+ (or (plist-get state :current) 0) delta) n)))
        (setq state (plist-put (plist-put state :current idx) :open t))
        (puthash dir state cc-butler--docs)
        (cc-butler--doc-refresh-layout dir)
        (message "cc-butler doc: %s" (plist-get (nth idx items) :label))))))

(defun cc-butler-doc-next ()
  "Show the next document in the selected session's panel."
  (interactive)
  (when-let ((dir (cc-butler--doc-target-dir))) (cc-butler--doc-step dir 1)))

(defun cc-butler-doc-prev ()
  "Show the previous document in the selected session's panel."
  (interactive)
  (when-let ((dir (cc-butler--doc-target-dir))) (cc-butler--doc-step dir -1)))

(defun cc-butler-doc-toggle ()
  "Toggle whether the selected session's document panel is shown."
  (interactive)
  (let* ((dir (cc-butler--doc-target-dir))
         (state (and dir (cc-butler--doc-state dir))))
    (if (not (and state (plist-get state :items)))
        (message "cc-butler: no documents for this session")
      (puthash dir (plist-put state :open (not (plist-get state :open)))
               cc-butler--docs)
      (cc-butler--doc-refresh-layout dir))))

(defun cc-butler-doc-hide ()
  "Hide the visible session's document panel and zoom into its terminal."
  (interactive)
  (let ((dir (cc-butler--visible-dir)))
    (when-let ((state (and dir (cc-butler--doc-state dir))))
      (puthash dir (plist-put state :open nil) cc-butler--docs)
      (cc-butler--doc-refresh-layout dir))
    (when (window-live-p cc-butler--main-window)
      (select-window cc-butler--main-window))))

(defun cc-butler-doc-remove ()
  "Drop the current document from the selected session's panel.
cc-butler-owned buffers (gh documents) are killed; visited files are only
unlinked from the panel."
  (interactive)
  (let* ((dir (cc-butler--doc-target-dir))
         (buf (and dir (cc-butler--current-doc-buffer dir))))
    (when (and dir buf) (cc-butler--doc-remove-buffer dir buf))))

(defun cc-butler-doc-revert ()
  "Re-fetch the current gh document.
Prefers the doc buffer's own context (when called from a doc buffer),
else the visible session's current document."
  (interactive)
  (if cc-butler--doc-buffer-kind
      (cc-butler--doc-render
       (list :kind cc-butler--doc-buffer-kind :ref cc-butler--doc-buffer-ref
             :cwd cc-butler--doc-buffer-cwd :buffer (current-buffer)
             :label (cc-butler--doc-label cc-butler--doc-buffer-kind
                                        cc-butler--doc-buffer-ref))
       cc-butler--doc-buffer-cwd)
    (let* ((dir (cc-butler--visible-dir))
           (doc (and dir (cc-butler--current-doc dir))))
      (when (and doc (not (eq (plist-get doc :kind) 'file)))
        (cc-butler--doc-render doc dir)
        (message "cc-butler doc: refreshing %s" (plist-get doc :label))))))

;;;; gh action commands (forge-style: read-only view, explicit actions)

(defun cc-butler--doc-sub (kind)
  "Return the `gh' subcommand string for KIND (`pr'/`issue'/`run')."
  (pcase kind ('pr "pr") ('issue "issue") ('run "run")))

(defun cc-butler--doc-action-buffer ()
  "Return the gh document buffer to act on.
This buffer when it is a gh document, else the visible session's current
document — so the actions work both in the panel and from the `C-c d'
prefix elsewhere."
  (if cc-butler--doc-buffer-kind
      (current-buffer)
    (when-let ((dir (cc-butler--visible-dir)))
      (cc-butler--current-doc-buffer dir))))

(defun cc-butler-doc-browse ()
  "Open the current gh document on the web (`gh ... view REF --web')."
  (interactive)
  (let ((buf (cc-butler--doc-action-buffer)))
    (unless (buffer-live-p buf) (user-error "No document to act on"))
    (with-current-buffer buf
      (let ((kind cc-butler--doc-buffer-kind)
            (ref cc-butler--doc-buffer-ref)
            (default-directory (or cc-butler--doc-buffer-cwd default-directory)))
        (unless (and kind (cc-butler--doc-sub kind))
          (user-error "Current document is not a gh document"))
        (start-process "cc-butler-doc-web" nil "gh" (cc-butler--doc-sub kind)
                       "view" ref "--web")
        (message "cc-butler doc: opening %s on the web"
                 (cc-butler--doc-label kind ref))))))

(define-derived-mode cc-butler-doc-compose-mode text-mode "cc-butler-Compose"
  "Major mode for composing a comment on a cc-butler gh document."
  (setq-local header-line-format
              (concat " " (propertize "C-c C-c" 'face 'bold) " post   "
                      (propertize "C-c C-k" 'face 'bold) " cancel")))

(defvar-local cc-butler--compose-target nil
  "Plist (:kind :ref :cwd :doc-buffer) the compose buffer posts to.")

(defun cc-butler-doc-comment ()
  "Compose a comment on the current PR/issue document (post with C-c C-c)."
  (interactive)
  (let ((doc-buf (cc-butler--doc-action-buffer)))
    (unless (buffer-live-p doc-buf) (user-error "No document to act on"))
    (let ((kind (buffer-local-value 'cc-butler--doc-buffer-kind doc-buf))
          (ref (buffer-local-value 'cc-butler--doc-buffer-ref doc-buf))
          (cwd (buffer-local-value 'cc-butler--doc-buffer-cwd doc-buf)))
    (unless (memq kind '(pr issue))
      (user-error "Comments apply to pr/issue documents only"))
    (let ((buf (get-buffer-create (format "*cc-butler-comment:%s-%s*" kind ref))))
      (with-current-buffer buf
        (cc-butler-doc-compose-mode)
        (erase-buffer)
        (setq cc-butler--compose-target
              (list :kind kind :ref ref :cwd cwd :doc-buffer doc-buf)))
      (pop-to-buffer buf)
      (message "Write your comment, then C-c C-c to post (C-c C-k cancels)")))))

(defun cc-butler-doc-compose-send ()
  "Post the composed comment via `gh ... comment REF --body-file'."
  (interactive)
  (let* ((tgt cc-butler--compose-target)
         (body (string-trim (buffer-substring-no-properties (point-min) (point-max)))))
    (unless tgt (user-error "No comment target"))
    (when (string-empty-p body) (user-error "Empty comment; nothing to post"))
    (let* ((kind (plist-get tgt :kind))
           (ref (plist-get tgt :ref))
           (doc-buf (plist-get tgt :doc-buffer))
           (default-directory (or (plist-get tgt :cwd) default-directory))
           (tmp (make-temp-file "cc-butler-comment"))
           (compose-buf (current-buffer)))
      (write-region body nil tmp nil 'silent)
      (make-process
       :name "cc-butler-doc-comment"
       :buffer (generate-new-buffer " *cc-butler-comment-out*")
       :command (list "gh" (cc-butler--doc-sub kind) "comment" ref "--body-file" tmp)
       :noquery t
       :sentinel
       (lambda (proc _event)
         (when (memq (process-status proc) '(exit signal))
           (let ((out (with-current-buffer (process-buffer proc) (buffer-string))))
             (ignore-errors (delete-file tmp))
             (when (buffer-live-p (process-buffer proc))
               (kill-buffer (process-buffer proc)))
             (if (eq (process-exit-status proc) 0)
                 (progn
                   (when (buffer-live-p compose-buf) (kill-buffer compose-buf))
                   (message "cc-butler doc: comment posted")
                   ;; refresh the underlying document so the new comment shows
                   (when (buffer-live-p doc-buf)
                     (with-current-buffer doc-buf
                       (when (fboundp 'cc-butler-doc-revert) (cc-butler-doc-revert)))))
               (message "cc-butler doc: comment failed — %s" (string-trim out))))))))))

(defun cc-butler-doc-compose-cancel ()
  "Abandon the comment being composed."
  (interactive)
  (when (eq major-mode 'cc-butler-doc-compose-mode)
    (kill-buffer (current-buffer))
    (message "cc-butler doc: comment cancelled")))

(define-key cc-butler-doc-compose-mode-map (kbd "C-c C-c") #'cc-butler-doc-compose-send)
(define-key cc-butler-doc-compose-mode-map (kbd "C-c C-k") #'cc-butler-doc-compose-cancel)

(defun cc-butler-doc-open ()
  "Prompt for a document and open it in the selected session's panel."
  (interactive)
  (let ((dir (cc-butler--doc-target-dir)))
    (unless dir (user-error "No session selected"))
    (let* ((kind (intern (completing-read "Document kind: "
                                          '("pr" "issue" "run" "file") nil t)))
           (ref (if (eq kind 'file)
                    (file-relative-name
                     (read-file-name "File: " (file-name-as-directory dir))
                     dir)
                  (string-trim (read-string (format "%s ref: " kind)))))
           (cwd (unless (eq kind 'file)
                  (pcase (cc-butler--doc-git-dir dir nil)
                    (`(:dir ,d) d)
                    (`(:ambiguous ,names)
                     (file-name-as-directory
                      (expand-file-name
                       (completing-read "Repo: " names nil t) dir)))
                    (_ nil)))))
      (cc-butler--doc-add dir kind ref cwd)
      (cc-butler--doc-refresh-layout dir))))

;;;; Keybindings

(with-eval-after-load 'cc-butler-session
  (when (boundp 'cc-butler-mode-map)
    (define-key cc-butler-mode-map "]" #'cc-butler-doc-next)
    (define-key cc-butler-mode-map "[" #'cc-butler-doc-prev)
    (define-key cc-butler-mode-map "d" #'cc-butler-doc-toggle)
    (define-key cc-butler-mode-map "D" #'cc-butler-doc-remove)
    (define-key cc-butler-mode-map "o" #'cc-butler-doc-open)))

(define-key cc-butler-doc-mode-map "]" #'cc-butler-doc-next)
(define-key cc-butler-doc-mode-map "[" #'cc-butler-doc-prev)
(define-key cc-butler-doc-mode-map "g" #'cc-butler-doc-revert)
(define-key cc-butler-doc-mode-map "k" #'cc-butler-doc-remove)
(define-key cc-butler-doc-mode-map "q" #'cc-butler-doc-hide)
(define-key cc-butler-doc-mode-map "w" #'cc-butler-doc-browse)
(define-key cc-butler-doc-mode-map (kbd "C-c C-n") #'cc-butler-doc-comment)
(define-key cc-butler-doc-mode-map (kbd "C-c C-o") #'cc-butler-doc-browse)

;; A global prefix so the panel is controllable from the session terminal
;; (or anywhere), not only from the session list.
(defvar cc-butler-doc-prefix-map
  (let ((m (make-sparse-keymap)))
    (define-key m "]" #'cc-butler-doc-next)
    (define-key m "[" #'cc-butler-doc-prev)
    (define-key m "d" #'cc-butler-doc-toggle)
    (define-key m "z" #'cc-butler-doc-hide)
    (define-key m "o" #'cc-butler-doc-open)
    (define-key m "g" #'cc-butler-doc-revert)
    (define-key m "k" #'cc-butler-doc-remove)
    (define-key m "n" #'cc-butler-doc-comment)
    (define-key m "w" #'cc-butler-doc-browse)
    m)
  "Keymap for cc-butler document-panel commands, bound under a global prefix.")

(global-set-key (kbd "C-c d") cc-butler-doc-prefix-map)

;;;; ------------------------------------------------------------------
;;;; MCP tool: a session opens a document into its own panel
;;;; ------------------------------------------------------------------

(defun cc-butler-tool-show-document (kind ref &optional repo)
  "MCP tool: open a KIND/REF document in the calling session's panel.
REPO names a child repo for gh kinds in a multi-repo topic workspace."
  (let ((dir (plist-get (claude-code-ide-mcp-server-get-session-context)
                        :project-dir)))
    (unless dir
      (error "No active Claude session context for this request"))
    (let ((k (intern (downcase (string-trim (or kind ""))))))
      (unless (memq k '(pr issue run file))
        (error "Unknown document kind %S (use pr, issue, run, or file)" kind))
      (when (or (null ref) (string-empty-p (string-trim ref)))
        (error "A document reference is required"))
      (let ((cwd nil))
        ;; gh kinds need a git repo; a topic-workspace root is not one.
        (unless (eq k 'file)
          (let ((g (cc-butler--doc-git-dir dir (and repo (string-trim repo)))))
            (pcase g
              (`(:dir ,d) (setq cwd d))
              (`(:badrepo ,name)
               (error "No git repo %S under this workspace; pass a valid `repo'" name))
              (`(:ambiguous ,names)
               (error "This workspace holds several repos (%s). Re-call show_document with `repo' set to the one this %s belongs to."
                      (mapconcat #'identity names ", ") k)))))
        (cc-butler--doc-add dir k (string-trim ref) cwd)
        (cc-butler--doc-refresh-layout dir)
        (cc-butler--maybe-refresh)
        (format "Opened %s%s in the document panel for session '%s'."
                (cc-butler--doc-label k (string-trim ref))
                (if cwd (format " (repo %s)"
                                (file-name-nondirectory (directory-file-name cwd)))
                  "")
                (cc-butler--display-name dir))))))

;; Idempotent (re)registration.
(setq claude-code-ide-mcp-server-tools
      (seq-remove
       (lambda (spec)
         (equal "show_document"
                (plist-get (claude-code-ide--normalize-tool-spec spec) :name)))
       claude-code-ide-mcp-server-tools))

(claude-code-ide-make-tool
 :function #'cc-butler-tool-show-document
 :name "show_document"
 :description "Open a reference document in THIS session's side document panel in the Emacs session manager, so the human can read it next to your terminal (and it stays pinned to this session when they switch away and back). Use it to surface the PR under review, the issue you are working, a failing CI run, or a design/markdown file. You can open several; they accumulate and the human can cycle through them. The panel persists per session."
 :args '((:name "kind"
                :type string
                :description "Document type: 'pr' (pull request), 'issue', 'run' (GitHub Actions workflow run), or 'file' (a local file in the working tree).")
         (:name "ref"
                :type string
                :description "The reference: a PR/issue/run NUMBER for pr/issue/run (e.g. '42'), or a file path relative to the working directory for 'file' (e.g. 'docs/DESIGN.md').")
         (:name "repo"
                :type string
                :description "For pr/issue/run only: the child repo this reference belongs to, when the session's workspace holds several repos (e.g. 'monocle', 'stark'). Omit for a single-repo session; if the workspace is multi-repo and this is omitted, the tool returns the list of repos to choose from."
                :optional t)))

(provide 'cc-butler-doc-panel)
;;; cc-butler-doc-panel.el ends here
