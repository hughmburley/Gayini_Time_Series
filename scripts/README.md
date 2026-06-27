# Gayini Scripts

The scripts folder is grouped by workflow role. Use `docs/current_run_order.md`
for the canonical run order and `docs/scripts_manifest.csv` for the full
classification and archive/removal record.

## Current Workflow Groups

- `00_setup/`: project setup and folder/config scaffolding.
- `01_prepare_inputs/`: vector preparation and raster catalogues.
- `02_extract_heavy/`: heavy ground-cover, annual inundation and daily inundation extraction. The `internal/` folder holds tracked compatibility-source scripts used by the active wrappers.
- `03_inundation_products/`: pre/post inundation products and curated analysis-base outputs.
- `04_gauges/`: optional Murrumbidgee gauge-context import.
- `05_ground_cover/`: ground-cover response and review tables.
- `06_mer/`: MER plot-table workflow, MER package support and MER raster census/build/summary scripts. Treat raster build scripts as explicit-run only.
- `07_figures_dashboards/`: review figures, dashboards, context flags and deck figure refresh scripts.
- `08_review_packages/`: review/PPT package spine and missing-asset scripts.
- `09_qa/`: read-only checks and local QA/maintenance helpers.
- `10_downstream_optional/`: optional descriptive diagnostics outside the production spine.
- `archive/`: legacy and one-off scripts retained for provenance only.

Do not run heavy extraction or raster build scripts just to refresh review
figures. Local/off-repo packaging utilities were removed from the shared branch
in Stage 3 and documented in `docs/scripts_manifest.csv`.
