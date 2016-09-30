(use-package helm
  :ensure t
  :init (global-unset-key (kbd "C-x c"))
  :config (progn
	    (setq helm-split-window-in-side-p t
		  helm-move-to-line-cycle-in-source t
		  helm-ff-search-library-in-sexp t
		  helm-scroll-amout 8
		  helm-ff-file-name-history-use-recentf t
		  helm-M-x-fuzzy-match t
		  helm-buffers-fuzzy-matching t
		  helm-recentf-fuzzy-match t)
	    (helm-mode t)
	    (helm-autoresize-mode 1))
  :bind (("C-c h" . helm-command-prefix)
	 ("M-x" . helm-M-x)
	 ("M-y" . helm-show-kill-ring)
	 ("C-x b" . helm-mini)))

(use-package helm-projectile
  :ensure t)

(use-package flx-ido
  :ensure t
  :bind (("C-x C-f" . ido-find-file)))
