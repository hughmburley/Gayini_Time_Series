# RS Workflow Simplification Changelog

Date: 2026-06-23

## Summary

Updated the Gayini RS/hydrology workflow naming to use a shorter active spine with lettered substeps where a stage has multiple related scripts. Stable output filenames were not renamed.

## Script Structure Changes

- Added `scripts/06_extract_MER_inundation_metrics.R` as the preferred active wrapper for MER-style inundation metrics.
- Added `scripts/07_import_murrumbidgee_gauge_context.R` as the preferred active wrapper for clean gauge import and RS/gauge context preparation.
- Added the pre/post hydrology substeps:
  - `scripts/08a_build_prepost_inundation_products.R`
  - `scripts/08b_check_prepost_inundation_products.R`
  - `scripts/08c_extract_prepost_inundation_to_plots.R`
- Added the curation substeps:
  - `scripts/09a_curate_rs_hydrology_analysis_base.R`
  - `scripts/09b_check_curated_rs_hydrology_outputs.R`
- Added the combined review-output substeps:
  - `scripts/10a_prepare_ground_cover_response_and_review_tables.R`
  - `scripts/10b_make_review_figures_and_dashboards.R`
  - `scripts/10c_make_review_extraction_method_maps.R`
- Moved formal lag diagnostics from `scripts/12_lag_diagnostics_inundation_gc.R` to `scripts/downstream_stats/12_lag_diagnostics_inundation_gc.R`.

## Documentation Changes

- Updated `docs/current_run_order.md` to the preferred active workflow.
- Updated `docs/rs_inundation_workflow_manifest.csv`.
- Added `docs/rs_inundation_script_rename_map.csv`.
- Added this changelog.

## Principles Applied

- No parent `08` script was created. The active pre/post hydrology product stage uses only `08a`, `08b`, and `08c`.
- Former ground-cover response and review-figure stages are combined under `10a`, `10b`, and `10c`.
- Formal lag diagnostics are outside the active main spine.
- Stable output filenames were retained.
- Expensive raster steps were not rerun.

## Compatibility Notes

Final pruning on 2026-06-23 moved old top-level numbered scripts into `scripts/archive/pre_clean_spine_20260623/`. They are retained for provenance only; active runs should use the clean top-level spine documented in `docs/current_run_order.md`.

The clean gauge-import wrapper consumes exported gauge CSVs and does not move gauge download/QA code into Gayini.
