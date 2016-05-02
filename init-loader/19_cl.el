(cond
 ((executable-find "sbcl.exe") (setq inferior-lisp-program "sbcl.exe"))
 ((executable-find "ccl.exe") (setq inferior-lisp-program "ccl.exe"))
 ((executable-find "wx86cl64.exe") (setq inferior-lisp-program "wx86cl64.exe -K utf-8")))

(require 'slime)
(slime-setup)
