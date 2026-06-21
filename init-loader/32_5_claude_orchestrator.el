;;; 32_5_claude_orchestrator.el --- Master/worker orchestration for CCSM  -*- lexical-binding: t; -*-

;; Turns the session manager into a control plane: a designated *master*
;; Claude session drives the *worker* sessions through Emacs.  Emacs is the
;; bus — workers are reached through their ghostel shells.
;;
;; Two directions:
;;
;;   PULL  — the master actively inspects and commands workers via three MCP
;;           tools it can call:
;;             list_claude_sessions   what's running, who's waiting, branches
;;             read_session_output    a worker's current screen
;;             send_to_session        type a prompt into a worker and submit
;;
;;   PUSH  — when a worker posts a notification (needs input / done), the event
;;           is forwarded into the master's terminal so it can aggregate and
;;           proactively report to you over its own remote-control channel.
;;
;; You remote-control ONE session (the master) from your phone; it becomes the
;; situation room for the rest.  Designate it with `m' in the manager buffer.

(require '32_2_claude_session_manager)
(require '32_3_claude_notifications)
(require 'claude-code-ide)

;;;; ------------------------------------------------------------------
;;;; Addressing, reading, sending
;;;; ------------------------------------------------------------------

(defun my/ccsm--dir-by-name (name)
  "Return the working-dir of the live session whose display name is NAME."
  (catch 'hit
    (maphash (lambda (dir proc)
               (when (and (process-live-p proc)
                          (equal (my/ccsm--display-name dir) name))
                 (throw 'hit dir)))
             claude-code-ide--processes)
    nil))

(defun my/ccsm--caller-dir ()
  "Return the working-dir of the session that invoked the current MCP tool."
  (plist-get (claude-code-ide-mcp-server-get-session-context) :project-dir))

(defun my/ccsm--read-output (dir &optional lines)
  "Return the last LINES (default 40) of session DIR's terminal screen."
  (let ((buf (get-buffer (claude-code-ide--get-buffer-name dir))))
    (when (buffer-live-p buf)
      (with-current-buffer buf
        (let* ((n (max 1 (or lines 40)))
               (start (save-excursion (goto-char (point-max))
                                      (forward-line (- n))
                                      (line-beginning-position))))
          (string-trim (buffer-substring-no-properties start (point-max))))))))

(defun my/ccsm--send-input (dir text &optional submit)
  "Type TEXT into session DIR's terminal; when SUBMIT, also press Return.
Embedded newlines in TEXT are sent as raw LF (Ctrl-J), which Claude's
input treats as a new line rather than a submit; carriage returns are
normalized to LF so the only thing that submits is the final Return."
  (let ((buf (get-buffer (claude-code-ide--get-buffer-name dir)))
        (body (replace-regexp-in-string "\r\n?" "\n" (or text ""))))
    (unless (buffer-live-p buf)
      (error "No live terminal for session %s" dir))
    (with-current-buffer buf
      (claude-code-ide--terminal-send-string body)
      (when submit (claude-code-ide--terminal-send-return)))
    t))

;;;; ------------------------------------------------------------------
;;;; Master designation
;;;; ------------------------------------------------------------------

(defun my/ccsm-set-master ()
  "Designate the session at point as the master/orchestrator (toggle)."
  (interactive)
  (let ((dir (my/ccsm--dir-at-point)))
    (unless dir (user-error "No session at point"))
    (setq my/ccsm--master (unless (equal dir my/ccsm--master) dir))
    (message "ccsm: master %s"
             (if my/ccsm--master
                 (format "set to %s" (my/ccsm--display-name my/ccsm--master))
               "cleared"))
    (my/ccsm--maybe-refresh)))

(with-eval-after-load '32_2_claude_session_manager
  (when (boundp 'my/ccsm-mode-map)
    (define-key my/ccsm-mode-map "m" #'my/ccsm-set-master)))

;;;; ------------------------------------------------------------------
;;;; PUSH: forward worker events to the master
;;;; ------------------------------------------------------------------

(defcustom my/ccsm-master-forward 'submit
  "How worker notifications are forwarded to the master session.
nil     -> do not forward
notify  -> type a one-line summary into the master, do NOT submit
submit  -> type the summary and submit it, so the master reacts at once"
  :type '(choice (const :tag "Off" nil)
                 (const :tag "Type only" notify)
                 (const :tag "Type and submit" submit))
  :group 'claude-code-ide)

(defun my/ccsm--forward-to-master (event)
  "Forward a worker EVENT into the master session's terminal."
  (when-let* ((mode my/ccsm-master-forward)
              (master my/ccsm--master)
              (dir (plist-get event :session))
              ((not (equal dir master)))
              (mbuf (get-buffer (claude-code-ide--get-buffer-name master)))
              ((buffer-live-p mbuf)))
    (let ((line (format "[ccsm] Worker \"%s\" needs attention: %s"
                        (my/ccsm--display-name dir)
                        (or (plist-get event :body)
                            (plist-get event :title) ""))))
      (with-current-buffer mbuf
        (claude-code-ide--terminal-send-string line)
        (when (eq mode 'submit)
          (claude-code-ide--terminal-send-return))))))

(add-hook 'my/ccsm-notification-functions #'my/ccsm--forward-to-master)

;;;; ------------------------------------------------------------------
;;;; MCP tools (the master's hands)
;;;; ------------------------------------------------------------------

(defun my/ccsm-tool-list-sessions ()
  "MCP tool: list the live Claude sessions for the orchestrator."
  (let ((self (my/ccsm--caller-dir))
        (rows '()))
    (dolist (s (my/ccsm--sessions))
      (let ((dir (plist-get s :dir)))
        (push (format "- %s%s | %s | branch:%s%s | %s"
                      (my/ccsm--display-name dir)
                      (cond ((equal dir self) " (you)")
                            ((equal dir my/ccsm--master) " (master)")
                            (t ""))
                      (if (my/ccsm--waiting-p dir) "WAITING-FOR-INPUT" "running")
                      (let ((b (plist-get s :branch))) (if (string-empty-p b) "-" b))
                      (let ((f (plist-get s :forge))) (if (string-empty-p f) "" (concat " " f)))
                      (let ((o (plist-get s :osc))) (if (string-empty-p o) "" o)))
              rows)))
    (if rows (mapconcat #'identity (nreverse rows) "\n") "No active Claude sessions")))

(defun my/ccsm-tool-read-session (name &optional lines)
  "MCP tool: return the recent terminal output of session NAME."
  (let ((dir (my/ccsm--dir-by-name name)))
    (if (not dir)
        (format "No session named %S.  Call list_claude_sessions for names." name)
      (or (my/ccsm--read-output dir (and lines (truncate lines)))
          "(no output)"))))

(defun my/ccsm-tool-send-session (name text)
  "MCP tool: type TEXT into session NAME and submit it."
  (let ((self (my/ccsm--caller-dir))
        (dir (my/ccsm--dir-by-name name)))
    (cond
     ((not dir)
      (format "No session named %S.  Call list_claude_sessions for names." name))
     ((equal dir self)
      (error "Refusing to send to the calling session itself"))
     (t
      (my/ccsm--send-input dir text t)
      (my/ccsm--clear-waiting dir)       ; commanding a worker attends to it
      (my/ccsm--maybe-refresh)
      (format "Sent to %s and submitted." name)))))

;; Idempotent (re)registration: drop prior copies before adding.
(setq claude-code-ide-mcp-server-tools
      (seq-remove
       (lambda (spec)
         (member (plist-get (claude-code-ide--normalize-tool-spec spec) :name)
                 '("list_claude_sessions" "read_session_output" "send_to_session")))
       claude-code-ide-mcp-server-tools))

(claude-code-ide-make-tool
 :function #'my/ccsm-tool-list-sessions
 :name "list_claude_sessions"
 :description "List the other live Claude Code sessions running in this Emacs (the workers you orchestrate): their stable name, whether each is WAITING-FOR-INPUT, its git branch, and its current activity title. Call this first to learn the names used by read_session_output and send_to_session."
 :args nil)

(claude-code-ide-make-tool
 :function #'my/ccsm-tool-read-session
 :name "read_session_output"
 :description "Read the recent terminal screen of another Claude session by name, to see what it is doing or asking. The text is that session's live TUI screen (may include UI chrome)."
 :args '((:name "name"
                :type string
                :description "Session name from list_claude_sessions (e.g. 'monocle-billing').")
         (:name "lines"
                :type integer
                :description "How many trailing lines to return (default 40)."
                :optional t)))

(claude-code-ide-make-tool
 :function #'my/ccsm-tool-send-session
 :name "send_to_session"
 :description "Type a prompt/answer into another Claude session by name and submit it (press Enter), to direct that worker. Use to answer a worker's question, give it a task, or unblock it. You cannot send to yourself. Multi-line is supported: put literal newlines in text — each becomes a new line (Ctrl-J) in the worker's input, and Enter is pressed only once, at the end, to submit."
 :args '((:name "name"
                :type string
                :description "Target session name from list_claude_sessions.")
         (:name "text"
                :type string
                :description "The text to type into that session before submitting. May contain newlines for a multi-line prompt; only the final submit presses Enter.")))

(provide '32_5_claude_orchestrator)
;;; 32_5_claude_orchestrator.el ends here
