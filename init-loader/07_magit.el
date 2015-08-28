(when
    (eq system-type 'windows-nt)
  (setq magit-git-executable "C:/Program Files/Git/bin/git.exe"))

(global-set-key (kbd "C-c g") 'magit-status)
(setq magit-last-seen-setup-instructions "1.4.0")
(setq git-commit-summary-max-length 80)
