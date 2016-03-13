;; Org

(global-set-key (kbd "C-c l") 'org-store-link)
(global-set-key (kbd "C-c a") 'org-agenda)
(global-set-key (kbd "C-c c") 'org-capture)
(global-set-key (kbd "C-c b") 'org-iswitchb)

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
	    (local-set-key (kbd "C-c `") 'org-edit-src-code)
	    ))

