# RS Inundation Consolidation Changelog

Date: 2026-06-23

> Superseded by `docs/CHANGELOG_rs_final_pruning.md` for active workflow naming. Old script names below describe the earlier consolidation pass and are historical/non-active.

## Changes Made

- Fixed active compatibility wrappers that pointed to missing top-level legacy script names.
- Updated the following wrappers to source the existing `scripts/obs/` implementation explicitly:
  - `scripts/04_extract_annual_inundation_full.R`
  - `scripts/05_extract_daily_inundation_full.R`
  - `scripts/06_build_prepost_inundation_rasters.R`
  - `scripts/07_extract_prepost_inundation_to_plots.R`
  - `scripts/10_ground_cover_prepost_response.R`
  - `scripts/11_ground_cover_prepost_figures.R`
- Added comments to those wrappers explaining that the `scripts/obs/` dependency is intentional and temporary until logic is merged into the active script.
- Confirmed `scripts/07_curate_rs_analysis_base.R` as the canonical RS curation script.
- Confirmed `scripts/07z_check_curated_outputs.R` as the canonical curated-output QA script.
- Marked `scripts/08_curate_rs_analysis_base.R` and `scripts/09_check_curated_outputs.R` as temporary compatibility wrappers in the workflow manifest.
- Added `docs/rs_inundation_workflow_manifest.csv`.
- Added `docs/rs_inundation_canonical_outputs.csv`.
- Added `docs/codebase_audit_rs_inundation.md`.

## Changes Not Made

- Did not move large source scripts out of `scripts/obs/` in this pass.
- Did not delete or archive any scripts.
- Did not rerun expensive raster processing.
- Did not change the scientific definitions of annual occurrence frequency or MER observed-sequence metrics.
- Did not merge `scripts/15_make_review_extraction_method_maps.R` into `scripts/13_make_adrian_review_png_assets.R`; it remains labelled as appendix/method asset generation pending manual review.

## Output Column Changes

- No new output columns were introduced during this audit pass.
- Existing MER columns previously added to `Output/csv/plot_rs_analysis_base.csv` remain part of the curated plot analysis base.

## Manual Review Still Needed

- Decide whether to merge the six fixed wrapper source scripts from `scripts/obs/` into their active top-level script names.
- Decide whether `scripts/13_make_adrian_review_png_assets.R` should absorb method-map generation from `scripts/15_make_review_extraction_method_maps.R`.
- Decide whether `R/step7_figure_helpers.R` should import common helpers from `R/gayini_analysis_base_functions.R` instead of carrying duplicate helper definitions.
