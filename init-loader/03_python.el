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
   (when (not (null pyvenv-virtual-env))
     (setq flycheck-python-pylint-executable (concat pyvenv-virtual-env "bin/pylint")))
   (flycheck-select-checker 'python-pylint)
   (jedi:setup)
   (company-mode t)
   (add-to-list 'company-backends 'company-jedi)
   (setq jedi:complete-on-dot t)
   (local-set-key (kbd "M-.") 'jedi:goto-definition)
   (local-set-key (kbd "M-*") 'jedi:goto-definition-pop-marker)
   (local-set-key (kbd "C-c C-d") 'jedi:show-doc)
   ))
