(use-package epc
  :ensure t)

(use-package python-environment
  :ensure t)

(use-package pyvenv
  :ensure t)

(use-package anaconda-mode
  :ensure t
  :bind (:map python-mode-map
	      ("C-c C-d" . anaconda-mode-show-doc))
  :config (progn
	    (add-hook 'python-mode-hook 'anaconda-mode)))

(use-package company-anaconda
  :ensure t
  :config (progn
	    (add-to-list 'company-backends 'company-anaconda)))

(defun toracle-setup-python ()
  (setq indent-tabs-mode nil)
  (add-to-list 'grep-find-ignored-directories "build")
  )

(add-hook 'python-mode-hook 'toracle-setup-python)
