# cc-butler — runtime-neutral governance store (SDD)

Status: **design draft, for approval before build.** Design-parallel (the
doc-view UX/bugs are the build priority). Applies cc-butler's "one core +
adapters" to knowledge/governance.

## 1. Problem (정수님's hard constraint)

Knowledge and principles must **not be coupled to Claude Code**. If the runtime
changes (Codex, AGENTS.md, …), the principles must survive. Today the butler/
steward **operational principles live ONLY in Claude Code memory**
(`~/.claude/…/memory/`) — a runtime coupling. That is a global-consistency
violation: the principles' single source of truth is a *runtime-specific* file.

Most knowledge is already neutral and stays put:
- **values / philosophy** → vault + warmblood-kr/skills (neutral).
- **reusable engineering discipline** → skills, trigger-fired (neutral), e.g.
  global-consistency.
- **repo-specific pitfalls** → in-repo docs (content-neutral; `CLAUDE.md` /
  `AGENTS.md` are just *filename* adapters).

Only the **butler/steward operational principles** are coupled. This SDD fixes
exactly that, minimally.

## 2. Principle — store is SSoT, runtime files are generated adapters

The same shape as maildir B (one uniform core + per-recipient adapters):

```
        cc-butler-owned NEUTRAL operating-principles store   (SSoT, content-only)
                              │  generate
        ┌─────────────────────┼──────────────────────────┐
   Claude Code adapter   Claude Code adapter          Codex adapter (future)
   role CLAUDE.md        memory notes                 AGENTS.md
   (front-of-house /     (regenerated cache)          (regenerated cache)
    below-stairs)
```

- The **store owns** the principles; every runtime file (role `CLAUDE.md`,
  Claude Code memory notes, a future `AGENTS.md`) is a **generated cache**.
- Editing a principle = **edit the store + regenerate** → all adapters update.
- global-consistency: SSoT = the store; no principle is authored in two places
  that can disagree (today's memory-only is that disagreement waiting to happen).

## 3. What goes in the store

The butler/steward **operational** principles currently in Claude Code memory —
e.g. `no-overinterpret`, `state-desync`, `decision-routing`, `DoD-vs-goal`,
`evaluation-independence`, `communication-style`, `decision-proposal-format`,
`institutionalize-learning`, and the just-added `butler-steward-routing`. Each is
content-only (no runtime-specific phrasing), tagged with a **scope** (which
role(s) it applies to).

Not in the store: values (→ vault), engineering discipline (→ skills), repo
pitfalls (→ repo docs) — already neutral.

## 4. Design (minimal — "neutral file + generation")

- **Store**: cc-butler-owned files, runtime-agnostic. One file per principle
  (mirrors the memory-note granularity), light front-matter: `id`, `scope`
  (`butler` | `steward` | `both`), `title`; body = the principle, content-only.
- **Adapters (generators)** — reuse what exists:
  - The Claude Code role-doc generators `cc-butler--butler-claude-md` /
    `cc-butler--steward-claude-md` become **adapters that read the store** and
    render the role `CLAUDE.md` (instead of hardcoding prose).
  - A memory adapter renders the store's notes into the Claude Code memory dir
    (so `MEMORY.md` + notes remain, now *derived*).
  - A future Codex adapter renders `AGENTS.md` from the same store — no principle
    rewrite.
- **Generation trigger**: on home bootstrap (`cc-butler--ensure-*-home`) + a
  manual `cc-butler-governance-regenerate` command. (Open question below.)

## 5. Migration plan (seamless, no disruption)

1. **Inventory** the operational principles now in Claude Code memory (the list
   in §3).
2. **Move** each into the neutral store as a content-only file (scope-tagged).
3. **Regenerate** back into Claude Code memory notes + the role `CLAUDE.md` — the
   memory content is preserved, now *derived from the store*.
4. From then on, memory is a **generated cache**; new operational learnings are
   authored in the store and regenerated (or written to memory then reconciled
   into the store — open question).

## 6. Consistency with institutionalize-learning

The just-added `institutionalize-learning` duty routes operational/coordination
learning to its "durable home". Under this SDD, that home is the **neutral
store** (which regenerates to memory), not memory directly. The SDD updates that
routing target; the role docs' duty text is regenerated to point at the store.
Circular-consistent: the learning duty and the store point at each other
correctly.

## 7. Open questions for 정수님

1. **Store location** — in the cc-butler repo (versioned with the code, travels
   with the package) vs the butler home (runtime state) vs a separate governance
   repo? (Recommend: in the cc-butler repo — the principles are the package's,
   and versioning them with it is honest.)
2. **Store format** — one-file-per-principle (like memory notes) with front-matter
   (`id`/`scope`/`title`), markdown or org? (Recommend: one-file-per-principle,
   markdown, minimal front-matter — matches the memory-note habit.)
3. **Generation trigger** — bootstrap-only, a manual regenerate command, or a
   save-hook on the store? (Recommend: bootstrap + manual command; no watcher.)
4. **Memory authoring** — is Claude Code memory now *purely* a generated cache
   (never hand-edited), or may a learning be written to memory first then
   reconciled into the store? (Affects whether the duty writes to store or memory.)

## 8. SPT

Not a framework: a **content-only file store + a thin generator**, reusing the
existing `cc-butler--*-claude-md` generators as the first adapter. No new runtime,
no new abstraction beyond store→adapter.
