;; window

;;; Code:

(when (fboundp 'windmove-default-keybindings)
  (windmove-default-keybindings 'meta))

(global-set-key (kbd "C-c <left>")  'windmove-left)
(global-set-key (kbd "C-c <right>") 'windmove-right)
(global-set-key (kbd "C-c <up>")    'windmove-up)
(global-set-key (kbd "C-c <down>")  'windmove-down)

(global-set-key (kbd "M-L") 'enlarge-window-horizontally)
(global-set-key (kbd "M-H") 'shrink-window-horizontally)
(global-set-key (kbd "M-K") 'shrink-window)
(global-set-key (kbd "M-J") 'enlarge-window)

; (global-set-key (kbd "C-x o") 'switch-window)

(winner-mode 1)

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

(global-set-key (kbd "C-c , .") 'toggle-window-dedicated)

(defun purpose/init ()
  (add-to-list 'purpose-user-regexp-purposes '("magit:.*" . magit))
  (purpose-compile-user-configuration)
  (purpose-mode 1))

(use-package ivy
  :ensure t
  :config (ivy-mode 1))

;; (use-package window-purpose
;;   :ensure t
;;   :config (purpose/init))

;; (use-package ivy-purpose
;;   :ensure t
;;   :config (ivy-purpose-setup)
;;   :bind (("C-x b" . ivy-purpose-switch-buffer-with-purpose)))

;;; 01_window.el ends here
