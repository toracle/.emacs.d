(prefer-coding-system 'utf-8)

(column-number-mode t)

(xterm-mouse-mode t)

(require 'neotree)
(global-set-key [f8] 'neotree-toggle)

(add-hook 'after-init-hook #'global-flycheck-mode)

(setq custom-safe-themes '("e56f1b1c1daec5dbddc50abd00fcd00f6ce4079f4a7f66052cf16d96412a09a9" "b71d5d49d0b9611c0afce5c6237aacab4f1775b74e513d8ba36ab67dfab35e5a" "756597b162f1be60a12dbd52bab71d40d6a2845a3e3c2584c6573ee9c332a66e" default))

(require 'smart-mode-line)
(sml/setup)
(sml/apply-theme 'powerline)
(ample-theme)

(global-page-break-lines-mode t)
(setq inhibit-startup-screen t)

(defun lunaryorn-new-buffer-frame ()
  "Create a new frame with a new empty buffer."
  (interactive)
  (let ((buffer (generate-new-buffer "untitled")))
    (set-buffer-major-mode buffer)
    (display-buffer buffer '(display-buffer-pop-up-frame . nil))))


(global-set-key (kbd "C-x n RET") #'lunaryorn-new-buffer-frame)
