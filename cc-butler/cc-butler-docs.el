;;; cc-butler-docs.el --- Butler self-document repository for cc-butler  -*- lexical-binding: t; -*-

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
;;                       `cc-butler--inbox-push'), and *explicitly* by the butler
;;                       calling the `butler_log' MCP tool for curated
;;                       decisions/progress.
;;
;;   DASHBOARD (now)   — regenerated.  Its Sessions table is built from live
;;                       cc-butler state (Emacs is the ground truth), merged with the
;;                       butler's free-text overview and open-decisions, which
;;                       it sets via the `butler_dashboard' MCP tool.
;;
;; Format is Org (rich in Emacs with zero setup; models timestamps/TODO/tables
;; natively; exports to Markdown/HTML via `ox-md'/`ox-html' when a published
;; site is wanted).  The two renderers below are the format seam: a Markdown
;; variant is a localized swap of `cc-butler-docs--render-log-entry',
;; `cc-butler-docs--render-dashboard', and `cc-butler-docs--ext'.
;;
;; Namespace `cc-butler-*' for now; renames to `claude-code-butler-*' when
;; cc-butler is productized into a standalone package.

(require 'cc-butler-session)
(require 'cc-butler-orchestrator)
(require 'cc-butler-doc-panel)
(require 'claude-code-ide)
(require 'subr-x)

;;;; ------------------------------------------------------------------
;;;; Location (anchored to the designated butler home)
;;;; ------------------------------------------------------------------

(defcustom cc-butler-docs-subdir "docs/"
  "Subdirectory of the butler home holding the document repository."
  :type 'string
  :group 'cc-butler)

(defcustom cc-butler-docs-log-subdir "log/"
  "Subdirectory of the docs dir holding per-day log files."
  :type 'string
  :group 'cc-butler)

(defcustom cc-butler-docs-auto-log t
  "When non-nil, worker events are appended to the daily log automatically."
  :type 'boolean
  :group 'cc-butler)

(defun cc-butler-docs--ext () "org")

(defun cc-butler-docs--home ()
  "Return the designated butler home directory, or nil."
  cc-butler--butler)

(defun cc-butler-docs--docs-dir ()
  "Return the document-repository directory, or nil when no butler is set."
  (when-let ((home (cc-butler-docs--home)))
    (file-name-as-directory
     (expand-file-name cc-butler-docs-subdir home))))

(defun cc-butler-docs--log-dir ()
  "Return the log directory, or nil."
  (when-let ((docs (cc-butler-docs--docs-dir)))
    (file-name-as-directory (expand-file-name cc-butler-docs-log-subdir docs))))

(defun cc-butler-docs--log-file ()
  "Return today's log file path, or nil."
  (when-let ((dir (cc-butler-docs--log-dir)))
    (expand-file-name (format-time-string (concat "%Y-%m-%d." (cc-butler-docs--ext)))
                      dir)))

(defun cc-butler-docs--dashboard-file ()
  "Return the dashboard file path, or nil."
  (when-let ((docs (cc-butler-docs--docs-dir)))
    (expand-file-name (concat "dashboard." (cc-butler-docs--ext)) docs)))

(defun cc-butler-docs--index-file ()
  "Return the index file path, or nil."
  (when-let ((docs (cc-butler-docs--docs-dir)))
    (expand-file-name (concat "index." (cc-butler-docs--ext)) docs)))

;;;; ------------------------------------------------------------------
;;;; Rendering (the Org format seam)
;;;; ------------------------------------------------------------------

(defun cc-butler-docs--render-log-entry (kind entry)
  "Render a log ENTRY of KIND as an Org heading (timestamped, tagged)."
  (let* ((lines (split-string (string-trim (or entry "")) "\n"))
         (head (or (car lines) ""))
         (rest (cdr lines)))
    (concat
     (format "* %s %s :%s:\n"
             (format-time-string "[%Y-%m-%d %a %H:%M]") head kind)
     (when rest
       (concat (mapconcat (lambda (l) (concat "  " l)) rest "\n") "\n")))))

(defun cc-butler-docs--cell (s)
  "Sanitize S for use inside an Org table cell (no newlines or bars)."
  (replace-regexp-in-string
   "|" "/" (replace-regexp-in-string "[\n\r]+" " " (string-trim (or s "")))))

(defun cc-butler-docs--session-rows ()
  "Return Org table rows describing every live session, butler first."
  (let (rows)
    (dolist (s (cc-butler--ordered (cc-butler--sessions)))
      (let* ((dir (plist-get s :dir))
             (tag (cond ((equal dir cc-butler--butler) " (butler)")
                        ((cc-butler--waiting-p dir) " (waiting)")
                        (t "")))
             (state (if (cc-butler--waiting-p dir) "WAITING" "running"))
             (branch (let ((b (plist-get s :branch))) (if (string-empty-p b) "-" b)))
             (pr (let ((f (plist-get s :forge))) (if (string-empty-p f) "-" f)))
             (act (let ((o (plist-get s :osc))) (if (string-empty-p o) "-" o))))
        (push (format "| %s%s | %s | %s | %s | %s |"
                      (cc-butler-docs--cell (cc-butler--display-name dir))
                      tag state
                      (cc-butler-docs--cell branch)
                      (cc-butler-docs--cell pr)
                      (cc-butler-docs--cell act))
              rows)))
    (nreverse rows)))

(defvar cc-butler-docs--overview nil
  "The butler's free-text overview, shown on the dashboard.")
(defvar cc-butler-docs--decisions nil
  "The butler's open-decisions text, shown on the dashboard.")

(defun cc-butler-docs--render-dashboard ()
  "Render the dashboard Org document from live state + butler-set text."
  (let ((rows (cc-butler-docs--session-rows)))
    (concat
     "#+TITLE: Butler dashboard\n#+STARTUP: overview\n"
     (format "Last updated: %s\n\n" (format-time-string "[%Y-%m-%d %a %H:%M]"))
     "* Sessions\n"
     "| Session | State | Branch | PR | Activity |\n"
     "|---------+-------+--------+----+----------|\n"
     (if rows (concat (string-join rows "\n") "\n") "| (none) | - | - | - | - |\n")
     "\n* Overview\n"
     (if (and cc-butler-docs--overview
              (not (string-empty-p (string-trim cc-butler-docs--overview))))
         (concat (string-trim cc-butler-docs--overview) "\n")
       "(none yet)\n")
     "\n* Open decisions\n"
     (if (and cc-butler-docs--decisions
              (not (string-empty-p (string-trim cc-butler-docs--decisions))))
         (concat (string-trim cc-butler-docs--decisions) "\n")
       "(none yet)\n"))))

;;;; ------------------------------------------------------------------
;;;; Writers
;;;; ------------------------------------------------------------------

(defun cc-butler-docs--ensure-index ()
  "Create the docs index file if it does not exist yet.  Return its path."
  (when-let ((file (cc-butler-docs--index-file)))
    (make-directory (file-name-directory file) t)
    (unless (file-exists-p file)
      (write-region
       (concat "#+TITLE: Butler docs\n\n"
               "Operational document repository for the cc-butler butler.\n\n"
               "- [[file:dashboard.org][Dashboard]] — current snapshot"
               " (sessions, overview, open decisions)\n"
               "- [[file:log/][Log]] — per-day, append-only timeline\n")
       nil file nil 'silent))
    file))

(defun cc-butler-docs--append-log (kind entry)
  "Append a KIND ENTRY to today's log file.  Return the path, or nil."
  (when-let ((dir (cc-butler-docs--log-dir)))
    (make-directory dir t)
    (let* ((file (cc-butler-docs--log-file))
           (new (not (file-exists-p file)))
           (text (concat
                  (when new
                    (format "#+TITLE: Butler log — %s\n#+STARTUP: showeverything\n\n"
                            (format-time-string "%Y-%m-%d")))
                  (cc-butler-docs--render-log-entry kind entry))))
      (write-region text nil file t 'silent)
      file)))

(defun cc-butler-docs--write-dashboard ()
  "(Re)write the dashboard file from current state.  Return the path, or nil."
  (when-let ((file (cc-butler-docs--dashboard-file)))
    (make-directory (file-name-directory file) t)
    (write-region (cc-butler-docs--render-dashboard) nil file nil 'silent)
    file))

;;;; ------------------------------------------------------------------
;;;; Automatic capture: worker events -> daily log
;;;; ------------------------------------------------------------------

(defun cc-butler-docs--auto-log (dir body)
  "Advice on `cc-butler--inbox-push': mirror a worker event into the daily log."
  (when (and cc-butler-docs-auto-log (cc-butler-docs--home))
    (ignore-errors
      (cc-butler-docs--append-log
       "event" (format "%s — %s" (cc-butler--who-dir dir) (or body ""))))))

(advice-add 'cc-butler--inbox-push :after #'cc-butler-docs--auto-log)

;;;; ------------------------------------------------------------------
;;;; Viewing (open the dashboard in the butler's document panel)
;;;; ------------------------------------------------------------------

(defun cc-butler-open-dashboard ()
  "Regenerate and open the butler dashboard in its document panel."
  (interactive)
  (let ((home (cc-butler-docs--home)))
    (unless home (user-error "No butler designated (press `b' on a session)"))
    (cc-butler-docs--ensure-index)
    (cc-butler-docs--write-dashboard)
    (cc-butler--doc-add home 'file
                      (concat cc-butler-docs-subdir
                              "dashboard." (cc-butler-docs--ext)))
    (cc-butler--doc-refresh-layout home)))

(with-eval-after-load 'cc-butler-session
  (when (boundp 'cc-butler-mode-map)
    (define-key cc-butler-mode-map "V" #'cc-butler-open-dashboard)))

;;;; ------------------------------------------------------------------
;;;; MCP tools (the butler's hands on its own docs)
;;;; ------------------------------------------------------------------

(defun cc-butler-tool-log (entry &optional kind)
  "MCP tool: append an ENTRY (of optional KIND) to the butler's daily log."
  (unless (cc-butler-docs--home)
    (error "No butler designated in the session manager (press `b' on a session)"))
  (unless (and entry (stringp entry) (not (string-empty-p (string-trim entry))))
    (error "A log entry is required"))
  (let* ((k (let ((c (and kind (downcase (string-trim kind)))))
              (if (member c '("event" "decision" "progress" "note")) c "note"))))
    (cc-butler-docs--ensure-index)
    (let ((file (cc-butler-docs--append-log k entry)))
      (format "Logged (%s) to %s" k (abbreviate-file-name file)))))

(defun cc-butler-tool-dashboard (&optional overview decisions)
  "MCP tool: update the butler dashboard's OVERVIEW and/or DECISIONS text.
The Sessions table is always regenerated from live cc-butler state."
  (unless (cc-butler-docs--home)
    (error "No butler designated in the session manager (press `b' on a session)"))
  (when (and overview (stringp overview))
    (setq cc-butler-docs--overview overview))
  (when (and decisions (stringp decisions))
    (setq cc-butler-docs--decisions decisions))
  (cc-butler-docs--ensure-index)
  (let ((file (cc-butler-docs--write-dashboard)))
    (format "Dashboard updated (%d live sessions): %s"
            (length (cc-butler--sessions))
            (abbreviate-file-name file))))

;; Idempotent (re)registration.
(setq claude-code-ide-mcp-server-tools
      (seq-remove
       (lambda (spec)
         (member (plist-get (claude-code-ide--normalize-tool-spec spec) :name)
                 '("butler_log" "butler_dashboard")))
       claude-code-ide-mcp-server-tools))

(claude-code-ide-make-tool
 :function #'cc-butler-tool-log
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
 :function #'cc-butler-tool-dashboard
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

(provide 'cc-butler-docs)
;;; cc-butler-docs.el ends here
