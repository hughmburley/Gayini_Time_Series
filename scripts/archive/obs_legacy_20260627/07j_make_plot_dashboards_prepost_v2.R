## -----------------------------------------------------------------------------
## Gayini remote sensing workflow
## 07j_make_plot_dashboards_prepost_v2.R
## -----------------------------------------------------------------------------


## Purpose:
## Create selected plot dashboards for Adrian / workshop review.
##
## This version is a full dashboard rework:
##
##   1. Adds a compact context header with treatment, vegetation, area,
##      valid-year counts and review status.
##
##   2. Replaces the simple pre/post inundation bars with a variation-aware
##      pre/post panel:
##        - annual plot values as jittered points,
##        - mean +/- 1 SD from the available annual series,
##        - Step 7 period frequency as labelled diamond markers.
##
##   3. Keeps the simplified ground-cover history:
##        - total vegetation = green / PV + non-green / NPV,
##        - bare ground = TERN/JRSRP band 1,
##        - gaps are not connected across long breaks.
##
##   4. Replaces the annual inundation bar plot with a lollipop-style
##      annual occurrence history. This keeps the discrete annual nature clear
##      while making the panel more comparable to the ground-cover time series.
##
##   5. Keeps the monthly sensor-specific inundation panel optional and off by
##      default. It is useful QA, but not part of the main dashboard by default.


## User settings ----


root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", "D:/Github_repos/Gayini"), winslash = "/", mustWork = TRUE)

DASHBOARD_PLOTS <- NULL
MAX_AUTO_PLOTS <- 12

MANAGEMENT_CHANGE_DATE <- as.Date("2019-07-01")
DEFAULT_PRE_START_DATE <- as.Date("2013-07-01")
DEFAULT_POST_END_DATE <- as.Date("2026-06-30")

GAP_DAYS_FOR_NEW_SEGMENT <- 550
ONLY_ADEQUATE_COVERAGE <- TRUE

## The main dashboard should avoid source clutter. Turn this on only for QA.
INCLUDE_SENSOR_MONTHLY_PANEL <- FALSE

## Annual lower panel style. Current options: "lollipop" or "line".
ANNUAL_HISTORY_STYLE <- "lollipop"

## Use a new output folder so old dashboard PNGs cannot be confused with new ones.
DASHBOARD_VERSION <- "v3"


## Required packages ----


required_packages <- c(
  "dplyr",
  "tidyr",
  "readr",
  "stringr",
  "purrr",
  "ggplot2",
  "magrittr",
  "patchwork",
  "scales"
)

source(file.path(root_dir, "R", "step7_figure_helpers.R"))
gayini_check_packages(required_packages)

library(dplyr)
library(tidyr)
library(readr)
library(stringr)
library(purrr)
library(ggplot2)
library(magrittr)
library(patchwork)
library(scales)


## Local helpers ----


gayini_first_scalar <- function(x, default = NA_character_) {
  if (is.null(x) || length(x) == 0 || all(is.na(x))) {
    return(default)
  }

  x[[1]]
}


gayini_fmt_chr <- function(x, default = "not recorded") {
  x <- gayini_first_scalar(x, default = default)

  if (is.na(x) || x == "") {
    return(default)
  }

  as.character(x)
}


gayini_fmt_num <- function(x, digits = 1, suffix = "", default = "NA") {
  x <- suppressWarnings(as.numeric(gayini_first_scalar(x, default = NA_real_)))

  if (is.na(x)) {
    return(default)
  }

  paste0(sprintf(paste0("%.", digits, "f"), x), suffix)
}


gayini_fmt_signed <- function(x, digits = 1, suffix = "") {
  x <- suppressWarnings(as.numeric(gayini_first_scalar(x, default = NA_real_)))

  if (is.na(x)) {
    return("NA")
  }

  paste0(sprintf(paste0("%+.", digits, "f"), x), suffix)
}


gayini_safe_date <- function(x, default) {
  out <- suppressWarnings(as.Date(gayini_first_scalar(x, default = default)))

  if (is.na(out)) {
    return(default)
  }

  out
}


gayini_wrap <- function(x, width = 130) {
  stringr::str_wrap(as.character(x), width = width)
}


gayini_make_period_for_date <- function(date_plot,
                                        pre_start_date,
                                        management_change_date,
                                        post_end_date) {
  dplyr::case_when(
    is.na(date_plot) ~ NA_character_,
    date_plot < pre_start_date ~ "Historical context",
    date_plot >= pre_start_date & date_plot < management_change_date ~ "Pre",
    date_plot >= management_change_date & date_plot <= post_end_date ~ "Post",
    date_plot > post_end_date ~ "After target period",
    TRUE ~ NA_character_
  )
}


gayini_prepare_annual_history <- function(path, source_label) {
  if (is.na(path) || !file.exists(path)) {
    return(NULL)
  }

  message("Reading annual inundation history: ", path)

  annual_data <- readr::read_csv(path, show_col_types = FALSE) %>%
    gayini_standardise_plot_id(object_name = paste0(source_label, " annual inundation table"))

  date_candidate <- gayini_get_first_existing_column(
    annual_data,
    c("date_midpoint", "date_plot", "date_start", "water_year_start", "start_date"),
    default = NA_character_
  )

  annual_data$date_plot <- suppressWarnings(as.Date(date_candidate))

  annual_data$annual_inundated_pct <- suppressWarnings(as.numeric(gayini_get_first_existing_column(
    annual_data,
    c(
      "annual_inundated_pct",
      "annual_inundated_any_pct",
      "mean_annual_inundated_pct",
      "mean_inundated_pct",
      "inundated_any_pct",
      "area_inundated_pct",
      "inundated_pct"
    ),
    default = NA_real_
  )))

  annual_data$water_year_label <- as.character(gayini_get_first_existing_column(
    annual_data,
    c("water_year", "period_year", "analysis_year", "water_year_label"),
    default = NA_character_
  ))

  annual_data$annual_source_label <- source_label

  if ("valid_coverage_status" %in% names(annual_data)) {
    annual_data <- annual_data %>%
      dplyr::filter(.data$valid_coverage_status == "adequate_coverage" | is.na(.data$valid_coverage_status))
  }

  annual_data %>%
    dplyr::filter(!is.na(.data$date_plot), !is.na(.data$annual_inundated_pct)) %>%
    dplyr::mutate(
      annual_inundated_pct = pmax(pmin(.data$annual_inundated_pct, 100), 0)
    )
}


gayini_make_prepost_variation_plot <- function(plot_row,
                                               annual_plot_data,
                                               management_change_date,
                                               pre_start_date,
                                               post_end_date) {
  step7_points <- tibble::tibble(
    period = factor(c("Pre", "Post"), levels = c("Pre", "Post")),
    step7_frequency_pct = c(
      plot_row$pre_conservation_inundation_frequency_pct,
      plot_row$post_conservation_inundation_frequency_pct
    ),
    step7_label = c(
      paste0("Step 7: ", sprintf("%.1f%%", plot_row$pre_conservation_inundation_frequency_pct)),
      paste0("Step 7: ", sprintf("%.1f%%", plot_row$post_conservation_inundation_frequency_pct))
    )
  )

  annual_period_data <- annual_plot_data %>%
    dplyr::mutate(
      dashboard_period = gayini_make_period_for_date(
        .data$date_plot,
        pre_start_date = pre_start_date,
        management_change_date = management_change_date,
        post_end_date = post_end_date
      )
    ) %>%
    dplyr::filter(.data$dashboard_period %in% c("Pre", "Post")) %>%
    dplyr::mutate(
      period = factor(.data$dashboard_period, levels = c("Pre", "Post"))
    )

  if (nrow(annual_period_data) > 0) {
    annual_summary <- annual_period_data %>%
      dplyr::group_by(.data$period) %>%
      dplyr::summarise(
        n_years = dplyr::n(),
        mean_value = mean(.data$annual_inundated_pct, na.rm = TRUE),
        sd_value = stats::sd(.data$annual_inundated_pct, na.rm = TRUE),
        ymin = pmax(.data$mean_value - .data$sd_value, 0),
        ymax = pmin(.data$mean_value + .data$sd_value, 100),
        .groups = "drop"
      )

    subtitle_text <- paste0(
      "Small points are annual values; black range is mean +/- 1 SD; diamonds are Step 7 period summaries."
    )

    p <- ggplot2::ggplot() +
      ggplot2::geom_boxplot(
        data = annual_period_data,
        ggplot2::aes(x = .data$period, y = .data$annual_inundated_pct),
        width = 0.52,
        fill = "grey94",
        colour = "grey45",
        outlier.shape = NA
      ) +
      ggplot2::geom_jitter(
        data = annual_period_data,
        ggplot2::aes(x = .data$period, y = .data$annual_inundated_pct),
        width = 0.075,
        height = 0,
        size = 2.0,
        alpha = 0.75,
        colour = "grey35"
      ) +
      ggplot2::geom_errorbar(
        data = annual_summary,
        ggplot2::aes(x = .data$period, ymin = .data$ymin, ymax = .data$ymax),
        width = 0.12,
        colour = "black",
        linewidth = 0.65
      ) +
      ggplot2::geom_point(
        data = annual_summary,
        ggplot2::aes(x = .data$period, y = .data$mean_value),
        shape = 21,
        fill = "white",
        colour = "black",
        size = 3.0,
        stroke = 0.7
      ) +
      ggplot2::geom_point(
        data = step7_points,
        ggplot2::aes(x = .data$period, y = .data$step7_frequency_pct, fill = .data$period),
        shape = 23,
        colour = "black",
        size = 4.2,
        stroke = 0.7,
        show.legend = FALSE
      ) +
      ggplot2::geom_text(
        data = step7_points,
        ggplot2::aes(x = .data$period, y = .data$step7_frequency_pct, label = sprintf("%.1f%%", .data$step7_frequency_pct)),
        vjust = -0.85,
        size = 3.4
      ) +
      ggplot2::scale_fill_manual(values = c("Pre" = "grey75", "Post" = "#2166ac")) +
      ggplot2::coord_cartesian(ylim = c(0, 100), clip = "off") +
      ggplot2::labs(
        title = "Pre/post inundation summary",
        subtitle = subtitle_text,
        x = NULL,
        y = "Inundation occurrence / area (%)"
      ) +
      gayini_theme_chart(base_size = 10) +
      ggplot2::theme(
        legend.position = "none",
        axis.text.x = ggplot2::element_text(angle = 0),
        plot.margin = ggplot2::margin(t = 8, r = 8, b = 8, l = 8)
      )
  } else {
    p <- step7_points %>%
      ggplot2::ggplot(ggplot2::aes(x = .data$period, y = .data$step7_frequency_pct, fill = .data$period)) +
      ggplot2::geom_col(width = 0.55, show.legend = FALSE) +
      ggplot2::geom_text(ggplot2::aes(label = sprintf("%.1f%%", .data$step7_frequency_pct)), vjust = -0.35, size = 3.5) +
      ggplot2::ylim(0, 100) +
      ggplot2::scale_fill_manual(values = c("Pre" = "grey65", "Post" = "#2166ac")) +
      ggplot2::labs(
        title = "Pre/post inundation summary",
        subtitle = "Annual plot values were not available; bars show Step 7 period summaries only.",
        x = NULL,
        y = "Frequency (%)"
      ) +
      gayini_theme_chart(base_size = 10) +
      ggplot2::theme(
        legend.position = "none",
        axis.text.x = ggplot2::element_text(angle = 0)
      )
  }

  p
}


gayini_make_annual_history_plot <- function(annual_plot_data,
                                            management_change_date,
                                            pre_start_date,
                                            post_end_date,
                                            annual_history_style = "lollipop") {
  if (nrow(annual_plot_data) == 0) {
    return(ggplot2::ggplot() + ggplot2::annotate("text", x = 0, y = 0, label = "No annual inundation rows for this plot") + ggplot2::theme_void())
  }

  annual_plot_data <- annual_plot_data %>%
    dplyr::arrange(.data$date_plot) %>%
    dplyr::mutate(
      dashboard_period = gayini_make_period_for_date(
        .data$date_plot,
        pre_start_date = pre_start_date,
        management_change_date = management_change_date,
        post_end_date = post_end_date
      ),
      dashboard_period = factor(
        .data$dashboard_period,
        levels = c("Historical context", "Pre", "Post", "After target period")
      )
    )

  source_text <- unique(annual_plot_data$annual_source_label)
  source_text <- source_text[!is.na(source_text)]
  source_text <- if (length(source_text) == 0) "annual inundation table" else source_text[[1]]

  p <- ggplot2::ggplot(annual_plot_data, ggplot2::aes(x = .data$date_plot, y = .data$annual_inundated_pct))

  if (annual_history_style == "line") {
    annual_plot_data <- annual_plot_data %>%
      gayini_add_gap_segments(
        date_col = "date_plot",
        group_cols = c("plot_id"),
        gap_days_for_new_segment = 550
      )

    p <- ggplot2::ggplot(
      annual_plot_data,
      ggplot2::aes(x = .data$date_plot, y = .data$annual_inundated_pct, group = .data$segment_id)
    ) +
      ggplot2::geom_line(colour = "grey45", linewidth = 0.45, na.rm = TRUE) +
      ggplot2::geom_point(ggplot2::aes(fill = .data$dashboard_period), shape = 21, size = 2.1, colour = "black", stroke = 0.25, na.rm = TRUE)
  } else {
    p <- p +
      ggplot2::geom_segment(
        ggplot2::aes(xend = .data$date_plot, y = 0, yend = .data$annual_inundated_pct),
        colour = "grey65",
        linewidth = 0.55,
        na.rm = TRUE
      ) +
      ggplot2::geom_point(
        ggplot2::aes(fill = .data$dashboard_period),
        shape = 21,
        size = 2.2,
        colour = "black",
        stroke = 0.25,
        na.rm = TRUE
      )
  }

  p +
    ggplot2::geom_vline(xintercept = management_change_date, linetype = "dashed", colour = "grey25") +
    ggplot2::coord_cartesian(ylim = c(0, 100)) +
    ggplot2::scale_x_date(date_breaks = "5 years", date_labels = "%Y") +
    ggplot2::scale_fill_manual(
      values = c(
        "Historical context" = "grey70",
        "Pre" = "grey45",
        "Post" = "#2166ac",
        "After target period" = "grey85"
      ),
      drop = FALSE,
      name = "Period"
    ) +
    ggplot2::labs(
      title = "Annual inundation occurrence history",
      subtitle = paste0("Source: ", source_text, ". Discrete annual values; use for hydrological context, not duration."),
      x = "Water year start / representative date",
      y = "Inundated area (%)"
    ) +
    gayini_theme_chart(base_size = 10) +
    ggplot2::theme(
      legend.position = "bottom"
    )
}


gayini_make_context_header <- function(this_plot,
                                       plot_row,
                                       review_note,
                                       management_change_date,
                                       annual_source_label) {
  treatment <- gayini_fmt_chr(plot_row$treatment)
  vegetation <- gayini_fmt_chr(plot_row$vegetation_adrian_group, default = gayini_fmt_chr(plot_row$vegetation))
  vegetation_original <- gayini_fmt_chr(plot_row$vegetation)
  area <- gayini_fmt_num(plot_row$area_ha, digits = 2, suffix = " ha", default = "area not recorded")

  pre_valid <- gayini_fmt_num(plot_row$pre_conservation_valid_year_count, digits = 0, default = "NA")
  post_valid <- gayini_fmt_num(plot_row$post_conservation_valid_year_count, digits = 0, default = "NA")

  title_line <- paste0("Plot dashboard: ", this_plot)

  context_line <- paste0(
    "Treatment: ", treatment,
    " | Vegetation group: ", vegetation,
    " | Area: ", area
  )

  if (!is.na(vegetation_original) && vegetation_original != vegetation && vegetation_original != "not recorded") {
    context_line <- paste0(context_line, " | Original veg: ", vegetation_original)
  }

  summary_line <- paste0(
    "Inundation frequency: Pre = ", gayini_fmt_num(plot_row$pre_conservation_inundation_frequency_pct, digits = 1, suffix = "%"),
    " | Post = ", gayini_fmt_num(plot_row$post_conservation_inundation_frequency_pct, digits = 1, suffix = "%"),
    " | Post - pre = ", gayini_fmt_signed(plot_row$post_minus_pre_inundation_frequency_pct_points, digits = 1, suffix = " ppt"),
    " | Class: ", gayini_change_class_label(plot_row$inundation_change_class)
  )

  support_line <- paste0(
    "Valid years: pre n = ", pre_valid,
    " | post n = ", post_valid,
    " | Review note: ", review_note,
    " | Annual context source: ", annual_source_label
  )

  ggplot2::ggplot() +
    ggplot2::annotate("text", x = 0, y = 1.00, hjust = 0, vjust = 1, size = 5.2, fontface = "bold", label = title_line) +
    ggplot2::annotate("text", x = 0, y = 0.68, hjust = 0, vjust = 1, size = 3.35, label = gayini_wrap(context_line, 150)) +
    ggplot2::annotate("text", x = 0, y = 0.42, hjust = 0, vjust = 1, size = 3.35, label = gayini_wrap(summary_line, 150)) +
    ggplot2::annotate("text", x = 0, y = 0.16, hjust = 0, vjust = 1, size = 3.10, label = gayini_wrap(support_line, 165)) +
    ggplot2::xlim(0, 1) +
    ggplot2::ylim(0, 1) +
    ggplot2::theme_void()
}


## Paths ----


fc_path <- gayini_find_first_existing(c(
  file.path(root_dir, "data_processed", "plot_fractional_cover_timeseries.csv"),
  file.path(root_dir, "Output", "csv", "04c_fractional_cover_full.csv")
))

annual_combined_path <- gayini_find_first_existing(c(
  file.path(root_dir, "Output", "csv", "07j_plot_annual_combined_inundation_summary.csv"),
  file.path(root_dir, "Output", "csv", "07h_plot_annual_combined_inundation_summary.csv"),
  file.path(root_dir, "Output", "csv", "07g_plot_annual_combined_inundation_summary.csv"),
  file.path(root_dir, "Output", "csv", "07f_plot_annual_combined_inundation_summary.csv"),
  file.path(root_dir, "Output", "csv", "07e_plot_annual_combined_inundation_summary.csv"),
  file.path(root_dir, "data_processed", "plot_annual_combined_inundation_summary.csv")
))

annual_landsat_path <- gayini_find_first_existing(c(
  file.path(root_dir, "data_processed", "plot_landsat_inundation_timeseries.csv"),
  file.path(root_dir, "Output", "csv", "05c_landsat_inundation_full.csv")
))

daily_path <- gayini_find_first_existing(c(
  file.path(root_dir, "data_processed", "plot_daily_inundation_timeseries.csv"),
  file.path(root_dir, "Output", "csv", "06c_daily_inundation_full.csv")
))

figure_dir <- file.path(root_dir, "Output", "figures", paste0("07j_plot_dashboards_", DASHBOARD_VERSION))
csv_dir <- file.path(root_dir, "Output", "csv")
diagnostics_dir <- file.path(root_dir, "Output", "diagnostics", paste0("07j_plot_dashboards_", DASHBOARD_VERSION))

dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(csv_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(diagnostics_dir, recursive = TRUE, showWarnings = FALSE)

review_notes_path <- file.path(diagnostics_dir, paste0("07j_plot_dashboard_review_notes_", DASHBOARD_VERSION, ".csv"))


## Read Step 7 plot summary ----


plot_summary <- gayini_read_step7_plot_summary(root_dir) %>%
  dplyr::mutate(
    vegetation_adrian_group = dplyr::case_when(
      "vegetation_adrian_group" %in% names(.) ~ as.character(.data$vegetation_adrian_group),
      .data$vegetation %in% c("Inland Floodplain Shrublands", "Inland Floodplain Swamps") ~ "Inland Floodplain Shrublands / Swamps",
      TRUE ~ as.character(.data$vegetation)
    )
  ) %>%
  gayini_make_period_plot_data()


## Select dashboard plots ----


if (is.null(DASHBOARD_PLOTS)) {
  positive_plots <- plot_summary %>%
    dplyr::arrange(dplyr::desc(.data$post_minus_pre_inundation_frequency_pct_points)) %>%
    dplyr::slice_head(n = 5) %>%
    dplyr::pull(.data$plot_id)

  negative_plots <- plot_summary %>%
    dplyr::arrange(.data$post_minus_pre_inundation_frequency_pct_points) %>%
    dplyr::slice_head(n = 4) %>%
    dplyr::pull(.data$plot_id)

  low_water_plots <- plot_summary %>%
    dplyr::arrange(.data$mean_period_frequency_pct) %>%
    dplyr::slice_head(n = 4) %>%
    dplyr::pull(.data$plot_id)

  DASHBOARD_PLOTS <- unique(c(positive_plots, negative_plots, low_water_plots)) %>%
    utils::head(MAX_AUTO_PLOTS)
}

message("Dashboard plots: ", paste(DASHBOARD_PLOTS, collapse = ", "))


## Read optional time-series data ----


fc_metric_data <- NULL

if (!is.na(fc_path)) {
  fc_metric_data <- gayini_prepare_ground_cover_long(
    fc_path = fc_path,
    only_adequate_coverage = ONLY_ADEQUATE_COVERAGE,
    object_name = "fractional-cover table"
  ) %>%
    gayini_prepare_ground_cover_total_bare()
}


annual_data <- gayini_prepare_annual_history(
  annual_combined_path,
  "Step 7 combined annual rasters"
)

if (is.null(annual_data) || nrow(annual_data) == 0) {
  annual_data <- gayini_prepare_annual_history(
    annual_landsat_path,
    "Annual Landsat/NSW fallback"
  )
}

if (is.null(annual_data) || nrow(annual_data) == 0) {
  annual_data <- NULL
}


daily_data <- NULL

if (INCLUDE_SENSOR_MONTHLY_PANEL && !is.na(daily_path)) {
  daily_data <- readr::read_csv(daily_path, show_col_types = FALSE) %>%
    gayini_standardise_plot_id(object_name = "daily inundation table")

  daily_data$date_plot <- as.Date(gayini_get_first_existing_column(daily_data, c("date_midpoint", "date_start", "date_end")))
  daily_data$month_plot <- as.Date(format(daily_data$date_plot, "%Y-%m-01"))
  daily_data$sensor_plot <- as.character(gayini_get_first_existing_column(daily_data, c("sensor", "sensor_clean", "sensor_evidence"), default = "sensor_unknown"))
}


## Dashboard loop ----


dashboard_index <- tibble::tibble(
  plot_id = character(),
  dashboard_path = character(),
  review_note = character(),
  treatment = character(),
  vegetation = character(),
  vegetation_adrian_group = character(),
  annual_context_source = character()
)

review_notes <- tibble::tibble(
  plot_id = character(),
  review_note = character(),
  dashboard_metric_note = character(),
  remaining_caveat = character()
)

for (this_plot in DASHBOARD_PLOTS) {
  plot_row <- plot_summary %>%
    dplyr::filter(.data$plot_id == !!this_plot) %>%
    dplyr::slice(1)

  if (nrow(plot_row) == 0) next

  review_note <- paste(
    unique(c(plot_row$review_flag %||% "standard review")),
    collapse = "; "
  )

  pre_start_date <- gayini_safe_date(plot_row$pre_start_date, DEFAULT_PRE_START_DATE)
  post_end_date <- gayini_safe_date(plot_row$post_end_date, DEFAULT_POST_END_DATE)
  management_change_date <- gayini_safe_date(plot_row$conservation_date, MANAGEMENT_CHANGE_DATE)

  annual_plot_data <- if (!is.null(annual_data)) {
    annual_data %>%
      dplyr::filter(.data$plot_id == !!this_plot) %>%
      dplyr::arrange(.data$date_plot)
  } else {
    tibble::tibble()
  }

  annual_source_label <- if (nrow(annual_plot_data) > 0) {
    unique(annual_plot_data$annual_source_label)[[1]]
  } else {
    "no annual table found"
  }

  header_plot <- gayini_make_context_header(
    this_plot = this_plot,
    plot_row = plot_row,
    review_note = review_note,
    management_change_date = management_change_date,
    annual_source_label = annual_source_label
  )

  prepost_variation_plot <- gayini_make_prepost_variation_plot(
    plot_row = plot_row,
    annual_plot_data = annual_plot_data,
    management_change_date = management_change_date,
    pre_start_date = pre_start_date,
    post_end_date = post_end_date
  )

  if (!is.null(fc_metric_data)) {
    fc_plot_data <- fc_metric_data %>%
      dplyr::filter(.data$plot_id == !!this_plot) %>%
      gayini_add_gap_segments(
        group_cols = c("plot_id", "metric"),
        gap_days_for_new_segment = GAP_DAYS_FOR_NEW_SEGMENT
      )

    if (nrow(fc_plot_data) > 0) {
      fc_x_min <- min(fc_plot_data$date_plot, na.rm = TRUE) - 180
      fc_x_max <- max(fc_plot_data$date_plot, na.rm = TRUE) + 180

      n_gc_dates <- dplyr::n_distinct(fc_plot_data$date_plot)

      fc_plot <- ggplot2::ggplot(
        fc_plot_data,
        ggplot2::aes(
          x = .data$date_plot,
          y = .data$cover_pct,
          colour = .data$metric,
          group = interaction(.data$metric, .data$segment_id)
        )
      ) +
        ggplot2::geom_line(linewidth = 0.45, na.rm = TRUE) +
        ggplot2::geom_point(size = 0.75, na.rm = TRUE) +
        ggplot2::geom_vline(xintercept = management_change_date, linetype = "dashed", colour = "grey30") +
        ggplot2::coord_cartesian(xlim = c(fc_x_min, fc_x_max), ylim = c(0, 100)) +
        ggplot2::scale_x_date(date_breaks = "5 years", date_labels = "%Y") +
        ggplot2::scale_colour_manual(values = c("Total vegetation" = "#1a9850", "Bare ground" = "#8c510a")) +
        ggplot2::labs(
          title = "Ground-cover history",
          subtitle = paste0("Total vegetation = green + non-green; gaps are not connected across long breaks; n dates = ", n_gc_dates, "."),
          x = "Date",
          y = "Cover (%)",
          colour = "Metric"
        ) +
        gayini_theme_chart(base_size = 10)
    } else {
      fc_plot <- ggplot2::ggplot() +
        ggplot2::annotate("text", x = 0, y = 0, label = "No ground-cover rows for this plot") +
        ggplot2::theme_void()
    }
  } else {
    fc_plot <- ggplot2::ggplot() +
      ggplot2::annotate("text", x = 0, y = 0, label = "No fractional-cover table found") +
      ggplot2::theme_void()
  }

  annual_history_plot <- if (nrow(annual_plot_data) > 0) {
    gayini_make_annual_history_plot(
      annual_plot_data = annual_plot_data,
      management_change_date = management_change_date,
      pre_start_date = pre_start_date,
      post_end_date = post_end_date,
      annual_history_style = ANNUAL_HISTORY_STYLE
    )
  } else {
    ggplot2::ggplot() +
      ggplot2::annotate("text", x = 0, y = 0, label = "No annual inundation rows for this plot") +
      ggplot2::theme_void()
  }

  if (!is.null(daily_data)) {
    daily_plot_data <- daily_data %>%
      dplyr::filter(.data$plot_id == !!this_plot) %>%
      dplyr::group_by(.data$month_plot, .data$sensor_plot) %>%
      dplyr::summarise(
        mean_daily_inundated_pct = mean(.data$daily_inundated_pct, na.rm = TRUE),
        .groups = "drop"
      )

    daily_plot <- ggplot2::ggplot(daily_plot_data, ggplot2::aes(x = .data$month_plot, y = .data$mean_daily_inundated_pct, colour = .data$sensor_plot)) +
      ggplot2::geom_line(linewidth = 0.4, na.rm = TRUE) +
      ggplot2::geom_point(size = 0.8, na.rm = TRUE) +
      ggplot2::geom_vline(xintercept = management_change_date, linetype = "dashed", colour = "grey30") +
      ggplot2::labs(
        title = "Monthly daily-inundation sensor QA",
        subtitle = "Optional QA panel; not used as the main dashboard hydrology summary.",
        x = "Month",
        y = "Mean daily inundated area (%)",
        colour = "Sensor"
      ) +
      gayini_theme_chart(base_size = 10)

    bottom_panel <- annual_history_plot / daily_plot
    dashboard_heights <- c(0.75, 2.45, 2.35, 2.00)
    dashboard <- header_plot / (prepost_variation_plot | fc_plot) / bottom_panel +
      patchwork::plot_layout(heights = dashboard_heights)
  } else {
    dashboard <- header_plot / (prepost_variation_plot | fc_plot) / annual_history_plot +
      patchwork::plot_layout(heights = c(0.75, 2.55, 2.35))
  }

  dashboard_path <- file.path(
    figure_dir,
    paste0("07j_plot_dashboard_", stringr::str_to_lower(this_plot), ".png")
  )

  ggplot2::ggsave(dashboard_path, plot = dashboard, width = 14.2, height = 9.6, dpi = 300)

  dashboard_index <- dplyr::bind_rows(
    dashboard_index,
    tibble::tibble(
      plot_id = this_plot,
      dashboard_path = dashboard_path,
      review_note = review_note,
      treatment = gayini_fmt_chr(plot_row$treatment),
      vegetation = gayini_fmt_chr(plot_row$vegetation),
      vegetation_adrian_group = gayini_fmt_chr(plot_row$vegetation_adrian_group),
      annual_context_source = annual_source_label
    )
  )

  review_notes <- dplyr::bind_rows(
    review_notes,
    tibble::tibble(
      plot_id = this_plot,
      review_note = review_note,
      dashboard_metric_note = "V3 dashboard uses Step 7 pre/post annual occurrence frequency, annual variation diagnostics, total vegetation + bare ground, and annual lollipop inundation context.",
      remaining_caveat = "Annual occurrence frequency is not hydroperiod, duration or flood depth. Annual variation points depend on the available annual table; if the combined Step 7 annual table is absent, the dashboard falls back to annual Landsat/NSW plot summaries."
    )
  )
}

dashboard_index_path <- file.path(figure_dir, paste0("07j_plot_dashboard_index_", DASHBOARD_VERSION, ".csv"))
readr::write_csv(dashboard_index, dashboard_index_path)
message("Wrote: ", dashboard_index_path)

readr::write_csv(review_notes, review_notes_path)
message("Wrote: ", review_notes_path)

## Also write to Output/csv for easier collection.
readr::write_csv(dashboard_index, file.path(csv_dir, paste0("07j_plot_dashboard_index_", DASHBOARD_VERSION, ".csv")))
readr::write_csv(review_notes, file.path(csv_dir, paste0("07j_plot_dashboard_review_notes_", DASHBOARD_VERSION, ".csv")))

message("07j dashboard rework complete. Wrote dashboards to: ", figure_dir)
