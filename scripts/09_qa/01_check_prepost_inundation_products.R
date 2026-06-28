# ------------------------------------------------------------------------------
# Script: scripts/09_qa/01_check_prepost_inundation_products.R
# Purpose: Check existing pre/post inundation products.
# Workflow stage: 09_qa
# Run mode: qa
# Heavy processing: no
# Key inputs:
#   - Existing pre/post rasters.
# Key outputs:
#   - QA diagnostics.
# Notes:
#   - QA step should read existing products and avoid rebuilding outputs.
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Load configuration and execute workflow step
# ------------------------------------------------------------------------------

## Purpose:
## Preferred active wrapper for read-only QA of existing pre/post inundation
## products. This does not rebuild rasters.


root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", "D:/Github_repos/Gayini"), winslash = "/", mustWork = TRUE)

# Archived implementation module; this file is the active workflow entry point.
source(file.path(root_dir, "scripts", "09_qa", "internal", "01_check_prepost_inundation_raster_outputs_impl.R"), chdir = TRUE)
