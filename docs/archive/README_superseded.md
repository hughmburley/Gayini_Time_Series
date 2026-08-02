# Gayini Run Order

These files define the handoff-ready run order after Stage 4 script renaming. Start with the repository README, then run `run_spine_smoke_test.R` before attempting any workflow script.

## Files

- `01_full_rebuild_workflow.csv`: full production sequence, including heavy extraction and protected raster build steps.
- `02_lightweight_review_refresh.csv`: review/deck refresh scripts that are safe after curated outputs exist.
- `03_mer_workflow.csv`: MER plot-table, package, raster readiness and raster production scripts.
- `04_qa_workflow.csv`: read-only checks and local maintenance helpers.
- `05_downstream_optional.csv`: optional diagnostics outside the production spine.

## Safety

Do not run heavy extraction or raster build scripts casually. In particular, scripts under `02_extract_heavy/`, `03_inundation_products/01_build_prepost_inundation_products.R`, and `06_mer/07_build_mer_annual_max_rasters.R` require explicit intent and current inputs. The default spine smoke test parses and checks structure only; it does not rebuild outputs.
