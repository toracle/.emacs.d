# cc-butler

A cmux-like **manager and control plane** for running many concurrent
[`claude-code-ide`](https://github.com/manzaltu/claude-code-ide.el) sessions in
one Emacs — with a butler/worker orchestration layer, a per-session document
panel, and a self-maintained document repository.

> Formerly the personal `init-loader/32_*` "CCSM" drop-ins; now a standalone
> package.

## Features

- **Session list** (`M-x cc-butler`) — a sticky left side window listing every
  live session as a readable multi-line block (title / activity / status /
  branch + PR). Navigating previews the session's terminal.
- **Per-session metadata** — a running Claude sets its own title/status via the
  `set_session_info` MCP tool so you can track many sessions at a glance.
- **Topic workspaces** — `cc-butler-new-topic` scaffolds a workspace (clones +
  `.projectile`/`CLAUDE.md` markers) and launches a session; `cc-butler-close-topic`
  (`K`) tears one down safely (see below).
- **Butler / worker control plane** — designate one session the *butler* (`b`);
  it drives the workers through MCP tools (`list_claude_sessions`,
  `read_session_output`, `send_to_session`) and receives their events
  (`report_to_butler` → `pending_events`). Drive it from your phone; it becomes
  the situation room for the rest.
- **Document panel** — a running Claude opens a PR, issue, CI run, or file into
  a right-hand panel beside its terminal (`show_document`), shown as a **tab
  line**; the set is remembered per session. Forge-style: read-only with
  explicit actions (`C-c d n` comment, `C-c d w` browse).
- **Butler document repository** — the butler keeps a regenerated
  `dashboard.org` (sessions table auto-built from live state + overview + open
  decisions) and an append-only daily log under its home `docs/`, updated via
  `butler_log` / `butler_dashboard` and auto-captured worker events.

## Safe topic teardown

`cc-butler-close-topic` (`K`) will not delete a workspace unless **every** git
clone in it has no local-only commits, a clean working tree, and no stashes
(checked with real `git`; a git error counts as unsafe). If anything is unsafe,
nothing is killed or deleted. It re-runs the audit immediately before deletion
(drift guard). `C-u` forces (skips the safety check).

## Install

cc-butler is not on a package archive yet. Put it on your `load-path` and
require it:

```elisp
(add-to-list 'load-path "~/.emacs.d/cc-butler/")
(require 'cc-butler)
```

Requires Emacs 29.1+ and `claude-code-ide` (0.2.7+); the terminal backend is
ghostel (via claude-code-ide).

## Layout

| File | Role |
|------|------|
| `cc-butler.el` | Package entry: group + module wiring. |
| `cc-butler-session.el` | Session list UI, metadata, preview, `set_session_info`. |
| `cc-butler-notifications.el` | Notification event hook + input-waiting approval queue. |
| `cc-butler-workspace.el` | Topic workspace scaffolding + safe teardown. |
| `cc-butler-orchestrator.el` | Butler/worker orchestration (PULL/PUSH, inbox). |
| `cc-butler-doc-panel.el` | Per-session document panel (tab line). |
| `cc-butler-docs.el` | Butler self-document repository (dashboard + log). |

Entry point: `M-x cc-butler`.
