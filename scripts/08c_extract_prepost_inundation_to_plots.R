## -----------------------------------------------------------------------------
## Gayini remote sensing workflow
## 08c_extract_prepost_inundation_to_plots.R
## -----------------------------------------------------------------------------


## Purpose:
## Preferred active wrapper for extracting pre/post inundation products to plots.
## Stable output filenames are retained by the source script.


root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", "D:/Github_repos/Gayini"), winslash = "/", mustWork = TRUE)
source(file.path(root_dir, "scripts", "obs", "07f_reextract_prepost_inundation_to_plots_only.R"), chdir = TRUE)

