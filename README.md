# Gayini remote sensing R scaffold

This starter scaffold is designed for an RStudio project.

Run scripts in order:

1. `scripts/00_setup/00_setup_project.R`
2. `scripts/01_prepare_inputs/01_prepare_vectors.R`
3. `scripts/01_prepare_inputs/02_catalog_rasters.R`

The raw data should stay inside `Input/` and should not be edited by the scripts.

The first milestone is a clean `data_processed/plot_master.csv` and a raster catalogue. Extraction and BFAST/tbreak analyses should only start after those checks have passed.
