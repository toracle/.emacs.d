;;; 05_gui --- Gui related settings

;;; Code:

(defvar toracle--base-font-family "D2Coding")

(defvar toracle--base-font-size 14)

(add-to-list 'default-frame-alist (cons 'toracle--frame-font-size toracle--base-font-size))

(defun set-current-frame-parameter (key value)
  (set-frame-parameter (selected-frame) key value))

(defun get-current-frame-parameter (key)
  (frame-parameter (selected-frame) key))

(defun toracle--set-frame-font-size (size)
  (set-current-frame-parameter 'toracle--frame-font-size size))

(defun toracle--get-frame-font-size ()
  (get-current-frame-parameter 'toracle--frame-font-size))

(defun toracle--set-font (fontname size)
  (set-frame-font (format "%s:pixelsize=%d" fontname size) t)
  (set-fontset-font t
		    'unicode-bmp
		    (font-spec :family fontname :size size))
  (minibuffer-message (format "Set frame-font to: %s %s" fontname size)))

(defun toracle--set-base-font (fontname size)
  (setq toracle--base-font-family fontname)
  (setq toracle--base-font-size size)
  (toracle--set-font fontname size))

(defun toracle--increase-frame-font-size ()
  (interactive)
  (toracle--set-frame-font-size (+ (toracle--get-frame-font-size) 1))
  (toracle--set-font toracle--base-font-family (toracle--get-frame-font-size)))

(defun toracle--decrease-frame-font-size ()
  (interactive)
  (toracle--set-frame-font-size (- (toracle--get-frame-font-size) 1))
  (toracle--set-font toracle--base-font-family (toracle--get-frame-font-size)))

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
  (s-contains? "Microsoft" (get-string-from-file "/proc/version")))

(defun disable-double-buffering ()
  (setq default-frame-alist
         (append default-frame-alist '((inhibit-double-buffering . t)))))

(when (display-graphic-p)
  (tool-bar-mode -1)
  (scroll-bar-mode -1)
  (setq-default line-spacing 1)
  
  (when (eq system-type 'darwin)
    (setq mac-command-modifier 'meta)
    (setq mac-option-modifier 'super))

  (defvar toracle--frame-font-size toracle--base-font-size)

  (global-set-key (kbd "M-_") 'toracle--decrease-frame-font-size)
  (global-set-key (kbd "M-+") 'toracle--increase-frame-font-size)
  (global-set-key (kbd "C-M-_") 'toracle--decrease-line-spacing)
  (global-set-key (kbd "C-M-+") 'toracle--increase-line-spacing)
  
  (toracle--set-base-font "D2Coding" 14)

  (when (wsl-system?)
    (disable-double-buffering))

  ; A workaround of slow response on Emacs 26.1
  ; See https://debbugs.gnu.org/cgi/bugreport.cgi?bug=30995
  (when (s-starts-with? "GNU Emacs 26.1 " (version))
    (setq x-wait-for-event-timeout nil)))

;;; 05_gui.el ends here
