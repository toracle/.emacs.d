;;; 10_gnus.el -- gnus setting

;;; Code:
(require 'cl)
(require 'smtpmail)

;; (setq gnus-select-method '(nnimap "gmail"
;; 				  (nnimap-address "imap.gmail.com")
;; 				  (nnimap-server-port 993)
;; 				  (nnimap-authinfo-file "~/.imap-authinfo")
;; 				  (nnimap-stream ssl)))

(setq imap-use-utf7 nil)
(setq mm-text-html-renderer 'w3m)
(setq mm-inline-text-html-with-images t)

(setq send-mail-function 'smtpmail-send-it
      message-send-mail-function 'smtpmail-send-it
      mail-from-style nil)

(load "~/.smtpinfo" 'noerror)

(setq smtpmail-debug-info t)

(defun set-smtp (mech server port user password)
  "Set related SMTP variables for supplied parameters."
  (setq starttls-use-gnutls nil
	starttls-gnutls-program nil
	starttls-extra-arguments nil
	smtpmail-smtp-server server
	smtpmail-smtp-service port
	smtpmail-auth-credentials (list (list server port user password))
	smtpmail-starttls-credentials nil
	smtpmail-auth-supported (list mech))
  (message "Setting SMTP server to `%s:%s' for user `%s'."
	   server port user))

(defun set-smtp-ssl (server port user password &optional key cert)
  "Set related SMTP and SSL variables for supplied parameters."
  (setq starttls-use-gnutls t
	starttls-gnutls-program "gnutls-cli"
	starttls-extra-arguments nil
	smtpmail-smtp-server server
	smtpmail-smtp-service port
	smtpmail-auth-credentials (list (list server port user password))
	smtpmail-starttls-credentials (list (list server port key cert)))
  (message "Setting SMTP server to `%s:%s' for user `%s'. (SSL enabled.)"
	   server port user))

(defun change-smtp ()
  "Change the SMTP server according to the current from line."
  (save-excursion
    (loop with from = (save-restriction
			(message-narrow-to-headers)
			(message-fetch-field "from"))
	  for (auth-mech address . auth-spec) in smtp-accounts
	  when (string-match address from)
	  do (cond ((memq auth-mech '(cram-md5 plain login))
		    (return (apply 'set-smtp (cons auth-mech auth-spec))))
		   ((eql auth-mech 'ssl)
		    (return (apply 'set-smtp-ssl auth-spec)))
		   (t (error "Unrecognized SMTP auth. mechanism: `%s'." auth-mech)))
	  finally (error "Cannot infer SMTP information."))))

(defadvice smtpmail-via-smtp
    (before smtpmail-via-smtp-ad-change-smtp (recipient smtpmail-text-buffer))
  "Call `change-smtp' before every `smtpmail-via-smtp'."
  (with-current-buffer smtpmail-text-buffer (change-smtp)))

(ad-activate 'smtpmail-via-smtp)

(provide '10_gnus)
;;; 10_gnus.el ends here
