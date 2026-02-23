(require 'cl-lib)

(defun calibredb-find-file-with-cloud-file (orig-func &rest args)
  (let* ((file-path (cadr (assoc :file-path (caar args))))
         (filename (expand-file-name file-path))
         (cmd (concat "file \"" filename "\"")))
    (shell-command cmd)
    (apply orig-func args)))


(use-package calibredb
  :ensure t
  :config (progn
            (setq calibredb-root-dir 
                  (cl-case system-type
                    (darwin "~/OneDrive/Calibre Library")
                    (windows-nt (let ((loc (getenv "OneDriveConsumer")))
                                       (if loc (expand-file-name "Calibre Library" loc)
                                         "~/OneDrive/Calibre Library")))))
            (setq calibredb-db-dir (expand-file-name "metadata.db" calibredb-root-dir))
            (setq calibredb-id-width 6))
            (when (eq system-type 'darwin)
              (advice-add 'calibredb-find-file :around #'calibredb-find-file-with-cloud-file)))
