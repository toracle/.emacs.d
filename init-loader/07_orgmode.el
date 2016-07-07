;; Org

(require 'org-mime)

(add-hook 'message-mode-hook
	  (lambda ()
	    (local-set-key (kbd "C-c M-o") 'org-mime-htmlize)))

(add-hook 'org-mode-hook
	  (lambda ()
	    (local-set-key (kbd "C-c M-o") 'org-mime-org-buffer-htmlize)))

(global-set-key (kbd "C-c l") 'org-store-link)
(global-set-key (kbd "C-c a") 'org-agenda)
(global-set-key (kbd "C-c c") 'org-capture)
(global-set-key (kbd "C-c b") 'org-iswitchb)

(setq org-log-done t)
(defun toracle-babel-config ()
  (org-babel-do-load-languages 'org-babel-load-languages
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
				 (ledger . t)))
  
  (setq org-confirm-babel-evaluate nil)
  (setq org-plantuml-jar-path
	(expand-file-name (concat user-emacs-directory "init-loader/" "plantuml.jar")))
  (local-set-key (kbd "C-c `") 'org-edit-src-code))

(add-hook 'org-mode-hook 'toracle-babel-config)
