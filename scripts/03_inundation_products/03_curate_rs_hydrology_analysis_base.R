# ------------------------------------------------------------------------------
# Script: scripts/03_inundation_products/03_curate_rs_hydrology_analysis_base.R
# Purpose: Build curated RS/hydrology analysis tables.
# Workflow stage: 03_inundation_products
# Run mode: lightweight_review
# Heavy processing: no
# Key inputs:
#   - Canonical RS outputs and optional gauge context.
# Key outputs:
#   - Curated analysis-base CSVs.
# Notes:
#   - Keep stable output filenames for downstream reports.
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Load configuration and execute workflow step
# ------------------------------------------------------------------------------

## Purpose:
## Preferred active entry point for the canonical RS curation stage. Optional
## RS/gauge context joins run only when imported gauge summaries are available.


root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", "D:/Github_repos/Gayini"), winslash = "/", mustWork = TRUE)

# Internal implementation modules; this file is the active workflow entry point.
source(file.path(root_dir, "scripts", "03_inundation_products", "internal", "03_curate_rs_analysis_base_impl.R"), chdir = FALSE)

gauge_context_inputs <- file.path(root_dir, c(
  "data_intermediate/hydrology/gayini_gauge_monthly_imported.csv",
  "data_intermediate/hydrology/gayini_gauge_water_year_imported.csv"
))

if (all(file.exists(gauge_context_inputs))) {
  source(file.path(root_dir, "scripts", "03_inundation_products", "internal", "04_join_rs_and_gauge_timeseries_impl.R"), chdir = FALSE)
} else {
  message("Optional gauge context inputs not found; skipping RS/gauge context joins.")
}
