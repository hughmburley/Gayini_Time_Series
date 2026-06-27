## -----------------------------------------------------------------------------
## Gayini remote sensing workflow
## 04b_test_fractional_cover_extraction_all_dev_plots.R
## -----------------------------------------------------------------------------


## Purpose:
## Test Landsat fractional-cover extraction for all 66 plots, but only using the
## development raster subset.


## This is the second fractional / ground-cover test.


## 04a tested three plots across the Landsat fractional-cover development rasters.


## 04b scales from three plots to all plots while still limiting the raster count.


## This script does not run the full 153-raster Landsat fractional-cover workflow.


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
## Keep rasters limited to the development subset, but use all available plots.


TARGET_PRODUCT <- "landsat_fractional_cover"


## Decision point:
## Primary extraction uses the plot boundary with no buffer.
## A one-pixel buffer is reserved for a later sensitivity analysis.


BUFFER_PIXELS <- 0


## Decision point:
## Preserve raw raster values in this development-scale test.
## If product metadata later confirms a scale factor, change it deliberately.


VALUE_SCALE_FACTOR <- 1


## Decision point:
## exactextractr::exact_extract() uses "mean" and "median" for summaries that
## are internally weighted by cell coverage fraction.


DEFAULT_PRIMARY_METHOD   <- "mean"
DEFAULT_SECONDARY_METHOD <- "median"


## Decision point:
## Landsat fractional-cover subset rasters are expected to have three bands in
## the current Gayini data, but this is still checked from the raster catalogue.


EXPECTED_BANDS_PER_RASTER <- 3


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


all_dev_output_path <- file.path(
  root_dir,
  "Output",
  "csv",
  "04b_fractional_cover_all_dev_plots.csv"
)


all_dev_checks_path <- file.path(
  root_dir,
  "Output",
  "diagnostics",
  "04b_fractional_cover_all_dev_plots_checks.csv"
)


band_sum_checks_path <- file.path(
  root_dir,
  "Output",
  "diagnostics",
  "04b_fractional_cover_all_dev_band_sum_checks.csv"
)


missing_values_path <- file.path(
  root_dir,
  "Output",
  "diagnostics",
  "04b_fractional_cover_all_dev_missing_values.csv"
)


valid_coverage_by_plot_path <- file.path(
  root_dir,
  "Output",
  "diagnostics",
  "04b_fractional_cover_all_dev_valid_coverage_by_plot.csv"
)


timeseries_by_treatment_path <- file.path(
  root_dir,
  "Output",
  "figures",
  "04b_fractional_cover_all_dev_timeseries_by_treatment.png"
)


valid_coverage_plot_path <- file.path(
  root_dir,
  "Output",
  "figures",
  "04b_fractional_cover_all_dev_valid_coverage_by_plot.png"
)


band_sum_plot_path <- file.path(
  root_dir,
  "Output",
  "figures",
  "04b_fractional_cover_all_dev_band_sum_check.png"
)


missingness_heatmap_path <- file.path(
  root_dir,
  "Output",
  "figures",
  "04b_fractional_cover_all_dev_missingness_heatmap.png"
)


## Folder checks ----


dir.create(dirname(all_dev_output_path), recursive = TRUE, showWarnings = FALSE)
dir.create(dirname(all_dev_checks_path), recursive = TRUE, showWarnings = FALSE)
dir.create(dirname(timeseries_by_treatment_path), recursive = TRUE, showWarnings = FALSE)


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
  setting_name  = "continuous_summary_method",
  default_value = DEFAULT_PRIMARY_METHOD
)


secondary_method_from_settings <- gayini_get_extraction_setting(
  extraction_settings,
  setting_name  = "continuous_secondary_method",
  default_value = DEFAULT_SECONDARY_METHOD
)


summary_methods <- gayini_normalise_fc_summary_methods(
  primary_method   = primary_method_from_settings,
  secondary_method = secondary_method_from_settings
)


message("Fractional-cover summary methods for exactextractr: ", paste(summary_methods, collapse = ", "))


## Select all plots ----


all_plots <- plots_clean |>
  dplyr::arrange(.data$plot_id)


message("Selected all plots: ", nrow(all_plots))


## Select fractional-cover development rasters ----


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


message("Fractional-cover development rasters: ", nrow(fc_dev_subset))


## Read fractional-cover band lookup ----


max_band_count <- max(fc_dev_subset$n_layers, na.rm = TRUE)


band_lookup <- gayini_read_fractional_cover_band_lookup(
  band_lookup_path = band_lookup_path,
  n_bands          = max_band_count
)


## Extract fractional-cover values ----


fc_all_dev_results <- gayini_extract_fractional_cover_subset(
  raster_subset       = fc_dev_subset,
  plots_sf            = all_plots,
  band_lookup         = band_lookup,
  summary_methods     = summary_methods,
  buffer_pixels       = BUFFER_PIXELS,
  value_scale_factor  = VALUE_SCALE_FACTOR,
  extraction_scope    = "development_all_plots"
)


## Add plot metadata for QA and exploratory figures ----


plot_metadata <- all_plots |>
  sf::st_drop_geometry() |>
  dplyr::select(dplyr::any_of(c("plot_id", "treatment", "vegetation", "area_ha")))


fc_all_dev_results <- fc_all_dev_results |>
  dplyr::left_join(plot_metadata, by = "plot_id")


## Create diagnostics ----


fc_all_dev_checks <- gayini_check_fractional_cover_test_results(
  extraction_results        = fc_all_dev_results,
  raster_subset             = fc_dev_subset,
  plots_sf                  = all_plots,
  expected_bands_per_raster = max_band_count
)


band_sum_checks <- gayini_make_fractional_cover_band_sum_checks(fc_all_dev_results)


missing_values <- fc_all_dev_results |>
  dplyr::filter(is.na(.data$mean_value) | is.na(.data$valid_coverage_count) | .data$valid_coverage_count <= 0) |>
  dplyr::arrange(.data$plot_id, .data$date_start, .data$band_number)


valid_coverage_by_plot <- fc_all_dev_results |>
  dplyr::group_by(.data$plot_id, .data$treatment, .data$vegetation, .data$area_ha) |>
  dplyr::summarise(
    n_rows                         = dplyr::n(),
    n_missing_mean_values          = sum(is.na(.data$mean_value)),
    n_zero_or_missing_valid_counts = sum(is.na(.data$valid_coverage_count) | .data$valid_coverage_count <= 0),
    min_valid_coverage_count       = gayini_safe_min(.data$valid_coverage_count),
    median_valid_coverage_count    = stats::median(.data$valid_coverage_count, na.rm = TRUE),
    max_valid_coverage_count       = gayini_safe_max(.data$valid_coverage_count),
    .groups                        = "drop"
  ) |>
  dplyr::arrange(.data$min_valid_coverage_count, .data$plot_id)


## Write tabular outputs ----


readr::write_csv(fc_all_dev_results, all_dev_output_path)
readr::write_csv(fc_all_dev_checks, all_dev_checks_path)
readr::write_csv(band_sum_checks, band_sum_checks_path)
readr::write_csv(missing_values, missing_values_path)
readr::write_csv(valid_coverage_by_plot, valid_coverage_by_plot_path)


message("Wrote: ", all_dev_output_path)
message("Wrote: ", all_dev_checks_path)
message("Wrote: ", band_sum_checks_path)
message("Wrote: ", missing_values_path)
message("Wrote: ", valid_coverage_by_plot_path)


## Create diagnostic plots ----


plot_timeseries_data <- fc_all_dev_results |>
  dplyr::mutate(date_plot = as.Date(.data$date_start)) |>
  dplyr::group_by(.data$treatment, .data$band_label, .data$date_plot) |>
  dplyr::summarise(
    mean_value_by_treatment = mean(.data$mean_value, na.rm = TRUE),
    n_plots                 = dplyr::n_distinct(.data$plot_id[!is.na(.data$mean_value)]),
    .groups                 = "drop"
  )


timeseries_by_treatment <- ggplot2::ggplot(
  plot_timeseries_data,
  ggplot2::aes(
    x      = .data$date_plot,
    y      = .data$mean_value_by_treatment,
    group  = .data$band_label,
    colour = .data$band_label
  )
) +
  ggplot2::geom_line(na.rm = TRUE) +
  ggplot2::geom_point(na.rm = TRUE) +
  ggplot2::facet_wrap(~ treatment) +
  ggplot2::labs(
    title    = "Fractional-cover development test: mean extracted value by treatment",
    subtitle = "All plots; Landsat fractional-cover development subset only; confirm band meanings before interpretation",
    x        = "Raster start date",
    y        = "Mean extracted value across plots",
    colour   = "Band label"
  ) +
  ggplot2::theme_minimal()


ggplot2::ggsave(
  filename = timeseries_by_treatment_path,
  plot     = timeseries_by_treatment,
  width    = 11,
  height   = 7,
  dpi      = 300
)


valid_coverage_plot <- ggplot2::ggplot(
  valid_coverage_by_plot,
  ggplot2::aes(
    x = stats::reorder(.data$plot_id, .data$median_valid_coverage_count),
    y = .data$median_valid_coverage_count
  )
) +
  ggplot2::geom_col() +
  ggplot2::coord_flip() +
  ggplot2::labs(
    title    = "Fractional-cover development test: median valid coverage by plot",
    subtitle = "Lower values may indicate small, clipped, edge, or NoData-affected plots",
    x        = "Plot ID",
    y        = "Median valid coverage count"
  ) +
  ggplot2::theme_minimal()


ggplot2::ggsave(
  filename = valid_coverage_plot_path,
  plot     = valid_coverage_plot,
  width    = 8,
  height   = 12,
  dpi      = 300
)


band_sum_plot <- ggplot2::ggplot(
  band_sum_checks,
  ggplot2::aes(
    x = as.Date(.data$date_start),
    y = .data$band_sum_mean_value
  )
) +
  ggplot2::geom_hline(yintercept = 100, linetype = "dashed") +
  ggplot2::geom_point(na.rm = TRUE, alpha = 0.6) +
  ggplot2::facet_wrap(~ band_sum_interpretation) +
  ggplot2::labs(
    title    = "Fractional-cover development test: band-sum diagnostic",
    subtitle = "If bands are PV/NPV/bare percentages, sums should usually be near 100",
    x        = "Raster start date",
    y        = "Sum of band means"
  ) +
  ggplot2::theme_minimal()


ggplot2::ggsave(
  filename = band_sum_plot_path,
  plot     = band_sum_plot,
  width    = 11,
  height   = 7,
  dpi      = 300
)


missingness_data <- fc_all_dev_results |>
  dplyr::group_by(.data$plot_id, .data$date_start) |>
  dplyr::summarise(
    missing_any_band = any(is.na(.data$mean_value)),
    missing_all_bands = all(is.na(.data$mean_value)),
    .groups = "drop"
  ) |>
  dplyr::mutate(
    missing_status = dplyr::case_when(
      missing_all_bands ~ "all bands missing",
      missing_any_band  ~ "some bands missing",
      TRUE              ~ "complete"
    )
  )


missingness_heatmap <- ggplot2::ggplot(
  missingness_data,
  ggplot2::aes(
    x    = as.Date(.data$date_start),
    y    = .data$plot_id,
    fill = .data$missing_status
  )
) +
  ggplot2::geom_tile() +
  ggplot2::labs(
    title = "Fractional-cover development test: missingness by plot and date",
    x     = "Raster start date",
    y     = "Plot ID",
    fill  = "Missingness"
  ) +
  ggplot2::theme_minimal()


ggplot2::ggsave(
  filename = missingness_heatmap_path,
  plot     = missingness_heatmap,
  width    = 10,
  height   = 12,
  dpi      = 300
)


message("Wrote: ", timeseries_by_treatment_path)
message("Wrote: ", valid_coverage_plot_path)
message("Wrote: ", band_sum_plot_path)
message("Wrote: ", missingness_heatmap_path)


## Stop only on failed checks ----


failed_checks <- fc_all_dev_checks |>
  dplyr::filter(.data$status == "fail")


warning_checks <- fc_all_dev_checks |>
  dplyr::filter(.data$status == "warn")


if (nrow(warning_checks) > 0) {
  warning(
    "Fractional-cover all-dev-plot warnings were created. Review: ",
    all_dev_checks_path,
    call. = FALSE
  )
}


if (nrow(failed_checks) > 0) {
  stop(
    "Fractional-cover all-dev-plot checks failed. Review: ",
    all_dev_checks_path,
    call. = FALSE
  )
}


## Final messages ----


message("Fractional-cover all-dev-plot test complete.")
message("Rows written: ", nrow(fc_all_dev_results))
message("Expected rows: ", nrow(all_plots) * nrow(fc_dev_subset) * max_band_count)
message("Review the CSV outputs and diagnostic plots before running full fractional-cover extraction.")
