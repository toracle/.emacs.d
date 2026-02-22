;;; 00_default.el

;;; Code:

(require 'seq)
(require 'cl-seq)

(set-language-environment "UTF-8")
(set-default-coding-systems 'utf-8)
(prefer-coding-system 'utf-8)

(tool-bar-mode -1)
(menu-bar-mode -1)
(scroll-bar-mode -1)
(column-number-mode t)
(xterm-mouse-mode t)

(setq save-abbrevs 'silently)
(setq inhibit-startup-screen t)
(setq dired-dwim-target t)
(setq backup-directory-alist `((".*" . ,temporary-file-directory)))
(setq auto-save-file-name-transforms `((".*" ,temporary-file-directory t)))

(setq default-input-method "korean-hangul390")
(setq default-korean-keyboard "3")

(setq-default indent-tabs-mode nil)

(global-set-key (kbd "C-x C-o") 'other-frame)

(use-package s
  :ensure t)

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

(unless (windows-system?)
 (let ((current-path (s-split ":" (getenv "PATH"))))
   (unless (cl-find "~/.local/bin" current-path :test 'string=)
     (setenv "PATH" (s-join ":" (cons "~/.local/bin" current-path))))))

;; (defun disable-double-buffering ()
;;   (setq default-frame-alist
;;         (append default-frame-alist '((inhibit-double-buffering . t)))))

(defun toracle/macos-glove80-keyboard-layout ()
  (interactive)
  (setq mac-command-modifier 'control)
  (setq mac-option-modifier 'meta)
  (setq mac-control-modifier 'super)
  (setq x-meta-keysym 'ctrl)
  (setq x-alt-keysym 'meta)
  (setq x-ctrl-keysym 'super)
  t)

(defun toracle/macos-internal-keyboard-layout ()
  (interactive)
  (setq mac-command-modifier 'meta)
  (setq mac-option-modifier 'super)
  (setq mac-control-modifier 'control)
  (setq x-meta-keysym nil)
  (setq x-alt-keysym nil)
  (setq x-ctrl-keysym nil)
  t)

(when (mac-system?)
  (setenv "LANG" "en_US.UTF-8")
  (when (file-exists-p "/usr/local/bin")
    (setenv "PATH" (concat (getenv "PATH") ":/usr/local/bin"))
    (add-to-list 'exec-path "/usr/local/bin")))

(when (or (mac-system?) (wsl-system?))
 (use-package exec-path-from-shell :ensure t
   :init (exec-path-from-shell-initialize)))

(defun init-loader-file-path (name)
  "Return a file path with NAME on init-loader directory."
  (concat (file-name-as-directory (concat user-emacs-directory "init-loader"))
	  name))

(use-package dashboard
  :ensure t
  :config (dashboard-setup-startup-hook))


;; (use-package ibuffer-vc
;;   :ensure t)

;; (use-package switch-window
;;   :ensure t)

;; (use-package visual-regexp-steroids
;;   :ensure t)

;; (use-package robe
;;   :ensure t)

;; (use-package ess
;;   :ensure t)

;; (use-package format-sql
;;   :ensure t)

;; (use-package xml-rpc
;;   :ensure t)

;; (use-package ledger-mode
;;   :ensure t)

;; (use-package ag
;;   :ensure t)

;; (defun spacemacs-ui-visual/compilation-buffer-apply-ansi-colors ()
;;   (let ((inhibit-read-only t))
;;     (read-only-mode 'toggle)
;;     (ansi-color-apply-on-region compilation-filter-start (point-max))
;;     (read-only-mode 'toggle)))

(defun create-new-scratch-buffer ()
  (interactive)
  (let ((buff (generate-new-buffer "*scratch*")))
    (set-buffer buff)
    (lisp-interaction-mode)
    (insert ";; This buffer is for text that is not saved, and for Lisp evaluation.\n")
    (insert ";; To create a file, visit it with C-x C-f and enter text in its buffer.\n")
    (insert "\n")
    (display-buffer buff)))

(global-set-key (kbd "C-x n RET") 'create-new-scratch-buffer)

;; (add-hook 'compilation-filter-hook 'spacemacs-ui-visual/compilation-buffer-apply-ansi-colors)
;; (add-hook 'shell-mode-hook 'ansi-color-for-comint-mode-on)
;; (add-to-list 'comint-output-filter-functions 'ansi-color-process-output)
;; (add-to-list 'Info-additional-directory-list (expand-file-name "~/texinfo"))

;; (add-hook 'yaml-mode-hook (lambda () (yafolding-mode t)))

;; ;; to prevent emacs crash when confronts emoji
;; ;; https://github.com/syl20bnr/spacemacs/issues/10695
;; (add-to-list 'face-ignored-fonts "Noto Color Emoji")

;; (setq epa-file-encrypt-to '("97F2043EC220D593"))

;; (use-package w3m
;;   :ensure t)

(provide '00_default)
;;; 00_default.el ends here
