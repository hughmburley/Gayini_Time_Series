# Gayini Remote Sensing Analysis

This repository contains the Gayini remote sensing, inundation, vegetation and
hydrology analysis workflow.

## How To Run The Workflow

1. Run `run_spine_smoke_test.R` from the repository root.
2. Review `docs/run_order/README.md`.
3. Run lightweight review refresh scripts only after curated outputs exist.
4. Do not run heavy extraction scripts unless rebuilding the full analysis.
5. Treat MER raster production under `scripts/06_mer/` as explicit-run only.
6. Do not use archived scripts for current analyses.

## Active Scripts

Active scripts live under `scripts/` in numbered workflow folders:

- `00_setup/`
- `01_prepare_inputs/`
- `02_extract_heavy/`
- `03_inundation_products/`
- `04_gauges/`
- `05_ground_cover/`
- `06_mer/`
- `07_figures_dashboards/`
- `08_review_packages/`
- `09_qa/`
- `10_downstream_optional/`

Use `docs/current_run_order.md` for the current sequence and
`docs/scripts_manifest.csv` for the script classification/rename record.

## Safety Notes

Raw inputs live under `Input/` and are ignored by Git. Generated outputs live
under `Output/` and are also ignored by Git. Heavy extraction and raster build
scripts are not run by the smoke test and should not be run casually.

Legacy script provenance is retained through Git history and the Stage 5 removal
manifests under `docs/`. Local packaging utilities were removed from the shared
GitHub workflow during the scripts-folder rationalisation.

## Package-Style Scaffold

The repository includes a minimal `DESCRIPTION`, `NAMESPACE`, and lightweight
`testthat` fixtures. It is package-ready scaffolding only; workflow scripts still
source helper files directly from `R/`.
