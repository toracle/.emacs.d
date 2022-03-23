;;; 00_default.el

;;; Code:

(prefer-coding-system 'utf-8)

(menu-bar-mode -1)
(column-number-mode t)
(xterm-mouse-mode t)

(setq save-abbrevs 'silently)
(setq inhibit-startup-screen t)
(setq dired-dwim-target t)
(setq backup-directory-alist `((".*" . ,temporary-file-directory)))
(setq auto-save-file-name-transforms `((".*" ,temporary-file-directory t)))
(setq default-input-method "korean-hangul")

(setq-default indent-tabs-mode nil)

(global-set-key (kbd "C-x C-o") 'other-frame)
(global-set-key (kbd "S-SPC") 'toggle-input-method)

(when (eq system-type 'darwin)
  (setenv "LANG" "en_US.UTF-8")
  (when (file-exists-p "/usr/local/bin")
    (setenv "PATH" (concat (getenv "PATH") ":/usr/local/bin"))
    (add-to-list 'exec-path "/usr/local/bin"))
  (use-package exec-path-from-shell :ensure t)
  (exec-path-from-shell-initialize))

(defun init-loader-file-path (name)
  "Return a file path with NAME on init-loader directory."
  (concat (file-name-as-directory (concat user-emacs-directory "init-loader"))
	  name))

(use-package dashboard
  :ensure t
  :config (dashboard-setup-startup-hook))

(use-package smart-mode-line
  :init (setq sml/no-confirm-load-theme t)
  :config (sml/setup)
  :ensure t)

(use-package smart-mode-line-powerline-theme
  :ensure t
  :config (sml/apply-theme 'powerline))

(use-package ample-theme
  :ensure t
  :config (ample-theme))

(use-package zoom-window
  :ensure t
  :bind (("C-x C-z" . zoom-window-zoom)))

(use-package dedicated
  :ensure t)

(use-package ibuffer-vc
  :ensure t)

;; (use-package org-plus-contrib
;;   :ensure t)

(use-package switch-window
  :ensure t)

(use-package visual-regexp-steroids
  :ensure t)

(use-package robe
  :ensure t)

(use-package ess
  :ensure t)

(use-package format-sql
  :ensure t)

(use-package xml-rpc
  :ensure t)

(use-package ledger-mode
  :ensure t)

(use-package ag
  :ensure t)

;; (use-package perspective
;;   :ensure t
;;   :config (persp-mode))


(defun spacemacs-ui-visual/compilation-buffer-apply-ansi-colors ()
  (let ((inhibit-read-only t))
    (toggle-read-only)
    (ansi-color-apply-on-region compilation-filter-start (point-max))
    (toggle-read-only)))

(defun create-new-scratch-buffer ()
  (interactive)
  (let ((buff (generate-new-buffer "*scratch*")))
    (set-buffer buff)
    (lisp-interaction-mode)
    (insert ";; This buffer is for text that is not saved, and for Lisp evaluation.\n")
    (insert ";; To create a file, visit it with C-x C-f and enter text in its buffer.\n")
    (insert "\n")
    (display-buffer buff)))

(global-set-key (kbd "C-x n RET") 'create-new-scratch-buffer)

(add-hook 'compilation-filter-hook 'spacemacs-ui-visual/compilation-buffer-apply-ansi-colors)
(add-hook 'shell-mode-hook 'ansi-color-for-comint-mode-on)
(add-to-list 'comint-output-filter-functions 'ansi-color-process-output)
(add-to-list 'Info-additional-directory-list (expand-file-name "~/texinfo"))

(add-hook 'yaml-mode-hook (lambda () (yafolding-mode t)))

;; to prevent emacs crash when confronts emoji
;; https://github.com/syl20bnr/spacemacs/issues/10695
(add-to-list 'face-ignored-fonts "Noto Color Emoji")

(setq epa-file-encrypt-to '("97F2043EC220D593"))

(use-package notmuch
  :ensure t
  :config (setq notmuch-search-oldest-first nil))

(require 'mu4e)

(setq mu4e-sent-folder   "/toracle/[Gmail]/Sent Mail"
      mu4e-drafts-folder "/toracle/[Gmail]/Drafts"
      mu4e-trash-folder  "/toracle/[Gmail]/Trash")

(use-package w3m
  :ensure t)

(setq gnus-select-method '(nntp "reader443.eternal-september.org"))

(provide '00_default)
;;; 00_default.el ends here
