(use-package kotlin-mode
  :ensure t)

(require 'lsp-mode)
(add-hook 'kotlin-mode-hook #'lsp)
