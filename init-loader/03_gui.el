;;; 05_gui --- Gui related settings

;;; Code:

(defvar toracle--base-font-family "D2Coding")
(defvar toracle--base-han-font-family "D2Coding")
(defvar toracle--base-font-size 15)


(setq face-font-rescale-alist
      '(((font-spec :family "Noto Sans CJK KR Mono") . 1.0)
        ((font-spec :family "Noto Sans CJK Mono") . 1.0)
        ((font-spec :family "D2Coding") . 1.07)
        ("*" . 1.0)))


(add-to-list 'default-frame-alist
             (cons 'toracle--frame-font-size toracle--base-font-size))

(defun set-current-frame-parameter (key value)
  (set-frame-parameter (selected-frame) key value))

(defun get-current-frame-parameter (key)
  (frame-parameter (selected-frame) key))

(defun toracle--set-frame-font-size (size)
  (set-current-frame-parameter 'toracle--frame-font-size size))

(defun toracle--get-frame-font-size ()
  (or (get-current-frame-parameter 'toracle--frame-font-size)
      toracle--base-font-size))

(defun toracle--set-font (fontname han-fontname size)
  (set-face-attribute 'default nil
                      :family fontname :height (* 10 size))
  (set-fontset-font t 'hangul (font-spec :name han-fontname))
  (minibuffer-message (format "Set frame-font to: %s %s %s"
                              fontname han-fontname size)))

(defun toracle--set-base-font (fontname han-fontname size)
  (setq toracle--base-font-family fontname)
  (setq toracle--base-han-font-family han-fontname)
  (setq toracle--base-font-size size)
  (toracle--set-font fontname han-fontname size))

(defun toracle--increase-frame-font-size ()
  (interactive)
  (toracle--set-frame-font-size (+ (toracle--get-frame-font-size) 1))
  (toracle--set-font toracle--base-font-family
                     toracle--base-han-font-family
                     (toracle--get-frame-font-size)))

(defun toracle--decrease-frame-font-size ()
  (interactive)
  (toracle--set-frame-font-size (max (- (toracle--get-frame-font-size) 1) 10))
  (toracle--set-font toracle--base-font-family
                     toracle--base-han-font-family
                     (toracle--get-frame-font-size)))

(defun toracle--increase-line-spacing ()
  (interactive)
  (setq line-spacing (1+ line-spacing)))

(defun toracle--decrease-line-spacing ()
  (interactive)
  (setq line-spacing (1- line-spacing)))

(defun get-string-from-file (path)
  (with-temp-buffer
    (insert-file-contents path)
    (buffer-string)))

(defun wsl-system? ()
  (and (string-equal "gnu/linux" system-type)
       (s-contains? "Microsoft" (get-string-from-file "/proc/version"))))

(defun windows-system? ()
  (string-equal system-type "windows-nt"))

(defun mac-system? ()
  (string-equal system-type "darwin"))

(defun disable-double-buffering ()
  (setq default-frame-alist
         (append default-frame-alist '((inhibit-double-buffering . t)))))

(when (display-graphic-p)
  (tool-bar-mode -1)
  (scroll-bar-mode -1)
  (setq-default line-spacing 1)

  (when (mac-system?)
    ;; (setq mac-command-modifier 'meta)
    ;; (setq mac-option-modifier 'meta)

    ;; for glove80 + macos modifier change (ctrl->command, command->control)
    (setq mac-command-modifier 'control)
    (setq mac-option-modifier 'meta))

  (when (wsl-system?)
    (disable-double-buffering))

  (when (windows-system?)
    (setq w32-use-visible-system-caret nil))

  (defvar toracle--frame-font-size toracle--base-font-size)

  (global-set-key (kbd "M-_") 'toracle--decrease-frame-font-size)
  (global-set-key (kbd "M-+") 'toracle--increase-frame-font-size)
  (global-set-key (kbd "C-M-_") 'toracle--decrease-line-spacing)
  (global-set-key (kbd "C-M-+") 'toracle--increase-line-spacing)
  
  (toracle--set-base-font toracle--base-font-family
                          toracle--base-han-font-family
                          toracle--base-font-size)

  ; A workaround of slow response on Emacs 26.1
  ; See https://debbugs.gnu.org/cgi/bugreport.cgi?bug=30995
  (when (s-starts-with? "GNU Emacs 26.1 " (version))
    (setq x-wait-for-event-timeout nil)))

;; (toracle--set-font "Ubuntu Mono" "Noto Sans CJK KR Mono" 15)
;; (toracle--set-font "Ubuntu Mono" "D2Coding" 15)


;;; 05_gui.el ends here
