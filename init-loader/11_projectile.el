; (setq projectile-mode-line): A remedy for a slow issue
; https://github.com/bbatsov/projectile/issues/1183#issuecomment-335569547
(use-package projectile
  :ensure t
  :config (progn
            ;; (setq projectile-mode-line '(:eval (format " Projectile[%s]"
            ;;                                            (projectile-project-name))))
	    (projectile-global-mode)
            (define-key projectile-mode-map (kbd "C-c p") 'projectile-command-map)
	    (add-to-list 'projectile-project-root-files ".svn")
	    (add-to-list 'projectile-project-root-files ".git")
	    (add-to-list 'projectile-project-root-files ".projectile")
	    (add-to-list 'projectile-project-root-files "setup.py")
            (add-to-list 'projectile-globally-ignored-directories ".pytest_cache")
            (add-to-list 'projectile-globally-ignored-directories "htmlcov")
            (add-to-list 'projectile-globally-ignored-directories ".eggs")
            (add-to-list 'projectile-globally-ignored-directories ".mypy_cache")
            (add-to-list 'projectile-globally-ignored-directories "*.egg-info")
	    (setq projectile-completion-system 'helm)))
