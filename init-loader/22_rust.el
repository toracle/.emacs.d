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
	    (add-hook 'rust-mode-hook '(lambda () (local-set-key (kbd "C-c C-j") #'imenu)))
            (add-hook 'rust-mode-hook 'eldoc-mode)
            (add-hook 'rust-mode-hook 'flycheck-mode)))

(use-package cargo
  :ensure t
  :config (add-hook 'rust-mode-hook 'cargo-minor-mode))

(use-package racer
  :ensure t
  :config (progn
	    (setq racer-cmd (expand-file-name "~/.cargo/bin/racer")) ;; Rustup binaries PATH
	    (setq racer-rust-src-path (expand-file-name "~/.rustup/toolchains/stable-x86_64-unknown-linux-gnu/lib/rustlib/src/rust/src")) ;; Rust source code PATH
	    (define-key rust-mode-map (kbd "TAB") #'company-indent-or-complete-common)
	    (setq company-tooltip-align-annotations t)
	    (add-hook 'rust-mode-hook #'racer-mode)
	    (add-hook 'racer-mode-hook #'eldoc-mode)
	    (add-hook 'racer-mode-hook #'company-mode)
            (add-hook 'rust-mode-hook '(lambda () (local-set-key (kbd "C-c d") #'racer-describe)))))

(use-package flycheck-inline
  :ensure t)

(use-package flycheck-rust
  :ensure t
  :config (progn
            (add-hook 'flycheck-mode-hook #'flycheck-rust-setup)
            (add-hook 'flycheck-mode-hook #'flycheck-inline-mode)))


(use-package toml-mode
  :ensure t)

;;; 22_rust.el ends here
