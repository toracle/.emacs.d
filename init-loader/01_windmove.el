;; Windmove

(if (display-graphic-p)
    nil
  (progn
    (define-key input-decode-map "\e\eOA" [S-up])
    (define-key input-decode-map "\e\eOB" [S-down])
    (define-key input-decode-map "\e\eOC" [S-right])
    (define-key input-decode-map "\e\eOD" [S-left])))

(when (fboundp 'windmove-default-keybindings)
  (if (display-graphic-p)
      (windmove-default-keybindings 'meta)
      (windmove-default-keybindings)))

(global-set-key (kbd "C-c <left>")  'windmove-left)
(global-set-key (kbd "C-c <right>") 'windmove-right)
(global-set-key (kbd "C-c <up>")    'windmove-up)
(global-set-key (kbd "C-c <down>")  'windmove-down)
