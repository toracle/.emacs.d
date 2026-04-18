(use-package scala-mode
  :interpreter
  ("scala" . scala-mode))


(use-package sbt-mode
  :ensure t
  :commands sbt-start sbt-command
  :config
  ;; WORKAROUND: https://github.com/ensime/emacs-sbt-mode/issues/31
  ;; allows using SPACE when in the minibuffer
  (substitute-key-definition
   'minibuffer-complete-word
   'self-insert-command
   minibuffer-local-completion-map)
   ;; sbt-supershell kills sbt-mode:  https://github.com/hvesalai/emacs-sbt-mode/issues/152
   (setq sbt:program-options '("-Dsbt.supershell=false")))


(use-package lsp-mode
  :ensure t
  ;; Optional - enable lsp-mode automatically in scala files
  :hook  (scala-mode . lsp)
         (lsp-mode . lsp-lens-mode)
  :config
  ;; Uncomment following section if you would like to tune lsp-mode performance according to
  ;; https://emacs-lsp.github.io/lsp-mode/page/performance/
  ;;       (setq gc-cons-threshold 100000000) ;; 100mb
  ;;       (setq read-process-output-max (* 1024 1024)) ;; 1mb
  ;;       (setq lsp-idle-delay 0.500)
  ;;       (setq lsp-log-io nil)
  ;;       (setq lsp-completion-provider :capf)
  (setq lsp-prefer-flymake nil))


(use-package lsp-metals
  :ensure t
  :custom
  ;; Metals claims to support range formatting by default but it supports range
  ;; formatting of multiline strings only. You might want to disable it so that
  ;; emacs can use indentation provided by scala-mode.
  (lsp-metals-server-args '("-J-Dmetals.allow-multiline-string-formatting=off"))
  :hook (scala-mode . lsp))


(use-package lsp-ui
  :ensure t)


(use-package company
  :hook (scala-mode . company-mode)
  :config
  (setq lsp-completion-provider :capf))


(use-package posframe
  ;; Posframe is a pop-up tool that must be manually installed for dap-mode
  :ensure t)


(use-package dap-mode
  :ensure t
  :hook
  (lsp-mode . dap-mode)
  (lsp-mode . dap-ui-mode))
