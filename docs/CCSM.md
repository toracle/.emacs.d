# CCSM — Claude Code Session Manager

A lightweight, cmux-like manager for running **many concurrent
`claude-code-ide` sessions** inside one Emacs, with a sticky side list, live
per-session metadata, OS-/remote-friendly notifications, topic-workspace
scaffolding, and a **butler/worker control plane** you can drive from your
phone.

It is a personal, non-packaged config that lives entirely under
[`init-loader/`](../init-loader/), loaded by `init-loader` in numeric order.

> Entry point: `M-x my/ccsm`.

---

## 1. File map

CCSM is split across five `32_*` drop-ins. They load in order; later files
`(require ...)` earlier ones.

| File | Role |
|------|------|
| [`32_1_claude_custom_tools.el`](../init-loader/32_1_claude_custom_tools.el) | Generic Emacs **buffer** MCP tools (`list_buffers`, `get_buffer_content`) — not CCSM-specific, but part of the same Claude bridge. |
| [`32_2_claude_session_manager.el`](../init-loader/32_2_claude_session_manager.el) | **CCSM core.** Session enumeration, the side-list UI, per-session metadata, navigation/preview, and the `set_session_info` tool. |
| [`32_3_claude_notifications.el`](../init-loader/32_3_claude_notifications.el) | Turns ghostel's single notification callback into a **decoupled event hook**; ships the input-waiting **approval queue** and opt-in listeners. |
| [`32_4_claude_workspace.el`](../init-loader/32_4_claude_workspace.el) | **Topic-workspace** scaffolding: clone repos + write `.projectile`/`CLAUDE.md` markers, then launch a session. |
| [`32_5_claude_orchestrator.el`](../init-loader/32_5_claude_orchestrator.el) | **Butler/worker** orchestration: a designated *butler* session drives *workers* through Emacs (PULL tools + PUSH forwarding). |

All MCP tools are registered against `claude-code-ide-mcp-server` and exposed to
the running Claude through the Emacs MCP bridge.

---

## 2. Core concepts

### Session
A **session** is one live `claude-code-ide` process. The canonical key is its
**working directory** (`dir`); CCSM looks sessions up in
`claude-code-ide--processes` and `claude-code-ide--session-ids`.

### Display name (the `.projectile` walk)
A session's name is the basename of the **nearest ancestor directory
containing `.projectile`** (`my/ccsm-project-marker`), falling back to the
working directory's own basename — see `my/ccsm--display-name`. This is the
single source of truth shared by the buffer name (`my/ccsm-buffer-name`, wired
into `claude-code-ide-buffer-name-function`) and the list title. The effect:
sessions launched in sibling repos of a *topic workspace* all collapse to the
**topic's** name instead of each repo's name.

### Per-session metadata (Claude sets it about itself)
`my/ccsm--meta` maps `dir → plist` with `:title`, `:status`, `:updated`. The
running Claude updates its own row by calling the **`set_session_info`** MCP
tool (see §8). This is how a session announces "what I am" and "what I'm doing
right now" to the human.

### Auxiliary info
- **Git branch** — `my/ccsm--git-branch`, cached 5s to avoid spawning `git` on
  every redraw.
- **PR number** — `my/ccsm--forge-fetch` shells out to `gh pr view` **async**
  and caches `"PR #NN"` per dir. Gated by `my/ccsm-enable-forge`.
- **OSC terminal title** — `my/ccsm--osc-title` reads ghostel's live OSC-2
  title (the task summary Claude emits as it works) straight off the term
  object, even though claude-code-ide disables title-based renaming.

---

## 3. Window layout

```
+------------------+--------------------------------------+
|  *claude-sessions* |                                    |
|  (side window,     |   selected session's terminal      |
|   left, slot 0,    |   (my/ccsm--main-window)           |
|   width 40,        |                                    |
|   dedicated)       |                                    |
+------------------+--------------------------------------+
```

`my/ccsm` runs `delete-other-windows`, displays the list buffer with
`display-buffer-in-side-window` (left, dedicated, `my/ccsm-list-width`), and
keeps a single **main window** (`my/ccsm--main-window`) for terminals.
Navigating the list **swaps the main window's buffer** with
`set-window-buffer` rather than popping new windows.

Because `set-window-buffer` does not fire `window-size-change-functions`,
`my/ccsm--terminal-resize` explicitly drives `ghostel--adjust-size` (sizing the
PTY to the *largest* window showing the session) so the preview isn't a stale
or clipped frame.

---

## 4. The session list UI (`my/ccsm-mode`)

Each session renders as a **multi-line block** so it stays readable in a narrow
window:

```
★ billing: invoice PDF        ← title (★ butler / ⏳ waiting / ● running)
   writing the PDF renderer   ← OSC terminal title (italic)
   waiting on review          ← status line (set via set_session_info)
   ⎇ feature/pdf   PR #42     ← branch + forge
```

**Ordering** (`my/ccsm--ordered`, a stable sort):
1. The **butler** session is pinned to the very top (`★`).
2. Sessions **awaiting input** form a FIFO **approval queue** (`⏳`, oldest
   request first).
3. Everything else keeps natural order.

The selected block is tracked with a `highlight` overlay (`my/ccsm--highlight`).

### Live updates
The list re-renders itself (debounced 0.3s, only when visible) on:
- **terminal title changes** — `:after` advice on `ghostel--set-title`;
- **session start/stop** — `:after` advice on `claude-code-ide--set-process`
  and `claude-code-ide--cleanup-on-exit`;
- **forge fetch completion**.

### Keybindings (`my/ccsm-mode-map`)

| Key | Command | Action |
|-----|---------|--------|
| `n` / `p`, `↓`/`↑`, `C-n`/`C-p` | `my/ccsm-next` / `my/ccsm-prev` | Move + preview the session |
| `SPC` | `my/ccsm-preview` | Preview in the main window, stay in the list |
| `RET` | `my/ccsm-visit` | Preview, **select** the terminal, clear it from the wait queue |
| `g` | `my/ccsm-refresh` | Re-render + re-fetch forge info |
| `c` | `my/ccsm-new-session` | Start a session in a chosen directory |
| `N` | `my/ccsm-new-topic` | Create a **topic workspace** (§6) |
| `b` | `my/ccsm-set-butler` | Toggle the session at point as **butler** (§7) |
| `l` | `my/ccsm-show-log` | Pop to the `*ccsm-log*` message log |
| `q` | `my/ccsm-quit` | Close the side window |

---

## 5. Notifications & the approval queue (`32_3`)

Claude Code raises a terminal notification (OSC 9 / OSC 777) when its agent
loop ends or it needs you. ghostel routes that to a single
`ghostel-notification-function`, which is awkward for a **headless daemon over
SSH** (no local tray).

`32_3` takes over that callback and re-emits it as an **abnormal hook**,
`my/ccsm-notification-functions`, whose listeners each receive an EVENT plist
(`:type :title :body :buffer :session :name`). ghostel's prior notifier is
**chained**, so a local GUI Emacs keeps its tray popup for free.

- **Built-in listener — approval queue** (`my/ccsm--queue-on-notification`): a
  notifying session is marked *waiting* (`my/ccsm--mark-waiting`) and pushed to
  the butler **inbox**, bubbling it to the top of the list. Visiting it (`RET`)
  clears it.
- **Opt-in listeners** (pick per environment; none on by default):
  - `my/ccsm-notify-echo` — echo-area/`*Messages*` (testing);
  - `my/ccsm-notify-desktop` — local D-Bus/OS desktop notification;
  - `my/ccsm-notify-command-listener` — run a shell template
    (`my/ccsm-notify-command`, `%t`/`%b` = title/body) for a remote messenger
    CLI, async.

---

## 6. Topic workspaces (`32_4`)

A **topic workspace** is a plain (non-git) directory that holds one or more
checked-out repos plus two markers:

- **`.projectile`** — makes projectile treat the topic dir as one project (all
  sibling repos visible without `/add-dir`) and makes CCSM name the session
  after the topic.
- **`CLAUDE.md`** — a thin file that `@`-imports the meta repo's shared docs
  (e.g. `monocle/CLAUDE.md`, `monocle/DESIGN.md`) and appends a short
  "reporting to the butler" note, so launching Claude there loads the project's
  architecture at startup.

Layouts live in **data**: `my/ccsm-project-templates`, an alist of
`(NAME . PLIST)` with `:base-dir :dir-format :repos :claude-import`. Adding a
project is just another entry. `M-x my/ccsm-new-topic` (or `N`) prompts for a
template (or `arbitrary`, which falls back to `my/ccsm-new-session`) and a
topic name, clones the repos **async/sequentially** (skipping present ones),
scaffolds the markers, and launches the session.

---

## 7. Butler / worker orchestration (`32_5`)

CCSM becomes a **control plane**: one designated **butler** session drives the
**worker** sessions, with **Emacs as the bus** (workers are reached through
their ghostel shells). You remote-control *one* session — the butler — from
your phone, and it becomes the situation room for the rest. Designate it with
`b` in the manager (`my/ccsm--butler`, pinned to top).

Two directions:

- **PULL** — the butler actively inspects/commands workers via MCP tools:
  - `list_claude_sessions` — what's running, who's `WAITING-FOR-INPUT`,
    branches, activity titles;
  - `read_session_output` — a worker's recent terminal screen (force-refreshed
    from the live ghostel grid first, so even a backgrounded buffer is current);
  - `send_to_session` — type a prompt into a worker and submit it (multi-line
    delivered as a bracketed paste so only the final Return submits; ESC bytes
    stripped).
- **PUSH** — when a worker posts a notification, `my/ccsm--forward-to-butler`
  types a one-line summary into the butler's terminal (and optionally submits
  it). Controlled by `my/ccsm-butler-forward` (`nil` / `notify` / `submit`).

### The inbox / report path
Workers can also report **up** with real content via `report_to_butler`
(`summary` / `status` / `needs`). Reports and forwarded events queue in
`my/ccsm--inbox` and are drained by the butler calling `pending_events` — so
the butler learns what changed **without anything being typed into its input
box**. All butler↔worker traffic is teed to the `*ccsm-log*` buffer
(`my/ccsm-show-log`, `l`), tagged with each session's name + id.

---

## 8. Per-session document panel (`32_6`)

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
in `my/ccsm--docs` (`:items` / `:current` / `:open`), so switching away and
back restores the same documents at the same selection. The doc window is
always a split to the **right of `my/ccsm--main-window`** (tracked as
`my/ccsm--doc-window`), reconciled on every preview by
`my/ccsm--apply-doc-layout` (hung on `my/ccsm-after-preview-functions`): show
the split iff the session has an open, non-empty panel; tear it down otherwise.
Because the split narrows the terminal window, the PTY is resized afterward.

**Documents** are fetched on demand:

| Kind | Source |
|------|--------|
| `pr` | `gh pr view REF --comments` |
| `issue` | `gh issue view REF --comments` |
| `run` | `gh run view REF` (workflow run) |
| `file` | a local file (path relative to the working dir), visited directly |

`gh` kinds render **async** into a read-only `my/ccsm-doc-mode` buffer. stdout
and stderr are captured **separately** so gh's progress spinner never pollutes
a clean render, and `my/ccsm--strip-ansi` removes terminal control sequences;
on failure stderr is shown so the error is still visible. `file` kinds open the
real file buffer **read-only** (`my/ccsm-doc-file-mode`, forge-style), with
`C-c C-e` to toggle editability. Re-opening an existing doc re-selects (and
re-fetches) it rather than duplicating.

Panel buffers **wrap** long lines unconditionally (`truncate-lines` and
`truncate-partial-width-windows` both nil, `word-wrap` t), so wide content —
markdown tables especially — reflows instead of being cut off the right edge,
even when the panel is narrow (e.g. a remote/phone-sized frame, where a
side-by-side window under 50 columns would otherwise force truncation).

### Multi-repo topic workspaces
A topic-workspace root is not itself a git repo — the repos are child
directories. For gh kinds, `my/ccsm--doc-git-dir` resolves the working
directory: an enclosing repo if there is one, the sole child repo if unique,
otherwise it reports the **ambiguous** set. The `show_document` tool then takes
an optional **`repo`** argument naming the child repo; omitting it on a
multi-repo workspace returns the list to choose from.

### Reading vs. acting (forge-style)
The panel keeps documents **read-only** and gates actions behind explicit keys
(borrowing forge's model): `C-c C-n` composes a comment in a
`my/ccsm-doc-compose-mode` buffer and posts it with `C-c C-c` via
`gh pr/issue comment --body-file`; `w` / `C-c C-o` opens the item on the web
(`gh … view --web`).

### Driving the panel
The running Claude opens documents into **its own** panel via the
**`show_document`** MCP tool (`kind` + `ref` + optional `repo`). The human
drives it from the session list, from a doc buffer, or from anywhere via the
global **`C-c d`** prefix:

| Key | Command | Action |
|-----|---------|--------|
| `o` | `my/ccsm-doc-open` | Prompt for kind/ref (and repo if needed), open into the selected session |
| `]` / `[` | `my/ccsm-doc-next` / `-prev` | Cycle documents |
| `d` | `my/ccsm-doc-toggle` | Show/hide the panel |
| `z` *(C-c d)* / `q` *(doc buf)* | `my/ccsm-doc-hide` | Hide the panel and **zoom** into the terminal |
| `D` / `k` | `my/ccsm-doc-remove` | Drop the current document (kills gh buffers; only unlinks files) |
| `g` | `my/ccsm-doc-revert` | Re-fetch the current gh doc |
| `w` | `my/ccsm-doc-browse` | Open the current gh doc on the web |
| `C-c C-n` | `my/ccsm-doc-comment` | Compose a comment on the current PR/issue |

The list keymap binds `o ] [ d D`; the doc buffer additionally binds
`q w k g C-c C-n C-c C-o`; `C-c d` is the global prefix (`d z ] [ o g k`).
`my/ccsm-doc-width` (default `nil` = half) sets the panel width.

---

## 9. Butler self-document repository (`32_7`)

The butler is where every worker's work converges, but that convergence lived
only in a scrolling chat stream. `32_7` gives the butler a durable document
repository it maintains **programmatically**, under
`<butler-home>/docs/` (butler home = `my/ccsm--butler`, e.g. `~/.ccsm/`):

```
<butler-home>/docs/
  index.org            landing page
  dashboard.org        CURRENT snapshot (regenerated on update)
  log/2026-07-01.org   per-day, append-only timeline
```

- **Log (time axis)** — append-only. Filled *automatically* by advice on
  `my/ccsm--inbox-push` (every worker report/notification), and *explicitly* by
  the butler calling **`butler_log`** for curated decisions/progress.
- **Dashboard (now)** — regenerated. Its Sessions table is built from **live
  CCSM state** (`my/ccsm--sessions` + waiting/branch/PR/activity), merged with
  the butler's overview and open-decisions set via **`butler_dashboard`**
  (omitted args keep their previous text).

Format is **Org** (rich in Emacs with zero setup; native timestamps/TODO/tables;
exports to Markdown/HTML via `ox-md`/`ox-html`). The renderers and
`my/ccsm-butler-docs--ext` are the format seam for a later Markdown swap. The
butler passes plain prose; the elisp emits the Org scaffolding, so format
fidelity is not on the agent. Open it with `V` in the manager (regenerate +
show in the panel), or `show_document file docs/dashboard.org`.

Customs: `my/ccsm-butler-docs-subdir` (`"docs/"`), `-log-subdir` (`"log/"`),
`-auto-log` (`t`).

See also the productization journal: [cc-butler-worklog.md](cc-butler-worklog.md).

---

## 10. MCP tools reference

Tools the running Claude can call through the Emacs bridge. Registration is
**idempotent** (each file removes prior copies of its tool names before
re-adding, so reloads don't duplicate).

| Tool | Defined in | Caller | Purpose |
|------|-----------|--------|---------|
| `set_session_info` | `32_2` | any session | Set **this** session's `title`/`status` in the list. |
| `show_document` | `32_6` | any session | Open a `pr`/`issue`/`run`/`file` (+ optional `repo`) in **this** session's document panel. |
| `list_buffers` | `32_1` | any session | List open Emacs buffers + metadata. |
| `get_buffer_content` | `32_1` | any session | Read a buffer (optional line range). |
| `list_claude_sessions` | `32_5` | butler | List the other live sessions (name, waiting?, branch, activity). |
| `read_session_output` | `32_5` | butler | Read another session's recent terminal screen. |
| `send_to_session` | `32_5` | butler | Type a prompt into another session and submit. |
| `report_to_butler` | `32_5` | worker | Report up with `summary`/`status`/`needs`. |
| `pending_events` | `32_5` | butler | Drain the inbox of queued worker events. |
| `butler_log` | `32_7` | butler | Append a timestamped entry to the daily log. |
| `butler_dashboard` | `32_7` | butler | Regenerate the dashboard (auto sessions table + overview/decisions). |

---

## 11. Customization (defcustoms / vars)

| Symbol | Default | Meaning |
|--------|---------|---------|
| `my/ccsm-channel-args` | `""` | Extra `claude` CLI args appended at launch (e.g. a `--dangerously-load-development-channels` channel flag). |
| `my/ccsm-project-marker` | `".projectile"` | Marker file that names a session. |
| `my/ccsm-list-width` | `40` | Width of the side list. |
| `my/ccsm-doc-width` | `nil` | Width of the document panel (`nil` = half). |
| `my/ccsm-enable-forge` | `t` | Fetch PR info via `gh` async. |
| `my/ccsm-submit-delay` | `0.1` | Settle delay before the submitting Return. |
| `my/ccsm-butler-forward` | `submit` | How worker events reach the butler (`nil`/`notify`/`submit`). |
| `my/ccsm-project-templates` | `monocle` entry | Topic-workspace registry. |
| `my/ccsm-notify-command` | `nil` | Shell template for the remote-notify listener. |
| `my/ccsm-log-buffer-name` | `"*ccsm-log*"` | Name of the message-log buffer. |

### Channels
`my/ccsm--with-channel` augments `claude-code-ide-cli-extra-flags` with
`my/ccsm-channel-args` for the duration of a launch, so topic/channel sessions
join a CCSM development channel. `my/ccsm-launch-with-channel` is the explicit
entry point.

---

*Personal config documentation. Last updated 2026-06-30.*
