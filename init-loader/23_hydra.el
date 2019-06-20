(use-package hydra
  :ensure t)

(defhydra hydra-windmove (global-map "C-x O")
  "windmove"
  ("j" windmove-left "left")
  ("l" windmove-right "right")
  ("i" windmove-up "up")
  ("k" windmove-down "down"))
