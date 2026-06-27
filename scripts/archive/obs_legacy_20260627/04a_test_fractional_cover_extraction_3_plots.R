## -----------------------------------------------------------------------------
## Gayini remote sensing workflow
## 04a_test_fractional_cover_extraction_3_plots.R
## -----------------------------------------------------------------------------


## Purpose:
## Test fractional-cover extraction on three plots before scaling to all plots.


## This script uses:
## - the clean plot layer from scripts/01_prepare_vectors.R
## - the development raster subset from scripts/03_make_raster_dev_subset.R
## - only Landsat fractional-cover rasters
## - only a small number of plots


## This script does not run the full extraction workflow.


## Setup ----


root_dir <- normalizePath("D:/Github_repos/Gayini", winslash = "/", mustWork = TRUE)


source(file.path(root_dir, "R", "gayini_helpers.R"))
source(file.path(root_dir, "R", "fractional_cover_extraction_functions.R"))


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


## Decision point:
## Keep the first test deliberately small. We want to test logic, not speed.


N_TEST_PLOTS <- 3


PREFERRED_TEST_PLOTS <- c("GA_029")


## Decision point:
## Use only the Landsat fractional-cover dev subset in this script.


TARGET_PRODUCT <- "landsat_fractional_cover"


## Decision point:
## Primary extraction uses the true plot boundary with no buffer.
## A one-pixel buffer can be tested later as a sensitivity analysis.


BUFFER_PIXELS <- 0


## Decision point:
## Preserve raw raster values in the smoke test.
## If product metadata later confirms a scaling rule, change this deliberately.


VALUE_SCALE_FACTOR <- 1


## Decision point:
## exactextractr::exact_extract() uses "mean" and "median" for polygon summaries
## that are internally weighted by cell coverage fraction.


DEFAULT_PRIMARY_METHOD   <- "mean"
DEFAULT_SECONDARY_METHOD <- "median"


## Paths ----


plots_path <- file.path(
  root_dir,
  "data_intermediate",
  "spatial",
  "plots_clean.gpkg"
)


dev_subset_path <- file.path(
  root_dir,
  "data_intermediate",
  "raster_catalog",
  "raster_dev_subset.csv"
)


extraction_settings_path <- file.path(
  root_dir,
  "config",
  "extraction_settings.csv"
)


band_lookup_path <- file.path(
  root_dir,
  "config",
  "class_legends",
  "fractional_cover_bands.csv"
)


test_extraction_output_path <- file.path(
  root_dir,
  "Output",
  "csv",
  "04a_test_fractional_cover_extraction_3_plots.csv"
)


band_sum_checks_path <- file.path(
  root_dir,
  "Output",
  "diagnostics",
  "04a_test_fractional_cover_band_sum_checks.csv"
)


test_checks_path <- file.path(
  root_dir,
  "Output",
  "diagnostics",
  "04a_test_fractional_cover_extraction_checks.csv"
)


test_plot_selection_path <- file.path(
  root_dir,
  "Output",
  "diagnostics",
  "04a_test_fractional_cover_selected_plots.csv"
)


timeseries_plot_path <- file.path(
  root_dir,
  "Output",
  "figures",
  "04a_test_fractional_cover_plot_timeseries.png"
)


valid_count_plot_path <- file.path(
  root_dir,
  "Output",
  "figures",
  "04a_test_fractional_cover_valid_count.png"
)


band_sum_plot_path <- file.path(
  root_dir,
  "Output",
  "figures",
  "04a_test_fractional_cover_band_sum_check.png"
)


## Folder checks ----


dir.create(dirname(test_extraction_output_path), recursive = TRUE, showWarnings = FALSE)
dir.create(dirname(test_checks_path), recursive = TRUE, showWarnings = FALSE)
dir.create(dirname(timeseries_plot_path), recursive = TRUE, showWarnings = FALSE)


## Input checks ----


gayini_stop_if_missing(plots_path, label = "clean plot layer")
gayini_stop_if_missing(dev_subset_path, label = "development raster subset")


## Read inputs ----


plots_clean <- sf::st_read(plots_path, quiet = TRUE)


raster_dev_subset <- readr::read_csv(
  dev_subset_path,
  show_col_types = FALSE
)


extraction_settings <- gayini_read_extraction_settings(extraction_settings_path)


message("Clean plots available: ", nrow(plots_clean))
message("Development raster subset rows: ", nrow(raster_dev_subset))


## Read extraction settings ----


primary_method_from_settings <- gayini_get_extraction_setting(
  extraction_settings,
  setting_name   = "continuous_summary_method",
  default_value  = DEFAULT_PRIMARY_METHOD
)


secondary_method_from_settings <- gayini_get_extraction_setting(
  extraction_settings,
  setting_name   = "continuous_secondary_method",
  default_value  = DEFAULT_SECONDARY_METHOD
)


summary_methods <- gayini_normalise_fc_summary_methods(
  primary_method   = primary_method_from_settings,
  secondary_method = secondary_method_from_settings
)


message("Fractional-cover summary methods for exactextractr: ", paste(summary_methods, collapse = ", "))


## Select test plots ----


test_plots <- gayini_select_fractional_cover_test_plots(
  plots_sf            = plots_clean,
  preferred_plot_ids  = PREFERRED_TEST_PLOTS,
  n_plots             = N_TEST_PLOTS
)


test_plot_table <- test_plots |>
  sf::st_drop_geometry() |>
  dplyr::select(dplyr::any_of(c("plot_id", "treatment", "vegetation", "area_ha"))) |>
  dplyr::arrange(.data$plot_id)


readr::write_csv(test_plot_table, test_plot_selection_path)


message("Selected test plots: ", paste(test_plot_table$plot_id, collapse = ", "))


## Select fractional-cover test rasters ----


fc_dev_subset <- raster_dev_subset |>
  dplyr::filter(.data$product == TARGET_PRODUCT) |>
  dplyr::arrange(as.Date(.data$date_start), .data$file_name)


if (nrow(fc_dev_subset) == 0) {
  stop(
    "No fractional-cover rasters found in raster_dev_subset.csv for product: ",
    TARGET_PRODUCT,
    call. = FALSE
  )
}


message("Fractional-cover test rasters: ", nrow(fc_dev_subset))


## Read fractional-cover band lookup ----


max_band_count <- max(fc_dev_subset$n_layers, na.rm = TRUE)


band_lookup <- gayini_read_fractional_cover_band_lookup(
  band_lookup_path = band_lookup_path,
  n_bands          = max_band_count
)


## Extract fractional-cover values ----


fc_test_results <- gayini_extract_fractional_cover_subset(
  raster_subset       = fc_dev_subset,
  plots_sf            = test_plots,
  band_lookup         = band_lookup,
  summary_methods     = summary_methods,
  buffer_pixels       = BUFFER_PIXELS,
  value_scale_factor  = VALUE_SCALE_FACTOR
)


## Create diagnostics ----


fc_test_checks <- gayini_check_fractional_cover_test_results(
  extraction_results        = fc_test_results,
  raster_subset             = fc_dev_subset,
  plots_sf                  = test_plots,
  expected_bands_per_raster = max_band_count
)


band_sum_checks <- gayini_make_fractional_cover_band_sum_checks(fc_test_results)


## Write tabular outputs ----


readr::write_csv(fc_test_results, test_extraction_output_path)
readr::write_csv(fc_test_checks, test_checks_path)
readr::write_csv(band_sum_checks, band_sum_checks_path)


message("Wrote: ", test_extraction_output_path)
message("Wrote: ", test_checks_path)
message("Wrote: ", band_sum_checks_path)
message("Wrote: ", test_plot_selection_path)


## Create diagnostic plots ----


plot_timeseries_data <- fc_test_results |>
  dplyr::mutate(date_plot = as.Date(.data$date_start))


plot_timeseries <- ggplot2::ggplot(
  plot_timeseries_data,
  ggplot2::aes(
    x      = .data$date_plot,
    y      = .data$mean_value,
    group  = .data$band_label,
    colour = .data$band_label
  )
) +
  ggplot2::geom_line(na.rm = TRUE) +
  ggplot2::geom_point(na.rm = TRUE) +
  ggplot2::facet_wrap(~ plot_id) +
  ggplot2::labs(
    title    = "Fractional-cover smoke test: mean extracted value",
    subtitle = "Development subset only; confirm band meanings before interpretation",
    x        = "Raster start date",
    y        = "Mean extracted value",
    colour   = "Band label"
  ) +
  ggplot2::theme_minimal()


ggplot2::ggsave(
  filename = timeseries_plot_path,
  plot     = plot_timeseries,
  width    = 10,
  height   = 7,
  dpi      = 300
)


valid_count_plot <- ggplot2::ggplot(
  plot_timeseries_data,
  ggplot2::aes(
    x     = .data$date_plot,
    y     = .data$valid_coverage_count,
    group = .data$band_label
  )
) +
  ggplot2::geom_line(na.rm = TRUE) +
  ggplot2::geom_point(na.rm = TRUE) +
  ggplot2::facet_grid(plot_id ~ band_label) +
  ggplot2::labs(
    title    = "Fractional-cover smoke test: valid coverage count",
    subtitle = "Count is the sum of non-NA coverage fractions from exactextractr",
    x        = "Raster start date",
    y        = "Valid coverage count"
  ) +
  ggplot2::theme_minimal()


ggplot2::ggsave(
  filename = valid_count_plot_path,
  plot     = valid_count_plot,
  width    = 10,
  height   = 8,
  dpi      = 300
)


band_sum_plot <- ggplot2::ggplot(
  band_sum_checks,
  ggplot2::aes(
    x     = as.Date(.data$date_start),
    y     = .data$band_sum_mean_value,
    group = .data$plot_id
  )
) +
  ggplot2::geom_line(na.rm = TRUE) +
  ggplot2::geom_point(na.rm = TRUE) +
  ggplot2::facet_wrap(~ plot_id) +
  ggplot2::labs(
    title    = "Fractional-cover smoke test: band-sum diagnostic",
    subtitle = "If bands are PV/NPV/bare percentages, sums should usually be near 100",
    x        = "Raster start date",
    y        = "Sum of band means"
  ) +
  ggplot2::theme_minimal()


ggplot2::ggsave(
  filename = band_sum_plot_path,
  plot     = band_sum_plot,
  width    = 10,
  height   = 7,
  dpi      = 300
)


message("Wrote: ", timeseries_plot_path)
message("Wrote: ", valid_count_plot_path)
message("Wrote: ", band_sum_plot_path)


## Stop only on failed checks ----


failed_checks <- fc_test_checks |>
  dplyr::filter(.data$status == "fail")


warning_checks <- fc_test_checks |>
  dplyr::filter(.data$status == "warn")


if (nrow(warning_checks) > 0) {
  warning(
    "Fractional-cover smoke-test warnings were created. Review: ",
    test_checks_path,
    call. = FALSE
  )
}


if (nrow(failed_checks) > 0) {
  stop(
    "Fractional-cover smoke-test checks failed. Review: ",
    test_checks_path,
    call. = FALSE
  )
}


## Final messages ----


message("Fractional-cover smoke test complete.")
message("Rows written: ", nrow(fc_test_results))
message("Review the CSV outputs and diagnostic plots before scaling to all plots.")



####################################################################################################
############################################ TBC ###################################################
####################################################################################################
