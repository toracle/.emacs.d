(use-package projectile
  :ensure t
  :config (progn
	    (projectile-global-mode)
	    (add-to-list 'projectile-project-root-files ".svn")
	    (add-to-list 'projectile-project-root-files ".git")
	    (add-to-list 'projectile-project-root-files ".projectile")
	    (add-to-list 'projectile-project-root-files "setup.py")
	    (setq projectile-completion-system 'helm)))
