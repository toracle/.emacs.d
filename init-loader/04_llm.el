;;; begin

(when (functionp 'use-package-vc-install)
  (use-package claude-code-ide
    :vc (:url "https://github.com/manzaltu/claude-code-ide.el" :branch "main")
    :bind (("C-c C-SPC" . claude-code-ide-menu))
    :config (claude-code-ide-emacs-tools-setup)))


(use-package gptel
  :custom (gptel-curl-coding-system 'utf-8)
  :config (modify-coding-system-alist 'process "curl" 'utf-8)
  ;;      (setq gptel-use-curl nil)
  :ensure t)


(use-package gptel-agent
  :ensure t)


(if (not (windows-system?))
    (use-package vterm
      :ensure t)
  (use-package eat
    :ensure t)


(defun toracle-llm/list-buffers ()
  (apply 'concat (mapcar (lambda (buffer) (concat (buffer-name buffer) "\n"))
                         (buffer-list))))


(defun toracle-llm/list-buffers ()
  (buffer-list))


(gptel-make-tool
 :name "list-all-buffers"
 :function 'toracle-llm/list-buffers
 :description "list all open buffers in emacs, it can be used before calling other tools to understand and state of the system"
 :args '()
 :category "emacs")

;;; ends
