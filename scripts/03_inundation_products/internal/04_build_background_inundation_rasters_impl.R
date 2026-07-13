# ------------------------------------------------------------------------------
# Script: scripts/03_inundation_products/internal/04_build_background_inundation_rasters_impl.R
# Purpose: Internal implementation for historical/background annual inundation
#          occurrence rasters.
# Workflow stage: 03_inundation_products
# Run mode: heavy
# Heavy processing: yes
# Key inputs:
#   - data_intermediate/raster_catalog/raster_catalog.csv
#   - Input/landsat_inundation annual rasters
#   - data_intermediate/spatial/boundary_clean.gpkg
#   - data_intermediate/spatial/plots_clean.gpkg
# Key outputs:
#   - Output/rasters/inundation_background/
#   - Output/csv/inundation/background_rasters/
#   - Output/diagnostics/inundation_background_rasters/
#   - Output/figures/maps/inundation/background_rasters/
#   - Output/reports/rs_inundation_background_raster_handoff.md
# Notes:
#   - Landsat-only annual occurrence product. Not hydroperiod, duration, depth,
#     wet-days, water quality, or ecological outcome.
# ------------------------------------------------------------------------------


## User settings ----

root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", "D:/Github_repos/Gayini"), winslash = "/", mustWork = TRUE)

WATER_YEAR_START_MONTH   <- 7
REFERENCE_PRODUCT        <- "landsat_inundation"
BOUNDARY_BUFFER_M        <- 100
PLOT_BUFFER_PIXELS       <- 1
PREFER_CLOUD3_DUPLICATES <- TRUE
EXPLICIT_NODATA_VALUES   <- c(255, 65535, 127, -1)
DAILY_WET_RULE           <- "strict_value_1"
STOP_ON_LOGICAL_FAILURE  <- FALSE
WRITE_FIGURES            <- TRUE
CHANGE_MAP_LIMIT         <- 60

period_definitions <- tibble::tribble(
  ~period_key,                                      ~start_date,         ~end_date,           ~deck_role,
  "background_strict_1989_2014",                   as.Date("1988-07-01"), as.Date("2014-06-30"), "main_deck_default",
  "background_pre2015_sensitivity_1989_2015",      as.Date("1988-07-01"), as.Date("2015-06-30"), "sensitivity_check",
  "recent_landsat_only_2014_2023",                 as.Date("2013-07-01"), as.Date("2023-06-30"), "landsat_only_recent_comparator"
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


## Load packages ----

library(sf)
library(terra)
library(exactextractr)
library(dplyr)
library(tidyr)
library(tibble)
library(readr)
library(stringr)
library(purrr)
library(lubridate)
library(ggplot2)


## Source functions ----

source(file.path(root_dir, "R", "gayini_temp_cleanup_functions.R"))
source(file.path(root_dir, "R", "inundation_pre_post_raster_functions.R"))
source(file.path(root_dir, "R", "gayini_inundation_wet_rule.R"))  # wet rule extracted (B6)
source(file.path(root_dir, "R", "gayini_plotting_helpers.R"))

analysis_base_functions_path <- file.path(root_dir, "R", "gayini_analysis_base_functions.R")
if (file.exists(analysis_base_functions_path)) {
  source(analysis_base_functions_path)
}

terra_temp_dir <- gayini_setup_terra_temp(
  temp_dir = file.path(root_dir, "data_intermediate", "terra_tmp", "background_inundation")
)

on.exit(
  gayini_cleanup_terra_temp(temp_dir = terra_temp_dir),
  add = TRUE
)


## Input paths ----

raster_catalog_path <- file.path(root_dir, "data_intermediate", "raster_catalog", "raster_catalog.csv")
plots_clean_path    <- file.path(root_dir, "data_intermediate", "spatial", "plots_clean.gpkg")
boundary_path       <- file.path(root_dir, "data_intermediate", "spatial", "boundary_clean.gpkg")

plot_context_candidates <- c(
  file.path(root_dir, "Output", "csv", "ground_cover", "plot_context_flags.csv"),
  file.path(root_dir, "Output", "csv", "plot_context_flags.csv")
)

existing_background_plot_path <- file.path(root_dir, "Output", "csv", "inundation", "background_inundation_frequency_by_plot.csv")

current_pre_raster_path  <- file.path(root_dir, "Output", "rasters", "inundation_pre_post", "pre_conservation_inundation_frequency_pct.tif")
current_post_raster_path <- file.path(root_dir, "Output", "rasters", "inundation_pre_post", "post_conservation_inundation_frequency_pct.tif")


## Output folders ----

background_raster_root <- file.path(root_dir, "Output", "rasters", "inundation_background")
csv_dir                <- file.path(root_dir, "Output", "csv", "inundation", "background_rasters")
figures_dir            <- file.path(root_dir, "Output", "figures", "maps", "inundation", "background_rasters")
diagnostics_dir        <- file.path(root_dir, "Output", "diagnostics", "inundation_background_rasters")
reports_dir            <- file.path(root_dir, "Output", "reports")

purrr::walk(
  c(background_raster_root, csv_dir, figures_dir, diagnostics_dir, reports_dir),
  ~dir.create(.x, recursive = TRUE, showWarnings = FALSE)
)


## Output paths ----

period_summary_path       <- file.path(csv_dir, "background_raster_period_summary.csv")
year_summary_path         <- file.path(csv_dir, "background_raster_year_summary.csv")
input_catalog_path        <- file.path(csv_dir, "background_raster_input_catalog.csv")
manifest_path             <- file.path(csv_dir, "background_raster_manifest.csv")
value_summary_path        <- file.path(csv_dir, "background_raster_value_summary.csv")
plot_frequency_path       <- file.path(csv_dir, "background_raster_frequency_by_plot.csv")
veg_group_path            <- file.path(csv_dir, "background_raster_frequency_by_vegetation_group.csv")
comparison_path           <- file.path(csv_dir, "background_raster_vs_existing_plot_background_comparison.csv")
checks_path               <- file.path(csv_dir, "background_raster_checks.csv")

input_report_path         <- file.path(diagnostics_dir, "background_raster_input_report.csv")
observation_density_path  <- file.path(diagnostics_dir, "background_raster_observation_density_by_year.csv")
spatial_checks_path       <- file.path(diagnostics_dir, "background_raster_spatial_checks.csv")
logical_checks_path       <- file.path(diagnostics_dir, "background_raster_logical_checks.csv")
period_value_summary_path <- file.path(diagnostics_dir, "background_raster_period_raster_value_summary.csv")
plot_extraction_path      <- file.path(diagnostics_dir, "background_raster_plot_extraction_checks.csv")
visual_style_checks_path  <- file.path(diagnostics_dir, "background_raster_visual_style_checks.csv")
legend_class_code_qa_path <- file.path(diagnostics_dir, "background_raster_legend_class_code_qa.csv")
handoff_report_path       <- file.path(reports_dir, "rs_inundation_background_raster_handoff.md")


## Local helpers ----

write_missing_report_and_stop <- function(problem, details = tibble::tibble()) {
  report <- tibble::tibble(
    status = "missing_input",
    problem = problem,
    created_at = as.character(Sys.time())
  )

  readr::write_csv(report, input_report_path)

  if (nrow(details) > 0) {
    readr::write_csv(details, file.path(diagnostics_dir, "background_raster_missing_input_details.csv"))
  }

  writeLines(
    c(
      "# RS Inundation Background Raster Handoff",
      "",
      "Status: not built.",
      "",
      paste0("Reason: ", problem),
      "",
      "No raster outputs were fabricated."
    ),
    handoff_report_path
  )

  stop(problem, call. = FALSE)
}

safe_mean <- function(x) {
  if (all(is.na(x))) NA_real_ else mean(x, na.rm = TRUE)
}

safe_median <- function(x) {
  if (all(is.na(x))) NA_real_ else stats::median(x, na.rm = TRUE)
}

safe_min <- function(x) {
  if (all(is.na(x))) NA_real_ else min(x, na.rm = TRUE)
}

safe_max <- function(x) {
  if (all(is.na(x))) NA_real_ else max(x, na.rm = TRUE)
}

fmt_num <- function(x, digits = 1) {
  ifelse(is.na(x), "NA", format(round(x, digits), nsmall = digits, trim = TRUE))
}

first_existing <- function(paths) {
  found <- paths[file.exists(paths)]
  if (length(found) == 0) NA_character_ else found[[1]]
}

align_to_reference_continuous <- function(x, reference) {
  same_geometry <- terra::compareGeom(
    x,
    reference,
    stopOnError = FALSE,
    crs = TRUE,
    ext = TRUE,
    rowcol = TRUE,
    res = TRUE
  )

  if (isTRUE(same_geometry)) {
    return(terra::mask(x, reference))
  }

  aligned <- try(terra::resample(x, reference, method = "bilinear"), silent = TRUE)
  if (inherits(aligned, "try-error")) {
    aligned <- terra::project(x, reference, method = "bilinear")
  }

  terra::mask(aligned, reference)
}

write_raster_map <- function(raster,
                             path,
                             title,
                             boundary_sf,
                             zlim = NULL,
                             palette = gayini_occurrence_palette_blue_ramp(64),
                             legend_breaks = c(0, 25, 50, 75, 100),
                             legend_title = "Frequency (%)") {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)

  png(filename = path, width = 2600, height = 1900, res = 220)
  op <- par(mar = c(2.8, 2.8, 3.6, 7.0), xpd = NA)
  on.exit({
    par(op)
    dev.off()
  }, add = TRUE)

  plot_args <- list(
    x = raster,
    main = title,
    col = palette,
    axes = FALSE,
    box = FALSE,
    plg = list(at = legend_breaks, title = legend_title)
  )
  if (!is.null(zlim)) {
    plot_args$range <- zlim
  }

  do.call(terra::plot, plot_args)
  boundary_vect <- terra::vect(sf::st_transform(boundary_sf, terra::crs(raster)))
  plot(boundary_vect, add = TRUE, border = "grey25", lwd = 1.0)
}

write_two_raster_map <- function(left_raster,
                                 right_raster,
                                 path,
                                 left_title,
                                 right_title,
                                 boundary_sf,
                                 zlim = NULL,
                                 palette = gayini_occurrence_palette_blue_ramp(64),
                                 legend_breaks = c(0, 25, 50, 75, 100),
                                 legend_title = "Frequency (%)") {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)

  png(filename = path, width = 3600, height = 1800, res = 220)
  op <- par(mfrow = c(1, 2), mar = c(2.8, 2.8, 3.6, 6.6), xpd = NA)
  on.exit({
    par(op)
    dev.off()
  }, add = TRUE)

  for (i in seq_len(2)) {
    r <- if (i == 1) left_raster else right_raster
    ttl <- if (i == 1) left_title else right_title
    plot_args <- list(
      x = r,
      main = ttl,
      col = palette,
      axes = FALSE,
      box = FALSE,
      plg = list(at = legend_breaks, title = legend_title)
    )
    if (!is.null(zlim)) {
      plot_args$range <- zlim
    }
    do.call(terra::plot, plot_args)
    boundary_vect <- terra::vect(sf::st_transform(boundary_sf, terra::crs(r)))
    plot(boundary_vect, add = TRUE, border = "grey25", lwd = 0.95)
  }
}

extract_frequency_stats_to_plots <- function(frequency_raster, support_raster, plots_sf, period_key) {
  prepared <- gayini_prepare_plots_for_raster(
    plots_sf = plots_sf,
    reference_raster = frequency_raster,
    buffer_pixels = PLOT_BUFFER_PIXELS
  )

  frequency_stats <- exactextractr::exact_extract(
    frequency_raster,
    prepared$plots_for_raster,
    c("mean", "median", "max"),
    progress = FALSE
  ) |>
    tibble::as_tibble()

  if (ncol(frequency_stats) == 3) {
    names(frequency_stats) <- c(
      "background_raster_mean_frequency_pct",
      "background_raster_median_frequency_pct",
      "background_raster_max_frequency_pct"
    )
  }

  support_zero <- terra::ifel(is.na(frequency_raster), 0, 1)

  support_stats <- exactextractr::exact_extract(
    support_zero,
    prepared$plots_for_raster,
    "mean",
    progress = FALSE
  ) |>
    tibble::as_tibble()

  if (ncol(support_stats) == 1) {
    names(support_stats) <- "background_raster_support_fraction"
  }

  dplyr::bind_cols(
    tibble::tibble(period_key = period_key),
    frequency_stats,
    support_stats
  ) |>
    dplyr::mutate(
      background_raster_support_pct = 100 * .data$background_raster_support_fraction
    ) |>
    dplyr::select(- .data$background_raster_support_fraction)
}

make_logical_checks_for_period <- function(period_key, period_rasters, annual_outputs, reference_grid) {
  freq <- period_rasters$inundation_frequency_pct
  wet <- period_rasters$wet_year_count
  valid <- period_rasters$valid_year_count
  support <- period_rasters$support_mask

  annual_alignment <- purrr::map_lgl(
    annual_outputs,
    function(x) {
      isTRUE(terra::compareGeom(freq, x$annual_wet_any, stopOnError = FALSE, crs = TRUE, ext = TRUE, rowcol = TRUE, res = TRUE)) &&
        isTRUE(terra::compareGeom(freq, x$annual_valid_any, stopOnError = FALSE, crs = TRUE, ext = TRUE, rowcol = TRUE, res = TRUE))
    }
  )

  period_alignment_ok <- all(vapply(
    list(wet, valid, support),
    function(x) {
      isTRUE(terra::compareGeom(freq, x, stopOnError = FALSE, crs = TRUE, ext = TRUE, rowcol = TRUE, res = TRUE))
    },
    logical(1)
  ))

  wet_gt_valid <- gayini_raster_sum(terra::ifel(wet > valid, 1, 0))
  frequency_without_valid <- gayini_raster_sum(terra::ifel(!is.na(freq) & valid <= 0, 1, 0))
  support_mismatch <- gayini_raster_sum(terra::ifel(is.na(freq) != is.na(support), 1, 0))

  tibble::tibble(
    period_key = period_key,
    check = c(
      "frequency_between_0_and_100",
      "wet_year_count_non_negative",
      "valid_year_count_not_less_than_wet_year_count",
      "frequency_requires_valid_years",
      "support_mask_matches_frequency",
      "annual_rasters_align_to_reference",
      "period_rasters_align"
    ),
    passed = c(
      gayini_raster_min(freq) >= 0 && gayini_raster_max(freq) <= 100,
      gayini_raster_min(wet) >= 0,
      wet_gt_valid == 0,
      frequency_without_valid == 0,
      support_mismatch == 0,
      all(annual_alignment),
      period_alignment_ok
    ),
    detail = c(
      paste0("range=", fmt_num(gayini_raster_min(freq), 3), " to ", fmt_num(gayini_raster_max(freq), 3)),
      paste0("min=", fmt_num(gayini_raster_min(wet), 3)),
      paste0(wet_gt_valid, " pixels where wet_year_count > valid_year_count"),
      paste0(frequency_without_valid, " pixels with frequency but no valid years"),
      paste0(support_mismatch, " cells where support mask and frequency NA status differ"),
      paste0(sum(annual_alignment), " of ", length(annual_alignment), " annual output pairs align"),
      paste0("period alignment=", period_alignment_ok)
    ),
    severity = c("stop_if_fail", "stop_if_fail", "stop_if_fail", "stop_if_fail", "stop_if_fail", "stop_if_fail", "stop_if_fail")
  ) |>
    dplyr::mutate(status = dplyr::if_else(.data$passed, "PASS", "CHECK"))
}


## Input checks ----

required_inputs <- c(
  raster_catalog = raster_catalog_path,
  plots_clean = plots_clean_path,
  boundary_clean = boundary_path
)

missing_required_inputs <- required_inputs[!file.exists(required_inputs)]

if (length(missing_required_inputs) > 0) {
  write_missing_report_and_stop(
    "Required input files are missing.",
    tibble::tibble(input_name = names(missing_required_inputs), path = unname(missing_required_inputs))
  )
}


## Read inputs ----

raster_catalog <- readr::read_csv(raster_catalog_path, show_col_types = FALSE)
plots_clean <- sf::st_read(plots_clean_path, quiet = TRUE) |>
  sf::st_make_valid()
boundary_clean <- sf::st_read(boundary_path, quiet = TRUE) |>
  sf::st_make_valid()

message("Raster catalogue rows: ", nrow(raster_catalog))
message("Clean plots: ", nrow(plots_clean))


## Standardise and filter Landsat catalogues ----

period_catalogs <- purrr::pmap(
  period_definitions,
  function(period_key, start_date, end_date, deck_role) {
    message("Selecting Landsat annual inundation rasters for ", period_key)

    selected <- gayini_standardise_landsat_background_inundation_catalog(
      raster_catalog = raster_catalog,
      root = root_dir,
      period_key = period_key,
      start_date = start_date,
      end_date = end_date,
      water_year_start_month = WATER_YEAR_START_MONTH,
      prefer_cloud3_duplicates = PREFER_CLOUD3_DUPLICATES
    ) |>
      dplyr::mutate(
        period_start_date = start_date,
        period_end_date = end_date,
        deck_role = deck_role
      )

    if (nrow(selected) == 0) {
      write_missing_report_and_stop(
        paste0("No landsat_inundation raster rows exist for requested period: ", period_key),
        tibble::tibble(period_key = period_key, start_date = start_date, end_date = end_date)
      )
    }

    selected
  }
)

inundation_catalog <- dplyr::bind_rows(period_catalogs)

missing_selected_files <- inundation_catalog |>
  dplyr::filter(!.data$file_exists) |>
  dplyr::select(.data$period, .data$analysis_year, .data$file_name, .data$file_path)

if (nrow(missing_selected_files) > 0) {
  write_missing_report_and_stop(
    "Selected Landsat inundation raster files are missing.",
    missing_selected_files
  )
}

readr::write_csv(inundation_catalog, input_catalog_path)
readr::write_csv(inundation_catalog, file.path(diagnostics_dir, "background_raster_selected_input_catalog.csv"))
message("Wrote: ", input_catalog_path)

input_report <- inundation_catalog |>
  dplyr::group_by(.data$period, .data$period_start_date, .data$period_end_date, .data$deck_role) |>
  dplyr::summarise(
    n_catalog_rows = dplyr::n(),
    n_existing_files = sum(.data$file_exists),
    first_water_year = min(.data$analysis_year),
    last_water_year = max(.data$analysis_year),
    n_water_years = dplyr::n_distinct(.data$analysis_year),
    first_date_midpoint = min(.data$date_midpoint),
    last_date_midpoint = max(.data$date_midpoint),
    products = paste(sort(unique(.data$product)), collapse = "; "),
    sensors = paste(sort(unique(.data$sensor_clean)), collapse = "; "),
    .groups = "drop"
  )

readr::write_csv(input_report, input_report_path)
message("Wrote: ", input_report_path)

period_year_lookup <- inundation_catalog |>
  dplyr::distinct(.data$period, .data$analysis_year, .data$analysis_year_start, .data$analysis_year_end, .data$period_year) |>
  dplyr::arrange(.data$period, .data$analysis_year)

year_summary <- inundation_catalog |>
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
  dplyr::mutate(
    annual_inundated_path = file.path(background_raster_root, .data$period, "annual", paste0("annual_inundated_any_", .data$period_year, ".tif")),
    annual_valid_path = file.path(background_raster_root, .data$period, "annual", paste0("annual_valid_any_", .data$period_year, ".tif"))
  ) |>
  dplyr::arrange(.data$period, .data$analysis_year, .data$product, .data$sensor_clean)

readr::write_csv(year_summary, year_summary_path)
message("Wrote: ", year_summary_path)

observation_density_by_year <- gayini_summarise_inundation_observation_density(inundation_catalog)
readr::write_csv(observation_density_by_year, observation_density_path)
message("Wrote: ", observation_density_path)

legend_class_code_qa <- tibble::tibble(
  product_family = "annual_inundation_occurrence",
  source_product = "landsat_inundation",
  wet_rule = "value_gt_zero",
  wet_values = "> 0",
  valid_values = "0 and > 0, excluding NA and explicit no-data codes",
  nodata_values = paste(EXPLICIT_NODATA_VALUES, collapse = "; "),
  frequency_denominator = "Number of annual inundation products available for the period; annual product cells interpreted as valid unless NA/no-data.",
  legend_confirmed = FALSE,
  confirmation_basis = "Consistent with existing annual occurrence workflow and selected raster product family; final source legend confirmation remains outstanding.",
  notes = "Annual products are interpreted as wet where inundation count/value > 0; zero is interpreted as not inundated; documented no-data codes are masked. This is consistent with the existing annual occurrence workflow but remains subject to final legend confirmation with Adrian/source metadata."
)

readr::write_csv(legend_class_code_qa, legend_class_code_qa_path)
message("Wrote: ", legend_class_code_qa_path)

recent_provenance_summary <- inundation_catalog |>
  dplyr::filter(.data$period == "recent_landsat_only_2014_2023") |>
  dplyr::summarise(
    products = paste(sort(unique(.data$product)), collapse = "; "),
    sensors = paste(sort(unique(.data$sensor_clean)), collapse = "; "),
    source_folders = paste(sort(unique(dirname(.data$file_path))), collapse = "; "),
    resolutions_m = paste(sort(unique(paste0(.data$resolution_x, " x ", .data$resolution_y))), collapse = "; "),
    n_rasters = dplyr::n(),
    n_needs_legend_check = sum(.data$needs_legend_check %in% TRUE | .data$needs_legend_check == "TRUE", na.rm = TRUE),
    provenance_label = dplyr::if_else(
      all(.data$product == "landsat_inundation") && all(.data$sensor_clean == "landsat") && all(grepl("landsat_inundation", .data$file_path)),
      "Catalogued Landsat annual inundation product family",
      "Mixed or uncertain annual inundation product family"
    ),
    .groups = "drop"
  )


## Create common reference grid ----

reference_grid <- gayini_make_reference_grid(
  inundation_catalog = inundation_catalog,
  boundary_sf = boundary_clean,
  reference_preference = REFERENCE_PRODUCT,
  boundary_buffer_m = BOUNDARY_BUFFER_M
)

message("Reference grid resolution: ", paste(terra::res(reference_grid), collapse = " x "))
message("Reference grid CRS: ", terra::crs(reference_grid, describe = TRUE)$name)


## Build annual and period rasters ----

annual_outputs_all <- list()
period_outputs <- list()
manifest_rows <- list()

for (period_key in period_definitions$period_key) {
  message("Building background period: ", period_key)

  this_raster_dir <- file.path(background_raster_root, period_key)
  this_annual_dir <- file.path(this_raster_dir, "annual")

  dir.create(this_raster_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(this_annual_dir, recursive = TRUE, showWarnings = FALSE)

  this_lookup <- period_year_lookup |>
    dplyr::filter(.data$period == period_key) |>
    dplyr::arrange(.data$analysis_year)

  this_annual_outputs <- list()

  for (this_period_year in this_lookup$period_year) {
    message("  Building annual inundation raster: ", this_period_year)

    this_catalog <- inundation_catalog |>
      dplyr::filter(.data$period_year == this_period_year)

    annual_wet_path <- file.path(this_annual_dir, paste0("annual_inundated_any_", this_period_year, ".tif"))
    annual_valid_path <- file.path(this_annual_dir, paste0("annual_valid_any_", this_period_year, ".tif"))

    if (file.exists(annual_wet_path) && file.exists(annual_valid_path)) {
      message("    Reusing existing annual rasters for ", this_period_year)
      this_annual_outputs[[this_period_year]] <- list(
        annual_wet_any = terra::rast(annual_wet_path)[[1]],
        annual_valid_any = terra::rast(annual_valid_path)[[1]],
        wet_observation_count = NULL,
        valid_observation_count = NULL
      )
    } else {
      this_annual_outputs[[this_period_year]] <- gayini_build_one_period_year_rasters(
        period_year_catalog = this_catalog,
        reference_grid = reference_grid,
        daily_wet_rule = DAILY_WET_RULE,
        nodata_values = EXPLICIT_NODATA_VALUES,
        output_dir = this_annual_dir
      )
    }
  }

  this_period <- gayini_build_period_frequency_rasters(
    annual_outputs = this_annual_outputs,
    period_lookup = this_lookup,
    period = period_key,
    output_dir = this_raster_dir
  )

  support_mask <- terra::ifel(!is.na(this_period$inundation_frequency_pct), 1, NA)
  names(support_mask) <- paste0(period_key, "_support_mask")

  support_path <- file.path(this_raster_dir, paste0(period_key, "_support_mask.tif"))
  terra::writeRaster(
    support_mask,
    filename = support_path,
    overwrite = TRUE,
    datatype = "INT1U",
    gdal = c("COMPRESS=LZW")
  )

  this_period$support_mask <- support_mask
  period_outputs[[period_key]] <- this_period
  annual_outputs_all[[period_key]] <- this_annual_outputs

  manifest_rows[[period_key]] <- tibble::tribble(
    ~period_key, ~output_type, ~path,
    period_key, "period_frequency", file.path(this_raster_dir, paste0(period_key, "_inundation_frequency_pct.tif")),
    period_key, "period_wet_year_count", file.path(this_raster_dir, paste0(period_key, "_wet_year_count.tif")),
    period_key, "period_valid_year_count", file.path(this_raster_dir, paste0(period_key, "_valid_year_count.tif")),
    period_key, "period_support_mask", support_path
  )
}


## Summaries and diagnostics ----

period_stacks <- purrr::imap(
  period_outputs,
  function(x, period_key) {
    out <- c(x$inundation_frequency_pct, x$wet_year_count, x$valid_year_count, x$support_mask)
    names(out) <- c(
      paste0(period_key, "_inundation_frequency_pct"),
      paste0(period_key, "_wet_year_count"),
      paste0(period_key, "_valid_year_count"),
      paste0(period_key, "_support_mask")
    )
    out
  }
)

period_value_summary <- purrr::map_dfr(period_stacks, gayini_summarise_named_rasters)
readr::write_csv(period_value_summary, value_summary_path)
readr::write_csv(period_value_summary, period_value_summary_path)
message("Wrote: ", value_summary_path)

period_summary <- period_definitions |>
  dplyr::left_join(input_report, by = c("period_key" = "period")) |>
  dplyr::mutate(
    deck_role = dplyr::coalesce(.data$deck_role.x, .data$deck_role.y),
    frequency_min_pct = purrr::map_dbl(.data$period_key, ~gayini_raster_min(period_outputs[[.x]]$inundation_frequency_pct)),
    frequency_max_pct = purrr::map_dbl(.data$period_key, ~gayini_raster_max(period_outputs[[.x]]$inundation_frequency_pct)),
    frequency_mean_pct = purrr::map_dbl(.data$period_key, ~as.numeric(terra::global(period_outputs[[.x]]$inundation_frequency_pct, mean, na.rm = TRUE)[1, 1])),
    wet_year_count_min = purrr::map_dbl(.data$period_key, ~gayini_raster_min(period_outputs[[.x]]$wet_year_count)),
    wet_year_count_max = purrr::map_dbl(.data$period_key, ~gayini_raster_max(period_outputs[[.x]]$wet_year_count)),
    valid_year_count_min = purrr::map_dbl(.data$period_key, ~gayini_raster_min(period_outputs[[.x]]$valid_year_count)),
    valid_year_count_max = purrr::map_dbl(.data$period_key, ~gayini_raster_max(period_outputs[[.x]]$valid_year_count)),
    valid_year_count_constant = .data$valid_year_count_min == .data$valid_year_count_max,
    frequency_denominator_wording = dplyr::if_else(
      .data$valid_year_count_constant,
      "Number of annual products available for the period",
      "Pixel-level valid annual-product count"
    ),
    non_na_frequency_cells = purrr::map_dbl(.data$period_key, ~gayini_raster_non_na_count(period_outputs[[.x]]$inundation_frequency_pct))
  ) |>
  dplyr::select(-dplyr::any_of(c("deck_role.x", "deck_role.y")))

readr::write_csv(period_summary, period_summary_path)
message("Wrote: ", period_summary_path)

manifest <- dplyr::bind_rows(manifest_rows) |>
  dplyr::bind_rows(
    year_summary |>
      dplyr::select(.data$period, .data$period_year, .data$annual_inundated_path, .data$annual_valid_path) |>
      tidyr::pivot_longer(
        cols = c(.data$annual_inundated_path, .data$annual_valid_path),
        names_to = "output_type",
        values_to = "path"
      ) |>
      dplyr::rename(period_key = .data$period) |>
      dplyr::mutate(output_type = dplyr::if_else(.data$output_type == "annual_inundated_path", "annual_inundated_any", "annual_valid_any")) |>
      dplyr::select(.data$period_key, .data$period_year, .data$output_type, .data$path)
  ) |>
  dplyr::mutate(
    relative_path = stringr::str_replace(.data$path, paste0("^", stringr::fixed(root_dir), "[/\\\\]?"), ""),
    file_exists = file.exists(.data$path),
    file_size_mb = dplyr::if_else(.data$file_exists, as.numeric(file.info(.data$path)$size) / 1024 / 1024, NA_real_)
  )

readr::write_csv(manifest, manifest_path)
message("Wrote: ", manifest_path)

logical_checks <- purrr::map_dfr(
  period_definitions$period_key,
  function(period_key) {
    make_logical_checks_for_period(
      period_key = period_key,
      period_rasters = period_outputs[[period_key]],
      annual_outputs = annual_outputs_all[[period_key]],
      reference_grid = reference_grid
    )
  }
)

readr::write_csv(logical_checks, logical_checks_path)
readr::write_csv(logical_checks, checks_path)
message("Wrote: ", logical_checks_path)

failed_stop_checks <- logical_checks |>
  dplyr::filter(.data$status == "CHECK", .data$severity == "stop_if_fail")

if (nrow(failed_stop_checks) > 0) {
  stop_message <- paste(failed_stop_checks$period_key, failed_stop_checks$check, failed_stop_checks$detail, sep = ": ", collapse = "; ")

  if (isTRUE(STOP_ON_LOGICAL_FAILURE)) {
    stop("Background raster logical checks failed: ", stop_message, ". See: ", logical_checks_path, call. = FALSE)
  } else {
    warning("Background raster logical checks need review: ", stop_message, ". See: ", logical_checks_path, call. = FALSE)
  }
}


## Plot extraction and tabular summaries ----

plot_context_path <- first_existing(plot_context_candidates)

plot_context <- if (!is.na(plot_context_path)) {
  readr::read_csv(plot_context_path, show_col_types = FALSE) |>
    dplyr::select(dplyr::any_of(c(
      "plot_id",
      "simplified_vegetation_group",
      "treed_plot_flag",
      "ground_cover_exclusion_flag",
      "collapsed_grazing_category",
      "centroid_x",
      "centroid_y",
      "area_ha"
    )))
} else {
  tibble::tibble(plot_id = character())
}

plot_summaries <- purrr::map_dfr(
  period_definitions$period_key,
  function(period_key) {
    period_stack <- c(
      period_outputs[[period_key]]$inundation_frequency_pct,
      period_outputs[[period_key]]$wet_year_count,
      period_outputs[[period_key]]$valid_year_count
    )

    names(period_stack) <- c(
      "background_raster_frequency_pct",
      "background_raster_wet_year_count",
      "background_raster_valid_year_count"
    )

    mean_extract <- gayini_extract_period_rasters_to_plots(
      period_rasters = period_stack,
      plots_sf = plots_clean,
      buffer_pixels = PLOT_BUFFER_PIXELS,
      summary_method = "mean",
      allow_terra_fallback = TRUE,
      stop_if_all_na = TRUE
    ) |>
      dplyr::mutate(period_key = period_key)

    frequency_stats <- extract_frequency_stats_to_plots(
      frequency_raster = period_outputs[[period_key]]$inundation_frequency_pct,
      support_raster = period_outputs[[period_key]]$support_mask,
      plots_sf = plots_clean,
      period_key = period_key
    )

    mean_extract |>
      dplyr::bind_cols(
        frequency_stats |>
          dplyr::select(
            .data$background_raster_mean_frequency_pct,
            .data$background_raster_median_frequency_pct,
            .data$background_raster_max_frequency_pct,
            .data$background_raster_support_pct
          )
      )
  }
)

if ("plot_id" %in% names(plot_summaries) && nrow(plot_context) > 0) {
  plot_summaries <- plot_summaries |>
    dplyr::select(-dplyr::any_of(setdiff(names(plot_context), "plot_id"))) |>
    dplyr::left_join(plot_context, by = "plot_id")
}

plot_summaries <- plot_summaries |>
  dplyr::relocate(
    dplyr::any_of(c(
      "period_key",
      "plot_id",
      "simplified_vegetation_group",
      "treed_plot_flag",
      "ground_cover_exclusion_flag",
      "collapsed_grazing_category",
      "background_raster_frequency_pct",
      "background_raster_wet_year_count",
      "background_raster_valid_year_count",
      "background_raster_support_pct",
      "background_raster_mean_frequency_pct",
      "background_raster_median_frequency_pct",
      "background_raster_max_frequency_pct"
    ))
  ) |>
  dplyr::arrange(.data$period_key, dplyr::desc(.data$background_raster_frequency_pct), .data$plot_id)

readr::write_csv(plot_summaries, plot_frequency_path)
message("Wrote: ", plot_frequency_path)

plot_extraction_checks <- plot_summaries |>
  dplyr::group_by(.data$period_key) |>
  dplyr::summarise(
    n_plot_rows = dplyr::n(),
    n_frequency_non_na = sum(!is.na(.data$background_raster_frequency_pct)),
    n_support_non_na = sum(!is.na(.data$background_raster_support_pct)),
    min_support_pct = safe_min(.data$background_raster_support_pct),
    max_support_pct = safe_max(.data$background_raster_support_pct),
    extraction_engines = paste(sort(unique(.data$extraction_engine)), collapse = "; "),
    .groups = "drop"
  )

readr::write_csv(plot_extraction_checks, plot_extraction_path)
message("Wrote: ", plot_extraction_path)

vegetation_group_summary <- plot_summaries |>
  dplyr::group_by(.data$period_key, .data$simplified_vegetation_group, .data$treed_plot_flag) |>
  dplyr::summarise(
    n_plots = dplyr::n_distinct(.data$plot_id),
    mean_background_raster_frequency_pct = round(safe_mean(.data$background_raster_frequency_pct), 2),
    median_background_raster_frequency_pct = round(safe_median(.data$background_raster_frequency_pct), 2),
    min_background_raster_frequency_pct = round(safe_min(.data$background_raster_frequency_pct), 2),
    max_background_raster_frequency_pct = round(safe_max(.data$background_raster_frequency_pct), 2),
    mean_background_raster_wet_year_count = round(safe_mean(.data$background_raster_wet_year_count), 2),
    mean_background_raster_valid_year_count = round(safe_mean(.data$background_raster_valid_year_count), 2),
    mean_background_raster_support_pct = round(safe_mean(.data$background_raster_support_pct), 2),
    .groups = "drop"
  ) |>
  dplyr::arrange(.data$period_key, .data$treed_plot_flag, dplyr::desc(.data$mean_background_raster_frequency_pct))

readr::write_csv(vegetation_group_summary, veg_group_path)
message("Wrote: ", veg_group_path)

if (file.exists(existing_background_plot_path)) {
  existing_background <- readr::read_csv(existing_background_plot_path, show_col_types = FALSE) |>
    dplyr::select(dplyr::any_of(c(
      "plot_id",
      "background_period_label",
      "background_valid_year_count",
      "background_wet_year_count",
      "background_inundation_frequency_pct"
    ))) |>
    dplyr::rename(
      existing_background_period_label = .data$background_period_label,
      existing_background_valid_year_count = .data$background_valid_year_count,
      existing_background_wet_year_count = .data$background_wet_year_count,
      existing_background_inundation_frequency_pct = .data$background_inundation_frequency_pct
    )

  comparison <- plot_summaries |>
    dplyr::left_join(existing_background, by = "plot_id") |>
    dplyr::mutate(
      raster_minus_existing_background_frequency_pct_points =
        .data$background_raster_frequency_pct - .data$existing_background_inundation_frequency_pct,
      raster_minus_existing_background_valid_years =
        .data$background_raster_valid_year_count - .data$existing_background_valid_year_count,
      raster_minus_existing_background_wet_years =
        .data$background_raster_wet_year_count - .data$existing_background_wet_year_count
    )
} else {
  comparison <- plot_summaries |>
    dplyr::mutate(
      existing_background_period_label = NA_character_,
      existing_background_valid_year_count = NA_real_,
      existing_background_wet_year_count = NA_real_,
      existing_background_inundation_frequency_pct = NA_real_,
      raster_minus_existing_background_frequency_pct_points = NA_real_,
      raster_minus_existing_background_valid_years = NA_real_,
      raster_minus_existing_background_wet_years = NA_real_
    )
}

readr::write_csv(comparison, comparison_path)
message("Wrote: ", comparison_path)

spatial_checks <- purrr::map_dfr(
  period_definitions$period_key,
  function(period_key) {
    checks <- gayini_plot_raster_spatial_checks(
      period_rasters = period_stacks[[period_key]],
      plots_sf = plots_clean,
      buffer_pixels = PLOT_BUFFER_PIXELS
    )

    dplyr::bind_rows(
      checks$spatial_summary |>
        dplyr::mutate(period_key = period_key, check_type = "spatial_summary", raster_layer = NA_character_),
      checks$centroid_non_na |>
        dplyr::transmute(
          period_key = period_key,
          check_type = "centroid_non_na",
          check = "centroid_non_na_plots",
          value = as.character(.data$centroid_non_na_plots),
          raster_layer = .data$raster_layer
        )
    )
  }
) |>
  dplyr::relocate(.data$period_key, .data$check_type, .data$raster_layer)

readr::write_csv(spatial_checks, spatial_checks_path)
message("Wrote: ", spatial_checks_path)


## Figures ----

figure_paths <- tibble::tibble(output_type = character(), path = character())

if (isTRUE(WRITE_FIGURES)) {
  strict_key <- "background_strict_1989_2014"
  sensitivity_key <- "background_pre2015_sensitivity_1989_2015"
  recent_key <- "recent_landsat_only_2014_2023"

  fig_strict <- file.path(figures_dir, "background_strict_1989_2014_annual_occurrence_frequency_main_deck.png")
  write_raster_map(
    raster = period_outputs[[strict_key]]$inundation_frequency_pct,
    path = fig_strict,
    title = "Historical Landsat background annual occurrence frequency (%)\n1988-1989 to 2013-2014 water years",
    boundary_sf = boundary_clean,
    zlim = c(0, 100)
  )

  fig_sensitivity <- file.path(figures_dir, "background_pre2015_sensitivity_1989_2015_annual_occurrence_frequency_check.png")
  write_raster_map(
    raster = period_outputs[[sensitivity_key]]$inundation_frequency_pct,
    path = fig_sensitivity,
    title = "Historical Landsat background annual occurrence frequency (%)\n1988-1989 to 2014-2015 water years",
    boundary_sf = boundary_clean,
    zlim = c(0, 100)
  )

  figure_paths <- dplyr::bind_rows(
    figure_paths,
    tibble::tibble(
      output_type = c("strict_main_deck_map", "sensitivity_check_map"),
      path = c(fig_strict, fig_sensitivity)
    )
  )

  if (file.exists(current_pre_raster_path)) {
    current_pre <- align_to_reference_continuous(terra::rast(current_pre_raster_path)[[1]], period_outputs[[strict_key]]$inundation_frequency_pct)
    pre_comparison <- file.path(figures_dir, "background_vs_current_pre_frequency_comparison.png")
    write_two_raster_map(
      left_raster = period_outputs[[strict_key]]$inundation_frequency_pct,
      right_raster = current_pre,
      path = pre_comparison,
      left_title = "Background Landsat-only annual occurrence (%)",
      right_title = "Current pre-conservation annual occurrence (%)",
      boundary_sf = boundary_clean,
      zlim = c(0, 100)
    )

    pre_change <- current_pre - period_outputs[[strict_key]]$inundation_frequency_pct
    names(pre_change) <- "current_pre_minus_background_strict_frequency_change"
    pre_change_path <- file.path(figures_dir, "current_pre_minus_background_strict_frequency_change.png")
    write_raster_map(
      raster = pre_change,
      path = pre_change_path,
      title = "Current pre-conservation minus historical background\nannual occurrence frequency (percentage points)",
      boundary_sf = boundary_clean,
      zlim = c(-CHANGE_MAP_LIMIT, CHANGE_MAP_LIMIT),
      palette = grDevices::colorRampPalette(unname(gayini_change_palette()))(64),
      legend_breaks = c(-CHANGE_MAP_LIMIT, -30, 0, 30, CHANGE_MAP_LIMIT),
      legend_title = "Change (ppt)"
    )

    figure_paths <- dplyr::bind_rows(
      figure_paths,
      tibble::tibble(
        output_type = c("background_vs_current_pre", "current_pre_minus_background"),
        path = c(pre_comparison, pre_change_path)
      )
    )
  }

  if (file.exists(current_post_raster_path)) {
    current_post <- align_to_reference_continuous(terra::rast(current_post_raster_path)[[1]], period_outputs[[strict_key]]$inundation_frequency_pct)
    post_comparison <- file.path(figures_dir, "background_vs_current_post_frequency_comparison.png")
    write_two_raster_map(
      left_raster = period_outputs[[strict_key]]$inundation_frequency_pct,
      right_raster = current_post,
      path = post_comparison,
      left_title = "Background Landsat-only annual occurrence (%)",
      right_title = "Current post-conservation annual occurrence (%)",
      boundary_sf = boundary_clean,
      zlim = c(0, 100)
    )

    post_change <- current_post - period_outputs[[strict_key]]$inundation_frequency_pct
    names(post_change) <- "current_post_minus_background_strict_frequency_change"
    post_change_path <- file.path(figures_dir, "current_post_minus_background_strict_frequency_change.png")
    write_raster_map(
      raster = post_change,
      path = post_change_path,
      title = "Current post-conservation minus historical background\nannual occurrence frequency (percentage points)",
      boundary_sf = boundary_clean,
      zlim = c(-CHANGE_MAP_LIMIT, CHANGE_MAP_LIMIT),
      palette = grDevices::colorRampPalette(unname(gayini_change_palette()))(64),
      legend_breaks = c(-CHANGE_MAP_LIMIT, -30, 0, 30, CHANGE_MAP_LIMIT),
      legend_title = "Change (ppt)"
    )

    figure_paths <- dplyr::bind_rows(
      figure_paths,
      tibble::tibble(
        output_type = c("background_vs_current_post", "current_post_minus_background"),
        path = c(post_comparison, post_change_path)
      )
    )
  }

  recent_comparison <- file.path(figures_dir, "historical_vs_recent_landsat_only_frequency_comparison.png")
  write_two_raster_map(
    left_raster = period_outputs[[strict_key]]$inundation_frequency_pct,
    right_raster = period_outputs[[recent_key]]$inundation_frequency_pct,
    path = recent_comparison,
    left_title = "Historical Landsat-only annual occurrence (%)",
    right_title = "Recent Landsat-only annual occurrence (%)",
    boundary_sf = boundary_clean,
    zlim = c(0, 100)
  )

  recent_change <- period_outputs[[recent_key]]$inundation_frequency_pct - period_outputs[[strict_key]]$inundation_frequency_pct
  names(recent_change) <- "recent_landsat_only_minus_background_strict_frequency_change"
  recent_change_path <- file.path(figures_dir, "recent_landsat_only_minus_background_strict_frequency_change.png")
  write_raster_map(
    raster = recent_change,
    path = recent_change_path,
    title = "Recent Landsat-only minus historical background\nannual occurrence frequency (percentage points)",
    boundary_sf = boundary_clean,
    zlim = c(-CHANGE_MAP_LIMIT, CHANGE_MAP_LIMIT),
    palette = grDevices::colorRampPalette(unname(gayini_change_palette()))(64),
    legend_breaks = c(-CHANGE_MAP_LIMIT, -30, 0, 30, CHANGE_MAP_LIMIT),
    legend_title = "Change (ppt)"
  )

  figure_paths <- dplyr::bind_rows(
    figure_paths,
    tibble::tibble(
      output_type = c("historical_vs_recent_landsat_only", "recent_landsat_only_minus_background"),
      path = c(recent_comparison, recent_change_path)
    )
  )

  plot_figure_data <- plot_summaries |>
    dplyr::filter(.data$period_key == strict_key)

  if (all(c("centroid_x", "centroid_y") %in% names(plot_figure_data))) {
    plot_map_path <- file.path(figures_dir, "background_raster_plot_frequency_map.png")
    plot_map <- ggplot2::ggplot(
      plot_figure_data,
      ggplot2::aes(
        x = .data$centroid_x,
        y = .data$centroid_y,
        colour = .data$background_raster_frequency_pct,
        shape = .data$treed_plot_flag
      )
    ) +
      ggplot2::geom_point(size = 3.2, alpha = 0.92) +
      ggplot2::coord_equal() +
      gayini_occurrence_scale_colour(name = "Annual occurrence (%)") +
      ggplot2::labs(
        title = "Historical Landsat background annual occurrence by plot",
        x = NULL,
        y = NULL,
        shape = "Plot interpretation group"
      ) +
      ggplot2::theme_minimal(base_size = 13) +
      ggplot2::theme(panel.grid.minor = ggplot2::element_blank())

    ggplot2::ggsave(plot_map_path, plot_map, width = 9.5, height = 7.2, dpi = 220)

    figure_paths <- dplyr::bind_rows(
      figure_paths,
      tibble::tibble(output_type = "background_raster_plot_frequency_map", path = plot_map_path)
    )
  }

  veg_plot_path <- file.path(figures_dir, "background_raster_by_vegetation_group.png")
  veg_plot <- plot_figure_data |>
    dplyr::filter(!is.na(.data$simplified_vegetation_group)) |>
    ggplot2::ggplot(
      ggplot2::aes(
        x = .data$simplified_vegetation_group,
        y = .data$background_raster_frequency_pct,
        fill = dplyr::if_else(.data$treed_plot_flag, "Treed / flagged plot", "Non-treed interpretation plot")
      )
    ) +
    ggplot2::geom_boxplot(width = 0.62, outlier.alpha = 0.55) +
    ggplot2::coord_flip() +
    ggplot2::scale_fill_manual(
      values = c("Non-treed interpretation plot" = "#4daf4a", "Treed / flagged plot" = "#984ea3"),
      name = "Plot interpretation group"
    ) +
    ggplot2::labs(
      title = "Historical Landsat background annual occurrence by vegetation group",
      x = NULL,
      y = "Annual occurrence frequency (%)"
    ) +
    ggplot2::theme_minimal(base_size = 13) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank())

  ggplot2::ggsave(veg_plot_path, veg_plot, width = 10.5, height = 7.0, dpi = 220)

  figure_paths <- dplyr::bind_rows(
    figure_paths,
    tibble::tibble(output_type = "background_raster_by_vegetation_group", path = veg_plot_path)
  )
}

if (nrow(figure_paths) > 0) {
  figure_manifest <- figure_paths |>
    dplyr::mutate(
      period_key = dplyr::case_when(
        grepl("strict|background_vs|current_|historical_vs|recent_", basename(.data$path)) ~ "background_strict_1989_2014",
        grepl("sensitivity", basename(.data$path)) ~ "background_pre2015_sensitivity_1989_2015",
        TRUE ~ NA_character_
      ),
      path = as.character(.data$path)
    )

  manifest <- dplyr::bind_rows(
    manifest,
    figure_manifest |>
      dplyr::transmute(period_key = .data$period_key, output_type = .data$output_type, path = .data$path)
  ) |>
    dplyr::mutate(
      relative_path = stringr::str_replace(.data$path, paste0("^", stringr::fixed(root_dir), "[/\\\\]?"), ""),
      file_exists = file.exists(.data$path),
      file_size_mb = dplyr::if_else(.data$file_exists, as.numeric(file.info(.data$path)$size) / 1024 / 1024, NA_real_)
    )

  readr::write_csv(manifest, manifest_path)
  message("Updated: ", manifest_path)
}

visual_style_checks <- tibble::tibble(
  figure_path = file.path(
    figures_dir,
    c(
      "background_strict_1989_2014_annual_occurrence_frequency_main_deck.png",
      "background_pre2015_sensitivity_1989_2015_annual_occurrence_frequency_check.png",
      "background_vs_current_pre_frequency_comparison.png",
      "background_vs_current_post_frequency_comparison.png",
      "historical_vs_recent_landsat_only_frequency_comparison.png",
      "current_pre_minus_background_strict_frequency_change.png",
      "current_post_minus_background_strict_frequency_change.png",
      "recent_landsat_only_minus_background_strict_frequency_change.png",
      "background_raster_plot_frequency_map.png",
      "background_raster_by_vegetation_group.png"
    )
  ),
  figure_family = c(
    rep("unidirectional_occurrence_raster", 5),
    rep("divergent_change_raster", 3),
    "plot_occurrence_map",
    "vegetation_group_summary"
  ),
  is_unidirectional_occurrence = c(rep(TRUE, 5), rep(FALSE, 3), TRUE, FALSE),
  uses_shared_blue_occurrence_scale = c(rep(TRUE, 5), rep(FALSE, 3), TRUE, FALSE),
  uses_fixed_0_100_limits = c(rep(TRUE, 5), rep(FALSE, 3), TRUE, FALSE),
  uses_0_25_50_75_100_breaks = c(rep(TRUE, 5), rep(FALSE, 3), TRUE, FALSE),
  legend_outside_map = TRUE,
  change_map_positive_is_blue = c(rep(NA, 5), rep(TRUE, 3), NA, NA),
  notes = c(
    rep("Annual occurrence maps use shared Gayini blue occurrence palette; no-data/outside support remains white/transparent.", 5),
    rep(paste0("Divergent red-white-blue map; positive values are wetter/more frequent annual inundation; display limits fixed to +/-", CHANGE_MAP_LIMIT, " percentage points."), 3),
    "Plot-level occurrence map uses shared blue occurrence colour scale with fixed 0-100 limits.",
    "Boxplot is not a raster occurrence map; treed labels are deck-facing text."
  )
)

readr::write_csv(visual_style_checks, visual_style_checks_path)
message("Wrote: ", visual_style_checks_path)


## Handoff report ----

veg_headline <- vegetation_group_summary |>
  dplyr::filter(.data$period_key == "background_strict_1989_2014") |>
  dplyr::arrange(dplyr::desc(.data$mean_background_raster_frequency_pct)) |>
  dplyr::mutate(
    line = paste0(
      "- ", .data$simplified_vegetation_group,
      " (treed=", .data$treed_plot_flag,
      "): mean ", fmt_num(.data$mean_background_raster_frequency_pct, 1),
      "%, n=", .data$n_plots
    )
  ) |>
  dplyr::pull(.data$line)

comparison_summary <- comparison |>
  dplyr::filter(.data$period_key == "background_pre2015_sensitivity_1989_2015") |>
  dplyr::summarise(
    n_compared = sum(!is.na(.data$raster_minus_existing_background_frequency_pct_points)),
    mean_delta_pct_points = safe_mean(.data$raster_minus_existing_background_frequency_pct_points),
    median_delta_pct_points = safe_median(.data$raster_minus_existing_background_frequency_pct_points),
    max_abs_delta_pct_points = safe_max(abs(.data$raster_minus_existing_background_frequency_pct_points)),
    .groups = "drop"
  )

annual_rasters_written <- manifest |>
  dplyr::filter(.data$output_type %in% c("annual_inundated_any", "annual_valid_any"), .data$file_exists) |>
  nrow()

reference_crs_name <- terra::crs(reference_grid, describe = TRUE)$name
if (is.null(reference_crs_name) || is.na(reference_crs_name)) {
  reference_crs_name <- terra::crs(reference_grid)
}

report_lines <- c(
  "# RS Inundation Background Raster Handoff",
  "",
  paste0("Generated: ", Sys.time()),
  "",
  "## Status",
  "",
  "- Built historical/background annual occurrence rasters from Landsat-only annual inundation inputs.",
  "- Main deck default product: `background_strict_1989_2014`.",
  "- Sensitivity product: `background_pre2015_sensitivity_1989_2015`.",
  "- Recent comparator: `recent_landsat_only_2014_2023`.",
  "- This product is annual occurrence frequency only. It is not hydroperiod, duration, depth, wet-days, water quality, or an ecological outcome.",
  "",
  "## Periods Built",
  "",
  paste0(
    "- `", period_summary$period_key, "`: ",
    period_summary$n_water_years, " water years; ",
    period_summary$first_water_year, "-", period_summary$last_water_year,
    "; ", period_summary$n_catalog_rows, " input rasters."
  ),
  "",
  "## Raster Grid",
  "",
  paste0("- Dimensions: ", terra::ncol(reference_grid), " columns x ", terra::nrow(reference_grid), " rows."),
  paste0("- Resolution: ", paste(terra::res(reference_grid), collapse = " x "), "."),
  paste0("- CRS: ", reference_crs_name, "."),
  "",
  "## Raster Value Ranges",
  "",
  paste0(
    "- `", period_summary$period_key, "`: frequency ",
    fmt_num(period_summary$frequency_min_pct, 2), "-", fmt_num(period_summary$frequency_max_pct, 2),
    "%; wet-year count ",
    fmt_num(period_summary$wet_year_count_min, 0), "-", fmt_num(period_summary$wet_year_count_max, 0),
    "; valid-year count ",
    fmt_num(period_summary$valid_year_count_min, 0), "-", fmt_num(period_summary$valid_year_count_max, 0), "."
  ),
  "",
  "## Annual Rasters Written",
  "",
  paste0("- Annual wet/valid raster files written: ", annual_rasters_written, "."),
  "",
  "## Denominator Wording",
  "",
  "- Frequency is calculated as the number of annual products in which inundation was mapped, divided by the number of annual products available for that period.",
  "- `valid_year_count` is constant within each period in these outputs, so it should not be described as independent per-pixel observation-density QA.",
  "",
  "## Recent Comparator Provenance",
  "",
  paste0("- Product family: ", recent_provenance_summary$products, "."),
  paste0("- Sensor label: ", recent_provenance_summary$sensors, "."),
  paste0("- Source folder(s): ", recent_provenance_summary$source_folders, "."),
  paste0("- Native source resolutions represented in the catalog: ", recent_provenance_summary$resolutions_m, "."),
  paste0("- Provenance conclusion: ", recent_provenance_summary$provenance_label, ". The varying native resolutions should be mentioned if the comparator is used as a sensor-era sensitivity figure."),
  "",
  "## Main Result By Vegetation Group",
  "",
  if (length(veg_headline) == 0) "- No vegetation-group summary rows available." else veg_headline,
  "",
  "## Comparison To Existing Plot-Level Background Table",
  "",
  paste0(
    "- Sensitivity-period plots compared: ", comparison_summary$n_compared,
    "; mean raster-minus-existing delta ",
    fmt_num(comparison_summary$mean_delta_pct_points, 2),
    " percentage points; median delta ",
    fmt_num(comparison_summary$median_delta_pct_points, 2),
    " percentage points; max absolute delta ",
    fmt_num(comparison_summary$max_abs_delta_pct_points, 2),
    " percentage points."
  ),
  "",
  "## QA",
  "",
  paste0("- Logical checks written to `", logical_checks_path, "`."),
  paste0("- Spatial checks written to `", spatial_checks_path, "`."),
  paste0("- Plot extraction checks written to `", plot_extraction_path, "`."),
  paste0("- Visual style checks written to `", visual_style_checks_path, "`."),
  paste0("- Legend/class-code QA written to `", legend_class_code_qa_path, "`."),
  paste0("- Manifest written to `", manifest_path, "`."),
  "",
  "## Caveats",
  "",
  "- Historical/background products use annual Landsat inputs only and should be labelled that way in the deck.",
  "- Annual products are interpreted as wet where inundation count/value is > 0; zero is interpreted as not inundated. This remains subject to final legend confirmation with Adrian/source metadata.",
  "- Comparisons with current pre/post products may mix Landsat-only background with combined recent sensor products unless explicitly using the Landsat-only recent comparator.",
  "- The optional fully non-overlapping `background_no_overlap_1989_2013` sensitivity was not added in this polish run because it would require another annual raster build rather than light-to-medium figure/report polish.",
  "",
  "## Main-Deck Figure Candidates",
  "",
  "- `background_strict_1989_2014_annual_occurrence_frequency_main_deck.png`",
  "- `historical_vs_recent_landsat_only_frequency_comparison.png`",
  "- `recent_landsat_only_minus_background_strict_frequency_change.png`",
  "- `background_raster_by_vegetation_group.png`",
  "",
  "## Deck Readiness",
  "",
  if (nrow(failed_stop_checks) == 0) {
    "- Ready for main-deck review as a Landsat-only historical/background annual occurrence product."
  } else {
    "- Not ready for main-deck use until logical checks marked `CHECK` are reviewed."
  }
)

writeLines(report_lines, handoff_report_path)
message("Wrote: ", handoff_report_path)

message("Background inundation raster workflow complete.")
