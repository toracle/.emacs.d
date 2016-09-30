
(use-package slime
  :config (progn
	    (cond
	     ((executable-find "sbcl") (setq inferior-lisp-program "sbcl"))
	     ((executable-find "ccl") (setq inferior-lisp-program "ccl"))
	     ((executable-find "wx86cl64") (setq inferior-lisp-program "wx86cl64 -K utf-8")))
	    (slime-setup)))
