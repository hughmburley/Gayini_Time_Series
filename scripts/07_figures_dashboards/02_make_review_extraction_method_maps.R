## -----------------------------------------------------------------------------
## Gayini remote sensing workflow
## 02_make_review_extraction_method_maps.R
## -----------------------------------------------------------------------------


## Purpose:
## Preferred active wrapper for appendix/method map assets used in review
## outputs.


root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", "D:/Github_repos/Gayini"), winslash = "/", mustWork = TRUE)

# Archived implementation module; this file is the active workflow entry point.
source(file.path(root_dir, "scripts", "archive", "pre_clean_spine_20260623", "15_make_review_extraction_method_maps.R"), chdir = TRUE)
