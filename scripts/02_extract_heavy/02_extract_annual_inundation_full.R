# ------------------------------------------------------------------------------
# Script: scripts/02_extract_heavy/02_extract_annual_inundation_full.R
# Purpose: Extract annual Landsat inundation.
# Workflow stage: 02_extract_heavy
# Run mode: heavy
# Heavy processing: yes
# Key inputs:
#   - Annual inundation rasters and plots.
# Key outputs:
#   - Annual inundation CSVs and processed tables.
# Notes:
#   - Heavy step; do not run casually and never from the smoke test.
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Load configuration and execute workflow step
# ------------------------------------------------------------------------------

## Purpose:
## Thin compatibility wrapper for the current full annual inundation extraction
## script. The current source logic is tracked under scripts/02_extract_heavy/
## internal/ for reproducibility; keep this wrapper until that logic is merged
## into this active script.


root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", "D:/Github_repos/Gayini"), winslash = "/", mustWork = TRUE)
source(file.path(root_dir, "scripts", "02_extract_heavy", "internal", "01_extract_landsat_inundation_full_impl.R"), chdir = TRUE)
