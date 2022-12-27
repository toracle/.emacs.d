(use-package kotlin-mode
  :ensure t
  :config (add-hook 'kotlin-mode-hook
                    (lambda ()
                      (subword-mode t))))

(require 'lsp-mode)
(add-hook 'kotlin-mode-hook #'lsp)
