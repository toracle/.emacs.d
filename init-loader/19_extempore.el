(require 'extempore)


(let ((extempore-el-path (concat (file-name-as-directory (concat user-emacs-directory
								 "modules"))
				 "extempore.el"))
      (user-extempore-directory (file-name-as-directory (concat (file-name-as-directory (getenv "HOME"))
								"extempore"))))
  (autoload 'extempore-mode extempore-el-path "" t)
  (add-to-list 'auto-mode-alist '("\\.xtm$" . extempore-mode))
  (setq user-extempore-directory "/path/to/extempore/")
  nil)
