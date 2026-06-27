# Current Run Order

Last updated: 2026-06-27

This document records the active Gayini RS/hydrology workflow after the Stage 3 scripts-folder rationalisation. Active scripts are grouped by workflow role under `scripts/`; historical scripts are retained under `scripts/archive/` for provenance and should not be run as active entry points.

Do not rerun expensive raster work just to refresh figures or diagnostics. In particular, `08a_build_prepost_inundation_products.R` should only be run when pre/post raster products need to be regenerated.

## Active Script Order

1. `scripts/00_setup/00_setup_project.R`
2. `scripts/01_prepare_inputs/01_prepare_vectors.R`
3. `scripts/01_prepare_inputs/02_catalog_rasters.R`
4. `scripts/02_extract_heavy/03_extract_ground_cover_full.R`
   - Ground-cover orchestrator. Landsat plot-scale extraction remains the core branch; optional MODIS broad-context extraction is controlled by `GAYINI_RUN_MODIS_GC`.
5. `scripts/02_extract_heavy/04_extract_annual_inundation_full.R`
   - Annual Landsat inundation extraction.
6. `scripts/02_extract_heavy/05_extract_daily_inundation_full.R`
   - Daily inundation extraction.
7. `scripts/06_mer/06_extract_MER_inundation_metrics.R`
   - Flow_MER-inspired plot-level daily inundation metrics.
   - Remote-sensing only: consumes the existing daily extraction table; does not read gauges, hydrology databases or rasters.
   - Sources active MER logic from `R/gayini_mer_inundation_functions.R`; archived `05b` code is provenance only.
   - Also writes compact MER review shortlist and deck-candidate figures.
8. `scripts/04_gauges/07_import_murrumbidgee_gauge_context.R`
   - Optional gauge-context import for later review stages.
   - Prefers a packaged clean gauge database under `Input/hydrology/`, then falls back to clean Murrumbidgee gauge exports.
   - Gauge download, patching and QA logic remains outside Gayini.
9. `scripts/03_inundation_products/08a_build_prepost_inundation_products.R`
   - Builds pre/post annual inundation occurrence products.
   - Expensive raster-processing step; run only when explicitly needed.
10. `scripts/09_qa/08b_check_prepost_inundation_products.R`
    - Read-only QA for existing pre/post inundation products.
    - Does not rebuild rasters.
11. `scripts/03_inundation_products/08c_extract_prepost_inundation_to_plots.R`
    - Extracts fixed pre/post inundation products to plots.
12. `scripts/03_inundation_products/09a_curate_rs_hydrology_analysis_base.R`
    - Builds the canonical RS curation outputs.
    - Runs RS/gauge context joins only when imported gauge summaries are available.
    - Stable output filenames remain unchanged.
13. `scripts/09_qa/09b_check_curated_rs_hydrology_outputs.R`
    - Curated-output QA.
14. `scripts/05_ground_cover/10a_prepare_ground_cover_response_and_review_tables.R`
    - Prepares ground-cover response summaries and review tables.
15. `scripts/07_figures_dashboards/10b_make_review_figures_and_dashboards.R`
    - Builds review figures and dashboards, including gauge context figures where available.
16. `scripts/07_figures_dashboards/10c_make_review_extraction_method_maps.R`
    - Builds appendix/method map assets.

There is intentionally no parent `08_build_prepost_inundation_products.R` script. The `08a/08b/08c` substeps are the active entries for that stage.

## Shared Helper Modules

Stage 1 code refresh helpers under `R/` support lightweight review, deck and MER summary scripts. They do not add run-order steps and should not be run directly:

- `R/gayini_plotting_helpers.R`
- `R/gayini_time_helpers.R`
- `R/gayini_output_helpers.R`
- `R/gayini_interpretation_filters.R`
- `R/gayini_mer_helpers.R`

## Archived Scripts

Historical scripts moved out of the active spine are retained under:

```text
scripts/archive/pre_clean_spine_20260623/
scripts/archive/obs_legacy_20260627/
scripts/archive/one_off_utilities_20260627/
```

They are retained for provenance only. The active entry points above are the workflow to run.

The archive includes the former top-level `05b`, `06`, `06z`, `07`, `07z`, `08`, `09`, `10`, `11`, `13`, `15`, and `17a/17b/17c` scripts, retired `obs` development/test scripts, and one-off utilities that should not be active entry points.

Local PowerShell packaging utilities were removed from the shared branch after being backed up locally under:

```text
Output/reports/code_refresh/stage3_removed_local_packaging/
```

They are documented in `docs/scripts_manifest.csv` and `Output/reports/code_refresh/stage3_removed_from_github_manifest.csv`.

Formal lag diagnostics are outside the active spine:

```text
scripts/10_downstream_optional/12_lag_diagnostics_inundation_gc.R
```

Use it only for downstream descriptive/statistical exploration, not as a main workflow step.

## Canonical Outputs

Use these outputs for downstream interpretation:

### Ground Cover

- `data_processed/plot_fractional_cover_timeseries.csv`
- `Output/csv/04c_fractional_cover_full.csv`
- Optional MODIS context outputs:
  - `data_processed/modis_ground_cover_context_timeseries.csv`
  - `Output/csv/03_modis_ground_cover_context_full.csv`

### Annual Inundation

- `data_processed/plot_landsat_inundation_timeseries.csv`
- `Output/csv/05c_landsat_inundation_full.csv`

### Daily Inundation

- `data_processed/plot_daily_inundation_timeseries.csv`
- `Output/csv/06c_daily_inundation_full.csv`

### MER Daily Inundation Summaries

- `Output/csv/05b_MER_plot_inundation_dynamic_metrics.csv`
- `data_processed/plot_inundation_dynamic_metrics.csv`
- `Output/csv/05b_MER_plot_inundation_monthly_seasonal_max.csv`
- `Output/diagnostics/06_MER_inundation/`
- `Output/figures/06_MER_inundation/`
- `Output/figures/06_MER_inundation/deck_candidates/`
- `Output/diagnostics/06_MER_inundation/mer_plot_review_shortlist.csv`
- `Output/diagnostics/06_MER_inundation/mer_deck_metric_use_notes.csv`
- Historical diagnostics retained for provenance:
  - `Output/diagnostics/05b_MER_inundation/`

### Gauge Context

- `Output/diagnostics/hydrology/gauge_database_import_manifest.csv`
- `data_processed/hydrology/gauge_context_for_deck.csv`
- `data_processed/hydrology/plot_rs_gauge_monthly_context.csv`
- `data_processed/hydrology/plot_rs_gauge_water_year_context.csv`
- `Output/diagnostics/hydrology/`

### Pre/Post Inundation Products

- `Output/rasters/inundation_pre_post/pre_conservation_inundation_frequency_pct.tif`
- `Output/rasters/inundation_pre_post/post_conservation_inundation_frequency_pct.tif`
- `Output/rasters/inundation_pre_post/post_minus_pre_inundation_frequency_pct_points.tif`
- `Output/csv/07f_pre_post_inundation_plot_summary_fixed.csv`
- `data_processed/plot_pre_post_inundation_frequency_fixed.csv`

### Curated Analysis Base

- `Output/csv/curated_ground_cover_timeseries.csv`
- `Output/csv/curated_annual_inundation_timeseries.csv`
- `Output/csv/curated_daily_inundation_monthly.csv`
- `Output/csv/plot_rs_analysis_base.csv`
- `Output/diagnostics/07_curate_rs_analysis_base/07_curate_variable_lut.csv`

### Review Tables And Figures

- `Output/csv/10a_ground_cover_prepost_plot_summary.csv`
- `Output/csv/10a_ground_cover_prepost_group_summary.csv`
- `Output/csv/10a_ground_cover_prepost_model_summary.csv`
- `Output/figures/10b_ground_cover_prepost_figures/`
- `Output/figures/hydrology/`

## Stale Or Debug Outputs

These are retained for provenance/debugging, but should not be used as canonical interpretation sources:

- `Output/csv/test_fractional_cover_extraction.csv`
- `Output/csv/04b_fractional_cover_all_dev_plots.csv`
- `Output/csv/05a_landsat_inundation_10_plots.csv`
- `Output/csv/05b_landsat_inundation_all_dev_plots.csv`
- `Output/csv/06a_daily_inundation_10_plots.csv`
- `Output/csv/06b_daily_inundation_all_dev_plots.csv`
- `Output/csv/07e_pre_post_inundation_plot_summary.csv`
- `Output/csv/raster_dev_subset_summary.csv`
- `Output/csv/raster_product_summary.csv`
- `Output/csv/raster_sensor_summary.csv`
- `Output/csv/plot_count_by_treatment.csv`
- `Output/csv/plot_count_by_vegetation.csv`
- `Output/csv/plot_count_by_vegetation_and_treatment.csv`

Use `Output/csv/07f_pre_post_inundation_plot_summary_fixed.csv` instead of the earlier `07e` plot summary for plot-level pre/post interpretation.
