# ------------------------------------------------------------------------------
# Script: scripts/09_qa/02_check_curated_rs_hydrology_outputs.R
# Purpose: Check curated RS/hydrology outputs.
# Workflow stage: 09_qa
# Run mode: qa
# Heavy processing: no
# Key inputs:
#   - Curated CSV outputs.
# Key outputs:
#   - QA diagnostics.
# Notes:
#   - QA step should read existing products and avoid rebuilding outputs.
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Load configuration and execute workflow step
# ------------------------------------------------------------------------------

## Purpose:
## Preferred active wrapper for curated RS/hydrology-output QA.


root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", "D:/Github_repos/Gayini"), winslash = "/", mustWork = TRUE)

# Archived implementation module; this file is the active workflow entry point.
source(file.path(root_dir, "scripts", "09_qa", "internal", "02_check_curated_outputs_impl.R"), chdir = TRUE)
