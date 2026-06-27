# Folder Structure Audit Addendum: Output Visible Cleanup

Date: 2026-06-23

This addendum records the targeted visible cleanup of `Output/` after the full folder audit and conservative Phase 2 archive-only cleanup.

## Scope

Only generated outputs under `Output/` and path references needed to keep the visible structure stable were changed. No scientific calculations were changed and no raster processing was rerun.

## Completed Moves

See `docs/archive_manifest_output_visible_cleanup_20260623.csv` for the complete row-level move record.

Summary:

- Archived older Step 7/review folders from `Output/figures/` into `Output/archive/repo_cleanup_20260623/figures/`.
- Archived old report dry-run folders from `Output/reports/` into `Output/archive/repo_cleanup_20260623/reports/`.
- Consolidated PNG maps by moving `Output/maps/modis_ground_cover/` to `Output/figures/maps/modis_ground_cover/`.
- Archived compressed packaging artifacts from `Output/maps/` and `Output/rasters/` into `Output/archive/repo_cleanup_20260623/compressed/`.
- Archived diagnostics tied to archived Step 7 and lag outputs.
- Removed the now-empty `Output/maps/` folder.

## Visible Output Convention

The intended visible structure is now:

```text
Output/
  archive/
  csv/
  diagnostics/
  figures/
    maps/
  logs/
  rasters/
  reports/
    adrian_review_png_assets/
```

PNG maps belong under `Output/figures/maps/`. Geospatial raster products remain under `Output/rasters/`.

## Preserved Current Outputs

The cleanup preserved current canonical and review-facing outputs, including:

- `Output/csv/curated_annual_inundation_timeseries.csv`
- `Output/csv/curated_daily_inundation_monthly.csv`
- `Output/csv/curated_ground_cover_timeseries.csv`
- `Output/csv/plot_rs_analysis_base.csv`
- `Output/csv/05b_MER_plot_inundation_dynamic_metrics.csv`
- `Output/csv/05b_MER_plot_inundation_monthly_seasonal_max.csv`
- `Output/csv/07f_pre_post_inundation_plot_summary_fixed.csv`
- `Output/csv/10a_ground_cover_prepost_plot_summary.csv`
- `Output/csv/10a_ground_cover_prepost_group_summary.csv`
- `Output/csv/10a_ground_cover_prepost_model_summary.csv`
- `Output/rasters/inundation_pre_post/`
- `Output/figures/10b_ground_cover_prepost_figures/`
- `Output/figures/hydrology/`
- `Output/reports/adrian_review_png_assets/`
- active diagnostics in `Output/diagnostics/`

## MER/Flow_MER Readiness

The next MER/Flow_MER pass should use:

```text
Output/csv/
Output/diagnostics/06_MER_inundation/
Output/figures/06_MER_inundation/
Output/reports/
```

Do not create multiple scattered MER output folders.
