;;; package --- rust configuration
;;;
;;; Commentary:
;;; rust configuration
;;; refer http://julienblanchard.com/2016/fancy-rust-development-with-emacs/
;;;
;;; Code:

(use-package rust-mode
  :ensure t
  :config (progn
	    (add-to-list 'auto-mode-alist '("\\.rs\\'" . rust-mode))
            (add-hook 'rust-mode-hook 'eglot-ensure)
	    (add-hook 'rust-mode-hook '(lambda () (local-set-key (kbd "C-c C-j") #'imenu)))
            (add-hook 'rust-mode-hook 'eldoc-mode)
            (add-hook 'rust-mode-hook 'flycheck-mode)))

(use-package cargo
  :ensure t
  :config (add-hook 'rust-mode-hook 'cargo-minor-mode))

(use-package flycheck-rust
  :ensure t
  :config (progn
            (add-hook 'flycheck-mode-hook #'flycheck-rust-setup)
            (add-hook 'flycheck-mode-hook #'flycheck-inline-mode)))

;;; 14_2_rust.el ends here
