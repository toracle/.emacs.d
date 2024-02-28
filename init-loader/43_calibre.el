(use-package calibredb
  :ensure t
  :config (progn
            (setq calibredb-root-dir "~/OneDrive/Calibre Library")
            (setq calibredb-db-dir (expand-file-name "metadata.db" calibre-root-dir))))
