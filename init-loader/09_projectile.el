(require 'projectile)
(projectile-global-mode)

(setq projectile-completion-system 'helm)
(helm-projectile-on)


;(setq projectile-switch-project-action 'neotree-projectile-action)

(add-to-list 'projectile-project-root-files ".svn")
(add-to-list 'projectile-project-root-files ".git")
(add-to-list 'projectile-project-root-files ".projectile")


(add-hook
 'projectile-mode-hook
 (lambda ()
   (local-set-key (kbd "C-c C-s") 'projectile-grep)))
