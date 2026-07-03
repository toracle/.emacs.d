# cc-butler — butler / steward role split (SDD)

Status: **design draft, for approval before build.** Names *butler* / *steward*
are tentative (alt: *foreman* / *orchestrator*).

## 1. Problem

A single butler session handles both the worker **nudge firehose** and the
boss's conversation. Nudges are *injected into the session's input*, so
decisions the boss needs to make get buried and scroll away, and the boss has no
quiet channel to speak into. This is **structural** — discipline can't make an
input-flooded session quiet.

## 2. Two roles (one *mode*)

| Role | Faces | Receives worker nudges/reports? | Job |
|------|-------|-------------------------------|-----|
| **butler** (front-of-house) | the boss | **No** — quiet channel | Hold the decision queue, present cleanly to the boss, query workers on demand, relay decisions down. |
| **steward** (below-stairs, ops chief) | the workers | **Yes** | Receive nudges + `report_to_butler`, dispatch, track DoD, maintain the dashboard, escalate decisions up to the butler. |

The split is **one optional mode**, off by default → **backward compatible**
(existing single-butler installs unaffected; the `report_to_butler` contract is
unchanged, only its routing target moves).

## 3. State model

```elisp
cc-butler--butler    ; existing — the butler (front-of-house) session dir
cc-butler--steward   ; NEW      — the steward (ops) session dir, or nil
```

- **Mode** = *split* when `cc-butler--steward` is a live session distinct from
  the butler; otherwise *single* (current behavior).
- **Ops recipient** — one accessor drives all firehose routing:
  ```elisp
  (defun cc-butler--ops-dir () (or cc-butler--steward cc-butler--butler))
  ```
  Single mode → ops-dir = butler (unchanged). Split mode → ops-dir = steward.

## 4. Routing changes (the core)

| Path | Now | After |
|------|-----|-------|
| Worker notification (nudge) → typed into a session | `cc-butler--forward-to-butler` → `cc-butler--butler` | `cc-butler--forward-to-ops` → **`cc-butler--ops-dir`** |
| `report_to_butler` (worker) → `cc-butler--inbox` | drained by butler via `pending_events` | inbox is the **ops** inbox; **steward** drains it via `pending_events` (butler no longer does) |
| Auto-log of worker events | on `cc-butler--inbox-push` | unchanged (still logs) |

Nothing is typed into the **butler** except escalations (§5). The butler simply
stops calling `pending_events`; the steward calls it.

Worker contract (documented in worker CLAUDE.md): **routine progress →
`report_to_butler` (goes to the steward)**; answer the butler's questions when
asked, but don't push progress at the butler.

## 5. butler ↔ steward channel (simplest: inter-session send + shared doc)

- **Escalate (steward → butler):** new MCP tool
  `escalate_to_butler(summary, needs)` — pushes onto a **butler-only** quiet
  queue `cc-butler--butler-inbox` **and** appends to a shared
  `decisions.org`, and types **one** quiet line into the butler ("decision
  waiting"). This is the *only* thing that reaches the butler.
- **Butler drains:** new MCP tool `pending_decisions()` — returns + clears the
  butler-inbox (mirrors `pending_events`, but for the quiet decision queue).
- **Relay (butler → steward):** the butler uses the **existing**
  `send_to_session(steward, answer)` and/or marks the item resolved in
  `decisions.org`. (Optional thin `resolve_decision(id, answer)` later.)
- **Shared state (both read):** `dashboard.org`, `decisions.org`, the daily
  `log/`, the roster, and the file-based memory all live under a
  `cc-butler-shared-dir` (independent of either role's home), so either role can
  load full context from files.

Single mode: no steward, so `escalate_to_butler` / `pending_decisions` are inert
(or route to the butler's normal inbox); the butler keeps using
`pending_events`. Contract preserved.

## 6. Homes, docs, and the household metaphor

Two run dirs (two sessions can't share a working dir), each with a role
`CLAUDE.md` that **names the metaphor explicitly** (boss request), so new users
aren't confused that both are "staff":

- `cc-butler-home` (butler) — CLAUDE.md: *"You are the **butler**:
  front-of-house. You face the master, keep a calm channel, hold the decision
  queue, and never let worker chatter reach the boss."*
- `cc-butler-steward-home` (steward) — CLAUDE.md: *"You are the **steward**:
  below-stairs operations chief. You receive the workers' reports, dispatch and
  track them, keep the dashboard, and escalate only decisions up to the
  butler."*

Shared operational docs live in `cc-butler-shared-dir` (default: the current
`~/.ccsm/docs` location, so the existing dashboard/log carry over).

## 7. Cutover (recommendation + trade-off)

The current `.ccsm` session holds **both** the boss's conversation **and** the
orchestration context. Only one continuity can be kept in-place; the other role
is a fresh session that reloads state from the shared files.

**Recommendation: `.ccsm` → butler; spawn a new steward.**
- Rationale: the boss's *conversation* is the higher-value, hard-to-reconstruct
  continuity; going forward that channel simply goes quiet (we stop routing
  nudges to it). Orchestration state lives in files (dashboard / log / roster),
  so a fresh steward reloads it cleanly.
- Alternative: `.ccsm` → steward (keep orchestration conversation in place), new
  butler for the boss (fresh, reads dashboard/memory). Trade-off: preserves
  ops-conversation continuity but restarts the boss's channel.

Either way the switch to split routing is automatic once `cc-butler--steward` is
set. **Decision for the boss.**

## 8. New / changed surface

- New: `cc-butler--steward`, `cc-butler--ops-dir`, `cc-butler--butler-inbox`;
  commands `cc-butler-start-steward` (+ manager key), role CLAUDE.md generators;
  MCP tools `escalate_to_butler`, `pending_decisions`; defcustoms
  `cc-butler-steward-home`, `cc-butler-shared-dir`.
- Changed: `cc-butler--forward-to-butler` → `--forward-to-ops` (targets
  ops-dir); `pending_events`/inbox conceptually the ops inbox; role CLAUDE.md
  content. `report_to_butler` **name/contract unchanged**.
- Unchanged: single-mode behavior; all existing MCP tool names.

## 9. Verification / DoD

- Split mode: worker nudge + `report_to_butler` reach the **steward**, nothing
  typed into the **butler**; `escalate_to_butler` → butler quiet queue +
  `decisions.org`; butler `pending_decisions` drains it; `send_to_session`
  relays back.
- Single mode unchanged (regression check).
- Live daemon unharmed; role sessions launched without restart. (Any
  live-daemon-affecting apply is gated.)
