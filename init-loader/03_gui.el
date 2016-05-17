;;; 05_gui --- Gui related settings

;;; Code:

(defun my-set-default-font (fontname size)
  (set-frame-font (format "%s:pixelsize=%d" fontname size) t)
  (set-fontset-font t
		    'unicode-bmp
		    (font-spec :family fontname :size size)))


(when (display-graphic-p)
  (tool-bar-mode -1)
  (scroll-bar-mode -1)
  (setq-default line-spacing 4)
  
  (when (eq system-type 'darwin)
    (setq mac-command-modifier 'meta)
    (setq mac-option-modifier 'super))

  (my-set-default-font "D2Coding" 14))

;;; 05_gui.el ends here
