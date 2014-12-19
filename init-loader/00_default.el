(prefer-coding-system 'utf-8)

(column-number-mode t)

(xterm-mouse-mode t)

(require 'neotree)
(global-set-key [f8] 'neotree-toggle)

(add-hook 'after-init-hook #'global-flycheck-mode)

(setq custom-safe-themes '("b71d5d49d0b9611c0afce5c6237aacab4f1775b74e513d8ba36ab67dfab35e5a" "756597b162f1be60a12dbd52bab71d40d6a2845a3e3c2584c6573ee9c332a66e" default))

(require 'smart-mode-line)
(sml/setup)
(sml/apply-theme 'powerline)
