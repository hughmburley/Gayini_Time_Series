# ------------------------------------------------------------------------------
# Script: scripts/03_inundation_products/01_build_prepost_inundation_products.R
# Purpose: Build pre/post annual occurrence rasters.
# Workflow stage: 03_inundation_products
# Run mode: heavy
# Heavy processing: yes
# Key inputs:
#   - Annual inundation products.
# Key outputs:
#   - Pre/post inundation rasters.
# Notes:
#   - Heavy step; do not run casually and never from the smoke test.
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Load configuration and execute workflow step
# ------------------------------------------------------------------------------

## Purpose:
## Preferred active wrapper for building pre/post inundation products. This is an
## expensive raster-processing step; run only when raster products need to be
## regenerated.


root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", "D:/Github_repos/Gayini"), winslash = "/", mustWork = TRUE)
source(file.path(root_dir, "scripts", "03_inundation_products", "internal", "01_build_pre_post_inundation_frequency_rasters_impl.R"), chdir = TRUE)
