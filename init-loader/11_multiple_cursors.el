(require 'expand-region)
(global-set-key (kbd "M-2") 'er/expand-region)

(require 'multiple-cursors)
(global-set-key (kbd "C-c C-m C-.") 'mc/mark-next-like-this)
(global-set-key (kbd "C-c C-m C-,") 'mc/mark-previous-like-this)
(global-set-key (kbd "C-c C-m C-a") 'mc/mark-all-like-this)
