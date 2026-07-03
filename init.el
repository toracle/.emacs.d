
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
(unless (or (package-installed-p 'use-package) (fboundp 'use-package))
  (package-refresh-contents)
  (package-install 'use-package))


;; (require 'cask "~/.cask/cask.el")
;; (cask-initialize)

(use-package init-loader
  :ensure t
  :config (init-loader-load (concat user-emacs-directory "init-loader")))

(setq custom-file "~/.emacs.d/custom.el")
(load custom-file 'noerror)

;; Customize keeps re-saving claude-code-ide-cli-path with a literal "~".
;; The ghostel backend spawns via execvp (no shell), so a literal tilde is
;; never expanded -> claude exits instantly -> "Invalid buffer".  Normalize
;; any tilde path after custom.el loads (custom.el loads after init-loader,
;; so this must live here to win).  Bare commands (PATH lookup) are left alone.
(when (and (boundp 'claude-code-ide-cli-path)
           (stringp claude-code-ide-cli-path)
           (string-prefix-p "~" claude-code-ide-cli-path))
  (setq claude-code-ide-cli-path (expand-file-name claude-code-ide-cli-path)))

(add-to-list 'load-path "~/.emacs.d/modules/")

;; cc-butler: Claude Code session manager + butler control plane.
;; A standalone package/repo at ~/projects/cc-butler (extracted from the old
;; init-loader/32_* "CCSM" drop-ins); loaded here rather than via init-loader.
(add-to-list 'load-path (expand-file-name "~/projects/cc-butler"))
(require 'cc-butler)

(put 'narrow-to-region 'disabled nil)
(put 'upcase-region 'disabled nil)
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(package-vc-selected-packages
   '((moinrpc-mode :url "https://github.com/toracle/moinrpc-mode" :branch
                   "devel"))))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
