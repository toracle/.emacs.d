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

(global-set-key (kbd "C-x C-o") 'other-frame)
(global-set-key (kbd "S-SPC") 'toggle-input-method)

(when (eq system-type 'darwin)
  (setenv "LANG" "en_US.UTF-8")
  (when (file-exists-p "/usr/local/bin")
    (setenv "PATH" (concat (getenv "PATH") ":/usr/local/bin"))
    (add-to-list 'exec-path "/usr/local/bin")))

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

(use-package page-break-lines
  :ensure t
  :config (global-page-break-lines-mode t))

(use-package zoom-window
  :ensure t
  :bind (("C-x C-z" . zoom-window-zoom)))

(use-package flycheck
  :ensure t
  :config (progn
	    (add-hook 'after-init-hook #'global-flycheck-mode)
	    (add-hook 'python-mode-hook (lambda () (flymake-mode -1)))
	    (add-hook 'python-mode-hook (lambda () (flycheck-select-checker 'python-pylint)))
	    (add-hook 'python-mode-hook (lambda ()
					  (setq flycheck-pylintrc
						(concat (file-name-as-directory (concat user-emacs-directory "init-loader"))
							"pylintrc"))))))

(use-package company
  :ensure t
  :config (progn
	    (add-hook 'python-mode-hook (lambda () (company-mode t)))))

(use-package dedicated
  :ensure t)

(use-package ibuffer-vc
  :ensure t)

(use-package org-plus-contrib
  :ensure t)

(use-package switch-window
  :ensure t)

(use-package visual-regexp-steroids
  :ensure t)

(use-package aggressive-indent
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

(provide '00_default)
;;; 00_default.el ends here
