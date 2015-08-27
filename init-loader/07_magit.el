(when
    (eq system-type 'windows-nt)
  (setq exec-path (add-to-list 'exec-path "C:/Program Files (x86)/Git/bin"))
  (setq magit-git-executable "C:/Program Files (x86)/Git/bin/git.exe")
  (setenv "PATH" (concat "C:\\Program Files (x86)\\Git\\bin;" (getenv "PATH"))))

(global-set-key (kbd "C-c g") 'magit-status)
(setq magit-last-seen-setup-instructions "1.4.0")
(setq git-commit-summary-max-length 80)
