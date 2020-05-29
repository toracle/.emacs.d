(require 'ansi-color)
(defun ansi-colorize-buffer ()
  (toggle-read-only)
  (ansi-color-apply-on-region (point-min) (point-max))
  (toggle-read-only))
  
(add-hook 'compilation-filter-hook 'ansi-colorize-buffer)

(use-package feature-mode
  :ensure t
  :config (add-to-list 'auto-mode-alist '("\.feature$" . feature-mode)))
