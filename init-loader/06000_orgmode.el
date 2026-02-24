;; Org

;; (use-package org-plus-contrib
;;   :ensure t)

;; (use-package org-mime
;;   :ensure t
;;   :config (progn
;; 	    (add-hook 'message-mode-hook
;; 			(local-set-key (kbd "C-c M-o") 'org-mime-htmlize))
;; 	    (add-hook 'org-mode-hook
;; 			(local-set-key (kbd "C-c M-o") 'org-mime-org-buffer-htmlize)))
;;   :bind (("C-c l" . org-store-link)
;; 	 ("C-c a" . org-agenda)
;; 	 ("C-c c" . org-capture)
;; 	 ("C-c b" . org-iswitchb)))

(use-package org-msg
  :ensure t)


(use-package ox-pandoc
  :ensure t)

;; Comment out ob-ipython due to an issue below
;; https://github.com/syl20bnr/spacemacs/issues/9941#issuecomment-543227397
;; 
;; (use-package ob-ipython
;;   :ensure t)

(use-package ob-restclient
  :ensure t)


(use-package ob-async
  :ensure t)


(use-package ob-powershell
  :ensure t
  :config (when (eq system-type 'darwin)
            (customize-set-variable 'org-babel-powershell-os-command "pwsh")))


(use-package toc-org
  :ensure t)


;; (use-package deft
;;   :config (progn
;;             (setq deft-extension "org"
;;                   deft-text-mode 'org-mode
;;                   deft-use-filename-as-title t)
;;             (let ((dropbox-dir-candidates '("/mnt/c/Users/torac/Dropbox/"
;;                                             "/home/toracle/Dropbox/"))
;;                   (deft-root-dir "Wooridle/toracle/Org/deft"))
;;               (dolist (dropbox-dir dropbox-dir-candidates)
;;                 (when (f-directory? dropbox-dir)
;;                   (setq deft-directory
;;                         (concat dropbox-dir deft-root-dir))))
;;             (global-set-key (kbd "<f9>") 'deft))))


(defun get-init-loader-resource-path (name)
  (expand-file-name (concat user-emacs-directory "init-loader/" name)))


(use-package plantuml-mode
  :ensure t
  :config (progn (add-to-list 'auto-mode-alist '("\\.plantuml\\'" . plantuml-mode))
                 (add-to-list 'org-src-lang-modes '("plantuml" . plantuml))
                 (setq plantuml-jar-path (get-init-loader-resource-path "plantuml.jar"))
                 (setq org-plantuml-jar-path (get-init-loader-resource-path "plantuml.jar"))
                 (add-hook 'plantuml-mode-hook '(lambda () (setq tab-width 4)))))

(setq org-log-done t)

(defun toracle-babel-config ()
  (org-babel-do-load-languages 'org-babel-load-languages
			       '((python . t)
                                 ;; (ipython . t)
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
                                 (powershell . t)
                                 (restclient . t)))
  (setq org-confirm-babel-evaluate nil)
  (setq org-plantuml-jar-path (get-init-loader-resource-path "plantuml.jar"))
  (setq org-ditaa-jar-path (get-init-loader-resource-path "ditaa0_9.jar"))
  (local-set-key (kbd "C-c `") 'org-edit-src-code))

(add-hook 'org-mode-hook 'toracle-babel-config)
(add-hook 'org-babel-after-execute-hook 'org-display-inline-images 'append)
