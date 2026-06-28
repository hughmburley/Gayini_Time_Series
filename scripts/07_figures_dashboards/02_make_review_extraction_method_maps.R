# ------------------------------------------------------------------------------
# Script: scripts/07_figures_dashboards/02_make_review_extraction_method_maps.R
# Purpose: Make extraction-method maps.
# Workflow stage: 07_figures_dashboards
# Run mode: lightweight_review
# Heavy processing: no
# Key inputs:
#   - Spatial inputs and existing products.
# Key outputs:
#   - Appendix/method map assets.
# Notes:
#   - Keep stable output filenames for downstream reports.
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Load configuration and execute workflow step
# ------------------------------------------------------------------------------

## Purpose:
## Preferred active wrapper for appendix/method map assets used in review
## outputs.


root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", "D:/Github_repos/Gayini"), winslash = "/", mustWork = TRUE)

# Internal implementation module; this file is the active workflow entry point.
source(file.path(root_dir, "scripts", "07_figures_dashboards", "internal", "03_make_review_extraction_method_maps_impl.R"), chdir = TRUE)
