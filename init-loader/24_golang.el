(use-package go-mode
  :ensure t
  :config (add-hook 'go-mode-hook
                    (lambda ()
                      (setq tab-width 4))))


(use-package lsp-mode
  :init
  ;; set prefix for lsp-command-keymap (few alternatives - "C-l", "C-c l")
  (setq lsp-keymap-prefix "C-c l")
  :hook (;; replace XXX-mode with concrete major-mode(e. g. python-mode)
         (go-mode . lsp)
         ;; if you want which-key integration
         )
  :commands lsp)
