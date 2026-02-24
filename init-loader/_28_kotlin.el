(use-package kotlin-mode
  :ensure t
  :config (progn
            (add-hook 'kotlin-mode-hook (lambda () (subword-mode t)))
            (add-hook 'kotlin-mode-hook 'eglot-ensure)) )

;; need to install and integrate kotlin-language-server
