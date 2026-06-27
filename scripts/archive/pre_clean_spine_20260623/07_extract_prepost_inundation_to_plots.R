## -----------------------------------------------------------------------------
## Gayini remote sensing workflow
## 07_extract_prepost_inundation_to_plots.R
## -----------------------------------------------------------------------------


## Purpose:
## Thin compatibility wrapper for the current fixed pre/post plot extraction.
## The current source logic still lives under scripts/obs/ after the cleanup
## pass; keep this wrapper until that logic is merged into this active script.


root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", "D:/Github_repos/Gayini"), winslash = "/", mustWork = TRUE)
source(file.path(root_dir, "scripts", "obs", "07f_reextract_prepost_inundation_to_plots_only.R"), chdir = TRUE)
