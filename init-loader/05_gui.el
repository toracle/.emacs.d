(if (display-graphic-p)
    (let
	((fontname "NanumGothicCoding")
	 (charset 'unicode-bmp)
	 (fontset "fontset-default"))
      (progn
	(tool-bar-mode -1)
	(scroll-bar-mode -1)
	(setq-default line-spacing 4)
	)

      (when (eq system-type 'windows-nt)
	(set-face-font 'default fontname)
	(set-fontset-font fontset 'hangul '(fontname . charset))
	(set-face-attribute 'default nil :font fontset :height 105)
	)

      (when (eq system-type 'darwin)
	(setq mac-command-modifier 'meta)
	(setq mac-right-option-modifier 'control)
	
;	(set-frame-font (format "%s:pixelsize=%d" fontname 14) t)
	(set-fontset-font (frame-parameter nil 'font) charset
			  (font-spec :family fontname :size 14))
	)
      ))
