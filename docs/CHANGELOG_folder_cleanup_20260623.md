# Folder Cleanup Changelog

Date: 2026-06-23

## Audit Artifacts Created

- `docs/folder_structure_audit_20260623.md`
- `docs/folder_cleanup_manifest_20260623.csv`
- `docs/canonical_output_register_20260623.csv`
- `scripts/utility_cleanup_empty_folders_20260623.R`

## Cleanup Actions

- No scientific calculations changed.
- No expensive raster processing rerun.
- No raw inputs moved.
- No non-empty outputs moved or deleted during audit generation.
- Deleted seven confirmed empty folders after the audit report and manifest were written. The first three were empty leaf folders from the audit; the remaining four were newly-empty parents exposed by deleting those leaves:
  - `data_intermediate/terra_tmp/07e_prepost_inundation`
  - `data_intermediate/terra_tmp`
  - `Output/figures/review/plot_dashboards/panels_if_no_patchwork`
  - `Output/figures/review/plot_dashboards`
  - `Output/figures/review`
  - `Output/maps/review/combo_rasters`
  - `Output/maps/review`

## Phase 2 Archive-Only Cleanup

- Wrote the archive manifest before moving files: `docs/archive_manifest_repo_cleanup_20260623.csv`.
- Archived 11 stale/non-active output items, totalling approximately 2.428 MB, into `Output/archive/repo_cleanup_20260623/`.
- Archived items were limited to:
  - superseded `Output/csv/07e_pre_post_inundation_plot_summary.csv`;
  - downstream lag diagnostic CSVs and `Output/figures/12_lag_diagnostics/`;
  - non-canonical debug/dev summary CSVs for plot counts and raster summaries.
- Kept current August review-deck assets in place, including:
  - `Output/reports/adrian_review_png_assets/`;
  - `Output/figures/10b_ground_cover_prepost_figures/`;
  - `Output/figures/hydrology/`;
  - `Output/figures/maps/modis_ground_cover/`.
- Kept potentially deck-facing Step 7 figure/dashboard folders in place pending manual review.
- No non-empty files were deleted.

## Recommended Safe Cleanup

- Archive non-empty stale candidates only after manual review confirms they are not needed for current review outputs.
