(use-package projectile
  :ensure t
  :config (progn
	    (add-to-list 'projectile-project-root-files ".svn")
	    (add-to-list 'projectile-project-root-files ".git")
	    (add-to-list 'projectile-project-root-files ".projectile")
	    (setq projectile-completion-system 'helm)
	    (add-hook 'python-mode-hook (lambda () (projectile-mode t))))
  :bind (("C-c C-s" . projectile-grep)))
