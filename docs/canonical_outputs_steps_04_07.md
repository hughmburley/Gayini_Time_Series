# Canonical Outputs For Steps 03-07

Last updated: 2026-06-15

> Superseded workflow-note: this document predates the 2026-06-23 final pruning pass. Old script names in this file are historical/non-active unless they also appear in `docs/current_run_order.md`.

This document records the canonical output set for the current remote-sensing workflow after the controlled cleanup pass and the MODIS context integration.

## Step 03 Ground Cover

Active script:

- `scripts/02_extract_heavy/03_extract_ground_cover_full.R`

Core Landsat source script:

- `scripts/archive/obs_legacy_20260627/04c_extract_fractional_cover_full.R`

Optional MODIS context helper:

- `R/modis_ground_cover_functions.R`

Canonical outputs:

- `data_processed/plot_fractional_cover_timeseries.csv`
- `Output/csv/04c_fractional_cover_full.csv`
- `Output/csv/curated_ground_cover_timeseries.csv`

Optional MODIS broad-context outputs:

- `data_processed/modis_ground_cover_context_timeseries.csv`
- `Output/csv/03_modis_ground_cover_context_full.csv`
- `Output/diagnostics/03_modis_ground_cover_context_checks.csv`
- `Output/diagnostics/03_modis_ground_cover_band_sum_checks.csv`

Key variables:

- `plot_id`
- `date_midpoint`
- `water_year`
- `period`
- `treatment`
- `vegetation`
- `vegetation_adrian_group`
- `bare_ground_pct`
- `green_pv_pct`
- `non_green_npv_pct`
- `total_veg_pct`
- `valid_coverage_status`

Ground-cover band definitions:

- Band 1 = bare ground.
- Band 2 = green / photosynthetic vegetation.
- Band 3 = non-green / non-photosynthetic vegetation.
- NoData = 255.

MODIS interpretation note:

- MODIS fractional cover is broad farm, buffer, management-zone or paddock context only. It should not be used as 1 ha plot-scale evidence.

## Step 04 Annual Inundation

Active wrapper:

- `scripts/02_extract_heavy/04_extract_annual_inundation_full.R`

Source script:

- `scripts/05c_extract_landsat_inundation_full.R`

Canonical outputs:

- `data_processed/plot_landsat_inundation_timeseries.csv`
- `Output/csv/05c_landsat_inundation_full.csv`
- `Output/csv/curated_annual_inundation_timeseries.csv`

Interpretation note:

- Annual inundation is annual occurrence frequency support. It is not flood duration, depth, hydroperiod, or number of wet days.
- `annual_valid_any = 1` means valid coverage, not flooding.

## Step 05 Daily Inundation

Active wrapper:

- `scripts/02_extract_heavy/05_extract_daily_inundation_full.R`

Source script:

- `scripts/06c_extract_daily_inundation_full.R`

Canonical outputs:

- `data_processed/plot_daily_inundation_timeseries.csv`
- `Output/csv/06c_daily_inundation_full.csv`
- `Output/csv/curated_daily_inundation_monthly.csv`

Interpretation note:

- Daily data are useful for QA, event timing, and sensor-density checks.
- The main hydrology summary should use annual and pre/post outputs by default.

## Step 06 Pre/Post Inundation Rasters

Active wrapper:

- `scripts/03_inundation_products/08a_build_prepost_inundation_products.R`

Source script:

- `scripts/07e_build_pre_post_inundation_frequency_rasters.R`

Canonical raster outputs:

- `Output/rasters/inundation_pre_post/pre_conservation_inundation_frequency_pct.tif`
- `Output/rasters/inundation_pre_post/post_conservation_inundation_frequency_pct.tif`
- `Output/rasters/inundation_pre_post/post_minus_pre_inundation_frequency_pct_points.tif`
- `Output/rasters/inundation_pre_post/pre_conservation_wet_year_count.tif`
- `Output/rasters/inundation_pre_post/pre_conservation_valid_year_count.tif`
- `Output/rasters/inundation_pre_post/post_conservation_wet_year_count.tif`
- `Output/rasters/inundation_pre_post/post_conservation_valid_year_count.tif`
- `Output/rasters/inundation_pre_post/annual/annual_inundated_any_*__YYYY.tif`
- `Output/rasters/inundation_pre_post/annual/annual_valid_any_*__YYYY.tif`

QA script:

- `scripts/09_qa/08b_check_prepost_inundation_products.R`

QA diagnostics:

- `Output/diagnostics/06z_check_prepost_inundation_raster_outputs/`

Interpretation note:

- The pre/post method estimates annual inundation occurrence frequency, not hydroperiod.
- The post-minus-pre raster is in percentage points, not percent change.
- `annual_valid_any` rasters represent valid coverage support, not flooding.

## Step 07 Pre/Post Inundation Plot Summary

Active wrapper:

- `scripts/03_inundation_products/08c_extract_prepost_inundation_to_plots.R`

Source script:

- `scripts/07f_reextract_prepost_inundation_to_plots_only.R`

Canonical outputs:

- `Output/csv/07f_pre_post_inundation_plot_summary_fixed.csv`
- `data_processed/plot_pre_post_inundation_frequency_fixed.csv`

Earlier fallback/provenance outputs:

- `Output/csv/07e_pre_post_inundation_plot_summary.csv`
- `data_processed/plot_pre_post_inundation_frequency.csv`

Use the fixed `07f` output for plot-level interpretation.

## Curated Analysis-Base Outputs

Active wrapper:

- `scripts/03_inundation_products/09a_curate_rs_hydrology_analysis_base.R`

Source script:

- `scripts/archive/pre_clean_spine_20260623/07_curate_rs_analysis_base.R`

Canonical outputs:

- `Output/csv/curated_ground_cover_timeseries.csv`
- `Output/csv/curated_annual_inundation_timeseries.csv`
- `Output/csv/curated_daily_inundation_monthly.csv`
- `Output/csv/plot_rs_analysis_base.csv`

Diagnostics:

- `Output/diagnostics/07_curate_rs_analysis_base/07_curate_row_counts.csv`
- `Output/diagnostics/07_curate_rs_analysis_base/07_curate_duplicate_checks.csv`
- `Output/diagnostics/07_curate_rs_analysis_base/07_curate_variable_lut.csv`
- `Output/diagnostics/07_curate_rs_analysis_base/07_curate_vegetation_group_counts.csv`
- `Output/diagnostics/07z_check_curated_outputs/`

## Known Caveats

- Inundation frequency is annual occurrence frequency, not duration, depth, hydroperiod, or wet days.
- The post-minus-pre inundation metric is in percentage points, not percent change.
- Sensor density differs among years; Sentinel-rich years may detect short-lived water more readily.
- Some `valid_coverage_pct` values can be slightly over 100 because of area/coverage rounding artefacts; flag these in QA instead of silently ignoring them.
- Ground-cover estimates may be uncertain in treed or woody plots.
- Tree flags are not final and treed plots should not be excluded by default.
- Grazing treatment is retained as metadata, but treatment comparison is a secondary sanity check rather than the main causal story.
- BFAST/tbreak should remain deferred until curated tables, pre/post inundation, pre/post ground cover, missingness, and lag diagnostics have been reviewed.
