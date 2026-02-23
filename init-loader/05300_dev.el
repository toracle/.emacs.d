;;; 05300_dev.el -- language configuration

(use-package eglot
  :ensure t)

(use-package corfu
  :ensure t
  :init (global-corfu-mode)
  :config (progn (setq corfu-auto t)))

(use-package corfu-terminal
  :ensure t
  :init (unless (display-graphic-p)
          (corfu-terminal-mode +1)))

(use-package cape
  :ensure t)

(use-package flycheck
  :ensure t
  )

(use-package flycheck-inline
  :ensure t)

(use-package epc
  :ensure t)

(use-package toml-mode
  :ensure t)

(require 'ansi-color)
(defun ansi-colorize-buffer ()
  (read-only-mode 'toggle)
  (ansi-color-apply-on-region (point-min) (point-max))
  (read-only-mode 'toggle))
  
(add-hook 'compilation-filter-hook 'ansi-colorize-buffer)

(use-package feature-mode
  :ensure t
  :config (add-to-list 'auto-mode-alist '("\.feature$" . feature-mode)))

(provide '05300_dev)
