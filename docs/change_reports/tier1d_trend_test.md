# Change report — Tier 1 · Task D (F6): the trend test

**Branch:** `feature/tier1d-trend-test`
**Date:** 2026-07-09
**Status:** acceptance gate PASSED — stopped before commit for human review of the verdicts (with Adrian).

## What this rung builds

F6 is **the gate for Phase D**. Everything so far has *described* the water; F6
asks the first real question: **for each vegetation × regime stratum, does flood
frequency actually change over time — and if it moves, is that a stable
directional trend or just climate-driven wet/dry cycling?**

It extracts each F5 sample point's 35-year annual wet/valid series from the
categorical stack, aggregates to one annual flood-frequency series per stratum,
fits three things together (Theil–Sen + Mann–Kendall primary, OLS reference,
LOESS shape), runs an episodic-robustness check, and assigns a per-stratum
verdict. **It builds no surface and does not advance to Phase D** — that is a
human call for any stratum that earns a directional-trend verdict.

## Files added (code only — committed)

- `R/gayini_trend_test_functions.R` — the F6 workhorse:
  - `gayini_trend_thresholds()` — the named verdict constants (flagged for stats review).
  - `gayini_extract_point_series()` — reprojects the **points** to the stack CRS and
    extracts the exact per-cell 35-year wet/valid series (the categorical stack is
    read-only and never resampled).
  - `gayini_stratum_annual_series()` — per stratum × year: `100 × wet ÷ valid`.
  - `gayini_mann_kendall()` / `gayini_theil_sen()` — base-R Mann–Kendall (tie-corrected,
    continuity-corrected) and Theil–Sen slope + CI (Sen 1968 / Gilbert 1987 rank method).
    Implemented in-repo so the verdict logic is auditable end-to-end and adds no dependency;
    `gayini_mann_kendall()` tau matches `stats::cor.test(method="kendall")` exactly.
  - `gayini_ols_fit()` / `gayini_loess_shape()` — OLS reference; LOESS smoother + monotonicity.
  - `gayini_stratum_trend_verdict()` / `gayini_run_trend_tests()` — assemble the three fits,
    the episodic-robustness re-test, and the verdict per stratum.
- `R/gayini_trend_test_figures.R` — the F6 concept + two data figures.
- `scripts/03_inundation_products/07_run_trend_test_f6.R` — the run script (sources, extract,
  test, figures, manifest, acceptance gate, review bundle; thresholds echoed to the log).

## Outputs produced (gitignored — reproducible from code)

- `Output/diagnostics/f6_stratum_annual_series.csv` — the raw annual series behind every verdict.
- `Output/diagnostics/f6_verdict_summary.csv` — the per-stratum verdict table (headline deliverable).
- `Output/figures/F6_concept.{svg,pdf}` — the three-verdict explainer.
- `Output/figures/F6_strata_trends_data.{png,pdf}` — the 3×3 small-multiple (community × band),
  each panel tinted by its verdict, the two biggest flood years circled.
- `Output/figures/F6_verdict_summary_data.{png,pdf}` — the verdict table figure.
- `Output/review_bundles/tier1d_trend_test.zip` — the review bundle (figures + diagnostics + manifest).

## Verdict thresholds (OUR defaults — FLAGGED for Adrian / stats review)

Named constants in `gayini_trend_thresholds()`; changing them changes VALUES, not logic:

| Constant | Value | Meaning |
|---|---|---|
| `MK_P_ALPHA` | 0.10 | Mann–Kendall two-sided significance cut |
| `N_LARGEST_FLOODS_DROP` | 2 | episodic-robustness: drop this many biggest flood years |
| `TS_CI_CONF` | 0.90 | Theil–Sen confidence level (= 1 − α) |
| `LOESS_SPAN` / `LOESS_DEGREE` | 0.75 / 2 | LOESS smoother (stats defaults) |
| `LOESS_MONOTONIC_FRAC` | 0.15 | counter-directional LOESS movement must be < this fraction of the dominant movement to count as "monotonic" |
| `MIN_POINT_VALID_YEARS` | 25 | a sample point must have ≥ this many valid years to be used |

## Verdict logic — and one resolved spec contradiction (please confirm)

Mann–Kendall (the **primary** test) decides whether there is *detectable movement*;
the flood-drop check, the slope, and the LOESS shape then decide whether that
movement is *directional* or merely *non-stationary*:

- **No trend** — MK p ≥ 0.10.
- **Directional trend** — MK p < 0.10 **and** flood-drop-robust **and** slope
  non-degenerate (Theil–Sen CI excludes 0) **and** LOESS monotonic in the same direction.
- **Non-stationary (episodic)** — MK p < 0.10 **but** the signal collapses when the two
  biggest floods are dropped, **or** the slope is degenerate, **or** the shape is non-monotonic.

**The spec's verdict rules listed "Theil–Sen CI spans 0 → no_trend" as a standalone
override, which contradicts "MK-significant → non-stationary."** The sample series are
strongly zero-inflated (many dry years → many tied 0→0 pairs), so the median pairwise
Theil–Sen slope is a degenerate 0 in most strata even where MK legitimately detects
late-clustered floods. Taking the override literally reports **all 9 strata as no-trend**
and buries the one real signal. Per direction from review, CI-spanning-0 is treated as a
**directional-vs-episodic discriminator, not an independent no-trend gate** — MK decides
movement, the flood-drop test is the principled episodic arbiter and is reported as its own
column. This changes exactly one stratum's label (Riverine · low: no_trend → non_stationary).

## Result (for review)

**8 no-trend · 1 non-stationary · 0 directional.** Only **Riverine Chenopod · low band**
shows detectable movement (MK τ = 0.40, p = 0.004): 21 dry years (1988–2008) then sporadic
small floods (2009–2022). Note it **survives** the flood-drop check (p = 0.014 after dropping
2010 & 2022) — so it is *not* a two-flood artifact; seven non-zero years all sit late in the
record. It is non-stationary because the LOESS shape is non-monotonic (an episodic emergence,
not a steady climb) and the robust slope is indistinguishable from zero. **No stratum earns a
directional-trend verdict, so on this evidence the Phase D probability surface is not warranted.**
"No robust trend" and "episodic" are the reportable findings here, per the ladder's gate.

## Conventions honoured

- Everything on EPSG:8058; the categorical wet/valid stack is read-only — only the **points**
  are reprojected (to EPSG:28355) for exact per-cell extraction. No pre/post products.
- Headline metric throughout: between-year annual wet frequency (`100 × wet ÷ valid`).
- One figure = one file = one slide; no composites; concept uses illustrative geometry.
- Acceptance gate passed (extraction, 9 strata × 35-year series, all tests + episodic-robustness
  computed, three PDFs present, thresholds echoed); review bundle zipped. Commit is human-gated.
