# Gayini Folder Structure Audit

Date: 2026-06-23

## Scope And Method

Inspected the actual filesystem under `D:/Github_repos/Gayini`, excluding internal Codex/Git metadata. This audit did not change scientific calculations, did not rerun raster processing, and did not move raw inputs.

## Executive Summary

- Folders reviewed: 109
- Files reviewed: 2996
- Total size reviewed: 52609.689 MB (51.38 GB)
- Empty folders found: 3
- Largest area: `Input/` at 52070.801 MB; preserve raw inputs.
- The top-level `scripts/` R workflow is clean: active scripts run from `00` through `10c`; no conflicting top-level numbered `11+` R scripts remain.
- Main cleanup opportunities are generated review/legacy outputs, old dry-run reports, cache/intermediate folders, and nested output archives.

## Current Top-Level Structure

| Folder | Direct files | Child folders | Size MB | Types | Status |
|---|---:|---:|---:|---|---|
| `Input` | 3 | 7 | 52070.801 | .qgz:1; .zip:1; .7z:1 | active_raw_input_preserve |
| `Output` | 3 | 8 | 275.7 | .txt:2; .ps1:1 | ambiguous_review |
| `data_intermediate` | 2 | 5 | 177.253 | .csv:2 | intermediate_data_review |
| `data_processed` | 11 | 1 | 83.527 | .csv:10; [no_ext]:1 | active_processed_data |
| `docs` | 19 | 5 | 1.089 | .md:10; .csv:3; .xlsx:2; .docx:2; .zip:1; .pdf:1 | active_code_or_docs |
| `scripts` | 21 | 3 | 0.748 | .r:16; .ps1:4; .mjs:1 | active_code_or_docs |
| `R` | 16 | 1 | 0.4 | .r:16 | active_code_or_docs |
| `archive` | 0 | 1 | 0.17 |  | archived_or_provenance |

## Largest Nested Folders

| Folder | Direct files | Child folders | Size MB | Types | Status |
|---|---:|---:|---:|---|---|
| `Input/ads` | 4 | 0 | 25288.68 | .jp2:4 | active_raw_input_preserve |
| `Input/modis_fractional_cover` | 489 | 0 | 22752.964 | .tif:302; .ovr:95; .xml:90; .txt:1; .db:1 | active_raw_input_preserve |
| `Input/sentinel2_inundation` | 3 | 11 | 2390.609 | .zip:3 | active_raw_input_preserve |
| `Input/sentinel2_inundation/2024-2025` | 25 | 0 | 1409.258 | .tif:24; .xml:1 | active_raw_input_preserve |
| `Input/landsat_fractionalcover3` | 155 | 0 | 1247.635 | .tif:153; .xml:2 | active_raw_input_preserve |
| `Input/sentinel2_inundation/2021-2022` | 81 | 0 | 373.648 | .aux:27; .tif:27; .pyrx:27 | active_raw_input_preserve |
| `Input/sentinel2_inundation/2019-2020` | 72 | 0 | 217.975 | .tif:31; .ovr:30; .xml:6; .tfw:3; .cpg:1; .dbf:1 | active_raw_input_preserve |
| `Input/sentinel2_inundation/2018-2019` | 140 | 0 | 182.437 | .xml:56; .tfw:28; .tif:28; .ovr:28 | active_raw_input_preserve |
| `data_intermediate/hydrology` | 7 | 0 | 164.311 | .csv:7 | intermediate_data_review |
| `Input/hydrology` | 8 | 0 | 155.535 | .csv:8 | active_raw_input_preserve |
| `Input/landsat_inundation` | 79 | 0 | 112.287 | .img:35; .rrd:35; .cpg:4; .dbf:4; .xml:1 | active_raw_input_preserve |
| `Output/archive` | 1 | 2 | 95.071 | .zip:1 | archived_or_provenance |
| `Output/csv` | 32 | 0 | 62.709 | .csv:31; [no_ext]:1 | active_or_canonical_output |
| `Output/archive/pre_adrian_review_20260616_131036` | 3 | 1 | 55.48 | .csv:2; .md:1 | archived_or_provenance |
| `Output/archive/pre_adrian_review_20260616_131036/Output` | 0 | 4 | 55.197 |  | archived_or_provenance |
| `Input/sentinel2_inundation/2023-2024` | 31 | 0 | 52.355 | .tif:31 | active_raw_input_preserve |
| `Input/sentinel2_inundation/2022-2023` | 78 | 0 | 51.196 | .tif:23; .xml:23; .cpg:16; .dbf:16 | active_raw_input_preserve |
| `Input/sentinel2_inundation/2020-2021` | 40 | 0 | 50.994 | .tif:20; .ovr:20 | active_raw_input_preserve |
| `Output/archive/pre_adrian_review_20260616_131036/Output/figures` | 26 | 6 | 46.113 | .png:26 | archived_or_provenance |
| `data_processed/hydrology` | 3 | 0 | 38.383 | .csv:3 | active_processed_data |
| `Output/figures` | 21 | 9 | 36.769 | .png:19; [no_ext]:1; .7z:1 | ambiguous_review |
| `Output/reports` | 8 | 4 | 27.025 | .xlsx:2; .pptx:2; [no_ext]:1; .png:1; .7z:1; .md:1 | mixed_reports_or_dry_run |
| `Output/rasters` | 1 | 1 | 22.372 | .7z:1 | active_or_canonical_output |
| `Output/archive/pre_adrian_review_20260616_131036/Output/figures/review` | 0 | 4 | 22.2 |  | archived_or_provenance |
| `Input/sentinel2_inundation/2014-2015` | 80 | 0 | 22.135 | .xml:32; .tfw:16; .tif:16; .ovr:16 | active_raw_input_preserve |
| `Output/maps` | 1 | 2 | 20.872 | .7z:1 | mixed_maps_output |
| `Output/rasters/inundation_pre_post` | 7 | 1 | 18.389 | .tif:7 | active_or_canonical_output |
| `Output/rasters/inundation_pre_post/annual` | 24 | 0 | 13.137 | .tif:24 | ambiguous_review |
| `Output/figures/maps/modis_ground_cover` | 46 | 0 | 12.409 | .png:46 | active_or_canonical_output |
| `data_intermediate/extraction_cache` | 2 | 1 | 11.598 | [no_ext]:1; .zip:1 | temporary_or_cache |

## Full Folder Inventory

| Folder | Direct files | Child folders | Size MB | Types | Status |
|---|---:|---:|---:|---|---|
| `archive` | 0 | 1 | 0.17 |  | archived_or_provenance |
| `archive/code_pre_refactor_20260615` | 1 | 2 | 0.17 | .csv:1 | archived_or_provenance |
| `archive/code_pre_refactor_20260615/Output` | 0 | 1 | 0.038 |  | archived_or_provenance |
| `archive/code_pre_refactor_20260615/Output/csv` | 1 | 0 | 0.038 | .csv:1 | archived_or_provenance |
| `archive/code_pre_refactor_20260615/scripts` | 9 | 0 | 0.129 | .r:9 | archived_or_provenance |
| `data_intermediate` | 2 | 5 | 177.253 | .csv:2 | intermediate_data_review |
| `data_intermediate/extraction_cache` | 2 | 1 | 11.598 | [no_ext]:1; .zip:1 | temporary_or_cache |
| `data_intermediate/extraction_cache/modis_aoi` | 604 | 0 | 11.493 | .tif:302; .xml:302 | temporary_or_cache |
| `data_intermediate/hydrology` | 7 | 0 | 164.311 | .csv:7 | intermediate_data_review |
| `data_intermediate/raster_catalog` | 3 | 0 | 0.285 | .csv:2; [no_ext]:1 | intermediate_data_review |
| `data_intermediate/spatial` | 6 | 0 | 1.059 | .gpkg:5; [no_ext]:1 | intermediate_data_review |
| `data_intermediate/terra_tmp` | 0 | 1 | 0 |  | temporary_or_cache |
| `data_intermediate/terra_tmp/07e_prepost_inundation` | 0 | 0 | 0 |  | empty |
| `data_processed` | 11 | 1 | 83.527 | .csv:10; [no_ext]:1 | active_processed_data |
| `data_processed/hydrology` | 3 | 0 | 38.383 | .csv:3 | active_processed_data |
| `docs` | 19 | 5 | 1.089 | .md:10; .csv:3; .xlsx:2; .docx:2; .zip:1; .pdf:1 | active_code_or_docs |
| `docs/archive` | 0 | 1 | 0.004 |  | archived_or_provenance |
| `docs/archive/pre_clean_spine_20260623` | 1 | 0 | 0.004 | .csv:1 | archived_or_provenance |
| `docs/config` | 1 | 0 | 0.001 | .csv:1 | ambiguous_review |
| `docs/docs` | 1 | 0 | 0.006 | .csv:1 | ambiguous_review |
| `docs/INPUT` | 0 | 1 | 0 |  | ambiguous_review |
| `docs/INPUT/Gayini` | 1 | 0 | 0 | .txt:1 | ambiguous_review |
| `docs/scripts` | 2 | 0 | 0.011 | .r:2 | ambiguous_review |
| `Input` | 3 | 7 | 52070.801 | .qgz:1; .zip:1; .7z:1 | active_raw_input_preserve |
| `Input/ads` | 4 | 0 | 25288.68 | .jp2:4 | active_raw_input_preserve |
| `Input/hydrology` | 8 | 0 | 155.535 | .csv:8 | active_raw_input_preserve |
| `Input/landsat_fractionalcover3` | 155 | 0 | 1247.635 | .tif:153; .xml:2 | active_raw_input_preserve |
| `Input/landsat_inundation` | 79 | 0 | 112.287 | .img:35; .rrd:35; .cpg:4; .dbf:4; .xml:1 | active_raw_input_preserve |
| `Input/modis_fractional_cover` | 489 | 0 | 22752.964 | .tif:302; .ovr:95; .xml:90; .txt:1; .db:1 | active_raw_input_preserve |
| `Input/sentinel2_inundation` | 3 | 11 | 2390.609 | .zip:3 | active_raw_input_preserve |
| `Input/sentinel2_inundation/2014-2015` | 80 | 0 | 22.135 | .xml:32; .tfw:16; .tif:16; .ovr:16 | active_raw_input_preserve |
| `Input/sentinel2_inundation/2015-2016` | 63 | 0 | 1.945 | .xml:18; .tfw:9; .tif:9; .ovr:9; .cpg:9; .dbf:9 | active_raw_input_preserve |
| `Input/sentinel2_inundation/2016-2017` | 92 | 0 | 4.744 | .xml:36; .tfw:18; .tif:18; .ovr:18; .cpg:1; .dbf:1 | active_raw_input_preserve |
| `Input/sentinel2_inundation/2017-2018` | 105 | 0 | 3.751 | .xml:42; .tfw:21; .tif:21; .ovr:21 | active_raw_input_preserve |
| `Input/sentinel2_inundation/2018-2019` | 140 | 0 | 182.437 | .xml:56; .tfw:28; .tif:28; .ovr:28 | active_raw_input_preserve |
| `Input/sentinel2_inundation/2019-2020` | 72 | 0 | 217.975 | .tif:31; .ovr:30; .xml:6; .tfw:3; .cpg:1; .dbf:1 | active_raw_input_preserve |
| `Input/sentinel2_inundation/2020-2021` | 40 | 0 | 50.994 | .tif:20; .ovr:20 | active_raw_input_preserve |
| `Input/sentinel2_inundation/2021-2022` | 81 | 0 | 373.648 | .aux:27; .tif:27; .pyrx:27 | active_raw_input_preserve |
| `Input/sentinel2_inundation/2022-2023` | 78 | 0 | 51.196 | .tif:23; .xml:23; .cpg:16; .dbf:16 | active_raw_input_preserve |
| `Input/sentinel2_inundation/2023-2024` | 31 | 0 | 52.355 | .tif:31 | active_raw_input_preserve |
| `Input/sentinel2_inundation/2024-2025` | 25 | 0 | 1409.258 | .tif:24; .xml:1 | active_raw_input_preserve |
| `Input/shapefiles` | 16 | 0 | 0.547 | .dbf:4; .prj:4; .shp:4; .shx:4 | active_raw_input_preserve |
| `Output` | 3 | 8 | 275.7 | .txt:2; .ps1:1 | ambiguous_review |
| `Output/archive` | 1 | 2 | 95.071 | .zip:1 | archived_or_provenance |
| `Output/archive/config` | 1 | 0 | 0 | .csv:1 | archived_or_provenance |
| `Output/archive/pre_adrian_review_20260616_131036` | 3 | 1 | 55.48 | .csv:2; .md:1 | archived_or_provenance |
| `Output/archive/pre_adrian_review_20260616_131036/Output` | 0 | 4 | 55.197 |  | archived_or_provenance |
| `Output/archive/pre_adrian_review_20260616_131036/Output/csv` | 6 | 1 | 6.169 | .csv:6 | archived_or_provenance |
| `Output/archive/pre_adrian_review_20260616_131036/Output/csv/review` | 5 | 0 | 1.044 | .csv:5 | archived_or_provenance |
| `Output/archive/pre_adrian_review_20260616_131036/Output/diagnostics` | 0 | 1 | 2.915 |  | archived_or_provenance |
| `Output/archive/pre_adrian_review_20260616_131036/Output/diagnostics/extraction_checks` | 7 | 0 | 2.915 | .csv:7 | archived_or_provenance |
| `Output/archive/pre_adrian_review_20260616_131036/Output/figures` | 26 | 6 | 46.113 | .png:26 | archived_or_provenance |
| `Output/archive/pre_adrian_review_20260616_131036/Output/figures/07g_prepost_panels` | 24 | 0 | 4.317 | .png:23; .csv:1 | archived_or_provenance |
| `Output/archive/pre_adrian_review_20260616_131036/Output/figures/07g_prepost_panels_v2` | 13 | 0 | 1.759 | .png:13 | archived_or_provenance |
| `Output/archive/pre_adrian_review_20260616_131036/Output/figures/07h_annual_inundation_panels` | 2 | 0 | 1.461 | .png:2 | archived_or_provenance |
| `Output/archive/pre_adrian_review_20260616_131036/Output/figures/07h_annual_inundation_panels_v2` | 2 | 0 | 0.302 | .png:2 | archived_or_provenance |
| `Output/archive/pre_adrian_review_20260616_131036/Output/figures/extraction_checks` | 1 | 2 | 7.904 | .zip:1 | archived_or_provenance |
| `Output/archive/pre_adrian_review_20260616_131036/Output/figures/extraction_checks/fractional_cover` | 24 | 0 | 1.437 | .png:24 | archived_or_provenance |
| `Output/archive/pre_adrian_review_20260616_131036/Output/figures/extraction_checks/fractional_cover_full_timeseries` | 60 | 0 | 3.716 | .png:60 | archived_or_provenance |
| `Output/archive/pre_adrian_review_20260616_131036/Output/figures/review` | 0 | 4 | 22.2 |  | archived_or_provenance |
| `Output/archive/pre_adrian_review_20260616_131036/Output/figures/review/daily_inundation_monthly` | 13 | 0 | 3.382 | .png:13 | archived_or_provenance |
| `Output/archive/pre_adrian_review_20260616_131036/Output/figures/review/ground_cover_timeseries` | 3 | 0 | 2.413 | .png:3 | archived_or_provenance |
| `Output/archive/pre_adrian_review_20260616_131036/Output/figures/review/plot_dashboards` | 7 | 0 | 7.316 | .png:7 | archived_or_provenance |
| `Output/archive/pre_adrian_review_20260616_131036/Output/figures/review/plot_maps` | 42 | 0 | 9.088 | .png:42 | archived_or_provenance |
| `Output/archive/pre_adrian_review_20260616_131036/Output/maps` | 1 | 0 | 0 | [no_ext]:1 | archived_or_provenance |
| `Output/csv` | 32 | 0 | 62.709 | .csv:31; [no_ext]:1 | active_or_canonical_output |
| `Output/diagnostics` | 82 | 10 | 10.863 | .csv:79; [no_ext]:1; .zip:1; .7z:1 | active_or_canonical_output |
| `Output/diagnostics/05b_MER_inundation` | 7 | 0 | 0.008 | .csv:7 | ambiguous_review |
| `Output/diagnostics/06z_check_prepost_inundation_raster_outputs` | 5 | 0 | 0.035 | .csv:4; .md:1 | ambiguous_review |
| `Output/diagnostics/07_curate_rs_analysis_base` | 4 | 0 | 0.006 | .csv:4 | ambiguous_review |
| `Output/diagnostics/07z_check_curated_outputs` | 9 | 0 | 0.014 | .csv:8; .md:1 | ambiguous_review |
| `Output/diagnostics/10a_ground_cover_prepost_response` | 4 | 0 | 0.004 | .csv:3; .md:1 | ambiguous_review |
| `Output/diagnostics/10b_ground_cover_prepost_figures` | 2 | 0 | 0.007 | .csv:1; .md:1 | ambiguous_review |
| `Output/diagnostics/12_lag_diagnostics` | 2 | 0 | 0.004 | .md:1; .csv:1 | ambiguous_review |
| `Output/diagnostics/hydrology` | 7 | 0 | 0.006 | .csv:7 | ambiguous_review |
| `Output/diagnostics/modis_ground_cover` | 4 | 0 | 0.007 | .csv:4 | ambiguous_review |
| `Output/diagnostics/step7_figure_luts` | 10 | 0 | 0.159 | .csv:10 | ambiguous_review |
| `Output/figures` | 21 | 9 | 36.769 | .png:19; [no_ext]:1; .7z:1 | ambiguous_review |
| `Output/figures/07g_prepost_panels_v2` | 26 | 0 | 5.208 | .png:23; .csv:3 | review_or_superseded_output |
| `Output/figures/07h_annual_inundation_panels_v2` | 3 | 0 | 2.054 | .png:2; .csv:1 | review_or_superseded_output |
| `Output/figures/07j_plot_dashboards_v2` | 13 | 0 | 4.842 | .png:12; .csv:1 | review_or_superseded_output |
| `Output/figures/07k_ground_cover_no_treatment` | 3 | 0 | 1.723 | .png:3 | review_or_superseded_output |
| `Output/figures/10b_ground_cover_prepost_figures` | 11 | 0 | 2.878 | .png:11 | active_or_canonical_output |
| `Output/figures/12_lag_diagnostics` | 4 | 0 | 2.125 | .png:4 | review_or_superseded_output |
| `Output/figures/hydrology` | 6 | 0 | 1.204 | .png:6 | active_or_canonical_output |
| `Output/figures/modis_ground_cover` | 14 | 0 | 5.94 | .png:14 | ambiguous_review |
| `Output/figures/review` | 0 | 1 | 0 |  | review_or_superseded_output |
| `Output/figures/review/plot_dashboards` | 0 | 1 | 0 |  | review_or_superseded_output |
| `Output/figures/review/plot_dashboards/panels_if_no_patchwork` | 0 | 0 | 0 |  | empty |
| `Output/logs` | 13 | 0 | 0.007 | .txt:12; [no_ext]:1 | ambiguous_review |
| `Output/maps` | 1 | 2 | 20.872 | .7z:1 | mixed_maps_output |
| `Output/figures/maps/modis_ground_cover` | 46 | 0 | 12.409 | .png:46 | active_or_canonical_output |
| `Output/maps/review` | 0 | 1 | 0 |  | mixed_maps_output |
| `Output/maps/review/combo_rasters` | 0 | 0 | 0 |  | empty |
| `Output/rasters` | 1 | 1 | 22.372 | .7z:1 | active_or_canonical_output |
| `Output/rasters/inundation_pre_post` | 7 | 1 | 18.389 | .tif:7 | active_or_canonical_output |
| `Output/rasters/inundation_pre_post/annual` | 24 | 0 | 13.137 | .tif:24 | ambiguous_review |
| `Output/reports` | 8 | 4 | 27.025 | .xlsx:2; .pptx:2; [no_ext]:1; .png:1; .7z:1; .md:1 | mixed_reports_or_dry_run |
| `Output/reports/adrian_review_png_assets` | 33 | 0 | 9.322 | .png:28; .csv:4; .md:1 | active_or_canonical_output |
| `Output/reports/archive_dry_run_20260616_130752` | 6 | 0 | 0.444 | .csv:5; .md:1 | archived_or_provenance |
| `Output/reports/archive_dry_run_20260616_131036` | 7 | 0 | 0.437 | .csv:5; .md:2 | archived_or_provenance |
| `Output/reports/archive_dry_run_20260616_133745` | 6 | 0 | 0.177 | .csv:5; .md:1 | archived_or_provenance |
| `R` | 16 | 1 | 0.4 | .r:16 | active_code_or_docs |
| `R/obs` | 5 | 0 | 0.096 | .r:5 | archived_or_provenance |
| `scripts` | 21 | 3 | 0.748 | .r:16; .ps1:4; .mjs:1 | active_code_or_docs |
| `scripts/archive` | 0 | 1 | 0.241 |  | archived_or_provenance |
| `scripts/archive/pre_clean_spine_20260623` | 22 | 0 | 0.241 | .r:18; .txt:4 | archived_or_provenance |
| `scripts/downstream_stats` | 1 | 0 | 0.034 | .r:1 | ambiguous_review |
| `scripts/obs` | 28 | 0 | 0.401 | .r:28 | archived_or_provenance |

## Empty Folders

- `data_intermediate/terra_tmp/07e_prepost_inundation`: recommend delete after audit; scripts should create these dynamically if needed.
- `Output/figures/review/plot_dashboards/panels_if_no_patchwork`: recommend delete after audit; scripts should create these dynamically if needed.
- `Output/maps/review/combo_rasters`: recommend delete after audit; scripts should create these dynamically if needed.

## Obsolete Or Stale Output Candidates

- `Output/csv/07e_pre_post_inundation_plot_summary.csv` is superseded by `Output/csv/07f_pre_post_inundation_plot_summary_fixed.csv`.
- `Output/csv/12_lag_*` and `Output/figures/12_lag_diagnostics/` are downstream/statistical outputs outside the active spine.
- `Output/figures/07g_prepost_panels_v2/`, `07h_annual_inundation_panels_v2/`, `07j_plot_dashboards_v2/`, and `07k_ground_cover_no_treatment/` look like older Step 7/review products; preserve until the current deck asset list is confirmed, then archive.
- `Output/reports/archive_dry_run_*` are old dry-run manifests and can be moved under `Output/archive/repo_cleanup_20260623/reports/` after review.
- `data_intermediate/extraction_cache/` and `data_intermediate/terra_tmp/` are cache/temp areas; archive or delete only after confirming they are regenerable for current workflows.
- `Output/archive/pre_adrian_review_20260616_131036/Output/` is a nested full-output archive. Leave in place for now, but avoid making new nested full `Output/` copies.

These are recommendations only. The cleanup manifest marks all non-empty stale candidates as manual-review items rather than deletion targets.

## Canonical Outputs

Canonical outputs are listed in `docs/canonical_output_register_20260623.csv`. High-priority keepers include:

- Curated RS tables in `Output/csv/curated_*` and `Output/csv/plot_rs_analysis_base.csv`.
- MER inundation metrics in `Output/csv/05b_MER_*` and `data_processed/plot_inundation_dynamic_metrics.csv`.
- Gauge context tables in `data_processed/hydrology/`.
- Pre/post inundation rasters in `Output/rasters/inundation_pre_post/`.
- Fixed pre/post plot summary `Output/csv/07f_pre_post_inundation_plot_summary_fixed.csv`.
- Ground-cover response summaries `Output/csv/10a_ground_cover_prepost_*`.
- Current review figures under `Output/figures/10b_ground_cover_prepost_figures/`, `Output/figures/hydrology/`, and `Output/reports/adrian_review_png_assets/`.
- Current diagnostics under `Output/diagnostics/`.

One expected output, `data_processed/raster_catalog.csv`, was not present in the current filesystem. Raster catalogue summaries exist in `Output/csv/`, so confirm whether the active catalogue location changed before treating this as a problem.

## Recommended Folder Convention

Use a simple generated-output structure:

```text
Output/
  csv/
  rasters/
  figures/
    maps/
  diagnostics/
  reports/
    adrian_review_png_assets/
  archive/
```

Reasoning: `csv`, `rasters`, `diagnostics`, and `reports` are already clear. The current split between `Output/maps/` and `Output/figures/` is ambiguous because maps are PNG figure assets. For future work, put map PNGs under `Output/figures/maps/` and reserve `Output/rasters/` for geospatial raster products. Keep review-deck bundles under `Output/reports/adrian_review_png_assets/`.

## Archive Structure Recommendation

Use dated, shallow archives rather than nesting full `Output/` trees repeatedly:

```text
Output/archive/repo_cleanup_20260623/
  csv/
  figures/
  reports/
  compressed/
archive/repo_cleanup_20260623/
  data_intermediate/
```

Leave existing nested archives in place for provenance, but avoid creating new `Output/archive/.../Output/...` copies unless there is a specific handoff reason.

## Scripts Audit

Top-level R scripts are now exactly the active spine from `00_setup_project.R` through `10c_make_review_extraction_method_maps.R`. No old top-level `17a/17b/17c` scripts remain. Archived implementation/provenance scripts live under `scripts/archive/pre_clean_spine_20260623/`; downstream lag diagnostics live under `scripts/downstream_stats/`; older source scripts remain under `scripts/obs/`.

Top-level non-R utility scripts remain: PowerShell collection/cleanup helpers and `build_modis_results_ppt_artifact_tool.mjs`. They do not visually contradict the numbered R spine, but should be documented as utilities if kept.

## R Helper Audit

Active helper files are the direct `R/*.R` files. `R/obs/` is archived/provenance. A function-name scan found 88 duplicate helper names; most are active-vs-`R/obs` copies. Live duplication worth later review includes:

- `gayini_check_packages` in `R/gayini_helpers.R`, `R/step7_figure_helpers.R`, and `R/gayini_analysis_base_functions.R`.
- Plot/path helpers such as `gayini_find_first_existing`, `gayini_standardise_plot_id`, and `gayini_get_first_existing_column` across curation and figure helper files.
- Map/plot helpers duplicated between `R/inundation_pre_post_plotting_functions.R` and `R/step7_figure_helpers.R`.

Do not refactor these as part of folder cleanup; create a later helper-consolidation task if needed.

## Gitignore Policy Recommendations

Recommend ignoring future generated heavy/intermediate material, while not removing existing tracked files blindly:

```gitignore
# Generated rasters and archives
Output/rasters/**/*.tif
Output/**/*.7z
Output/**/*.zip

# Generated figures/review assets
Output/figures/**/*.png
Output/figures/maps/**/*.png
Output/reports/adrian_review_png_assets/**/*.png

# Temporary/cache/intermediate material
data_intermediate/terra_tmp/
data_intermediate/extraction_cache/
**/.RData
**/.Rhistory
**/Thumbs.db

# Local machine paths/logs
Output/logs/*.txt
```

Review this policy against currently tracked files before applying it.

## Phase 2 Safe Cleanup Recommendation

Safe immediate cleanup was limited to empty-folder deletion and keeping all non-empty stale candidates for manual review/archive-first handling. The three empty leaf folders listed above were deleted, along with four newly-empty parent folders exposed by that cleanup: `data_intermediate/terra_tmp`, `Output/figures/review/plot_dashboards`, `Output/figures/review`, and `Output/maps/review`. A dry-run helper script has been added at `scripts/utility_cleanup_empty_folders_20260623.R`.

## Risks And Manual Review Items

- Confirm which review PNG folders are still needed for the August deck before archiving older Step 7/review figures.
- Confirm whether `Output/maps/` should be folded into `Output/figures/maps/` for future outputs.
- Confirm whether `data_intermediate/hydrology/` is required for reproducibility before archiving.
- Confirm whether generated compressed archives in `Output/` roots are backups or stale packaging artifacts.
- Confirm the missing `data_processed/raster_catalog.csv` expectation against current scripts.

## Final Audit Metrics

- Total current repository/output size reviewed: 52609.689 MB (51.38 GB).
- Number of folders reviewed: 109.
- Number of empty folders found: 3.
- Amount of data recommended for archiving: 742.068 MB, all requiring manual review except empty-folder deletion.
- Amount of data recommended for deletion: 0 MB of non-empty data; 3 empty folders only.
- Old top-level scripts conflicting with the clean active spine: none.
- Manual review needed before non-empty cleanup: yes.

## Post-Cleanup Check

- Empty folders remaining after safe cleanup: 0.
- Non-empty files or folders moved/deleted: none.

## Phase 2 Archive-Only Cleanup

After this audit was written, a conservative archive-only cleanup was applied. The pre-move archive manifest was written to `docs/archive_manifest_repo_cleanup_20260623.csv`, then 11 stale/non-active output items were moved into `Output/archive/repo_cleanup_20260623/`.

Archived total: approximately 2.428 MB.

Archived categories:

- Superseded pre/post plot summary: `Output/csv/07e_pre_post_inundation_plot_summary.csv`.
- Downstream lag diagnostic outputs: `Output/csv/12_lag_*` and `Output/figures/12_lag_diagnostics/`.
- Non-canonical debug/dev summaries: `Output/csv/plot_count_by_*`, `Output/csv/raster_dev_subset_summary.csv`, `Output/csv/raster_product_summary.csv`, and `Output/csv/raster_sensor_summary.csv`.

Current August review-deck assets and canonical outputs were kept in place. In particular, no files were moved from `Output/reports/adrian_review_png_assets/`, `Output/figures/10b_ground_cover_prepost_figures/`, `Output/figures/hydrology/`, `Output/figures/maps/modis_ground_cover/`, `Output/rasters/inundation_pre_post/`, or current canonical CSV outputs.

Potentially deck-facing Step 7 figure/dashboard folders were also left in place for manual review rather than archived automatically.

- Empty folders remaining after Phase 2 archive-only cleanup: 0.
- Non-empty files deleted: 0.
- Old top-level scripts conflicting with the clean active spine: none.

## Output Visible Cleanup Addendum

A later targeted visible cleanup of `Output/` is documented in:

```text
docs/folder_structure_audit_addendum_output_visible_cleanup_20260623.md
```

That pass archived older Step 7/review folders, moved MODIS PNG maps under `Output/figures/maps/`, archived compressed packaging artifacts, and left current canonical/review-facing outputs visible.
