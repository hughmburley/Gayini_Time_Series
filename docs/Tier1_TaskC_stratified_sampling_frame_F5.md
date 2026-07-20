# Tier 1 · Task C — The stratified sampling frame (F5)

**Branch:** `feature/tier1c-stratified-sampling`
**Type:** one Claude Code task · branch-and-PR into `main`, human-reviewed before merge
**Depends on:** Task A (EPSG:8058 vectors + `to_analysis_crs()` helper) and Task B (`R/gayini_gradient_helpers.R`, manifest helpers) — both on `main` — plus the annual raster stack (EPSG:28355).

---

## Why this task

F5 is where the ladder stops *describing* the water and builds the frame for *testing* it. Adrian's "control areas near the plots" means a **stratified random sample within each non-treed community, across its range of background flood frequency, near the plots but excluding their footprints**. That lets F6 ask the real question — *does any vegetation × inundation-regime stratum show a trend over time?* — instead of leaning on the 66 plots, which the NSW BCT design placed and which show little on their own.

This is the rung **Q1 to Adrian** is about. We build it now with defaults and flag every tunable, so his answer adjusts parameters, not the design.

**This is NOT a trend or probability surface.** F5 computes a *static* background flood-frequency surface only as the stratification substrate — the long-run "where does it flood" map on the headline metric. The trend/probability work stays behind the F6 gate.

## The metric, per pixel

Background flood frequency = `100 × Σ(wet_any) ÷ Σ(valid_any)` across the 35 years, per pixel — the **same between-year headline metric as F2–F4**, spatially. Compute it in native **EPSG:28355** (where the wet/valid counts are Tier-0 verified), then reproject the resulting *continuous* surface to 8058 (continuous → bilinear is fine; **never resample the categorical wet/valid bands**).

## Tunable defaults — OUR decisions, flagged for Adrian Q1

> These are named constants at the top of the script. Adrian's Q1 answer changes these values; the logic is unchanged either way.
>
> - **Focus:** the 3 non-treed communities only (Aeolian Chenopod, Riverine Chenopod, Inland Floodplain). Woodland / Forest excluded.
> - **Neighbourhood:** sample within `NEIGHBOURHOOD_RADIUS = 2 km` of a monitoring plot, clipped to the plot's **own** community.
> - **Exclusion:** drop the plot footprint + `EXCLUSION_BUFFER = 100 m` around it.
> - **Regime bands:** within-community **terciles** of background flood frequency (low / mid / high) — so "wet" is relative to each community's own range.
> - **Effort:** `N_PER_STRATUM = 40` points per community × regime band (only where that band exists in-neighbourhood).
> - **Support:** sample only pixels with `≥ MIN_VALID_YEARS = 25` of 35 valid years.
> - **Reproducibility:** `SEED = 20260709`.
>
> **Documented fallback:** if plot-neighbourhood sampling is too sparse in the fragmented communities (esp. Riverine/Aeolian patches), fall back to community-wide stratified sampling (still excluding plot footprints) and log that the fallback triggered. Do not silently change effort.

## Steps

1. **Background frequency surface.** From the stack in 28355, `freq = 100 × sum(wet) / sum(valid)` where `valid_years ≥ MIN_VALID_YEARS`; reproject the continuous surface to 8058 → `Output/rasters/background_flood_frequency_8058.tif`. Report the % of pixels retained after the support mask.
2. **Regime bands.** For each of the 3 focus communities, mask the frequency surface to the community polygon and compute within-community terciles; write a per-community regime-band lookup (low / mid / high). **Log each community's tercile breakpoints** — Aeolian's "high" will sit far below Inland Floodplain's "high", and that contrast is the point.
3. **Sampling frame.** Buffer plots by `NEIGHBOURHOOD_RADIUS`, clip to the plot's own community, subtract the footprint + `EXCLUSION_BUFFER`; intersect with the regime bands.
4. **Draw points.** `N_PER_STRATUM` stratified random points per community × regime band, from valid-support pixels only, fixed `SEED`. Attribute each point: `community`, `regime_band`, `background_flood_freq`, `nearest_plot_id`, `dist_to_plot_m`.
5. **Write** `Output/spatial_8058/stratified_sample_points.gpkg` + `Output/diagnostics/sample_summary.csv` (counts per community × regime band; empty strata logged, not dropped silently).
6. **F5 figure pair.**
   - **Concept:** the stratified-sampling explainer — community → regime bands → random points near plots, footprint excluded — in the agreed schematic style.
   - **Data:** a map of the background flood-frequency surface with the drawn points and plots, per-community zoom for the 3 focus communities, plus a small sample-summary panel (points per community × band).
7. **Register** in `figures_manifest.csv`; write `docs/change_reports/tier1c_stratified_sampling.md` (local); **package** the review bundle → `Output/review_bundles/tier1c_stratified_sampling.zip`.

## Acceptance gate (must pass before commit)

```r
stopifnot(
  # background frequency surface
  min(values(freq_8058), na.rm=TRUE) >= 0,
  max(values(freq_8058), na.rm=TRUE) <= 100,
  crs_epsg(freq_8058) == 8058,
  # sample points sane
  all(pts$community %in% focus_communities),         # 3 non-treed only
  all(pts$valid_years >= MIN_VALID_YEARS),
  all(pts$dist_to_plot_m >= EXCLUSION_BUFFER),        # outside the plot footprint buffer
  all(sf::st_within(pts, own_community, sparse=FALSE) |> diag()),  # each point in its community
  # every non-empty stratum was drawn; empties logged, not silent
  nrow(sample_summary) == n_strata_present
)
stopifnot(file.exists("Output/review_bundles/tier1c_stratified_sampling.zip"))
```

## Commit & push

```
git add R/ scripts/
git commit -m "Tier1C: stratified sampling frame (F5) + background flood-frequency surface"
git push   # then open PR feature/tier1c-stratified-sampling -> main
```
Stage code only; keep `docs/change_reports/` local (standing preference).

## Notes

- This is the rung Q1 addresses — parameters flagged, logic Q1-robust.
- The background flood-frequency surface is a **stratification substrate + descriptive map**, not the F8/F9 trend/probability surface.
- Plots are **anchors**: they locate the neighbourhoods and are excluded from sampling; they are not the analysis unit.
- **F6** (next rung) will extract each sample point's 35-year wet/valid series from the stack and test each community × regime stratum for a trend (linear + loess, with a trend / no-trend / non-stationary flag). F5 just builds the frame so that's possible — don't run any trend here.
- Stop at the acceptance gate; the review-bundle zip is what we open to assess the run.
