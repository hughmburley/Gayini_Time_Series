## -----------------------------------------------------------------------------
## Gayini remote sensing workflow
## 09_check_curated_outputs.R
## -----------------------------------------------------------------------------


## Purpose:
## Thin compatibility wrapper for the current curated-output QA script.


root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", "D:/Github_repos/Gayini"), winslash = "/", mustWork = TRUE)
source(file.path(root_dir, "scripts", "07z_check_curated_outputs.R"), chdir = TRUE)
