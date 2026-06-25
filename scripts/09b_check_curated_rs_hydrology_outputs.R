## -----------------------------------------------------------------------------
## Gayini remote sensing workflow
## 09b_check_curated_rs_hydrology_outputs.R
## -----------------------------------------------------------------------------


## Purpose:
## Preferred active wrapper for curated RS/hydrology-output QA.


root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", "D:/Github_repos/Gayini"), winslash = "/", mustWork = TRUE)

# Archived implementation module; this file is the active workflow entry point.
source(file.path(root_dir, "scripts", "archive", "pre_clean_spine_20260623", "07z_check_curated_outputs.R"), chdir = TRUE)
