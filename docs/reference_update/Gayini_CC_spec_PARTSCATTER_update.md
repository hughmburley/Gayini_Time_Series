# Gayini CC spec — PARTSCATTER

**A part-grain companion to the TEMPORAL-1 scatter, requested by the client.**
Design seat, 9 August 2026 — supersedes the 9 August draft of the same name. Additive only.

---

## 0 · Standing execution rule

Run to completion in one pass and report once, in the `RUN_` schema of Ruling DP. Every fork carries
a pre-registered rule; a fork with a rule is not a question. Do not ask before writing. If a rule is
clearly wrong for what you find, override it, state that you did and why, and keep going.

Halt only on: grid mismatch against `veg_regime_class_8058.tif`; a registry write that fails or
cannot be made atomic; a required input absent after searching; unresolved repository divergence.

**Deadline: Monday morning, 10 August.** The client is replacing a slide in a presentation he gives
that day. Deliver the figure before anything optional in this spec.

---

## 1 · Why this exists, and what changed

The 64-paddock scatter carries an apology in its own subtitle: **55 of 64 paddocks are Inland
Floodplain-dominant**, so the colour legend is close to decorative and the fitted line is mostly a
within-Inland relationship.

**Parts are community-pure by construction.** At part grain the colour means something, Aeolian and
Riverine get real representation, and the caveat comes off rather than being explained away.

**This is now a client request, not a companion of our choosing.** The client asked for the
paddock × vegetation-community version explicitly, expecting more points and better representation
of the two communities the paddock figure under-serves. He intends to replace the paddock-grain
figure with it in his deck.

**In our own record the paddock-grain figure stands and is not replaced.** Both are registered; the
client's choice of which to show is his.

---

## 2 · The count the client is expecting — read this before building

The client's own slide, two before the figure, states **115 distinct paddock × community areas**, over
a legend of **eight** vegetation communities including Inland Floodplain Woodlands (Blackbox), Inland
Riverine Forests (Redgum) and Riverine Sandhill Woodlands (Cypress).

**This figure will have materially fewer points than 115, for two good reasons**, and the gap must be
stated on the figure rather than discovered in the room:

- The census is **non-treed only**. Under a canopy the satellite's ground-cover number does not mean
  what it means in the open, so treed communities are out of scope by design.
- Parts below the cell-count floor are dropped, because a mean over a few dozen cells is not
  comparable to a mean over thousands.

**Report the reconciliation as a chain**, each step with its count and area: total paddock × community
areas → non-treed → surviving the cell-count filter → plotted. If your total does not land on 115,
report both numbers and do not adjust anything to reach it — the 115 comes from a different layer
and a difference is information, not an error.

---

## 3 · Build

Same producer, same metric, new grouping key. **No raster is opened and no new metric is computed.**

- **Unit:** paddock × community part. The grouping key is the same for both axes — a part's x and y
  are both computed over that part's own cells, never the parent paddock's.
- **y:** mean over the part's cells of each cell's temporal 5th percentile of total vegetation —
  identical definition to the paddock figure, seasonal basis.
- **x:** the same water quantity the paddock figure uses, computed over the part's cells.
- **Colour:** community, from `gayini_veg_regime_classes()`. **Size:** cell count.

**Drop parts below 500 cells** and report the number dropped and their combined area.

**Fit one smoother per community, not one overall.** At part grain the communities are separable and
that is the entire reason this version exists. **Pre-registered fork:** if a community's water axis
spans too narrow a range to support a smoother, draw its points without a fitted line and say which
and why — do not extrapolate a curve across a gap, and do not fall back to a single overall line.

---

## 4 · Labels — Ruling EC applies in full

**y-axis:** the canonical label already registered in the caption register for this quantity —
`5th-percentile ground cover, mean of cells (%)`. Not slide 29's older wording, not `veg_p05`, not
"poorest seasons".

**x-axis:** names the quantity, the population and the time step, and reflects that the population is
the **part**, not the paddock. Whatever form you choose is registered as the canonical label for the
part-grain water quantity.

**No internal identifiers on the face** (EA): no `veg_p05`, no `fit_id`, no `number_id`, no issue
codes such as `(C10)`, no repository paths. The support sentence stands; its parenthetical does not.

**Seasonal-basis footnote** in the same plain words now carried by the dashboards and TEMPORAL-1.
The client has confirmed the seasonal basis in writing and it is settled — do not hedge it, do not
offer the annual alternative, and do not describe it as pending.

---

## 5 · Caption

The caption carries, in plain words for a non-specialist reader:

1. **What one point is** — one paddock × community area, averaged over its own cells.
2. **The count, and why it is not 115** — treed communities out of scope because ground cover under
   canopy is not comparable; small parts dropped. One sentence, stated as a design choice.
3. **Non-independence** — parts within a paddock are not independent (L-01), so any interval is
   display only and understates clustering.
4. **DA's wording where a community line is drawn.** Describe each community's own supported range.
   **Do not write "monotone in every community."**

**No p-values. No coefficient is taken from the smoother.**

**Cultural sensitivity:** this figure goes to a Tribal Council audience. Place and community names
follow existing report-stream usage exactly; introduce no new naming. Flag anything uncertain rather
than deciding it.

---

## 6 · Delivery

- **A single PNG at slide dimensions**, so the client can drop it straight into a 16:9 slide without
  rescaling. Filename plain and self-describing.
- Registered through `gayini_write_and_register_figure()` in one transaction, five qualifiers
  populated, no NULLs.
- Both new labels written to the caption register.

---

## 7 · Report

- **The reconciliation chain of §2**, with counts and areas at each step, and the comparison against
  115 stated either way.
- **Per community:** n parts, cell-count range, water-axis range, and whether a smoother was drawn.
  That table is what shows whether Aeolian and Riverine actually span enough range to carry a line,
  or whether the paddock figure's dominance problem has simply moved to a new grain.
- The two registered labels.
- Anything found and held.

---

## 8 · Constraints

Additive only; the paddock-grain figure is not modified or superseded in our record. Pixel support
throughout; no plot measurement enters (C10). `veg_p05_spatial` and `veg_p05_temporal_mean` never
appear in one figure. Any edit containing an escape, a newline or a multi-line string goes through a
file, never a shell heredoc (DS); parse-check before rendering.

---

## 9 · Ruling texts in force

Reject any citation of a ruling number for which you hold no issued text.

**AZ / CX** — `mean_flood` is the share of a unit's cells seen wet, mean over years. It is never
labelled a between-year frequency. AZ beats any conflicting spec.

**BB** — `Output/diag/*`, `Output/runs/*.md` and named tables are version-controlled for citability.
Un-ignore lines are targeted and verified with `git check-ignore -v`.

**CZ** — `number_id` at the point of quotation, not per table row.

**DA** — never "monotone in every community". Aeolian's wet end is 60 cells, Riverine's 69.

**DB** — 795,602 of 988,831 non-treed cells are inside a management zone. The unit table and the
community table describe different populations and neither may stand in for the other.

**DP** — every run writes `Output/runs/RUN_<TASK>_<DATE>.md` in the fixed schema: decisions needed,
checks, overrides, disagreements, artefacts, not done, rulings.

**DS** — any edit containing an escape, a newline, or a multi-line string goes through a file, never
a shell heredoc. Parse-check before rendering.

**EA** — internal identifiers do not appear on client-facing figure faces. This covers issue codes,
ruling letters, `number_id`, `fit_id`, and repository paths.

**EC** — every axis label on a client-facing figure names the quantity, the population it is computed
over, and the time step. No abbreviation of the quantity, no formula fragment in a parenthetical, and
no evaluative or interpretive wording. Where the full statement does not fit on the axis, the axis
carries the quantity and the subtitle carries population and time step, in the same words on every
figure showing that quantity. The same quantity is labelled identically across every product. A
figure that cannot be labelled precisely is not shipped until it can.

**L-01** — units within a shared parent are not independent; intervals over them are display only.

**C10** — plot support and pixel support are both correct at different scales and must never be mixed
in one figure.
