# Output Visible Cleanup Changelog

Date: 2026-06-23

## Summary

Performed a final visible tidy of `Output/` before the next MER/Flow_MER analysis pass.

No scientific calculations were changed. No expensive raster processing was rerun. No raw inputs were moved. No non-empty files were deleted.

## Archive Manifest

The pre-move and post-move archive manifest is:

```text
docs/archive_manifest_output_visible_cleanup_20260623.csv
```

The manifest records 12 moved items, totalling approximately 39.903 MB.

## Moves Completed

- Archived older Step 7/review figure folders to `Output/archive/repo_cleanup_20260623/figures/`:
  - `Output/figures/07g_prepost_panels_v2/`
  - `Output/figures/07h_annual_inundation_panels_v2/`
  - `Output/figures/07j_plot_dashboards_v2/`
  - `Output/figures/07k_ground_cover_no_treatment/`
- Archived old report dry-run folders to `Output/archive/repo_cleanup_20260623/reports/`.
- Moved MODIS PNG maps from `Output/maps/modis_ground_cover/` to `Output/figures/maps/modis_ground_cover/`.
- Moved compressed packaging artifacts to `Output/archive/repo_cleanup_20260623/compressed/`:
  - `Output/maps/modis_ground_cover.7z`
  - `Output/rasters/inundation_pre_post.7z`
- Archived diagnostics tied to archived outputs:
  - `Output/diagnostics/12_lag_diagnostics/`
  - `Output/diagnostics/step7_figure_luts/`
- Deleted the now-empty `Output/maps/` folder.

## Kept Visible

- Canonical CSV outputs in `Output/csv/`.
- Current pre/post rasters in `Output/rasters/inundation_pre_post/`.
- Current review figures in `Output/figures/10b_ground_cover_prepost_figures/`.
- Current hydrology review figures in `Output/figures/hydrology/`.
- Current review-deck bundle in `Output/reports/adrian_review_png_assets/`.
- Current diagnostics needed for active workflows, including MER, hydrology, 10a, 10b, and MODIS diagnostics.

## Path Updates

- Updated `R/modis_ground_cover_functions.R` so future MODIS map PNGs go to `Output/figures/maps/modis_ground_cover/`.
- Updated `R/gayini_helpers.R` so setup creates `Output/figures/maps/` instead of `Output/maps/`.
- Updated current MODIS map diagnostics/manifests to reference `Output/figures/maps/modis_ground_cover/`.

## MER/Flow_MER Convention

Use existing folders where possible:

```text
Output/csv/
Output/diagnostics/06_MER_inundation/
Output/figures/06_MER_inundation/
Output/reports/
```

If MER/Flow_MER figures are needed, use the single folder `Output/figures/06_MER_inundation/`.
