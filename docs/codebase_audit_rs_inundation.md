# Gayini RS Inundation Codebase Audit

Date: 2026-06-23

> Superseded by `docs/current_run_order.md` and `docs/CHANGELOG_rs_final_pruning.md` for active workflow naming. Old script names in this audit are historical/non-active unless they also appear in the current run order.

## Scope

This audit covers the main `Gayini` repository only, with emphasis on the remote-sensing inundation spine. It does not review or merge code from the separate `Water_gauges` or `Biodiversity` repositories.

The audit was run in conservative mode: identify structure and risks first, then make only clearly safe consolidation changes. No scientific metric logic was changed.

## High-Level Findings

1. Several active top-level wrappers pointed to missing top-level legacy scripts. The corresponding source scripts existed under `scripts/obs/`, so the wrappers were broken for normal use.
2. The current canonical curation path is clear: `scripts/07_curate_rs_analysis_base.R` writes the curated tables and `scripts/07z_check_curated_outputs.R` checks them.
3. The repository still carries a large amount of useful but non-canonical history in `scripts/obs/` and `R/obs/`. This is good for provenance but should not be treated as active workflow unless a wrapper explicitly says so.
4. Helper-function duplication is mostly between active files and their `R/obs/` archived equivalents. That is expected after the cleanup pass, but there is also some live duplication among `R/gayini_analysis_base_functions.R`, `R/step7_figure_helpers.R`, and `R/inundation_pre_post_plotting_functions.R`.
5. Outputs can be separated into canonical analysis outputs, QA diagnostics, review-only figure assets, and stale/debug outputs. The canonical list is now captured in `docs/rs_inundation_canonical_outputs.csv`.

## Active Script Spine

The active RS spine should be treated as:

1. `scripts/00_setup_project.R`
2. `scripts/01_prepare_vectors.R`
3. `scripts/02_catalog_rasters.R`
4. `scripts/03_extract_ground_cover_full.R`
5. `scripts/04_extract_annual_inundation_full.R`
6. `scripts/05_extract_daily_inundation_full.R`
7. `scripts/05b_MER_extract_inundation.R`
8. `scripts/06_build_prepost_inundation_rasters.R`
9. `scripts/06z_check_prepost_inundation_raster_outputs.R`
10. `scripts/07_extract_prepost_inundation_to_plots.R`
11. `scripts/07_curate_rs_analysis_base.R`
12. `scripts/07z_check_curated_outputs.R`
13. `scripts/10_ground_cover_prepost_response.R`
14. `scripts/11_ground_cover_prepost_figures.R`
15. `scripts/12_lag_diagnostics_inundation_gc.R`
16. `scripts/13_make_adrian_review_png_assets.R`
17. `scripts/15_make_review_extraction_method_maps.R`

`scripts/08_curate_rs_analysis_base.R` and `scripts/09_check_curated_outputs.R` are compatibility wrappers only. They should be retired once any external run notes are updated to call `07_curate` and `07z_check` directly.

## Wrapper Audit

| Script | Previous target status | Current decision |
|---|---|---|
| `scripts/04_extract_annual_inundation_full.R` | Target missing at top level; source existed in `scripts/obs/` | Fixed wrapper to source `scripts/obs/05c_extract_landsat_inundation_full.R` explicitly |
| `scripts/05_extract_daily_inundation_full.R` | Target missing at top level; source existed in `scripts/obs/` | Fixed wrapper to source `scripts/obs/06c_extract_daily_inundation_full.R` explicitly |
| `scripts/06_build_prepost_inundation_rasters.R` | Target missing at top level; source existed in `scripts/obs/` | Fixed wrapper to source `scripts/obs/07e_build_pre_post_inundation_frequency_rasters.R` explicitly |
| `scripts/07_extract_prepost_inundation_to_plots.R` | Target missing at top level; source existed in `scripts/obs/` | Fixed wrapper to source `scripts/obs/07f_reextract_prepost_inundation_to_plots_only.R` explicitly |
| `scripts/08_curate_rs_analysis_base.R` | Target exists | Keep temporarily as compatibility wrapper |
| `scripts/09_check_curated_outputs.R` | Target exists | Keep temporarily as compatibility wrapper |
| `scripts/10_ground_cover_prepost_response.R` | Target missing at top level; source existed in `scripts/obs/` | Fixed wrapper to source `scripts/obs/10a_ground_cover_prepost_response.R` explicitly |
| `scripts/11_ground_cover_prepost_figures.R` | Target missing at top level; source existed in `scripts/obs/` | Fixed wrapper to source `scripts/obs/10b_ground_cover_prepost_figures.R` explicitly |

These wrapper fixes are intentionally conservative. They restore runnable paths without copying thousands of lines into active scripts or changing scientific logic.

## Obsolete, Superseded, or Review-Only Scripts

The following should not be treated as canonical active workflow scripts:

- `scripts/extraction_check_fractional_cover_visualise.R` is ad hoc visual checking and is an archive candidate.
- `scripts/03_make_raster_dev_subset.R` is a development helper.
- `scripts/refine_modis_phase3_assets.R` is a MODIS review helper, not part of the inundation spine.
- `scripts/obs/04a*`, `04b*`, `05a*`, `05b*`, `06a*`, `06b*` are test/dev extraction scripts.
- `scripts/obs/07g_plot_pre_post_inundation_summary_panels.R` and `scripts/obs/07h_plot_annual_inundation_panels.R` are superseded by their `v2` scripts.
- `scripts/obs/07a` through `07k` contain useful historic figure and analysis scripts but should remain provenance/review support unless promoted deliberately.

## Helper Function Duplication

Expected duplication:

- Most duplicate helper names are active-vs-`R/obs/` copies after the cleanup pass. Examples include `gayini_catalog_rasters`, `gayini_prepare_core_vectors`, `gayini_count_fraction_summary`, and many pre/post raster helpers.

Live duplication worth later consolidation:

- `gayini_check_packages` appears in `R/gayini_helpers.R`, `R/step7_figure_helpers.R`, and `R/gayini_analysis_base_functions.R`.
- `gayini_find_first_existing`, `gayini_find_plot_id_column`, `gayini_get_first_existing_column`, and `gayini_standardise_plot_id` appear in both `R/step7_figure_helpers.R` and `R/gayini_analysis_base_functions.R`.
- Plotting helpers are split between `R/inundation_pre_post_plotting_functions.R` and `R/step7_figure_helpers.R`.

Recommendation: do not refactor these in the same pass as wrapper repair. Later, move generic package/path/plot-id helpers into one common file and have plotting helpers source it.

## Canonical Outputs

Canonical outputs are listed in `docs/rs_inundation_canonical_outputs.csv`.

Most important downstream outputs are:

- `Output/csv/curated_annual_inundation_timeseries.csv`
- `Output/csv/curated_daily_inundation_monthly.csv`
- `Output/csv/05b_MER_plot_inundation_dynamic_metrics.csv`
- `Output/csv/05b_MER_plot_inundation_monthly_seasonal_max.csv`
- `Output/csv/curated_ground_cover_timeseries.csv`
- `Output/csv/plot_rs_analysis_base.csv`
- `Output/diagnostics/07_curate_rs_analysis_base/07_curate_variable_lut.csv`
- `Output/rasters/inundation_pre_post/pre_conservation_inundation_frequency_pct.tif`
- `Output/rasters/inundation_pre_post/post_conservation_inundation_frequency_pct.tif`
- `Output/rasters/inundation_pre_post/post_minus_pre_inundation_frequency_pct_points.tif`

The current annual inundation metric remains annual occurrence frequency:

`100 * wet valid water years / valid water years`

It is not hydroperiod, flood depth, duration, or wet days. MER metrics remain supporting observed extent/timing metrics.

## Consolidation Decisions

Safe changes made:

- Fixed broken wrappers to source the current `scripts/obs/` logic explicitly.
- Documented those wrappers as temporary compatibility wrappers.
- Added workflow and canonical-output manifests.
- Added this audit report and a changelog.

Changes deferred:

- Moving large source scripts from `scripts/obs/` into active top-level scripts.
- Merging method-map generation from `scripts/15_make_review_extraction_method_maps.R` into `scripts/13_make_adrian_review_png_assets.R`.
- Consolidating duplicate helper functions across `R/step7_figure_helpers.R`, `R/inundation_pre_post_plotting_functions.R`, and `R/gayini_analysis_base_functions.R`.
- Archiving obsolete scripts. No files were deleted or moved in this pass.

## Manual Review Still Needed

1. Decide whether the active wrappers should eventually absorb their `scripts/obs/` source logic.
2. Decide whether `08`/`09` compatibility wrappers can be retired after updating all run notes.
3. Review whether `13` should become the single review-figure generator and whether `15` should remain appendix/method maps.
4. Review live helper duplication before any refactor, especially functions shared by curation and figures.
5. Run expensive raster steps only when explicitly needed; this audit did not rebuild rasters.
