(require 'projectile)
(projectile-global-mode)

(progn
   (helm-projectile-on)
   (add-to-list 'projectile-project-root-files ".svn")
   (add-to-list 'projectile-project-root-files ".git")
   (add-to-list 'projectile-project-root-files ".projectile")
   (setq projectile-completion-system 'helm)
   (local-set-key (kbd "C-c C-s") 'projectile-grep))
