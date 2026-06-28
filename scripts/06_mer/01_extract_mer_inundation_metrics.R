# ------------------------------------------------------------------------------
# Script: scripts/06_mer/01_extract_mer_inundation_metrics.R
# Purpose: Extract MER plot-level observed-footprint metrics.
# Workflow stage: 06_mer
# Run mode: lightweight_review
# Heavy processing: no
# Key inputs:
#   - Daily inundation extraction outputs.
# Key outputs:
#   - MER plot metric CSVs/diagnostics.
# Notes:
#   - MER observed wet extent metrics are supplementary and are not
#     hydroperiod.
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Load configuration and execute workflow step
# ------------------------------------------------------------------------------

## Purpose:
## Preferred active driver for Flow_MER-inspired plot-level inundation metrics
## and compact deck-ready RS outputs.


root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", "D:/Github_repos/Gayini"), winslash = "/", mustWork = TRUE)

source(file.path(root_dir, "R", "gayini_mer_inundation_functions.R"))

run_gayini_mer_inundation(root_dir = root_dir)
write_gayini_mer_deck_outputs(root_dir = root_dir)
