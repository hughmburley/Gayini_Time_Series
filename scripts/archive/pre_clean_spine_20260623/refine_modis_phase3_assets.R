## -----------------------------------------------------------------------------
## Gayini MODIS Phase 3 communication refinement assets
## -----------------------------------------------------------------------------


## Purpose:
## Build refined MODIS maps, figures, representative-month diagnostics and asset
## manifest for the MODIS companion deck and selected main-deck slides.
##
## This script reads existing Phase 2 outputs. It does not rerun MODIS extraction
## and does not create plot-level MODIS statistics.


root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", "D:/Github_repos/Gayini"), winslash = "/", mustWork = TRUE)


source(file.path(root_dir, "R", "gayini_helpers.R"))
source(file.path(root_dir, "R", "raster_catalog_functions.R"))
source(file.path(root_dir, "R", "fractional_cover_extraction_functions.R"))
source(file.path(root_dir, "R", "modis_ground_cover_functions.R"))


required_packages <- c(
  "sf",
  "terra",
  "dplyr",
  "tidyr",
  "readr",
  "tibble",
  "magrittr",
  "ggplot2"
)


gayini_check_packages(required_packages)
library(magrittr)


gayini_run_modis_phase3_asset_refinement(root = root_dir)


message("Expected review outputs:")
message("  Output/diagnostics/modis_ground_cover/modis_representative_month_selection.csv")
message("  Output/diagnostics/modis_ground_cover/modis_selected_management_zone_register.csv")
message("  Output/diagnostics/modis_ground_cover/modis_phase3_asset_manifest.csv")
message("  Output/maps/modis_ground_cover/*_refined.png")
message("  Output/figures/modis_ground_cover/*_refined.png and anomaly figures")
