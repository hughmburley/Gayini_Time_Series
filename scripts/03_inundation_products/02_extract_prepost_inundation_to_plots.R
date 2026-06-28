# ------------------------------------------------------------------------------
# Script: scripts/03_inundation_products/02_extract_prepost_inundation_to_plots.R
# Purpose: Extract pre/post products to plots.
# Workflow stage: 03_inundation_products
# Run mode: lightweight_review
# Heavy processing: no
# Key inputs:
#   - Pre/post rasters and plots.
# Key outputs:
#   - Canonical plot-level pre/post table.
# Notes:
#   - Keep stable output filenames for downstream reports.
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Load configuration and execute workflow step
# ------------------------------------------------------------------------------

## Purpose:
## Preferred active wrapper for extracting pre/post inundation products to plots.
## Stable output filenames are retained by the source script.


root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", "D:/Github_repos/Gayini"), winslash = "/", mustWork = TRUE)
source(file.path(root_dir, "scripts", "03_inundation_products", "internal", "02_reextract_prepost_inundation_to_plots_only_impl.R"), chdir = TRUE)
