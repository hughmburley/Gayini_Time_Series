####################################################################################################


## GAYINI REMOTE SENSING PROJECT


## Run script 02: catalogue raster files before any extraction or change detection.


####################################################################################################


## Purpose:
## Create a small, date-spread development subset of rasters for extraction tests.


## This script does not extract raster values.


## It only selects test rasters from the clean raster catalogue created by:
## scripts/02_catalog_rasters.R


## The development subset lets us test extraction code safely before using all rasters.


## Setup ----


root_dir <- normalizePath("D:/Github_repos/Gayini", winslash = "/", mustWork = TRUE)


source(file.path(root_dir, "R", "gayini_helpers.R"))
source(file.path(root_dir, "R", "raster_subset_functions.R"))


required_packages <- c(
  "dplyr",
  "readr",
  "stringr",
  "tibble"
)


gayini_check_packages(required_packages)


## User settings ----


N_PER_GROUP <- 10


INCLUDE_PRODUCTS <- c(
  "landsat_fractional_cover",
  "landsat_inundation",
  "sentinel2_inundation",
  "modis_fractional_cover",
  "aerial_or_ads_imagery"
)


GROUP_DAILY_INUNDATION_BY_SENSOR <- TRUE


INCLUDE_ADS_IN_DEV_SUBSET <- TRUE


## Decision settings for later extraction scripts ----


## These settings are written to config/extraction_settings.csv for transparency.


## They are not used for extraction in this script.


## Main decision:
## Use the true plot boundary for the primary extraction, with no buffer.


## Rationale:
## The 1 ha plots are the experimental/monitoring units. Buffering by one pixel would
## deliberately include neighbouring land and may mix treatments or vegetation classes.


## Later sensitivity option:
## A one-pixel buffer can be tested later as a context/edge sensitivity analysis.


EDGE_BUFFER_PIXELS        <- 0
SENSITIVITY_BUFFER_PIXELS <- 1


## Main decision:
## For continuous fractional-cover rasters, the primary summary should be an
## area/coverage-weighted mean. The method name should be carried into outputs.


CONTINUOUS_SUMMARY_METHOD   <- "weighted_mean"
CONTINUOUS_SECONDARY_METHOD <- "weighted_median"


## Main decision:
## For categorical inundation rasters, the primary summary should preserve class
## area proportions. Majority class is useful for QA, but not as the only output.


CATEGORICAL_SUMMARY_METHOD   <- "coverage_fraction"
CATEGORICAL_SECONDARY_METHOD <- "majority_class"


## Paths ----


raster_catalog_path <- file.path(
  root_dir,
  "data_intermediate",
  "raster_catalog",
  "raster_catalog.csv"
)


dev_subset_path <- file.path(
  root_dir,
  "data_intermediate",
  "raster_catalog",
  "raster_dev_subset.csv"
)


dev_subset_summary_path <- file.path(
  root_dir,
  "Output",
  "csv",
  "raster_dev_subset_summary.csv"
)


dev_subset_checks_path <- file.path(
  root_dir,
  "Output",
  "diagnostics",
  "raster_dev_subset_checks.csv"
)


extraction_settings_path <- file.path(
  root_dir,
  "config",
  "extraction_settings.csv"
)


## Folder checks ----


dir.create(dirname(dev_subset_path), recursive = TRUE, showWarnings = FALSE)
dir.create(dirname(dev_subset_summary_path), recursive = TRUE, showWarnings = FALSE)
dir.create(dirname(dev_subset_checks_path), recursive = TRUE, showWarnings = FALSE)
dir.create(dirname(extraction_settings_path), recursive = TRUE, showWarnings = FALSE)


## Input checks ----


if (!file.exists(raster_catalog_path)) {
  stop(
    "Missing raster catalogue: ",
    raster_catalog_path,
    "\nPlease run scripts/02_catalog_rasters.R first.",
    call. = FALSE
  )
}


## Read raster catalogue ----


raster_catalog <- readr::read_csv(
  raster_catalog_path,
  show_col_types = FALSE
)


message("Raster catalogue rows: ", nrow(raster_catalog))


## Create development subset ----


dev_subset <- gayini_make_raster_dev_subset(
  raster_catalog                       = raster_catalog,
  include_products                     = INCLUDE_PRODUCTS,
  n_per_group                          = N_PER_GROUP,
  group_daily_inundation_by_sensor     = GROUP_DAILY_INUNDATION_BY_SENSOR,
  include_ads                          = INCLUDE_ADS_IN_DEV_SUBSET
)


## Summarise and check the development subset ----


dev_subset_summary <- gayini_summarise_raster_dev_subset(dev_subset)


dev_subset_checks <- gayini_check_raster_dev_subset(
  dev_subset   = dev_subset,
  n_per_group  = N_PER_GROUP
)


## Write extraction decision settings for later scripts ----


extraction_settings <- gayini_make_extraction_decision_table(
  edge_buffer_pixels           = EDGE_BUFFER_PIXELS,
  sensitivity_buffer_pixels    = SENSITIVITY_BUFFER_PIXELS,
  continuous_summary_method    = CONTINUOUS_SUMMARY_METHOD,
  continuous_secondary_method  = CONTINUOUS_SECONDARY_METHOD,
  categorical_summary_method   = CATEGORICAL_SUMMARY_METHOD,
  categorical_secondary_method = CATEGORICAL_SECONDARY_METHOD
)


## Write outputs ----


readr::write_csv(dev_subset, dev_subset_path)
readr::write_csv(dev_subset_summary, dev_subset_summary_path)
readr::write_csv(dev_subset_checks, dev_subset_checks_path)
readr::write_csv(extraction_settings, extraction_settings_path)


message("Wrote: ", dev_subset_path)
message("Wrote: ", dev_subset_summary_path)
message("Wrote: ", dev_subset_checks_path)
message("Wrote: ", extraction_settings_path)


## Stop if any checks failed ----


failed_checks <- dev_subset_checks |>
  dplyr::filter(status == "fail")


if (nrow(failed_checks) > 0) {
  stop(
    "Development-subset checks failed. Review: ",
    dev_subset_checks_path,
    call. = FALSE
  )
}


## Final messages ----


message("Development subset complete.")
message("Development subset rows: ", nrow(dev_subset))
message("Do not run extraction until raster_dev_subset.csv and extraction_settings.csv have been checked.")



####################################################################################################
############################################ TBC ###################################################
####################################################################################################
