;;; 00_default.el

;;; Code:

(prefer-coding-system 'utf-8)

(tool-bar-mode -1)
(scroll-bar-mode -1)
(menu-bar-mode -1)
(column-number-mode t)
(xterm-mouse-mode t)

(add-hook 'after-init-hook #'global-flycheck-mode)

(require 'smart-mode-line)
(setq sml/no-confirm-load-theme t)
(sml/setup)
(sml/apply-theme 'powerline)
(ample-theme)

(global-page-break-lines-mode t)
(setq inhibit-startup-screen t)

(global-set-key (kbd "C-x C-o") 'other-frame)

(when (eq system-type 'darwin)
  (add-to-list 'exec-path "/usr/local/bin"))

(setq dired-dwim-target t)

(setq backup-directory-alist
      `((".*" . ,temporary-file-directory)))
(setq auto-save-file-name-transforms
      `((".*" ,temporary-file-directory t)))

(when (eq system-type 'darwin)
  (setenv "PATH" (concat (getenv "PATH") ":/usr/local/bin"))
  (setenv "LANG" "ko_KR.UTF-8"))

(setq default-input-method "korean-hangul")
(global-set-key (kbd "S-SPC") 'toggle-input-method)

(require 'zoom-window)
(global-set-key (kbd "C-x C-z") 'zoom-window-zoom)

(provide '00_default)
;;; 00_default.el ends here
