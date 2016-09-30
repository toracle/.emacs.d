;;; 00_default.el

;;; Code:

(prefer-coding-system 'utf-8)

(menu-bar-mode -1)
(column-number-mode t)
(xterm-mouse-mode t)

(setq save-abbrevs 'silently)

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

(setq inhibit-startup-screen t)

(global-set-key (kbd "C-x C-o") 'other-frame)

(when (eq system-type 'darwin)
  (add-to-list 'exec-path "/usr/local/bin"))

(setq dired-dwim-target t)

(setq backup-directory-alist
      `((".*" . ,temporary-file-directory)))

(setq auto-save-file-name-transforms
      `((".*" ,temporary-file-directory t)))

(when (eq system-type 'darwin)
  (setenv "PATH" (concat (getenv "PATH") ":/usr/local/bin"))
  (setenv "LANG" "en_US.UTF-8"))

(setq default-input-method "korean-hangul")
(global-set-key (kbd "S-SPC") 'toggle-input-method)

(use-package zoom-window
  :ensure t
  :bind (("C-x C-z" . zoom-window-zoom)))

(use-package flycheck
  :ensure t
  :config (add-hook 'after-init-hook #'global-flycheck-mode))

(use-package company
  :ensure t)

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
