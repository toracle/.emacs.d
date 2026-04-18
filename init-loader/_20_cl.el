(use-package slime
  :ensure t
  :config (progn
	    (cond
	     ((executable-find "ros") (let ((helper-file (expand-file-name "~/.roswell/helper.el")))
                                        (when (file-exists-p helper-file)
                                          (load helper-file 'noerror)
                                          (setq inferior-lisp-program "ros run"))))
	     ((executable-find "sbcl") (setq inferior-lisp-program "sbcl"))
	     ((executable-find "clisp") (setq inferior-lisp-program "clisp"))
	     ((executable-find "ccl") (setq inferior-lisp-program "ccl"))
             ((executable-find "ecl") (setq inferior-lisp-program "ecl"))
	     ((executable-find "wx86cl64") (setq inferior-lisp-program "wx86cl64 -K utf-8")))
            (setq slime-contribs '(slime-fancy))
	    (slime-setup)))

(use-package slime-company
  :ensure t
  :config (progn
            (company-mode t)
            (slime-setup '(slime-fancy slime-company))))

(defvar paren-face 'paren-face)
(make-face 'paren-face)
(set-face-foreground 'paren-face "#444444")

;; (dolist (mode '(lisp-mode
;;                 emacs-lisp-mode
;;                 scheme-mode))
;;   (font-lock-add-keywords mode
;; 			  '(("(\\|)" . paren-face))))

(mapc (lambda (mode) (font-lock-add-keywords mode '(("(\\|)" . paren-face))))
      '(lisp-mode emacs-lisp-mode scheme-mode))

(add-hook 'slime-repl-mode-hook 'ansi-color-for-comint-mode-on)

(use-package paredit
  :ensure t
  :config (progn
            (add-hook 'emacs-lisp-mode-hook #'paredit-mode)
            (add-hook 'lisp-mode-hook #'paredit-mode)
            (add-hook 'cider-mode-hook #'paredit-mode)))


;; install clhs
;; ros install clhs
(let ((clhs-loader-path (expand-file-name "~/.roswell/lisp/quicklisp/clhs-use-local.el")))
  (when
      (file-exists-p clhs-loader-path)
    (load clhs-loader-path t)))


(let ((site-init-dir "/etc/emacs/site-start.d/"))
  (when (file-accessible-directory-p site-init-dir)
    (add-to-list 'load-path site-init-dir)))
