(use-package chatgpt-shell
  :ensure t
  :config (progn
            (setq chatgpt-shell-openai-key
                  (lambda () (auth-source-pick-first-password :host "api.openai.com")))))
