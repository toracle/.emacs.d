# cc-butler — doc-view read-receipts (SDD)

Status: **design draft, for approval before build.** Additive on the human
adapter ([unified SDD](cc-butler-decision-workflow-sdd.md)) and maildir B.

## 1. Problem

The butler can surface a document to 정수님, but has **no feedback that 정수님
actually read it**. Without a read signal, the sender re-raises things 정수님
has already seen, or assumes something was seen when it wasn't. We need a
**read-receipt**: a lightweight, durable signal back to the sender that a
message was read.

## 2. Core — a read-receipt *is* a `read` reply on the message's correlation

This reuses maildir B's reply/correlation wholesale — no new mechanism:

- Marking a message **read** emits a **`read`-kind reply** (in-reply-to the
  message id) routed to the **sender's** inbox — exactly the return path a
  decision answer already uses.
- The sender (steward/butler) sees it via the existing `pending_events`
  ("정수님 read: <summary>"), and it is durable (archived) — the **audit trail
  records the read**.

**Symmetry with decisions.** A decision's `C-c C-c` answer already *is* a read
signal (you can't answer what you didn't read). Informational messages
(`note`/`relay`) have **no answer**, so they had no close signal — the read-mark
(`r`) is that close signal. So:

| kind | close action | doubles as read signal? |
|------|--------------|-------------------------|
| `decision` | `C-c C-c` (answer) | yes (answering = reading) |
| `note` / `relay` | **`r` (mark read)** | yes (this is its purpose) |

`r` is also available on a `decision` as "seen, will answer later" — it emits a
read receipt **without an answer and without closing** the decision (it stays in
`open/`; only `C-c C-c` closes it — see §4). Optional, secondary to note/relay.

## 3. Lifecycle & the single source of truth (global-consistency)

Applying the global-consistency principle: **read-status has one source of
truth — the message's maildir lifecycle** — propagated, never stored in two
places that can disagree.

```
new/  →  (arrival watcher renders)  →  open/  →  (close)  →  done/
         message archived                unread            read/answered
                                          the doc's location IS the state
```

- The **doc's location** (`open/` = open/unread, `done/` = closed/read) mirrors
  the message state — it is the one record. No separate "read?" flag kept
  elsewhere.
- **Revision to §③ of the unified SDD:** notes/relays no longer render straight
  to `done/`. They render to `open/` as *unread*, and `r` moves them to `done/`
  while emitting the receipt — so an informational message stays visible until
  actually read. Decisions and notes share one `open/→done/` lifecycle; only the
  **close action** differs (answer vs read).

## 4. Affordance

- **`r`** in the doc view marks the current document read, emits the receipt,
  and refreshes the ⚖ indicator. (Bound in `cc-butler-decision-mode`, alongside
  `C-c C-c`.) Whether it **closes** the doc depends on kind:
  - **`note`/`relay`** — `r` closes it: `open/ → done/` (read *is* its close).
  - **`decision`** — `r` emits a read-receipt only and **keeps the decision in
    `open/`**. A decision is closed **only** by its `C-c C-c` answer, never by
    `r` — so an unanswered decision can never be archived out of the queue and
    lost. (This is the "seen, will answer later" receipt of §2.)
- Non-destructive and consistent with the read-only viewer: `r` records a read,
  it never edits or deletes the underlying message (which is already archived).

## 5. Scope

- **Sender-bearing inbox messages only** (`decision`/`note`/`relay` — they carry
  a correlation + sender) propagate a receipt.
- **Plain documents** (dashboard, a gh PR/issue opened in the panel) have no
  sender/correlation → `r` is a **local read mark only** (clears the indicator);
  there is no receipt to send. The affordance is the same key; the propagation
  is conditional on a routing footer being present.

## 6. Read vs acknowledged (SPT: one tier first)

정수님 distinguished **read** (인지, "I've seen it") from **acknowledged** (숙지,
"I've absorbed it"). **SPT: ship `read` only first** — one key, one receipt kind.
A second tier can follow *if 정수님 wants it*: e.g. `r` = read, `R` (or `a`) =
acknowledged, carried as the receipt's sub-kind; the sender then distinguishes
"seen" from "understood". Designed-for but not built now.

## 7. Open questions for 정수님 (surfaced, not decided)

1. **Mark key** — `r` (proposed) for read? (`R`/`a` reserved for a later
   acknowledged tier.)
2. **Two tiers now or later** — ship `read` alone (SPT), or include
   `acknowledged` from the start?

## 8. SPT / reuse

No new transport: the receipt is a `read`-kind reply over maildir B's existing
correlation + `pending_events`. The only real deltas are (a) the `r` key in
`cc-butler-decision-mode`, (b) notes/relays rendering to `open/` (unread) instead
of `done/`, and (c) the sender-footer check that gates propagation.

## 9. Verification plan (for when built)

- Receipt: `r` on a `note` emits a `read` reply to the sender, correlated to the
  note id; the sender reads it via `pending_events`.
- Lifecycle: `r` moves the doc `open/ → done/`; the ⚖ indicator decrements.
- Scope: `r` on a plain doc (no footer) marks read locally and sends **no**
  receipt.
- Audit: the read is recoverable from the archived message + receipt.
- Symmetry: a decision's `C-c C-c` still both answers and closes (no double
  receipt); `r` on a decision emits a read receipt without an answer **and leaves
  it in `open/`** (only `C-c C-c` closes a decision — an unanswered decision is
  never lost).
