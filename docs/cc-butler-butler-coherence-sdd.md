# cc-butler — butler coherence (CC on 정수님's message path) — SDD

Status: **design draft; the core is a simple CC-add, buildable test-first.**
One body with maildir B, the human adapter/inbox, and provenance (Via/CC) — the
butler is a **node on 정수님's message path**, not a router.

## 1. Problem — the butler is blind to 정수님's decision state

Measured: the butler's maildir (`.ccsm`) is empty, and every decision document is
addressed `to=cc-butler-steward`. So 정수님's `C-c C-c` answer routes **only to
the steward** (the escalator) — the **butler never learns 정수님 answered**.

Living evidence: the butler green-lit "0070" *after* 정수님 had already answered
that decision — a **duplicate instruction**, because the butler's view of 정수님's
decision state was stale. This is the §"surface ≠ delivered" pile-up root
(chat-path and inbox-path not reconciled), now on the butler side.

## 2. Principle — the butler is a VISIBILITY node, not a router

- Keep 정수님's answer **direct-routed** to the escalator (speed — do NOT funnel
  it through the butler; the butler must never be a bottleneck or a hop that can
  drop/delay the answer).
- ADD a **copy / receipt to the butler** (CC), so the butler is *coherent* with
  정수님's decision state — visibility only.
- The butler is thus a **Via/CC node** on 정수님's message path (ties to the
  provenance envelope's From/Via/Re — the butler appears as a CC recipient, not
  as From).

## 3. Mechanism — two CC points (reuse the maildir, no new transport)

1. **Arrival CC** — when a decision is rendered into 정수님's inbox, deliver a
   receipt to the butler: "a decision is pending for 정수님 (id/topic)". The
   butler knows what's awaiting 정수님.
2. **Answer CC** — when 정수님 submits (`C-c C-c`), *in addition to* the direct
   route to the escalator, deliver a receipt to the butler: "정수님 answered
   decision D → <answer>". The butler knows the outcome and won't re-issue it.

Both are `cc-butler--ch-deliver` to the butler agent (`cc-butler--mail-butler-agent`)
— the same maildir bricks, a copy alongside the existing route.

## 4. Reconcile chat-path ↔ inbox-path

The butler delivers to 정수님 via chat and reads answers there; the inbox is the
durable path. These two must **reconcile** — the Answer CC is exactly what lets
the butler close its chat-side loop against the inbox answer (preventing the 0070
duplicate). Same root, same fix shape as the 9-decision pile-up reconcile.

## 5. Open questions (GATING → 정수님's inbox)

1. **CC granularity** — a full copy of the decision/answer, or a terse receipt
   ("정수님 answered D: yes")? (Recommend: terse receipt — visibility, not bulk.)
2. **Butler's surface** — does the butler consume these via `pending_events`
   (its normal drain), or a distinct receipt stream it polls? (Recommend:
   pending_events — one inbox, no new channel.)
3. **Arrival CC scope** — CC the butler on *every* decision arrival, or only
   ones it did not itself originate? (Recommend: every arrival — cheap, and the
   butler wants the full picture of 정수님's queue.)

## 6. SPT

Reuse `cc-butler--ch-deliver` + the butler agent + the existing arrival/submit
hooks. The only addition is **a CC deliver at two existing points**. No new
transport, no routing change, no bottleneck — a copy on the wire. Because it is
this small, it can be **built test-first now** (assert the butler receives the
arrival + answer receipts) while the three open questions refine the shape.
