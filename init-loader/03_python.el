(add-hook 'python-mode-hook
	  (lambda ()
	    (setq indent-tabs-mode nil)
;	    (setq tab-width (default-value 'tab-width))
;	    (dtrt-indent-mode 1)
	    (flymake-mode -1)
	    (setq flycheck-pylintrc
		  (concat
		   (file-name-as-directory
		    (concat
		     user-emacs-directory "init-loader"))
		   "pylintrc"))
	    (flycheck-select-checker 'python-pylint)
	    (jedi:setup)
	    (setq jedi:setup-keys t)
	    (setq jedi:complete-on-dot t)
	    (setq elpy-mode t)
	    (elpy-enable)
	    (setq elpy-rpc-backend "jedi")
;	    (elpy-use-ipython)
	    )
	  )
