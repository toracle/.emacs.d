;; Org

;; (use-package org-plus-contrib
;;   :ensure t)

(use-package org-mime
  :ensure t
  :config (progn
	    (add-hook 'message-mode-hook
			(local-set-key (kbd "C-c M-o") 'org-mime-htmlize))
	    (add-hook 'org-mode-hook
			(local-set-key (kbd "C-c M-o") 'org-mime-org-buffer-htmlize)))
  :bind (("C-c l" . org-store-link)
	 ("C-c a" . org-agenda)
	 ("C-c c" . org-capture)
	 ("C-c b" . org-iswitchb)))

(use-package ox-pandoc
  :ensure t)

(use-package ob-ipython
  :ensure t)

(use-package ob-restclient
  :ensure t)

(defun get-plantuml-jar-path ()
  (expand-file-name (concat user-emacs-directory "init-loader/" "plantuml.jar")))

(use-package plantuml-mode
  :ensure t
  :config (progn (add-to-list 'auto-mode-alist '("\\.plantuml\\'" . plantuml-mode))
                 (add-to-list 'org-src-lang-modes '("plantuml" . plantuml))
                 (setq plantuml-jar-path (get-plantuml-jar-path))
                 (add-hook 'plantuml-mode-hook '(lambda () (setq tab-width 4)))))

(setq org-log-done t)
(defun toracle-babel-config ()
  (org-babel-do-load-languages 'org-babel-load-languages
			       '((python . t)
                     (ipython . t)
				     (emacs-lisp . t)
				     (R . t)
				     (ditaa . t)
				     (dot . t)
				     (shell . t)
				     (gnuplot . t)
				     (js . t)
				     (lisp . t)
				     (ruby . t)
				     (sql . t)
				     (plantuml . t)
				     (sql . t)
				     (ledger . t)
                     (restclient . t)))
  (setq org-confirm-babel-evaluate nil)
  (setq org-plantuml-jar-path (get-plantuml-jar-path))
  (local-set-key (kbd "C-c `") 'org-edit-src-code))

(add-hook 'org-mode-hook 'toracle-babel-config)
(add-hook 'org-babel-after-execute-hook 'org-display-inline-images 'append)
