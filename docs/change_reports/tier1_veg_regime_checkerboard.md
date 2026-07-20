# Change report — Tier 1 · Task C1 (vegetation × wetness checkerboard)

**Branch:** `feature/tier1e-f7-groundcover-response` (Task C1 of the checkerboard/dashboards spec)
**Date:** 2026-07-10
**Scope:** Task C1 only — the class raster + bivariate maps + the reusable map function they run on. Tasks D1 (paddock dashboards) and D2 (site dashboards) not started.

## What was built

| Artefact | Path |
|---|---|
| Reusable map fn | `gayini_plot_area_map()` in `R/gayini_area_map.R` |
| Class raster | `Output/rasters/veg_regime_class_8058.tif` (categorical, RAT + colour table) |
| Class fns | `R/gayini_veg_regime_functions.R` (class table, palette, 3×3 legend, builder, counts) |
| Whole-farm map | `Output/figures/C1_veg_regime_bivariate_farm_data.{png,pdf}` |
| Paddock maps (21) | `Output/figures/C1_veg_regime_paddock_<slug>_data.{png,pdf}` |
| QA | `Output/diagnostics/veg_regime_class_qa.json` (all_pass) + `c1_inset_overlap_check.csv` |
| dim_metric | `veg_regime_class` (domain `landcover`; Python METRICS + R safety-insert) |
| Build script | `scripts/03_inundation_products/10_build_veg_regime_checkerboard.R` |
| Bundle | `Output/review_bundles/tier1_veg_regime_checkerboard.zip` |

## Reuse principle (done first)

The F5c paddock-zoom plotting was **refactored into one reusable function** `gayini_plot_area_map(area, fill_layer, fill_spec, points=NULL, neighbours, outline, inset, legend_grob, …)`. It handles both a **continuous** fill (flood-freq ramp) and a **discrete bivariate** fill (the class raster), plus heavy outline / light neighbours / locator inset / reserved title-map-caption bands + inset-overlap check. `gayini_build_f5c_paddock_zooms()` was rewritten as a thin wrapper over it — **the plot code is not forked**. The F5 legibility build (`11_build_f5_legibility_views.R`) was re-run and its gate still passes (F5c figures visually identical), so the refactor is regression-free. D1/D2 will call the same function.

## Class raster

`gayini_build_veg_regime_class()` uses the **same** support threshold (25/35 valid years) and the **same** `regime_band_breaks.csv` terciles as `v_pixel_census_by_veg_regime`, so per-class pixel counts reconcile **exactly**. Codes (community×10 + band): `11/12/13` Aeolian, `21/22/23` Riverine, `31/32/33` Inland (low/mid/high); `40` Woodland/Forest (context); `50` Other/minor; NA elsewhere. Written INT1U with a self-describing RAT + colour table. EPSG:8058, 24.97 m.

Gotcha fixed along the way: a categorical raster's `as.data.frame`/`freq` return factor **labels**, not the numeric codes — the fill join and counts must strip `levels()`/`coltab()` first and work in codes.

## Bivariate scheme (fixed, from the spec — not recomputed)

| | low | mid | high |
|---|---|---|---|
| Aeolian | `#E5D3A0` | `#C79A3C` | `#8F6E24` |
| Riverine | `#B3E0D6` | `#3FAE97` | `#27725F` |
| Inland Floodplain | `#AAC6E4` | `#2E6DB0` | `#1B4270` |

Woodland (context) = `#9E9E9E` single shade · Other/minor = `#E0E0E0`. Rendered as a **3×3 legend** (community rows × wetness columns) + two context swatches, matching the concept slide. Terciles cross-checked against the spec values and match.

## Paddock set

"Major paddocks" = the **20 management zones containing a hectare plot**, unioned with the **4 named** (Bala 28ca, Bala 29ca, Dinan 8, Dinan 10) → **21 unique maps** (adds Dinan 10, which is point-dense but plot-free). Chosen over all-64 to cover every deck paddock-review target without ballooning.

## QA / acceptance (all pass)

- **Class areas reconcile to the census exactly**: max abs per-class pixel diff = **0** across all 11 classes (1,080,157 pixels total).
- CRS 8058; 11 classes present; palette matches the fixed scheme; **woodland shown as context only** (band = context, unbanded).
- All 21 paddock insets clear the title/caption bands; the whole-farm map draws no inset (`inset=FALSE`).

## Deck note — which slide each lands on

`C1_veg_regime_bivariate_farm_data` is the deck's **checkerboard concept slide made real** — the single-hue blue flood-frequency surface is replaced by the two-variable community×wetness fill on the same farm layout, so the schematic and the data figure read as one. The 21 `C1_veg_regime_paddock_<name>` maps are the **per-paddock checkerboard panels** for the Nari Nari paddock review: each shows its pixels' community×wetness classes with the paddock outline heavy, neighbours light, and a property-scale locator inset. They also hand D1/D2 a ready class raster + map function to build the dashboards on.

## Rebuild dependency

`veg_regime_class_8058.tif` is regenerable from code (Output/ is gitignored). The `dim_metric` definition is canonical in the Python builder METRICS list (survives rebuilds); the R script also `INSERT OR IGNORE`s it for pre-rebuild databases. The raster is **not** registered in `raster_asset` (out of scope for C1; can be added via `03_populate_raster_metadata.R`'s catalogue if wanted).
