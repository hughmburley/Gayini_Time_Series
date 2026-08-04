# Task U · Gate U2 — design-seat response

**Date:** 1 August 2026 · **From:** design seat · **To:** CC
**Re:** `docs/change_reports/TaskU_gateU2_report.md`, `main:77ffe9b`
**Spec:** `docs/LiDAR/TaskU_lidar_structural_lens_v1.2.md` + amendment log

**Gate U2 accepted. Start Gate U3.** One new pre-registered rule below, to be pinned
before U‑Q4a computes anything.

---

## 1 · The Bala wet-fraction table reframes U‑Q1, and not the way the report has it

The report reads 29ca's 13.9% wet fraction as evidence the floor deficit is
"substantially hydrological rather than management history", and frames U‑Q1 as
distinguishing **structural from hydrological**. Both need adjusting.

### 1a · It is not a rival explanation — it is the project's own headline mechanism

The spine says flood frequency sets the drought floor, and that p05 rises roughly 2.2×
faster than p50 across the gradient. 29ca floods at one fifth its neighbours' rate. **A
low floor there is what the spine predicts.** The finding is therefore not "here is a
competing hypothesis to clearing" but "**the reference-state anomaly may be an ordinary
instance of the result we already published**".

That converts a qualitative argument into a quantitative test, and the test needs no
LiDAR:

> **R6 · Floor-versus-flood placement of the Bala paddocks.** *(pre-registered, pinned
> before any value is computed)*
>
> Fit the floor-versus-flood-frequency relationship on the all-pixel census at **pixel
> support**, **within community**, using the census long-run flood frequency — not
> annual wet fraction. Place all four Bala reference paddocks on that fit and report
> **each paddock's residual**, signed, with its community and n.
>
> Reported whatever the sign. The fit is **not re-specified after seeing the
> residuals**, and no paddock is excluded from the fit on the basis of its residual.
> Report the fit's own scatter so a residual can be read against it.

**Why this matters for U‑Q4a.** If 29ca sits **on** the curve, dryness accounts for the
deficit and there is no reference-state anomaly left to explain. If it sits **below**,
the residual is real — and *the residual*, not the raw 42 pp gap, is what the LiDAR
structure test should be aimed at. Either way U‑Q4a gets a sharper target than it has now.

Run R6 **before** U‑Q4a. It is a database query.

**A variable trap to avoid inside R6.** §3's Bala table is **annual wet fraction in a
single water year**. The census gradient is **long-run flood frequency over 35 years**.
These are different variables on different scales and must not be substituted for one
another. Any statement placing 29ca on the census curve uses the census variable.

### 1b · "Hydrological" and "structural" are not separable on this property

Dryness here can be manufactured. Banks and levees built to keep water off cropped
country is precisely what Task J is about. **If 29ca was cropped, its low inundation may
be a consequence of the management history rather than an alternative to it.** A paddock
flooding at 13.9% in the wettest year in the gauge record, while its three neighbours
reach 66–81%, is either topographically high or hydrologically isolated — and those look
very different in a DEM.

So U‑Q4a's question is not "structural or hydrological" but:

> **Is 29ca's hydrological isolation natural or engineered?**

Amend the U‑Q4a framing accordingly.

### 1c · A cheap check that follows from this — visual only

Banks are linear, sharp-edged and unmistakable at 50 cm. The 2009 `bb0` is already
warped and on disk. **Look at Bala 29ca and its three neighbours in the 2009 DEM and say
what you see** — engineered linear features on 29ca's boundary or not.

This is a **visual inspection reported in prose**, not an analysis: no roughness metric,
no derived surface, no numbers, nothing registered. If it shows something, it comes back
here as a candidate for a properly specified test. If it shows nothing, say so in one
line. Timebox it; it is not allowed to grow.

---

## 2 · Gate E, and a pre-registration hazard to name now

This closes a loop. T2 Gate E found the reference set heterogeneous enough to make
distance-to-reference undefined as specified. **Now the mechanism is visible:** one of
the four reference paddocks sits in a different hydrological regime from the other three.

That is useful, and it is also the exact place the project is most exposed.

**Dropping 29ca from the reference set would raise the reference floor and narrow the
reference-versus-grazed gap** — a convergence-favourable move, made after seeing the
data, on a project that pre-registered specifically to guard against that pressure.

**No change to the reference set is made inside Task U.** If R6's residuals suggest one,
that comes back to the design seat as a decision. Any redefinition must be justified on a
rule stated independently of its effect on the answer, and **both versions reported**.
Flagging it here so it is on the record before the numbers exist, not after.

---

## 3 · Accepted as reported

- The **two-candidate-water-year** treatment. Reporting both rather than collapsing is
  right, and the shaded two-year band on the figure is the correct visual grammar for it.
- **Direction robust, magnitude not** — and the §5 licensing block is the right way to
  carry that. Hold that boundary in every U‑Q3 and U‑Q4c sentence.
- The **within-unit tercile** warning, twice. Aeolian 6.64% and Inland 64.05% both
  reading "high" is exactly the kind of thing that reaches a deliverable and misleads.
- **R in place of matplotlib.** Correct, and for the stated reason: one-transaction
  write-and-register is strictly better, not merely equivalent.
- The `#2166AC` collision catch and the third incidental convergence demonstration.
- **C1 applied** — the structural reading of the density diagnostic withdrawn.
- R5 and U3.6 amended into v1.2 in place with a dated log, no v1.3. Do the same with R6.

## 4 · Adrian — question 2 upgraded, and the email is worth sending today

Agreed that flight months moved from nicety to the cheapest available improvement:
knowing them collapses four candidate readings to two and removes the 20.8 pp / 4.4×
spread from every change statement in the task. Still not gating. The email as drafted
covers all three; send it today rather than next week.

## 5 · Sequence from here

1. **Gate U3** — the sensor step-change verdict, including **U3.6**'s density-scaling
   test on the 1.0622 → 1.4672 `bb5` step. STOP as specified; the verdict is a science
   decision and a density-derived correction is never applied silently.
2. **R6** — before U‑Q4a. Database query.
3. **§1c** — the DEM visual, timeboxed, prose only.
4. **Gate U4**, U‑Q4a first, reframed per §1b.


*(corrected 4 August 2026, LID-1 Y1: was **1.4855**, computed on `d4`-only 2021 data before the U-I11 re-run and never refreshed. The artefact `taskU_gateU1_r2_density_diagnostic.csv` reads 1.4672. The qualitative claim is unchanged — 1.0622 → 1.4672 is +38.1%, still ~40% — and U3.6 regresses on block density differences rather than this median, so no conclusion moves.)*
