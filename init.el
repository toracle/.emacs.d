
;; Added by Package.el.  This must come before configurations of
;; installed packages.  Don't delete this line.  If you don't want it,
;; just comment it out by adding a semicolon to the start of the line.
;; You may delete these explanatory comments.

(require 'package)
(setq package-enable-at-startup nil)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/"))
(add-to-list 'package-archives '("org" . "http://orgmode.org/elpa/"))

(package-initialize)

;; Bootstrap `use-package'
(unless (or (package-installed-p 'use-package) (fboundp 'use-package))
  (package-refresh-contents)
  (package-install 'use-package))


;; (require 'cask "~/.cask/cask.el")
;; (cask-initialize)

(use-package init-loader
  :ensure t
  :config (init-loader-load (concat user-emacs-directory "init-loader")))

(setq custom-file "~/.emacs.d/custom.el")
(load custom-file 'noerror)

;; Customize keeps re-saving claude-code-ide-cli-path with a literal "~".
;; The ghostel backend spawns via execvp (no shell), so a literal tilde is
;; never expanded -> claude exits instantly -> "Invalid buffer".  Normalize
;; any tilde path after custom.el loads (custom.el loads after init-loader,
;; so this must live here to win).  Bare commands (PATH lookup) are left alone.
(when (and (boundp 'claude-code-ide-cli-path)
           (stringp claude-code-ide-cli-path)
           (string-prefix-p "~" claude-code-ide-cli-path))
  (setq claude-code-ide-cli-path (expand-file-name claude-code-ide-cli-path)))

(add-to-list 'load-path "~/.emacs.d/modules/")

;; cc-butler is now installed + loaded via `use-package'/:vc in
;; init-loader/04000_llm.el (was a manual load-path + require here).

;; Governance store moved out of the cc-butler repo (public) into the
;; warmble-jumble vault (private-to-org, colleague-visible) — 정수님's
;; decision, 2026-08-13. Explicit override so record_principle/
;; regenerate_governance route here regardless of which cc-butler
;; checkout's code happens to load (see cc-butler-governance-dir in
;; cc-butler-governance.el).
;;
;; ~/obsidian/warmble-jumble, NOT ~/projects/warmble-jumble — there are
;; two clones on this machine and only ~/obsidian/warmble-jumble is
;; what wb-para's own tooling (vault_paths.py, push-vault.sh, the Stop
;; hook, capture/organize/promote/link) actually reads and pushes.
(setq cc-butler-governance-dir
      (expand-file-name "~/obsidian/warmble-jumble/3-resources/cc-butler-governance/"))

;; North Star self-check interval — 정수님's call, 2026-08-13: 1 hour, not the
;; 2-hour default. This is now the ONLY North Star pulse mechanism (butler's
;; own session-local cron backup was deliberately removed the same day in
;; favor of this single external/systematic one) — a silent revert here means
;; the pulse silently stops existing, not just runs less often.
;;
;; The setq alone is NOT enough: `cc-butler-north-star.el' arms its timer at
;; its own top level, at LOAD time — via `(require 'cc-butler)' above, which
;; runs BEFORE this line. So on a fresh start the timer would already be
;; armed at the stale 7200s default before this setq ever executes; only the
;; *variable* would read 3600, the *timer* would still fire every 2 hours.
;; Re-arm explicitly so both agree regardless of load order.
(setq cc-butler-north-star-interval 3600)
(cc-butler--north-star-ensure-timer)

;; North Star fleet identity — 정수님's call, 2026-08-13: the governance store
;; above is shared across possibly-multiple cc-butler fleets, so the North
;; Star goals file needs to be namespaced per fleet rather than assumed
;; fleet-exclusive. Corrected same day: an initial "monocle" default was
;; wrong for exactly the reason this variable exists — other fleets ALSO
;; work on monocle, so a client-project name can't distinguish fleets.
;; Namespaced by MACHINE/INSTANCE instead — this one is the Desk Mini X600,
;; per 정수님 directly. Change it here if that changes.
;;
;; Same load-order trap as the interval above, one level deeper:
;; cc-butler-north-star-file's default is ALSO a defcustom default-value
;; expression baked in once at (require 'cc-butler) time, using whatever
;; cc-butler-fleet-name/cc-butler-governance-store held THEN. Setting
;; cc-butler-fleet-name here does not retroactively re-derive it. Re-derive
;; explicitly so the actual file path reflects the fleet name, not just the
;; fleet-name variable in isolation.
(setq cc-butler-fleet-name "x600")
(setq cc-butler-north-star-file
      (expand-file-name (format "north-star-%s.org" cc-butler-fleet-name)
                         (cc-butler-governance-store)))

(put 'narrow-to-region 'disabled nil)
(put 'upcase-region 'disabled nil)
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(package-vc-selected-packages
   '((moinrpc-mode :url "https://github.com/toracle/moinrpc-mode" :branch
                   "devel"))))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )
