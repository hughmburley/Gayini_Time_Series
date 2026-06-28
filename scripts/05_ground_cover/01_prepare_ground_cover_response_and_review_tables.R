# ------------------------------------------------------------------------------
# Script: scripts/05_ground_cover/01_prepare_ground_cover_response_and_review_tables.R
# Purpose: Prepare ground-cover response and review tables.
# Workflow stage: 05_ground_cover
# Run mode: lightweight_review
# Heavy processing: no
# Key inputs:
#   - Curated analysis-base outputs.
# Key outputs:
#   - Ground-cover pre/post summary tables.
# Notes:
#   - Keep stable output filenames for downstream reports.
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Load configuration and execute workflow step
# ------------------------------------------------------------------------------

## Purpose:
## Preferred active wrapper for downstream ground-cover response summaries and
## review tables. Stable output filenames are retained by the source script.


root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", "D:/Github_repos/Gayini"), winslash = "/", mustWork = TRUE)
source(file.path(root_dir, "scripts", "05_ground_cover", "internal", "01_ground_cover_prepost_response_impl.R"), chdir = TRUE)
