(require 'ansi-color)
(defun ansi-colorize-buffer ()
  (toggle-read-only)
  (ansi-color-apply-on-region (point-min) (point-max))
  (toggle-read-only))
  
(add-hook 'compilation-filter-hook 'ansi-colorize-buffer)
