# Task J — Gate 3 (placebo ladder, 25 dates) — report, then STOP

**Branch:** `tier1j-prepost-placebo`. Descriptive only; **not** an effect estimate. No law fit, no figures (Gate 4, separate sign-off). Exit 0; **all 58 assertions PASS**.

**Code:** `scripts/03_inundation_products/17_task_J_gate3_placebo_ladder.R` (driver), reusing `internal/task_J_prepost_placebo_impl.R`.
**Results tables (small; commit via `git add -f`):**
- `Output/tables/task_J_gate3_J_T1.csv` — the 25-row ladder (19 cols)
- `Output/tables/task_J_gate3_shape_vs_reference.csv` — pixel vs plot per date
- `Output/tables/task_J_gate3_assertions.csv` — 58 rows (input_stack 5 · per_date 50 · reproducibility 1 · flow_join 1 · shape 1)

## The point of the task, made

24 of these 25 dates are **placebos — nothing happened at them.** Their whole-farm `diff_pp` ranges from **−27.82 pp (C=2000)** to **+7.07 pp (C=2010)**, all tracking how wet the two windows were. The one real date, **C=2018, is +9.30 pp** — the largest *positive* diff at pixel support, but squarely inside the spread a flow-driven system produces when nothing was done. The formal law (Gate 4) will show how much of it flow explains.

## Verification (this is evidence, not a claim)

- **Reproducibility vs Gate 2 — PASS.** 2018 is one of the 25 ladder dates, so it was recomputed by the *current* impl (which gained `taskj_assert_layer_names`, `taskj_write_and_assert`, and the corrected `taskj_assert_diff_range` after the Gate-2 CSVs were made). The 2018 row reproduces the staged Gate-2 summary **exactly**: `diff_pp 9.2961==9.2961 · n_px 1377989==1377989 · fail_tile 4836==4836 · fail_farm 0==0`. **The impl additions are proven inert on the numbers.**
- **Flow join — EXACT for all 25 dates.** `max|flow_pre|=0.0000`, `max|flow_post|=0.0000`, `max|q_ratio|=0.00000` vs the reference CSV. The gauge +1 (END-year) shift is right for every window. *NB: this checks the flow JOIN, not the raster window — a shifted raster window would leave q_ratio untouched (both sides derive it from the gauge table).*
- **Raster-window mapping — PASS per date** (the real position check). Each date's transition, first-PRE, first-POST and last-POST layer *names* match the expected water-year strings, e.g. C=2018 → tran `2017-2018`, POST `2018-2019..2022-2023`.
- **Structural diff range [−100,100] — PASS all 25** (the corrected invariant; the retired `-(n_pre-1)/n_pre*100` floor is gone).
- **MIN_VALID — inert across the whole ladder.** `fail_farm = 0` for **all 25 dates**. Tile-wide fails vary (0 → 341k for the 2009–2011 windows) but are entirely outside the boundary. MIN_VALID drops nothing in the analysis footprint, at any date.

**On the assertion structure (this is stronger than Gate 2, not weaker).** Gate 2 ran 7 *product* asserts on its one date; Gate 3 runs 5 *input_stack* asserts once plus 2 per date. That is not a loss of coverage. The 5 input_stack asserts run on **all 35 layers**, and `wet ⊆ valid` on the full stack **mathematically implies** `freq ∈ [0,100]`, `wet_count ≤ valid_count`, and freq-requires-valid for **every** window subset a cut date can carve out — so asserting once on the stack *dominates* re-asserting those three per window. The 2 per-date checks then cover the only things that are date-specific: the structural diff range and the layer-name→water-year mapping. Plus the reproducibility row proves the 2018 numbers are byte-identical to Gate 2's. Fewer rows, not less coverage.

## Shape match vs plot-support reference

- **Pearson r = 0.9377 · Spearman r = 0.8892 · sign agreement 22/25 · turning point pixel 2008 / plot 2007** (spec expected ~2007). The 3 sign disagreements (2007, 2011, 2012) are all in the near-zero band (|diff| < 3 pp). The window mapping is confirmed by the shape as well as the layer names.

## The `diff = −100` evidence (why the old floor was wrong)

`diff_farm == −100` means a pixel wet in **every** pre-year and dry in **every** post-year — legal, and impossible under the retired floor for short windows. Counts within the farm:

| C | n_pre | px at diff=−100 |
|---|---|---|
| 1994 | 5 | **16,698** |
| 1995 | 6 | **15,264** |
| 1996 | 7 | 32 |
| 1999 | 10 | 24 |
| 2000 | 11 | 24 |
| 2001+ | ≥12 | 0 (a few 6s at 2003/04) |

The earliest windows (pre = wet early-1990s, post = drought onset) carry thousands of legitimate −100 pixels — concrete evidence that reading `−96.552` off the 2018 window and generalising it to `-(n_pre-1)/n_pre*100` was an error, not a data problem. (Recorded per-date as `n_px_diff_eq_neg100` in J-T1.)

## Finding for the register — plot/pixel ratio is NOT stable

The plot/pixel `diff_pp` ratio swings from **0.41 to 2.62** (median 0.83 among the 20 well-conditioned dates); 2018's 1.23× does **not** generalise. It even inverts by regime: pixel magnitude *exceeds* plot for the dry-post drought dates (1994–2002, ratio → 0.41) and *trails* it for the wet-post dates (2008–2010, ratio → 2.62). Reason: **L15's 1.5–1.8× applies to frequency LEVELS (the any-pixel rule), not to differences** — the any-pixel gap differs between the two windows, so the diff ratio is not a constant. This belongs in the limitations register (Gate 5).

## Performance note

`gc()` added at the end of each ladder iteration (after `rm(build)`): terra's C++ raster memory returns to the OS only on collection, so without it the process grows across 25 dates even though the ladder streams (one date's ~350 MB peak, nothing retained). `memfrac` left at 0.5; `freq_raw`/`wet_count` left in the shared impl (additive-only — Gate 2's committed results came from it). Gate 3 writes **no rasters**, so the `ondisk` assertion group re-engages at Gate 4.

## Not done here (deferred to Gate 4, separate sign-off)

The `diff_pp ~ a + b·log(q_ratio)` law fitted on the 24 placebos, the 2018 residual and its rank, the two robustness refits, and the four figures (J-F1…J-F4). No figures were built.

**STOP — holding for Gate 3 sign-off.**
