;(when
;    (eq system-type 'windows-nt)
;  (setq magit-git-executable "C:/Program Files/Git/bin/git.exe"))

(use-package magit
  :ensure t
  :bind (("C-c g" . magit-status))
  :config (setq magit-last-seen-setup-instructions "1.4.0"
		git-commit-summary-max-length 80))
