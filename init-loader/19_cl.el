(cond
 ((executable-find "sbcl") (setq inferior-lisp-program "sbcl"))
 ((executable-find "ccl") (setq inferior-lisp-program "ccl")))

(require 'slime)
(slime-setup)
