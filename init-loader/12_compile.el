(require 'ansi-color)
(defun ansi-colorize-buffer ()
  (read-only-mode 'toggle)
  (ansi-color-apply-on-region (point-min) (point-max))
  (read-only-mode 'toggle))
  
(add-hook 'compilation-filter-hook 'ansi-colorize-buffer)

(use-package feature-mode
  :ensure t
  :config (add-to-list 'auto-mode-alist '("\.feature$" . feature-mode)))
