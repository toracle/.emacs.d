(defun calibredb-find-file-with-cloud-file (orig-func &rest args)
  (let* ((file-path (cadr (assoc :file-path (caar args))))
         (filename (expand-file-name file-path))
         (cmd (concat "file \"" filename "\"")))
    (shell-command cmd)
    (apply orig-func args)))


(use-package calibredb
  :ensure t
  :config (progn
            (setq calibredb-root-dir "~/OneDrive/Calibre Library")
            (setq calibredb-db-dir (expand-file-name "metadata.db" calibredb-root-dir))
            (when (eq system-type 'darwin)
              (advice-add 'calibredb-find-file :around #'calibredb-find-file-with-cloud-file))))
