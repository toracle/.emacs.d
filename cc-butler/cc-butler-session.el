;;; cc-butler-session.el --- Claude Code Session Manager (cc-butler)  -*- lexical-binding: t; -*-

;; A lightweight, cmux-like session manager for `claude-code-ide':
;;
;;  - A sticky left-hand list of live Claude sessions, each rendered as a
;;    multi-line block (title / status / branch + PR) so it stays readable in
;;    a narrow side window.  Moving between entries shows that session's
;;    terminal in the main window.
;;  - Per-session metadata (title / status) that the *running* Claude can set
;;    about itself through the Emacs MCP bridge (tool `set_session_info').
;;  - Auxiliary info per session: git branch, plus best-effort PR number.
;;  - Buffer / display naming based on a `.projectile' marker walked up from
;;    the working directory, so sessions launched inside a meta-repo get the
;;    *topic parent's* name instead of all collapsing to the meta-repo name.
;;
;; Personal, non-packaged config drop-in.  Entry point: M-x cc-butler.

(require 'claude-code-ide)
(require 'claude-code-ide-mcp-server)
(require 'subr-x)
(require 'seq)

;;;; ------------------------------------------------------------------
;;;; Channel launch flag (shared by the topic/session launchers)
;;;; ------------------------------------------------------------------

(defcustom cc-butler-channel-args ""
  "Extra `claude' CLI args appended when launching a cc-butler session.
Use to enable a cc-butler channel, e.g.
  \"--dangerously-load-development-channels server:cc-butlertest\"
An empty string adds nothing."
  :type 'string
  :group 'cc-butler)

(defmacro cc-butler--with-channel (&rest body)
  "Run BODY with `claude-code-ide-cli-extra-flags' augmented by `cc-butler-channel-args'."
  (declare (indent 0))
  `(let ((claude-code-ide-cli-extra-flags
          (string-trim (concat (or claude-code-ide-cli-extra-flags "")
                               " " cc-butler-channel-args))))
     ,@body))

;;;; ------------------------------------------------------------------
;;;; Display naming: nearest ancestor holding `.projectile'
;;;; ------------------------------------------------------------------

(defcustom cc-butler-project-marker ".projectile"
  "Marker file used to choose the directory a session is named after.
Sessions are named after the nearest ancestor of the working directory
that contains this file.  Defaults to `.projectile' for compatibility
with the projectile package."
  :type 'string
  :group 'cc-butler)

(defun cc-butler--display-name (directory)
  "Return the topic name for DIRECTORY.
That is the basename of the nearest ancestor containing
`cc-butler-project-marker', or DIRECTORY's own basename when no marker is
found.  This is the single source of truth shared by the buffer name and
the session-list title."
  (let ((root (and directory
                   (locate-dominating-file directory cc-butler-project-marker))))
    (file-name-nondirectory
     (directory-file-name (expand-file-name (or root directory))))))

(defun cc-butler-buffer-name (directory)
  "Name a Claude session buffer for DIRECTORY (see `cc-butler--display-name')."
  (format "*claude-code[%s]*" (cc-butler--display-name directory)))

(setq claude-code-ide-buffer-name-function #'cc-butler-buffer-name)

;;;; ------------------------------------------------------------------
;;;; Per-session metadata (set by Claude via MCP)
;;;; ------------------------------------------------------------------

(defvar cc-butler--meta (make-hash-table :test 'equal)
  "Map a canonical working-dir (the session key) to a metadata plist.
Recognized keys: :title :status :updated.")

(defun cc-butler--meta-get (dir)
  "Return the metadata plist for session DIR, or nil."
  (gethash dir cc-butler--meta))

(defun cc-butler--meta-set (dir &rest kvs)
  "Merge KVS (a plist) into the metadata for session DIR."
  (let ((plist (gethash dir cc-butler--meta)))
    (while kvs
      (setq plist (plist-put plist (pop kvs) (pop kvs))))
    (setq plist (plist-put plist :updated (current-time)))
    (puthash dir plist cc-butler--meta)
    plist))

;;;; ------------------------------------------------------------------
;;;; Auxiliary git / forge info
;;;; ------------------------------------------------------------------

(defvar cc-butler--branch-cache (make-hash-table :test 'equal)
  "Map working-dir -> (TIMESTAMP . BRANCH); a short TTL avoids spawning git
on every redraw when titles change rapidly.")

(defun cc-butler--git-branch-1 (dir)
  "Return the current git branch for DIR, or nil (uncached)."
  (let ((default-directory dir))
    (ignore-errors
      (with-temp-buffer
        (when (eq 0 (process-file "git" nil t nil
                                  "rev-parse" "--abbrev-ref" "HEAD"))
          (let ((b (string-trim (buffer-string))))
            (unless (string-empty-p b) b)))))))

(defun cc-butler--git-branch (dir)
  "Return the current git branch for DIR, or nil, cached for 5s."
  (when (and dir (file-directory-p dir))
    (let ((cached (gethash dir cc-butler--branch-cache))
          (now (float-time)))
      (if (and cached (< (- now (car cached)) 5.0))
          (cdr cached)
        (let ((branch (cc-butler--git-branch-1 dir)))
          (puthash dir (cons now branch) cc-butler--branch-cache)
          branch)))))

;;;; OSC terminal title (the task summary Claude emits as it works)

(defun cc-butler--osc-title (buffer)
  "Return the live terminal title of BUFFER (ghostel OSC 2), or nil.
claude-code-ide disables ghostel's title-based *renaming*, but the
terminal still tracks the title; read it straight from the term object."
  (when (buffer-live-p buffer)
    (with-current-buffer buffer
      (when (and (boundp 'ghostel--term) ghostel--term
                 (fboundp 'ghostel--get-title))
        (let ((title (ignore-errors (ghostel--get-title ghostel--term))))
          (and (stringp title)
               (not (string-empty-p (string-trim title)))
               (string-trim title)))))))

(defvar cc-butler-enable-forge t
  "When non-nil, fetch PR info via the `gh' CLI asynchronously.")

(defvar cc-butler--forge-cache (make-hash-table :test 'equal)
  "Map working-dir -> forge info string (e.g. \"PR #12\"), best effort.")

(defun cc-butler--forge-fetch (dir)
  "Asynchronously fetch the PR number for DIR via `gh', then refresh."
  (when (and cc-butler-enable-forge
             (executable-find "gh")
             dir (file-directory-p dir))
    (let ((default-directory dir))
      (ignore-errors
        (make-process
         :name "cc-butler-gh"
         :buffer (generate-new-buffer " *cc-butler-gh*")
         :command '("gh" "pr" "view" "--json" "number" "-q" ".number")
         :noquery t
         :sentinel
         (lambda (proc _event)
           (when (memq (process-status proc) '(exit signal))
             (let ((out (with-current-buffer (process-buffer proc)
                          (string-trim (buffer-string)))))
               (puthash dir
                        (and (string-match-p "\\`[0-9]+\\'" out)
                             (format "PR #%s" out))
                        cc-butler--forge-cache))
             (when (buffer-live-p (process-buffer proc))
               (kill-buffer (process-buffer proc)))
             (cc-butler--maybe-refresh))))))))

;;;; ------------------------------------------------------------------
;;;; Session enumeration
;;;; ------------------------------------------------------------------

(defun cc-butler--sessions ()
  "Return a list of session plists for all live Claude sessions.
Each plist has :dir :session-id :buffer :title :status :branch :forge."
  (claude-code-ide--cleanup-dead-processes)
  (let (out)
    (maphash
     (lambda (dir process)
       (when (process-live-p process)
         (let* ((bufname (claude-code-ide--get-buffer-name dir))
                (buffer (get-buffer bufname))
                (meta (cc-butler--meta-get dir)))
           (push (list :dir dir
                       :session-id (gethash dir claude-code-ide--session-ids)
                       :buffer buffer
                       :title (or (plist-get meta :title)
                                  (cc-butler--display-name dir))
                       :osc (or (cc-butler--osc-title buffer) "")
                       :status (or (plist-get meta :status) "")
                       :branch (or (cc-butler--git-branch dir) "")
                       :forge (or (gethash dir cc-butler--forge-cache) ""))
                 out))))
     claude-code-ide--processes)
    (nreverse out)))

(defun cc-butler--dir-for-buffer (buffer)
  "Return the session working-dir whose terminal is BUFFER, or nil."
  (let ((name (buffer-name buffer)) found)
    (maphash (lambda (dir _proc)
               (when (and (not found)
                          (equal name (claude-code-ide--get-buffer-name dir)))
                 (setq found dir)))
             claude-code-ide--processes)
    found))

(defvar cc-butler--butler nil
  "Working-dir of the designated butler session, or nil.
The butler is a special Claude session that interfaces with the human and
drives the worker sessions through the orchestration MCP tools, receiving
forwarded worker events.  It is pinned to the top of the list.")

(defvar cc-butler--waiting (make-hash-table :test 'equal)
  "Map a session working-dir -> float-time when it began awaiting user input.
Sessions present here sort to the top of the list as an approval queue,
oldest request first (FIFO); absence means the session is not waiting.")

(defun cc-butler--waiting-p (dir)
  "Return the wait timestamp for DIR, or nil when it is not waiting."
  (gethash dir cc-butler--waiting))

(defun cc-butler--mark-waiting (dir)
  "Record that session DIR began awaiting user input (keep the earliest time)."
  (when (and dir (not (gethash dir cc-butler--waiting)))
    (puthash dir (float-time) cc-butler--waiting)))

(defun cc-butler--clear-waiting (dir)
  "Mark session DIR as no longer awaiting input."
  (when dir (remhash dir cc-butler--waiting)))

(defvar cc-butler--inbox nil
  "Pending worker events for the butler to pull (newest pushed to the front).
Each entry is a plist (:time :dir :name :body).  Drained by the
`pending_events' MCP tool.")

;;;; Identity + butler<->worker message log

(defun cc-butler--session-id (dir)
  "Return the claude-code-ide session id for DIR, or nil."
  (gethash dir claude-code-ide--session-ids))

(defun cc-butler--who (name id)
  "Format a session label from NAME and session ID."
  (if (and id (stringp id) (not (string-empty-p id)))
      (format "%s (%s)" name id)
    (or name "?")))

(defun cc-butler--who-dir (dir)
  "Format the session label (name + id) for session DIR."
  (cc-butler--who (cc-butler--display-name dir) (cc-butler--session-id dir)))

(defcustom cc-butler-log-buffer-name "*cc-butler-log*"
  "Name of the cc-butler message-log buffer that tees butler<->worker traffic."
  :type 'string
  :group 'cc-butler)

(define-derived-mode cc-butler-log-mode special-mode "cc-butler-Log"
  "Major mode for the cc-butler butler<->worker message log.")

(defun cc-butler--log (fmt &rest args)
  "Append a timestamped FMT/ARGS line to `cc-butler-log-buffer-name'."
  (let ((buf (get-buffer-create cc-butler-log-buffer-name)))
    (with-current-buffer buf
      (unless (derived-mode-p 'cc-butler-log-mode) (cc-butler-log-mode))
      (let ((inhibit-read-only t))
        (save-excursion
          (goto-char (point-max))
          (insert (format-time-string "[%H:%M:%S] ")
                  (apply #'format fmt args) "\n")))
      (dolist (w (get-buffer-window-list buf nil t))
        (set-window-point w (point-max))))))

(defun cc-butler-show-log ()
  "Pop to the cc-butler message-log buffer."
  (interactive)
  (pop-to-buffer (get-buffer-create cc-butler-log-buffer-name)))

(defun cc-butler--inbox-push (dir body)
  "Record a worker event from session DIR with BODY into the butler inbox.
The worker's name and session id are attached, and the event is teed to
the cc-butler log."
  (push (list :time (current-time)
              :dir dir
              :name (cc-butler--display-name dir)
              :id (cc-butler--session-id dir)
              :body (or body ""))
        cc-butler--inbox)
  (cc-butler--log "%s → butler │ %s" (cc-butler--who-dir dir) (or body "")))

(defun cc-butler--ordered (sessions)
  "Sort SESSIONS for display.
The butler session is pinned to the very top.  Then sessions awaiting
user input (FIFO, oldest request first) form an approval queue, and the
rest keep their natural order (the sort is stable)."
  (sort (copy-sequence sessions)
        (lambda (a b)
          (let ((butler-a (equal (plist-get a :dir) cc-butler--butler))
                (butler-b (equal (plist-get b :dir) cc-butler--butler)))
            (cond
             (butler-a t)
             (butler-b nil)
             (t (let ((wa (cc-butler--waiting-p (plist-get a :dir)))
                      (wb (cc-butler--waiting-p (plist-get b :dir))))
                  (cond ((and wa wb) (< wa wb))
                        (wa t)
                        (wb nil)
                        (t nil)))))))))

;;;; ------------------------------------------------------------------
;;;; List UI (multi-line entries in a sticky side window)
;;;; ------------------------------------------------------------------

(defcustom cc-butler-list-width 40
  "Width, in columns, of the sticky session-list side window."
  :type 'integer
  :group 'cc-butler)

(defvar cc-butler--list-buffer-name "*claude-sessions*"
  "Name of the session-list buffer.")

(defvar cc-butler--main-window nil
  "The window the session manager uses to display session terminals.")

(defvar-local cc-butler--entries nil
  "Ordered list of (DIR . START-POS) for the rendered entries.")

(defvar-local cc-butler--hl-overlay nil
  "Overlay highlighting the currently selected entry block.")

(defvar-keymap cc-butler-mode-map
  :doc "Keymap for `cc-butler-mode'."
  "n"        #'cc-butler-next
  "p"        #'cc-butler-prev
  "<down>"   #'cc-butler-next
  "<up>"     #'cc-butler-prev
  "C-n"      #'cc-butler-next
  "C-p"      #'cc-butler-prev
  "RET"      #'cc-butler-visit
  "SPC"      #'cc-butler-preview
  "g"        #'cc-butler-refresh
  "c"        #'cc-butler-new-session
  "l"        #'cc-butler-show-log
  "q"        #'cc-butler-quit)

(define-derived-mode cc-butler-mode special-mode "CC-Sessions"
  "Major mode for the Claude Code session manager."
  (buffer-disable-undo)
  (setq-local cursor-in-non-selected-windows nil))

;;;; Rendering

(defun cc-butler--render ()
  "Render all live sessions as multi-line blocks in the current buffer."
  (let ((inhibit-read-only t)
        (sessions (cc-butler--ordered (cc-butler--sessions)))
        entries)
    (erase-buffer)
    (if (null sessions)
        (insert (propertize "No active Claude sessions.\n\n" 'face 'shadow)
                (propertize "c" 'face 'bold) " start   "
                (propertize "g" 'face 'bold) " refresh   "
                (propertize "q" 'face 'bold) " quit\n")
      (dolist (s sessions)
        (let ((start (point))
              (title (plist-get s :title))
              (osc (plist-get s :osc))
              (status (plist-get s :status))
              (branch (plist-get s :branch))
              (forge (plist-get s :forge)))
          (push (cons (plist-get s :dir) start) entries)
          (let* ((d (plist-get s :dir))
                 (waiting (cc-butler--waiting-p d))
                 (butler (equal d cc-butler--butler)))
            (insert (propertize (concat (cond (butler "★ ")
                                              (waiting "⏳ ")
                                              (t "● "))
                                        title)
                                'face (cond (butler 'font-lock-keyword-face)
                                            (waiting 'warning)
                                            (t 'bold)))
                    "\n"))
          (unless (string-empty-p osc)
            (insert "   " (propertize osc 'face 'italic) "\n"))
          (unless (string-empty-p status)
            (insert "   " (propertize status 'face 'font-lock-string-face) "\n"))
          (let ((meta (mapconcat
                       #'identity
                       (delq nil
                             (list (unless (string-empty-p branch)
                                     (concat "⎇ " branch))
                                   (unless (string-empty-p forge) forge)))
                       "   ")))
            (unless (string-empty-p meta)
              (insert "   " (propertize meta 'face 'font-lock-comment-face) "\n")))
          (insert "\n")
          (put-text-property start (point) 'cc-butler-dir (plist-get s :dir)))))
    (setq cc-butler--entries (nreverse entries))
    (goto-char (point-min))
    (cc-butler--highlight)))

(defun cc-butler--list-buffer ()
  "Return the session-list buffer, (re)rendering its contents."
  (let ((buf (get-buffer-create cc-butler--list-buffer-name)))
    (with-current-buffer buf
      (unless (derived-mode-p 'cc-butler-mode)
        (cc-butler-mode))
      (cc-butler--render))
    buf))

(defun cc-butler--dir-at-point ()
  "Return the session working-dir for the entry at point, or nil."
  (get-text-property (point) 'cc-butler-dir))

(defun cc-butler--current-index ()
  "Index into `cc-butler--entries' of the entry containing point, or nil."
  (let ((pt (point)) (i 0) idx)
    (dolist (e cc-butler--entries)
      (when (>= pt (cdr e)) (setq idx i))
      (setq i (1+ i)))
    idx))

(defun cc-butler--entry-end (i)
  "Buffer position at which entry I ends."
  (if (< (1+ i) (length cc-butler--entries))
      (cdr (nth (1+ i) cc-butler--entries))
    (point-max)))

(defun cc-butler--highlight ()
  "Highlight the entry block at point."
  (when-let ((i (cc-butler--current-index)))
    (unless (overlayp cc-butler--hl-overlay)
      (setq cc-butler--hl-overlay (make-overlay 1 1)))
    (move-overlay cc-butler--hl-overlay
                  (cdr (nth i cc-butler--entries))
                  (cc-butler--entry-end i)
                  (current-buffer))
    (overlay-put cc-butler--hl-overlay 'face 'highlight)))

(defun cc-butler--reprint ()
  "Re-render the list in place, keeping the selected session if possible."
  (when-let ((buf (get-buffer cc-butler--list-buffer-name)))
    (with-current-buffer buf
      (let ((dir (cc-butler--dir-at-point)))
        (cc-butler--render)
        (when-let ((e (and dir (assoc dir cc-butler--entries))))
          (goto-char (cdr e))
          (cc-butler--highlight))))))

(defun cc-butler--maybe-refresh ()
  "Re-render the list if its buffer exists (safe to call from anywhere)."
  (when (get-buffer cc-butler--list-buffer-name)
    (cc-butler--reprint)))

;;;; Live updates from terminal title changes

(defvar cc-butler--refresh-timer nil
  "Debounce timer for live refreshes triggered by terminal title changes.")

(defun cc-butler--schedule-refresh ()
  "Debounced reprint, only while the list window is visible."
  (when (get-buffer-window cc-butler--list-buffer-name)
    (when (timerp cc-butler--refresh-timer)
      (cancel-timer cc-butler--refresh-timer))
    (setq cc-butler--refresh-timer
          (run-with-idle-timer 0.3 nil #'cc-butler--reprint))))

(defun cc-butler--on-title-change (&rest _)
  "Advice on `ghostel--set-title': nudge the manager to refresh live.
Claude emits an OSC 2 title as it works; the module funcalls
`ghostel--set-title' on each change, which we ride to update the list."
  (cc-butler--schedule-refresh))

(with-eval-after-load 'ghostel
  (when (fboundp 'ghostel--set-title)
    (advice-add 'ghostel--set-title :after #'cc-butler--on-title-change)))

;;;; Reflect session start / stop in the manager

(defun cc-butler--on-session-change (&rest _)
  "Advice: refresh the manager when a session is registered or torn down.
`claude-code-ide--set-process' adds a session to the registry (the point
at which it becomes enumerable), and `claude-code-ide--cleanup-on-exit'
removes it."
  (cc-butler--schedule-refresh))

(advice-add 'claude-code-ide--set-process :after #'cc-butler--on-session-change)
(advice-add 'claude-code-ide--cleanup-on-exit :after #'cc-butler--on-session-change)

;;;; Navigation / preview

(defun cc-butler--main-win ()
  "Return a live window for showing session terminals, creating one if needed."
  (let ((list-win (get-buffer-window cc-butler--list-buffer-name)))
    (if (and (window-live-p cc-butler--main-window)
             (not (eq cc-butler--main-window list-win)))
        cc-butler--main-window
      (setq cc-butler--main-window
            (or (seq-find (lambda (w)
                            (and (not (eq w list-win))
                                 (not (window-dedicated-p w))))
                          (window-list))
                (and (window-live-p list-win)
                     (split-window list-win nil 'right)))))))

(defun cc-butler--terminal-resize (buffer window)
  "Resize the ghostel terminal in BUFFER to fit WINDOW and redraw.
`set-window-buffer' does not run `window-size-change-functions', so
ghostel never resizes the PTY to the preview window; without this, claude
keeps rendering at its previous grid size and the preview shows stale or
clipped output.  Deferred so the buffer-change hook anchors the window
first."
  (when (and (buffer-live-p buffer) (window-live-p window))
    (run-at-time
     0 nil
     (lambda ()
       (when (and (buffer-live-p buffer) (window-live-p window)
                  (eq (window-buffer window) buffer))
         (with-current-buffer buffer
           (when (and (derived-mode-p 'ghostel-mode)
                      (fboundp 'ghostel--adjust-size))
             ;; Size the PTY to the LARGEST window showing the session (the
             ;; preview), not the default smallest — otherwise a second,
             ;; smaller window showing the same buffer shrinks the grid and
             ;; clips the preview.  Restored immediately.
             (let ((orig (default-value 'window-adjust-process-window-size-function)))
               (setq-default window-adjust-process-window-size-function
                             #'window-adjust-process-window-size-largest)
               (unwind-protect
                   (ignore-errors (ghostel--adjust-size window))
                 (setq-default window-adjust-process-window-size-function orig))))))))))

(defvar cc-butler-after-preview-functions nil
  "Abnormal hook run after a session terminal is shown in the main window.
Each function receives (DIR MAIN-WINDOW).  The document-panel module
(`cc-butler-doc-panel') rides this to add or tear down the per-session
document split *before* the terminal is resized to its final width.")

(defun cc-butler-preview ()
  "Show the session at point in the main window, staying in the list."
  (interactive)
  (let* ((dir (cc-butler--dir-at-point))
         (buf (and dir (get-buffer (claude-code-ide--get-buffer-name dir))))
         (win (cc-butler--main-win)))
    (when (and (buffer-live-p buf) (window-live-p win))
      (set-window-buffer win buf)
      (run-hook-with-args 'cc-butler-after-preview-functions dir win)
      (cc-butler--terminal-resize buf win))))

(defun cc-butler--goto-index (i)
  "Move to entry I, highlight it and preview its session."
  (when (and cc-butler--entries (>= i 0) (< i (length cc-butler--entries)))
    (goto-char (cdr (nth i cc-butler--entries)))
    (cc-butler--highlight)
    (cc-butler-preview)))

(defun cc-butler-next ()
  "Move to the next session and preview it."
  (interactive)
  (let ((i (or (cc-butler--current-index) -1)))
    (cc-butler--goto-index (min (1+ i) (1- (length cc-butler--entries))))))

(defun cc-butler-prev ()
  "Move to the previous session and preview it."
  (interactive)
  (let ((i (or (cc-butler--current-index) 0)))
    (cc-butler--goto-index (max (1- i) 0))))

(defun cc-butler-visit ()
  "Preview the session at point, select its window, and clear it from the queue.
Visiting a session means you are attending to it, so it leaves the
input-waiting queue."
  (interactive)
  (cc-butler--clear-waiting (cc-butler--dir-at-point))
  (cc-butler-preview)
  (when (window-live-p (cc-butler--main-win))
    (select-window (cc-butler--main-win)))
  (cc-butler--maybe-refresh))

(defun cc-butler-refresh ()
  "Refresh the session list and re-fetch forge info."
  (interactive)
  (when cc-butler-enable-forge
    (dolist (s (cc-butler--sessions))
      (cc-butler--forge-fetch (plist-get s :dir))))
  (cc-butler--reprint))

(defun cc-butler-new-session ()
  "Start a new Claude session in a chosen directory, then re-open the manager."
  (interactive)
  (let ((default-directory
         (read-directory-name "Start Claude session in: "
                              (or (cc-butler--dir-at-point) default-directory))))
    (claude-code-ide))
  (cc-butler))

(defun cc-butler-quit ()
  "Close the session-list side window."
  (interactive)
  (when-let ((win (get-buffer-window cc-butler--list-buffer-name)))
    (delete-window win)))

;;;###autoload
(defun cc-butler ()
  "Open the Claude Code Session Manager."
  (interactive)
  (let ((list-buf (cc-butler--list-buffer)))
    (delete-other-windows)
    (setq cc-butler--main-window (selected-window))
    (let ((list-win (display-buffer-in-side-window
                     list-buf
                     `((side . left) (slot . 0)
                       (window-width . ,cc-butler-list-width)
                       (preserve-size . (t . nil))))))
      (when (window-live-p list-win)
        (set-window-dedicated-p list-win t)
        (select-window list-win)
        (goto-char (point-min))
        (cc-butler--highlight)
        (cc-butler-preview))
      (when cc-butler-enable-forge
        (dolist (s (cc-butler--sessions))
          (cc-butler--forge-fetch (plist-get s :dir)))))))

;;;; ------------------------------------------------------------------
;;;; MCP tool: let Claude set its own title / status
;;;; ------------------------------------------------------------------

(defun cc-butler-tool-set-session-info (&optional title status)
  "MCP tool: let the calling Claude session set its own TITLE/STATUS."
  (let* ((ctx (claude-code-ide-mcp-server-get-session-context))
         (dir (plist-get ctx :project-dir)))
    (unless dir
      (error "No active Claude session context for this request"))
    (apply #'cc-butler--meta-set dir
           (append (when (and title (stringp title) (not (string-empty-p title)))
                     (list :title title))
                   (when (and status (stringp status))
                     (list :status status))))
    (cc-butler--maybe-refresh)
    (format "Updated session '%s': title=%s status=%s"
            (cc-butler--display-name dir)
            (or title "(unchanged)")
            (or status "(unchanged)"))))

;; Make (re)loading idempotent: drop any previously-registered tool of the
;; same name before registering, so reloads don't accumulate duplicates.
(setq claude-code-ide-mcp-server-tools
      (seq-remove
       (lambda (spec)
         (equal "set_session_info"
                (plist-get (claude-code-ide--normalize-tool-spec spec) :name)))
       claude-code-ide-mcp-server-tools))

(claude-code-ide-make-tool
 :function #'cc-butler-tool-set-session-info
 :name "set_session_info"
 :description "Set THIS Claude session's display title and/or status line in the Emacs session manager so the human can track multiple sessions at a glance. Use a short title naming the task/topic (e.g. 'billing: invoice PDF') and a concise status describing what you are doing right now (e.g. 'writing tests', 'waiting on review'). Call it whenever your focus changes."
 :args '((:name "title"
                :type string
                :description "Short task/topic title for this session. Optional; omit to leave unchanged."
                :optional t)
         (:name "status"
                :type string
                :description "Concise current status / subtitle. Optional; omit to leave unchanged."
                :optional t)))

(provide 'cc-butler-session)
;;; cc-butler-session.el ends here
