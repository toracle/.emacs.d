;; Windmove

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

(global-set-key (kbd "C-x o") 'switch-window)

;;; 01_windmove.el ends here
