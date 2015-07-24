(add-hook 'python-mode-hook
	  (lambda ()
	    (setq indent-tabs-mode nil)
	    (flymake-mode -1)
	    (setq flycheck-pylintrc
		  (concat
		   (file-name-as-directory
		    (concat
		     user-emacs-directory "init-loader"))
		   "pylintrc"))
	    (flycheck-select-checker 'python-pylint)
	    (jedi:setup)
	    (add-to-list 'company-backends 'company-jedi)
	    (setq jedi:setup-keys t)
	    (setq jedi:complete-on-dot t)
	    (setq elpy-mode t)
	    (elpy-enable)
	    (setq elpy-rpc-backend "jedi")
;	    (company-mode -1)
	    (setq jedi:tooltip-method nil)
	    )
	  )
