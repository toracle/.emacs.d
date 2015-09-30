(require 'cask "~/.cask/cask.el")
(cask-initialize)

(require 'init-loader)
(init-loader-load (concat user-emacs-directory "init-loader"))

(setq custom-file "~/.emacs.d/custom.el")
(load custom-file)
