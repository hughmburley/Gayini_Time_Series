# T8 / T9 / T10 — design-seat decisions on Gate A recon

**Version:** v1 · 28 July 2026
**Amends:** `Gayini_reference_state_specs_T7_T11.md` v1
**Responds to:** `T8_T9_T10_gateA_recon.md`, SHA 7fe6808

Recon accepted. All three STOPs were correct. Decisions below, in the order CC asked.

---

## 1. T9 — RATIFY CLOSE AT GATE A

**The premise was mine and it was wrong.** Wet pixels carry more cover at every percentile,
most strongly at the floor (+24.4 pp at p05), and the pattern holds in all four reference
paddocks including the two wet ones the premise named. Masking water would push the floor
down, not up. The stopping rule in the spec was met exactly as written.

Do not run T9 Gate B.

### One addendum, if it is cheap

CC already holds the extraction. If it costs one pass and no new tooling:

> Of the pixels that constitute the **bottom 5% of each paddock-year** (the pixels that *set*
> `veg_p05_spatial`), what share carried `wet_any == 1`? Report against each paddock's overall
> wet share for that year.

If wet pixels are not over-represented in the tail, L-3 closes by direct measurement rather
than by inference from a group mean. The current evidence — p05 of the wet group at 74.4,
above every paddock floor — already implies it, but the implication is one step longer than
it needs to be. **If this is not cheap, skip it; the existing evidence is sufficient to close.**

### Consequence — the word "confound" was wrong

L-3 graduates to the limitations register as **tested and closed**, not as an open concern.

More importantly, this changes how the wetness relationship should be described everywhere,
including the deck. Water is not a measurement artefact contaminating the floor. **Water is
the ecological driver of the floor.** Inundation greens this floodplain; drier paddocks
genuinely carry lower floors because they genuinely carry less cover in their worst ground.

So the between-paddock relationship at T10 is not a confound to be removed. It is the main
effect. The management question is what remains *after* it — which is exactly what T10 Gate C
was specified to measure, so the task is right even though my framing of it was not.

Methods §7 and the deck's slide 18 both need rewording on this point. Design-seat action, not CC's.

---

## 2. T8 — CATALOGUE SUPPLIED; ENUMERATION IS A DESIGN-SEAT ARTEFACT BY NATURE

`Gayini_reference_state_results_catalogue.xlsx` exists but was never committed — it is a
design-seat output. That is a spec defect on my side: I referenced a path CC could not reach.
The file is being committed alongside this amendment.

**Do not expect the 18 numbers to be derivable from the database.** Which numbers count as
headline numbers is a curation decision about what reaches a deliverable, not a query result.
That is precisely why they need pinning: nothing in the schema currently distinguishes a
number that appears on a slide from one that does not. `dim_headline_number` is the object
that makes the curation explicit and testable.

Two amendments to Gate B:

- **Follow the existing pattern.** CC found `v_presentation_headlines_live` (9 rows) carrying
  `support`, `source_artefact`, `source_asset_id` and `caveat`. Where `dim_headline_number`
  can reuse those column names and semantics, it should. Report any place the two objects
  would disagree about the same number.
- **Include the eight numbers CC has already reproduced live** (the three-arm rollup pair and
  the reference-gap ordering pair) as the first rows. Their spread is measured; they do not
  need re-deriving.

Gate A can now run as written.

---

## 3. T10 — PROCEED TO GATE B, WITH THREE AMENDMENTS

### 3a. Do NOT reconcile to my regression

The r = 0.710 / slope +0.548 figures were computed in a chat session, outside the pipeline,
with no registration and no review. **They are not a target.** Recompute independently from
`fact_zone_veg_annual`. If the result disagrees with mine, mine was wrong — report the
difference and carry on with yours. Treating an unregistered number as ground truth is the
failure mode this whole task exists to fix.

### 3b. The five-period table is NOT to be rebuilt as the primary result

I-29 is correct and it is worse than a missing script. The boundaries are uneven — 5, 10, 10,
6 and 4 years — and nobody can say where they came from. Undocumented, unequal boundaries
chosen at unknown time relative to seeing the data are a forking-paths risk regardless of
whether anyone intended one.

I tested whether the boundaries were doing work (design seat, unregistered — treat as a
prediction to check, not a result):

| periodisation | gaps (pp) | narrowing |
|---|---|---|
| deck 5-period, no script | −13.1 −11.4 −7.9 −5.7 −5.6 | monotonic |
| equal decades | −13.2 −9.8 −7.1 −5.5 | monotonic |
| two-window, has a script | −13.1 −5.7 | monotonic |
| equal thirds | −12.6 −8.0 −6.2 | monotonic |

The narrowing survives every periodisation, so the boundaries were **not** doing the work.
That is reassuring — but it is a reason to adopt a defensible periodisation, not a licence to
keep an undocumented one.

**Gate B primary output: the annual gap series with a fitted trend, no period boundaries at
all.** One value per water year, a slope, an r, and a standard error. This removes the
boundary decision from the analysis entirely.

Report the five-period and two-window versions as sensitivities beneath it, so a reader can
see the choice did not matter.

My own annual fit, again as a prediction to check rather than a target: slope +0.273 pp/yr,
r = 0.770 for all four reference paddocks; slope +0.057 pp/yr, r = 0.222 excluding Bala 29ca.
If that holds, **the convergence is as much a single-paddock artefact as the gap is** —
without Bala 29ca the gap is not merely small, it is not narrowing either. Check it; do not
assume it.

### 3c. Gate C residuals are the headline, not a supporting analysis

Given 1 above, reorder Gate B and Gate C in emphasis. The question is no longer "does the gap
survive removing a confound" but "which paddocks sit above or below the floor their water
regime predicts." Report the full 64-paddock residual table, with the four reference paddocks
and Dinan 10 identified, as the primary output of T10.

---

## 4. Blocking status for 10 August

I-29 blocks the deck's central table. Slides 7 and 8 of
`Gayini_reference_state_review_v3.pptx` carry numbers with no producing script. **They cannot
ship in that form.** Either T10 Gate B lands and the annual-trend version replaces them, or
those slides come out. This is now the critical path item for the reference-state deliverable.

## 5. Sequence from here

1. T8 Gate A — unblocked, catalogue supplied
2. T10 Gate B and C — unblocked, amended per 3a–3c
3. T9 — closed at Gate A; addendum only if cheap
4. T7 — unblocked; does not depend on T8 Gate B, correcting the original spec
5. T11 — after T10 Gate C, so the residual panel can be built with the other two

## 6. Standing amendment to all five specs

Any number produced in a design-seat chat session and quoted in a spec is a **prediction to be
checked**, never a target to reconcile to. Where CC's independently computed value disagrees
with a design-seat value, CC's value stands and the disagreement is reported. This applies
retrospectively to every figure quoted in `Gayini_reference_state_specs_T7_T11.md` v1.
