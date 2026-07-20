# Gayini — path to 10 August

*The backbone. What we're shipping, what's done, what's left, who does it. Updated 20 Jul 2026. ~3 weeks out.*

## The operating rule (applies everywhere)

**Build with documented defaults. Do not gate on Adrian or Jana.** Where a call is needed (band structure, canonical percentile, display convention, paddock wording), make it, add a one-line "provisional — pending review" note, and keep moving. Send Jana one email and proceed regardless. We finish the work; they refine it later.

## Deliverables and status

| # | Deliverable | Status | What's left | Where it's done |
|---|---|---|---|---|
| 1 | **Site reports (66)** — per-site markdown: dashboards + site & paddock text | **5 of 66.** Template now defined (`GA_019` prototype) | (a) build the 61 missing site dashboards; (b) wire the plot→paddock join; (c) run the template ×66 | Template & spec: **design seat.** Batch build: **workstation** |
| 2 | **The deck** (Adrian / presentation) | Stocktake done (36 slides); mini-deck built | Rebuild the ~11 restate/reframe slides against the census; pick FRAME defaults | Plan: **design seat.** Build: **workstation** (CC, pptxgenjs) |
| 3 | **The paper / scientific writeup** | Framing settled (null + cover-vs-condition caveat); results locked | Draft it — intro, methods, the census result, Task J, limitations | **Design seat** (you + me), now |
| 4 | **Task J (2018) writeup** | Analytically complete | Write up with caveats; send Jana email once; do **not** wait | **Design seat** |
| — | *Enablers (do inline, not as projects):* D1 commit v4 · D2 area basis · figure registration · gitignore `fc_intermediate` | specs drafted | run them | **Workstation**, folded into #1/#2 |

## What is genuinely DONE (stop re-checking)

The all-pixel census — complete, reconciled, on-disk verified. Headlines locked: 9/0/0 no trend · dry→wet gradient · absolute flood zones · refugia signal · cover-vs-condition caveat. The DB is sound (32/32 release checks). Task J analysis is complete. The census summaries are materialised (three CSVs, in the workbook). These do **not** need more auditing.

## Not doing before Aug 10 (parked)

Rubric code audit · output-folder migration beyond the trivial bits · refugia per-pixel product *(only if it goes in the paper — decide when we draft that section)* · anything waiting on Adrian/Jana answers · CSIRO HCAS 3.3 integration.

## The split — so being off the workstation never blocks us

- **Design seat (now, laptop/chat):** finalise the site-report template → write the batch-build spec · draft the paper · lock the deck-rebuild plan with FRAME defaults · Task J writeup · Jana email.
- **Workstation (CC, when you're on it):** batch-build 61 dashboards + 66 reports · rebuild the deck · run D1/D2/figure fixes.

## Immediate next actions (this week)

1. **Site reports:** you react to the `GA_019` prototype → I turn it into the batch-build spec (dashboards ×66 + paddock join + template runner). *[biggest deliverable — highest priority]*
2. **Paper:** I draft the outline + the results section from the locked census numbers; you steer.
3. **Deck:** I write the rebuild spec (which slides, which defaults) off the existing stocktake.
4. **Task J + Jana:** I draft the writeup and the one Jana email; you send it and we move on.

*Everything on this page is un-gated except where noted. The bottleneck is build time, not decisions — so the plan is to spec fast and batch on the workstation, not to deliberate.*
