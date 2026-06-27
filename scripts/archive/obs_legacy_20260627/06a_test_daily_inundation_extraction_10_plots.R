## 06a daily inundation extraction smoke test ----

## Purpose:
## Test extraction of the NSW inland floodplain wetland daily inundation rasters.
## These rasters are mixed-sensor daily maps, not Sentinel-only rasters.
## Expected values, based on SEED/Data.NSW metadata:
## 0 = not inundated
## 1 = inundated
## 2 = off-river storage with water
## 3 = cloud shadow
## Legend should still be confirmed with Adrian before final interpretation.


## User settings ----

root_dir                 <- "D:/Github_repos/Gayini"

TARGET_PLOT_COUNT        <- 10

TARGET_RASTER_COUNT      <- 12

INCLUDE_EDGE_PLOT_ID     <- "GA_029"

EXPLICIT_NODATA_VALUES   <- c(255, 65535, 127, -1)


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


## Paths ----

plots_clean_path         <- file.path(root_dir, "data_intermediate", "spatial", "plots_clean.gpkg")

raster_catalog_path      <- file.path(root_dir, "data_intermediate", "raster_catalog", "raster_catalog.csv")

csv_dir                  <- file.path(root_dir, "Output", "csv")

diagnostics_dir          <- file.path(root_dir, "Output", "diagnostics")

figures_dir              <- file.path(root_dir, "Output", "figures")


## Output paths ----

main_output_path         <- file.path(csv_dir, "06a_daily_inundation_10_plots.csv")

selected_plots_path      <- file.path(diagnostics_dir, "06a_daily_inundation_10_plots_selected_plots.csv")

selected_rasters_path    <- file.path(diagnostics_dir, "06a_daily_inundation_10_plots_selected_rasters.csv")

checks_path              <- file.path(diagnostics_dir, "06a_daily_inundation_10_plots_checks.csv")

sensor_summary_path      <- file.path(diagnostics_dir, "06a_daily_inundation_10_plots_sensor_summary.csv")

value_summary_path       <- file.path(diagnostics_dir, "06a_daily_inundation_10_plots_value_summary.csv")

coverage_summary_path    <- file.path(diagnostics_dir, "06a_daily_inundation_10_plots_coverage_summary.csv")

plot_summary_path        <- file.path(diagnostics_dir, "06a_daily_inundation_10_plots_plot_summary.csv")


## Figure paths ----

fig_daily_inundated_path <- file.path(figures_dir, "06a_daily_inundation_10_plots_daily_inundated_pct.png")

fig_value_pct_path       <- file.path(figures_dir, "06a_daily_inundation_10_plots_value_area_percentages.png")

fig_coverage_path        <- file.path(figures_dir, "06a_daily_inundation_10_plots_valid_interpretation_coverage.png")

fig_sensor_summary_path  <- file.path(figures_dir, "06a_daily_inundation_10_plots_sensor_value_summary.png")

fig_cloud_shadow_path    <- file.path(figures_dir, "06a_daily_inundation_10_plots_cloud_shadow_pct.png")


## Create output folders ----

dir.create(csv_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(diagnostics_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(figures_dir, recursive = TRUE, showWarnings = FALSE)


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


## Standardise daily inundation catalogue ----

if (!"plot_id" %in% names(plots_clean)) {
  stop("Clean plots must contain a plot_id column.", call. = FALSE)
}

daily_inundation_catalog <- gayini_standardise_daily_inundation_catalog(
  raster_catalog = raster_catalog,
  root           = root_dir
)

message("Daily inundation rasters found: ", nrow(daily_inundation_catalog))

message("Daily inundation sensors: ", paste(unique(daily_inundation_catalog$sensor), collapse = ", "))

if (nrow(daily_inundation_catalog) == 0) {
  stop("No daily inundation rasters found. Check catalogue paths and filename parsing.", call. = FALSE)
}


## Select test plots ----

selected_plots <- gayini_select_spread_plots(
  plots_sf        = plots_clean,
  n_plots         = TARGET_PLOT_COUNT,
  include_plot_id = INCLUDE_EDGE_PLOT_ID
)

message("Selected test plots: ", paste(selected_plots$plot_id, collapse = ", "))


## Select test rasters ----

selected_rasters <- gayini_select_daily_inundation_dev_rasters(
  catalog  = daily_inundation_catalog,
  target_n = TARGET_RASTER_COUNT
)

message("Daily inundation test rasters: ", nrow(selected_rasters))

message("Daily inundation test sensors: ", paste(unique(selected_rasters$sensor), collapse = ", "))


## Write selection diagnostics before extraction ----

readr::write_csv(sf::st_drop_geometry(selected_plots), selected_plots_path)

readr::write_csv(selected_rasters, selected_rasters_path)

message("Wrote: ", selected_plots_path)

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

sensor_summary <- extraction |>
  dplyr::group_by(.data$sensor, .data$sensor_evidence, .data$raster_res_x, .data$raster_res_y) |>
  dplyr::summarise(
    rasters = dplyr::n_distinct(.data$file_name),
    rows = dplyr::n(),
    mean_daily_inundated_pct = mean(.data$daily_inundated_pct, na.rm = TRUE),
    mean_cloud_shadow_pct = mean(.data$value_3_cloud_shadow_pct, na.rm = TRUE),
    mean_valid_interpretation_pct = mean(.data$valid_interpretation_pct, na.rm = TRUE),
    .groups = "drop"
  )

value_summary <- extraction |>
  dplyr::summarise(
    rows = dplyr::n(),
    rasters = dplyr::n_distinct(.data$file_name),
    plots = dplyr::n_distinct(.data$plot_id),
    mean_value_0_not_inundated_pct = mean(.data$value_0_not_inundated_pct, na.rm = TRUE),
    mean_value_1_inundated_pct = mean(.data$value_1_inundated_pct, na.rm = TRUE),
    mean_value_2_ors_water_pct = mean(.data$value_2_ors_water_pct, na.rm = TRUE),
    mean_value_3_cloud_shadow_pct = mean(.data$value_3_cloud_shadow_pct, na.rm = TRUE),
    max_other_value_area_pct = max(.data$other_value_area_pct, na.rm = TRUE),
    max_explicit_nodata_area_pct = max(.data$explicit_nodata_area_pct, na.rm = TRUE)
  )

coverage_summary <- extraction |>
  dplyr::count(.data$valid_coverage_status, name = "rows") |>
  dplyr::mutate(percent = 100 * .data$rows / sum(.data$rows))

plot_summary <- extraction |>
  dplyr::group_by(.data$plot_id) |>
  dplyr::summarise(
    rasters = dplyr::n_distinct(.data$file_name),
    mean_daily_inundated_pct = mean(.data$daily_inundated_pct, na.rm = TRUE),
    max_daily_inundated_pct = max(.data$daily_inundated_pct, na.rm = TRUE),
    mean_cloud_shadow_pct = mean(.data$value_3_cloud_shadow_pct, na.rm = TRUE),
    min_valid_interpretation_pct = min(.data$valid_interpretation_pct, na.rm = TRUE),
    .groups = "drop"
  ) |>
  dplyr::arrange(dplyr::desc(.data$mean_daily_inundated_pct))


## Write outputs ----

readr::write_csv(extraction, main_output_path)

readr::write_csv(checks, checks_path)

readr::write_csv(sensor_summary, sensor_summary_path)

readr::write_csv(value_summary, value_summary_path)

readr::write_csv(coverage_summary, coverage_summary_path)

readr::write_csv(plot_summary, plot_summary_path)

message("Wrote: ", main_output_path)

message("Wrote: ", checks_path)

message("Wrote: ", sensor_summary_path)

message("Wrote: ", value_summary_path)

message("Wrote: ", coverage_summary_path)

message("Wrote: ", plot_summary_path)


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
    .data$value_3_cloud_shadow_pct
  ) |>
  tidyr::pivot_longer(
    cols      = dplyr::starts_with("value_"),
    names_to  = "daily_value_label",
    values_to = "area_pct"
  ) |>
  dplyr::mutate(
    daily_value_label = dplyr::case_when(
      .data$daily_value_label == "value_0_not_inundated_pct" ~ "0 not inundated",
      .data$daily_value_label == "value_1_inundated_pct" ~ "1 inundated",
      .data$daily_value_label == "value_2_ors_water_pct" ~ "2 ORS water",
      .data$daily_value_label == "value_3_cloud_shadow_pct" ~ "3 cloud shadow",
      TRUE ~ .data$daily_value_label
    )
  )

sensor_value_summary <- value_long |>
  dplyr::group_by(.data$sensor, .data$date_start, .data$daily_value_label) |>
  dplyr::summarise(mean_area_pct = mean(.data$area_pct, na.rm = TRUE), .groups = "drop")


## Figure: daily inundated percentage ----

fig_daily_inundated <- ggplot(extraction, aes(x = date_start, y = daily_inundated_pct)) +
  geom_line(aes(group = plot_id), linewidth = 0.25, alpha = 0.45) +
  geom_point(aes(shape = sensor), size = 1.8, alpha = 0.85) +
  facet_wrap(~ plot_id, ncol = 2) +
  labs(
    title = "06a daily inundation smoke test: area inundated",
    subtitle = "Primary provisional metric: daily_inundated_pct = area where value == 1",
    x = "Raster date",
    y = "Inundated area (%)",
    shape = "Sensor"
  ) +
  theme_bw(base_size = 9) +
  theme(
    plot.title = element_text(size = 13),
    plot.subtitle = element_text(size = 9),
    strip.text = element_text(size = 8),
    axis.text.x = element_text(size = 7, angle = 45, hjust = 1),
    legend.position = "bottom"
  )

ggsave(fig_daily_inundated_path, fig_daily_inundated, width = 12, height = 12, dpi = 300)

message("Wrote: ", fig_daily_inundated_path)


## Figure: value-area percentages ----

fig_value_pct <- ggplot(value_long, aes(x = date_start, y = area_pct, group = daily_value_label)) +
  geom_line(linewidth = 0.25, alpha = 0.65) +
  geom_point(aes(shape = sensor), size = 1.3, alpha = 0.85) +
  facet_wrap(~ plot_id, ncol = 2) +
  labs(
    title = "06a daily inundation smoke test: value-area percentages",
    subtitle = "Expected legend: 0 not inundated; 1 inundated; 2 ORS water; 3 cloud shadow",
    x = "Raster date",
    y = "Area within plot (%)",
    shape = "Sensor",
    colour = "Raster value"
  ) +
  theme_bw(base_size = 9) +
  theme(
    plot.title = element_text(size = 13),
    plot.subtitle = element_text(size = 9),
    strip.text = element_text(size = 8),
    axis.text.x = element_text(size = 7, angle = 45, hjust = 1),
    legend.position = "bottom"
  )

ggsave(fig_value_pct_path, fig_value_pct, width = 12, height = 12, dpi = 300)

message("Wrote: ", fig_value_pct_path)


## Figure: valid interpretation coverage ----

fig_coverage <- ggplot(extraction, aes(x = date_start, y = valid_interpretation_pct)) +
  geom_hline(yintercept = 75, linetype = "dashed", linewidth = 0.25) +
  geom_point(aes(shape = sensor), size = 1.8, alpha = 0.85) +
  facet_wrap(~ plot_id, ncol = 2) +
  labs(
    title = "06a daily inundation smoke test: valid interpretation coverage",
    subtitle = "Coverage excludes cloud shadow, explicit NoData, and unexpected values",
    x = "Raster date",
    y = "Valid interpretation area (%)",
    shape = "Sensor"
  ) +
  theme_bw(base_size = 9) +
  theme(
    plot.title = element_text(size = 13),
    plot.subtitle = element_text(size = 9),
    strip.text = element_text(size = 8),
    axis.text.x = element_text(size = 7, angle = 45, hjust = 1),
    legend.position = "bottom"
  )

ggsave(fig_coverage_path, fig_coverage, width = 12, height = 12, dpi = 300)

message("Wrote: ", fig_coverage_path)


## Figure: sensor value summary ----

fig_sensor_summary <- ggplot(sensor_value_summary, aes(x = date_start, y = mean_area_pct, group = daily_value_label)) +
  geom_line(linewidth = 0.35, alpha = 0.75) +
  geom_point(size = 1.8, alpha = 0.85) +
  facet_grid(sensor ~ daily_value_label) +
  labs(
    title = "06a daily inundation smoke test: mean value percentages by sensor",
    subtitle = "Diagnostic only; checks whether L7, L8, S2 and inferred S2 rasters behave similarly",
    x = "Raster date",
    y = "Mean area across selected plots (%)"
  ) +
  theme_bw(base_size = 9) +
  theme(
    plot.title = element_text(size = 13),
    plot.subtitle = element_text(size = 9),
    strip.text = element_text(size = 8),
    axis.text.x = element_text(size = 7, angle = 45, hjust = 1),
    legend.position = "bottom"
  )

ggsave(fig_sensor_summary_path, fig_sensor_summary, width = 14, height = 8, dpi = 300)

message("Wrote: ", fig_sensor_summary_path)


## Figure: cloud shadow percentage ----

fig_cloud_shadow <- ggplot(extraction, aes(x = date_start, y = value_3_cloud_shadow_pct)) +
  geom_point(aes(shape = sensor), size = 1.8, alpha = 0.85) +
  facet_wrap(~ plot_id, ncol = 2) +
  labs(
    title = "06a daily inundation smoke test: cloud shadow area",
    subtitle = "Value 3 interpreted as cloud shadow based on SEED/Data.NSW metadata",
    x = "Raster date",
    y = "Cloud shadow area (%)",
    shape = "Sensor"
  ) +
  theme_bw(base_size = 9) +
  theme(
    plot.title = element_text(size = 13),
    plot.subtitle = element_text(size = 9),
    strip.text = element_text(size = 8),
    axis.text.x = element_text(size = 7, angle = 45, hjust = 1),
    legend.position = "bottom"
  )

ggsave(fig_cloud_shadow_path, fig_cloud_shadow, width = 12, height = 12, dpi = 300)

message("Wrote: ", fig_cloud_shadow_path)


## Finish ----

message("Daily inundation 06a smoke test complete.")

message("Rows written: ", nrow(extraction))

message("Expected rows: ", expected_rows)

message("Primary output: ", main_output_path)

message("Review diagnostics and figures before scaling to 06b.")

if (any(checks$check == "row_count_matches" & checks$value == "FALSE")) {
  warning("Daily inundation 06a row count did not match expectation. Review checks before continuing.", call. = FALSE)
}

if (any(extraction$other_value_area_pct > 0, na.rm = TRUE)) {
  warning("Unexpected raster values were detected. Review other_value_area_pct before continuing.", call. = FALSE)
}

if (any(extraction$valid_coverage_status != "adequate_coverage", na.rm = TRUE)) {
  warning("Some daily inundation rows have low valid interpretation coverage. Review coverage diagnostics.", call. = FALSE)
}
