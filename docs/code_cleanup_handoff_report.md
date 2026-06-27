# Code Cleanup Handoff Report

Generated: 2026-06-15

> Superseded workflow-note: this handoff predates the 2026-06-23 final pruning pass. Old script names in this file are historical/non-active unless they also appear in `docs/current_run_order.md`.

## Scope

This controlled cleanup pass archived old/test/dev code by copy only, added a cleaner active script sequence using wrappers, updated documentation, inventoried helper files, and added a lightweight QA script for existing pre/post inundation raster outputs.

No files were deleted. No extraction scripts were run. The expensive pre/post raster build was not run. `scripts/07e_build_pre_post_inundation_frequency_rasters.R` was not modified.

## Files Created

- `scripts/03_extract_ground_cover_full.R`
- `scripts/04_extract_annual_inundation_full.R`
- `scripts/05_extract_daily_inundation_full.R`
- `scripts/06_build_prepost_inundation_rasters.R`
- `scripts/06z_check_prepost_inundation_raster_outputs.R`
- `scripts/07_extract_prepost_inundation_to_plots.R`
- `scripts/08_curate_rs_analysis_base.R`
- `scripts/09_check_curated_outputs.R`
- `scripts/10_ground_cover_prepost_response.R`
- `scripts/11_ground_cover_prepost_figures.R`
- `docs/script_rename_map.csv`
- `docs/function_file_inventory.md`
- `docs/code_cleanup_handoff_report.md`
- `Output/diagnostics/06z_check_prepost_inundation_raster_outputs/06z_raster_file_inventory.csv`
- `Output/diagnostics/06z_check_prepost_inundation_raster_outputs/06z_raster_value_ranges.csv`
- `Output/diagnostics/06z_check_prepost_inundation_raster_outputs/06z_raster_alignment_checks.csv`
- `Output/diagnostics/06z_check_prepost_inundation_raster_outputs/06z_raster_logic_checks.csv`
- `Output/diagnostics/06z_check_prepost_inundation_raster_outputs/06z_codex_handoff_report.md`

## Files Modified

- `tools/archive_legacy_code.ps1`
  - Added older non-v2 Step 7 plotting scripts to the copy-only archive candidate list.
- `docs/current_run_order.md`
  - Updated active run order to the wrapper sequence.
- `docs/canonical_outputs_steps_04_07.md`
  - Updated canonical outputs and Step 06 raster QA notes.
- `docs/script_rename_map.csv`
  - Records wrapper, active, archived, and unchanged script statuses.

## Files Archived / Copied

Copied to `archive/code_pre_refactor_20260615/`; originals retained:

- `scripts/04a_test_fractional_cover_extraction_3_plots.R`
- `scripts/04b_test_fractional_cover_extraction_all_dev_plots.R`
- `scripts/05a_test_landsat_inundation_extraction_10_plots.R`
- `scripts/05b_test_landsat_inundation_extraction_all_dev_plots.R`
- `scripts/06a_test_daily_inundation_extraction_10_plots.R`
- `scripts/06b_test_daily_inundation_extraction_all_dev_plots.R`
- `scripts/07g_plot_pre_post_inundation_summary_panels.R`
- `scripts/07h_plot_annual_inundation_panels.R`
- `scripts/extraction_check_fractional_cover_visualise.R`
- `Output/csv/test_fractional_cover_extraction.csv`

Manifest:

- `archive/code_pre_refactor_20260615/archive_manifest.csv`

## Files Not Found

No required files were missing during the archive or lightweight QA steps.

## Commands Run

- `powershell -ExecutionPolicy Bypass -File tools/archive_legacy_code.ps1`
- `Rscript --vanilla scripts/09_check_curated_outputs.R`
- `Rscript --vanilla scripts/06z_check_prepost_inundation_raster_outputs.R`

`Rscript` was run with `C:\Program Files\R\R-4.5.1\bin` temporarily prepended to PATH because `Rscript` is not available on PATH in this shell.

## Check Status

### `09_check_curated_outputs.R`

Status: REVIEW

- Duplicate key checks: pass.
- Missingness checks: no variables with >=50% missingness.
- Review warning: `curated_annual_inundation_timeseries::valid_coverage_pct` ranges from `100.07883734054845` to `100.14170954658624`.

### `06z_check_prepost_inundation_raster_outputs.R`

Status: REVIEW

- Failed checks: 0.
- Passed checks: 105.
- Informational checks: 1.
- Review checks: 1.
- Review warning: `valid_coverage_pct_slightly_over_100`, with `n_over_100=2310` and `max=100.14171`.
- This is flagged as a likely area-rounding artefact rather than silently ignored.

## Warnings / Errors

- Initial `06z` run failed because `raster_type` was dropped before annual-year grouping. Patched only `scripts/06z_check_prepost_inundation_raster_outputs.R` and reran successfully.
- Both final lightweight checks completed with REVIEW status due the same valid-coverage rounding issue.
- No raster rebuilds or extraction runs were performed.

## Risky Changes Avoided

- Did not delete old files.
- Did not move old files.
- Did not rename proven working scripts directly.
- Did not modify `scripts/07e_build_pre_post_inundation_frequency_rasters.R`.
- Did not rewrite specialised extraction or raster helper files.
- Did not mechanically replace every existing base R pipe in specialised active helper files. These files support expensive extraction/raster workflows and should be updated only in a dedicated, tested pass.

## Recommended Next Task

Review the two REVIEW warnings and accept/document the `valid_coverage_pct` area-rounding artefact. After that, continue with lightweight missingness and lag diagnostics using the curated analysis-base outputs. Do not move on to BFAST/tbreak yet.
