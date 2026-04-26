;;; begin

;; ---- gptel daemon void-variable guard ----
(defvar gptel--tool-preview-alist nil)

(use-package gptel
  :ensure t
  :demand t
  :custom (gptel-curl-coding-system 'utf-8)
  :config (modify-coding-system-alist 'process "curl" 'utf-8)
  (setq gptel-include-reasoning nil
        gptel-default-mode 'org-mode)
  (require 'gptel-transient))


(gptel-make-openai "OpenRouter"
  :host "openrouter.ai"
  :endpoint "/api/v1/chat/completions"
  :stream t
  :key 'gptel-api-key-from-auth-source
  :models '(openai/gpt-oss-120b google/gemma-3-27b-it google/gemini-3-flash-preview upstage/solar-pro-3 qwen/qwen3.5-35b-a3b qwen/qwen3.5-122b-a10b qwen/qwen3.5-397b-a17b qwen/qwen3-coder-next))


;; (defun toracle-llm/list-buffers ()
;;   (buffer-list))


;; (gptel-make-tool
;;  :name "list-all-buffers"
;;  :function 'toracle-llm/list-buffers
;;  :description "list all open buffers in emacs, it can be used before calling other tools to understand and state of the system"
;;  :args '()
;;  :category "emacs")


;; (defun toracle-llm/get-buffer-content (buffer-name)
;;   "Return a plist (:status STRING :content STRING) for buffer BUFFER-NAME.
;; Never switches to the buffer or modifies it."
;;   (let ((buf (get-buffer buffer-name)))
;;     (if (not buf)
;;         (list :status "error" :message (format "No such buffer: %s" buffer-name))
;;       (with-current-buffer buf
;;         (list :status "ok"
;;               :content (buffer-substring-no-properties (point-min) (point-max)))))))
    
;; (gptel-make-tool
;;  :name "get-buffer-content"
;;  :description "Read the entire text of a specified buffer without side‑effects."
;;  :parameters '(("buffer-name" string "Name of the buffer to read"))
;;  :function #'toracle-llm/get-buffer-content
;;  :args '((:name "buffer-name" :type string))
;;  :category "emacs")


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
  ("a" gptel-agent "gptel-agent")
  ("b" gptel-abort "gptel-abort"))

(global-set-key (kbd "C-c C-SPC") #'hydra-llm/body)

;;; ends
