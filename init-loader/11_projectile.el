(use-package projectile
  :ensure t
  :config (progn
	    (add-to-list 'projectile-project-root-files ".svn")
	    (add-to-list 'projectile-project-root-files ".git")
	    (add-to-list 'projectile-project-root-files ".projectile")
	    (setq projectile-completion-system 'helm))
  :bind (("C-c C-s" . projectile-grep)))
