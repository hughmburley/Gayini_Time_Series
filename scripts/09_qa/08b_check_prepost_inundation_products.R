## -----------------------------------------------------------------------------
## Gayini remote sensing workflow
## 08b_check_prepost_inundation_products.R
## -----------------------------------------------------------------------------


## Purpose:
## Preferred active wrapper for read-only QA of existing pre/post inundation
## products. This does not rebuild rasters.


root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", "D:/Github_repos/Gayini"), winslash = "/", mustWork = TRUE)

# Archived implementation module; this file is the active workflow entry point.
source(file.path(root_dir, "scripts", "archive", "pre_clean_spine_20260623", "06z_check_prepost_inundation_raster_outputs.R"), chdir = TRUE)
