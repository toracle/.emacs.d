(use-package go-mode
  :ensure t
  :config (progn
            (add-hook 'go-mode-hook (lambda () (setq tab-width 4)))
            (add-hook 'go-mode-hook 'eglot-ensure)))

;; need to install gopls
(unless (executable-find "gopls")
  (message "Need to install gopls: go install golang.org/x/tools/gopls@latest")
  (shell-command "go install golang.org/x/tools/gopls@latest"))
