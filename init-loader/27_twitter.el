(use-package twittering-mode
  :ensure t
  :config (progn
            (add-hook 'twittering-mode-hook
                      (lambda ()
                        (setq twittering-timer-interval 300)
                        (local-set-key (kbd "s") 'twittering-favorite)))))
