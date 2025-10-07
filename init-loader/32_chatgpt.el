(use-package chatgpt-shell
  :ensure t
  :custom
  ((chatgpt-shell-openai-key
    (lambda ()
      (auth-source-pick-first-password :host "api.openai.com")))))


(when (functionp 'use-package-vc-install)
  (use-package claude-code-ide
    :vc (:url "https://github.com/manzaltu/claude-code-ide.el" :branch "main")
    :bind (("C-c C-SPC" . claude-code-ide-menu))
    :config (claude-code-ide-emacs-tools-setup)))


(use-package gptel
  :ensure t)

