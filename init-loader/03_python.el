(add-hook
 'python-mode-hook
 (lambda ()
   (setq indent-tabs-mode nil)
   (flymake-mode -1)
   (setq flycheck-pylintrc
	 (concat
	  (file-name-as-directory
	   (concat user-emacs-directory "init-loader"))
	  "pylintrc"))
   (flycheck-select-checker 'python-pylint)
   (jedi:setup)
   (company-mode)
   (add-to-list 'company-backends 'company-jedi)
   (setq jedi:setup-keys t)
   (setq jedi:complete-on-dot t)
   (setq jedi:tooltip-method t)
   (local-set-key (kbd "M-.") 'jedi:goto-definition)
   (local-set-key (kbd "M-*") 'jedi:goto-definition-pop-marker)
   )
 )
