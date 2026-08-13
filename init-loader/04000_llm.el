;;; begin

;; ---- gptel daemon void-variable guard ----
(defvar gptel--tool-preview-alist nil)

(use-package gptel
  :ensure t
  :demand t
  :custom (gptel-curl-coding-system 'utf-8)
  :config (modify-coding-system-alist 'process "curl" 'utf-8)
  (setq gptel-include-reasoning nil
        gptel-default-mode 'org-mode)
  (require 'gptel-transient))


(gptel-make-openai "OpenRouter"
  :host "openrouter.ai"
  :endpoint "/api/v1/chat/completions"
  :stream t
  :key 'gptel-api-key-from-auth-source
  :models '(openai/gpt-oss-120b google/gemma-3-27b-it google/gemini-3-flash-preview upstage/solar-pro-3 qwen/qwen3.5-35b-a3b qwen/qwen3.5-122b-a10b qwen/qwen3.5-397b-a17b qwen/qwen3-coder-next))


;; (defun toracle-llm/list-buffers ()
;;   (buffer-list))


;; (gptel-make-tool
;;  :name "list-all-buffers"
;;  :function 'toracle-llm/list-buffers
;;  :description "list all open buffers in emacs, it can be used before calling other tools to understand and state of the system"
;;  :args '()
;;  :category "emacs")


;; (defun toracle-llm/get-buffer-content (buffer-name)
;;   "Return a plist (:status STRING :content STRING) for buffer BUFFER-NAME.
;; Never switches to the buffer or modifies it."
;;   (let ((buf (get-buffer buffer-name)))
;;     (if (not buf)
;;         (list :status "error" :message (format "No such buffer: %s" buffer-name))
;;       (with-current-buffer buf
;;         (list :status "ok"
;;               :content (buffer-substring-no-properties (point-min) (point-max)))))))
    
;; (gptel-make-tool
;;  :name "get-buffer-content"
;;  :description "Read the entire text of a specified buffer without side‑effects."
;;  :parameters '(("buffer-name" string "Name of the buffer to read"))
;;  :function #'toracle-llm/get-buffer-content
;;  :args '((:name "buffer-name" :type string))
;;  :category "emacs")


(use-package gptel-agent
  :ensure t)


(if (not (windows-system?))
    (use-package ghostel
      :ensure t
      ;; Full redraws are more robust with Claude Code's aggressive partial
      ;; screen updates (per ghostel's own docs).
      :custom (ghostel-full-redraw t)
      :config
      ;; ghostel defers terminal redraws to a coalescing timer but never calls
      ;; `redisplay', so output arriving while Emacs is idle (e.g. a Claude
      ;; session printing in a non-selected/preview window) updates the buffer
      ;; yet does not repaint the window until the next keystroke.  Force a
      ;; redisplay after each deferred redraw to close that gap.
      (defun my/ghostel--redraw-redisplay (&rest _)
        (redisplay))
      (advice-add 'ghostel--redraw-now :after #'my/ghostel--redraw-redisplay))
  (use-package eat
    :ensure t))


(if (functionp 'use-package-vc-install)
    (eval
     '(use-package claude-code-ide
        :vc (:url "https://github.com/manzaltu/claude-code-ide.el" :branch "main" :rev :newest)
        :bind (("C-c C-SPC" . claude-code-ide-menu))
        :config (claude-code-ide-emacs-tools-setup) (setq claude-code-ide-terminal-backend 'ghostel)))
  (defun claude-code-ide-menu ()
    (interactive)
    (message "claude-code-ide package not installed.")))


;; cc-butler: multi-session Claude Code manager + butler control plane
;; (https://github.com/toracle/cc-butler).  Depends on claude-code-ide (above)
;; + hydra.  Same Emacs-30 `:vc' guard as the block above; on older Emacs it
;; no-ops.  NOTE: this loads from GitHub, not the local ~/projects/cc-butler
;; checkout -- run `M-x package-vc-upgrade cc-butler' to pick up new commits.
(if (functionp 'use-package-vc-install)
    (eval
     '(use-package cc-butler
        :vc (:url "https://github.com/toracle/cc-butler" :branch "main" :rev :newest)
        :after claude-code-ide))
  (defun cc-butler (&rest _)
    (interactive)
    (message "cc-butler package not installed.")))

;; The cc-butler governance store is pinned OUTSIDE this repo, and the pin
;; deliberately does NOT live in this file.
;;
;; The store holds site-specific operating principles -- they name real people,
;; repos and incidents -- so neither the store nor its location belongs in a
;; public repo, and THIS FILE IS PUBLIC.  The actual `setq' lives in
;; `~/.emacs.d/custom.el', which is gitignored by a COMMITTED `.gitignore'
;; line (`.gitignore:17'), so it never reaches the remote.  Look there to see
;; or change the path.
;;
;; Both `record_principle' and `cc-butler-governance-regenerate' act on
;; `cc-butler-governance-dir', so that one pin keeps every write private.  The
;; package's own governance/ stays the generic BUILT-IN default for fresh
;; installs, and `cc-butler-governance-user-dir' remains available as an
;; override/additive layer on top.  A defcustom is not re-evaluated once bound,
;; which is why the value is set explicitly rather than left to the load-time
;; default.
;;
;; FAILURE MODE -- read this before "fixing" anything here: if that pin is lost,
;; governance does NOT error.  It silently falls back to the package's bundled
;; generic store, and the fleet keeps running while reading the wrong
;; principles.  Verify the live value, never infer it:
;;   emacsclient -e '(cc-butler-governance-store)'

;; A monocle topic template for `cc-butler-new-topic'.  Picking "monocle" and
;; typing a topic name (e.g. "cli-rust") creates ~/projects/monocle-<topic>/ as
;; the parent (projectile) workspace, clones the warmblood-kr/monocle meta repo
;; into it as monocle/, and scaffolds .projectile + a CLAUDE.md that @-imports
;; the meta repo's shared docs.  Template lives here in private config, not in
;; the package (which ships no real repos).  Guard on the feature so the macro
;; and its registry exist before we register.
(with-eval-after-load 'cc-butler-workspace
  ;; CONVENTION: `monocle' is the META repo of the whole monocle family.  EVERY
  ;; monocle-related topic clones it FIRST (as the meta repo, per :repos order),
  ;; then any project-specific repos — so a worker always has the shared monocle
  ;; architecture (monocle/CLAUDE.md + monocle/DESIGN.md) at hand.
  (cc-butler-define-project-template monocle
    :base-dir "~/projects"
    :dir-format "monocle-%s"
    :repos ("git@github.com:warmblood-kr/monocle.git")
    :claude-import ("monocle/CLAUDE.md" "monocle/DESIGN.md"))
  ;; stark: the monocle admin console (관리자 콘솔) — a monocle-family topic, so
  ;; it clones the monocle meta repo FIRST, then stark.  Imports the monocle
  ;; meta docs plus stark's own guide (stark has CLAUDE.md but no DESIGN.md).
  (cc-butler-define-project-template stark
    :base-dir "~/projects"
    :dir-format "stark-%s"
    :repos ("git@github.com:warmblood-kr/monocle.git"
            "git@github.com:warmblood-kr/stark.git")
    :claude-import ("monocle/CLAUDE.md" "monocle/DESIGN.md" "stark/CLAUDE.md"))
  ;; monocle-mobile: the Flutter mobile app (Android + iOS).  A monocle-family
  ;; topic, so the monocle meta repo comes FIRST.  `monocle-flutter-core' rides
  ;; along because it holds the transport layer the app talks to Stark through —
  ;; chat/Responses-API and tool-calling work lands in one or both, so a topic
  ;; that clones only the app keeps hitting a wall it cannot see into.
  ;; flutter-core ships no CLAUDE.md of its own (README only), hence absent from
  ;; the imports.
  (cc-butler-define-project-template monocle-mobile
    :base-dir "~/projects"
    :dir-format "monocle-mobile-%s"
    :repos ("git@github.com:warmblood-kr/monocle.git"
            "git@github.com:warmblood-kr/monocle-mobile-app.git"
            "git@github.com:warmblood-kr/monocle-flutter-core.git")
    :claude-import ("monocle/CLAUDE.md" "monocle/DESIGN.md"
                    "monocle-mobile-app/CLAUDE.md"))
  ;; cc-butler itself — NOT a monocle-family topic, so no monocle meta repo.
  ;; The repo ships no CLAUDE.md (start from README.org / docs/ / governance/),
  ;; hence no :claude-import.  dir-format keeps topics out of the existing
  ;; ~/projects/cc-butler working checkout.
  (cc-butler-define-project-template cc-butler
    :base-dir "~/projects"
    :dir-format "cc-butler-%s"
    :repos ("https://github.com/toracle/cc-butler.git")
    :claude-import nil))


;; Resolve the Claude CLI to an absolute, tilde-free path.
;; The ghostel backend spawns the program directly via execvp (no shell),
;; so a literal "~/..." is never expanded and the process dies instantly,
;; surfacing as a bare "Invalid buffer" error.  Detect across environments
;; (Linux, WSL, macOS, native Windows): prefer a PATH lookup, then fall back
;; to known install locations.  Leave the default untouched when none exist.
(let ((claude-bin
       (or (executable-find "claude")
           (seq-find #'file-executable-p
                     (mapcar #'expand-file-name
                             '("~/.local/bin/claude"
                               "~/.claude/local/claude"
                               "/opt/homebrew/bin/claude"
                               "/usr/local/bin/claude"))))))
  (when claude-bin
    (setq claude-code-ide-cli-path claude-bin)))


(defhydra hydra-llm (:hint t)
  "llm"
  ("c" claude-code-ide-menu "claude-code-ide")
  ("C" cc-butler-launch-with-channel "cc+channel")
  ("s" cc-butler "cc-sessions")
  ("t" cc-butler-new-topic "cc-new-topic")
  ("g" gptel "gptel")
  ("m" gptel-menu "gptel-menu")
  ("a" gptel-agent "gptel-agent")
  ("b" gptel-abort "gptel-abort"))

(global-set-key (kbd "C-c C-SPC") #'hydra-llm/body)

;;; ends
