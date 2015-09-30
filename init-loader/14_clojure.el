;; 13_clojure.el

(add-hook 'cider-mode-hook #'eldoc-mode)
(setq cider-repl-result-prefix ";; => ")
(setq cider-interactive-eval-result-prefix ";; => ")

(add-hook 'cider-mode-hook #'rainbow-delimiters-mode)
(add-hook 'emacs-lisp-mode-hook #'rainbow-delimiters-mode)

(set-face-attribute 'rainbow-delimiters-depth-1-face nil :foreground "#78c5d6")
(set-face-attribute 'rainbow-delimiters-depth-2-face nil :foreground "#bf62a6")
(set-face-attribute 'rainbow-delimiters-depth-3-face nil :foreground "#459ba8")
(set-face-attribute 'rainbow-delimiters-depth-4-face nil :foreground "#e868a2")
(set-face-attribute 'rainbow-delimiters-depth-5-face nil :foreground "#79c267")
(set-face-attribute 'rainbow-delimiters-depth-6-face nil :foreground "#f28c33")
(set-face-attribute 'rainbow-delimiters-depth-7-face nil :foreground "#c5d647")
(set-face-attribute 'rainbow-delimiters-depth-8-face nil :foreground "#f5d63d")
(set-face-attribute 'rainbow-delimiters-depth-9-face nil :foreground "#78c5d6")

(set-face-attribute 'rainbow-delimiters-unmatched-face nil
                    :foreground 'unspecified
                    :inherit 'show-paren-mismatch
                    :strike-through t)

(electric-pair-mode 1)
