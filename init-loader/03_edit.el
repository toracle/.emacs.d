(use-package expand-region
  :ensure t
  :bind (("M-2" . er/expand-region)))


(use-package multiple-cursors
  :ensure t
  :bind (("C-c m ." . mc/mark-next-like-this)
	 ("C-c m ," . mc/mark-previous-like-this)
	 ("C-c m a" . mc/mark-all-like-this)))


(use-package yasnippet
  :ensure t
  :config (progn
	    (setq yas-snippet-dirs (list (concat user-emacs-directory "snippets")))
            (yas--load-snippet-dirs)
	    (yas-global-mode 1)))
