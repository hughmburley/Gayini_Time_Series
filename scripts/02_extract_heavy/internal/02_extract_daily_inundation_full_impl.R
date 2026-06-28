# ------------------------------------------------------------------------------
# Script: scripts/02_extract_heavy/internal/02_extract_daily_inundation_full_impl.R
# Purpose: Internal implementation module for 02_extract_heavy: extract daily
#          inundation full impl.
# Workflow stage: 02_extract_heavy
# Run mode: heavy
# Heavy processing: yes
# Key inputs:
#   - Inputs are supplied by the active wrapper or existing workflow outputs.
# Key outputs:
#   - Outputs are written by the implementation module for its active wrapper.
# Notes:
#   - Internal module; run the wrapper script in the parent folder unless
#     debugging.
#   - Heavy step; do not run casually and never from the smoke test.
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Load configuration and execute workflow step
# ------------------------------------------------------------------------------
## 06c daily inundation full extraction ----

## Purpose:
## Scale the passed 06b daily inundation extraction from all plots on the development subset to all clean plots across the full daily-inundation time series.
## Expected values, based on SEED/Data.NSW metadata:
## 0 = not inundated
## 1 = inundated
## 2 = off-river storage with water
## 3 = cloud shadow
## Legend should still be confirmed with Adrian before final interpretation.


## User settings ----

root_dir                <- "D:/Github_repos/Gayini"
EXPLICIT_NODATA_VALUES  <- c(255, 65535, 127, -1)
MIN_VALID_PCT_WARNING   <- 75
TOP_EVENT_N             <- 50


## Required packages ----

required_packages <- c(
  "sf",
  "terra",
  "exactextractr",
  "dplyr",
  "tidyr",
  "readr",
  "stringr",
  "purrr",
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
library(ggplot2)


## Source functions ----

source(file.path(root_dir, "R", "daily_inundation_extraction_functions.R"))


## Input paths ----

plots_clean_path         <- file.path(root_dir, "data_intermediate", "spatial", "plots_clean.gpkg")
raster_catalog_path      <- file.path(root_dir, "data_intermediate", "raster_catalog", "raster_catalog.csv")


## Output folders ----

csv_dir                  <- file.path(root_dir, "Output", "csv")
diagnostics_dir          <- file.path(root_dir, "Output", "diagnostics")
figures_dir              <- file.path(root_dir, "Output", "figures")


## Output paths ----

main_output_path         <- file.path(csv_dir, "06c_daily_inundation_full.csv")
processed_output_path    <- file.path(root_dir, "data_processed", "plot_daily_inundation_timeseries.csv")
selected_rasters_path    <- file.path(diagnostics_dir, "06c_daily_inundation_full_selected_rasters.csv")
checks_path              <- file.path(diagnostics_dir, "06c_daily_inundation_full_checks.csv")
sensor_summary_path      <- file.path(diagnostics_dir, "06c_daily_inundation_full_sensor_summary.csv")
value_summary_path       <- file.path(diagnostics_dir, "06c_daily_inundation_full_value_summary.csv")
coverage_summary_path    <- file.path(diagnostics_dir, "06c_daily_inundation_full_coverage_summary.csv")
plot_summary_path        <- file.path(diagnostics_dir, "06c_daily_inundation_full_plot_summary.csv")
sensor_date_summary_path <- file.path(diagnostics_dir, "06c_daily_inundation_full_sensor_date_summary.csv")
value_by_sensor_path     <- file.path(diagnostics_dir, "06c_daily_inundation_full_value_by_sensor_summary.csv")
top_events_path          <- file.path(diagnostics_dir, "06c_daily_inundation_full_top_inundation_events.csv")
runtime_summary_path     <- file.path(diagnostics_dir, "06c_daily_inundation_full_runtime_summary.csv")


## Figure paths ----

fig_inundated_heatmap_path <- file.path(figures_dir, "06c_daily_inundation_full_daily_inundated_heatmap.png")
fig_sensor_summary_path    <- file.path(figures_dir, "06c_daily_inundation_full_mean_inundated_by_sensor.png")
fig_value_by_sensor_path   <- file.path(figures_dir, "06c_daily_inundation_full_value_area_by_sensor.png")
fig_coverage_heatmap_path  <- file.path(figures_dir, "06c_daily_inundation_full_valid_interpretation_heatmap.png")
fig_cloud_heatmap_path     <- file.path(figures_dir, "06c_daily_inundation_full_cloud_shadow_heatmap.png")


## Create output folders ----

dir.create(csv_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(diagnostics_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(figures_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(dirname(processed_output_path), recursive = TRUE, showWarnings = FALSE)


## Read inputs ----

if (!file.exists(plots_clean_path)) {
  stop("Missing clean plot file: ", plots_clean_path, call. = FALSE)
}

if (!file.exists(raster_catalog_path)) {
  stop("Missing raster catalogue: ", raster_catalog_path, call. = FALSE)
}

plots_clean <- sf::st_read(plots_clean_path, quiet = TRUE)

raster_catalog <- readr::read_csv(raster_catalog_path, show_col_types = FALSE)

message("Clean plots available: ", nrow(plots_clean))
message("Raster catalogue rows: ", nrow(raster_catalog))


## Standardise full daily inundation raster catalogue ----

if (!"plot_id" %in% names(plots_clean)) {
  stop("Clean plots must contain a plot_id column.", call. = FALSE)
}


daily_inundation_catalog <-
  gayini_standardise_daily_inundation_catalog(
  raster_catalog = raster_catalog,
  root           = root_dir)


daily_inundation_catalog <- daily_inundation_catalog |>
  dplyr::distinct(.data$file_path, .keep_all = TRUE) |>
  dplyr::arrange(.data$date_start, .data$sensor, .data$file_name)


message("Daily inundation full rasters: ", nrow(daily_inundation_catalog))
message("Daily inundation full sensors: ", paste(unique(daily_inundation_catalog$sensor), collapse = ", "))


if (nrow(daily_inundation_catalog) == 0) {
  stop("No daily inundation rasters found in raster_catalog.csv.", call. = FALSE)
}


## Select all clean plots ----

selected_plots <- plots_clean |>
  dplyr::arrange(.data$plot_id)

selected_rasters <- daily_inundation_catalog

message("Selected all plots: ", nrow(selected_plots))
message("Selected daily inundation full rasters: ", nrow(selected_rasters))


## Write raster-selection diagnostic before extraction ----

readr::write_csv(selected_rasters, selected_rasters_path)

message("Wrote: ", selected_rasters_path)


## Extract daily inundation ----

extraction <- gayini_extract_daily_inundation_collection(
  raster_catalog          = selected_rasters,
  plots_sf                = selected_plots,
  explicit_nodata_values  = EXPLICIT_NODATA_VALUES
)


## Checks ----

expected_rows <- nrow(selected_plots) * nrow(selected_rasters)

checks <- gayini_make_daily_inundation_checks(
  extraction    = extraction,
  expected_rows = expected_rows
)

extraction_for_summary <- extraction |>
  dplyr::mutate(
    raster_res_x_group = round(.data$raster_res_x, 3),
    raster_res_y_group = round(.data$raster_res_y, 3)
  )

sensor_summary <- extraction_for_summary |>
  dplyr::group_by(
    .data$sensor,
    .data$sensor_evidence,
    .data$raster_res_x_group,
    .data$raster_res_y_group) |>

  dplyr::summarise(
    rasters                         = dplyr::n_distinct(.data$file_name),
    rows                            = dplyr::n(),
    mean_daily_inundated_pct        = mean(.data$daily_inundated_pct, na.rm = TRUE),
    max_daily_inundated_pct         = max(.data$daily_inundated_pct, na.rm = TRUE),
    mean_ors_water_pct              = mean(.data$value_2_ors_water_pct, na.rm = TRUE),
    mean_cloud_shadow_pct           = mean(.data$value_3_cloud_shadow_pct, na.rm = TRUE),
    mean_valid_interpretation_pct   = mean(.data$valid_interpretation_pct, na.rm = TRUE),
    min_valid_interpretation_pct    = min(.data$valid_interpretation_pct, na.rm = TRUE),
    .groups                         = "drop")

value_summary <- extraction |>
  dplyr::summarise(
    rows                             = dplyr::n(),
    rasters                          = dplyr::n_distinct(.data$file_name),
    plots                            = dplyr::n_distinct(.data$plot_id),
    mean_value_0_not_inundated_pct   = mean(.data$value_0_not_inundated_pct, na.rm = TRUE),
    mean_value_1_inundated_pct       = mean(.data$value_1_inundated_pct, na.rm = TRUE),
    mean_value_2_ors_water_pct       = mean(.data$value_2_ors_water_pct, na.rm = TRUE),
    mean_value_3_cloud_shadow_pct    = mean(.data$value_3_cloud_shadow_pct, na.rm = TRUE),
    max_value_2_ors_water_pct        = max(.data$value_2_ors_water_pct, na.rm = TRUE),
    max_value_3_cloud_shadow_pct     = max(.data$value_3_cloud_shadow_pct, na.rm = TRUE),
    max_other_value_area_pct         = max(.data$other_value_area_pct, na.rm = TRUE),
    max_explicit_nodata_area_pct     = max(.data$explicit_nodata_area_pct, na.rm = TRUE))

coverage_summary <- extraction |>
  dplyr::count(.data$valid_coverage_status, name = "rows") |>
  dplyr::mutate(percent = 100 * .data$rows / sum(.data$rows))

plot_summary <- extraction |>
  dplyr::group_by(.data$plot_id) |>
  dplyr::summarise(
    rasters                       = dplyr::n_distinct(.data$file_name),
    mean_daily_inundated_pct      = mean(.data$daily_inundated_pct, na.rm = TRUE),
    max_daily_inundated_pct       = max(.data$daily_inundated_pct, na.rm = TRUE),
    mean_ors_water_pct            = mean(.data$value_2_ors_water_pct, na.rm = TRUE),
    max_ors_water_pct             = max(.data$value_2_ors_water_pct, na.rm = TRUE),
    mean_cloud_shadow_pct         = mean(.data$value_3_cloud_shadow_pct, na.rm = TRUE),
    max_cloud_shadow_pct          = max(.data$value_3_cloud_shadow_pct, na.rm = TRUE),
    min_valid_interpretation_pct  = min(.data$valid_interpretation_pct, na.rm = TRUE),
    .groups                       = "drop") |>

  dplyr::arrange(dplyr::desc(.data$mean_daily_inundated_pct))

sensor_date_summary <- extraction |>
  dplyr::group_by(.data$sensor, .data$date_start, .data$file_name) |>
  dplyr::summarise(
    plots                         = dplyr::n_distinct(.data$plot_id),
    mean_daily_inundated_pct      = mean(.data$daily_inundated_pct, na.rm = TRUE),
    max_daily_inundated_pct       = max(.data$daily_inundated_pct, na.rm = TRUE),
    mean_ors_water_pct            = mean(.data$value_2_ors_water_pct, na.rm = TRUE),
    max_ors_water_pct             = max(.data$value_2_ors_water_pct, na.rm = TRUE),
    mean_cloud_shadow_pct         = mean(.data$value_3_cloud_shadow_pct, na.rm = TRUE),
    max_cloud_shadow_pct          = max(.data$value_3_cloud_shadow_pct, na.rm = TRUE),
    min_valid_interpretation_pct  = min(.data$valid_interpretation_pct, na.rm = TRUE),
    .groups                       = "drop") |>

  dplyr::arrange(.data$date_start, .data$sensor, .data$file_name)


value_by_sensor_summary <- extraction |>
  dplyr::group_by(.data$sensor) |>
  dplyr::summarise(
    mean_not_inundated_pct       = mean(.data$value_0_not_inundated_pct, na.rm = TRUE),
    mean_inundated_pct           = mean(.data$value_1_inundated_pct, na.rm = TRUE),
    mean_ors_water_pct           = mean(.data$value_2_ors_water_pct, na.rm = TRUE),
    mean_cloud_shadow_pct        = mean(.data$value_3_cloud_shadow_pct, na.rm = TRUE),
    mean_other_value_pct         = mean(.data$other_value_area_pct, na.rm = TRUE),
    mean_explicit_nodata_pct     = mean(.data$explicit_nodata_area_pct, na.rm = TRUE),
    .groups                      = "drop"
  )

top_events <- extraction |>
  dplyr::arrange(dplyr::desc(.data$daily_inundated_pct)) |>
  dplyr::slice_head(n = TOP_EVENT_N)


runtime_summary <- extraction |>
  dplyr::group_by(.data$sensor, .data$file_name, .data$date_start) |>
  dplyr::summarise(
    extraction_elapsed_seconds = dplyr::first(.data$extraction_elapsed_seconds),
    rows                       = dplyr::n(),
    plots                      = dplyr::n_distinct(.data$plot_id),
    .groups                    = "drop") |>

  dplyr::arrange(dplyr::desc(.data$extraction_elapsed_seconds))


## Write outputs ----

readr::write_csv(extraction, main_output_path)
readr::write_csv(extraction, processed_output_path)
readr::write_csv(checks, checks_path)
readr::write_csv(sensor_summary, sensor_summary_path)
readr::write_csv(value_summary, value_summary_path)
readr::write_csv(coverage_summary, coverage_summary_path)
readr::write_csv(plot_summary, plot_summary_path)
readr::write_csv(sensor_date_summary, sensor_date_summary_path)
readr::write_csv(value_by_sensor_summary, value_by_sensor_path)
readr::write_csv(top_events, top_events_path)
readr::write_csv(runtime_summary, runtime_summary_path)


message("Wrote: ", main_output_path)
message("Wrote: ", processed_output_path)
message("Wrote: ", checks_path)
message("Wrote: ", sensor_summary_path)
message("Wrote: ", value_summary_path)
message("Wrote: ", coverage_summary_path)
message("Wrote: ", plot_summary_path)
message("Wrote: ", sensor_date_summary_path)
message("Wrote: ", value_by_sensor_path)
message("Wrote: ", top_events_path)
message("Wrote: ", runtime_summary_path)


## Prepare plotting data ----

value_long <- extraction |>
  dplyr::select(
    .data$plot_id,
    .data$date_start,
    .data$sensor,
    .data$file_name,
    .data$value_0_not_inundated_pct,
    .data$value_1_inundated_pct,
    .data$value_2_ors_water_pct,
    .data$value_3_cloud_shadow_pct) |>

  tidyr::pivot_longer(
    cols      = dplyr::starts_with("value_"),
    names_to  = "daily_value_label",
    values_to = "area_pct") |>

  dplyr::mutate(
    daily_value_label = dplyr::case_when(
      .data$daily_value_label == "value_0_not_inundated_pct" ~ "0 not inundated",
      .data$daily_value_label == "value_1_inundated_pct" ~ "1 inundated",
      .data$daily_value_label == "value_2_ors_water_pct" ~ "2 ORS water",
      .data$daily_value_label == "value_3_cloud_shadow_pct" ~ "3 cloud shadow",
      TRUE ~ .data$daily_value_label))

value_date_sensor_summary <- value_long |>
  dplyr::group_by(.data$sensor, .data$date_start, .data$daily_value_label) |>
  dplyr::summarise(mean_area_pct = mean(.data$area_pct, na.rm = TRUE), .groups = "drop")


## Figure: daily inundated heatmap ----

fig_inundated_heatmap <- ggplot(extraction, aes(x = date_start, y = plot_id, fill = daily_inundated_pct)) +
  geom_tile() +
  facet_grid(sensor ~ ., scales = "free_y", space = "free_y") +

  labs(
    title = "06c daily inundation full extraction: area inundated",
    subtitle = "Primary metric: daily_inundated_pct = area where value == 1; all plots, full daily raster time series",
    x = "Raster date",
    y = "Plot",
    fill = "Inundated (%)") +

  scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
  theme_bw(base_size = 9) +

  theme(
    plot.title = element_text(size = 13),
    plot.subtitle = element_text(size = 9),
    strip.text.y = element_text(size = 8),
    axis.text.x = element_text(size = 7, angle = 45, hjust = 1),
    axis.text.y = element_text(size = 5),
    legend.position = "bottom")

ggsave(fig_inundated_heatmap_path, fig_inundated_heatmap, width = 16, height = 14, dpi = 300)

message("Wrote: ", fig_inundated_heatmap_path)


## Figure: mean inundated by sensor ----

fig_sensor_summary <- ggplot(sensor_date_summary, aes(x = date_start, y = mean_daily_inundated_pct, group = sensor)) +
  geom_line(aes(linetype = sensor), linewidth = 0.4, alpha = 0.85) +
  geom_point(aes(shape = sensor), size = 1.8, alpha = 0.85) +

  labs(
    title = "06c daily inundation full extraction: mean inundation by sensor",
    subtitle = "Diagnostic only; sensor groups are not temporally interchangeable",
    x = "Raster date",
    y = "Mean area inundated across plots (%)",
    linetype = "Sensor",
    shape = "Sensor") +

  scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
  theme_bw(base_size = 9) +
  theme(
    plot.title = element_text(size = 13),
    plot.subtitle = element_text(size = 9),
    axis.text.x = element_text(size = 7, angle = 45, hjust = 1),
    legend.position = "bottom")

ggsave(fig_sensor_summary_path, fig_sensor_summary, width = 14, height = 7, dpi = 300)

message("Wrote: ", fig_sensor_summary_path)


## Figure: value areas by sensor ----

fig_value_by_sensor <- ggplot(value_date_sensor_summary, aes(x = date_start, y = mean_area_pct, group = sensor)) +
  geom_line(aes(linetype = sensor), linewidth = 0.35, alpha = 0.85) +
  geom_point(aes(shape = sensor), size = 1.5, alpha = 0.85) +
  facet_wrap(~ daily_value_label, ncol = 2, scales = "free_y") +
  labs(
    title = "06c daily inundation full extraction: mean value-area percentages",
    subtitle = "Expected legend: 0 not inundated; 1 inundated; 2 ORS water; 3 cloud shadow",
    x = "Raster date",
    y = "Mean area across plots (%)",
    linetype = "Sensor",
    shape = "Sensor") +

  scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
  theme_bw(base_size = 9) +
  theme(
    plot.title = element_text(size = 13),
    plot.subtitle = element_text(size = 9),
    axis.text.x = element_text(size = 7, angle = 45, hjust = 1),
    strip.text = element_text(size = 8),
    legend.position = "bottom")

ggsave(fig_value_by_sensor_path, fig_value_by_sensor, width = 15, height = 8, dpi = 300)

message("Wrote: ", fig_value_by_sensor_path)


## Figure: valid interpretation heatmap ----

fig_coverage_heatmap <- ggplot(extraction, aes(x = date_start, y = plot_id, fill = valid_interpretation_pct)) +
  geom_tile() +
  facet_grid(sensor ~ ., scales = "free_y", space = "free_y") +

  labs(
    title = "06c daily inundation full extraction: valid interpretation area",
    subtitle = "Coverage excludes cloud shadow, explicit NoData, and unexpected values",
    x = "Raster date",
    y = "Plot",
    fill = "Valid area (%)") +

  scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
  theme_bw(base_size = 9) +
  theme(
    plot.title = element_text(size = 13),
    plot.subtitle = element_text(size = 9),
    strip.text.y = element_text(size = 8),
    axis.text.x = element_text(size = 7, angle = 45, hjust = 1),
    axis.text.y = element_text(size = 5),
    legend.position = "bottom")

ggsave(fig_coverage_heatmap_path, fig_coverage_heatmap, width = 16, height = 14, dpi = 300)

message("Wrote: ", fig_coverage_heatmap_path)


## Figure: cloud shadow heatmap ----

fig_cloud_heatmap <- ggplot(extraction, aes(x = date_start, y = plot_id, fill = value_3_cloud_shadow_pct)) +
  geom_tile() +
  facet_grid(sensor ~ ., scales = "free_y", space = "free_y") +

  labs(
    title = "06c daily inundation full extraction: cloud shadow area",
    subtitle = "Value 3 interpreted as cloud shadow based on SEED/Data.NSW metadata",
    x = "Raster date",
    y = "Plot",
    fill = "Cloud shadow (%)") +

  scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
  theme_bw(base_size = 9) +

  theme(
    plot.title = element_text(size = 13),
    plot.subtitle = element_text(size = 9),
    strip.text.y = element_text(size = 8),
    axis.text.x = element_text(size = 7, angle = 45, hjust = 1),
    axis.text.y = element_text(size = 5),
    legend.position = "bottom")

ggsave(fig_cloud_heatmap_path, fig_cloud_heatmap, width = 16, height = 14, dpi = 300)

message("Wrote: ", fig_cloud_heatmap_path)


## Finish ----

message("Daily inundation 06c full extraction complete.")
message("Rows written: ", nrow(extraction))
message("Expected rows: ", expected_rows)
message("Primary output: ", main_output_path)
message("Processed output: ", processed_output_path)
message("Review diagnostics and figures before combining daily inundation with annual inundation and ground cover.")


if (any(checks$check == "row_count_matches" & checks$value == "FALSE")) {
  warning("Daily inundation 06c row count did not match expectation. Review checks before continuing.", call. = FALSE)
}

if (any(extraction$other_value_area_pct > 0, na.rm = TRUE)) {
  warning("Unexpected raster values were detected. Review other_value_area_pct before continuing.", call. = FALSE)
}

if (any(extraction$valid_interpretation_pct < MIN_VALID_PCT_WARNING, na.rm = TRUE)) {
  warning("Some daily inundation rows have low valid interpretation coverage. Review coverage diagnostics.", call. = FALSE)
}




####################################################################################################
############################################ TBC ###################################################
####################################################################################################
