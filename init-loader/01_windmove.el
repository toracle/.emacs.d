;; Windmove                                                                                                                                      

(define-key input-decode-map "\e\eOA" [S-up])
(define-key input-decode-map "\e\eOB" [S-down])
(define-key input-decode-map "\e\eOC" [S-right])
(define-key input-decode-map "\e\eOD" [S-left])

(when (fboundp 'windmove-default-keybindings)
  (windmove-default-keybindings))

(global-set-key (kbd "C-c <left>")  'windmove-left)
(global-set-key (kbd "C-c <right>") 'windmove-right)
(global-set-key (kbd "C-c <up>")    'windmove-up)
(global-set-key (kbd "C-c <down>")  'windmove-down)
