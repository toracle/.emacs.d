# cc-butler — documents ↔ inbox coexistence (UX-design review)

Status: **UX-design review (not build).** For 정수님's review before the inbox
is built. The inbox build is on hold pending this; the harness / bug ④⑤ /
compose tracks proceed independently.

## 1. The tension (two things of different nature)

| | **Documents** (`show_document`, dashboard, PRs, docs/) | **Inbox items** (decisions, notes) |
|---|---|---|
| direction | **pull** — you go to them | **push** — they come to you |
| lifetime | **persistent** — stay, re-referenced | **transient** — pass after handling (sign & next) |
| grain | **whole overview / reference** | **per-case** |
| use | open → read → close → back to work; reopen later | process → answer → next |

Forcing both into one identical surface fights one nature or the other: a
sign-&-next queue makes a reference doc vanish; a persistent library makes a
decision nag forever.

## 2. The blur (why a clean split fails)

- **Briefings** are *documents that flow into the inbox* (pushed for 정수님 to
  read) — both natures at once.
- A **handled decision** may need **re-reference later** (like a document).
- So "documents vs inbox" is not a partition of *objects*; it is two *modes of
  attention* — "what needs me now" vs "what I'm reading" — and the same object
  can pass through both.

## 3. Concept model — separate the QUEUE from the READING SURFACE

The reconciling move: don't unify the *objects*; unify the **reading surface**,
and keep a separate **pending queue (index)**.

- **Reading surface** (the doc-view panel): the *one* place anything is
  displayed and read — a reference doc, or the detail of an inbox item. One
  umbrella, one addressing scheme. (Static reference and inbox detail are read
  in the *same* surface.)
- **Pending queue** (the inbox): an *index* of "what needs me" — the push,
  transient items (decisions/notes/briefings), with an unread badge. It is not a
  second reader; it is the **to-do list** that *feeds* the reading surface.
- **Done/archive**: handled items leave the queue but stay **re-referenceable**
  (openable into the same reading surface later — like an email's All-Mail).

So: *pull-reference* = open a document into the reading surface directly.
*push-queue* = an item lands in the queue (badge), you open it into the same
reading surface, handle it (sign & next), it leaves the queue but stays readable.

## 4. Options

**Option A — two surfaces (Library + Inbox).** A persistent "Library" view of
all documents + a separate "Inbox" queue. *Pro:* clean nature-match. *Con:* two
places to look (breaks 정수님's "one umbrella"); briefings must pick a home; more
UI.

**Option B — one typed list (everything is a list item).** A single list mixing
documents and inbox items, distinguished by kind/state, with filters ("needs
action" vs "reference"). *Pro:* literally one surface. *Con:* mixes static +
flowing in one list — clutter; "browse reference" and "sign & next" are different
rhythms crammed together; a persistent dashboard as a "list item" is awkward.

**Option C — one reading surface + a pending queue (recommended).** §3: the
doc-view panel is the single reader; the inbox is the *pending index* that feeds
it; done/archive keeps handled items readable. *Pro:* honours both natures
(pull-read vs push-queue) with **one place you actually read**; the briefing blur
is natural (a queued item that is also a readable doc); re-reference is just
reopening from done. *Con:* two *concepts* to learn (the queue vs the reader) —
mitigated because the reader is shared, so it feels like "a to-do badge on top of
the doc view you already have".

## 5. Recommendation — Option C, and how the axes resolve

1. **One surface vs two?** One *reading* surface; the inbox is an *index/queue*,
   not a second reader. Effectively one place to read, one to-do badge.
2. **Do documents enter the inbox?** Only **pushed** ones (briefings, decisions,
   notes) enter the *queue*. Pull-reference docs (dashboard, PRs) are opened into
   the reading surface directly; they may also be *listed* under a "reference"
   heading but never nag as unread.
3. **Moving between static reference ↔ flowing queue?** Same reader; you either
   open a reference doc (pull) or `Enter` a queue item (push). The ⚖ badge is the
   only "flowing" signal; nothing auto-switches your view (guarantee 4).
4. **Re-reference a handled item?** Yes — handled → done/archive, reopened into
   the reading surface from the inbox's "done" view or by link. Persistent.
5. **Session ↔ document ↔ inbox flow?**
   - *In a session:* open a doc → read in the reading surface → close → back to
     the session conversation. Reopen anytime (pull).
   - *Inbox:* `i` → the pending queue (what needs me) → `Enter` an item → its
     detail in the reading surface → compose (bottom split) → sign → it leaves
     the queue → next item (or back to the list).
   - The reading surface is shared by both; the queue is the pending-index; the
     session is where work happens.

## 6. Interaction sketch (Option C)

```
 session (work)  ──open doc──▶  READING SURFACE  ◀──Enter item──  INBOX QUEUE (i)
      ▲                         (one reader:                      [⚖ n unread]
      └──── close/back ─────     ref doc OR item detail)          decisions/notes/
                                        │                          briefings
                                   compose ↓ (bottom split)              │
                                   sign & next ──────────────────────────┘
                                        │
                                   done/archive (re-openable later)
```

## 7. What this does NOT change

Independent of this model, already confirmed/live: arrival-no-disturb (badge
only), the compose bottom-split + one-step commit + sign & next, the 7
guarantees, and the doc-view bug fixes (④⑤) — all proceed on the harness. This
review only decides **how the inbox and documents coexist**, i.e. Option C:
*one reader, a pending queue feeding it, done stays readable.*
