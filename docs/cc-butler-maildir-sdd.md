# cc-butler — maildir message bus (SDD)

Status: **design draft, for approval before build.**

## 1. Problem

Inter-session messaging in cc-butler is currently three ad-hoc mechanisms:

- **input-box typing** (nudge forwarding, `send_to_session` down to workers) —
  injects into a session's terminal input. It pollutes the human's box (just
  fixed for the butler), needs a manual/auto Return, and is the *only* way to
  wake an idle agent — the two concerns (wake vs. content) are conflated.
- **in-memory queues** (`cc-butler--inbox`, `cc-butler--butler-inbox`) — lost on
  a daemon crash, not auditable, not visible across restarts.
- **no down inbox** — messages to a worker can only be typed at it.

We want **one** durable, lock-free, auditable message bus, borrowing the Unix
**maildir** pattern, with the audit trail falling out as a byproduct (a core
boss requirement).

## 2. Maildir, and its known issues (research)

Maildir (D. J. Bernstein, qmail) stores each message as its own file across
`tmp/`, `new/`, `cur/`. **Delivery is lock-free:**

1. writer creates a uniquely-named file in `tmp/`, writes it fully, `fsync`s;
2. `rename()` it into `new/` — atomic within a filesystem, so a reader in `new/`
   never sees a partial message;
3. a reader processes a `new/` message and `rename()`s it to `cur/` (seen).

No locks: partial writes are quarantined in `tmp/`; visibility is flipped by one
atomic rename. Contrast mbox, whose single-file appends needed locking ("lock
hell") — maildir exists precisely to avoid that.

**Known issues and how they bear on us:**

| Issue | Reality | Our mitigation |
|-------|---------|----------------|
| "lock hell" | maildir *avoids* it; the risk is two readers grabbing the same `new/` file | each inbox has **one** consumer (the owning agent); a losing `rename` = "someone else took it", treat as no-op |
| NFS | `rename` is atomic on modern NFS; DJB's original used `link()`+`unlink()` for old NFS; `readdir` caching delays new-file visibility | design stays **NFS-safe** (unique names carry host; deliver via `link`→`unlink` fallback) but we run **local first**; poll interval absorbs readdir lag |
| ordering | directory order ≠ chronological | embed a **sortable timestamp** prefix in the filename; readers sort `new/` before processing |
| stale `tmp/` | a writer that crashes mid-write leaves orphans | periodic **sweep** of `tmp/` files older than a TTL (DJB: 36h; we can use 1h) |
| `:` in names | the `:2,` flags separator is illegal on FAT/Windows | Linux/ext4 → fine; avoid `:` in our scheme anyway (use `.`) for portability |
| durability | a crash between write and rename loses the message | `fsync` the `tmp/` file **before** rename (low volume → cheap) — this is what makes the audit trail trustworthy |
| dir scaling | huge `new/`/`cur/` slow `readdir` | low message rate; **archive** rotation keeps dirs small |

## 3. Design

### 3.1 Layout — an independent, durable tree

Root `cc-butler-mail-dir` (defcustom), **outside** session context (not
`~/.claude`), e.g. `~/.local/state/cc-butler/mail/` (or `~/.cc-butler/mail/`).
This is the agent system's durable state + audit trail.

```
<mail-dir>/
  <agent>/                 one inbox per agent (butler, steward, each worker)
    tmp/   new/   cur/      maildir triad
    archive/                processed messages, kept for the audit trail
```

`<agent>` is the session's stable display name (the `.projectile` topic name),
slugified.

### 3.2 Message

A plist/JSON file: `(:id :time :from :to :kind :body [:needs …])`.
`:kind` ∈ `report | decision | dispatch | relay | note`.

Filename (ordering + uniqueness, colon-free, NFS-safe):
`<epoch-nanos>.<pid>-<counter>-<rand>.<host>.eld`

### 3.3 Deliver / consume

- **Deliver** `msg` to `<to>`: write to `<to>/tmp/<name>`, `fsync`, `rename` →
  `<to>/new/<name>`. (NFS fallback: `link` tmp→new, then `unlink` tmp.)
- **Consume** by the owning agent: list `<self>/new/` **sorted by name**; for
  each, read → act → `rename` to `<self>/archive/` (NOT delete → audit trail).
  (`cur/` is available if we later want a "seen but not archived" state; v1 goes
  straight to `archive/`.)

### 3.4 Poke policy — separate *wake* from *content*

An inbox is pull-based and cannot wake an idle agent; injection is the only wake
mechanism. So **split the concerns**:

- **content** always travels in the inbox (clean, durable, audited);
- **wake** is a *poke* — a minimal signal, **never the body**.

Poke rules:
- **User-facing butler: never poked.** The human drives it; it drains
  `pending_decisions` at each turn. Its input box stays pristine. (This is the
  bug we just fixed, generalized to a rule.)
- **Agent channels (steward, workers): poke allowed** — a one-line
  "you have mail — drain your inbox" typed + submitted to wake an idle agent,
  which then pulls the real content from its inbox. Never the message body.
- Poke can also be non-terminal where possible: a **manager-list indicator**
  (unread count on the agent's entry) for agents a human is watching.

### 3.5 Unify the existing tools onto the bus

| Tool | Direction | Now | On the bus |
|------|-----------|-----|-----------|
| `report_to_butler` | worker → steward | in-mem `cc-butler--inbox` | deliver `kind=report` to the steward's inbox |
| `escalate_to_butler` | steward → butler | in-mem `cc-butler--butler-inbox` | deliver `kind=decision` to the butler's inbox |
| `pending_events` | steward drains | drain in-mem | consume steward's `new/` |
| `pending_decisions` | butler drains | drain in-mem | consume butler's `new/` |
| `send_to_session` | butler/steward → worker | **type into terminal** | deliver `kind=dispatch` to the worker's inbox **+ poke** to wake it |
| *(new)* `check_inbox` | any agent | — | consume own `new/` (workers use this) |

**Down-direction to workers** is the notable change: instead of typing a prompt
into the worker, we deliver to its inbox and poke it. The worker's CLAUDE.md
(topic scaffold) gains a rule: *"at the start of each turn, `check_inbox` and do
what it says."* Tool **names/contracts stay the same** where they exist
(backward compatible); only the transport changes.

### 3.6 Backward compatibility

- Single mode and the existing tool names are unchanged; the bus is the new
  transport under them.
- A defcustom `cc-butler-message-transport` (`in-memory` | `maildir`) lets the
  bus be adopted incrementally and rolled back.

## 4. Open questions

- `<mail-dir>` default location (`~/.local/state/cc-butler/mail` vs
  `~/.cc-butler/mail`).
- Poke transport for agents: terminal one-liner vs. an OS/emacs notification —
  and whether workers reliably act on `check_inbox` (needs the scaffold rule).
- Do we need `cur/` (seen-but-open) or is `new/ → archive/` enough for v1.
- Archive rotation / retention policy for the audit trail.

## 5. Verification plan

- Concurrency: N writers deliver to one inbox simultaneously → all land in
  `new/`, none partial, unique names, none lost (temp-dir harness).
- Crash safety: kill between write and rename → orphan only in `tmp/`, swept
  later; no half-message ever in `new/`.
- Ordering: delivered-order == filename-sorted consume order.
- Audit: every consumed message present in `archive/` (nothing deleted).
- Poke policy: butler inbox delivery types nothing into the butler; worker
  dispatch pokes + the worker drains.
- Rollback: `cc-butler-message-transport in-memory` restores current behavior.
