(require 'expand-region)
(global-set-key (kbd "M-2") 'er/expand-region)

(require 'multiple-cursors)
(global-set-key (kbd "C-c m .") 'mc/mark-next-like-this)
(global-set-key (kbd "C-c m ,") 'mc/mark-previous-like-this)
(global-set-key (kbd "C-c m a") 'mc/mark-all-like-this)
