
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

;; claude-code-ide-mcp-server-port: pin the MCP tools server to a fixed port
;; instead of leaving it at the default nil (auto-select). 2026-08-14,
;; jeongsoo -- tonight, a live incident happened because this was left at
;; nil: the single Emacs-process-global MCP server binds a fresh random
;; OS-assigned port on every (re)start, but a Claude Code CLI session's
;; connection URL is baked into its argv at spawn time with no
;; re-resolution mechanism. So a session spawned in the narrow window
;; before a later re-bind superseded an earlier one ends up permanently
;; pointed at a dead port, with no error surfaced anywhere obvious. This
;; happened for real: one fleet session, spawned right after a
;; crash-restart, caught an early bind on port 35625, which was then
;; superseded by a second bind on port 37587 about 4 minutes later, and had
;; been silently broken since (confirmed via ps+ss; had to fall back to
;; `emacsclient -e' to communicate with it at all).
;;
;; Investigated claude-code-ide-mcp-server.el and
;; claude-code-ide-mcp-http-server.el before picking this fix: if this port
;; is already bound by another process when the server tries to start, it
;; does NOT silently fall back to picking a random port instead --
;; `claude-code-ide-mcp-http-server-start' calls `ws-start' with the exact
;; port, which calls `make-network-process' with that literal :service
;; value; on bind failure that error propagates up (re-signaled by
;; `claude-code-ide-mcp-http-server-start''s condition-case) to
;; `claude-code-ide-mcp-server--start-server', whose condition-case logs it
;; and calls `message' with "Warning: Failed to start MCP server: ..." and
;; returns nil. The server just fails to start; it does not quietly rebind
;; elsewhere. So pinning the port is safe: it can't silently degrade back
;; into this bug's failure mode.
;;
;; 37587 is the port that is currently live and working for 10 of 11 fleet
;; sessions right now, so it is the natural fixed value to standardize on.
(setq claude-code-ide-mcp-server-port 37587)

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
