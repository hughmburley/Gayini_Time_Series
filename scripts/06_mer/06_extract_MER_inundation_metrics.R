## -----------------------------------------------------------------------------
## Gayini remote sensing workflow
## 06_extract_MER_inundation_metrics.R
## -----------------------------------------------------------------------------


## Purpose:
## Preferred active driver for Flow_MER-inspired plot-level inundation metrics
## and compact deck-ready RS outputs.


root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", "D:/Github_repos/Gayini"), winslash = "/", mustWork = TRUE)

source(file.path(root_dir, "R", "gayini_mer_inundation_functions.R"))

run_gayini_mer_inundation(root_dir = root_dir)
write_gayini_mer_deck_outputs(root_dir = root_dir)
