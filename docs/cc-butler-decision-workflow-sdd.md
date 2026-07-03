# cc-butler — messaging: one core, per-recipient adapters (SDD)

Status: **design draft, for approval before build.** Unifies maildir B (already
built, flagged off) and the document-based decision workflow into one design.
Core mechanics detail: [maildir SDD](cc-butler-maildir-sdd.md).

## 1. Organizing principle (정수님's insight)

**Every participant is an equal node with an inbox — the sessions (agents) *and*
the human (정수님). One bus, one addressing scheme.** The inbox core is uniform;
the only thing that differs is the *recipient type*, and the recipient type
decides how a message is consumed — its presentation and interaction. That
difference lives in a per-recipient *adapter*, never in the core.

- **Session (agent) node** → its inbox is drained *programmatically*
  (`check_inbox` / the up-direction drains). This is the **agent adapter**.
- **The human (정수님) node** → 정수님's inbox *is the decision-document
  directory*. The same messages are rendered as read-and-answer decision
  documents, answered in place and submitted with `C-c C-c`. This is the
  **human adapter**, and **the butler *is* that adapter** (§3).

So there is **no separate "decision document system"**, and the human is not
outside the bus — 정수님 is a first-class node on it. Human-bound and
agent-bound messages are the same durable maildir messages, in the same store,
under **one audit trail.** The core is uniform; only the adapter branches.

Participant symmetry — all inbox nodes on one addressing scheme:

| Node | Inbox | Adapter |
|------|-------|---------|
| steward | steward inbox | agent — `pending_events` drain |
| butler | butler inbox | agent — `pending_decisions` drain |
| worker | worker inbox | agent — `check_inbox` (later, §5) |
| **정수님** | decision-document dir | **human — the butler renders + routes** |

```
        ┌───────────────── uniform maildir core ─────────────────┐
        │  durable per-recipient inbox: deliver → new/ (atomic),  │
        │  drain → archive/ (audit trail), correlation ids,       │
        │  transport flag (in-memory | maildir)                   │
        └───────┬───────────────────┬────────────────────┬───────┘
                │                   │                    │
        agent adapter        agent adapter         HUMAN adapter
        (steward inbox)      (butler inbox)        (boss decisions)
        pending_events       pending_decisions     decision docs + C-c C-c
                │                   │                    │
        [C: worker inbox — a later agent adapter, same core, no redesign]
```

## 2. The uniform core (built as maildir B)

One durable, lock-free, auditable inbox per recipient (agent id *or* the human).
Deliver writes `tmp/` then atomically renames into `new/`; draining moves each
message to `archive/`, so **the sorted files are the audit trail** — no separate
log. Messages carry request/response **correlation ids** (`reply-to` /
`in-reply-to`) so a reply reaches whoever asked. Behind
`cc-butler-message-transport` (`in-memory` default | `maildir`) for rollback.
*(Core + agent adapter are already implemented and verified — BDD 10/10; see the
maildir SDD.)*

## 3. Agent adapters (built)

- **steward inbox** — worker `report_to_butler` lands here; drained
  programmatically by `pending_events`.
- **butler inbox** — steward `escalate_to_butler` lands here; drained by
  `pending_decisions`.
- Pull-only: nothing is typed into any terminal.

## 4. Human adapter — the butler, rendering 정수님's inbox (to build)

정수님's inbox is the same core, rendered by **the butler** (its human adapter)
for a human to answer. The butler is *not* disintermediated — its
front-of-house role **is** this adapter: it renders each message in 정수님's
inbox as a readable decision document, and routes 정수님's `C-c C-c` answer
back to the originating session with the correlation id.

- **One file per decision** (not one big doc). Named by timestamp
  (`open/20260704T0102-<corr>.org`); filename order = chronological = the
  decision history. Answered files move to `done/` — mirroring
  `new/`→`archive/`. **The sorted directory is the audit trail.**
- **A decision file *is* an escalation message + a human-answer affordance.**
  `escalate_to_butler` and decision-file creation are **one path**: the human
  adapter renders the butler-inbox message as this file.
- **File shape:** top = context + options `A/B/C` (preserved, not mutated);
  bottom = an **answer region** the boss fills — an option pick *and/or*
  free-form text. A `do-not-edit` footer holds the correlation id + target
  session.
- **Editable, unlike the read-only dashboard.** Opens in `org-mode` (syntax
  highlighting) under the doc panel's viewer minor mode; answering flips it to
  editable (the view↔edit idea, applied — the current `cc-butler-doc-view-mode`
  is viewer-only, so this re-introduces a bounded edit for the answer region).
- **Submit = `C-c C-c`** — an *explicit* parse trigger (not auto-on-save), so a
  half-written answer never leaks: the isomorph of the core's "a half-written
  message is never read" (tmp→rename). On submit, the answer becomes a
  **`reply`** on the decision's correlation → routed to the originating session
  → the file moves to `done/`. Reuses the core's reply routing; no new system.

## 5. Extension point — C (worker DOWN), later, no redesign

Because the core is uniform, the deferred worker down-direction is **just
another agent adapter**: deliver to a worker's inbox, the worker drains
(`check_inbox`) and replies. It slots onto the same core with **no rework** —
this is the generalize-before-extend payoff of B-now / C-later. **Do not build C
now** (north star; no worker touched); the SDD only marks the seam.

## 6. Open questions for 정수님 (surfaced, not decided)

1. **Adapter boundary** — confirm the split: agent = programmatic drain, human =
   decision-doc + `C-c C-c`. Any recipient that should behave differently?
2. **Human-adapter submit UX** — parse trigger: explicit `C-c C-c`
   *(recommended, safe)* vs auto-on-save; marking form: org checkbox `[X]` vs a
   `Decision:` line vs a TODO keyword (all support option-pick + free-form).

*Resolved (was open):* **butler-relay coexistence** — the butler **is** the human
adapter (§4), not something the document workflow bypasses. Rendering 정수님's
inbox as decision documents and routing the answers back *is* its front-of-house
role, so there is no either/or with a separate verbal relay — they are one
adapter.

## 7. SPT / reuse

Build nothing large: the **core + agent adapters exist (B)**; the human adapter
layers the **doc panel** (show the decision file), **org-mode** (structure +
highlighting), and the **core's reply/correlation** (route the answer) — the
decision workflow is a *presentation adapter over B*, not a second system.

## 8. Verification plan (human adapter, when built)

- Create: an escalation produces an `open/` decision file (timestamped,
  correlation embedded); it is the same message as the butler-inbox entry.
- Answer + submit: `C-c C-c` on a filled file routes the answer to the target
  session via the correlation and moves the file to `done/`.
- Safety: an un-submitted (half-written) answer never leaves the file.
- Audit: `open/` + `done/` sorted reconstruct the full decision history.
- Preserve: answering never mutates the decision text/options.
