;;; cc-butler.el --- Manage & orchestrate multiple Claude Code sessions  -*- lexical-binding: t; -*-

;; Author: Jeongsoo Park <jeongsoo@warmblood.kr>
;; Maintainer: Jeongsoo Park <jeongsoo@warmblood.kr>
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1") (claude-code-ide "0.2.7"))
;; Keywords: tools, processes, convenience
;; URL: https://github.com/toracle/cc-butler

;; This file is not part of GNU Emacs.

;;; Commentary:
;;
;; cc-butler is a cmux-like manager and control plane for running many
;; concurrent `claude-code-ide' sessions in one Emacs:
;;
;;   - a sticky left-hand list of live sessions (`M-x cc-butler');
;;   - per-session metadata a running Claude sets about itself over MCP;
;;   - topic workspaces (`cc-butler-new-topic' / `cc-butler-close-topic');
;;   - a butler/worker control plane, where one designated *butler* session
;;     drives the *worker* sessions and aggregates their events;
;;   - a per-session document panel (PRs, issues, CI runs, files) shown as a
;;     tab line beside the session;
;;   - a butler self-document repository (a regenerated dashboard plus an
;;     append-only daily log).
;;
;; This file only wires the modules together; each concern lives in its own
;; `cc-butler-*.el'.  See the README for the full picture.

;;; Code:

(defgroup cc-butler nil
  "Manage and orchestrate multiple Claude Code sessions."
  :group 'tools
  :prefix "cc-butler-")

(require 'cc-butler-session)
(require 'cc-butler-notifications)
(require 'cc-butler-workspace)
(require 'cc-butler-orchestrator)
(require 'cc-butler-doc-panel)
(require 'cc-butler-docs)

(provide 'cc-butler)
;;; cc-butler.el ends here
