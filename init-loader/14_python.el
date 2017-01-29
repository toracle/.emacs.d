;;; 14_python.el --- python.el configuration
;;;
;;; Commentary:
;;; 
;;; Code:

(use-package epc
  :ensure t)

(use-package python-environment
  :ensure t)

(use-package pyvenv
  :ensure t)

(defun python/init-eldoc-mode ()
  "Setup eldoc."
  (eldoc-mode)
  (anaconda-eldoc-mode))

(defun python/init-grep-find ()
  "Setup grep find."
  (add-to-list 'grep-find-ignored-directories "build"))

(defun python/init-indent ()
  "Setup indentation."
  (setq indent-tabs-mode nil))

(defun python/init-imenu ()
  "Setup imenu."
  (when (fboundp #'python-imenu-create-flat-index)
    (setq-local imenu-create-index-function
		#'python-imenu-create-flat-index)))

(defun python/init-misc ()
  "Setup misc stuffs."
  (subword-mode +1))

(use-package anaconda-mode
  :ensure t
  :bind (:map anaconda-mode-map
	      ("C-c C-d" . anaconda-mode-show-doc)
	      ("M-?" . anaconda-mode-find-references))
  :config (progn
	    (add-hook 'python-mode-hook 'anaconda-mode)
	    (add-hook 'python-mode-hook 'python/init-eldoc-mode)))

(use-package company-anaconda
  :ensure t
  :config (progn
	    (add-to-list 'company-backends 'company-anaconda)))

(use-package pip-requirements
  :ensure t)


(add-hook 'python-mode-hook 'python/init-grep-find)
(add-hook 'python-mode-hook 'python/init-indent)
(add-hook 'python-mode-hook 'python/init-imenu)
(add-hook 'python-mode-hook 'python/init-misc)

(provide '14_python)

;;; 14_python.el ends here
