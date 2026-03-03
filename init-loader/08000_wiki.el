;;; 08000_wiki.el --- init file for moinrpc-mode
;; -*- lexical-binding: t -*-

;; moinrpc-mode: install from VC and defer loading via autoloads


(use-package moinrpc-mode
  :vc (:url "https://github.com/toracle/moinrpc-mode" :branch "devel")
  ;; :vc (:url "/home/toracle/projects/moinrpc-mode")
  :defer t
  :commands (moinrpc-main-page moinrpc-open-page moinrpc-save-page moinrpc-helm-find-page)
  :config
  ;; Optional: customize defaults here
  (setq moinrpc-default-timeout 30))

(provide '08000_wiki)
;;; 08000_wiki.el ends here
