# cc-butler — worklog & roadmap

Running journal of the work turning **CCSM** (the `init-loader/32_*` Claude Code
session manager) into a standalone package, **`cc-butler`**. Purpose: so that
even if a working session's context is lost, what was done and what comes next
stay connected.

- Technical reference for the current system: [CCSM.md](CCSM.md).
- Package name (decided 2026-07-01): **`cc-butler`**. Symbols are still under
  the personal `my/ccsm-*` prefix during the init-loader phase; the rename to
  `cc-butler-*` is a planned extraction step (see *Next*).

---

## File map (current)

| File | Role |
|------|------|
| `32_1_claude_custom_tools.el` | Generic Emacs buffer MCP tools. |
| `32_2_claude_session_manager.el` | CCSM core: session list, metadata, preview. |
| `32_3_claude_notifications.el` | Notification event hook + approval queue. |
| `32_4_claude_workspace.el` | Topic-workspace scaffolding. |
| `32_5_claude_orchestrator.el` | Butler/worker orchestration (PULL/PUSH, inbox). |
| `32_6_claude_doc_panel.el` | **Per-session document panel** (added 2026-06-30/07-01). |
| `32_7_claude_butler_docs.el` | **Butler self-document repository** (added 2026-07-01). |

---

## 2026-06-30 → 07-01

### Documented CCSM
- Wrote [docs/CCSM.md](CCSM.md); linked from `README.md`.

### Built the per-session document panel (`32_6`)
A right-hand vertical split, nested per session, holding rendered documents;
state keyed by working-dir so it persists across session switches.
- Decisions: gh CLI → read-only buffer; sources PR/issue/run/file; multi-doc
  per session (cycle + restore whole set); invoked by the session itself.
- Layout seam: `my/ccsm-after-preview-functions` in `32_2`; doc window is a
  split right of `my/ccsm--main-window`, reconciled on every preview.
- MCP tool `show_document (kind, ref, repo?)`.
- Fixes found during live verification:
  - gh ran in the non-git topic root → resolve the child repo, add a `repo`
    arg + ambiguity prompt for multi-repo workspaces (`my/ccsm--doc-git-dir`).
  - gh spinner ANSI leaked → capture stdout/stderr separately + `strip-ansi`.
  - **Wide content cut off in a narrow panel** → root cause
    `truncate-partial-width-windows` (default 50): side-by-side windows under
    50 cols truncate regardless of `truncate-lines`. Fixed by setting it (and
    `truncate-lines`) nil + `word-wrap` t in panel buffers, so tables reflow.
- UX (forge-style): PR/issue stay read-only with explicit actions — `C-c C-n`
  compose+post a comment via `gh`, `w`/`C-c C-o` open on the web; files open
  read-only (`my/ccsm-doc-file-mode`) with `C-c C-e` to edit; `q` / `C-c d z`
  close+zoom; global `C-c d` prefix drives the panel from anywhere.

### Built the butler self-document repository (`32_7`)
The butler is where all worker work converges, but it scrolled away as chat.
Gave the butler a durable, programmatically-maintained doc repo.
- **Location:** `<butler-home>/docs/` (butler home = `my/ccsm--butler`,
  currently `~/.ccsm/`, already a git repo). `dashboard.org`,
  `log/YYYY-MM-DD.org`, `index.org`.
- **Format:** Org (rich in Emacs with zero setup — org-mode is built-in here,
  markdown-mode is NOT installed; models timestamps/TODO/tables natively; and
  it exports to Markdown/HTML via `ox-md`/`ox-html` if a published site is
  wanted). The two renderers + `--ext` are the format seam for a later
  Markdown swap.
- **Update protocol:**
  - `butler_log (entry, kind?)` — append a timestamped, tagged Org entry to the
    daily log.
  - `butler_dashboard (overview?, decisions?)` — regenerate `dashboard.org`:
    Sessions table **auto-built from live CCSM state**, plus butler-set overview
    and open-decisions (omitted args keep their previous text).
  - **Auto-capture:** advice on `my/ccsm--inbox-push` mirrors every worker
    report/notification into the daily log (default on), so the timeline fills
    itself.
- View with `V` in the manager, or `show_document file docs/dashboard.org`.

## 2026-07-02

### Doc panel: tab line, header line removed (`32_6`)
- Multi-doc UI is now a **tab line** on the doc window (window-parameter, not
  buffer-local `tab-line-mode` → no leak), reusing tab-line's renderer/mouse/
  close; `my/ccsm--doc-sync-current` keeps `:current` in step on tab click.
- **Header line removed** (user decision): navigation = tab line, actions =
  `C-c d` (which now also carries `n` comment / `w` browse, acting on the
  visible session's current doc so they work from the terminal too).

### `my/ccsm-close-topic` — safe topic teardown (`32_4`, `K`)
- Inverse of `new-topic`. Safety gate per git clone (no local-only commits /
  clean tree / no stash, real `git`, git-error = unsafe); abort-on-any-unsafe,
  nothing touched. Kills session, **re-audits immediately before deletion**
  (drift guard), deletes workspace (home/root/shallow guarded). `C-u` forces.
- Verified against throwaway temp repos incl. the drift case.

### Decisions locked
- Package name **cc-butler**; `ccsm→cc-butler` rename **deferred to the package
  extraction** (avoid user-facing churn now).

---

## Next / open

- **Package extraction → `cc-butler`.** Rename `my/ccsm-*` → `cc-butler-*`
  (symbols, buffer names `*claude-sessions*`/`*ccsm-log*`, keymaps, the
  `my/ccsm` entry command, MCP-tool internals) and restructure the `32_*`
  drop-ins into a real package (`cc-butler.el`, `cc-butler-session.el`, …).
  This is user-facing (muscle memory: `M-x my/ccsm`, keybindings), so treat it
  as a deliberate, order-safe pass (see the `backward-compatible-changes`
  discipline), not a big-bang mid-session edit. **Decide: now, or at extraction?**
- **Butler home variable.** Formalize `cc-butler-home` (currently derived from
  the runtime `my/ccsm--butler`); tie into the planned "designated butler home"
  + "default playground root" of the productization.
- **MkDocs publishing?** If wanted, wire Org → Markdown export (`ox-md`) over
  the butler docs; otherwise Emacs/agent remains the primary consumer (Org).
- **Cosmetic:** strip ghostel spinner glyphs (`⠂ ✳`) from OSC activity in the
  dashboard table.
- **Deferred (low priority):** wide-table panel toggle (truncate↔wrap per
  buffer) for when a table is wider than the panel.

---

*Last updated: 2026-07-01.*
