# Task J — Gate 4 (the law and the four figures) — report, then STOP

**Branch:** `tier1j-prepost-placebo`. Descriptive only; **not** an effect estimate. Fit and rank are PRE-REGISTERED (pooled residual sd, ddof=1); no re-ranking, no regime-scaling, no p-value/CI from the placebo spread. Exit 0.

**Code:** `18_task_J_gate4_law.R` (law + heteroscedasticity), `19_task_J_gate4_figures.R` (6 diff rasters + 4 figures).
**Tables (small; commit via `git add -f`):** `task_J_gate4_law_summary.csv`, `task_J_gate4_residual_ranking.csv`, `task_J_gate4_heteroscedasticity.csv`, `task_J_gate4_raster_assertions.csv`.
**Figures (gitignored PNGs):** `Output/figures/maps/task_J/J-F1…, J-F2…`, `Output/figures/plots/task_J/J-F3…, J-F4…`.

## The finding — it shifted from the plot-support answer in the spec

| | plot support (spec/register) | **pixel support (this build)** |
|---|---|---|
| law | diff = +2.20 + 18.27·log q, R² 0.865, resid sd 3.95 | **diff = −1.44 + 19.62·log q, R² 0.864, resid sd 4.16** |
| 2018 predicted / observed | +5.20 / +11.47 | **+1.78 / +9.30** |
| 2018 residual | +6.27 pp, 1.59 sd | **+7.51 pp, 1.80 sd** |
| 2018 rank of 25 | 3rd | **2nd** |
| placebos exceeding 2018 | 2 (2009, 1994) | **1 (2005)** |

**C=2009 inverted.** At plot support 2009 was the *largest* residual (2.04 sd) and beat the real date at essentially the same flow (q 1.170 vs 1.179) — the fact that made "ordinary" defensible. **At pixel support 2009 collapses to +3.37 pp = 0.81 sd (rank 11)**, and 2018 more than doubles it at near-identical flow. The one date still above 2018 is **C=2005** — a placebo at the dry end (+8.67 pp, 2.08 sd), where the farm stayed *less* dry than the extreme low flow predicts. Nothing happened at 2005.

**Robustness** (both refits): `~ log q + n_pre_years` — flow coef 19.62 → 15.63 (−20%), R² 0.864 → 0.918 (rose), 2018 → 1.36 sd; `n_pre`↔`log q` corr = 0.632 (matches plot's 0.632). Independent-5 refit (1994,1999,2004,2009,2014): 2018 → 1.34 sd (residual sd 5.55, n=5, tiny). Across all three fits 2018 sits at **1.34–1.80 sd** — always positive, never trivial, never significance.

## Heteroscedasticity — a caveat ON the sd framing (evidenced, NOT acted on)

The residuals are strongly heteroscedastic, so pooled "sd" units are not comparable across regimes:

| regime | n placebos | residual sd | mean \|diff_pp\| | max residual |
|---|---|---|---|---|
| dry (q<0.6) | 13 | 5.13 | 21.82 | +8.67 (2005) |
| wet (q≥0.6) | 11 | 2.30 | 3.78 | +4.10 (2016) |

`corr(|residual|, |diff_pp|) = +0.566` (multiplicative error). This is recorded as a **caveat on the sd ranking, not acted on** — the q<0.6 split is post-hoc and re-scaling after seeing the answer is exactly what the placebo design prevents. Rank 2 stands as pre-registered.

**One scaling-free comparison** (needs no error model): among the WET-post placebos (q≥0.6, comparable wetness to 2018), the largest residual is **+4.10 pp (C=2016)**; 2018 is **+7.51 pp = 1.8× it**. Beside it, the largest DRY-post placebo is **+8.67 pp (C=2005)** — the one date above 2018 overall. **Both are true and they point opposite ways:** among comparable-flow dates 2018 is the largest; across all dates it is second.

## Figures (styling pinned; `gayini_theme_map(13)` + `gayini_change_scale_fill(60)`)

- **J-F1** — the 2018 difference map with paddock context. Subtitle corrected to *"Between-year flood frequency change, percentage points"* (not "Annual occurrence…", L25); caption appended *"Descriptive only: see J-F3."* Predominantly blue (wetter post-2018).
- **J-F2** — the six-panel ladder (1994, 1999, 2004, 2009, 2014, 2018), one shared legend, identical ±60 scale, 2018 marked by a heavier border. The point lands visually: **1994/1999/2004 are overwhelmingly red** (drier post, drought onset) at dates when nothing happened; 2018 is blue. Caption: "No cuts occurred at any date except 2018."
- **J-F3** — the law. Scatter of all 25, line + ±1 residual-SD band from the 24 placebos only, 2018 a red diamond above the band, **2009 labelled just below it at the same x, 2005 labelled at the dry end**. Annotated R²=0.864, predicted +1.78 vs observed +9.30, residual +7.51 pp, **rank 2 of 25**. The visible funnel *is* the heteroscedasticity. This figure carries the task.
- **J-F4** — 35-year annual series: whole-farm **wet extent** (% of farm wet each year) over flow, post-2018 window shaded, WY2022-23 marked. **Labelling note (L25):** the y-axis is the *per-year spatial extent*, not the headline between-year frequency (which is the multi-year window mean of it) — stated on the axis and in the caption. Flag if you intended the axis to read differently.

## Assertions / provenance

- **`ondisk` group re-engaged:** all 12 raster writes (6 × 28355 + 6 × 8058) re-read from a fresh `terra::rast()` and asserted — **36 rows, all PASS** (sentinel absent as value, NA count preserved, range matches in-memory). `task_J_gate4_raster_assertions.csv`.
- **All stats native 28355; only the continuous diff reprojected to 8058 (bilinear) for display.** No hectares off the 28355 grid.
- **`raster_asset` registration DEFERRED** — Task H is running concurrently and owns `raster_asset`; Task J does not touch the DB. Register after H settles, or on your call.

## What must not be claimed

*(Copied from the spec. Support-invariant claims hold as written; the two lines carrying plot-support residual numbers are SUPERSEDED at pixel support — flagged inline. The register/spec rewrite is yours, Gate 5.)*

- ❌ "The cuts increased inundation." Not identifiable (**L01, L02, L03, L12**). — **holds.**
- ❌ "The 2018 difference map shows a management effect." A law fitted only on dates when nothing happened explains most of it (**L26**). — **holds** (pixel: law predicts +1.78 of the +9.30).
- ❌ Any p-value from the placebo spread (**L27**). — **holds.** Only 5 of 25 independent.
- ❌ "The unexplained residual is the cuts." It is uniform, and uniform is unattributable. Delivery is a live alternative and **cannot be ruled out — permanently** (Redbank/Maude fraction 0.650→0.729; Redbank 1993–2006 gap unrecoverable) (**L29, L30, L33**). — **holds** (pixel unexplained is +7.51 pp, not +6).
- ✅ "Inundation was higher in 2018–2022 than in 1988–2017" — **only** beside the drop-2022 number, which reverses the sign. — **holds.**
- ✅ "The pre/post difference is largely determined by how wet the two windows were; R² ≈ 0.86 across 25 dates." — **holds** (pixel R² 0.864).
- ✅ "There is no detectable effect at plot support; the detection floor is roughly ±4 pp." — **holds** (pixel residual sd 4.16 pp).
- 🔴 **SUPERSEDED at pixel support — for your Gate 5 rewrite.** The spec reads: *❌ "…the 2018 residual is third largest — 2009 (+8.04, 2.04 sd) and 1994 (−7.37, 1.86 sd) both exceed it… an ordinary residual"* and *✅ "…smaller than two of them."* **At pixel support the 2018 residual is SECOND of 25; exactly one placebo (2005, +8.67 pp, 2.08 sd) exceeds it; 2009 falls to 0.81 sd.** "Ordinary" is materially weaker — but 2018 is **not** rank 1, and 1.80 sd across 24 non-independent placebos is not significance. Whether "ordinary" survives, and how to phrase it, is your call.

## Not done / deferred

The `raster_asset` registration (Task H live), the limitations-register rewrite for L26/L33 (yours, Gate 5), and anything deck-facing. No slide text written.

**STOP — holding for Gate 4 sign-off.**
