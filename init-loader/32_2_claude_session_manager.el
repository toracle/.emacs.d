;;; 32_2_claude_session_manager.el --- Claude Code Session Manager (CCSM)  -*- lexical-binding: t; -*-

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
;; Personal, non-packaged config drop-in.  Entry point: M-x my/ccsm.

(require 'claude-code-ide)
(require 'claude-code-ide-mcp-server)
(require 'subr-x)
(require 'seq)

;;;; ------------------------------------------------------------------
;;;; Channel launch flag (shared by the topic/session launchers)
;;;; ------------------------------------------------------------------

(defcustom my/ccsm-channel-args ""
  "Extra `claude' CLI args appended when launching a CCSM session.
Use to enable a CCSM channel, e.g.
  \"--dangerously-load-development-channels server:ccsmtest\"
An empty string adds nothing."
  :type 'string
  :group 'claude-code-ide)

(defmacro my/ccsm--with-channel (&rest body)
  "Run BODY with `claude-code-ide-cli-extra-flags' augmented by `my/ccsm-channel-args'."
  (declare (indent 0))
  `(let ((claude-code-ide-cli-extra-flags
          (string-trim (concat (or claude-code-ide-cli-extra-flags "")
                               " " my/ccsm-channel-args))))
     ,@body))

;;;; ------------------------------------------------------------------
;;;; Display naming: nearest ancestor holding `.projectile'
;;;; ------------------------------------------------------------------

(defcustom my/ccsm-project-marker ".projectile"
  "Marker file used to choose the directory a session is named after.
Sessions are named after the nearest ancestor of the working directory
that contains this file.  Defaults to `.projectile' for compatibility
with the projectile package."
  :type 'string
  :group 'claude-code-ide)

(defun my/ccsm--display-name (directory)
  "Return the topic name for DIRECTORY.
That is the basename of the nearest ancestor containing
`my/ccsm-project-marker', or DIRECTORY's own basename when no marker is
found.  This is the single source of truth shared by the buffer name and
the session-list title."
  (let ((root (and directory
                   (locate-dominating-file directory my/ccsm-project-marker))))
    (file-name-nondirectory
     (directory-file-name (expand-file-name (or root directory))))))

(defun my/ccsm-buffer-name (directory)
  "Name a Claude session buffer for DIRECTORY (see `my/ccsm--display-name')."
  (format "*claude-code[%s]*" (my/ccsm--display-name directory)))

(setq claude-code-ide-buffer-name-function #'my/ccsm-buffer-name)

;;;; ------------------------------------------------------------------
;;;; Per-session metadata (set by Claude via MCP)
;;;; ------------------------------------------------------------------

(defvar my/ccsm--meta (make-hash-table :test 'equal)
  "Map a canonical working-dir (the session key) to a metadata plist.
Recognized keys: :title :status :updated.")

(defun my/ccsm--meta-get (dir)
  "Return the metadata plist for session DIR, or nil."
  (gethash dir my/ccsm--meta))

(defun my/ccsm--meta-set (dir &rest kvs)
  "Merge KVS (a plist) into the metadata for session DIR."
  (let ((plist (gethash dir my/ccsm--meta)))
    (while kvs
      (setq plist (plist-put plist (pop kvs) (pop kvs))))
    (setq plist (plist-put plist :updated (current-time)))
    (puthash dir plist my/ccsm--meta)
    plist))

;;;; ------------------------------------------------------------------
;;;; Auxiliary git / forge info
;;;; ------------------------------------------------------------------

(defvar my/ccsm--branch-cache (make-hash-table :test 'equal)
  "Map working-dir -> (TIMESTAMP . BRANCH); a short TTL avoids spawning git
on every redraw when titles change rapidly.")

(defun my/ccsm--git-branch-1 (dir)
  "Return the current git branch for DIR, or nil (uncached)."
  (let ((default-directory dir))
    (ignore-errors
      (with-temp-buffer
        (when (eq 0 (process-file "git" nil t nil
                                  "rev-parse" "--abbrev-ref" "HEAD"))
          (let ((b (string-trim (buffer-string))))
            (unless (string-empty-p b) b)))))))

(defun my/ccsm--git-branch (dir)
  "Return the current git branch for DIR, or nil, cached for 5s."
  (when (and dir (file-directory-p dir))
    (let ((cached (gethash dir my/ccsm--branch-cache))
          (now (float-time)))
      (if (and cached (< (- now (car cached)) 5.0))
          (cdr cached)
        (let ((branch (my/ccsm--git-branch-1 dir)))
          (puthash dir (cons now branch) my/ccsm--branch-cache)
          branch)))))

;;;; OSC terminal title (the task summary Claude emits as it works)

(defun my/ccsm--osc-title (buffer)
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

(defvar my/ccsm-enable-forge t
  "When non-nil, fetch PR info via the `gh' CLI asynchronously.")

(defvar my/ccsm--forge-cache (make-hash-table :test 'equal)
  "Map working-dir -> forge info string (e.g. \"PR #12\"), best effort.")

(defun my/ccsm--forge-fetch (dir)
  "Asynchronously fetch the PR number for DIR via `gh', then refresh."
  (when (and my/ccsm-enable-forge
             (executable-find "gh")
             dir (file-directory-p dir))
    (let ((default-directory dir))
      (ignore-errors
        (make-process
         :name "ccsm-gh"
         :buffer (generate-new-buffer " *ccsm-gh*")
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
                        my/ccsm--forge-cache))
             (when (buffer-live-p (process-buffer proc))
               (kill-buffer (process-buffer proc)))
             (my/ccsm--maybe-refresh))))))))

;;;; ------------------------------------------------------------------
;;;; Session enumeration
;;;; ------------------------------------------------------------------

(defun my/ccsm--sessions ()
  "Return a list of session plists for all live Claude sessions.
Each plist has :dir :session-id :buffer :title :status :branch :forge."
  (claude-code-ide--cleanup-dead-processes)
  (let (out)
    (maphash
     (lambda (dir process)
       (when (process-live-p process)
         (let* ((bufname (claude-code-ide--get-buffer-name dir))
                (buffer (get-buffer bufname))
                (meta (my/ccsm--meta-get dir)))
           (push (list :dir dir
                       :session-id (gethash dir claude-code-ide--session-ids)
                       :buffer buffer
                       :title (or (plist-get meta :title)
                                  (my/ccsm--display-name dir))
                       :osc (or (my/ccsm--osc-title buffer) "")
                       :status (or (plist-get meta :status) "")
                       :branch (or (my/ccsm--git-branch dir) "")
                       :forge (or (gethash dir my/ccsm--forge-cache) ""))
                 out))))
     claude-code-ide--processes)
    (nreverse out)))

(defun my/ccsm--dir-for-buffer (buffer)
  "Return the session working-dir whose terminal is BUFFER, or nil."
  (let ((name (buffer-name buffer)) found)
    (maphash (lambda (dir _proc)
               (when (and (not found)
                          (equal name (claude-code-ide--get-buffer-name dir)))
                 (setq found dir)))
             claude-code-ide--processes)
    found))

(defvar my/ccsm--butler nil
  "Working-dir of the designated butler session, or nil.
The butler is a special Claude session that interfaces with the human and
drives the worker sessions through the orchestration MCP tools, receiving
forwarded worker events.  It is pinned to the top of the list.")

(defvar my/ccsm--waiting (make-hash-table :test 'equal)
  "Map a session working-dir -> float-time when it began awaiting user input.
Sessions present here sort to the top of the list as an approval queue,
oldest request first (FIFO); absence means the session is not waiting.")

(defun my/ccsm--waiting-p (dir)
  "Return the wait timestamp for DIR, or nil when it is not waiting."
  (gethash dir my/ccsm--waiting))

(defun my/ccsm--mark-waiting (dir)
  "Record that session DIR began awaiting user input (keep the earliest time)."
  (when (and dir (not (gethash dir my/ccsm--waiting)))
    (puthash dir (float-time) my/ccsm--waiting)))

(defun my/ccsm--clear-waiting (dir)
  "Mark session DIR as no longer awaiting input."
  (when dir (remhash dir my/ccsm--waiting)))

(defvar my/ccsm--inbox nil
  "Pending worker events for the butler to pull (newest pushed to the front).
Each entry is a plist (:time :dir :name :body).  Drained by the
`pending_events' MCP tool.")

(defun my/ccsm--inbox-push (dir body)
  "Record a worker event from session DIR with BODY into the butler inbox."
  (push (list :time (current-time)
              :dir dir
              :name (my/ccsm--display-name dir)
              :body (or body ""))
        my/ccsm--inbox))

(defun my/ccsm--ordered (sessions)
  "Sort SESSIONS for display.
The butler session is pinned to the very top.  Then sessions awaiting
user input (FIFO, oldest request first) form an approval queue, and the
rest keep their natural order (the sort is stable)."
  (sort (copy-sequence sessions)
        (lambda (a b)
          (let ((butler-a (equal (plist-get a :dir) my/ccsm--butler))
                (butler-b (equal (plist-get b :dir) my/ccsm--butler)))
            (cond
             (butler-a t)
             (butler-b nil)
             (t (let ((wa (my/ccsm--waiting-p (plist-get a :dir)))
                      (wb (my/ccsm--waiting-p (plist-get b :dir))))
                  (cond ((and wa wb) (< wa wb))
                        (wa t)
                        (wb nil)
                        (t nil)))))))))

;;;; ------------------------------------------------------------------
;;;; List UI (multi-line entries in a sticky side window)
;;;; ------------------------------------------------------------------

(defcustom my/ccsm-list-width 40
  "Width, in columns, of the sticky session-list side window."
  :type 'integer
  :group 'claude-code-ide)

(defvar my/ccsm--list-buffer-name "*claude-sessions*"
  "Name of the session-list buffer.")

(defvar my/ccsm--main-window nil
  "The window the session manager uses to display session terminals.")

(defvar-local my/ccsm--entries nil
  "Ordered list of (DIR . START-POS) for the rendered entries.")

(defvar-local my/ccsm--hl-overlay nil
  "Overlay highlighting the currently selected entry block.")

(defvar-keymap my/ccsm-mode-map
  :doc "Keymap for `my/ccsm-mode'."
  "n"        #'my/ccsm-next
  "p"        #'my/ccsm-prev
  "<down>"   #'my/ccsm-next
  "<up>"     #'my/ccsm-prev
  "C-n"      #'my/ccsm-next
  "C-p"      #'my/ccsm-prev
  "RET"      #'my/ccsm-visit
  "SPC"      #'my/ccsm-preview
  "g"        #'my/ccsm-refresh
  "c"        #'my/ccsm-new-session
  "q"        #'my/ccsm-quit)

(define-derived-mode my/ccsm-mode special-mode "CC-Sessions"
  "Major mode for the Claude Code session manager."
  (buffer-disable-undo)
  (setq-local cursor-in-non-selected-windows nil))

;;;; Rendering

(defun my/ccsm--render ()
  "Render all live sessions as multi-line blocks in the current buffer."
  (let ((inhibit-read-only t)
        (sessions (my/ccsm--ordered (my/ccsm--sessions)))
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
                 (waiting (my/ccsm--waiting-p d))
                 (butler (equal d my/ccsm--butler)))
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
          (put-text-property start (point) 'my/ccsm-dir (plist-get s :dir)))))
    (setq my/ccsm--entries (nreverse entries))
    (goto-char (point-min))
    (my/ccsm--highlight)))

(defun my/ccsm--list-buffer ()
  "Return the session-list buffer, (re)rendering its contents."
  (let ((buf (get-buffer-create my/ccsm--list-buffer-name)))
    (with-current-buffer buf
      (unless (derived-mode-p 'my/ccsm-mode)
        (my/ccsm-mode))
      (my/ccsm--render))
    buf))

(defun my/ccsm--dir-at-point ()
  "Return the session working-dir for the entry at point, or nil."
  (get-text-property (point) 'my/ccsm-dir))

(defun my/ccsm--current-index ()
  "Index into `my/ccsm--entries' of the entry containing point, or nil."
  (let ((pt (point)) (i 0) idx)
    (dolist (e my/ccsm--entries)
      (when (>= pt (cdr e)) (setq idx i))
      (setq i (1+ i)))
    idx))

(defun my/ccsm--entry-end (i)
  "Buffer position at which entry I ends."
  (if (< (1+ i) (length my/ccsm--entries))
      (cdr (nth (1+ i) my/ccsm--entries))
    (point-max)))

(defun my/ccsm--highlight ()
  "Highlight the entry block at point."
  (when-let ((i (my/ccsm--current-index)))
    (unless (overlayp my/ccsm--hl-overlay)
      (setq my/ccsm--hl-overlay (make-overlay 1 1)))
    (move-overlay my/ccsm--hl-overlay
                  (cdr (nth i my/ccsm--entries))
                  (my/ccsm--entry-end i)
                  (current-buffer))
    (overlay-put my/ccsm--hl-overlay 'face 'highlight)))

(defun my/ccsm--reprint ()
  "Re-render the list in place, keeping the selected session if possible."
  (when-let ((buf (get-buffer my/ccsm--list-buffer-name)))
    (with-current-buffer buf
      (let ((dir (my/ccsm--dir-at-point)))
        (my/ccsm--render)
        (when-let ((e (and dir (assoc dir my/ccsm--entries))))
          (goto-char (cdr e))
          (my/ccsm--highlight))))))

(defun my/ccsm--maybe-refresh ()
  "Re-render the list if its buffer exists (safe to call from anywhere)."
  (when (get-buffer my/ccsm--list-buffer-name)
    (my/ccsm--reprint)))

;;;; Live updates from terminal title changes

(defvar my/ccsm--refresh-timer nil
  "Debounce timer for live refreshes triggered by terminal title changes.")

(defun my/ccsm--schedule-refresh ()
  "Debounced reprint, only while the list window is visible."
  (when (get-buffer-window my/ccsm--list-buffer-name)
    (when (timerp my/ccsm--refresh-timer)
      (cancel-timer my/ccsm--refresh-timer))
    (setq my/ccsm--refresh-timer
          (run-with-idle-timer 0.3 nil #'my/ccsm--reprint))))

(defun my/ccsm--on-title-change (&rest _)
  "Advice on `ghostel--set-title': nudge the manager to refresh live.
Claude emits an OSC 2 title as it works; the module funcalls
`ghostel--set-title' on each change, which we ride to update the list."
  (my/ccsm--schedule-refresh))

(with-eval-after-load 'ghostel
  (when (fboundp 'ghostel--set-title)
    (advice-add 'ghostel--set-title :after #'my/ccsm--on-title-change)))

;;;; Reflect session start / stop in the manager

(defun my/ccsm--on-session-change (&rest _)
  "Advice: refresh the manager when a session is registered or torn down.
`claude-code-ide--set-process' adds a session to the registry (the point
at which it becomes enumerable), and `claude-code-ide--cleanup-on-exit'
removes it."
  (my/ccsm--schedule-refresh))

(advice-add 'claude-code-ide--set-process :after #'my/ccsm--on-session-change)
(advice-add 'claude-code-ide--cleanup-on-exit :after #'my/ccsm--on-session-change)

;;;; Navigation / preview

(defun my/ccsm--main-win ()
  "Return a live window for showing session terminals, creating one if needed."
  (let ((list-win (get-buffer-window my/ccsm--list-buffer-name)))
    (if (and (window-live-p my/ccsm--main-window)
             (not (eq my/ccsm--main-window list-win)))
        my/ccsm--main-window
      (setq my/ccsm--main-window
            (or (seq-find (lambda (w)
                            (and (not (eq w list-win))
                                 (not (window-dedicated-p w))))
                          (window-list))
                (and (window-live-p list-win)
                     (split-window list-win nil 'right)))))))

(defun my/ccsm--terminal-resize (buffer window)
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

(defun my/ccsm-preview ()
  "Show the session at point in the main window, staying in the list."
  (interactive)
  (let* ((dir (my/ccsm--dir-at-point))
         (buf (and dir (get-buffer (claude-code-ide--get-buffer-name dir))))
         (win (my/ccsm--main-win)))
    (when (and (buffer-live-p buf) (window-live-p win))
      (set-window-buffer win buf)
      (my/ccsm--terminal-resize buf win))))

(defun my/ccsm--goto-index (i)
  "Move to entry I, highlight it and preview its session."
  (when (and my/ccsm--entries (>= i 0) (< i (length my/ccsm--entries)))
    (goto-char (cdr (nth i my/ccsm--entries)))
    (my/ccsm--highlight)
    (my/ccsm-preview)))

(defun my/ccsm-next ()
  "Move to the next session and preview it."
  (interactive)
  (let ((i (or (my/ccsm--current-index) -1)))
    (my/ccsm--goto-index (min (1+ i) (1- (length my/ccsm--entries))))))

(defun my/ccsm-prev ()
  "Move to the previous session and preview it."
  (interactive)
  (let ((i (or (my/ccsm--current-index) 0)))
    (my/ccsm--goto-index (max (1- i) 0))))

(defun my/ccsm-visit ()
  "Preview the session at point, select its window, and clear it from the queue.
Visiting a session means you are attending to it, so it leaves the
input-waiting queue."
  (interactive)
  (my/ccsm--clear-waiting (my/ccsm--dir-at-point))
  (my/ccsm-preview)
  (when (window-live-p (my/ccsm--main-win))
    (select-window (my/ccsm--main-win)))
  (my/ccsm--maybe-refresh))

(defun my/ccsm-refresh ()
  "Refresh the session list and re-fetch forge info."
  (interactive)
  (when my/ccsm-enable-forge
    (dolist (s (my/ccsm--sessions))
      (my/ccsm--forge-fetch (plist-get s :dir))))
  (my/ccsm--reprint))

(defun my/ccsm-new-session ()
  "Start a new Claude session in a chosen directory, then re-open the manager."
  (interactive)
  (let ((default-directory
         (read-directory-name "Start Claude session in: "
                              (or (my/ccsm--dir-at-point) default-directory))))
    (claude-code-ide))
  (my/ccsm))

(defun my/ccsm-quit ()
  "Close the session-list side window."
  (interactive)
  (when-let ((win (get-buffer-window my/ccsm--list-buffer-name)))
    (delete-window win)))

;;;###autoload
(defun my/ccsm ()
  "Open the Claude Code Session Manager."
  (interactive)
  (let ((list-buf (my/ccsm--list-buffer)))
    (delete-other-windows)
    (setq my/ccsm--main-window (selected-window))
    (let ((list-win (display-buffer-in-side-window
                     list-buf
                     `((side . left) (slot . 0)
                       (window-width . ,my/ccsm-list-width)
                       (preserve-size . (t . nil))))))
      (when (window-live-p list-win)
        (set-window-dedicated-p list-win t)
        (select-window list-win)
        (goto-char (point-min))
        (my/ccsm--highlight)
        (my/ccsm-preview))
      (when my/ccsm-enable-forge
        (dolist (s (my/ccsm--sessions))
          (my/ccsm--forge-fetch (plist-get s :dir)))))))

;;;; ------------------------------------------------------------------
;;;; MCP tool: let Claude set its own title / status
;;;; ------------------------------------------------------------------

(defun my/ccsm-tool-set-session-info (&optional title status)
  "MCP tool: let the calling Claude session set its own TITLE/STATUS."
  (let* ((ctx (claude-code-ide-mcp-server-get-session-context))
         (dir (plist-get ctx :project-dir)))
    (unless dir
      (error "No active Claude session context for this request"))
    (apply #'my/ccsm--meta-set dir
           (append (when (and title (stringp title) (not (string-empty-p title)))
                     (list :title title))
                   (when (and status (stringp status))
                     (list :status status))))
    (my/ccsm--maybe-refresh)
    (format "Updated session '%s': title=%s status=%s"
            (my/ccsm--display-name dir)
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
 :function #'my/ccsm-tool-set-session-info
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

(provide '32_2_claude_session_manager)
;;; 32_2_claude_session_manager.el ends here
