## -----------------------------------------------------------------------------
## Gayini remote sensing workflow
## 04_extract_annual_inundation_full.R
## -----------------------------------------------------------------------------


## Purpose:
## Thin compatibility wrapper for the current full annual inundation extraction
## script. The current source logic is tracked under scripts/02_extract_heavy/
## internal/ for reproducibility; keep this wrapper until that logic is merged
## into this active script.


root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", "D:/Github_repos/Gayini"), winslash = "/", mustWork = TRUE)
source(file.path(root_dir, "scripts", "02_extract_heavy", "internal", "05c_extract_landsat_inundation_full.R"), chdir = TRUE)
