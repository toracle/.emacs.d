(require 'expand-region)
(global-set-key (kbd "C-@") 'er/expand-region)

(require 'multiple-cursors)
(global-set-key (kbd "C-c .") 'mc/mark-next-like-this)
(global-set-key (kbd "C-c ,") 'mc/mark-previous-like-this)
(global-set-key (kbd "C-c >") 'mc/mark-all-like-this)
