# ------------------------------------------------------------------------------
# Script: scripts/03_inundation_products/internal/01_build_pre_post_inundation_frequency_rasters_impl.R
# Purpose: Internal implementation module for 03_inundation_products: build
#          pre post inundation frequency rasters impl.
# Workflow stage: 03_inundation_products
# Run mode: lightweight_review
# Heavy processing: no
# Key inputs:
#   - Inputs are supplied by the active wrapper or existing workflow outputs.
# Key outputs:
#   - Outputs are written by the implementation module for its active wrapper.
# Notes:
#   - Internal module; run the wrapper script in the parent folder unless
#     debugging.
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Load configuration and execute workflow step
# ------------------------------------------------------------------------------
                                  ## 07e build pre-/post-conservation inundation-frequency rasters ----

## Purpose:
## Insert this script after 05c/06c and before the pre-/post-conservation
## vegetation-response analysis.
##
## This step creates annual binary inundation rasters from all available
## inundation sources, then summarises those annual rasters into:
##   1. pre-conservation inundation-frequency raster
##   2. post-conservation inundation-frequency raster
##   3. post-minus-pre difference raster
##   4. plot-level summaries using a one-pixel buffer
##
## Main question:
## Which 1 ha plots have similar inundation frequency after conservation
## management began, and which plots now look wetter or drier than their
## recent pre-conservation baseline?


## User settings ----

root_dir                      <- Sys.getenv("GAYINI_ROOT", "D:/Github_repos/Gayini")

PRE_START_DATE                <- as.Date("2013-07-01")
CONSERVATION_DATE             <- as.Date("2019-07-01")
POST_END_DATE                 <- as.Date("2026-06-30")
WATER_YEAR_START_MONTH        <- 7
MIN_VALID_YEARS_PRE           <- 2
MIN_VALID_YEARS_POST          <- 2
STOP_ON_LOGICAL_FAILURE       <- FALSE

REFERENCE_PRODUCT             <- "landsat_inundation"
BOUNDARY_BUFFER_M             <- 100
PLOT_BUFFER_PIXELS            <- 1

## strict_value_1 = count daily value 1 as inundated; value 2 / ORS water is not counted.
## include_ors_value_2 = count daily values 1 and 2 as inundated.
## Keep strict_value_1 as the primary ecological floodplain rule until Adrian says otherwise.
DAILY_WET_RULE                <- "strict_value_1"

PREFER_CLOUD3_DUPLICATES      <- TRUE
EXPLICIT_NODATA_VALUES        <- c(255, 65535, 127, -1)

WRITE_ANNUAL_RASTERS          <- TRUE
WRITE_DIAGNOSTIC_FIGURE       <- TRUE



source("R/gayini_temp_cleanup_functions.R")

terra_temp_dir <- gayini_setup_terra_temp(
  temp_dir = file.path("data_intermediate", "terra_tmp", "07e_prepost_inundation")
)

on.exit(
  gayini_cleanup_terra_temp(temp_dir = terra_temp_dir),
  add = TRUE
)


## Required packages ----

required_packages <- c(
  "sf",
  "terra",
  "exactextractr",
  "dplyr",
  "tidyr",
  "tibble",
  "readr",
  "stringr",
  "purrr",
  "lubridate",
  "ggplot2"
)

missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]

if (length(missing_packages) > 0) {
  stop("Missing required packages: ", paste(missing_packages, collapse = ", "), call. = FALSE)
}

message("All required packages are available.")


## Load packages ----

library(sf)
library(terra)
library(exactextractr)
library(dplyr)
library(tidyr)
library(readr)
library(stringr)
library(purrr)
library(lubridate)
library(ggplot2)


## Source functions ----

source(file.path(root_dir, "R", "inundation_pre_post_raster_functions.R"))
source(file.path(root_dir, "R", "gayini_inundation_wet_rule.R"))  # wet rule extracted (B6)


## Input paths ----

raster_catalog_path <- file.path(root_dir, "data_intermediate", "raster_catalog", "raster_catalog.csv")
plots_clean_path    <- file.path(root_dir, "data_intermediate", "spatial", "plots_clean.gpkg")
boundary_path       <- file.path(root_dir, "data_intermediate", "spatial", "boundary_clean.gpkg")


## Output folders ----

raster_dir          <- file.path(root_dir, "Output", "rasters", "inundation_pre_post")
annual_raster_dir   <- file.path(raster_dir, "annual")
csv_dir             <- file.path(root_dir, "Output", "csv")
diagnostics_dir     <- file.path(root_dir, "Output", "diagnostics")
figures_dir         <- file.path(root_dir, "Output", "figures")
processed_dir       <- file.path(root_dir, "data_processed")

purrr::walk(
  c(raster_dir, annual_raster_dir, csv_dir, diagnostics_dir, figures_dir, processed_dir),
  ~dir.create(.x, recursive = TRUE, showWarnings = FALSE)
)


## Output paths ----

selected_catalog_path       <- file.path(diagnostics_dir, "07e_pre_post_inundation_selected_rasters.csv")
annual_summary_path         <- file.path(diagnostics_dir, "07e_pre_post_inundation_period_year_summary.csv")
observation_density_path     <- file.path(diagnostics_dir, "07e_pre_post_inundation_observation_density_by_year.csv")
checks_path                 <- file.path(diagnostics_dir, "07e_pre_post_inundation_checks.csv")
logical_checks_path         <- file.path(diagnostics_dir, "07e_pre_post_inundation_logical_checks.csv")
period_value_summary_path   <- file.path(diagnostics_dir, "07e_pre_post_inundation_period_raster_value_summary.csv")
variable_lookup_path        <- file.path(diagnostics_dir, "07e_pre_post_inundation_variable_lookup.csv")
plot_summary_path           <- file.path(csv_dir, "07e_pre_post_inundation_plot_summary.csv")
processed_plot_summary_path <- file.path(processed_dir, "plot_pre_post_inundation_frequency.csv")
figure_path                 <- file.path(figures_dir, "07e_pre_post_inundation_frequency_maps.png")

pre_raster_path             <- file.path(raster_dir, "pre_conservation_inundation_frequency_pct.tif")
post_raster_path            <- file.path(raster_dir, "post_conservation_inundation_frequency_pct.tif")
diff_raster_path            <- file.path(raster_dir, "post_minus_pre_inundation_frequency_pct_points.tif")


## Read inputs ----

if (!file.exists(raster_catalog_path)) {
  stop("Missing raster catalogue: ", raster_catalog_path, call. = FALSE)
}

if (!file.exists(plots_clean_path)) {
  stop("Missing clean plots file: ", plots_clean_path, call. = FALSE)
}

if (!file.exists(boundary_path)) {
  stop("Missing clean boundary file: ", boundary_path, call. = FALSE)
}

raster_catalog <- readr::read_csv(raster_catalog_path, show_col_types = FALSE)
plots_clean    <- sf::st_read(plots_clean_path, quiet = TRUE)
boundary_clean <- sf::st_read(boundary_path, quiet = TRUE)

message("Raster catalogue rows: ", nrow(raster_catalog))
message("Clean plots: ", nrow(plots_clean))


## Standardise and filter inundation catalogue ----

inundation_catalog <- gayini_standardise_combined_inundation_catalog(
  raster_catalog              = raster_catalog,
  root                        = root_dir,
  start_date                  = PRE_START_DATE,
  end_date                    = POST_END_DATE,
  conservation_date           = CONSERVATION_DATE,
  water_year_start_month      = WATER_YEAR_START_MONTH,
  prefer_cloud3_duplicates    = PREFER_CLOUD3_DUPLICATES
)

if (nrow(inundation_catalog) == 0) {
  stop("No inundation rasters selected for pre/post analysis.", call. = FALSE)
}

readr::write_csv(inundation_catalog, selected_catalog_path)
message("Wrote: ", selected_catalog_path)

period_year_summary <- inundation_catalog |>
  dplyr::count(
    .data$period,
    .data$analysis_year,
    .data$analysis_year_start,
    .data$analysis_year_end,
    .data$period_year,
    .data$product,
    .data$sensor_clean,
    name = "rasters"
  ) |>
  dplyr::arrange(.data$period, .data$analysis_year, .data$product, .data$sensor_clean)

readr::write_csv(period_year_summary, annual_summary_path)
message("Wrote: ", annual_summary_path)

observation_density_by_year <- gayini_summarise_inundation_observation_density(inundation_catalog)

readr::write_csv(observation_density_by_year, observation_density_path)
message("Wrote: ", observation_density_path)

low_density_years <- observation_density_by_year |>
  dplyr::filter(.data$observation_density_class %in% c("single_raster", "very_low_density"))

if (nrow(low_density_years) > 0) {
  warning(
    "Some water years have low inundation-observation density. See: ",
    observation_density_path,
    call. = FALSE
  )
}


## Create common reference grid ----

reference_grid <- gayini_make_reference_grid(
  inundation_catalog    = inundation_catalog,
  boundary_sf           = boundary_clean,
  reference_preference  = REFERENCE_PRODUCT,
  boundary_buffer_m     = BOUNDARY_BUFFER_M
)

message("Reference grid resolution: ", paste(terra::res(reference_grid), collapse = " x "))
message("Reference grid CRS: ", terra::crs(reference_grid, describe = TRUE)$name)


## Build annual binary rasters ----

period_year_lookup <- inundation_catalog |>
  dplyr::distinct(.data$period, .data$analysis_year, .data$analysis_year_start, .data$analysis_year_end, .data$period_year) |>
  dplyr::arrange(.data$period, .data$analysis_year)

annual_outputs <- list()

for (this_period_year in period_year_lookup$period_year) {
  message("Building annual inundation raster: ", this_period_year)

  this_catalog <- inundation_catalog |>
    dplyr::filter(.data$period_year == this_period_year)

  annual_outputs[[this_period_year]] <- gayini_build_one_period_year_rasters(
    period_year_catalog  = this_catalog,
    reference_grid       = reference_grid,
    daily_wet_rule       = DAILY_WET_RULE,
    nodata_values        = EXPLICIT_NODATA_VALUES,
    output_dir           = if (WRITE_ANNUAL_RASTERS) annual_raster_dir else NULL
  )
}


## Build pre and post period rasters ----

pre_period <- gayini_build_period_frequency_rasters(
  annual_outputs = annual_outputs,
  period_lookup  = period_year_lookup,
  period         = "pre_conservation",
  output_dir     = raster_dir
)

post_period <- gayini_build_period_frequency_rasters(
  annual_outputs = annual_outputs,
  period_lookup  = period_year_lookup,
  period         = "post_conservation",
  output_dir     = raster_dir
)

inundation_diff <- post_period$inundation_frequency_pct - pre_period$inundation_frequency_pct
names(inundation_diff) <- "post_minus_pre_inundation_frequency_pct_points"

terra::writeRaster(
  inundation_diff,
  filename = diff_raster_path,
  overwrite = TRUE,
  gdal = c("COMPRESS=LZW")
)

message("Wrote: ", pre_raster_path)
message("Wrote: ", post_raster_path)
message("Wrote: ", diff_raster_path)


## Extract period rasters to plots using one-pixel buffer ----

period_stack <- c(
  pre_period$inundation_frequency_pct,
  post_period$inundation_frequency_pct,
  inundation_diff,
  pre_period$valid_year_count,
  post_period$valid_year_count
)

period_stack_names <- c(
  "pre_conservation_inundation_frequency_pct",
  "post_conservation_inundation_frequency_pct",
  "post_minus_pre_inundation_frequency_pct_points",
  "pre_conservation_valid_year_count",
  "post_conservation_valid_year_count"
)

names(period_stack) <- period_stack_names

period_value_summary <- gayini_summarise_named_rasters(period_stack)
readr::write_csv(period_value_summary, period_value_summary_path)
message("Wrote: ", period_value_summary_path)

gayini_write_variable_lookup(variable_lookup_path)
message("Wrote: ", variable_lookup_path)

plot_summary <- gayini_extract_period_rasters_to_plots(
  period_rasters   = period_stack,
  plots_sf         = plots_clean,
  buffer_pixels    = PLOT_BUFFER_PIXELS,
  summary_method   = "mean",
  allow_terra_fallback = TRUE,
  stop_if_all_na = TRUE
) |>
  gayini_add_period_metadata_to_plot_summary(
    period_year_lookup = period_year_lookup,
    conservation_date = CONSERVATION_DATE,
    pre_start_date = PRE_START_DATE,
    post_end_date = POST_END_DATE,
    daily_wet_rule = DAILY_WET_RULE,
    reference_product = REFERENCE_PRODUCT
  )

readr::write_csv(plot_summary, plot_summary_path)
readr::write_csv(plot_summary, processed_plot_summary_path)

message("Wrote: ", plot_summary_path)
message("Wrote: ", processed_plot_summary_path)


## Checks ----

checks <- tibble::tibble(
  check = c(
    "selected_rasters",
    "period_years",
    "density_summary_rows",
    "low_density_years",
    "pre_period_years",
    "post_period_years",
    "plots_extracted",
    "reference_resolution_x",
    "reference_resolution_y",
    "plot_buffer_pixels",
    "daily_wet_rule",
    "water_year_start_month",
    "conservation_date",
    "pre_start_date",
    "post_end_date"
  ),
  value = c(
    as.character(nrow(inundation_catalog)),
    as.character(nrow(period_year_lookup)),
    as.character(nrow(observation_density_by_year)),
    as.character(nrow(low_density_years)),
    as.character(sum(period_year_lookup$period == "pre_conservation")),
    as.character(sum(period_year_lookup$period == "post_conservation")),
    as.character(nrow(plot_summary)),
    as.character(terra::res(reference_grid)[[1]]),
    as.character(terra::res(reference_grid)[[2]]),
    as.character(PLOT_BUFFER_PIXELS),
    DAILY_WET_RULE,
    as.character(WATER_YEAR_START_MONTH),
    as.character(CONSERVATION_DATE),
    as.character(PRE_START_DATE),
    as.character(POST_END_DATE)
  )
)

readr::write_csv(checks, checks_path)
message("Wrote: ", checks_path)


## Logical QA checks ----

logical_checks <- gayini_check_prepost_inundation_outputs(
  inundation_catalog    = inundation_catalog,
  period_year_lookup    = period_year_lookup,
  observation_density   = observation_density_by_year,
  pre_period            = pre_period,
  post_period           = post_period,
  inundation_diff       = inundation_diff,
  plot_summary          = plot_summary,
  plots_clean           = plots_clean,
  min_valid_years_pre   = MIN_VALID_YEARS_PRE,
  min_valid_years_post  = MIN_VALID_YEARS_POST
)

readr::write_csv(logical_checks, logical_checks_path)
message("Wrote: ", logical_checks_path)

failed_stop_checks <- logical_checks |>
  dplyr::filter(.data$status == "CHECK", .data$severity == "stop_if_fail")

failed_review_checks <- logical_checks |>
  dplyr::filter(.data$status == "CHECK", .data$severity != "stop_if_fail")

if (nrow(failed_stop_checks) > 0) {
  stop_message <- paste(
    failed_stop_checks$check,
    failed_stop_checks$detail,
    sep = ": ",
    collapse = "; "
  )

  if (isTRUE(STOP_ON_LOGICAL_FAILURE)) {
    stop(
      "Pre/post inundation logical checks failed: ",
      stop_message,
      ". See: ", logical_checks_path,
      call. = FALSE
    )
  } else {
    warning(
      "Pre/post inundation logical checks failed and need review: ",
      stop_message,
      ". See: ", logical_checks_path,
      call. = FALSE
    )
  }
}

if (nrow(failed_review_checks) > 0) {
  warning(
    "Some pre/post inundation review checks need attention. See: ",
    logical_checks_path,
    call. = FALSE
  )
}


## Diagnostic raster map ----

if (WRITE_DIAGNOSTIC_FIGURE) {
  png(filename = figure_path, width = 3600, height = 1400, res = 200)
  par(mfrow = c(1, 3), mar = c(3, 3, 3, 5))
  terra::plot(pre_period$inundation_frequency_pct, main = "Pre-conservation\ninundation frequency (%)")
  terra::plot(post_period$inundation_frequency_pct, main = "Post-conservation\ninundation frequency (%)")
  terra::plot(inundation_diff, main = "Post - pre\npercentage points")
  dev.off()

  message("Wrote: ", figure_path)
}


## Final console summary ----

message("07e complete.")
message("Primary interpretation raster: ", diff_raster_path)
message("Primary plot-level table: ", processed_plot_summary_path)
