## -----------------------------------------------------------------------------
## Gayini remote sensing workflow
## 05a_test_landsat_inundation_extraction_10_plots.R
## -----------------------------------------------------------------------------


## Purpose:
## Run a small, spatially spread smoke test for Landsat annual inundation
## extraction.


## Landsat annual inundation values are treated as whole-number inundation counts
## for each water year, based on Adrian's current notes. The primary derived
## metric is the area percentage of each plot with count > 0.


## This differs from fractional cover. We do not treat these values as a
## continuous surface in the main output. We preserve count-area percentages and
## calculate derived inundation metrics only after area-fraction extraction.


## Setup ----


root_dir <- normalizePath("D:/Github_repos/Gayini", winslash = "/", mustWork = TRUE)

source(file.path(root_dir, "R", "gayini_helpers.R"))
source(file.path(root_dir, "R", "inundation_extraction_functions.R"))

message("Using inundation functions from: ", file.path(root_dir, "R", "inundation_extraction_functions.R"))

if (!exists("gayini_extract_landsat_inundation_collection", mode = "function")) {
  stop("Required function gayini_extract_landsat_inundation_collection() was not loaded. Check R/inundation_extraction_functions.R.", call. = FALSE)
}

required_packages <- c(
  "sf",
  "terra",
  "exactextractr",
  "dplyr",
  "tidyr",
  "readr",
  "tibble",
  "ggplot2"
)

gayini_check_packages(required_packages)


## User settings ----


TARGET_PRODUCT <- "landsat_inundation"
USE_DEV_SUBSET <- TRUE

N_TEST_PLOTS <- 10
INCLUDE_PLOT_IDS <- c("GA_029")

BUFFER_PIXELS <- 0

COUNT_VALUES <- 0:3
NODATA_VALUES <- c(255)

VERY_LOW_COVERAGE_PCT <- 25
ADEQUATE_COVERAGE_PCT <- 75

EXPECTED_RASTERS <- 10


## Decision notes ----


## Use the development subset first. This should select roughly 10 annual
## Landsat inundation rasters spread through the time series.


## Use 10 spatially spread plots rather than 3 plots. This still keeps the test
## manageable, but should catch more edge, clipped, and coverage issues.


## Include GA_029 because it is known to be smaller / clipped and is useful for
## testing coverage diagnostics.


## Primary extraction uses the mapped plot boundary only. A one-pixel buffer is
## reserved for later sensitivity checks and should not be mixed into the main
## extraction table.


## Preserve count values 0, 1, 2 and 3 as separate area percentages. The primary
## derived metric is inundated_any_pct = area percentage where count > 0.


## Treat 255 as NoData even where raster metadata does not expose it
## consistently.


## Coverage thresholds are based on percentage of expected plot coverage, not
## raw cell count, because annual inundation rasters have mixed resolutions.


## Paths ----


plots_path <- file.path(
  root_dir,
  "data_intermediate",
  "spatial",
  "plots_clean.gpkg"
)

raster_catalog_path <- file.path(
  root_dir,
  "data_intermediate",
  "raster_catalog",
  "raster_catalog.csv"
)

raster_dev_subset_path <- file.path(
  root_dir,
  "data_intermediate",
  "raster_catalog",
  "raster_dev_subset.csv"
)

output_csv_dir <- file.path(root_dir, "Output", "csv")
output_diagnostics_dir <- file.path(root_dir, "Output", "diagnostics")
output_figures_dir <- file.path(root_dir, "Output", "figures")

dir.create(output_csv_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(output_diagnostics_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(output_figures_dir, recursive = TRUE, showWarnings = FALSE)

output_path <- file.path(
  output_csv_dir,
  "05a_landsat_inundation_10_plots.csv"
)

checks_path <- file.path(
  output_diagnostics_dir,
  "05a_landsat_inundation_10_plots_checks.csv"
)

count_summary_path <- file.path(
  output_diagnostics_dir,
  "05a_landsat_inundation_10_plots_count_summary.csv"
)

coverage_summary_path <- file.path(
  output_diagnostics_dir,
  "05a_landsat_inundation_10_plots_coverage_summary.csv"
)

selected_plots_path <- file.path(
  output_diagnostics_dir,
  "05a_landsat_inundation_10_plots_selected_plots.csv"
)

count_fraction_plot_path <- file.path(
  output_figures_dir,
  "05a_landsat_inundation_10_plots_count_area_percentages.png"
)

inundated_any_plot_path <- file.path(
  output_figures_dir,
  "05a_landsat_inundation_10_plots_inundated_any_pct.png"
)

coverage_plot_path <- file.path(
  output_figures_dir,
  "05a_landsat_inundation_10_plots_valid_coverage.png"
)

majority_plot_path <- file.path(
  output_figures_dir,
  "05a_landsat_inundation_10_plots_majority_count.png"
)

legacy_output_paths <- c(
  file.path(output_diagnostics_dir, "05a_landsat_inundation_10_plots_class_summary.csv"),
  file.path(output_figures_dir, "05a_landsat_inundation_10_plots_class_fractions.png"),
  file.path(output_figures_dir, "05a_landsat_inundation_10_plots_majority_class.png")
)


## Input checks ----


required_files <- c(
  plots_path,
  raster_catalog_path
)

if (USE_DEV_SUBSET) {
  required_files <- c(required_files, raster_dev_subset_path)
}

missing_files <- required_files[!file.exists(required_files)]

if (length(missing_files) > 0) {
  stop(
    "Missing required files:\n",
    paste(missing_files, collapse = "\n"),
    call. = FALSE
  )
}


## Clean stale legacy outputs ----


existing_legacy_outputs <- legacy_output_paths[file.exists(legacy_output_paths)]

if (length(existing_legacy_outputs) > 0) {
  unlink(existing_legacy_outputs, force = TRUE)
  message("Removed stale legacy class-based outputs: ", paste(basename(existing_legacy_outputs), collapse = ", "))
}


## Read inputs ----


plots_clean <- sf::st_read(
  plots_path,
  quiet = TRUE
)

message("Clean plots available: ", nrow(plots_clean))

if (USE_DEV_SUBSET) {
  raster_catalog <- readr::read_csv(
    raster_dev_subset_path,
    show_col_types = FALSE
  )

  message("Development raster subset rows: ", nrow(raster_catalog))
} else {
  raster_catalog <- readr::read_csv(
    raster_catalog_path,
    show_col_types = FALSE
  )

  message("Full raster catalogue rows: ", nrow(raster_catalog))
}

raster_catalog <- gayini_standardise_inundation_catalog(raster_catalog)


## Select spatially spread test plots ----


plots_test <- gayini_select_spread_plots(
  plots_sf = plots_clean,
  n_plots = N_TEST_PLOTS,
  include_plot_ids = INCLUDE_PLOT_IDS
)

readr::write_csv(
  sf::st_drop_geometry(plots_test),
  selected_plots_path
)

message("Selected test plots: ", paste(plots_test$plot_id, collapse = ", "))


## Select Landsat annual inundation rasters ----


landsat_inundation_catalog <- raster_catalog |>
  dplyr::filter(.data$product == TARGET_PRODUCT) |>
  dplyr::arrange(.data$date_start, .data$file_name)

if (nrow(landsat_inundation_catalog) == 0) {
  stop(
    "No Landsat annual inundation rasters found in selected catalogue.",
    call. = FALSE
  )
}

if (USE_DEV_SUBSET && nrow(landsat_inundation_catalog) != EXPECTED_RASTERS) {
  warning(
    "Expected ",
    EXPECTED_RASTERS,
    " development Landsat inundation rasters, but found ",
    nrow(landsat_inundation_catalog),
    ". Continue, but review the subset.",
    call. = FALSE
  )
}

message("Landsat annual inundation test rasters: ", nrow(landsat_inundation_catalog))
message(
  "Landsat annual inundation sensors: ",
  paste(sort(unique(landsat_inundation_catalog$sensor)), collapse = ", ")
)


## Run extraction ----


extraction_output <- gayini_extract_landsat_inundation_collection(
  raster_catalog = landsat_inundation_catalog,
  plots_sf = plots_test,
  count_values = COUNT_VALUES,
  nodata_values = NODATA_VALUES,
  buffer_pixels = BUFFER_PIXELS,
  extraction_scope = "landsat_inundation_10_plot_smoke_test",
  legend_status = "unconfirmed",
  very_low_pct = VERY_LOW_COVERAGE_PCT,
  adequate_pct = ADEQUATE_COVERAGE_PCT
)

expected_rows <- nrow(plots_test) * nrow(landsat_inundation_catalog)

required_count_output_columns <- c(
  paste0("count_", COUNT_VALUES, "_area_pct"),
  "other_count_area_pct",
  "inundated_any_pct",
  "mean_inundation_count",
  "majority_count"
)

missing_count_output_columns <- setdiff(required_count_output_columns, names(extraction_output))

if (length(missing_count_output_columns) > 0) {
  stop(
    "The 05a extraction output is missing required count-based columns: ",
    paste(missing_count_output_columns, collapse = ", "),
    ". This usually means the old inundation function file is still being sourced.",
    call. = FALSE
  )
}

legacy_class_columns <- grep("^class_[0-9]+_pct$|^other_class_pct$|^majority_class$", names(extraction_output), value = TRUE)

if (length(legacy_class_columns) > 0) {
  warning(
    "Legacy class-based columns are present in 05a output: ",
    paste(legacy_class_columns, collapse = ", "),
    ". These should be removed before scaling to 05b.",
    call. = FALSE
  )
}

checks <- gayini_make_landsat_inundation_checks(
  extraction_output = extraction_output,
  expected_rows = expected_rows
)

count_summary <- gayini_make_landsat_inundation_count_summary(extraction_output)

coverage_summary <- gayini_make_inundation_coverage_summary(extraction_output)


## Write outputs ----


readr::write_csv(extraction_output, output_path)
readr::write_csv(checks, checks_path)
readr::write_csv(count_summary, count_summary_path)
readr::write_csv(coverage_summary, coverage_summary_path)

message("Wrote: ", output_path)
message("Wrote: ", checks_path)
message("Wrote: ", count_summary_path)
message("Wrote: ", coverage_summary_path)
message("Wrote: ", selected_plots_path)


## Diagnostic figures ----


count_area_columns <- paste0("count_", COUNT_VALUES, "_area_pct")

count_plot_data <- extraction_output |>
  dplyr::select(
    .data$plot_id,
    .data$date_start,
    .data$file_name,
    dplyr::all_of(count_area_columns)
  ) |>
  tidyr::pivot_longer(
    cols = dplyr::all_of(count_area_columns),
    names_to = "inundation_count",
    values_to = "area_pct"
  ) |>
  dplyr::mutate(
    inundation_count = gsub("count_", "", .data$inundation_count),
    inundation_count = gsub("_area_pct", "", .data$inundation_count),
    inundation_count = paste0("Count ", .data$inundation_count)
  )

count_fraction_plot <- ggplot2::ggplot(
  count_plot_data,
  ggplot2::aes(
    x = .data$date_start,
    y = .data$area_pct,
    colour = .data$inundation_count
  )
) +
  ggplot2::geom_line(linewidth = 0.25, na.rm = TRUE) +
  ggplot2::geom_point(size = 0.9, na.rm = TRUE) +
  ggplot2::facet_wrap(~ plot_id, ncol = 2) +
  ggplot2::labs(
    title = "05a Landsat annual inundation smoke test: count-area percentages",
    subtitle = "10 spatially spread plots; values treated as water-year inundation counts; legend unconfirmed",
    x = "Raster start date",
    y = "Area within valid plot coverage (%)",
    colour = "Inundation count"
  ) +
  ggplot2::theme_minimal(base_size = 9) +
  ggplot2::theme(
    plot.title = ggplot2::element_text(size = 11),
    plot.subtitle = ggplot2::element_text(size = 9),
    strip.text = ggplot2::element_text(size = 8),
    legend.position = "bottom"
  )

ggplot2::ggsave(
  filename = count_fraction_plot_path,
  plot = count_fraction_plot,
  width = 11,
  height = 12,
  dpi = 300
)

inundated_any_plot <- ggplot2::ggplot(
  extraction_output,
  ggplot2::aes(
    x = .data$date_start,
    y = .data$inundated_any_pct,
    colour = .data$valid_coverage_status
  )
) +
  ggplot2::geom_line(linewidth = 0.25, na.rm = TRUE) +
  ggplot2::geom_point(size = 1.0, na.rm = TRUE) +
  ggplot2::facet_wrap(~ plot_id, ncol = 2) +
  ggplot2::labs(
    title = "05a Landsat annual inundation smoke test: area inundated at least once",
    subtitle = "Primary metric: inundated_any_pct = plot area where annual count > 0",
    x = "Raster start date",
    y = "Inundated area (%)",
    colour = "Coverage status"
  ) +
  ggplot2::theme_minimal(base_size = 9) +
  ggplot2::theme(
    plot.title = ggplot2::element_text(size = 11),
    plot.subtitle = ggplot2::element_text(size = 9),
    strip.text = ggplot2::element_text(size = 8),
    legend.position = "bottom"
  )

ggplot2::ggsave(
  filename = inundated_any_plot_path,
  plot = inundated_any_plot,
  width = 11,
  height = 12,
  dpi = 300
)

coverage_plot <- ggplot2::ggplot(
  extraction_output,
  ggplot2::aes(
    x = .data$date_start,
    y = .data$valid_coverage_pct,
    colour = .data$valid_coverage_status
  )
) +
  ggplot2::geom_hline(yintercept = ADEQUATE_COVERAGE_PCT, linetype = "dashed") +
  ggplot2::geom_point(size = 1.0, na.rm = TRUE) +
  ggplot2::facet_wrap(~ plot_id, ncol = 2) +
  ggplot2::labs(
    title = "05a Landsat annual inundation smoke test: valid coverage",
    subtitle = "Coverage is expressed as percent of expected plot coverage at each raster resolution",
    x = "Raster start date",
    y = "Valid coverage of expected plot area (%)",
    colour = "Coverage status"
  ) +
  ggplot2::theme_minimal(base_size = 9) +
  ggplot2::theme(
    plot.title = ggplot2::element_text(size = 11),
    plot.subtitle = ggplot2::element_text(size = 9),
    strip.text = ggplot2::element_text(size = 8),
    legend.position = "bottom"
  )

ggplot2::ggsave(
  filename = coverage_plot_path,
  plot = coverage_plot,
  width = 11,
  height = 12,
  dpi = 300
)

majority_plot <- ggplot2::ggplot(
  extraction_output,
  ggplot2::aes(
    x = .data$date_start,
    y = factor(.data$majority_count),
    colour = .data$valid_coverage_status
  )
) +
  ggplot2::geom_point(size = 1.1, na.rm = TRUE) +
  ggplot2::facet_wrap(~ plot_id, ncol = 2) +
  ggplot2::labs(
    title = "05a Landsat annual inundation smoke test: majority count",
    subtitle = "Majority count is diagnostic only; count-area fractions and inundated_any_pct are primary",
    x = "Raster start date",
    y = "Majority count",
    colour = "Coverage status"
  ) +
  ggplot2::theme_minimal(base_size = 9) +
  ggplot2::theme(
    plot.title = ggplot2::element_text(size = 11),
    plot.subtitle = ggplot2::element_text(size = 9),
    strip.text = ggplot2::element_text(size = 8),
    legend.position = "bottom"
  )

ggplot2::ggsave(
  filename = majority_plot_path,
  plot = majority_plot,
  width = 11,
  height = 12,
  dpi = 300
)

message("Wrote: ", count_fraction_plot_path)
message("Wrote: ", inundated_any_plot_path)
message("Wrote: ", coverage_plot_path)
message("Wrote: ", majority_plot_path)


## Final checks ----


row_count_matches <- nrow(extraction_output) == expected_rows

if (!row_count_matches) {
  warning(
    "Unexpected row count. Expected ",
    expected_rows,
    " but wrote ",
    nrow(extraction_output),
    ".",
    call. = FALSE
  )
}

unexpected_count_rows <- sum(
  !is.na(extraction_output$other_count_area_pct) &
    extraction_output$other_count_area_pct > 0
)

count_columns_present <- all(
  paste0("count_", COUNT_VALUES, "_area_pct") %in% names(extraction_output)
)

inundated_any_problem_rows <- sum(
  !is.na(extraction_output$inundated_any_pct) &
    (
      extraction_output$inundated_any_pct < 0 |
        extraction_output$inundated_any_pct > 100
    )
)

has_warning <- !row_count_matches |
  !count_columns_present |
  unexpected_count_rows > 0 |
  inundated_any_problem_rows > 0

message("Landsat inundation 05a smoke test complete.")
message("Rows written: ", nrow(extraction_output))
message("Expected rows: ", expected_rows)
message("Review CSV outputs and diagnostic plots before scaling to all plots.")

if (has_warning) {
  warning(
    "Landsat inundation 05a warnings were created. Review: ",
    checks_path,
    call. = FALSE
  )
}




####################################################################################################
############################################ TBC ###################################################
####################################################################################################