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
	    (local-set-key (kbd "C-c C-j") #'imenu)))

(use-package cargo
  :ensure t
  :config (add-hook 'rust-mode-hook 'cargo-minor-mode))

(use-package racer
  :ensure t
  :config (progn
	    (setq racer-cmd "~/.cargo/bin/racer") ;; Rustup binaries PATH
	    (setq racer-rust-src-path "~/src/rust/src") ;; Rust source code PATH
	    (define-key rust-mode-map (kbd "TAB") #'company-indent-or-complete-common)
	    (setq company-tooltip-align-annotations t)
	    (add-hook 'rust-mode-hook #'racer-mode)
	    (add-hook 'racer-mode-hook #'eldoc-mode)
	    (add-hook 'racer-mode-hook #'company-mode)
	    (local-set-key (kbd "C-c C-d") #'racer-describe)))

(use-package flycheck-rust
  :ensure t
  :config (add-hook 'flycheck-mode-hook #'flycheck-rust-setup))


(use-package toml-mode
  :ensure t)

;;; 22_rust.el ends here
