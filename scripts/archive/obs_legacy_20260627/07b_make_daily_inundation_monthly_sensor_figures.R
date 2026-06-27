####################################################################################################


## GAYINI REMOTE SENSING PROJECT


## 07b_make_daily_inundation_monthly_sensor_figures.R


####################################################################################################


## Purpose ----


## Create Adrian-review daily-inundation figures from the completed 06c full
## daily-inundation extraction.


## The existing 06c heatmap is useful as a whole-dataset diagnostic but too dense
## for review slides. This script:
##
##   1. Aggregates daily observations to plot × sensor × month.
##   2. Writes one heatmap PNG per sensor, instead of faceting all sensors together.
##   3. Labels only every fifth plot on the y-axis.
##   4. Uses larger text suitable for PowerPoint.
##
## The main metric is monthly mean daily_inundated_pct. The script also writes
## optional valid-interpretation and cloud-shadow heatmaps by sensor.


## This script does not rerun extraction.


## Setup ----


default_root <- "D:/Github_repos/Gayini"


helper_path <- file.path(default_root, "R", "gayini_review_figure_functions.R")


if (!file.exists(helper_path)) {
  helper_path <- file.path(getwd(), "R", "gayini_review_figure_functions.R")
}


if (!file.exists(helper_path)) {
  stop(
    "Could not find R/gayini_review_figure_functions.R. Copy the supplied R/ helper file into the project root first.",
    call. = FALSE
  )
}


source(helper_path)


root_dir <- gayini_review_find_root(default_root = default_root)


required_packages <- c(
  "dplyr",
  "tidyr",
  "readr",
  "ggplot2",
  "lubridate",
  "stringr",
  "tibble"
)


gayini_review_check_packages(required_packages)


library(dplyr)
library(tidyr)
library(readr)
library(ggplot2)
library(lubridate)
library(stringr)
library(tibble)


## User settings ----


PLOT_LABEL_EVERY_N <- 5


## The heatmap metric is monthly mean inundated area. Monthly max is also written
## to the CSV and can be substituted into the plotting function if needed.

MAIN_METRIC <- "monthly_mean_daily_inundated_pct"


WRITE_VALID_INTERPRETATION_HEATMAPS <- TRUE
WRITE_CLOUD_SHADOW_HEATMAPS        <- TRUE


FIGURE_WIDTH  <- 14
FIGURE_HEIGHT <- 9
FIGURE_DPI    <- 300
BASE_SIZE     <- 15


## Paths ----


input_path <- file.path(
  root_dir,
  "Output",
  "csv",
  "06c_daily_inundation_full.csv"
)


plot_master_path <- file.path(
  root_dir,
  "data_processed",
  "plot_master.csv"
)


output_dir <- file.path(
  root_dir,
  "Output",
  "figures",
  "review",
  "daily_inundation_monthly"
)


csv_dir <- file.path(
  root_dir,
  "Output",
  "csv",
  "review"
)


gayini_review_make_dir(output_dir)
gayini_review_make_dir(csv_dir)


monthly_output_path <- file.path(
  csv_dir,
  "07b_daily_inundation_monthly_by_sensor_plot.csv"
)


sensor_month_output_path <- file.path(
  csv_dir,
  "07b_daily_inundation_monthly_by_sensor_summary.csv"
)


## Read data ----


gayini_review_required_file(input_path)

daily <- readr::read_csv(input_path, show_col_types = FALSE)


if (file.exists(plot_master_path)) {
  plot_master <- readr::read_csv(plot_master_path, show_col_types = FALSE)
} else {
  plot_master <- daily |>
    dplyr::distinct(.data$plot_id) |>
    dplyr::mutate(treatment = NA_character_, vegetation = NA_character_)
}


required_columns <- c(
  "plot_id",
  "date_start",
  "sensor",
  "daily_inundated_pct",
  "valid_interpretation_pct",
  "value_3_cloud_shadow_pct"
)


missing_columns <- setdiff(required_columns, names(daily))


if (length(missing_columns) > 0) {
  stop(
    "06c daily-inundation table is missing required columns: ",
    paste(missing_columns, collapse = ", "),
    call. = FALSE
  )
}


## Monthly aggregation ----


daily_monthly <- daily |>
  dplyr::mutate(
    date_start = as.Date(.data$date_start),
    month      = lubridate::floor_date(.data$date_start, unit = "month")
  ) |>
  dplyr::group_by(.data$sensor, .data$plot_id, .data$month) |>
  dplyr::summarise(
    monthly_mean_daily_inundated_pct      = gayini_review_safe_mean(.data$daily_inundated_pct),
    monthly_max_daily_inundated_pct       = gayini_review_safe_max(.data$daily_inundated_pct),
    monthly_mean_valid_interpretation_pct = gayini_review_safe_mean(.data$valid_interpretation_pct),
    monthly_min_valid_interpretation_pct  = gayini_review_safe_min(.data$valid_interpretation_pct),
    monthly_mean_cloud_shadow_pct         = gayini_review_safe_mean(.data$value_3_cloud_shadow_pct),
    monthly_max_cloud_shadow_pct          = gayini_review_safe_max(.data$value_3_cloud_shadow_pct),
    n_daily_observations                  = dplyr::n_distinct(.data$date_start),
    .groups                               = "drop"
  ) |>
  dplyr::left_join(
    plot_master |>
      dplyr::select(dplyr::any_of(c("plot_id", "treatment", "vegetation", "area_ha"))),
    by = "plot_id"
  )


sensor_monthly <- daily_monthly |>
  dplyr::group_by(.data$sensor, .data$month) |>
  dplyr::summarise(
    mean_monthly_inundated_pct      = gayini_review_safe_mean(.data$monthly_mean_daily_inundated_pct),
    max_monthly_inundated_pct       = gayini_review_safe_max(.data$monthly_max_daily_inundated_pct),
    mean_valid_interpretation_pct   = gayini_review_safe_mean(.data$monthly_mean_valid_interpretation_pct),
    mean_cloud_shadow_pct           = gayini_review_safe_mean(.data$monthly_mean_cloud_shadow_pct),
    plots_with_observations         = dplyr::n_distinct(.data$plot_id[!is.na(.data$monthly_mean_daily_inundated_pct)]),
    daily_observations_in_month     = sum(.data$n_daily_observations, na.rm = TRUE),
    .groups                         = "drop"
  )


readr::write_csv(daily_monthly, monthly_output_path)
readr::write_csv(sensor_monthly, sensor_month_output_path)


message("Wrote: ", monthly_output_path)
message("Wrote: ", sensor_month_output_path)


## Plot order ----


plot_order <- plot_master |>
  dplyr::select(dplyr::any_of(c("plot_id", "treatment", "vegetation"))) |>
  dplyr::distinct() |>
  dplyr::mutate(plot_number = gayini_review_plot_id_number(.data$plot_id)) |>
  dplyr::arrange(.data$treatment, .data$vegetation, .data$plot_number, .data$plot_id) |>
  dplyr::pull(.data$plot_id)


if (length(plot_order) == 0) {
  plot_order <- gayini_review_order_plot_ids(unique(daily_monthly$plot_id))
}


plot_axis_labels <- setNames(
  gayini_review_label_every_nth(plot_order, n = PLOT_LABEL_EVERY_N),
  plot_order
)


## Plot function ----


make_sensor_heatmap <- function(data, sensor_id, metric_column, fill_label, file_stub, title_metric) {

  sensor_data <- data |>
    dplyr::filter(.data$sensor == sensor_id) |>
    dplyr::mutate(plot_id = factor(.data$plot_id, levels = rev(plot_order)))

  if (nrow(sensor_data) == 0) {
    warning("No data for sensor: ", sensor_id)
    return(invisible(NULL))
  }

  metric_values <- sensor_data[[metric_column]]

  p <- ggplot2::ggplot(
    sensor_data,
    ggplot2::aes(
      x    = .data$month,
      y    = .data$plot_id,
      fill = .data[[metric_column]]
    )
  ) +
    ggplot2::geom_tile() +
    ggplot2::labs(
      title    = paste0("Daily inundation by month: ", sensor_id, " — ", title_metric),
      subtitle = "Monthly aggregation of 06c daily extraction; y-axis labels show every fifth plot.",
      x        = "Month",
      y        = "Plot ID",
      fill     = fill_label
    ) +
    ggplot2::scale_x_date(date_breaks = "6 months", date_labels = "%Y-%m") +
    ggplot2::scale_y_discrete(labels = plot_axis_labels) +
    ggplot2::scale_fill_gradient(
      low      = "grey95",
      high     = "steelblue",
      limits   = c(0, max(100, metric_values, na.rm = TRUE)),
      na.value = "grey80"
    ) +
    gayini_review_theme(base_size = BASE_SIZE) +
    ggplot2::theme(
      axis.text.x       = ggplot2::element_text(angle = 45, hjust = 1),
      axis.text.y       = ggplot2::element_text(size = BASE_SIZE - 4),
      legend.key.width  = grid::unit(2.8, "cm"),
      legend.key.height = grid::unit(0.35, "cm")
    )

  output_path <- file.path(
    output_dir,
    paste0("07b_monthly_", file_stub, "_sensor_", gayini_review_clean_filename(sensor_id), ".png")
  )

  gayini_review_save_png(
    plot   = p,
    path   = output_path,
    width  = FIGURE_WIDTH,
    height = FIGURE_HEIGHT,
    dpi    = FIGURE_DPI
  )

  invisible(output_path)
}


## Main heatmaps by sensor ----


sensor_ids <- sort(unique(daily_monthly$sensor))


for (sensor_id in sensor_ids) {

  make_sensor_heatmap(
    data          = daily_monthly,
    sensor_id     = sensor_id,
    metric_column = "monthly_mean_daily_inundated_pct",
    fill_label    = "Mean inundated (%)",
    file_stub     = "mean_inundated_pct",
    title_metric  = "mean inundated area"
  )

  if (isTRUE(WRITE_VALID_INTERPRETATION_HEATMAPS)) {
    make_sensor_heatmap(
      data          = daily_monthly,
      sensor_id     = sensor_id,
      metric_column = "monthly_mean_valid_interpretation_pct",
      fill_label    = "Valid area (%)",
      file_stub     = "valid_interpretation_pct",
      title_metric  = "valid interpretation area"
    )
  }

  if (isTRUE(WRITE_CLOUD_SHADOW_HEATMAPS)) {
    make_sensor_heatmap(
      data          = daily_monthly,
      sensor_id     = sensor_id,
      metric_column = "monthly_mean_cloud_shadow_pct",
      fill_label    = "Cloud shadow (%)",
      file_stub     = "cloud_shadow_pct",
      title_metric  = "cloud shadow area"
    )
  }
}


## Sensor-summary line plot ----


sensor_summary_plot <- ggplot2::ggplot(
  sensor_monthly,
  ggplot2::aes(
    x      = .data$month,
    y      = .data$mean_monthly_inundated_pct,
    group  = .data$sensor,
    colour = .data$sensor
  )
) +
  ggplot2::geom_line(linewidth = 0.75, na.rm = TRUE) +
  ggplot2::geom_point(size = 1.5, alpha = 0.85, na.rm = TRUE) +
  ggplot2::labs(
    title    = "Daily inundation by month: sensor summary",
    subtitle = "Mean monthly inundated area across all plots; sensor groups are not temporally interchangeable.",
    x        = "Month",
    y        = "Mean inundated area across plots (%)",
    colour   = "Sensor"
  ) +
  ggplot2::scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
  gayini_review_theme(base_size = BASE_SIZE) +
  ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 45, hjust = 1))


sensor_summary_path <- file.path(
  output_dir,
  "07b_monthly_mean_inundated_pct_sensor_summary.png"
)


gayini_review_save_png(
  plot   = sensor_summary_plot,
  path   = sensor_summary_path,
  width  = 13,
  height = 7.5,
  dpi    = FIGURE_DPI
)


## Finish ----


message("07b daily-inundation monthly sensor figures complete.")
message("Figure folder: ", output_dir)
