;;; 05_gui --- Gui related settings

;;; Code:

(defun toracle-set-default-font (fontname size)
  (setq toracle-default-font-family fontname)
  (setq toracle-default-font-size size)
  (set-frame-font (format "%s:pixelsize=%d" fontname size) t)
  (set-fontset-font t
		    'unicode-bmp
		    (font-spec :family fontname :size size)))

(defun toracle-increase-font-size ()
  (interactive)
  (setq toracle-default-font-size (+ toracle-default-font-size 2))
  (toracle-set-default-font toracle-default-font-family toracle-default-font-size))

(defun toracle-decrease-font-size ()
  (interactive)
  (setq toracle-default-font-size (- toracle-default-font-size 2))
  (toracle-set-default-font toracle-default-font-family toracle-default-font-size))

(when (display-graphic-p)
  (tool-bar-mode -1)
  (scroll-bar-mode -1)
  (setq-default line-spacing 4)
  
  (when (eq system-type 'darwin)
    (setq mac-command-modifier 'meta)
    (setq mac-option-modifier 'super))

  (defvar toracle-default-font-size 14)
  (defvar toracle-default-font-family "D2Coding")

  (global-set-key (kbd "M-_") 'toracle-decrease-font-size)
  (global-set-key (kbd "M-+") 'toracle-increase-font-size)
  
  (toracle-set-default-font "D2Coding" 14))

;;; 05_gui.el ends here
