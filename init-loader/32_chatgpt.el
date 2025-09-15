(use-package chatgpt-shell
  :ensure t
  :custom
  ((chatgpt-shell-openai-key
    (lambda ()
      (auth-source-pick-first-password :host "api.openai.com")))))


(use-package claude-code-ide
    :ensure t
    :bind (("C-c C-SPC" . claude-code-ide-menu))
    :config (claude-code-ide-emacs-tools-setup))
