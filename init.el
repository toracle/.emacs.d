
;; Added by Package.el.  This must come before configurations of
;; installed packages.  Don't delete this line.  If you don't want it,
;; just comment it out by adding a semicolon to the start of the line.
;; You may delete these explanatory comments.

(require 'package)
(setq package-enable-at-startup nil)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/"))
(add-to-list 'package-archives '("org" . "http://orgmode.org/elpa/"))

(package-initialize)

;; Bootstrap `use-package'
(unless (package-installed-p 'use-package)
  (package-refresh-contents)
  (package-install 'use-package))


;; (require 'cask "~/.cask/cask.el")
;; (cask-initialize)

(use-package init-loader
  :ensure t
  :config (init-loader-load (concat user-emacs-directory "init-loader")))

;; (require 'init-loader)
;; (init-loader-load (concat user-emacs-directory "init-loader"))

(setq custom-file "~/.emacs.d/custom.el")
(load custom-file 'noerror)

(add-to-list 'load-path "~/.emacs.d/modules/")
(put 'narrow-to-region 'disabled nil)
(put 'upcase-region 'disabled nil)
