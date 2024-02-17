;;; 14_0_lang.el -- language configuration


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


(require 'treesit)
(if (treesit-available-p)
    t)


(provide '14_0_lang)
