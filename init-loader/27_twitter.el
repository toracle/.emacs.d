(use-package twittering-mode
  :ensure t
  :config (progn
            (add-hook 'twittering-mode-hook
                      (lambda ()
                        (setq twittering-timer-interval 300)
                        (setq twittering-icon-mode t)
                        (setq twittering-status-format "%RT{%FACE[bold]{RT}}%i %S,  %@:

 %T
// from %f%L%r%R%QT{
   +----
   %i %S,  %@:
   %T
   // from %f%L%r%R
   +----}

 ")
                        (local-set-key (kbd "s") 'twittering-favorite)))))
