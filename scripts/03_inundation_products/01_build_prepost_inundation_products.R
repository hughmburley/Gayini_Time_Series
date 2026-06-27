## -----------------------------------------------------------------------------
## Gayini remote sensing workflow
## 01_build_prepost_inundation_products.R
## -----------------------------------------------------------------------------


## Purpose:
## Preferred active wrapper for building pre/post inundation products. This is an
## expensive raster-processing step; run only when raster products need to be
## regenerated.


root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", "D:/Github_repos/Gayini"), winslash = "/", mustWork = TRUE)
source(file.path(root_dir, "scripts", "archive", "obs_legacy_20260627", "07e_build_pre_post_inundation_frequency_rasters.R"), chdir = TRUE)
