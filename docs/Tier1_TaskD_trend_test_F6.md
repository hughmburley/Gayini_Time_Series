# Tier 1 · Task D — Does anything move? The trend test (F6)

**Branch:** `feature/tier1d-trend-test`
**Type:** one Codex task · branch-and-PR into `main`, human-reviewed
**Depends on:** F5 merged (`stratified_sample_points.gpkg`), the annual raster stack (EPSG:28355), and the shared gradient/manifest helpers.

---

## Why this task — and what it is *not*

F6 is the gate. Everything so far has *described* the water; F6 asks the first real question: **for each vegetation × regime stratum, does flood frequency actually change over time — and if it moves, is that a stable directional trend or just the climate-driven wet/dry cycling?**

This matters because Gayini inundation is episodic: a handful of big flood years (2010-11, 2016-17, 2022-23) and the 2006-07 Millennium Drought trough dominate the record. A naïve linear fit over 1988–2023 could report "wetting" simply because the biggest floods happen to fall late in the record — that is **not** a trend, it's where the wet years landed. F6 has to tell those apart honestly.

**F6 does not build a surface and does not auto-advance to Phase D.** It produces the evidence and a per-stratum verdict; whether F7–F9 proceed is a human call (with Adrian) based on that evidence. "No trend" and "not a stable trend" are legitimate, reportable results.

## Inputs

- `Output/spatial_8058/stratified_sample_points.gpkg` — 360 points, 9 strata (3 communities × 3 within-community bands), 40 each.
- `Output/rasters/inundation_annual_stack/annual_{wet,valid}_any_1988_2023.tif` (EPSG:28355, 35 bands) — reproject points to 28355 (or reproject-on-read); never resample the categorical stack.

## Method — simplest first, nothing hidden

1. **Extract** each point's 35-year annual wet/valid series from the stack. Keep only point-years with a valid observation.
2. **Per stratum, per year:** flood frequency = wet ÷ valid across that stratum's points → a 35-point annual series (0–100%). Record n_valid per year.
3. **Fit three things and show them together** (the point of showing all three is that they disagree when the signal is non-linear or episodic):
   - **Theil–Sen slope + Mann–Kendall** tau, p — robust, non-parametric, assumes neither linearity nor normality. This is the primary trend test.
   - **OLS linear** slope + R² — for reference and to expose weakness (low R² = weak).
   - **LOESS smoother** — to reveal non-monotonic shape (rise-then-fall, steps, cycles).
4. **Episodic-robustness check:** recompute Theil–Sen + Mann–Kendall with the stratum's **two largest flood years dropped**. If the verdict flips (significant → not), the movement is carried by a few wet years, not a stable trend.
5. **Verdict per stratum** (thresholds are named constants, flagged for Adrian/stats review):
   - **No trend** — MK p ≥ 0.10, or Theil–Sen CI spans 0.
   - **Directional trend** — MK p < 0.10 **and** robust to dropping the two largest flood years **and** LOESS monotonic in the same direction.
   - **Non-stationary (episodic / cycle-dominated)** — MK p < 0.10 **but** not robust to the flood-drop, or LOESS clearly non-monotonic. Movement is real but not a stable directional trend.

## Figures (one figure = one file = one slide)

- **F6 concept** — the three-verdict explainer: three archetype series side by side (a clean directional trend; a flat no-trend cloud; an episodic/cyclic series that a linear fit would misread as a trend), with a plain-language note on what each verdict means and why "non-stationary ≠ trend." Agreed schematic style.
- **F6 strata trends (data)** — a 3×3 small-multiple (communities × bands), each panel: the annual flood-frequency series, the LOESS smoother, the linear fit, the big flood years marked, and the panel outlined/tinted by its verdict colour. One file (deliberate small-multiple = one slide).
- **F6 verdict summary (data)** — a table figure: per stratum, Theil–Sen slope (ppt/yr), MK tau + p, OLS R², flood-drop-robust? (Y/N), LOESS monotonic? (Y/N), and the verdict. Its own file.

## Acceptance gate (must pass before commit)

```r
stopifnot(
  # extraction
  all(pts_years$valid_years >= 25),
  n_strata == 9, all(strata_series_length == 35),
  # tests computed per stratum
  all(!is.na(verdict_tbl$theil_sen_slope)),
  all(!is.na(verdict_tbl$mk_p)),
  all(verdict_tbl$verdict %in% c("no_trend","directional_trend","non_stationary")),
  # episodic-robustness actually run
  all(!is.na(verdict_tbl$mk_p_drop2floods)),
  # figures one-per-file per convention
  file.exists("Output/figures/F6_strata_trends_data.pdf"),
  file.exists("Output/figures/F6_verdict_summary_data.pdf"),
  file.exists("Output/figures/F6_concept.pdf"),
  file.exists("Output/review_bundles/tier1d_trend_test.zip")
)
# thresholds echoed to the log so the verdict logic is auditable
stopifnot(exists("verdict_thresholds_logged"))
```

## Commit & push

```
git add R/ scripts/
git commit -m "Tier1D: F6 trend test per stratum (Theil-Sen/MK + LOESS + episodic-robustness) with verdicts"
git push   # PR feature/tier1d-trend-test -> main
```
Code only; change report local.

## Notes

- **Simplest first.** Aggregate annual frequency per stratum + robust monotonic test is the primary; a point-level logistic mixed model and any rainfall/ENSO decomposition are deferred — only worth it *if* a stratum shows a genuine directional trend worth disentangling.
- Verdict thresholds (MK p < 0.10, drop-2-floods, LOESS monotonicity) are OUR defaults — named constants, flagged for Adrian/stats review; changing them changes values, not logic.
- **The gate is human.** F6 outputs verdicts; the decision to build the Phase D probability surface is made with Adrian, and only for strata that earn a directional-trend verdict. Report the nulls and the episodic cases as findings.
- Stop at the acceptance gate; the review-bundle zip is what we open.
