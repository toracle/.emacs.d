;;; 32_4_claude_workspace.el --- Topic workspace scaffolding for CCSM  -*- lexical-binding: t; -*-

;; Create a "topic workspace" for a known project and drop straight into a
;; Claude session there.  A topic workspace is a plain (non-git) directory
;; that holds one or more checked-out repos plus two markers:
;;
;;   .projectile  -- makes projectile treat the topic dir as one project, so
;;                   all sibling repos are visible without /add-dir, and the
;;                   session manager names the session after the topic.
;;   CLAUDE.md    -- a thin file that @-imports the meta repo's shared docs
;;                   (CLAUDE.md / DESIGN.md), so launching Claude at the topic
;;                   dir loads the project's architecture at startup.
;;
;; The layout differs per project, so it lives in DATA: a template registry.
;; "Make a monocle topic" knows the meta repo URL and the import list; adding
;; another project is just another entry.  An "arbitrary" choice falls back to
;; `my/ccsm-new-session' (pick a directory, start a session, no scaffolding).
;;
;; Entry point: M-x my/ccsm-new-topic  (also `t' in the CCSM hydra,
;; `N' in the session-manager buffer).

(require '32_2_claude_session_manager)

(defcustom my/ccsm-project-templates
  '((monocle
     :base-dir "~/projects"
     :dir-format "monocle-%s"
     :repos ("git@github.com:warmblood-kr/monocle.git")
     :claude-import ("monocle/CLAUDE.md" "monocle/DESIGN.md")))
  "Registry of project templates for `my/ccsm-new-topic'.
Each entry is (NAME . PLIST) with keys:
  :base-dir       directory under which topic workspaces are created
  :dir-format     `format' string for the topic dir name; %s = topic name
  :repos          list of git URLs to clone into the topic dir; the first is
                  the meta repo (its local name is used for :claude-import)
  :claude-import  paths (relative to the topic dir) to @-import in the
                  generated CLAUDE.md, e.g. \"monocle/DESIGN.md\""
  :type '(alist :key-type symbol :value-type plist)
  :group 'claude-code-ide)

(defun my/ccsm--template (name)
  "Return the template plist for NAME (a symbol), or nil."
  (cdr (assq name my/ccsm-project-templates)))

(defun my/ccsm--repo-local-name (url)
  "Return the local clone directory name for a git URL.
\"git@github.com:org/monocle.git\" -> \"monocle\"."
  (let ((name (file-name-nondirectory (directory-file-name url))))
    (if (string-suffix-p ".git" name)
        (substring name 0 -4)
      name)))

(defun my/ccsm--topic-dir (template topic)
  "Return the absolute topic-workspace directory for TEMPLATE and TOPIC."
  (file-name-as-directory
   (expand-file-name
    (format (plist-get template :dir-format) topic)
    (expand-file-name (plist-get template :base-dir)))))

(defun my/ccsm--scaffold (topic-dir template)
  "Write `.projectile' and `CLAUDE.md' markers into TOPIC-DIR (idempotent).
Existing files are never clobbered."
  (let ((proj (expand-file-name ".projectile" topic-dir))
        (cmd  (expand-file-name "CLAUDE.md" topic-dir)))
    (unless (file-exists-p proj)
      (write-region "" nil proj nil 'silent))
    (unless (file-exists-p cmd)
      (let ((imports (plist-get template :claude-import))
            (topic (file-name-nondirectory (directory-file-name topic-dir))))
        (with-temp-file cmd
          (insert (format "# %s workspace\n\n" topic))
          (insert "Shared architecture and conventions, imported from the meta repo:\n\n")
          (dolist (imp imports)
            (insert (format "@%s\n" imp)))
          (insert "\n## Reporting to the butler (CCSM)\n\n")
          (insert "This session may run as a *worker* under a CCSM butler that coordinates\n")
          (insert "sessions. When you finish a task, get blocked, or need a human decision,\n")
          (insert "call the `report_to_butler` tool with real content — `summary` (what you\n")
          (insert "did / what happened), `status` (current state), and `needs` (what you need\n")
          (insert "from the human, or omit if just informing). Keep it concise; the butler\n")
          (insert "relays it to the human.\n"))))
    topic-dir))

(defun my/ccsm--start-session-in (dir)
  "Start a Claude session with DIR as the working directory.
Honors `my/ccsm-channel-args' so topic sessions can join the CCSM channel."
  (let ((default-directory (file-name-as-directory (expand-file-name dir))))
    (my/ccsm--with-channel (claude-code-ide))))

(defun my/ccsm--clone-repos (topic-dir repos done-fn)
  "Clone REPOS into TOPIC-DIR sequentially and asynchronously.
Each already-present repo is skipped.  On completion DONE-FN is called
with t (all succeeded) or nil (a clone failed)."
  (if (null repos)
      (funcall done-fn t)
    (let* ((url (car repos))
           (rest (cdr repos))
           (name (my/ccsm--repo-local-name url))
           (dest (expand-file-name name topic-dir)))
      (if (file-directory-p dest)
          (my/ccsm--clone-repos topic-dir rest done-fn)
        (let ((default-directory (file-name-as-directory topic-dir))
              (buf (generate-new-buffer (format " *ccsm-clone:%s*" name))))
          (message "ccsm: cloning %s ..." url)
          (make-process
           :name (format "ccsm-clone-%s" name)
           :buffer buf
           :command (list "git" "clone" url name)
           :noquery t
           :sentinel
           (lambda (proc _event)
             (when (memq (process-status proc) '(exit signal))
               (if (eq 0 (process-exit-status proc))
                   (progn
                     (when (buffer-live-p buf) (kill-buffer buf))
                     (my/ccsm--clone-repos topic-dir rest done-fn))
                 (message "ccsm: `git clone %s' failed — see %s"
                          url (buffer-name buf))
                 (funcall done-fn nil))))))))))

(defun my/ccsm--finish-topic (topic-dir template)
  "Scaffold TOPIC-DIR, start a session there, and open the manager."
  (my/ccsm--scaffold topic-dir template)
  (my/ccsm--start-session-in topic-dir)
  (my/ccsm))

;;;###autoload
(defun my/ccsm-new-topic ()
  "Create a topic workspace from a template and start a Claude session in it.
Prompts for a template (or `arbitrary', which delegates to
`my/ccsm-new-session') and a topic name, clones the template's repos if
needed, scaffolds the markers, and launches Claude at the topic dir."
  (interactive)
  (let* ((names (append (mapcar (lambda (e) (symbol-name (car e)))
                                my/ccsm-project-templates)
                        '("arbitrary")))
         (choice (completing-read "Workspace template: " names nil t)))
    (if (equal choice "arbitrary")
        (call-interactively #'my/ccsm-new-session)
      (let* ((template (my/ccsm--template (intern choice)))
             (topic (string-trim (read-string (format "%s topic name: " choice)))))
        (when (string-empty-p topic)
          (user-error "Topic name must not be empty"))
        (when (string-match-p "[/ \t]" topic)
          (user-error "Topic name must not contain spaces or slashes: %S" topic))
        (let* ((topic-dir (my/ccsm--topic-dir template topic))
               (repos (plist-get template :repos))
               (meta-dir (expand-file-name
                          (my/ccsm--repo-local-name (car repos)) topic-dir)))
          (make-directory topic-dir t)
          (if (file-directory-p meta-dir)
              ;; Already cloned — just scaffold (idempotent) and start.
              (my/ccsm--finish-topic topic-dir template)
            (my/ccsm--clone-repos
             topic-dir repos
             (lambda (ok)
               (if ok
                   (my/ccsm--finish-topic topic-dir template)
                 (message "ccsm: workspace %s not started (clone failed)"
                          topic-dir))))))))))

;;;; ------------------------------------------------------------------
;;;; Close a topic: safety-gated session teardown + workspace removal
;;;; ------------------------------------------------------------------
;;
;; The inverse of `my/ccsm-new-topic'.  Before deleting anything it proves no
;; *local* work would be lost — every git clone in the workspace must have no
;; local-only commits, a clean working tree, and no stashes.  These are checked
;; with real `git' invocations (not ref/fetch state, which has misled before).
;; If any check fails, nothing is killed or deleted.  Whether the work reached
;; production is out of scope; the guarantee is only "everything local is on
;; origin and clean".

(defun my/ccsm--close-topic-dir (session-dir)
  "Return the topic-workspace root for SESSION-DIR.
The nearest ancestor holding `my/ccsm-project-marker', else SESSION-DIR."
  (file-name-as-directory
   (expand-file-name
    (or (locate-dominating-file session-dir my/ccsm-project-marker)
        session-dir))))

(defun my/ccsm--close-topic-repos (topic-dir)
  "Return the git clones to vet before removing TOPIC-DIR.
TOPIC-DIR itself when it is a repo, else its immediate child repos."
  (if (file-directory-p (expand-file-name ".git" topic-dir))
      (list (file-name-as-directory topic-dir))
    (seq-filter
     (lambda (p) (and (file-directory-p p)
                      (file-directory-p (expand-file-name ".git" p))))
     (ignore-errors (directory-files topic-dir t "\\`[^.]")))))

(defun my/ccsm--git-run (dir args)
  "Run git ARGS in DIR; return (OK . TRIMMED-OUTPUT)."
  (let ((default-directory (file-name-as-directory dir)))
    (with-temp-buffer
      (let ((code (ignore-errors (apply #'process-file "git" nil t nil args))))
        (cons (eq code 0) (string-trim (buffer-string)))))))

(defun my/ccsm--close-topic-unsafe (repo)
  "Return the reasons REPO is unsafe to delete (nil = safe).
No local-only commits, clean working tree, no stashes; a failed `git'
invocation is itself unsafe (we could not verify)."
  (let (reasons)
    (pcase-dolist
        (`(,label . ,args)
         '(("local-only commits" "log" "--branches" "--not" "--remotes" "--oneline")
           ("uncommitted changes" "status" "--porcelain")
           ("stashed changes"     "stash" "list")))
      (let ((res (my/ccsm--git-run repo args)))
        (cond
         ((not (car res))
          (push (format "%s: `git %s' failed" label (string-join args " ")) reasons))
         ((not (string-empty-p (cdr res)))
          (push label reasons)))))
    (nreverse reasons)))

(defun my/ccsm--close-topic-audit (topic-dir)
  "Return an alist (REPO . REASONS) for every unsafe repo under TOPIC-DIR."
  (let (bad)
    (dolist (repo (my/ccsm--close-topic-repos topic-dir))
      (when-let ((reasons (my/ccsm--close-topic-unsafe repo)))
        (push (cons repo reasons) bad)))
    (nreverse bad)))

(defun my/ccsm--close-topic-kill-session (dir)
  "Terminate the Claude session for DIR (process, buffers, state).
Returns the list of buffer names killed."
  (let* ((name (my/ccsm--display-name dir))
         (bufname (claude-code-ide--get-buffer-name dir))
         (buf (get-buffer bufname))
         killed)
    (when (buffer-live-p buf)
      (let ((proc (get-buffer-process buf)))
        (when (process-live-p proc) (ignore-errors (delete-process proc))))
      (let ((kill-buffer-query-functions nil))
        (ignore-errors (kill-buffer buf)))
      (push bufname killed))
    ;; A manager-side buffer literally named after the topic, if any.
    (when-let ((tb (get-buffer name)))
      (let ((kill-buffer-query-functions nil))
        (ignore-errors (kill-buffer tb)))
      (push name killed))
    (ignore-errors (claude-code-ide--cleanup-on-exit dir))
    (when (fboundp 'my/ccsm--clear-waiting) (my/ccsm--clear-waiting dir))
    (when (boundp 'my/ccsm--docs) (remhash dir my/ccsm--docs))
    (when (equal dir my/ccsm--butler) (setq my/ccsm--butler nil))
    (when (fboundp 'my/ccsm--maybe-refresh) (my/ccsm--maybe-refresh))
    (nreverse killed)))

(defun my/ccsm--close-topic-deletable-p (dir)
  "Return non-nil when DIR is a plausible workspace dir to delete.
A backstop against obviously-wrong targets (home, root, .emacs.d, and
paths shallower than three components); the commit-safety gate is the
real guarantee."
  (let ((d (directory-file-name (expand-file-name dir))))
    (and (file-directory-p d)
         (> (length (split-string d "/" t)) 2)
         (not (member d (list (directory-file-name (expand-file-name "~"))
                              (directory-file-name (expand-file-name "~/.emacs.d"))
                              "/" "/home" "/root" "/tmp"))))))

;;;###autoload
(defun my/ccsm-close-topic (&optional force)
  "Close a topic: vet its repos, kill the session, delete the workspace.
Select a live session by name.  Unless FORCE (a prefix arg), refuse unless
every git clone in the workspace has no local-only commits, a clean working
tree, and no stashes — so no committed or staged work is lost.  Prod/remote
state is out of scope."
  (interactive "P")
  (let* ((sessions (my/ccsm--sessions))
         (names (mapcar (lambda (s) (my/ccsm--display-name (plist-get s :dir)))
                        sessions))
         (default (and (derived-mode-p 'my/ccsm-mode)
                       (my/ccsm--dir-at-point)
                       (my/ccsm--display-name (my/ccsm--dir-at-point))))
         (name (completing-read
                (format "Close topic%s: " (if force " (FORCE — skip safety)" ""))
                names nil t nil nil default))
         (dir (and name (seq-some
                         (lambda (s)
                           (let ((d (plist-get s :dir)))
                             (and (equal (my/ccsm--display-name d) name) d)))
                         sessions)))
         (topic-dir (and dir (my/ccsm--close-topic-dir dir))))
    (unless dir (user-error "No live session named %S" name))
    ;; 1) safety gate — abort before touching anything.
    (unless force
      (let ((bad (my/ccsm--close-topic-audit topic-dir)))
        (when bad
          (user-error
           "Refusing to close %s — unsafe, nothing killed or deleted:\n%s"
           name
           (mapconcat
            (lambda (cell)
              (format "  %s: %s"
                      (file-name-nondirectory (directory-file-name (car cell)))
                      (string-join (cdr cell) ", ")))
            bad "\n")))))
    (unless (yes-or-no-p
             (format "Kill session %s and DELETE %s%s? "
                     name topic-dir (if force " [FORCE: safety skipped]" "")))
      (user-error "Aborted"))
    ;; 2) kill session.
    (let* ((killed (my/ccsm--close-topic-kill-session dir))
           ;; Re-run the safety audit immediately before deletion, so state
           ;; that drifted between the gate and now (a background write, a new
           ;; stash) still blocks removal.  Skipped under FORCE.
           (recheck (unless force (my/ccsm--close-topic-audit topic-dir)))
           deleted skipped)
      ;; 3) delete workspace (only if still deletable and still safe).
      (cond
       ((not (my/ccsm--close-topic-deletable-p topic-dir))
        (setq skipped (format "refused unusual path %s" topic-dir)))
       (recheck
        (setq skipped
              (format "became unsafe just before deletion (%s) — NOT deleted"
                      (mapconcat (lambda (c)
                                   (file-name-nondirectory
                                    (directory-file-name (car c))))
                                 recheck ", "))))
       (t (ignore-errors (delete-directory topic-dir t))
          (setq deleted (not (file-exists-p topic-dir)))))
      ;; 4) report.
      (message "ccsm: closed %s — killed %s%s"
               name
               (if killed (string-join killed ", ") "(no buffers)")
               (cond (deleted (format "; deleted %s" topic-dir))
                     (skipped (format "; %s" skipped))
                     (t (format "; workspace NOT deleted (%s)" topic-dir)))))))

;; Reachable from the session manager and the LLM hydra.
(with-eval-after-load '32_2_claude_session_manager
  (when (boundp 'my/ccsm-mode-map)
    (define-key my/ccsm-mode-map "N" #'my/ccsm-new-topic)
    (define-key my/ccsm-mode-map "K" #'my/ccsm-close-topic)))

(provide '32_4_claude_workspace)
;;; 32_4_claude_workspace.el ends here
