# Tier 1 · Task A — Reproject to EPSG:8058 and build the sampling-design map

**Branch:** `feature/tier1a-reproject-and-sampling-map`
**Type:** one Claude Code task · branch-and-PR into `main`, human-reviewed before merge
**Depends on:** Tier 0 (spine view, SQLite DB, GeoPackage) + `shapefiles/`
**Convention set here:** every analytical step from now on ships a **figure pair** — a *concept* figure (an explainer of what the code is doing, in the style agreed in chat) and the *data* figure it produces. This task establishes that pattern.

---

## Why this task

The analysis is now framed as a spatially explicit remote-sensing environmental-change assessment. Before any map can be trusted, every layer must share one coordinate system, and the 1 ha plots must land inside their own vegetation communities. This task lays that common ground on **GDA2020 / NSW Lambert (EPSG:8058)** — one projection for all of NSW, so Gayini's MGA zone 54/55 straddle is a non-issue — and produces the orientation map the whole ladder refers back to. The map is also the acceptance test for the reprojection: if a plot doesn't sit in its assigned community, the CRS work is wrong.

The 1 ha plots are **included but are not the analysis spine**. They are located reference anchors. Do not build any pre/post product in this task.

## Goal

1. Reproject all vector layers and the annual raster stack to **EPSG:8058**, writing **new files** (originals untouched) and adding a **reproject-on-read helper** for use inside functions.
2. Produce **F1 — the sampling-design map** (real geo) with per-community zoom insets.
3. Produce the **F1 concept figure** (the plots-on-an-angle / community-wet-range explainer).
4. Register both in a **figures manifest** under the `{step}_{concept|data}` convention and write a change report.

## Inputs

- `shapefiles/gayini_boundary.*` (EPSG:4283)
- `shapefiles/Gayini_Vegetation-classes-use.*` (EPSG:4283) — **note: the fourth community, Riverine Chenopod Shrublands (n=19), is missing from the current map legend; add it.**
- `shapefiles/gayini_hectare_plots.*` (EPSG:7854, GDA2020 MGA zone 54) — true survey polygons, **angled relative to the pixel grid; do not snap to it**
- `shapefiles/CA0561_ManagementZones.*` (EPSG:28355) — paddocks / management zones
- `Gayini_Results.sqlite` → `dim_plot` (`plot_id`, `simplified_vegetation_group`, `treed_plot_flag`, `ground_cover_exclusion_flag`, `spatial_review_flag`, centroids) and `v_plot_year_analysis_spine`
- `Gayini_Results.gpkg` (map-ready companion, mixed CRS)
- `Output/rasters/inundation_annual_stack/annual_{wet,valid}_any_1988_2023.tif` (EPSG:28355, 35 bands)

## Steps

1. **Reproject helper.** Add `to_analysis_crs(x, target = 8058)` used by all figure/analysis functions. It must never mutate a source file. Write reprojected vector copies to `Output/spatial_8058/` with an `_epsg8058` suffix.
2. **Raster.** Either reproject the 35-band stack to `Output/rasters/inundation_annual_stack_8058/` **or** reproject-on-read in the extraction helpers — **document which was chosen and why** (record the resampling method for the categorical wet/valid layers: nearest, not bilinear).
3. **Vectors.** Reproject boundary, vegetation classes (with the 4th community added), management zones, and the 1 ha plots to 8058. Keep plots as true polygons at survey orientation.
4. **Spatial QA.** Confirm every plot centroid falls within the boundary; report the count of plots whose footprint intersects its assigned `simplified_vegetation_group` polygon, and flag mismatches (including the six spatial-review plots: GA_006, GA_007, GA_016, GA_022, GA_029, GA_066).
5. **F1 data figure — sampling-design map.** Boundary + four vegetation communities (colour-coded) + management zones (light) + 66 plots (symbol by community, treed distinguished, drawn at true orientation), scale bar, north arrow, legend, and **one zoom inset per community**. Save PNG + PDF.
6. **F1 concept figure.** An explainer in the agreed conceptual style: plots sit at an angle on the pixel grid; each community spans a range of inundation regimes. Save as SVG/PDF.
7. **Manifest + report.** Register both figures in `Output/figures/figures_manifest.csv` with columns `step, kind {concept|data}, path, inputs, crs`, and write `docs/change_reports/tier1a_reproject_sampling_map.md`.

## Acceptance gate (must pass before commit)

```r
stopifnot(
  crs_epsg(all_reprojected_layers) == 8058,            # everything on NSW Lambert
  identical(checksum(source_files_before), checksum(source_files_after)),  # originals untouched
  n_plot_centroids_in_boundary == 66,                  # all plots inside the property
  n_veg_classes_in_legend == 4,                        # Riverine Chenopod restored
  all(plot_counts_by_group == c(22, 19, 16, 9))        # community counts intact
)
# figures + manifest exist and follow the {step}_{concept|data} convention
stopifnot(
  file.exists("Output/figures/F1_sampling_design_map_data.pdf"),
  file.exists("Output/figures/F1_sampling_design_concept.svg"),
  file.exists("Output/figures/figures_manifest.csv")
)
# community–plot intersection mismatches are LOGGED, not silently dropped
stopifnot(exists("plot_community_mismatch_report"))
```

## Commit & push

```
git add scripts/01_prepare_inputs/ Output/spatial_8058/ Output/figures/ docs/change_reports/tier1a_reproject_sampling_map.md
git commit -m "Tier1A: reproject to EPSG:8058 + sampling-design map (F1) with concept figure"
git push   # then open PR feature/tier1a-reproject-and-sampling-map -> main
```

## Notes

- EPSG:8058 = GDA2020 / NSW Lambert. Prefer reproject-on-read inside functions; keep source files pristine.
- No pre/post products in this task — that framing is retired.
- Plots are reference anchors, not the analysis spine.
- This task unblocks the map-based rungs (F3–F5); the database-only rungs (F2 time series, F3 cube) can proceed in parallel and do not depend on it.
