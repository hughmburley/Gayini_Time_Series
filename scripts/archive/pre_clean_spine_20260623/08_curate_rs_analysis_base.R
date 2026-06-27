## -----------------------------------------------------------------------------
## Gayini remote sensing workflow
## 08_curate_rs_analysis_base.R
## -----------------------------------------------------------------------------


## Purpose:
## Thin compatibility wrapper for the current curated analysis-base script.


root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", "D:/Github_repos/Gayini"), winslash = "/", mustWork = TRUE)
source(file.path(root_dir, "scripts", "07_curate_rs_analysis_base.R"), chdir = TRUE)
