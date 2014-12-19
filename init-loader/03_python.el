(elpy-enable)
(setq elpy-rpc-backend "rope")

(smart-tabs-advice python-indent-line-1 python-indent)

(add-hook 'python-mode-hook
	  (lambda ()
	    (setq indent-tabs-mode t)
	    (setq tab-width (default-value 'tab-width))
	    (setq ropemacs-mode t)
	    (setq elpy-mode t)
	    (setq flycheck-pylintrc (concat user-emacs-directory "init-loader/" "pylintrc"))
	    (flycheck-select-checker 'python-pylint)
	    )
	  )

(setq ropemacs-enable-autoimport t)


;(add-to-list 'load-path "~/.emacs.d/elisp/Pymacs")
;(require 'pymacs)
;(pymacs-load "ropemacs" "rope-")
