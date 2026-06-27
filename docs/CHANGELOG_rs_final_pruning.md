# RS Workflow Final Pruning Changelog

Date: 2026-06-23

## Summary

Pruned old numbered compatibility scripts from the top-level `scripts/` folder so the active R workflow visibly ends at `10c`.

## Changes

- Moved historical top-level workflow scripts to `scripts/archive/pre_clean_spine_20260623/`.
- Removed top-level `17a`, `17b`, and `17c` scripts.
- Kept gauge import under `scripts/07_import_murrumbidgee_gauge_context.R`.
- Kept RS/gauge joins under `scripts/09a_curate_rs_hydrology_analysis_base.R`.
- Kept gauge review plots under `scripts/10b_make_review_figures_and_dashboards.R`.
- Kept formal lag diagnostics outside the active spine at `scripts/downstream_stats/12_lag_diagnostics_inundation_gc.R`.
- Updated the run order, workflow manifest, script rename map, and canonical-output producer references.

## Verification Notes

- No expensive raster steps were rerun.
- The top-level R workflow now contains only the active scripts `00` through `10c`.
