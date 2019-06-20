(use-package hydra
  :ensure t)

(defhydra hydra-windmove (global-map "C-x o")
  "windmove"
  ("j" windmove-left "left")
  ("l" windmove-right "right")
  ("i" windmove-up "up")
  ("k" windmove-down "down"))


(defhydra hydra-switch-frame (global-map "C-x C-o")
  "switch-frame"
  ("o" other-frame "other"))
