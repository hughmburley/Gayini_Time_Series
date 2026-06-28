# ------------------------------------------------------------------------------
# Script: scripts/07_figures_dashboards/01_make_review_figures_and_dashboards.R
# Purpose: Make review figures and dashboards.
# Workflow stage: 07_figures_dashboards
# Run mode: lightweight_review
# Heavy processing: no
# Key inputs:
#   - Curated outputs and context tables.
# Key outputs:
#   - Review figures and dashboard assets.
# Notes:
#   - Keep stable output filenames for downstream reports.
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Load configuration and execute workflow step
# ------------------------------------------------------------------------------

## Purpose:
## Preferred active wrapper for review figures and dashboards, including gauge
## context figures when imported gauge context is available.


root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", "D:/Github_repos/Gayini"), winslash = "/", mustWork = TRUE)

# Internal implementation modules; this file is the active workflow entry point.
source(file.path(root_dir, "scripts", "07_figures_dashboards", "internal", "01_make_adrian_review_png_assets_impl.R"), chdir = TRUE)

gauge_figure_script <- file.path(root_dir, "scripts", "07_figures_dashboards", "internal", "02_plot_rs_gauge_context_impl.R")
if (file.exists(gauge_figure_script)) {
  source(gauge_figure_script, chdir = TRUE)
}
