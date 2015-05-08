(org-babel-do-load-languages
 'org-babel-load-languages
 '((python . t)
   (emacs-lisp . t)
   (R . t)
   (ditaa . t)
   (dot . t)
   (sh . t)
   (gnuplot . t)
   (js . t)
   (lisp . t)
   (ruby . t)
   (plantuml . t)
   ))

(setq org-confirm-babel-evaluate nil)

(setq org-plantuml-jar-path
      (expand-file-name (concat user-emacs-directory "init-loader/" "plantuml.jar")))
