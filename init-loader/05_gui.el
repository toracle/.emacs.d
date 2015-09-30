;;; 05_gui --- Gui related settings

;;; Code:

(when (display-graphic-p)
  (tool-bar-mode -1)
  (scroll-bar-mode -1)
  (setq-default line-spacing 4)
  
  (when (eq system-type 'darwin)
    (setq mac-command-modifier 'meta)
    (setq mac-option-modifier 'super))

  (set-fontset-font "fontset-standard"
		    'unicode-bmp
		    (font-spec :family "NanumGothicCoding" :size 14)))

;;; 05_gui.el ends here
