;;; 32_3_claude_notifications.el --- Claude session notification events  -*- lexical-binding: t; -*-

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

(require '32_2_claude_session_manager)
(require 'format-spec)

(defgroup my/ccsm-notify nil
  "Decoupled notification events for Claude Code sessions."
  :group 'claude-code-ide)

;;;; ------------------------------------------------------------------
;;;; The event hook
;;;; ------------------------------------------------------------------

(defvar my/ccsm-notification-functions nil
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

(defun my/ccsm-emit-notification (event)
  "Run `my/ccsm-notification-functions' with EVENT (a no-op when empty)."
  (run-hook-with-args 'my/ccsm-notification-functions event))

;;;; ------------------------------------------------------------------
;;;; Source: ride ghostel's notification callback
;;;; ------------------------------------------------------------------

(defvar my/ccsm--prior-ghostel-notify nil
  "The `ghostel-notification-function' in effect before we took it over.
Chained after emitting so ghostel's built-in (e.g. local OS) notifier
still runs.")

(defun my/ccsm--on-ghostel-notification (title body)
  "Emit a decoupled event for a ghostel TITLE/BODY notification.
ghostel calls this in the originating terminal buffer, so the current
buffer identifies the session.  After emitting, the previously-installed
ghostel notifier is chained so existing behavior is preserved."
  (let* ((buffer (current-buffer))
         (dir (my/ccsm--dir-for-buffer buffer)))
    (my/ccsm-emit-notification
     (list :type 'notification
           :title (or title "")
           :body (or body "")
           :buffer buffer
           :session dir
           :name (and dir (my/ccsm--display-name dir))))
    (when (and my/ccsm--prior-ghostel-notify
               (not (eq my/ccsm--prior-ghostel-notify
                        #'my/ccsm--on-ghostel-notification)))
      (ignore-errors (funcall my/ccsm--prior-ghostel-notify title body)))))

(defun my/ccsm--install-notification-source ()
  "Take over `ghostel-notification-function', remembering the prior one."
  (when (and (boundp 'ghostel-notification-function)
             (not (eq ghostel-notification-function
                      #'my/ccsm--on-ghostel-notification)))
    (setq my/ccsm--prior-ghostel-notify ghostel-notification-function))
  (setq ghostel-notification-function #'my/ccsm--on-ghostel-notification))

(with-eval-after-load 'ghostel
  (my/ccsm--install-notification-source))

;;;; ------------------------------------------------------------------
;;;; Ready-made listeners (opt-in; pick per environment)
;;;; ------------------------------------------------------------------

(defun my/ccsm--event-title (event)
  "A human label for EVENT: the session name if known, else the title."
  (or (plist-get event :name)
      (let ((title (plist-get event :title)))
        (and (stringp title) (not (string-empty-p title)) title))
      "Claude"))

(defun my/ccsm-notify-echo (event)
  "Listener: echo EVENT to the echo area and *Messages* (handy for testing)."
  (message "[Claude] %s — %s"
           (my/ccsm--event-title event)
           (or (plist-get event :body) (plist-get event :title) "")))

(defun my/ccsm--dbus-available-p ()
  "Return non-nil when a D-Bus session bus looks reachable."
  (and (featurep 'dbusbind)
       (getenv "DBUS_SESSION_BUS_ADDRESS")
       t))

(defun my/ccsm-notify-desktop (event)
  "Listener: show EVENT as a local OS desktop notification.
Use this only if you have disabled ghostel's own notifier (otherwise
you'd get two).  Best-effort and OS-dependent."
  (let ((title (my/ccsm--event-title event))
        (body (or (plist-get event :body) "")))
    (cond
     ((and (fboundp 'notifications-notify) (my/ccsm--dbus-available-p))
      (ignore-errors
        (notifications-notify :title title :body body :app-name "Claude Code")))
     ((fboundp 'ghostel-default-notify)
      (ignore-errors (ghostel-default-notify title body))))))

(defcustom my/ccsm-notify-command nil
  "Shell command template for `my/ccsm-notify-command-listener'.
%t expands to the (shell-quoted) title, %b to the (shell-quoted) body.
Examples:
  \"telegram-send --title %t %b\"
  \"~/bin/notify-remote %t %b\""
  :type '(choice (const :tag "None" nil) string)
  :group 'my/ccsm-notify)

(defun my/ccsm-notify-command-listener (event)
  "Listener: run `my/ccsm-notify-command' for EVENT (for remote/messenger use).
Runs asynchronously so a slow backend never blocks Emacs."
  (when my/ccsm-notify-command
    (let* ((title (my/ccsm--event-title event))
           (body (or (plist-get event :body) ""))
           (cmd (format-spec my/ccsm-notify-command
                             `((?t . ,(shell-quote-argument title))
                               (?b . ,(shell-quote-argument body))))))
      (ignore-errors
        (let ((proc (start-process-shell-command "ccsm-notify" nil cmd)))
          (set-process-query-on-exit-flag proc nil))))))

(provide '32_3_claude_notifications)
;;; 32_3_claude_notifications.el ends here
