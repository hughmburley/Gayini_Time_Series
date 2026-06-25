## -----------------------------------------------------------------------------
## Gayini remote sensing workflow
## 04_extract_annual_inundation_full.R
## -----------------------------------------------------------------------------


## Purpose:
## Thin compatibility wrapper for the current full annual inundation extraction
## script. The current source logic still lives under scripts/obs/ after the
## cleanup pass; keep this wrapper until that logic is merged into this active
## script.


root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", "D:/Github_repos/Gayini"), winslash = "/", mustWork = TRUE)
source(file.path(root_dir, "scripts", "obs", "05c_extract_landsat_inundation_full.R"), chdir = TRUE)
