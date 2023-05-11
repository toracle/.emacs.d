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

;; (use-package flycheck-mypy
;;   :ensure t)

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
  (subword-mode +1)
  (pyvenv-mode t))

(defun python/init-flycheck ()
  "Setup flycheck."
  (flymake-mode -1)
  (flycheck-mode t)
  (require 'flycheck-ruff)
  (flycheck-select-checker 'python-ruff)
  (flycheck-add-next-checker 'python-ruff 'python-mypy))

(defun python/init-company ()
  "Setup company."
  (company-mode t))

(defun python/init-anaconda ()
  "Setup anaconda."
  (anaconda-mode t)
  (python/init-eldoc-mode))

(defun python/init-folding ()
  (hs-minor-mode t)
  (local-set-key (kbd "C-c C-;") 'hs-toggle-hiding))

(use-package pytest
  :ensure t
  :config (add-hook 'python-mode-hook
                    (lambda ()
                      (local-set-key (kbd "C-c t a") 'pytest-all)
                      (local-set-key (kbd "C-c t m") 'pytest-module)
                      (local-set-key (kbd "C-c t .") 'pytest-one)
                      (local-set-key (kbd "C-c t c") 'pytest-again)
                      (local-set-key (kbd "C-c t d") 'pytest-directory)
                      (local-set-key (kbd "C-c t p a") 'pytest-pdb-all)
                      (local-set-key (kbd "C-c t p m") 'pytest-pdb-module)
                      (local-set-key (kbd "C-c t p .") 'pytest-pdb-one))))

(use-package flycheck
  :ensure t
  :config (add-hook 'python-mode-hook 'python/init-flycheck))

(use-package company
  :ensure t
  :config (progn
            (add-hook 'python-mode-hook 'python/init-company)
            (add-hook 'lisp-mode-hook (lambda () (company-mode t)))))

(use-package anaconda-mode
  :ensure t
  :bind (:map anaconda-mode-map
	      ("C-c C-d" . anaconda-mode-show-doc)
	      ("M-?" . anaconda-mode-find-references))
  :config (add-hook 'python-mode-hook 'python/init-anaconda))

(use-package company-anaconda
  :ensure t
  :config (add-to-list 'company-backends 'company-anaconda))

;; (use-package pip-requirements
;;   :ensure t)

;; (use-package flycheck-pycheckers
;;   :ensure t
;;   :config (progn (add-hook 'flycheck-mode-hook #'flycheck-pycheckers-setup)
;;                  (setq flycheck-pycheckers-max-line-length 200)
;;                  (setq flycheck-pycheckers-checkers '(mypy3 python-ruff))))



(use-package python-docstring
  :ensure t
  :config (add-hook 'python-mode-hook (lambda () (python-docstring-mode t))))

(add-hook 'python-mode-hook 'python/init-grep-find)
(add-hook 'python-mode-hook 'python/init-indent)
(add-hook 'python-mode-hook 'python/init-imenu)
(add-hook 'python-mode-hook 'python/init-misc)
(add-hook 'python-mode-hook 'python/init-folding)

(use-package cov
  :ensure t
  :config (add-hook 'python-mode-hook (lambda ()
                                        (setq cov-coverage-mode t)
                                        (cov-mode t))))

(provide '14_python)

;;; 14_python.el ends here
