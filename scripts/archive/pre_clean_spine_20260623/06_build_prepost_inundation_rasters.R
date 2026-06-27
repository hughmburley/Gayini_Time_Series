## -----------------------------------------------------------------------------
## Gayini remote sensing workflow
## 06_build_prepost_inundation_rasters.R
## -----------------------------------------------------------------------------


## Purpose:
## Thin compatibility wrapper for the current pre/post inundation raster build.
## This wrapper does not alter the scientific logic in the source script. The
## current source logic still lives under scripts/obs/ after the cleanup pass;
## keep this wrapper until that logic is merged into this active script.


root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", "D:/Github_repos/Gayini"), winslash = "/", mustWork = TRUE)
source(file.path(root_dir, "scripts", "obs", "07e_build_pre_post_inundation_frequency_rasters.R"), chdir = TRUE)
