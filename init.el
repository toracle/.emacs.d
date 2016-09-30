
;; Added by Package.el.  This must come before configurations of
;; installed packages.  Don't delete this line.  If you don't want it,
;; just comment it out by adding a semicolon to the start of the line.
;; You may delete these explanatory comments.

(require 'package)
(setq package-enable-at-startup nil)
(add-to-list 'package-archives
             '("melpa" . "https://melpa.org/packages/"))

(package-initialize)

;; Bootstrap `use-package'
(unless (package-installed-p 'use-package)
  (package-refresh-contents)
  (package-install 'use-package))


;; (require 'cask "~/.cask/cask.el")
;; (cask-initialize)

(use-package init-loader
  :init (init-loader-load (concat user-emacs-directory "init-loader")))

;; (require 'init-loader)
;; (init-loader-load (concat user-emacs-directory "init-loader"))

(setq custom-file "~/.emacs.d/custom.el")
(load custom-file 'noerror)

(add-to-list 'load-path "~/.emacs.d/modules/")
(put 'narrow-to-region 'disabled nil)
