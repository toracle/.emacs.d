;;; 32_7_claude_butler_docs.el --- Butler self-document repository for CCSM  -*- lexical-binding: t; -*-

;; The butler is where every worker session's work converges — but that
;; convergence currently happens only in a chat stream that scrolls away, so
;; the actual state of the world is hard to grasp.  This module gives the
;; butler a durable *document repository* it maintains programmatically:
;;
;;   <butler-home>/docs/
;;     index.org            landing page (links)
;;     dashboard.org        CURRENT snapshot, regenerated on each update
;;     log/2026-07-01.org   per-day, append-only timeline
;;
;; Two document kinds, two update paths:
;;
;;   LOG (time axis)   — append-only.  Filled *automatically* from worker
;;                       events (every report/notification that flows through
;;                       `my/ccsm--inbox-push'), and *explicitly* by the butler
;;                       calling the `butler_log' MCP tool for curated
;;                       decisions/progress.
;;
;;   DASHBOARD (now)   — regenerated.  Its Sessions table is built from live
;;                       CCSM state (Emacs is the ground truth), merged with the
;;                       butler's free-text overview and open-decisions, which
;;                       it sets via the `butler_dashboard' MCP tool.
;;
;; Format is Org (rich in Emacs with zero setup; models timestamps/TODO/tables
;; natively; exports to Markdown/HTML via `ox-md'/`ox-html' when a published
;; site is wanted).  The two renderers below are the format seam: a Markdown
;; variant is a localized swap of `my/ccsm-butler-docs--render-log-entry',
;; `my/ccsm-butler-docs--render-dashboard', and `my/ccsm-butler-docs--ext'.
;;
;; Namespace `my/ccsm-butler-*' for now; renames to `claude-code-butler-*' when
;; CCSM is productized into a standalone package.

(require '32_2_claude_session_manager)
(require '32_5_claude_orchestrator)
(require '32_6_claude_doc_panel)
(require 'claude-code-ide)
(require 'subr-x)

;;;; ------------------------------------------------------------------
;;;; Location (anchored to the designated butler home)
;;;; ------------------------------------------------------------------

(defcustom my/ccsm-butler-docs-subdir "docs/"
  "Subdirectory of the butler home holding the document repository."
  :type 'string
  :group 'claude-code-ide)

(defcustom my/ccsm-butler-docs-log-subdir "log/"
  "Subdirectory of the docs dir holding per-day log files."
  :type 'string
  :group 'claude-code-ide)

(defcustom my/ccsm-butler-docs-auto-log t
  "When non-nil, worker events are appended to the daily log automatically."
  :type 'boolean
  :group 'claude-code-ide)

(defun my/ccsm-butler-docs--ext () "org")

(defun my/ccsm-butler-docs--home ()
  "Return the designated butler home directory, or nil."
  my/ccsm--butler)

(defun my/ccsm-butler-docs--docs-dir ()
  "Return the document-repository directory, or nil when no butler is set."
  (when-let ((home (my/ccsm-butler-docs--home)))
    (file-name-as-directory
     (expand-file-name my/ccsm-butler-docs-subdir home))))

(defun my/ccsm-butler-docs--log-dir ()
  "Return the log directory, or nil."
  (when-let ((docs (my/ccsm-butler-docs--docs-dir)))
    (file-name-as-directory (expand-file-name my/ccsm-butler-docs-log-subdir docs))))

(defun my/ccsm-butler-docs--log-file ()
  "Return today's log file path, or nil."
  (when-let ((dir (my/ccsm-butler-docs--log-dir)))
    (expand-file-name (format-time-string (concat "%Y-%m-%d." (my/ccsm-butler-docs--ext)))
                      dir)))

(defun my/ccsm-butler-docs--dashboard-file ()
  "Return the dashboard file path, or nil."
  (when-let ((docs (my/ccsm-butler-docs--docs-dir)))
    (expand-file-name (concat "dashboard." (my/ccsm-butler-docs--ext)) docs)))

(defun my/ccsm-butler-docs--index-file ()
  "Return the index file path, or nil."
  (when-let ((docs (my/ccsm-butler-docs--docs-dir)))
    (expand-file-name (concat "index." (my/ccsm-butler-docs--ext)) docs)))

;;;; ------------------------------------------------------------------
;;;; Rendering (the Org format seam)
;;;; ------------------------------------------------------------------

(defun my/ccsm-butler-docs--render-log-entry (kind entry)
  "Render a log ENTRY of KIND as an Org heading (timestamped, tagged)."
  (let* ((lines (split-string (string-trim (or entry "")) "\n"))
         (head (or (car lines) ""))
         (rest (cdr lines)))
    (concat
     (format "* %s %s :%s:\n"
             (format-time-string "[%Y-%m-%d %a %H:%M]") head kind)
     (when rest
       (concat (mapconcat (lambda (l) (concat "  " l)) rest "\n") "\n")))))

(defun my/ccsm-butler-docs--cell (s)
  "Sanitize S for use inside an Org table cell (no newlines or bars)."
  (replace-regexp-in-string
   "|" "/" (replace-regexp-in-string "[\n\r]+" " " (string-trim (or s "")))))

(defun my/ccsm-butler-docs--session-rows ()
  "Return Org table rows describing every live session, butler first."
  (let (rows)
    (dolist (s (my/ccsm--ordered (my/ccsm--sessions)))
      (let* ((dir (plist-get s :dir))
             (tag (cond ((equal dir my/ccsm--butler) " (butler)")
                        ((my/ccsm--waiting-p dir) " (waiting)")
                        (t "")))
             (state (if (my/ccsm--waiting-p dir) "WAITING" "running"))
             (branch (let ((b (plist-get s :branch))) (if (string-empty-p b) "-" b)))
             (pr (let ((f (plist-get s :forge))) (if (string-empty-p f) "-" f)))
             (act (let ((o (plist-get s :osc))) (if (string-empty-p o) "-" o))))
        (push (format "| %s%s | %s | %s | %s | %s |"
                      (my/ccsm-butler-docs--cell (my/ccsm--display-name dir))
                      tag state
                      (my/ccsm-butler-docs--cell branch)
                      (my/ccsm-butler-docs--cell pr)
                      (my/ccsm-butler-docs--cell act))
              rows)))
    (nreverse rows)))

(defvar my/ccsm-butler-docs--overview nil
  "The butler's free-text overview, shown on the dashboard.")
(defvar my/ccsm-butler-docs--decisions nil
  "The butler's open-decisions text, shown on the dashboard.")

(defun my/ccsm-butler-docs--render-dashboard ()
  "Render the dashboard Org document from live state + butler-set text."
  (let ((rows (my/ccsm-butler-docs--session-rows)))
    (concat
     "#+TITLE: Butler dashboard\n#+STARTUP: overview\n"
     (format "Last updated: %s\n\n" (format-time-string "[%Y-%m-%d %a %H:%M]"))
     "* Sessions\n"
     "| Session | State | Branch | PR | Activity |\n"
     "|---------+-------+--------+----+----------|\n"
     (if rows (concat (string-join rows "\n") "\n") "| (none) | - | - | - | - |\n")
     "\n* Overview\n"
     (if (and my/ccsm-butler-docs--overview
              (not (string-empty-p (string-trim my/ccsm-butler-docs--overview))))
         (concat (string-trim my/ccsm-butler-docs--overview) "\n")
       "(none yet)\n")
     "\n* Open decisions\n"
     (if (and my/ccsm-butler-docs--decisions
              (not (string-empty-p (string-trim my/ccsm-butler-docs--decisions))))
         (concat (string-trim my/ccsm-butler-docs--decisions) "\n")
       "(none yet)\n"))))

;;;; ------------------------------------------------------------------
;;;; Writers
;;;; ------------------------------------------------------------------

(defun my/ccsm-butler-docs--ensure-index ()
  "Create the docs index file if it does not exist yet.  Return its path."
  (when-let ((file (my/ccsm-butler-docs--index-file)))
    (make-directory (file-name-directory file) t)
    (unless (file-exists-p file)
      (write-region
       (concat "#+TITLE: Butler docs\n\n"
               "Operational document repository for the CCSM butler.\n\n"
               "- [[file:dashboard.org][Dashboard]] — current snapshot"
               " (sessions, overview, open decisions)\n"
               "- [[file:log/][Log]] — per-day, append-only timeline\n")
       nil file nil 'silent))
    file))

(defun my/ccsm-butler-docs--append-log (kind entry)
  "Append a KIND ENTRY to today's log file.  Return the path, or nil."
  (when-let ((dir (my/ccsm-butler-docs--log-dir)))
    (make-directory dir t)
    (let* ((file (my/ccsm-butler-docs--log-file))
           (new (not (file-exists-p file)))
           (text (concat
                  (when new
                    (format "#+TITLE: Butler log — %s\n#+STARTUP: showeverything\n\n"
                            (format-time-string "%Y-%m-%d")))
                  (my/ccsm-butler-docs--render-log-entry kind entry))))
      (write-region text nil file t 'silent)
      file)))

(defun my/ccsm-butler-docs--write-dashboard ()
  "(Re)write the dashboard file from current state.  Return the path, or nil."
  (when-let ((file (my/ccsm-butler-docs--dashboard-file)))
    (make-directory (file-name-directory file) t)
    (write-region (my/ccsm-butler-docs--render-dashboard) nil file nil 'silent)
    file))

;;;; ------------------------------------------------------------------
;;;; Automatic capture: worker events -> daily log
;;;; ------------------------------------------------------------------

(defun my/ccsm-butler-docs--auto-log (dir body)
  "Advice on `my/ccsm--inbox-push': mirror a worker event into the daily log."
  (when (and my/ccsm-butler-docs-auto-log (my/ccsm-butler-docs--home))
    (ignore-errors
      (my/ccsm-butler-docs--append-log
       "event" (format "%s — %s" (my/ccsm--who-dir dir) (or body ""))))))

(advice-add 'my/ccsm--inbox-push :after #'my/ccsm-butler-docs--auto-log)

;;;; ------------------------------------------------------------------
;;;; Viewing (open the dashboard in the butler's document panel)
;;;; ------------------------------------------------------------------

(defun my/ccsm-butler-open-dashboard ()
  "Regenerate and open the butler dashboard in its document panel."
  (interactive)
  (let ((home (my/ccsm-butler-docs--home)))
    (unless home (user-error "No butler designated (press `b' on a session)"))
    (my/ccsm-butler-docs--ensure-index)
    (my/ccsm-butler-docs--write-dashboard)
    (my/ccsm--doc-add home 'file
                      (concat my/ccsm-butler-docs-subdir
                              "dashboard." (my/ccsm-butler-docs--ext)))
    (my/ccsm--doc-refresh-layout home)))

(with-eval-after-load '32_2_claude_session_manager
  (when (boundp 'my/ccsm-mode-map)
    (define-key my/ccsm-mode-map "V" #'my/ccsm-butler-open-dashboard)))

;;;; ------------------------------------------------------------------
;;;; MCP tools (the butler's hands on its own docs)
;;;; ------------------------------------------------------------------

(defun my/ccsm-butler-tool-log (entry &optional kind)
  "MCP tool: append an ENTRY (of optional KIND) to the butler's daily log."
  (unless (my/ccsm-butler-docs--home)
    (error "No butler designated in the session manager (press `b' on a session)"))
  (unless (and entry (stringp entry) (not (string-empty-p (string-trim entry))))
    (error "A log entry is required"))
  (let* ((k (let ((c (and kind (downcase (string-trim kind)))))
              (if (member c '("event" "decision" "progress" "note")) c "note"))))
    (my/ccsm-butler-docs--ensure-index)
    (let ((file (my/ccsm-butler-docs--append-log k entry)))
      (format "Logged (%s) to %s" k (abbreviate-file-name file)))))

(defun my/ccsm-butler-tool-dashboard (&optional overview decisions)
  "MCP tool: update the butler dashboard's OVERVIEW and/or DECISIONS text.
The Sessions table is always regenerated from live CCSM state."
  (unless (my/ccsm-butler-docs--home)
    (error "No butler designated in the session manager (press `b' on a session)"))
  (when (and overview (stringp overview))
    (setq my/ccsm-butler-docs--overview overview))
  (when (and decisions (stringp decisions))
    (setq my/ccsm-butler-docs--decisions decisions))
  (my/ccsm-butler-docs--ensure-index)
  (let ((file (my/ccsm-butler-docs--write-dashboard)))
    (format "Dashboard updated (%d live sessions): %s"
            (length (my/ccsm--sessions))
            (abbreviate-file-name file))))

;; Idempotent (re)registration.
(setq claude-code-ide-mcp-server-tools
      (seq-remove
       (lambda (spec)
         (member (plist-get (claude-code-ide--normalize-tool-spec spec) :name)
                 '("butler_log" "butler_dashboard")))
       claude-code-ide-mcp-server-tools))

(claude-code-ide-make-tool
 :function #'my/ccsm-butler-tool-log
 :name "butler_log"
 :description "Append a timestamped entry to the butler's append-only daily log (docs/log/YYYY-MM-DD.org under the butler home). Use it to record decisions you made, progress worth remembering, or notes — the durable timeline that survives the chat scrolling away. Worker reports/notifications are logged automatically; use this for the curated, higher-signal entries. Call it when something happens that future-you (or a fresh context) should be able to reconstruct."
 :args '((:name "entry"
                :type string
                :description "The log entry text (one or more lines). Be concrete: what happened, what was decided, why.")
         (:name "kind"
                :type string
                :description "Entry kind: 'decision', 'progress', 'event', or 'note' (default 'note'). Optional."
                :optional t)))

(claude-code-ide-make-tool
 :function #'my/ccsm-butler-tool-dashboard
 :name "butler_dashboard"
 :description "Update the butler's at-a-glance dashboard (docs/dashboard.org under the butler home). The per-session status table (running/waiting, branch, PR, current activity) is regenerated automatically from live session state — you do NOT supply it. You supply the human judgment: a short OVERVIEW of the current situation and the list of OPEN DECISIONS awaiting input. Call it whenever the big picture changes so the snapshot stays current. Omitting an argument keeps its previous text."
 :args '((:name "overview"
                :type string
                :description "Short free-text overview of the current situation across all sessions. Optional; omit to keep the previous overview."
                :optional t)
         (:name "decisions"
                :type string
                :description "The open decisions / questions awaiting a human, one per line. Optional; omit to keep the previous list."
                :optional t)))

(provide '32_7_claude_butler_docs)
;;; 32_7_claude_butler_docs.el ends here
