(require 'expand-region)
(global-set-key (kbd "C-c C-m 2") 'er/expand-region)

(require 'multiple-cursors)
(global-set-key (kbd "C-c C-m .") 'mc/mark-next-like-this)
(global-set-key (kbd "C-c C-m ,") 'mc/mark-previous-like-this)
(global-set-key (kbd "C-c C-m a") 'mc/mark-all-like-this)
