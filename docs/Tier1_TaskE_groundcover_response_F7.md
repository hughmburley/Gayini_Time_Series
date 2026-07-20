# Tier 1 · Task E — Does vegetation track the flood pulses? Ground-cover response within strata (F7)

**Branch:** `feature/tier1e-f7-groundcover-response`
**Type:** one Claude Code task · branch-and-PR into `main`, human-reviewed before merge
**Depends on:** F6 merged (`main @ b0ef893`); the results spine (`Gayini_Results.sqlite`, `v_plot_year_analysis_spine`); the sub-annual canonical tables (`stg_canonical_ground_cover_timeseries`, `stg_canonical_daily_inundation_monthly`); F5 products (`Output/rasters/background_flood_frequency_8058.tif`, `Output/diagnostics/regime_band_breaks.csv`); and the shared helpers (`R/gayini_gradient_helpers.R`, manifest helpers).

---

## Why this task — and what it is *not*

F6 shut the gate: no stratum shows a directional trend (8 no-trend · 1 non-stationary · 0 directional). The system is **flood-pulse driven, not trending**. So Phase D is no longer a march to a trend surface — the F9 surface is retired and the static F5 background flood-frequency surface already *is* the flood-probability product.

That leaves **one live analytical question**, and F7 is it: within each vegetation × regime stratum, **does ground cover respond to the flood pulses?** The F6 series oscillate (drought dips, flood spikes) around a stable mean; F7 asks whether vegetation rides those oscillations. This is the *support* rung the reshaped ladder names "the within-signal" — descriptive and mechanistic, organised on the same strata as F5/F6.

**F7 is NOT a trend, a surface, or a driver analysis.** It does not extrapolate, does not model rainfall/ENSO/flow (that is the parked next phase, now genuinely motivated by F6), and does not reopen the gate. It describes the contemporaneous and short-lag inundation→cover relationship and reports it per stratum. "Weak or no response in a stratum" is a legitimate, reportable result.

### Scientific framing (ground the figures in it)

Flood-pulse ecology predicts a **lagged, community-specific, spatially uneven** cover response: a wet pulse drives a green flush (PV) that decays to standing dry matter (NPV) and suppresses bare ground, strongest where flooding is frequent enough to matter and where canopy does not confound the signal. Hence: the three **non-treed** communities only, read along the dry→wet gradient; total vegetation as the headline cover response with a PV/NPV split as the mechanistic secondary; and an explicit short-lag test, because the response is not expected to be purely contemporaneous.

## The metric contract (do not blur the headline)

- **Headline stays the headline.** Between-year annual flood frequency (`100 × wet-valid-years ÷ valid-years`) defines *where each plot sits* (its stratum) and anchors every framing.
- **The response axis is the intensity metric, clearly labelled.** Cover responds to *how much* water, not merely *whether* a year was wet. So the F7 inundation regressor is the continuous **wet-extent intensity** — annual `annual_occurrence_pct` (spine) for the same-year model, and monthly `mean_daily_inundated_pct` (sub-annual table) for the lag model. Label it everywhere as the **secondary "wet-extent" metric**; never present it as the headline. This is the one rung where the secondary metric legitimately carries the response, and the concept figure must state the distinction in words.
- **One vegetation scheme: the 4-class `simplified_vegetation_group`.** The sub-annual tables only carry the legacy 5-class `vegetation_adrian_group` and a `period` (pre/post) column — **join to `dim_plot` for `simplified_vegetation_group` / `treed_plot_flag` / `ground_cover_exclusion_flag`, and drop `vegetation_adrian_group` and `period` entirely.** Treed and cover-excluded plots are out of the analytical focus.

## Supersedes the pre/post lag precursor

`scripts/10_downstream_optional/01_lag_diagnostics_inundation_gc.R` is retired by this task. Its monthly-lag method (0/3/6/9/12-month inundation→cover correlations) is sound and is **reused**, but it reads pre-spine CSVs, groups by the 5-class `vegetation_adrian_group`, and is wired to `MANAGEMENT_CHANGE_DATE <- 2019-07-01` with a `period` (pre/post) split. F7 re-implements the method **DB-first, on the 4-class strata, with no pre/post scaffolding**. Move the old script to `scripts/_deprecated/` in this branch (final deletion belongs to the post-Phase-D repo cleanup, not here).

## Inputs

- `v_plot_year_analysis_spine` — plot × water-year: `annual_occurrence_pct` (intensity), `annual_wet_any`, `annual_valid_any`, `annual_valid_coverage_pct`, `mean_total_veg_pct`, `mean_pv_pct`, `mean_npv_pct`, `mean_bare_ground_pct`, `simplified_vegetation_group`, `treed_plot_flag`, `ground_cover_exclusion_flag`.
- `stg_canonical_ground_cover_timeseries` — plot × `date_midpoint`: `total_veg_pct`, `green_pv_pct`, `non_green_npv_pct`, `bare_ground_pct`, `valid_coverage_count`. Join `dim_plot` for the 4-class group + flags.
- `stg_canonical_daily_inundation_monthly` — plot × `month_start`: `mean_daily_inundated_pct` (intensity), `n_daily_observations`.
- `dim_plot` — `centroid_x`, `centroid_y`, `simplified_vegetation_group`, treed/exclusion flags — for stratum assignment.
- `Output/rasters/background_flood_frequency_8058.tif` + `Output/diagnostics/regime_band_breaks.csv` — to assign each plot its F5 regime band (so F7 strata are *definitionally* the F5 strata).

## Tunable defaults — OUR decisions, flagged for Adrian Q3

> Named constants at the top of the functions; Adrian's Q3(a) answer changes values, not logic. Echo them to the log (`f7_thresholds_logged`).
>
> - **Focus:** the 3 non-treed communities (`treed_plot_flag == 0 & ground_cover_exclusion_flag == 0`).
> - **Annual valid-coverage mask (Q3a):** keep plot-years with `annual_valid_coverage_pct >= MIN_VALID_COVERAGE = 40`. Low-support years otherwise inflate response noise.
> - **Monthly support:** keep months with `n_daily_observations >= MIN_MONTH_OBS = 3`; require `MIN_LAG_PAIRS = 6` paired months per plot × lag.
> - **Lags:** `MONTHLY_LAGS = c(0, 3, 6, 9, 12)` (cover at month *t* vs inundation intensity at *t − lag*); annual `ANNUAL_LAGS = c(0, 1)` as a coarse cross-check.
> - **Response verdict thresholds:** stratum "responds" if `median plot r >= R_RESPOND = 0.20` **and** sign-consistent (`>= SIGN_FRAC = 0.70` of plots positive) **and** the stratum-median bootstrap CI excludes 0. Otherwise "weak / no clear response," or "mixed" if sign-inconsistent.
> - **Reproducibility:** `SEED = 20260709` (bootstrap CIs).

## Method — simplest first, nothing hidden

1. **Assign each plot its F5 stratum.** Extract `background_flood_frequency_8058.tif` at the `dim_plot` centroid; apply the per-community tercile breaks from `regime_band_breaks.csv` → each non-treed plot gets `regime_band ∈ {low, mid, high}`. Log the plot → (community, band) table; this ties F7 strata to F5 exactly.
2. **Same-year within-plot response (primary).** From the spine, non-treed, valid-coverage-masked: for each plot compute Pearson `r` and OLS slope of `mean_total_veg_pct` on `annual_occurrence_pct` across its valid years (drop plots with < 4 valid years or zero variance — log them). Summarise the per-plot distribution to (a) each **community** and (b) each **community × band stratum**: median `r`, mean slope, sign-consistency fraction, and a plot-level bootstrap CI on the stratum median. Repeat for `mean_bare_ground_pct` (expected negative) as the mirror, and PV/NPV as the mechanistic secondary. *Prefer this dependency-light per-plot-then-summarise approach (as F6 hand-rolled Theil–Sen to avoid deps); a `cover ~ intensity + (1|plot)` mixed model may be added as a secondary cross-check only if `lme4` is already a project dependency — not required.*
3. **Monthly lag profile (secondary).** Join `stg_canonical_ground_cover_timeseries` (cover at `date_midpoint` → month) to `stg_canonical_daily_inundation_monthly` (`mean_daily_inundated_pct` at `month_start − lag`) on plot × month, via `dim_plot` for the 4-class group; **drop `period` and `vegetation_adrian_group`.** Per plot × lag compute the cover–intensity correlation; summarise to per-community median correlation at each lag. Report the lag at which each community's median correlation peaks. This supersedes script 10.
4. **Verdict per stratum.** Apply the response thresholds → `responds` / `weak_or_none` / `mixed`, mirroring the F6 verdict pattern (named constants, logged, flagged for Adrian). Descriptive, not inferential-overclaimed.
5. **Persist + register.** Write `f7_response_by_plot.csv`, `f7_response_summary.csv` (per stratum), and `f7_lag_profile.csv` to `Output/csv/`; register all figures in `figures_manifest.csv`.

## Figures (one figure = one file = one slide)

- **F7 concept** — the within-strata response explainer in the agreed schematic style: headline (*where / whether*) vs intensity (*how much*, the response axis) stated explicitly; a wet pulse → green flush (PV) → decay to NPV, bare ground down; and the short-lag idea. SVG + PDF.
- **F7 response by community (data)** — the primary result: `total_veg_pct` vs wet-extent intensity for the 3 non-treed communities in dry→wet order, per-plot slopes drawn (spaghetti) with the community summary; the confirmed dry→wet strengthening (≈0.22 → 0.28 → 0.39) should be legible. PNG + PDF.
- **F7 strata panel (data)** — a 3×3 small-multiple (community × regime band) mirroring F6's layout, each cell showing the response effect + per-cell `n`, tinted by verdict. **Print per-cell `n`** and caption the small-`n` caution (≈5–7 plots/cell). One file. PNG + PDF.
- **F7 lag profile (data)** — median cover–intensity correlation vs lag (0/3/6/9/12 months) per community, peak lag marked. PNG + PDF.
- **F7 response summary (data)** — a table figure: per stratum, `n_plots`, median `r` (veg & bare), sign-consistency, bootstrap CI, peak lag, verdict. Its own file. PNG + PDF.

## Acceptance gate (must pass before commit)

```r
stopifnot(
  # --- one vegetation scheme, non-treed focus, no pre/post leakage ---
  all(response_by_plot$simplified_vegetation_group %in% gayini_focus_levels()),   # 3 non-treed
  !any(c("period", "vegetation_adrian_group") %in% names(lag_pairs)),             # pre/post scheme dropped
  # --- strata tied to F5 ---
  all(plot_stratum$regime_band %in% c("low", "mid", "high")),
  nrow(plot_stratum) == 57,                                                        # 66 - 9 treed
  # --- same-year response computed and summarised ---
  all(!is.na(response_summary$median_r_veg)),
  all(response_summary$verdict %in% c("responds", "weak_or_none", "mixed")),
  # confirmatory: community-level dry->wet strengthening recovered
  with(community_summary,
       median_r_veg[community == "Inland Floodplain Shrublands / Swamps"] >
       median_r_veg[community == "Aeolian Chenopod Shrublands"]),
  # --- lag profile computed at all lags, superseding script 10 ---
  all(c(0, 3, 6, 9, 12) %in% lag_profile$lag_months),
  # --- masks + thresholds auditable ---
  exists("f7_thresholds_logged"),
  # --- figures one-per-file per convention ---
  file.exists("Output/figures/F7_concept.svg"),
  file.exists("Output/figures/F7_response_by_community_data.pdf"),
  file.exists("Output/figures/F7_strata_panel_data.pdf"),
  file.exists("Output/figures/F7_lag_profile_data.pdf"),
  file.exists("Output/figures/F7_response_summary_data.pdf"),
  file.exists("Output/review_bundles/tier1e_f7_groundcover_response.zip")
)
```

## Commit & push

```
git add R/ scripts/
git commit -m "Tier1E: F7 ground-cover response within strata (same-year + monthly lag, 4-class, DB-first; supersedes script 10)"
git push   # PR feature/tier1e-f7-groundcover-response -> main
```
Code only; change report local.

## Notes

- **DB-first is the reproducibility win.** The same-year primary and the lag profile run entirely off the curated DB; only the plot → F5-band assignment touches a raster (reused from F5, not recomputed). F7 is the first Phase-D rung with no external gpkg dependency.
- **Strata are the F5 strata**, by construction — the plot band comes from the F5 surface + F5 breaks, so F5 → F6 → F7 read as one family.
- **Small-`n` honesty.** The robust, interpretable signal is at the community level (16 / 19 / 22 plots); the 3×3 stratum panel is the "within strata" view the ladder names but each cell is thin — show `n`, caption the caution, do not over-read a single cell.
- **Metric discipline.** Headline defines strata; the labelled secondary intensity metric carries the response. Do not let the response axis drift into being called the headline.
- **Drivers stay parked.** Rainfall / ENSO / flow (and the Riverine-low non-stationary step) are the *next* phase, not F7.
- **Grazing is metadata**, not a covariate in this first cut (standing convention).
- Stop at the acceptance gate; the review-bundle zip is what we open.
