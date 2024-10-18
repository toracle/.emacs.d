;;; 14_python.el --- python.el configuration
;;;
;;; Commentary:
;;; 
;;; Code:

(add-to-list 'major-mode-remap-alist '(python-mode . python-ts-mode))

(use-package python-environment
  :ensure t)

(use-package python-docstring
  :ensure t
  :config (add-hook 'python-ts-mode-hook (lambda () (python-docstring-mode t))))

(use-package pyvenv
  :ensure t)

(use-package pytest
  :ensure t
  :config (add-hook 'python-ts-mode-hook
                    (lambda ()
                      (local-set-key (kbd "C-c t a") 'pytest-all)
                      (local-set-key (kbd "C-c t m") 'pytest-module)
                      (local-set-key (kbd "C-c t .") 'pytest-one)
                      (local-set-key (kbd "C-c t c") 'pytest-again)
                      (local-set-key (kbd "C-c t d") 'pytest-directory)
                      (local-set-key (kbd "C-c t p a") 'pytest-pdb-all)
                      (local-set-key (kbd "C-c t p m") 'pytest-pdb-module)
                      (local-set-key (kbd "C-c t p .") 'pytest-pdb-one))))

(use-package cov
  :ensure t
  :config (add-hook 'python-ts-mode-hook (lambda ()
                                           (setq cov-coverage-mode t)
                                           (cov-mode t))))

(use-package flycheck-pycheckers
  :ensure t
  :config (progn (add-hook 'flycheck-mode-hook #'flycheck-pycheckers-setup)
                 (setq flycheck-pycheckers-max-line-length 200
                       flycheck-pycheckers-checkers '(mypy3 python-ruff))))

(defun python/init-eldoc-mode ()
  "Setup eldoc."
  (eldoc-mode))

(defun python/init-grep-find ()
  "Setup grep find."
  (add-to-list 'grep-find-ignored-directories "build"))

(defun python/init-indent ()
  "Setup indentation."
  (setq indent-tabs-mode nil))

(defun python/init-imenu ()
  "Setup imenu."
  (when (fboundp #'python-imenu-create-flat-index)
    (setq-local imenu-create-index-function #'python-imenu-create-flat-index)))

(defun python/init-misc ()
  "Setup misc stuffs."
  (local-set-key (kbd "C-c x r") 'eglot-rename)
  (subword-mode +1)
  (pyvenv-mode t))

(defun python/init-flycheck ()
  "Setup flycheck."
  (flymake-mode -1)
  (flycheck-mode t)
  (require 'flycheck-ruff)
  (flycheck-select-checker 'python-ruff)
  (flycheck-add-next-checker 'python-ruff 'python-mypy))

(defun python/init-folding ()
  (hs-minor-mode t)
  (local-set-key (kbd "C-c C-;") 'hs-toggle-hiding))

(defun python/install-lsp-server ()
  "Install pylsp server"
  (unless (executable-find "pylsp")
    (message "Installing python-lsp-server")
    (shell-command "pip install python-lsp-server\\[all\\]")))


(python/install-lsp-server)

(add-hook 'python-ts-mode-hook 'eglot-ensure)
(add-hook 'python-ts-mode-hook 'python/init-eldoc-mode)
(add-hook 'python-ts-mode-hook 'python/init-grep-find)
(add-hook 'python-ts-mode-hook 'python/init-indent)
(add-hook 'python-ts-mode-hook 'python/init-imenu)
(add-hook 'python-ts-mode-hook 'python/init-misc)
(add-hook 'python-ts-mode-hook 'python/init-flycheck)
(add-hook 'python-ts-mode-hook 'python/init-folding)

;; replaced company with corfu+cape
;; replaced anaconda-mode with pylsp+eglot

;; Refer to
;; [Emacs, Python, Treesitter and Eglot](https://gist.github.com/habamax/290cda0e0cdc6118eb9a06121b9bc0d7)
;; [Eglot+Tree-Sitter in Emacs 29](https://www.adventuresinwhy.com/post/eglot/)
;; [Setting up Eglot for Python](https://www.reddit.com/r/emacs/comments/ye18nd/setting_up_eglot_for_python/)

(provide '14_1_python)

;;; 14_python.el ends here
