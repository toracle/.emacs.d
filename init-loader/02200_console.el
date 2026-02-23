;;; 06_console.el

;;; Code:

(when (not (display-graphic-p))
  (define-key input-decode-map "\e\eOA" [S-up])
  (define-key input-decode-map "\e\eOB" [S-down])
  (define-key input-decode-map "\e\eOC" [S-right])
  (define-key input-decode-map "\e\eOD" [S-left])

  (define-key input-decode-map "\e[1;9A" [M-up])
  (define-key input-decode-map "\e[1;9B" [M-down])
  (define-key input-decode-map "\e[1;9C" [M-right])
  (define-key input-decode-map "\e[1;9D" [M-left]))

;;; 06_console.el ends here
