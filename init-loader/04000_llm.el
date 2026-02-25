;;; begin

(use-package gptel
  :custom (gptel-curl-coding-system 'utf-8)
  :config (modify-coding-system-alist 'process "curl" 'utf-8)
  (setq gptel-include-reasoning nil
        gptel-default-mode 'org-mode)
  :ensure t)


(gptel-make-openai "OpenRouter"
  :host "openrouter.ai"
  :endpoint "/api/v1/chat/completions"
  :stream t
  :key 'gptel-api-key-from-auth-source
  :models '(openai/gpt-oss-120b))


(defun toracle-llm/list-buffers ()
  (buffer-list))


(gptel-make-tool
 :name "list-all-buffers"
 :function 'toracle-llm/list-buffers
 :description "list all open buffers in emacs, it can be used before calling other tools to understand and state of the system"
 :args '()
 :category "emacs")


(use-package gptel-agent
  :ensure t)


(if (not (windows-system?))
    (use-package vterm
      :ensure t)
  (use-package eat
    :ensure t))


(if (functionp 'use-package-vc-install)
    (eval
     '(use-package claude-code-ide
        :vc (:url "https://github.com/manzaltu/claude-code-ide.el" :branch "main")
        :bind (("C-c C-SPC" . claude-code-ide-menu))
        :config (claude-code-ide-emacs-tools-setup)))
  (defun claude-code-ide-menu ()
    (interactive)
    (message "claude-code-ide package not installed.")))


(defhydra hydra-llm (:hint t)
  "llm"
  ("c" claude-code-ide-menu "claude-code-ide")
  ("g" gptel "gptel")
  ("m" gptel-menu "gptel-menu")
  ("a" gptel-agent "gptel-agent"))

(global-set-key (kbd "C-c C-SPC") #'hydra-llm/body)

;;; ends
