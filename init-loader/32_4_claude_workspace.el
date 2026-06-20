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
            (insert (format "@%s\n" imp))))))
    topic-dir))

(defun my/ccsm--start-session-in (dir)
  "Start a Claude session with DIR as the working directory."
  (let ((default-directory (file-name-as-directory (expand-file-name dir))))
    (claude-code-ide)))

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

;; Reachable from the session manager and the LLM hydra.
(with-eval-after-load '32_2_claude_session_manager
  (when (boundp 'my/ccsm-mode-map)
    (define-key my/ccsm-mode-map "N" #'my/ccsm-new-topic)))

(provide '32_4_claude_workspace)
;;; 32_4_claude_workspace.el ends here
