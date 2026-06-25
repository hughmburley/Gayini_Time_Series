## -----------------------------------------------------------------------------
## Gayini remote sensing workflow
## 09a_curate_rs_hydrology_analysis_base.R
## -----------------------------------------------------------------------------


## Purpose:
## Preferred active entry point for the canonical RS curation stage. Optional
## RS/gauge context joins run only when imported gauge summaries are available.


root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", "D:/Github_repos/Gayini"), winslash = "/", mustWork = TRUE)

# Archived implementation modules; this file is the active workflow entry point.
source(file.path(root_dir, "scripts", "archive", "pre_clean_spine_20260623", "07_curate_rs_analysis_base.R"), chdir = FALSE)

gauge_context_inputs <- file.path(root_dir, c(
  "data_intermediate/hydrology/gayini_gauge_monthly_imported.csv",
  "data_intermediate/hydrology/gayini_gauge_water_year_imported.csv"
))

if (all(file.exists(gauge_context_inputs))) {
  source(file.path(root_dir, "scripts", "archive", "pre_clean_spine_20260623", "17b_join_rs_and_gauge_timeseries.R"), chdir = FALSE)
} else {
  message("Optional gauge context inputs not found; skipping RS/gauge context joins.")
}
