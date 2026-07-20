# Change report — Tier 1 · Pixel census (Task 1)

**Branch:** `feature/tier1e-f7-groundcover-response` (Task 1 of the pixel-census/rasters spec)
**Date:** 2026-07-10
**Scope:** Task 1 only — the database view `v_pixel_census_by_veg_regime`. Tasks 2–5 not started.

## What was built

A per-stratum pixel census answering: for every vegetation-community × wetness-band
stratum, how many valid farm pixels exist, what area / share of the farm that is, how
many stratified points currently sample it, and at what fraction / density.

| Artefact | Path |
|---|---|
| View | `v_pixel_census_by_veg_regime` (in `Output/database/Gayini_Results.sqlite`) |
| Base table | `census_stratum` (persisted numbers the view derives from) |
| dim_metric rows | `census_stratum_{pixel_count, area_ha, sampling_fraction, sampling_density_per_1000ha}` (domain `sampling`) |
| CSV | `Output/diagnostics/pixel_census.csv` |
| QA | `Output/diagnostics/pixel_census_qa.json` |
| Figure | `Output/figures/F5d_pixel_census_data.{png,pdf}` (manifest step `F5d`) |
| Bundle | `Output/review_bundles/tier1_pixel_census.zip` |
| Code | `R/gayini_pixel_census_functions.R`, `scripts/03_inundation_products/09_build_pixel_census_view.R`, METRICS in `scripts/11_database/01_build_results_database.py` |

## Method

- **Surface:** background flood-frequency recomputed from the 28355 `annual_{wet,valid}_any_1988_2023.tif`
  stack via the existing F5 `gayini_background_flood_frequency()` (continuous → bilinear to 8058,
  valid-year count → nearest). Recomputed rather than read from the saved tif so the valid-coverage
  mask is **parameterised** by `MIN_VALID_YEARS = 25`: a non-NA freq pixel == a valid pixel.
- **Community:** vegetation-community polygons rasterised onto the 8058 grid (~0.0624 ha/pixel).
- **Band:** community-relative tercile edges read from `regime_band_breaks.csv` (F5 source of truth),
  applied with `gayini_assign_regime_band()` (`findInterval`).
- **Rows:** 9 focus strata (3 non-treed communities × low/mid/high) + 2 unbanded context rows
  (treed `Floodplain Woodland / Forest`, `Other / minor units`). Context rows have null band breaks
  and 0 sample points by design.
- **View derives** `pct_of_farm`, `sampling_fraction` (points/pixels) and `points_per_1000ha` from the
  stored counts, so there is a single source of truth.

## Results (headline)

| Community | Band area (ha, each) | pts / 1000 ha |
|---|---:|---:|
| Aeolian Chenopod (dry) | ~1,600 | **~24–27** |
| Riverine Chenopod | ~4,000 | ~10 |
| Inland Floodplain (wet) | ~14,900 | **~2.7** |

Equal allocation (40 pts/stratum) over-represents the small dry Aeolian strata ~10× relative to the
large wet Inland Floodplain strata — exactly the intended, now-visible signal.

## QA / acceptance (all pass)

- CRS 8058; 11 strata rows (9 focus + 2 context); `pct_of_farm` sums to 100.
- **Area reconciliation:** classified valid + masked-out pixels = **67,349.3 ha** vs the vector
  community union **67,349.5 ha** → **−0.000%** (raster tabulation matches the veg map exactly).
  Support mask dropped **0** in-community pixels at the 25/35 threshold (consistent with F5).
- The vegetation-community map covers **67,350 ha of the 85,911 ha farm boundary (−21.6%)** — the veg
  layer does not tile unmapped/other land; this is a data fact, reported in `pixel_census_qa.json`, not
  an error. `pct_of_farm` is therefore a share of the *mapped, valid* farm.
- Null checks: no null/negative pixel counts; focus band breaks all present; context breaks all null.
- Sampling: 360 points total, all in focus strata.

## Rebuild dependency (important)

This is a **post-build DB mutation** (same class as `03_populate_raster_metadata.R`): the Python
builder unlinks + rebuilds the DB and has no GDAL, so `census_stratum` + the view are wiped by a full
rebuild. Re-run order after any rebuild: builder → `03_populate_raster_metadata.R` →
`05_build_unified_annual_stack.R` → `09_build_pixel_census_view.R`. The canonical `dim_metric`
definitions live in the builder's METRICS list (survive rebuilds); the R script also
`INSERT OR IGNORE`s them for pre-rebuild databases.

## Deck note — how this maps to the sampling-density slide

`v_pixel_census_by_veg_regime` is the data behind the deck's **sampling-density** slide. It quantifies,
per vegetation × wetness stratum, the farm area available versus how densely the current design samples
it. The story the slide should tell drops straight out of `points_per_1000ha`: because the design uses
**equal allocation** (40 points per stratum), the small, dry **Aeolian** strata (~1,600 ha each) are
sampled at ~24–27 points per 1000 ha, while the large, wet **Inland Floodplain** strata (~14,900 ha
each) sit at ~2.7 — roughly a **tenfold over-representation of the small strata**. That is deliberate:
equal allocation buys statistical power in the rare dry strata at the cost of proportional
representation, and the census makes the trade-off explicit and defensible rather than hidden. The
treed Woodland/Forest (context, unsampled) and Other/minor units are shown greyed for completeness.
