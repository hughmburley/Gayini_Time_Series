## -----------------------------------------------------------------------------
## Gayini remote sensing workflow
## 04c_extract_fractional_cover_full.R
## -----------------------------------------------------------------------------


## Purpose:
## Run the full Landsat fractional-cover / ground-cover extraction for all plots
## and all catalogued Landsat fractional-cover rasters.


## This script is the third script in the 04-series.


## 04a tested three plots across the development raster subset.


## 04b tested all plots across the development raster subset.


## 04c scales to all plots and all Landsat fractional-cover rasters.


## This script writes all extracted values, including missing and low-coverage
## cases. It does not interpolate, fill, or drop missing observations.


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
## Use the full raster catalogue, but select only Landsat fractional-cover rasters.


TARGET_PRODUCT <- "landsat_fractional_cover"


## Decision point:
## Primary extraction uses the plot boundary with no buffer.
## A one-pixel buffer is reserved for a later sensitivity analysis.


BUFFER_PIXELS <- 0


## Decision point:
## Preserve raw raster values because the Gayini subset rasters appear to already
## be in 0 to 100 percentage units. If product metadata later confirms a scale
## factor, change this deliberately and rerun.


VALUE_SCALE_FACTOR <- 1


## Decision point:
## exactextractr::exact_extract() uses "mean" and "median" for summaries that
## are internally weighted by polygon coverage fraction.


DEFAULT_PRIMARY_METHOD   <- "mean"
DEFAULT_SECONDARY_METHOD <- "median"


## Decision point:
## Landsat fractional-cover subset rasters are expected to have three bands in
## the current Gayini data. This is checked from the raster catalogue.


EXPECTED_BANDS_PER_RASTER <- 3


## Decision point:
## Valid coverage counts are effective raster-cell counts after polygon overlap
## and NoData handling. These thresholds are first-pass QA thresholds, not final
## scientific exclusion rules.


VERY_LOW_COVERAGE_THRESHOLD <- 1
ADEQUATE_COVERAGE_THRESHOLD <- 5


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


full_output_path <- file.path(
  root_dir,
  "Output",
  "csv",
  "04c_fractional_cover_full.csv"
)


processed_output_path <- file.path(
  root_dir,
  "data_processed",
  "plot_fractional_cover_timeseries.csv"
)


full_checks_path <- file.path(
  root_dir,
  "Output",
  "diagnostics",
  "04c_fractional_cover_full_checks.csv"
)


band_sum_checks_path <- file.path(
  root_dir,
  "Output",
  "diagnostics",
  "04c_fractional_cover_full_band_sum_checks.csv"
)


missing_values_path <- file.path(
  root_dir,
  "Output",
  "diagnostics",
  "04c_fractional_cover_full_missing_values.csv"
)


valid_coverage_by_plot_path <- file.path(
  root_dir,
  "Output",
  "diagnostics",
  "04c_fractional_cover_full_valid_coverage_by_plot.csv"
)


valid_coverage_status_summary_path <- file.path(
  root_dir,
  "Output",
  "diagnostics",
  "04c_fractional_cover_full_valid_coverage_status_summary.csv"
)


missingness_by_raster_path <- file.path(
  root_dir,
  "Output",
  "diagnostics",
  "04c_fractional_cover_full_missingness_by_raster.csv"
)


timeseries_by_treatment_path <- file.path(
  root_dir,
  "Output",
  "figures",
  "04c_fractional_cover_full_timeseries_by_treatment.png"
)


valid_coverage_plot_path <- file.path(
  root_dir,
  "Output",
  "figures",
  "04c_fractional_cover_full_valid_coverage_by_plot.png"
)


band_sum_plot_path <- file.path(
  root_dir,
  "Output",
  "figures",
  "04c_fractional_cover_full_band_sum_check.png"
)


missingness_by_raster_plot_path <- file.path(
  root_dir,
  "Output",
  "figures",
  "04c_fractional_cover_full_missingness_by_raster.png"
)


missingness_heatmap_path <- file.path(
  root_dir,
  "Output",
  "figures",
  "04c_fractional_cover_full_missingness_heatmap.png"
)


## Folder checks ----


dir.create(dirname(full_output_path), recursive = TRUE, showWarnings = FALSE)
dir.create(dirname(processed_output_path), recursive = TRUE, showWarnings = FALSE)
dir.create(dirname(full_checks_path), recursive = TRUE, showWarnings = FALSE)
dir.create(dirname(timeseries_by_treatment_path), recursive = TRUE, showWarnings = FALSE)


## Input checks ----


gayini_stop_if_missing(plots_path, label = "clean plot layer")
gayini_stop_if_missing(raster_catalog_path, label = "raster catalogue")


## Read inputs ----


plots_clean <- sf::st_read(plots_path, quiet = TRUE)


raster_catalog <- readr::read_csv(
  raster_catalog_path,
  show_col_types = FALSE
)


## Standardise the raster catalogue schema.
## This protects 04c from older catalogues that do not yet contain product or
## sensor columns. For ground-cover/fractional-cover rasters, product is inferred
## from the folder/filename and sensor is inferred as L5/L7/L8/L9 where possible,
## otherwise LS for general Landsat.


raster_catalog <- gayini_standardise_fractional_cover_catalog(
  raster_catalog = raster_catalog,
  target_product = TARGET_PRODUCT
)


extraction_settings <- gayini_read_extraction_settings(extraction_settings_path)


message("Clean plots available: ", nrow(plots_clean))
message("Raster catalogue rows: ", nrow(raster_catalog))


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


## Select all Landsat fractional-cover rasters ----


fc_full_catalog <- raster_catalog |>
  dplyr::filter(.data$product == TARGET_PRODUCT) |>
  dplyr::mutate(
    date_start = as.Date(.data$date_start),
    date_end   = as.Date(.data$date_end)
  ) |>
  dplyr::arrange(.data$date_start, .data$file_name)


if (nrow(fc_full_catalog) == 0) {
  stop(
    "No fractional-cover rasters found in raster_catalog.csv for product: ",
    TARGET_PRODUCT,
    call. = FALSE
  )
}


message("Fractional-cover full rasters: ", nrow(fc_full_catalog))
message("Fractional-cover sensor values: ", paste(sort(unique(fc_full_catalog$sensor)), collapse = ", "))


## Read fractional-cover band lookup ----


max_band_count <- max(fc_full_catalog$n_layers, na.rm = TRUE)


if (max_band_count != EXPECTED_BANDS_PER_RASTER) {
  warning(
    "Maximum fractional-cover band count is ",
    max_band_count,
    ", but expected ",
    EXPECTED_BANDS_PER_RASTER,
    ". Continue, but review band lookup and outputs.",
    call. = FALSE
  )
}


band_lookup <- gayini_read_fractional_cover_band_lookup(
  band_lookup_path = band_lookup_path,
  n_bands          = max_band_count
)


## Extract fractional-cover values ----


fc_full_results <- gayini_extract_fractional_cover_subset(
  raster_subset       = fc_full_catalog,
  plots_sf            = all_plots,
  band_lookup         = band_lookup,
  summary_methods     = summary_methods,
  buffer_pixels       = BUFFER_PIXELS,
  value_scale_factor  = VALUE_SCALE_FACTOR,
  extraction_scope    = "full_all_plots"
)


## Add plot metadata and coverage-status flags ----


plot_metadata <- all_plots |>
  sf::st_drop_geometry() |>
  dplyr::select(dplyr::any_of(c("plot_id", "treatment", "vegetation", "area_ha")))


fc_full_results <- fc_full_results |>
  dplyr::left_join(plot_metadata, by = "plot_id") |>
  gayini_add_valid_coverage_status(
    very_low_threshold = VERY_LOW_COVERAGE_THRESHOLD,
    adequate_threshold = ADEQUATE_COVERAGE_THRESHOLD
  ) |>
  dplyr::mutate(
    date_midpoint = dplyr::if_else(
      is.na(.data$date_end),
      as.Date(.data$date_start),
      as.Date(.data$date_start) + floor(as.numeric(as.Date(.data$date_end) - as.Date(.data$date_start)) / 2)
    )
  )


## Create diagnostics ----


fc_full_checks <- gayini_check_fractional_cover_test_results(
  extraction_results        = fc_full_results,
  raster_subset             = fc_full_catalog,
  plots_sf                  = all_plots,
  expected_bands_per_raster = max_band_count
)


band_sum_checks <- gayini_make_fractional_cover_band_sum_checks(fc_full_results)


missing_values <- fc_full_results |>
  dplyr::filter(
    is.na(.data$mean_value) |
      is.na(.data$valid_coverage_count) |
      .data$valid_coverage_count <= 0 |
      .data$valid_coverage_status %in% c("very_low_coverage", "low_coverage")
  ) |>
  dplyr::arrange(.data$plot_id, .data$date_start, .data$band_number)


valid_coverage_by_plot <- fc_full_results |>
  dplyr::group_by(.data$plot_id, .data$treatment, .data$vegetation, .data$area_ha) |>
  dplyr::summarise(
    n_rows                         = dplyr::n(),
    n_missing_mean_values          = sum(is.na(.data$mean_value)),
    n_no_valid_coverage            = sum(.data$valid_coverage_status == "no_valid_coverage", na.rm = TRUE),
    n_very_low_coverage            = sum(.data$valid_coverage_status == "very_low_coverage", na.rm = TRUE),
    n_low_coverage                 = sum(.data$valid_coverage_status == "low_coverage", na.rm = TRUE),
    n_adequate_coverage            = sum(.data$valid_coverage_status == "adequate_coverage", na.rm = TRUE),
    min_valid_coverage_count       = gayini_safe_min(.data$valid_coverage_count),
    median_valid_coverage_count    = gayini_safe_median(.data$valid_coverage_count),
    max_valid_coverage_count       = gayini_safe_max(.data$valid_coverage_count),
    .groups                        = "drop"
  ) |>
  dplyr::arrange(.data$min_valid_coverage_count, .data$plot_id)


valid_coverage_status_summary <- fc_full_results |>
  dplyr::count(.data$valid_coverage_status, name = "n_rows") |>
  dplyr::mutate(pct_rows = 100 * .data$n_rows / sum(.data$n_rows)) |>
  dplyr::arrange(dplyr::desc(.data$n_rows))


missingness_by_raster <- fc_full_results |>
  dplyr::group_by(.data$file_name, .data$date_start, .data$date_end, .data$water_year) |>
  dplyr::summarise(
    n_rows                  = dplyr::n(),
    n_missing_mean_values   = sum(is.na(.data$mean_value)),
    n_no_valid_coverage     = sum(.data$valid_coverage_status == "no_valid_coverage", na.rm = TRUE),
    n_very_low_coverage     = sum(.data$valid_coverage_status == "very_low_coverage", na.rm = TRUE),
    n_low_coverage          = sum(.data$valid_coverage_status == "low_coverage", na.rm = TRUE),
    n_adequate_coverage     = sum(.data$valid_coverage_status == "adequate_coverage", na.rm = TRUE),
    n_plots_with_any_missing = dplyr::n_distinct(.data$plot_id[is.na(.data$mean_value)]),
    pct_missing_rows        = 100 * .data$n_missing_mean_values / .data$n_rows,
    .groups                 = "drop"
  ) |>
  dplyr::arrange(dplyr::desc(.data$pct_missing_rows), .data$date_start)


## Write tabular outputs ----


readr::write_csv(fc_full_results, full_output_path)
readr::write_csv(fc_full_results, processed_output_path)
readr::write_csv(fc_full_checks, full_checks_path)
readr::write_csv(band_sum_checks, band_sum_checks_path)
readr::write_csv(missing_values, missing_values_path)
readr::write_csv(valid_coverage_by_plot, valid_coverage_by_plot_path)
readr::write_csv(valid_coverage_status_summary, valid_coverage_status_summary_path)
readr::write_csv(missingness_by_raster, missingness_by_raster_path)


message("Wrote: ", full_output_path)
message("Wrote: ", processed_output_path)
message("Wrote: ", full_checks_path)
message("Wrote: ", band_sum_checks_path)
message("Wrote: ", missing_values_path)
message("Wrote: ", valid_coverage_by_plot_path)
message("Wrote: ", valid_coverage_status_summary_path)
message("Wrote: ", missingness_by_raster_path)


## Create diagnostic plots ----


plot_timeseries_data <- fc_full_results |>
  dplyr::mutate(date_plot = as.Date(.data$date_midpoint)) |>
  dplyr::group_by(.data$treatment, .data$band_label, .data$date_plot) |>
  dplyr::summarise(
    mean_value_by_treatment = gayini_safe_mean(.data$mean_value),
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
  ggplot2::geom_line(na.rm = TRUE, linewidth = 0.25) +
  ggplot2::geom_point(na.rm = TRUE, size = 0.6) +
  ggplot2::facet_wrap(~ treatment) +
  ggplot2::labs(
    title    = "Full fractional-cover extraction: mean extracted value by treatment",
    subtitle = "All plots; all catalogued Landsat fractional-cover rasters; confirm band meanings before interpretation",
    x        = "Raster midpoint date",
    y        = "Mean extracted value across plots",
    colour   = "Band label"
  ) +
  ggplot2::theme_minimal()


ggplot2::ggsave(
  filename = timeseries_by_treatment_path,
  plot     = timeseries_by_treatment,
  width    = 12,
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
    title    = "Full fractional-cover extraction: median valid coverage by plot",
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
  ggplot2::geom_point(na.rm = TRUE, alpha = 0.35, size = 0.5) +
  ggplot2::facet_wrap(~ band_sum_interpretation) +
  ggplot2::labs(
    title    = "Full fractional-cover extraction: band-sum diagnostic",
    subtitle = "If bands are PV/NPV/bare percentages, sums should usually be near 100",
    x        = "Raster start date",
    y        = "Sum of band means"
  ) +
  ggplot2::theme_minimal()


ggplot2::ggsave(
  filename = band_sum_plot_path,
  plot     = band_sum_plot,
  width    = 12,
  height   = 7,
  dpi      = 300
)


missingness_by_raster_plot <- ggplot2::ggplot(
  missingness_by_raster,
  ggplot2::aes(
    x = as.Date(.data$date_start),
    y = .data$pct_missing_rows
  )
) +
  ggplot2::geom_col() +
  ggplot2::labs(
    title    = "Full fractional-cover extraction: missing rows by raster",
    subtitle = "High values indicate dates where source raster valid-data coverage is limited across the plot network",
    x        = "Raster start date",
    y        = "Missing rows (%)"
  ) +
  ggplot2::theme_minimal()


ggplot2::ggsave(
  filename = missingness_by_raster_plot_path,
  plot     = missingness_by_raster_plot,
  width    = 12,
  height   = 6,
  dpi      = 300
)


missingness_data <- fc_full_results |>
  dplyr::group_by(.data$plot_id, .data$date_start) |>
  dplyr::summarise(
    missing_any_band  = any(is.na(.data$mean_value)),
    missing_all_bands = all(is.na(.data$mean_value)),
    worst_coverage_status = dplyr::case_when(
      any(.data$valid_coverage_status == "no_valid_coverage") ~ "no valid coverage",
      any(.data$valid_coverage_status == "very_low_coverage") ~ "very low coverage",
      any(.data$valid_coverage_status == "low_coverage") ~ "low coverage",
      TRUE ~ "adequate coverage"
    ),
    .groups = "drop"
  ) |>
  dplyr::mutate(
    missing_status = dplyr::case_when(
      missing_all_bands ~ "all bands missing",
      missing_any_band  ~ "some bands missing",
      TRUE              ~ worst_coverage_status
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
    title = "Full fractional-cover extraction: missingness and coverage by plot and date",
    x     = "Raster start date",
    y     = "Plot ID",
    fill  = "Status"
  ) +
  ggplot2::theme_minimal()


ggplot2::ggsave(
  filename = missingness_heatmap_path,
  plot     = missingness_heatmap,
  width    = 12,
  height   = 12,
  dpi      = 300
)


message("Wrote: ", timeseries_by_treatment_path)
message("Wrote: ", valid_coverage_plot_path)
message("Wrote: ", band_sum_plot_path)
message("Wrote: ", missingness_by_raster_plot_path)
message("Wrote: ", missingness_heatmap_path)


## Stop only on failed checks ----


failed_checks <- fc_full_checks |>
  dplyr::filter(.data$status == "fail")


warning_checks <- fc_full_checks |>
  dplyr::filter(.data$status == "warn")


if (nrow(warning_checks) > 0) {
  warning(
    "Fractional-cover full-extraction warnings were created. Review: ",
    full_checks_path,
    call. = FALSE
  )
}


if (nrow(failed_checks) > 0) {
  stop(
    "Fractional-cover full-extraction checks failed. Review: ",
    full_checks_path,
    call. = FALSE
  )
}


## Final messages ----


message("Full fractional-cover extraction complete.")
message("Rows written: ", nrow(fc_full_results))
message("Expected rows: ", nrow(all_plots) * nrow(fc_full_catalog) * max_band_count)
message("Primary output: ", full_output_path)
message("Processed output: ", processed_output_path)
message("Review diagnostics before using outputs for interpretation or time-series modelling.")
