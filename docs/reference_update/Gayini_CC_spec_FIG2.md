# CC spec FIG-2 v2 — figure tweaks before the 10 August meeting

**Design seat · 7 August 2026.** Supersedes `Gayini_CC_spec_FIG2.md` (v1, same date). Follows the
FIG-1 rebuild instruction. Runs on the methods seat after pack v1.3 seals.

**What changed from v1**

| | change | § |
|---|---|---|
| 1 | Panels carry **both r and weighted R²**, not R² alone | 1 |
| 2 | **New: the bootstrap distribution figure** | 5 |

**Context that sets the priorities.** Adrian has **ten minutes for the whole project**; these figures
get the last two or three. **A number on a face that needs explaining is worse than no number.**

**No re-analysis and no refit.** §5 re-runs an existing bootstrap to recover its draws and must
reproduce the registered percentiles exactly. Nothing new is registered except where stated.

---

## 1 · Both statistics on each panel

Report **r and weighted R² together**, from the same fit:

| panel | r (stored) | weighted R² |
|---|---:|---:|
| C · whole record | 0.687384 | **0.47** |
| A · cropping era | 0.684 | **0.47** |
| B · post-management | 0.579 | **0.34** |

**Compute R² from the stored `r` in `PARTREG_part_regression_coefficients.csv` and
`PARTREG_S2_regression_coefficients.csv`. Do not refit.** Confirm each equals r² to four decimals and
report the check.

**Label it `weighted R²`, not `R²`.** The fits are pixel-weighted by part cell count, and an
unqualified R² invites a reader to recompute it unweighted and find a different number.

### 1.1 · What must NOT go on these figures

**No community R² and no within-unit R².** The Inland community fit (0.39) and the within-unit fit
(0.17) are different quantities across two estimands. A third number on the face invites a question
there is no time to answer.

**The within-unit R² is unregistered.** The v1.3 covering note states that no figure in the pack
shows the within-place number. It stays off every pack figure and remains in the covering note for
questions.

### 1.2 · Register the three R² values

They appear on a deliverable, so the five-qualifier rule applies: support level, scope filter, pixel
constant, denominator, period label. Three rows, additive, idempotent on re-run. **State on each row
that it is weighted**, and record the estimand as between-unit.

---

## 2 · Single-page residual maps — build both

The three-panel figure is legible as a set and illegible one panel at a time. Bala 29ca's thirds are
a few millimetres across.

**Same producer, loop over periods.** Three additional outputs, one period per page, at full width.

**Identical colour scale and identical ticks across all four outputs**, read from one constant so
they cannot diverge on a later run. **The corrected footer from the caption register goes on every
one.**

At full page the part labels and conserved outlines become readable, which they are not now. Add both
where the space allows.

**The three-panel figure stays in the pack.** The single pages ship alongside it, registered
separately in `figure_asset`, and the manifest distinguishes them.

---

## 3 · The unzoned figures — relabelled, and outside the manifest

Adrian receives `UNZONED_F1_between_units_two_sets.png` and `UNZONED_F2_within_response.png` **as a
separate attachment, not in the pack.** This keeps the covering note's sentence true while still
getting the figures to a collaborator who should see them.

1. Replace `INTERNAL · NOT FOR DISTRIBUTION` with
   **`PROVISIONAL · unregistered · for reference, not for onward circulation`**.
2. **Keep F1's red DESCRIPTIVE ONLY banner exactly as written.** It is the only thing preventing the
   figure being read as Stage A2.
3. **F2 panel B to densities, not counts.** 91 patches against 115 parts, so bar heights are not
   comparable and the unzoned distribution's apparent rightward shift is partly an n effect. Keep the
   91/91 and 115/115 annotation.

Not registered in `figure_asset`.

---

## 4 · The `veg_p05` label check — first, before anything else here

**"The same country, two ways of looking at it"** carries a colour-scale label reading
**`veg_p05 (%)`**.

If those panels plot the **spatial** floor — the across-cells-within-year quantity every part and
paddock number uses — the label names the **census temporal** floor instead. That is the pair the
ground-cover metadata record calls the single most confusable in the project, and the two differ by
up to 17 points at fine grain. **Both plausibly occupy the 30–80 range shown, so the figure cannot be
read to tell which it is.**

**Check the producer and report which quantity the panels actually plot.** If it is the spatial
floor, the label is wrong **in the current methods document**. **Do not fix it silently** — a
mislabel there has consequences beyond one axis title.

---

## 5 · The bootstrap distribution figure — new

**A methods and Q&A figure, not a presentation figure.** It needs a sentence explaining what a
bootstrap is, and that sentence does not fit in two minutes.

### 5.1 · What it shows, and what it does not

It shows **how much the fitted slope moves when the paddocks are resampled**. 

**It does not show how often the observed coefficient was found.** The bootstrap resamples around the
point estimate, so the observed value sits at the centre of its own distribution by construction and
the density there is high regardless. Any caption phrasing it as a frequency of the observed value is
wrong and must not be written.

### 5.2 · Reproduction first — this is a halt condition

The stored tables hold `boot_slope_p2_5`, `p50` and `p97_5`, **not the draws**. Recovering the draws
means re-running the bootstrap.

**Run with the recorded seed and reproduce the registered percentiles exactly before plotting.**
Assert it in code. **If any percentile does not match its registered value, stop and report** — a
histogram whose 2.5th percentile disagrees with the interval printed beside it is worse than no
figure.

Same draw count across every distribution on a panel, so counts are comparable and densities are not
needed.

### 5.3 · Two panels

**Panel A — the community finding.** Four distributions on one common axis: pooled `2.3_weighted`,
then `2.6_aeolian`, `2.6_riverine`, `2.6_inland`. The pooled and Inland distributions are compact;
the two chenopod distributions are wide and sprawl across a range that includes zero. **This makes
the community finding legible at a glance in a way the caption sentence does not.**

**Panel B — the grain check.** Paddock-grain against part-grain, two distributions almost entirely
superimposed. **Says "changing the grain moved nothing" better than "they differ by 0.0005".**

### 5.4 · Drawing rules

Style follows the existing overlapping-histogram treatment: semi-transparent fills, one common axis
per panel, legend top right, the clipped-tail convention stated if any tail is clipped.

- **Mark the observed coefficient** on each distribution, and the 2.5 and 97.5 bounds.
- **Do not draw a zero line.** Distance from the distribution to zero read by eye *is* a p-value,
  drawn rather than computed. It would also wreck panel A's axis — the pooled distribution runs 0.36
  to 0.75.
- **Let the axis span the draws.** Do not extend it to include zero.
- **No annotation of the form "X% of draws exceed Y".** That is the same p-value in a third disguise.
- State on the face: **2,000 draws, resampling paddocks with replacement, clustered on `zone_fid`,
  seed recorded.** And that 115 parts sit in 64 paddocks, so **64 clusters — not 115 observations —
  bound the precision.**

### 5.5 · Status

Register in `figure_asset` **only if it ships in a pack**. It is a methods-document and Q&A figure;
if it stays internal it stays unregistered, and the manifest says which.

---

## 6 · Gates

**Gate 1 · STOP.** §4's label check. Report which quantity the panels plot, before any other work
here.

**Gate 2 · STOP.** §1, with the r² arithmetic check and the three registered rows.

**Gate 3 · STOP.** §5.2's reproduction assertion — the recovered draws against the registered
percentiles — **before any bootstrap figure is drawn.**

§2 and §3 then run to completion and report once.
