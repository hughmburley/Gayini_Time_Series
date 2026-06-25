# Function File Inventory

Last updated: 2026-06-15

This inventory supports the controlled cleanup pass before the next analysis phase. It identifies which helper files are general, plotting-oriented, or specialised raster/extraction code. No broad helper rewrites were made in this pass.

## General Helper Candidates

- `R/gayini_helpers.R`
  - General project helpers for package checks, standard paths, directory creation, field lookup, uniqueness checks, and file writing.
  - Candidate for future consolidation with `R/gayini_analysis_base_functions.R`, especially `gayini_check_packages()` and first-existing/required-file style helpers.
- `R/gayini_analysis_base_functions.R`
  - Current general analysis-base helper file for curated tables.
  - Keep as the central helper file for Step 8 onward tabular analysis, plot ID standardisation, water years, periods, vegetation-group recoding, ground-cover band recoding, duplicate checks, row-count diagnostics, and variable lookup tables.

## Plotting Helpers

- `R/step7_figure_helpers.R`
  - Step 7 plotting and map helpers, including plot context loading, cluster helpers, figure-index writing, and chart/map themes.
  - Keep as plotting support for legacy/current Step 7 figure scripts until figure code is consolidated.
- `R/inundation_pre_post_plotting_functions.R`
  - Older pre/post plotting helper file.
  - Some functions overlap with `step7_figure_helpers.R`; keep for compatibility until the Step 7 plotting scripts are retired or updated.
- `R/gayini_review_figure_functions.R`
  - Review/QA figure helpers.
  - Keep separate for review figure workflows.

## Specialised Extraction And Raster Helpers

Do not rewrite these in this cleanup pass except for narrow, tested, mechanical changes:

- `R/vector_prep_functions.R`
- `R/raster_catalog_functions.R`
- `R/raster_subset_functions.R`
- `R/fractional_cover_extraction_functions.R`
- `R/inundation_extraction_functions.R`
- `R/daily_inundation_extraction_functions.R`
- `R/inundation_pre_post_raster_functions.R`
- `R/gayini_temp_cleanup_functions.R`

These files contain specialised spatial, extraction, terra, exactextractr, and raster-build logic. They are active dependencies for upstream extraction and raster processing, so broad consolidation or style-only rewrites would be higher risk than useful before the next analysis phase.

## Duplicated Helper Patterns

Known duplicated function families:

- Package checks:
  - `gayini_check_packages()` in `R/gayini_helpers.R`, `R/gayini_analysis_base_functions.R`, and `R/step7_figure_helpers.R`.
- First-existing / candidate-column helpers:
  - `gayini_find_first_existing()`, `gayini_get_first_existing_column()`, `gayini_first_existing_column()`, and related field lookup helpers.
- Plot ID standardisation:
  - `gayini_find_plot_id_column()` and `gayini_standardise_plot_id()` occur in analysis/figure helper code.
- Safe summary helpers:
  - `gayini_safe_min()`, `gayini_safe_max()`, `gayini_safe_mean()`, and `gayini_safe_median()` occur in extraction/review helpers.
- Water-year helpers:
  - `gayini_assign_water_year()`, `gayini_get_water_year()`, and `gayini_make_water_year()` occur in analysis and extraction/raster helper files.

## Cleanup Decision

Low-risk action taken:

- Created cleaner active wrapper scripts and documentation.
- Added the non-expensive `06z` raster-output QA script.

Risky changes avoided:

- Did not consolidate extraction/raster helpers into `R/gayini_analysis_base_functions.R`.
- Did not rewrite specialised raster-processing functions.
- Did not mechanically replace every existing base R pipe in specialised active helper files, because those files support expensive extraction/raster workflows that are not being rerun in this pass.

Recommended future cleanup:

1. Create a small `R/gayini_core_helpers.R` or expand `R/gayini_analysis_base_functions.R` with truly generic helpers only.
2. Update active scripts one family at a time to source the shared helper.
3. Run the corresponding lightweight or full workflow checks after each family-level consolidation.
4. Defer extraction/raster helper style rewrites until an approved extraction/raster rerun window.

