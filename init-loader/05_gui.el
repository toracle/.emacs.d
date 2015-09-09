(if (display-graphic-p)
    (let
	((fontname "NanumGothicCoding")
	 (charset 'unicode-bmp)
	 (fontset "fontset-default"))
      (progn
	(tool-bar-mode -1)
	(scroll-bar-mode -1)
	(setq-default line-spacing 4)
	(set-fontset-font (frame-parameter nil 'font) charset
			  (font-spec :family fontname :size 14)))

      (when (eq system-type 'windows-nt)
	(set-face-font 'default fontname))

      (when (eq system-type 'darwin)
	(setq mac-command-modifier 'meta)
	(setq mac-right-option-modifier 'control))))
