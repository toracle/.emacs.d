;;; cc-butler-notifications.el --- Claude session notification events  -*- lexical-binding: t; -*-

;; Claude Code raises a terminal notification (OSC 9 / OSC 777) when its agent
;; loop ends or it needs you (a question, a permission prompt, "done").  In a
;; local GUI terminal that becomes a system-tray notification; ghostel already
;; routes it to `ghostel-notification-function' (whose default pops an OS
;; notification via alert.el).
;;
;; That single callback is awkward for a headless Emacs daemon reached over
;; SSH: there is no local tray to notify.  So we turn it into a *decoupled
;; event*: an abnormal hook anyone can listen on.
;;
;;   - No listener  -> the event simply vanishes.
;;   - Listeners    -> each is called with the EVENT plist and may do anything
;;                     (pop an OS notification locally, shell out to a
;;                     messenger CLI on a remote box, log it, ...).
;;
;; ghostel's own default notifier is preserved (chained), so a local GUI Emacs
;; keeps its tray notification for free; the hook is the *extra* extensibility
;; point for environment-specific backends.  Nothing below is enabled by
;; default — add the listener that fits your run environment.

(require 'cc-butler-session)
(require 'format-spec)

(defgroup cc-butler-notify nil
  "Decoupled notification events for Claude Code sessions."
  :group 'cc-butler)

;;;; ------------------------------------------------------------------
;;;; The event hook
;;;; ------------------------------------------------------------------

(defvar cc-butler-notification-functions nil
  "Abnormal hook run when a Claude session posts a notification.
Each listener is called with one argument, an EVENT plist:

  :type    always the symbol `notification'
  :title   notification title  (string)
  :body    notification body   (string)
  :buffer  the session terminal buffer
  :session the session working-dir, or nil if not a managed session
  :name    the session display name, or nil

Register listeners with `add-hook'.  With no listeners the event is
dropped silently.")

(defun cc-butler-emit-notification (event)
  "Run `cc-butler-notification-functions' with EVENT (a no-op when empty)."
  (run-hook-with-args 'cc-butler-notification-functions event))

;;;; ------------------------------------------------------------------
;;;; Source: ride ghostel's notification callback
;;;; ------------------------------------------------------------------

(defvar cc-butler--prior-ghostel-notify nil
  "The `ghostel-notification-function' in effect before we took it over.
Chained after emitting so ghostel's built-in (e.g. local OS) notifier
still runs.")

(defun cc-butler--on-ghostel-notification (title body)
  "Emit a decoupled event for a ghostel TITLE/BODY notification.
ghostel calls this in the originating terminal buffer, so the current
buffer identifies the session.  After emitting, the previously-installed
ghostel notifier is chained so existing behavior is preserved."
  (let* ((buffer (current-buffer))
         (dir (cc-butler--dir-for-buffer buffer)))
    (cc-butler-emit-notification
     (list :type 'notification
           :title (or title "")
           :body (or body "")
           :buffer buffer
           :session dir
           :name (and dir (cc-butler--display-name dir))))
    (when (and cc-butler--prior-ghostel-notify
               (not (eq cc-butler--prior-ghostel-notify
                        #'cc-butler--on-ghostel-notification)))
      (ignore-errors (funcall cc-butler--prior-ghostel-notify title body)))))

(defun cc-butler--install-notification-source ()
  "Take over `ghostel-notification-function', remembering the prior one."
  (when (and (boundp 'ghostel-notification-function)
             (not (eq ghostel-notification-function
                      #'cc-butler--on-ghostel-notification)))
    (setq cc-butler--prior-ghostel-notify ghostel-notification-function))
  (setq ghostel-notification-function #'cc-butler--on-ghostel-notification))

(with-eval-after-load 'ghostel
  (cc-butler--install-notification-source))

;;;; ------------------------------------------------------------------
;;;; Ready-made listeners (opt-in; pick per environment)
;;;; ------------------------------------------------------------------

(defun cc-butler--event-title (event)
  "A human label for EVENT: the session name if known, else the title."
  (or (plist-get event :name)
      (let ((title (plist-get event :title)))
        (and (stringp title) (not (string-empty-p title)) title))
      "Claude"))

(defun cc-butler-notify-echo (event)
  "Listener: echo EVENT to the echo area and *Messages* (handy for testing)."
  (message "[Claude] %s — %s"
           (cc-butler--event-title event)
           (or (plist-get event :body) (plist-get event :title) "")))

(defun cc-butler--dbus-available-p ()
  "Return non-nil when a D-Bus session bus looks reachable."
  (and (featurep 'dbusbind)
       (getenv "DBUS_SESSION_BUS_ADDRESS")
       t))

(defun cc-butler-notify-desktop (event)
  "Listener: show EVENT as a local OS desktop notification.
Use this only if you have disabled ghostel's own notifier (otherwise
you'd get two).  Best-effort and OS-dependent."
  (let ((title (cc-butler--event-title event))
        (body (or (plist-get event :body) "")))
    (cond
     ((and (fboundp 'notifications-notify) (cc-butler--dbus-available-p))
      (ignore-errors
        (notifications-notify :title title :body body :app-name "Claude Code")))
     ((fboundp 'ghostel-default-notify)
      (ignore-errors (ghostel-default-notify title body))))))

(defcustom cc-butler-notify-command nil
  "Shell command template for `cc-butler-notify-command-listener'.
%t expands to the (shell-quoted) title, %b to the (shell-quoted) body.
Examples:
  \"telegram-send --title %t %b\"
  \"~/bin/notify-remote %t %b\""
  :type '(choice (const :tag "None" nil) string)
  :group 'cc-butler-notify)

(defun cc-butler-notify-command-listener (event)
  "Listener: run `cc-butler-notify-command' for EVENT (for remote/messenger use).
Runs asynchronously so a slow backend never blocks Emacs."
  (when cc-butler-notify-command
    (let* ((title (cc-butler--event-title event))
           (body (or (plist-get event :body) ""))
           (cmd (format-spec cc-butler-notify-command
                             `((?t . ,(shell-quote-argument title))
                               (?b . ,(shell-quote-argument body))))))
      (ignore-errors
        (let ((proc (start-process-shell-command "cc-butler-notify" nil cmd)))
          (set-process-query-on-exit-flag proc nil))))))

;;;; ------------------------------------------------------------------
;;;; Built-in listener: input-waiting approval queue
;;;; ------------------------------------------------------------------

;; A Claude session that posts a notification is asking for attention
;; (a question, a permission prompt, "done").  Treat that as "awaiting
;; user input" and bubble it to the top of the session list as a FIFO
;; approval queue.  Visiting the session (RET) clears it from the queue.
(defun cc-butler--queue-on-notification (event)
  "Enqueue the notifying session: mark it waiting and record it in the inbox."
  (when-let ((dir (plist-get event :session)))
    (cc-butler--mark-waiting dir)
    (cc-butler--inbox-push dir (or (plist-get event :body)
                                 (plist-get event :title) ""))
    (cc-butler--maybe-refresh)))

(add-hook 'cc-butler-notification-functions #'cc-butler--queue-on-notification)

(provide 'cc-butler-notifications)
;;; cc-butler-notifications.el ends here
