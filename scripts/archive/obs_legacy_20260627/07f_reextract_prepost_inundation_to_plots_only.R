## 07f re-extract pre/post inundation rasters to plots only ----
##
## Purpose:
##   Use this after 07e has successfully built the period rasters, but the
##   plot-level extraction table needs to be regenerated or checked.
##
##   This avoids rebuilding annual rasters.

root_dir <- Sys.getenv("GAYINI_ROOT", "D:/Github_repos/Gayini")

PLOT_BUFFER_PIXELS <- 1
MIN_VALID_YEARS_PRE <- 2
MIN_VALID_YEARS_POST <- 2
DAILY_WET_RULE <- "strict_value_1"
REFERENCE_PRODUCT <- "landsat_inundation"
CONSERVATION_DATE <- as.Date("2019-07-01")
PRE_START_DATE <- as.Date("2013-07-01")
POST_END_DATE <- as.Date("2026-06-30")

required_packages <- c(
  "sf",
  "terra",
  "exactextractr",
  "dplyr",
  "tidyr",
  "tibble",
  "readr",
  "stringr"
)

missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]

if (length(missing_packages) > 0) {
  stop("Missing required packages: ", paste(missing_packages, collapse = ", "), call. = FALSE)
}

library(sf)
library(terra)
library(exactextractr)
library(dplyr)
library(tidyr)
library(readr)
library(stringr)

source(file.path(root_dir, "R", "inundation_pre_post_raster_functions.R"))

plots_clean_path <- file.path(root_dir, "data_intermediate", "spatial", "plots_clean.gpkg")

raster_dir <- file.path(root_dir, "Output", "rasters", "inundation_pre_post")
csv_dir <- file.path(root_dir, "Output", "csv")
diagnostics_dir <- file.path(root_dir, "Output", "diagnostics")
processed_dir <- file.path(root_dir, "data_processed")

dir.create(csv_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(diagnostics_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(processed_dir, recursive = TRUE, showWarnings = FALSE)

pre_raster_path <- file.path(raster_dir, "pre_conservation_inundation_frequency_pct.tif")
post_raster_path <- file.path(raster_dir, "post_conservation_inundation_frequency_pct.tif")
diff_raster_path <- file.path(raster_dir, "post_minus_pre_inundation_frequency_pct_points.tif")
pre_valid_path <- file.path(raster_dir, "pre_conservation_valid_year_count.tif")
post_valid_path <- file.path(raster_dir, "post_conservation_valid_year_count.tif")

required_files <- c(
  plots_clean_path,
  pre_raster_path,
  post_raster_path,
  diff_raster_path,
  pre_valid_path,
  post_valid_path
)

missing_files <- required_files[!file.exists(required_files)]

if (length(missing_files) > 0) {
  stop("Missing required files: ", paste(missing_files, collapse = "; "), call. = FALSE)
}

plots_clean <- sf::st_read(plots_clean_path, quiet = TRUE)

period_raster_paths <- c(
  pre_raster_path,
  post_raster_path,
  diff_raster_path,
  pre_valid_path,
  post_valid_path
)

period_stack <- terra::rast(period_raster_paths)

if (!terra::hasValues(period_stack)) {
  stop(
    "Period raster stack has no readable cell values immediately after terra::rast(period_raster_paths). ",
    "Check that the TIFF files are complete, not locked by another process, and readable by terra.",
    call. = FALSE
  )
}

names(period_stack) <- c(
  "pre_conservation_inundation_frequency_pct",
  "post_conservation_inundation_frequency_pct",
  "post_minus_pre_inundation_frequency_pct_points",
  "pre_conservation_valid_year_count",
  "post_conservation_valid_year_count"
)

period_value_summary <- gayini_summarise_named_rasters(period_stack)

period_value_summary_path <- file.path(
  diagnostics_dir,
  "07f_pre_post_inundation_period_raster_value_summary.csv"
)

readr::write_csv(period_value_summary, period_value_summary_path)
message("Wrote: ", period_value_summary_path)

if (any(period_value_summary$non_na_cells == 0 | is.na(period_value_summary$non_na_cells))) {
  stop(
    "One or more period rasters have zero non-NA cells. ",
    "Inspect: ", period_value_summary_path,
    call. = FALSE
  )
}

plot_spatial_checks <- gayini_plot_raster_spatial_checks(
  period_rasters = period_stack,
  plots_sf       = plots_clean,
  buffer_pixels  = PLOT_BUFFER_PIXELS
)

plot_spatial_checks_path <- file.path(
  diagnostics_dir,
  "07f_pre_post_inundation_plot_extraction_spatial_checks.csv"
)

plot_centroid_checks_path <- file.path(
  diagnostics_dir,
  "07f_pre_post_inundation_plot_extraction_centroid_checks.csv"
)

readr::write_csv(plot_spatial_checks$spatial_summary, plot_spatial_checks_path)
readr::write_csv(plot_spatial_checks$centroid_non_na, plot_centroid_checks_path)

message("Wrote: ", plot_spatial_checks_path)
message("Wrote: ", plot_centroid_checks_path)

plot_summary <- gayini_extract_period_rasters_to_plots(
  period_rasters        = period_stack,
  plots_sf              = plots_clean,
  buffer_pixels         = PLOT_BUFFER_PIXELS,
  summary_method        = "mean",
  allow_terra_fallback  = TRUE,
  stop_if_all_na        = TRUE
) |>
  dplyr::mutate(
    vegetation_adrian_group = dplyr::case_when(
      .data$vegetation %in% c("Inland Floodplain Shrublands", "Inland Floodplain Swamps") ~ "Inland Floodplain Shrublands / Swamps",
      TRUE ~ .data$vegetation
    ),
    inundation_change_class = dplyr::case_when(
      is.na(.data$post_minus_pre_inundation_frequency_pct_points) ~ "no_comparison",
      .data$post_minus_pre_inundation_frequency_pct_points >= 20 ~ "much_wetter_post",
      .data$post_minus_pre_inundation_frequency_pct_points >= 5 ~ "wetter_post",
      .data$post_minus_pre_inundation_frequency_pct_points <= -20 ~ "much_drier_post",
      .data$post_minus_pre_inundation_frequency_pct_points <= -5 ~ "drier_post",
      TRUE ~ "similar_frequency"
    ),
    conservation_date = CONSERVATION_DATE,
    pre_start_date = PRE_START_DATE,
    post_end_date = POST_END_DATE,
    daily_wet_rule = DAILY_WET_RULE,
    reference_product = REFERENCE_PRODUCT
  )

fixed_plot_summary_path <- file.path(csv_dir, "07f_pre_post_inundation_plot_summary_fixed.csv")
fixed_processed_path <- file.path(processed_dir, "plot_pre_post_inundation_frequency_fixed.csv")

readr::write_csv(plot_summary, fixed_plot_summary_path)
readr::write_csv(plot_summary, fixed_processed_path)

message("Wrote: ", fixed_plot_summary_path)
message("Wrote: ", fixed_processed_path)

plot_checks <- tibble::tibble(
  check = c(
    "plot_rows",
    "pre_values_non_na",
    "post_values_non_na",
    "diff_values_non_na",
    "pre_valid_year_values_non_na",
    "post_valid_year_values_non_na",
    "change_classes"
  ),
  value = c(
    as.character(nrow(plot_summary)),
    as.character(sum(!is.na(plot_summary$pre_conservation_inundation_frequency_pct))),
    as.character(sum(!is.na(plot_summary$post_conservation_inundation_frequency_pct))),
    as.character(sum(!is.na(plot_summary$post_minus_pre_inundation_frequency_pct_points))),
    as.character(sum(!is.na(plot_summary$pre_conservation_valid_year_count))),
    as.character(sum(!is.na(plot_summary$post_conservation_valid_year_count))),
    paste(names(table(plot_summary$inundation_change_class)), table(plot_summary$inundation_change_class), collapse = "; ")
  )
)

plot_checks_path <- file.path(diagnostics_dir, "07f_pre_post_inundation_plot_extraction_checks.csv")
readr::write_csv(plot_checks, plot_checks_path)
message("Wrote: ", plot_checks_path)

message("07f plot re-extraction complete.")
