(use-package hydra
  :ensure t)

(defun toggle-window-dedicated ()
  "Toggle whether the current active window is dedicated or not"
  (interactive)
  (message
   (if (let (window (get-buffer-window (current-buffer)))
         (set-window-dedicated-p window
                                 (not (window-dedicated-p window))))
       "Window '%s' is dedicated"
     "Window '%s' is undedicated")
   (current-buffer)))

(defhydra hydra-windmove (global-map "C-x o")
  "windmove"
  ("j" windmove-left "left")
  ("l" windmove-right "right")
  ("i" windmove-up "up")
  ("k" windmove-down "down")
  ("o" other-window "other")
  ("." toggle-window-dedicated "dedicate"))

(provide '23_hydra)
;;; 23_hydra.el ends here
