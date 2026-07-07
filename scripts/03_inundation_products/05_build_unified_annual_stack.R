# ------------------------------------------------------------------------------
# Script: scripts/03_inundation_products/05_build_unified_annual_stack.R
# Purpose: Build one continuous per-water-year wet_any / valid_any raster stack
#          for all 35 water years (1988-1989 .. 2022-2023) on the pinned CRS
#          (EPSG:28355) and 25 m reference grid, with a manifest and QA.
# Workflow stage: 03_inundation_products
# Run mode: heavy
# Heavy processing: yes
# Key inputs:
#   - Input/landsat_inundation/lo_YYYY_YYYY.img  (35 canonical annual sources)
#   - Output/database/Gayini_Results.sqlite      (stg_canonical_annual_inundation)
# Key outputs:
#   - Output/rasters/inundation_annual_stack/annual_wet_any_1988_2023.tif   (35 lyr)
#   - Output/rasters/inundation_annual_stack/annual_valid_any_1988_2023.tif (35 lyr)
#   - Output/csv/annual_stack_manifest.csv
#   - raster_asset rows for both stacks (idempotent registration)
# Notes:
#   - Heavy raster-processing step. Do not run from smoke tests.
#   - Tier 0 sub-step 0.1. See docs/tier0_annual_stack_task.md.
# ------------------------------------------------------------------------------

root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", "D:/Github_repos/Gayini"), winslash = "/", mustWork = TRUE)
source(file.path(root_dir, "scripts", "03_inundation_products", "internal", "05_build_unified_annual_stack_impl.R"), chdir = TRUE)
