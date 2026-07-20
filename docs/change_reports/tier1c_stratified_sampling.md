# Change report — Tier 1 · Task C (F5): the stratified sampling frame

**Branch:** `feature/tier1c-stratified-sampling`
**Date:** 2026-07-09
**Status:** acceptance gate PASSED — stopped before commit for human review of the sampling map.

## What this rung builds

F5 stops *describing* the water and builds the frame for *testing* it: a
**stratified random sample within each non-treed community, across its range of
background flood frequency, near the plots but excluding their footprints.** This
is the frame F6 will consume to ask "does any vegetation × inundation-regime
stratum trend over time?" — it is **not** a trend or probability surface.

## Files added (code only — committed)

- `R/gayini_stratified_sampling_functions.R` — the F5 workhorse:
  - `gayini_background_flood_frequency()` — the static background surface
    (headline between-year metric, spatially).
  - `gayini_community_regime_bands()` / `gayini_assign_regime_band()` — within-community terciles.
  - `gayini_candidate_pixels()` — support-filtered, footprint-excluded candidate pixel centres.
  - `gayini_draw_stratified_sample()` — the stratified draw + summary.
- `R/gayini_stratified_sampling_figures.R` — the F5 concept + data figure pair.
- `scripts/03_inundation_products/06_build_stratified_sampling_frame_f5.R` — the run script (tunable defaults at the top, acceptance gate, review bundle).

## Outputs produced (gitignored — reproducible from code)

- `Output/rasters/background_flood_frequency_8058.tif`
- `Output/spatial_8058/stratified_sample_points.gpkg` (360 points)
- `Output/diagnostics/{sample_summary,regime_band_breaks}.csv`
- `Output/figures/F5_stratified_sampling_{concept.svg/pdf, map_data.png/pdf}` (+ manifest rows)
- `Output/review_bundles/tier1c_stratified_sampling.zip`

## The metric, per pixel

Background flood frequency = `100 × Σ(wet_any) ÷ Σ(valid_any)` across the 35
years — the **same between-year headline metric as F2–F4**, computed spatially.
Computed in native **EPSG:28355** (where the Tier-0 wet/valid counts are
verified), then the *continuous* surface is reprojected to **EPSG:8058** with
**bilinear**. The categorical wet/valid bands are **never** resampled; only the
derived continuous surface (bilinear) and the derived integer valid-year count
(nearest, kept as an exact support layer) are reprojected. Source rasters are
read-only.

- Support mask: pixels with `≥ 25 / 35` valid years. **≈100% of observed pixels
  retained** (9,754,212 of 9,756,630) — the annual stack is dense across the site.
- Surface range on 8058: **0–100%** (bounded because wet ⊆ valid by the Tier-0 rule).

## Tunable defaults — OUR decisions, FLAGGED for Adrian Q1

Named constants at the top of the run script. Adrian's Q1 answer changes these
*values*; the logic is unchanged either way.

| constant | default | meaning |
|---|---|---|
| focus | 3 non-treed communities | Aeolian / Riverine / Inland Floodplain (Woodland/Forest excluded) |
| `NEIGHBOURHOOD_RADIUS` | 2 km | sample within 2 km of a monitoring plot, clipped to the plot's own community |
| `EXCLUSION_BUFFER` | 100 m | drop the plot footprint + 100 m |
| regime bands | within-community **terciles** | "wet" is relative to each community's own range |
| `N_PER_STRATUM` | 40 | points per community × regime band |
| `MIN_VALID_YEARS` | 25 | sample only pixels with ≥ 25 of 35 valid years |
| `SEED` | 20260709 | reproducibility |

**Documented fallback:** if a community's plot-neighbourhood is too sparse to
fill even one stratum (< `N_PER_STRATUM` candidate pixels), fall back to
community-wide stratified sampling (footprints still excluded) and log it. **Not
triggered on this run** — all three communities had rich neighbourhoods.

## Within-community tercile breakpoints (flood frequency %)

The contrast is the point: Aeolian's "high" (5.7–76%) sits far below Inland
Floodplain's "high" (34–97%).

| community | min | low\|mid | mid\|high | max |
|---|---|---|---|---|
| Aeolian Chenopod Shrublands | 0 | 0.18 | 5.71 | 76.0 |
| Riverine Chenopod Shrublands | 0 | 5.44 | 16.2 | 85.2 |
| Inland Floodplain Shrublands / Swamps | 0 | 18.7 | 34.4 | 97.1 |

## Sample drawn

360 points = 3 communities × 3 regime bands × 40. Every stratum filled to target;
no empty strata; no fallback. Each point carries `community`, `regime_band`,
`background_flood_freq`, `valid_years`, `nearest_plot_id`, `dist_to_plot_m`.

## Acceptance gate — PASSED

- surface bounded 0–100, CRS 8058;
- all points in the 3 focus communities, `valid_years ≥ 25`,
  `dist_to_plot_m ≥ 100 m`, each point strictly within its own community polygon;
- `nrow(sample_summary) == n_strata_present` (9); empty strata would be logged, not dropped.

### One implementation note

`terra::mask()` keeps a cell if it *overlaps* the neighbourhood, so a pixel
centre a few metres inside the exclusion hole could survive (2 of 360 points came
out at 93–97 m on the first run). Fixed by an explicit vector-level
`st_within(candidate, exclusion_zone)` test in `gayini_candidate_pixels()`, which
enforces `dist_to_plot_m ≥ EXCLUSION_BUFFER` exactly.

## Notes / hand-off to F6

- The background surface is a **stratification substrate + descriptive map**, not
  the F8/F9 trend/probability surface. No trend is run here.
- Plots are **anchors**: they locate the neighbourhoods and are excluded from
  sampling; they are not the analysis unit.
- F6 extracts each sample point's 35-year wet/valid series from the stack and
  tests each community × regime stratum for a trend. F5 just builds the frame.
- The 7 plot/community mismatches (`gayini-tier1a-plot-community-mismatches`) do
  not block this rung: neighbourhoods are clipped to the community polygon, so a
  plot whose footprint sits just outside its community still anchors sampling
  within the community where its 2 km buffer overlaps it.
