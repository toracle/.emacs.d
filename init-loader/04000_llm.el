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
    (use-package ghostel
      :ensure t
      ;; Full redraws are more robust with Claude Code's aggressive partial
      ;; screen updates (per ghostel's own docs).
      :custom (ghostel-full-redraw t)
      :config
      ;; ghostel defers terminal redraws to a coalescing timer but never calls
      ;; `redisplay', so output arriving while Emacs is idle (e.g. a Claude
      ;; session printing in a non-selected/preview window) updates the buffer
      ;; yet does not repaint the window until the next keystroke.  Force a
      ;; redisplay after each deferred redraw to close that gap.
      (defun my/ghostel--redraw-redisplay (&rest _)
        (redisplay))
      (advice-add 'ghostel--redraw-now :after #'my/ghostel--redraw-redisplay))
  (use-package eat
    :ensure t))


(if (functionp 'use-package-vc-install)
    (eval
     '(use-package claude-code-ide
        :vc (:url "https://github.com/manzaltu/claude-code-ide.el" :branch "main" :rev :newest)
        :bind (("C-c C-SPC" . claude-code-ide-menu))
        :config (claude-code-ide-emacs-tools-setup) (setq claude-code-ide-terminal-backend 'ghostel)))
  (defun claude-code-ide-menu ()
    (interactive)
    (message "claude-code-ide package not installed.")))


;; Resolve the Claude CLI to an absolute, tilde-free path.
;; The ghostel backend spawns the program directly via execvp (no shell),
;; so a literal "~/..." is never expanded and the process dies instantly,
;; surfacing as a bare "Invalid buffer" error.  Detect across environments
;; (Linux, WSL, macOS, native Windows): prefer a PATH lookup, then fall back
;; to known install locations.  Leave the default untouched when none exist.
(let ((claude-bin
       (or (executable-find "claude")
           (seq-find #'file-executable-p
                     (mapcar #'expand-file-name
                             '("~/.local/bin/claude"
                               "~/.claude/local/claude"
                               "/opt/homebrew/bin/claude"
                               "/usr/local/bin/claude"))))))
  (when claude-bin
    (setq claude-code-ide-cli-path claude-bin)))


(defhydra hydra-llm (:hint t)
  "llm"
  ("c" claude-code-ide-menu "claude-code-ide")
  ("s" my/ccsm "cc-sessions")
  ("t" my/ccsm-new-topic "cc-new-topic")
  ("g" gptel "gptel")
  ("m" gptel-menu "gptel-menu")
  ("a" gptel-agent "gptel-agent")
  ("b" gptel-abort "gptel-abort"))

(global-set-key (kbd "C-c C-SPC") #'hydra-llm/body)

;;; ends
