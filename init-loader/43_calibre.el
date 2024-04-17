(use-package calibredb
  :ensure t
  :config (progn
            (setq calibredb-root-dir (let ((loc (getenv "OneDriveConsumer")))
                                       (if loc loc "~/OneDrive/Calibre Library")))
            (setq calibredb-db-dir (expand-file-name "metadata.db" calibredb-root-dir))
            (setq calibredb-id-width 6)))
