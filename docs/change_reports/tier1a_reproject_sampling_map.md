# Change report — Tier 1 · Task A: reproject to EPSG:8058 + sampling-design map (F1)

**Task spec:** `docs/Tier1_TaskA_reproject_8058_and_sampling_design_map.md`
**Branch (intended):** `feature/tier1a-reproject-and-sampling-map` (not yet created — stopped at the acceptance gate)
**Base commit:** `6b10681` (main)
**Status:** acceptance gate PASSED; **not committed** — awaiting human review of the sampling-design map before branch-and-PR.
**This report is INTERNAL ONLY and is not committed.**

---

## 1. What was built

The pivot to a spatially explicit remote-sensing analysis on **GDA2020 / NSW Lambert (EPSG:8058)**.
All vector layers get reprojected copies; the raster stack is handled reproject-on-read; the F1
figure pair (concept + data) is produced; a figures manifest and plot/community QA report are written.
Every acceptance-gate assertion passes.

## 2. Code committed (to be staged — NOT yet committed)

Three new files, all additive (no existing file was modified):

| File | Purpose |
|------|---------|
| `R/gayini_spatial_8058_functions.R` | `to_analysis_crs()` reproject-on-read helper (sf / SpatRaster / path; nearest for categorical rasters), `gayini_crs_epsg()`, vegetation→community lookup + `gayini_simplify_vegetation()` / `gayini_dissolve_communities()`, `gayini_reproject_vectors_8058()`, `gayini_load_dim_plot()`, `gayini_plot_community_qa()`, figures-manifest row helper. |
| `R/gayini_sampling_design_map.R` | Community palette, scale-bar + north-arrow layer helpers (no `ggspatial` dependency — that package is not installed), `gayini_build_sampling_design_map()` (F1 data map with 4 per-community insets), `gayini_build_concept_figure()` (F1 concept explainer). |
| `scripts/01_prepare_inputs/04_reproject_to_epsg8058_and_sampling_map.R` | Orchestration: snapshot source checksums → reproject vectors → raster reproject-on-read smoke test → spatial QA → figure pair → manifest → **acceptance gate** → summary. Stops before commit. |

## 3. The reproject-on-read helper

`to_analysis_crs(x, target = 8058, method = NULL)` is the single entry point downstream code uses so
nothing has to reason about source CRS. It dispatches on type:
- **sf / sfc** → `sf::st_transform()`
- **SpatRaster** → `terra::project(..., method = "near")` by default (categorical wet/valid layers;
  bilinear would invent classes)
- **file path** → read, then dispatch

It never writes and never touches the source on disk.

## 4. Raster decision — REPROJECT-ON-READ (not a written copy)

The 35-band wet/valid stack is **not** reprojected to a new file. Rationale (recorded in the run
script §4):
- Annual occurrence / wet-cell counts are **locked in EPSG:28355** (Tier 0, verified vs manifest).
  Reprojecting a categorical stack resamples cells and would move those counts, breaking the spine.
- **Nothing in Task A consumes the raster** — the sampling-design map is vectors + plots only.
- Keeping the authoritative stack pristine and projecting on read preserves both the numbers and the
  single source of truth. Later extraction rungs call `to_analysis_crs()` at the point of use.
- Categorical layers use **nearest-neighbour**, never bilinear.

A one-band smoke test (`annual_wet_any_1988_2023.tif[[1]]` → 8058, nearest) confirms the helper tags
8058: **PASS**.

## 5. Generated artefacts (gitignored — reproducible from code, NOT committed)

`Output/` is blanket-gitignored; per the standing Tier 0 preference we **commit code only**. These are
produced by running the script:

**Reprojected vectors — `Output/spatial_8058/` (all EPSG:8058):**
- `gayini_boundary_epsg8058.gpkg`
- `vegetation_classes_epsg8058.gpkg` (detailed classes + attached `simplified_vegetation_group`)
- `vegetation_communities_epsg8058.gpkg` (dissolved: one feature per community + "Other / minor units")
- `gayini_hectare_plots_epsg8058.gpkg` (66 true-orientation polygons; **not** snapped to the pixel grid; `plot_id` standardised from `Gayini.Nam`)
- `management_zones_epsg8058.gpkg` (64 zones)

**Figures — `Output/figures/`:**
- `F1_sampling_design_map_data.png` / `.pdf` — boundary (dark) + 4 communities (fill) + management
  zones (light) + 66 plots (symbol by community, treed = triangle, drawn at true orientation) + scale
  bar + north arrow + legend + one zoom inset per community.
- `F1_sampling_design_concept.svg` / `.pdf` — schematic: (A) a 1 ha plot angled on the pixel grid
  ("surveyed at TRUE orientation — not snapped"); (B) each community spanning a dry→wet inundation range.
- `figures_manifest.csv` — columns `step, kind {concept|data}, path, inputs, crs` (4 rows: F1 concept
  svg/pdf, F1 data png/pdf).

**QA — `Output/diagnostics/`:**
- `plot_community_mismatch_report.csv` — 13 logged flags (see §7).

## 6. The 4th community restored + the vegetation mapping

The source `Gayini_Vegetation-classes-use.shp` carries 9 detailed `Vegetation` types; the analysis
groups them into the **four** plot communities in `dim_plot.simplified_vegetation_group`. The lookup
(`gayini_vegetation_group_lookup()`):

| Detailed type(s) | Simplified community |
|---|---|
| Inland Floodplain Shrublands, Inland Floodplain Swamps | Inland Floodplain Shrublands / Swamps |
| Riverine Chenopod Shrublands | **Riverine Chenopod Shrublands** (the one missing from the old legend — now restored) |
| Aeolian Chenopod Shrublands | Aeolian Chenopod Shrublands |
| Inland Floodplain Woodlands, Inland Riverine Forests | Floodplain Woodland / Forest |
| Riverine Plain Grasslands, Riverine Sandhill Woodlands, Sand Plain Mulga Shrublands | Other / minor units (context grey; hosts no plots; **not** one of the four legend classes) |

The legend shows exactly **4** communities. Plot counts by community are intact: **22 / 19 / 16 / 9**.

## 7. Spatial QA findings (logged, not silently dropped)

- **Plot centroids inside the boundary: 66 / 66** ✓
- **Plot footprints inside their assigned community polygon: 59 / 66**
- `plot_community_mismatch_report.csv` logs **13** flags:
  - **6 named spatial-review plots** (GA_006, GA_007, GA_016, GA_022, GA_029, GA_066) — issue
    `spatial_review_plot_ok`: footprint DOES intersect the assigned community; surfaced because the
    task asked for them explicitly.
  - **7 footprint-outside-community plots** (GA_024, GA_037, GA_038, GA_044, GA_047, GA_048, GA_049) —
    issue `footprint_outside_assigned_community`: the plot square does not intersect the mapped polygon
    of its `simplified_vegetation_group`. All 7 also carry `spatial_review_flag = 1` in `dim_plot`.
    Likely a plot-vs-vegetation-boundary near-miss (plots on the edge of a mapped unit); worth NNTC/Adrian
    confirmation before community-stratified summaries, but **not** a CRS error — every plot centroid is
    inside the property and the community counts are unchanged.
- Context: `dim_plot` carries `spatial_review_flag = 1` on **24** plots total; the QA only elevates a
  flag to a *mismatch* when the geometry actually disagrees (the 7 above) or the plot is one of the six
  named review plots.

## 8. Acceptance gate — all assertions PASS

| Gate check | Result |
|---|---|
| `crs_epsg(all_reprojected_layers) == 8058` | ✓ boundary/veg/communities/plots/management all 8058 |
| `identical(checksum(before), checksum(after))` | ✓ source shapefiles byte-identical (also confirmed via `git status Input/` = clean) |
| `n_plot_centroids_in_boundary == 66` | ✓ |
| `n_veg_classes_in_legend == 4` | ✓ Riverine Chenopod restored |
| `all(plot_counts_by_group == c(22,19,16,9))` | ✓ |
| raster reproject-on-read smoke test | ✓ PASS |
| F1 data pdf / concept svg / manifest exist | ✓ |
| `exists("plot_community_mismatch_report")` | ✓ |

## 9. Explicitly NOT part of this task

- **No pre/post products** — that framing is retired.
- **No written reprojected raster stack** — reproject-on-read by design (§4).
- **No modelling** — plots are reference anchors here, not the analysis spine.
- **No commit / branch / PR yet** — stopped at the acceptance gate for human review of the map.
- Sentinel-2 legend remains open (unchanged; out of scope).

## 10. How to reproduce

```
Rscript scripts/01_prepare_inputs/04_reproject_to_epsg8058_and_sampling_map.R
```
Regenerates all `Output/spatial_8058/`, `Output/figures/`, and the mismatch report, and re-runs the gate.
