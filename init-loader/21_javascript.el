;;; package --- javascript configuration
;;;
;;; Commentary:
;;; javascript configuration
;;;
;;; Code:

(defun js/init-flycheck ()
  "Setup flycheck."
  (flymake-mode -1)
  (flycheck-mode t)
  (defvar flycheck-eslintrc (init-loader-file-path "eslintrc.js"))
  (flycheck-select-checker 'javascript-eslint))

(defun js/init-company ()
  "Setup company."
  (company-mode t))

(defun js/init-js2 ()
  (add-to-list 'auto-mode-alist '("\\.js\\'" . js2-mode))
  (add-hook 'js2-mode-hook '(flycheck-select-checker javascript-eslint))
  (setq js2-basic-offset 2)
  (setq indent-tabs-mode nil)
  (setq js2-strict-missing-semi-warning nil))

(use-package flycheck
  :ensure t
  :config (add-hook 'js2-mode-hook 'js/init-flycheck))

(use-package company
  :ensure t
  :config (add-hook 'js2-mode-hook 'js/init-company))

(use-package js2-mode
  :ensure t
  :config (js/init-js2))

(use-package tern
  :ensure t
  :config (add-hook 'js2-mode-hook 'tern-mode))

(use-package company-tern
  :ensure t
  :config (add-to-list 'company-backends 'company-tern))

(provide '21_javascript)
;;; 21_javascript.el ends here
