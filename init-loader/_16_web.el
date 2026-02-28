(use-package web-mode
  :ensure t
  :config (progn
            (add-hook 'web-mode 'eglot-ensure)
	    (add-to-list 'auto-mode-alist '("\\.html\\'" . web-mode))
	    (add-to-list 'auto-mode-alist '("\\.phtml\\'" . web-mode))
	    (add-to-list 'auto-mode-alist '("\\.tpl\\.php\\'" . web-mode))
	    (add-to-list 'auto-mode-alist '("\\.[agj]sp\\'" . web-mode))
	    (add-to-list 'auto-mode-alist '("\\.as[cp]x\\'" . web-mode))
	    (add-to-list 'auto-mode-alist '("\\.erb\\'" . web-mode))
	    (add-to-list 'auto-mode-alist '("\\.mustache\\'" . web-mode))
	    (add-to-list 'auto-mode-alist '("\\.djhtml\\'" . web-mode))
	    (add-to-list 'auto-mode-alist '("\\.css\\'" . web-mode))
	    (add-to-list 'auto-mode-alist '("\\.scss\\'" . web-mode))))

;; (use-package company-web
;;   :ensure t)

(defun my-web-mode-hook ()
  "Hooks for Web mode."
  (setq web-mode-markup-indent-offset 2)
  (setq web-mode-css-indent-offset 2)
  (setq web-mode-code-indent-offset 2)
  (setq web-mode-enable-engine-detection t)
  (setq web-mode-style-padding 0)
  (setq web-mode-script-padding 0)
  (local-set-key (kbd "C-c /")  'web-mode-element-close)
  (local-set-key (kbd "C-M-i")  'company-complete)
  (define-key web-mode-map (kbd "C-'") 'company-web-html)
  (subword-mode t)
  (setq indent-tabs-mode nil)
  (setq company-tooltip-limit 20)
  (setq company-tooltop-align-annotation 't)
  (setq company-idle-delay .3)
  (setq company-begin-commands '(self-insert-command)))

(add-hook 'web-mode-hook  'my-web-mode-hook)
(add-hook 'css-mode-hook  'my-web-mode-hook)

(defun yaml/init-subword ()
  (subword-mode +1))

(use-package emmet-mode
  :ensure t
  :config (progn (add-hook 'sgml-mode-hook 'emmet-mode)
                 (add-hook 'css-mode-hook 'emmet-mode)))

(use-package markdown-mode
  :config (setq markdown-code-face "D2Coding")
  :ensure t)

(use-package yaml-mode
  :config (progn
            (add-hook 'yaml-mode-hook 'yaml/init-subword))
  :ensure t)

(use-package adoc-mode
  :ensure t)

(use-package creole
  :ensure t)

(use-package impatient-mode
  :ensure t)

(use-package restclient
  :ensure t
  :config (progn
            (add-to-list 'auto-mode-alist '("\\.restclient\\'" . restclient-mode))
            (add-hook 'restclient-mode-hook 'company-mode)))

(use-package smart-shift
  :ensure t)

(use-package vue-mode
  :ensure t
  :config (setq mmm-submode-decoration-level 0))

(defun toracle/init-company-restclient ()
  (add-to-list 'company-backends 'company-restclient))

(use-package company-restclient
  :ensure t
  :config 'toracle/init-company-restclient)

(add-to-list 'eglot-server-programs '(web-mode . ("vscode-html-language-server" "--stdio")))
