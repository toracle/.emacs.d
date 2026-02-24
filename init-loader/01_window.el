;; window

;;; Code:

(if (display-graphic-p)
    (load-theme 'leuven-dark)
  (load-theme 'tango-dark))

(winner-mode t)

(when (fboundp 'windmove-default-keybindings)
  (windmove-default-keybindings 'meta))

(global-set-key (kbd "M-L") 'enlarge-window-horizontally)
(global-set-key (kbd "M-H") 'shrink-window-horizontally)
(global-set-key (kbd "M-K") 'shrink-window)
(global-set-key (kbd "M-J") 'enlarge-window)

; (global-set-key (kbd "C-x o") 'switch-window)

(use-package vertico
  :ensure t
  :config (vertico-mode t))

(use-package orderless
  :ensure t
  :config (setq completion-styles '(orderless basic)))

(use-package marginalia
  :ensure t
  :config (marginalia-mode t))

(use-package consult
  :ensure t)

(use-package zoom-window
  :ensure t
  :bind (("C-x C-z" . zoom-window-zoom)))

(use-package dedicated
  :ensure t)

(use-package all-the-icons
  :ensure t
  :if (display-graphic-p))

;;; 01_window.el ends here
