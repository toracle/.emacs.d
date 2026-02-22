(use-package yasnippet
  :ensure t
  :config (progn
	    (setq yas-snippet-dirs (list (concat user-emacs-directory "snippets")))
            (yas--load-snippet-dirs)
	    (yas-global-mode 1)))

