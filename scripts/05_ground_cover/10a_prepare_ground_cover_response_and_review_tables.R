## -----------------------------------------------------------------------------
## Gayini remote sensing workflow
## 10a_prepare_ground_cover_response_and_review_tables.R
## -----------------------------------------------------------------------------


## Purpose:
## Preferred active wrapper for downstream ground-cover response summaries and
## review tables. Stable output filenames are retained by the source script.


root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", "D:/Github_repos/Gayini"), winslash = "/", mustWork = TRUE)
source(file.path(root_dir, "scripts", "obs", "10a_ground_cover_prepost_response.R"), chdir = TRUE)

