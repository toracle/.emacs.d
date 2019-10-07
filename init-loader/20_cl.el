(use-package slime
  :ensure t
  :config (progn
	    (cond
	     ((executable-find "ros")
              (load (expand-file-name "~/.roswell/helper.el") 'noerror))
	     ((executable-find "sbcl") (setq inferior-lisp-program "sbcl"))
	     ((executable-find "clisp") (setq inferior-lisp-program "clisp"))
	     ((executable-find "ccl") (setq inferior-lisp-program "ccl"))
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
