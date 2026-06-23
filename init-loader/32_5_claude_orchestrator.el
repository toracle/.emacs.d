;;; 32_5_claude_orchestrator.el --- Butler/worker orchestration for CCSM  -*- lexical-binding: t; -*-

;; Turns the session manager into a control plane: a designated *butler*
;; Claude session drives the *worker* sessions through Emacs.  Emacs is the
;; bus — workers are reached through their ghostel shells.
;;
;; Two directions:
;;
;;   PULL  — the butler actively inspects and commands workers via three MCP
;;           tools it can call:
;;             list_claude_sessions   what's running, who's waiting, branches
;;             read_session_output    a worker's current screen
;;             send_to_session        type a prompt into a worker and submit
;;
;;   PUSH  — when a worker posts a notification (needs input / done), the event
;;           is forwarded into the butler's terminal so it can aggregate and
;;           proactively report to you over its own remote-control channel.
;;
;; You remote-control ONE session (the butler) from your phone; it becomes the
;; situation room for the rest.  Designate it with `b' in the manager buffer.

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

(defun my/ccsm--refresh-terminal-text (buffer)
  "Force BUFFER's text to be re-synced from the live ghostel grid.
ghostel only repaints a buffer that is displayed in a window; a
background session buffer is never redisplayed, so its text can be a
stale frame.  Drive a full `ghostel--redraw' directly (the same call
ghostel makes on config changes) so the text reflects the current frame
without needing a window."
  (with-current-buffer buffer
    (when (and (boundp 'ghostel--term) ghostel--term (fboundp 'ghostel--redraw))
      (let ((inhibit-read-only t))
        (ignore-errors (ghostel--redraw ghostel--term t))))))

(defun my/ccsm--read-output (dir &optional lines)
  "Return the last LINES (default 40) of session DIR's terminal screen.
The terminal text is force-refreshed first so the capture is always the
current frame, even for a background (non-displayed) buffer."
  (let ((buf (get-buffer (claude-code-ide--get-buffer-name dir))))
    (when (buffer-live-p buf)
      (my/ccsm--refresh-terminal-text buf)
      (with-current-buffer buf
        (let* ((n (max 1 (or lines 40)))
               (start (save-excursion (goto-char (point-max))
                                      (forward-line (- n))
                                      (line-beginning-position))))
          (string-trim (buffer-substring-no-properties start (point-max))))))))

(defcustom my/ccsm-submit-delay 0.1
  "Seconds to wait after sending text before the submitting Return.
The worker's input must settle before Enter or the Return is dropped and
nothing submits (the same delay `claude-code-ide-send-prompt' uses)."
  :type 'number
  :group 'claude-code-ide)

(defun my/ccsm--send-input (dir text &optional submit)
  "Type TEXT into session DIR's terminal; when SUBMIT, also press Return.
Claude treats a raw LF as a submit, so multi-line TEXT is delivered as a
bracketed paste (\\e[200~..\\e[201~) — Claude enables paste mode, which
keeps the embedded newlines literal so only the final Return submits.
Carriage returns are normalized to LF and stray ESC bytes are stripped so
the body cannot break out of the paste or submit mid-prompt.  A short
settle delay precedes the Return so it is not dropped before the input is
processed."
  (let* ((buf (get-buffer (claude-code-ide--get-buffer-name dir)))
         (body (replace-regexp-in-string
                "\e" ""
                (replace-regexp-in-string "\r\n?" "\n" (or text "")))))
    (unless (buffer-live-p buf)
      (error "No live terminal for session %s" dir))
    (with-current-buffer buf
      (if (string-search "\n" body)
          (claude-code-ide--terminal-send-string (concat "\e[200~" body "\e[201~"))
        (claude-code-ide--terminal-send-string body))
      (when submit
        (sleep-for my/ccsm-submit-delay)
        (claude-code-ide--terminal-send-return)))
    t))

;;;; ------------------------------------------------------------------
;;;; Butler designation
;;;; ------------------------------------------------------------------

(defun my/ccsm-set-butler ()
  "Designate the session at point as the butler (toggle)."
  (interactive)
  (let ((dir (my/ccsm--dir-at-point)))
    (unless dir (user-error "No session at point"))
    (setq my/ccsm--butler (unless (equal dir my/ccsm--butler) dir))
    (message "ccsm: butler %s"
             (if my/ccsm--butler
                 (format "set to %s" (my/ccsm--display-name my/ccsm--butler))
               "cleared"))
    (my/ccsm--maybe-refresh)))

(with-eval-after-load '32_2_claude_session_manager
  (when (boundp 'my/ccsm-mode-map)
    (define-key my/ccsm-mode-map "b" #'my/ccsm-set-butler)))

;;;; ------------------------------------------------------------------
;;;; Launch a session joined to the CCSM channel
;;;; ------------------------------------------------------------------

;;;###autoload
(defun my/ccsm-launch-with-channel ()
  "Start a Claude session in the current project with the CCSM channel.
Requires `my/ccsm-channel-args' to be set (the `--channels' /
`--dangerously-load-development-channels' flag for your channel server)."
  (interactive)
  (when (string-empty-p (string-trim (or my/ccsm-channel-args "")))
    (user-error "Set `my/ccsm-channel-args' to a channel launch flag first"))
  (my/ccsm--with-channel (claude-code-ide)))

;;;; ------------------------------------------------------------------
;;;; PUSH: forward worker events to the butler
;;;; ------------------------------------------------------------------

(defcustom my/ccsm-butler-forward 'submit
  "How worker notifications are forwarded to the butler session.
nil     -> do not forward
notify  -> type a one-line summary into the butler, do NOT submit
submit  -> type the summary and submit it, so the butler reacts at once"
  :type '(choice (const :tag "Off" nil)
                 (const :tag "Type only" notify)
                 (const :tag "Type and submit" submit))
  :group 'claude-code-ide)

(defun my/ccsm--forward-to-butler (event)
  "Forward a worker EVENT into the butler session's terminal."
  (when-let* ((mode my/ccsm-butler-forward)
              (butler my/ccsm--butler)
              (dir (plist-get event :session))
              ((not (equal dir butler)))
              (mbuf (get-buffer (claude-code-ide--get-buffer-name butler)))
              ((buffer-live-p mbuf)))
    (my/ccsm--send-input
     butler
     (format "[ccsm] Worker %s needs attention: %s"
             (my/ccsm--who-dir dir)
             (or (plist-get event :body) (plist-get event :title) ""))
     (eq mode 'submit))))

(add-hook 'my/ccsm-notification-functions #'my/ccsm--forward-to-butler)

;;;; ------------------------------------------------------------------
;;;; MCP tools (the butler's hands)
;;;; ------------------------------------------------------------------

(defun my/ccsm-tool-list-sessions ()
  "MCP tool: list the live Claude sessions for the butler."
  (let ((self (my/ccsm--caller-dir))
        (rows '()))
    (dolist (s (my/ccsm--sessions))
      (let ((dir (plist-get s :dir)))
        (push (format "- %s%s | %s | branch:%s%s | %s"
                      (my/ccsm--display-name dir)
                      (cond ((equal dir self) " (you)")
                            ((equal dir my/ccsm--butler) " (butler)")
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
      (my/ccsm--log "%s → %s │ %s" (my/ccsm--who-dir self) (my/ccsm--who-dir dir) text)
      (my/ccsm--maybe-refresh)
      (format "Sent to %s and submitted." name)))))

(defun my/ccsm-tool-report-to-butler (summary &optional status needs)
  "MCP tool: a worker reports to the butler with real content.
SUMMARY is what happened / what was done, STATUS the current state, and
NEEDS what the worker needs from the human (all teed to the inbox and
log).  The caller's session name and id are attached automatically."
  (let ((self (my/ccsm--caller-dir)))
    (unless self
      (error "No calling session context for this report"))
    (let* ((parts (delq nil
                        (list (and (stringp summary) (not (string-empty-p summary)) summary)
                              (and (stringp status) (not (string-empty-p status))
                                   (concat "status: " status))
                              (and (stringp needs) (not (string-empty-p needs))
                                   (concat "needs: " needs)))))
           (msg (if parts (string-join parts " · ") "(empty report)")))
      (my/ccsm--inbox-push self msg)
      (my/ccsm--maybe-refresh)
      (format "Reported to the butler as %s." (my/ccsm--who-dir self)))))

(defun my/ccsm-tool-inbox ()
  "MCP tool: return and clear the butler's pending worker events.
This is the pull side of the bus: worker notifications (needs input /
done) are queued in Emacs and drained here, so the butler gets them
without anything being typed into its input box."
  (if (null my/ccsm--inbox)
      "No pending worker events."
    (let ((events (reverse my/ccsm--inbox)))
      (setq my/ccsm--inbox nil)
      (mapconcat (lambda (e)
                   (format "- [%s] %s: %s"
                           (format-time-string "%H:%M" (plist-get e :time))
                           (my/ccsm--who (plist-get e :name) (plist-get e :id))
                           (plist-get e :body)))
                 events "\n"))))

;; Idempotent (re)registration: drop prior copies before adding.
(setq claude-code-ide-mcp-server-tools
      (seq-remove
       (lambda (spec)
         (member (plist-get (claude-code-ide--normalize-tool-spec spec) :name)
                 '("list_claude_sessions" "read_session_output"
                   "send_to_session" "pending_events" "report_to_butler")))
       claude-code-ide-mcp-server-tools))

(claude-code-ide-make-tool
 :function #'my/ccsm-tool-inbox
 :name "pending_events"
 :description "Drain the butler's inbox: pending events from worker sessions that need attention (a worker asked a question, finished, reported, or hit a prompt), newest last. Each line is a timestamped worker name (with its session id) and message. Call this at the start of each turn (and whenever you are nudged) to learn what changed without anything being typed into your input box. Returns the events and clears them."
 :args nil)

(claude-code-ide-make-tool
 :function #'my/ccsm-tool-report-to-butler
 :name "report_to_butler"
 :description "Report up to the butler/orchestrator with real content — not just 'I need attention'. State WHAT happened / what you did, the current STATE, and exactly what you NEED from the human (a decision, input, or nothing). Your session name and id are attached automatically; the butler reads it from its inbox and relays a summary to the human. Call it when you finish, get blocked, or need a decision."
 :args '((:name "summary"
                :type string
                :description "What happened or what you did — the substance of the report (e.g. 'implemented invoice PDF rendering, all tests pass').")
         (:name "status"
                :type string
                :description "Current state, e.g. 'PR #42 open, CI green' or 'blocked on the DB migration'. Optional."
                :optional t)
         (:name "needs"
                :type string
                :description "What you need from the human/butler to proceed, e.g. 'approve the merge' or 'which auth method to use'. Omit (or 'nothing') if you are only informing. Optional."
                :optional t)))

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
 :description "Type a prompt/answer into another Claude session by name and submit it (press Enter), to direct that worker. Use to answer a worker's question, give it a task, or unblock it. You cannot send to yourself. Multi-line is supported: include newlines in text — they are delivered as a paste and stay literal, and Enter is pressed only once, at the end, to submit."
 :args '((:name "name"
                :type string
                :description "Target session name from list_claude_sessions.")
         (:name "text"
                :type string
                :description "The text to type into that session before submitting. May contain newlines for a multi-line prompt; only the final submit presses Enter.")))

(provide '32_5_claude_orchestrator)
;;; 32_5_claude_orchestrator.el ends here
