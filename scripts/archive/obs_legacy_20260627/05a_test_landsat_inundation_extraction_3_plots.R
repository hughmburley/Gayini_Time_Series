## -----------------------------------------------------------------------------
## Gayini remote sensing workflow
## 05a_test_landsat_inundation_extraction_3_plots.R
## -----------------------------------------------------------------------------


## Purpose:
## Run a small smoke test for Landsat annual inundation extraction.


## This script tests the categorical inundation extraction logic before scaling
## to all plots and all Landsat annual inundation rasters.


## Inundation values are class codes, not continuous values. Therefore, the
## script records class-area percentages and majority class; it does not compute
## mean inundation class values.


## Setup ----


root_dir <- normalizePath("D:/Github_repos/Gayini", winslash = "/", mustWork = TRUE)


source(file.path(root_dir, "R", "gayini_helpers.R"))
source(file.path(root_dir, "R", "inundation_extraction_functions.R"))


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


## Decision point:
## Use the development subset first. This should select roughly 10 annual
## Landsat inundation rasters spread through the time series.


USE_DEV_SUBSET <- TRUE


## Decision point:
## Use a small set of plots first. Include GA_029 because it is known to be
## smaller / clipped and is useful for testing coverage diagnostics.


TEST_PLOT_IDS <- c("GA_001", "GA_013", "GA_029")


## Decision point:
## Primary extraction uses the mapped plot boundary only. A one-pixel buffer is
## reserved for later sensitivity checks and should not be mixed into the main
## extraction table.


BUFFER_PIXELS <- 0


## Decision point:
## Preserve class codes 0, 1, 2 and 3 as separate percentages. Do not collapse
## these to inundated / not inundated until Adrian confirms the legend.


CLASS_VALUES <- 0:3


## Decision point:
## Treat 255 as NoData even where raster metadata does not expose it consistently.


NODATA_VALUES <- c(255)


## Decision point:
## These thresholds are based on percentage of expected cell coverage within the
## plot, not raw cell count, because annual inundation rasters have mixed 25 m,
## 30 m and 10 m resolutions.


VERY_LOW_COVERAGE_PCT <- 25
ADEQUATE_COVERAGE_PCT <- 75


EXPECTED_RASTERS <- 10


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
  "05a_landsat_inundation_3_plots.csv"
)


checks_path <- file.path(
  output_diagnostics_dir,
  "05a_landsat_inundation_3_plots_checks.csv"
)


class_summary_path <- file.path(
  output_diagnostics_dir,
  "05a_landsat_inundation_3_plots_class_summary.csv"
)


coverage_summary_path <- file.path(
  output_diagnostics_dir,
  "05a_landsat_inundation_3_plots_coverage_summary.csv"
)


selected_plots_path <- file.path(
  output_diagnostics_dir,
  "05a_landsat_inundation_3_plots_selected_plots.csv"
)


class_fraction_plot_path <- file.path(
  output_figures_dir,
  "05a_landsat_inundation_class_fractions.png"
)


coverage_plot_path <- file.path(
  output_figures_dir,
  "05a_landsat_inundation_valid_coverage.png"
)


majority_plot_path <- file.path(
  output_figures_dir,
  "05a_landsat_inundation_majority_class.png"
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


## Select test plots ----


missing_test_plots <- setdiff(TEST_PLOT_IDS, plots_clean$plot_id)


if (length(missing_test_plots) > 0) {
  stop(
    "Requested test plots not found: ",
    paste(missing_test_plots, collapse = ", "),
    call. = FALSE
  )
}


plots_test <- plots_clean |>
  dplyr::filter(.data$plot_id %in% TEST_PLOT_IDS) |>
  dplyr::arrange(match(.data$plot_id, TEST_PLOT_IDS))


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
message("Landsat annual inundation sensors: ",
  paste(sort(unique(landsat_inundation_catalog$sensor)), collapse = ", "))


## Run extraction ----


extraction_output <- gayini_extract_inundation_collection(
  raster_catalog = landsat_inundation_catalog,
  plots_sf = plots_test,
  class_values = CLASS_VALUES,
  nodata_values = NODATA_VALUES,
  buffer_pixels = BUFFER_PIXELS,
  extraction_scope = "landsat_inundation_3_plot_smoke_test",
  legend_status = "unconfirmed",
  very_low_pct = VERY_LOW_COVERAGE_PCT,
  adequate_pct = ADEQUATE_COVERAGE_PCT
)


expected_rows <- nrow(plots_test) * nrow(landsat_inundation_catalog)


checks <- gayini_make_inundation_checks(
  extraction_output = extraction_output,
  expected_rows = expected_rows
)


class_summary <- gayini_make_inundation_class_summary(extraction_output)


coverage_summary <- gayini_make_inundation_coverage_summary(extraction_output)


## Write outputs ----


readr::write_csv(extraction_output, output_path)


readr::write_csv(checks, checks_path)


readr::write_csv(class_summary, class_summary_path)


readr::write_csv(coverage_summary, coverage_summary_path)


message("Wrote: ", output_path)
message("Wrote: ", checks_path)
message("Wrote: ", class_summary_path)
message("Wrote: ", coverage_summary_path)
message("Wrote: ", selected_plots_path)


## Diagnostic figures ----


class_plot_data <- extraction_output |>
  dplyr::select(
    .data$plot_id,
    .data$date_start,
    .data$file_name,
    .data$class_0_pct,
    .data$class_1_pct,
    .data$class_2_pct,
    .data$class_3_pct
  ) |>
  tidyr::pivot_longer(
    cols = dplyr::starts_with("class_"),
    names_to = "class_code",
    values_to = "class_pct"
  ) |>
  dplyr::mutate(
    class_code = gsub("class_", "", .data$class_code),
    class_code = gsub("_pct", "", .data$class_code),
    class_code = paste0("Class ", .data$class_code)
  )


class_fraction_plot <- ggplot2::ggplot(
  class_plot_data,
  ggplot2::aes(x = .data$date_start, y = .data$class_pct, colour = .data$class_code)
) +
  ggplot2::geom_line(linewidth = 0.3, na.rm = TRUE) +
  ggplot2::geom_point(size = 1.1, na.rm = TRUE) +
  ggplot2::facet_wrap(~ plot_id, ncol = 1) +
  ggplot2::labs(
    title = "05a Landsat annual inundation smoke test: class-area percentages",
    subtitle = "Class legend is unconfirmed; preserve class fractions before interpretation",
    x = "Raster start date",
    y = "Class area within plot (%)",
    colour = "Raster class"
  ) +
  ggplot2::theme_minimal(base_size = 10)


ggplot2::ggsave(
  filename = class_fraction_plot_path,
  plot = class_fraction_plot,
  width = 10,
  height = 8,
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
  ggplot2::geom_point(size = 1.4, na.rm = TRUE) +
  ggplot2::facet_wrap(~ plot_id, ncol = 1) +
  ggplot2::labs(
    title = "05a Landsat annual inundation smoke test: valid coverage",
    subtitle = "Coverage is expressed as percent of expected plot coverage at each raster resolution",
    x = "Raster start date",
    y = "Valid coverage of expected plot area (%)",
    colour = "Coverage status"
  ) +
  ggplot2::theme_minimal(base_size = 10)


ggplot2::ggsave(
  filename = coverage_plot_path,
  plot = coverage_plot,
  width = 10,
  height = 8,
  dpi = 300
)


majority_plot <- ggplot2::ggplot(
  extraction_output,
  ggplot2::aes(
    x = .data$date_start,
    y = factor(.data$majority_class),
    colour = .data$valid_coverage_status
  )
) +
  ggplot2::geom_point(size = 1.6, na.rm = TRUE) +
  ggplot2::facet_wrap(~ plot_id, ncol = 1) +
  ggplot2::labs(
    title = "05a Landsat annual inundation smoke test: majority class",
    subtitle = "Majority class is a diagnostic only; class fractions are the primary output",
    x = "Raster start date",
    y = "Majority class",
    colour = "Coverage status"
  ) +
  ggplot2::theme_minimal(base_size = 10)


ggplot2::ggsave(
  filename = majority_plot_path,
  plot = majority_plot,
  width = 10,
  height = 8,
  dpi = 300
)


message("Wrote: ", class_fraction_plot_path)
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


unexpected_class_rows <- sum(
  !is.na(extraction_output$other_class_pct) &
    extraction_output$other_class_pct > 0
)


class_columns_present <- all(
  paste0("class_", CLASS_VALUES, "_pct") %in% names(extraction_output)
)


has_warning <- !row_count_matches |
  !class_columns_present |
  unexpected_class_rows > 0


message("Landsat inundation 05a smoke test complete.")
message("Rows written: ", nrow(extraction_output))
message("Expected rows: ", expected_rows)
message("Review CSV outputs and diagnostic plots before scaling to all plots.")


if (has_warning) {
  warning(
    "05a inundation smoke-test warnings were created. Review: ",
    checks_path,
    call. = FALSE
  )
}



####################################################################################################
############################################ TBC ###################################################
####################################################################################################
