# ------------------------------------------------------------------------------
# Script: scripts/03_inundation_products/04_build_background_inundation_rasters.R
# Purpose: Build historical/background annual inundation occurrence rasters.
# Workflow stage: 03_inundation_products
# Run mode: heavy
# Heavy processing: yes
# Key inputs:
#   - raster_catalog.csv
#   - historical Landsat inundation rasters
#   - clean boundary and plot layers
# Key outputs:
#   - background annual occurrence rasters
#   - wet/valid year count rasters
#   - annual wet/valid rasters
#   - plot and vegetation-group summaries
# Notes:
#   - Heavy raster-processing step. Do not run from smoke tests.
# ------------------------------------------------------------------------------

root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", "D:/Github_repos/Gayini"), winslash = "/", mustWork = TRUE)
source(file.path(root_dir, "scripts", "03_inundation_products", "internal", "04_build_background_inundation_rasters_impl.R"), chdir = TRUE)
