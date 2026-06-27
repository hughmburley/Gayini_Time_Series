## -----------------------------------------------------------------------------
## Gayini remote sensing workflow
## 11_ground_cover_prepost_figures.R
## -----------------------------------------------------------------------------


## Purpose:
## Thin compatibility wrapper for the current ground-cover pre/post figure
## script. The current source logic still lives under scripts/obs/ after the
## cleanup pass; keep this wrapper until that logic is merged into this active
## script.


root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", "D:/Github_repos/Gayini"), winslash = "/", mustWork = TRUE)
source(file.path(root_dir, "scripts", "obs", "10b_ground_cover_prepost_figures.R"), chdir = TRUE)
