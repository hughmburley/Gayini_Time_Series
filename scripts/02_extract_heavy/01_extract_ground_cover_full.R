# ------------------------------------------------------------------------------
# Script: scripts/02_extract_heavy/01_extract_ground_cover_full.R
# Purpose: Extract ground-cover time series.
# Workflow stage: 02_extract_heavy
# Run mode: heavy
# Heavy processing: yes
# Key inputs:
#   - Raster catalogue, plot vectors and fractional-cover rasters.
# Key outputs:
#   - Ground-cover extraction CSVs and processed tables.
# Notes:
#   - Heavy step; do not run casually and never from the smoke test.
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Load configuration and execute workflow step
# ------------------------------------------------------------------------------

## Purpose:
## Ground-cover extraction orchestrator.
##
## Landsat plot-scale extraction remains the core ground-cover output.
## MODIS fractional cover is optional broad context only: farm, buffers,
## management zones and optional paddocks, not 1 ha plot evidence.


root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", "D:/Github_repos/Gayini"), winslash = "/", mustWork = TRUE)


source(file.path(root_dir, "R", "gayini_helpers.R"))
source(file.path(root_dir, "R", "raster_catalog_functions.R"))
source(file.path(root_dir, "R", "fractional_cover_extraction_functions.R"))
source(file.path(root_dir, "R", "modis_ground_cover_functions.R"))


required_packages <- c(
  "sf",
  "terra",
  "exactextractr",
  "dplyr",
  "tidyr",
  "readr",
  "tibble",
  "stringr",
  "purrr",
  "lubridate",
  "magrittr",
  "ggplot2"
)


gayini_check_packages(required_packages)
library(magrittr)
gayini_make_dirs(root = root_dir)


## User settings ----


gayini_env_flag <- function(name, default = TRUE) {

  value <- Sys.getenv(name, unset = NA_character_)

  if (is.na(value) || value == "") {
    return(default)
  }

  tolower(value) %in% c("true", "t", "1", "yes", "y")

}


gayini_env_numeric <- function(name, default = Inf) {

  value <- Sys.getenv(name, unset = NA_character_)

  if (is.na(value) || value == "") {
    return(default)
  }

  if (tolower(value) %in% c("inf", "infinite", "all")) {
    return(Inf)
  }

  as.numeric(value)

}


gayini_env_choice <- function(name, default, allowed) {

  value <- Sys.getenv(name, unset = NA_character_)

  if (is.na(value) || value == "") {
    return(default)
  }

  value <- tolower(value)

  if (!value %in% allowed) {
    stop("Environment setting ", name, " must be one of: ", paste(allowed, collapse = ", "), call. = FALSE)
  }

  value

}


RUN_LANDSAT_GC <- gayini_env_flag("GAYINI_RUN_LANDSAT_GC", TRUE)
RUN_MODIS_GC   <- gayini_env_flag("GAYINI_RUN_MODIS_GC", TRUE)


MODIS_RUN_MODE <- gayini_env_choice("GAYINI_MODIS_RUN_MODE", "full", c("test", "full"))
MODIS_TEST_N   <- gayini_env_numeric("GAYINI_MODIS_TEST_N", 3)


OVERWRITE_MODIS_CACHE <- gayini_env_flag("GAYINI_MODIS_OVERWRITE_CACHE", FALSE)
WRITE_MODIS_MAPS      <- gayini_env_flag("GAYINI_WRITE_MODIS_MAPS", TRUE)
WRITE_MODIS_FIGURES   <- gayini_env_flag("GAYINI_WRITE_MODIS_FIGURES", TRUE)
WRITE_MODIS_PPT       <- gayini_env_flag("GAYINI_WRITE_MODIS_PPT", TRUE)


message("Ground-cover settings:")
message("  RUN_LANDSAT_GC: ", RUN_LANDSAT_GC)
message("  RUN_MODIS_GC: ", RUN_MODIS_GC)
message("  MODIS_RUN_MODE: ", MODIS_RUN_MODE)
message("  MODIS_TEST_N: ", MODIS_TEST_N)
message("  OVERWRITE_MODIS_CACHE: ", OVERWRITE_MODIS_CACHE)
message("  WRITE_MODIS_MAPS: ", WRITE_MODIS_MAPS)
message("  WRITE_MODIS_FIGURES: ", WRITE_MODIS_FIGURES)
message("  WRITE_MODIS_PPT: ", WRITE_MODIS_PPT)


## Landsat branch ----


gayini_run_landsat_ground_cover_full <- function(root = root_dir) {

  candidate_scripts <- c(
    file.path(root, "scripts", "04c_extract_fractional_cover_full.R"),
    file.path(root, "scripts", "02_extract_heavy", "internal", "03_extract_fractional_cover_full_impl.R")
  )

  landsat_script <- candidate_scripts[file.exists(candidate_scripts)][1]

  if (is.na(landsat_script)) {
    stop(
      "Could not find the Landsat full fractional-cover script. Checked: ",
      paste(candidate_scripts, collapse = "; "),
      call. = FALSE
    )
  }

  message("Running Landsat plot-scale ground-cover branch: ", landsat_script)
  source(landsat_script, chdir = TRUE)

}


if (isTRUE(RUN_LANDSAT_GC)) {
  gayini_run_landsat_ground_cover_full(root = root_dir)
} else {
  message("Skipping Landsat ground-cover branch because GAYINI_RUN_LANDSAT_GC is false.")
}


## MODIS context branch ----


if (isTRUE(RUN_MODIS_GC)) {
  message("Running MODIS broad-context ground-cover branch.")
  message("MODIS test_n: ", MODIS_TEST_N)

  gayini_run_modis_ground_cover_context(
    root = root_dir,
    crop_to_aoi = TRUE,
    overwrite_cache = OVERWRITE_MODIS_CACHE,
    run_mode = MODIS_RUN_MODE,
    test_n = MODIS_TEST_N,
    write_maps = WRITE_MODIS_MAPS,
    write_figures = WRITE_MODIS_FIGURES,
    write_ppt = WRITE_MODIS_PPT
  )
} else {
  message("Skipping MODIS ground-cover branch because GAYINI_RUN_MODIS_GC is false.")
}


message("Ground-cover extraction orchestrator complete.")
