;;; package --- javascript configuration
;;;
;;; Commentary:
;;; javascript configuration
;;;
;;; Code:

(use-package js2-mode
  :ensure t
  :config (progn
	    (add-to-list 'auto-mode-alist '("\\.js\\'" . js2-mode))
	    (add-hook 'js2-mode-hook '(flycheck-select-checker javascript-eslint))
	    (add-hook 'js2-mode-hook (lambda ()
				       (setq flycheck-
					     (concat (file-name-as-directory (concat user-emacs-directory "init-loader"))
						     "eslintrc"))))))

(use-package tern
  :ensure t
  :config (add-hook 'js2-mode-hook 'tern-mode))

(use-package company-tern
  :ensure t
  :config (progn
	    (add-to-list 'company-backends 'company-tern)
	    (add-hook 'js2-mode-hook '(company-mode t))))

(provide '21_javascript)
;;; 21_javascript.el ends here
