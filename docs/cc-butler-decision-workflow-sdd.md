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

### 4a. Message kinds in 정수님's inbox (proposed, for §6)

정수님's inbox receives more than decisions — a steward may relay a plain
**note** (informational: "worker X finished", "CI green"). If everything became
an answerable document the directory would clog with things that need no answer.
So the human adapter **renders by `:kind`** (the core already carries it):

| kind | render | interaction |
|------|--------|-------------|
| `decision` | an **answerable** document (options + answer region) | `C-c C-c` submits a reply |
| `note` / `relay` | a **read-only notification** (no answer region) | mark seen → straight to `done/` |

Only `decision` messages become answerable files; notes render read-only, so the
answerable queue stays exactly the open decisions. Both are the same durable
messages under one audit trail.

### 4b. Decision-text integrity in the edit buffer (proposed, for §6)

Only the **answer region** may be edited or parsed; the decision text and
options above it are preserved. Proposed mechanism (Emacs-native):

- Put a **`read-only` text property** on the decision/options region (and the
  `do-not-edit` footer) while the answer region is left writable. The buffer is
  editable, but only the answer region accepts input — the top physically can't
  be changed. (Simpler than region-narrowing; standard Emacs affordance.)
- On `C-c C-c`, **parse only the answer region** (between its start marker and
  the footer), and **validate** the top is byte-identical to the source message
  before routing — a belt-and-suspenders integrity check.

### 4c. The doc inbox is 정수님's *general* inbox — butler-authored briefings

정수님's insight: the doc inbox is not only for *worker-originated* messages
(decision/note relayed up). It is 정수님's **general durable inbox for everything
정수님-facing**, and that includes the **butler proactively briefing 정수님 — as a
document, not as chat.**

- **Principle:** *durable 정수님-facing comms → the doc inbox; chat → ephemeral
  only.* A chat briefing scrolls away; a status/briefing/explanation 정수님 will
  want to keep and reference must be a **durable document** in the inbox. So the
  butler writes briefings **into the inbox**, not into the conversation.
- **Briefing = a note-like message** (informational, no answer). It renders
  read-only like a `note` and is **closed by the read-receipt `r`** (see the
  read-receipt SDD) — decisions close by `C-c C-c`, informational/briefings by
  `r`.
- **Mechanism — reuse maildir B.** A briefing is a maildir message delivered to
  정수님's inbox; the arrival watcher renders it; `r` closes it and sends the
  read-receipt back to the butler. This needs a **butler briefing-author path**:
  a note-like send to 정수님's inbox, **symmetric with `escalate_to_butler`**
  (which sends a `decision`). Everything durable 정수님 should see thus converges
  in the one inbox; global-consistency holds (same lifecycle, one audit trail).

Design judgment (in §6): is a briefing a **new `:kind briefing`**, or just a
`note` with **author = butler** (SPT)? And the **butler author affordance** — an
MCP tool (e.g. `brief_the_boss(title, body)`) or a command.

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
3. **Message-kind rendering** (§4a) — confirm: `decision` → answerable document,
   `note`/`relay` → read-only notification, so the answerable queue is exactly
   the open decisions. Any other kinds to distinguish?
4. **Answer-region integrity** (§4b) — confirm the mechanism: a `read-only`
   text property on the decision/options + footer, parse only the answer region,
   validate the top unchanged on submit. Acceptable, or prefer narrowing to the
   answer region?
5. **Briefing kind** (§4c) — a butler briefing: new `:kind briefing`, or a
   `note` with `author = butler` (SPT)? (Distinct rendering wanted, or is the
   note read-only + `r` close enough?)
6. **Butler author affordance** (§4c) — the shape of the briefing-author path:
   an MCP tool like `brief_the_boss(title, body)`, and/or an interactive command?

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
