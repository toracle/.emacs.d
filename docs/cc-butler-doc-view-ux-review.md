# cc-butler doc-view — UX review & test-harness design

Status: design/review draft. Adapts a web design-review to the Emacs **TUI**
context (like cli-rust re-cast web review for terminals). This review defines
**what the doc-view must guarantee**; the UX-narrated BDD (below) verifies those
guarantees against a **faithful-fake** surface, and bugs ④⑤ are fixed test-first
on it.

## 1. UX guarantees (what "good" means) — by dimension

Each guarantee is a *user-observable* promise, not an internal detail.

1. **Navigation safety (least-surprise).**
   - At the last document, `n` (next) keeps the user on a valid document (wrap or
     stop) and **never blanks/closes the panel**.
   - At the first document, `p` (prev) likewise — **the panel never vanishes.**
     *(Violated → bug ④.)*
   - Every move gives a position signal: *"doc 3/15 — <label>"*, so the user
     knows where they are and that the edges are edges.

2. **Discoverability.**
   - Every operation is reachable from a single discoverable menu: `?` opens a
     hydra listing **all** ops, including the **close (`q`) / reopen (`v`) pair**
     so a closed panel is recoverable. *(Violated → bug ③: reopen `v` is hidden,
     old `C-c d d` removed with no signal.)*
   - Familiar/legacy bindings are documented, not silently dropped.

3. **Key consistency.**
   - One scheme; the same key means the same concept across the doc-view and the
     decision viewer: `r` read · `c` confirm/answer · `k` remove · `n`/`p` nav ·
     `g` reload · `q` quit · `?` menu. Divergences (e.g. `w` browse) are only
     *additions*, never re-meanings.

4. **Feedback / state signals.**
   - Arrival of a new document signals without stealing focus (the ⚖ indicator).
   - Actions confirm (a message on read/answer/remove); the current tab is
     visibly the selected one.

5. **Mode-line cleanliness.**
   - A read-only viewer shows **no spurious "modified" `*`** and **no "invalid"**
     mode-line construct; the lighter is a small, valid string. *(Violated →
     bug ⑤.)*

6. **Edge / error grace.**
   - Empty panel, a dead document buffer, an unreadable file, "no more
     documents", "no open decisions" → a **clear message**, never a crash and
     never a silent panel close. *(Bug ④ is this class: navigation onto a
     dead-buffer document closes the panel instead of recovering.)*

7. **Destructive-action & mode safety.** *(added — a real data-loss incident:
   typing "OK" fired `k`=kill, closing the view and losing the comment.)*
   - **The fundamental fix (정수님): compose is a *dedicated buffer*, not inline.**
     Like `org-edit-special` (`C-c '`) / magit: the viewer stays a **pure
     command-mode** read-only surface; to answer, `c` opens a **separate compose
     buffer** (its own major mode / template) where you write freely; committing
     returns the text into the doc's answer region. Because there is **no inline
     editing in the viewer at all**, mode-confusion and destructive-key misfire
     are *structurally impossible* — a stronger guarantee than the inline guard.
   - **Safety net (already live):** the inline char-property guard (answer-region
     letters self-insert, only `C-c C-c` submits) stays, so even inline editing
     can't lose text. Dedicated-buffer compose supersedes it as the primary UX.
   - The current **mode is always visible** — viewer (command) vs a compose
     buffer (its own mode-line) — so a keystroke is never a surprise.
   - **Entering compose is discoverable** (`?` hydra + a signal), and `k`
     **removes a document without closing the panel** (stay on a neighbour; same
     family as the `p`/bug④ delete-window fault).

   **Compose mechanism (정수님-confirmed):**
   - `c` → a dedicated compose buffer opened as a **bottom split below the doc**
     (`org-edit-special` pattern; the answer region modelled as a source block —
     reuse if clean, else a parallel impl).
   - **Commit (`C-c '`) does both** (simplified, per 정수님): it writes the answer
     back into the doc's answer region (**record / audit** — decision text +
     options stay read-only) **and** pushes it down the channel to the asker.
     One step; no separate submit.
   - **Sign & next:** on commit the doc is **archived (open/ → done/), removed
     from the view, and the next open decision opens automatically** (or the
     inbox list returns) — "sign, next; sign, next", never a manual kill-buffer.
   - Compose buffer mode: org / an RFC template per `decision-proposal-format`.

## 1b. Surface & authoring rules (from the same incident)

- **Answerable vs reference.** A document that **needs an answer** (a
  product-gate decision, anything the boss must decide) must be rendered through
  the **human adapter / channel** (answer region + `C-c C-c`, correlation reply)
  — never as a plain `show_document`. `show_document` is for **briefing /
  reference** only. Rule for the surface unification: *needs-answer → channel;
  reference → show_document*. (The incident: a hand-`show_document`'d doc looked
  answerable but wasn't.)
- **Authoring style.** A rendered decision (or butler briefing) is written
  **RFC / narrative** style — background, rationale, options, the reasoning
  behind the recommendation, enough simulation — per the refined
  `decision-proposal-format`. Not a bare question.

## 1c. Inbox model — list-first (정수님)

"One surface" = **one umbrella = one inbox**. The doc-view IS 정수님's inbox: a
durable **list** you browse, not windows that pop at you. Concretizes the earlier
"surface unification": auto-popup → a *browsable* inbox.

- **List, not popups.** Decisions, notes, briefings appear as a durable list of
  items (open + recently done), sorted; you *look at the list*.
- **Unread count in the sidebar** — next to the butler in the Claude session
  list, like an email unread badge (the ⚖ count).
- **Keys:** `i` → enter the inbox list · `n`/`p` → move within the list · `Enter`
  → open the item's detail · answer via the compose bottom-split · then **return
  to the list** (sign & next). One umbrella; one addressing scheme.
- **Email-client feel but simpler — NOT Gnus** (정수님 explicit: too complex).
- **Consistent with guarantee 4 / arrival-no-disturb:** an arrival updates the
  *list + unread count only*, never the view you're in.
- Storage stays two dirs (adapter `decisions/` + manual `~/.ccsm/docs/`); the
  *view* is one browsable list across both (global-consistency: one view, two
  homes).

## 2. Faithful-fake harness (non-tautological)

**Principle (정수님):** the parts that touch Emacs (buffers, windows, mode-line)
are the doc-view's *external interface*. Put them behind a small **surface**
port with two adapters:

- **real** — actual `find-file-noselect` / `split-window` / `set-window-buffer`
  / `delete-window` / mode-line.
- **fake** — an in-memory model that **faithfully mimics observable state**: the
  ordered doc set, the current index, whether the panel is visible, and which
  buffer/label it shows, plus the mode-line string.

**Non-tautological rule:** tests assert on the fake's **resulting state and
observable behaviour** — *"after `p` at index 0, the panel is still visible and
shows a valid document"* — **not** on "was `hide` called". A call-spy that
asserts its own calls is tautological and passes even when the logic is wrong.
The fake must be faithful enough that wrong logic produces a wrong *state*, which
the assert catches. The mock channel (`cc-butler-mail-test`) is reused/extended
for the transport side, and the **same BDD passes the fake and the real
adapter** — the fake's contract == the real adapter's contract.

Surface port (minimal, driven by the guarantees):

```
(cl-defstruct cc-butler-doc-surface
  open-doc      ; (kind ref) -> a doc handle (buffer id)   [render]
  show          ; (handle)   -> panel now shows handle      [window]
  hide          ; ()         -> panel not visible
  visible-p     ; ()         -> bool
  shown         ; ()         -> the handle currently shown (or nil)
  modeline)     ; (handle)   -> the mode-line string for that doc
```

The panel **logic** (add / step / remove / hide / reopen / index-link) is
rewritten against this port; the fake records *state*, the real adapter does the
Emacs calls. `apply-doc-layout`'s "close when no current buffer" becomes a
port-level `visible-p`/`shown` fact the fake exposes.

## 3. UX-narrated BDD (expectations, not internals)

- **first-doc prev keeps the panel (bug ④ regression):** Given a panel of 3 docs
  showing #1, When the user presses `p`, Then the panel is still visible and
  shows a document (wrap→#3 or stay→#1), and a position signal is shown.
- **last-doc next keeps the user oriented:** Given #3 of 3, When `n`, Then still
  visible on a valid doc with a signal.
- **dead-buffer navigation recovers, never closes:** Given the current doc's
  buffer died, When the panel refreshes, Then it shows another doc or a clear
  "document unavailable" message — the panel does not silently close.
- **close then reopen preserves the set:** Given 3 docs, When `q` then `v`, Then
  the same 3 docs and the same current index are shown.
- **remove adjusts the index:** Given #2 of 3 shown, When `k`, Then 2 docs remain
  and a valid neighbour is shown (index clamped in range).
- **tab accumulation:** Given show_document called for A then B, Then the panel
  has 2 tabs and shows B (newest), navigable back to A.
- **mode-line clean (bug ⑤ regression):** Given a read-only doc, Then its
  mode-line has no "modified" `*` and no "invalid" segment; the lighter is a
  small valid string.
- **decision render integrity:** Given a decision doc, Then the answer region is
  editable, the rest read-only, org highlighting (major mode) preserved.
- **transport e2e (fake transport):** Given a decision shown in the panel, When
  the user answers and submits, Then the reply reaches the origin session's inbox
  via the channel — same scenario green on the fake and the real adapter.
- **discoverability:** Given the viewer, When `?`, Then the menu lists r/c/k/n/p/
  g/q **and v (reopen)**.
- **compose is a dedicated buffer (guarantee 7):** Given a decision in the
  viewer, When the user presses `c`, Then a **separate compose buffer** opens and
  the viewer buffer accepts **no inline edits** (it stays read-only command-mode);
  When the user commits (`C-c '`), Then the text is in the doc's answer region and
  the viewer is command-only again — and a destructive key in the viewer while a
  compose buffer is open still cannot touch the composed text.
- **compose → record → submit:** Given a committed answer in the doc's answer
  region, When submitted, Then it routes to the origin session via the channel
  (same scenario on the fake and real transport), and the answer remains recorded
  in the doc for audit.

### Compose — resolved (정수님)

- **Reuse `org-edit-special`** (model the answer region as an Org source block);
  parallel impl only if reuse is unclean. *(SPT.)*
- Compose buffer opens as a **bottom split below the doc**.
- **One step:** `C-c '` (commit) writes the answer back into the doc **and**
  pushes it down the channel — no separate submit.
- **Sign & next:** commit archives the doc (open/→done/), removes it from the
  view, and opens the next open decision (or returns to the inbox list).
- Compose buffer mode: **org / an RFC template** per `decision-proposal-format`.

## 4. Coverage (guide, not goal)

Measure with `undercover.el`/`edebug` to surface untested branches (e.g. the
dead-buffer edge, empty-panel). Coverage **finds blind spots**; it does not
license tautological tests to hit 100% — SPT: meaningful asserts first.

## 5. Sequencing

UX review (this) → faithful-fake surface + UX-BDD → bugs ④⑤ **test-first**
(failing regression → fix → green) → then the pending UX (decision→panel surface
unification, index-link nav, hydra reopen) built **on this harness**. Reversible,
worker-untouched, B Tier-1 intact.
