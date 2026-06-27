## -----------------------------------------------------------------------------
## Gayini remote sensing workflow
## 01_make_review_figures_and_dashboards.R
## -----------------------------------------------------------------------------


## Purpose:
## Preferred active wrapper for review figures and dashboards, including gauge
## context figures when imported gauge context is available.


root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", "D:/Github_repos/Gayini"), winslash = "/", mustWork = TRUE)

# Archived implementation modules; this file is the active workflow entry point.
source(file.path(root_dir, "scripts", "archive", "pre_clean_spine_20260623", "13_make_adrian_review_png_assets.R"), chdir = TRUE)

gauge_figure_script <- file.path(root_dir, "scripts", "archive", "pre_clean_spine_20260623", "17c_plot_rs_gauge_context.R")
if (file.exists(gauge_figure_script)) {
  source(gauge_figure_script, chdir = TRUE)
}
