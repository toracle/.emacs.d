;;; 14_0_lang.el -- language configuration


(use-package eglot
  :ensure t)

(use-package corfu
  :ensure t
  :init (global-corfu-mode)
  :config (progn (setq corfu-auto t)))

(use-package corfu-terminal
  :ensure t
  :init (unless (display-graphic-p)
          (corfu-terminal-mode +1)))

(use-package cape
  :ensure t)

(require 'treesit)
(if (treesit-available-p)
    t)

(use-package flycheck
  :ensure t
  )

(use-package epc
  :ensure t)

(use-package flycheck-inline
  :ensure t)

(use-package toml-mode
  :ensure t)

(use-package dotnet
  :ensure t)

(use-package csproj-mode
  :ensure t)

;; project-find-function supporting both C# and F#:

(defun dotnet-mode/find-sln-or-fsproj (dir-or-file)
  "Search for a solution or F# project file in any enclosing
folders relative to DIR-OR-FILE."
  (dotnet-mode-search-upwards (rx (0+ nonl) (or ".fsproj" ".sln" ".csproj") eol)
                              (file-name-directory dir-or-file)))

(defun dotnet-mode-search-upwards (regex dir)
  (when dir
    (or (car-safe (directory-files dir 'full regex))
        (dotnet-mode-search-upwards regex (dotnet-mode-parent-dir dir)))))

(defun dotnet-mode-parent-dir (dir)
  (let ((p (file-name-directory (directory-file-name dir))))
    (unless (equal p dir)
      p)))

;; Make project.el aware of dotnet projects
(defun dotnet-mode-project-root (dir)
  (when-let (project-file (dotnet-mode/find-sln-or-fsproj dir))
    (cons 'dotnet (file-name-directory project-file))))

(cl-defmethod project-roots ((project (head dotnet)))
  (list (cdr project)))

(add-hook 'project-find-functions #'dotnet-mode-project-root)

(use-package sharper
  :ensure t)

(provide '14_0_lang)
