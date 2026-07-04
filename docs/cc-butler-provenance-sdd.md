# cc-butler — relay fidelity / provenance (SDD)

Status: **design draft, for approval before build.** Design-parallel (inbox C is
built; this is the next design track). One thread with maildir B, the human
adapter / inbox, and the governance store — they all form **one document graph**.

## 1. Problem — a summary of a summary

정수님 says X. The butler digests it to X′, the steward digests X′ to X″, the
worker acts on X″. Each hop **re-summarizes**, and 정수님's actual words — the
verbatim intent — are **lost** by the time they reach the worker. The worker can
neither see what 정수님 really said nor trace a result back to its origin. This is
a **provenance** failure: fidelity and traceability decay per hop.

(The same shape as the "black-vs-dark-gray launch config" tell earlier: a
difference introduced upstream, invisible downstream — but here it is *meaning*,
not colour.)

## 2. Principle — verbatim SSoT + resolvable references (progressive disclosure)

Do not fight summarization — summaries are useful for *quick action*. Instead:

- **The verbatim original is the single source of truth** and is **preserved,
  never re-summarized.**
- Every relay carries a **digest** (act on this) **plus a resolvable reference**
  to the verbatim original (open this when precision matters).
- **Progressive disclosure:** a worker acts on the digest, and *resolves the
  reference* only when it needs 정수님's exact words.

This reuses the maildir bricks already in place — the **sortable timestamp**, the
**message id**, and **request/response correlation** — as the addressing for the
verbatim source. No new transport.

## 3. Three additions (SPT — on existing bricks)

1. **Preserve 정수님's answer verbatim.** The human adapter already records
   정수님's answer as a durable document (the decision doc → done/); the reply
   message carries the **exact words**. Rule: **no hop re-summarizes 정수님's
   verbatim answer** — it travels intact, id-addressable. (A digest may be added
   *alongside*, never *instead of*.)
2. **A worker dispatch carries a reference + appendix.** When the steward
   dispatches work derived from a decision, the dispatch message includes:
   *(a)* the **digest** (what to do), *(b)* a **reference** — the correlation
   id / path of the verbatim decision + 정수님-answer, and *(c)* optionally the
   **verbatim appendix** (the exact text attached). So the worker has both the
   quick digest and the ground truth.
3. **The worker can resolve / open the reference.** A worker reads the digest to
   act; when it needs the exact intent, it **resolves the reference** to see the
   verbatim original (progressive disclosure).

## 4. The document graph (cross-reference)

Correlation ids already link messages; make that a **traceable graph**:

```
  decision(id=D) ──answer──▶ 정수님-answer(in-reply-to=D, verbatim)
        │                              │
        │                       dispatch(references=D, digest + appendix)
        │                              │
        └───────── result(in-reply-to=dispatch, references=D) ◀── worker
```

Every node references its origin `D`, so any result traces back to 정수님's
verbatim intent. This is the **same substrate** as the inbox (decisions are
graph nodes), maildir B (correlation), and the governance store (documents as
nodes) — **one document graph**, not a new system.

## 5. Open questions for 정수님 (GATING — surfaced, not decided)

1. **Appendix format** — does a dispatch carry the verbatim **inline** (the full
   text attached, always available but heavier) or only a **link/reference** the
   worker resolves (lean, but needs resolution)? Or inline for short answers,
   link for long?
2. **Link resolution** — how does a worker resolve a reference id → the verbatim
   document? A tool (e.g. `resolve_reference(id)` → the verbatim text), a shared
   path, or the maildir archive by id?
3. **Worker-open UX** — how does the worker *see* the verbatim original — a tool
   result inline, a file it opens, or a rendered doc (like the human adapter
   renders for 정수님)?

## 6. SPT / reuse

No new transport, no new framework: reuse the maildir timestamp + id +
correlation as the reference/addressing, the human adapter's durable done/ as the
verbatim store, and the existing dispatch (`send_to_session` / the channel) to
carry digest + reference + appendix. The only real additions are the three of §3.

## 7. Verification plan (for when built)

- Verbatim preserved: 정수님's answer text at the worker equals the text 정수님
  wrote (byte-for-byte), with any digest *additive*.
- Reference resolvable: a worker given a dispatch can resolve its reference id to
  the exact verbatim original.
- Traceable: from a worker's result, following `references` reaches 정수님's
  verbatim answer and the originating decision.
- Progressive disclosure: the worker acts on the digest without resolving; it
  resolves only when it chooses to.
