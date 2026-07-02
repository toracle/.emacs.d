# cc-butler — Claude Code Session Manager

A lightweight, cmux-like manager for running **many concurrent
`claude-code-ide` sessions** inside one Emacs, with a sticky side list, live
per-session metadata, OS-/remote-friendly notifications, topic-workspace
scaffolding, and a **butler/worker control plane** you can drive from your
phone.

It is a standalone Emacs Lisp package under [`cc-butler/`](../cc-butler/)
(extracted from the old `init-loader/32_*` "CCSM" drop-ins), loaded via
`(require 'cc-butler)`. See also the package [README](../cc-butler/README.md).

> Entry point: `M-x cc-butler`.

---

## 1. File map

The package is `cc-butler.el` (entry: group + `require`s) plus one file per
concern. Each `(require ...)`s the modules it depends on.

| File | Role |
|------|------|
| [`cc-butler.el`](../cc-butler/cc-butler.el) | Package entry: the `cc-butler` group and module wiring. |
| [`cc-butler-session.el`](../cc-butler/cc-butler-session.el) | **Core.** Session enumeration, the side-list UI, per-session metadata, navigation/preview, and the `set_session_info` tool. |
| [`cc-butler-notifications.el`](../cc-butler/cc-butler-notifications.el) | Turns ghostel's single notification callback into a **decoupled event hook**; ships the input-waiting **approval queue** and opt-in listeners. |
| [`cc-butler-workspace.el`](../cc-butler/cc-butler-workspace.el) | **Topic-workspace** scaffolding + safe teardown (`cc-butler-close-topic`). |
| [`cc-butler-orchestrator.el`](../cc-butler/cc-butler-orchestrator.el) | **Butler/worker** orchestration: a designated *butler* session drives *workers* through Emacs (PULL tools + PUSH forwarding). |
| [`cc-butler-doc-panel.el`](../cc-butler/cc-butler-doc-panel.el) | **Per-session document panel** (tab line): PRs/issues/runs/files beside a session. |
| [`cc-butler-docs.el`](../cc-butler/cc-butler-docs.el) | **Butler self-document repository**: dashboard + append-only daily log. |

The generic buffer MCP tools (`list_buffers`, `get_buffer_content`) remain a
separate init-loader drop-in
([`32_1_claude_custom_tools.el`](../init-loader/32_1_claude_custom_tools.el)) —
not part of cc-butler. All MCP tools are registered against
`claude-code-ide-mcp-server` and exposed to the running Claude through the Emacs
MCP bridge.

---

## 2. Core concepts

### Session
A **session** is one live `claude-code-ide` process. The canonical key is its
**working directory** (`dir`); cc-butler looks sessions up in
`claude-code-ide--processes` and `claude-code-ide--session-ids`.

### Display name (the `.projectile` walk)
A session's name is the basename of the **nearest ancestor directory
containing `.projectile`** (`cc-butler-project-marker`), falling back to the
working directory's own basename — see `cc-butler--display-name`. This is the
single source of truth shared by the buffer name (`cc-butler-buffer-name`, wired
into `claude-code-ide-buffer-name-function`) and the list title. The effect:
sessions launched in sibling repos of a *topic workspace* all collapse to the
**topic's** name instead of each repo's name.

### Per-session metadata (Claude sets it about itself)
`cc-butler--meta` maps `dir → plist` with `:title`, `:status`, `:updated`. The
running Claude updates its own row by calling the **`set_session_info`** MCP
tool (see §8). This is how a session announces "what I am" and "what I'm doing
right now" to the human.

### Auxiliary info
- **Git branch** — `cc-butler--git-branch`, cached 5s to avoid spawning `git` on
  every redraw.
- **PR number** — `cc-butler--forge-fetch` shells out to `gh pr view` **async**
  and caches `"PR #NN"` per dir. Gated by `cc-butler-enable-forge`.
- **OSC terminal title** — `cc-butler--osc-title` reads ghostel's live OSC-2
  title (the task summary Claude emits as it works) straight off the term
  object, even though claude-code-ide disables title-based renaming.

---

## 3. Window layout

```
+------------------+--------------------------------------+
|  *claude-sessions* |                                    |
|  (side window,     |   selected session's terminal      |
|   left, slot 0,    |   (cc-butler--main-window)           |
|   width 40,        |                                    |
|   dedicated)       |                                    |
+------------------+--------------------------------------+
```

`cc-butler` runs `delete-other-windows`, displays the list buffer with
`display-buffer-in-side-window` (left, dedicated, `cc-butler-list-width`), and
keeps a single **main window** (`cc-butler--main-window`) for terminals.
Navigating the list **swaps the main window's buffer** with
`set-window-buffer` rather than popping new windows.

Because `set-window-buffer` does not fire `window-size-change-functions`,
`cc-butler--terminal-resize` explicitly drives `ghostel--adjust-size` (sizing the
PTY to the *largest* window showing the session) so the preview isn't a stale
or clipped frame.

---

## 4. The session list UI (`cc-butler-mode`)

Each session renders as a **multi-line block** so it stays readable in a narrow
window:

```
★ billing: invoice PDF        ← title (★ butler / ⏳ waiting / ● running)
   writing the PDF renderer   ← OSC terminal title (italic)
   waiting on review          ← status line (set via set_session_info)
   ⎇ feature/pdf   PR #42     ← branch + forge
```

**Ordering** (`cc-butler--ordered`, a stable sort):
1. The **butler** session is pinned to the very top (`★`).
2. Sessions **awaiting input** form a FIFO **approval queue** (`⏳`, oldest
   request first).
3. Everything else keeps natural order.

The selected block is tracked with a `highlight` overlay (`cc-butler--highlight`).

### Live updates
The list re-renders itself (debounced 0.3s, only when visible) on:
- **terminal title changes** — `:after` advice on `ghostel--set-title`;
- **session start/stop** — `:after` advice on `claude-code-ide--set-process`
  and `claude-code-ide--cleanup-on-exit`;
- **forge fetch completion**.

### Keybindings (`cc-butler-mode-map`)

| Key | Command | Action |
|-----|---------|--------|
| `n` / `p`, `↓`/`↑`, `C-n`/`C-p` | `cc-butler-next` / `cc-butler-prev` | Move + preview the session |
| `SPC` | `cc-butler-preview` | Preview in the main window, stay in the list |
| `RET` | `cc-butler-visit` | Preview, **select** the terminal, clear it from the wait queue |
| `g` | `cc-butler-refresh` | Re-render + re-fetch forge info |
| `c` | `cc-butler-new-session` | Start a session in a chosen directory |
| `N` | `cc-butler-new-topic` | Create a **topic workspace** (§6) |
| `K` | `cc-butler-close-topic` | Safely close a topic: vet, kill session, delete workspace (§6) |
| `b` | `cc-butler-set-butler` | Toggle the session at point as **butler** (§7) |
| `l` | `cc-butler-show-log` | Pop to the `*cc-butler-log*` message log |
| `q` | `cc-butler-quit` | Close the side window |

---

## 5. Notifications & the approval queue (`notifications`)

Claude Code raises a terminal notification (OSC 9 / OSC 777) when its agent
loop ends or it needs you. ghostel routes that to a single
`ghostel-notification-function`, which is awkward for a **headless daemon over
SSH** (no local tray).

`notifications` takes over that callback and re-emits it as an **abnormal hook**,
`cc-butler-notification-functions`, whose listeners each receive an EVENT plist
(`:type :title :body :buffer :session :name`). ghostel's prior notifier is
**chained**, so a local GUI Emacs keeps its tray popup for free.

- **Built-in listener — approval queue** (`cc-butler--queue-on-notification`): a
  notifying session is marked *waiting* (`cc-butler--mark-waiting`) and pushed to
  the butler **inbox**, bubbling it to the top of the list. Visiting it (`RET`)
  clears it.
- **Opt-in listeners** (pick per environment; none on by default):
  - `cc-butler-notify-echo` — echo-area/`*Messages*` (testing);
  - `cc-butler-notify-desktop` — local D-Bus/OS desktop notification;
  - `cc-butler-notify-command-listener` — run a shell template
    (`cc-butler-notify-command`, `%t`/`%b` = title/body) for a remote messenger
    CLI, async.

---

## 6. Topic workspaces (`workspace`)

A **topic workspace** is a plain (non-git) directory that holds one or more
checked-out repos plus two markers:

- **`.projectile`** — makes projectile treat the topic dir as one project (all
  sibling repos visible without `/add-dir`) and makes cc-butler name the session
  after the topic.
- **`CLAUDE.md`** — a thin file that `@`-imports the meta repo's shared docs
  (e.g. `monocle/CLAUDE.md`, `monocle/DESIGN.md`) and appends a short
  "reporting to the butler" note, so launching Claude there loads the project's
  architecture at startup.

Layouts live in **data**: `cc-butler-project-templates`, an alist of
`(NAME . PLIST)` with `:base-dir :dir-format :repos :claude-import`. Adding a
project is just another entry. `M-x cc-butler-new-topic` (or `N`) prompts for a
template (or `arbitrary`, which falls back to `cc-butler-new-session`) and a
topic name, clones the repos **async/sequentially** (skipping present ones),
scaffolds the markers, and launches the session.

### Closing a topic (`cc-butler-close-topic`, `K`)
The inverse of `new-topic`. Pick a live session; before removing anything it
**proves no local work would be lost** — every git clone in the workspace must
have no local-only commits (`git log --branches --not --remotes`), a clean
working tree (`git status --porcelain`), and no stashes (`git stash list`),
checked with real `git` (a git error also counts as unsafe). If **any** clone
fails **any** check, nothing is killed or deleted and the reasons are reported.
On pass + confirmation it kills the session (terminal process + buffers,
`claude-code-ide--cleanup-on-exit`, clears waiting/docs/butler state),
**re-runs the audit immediately before deletion** (drift guard), then deletes
the workspace (home/root/shallow paths refused). `C-u` forces (skips safety).
Scope: local-loss prevention only — prod/remote state is out of scope.

---

## 7. Butler / worker orchestration (`orchestrator`)

cc-butler becomes a **control plane**: one designated **butler** session drives the
**worker** sessions, with **Emacs as the bus** (workers are reached through
their ghostel shells). You remote-control *one* session — the butler — from
your phone, and it becomes the situation room for the rest. Designate it with
`b` in the manager (`cc-butler--butler`, pinned to top).

Two directions:

- **PULL** — the butler actively inspects/commands workers via MCP tools:
  - `list_claude_sessions` — what's running, who's `WAITING-FOR-INPUT`,
    branches, activity titles;
  - `read_session_output` — a worker's recent terminal screen (force-refreshed
    from the live ghostel grid first, so even a backgrounded buffer is current);
  - `send_to_session` — type a prompt into a worker and submit it (multi-line
    delivered as a bracketed paste so only the final Return submits; ESC bytes
    stripped).
- **PUSH** — when a worker posts a notification, `cc-butler--forward-to-butler`
  types a one-line summary into the butler's terminal (and optionally submits
  it). Controlled by `cc-butler-forward` (`nil` / `notify` / `submit`).

### The inbox / report path
Workers can also report **up** with real content via `report_to_butler`
(`summary` / `status` / `needs`). Reports and forwarded events queue in
`cc-butler--inbox` and are drained by the butler calling `pending_events` — so
the butler learns what changed **without anything being typed into its input
box**. All butler↔worker traffic is teed to the `*cc-butler-log*` buffer
(`cc-butler-show-log`, `l`), tagged with each session's name + id.

---

## 8. Per-session document panel (`doc-panel`)

A session's TUI output scrolls away and is poor for holding the *context* a
task needs — the PR under review, the issue it closes, the CI run that failed,
a design doc. The **document panel** gives each session a right-hand vertical
split, **nested inside that session's area**, holding a set of rendered
documents:

```
+----------+---------------------------------+
| sessions |  terminal      |   document     |  ← per-session child split
|  list    |  (the session) |    panel       |
+----------+---------------------------------+
```

The panel is **bound to the session**: its document set is keyed by working-dir
in `cc-butler--docs` (`:items` / `:current` / `:open`), so switching away and
back restores the same documents at the same selection. The doc window is
always a split to the **right of `cc-butler--main-window`** (tracked as
`cc-butler--doc-window`), reconciled on every preview by
`cc-butler--apply-doc-layout` (hung on `cc-butler-after-preview-functions`): show
the split iff the session has an open, non-empty panel; tear it down otherwise.
Because the split narrows the terminal window, the PTY is resized afterward.

The panel's open documents appear as a **tab line** at the top of the doc
window — one clickable tab per document (labeled by `:label`), the active tab
being the shown one, and a close button removing it. The tab line is attached
to the doc *window* via its `tab-line-format` window parameter (not
`tab-line-mode`, which is buffer-local and would leak the tabs into any other
window showing the same file); it reuses tab-line's built-in
renderer/mouse/close, driven by buffer-local `tab-line-tabs-function` etc. on
each doc buffer, with `cc-butler--doc-sync-current` (on
`window-buffer-change-functions`) keeping `:current` in step when a tab is
clicked. There is **no header line** — navigation is the tab line, actions are
`C-c d`.

**Documents** are fetched on demand:

| Kind | Source |
|------|--------|
| `pr` | `gh pr view REF --comments` |
| `issue` | `gh issue view REF --comments` |
| `run` | `gh run view REF` (workflow run) |
| `file` | a local file (path relative to the working dir), visited directly |

`gh` kinds render **async** into a read-only `cc-butler-doc-mode` buffer. stdout
and stderr are captured **separately** so gh's progress spinner never pollutes
a clean render, and `cc-butler--strip-ansi` removes terminal control sequences;
on failure stderr is shown so the error is still visible. `file` kinds open the
real file buffer **read-only** (`cc-butler-doc-file-mode`, forge-style), with
`C-c C-e` to toggle editability. Re-opening an existing doc re-selects (and
re-fetches) it rather than duplicating.

Panel buffers **wrap** long lines unconditionally (`truncate-lines` and
`truncate-partial-width-windows` both nil, `word-wrap` t), so wide content —
markdown tables especially — reflows instead of being cut off the right edge,
even when the panel is narrow (e.g. a remote/phone-sized frame, where a
side-by-side window under 50 columns would otherwise force truncation).

### Multi-repo topic workspaces
A topic-workspace root is not itself a git repo — the repos are child
directories. For gh kinds, `cc-butler--doc-git-dir` resolves the working
directory: an enclosing repo if there is one, the sole child repo if unique,
otherwise it reports the **ambiguous** set. The `show_document` tool then takes
an optional **`repo`** argument naming the child repo; omitting it on a
multi-repo workspace returns the list to choose from.

### Reading vs. acting (forge-style)
The panel keeps documents **read-only** and gates actions behind explicit keys
(borrowing forge's model): `C-c C-n` composes a comment in a
`cc-butler-doc-compose-mode` buffer and posts it with `C-c C-c` via
`gh pr/issue comment --body-file`; `w` / `C-c C-o` opens the item on the web
(`gh … view --web`).

### Driving the panel
The running Claude opens documents into **its own** panel via the
**`show_document`** MCP tool (`kind` + `ref` + optional `repo`). The human
drives it from the session list, from a doc buffer, or from anywhere via the
global **`C-c d`** prefix:

| Key | Command | Action |
|-----|---------|--------|
| tab click / `]` `[` | `cc-butler-doc-next` / `-prev` | Select / cycle documents |
| tab `×` / `k` `D` | `cc-butler-doc-remove` | Drop a document (kills gh buffers; only unlinks files) |
| `o` | `cc-butler-doc-open` | Prompt for kind/ref (and repo if needed), open into the selected session |
| `d` | `cc-butler-doc-toggle` | Show/hide the panel |
| `z` *(C-c d)* / `q` *(doc buf)* | `cc-butler-doc-hide` | Hide the panel and **zoom** into the terminal |
| `g` | `cc-butler-doc-revert` | Re-fetch the current gh doc |
| `w` | `cc-butler-doc-browse` | Open the current gh doc on the web |
| `n` *(C-c d)* / `C-c C-n` | `cc-butler-doc-comment` | Compose a comment on the current PR/issue |

Documents are navigated/closed via the **tab line**; panel and gh actions via
the global **`C-c d`** prefix (`d z ] [ o g k n w`) — no header line. `n`/`w`
from `C-c d` act on the visible session's current document, so they work from
the terminal too. `cc-butler-doc-width` (default `nil` = half) sets the width.

---

## 9. Butler self-document repository (`docs`)

The butler is where every worker's work converges, but that convergence lived
only in a scrolling chat stream. `docs` gives the butler a durable document
repository it maintains **programmatically**, under
`<butler-home>/docs/` (butler home = `cc-butler--butler`, e.g. `~/.cc-butler/`):

```
<butler-home>/docs/
  index.org            landing page
  dashboard.org        CURRENT snapshot (regenerated on update)
  log/2026-07-01.org   per-day, append-only timeline
```

- **Log (time axis)** — append-only. Filled *automatically* by advice on
  `cc-butler--inbox-push` (every worker report/notification), and *explicitly* by
  the butler calling **`butler_log`** for curated decisions/progress.
- **Dashboard (now)** — regenerated. Its Sessions table is built from **live
  cc-butler state** (`cc-butler--sessions` + waiting/branch/PR/activity), merged with
  the butler's overview and open-decisions set via **`butler_dashboard`**
  (omitted args keep their previous text).

Format is **Org** (rich in Emacs with zero setup; native timestamps/TODO/tables;
exports to Markdown/HTML via `ox-md`/`ox-html`). The renderers and
`cc-butler-docs--ext` are the format seam for a later Markdown swap. The
butler passes plain prose; the elisp emits the Org scaffolding, so format
fidelity is not on the agent. Open it with `V` in the manager (regenerate +
show in the panel), or `show_document file docs/dashboard.org`.

Customs: `cc-butler-docs-subdir` (`"docs/"`), `-log-subdir` (`"log/"`),
`-auto-log` (`t`).

See also the productization journal: [cc-butler-worklog.md](cc-butler-worklog.md).

---

## 10. MCP tools reference

Tools the running Claude can call through the Emacs bridge. Registration is
**idempotent** (each file removes prior copies of its tool names before
re-adding, so reloads don't duplicate).

| Tool | Defined in | Caller | Purpose |
|------|-----------|--------|---------|
| `set_session_info` | `session` | any session | Set **this** session's `title`/`status` in the list. |
| `show_document` | `doc-panel` | any session | Open a `pr`/`issue`/`run`/`file` (+ optional `repo`) in **this** session's document panel. |
| `list_buffers` | `32_1` | any session | List open Emacs buffers + metadata. |
| `get_buffer_content` | `32_1` | any session | Read a buffer (optional line range). |
| `list_claude_sessions` | `orchestrator` | butler | List the other live sessions (name, waiting?, branch, activity). |
| `read_session_output` | `orchestrator` | butler | Read another session's recent terminal screen. |
| `send_to_session` | `orchestrator` | butler | Type a prompt into another session and submit. |
| `report_to_butler` | `orchestrator` | worker | Report up with `summary`/`status`/`needs`. |
| `pending_events` | `orchestrator` | butler | Drain the inbox of queued worker events. |
| `butler_log` | `docs` | butler | Append a timestamped entry to the daily log. |
| `butler_dashboard` | `docs` | butler | Regenerate the dashboard (auto sessions table + overview/decisions). |

---

## 11. Customization (defcustoms / vars)

| Symbol | Default | Meaning |
|--------|---------|---------|
| `cc-butler-channel-args` | `""` | Extra `claude` CLI args appended at launch (e.g. a `--dangerously-load-development-channels` channel flag). |
| `cc-butler-project-marker` | `".projectile"` | Marker file that names a session. |
| `cc-butler-list-width` | `40` | Width of the side list. |
| `cc-butler-doc-width` | `nil` | Width of the document panel (`nil` = half). |
| `cc-butler-enable-forge` | `t` | Fetch PR info via `gh` async. |
| `cc-butler-submit-delay` | `0.1` | Settle delay before the submitting Return. |
| `cc-butler-forward` | `submit` | How worker events reach the butler (`nil`/`notify`/`submit`). |
| `cc-butler-project-templates` | `monocle` entry | Topic-workspace registry. |
| `cc-butler-notify-command` | `nil` | Shell template for the remote-notify listener. |
| `cc-butler-log-buffer-name` | `"*cc-butler-log*"` | Name of the message-log buffer. |

### Channels
`cc-butler--with-channel` augments `claude-code-ide-cli-extra-flags` with
`cc-butler-channel-args` for the duration of a launch, so topic/channel sessions
join a cc-butler development channel. `cc-butler-launch-with-channel` is the explicit
entry point.

---

*Personal config documentation. Last updated 2026-06-30.*
