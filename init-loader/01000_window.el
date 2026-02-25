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

(use-package hydra
  :ensure t)

(defun toggle-window-dedicated ()
  "Toggle whether the current active window is dedicated or not"
  (interactive)
  (message
   (if (let (window (get-buffer-window (current-buffer)))
         (set-window-dedicated-p window
                                 (not (window-dedicated-p window))))
       "Window '%s' is dedicated"
     "Window '%s' is undedicated")
   (current-buffer)))

(defhydra hydra-windmove (:hint t)
  "windmove"
  ("j" windmove-left "left")
  ("l" windmove-right "right")
  ("i" windmove-up "up")
  ("k" windmove-down "down")
  ("o" other-window "other")
  ("." toggle-window-dedicated "dedicate"))

(global-set-key (kbd "C-x o") #'hydra-windmove/body)

;;; 01_window.el ends here
