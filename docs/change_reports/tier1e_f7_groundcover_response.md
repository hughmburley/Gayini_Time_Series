# Change report — Tier 1 · Task E (F7): ground-cover response within strata

**Branch:** `feature/tier1e-f7-groundcover-response` (off `main @ b0ef893`)
**Date:** 2026-07-09
**Status:** acceptance gate PASSED · held for review with Adrian before commit-to-main / merge

---

## What F7 does

F6 shut the gate (no stratum trends; the system is flood-pulse driven). F7 answers
the one live question: **within each vegetation × flood-regime stratum, does ground
cover respond to the flood pulses?** Descriptive support — not a trend, surface, or
driver analysis, and it does not reopen the gate.

Two reads:
1. **Same-year within-plot response (primary)** — per-plot Pearson r + OLS slope of
   ground cover on the wet-extent intensity (`annual_occurrence_pct`) across each
   plot's valid years, summarised to community and community × regime band with a
   plot-level bootstrap CI on each stratum's median r.
2. **Monthly lag profile (secondary)** — per plot × lag correlation of monthly total
   veg on monthly inundation intensity (`mean_daily_inundated_pct`) at t − lag,
   summarised to a per-community median at each lag (0/3/6/9/12 mo). Supersedes
   `scripts/10_downstream_optional/01_lag_diagnostics_inundation_gc.R`.

## Files

**New**
- `R/gayini_ground_cover_response_functions.R` — thresholds (`gayini_f7_thresholds`),
  verdict vocab/palette, plot→F5-stratum assignment, same-year response +
  per-group summary + verdict, hand-rolled bootstrap-median CI, monthly lag profile.
- `R/gayini_ground_cover_response_figures.R` — F7 concept + 4 data figures.
- `scripts/03_inundation_products/08_run_groundcover_response_f7.R` — orchestrator
  (DB-first; one raster extraction for plot→band), acceptance gate, review bundle.

**Moved**
- `scripts/10_downstream_optional/01_lag_diagnostics_inundation_gc.R` →
  `scripts/_deprecated/` (method reused DB-first on the 4-class strata; final
  deletion deferred to post-Phase-D cleanup).

**Outputs (gitignored)**
- `Output/csv/{f7_response_by_plot,f7_response_summary,f7_lag_profile}.csv`
- `Output/diagnostics/f7_plot_stratum.csv`
- `Output/figures/F7_concept.{svg,pdf}`,
  `Output/figures/F7_{response_by_community,strata_panel,lag_profile,response_summary}_data.{png,pdf}`
- `Output/review_bundles/tier1e_f7_groundcover_response.zip`

## Results

- **57** non-treed plots banded low/mid/high from the F5 surface + F5 tercile breaks
  (strata = F5 strata by construction). **52** usable for the same-year fit (5
  Aeolian-low plots dropped: always-dry → zero intensity variance).
- **Same-year response strengthens dry→wet:** community median veg r = **0.17**
  (Aeolian) → **0.26** (Riverine) → **0.42** (Inland Floodplain). Positive in **all
  52** usable plots (sign +ve = 100% every stratum); max r = 0.70.
- **Verdicts: 6 responds · 3 weak_or_none · 0 mixed.** Weak = Aeolian low/mid,
  Riverine low (median r < 0.20). Response also strengthens low→high band within
  community. No "mixed" because every plot's veg response is positive.
- **Lag profile peaks at 3 months for all three communities** (Aeolian 0.38,
  Riverine 0.30, Inland 0.26) — the flood-pulse "green flush a season later"
  prediction. Sub-annual (daily) inundation record is recent, so plot counts are
  lower than the same-year read (Aeolian especially thin: 2–3 plots/lag).

## Decisions & caveats for Adrian

- **`MIN_VALID_COVERAGE = 40` (Q3a) is a documented placeholder** — his answer
  changes the value, not the logic. All thresholds echoed to the log
  (`f7_thresholds_logged`) and named in `gayini_f7_thresholds()`.
- **Verdict thresholds** (`R_RESPOND = 0.20`, `SIGN_FRAC = 0.70`, bootstrap CI
  excludes 0) flagged for review — same posture as F6.
- **Aeolian-high "responds" rests on n = 3 plots** (all positive; bootstrap median CI
  [0.23, 0.39]). Legitimate per the rule, but the small-n caution applies — read the
  community-level result as the robust signal (captioned on the strata panel).
- **`median r (bare)` is exactly −`median r (veg)`** in every stratum. This is a
  mathematical identity, not corroboration: fractional cover has total_veg + bare =
  100, so cor(bare, x) ≡ −cor(veg, x). The bare mirror is confirmatory-only; the
  mechanistically independent secondary is the PV/NPV split (in
  `f7_response_by_plot.csv`, columns `r_pv` / `r_npv`), because PV + NPV = total_veg.

## Metric discipline

Headline between-year flood frequency defines each plot's **stratum**; the labelled
**secondary** wet-extent intensity carries the **response** (annual occurrence for the
same-year read, monthly inundation for the lag read). Every figure/axis labels the
response metric as secondary. 4-class `simplified_vegetation_group` only; `period` and
`vegetation_adrian_group` dropped (gate asserts both).

## Acceptance gate

All `stopifnot` conditions passed (57 plots; median_r_veg non-NA all 9 strata;
verdicts in {responds, weak_or_none, mixed}; Inland > Aeolian; lags 0/3/6/9/12
present; no period/adrian leakage; five figures + bundle written).
