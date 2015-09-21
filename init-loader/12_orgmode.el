;; Org

(add-hook 'org-mode-hook
	  (progn
	    (setq org-log-done t)

	    ;; Org-Babel

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
	       (ledger . t)
	       ))

	    (setq org-confirm-babel-evaluate nil)

	    ;; Org-Babel PlantUML

	    (setq org-plantuml-jar-path
		  (expand-file-name (concat user-emacs-directory "init-loader/" "plantuml.jar")))
	    (local-set-key (kbd "C-c `") 'org-edit-src-code)))
