# ------------------------------------------------------------------------------
# Script: scripts/07_figures_dashboards/internal/01_make_adrian_review_png_assets_impl.R
# Purpose: Internal implementation module for 07_figures_dashboards: make
#          adrian review png assets impl.
# Workflow stage: 07_figures_dashboards
# Run mode: lightweight_review
# Heavy processing: no
# Key inputs:
#   - Inputs are supplied by the active wrapper or existing workflow outputs.
# Key outputs:
#   - Outputs are written by the implementation module for its active wrapper.
# Notes:
#   - Internal module; run the wrapper script in the parent folder unless
#     debugging.
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Load configuration and execute workflow step
# ------------------------------------------------------------------------------

## Purpose:
## Create standalone review-ready PNG assets for manual PowerPoint updating.
## This script reads existing curated, Step 10, Step 12, and QA outputs only.
## It does not run extraction, raster processing, BFAST, tbreak, or PowerPoint.


## User settings ----


root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", "D:/Github_repos/Gayini"), winslash = "/", mustWork = TRUE)
MANAGEMENT_CHANGE_DATE <- as.Date("2019-07-01")
FIGURE_WIDTH <- 12
FIGURE_HEIGHT <- 7.2
FIGURE_DPI <- 320
DASHBOARD_WIDTH <- 14.2
DASHBOARD_HEIGHT <- 9.6
DASHBOARD_PLOTS <- c("GA_001", "GA_003", "GA_012", "GA_019", "GA_026", "GA_032", "GA_035", "GA_043", "GA_052", "GA_065")
N_SCATTER_LABELS <- 7L
N_TIMING_EXAMPLE_PLOTS <- 6L
OVERLAP_START_OVERRIDE <- as.Date(NA)
OVERLAP_END_OVERRIDE <- as.Date(NA)


## Required packages ----


required_packages <- c(
  "dplyr",
  "tidyr",
  "readr",
  "stringr",
  "ggplot2",
  "magrittr",
  "tibble",
  "scales",
  "patchwork"
)

source(file.path(root_dir, "R", "gayini_analysis_base_functions.R"))
gayini_check_packages(required_packages)

library(dplyr)
library(tidyr)
library(readr)
library(stringr)
library(ggplot2)
library(magrittr)
library(tibble)
library(scales)
library(patchwork)

use_ggrepel <- requireNamespace("ggrepel", quietly = TRUE)


## Paths ----


csv_dir <- file.path(root_dir, "Output", "csv")
diagnostics_dir <- file.path(root_dir, "Output", "diagnostics")
asset_dir <- file.path(root_dir, "Output", "reports", "adrian_review_png_assets")

dir.create(asset_dir, recursive = TRUE, showWarnings = FALSE)

plot_summary_path <- file.path(csv_dir, "10a_ground_cover_prepost_plot_summary.csv")
model_summary_path <- file.path(csv_dir, "10a_ground_cover_prepost_model_summary.csv")
ground_cover_path <- file.path(csv_dir, "curated_ground_cover_timeseries.csv")
annual_inundation_path <- file.path(csv_dir, "curated_annual_inundation_timeseries.csv")
monthly_inundation_path <- file.path(csv_dir, "curated_daily_inundation_monthly.csv")
plot_base_path <- file.path(csv_dir, "plot_rs_analysis_base.csv")
lag_by_plot_path <- file.path(csv_dir, "12_lag_diagnostics_by_plot.csv")
raw_ground_cover_path <- file.path(csv_dir, "04c_fractional_cover_full.csv")
gc_coverage_summary_path <- file.path(diagnostics_dir, "04c_fractional_cover_full_valid_coverage_by_plot.csv")
annual_coverage_summary_path <- file.path(diagnostics_dir, "05c_landsat_inundation_full_coverage_summary.csv")

figure_manifest_path <- file.path(asset_dir, "figure_manifest.csv")
dashboard_index_path <- file.path(asset_dir, "dashboard_index.csv")
handoff_report_path <- file.path(asset_dir, "codex_handoff_report.md")

input_paths <- c(
  plot_summary = plot_summary_path,
  model_summary = model_summary_path,
  curated_ground_cover = ground_cover_path,
  curated_annual_inundation = annual_inundation_path,
  curated_daily_inundation_monthly = monthly_inundation_path,
  plot_rs_analysis_base = plot_base_path,
  raw_ground_cover_04c = raw_ground_cover_path
)

missing_inputs <- names(input_paths)[!file.exists(input_paths)]

if (length(missing_inputs) > 0) {
  stop("Missing required input(s): ", paste(missing_inputs, collapse = ", "), call. = FALSE)
}


## Helpers ----


require_columns <- function(df, required_cols, object_name) {
  missing_cols <- setdiff(required_cols, names(df))

  if (length(missing_cols) > 0) {
    stop(
      object_name, " is missing required column(s): ",
      paste(missing_cols, collapse = ", "),
      call. = FALSE
    )
  }

  invisible(TRUE)
}


theme_review <- function(base_size = 13) {
  ggplot2::theme_minimal(base_size = base_size, base_family = "Arial") +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      plot.title = ggplot2::element_text(face = "bold", size = base_size + 4),
      plot.subtitle = ggplot2::element_text(size = base_size),
      plot.caption = ggplot2::element_text(size = base_size - 2, colour = "grey30", hjust = 0),
      axis.title = ggplot2::element_text(face = "bold"),
      legend.title = ggplot2::element_text(face = "bold"),
      legend.position = "bottom",
      strip.text = ggplot2::element_text(face = "bold"),
      strip.background = ggplot2::element_rect(fill = "grey94", colour = NA)
    )
}


theme_dashboard <- function(base_size = 10) {
  theme_review(base_size = base_size) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(face = "bold", size = base_size + 2),
      plot.subtitle = ggplot2::element_text(size = base_size - 1),
      plot.caption = ggplot2::element_text(size = base_size - 2),
      legend.position = "bottom"
    )
}


change_class_label <- function(x) {
  dplyr::case_when(
    x == "much_wetter_post" ~ "Much wetter post",
    x == "wetter_post" ~ "Wetter post",
    x == "similar_frequency" ~ "Similar frequency",
    x == "drier_post" ~ "Drier post",
    x == "much_drier_post" ~ "Much drier post",
    x == "no_comparison" ~ "No comparison",
    TRUE ~ stringr::str_to_sentence(stringr::str_replace_all(as.character(x), "_", " "))
  )
}


fmt_num <- function(x, digits = 1, suffix = "") {
  x <- suppressWarnings(as.numeric(x))

  ifelse(is.na(x), "NA", paste0(sprintf(paste0("%.", digits, "f"), x), suffix))
}


fmt_signed <- function(x, digits = 1, suffix = "") {
  x <- suppressWarnings(as.numeric(x))

  ifelse(is.na(x), "NA", paste0(sprintf(paste0("%+.", digits, "f"), x), suffix))
}


safe_mean <- function(x) {
  if (all(is.na(x))) {
    return(NA_real_)
  }

  mean(x, na.rm = TRUE)
}


water_year_start <- function(water_year) {
  suppressWarnings(as.integer(stringr::str_sub(as.character(water_year), 1, 4)))
}


add_plot_labels <- function(plot, label_data, x_col, y_col, label_size = 3.4) {
  if (nrow(label_data) == 0) {
    return(plot)
  }

  if (use_ggrepel) {
    return(
      plot +
        ggrepel::geom_text_repel(
          data = label_data,
          ggplot2::aes(x = .data[[x_col]], y = .data[[y_col]], label = .data$plot_id),
          inherit.aes = FALSE,
          size = label_size,
          seed = 42,
          min.segment.length = 0,
          box.padding = 0.35,
          point.padding = 0.25,
          segment.colour = "grey60",
          max.overlaps = Inf,
          show.legend = FALSE
        )
    )
  }

  plot +
    ggplot2::geom_text(
      data = label_data,
      ggplot2::aes(x = .data[[x_col]], y = .data[[y_col]], label = .data$plot_id),
      inherit.aes = FALSE,
      size = label_size,
      vjust = -0.85,
      check_overlap = TRUE,
      show.legend = FALSE
    )
}


save_png <- function(plot, filename, width = FIGURE_WIDTH, height = FIGURE_HEIGHT) {
  path <- file.path(asset_dir, filename)
  ggplot2::ggsave(path, plot = plot, width = width, height = height, dpi = FIGURE_DPI, bg = "white")
  message("Wrote: ", path)
  path
}


manifest_rows <- tibble::tibble(
  filename = character(),
  figure_title = character(),
  figure_family = character(),
  source_script_or_input = character(),
  main_input_data = character(),
  output_path = character(),
  notes = character(),
  review_flag = character()
)


add_manifest <- function(filename,
                         figure_title,
                         figure_family,
                         source_script_or_input,
                         main_input_data,
                         output_path,
                         notes,
                         review_flag = "ok") {
  manifest_rows <<- dplyr::bind_rows(
    manifest_rows,
    tibble::tibble(
      filename = filename,
      figure_title = figure_title,
      figure_family = figure_family,
      source_script_or_input = source_script_or_input,
      main_input_data = main_input_data,
      output_path = output_path,
      notes = notes,
      review_flag = review_flag
    )
  )
}


make_support_tiles <- function(valid_fraction,
                               wet_fraction = NA_real_,
                               mode = c("ground_cover", "inundation"),
                               n_side = 5L) {
  mode <- match.arg(mode)
  n_tiles <- n_side * n_side
  valid_tiles <- max(0L, min(n_tiles, round(valid_fraction * n_tiles)))

  tile_data <- tibble::tibble(
    x = rep(seq_len(n_side), times = n_side),
    y = rep(seq_len(n_side), each = n_side),
    tile_id = seq_len(n_tiles)
  ) %>%
    dplyr::mutate(
      support_class = dplyr::if_else(.data$tile_id <= valid_tiles, "Valid", "No valid support")
    )

  if (mode == "inundation") {
    wet_tiles <- ifelse(is.na(wet_fraction), 0L, max(0L, min(valid_tiles, round(wet_fraction * n_tiles))))
    tile_data <- tile_data %>%
      dplyr::mutate(
        support_class = dplyr::case_when(
          .data$tile_id <= wet_tiles ~ "Inundated",
          .data$tile_id <= valid_tiles ~ "Valid dry",
          TRUE ~ "No valid support"
        )
      )
  }

  tile_data
}


make_support_panel <- function(tile_data, title_text, subtitle_text, mode = c("ground_cover", "inundation")) {
  mode <- match.arg(mode)

  fill_values <- if (mode == "inundation") {
    c("Inundated" = "#3a6ea5", "Valid dry" = "#d9d9d9", "No valid support" = "#f4f4f4")
  } else {
    c("Valid" = "#8fb996", "No valid support" = "#f4f4f4")
  }

  ggplot2::ggplot(tile_data, ggplot2::aes(x = .data$x, y = .data$y, fill = .data$support_class)) +
    ggplot2::geom_tile(colour = "white", linewidth = 0.55) +
    ggplot2::annotate("rect", xmin = 1.05, xmax = 4.95, ymin = 1.05, ymax = 4.95, colour = "#c43c39", fill = NA, linewidth = 1.1) +
    ggplot2::annotate("rect", xmin = 0.55, xmax = 5.45, ymin = 0.55, ymax = 5.45, colour = "grey45", fill = NA, linewidth = 0.8, linetype = "dashed") +
    ggplot2::scale_fill_manual(values = fill_values, drop = FALSE) +
    ggplot2::coord_equal(expand = FALSE) +
    ggplot2::labs(title = title_text, subtitle = subtitle_text, x = NULL, y = NULL, fill = "Cell support") +
    theme_review(base_size = 10) +
    ggplot2::theme(
      axis.text = ggplot2::element_blank(),
      panel.grid = ggplot2::element_blank(),
      legend.position = "bottom"
    )
}


class_order <- c("Drier post", "Similar frequency", "Wetter post", "Much wetter post", "Much drier post", "No comparison")
class_colours <- c(
  "Drier post" = "#b07d3c",
  "Similar frequency" = "#8f8f8f",
  "Wetter post" = "#59a14f",
  "Much wetter post" = "#2c7fb8",
  "Much drier post" = "#8c510a",
  "No comparison" = "#c7c7c7"
)


## Read inputs ----


plot_summary <- readr::read_csv(plot_summary_path, show_col_types = FALSE) %>%
  gayini_standardise_plot_id(object_name = "10a plot summary") %>%
  dplyr::mutate(
    inundation_change_label = factor(change_class_label(.data$inundation_change_class), levels = class_order),
    delta_total_veg_pct = as.numeric(.data$delta_total_veg_pct),
    delta_bare_ground_pct = as.numeric(.data$delta_bare_ground_pct),
    post_minus_pre_inundation_frequency_pct_points = as.numeric(.data$post_minus_pre_inundation_frequency_pct_points),
    pre_conservation_inundation_frequency_pct = as.numeric(.data$pre_conservation_inundation_frequency_pct),
    post_conservation_inundation_frequency_pct = as.numeric(.data$post_conservation_inundation_frequency_pct)
  )

model_summary <- readr::read_csv(model_summary_path, show_col_types = FALSE)

ground_cover <- readr::read_csv(ground_cover_path, show_col_types = FALSE) %>%
  gayini_standardise_plot_id(object_name = "curated ground cover") %>%
  dplyr::mutate(
    date_midpoint = as.Date(.data$date_midpoint),
    total_veg_pct = as.numeric(.data$total_veg_pct),
    bare_ground_pct = as.numeric(.data$bare_ground_pct)
  )

annual_inundation <- readr::read_csv(annual_inundation_path, show_col_types = FALSE) %>%
  gayini_standardise_plot_id(object_name = "curated annual inundation") %>%
  dplyr::mutate(
    water_year_start = water_year_start(.data$water_year),
    date_plot = as.Date(sprintf("%s-07-01", .data$water_year_start)),
    inundated_any_pct = as.numeric(.data$inundated_any_pct),
    annual_wet_any = as.numeric(.data$annual_wet_any),
    annual_valid_any = as.numeric(.data$annual_valid_any),
    count_1_area_pct = as.numeric(.data$count_1_area_pct),
    valid_coverage_pct = as.numeric(.data$valid_coverage_pct)
  )

monthly_inundation <- readr::read_csv(monthly_inundation_path, show_col_types = FALSE) %>%
  gayini_standardise_plot_id(object_name = "curated daily inundation monthly") %>%
  dplyr::mutate(
    month_start = as.Date(.data$month_start),
    mean_daily_inundated_pct = as.numeric(.data$mean_daily_inundated_pct),
    max_daily_inundated_pct = as.numeric(.data$max_daily_inundated_pct)
  )

plot_base <- readr::read_csv(plot_base_path, show_col_types = FALSE) %>%
  gayini_standardise_plot_id(object_name = "plot RS analysis base")

raw_ground_cover <- readr::read_csv(raw_ground_cover_path, show_col_types = FALSE) %>%
  gayini_standardise_plot_id(object_name = "04c raw ground cover") %>%
  dplyr::mutate(
    date_midpoint = as.Date(.data$date_midpoint),
    valid_coverage_count = as.numeric(.data$valid_coverage_count),
    mean_value = as.numeric(.data$mean_value)
  )

lag_by_plot <- if (file.exists(lag_by_plot_path)) {
  readr::read_csv(lag_by_plot_path, show_col_types = FALSE) %>%
    gayini_standardise_plot_id(object_name = "12 lag diagnostics")
} else {
  tibble::tibble()
}

gc_coverage_summary <- if (file.exists(gc_coverage_summary_path)) {
  readr::read_csv(gc_coverage_summary_path, show_col_types = FALSE) %>%
    gayini_standardise_plot_id(object_name = "04c valid coverage summary")
} else {
  tibble::tibble()
}

annual_coverage_summary <- if (file.exists(annual_coverage_summary_path)) {
  readr::read_csv(annual_coverage_summary_path, show_col_types = FALSE) %>%
    gayini_standardise_plot_id(object_name = "05c annual coverage summary")
} else {
  tibble::tibble()
}

require_columns(
  plot_summary,
  c(
    "plot_id",
    "inundation_change_class",
    "inundation_change_label",
    "post_minus_pre_inundation_frequency_pct_points",
    "delta_total_veg_pct",
    "delta_bare_ground_pct",
    "pre_conservation_inundation_frequency_pct",
    "post_conservation_inundation_frequency_pct",
    "vegetation_adrian_group"
  ),
  "10a plot summary"
)


## 1. Review scatterplots ----


make_scatter_labels <- function(df, response_col) {
  df %>%
    dplyr::mutate(
      response_value = .data[[response_col]],
      abs_response = abs(.data$response_value),
      review_flag = dplyr::case_when(
        response_col == "delta_total_veg_pct" & (.data$strong_total_veg_increase | .data$strong_total_veg_decrease | .data$wetter_post_and_greener) ~ TRUE,
        response_col == "delta_bare_ground_pct" & (.data$strong_bare_increase | .data$strong_bare_decrease | .data$wetter_post_and_barer) ~ TRUE,
        TRUE ~ FALSE
      )
    ) %>%
    dplyr::arrange(dplyr::desc(.data$review_flag), dplyr::desc(.data$abs_response)) %>%
    dplyr::slice_head(n = N_SCATTER_LABELS)
}


make_review_scatter <- function(df, response_col, y_label, title, caption, include_trend = TRUE) {
  labels <- make_scatter_labels(df, response_col)

  p <- ggplot2::ggplot(
    df,
    ggplot2::aes(
      x = .data$post_minus_pre_inundation_frequency_pct_points,
      y = .data[[response_col]]
    )
  ) +
    ggplot2::geom_hline(yintercept = 0, colour = "grey45", linewidth = 0.4) +
    ggplot2::geom_vline(xintercept = 0, colour = "grey45", linewidth = 0.4)

  if (include_trend) {
    p <- p +
      ggplot2::geom_smooth(
        method = "lm",
        se = TRUE,
        colour = "grey45",
        fill = "grey80",
        linewidth = 0.45,
        alpha = 0.22
      )
  }

  p <- p +
    ggplot2::geom_point(
      ggplot2::aes(fill = .data$inundation_change_label),
      shape = 21,
      colour = "grey20",
      stroke = 0.35,
      size = 3.4,
      alpha = 0.9
    ) +
    ggplot2::scale_fill_manual(values = class_colours, drop = TRUE, na.value = "grey75") +
    ggplot2::labs(
      title = title,
      subtitle = "Points are plots grouped by annual occurrence-frequency change class.",
      x = "Post minus pre inundation frequency (percentage points)",
      y = y_label,
      fill = "Occurrence-frequency class",
      caption = caption
    ) +
    theme_review(base_size = 14) +
    ggplot2::theme(
      legend.position = "bottom",
      axis.text.x = ggplot2::element_text(angle = 0)
    ) +
    ggplot2::guides(fill = ggplot2::guide_legend(nrow = 2, byrow = TRUE))

  add_plot_labels(
    p,
    labels,
    x_col = "post_minus_pre_inundation_frequency_pct_points",
    y_col = response_col,
    label_size = 3.5
  )
}


scatter_total_path <- save_png(
  make_review_scatter(
    plot_summary,
    "delta_total_veg_pct",
    "Delta total vegetation (percentage points)",
    "Inundation change and total vegetation response",
    "Descriptive screening only; inundation frequency is annual occurrence frequency.",
    include_trend = TRUE
  ),
  "scatter_inundation_vs_total_veg_review.png"
)

add_manifest(
  "scatter_inundation_vs_total_veg_review.png",
  "Inundation change and total vegetation response",
  "scatter",
  "scripts/13_make_adrian_review_png_assets.R",
  "Output/csv/10a_ground_cover_prepost_plot_summary.csv",
  scatter_total_path,
  "Grouped only by inundation occurrence-frequency class; thin linear trend is descriptive.",
  "review_ready"
)

scatter_total_plain_path <- save_png(
  make_review_scatter(
    plot_summary,
    "delta_total_veg_pct",
    "Delta total vegetation (percentage points)",
    "Inundation change and total vegetation response",
    "Descriptive screening only; inundation frequency is annual occurrence frequency.",
    include_trend = FALSE
  ),
  "scatter_inundation_vs_total_veg_review_plain.png"
)

add_manifest(
  "scatter_inundation_vs_total_veg_review_plain.png",
  "Inundation change and total vegetation response, plain version",
  "scatter",
  "scripts/13_make_adrian_review_png_assets.R",
  "Output/csv/10a_ground_cover_prepost_plot_summary.csv",
  scatter_total_plain_path,
  "Plain no-trend version for slides where the trend ribbon is distracting.",
  "optional_plain_version"
)

scatter_bare_path <- save_png(
  make_review_scatter(
    plot_summary,
    "delta_bare_ground_pct",
    "Delta bare ground (percentage points)",
    "Inundation change and bare ground response",
    "Descriptive screening only; positive bare-ground change means more bare ground post-conservation-management change.",
    include_trend = TRUE
  ),
  "scatter_inundation_vs_bare_ground_review.png"
)

add_manifest(
  "scatter_inundation_vs_bare_ground_review.png",
  "Inundation change and bare ground response",
  "scatter",
  "scripts/13_make_adrian_review_png_assets.R",
  "Output/csv/10a_ground_cover_prepost_plot_summary.csv",
  scatter_bare_path,
  "Grouped only by inundation occurrence-frequency class; thin linear trend is descriptive.",
  "review_ready"
)

scatter_bare_plain_path <- save_png(
  make_review_scatter(
    plot_summary,
    "delta_bare_ground_pct",
    "Delta bare ground (percentage points)",
    "Inundation change and bare ground response",
    "Descriptive screening only; positive bare-ground change means more bare ground post-conservation-management change.",
    include_trend = FALSE
  ),
  "scatter_inundation_vs_bare_ground_review_plain.png"
)

add_manifest(
  "scatter_inundation_vs_bare_ground_review_plain.png",
  "Inundation change and bare ground response, plain version",
  "scatter",
  "scripts/13_make_adrian_review_png_assets.R",
  "Output/csv/10a_ground_cover_prepost_plot_summary.csv",
  scatter_bare_plain_path,
  "Plain no-trend version for slides where the trend ribbon is distracting.",
  "optional_plain_version"
)


## 2. Selected timing examples restricted to overlap period ----


gc_monthly_range <- range(ground_cover$date_midpoint, na.rm = TRUE)
monthly_range <- range(monthly_inundation$month_start, na.rm = TRUE)
overlap_start <- max(gc_monthly_range[1], monthly_range[1], na.rm = TRUE)
overlap_end <- min(gc_monthly_range[2], monthly_range[2], na.rm = TRUE)

if (!is.na(OVERLAP_START_OVERRIDE)) {
  overlap_start <- OVERLAP_START_OVERRIDE
}

if (!is.na(OVERLAP_END_OVERRIDE)) {
  overlap_end <- OVERLAP_END_OVERRIDE
}

if (nrow(lag_by_plot) > 0) {
  timing_plot_reasons <- lag_by_plot %>%
    dplyr::filter(.data$diagnostic_type == "monthly", .data$support_class == "adequate_support", !is.na(.data$correlation)) %>%
    dplyr::mutate(abs_correlation = abs(.data$correlation)) %>%
    dplyr::group_by(.data$plot_id) %>%
    dplyr::arrange(dplyr::desc(.data$abs_correlation), .by_group = TRUE) %>%
    dplyr::slice_head(n = 1) %>%
    dplyr::ungroup() %>%
    dplyr::arrange(dplyr::desc(.data$abs_correlation)) %>%
    dplyr::slice_head(n = N_TIMING_EXAMPLE_PLOTS) %>%
    dplyr::transmute(
      plot_id = .data$plot_id,
      selection_reason = paste0(change_class_label(plot_summary$inundation_change_class[match(.data$plot_id, plot_summary$plot_id)]), "; lag r=", round(.data$correlation, 2)),
      facet_label = paste0(.data$plot_id, "\n", .data$selection_reason)
    )
} else {
  timing_plot_reasons <- plot_summary %>%
    dplyr::arrange(dplyr::desc(abs(.data$delta_total_veg_pct))) %>%
    dplyr::slice_head(n = N_TIMING_EXAMPLE_PLOTS) %>%
    dplyr::transmute(
      plot_id = .data$plot_id,
      selection_reason = paste0(change_class_label(.data$inundation_change_class), "; large GC response"),
      facet_label = paste0(.data$plot_id, "\n", .data$selection_reason)
    )
}

timing_gc <- ground_cover %>%
  dplyr::filter(.data$plot_id %in% timing_plot_reasons$plot_id, .data$date_midpoint >= overlap_start, .data$date_midpoint <= overlap_end) %>%
  dplyr::select("plot_id", date_plot = "date_midpoint", "total_veg_pct", "bare_ground_pct") %>%
  tidyr::pivot_longer(
    cols = c("total_veg_pct", "bare_ground_pct"),
    names_to = "metric",
    values_to = "value_pct"
  ) %>%
  dplyr::mutate(
    metric = dplyr::case_when(
      .data$metric == "total_veg_pct" ~ "Total vegetation",
      .data$metric == "bare_ground_pct" ~ "Bare ground",
      TRUE ~ .data$metric
    )
  )

timing_inundation <- monthly_inundation %>%
  dplyr::filter(.data$plot_id %in% timing_plot_reasons$plot_id, .data$month_start >= overlap_start, .data$month_start <= overlap_end) %>%
  dplyr::transmute(
    plot_id = .data$plot_id,
    date_plot = .data$month_start,
    metric = "Monthly inundation",
    value_pct = .data$mean_daily_inundated_pct
  )

timing_data <- dplyr::bind_rows(timing_gc, timing_inundation) %>%
  dplyr::left_join(timing_plot_reasons, by = "plot_id") %>%
  dplyr::mutate(metric = factor(.data$metric, levels = c("Total vegetation", "Bare ground", "Monthly inundation")))

timing_plot <- ggplot2::ggplot(timing_data, ggplot2::aes(x = .data$date_plot, y = .data$value_pct, colour = .data$metric)) +
  ggplot2::geom_vline(xintercept = MANAGEMENT_CHANGE_DATE, linetype = "dashed", colour = "grey35", linewidth = 0.4) +
  ggplot2::geom_line(linewidth = 0.65, na.rm = TRUE) +
  ggplot2::geom_point(size = 1.3, alpha = 0.8, na.rm = TRUE) +
  ggplot2::facet_wrap(~ facet_label, ncol = 2) +
  ggplot2::coord_cartesian(ylim = c(0, 100)) +
  ggplot2::scale_colour_manual(values = c("Total vegetation" = "#59a14f", "Bare ground" = "#b07d3c", "Monthly inundation" = "#3a6ea5")) +
  ggplot2::scale_x_date(date_breaks = "2 years", date_labels = "%Y") +
  ggplot2::labs(
    title = "Selected plot examples: ground cover and monthly inundation",
    subtitle = "Restricted to the overlap period for timing comparison.",
    x = "Date",
    y = "Percent",
    colour = "Metric",
    caption = "Visual timing comparison only; not a causal test."
  ) +
  theme_review(base_size = 11)

timing_path <- save_png(timing_plot, "selected_plot_examples_overlap_period_only.png", width = 12, height = 9)

add_manifest(
  "selected_plot_examples_overlap_period_only.png",
  "Selected plot examples: ground cover and monthly inundation",
  "timing_examples",
  "scripts/13_make_adrian_review_png_assets.R",
  "curated_ground_cover_timeseries.csv; curated_daily_inundation_monthly.csv; 12_lag_diagnostics_by_plot.csv",
  timing_path,
  paste0("Overlap period used: ", overlap_start, " to ", overlap_end, "."),
  "review_ready"
)


## 3. Revised dashboards ----


dashboard_index <- tibble::tibble(
  plot_id = character(),
  occurrence_class = character(),
  pre_frequency_pct = numeric(),
  post_frequency_pct = numeric(),
  change_pct_points = numeric(),
  delta_total_veg_pct = numeric(),
  vegetation_group = character(),
  dashboard_file = character(),
  visual_consistency_note = character()
)


make_dashboard_header <- function(row) {
  header <- paste0(
    "Occurrence class: ", as.character(row$inundation_change_label),
    " | Pre ", fmt_num(row$pre_conservation_inundation_frequency_pct, 1, "%"),
    " | Post ", fmt_num(row$post_conservation_inundation_frequency_pct, 1, "%"),
    " | Change ", fmt_signed(row$post_minus_pre_inundation_frequency_pct_points, 1, " ppt"),
    " | GC d veg ", fmt_signed(row$delta_total_veg_pct, 1, " ppt"),
    " | ", row$vegetation_adrian_group
  )

  ggplot2::ggplot() +
    ggplot2::annotate("text", x = 0, y = 0.82, hjust = 0, vjust = 1, size = 5.4, fontface = "bold", label = paste0("Plot ", row$plot_id)) +
    ggplot2::annotate("text", x = 0, y = 0.50, hjust = 0, vjust = 1, size = 3.65, label = stringr::str_wrap(header, 150)) +
    ggplot2::annotate("text", x = 0, y = 0.18, hjust = 0, vjust = 1, size = 3.05, colour = "grey30", label = "Class is based on annual occurrence frequency; top-left shows annual inundated area variation.") +
    ggplot2::xlim(0, 1) +
    ggplot2::ylim(0, 1) +
    ggplot2::theme_void()
}


make_visual_consistency_note <- function(row, annual_plot_data) {
  annual_period <- annual_plot_data %>%
    dplyr::filter(.data$period %in% c("pre_conservation", "post_conservation")) %>%
    dplyr::group_by(.data$period) %>%
    dplyr::summarise(mean_annual_area_pct = safe_mean(.data$inundated_any_pct), .groups = "drop")

  pre_area <- annual_period$mean_annual_area_pct[annual_period$period == "pre_conservation"]
  post_area <- annual_period$mean_annual_area_pct[annual_period$period == "post_conservation"]

  if (length(pre_area) == 0 || length(post_area) == 0 || is.na(pre_area) || is.na(post_area)) {
    return("Review annual area panel: insufficient pre/post annual values for consistency check.")
  }

  area_change <- post_area - pre_area
  class_value <- as.character(row$inundation_change_class)

  dplyr::case_when(
    class_value %in% c("drier_post", "much_drier_post") & area_change > 10 ~ paste0("Review: occurrence class is drier but mean annual inundated area is higher post by ", fmt_num(area_change, 1, " ppt"), ". This can happen when fewer wet years are larger."),
    class_value %in% c("wetter_post", "much_wetter_post") & area_change < -10 ~ paste0("Review: occurrence class is wetter but mean annual inundated area is lower post by ", fmt_num(abs(area_change), 1, " ppt"), "."),
    class_value == "similar_frequency" & abs(area_change) > 10 ~ paste0("Review: occurrence class is similar but annual inundated area differs by ", fmt_signed(area_change, 1, " ppt"), "."),
    TRUE ~ "Visual check: annual area boxplot is broadly consistent with the occurrence-frequency class."
  )
}


for (plot_id_i in DASHBOARD_PLOTS) {
  row <- plot_summary %>%
    dplyr::filter(.data$plot_id == plot_id_i) %>%
    dplyr::slice(1)

  if (nrow(row) == 0) {
    warning("Dashboard plot not found in 10a summary: ", plot_id_i, call. = FALSE)
    next
  }

  annual_plot_data <- annual_inundation %>%
    dplyr::filter(.data$plot_id == plot_id_i)

  gc_plot_data <- ground_cover %>%
    dplyr::filter(.data$plot_id == plot_id_i)

  annual_period_data <- annual_plot_data %>%
    dplyr::filter(.data$period %in% c("pre_conservation", "post_conservation")) %>%
    dplyr::mutate(period_label = factor(dplyr::case_when(
      .data$period == "pre_conservation" ~ "Pre",
      .data$period == "post_conservation" ~ "Post",
      TRUE ~ .data$period
    ), levels = c("Pre", "Post")))

  top_left <- ggplot2::ggplot(annual_period_data, ggplot2::aes(x = .data$period_label, y = .data$inundated_any_pct)) +
    ggplot2::geom_boxplot(width = 0.52, fill = "grey94", colour = "grey35", outlier.shape = NA) +
    ggplot2::geom_jitter(width = 0.08, height = 0, colour = "#3a6ea5", size = 2.4, alpha = 0.82) +
    ggplot2::geom_point(
      data = tibble::tibble(
        period_label = factor(c("Pre", "Post"), levels = c("Pre", "Post")),
        frequency_pct = c(row$pre_conservation_inundation_frequency_pct, row$post_conservation_inundation_frequency_pct)
      ),
      ggplot2::aes(x = .data$period_label, y = .data$frequency_pct),
      inherit.aes = FALSE,
      shape = 23,
      fill = "white",
      colour = "black",
      size = 4.0,
      stroke = 0.7
    ) +
    ggplot2::coord_cartesian(ylim = c(0, 100)) +
    ggplot2::labs(
      title = "Annual inundation variation (% area)",
      subtitle = "Points are annual plot values; diamonds are period occurrence frequency.",
      x = NULL,
      y = "Inundated area / occurrence (%)"
    ) +
    theme_dashboard()

  gc_long <- gc_plot_data %>%
    dplyr::select("plot_id", "date_midpoint", "total_veg_pct", "bare_ground_pct") %>%
    tidyr::pivot_longer(cols = c("total_veg_pct", "bare_ground_pct"), names_to = "metric", values_to = "value_pct") %>%
    dplyr::mutate(metric = dplyr::case_when(
      .data$metric == "total_veg_pct" ~ "Total vegetation",
      .data$metric == "bare_ground_pct" ~ "Bare ground",
      TRUE ~ .data$metric
    ))

  gc_history <- ggplot2::ggplot(gc_long, ggplot2::aes(x = .data$date_midpoint, y = .data$value_pct, colour = .data$metric)) +
    ggplot2::geom_vline(xintercept = MANAGEMENT_CHANGE_DATE, linetype = "dashed", colour = "grey35", linewidth = 0.4) +
    ggplot2::geom_line(linewidth = 0.55, na.rm = TRUE) +
    ggplot2::geom_point(size = 0.9, alpha = 0.75, na.rm = TRUE) +
    ggplot2::coord_cartesian(ylim = c(0, 100)) +
    ggplot2::scale_x_date(date_breaks = "5 years", date_labels = "%Y") +
    ggplot2::scale_colour_manual(values = c("Total vegetation" = "#59a14f", "Bare ground" = "#b07d3c")) +
    ggplot2::labs(
      title = "Ground-cover history",
      subtitle = "Total vegetation and bare ground from curated ground-cover series.",
      x = "Date",
      y = "Cover (%)",
      colour = "Metric"
    ) +
    theme_dashboard()

  annual_history <- ggplot2::ggplot(annual_plot_data, ggplot2::aes(x = .data$date_plot, y = .data$inundated_any_pct)) +
    ggplot2::geom_segment(ggplot2::aes(xend = .data$date_plot, y = 0, yend = .data$inundated_any_pct), colour = "grey65", linewidth = 0.55, na.rm = TRUE) +
    ggplot2::geom_point(ggplot2::aes(fill = .data$period), shape = 21, colour = "black", stroke = 0.25, size = 2.1, na.rm = TRUE) +
    ggplot2::geom_vline(xintercept = MANAGEMENT_CHANGE_DATE, linetype = "dashed", colour = "grey35", linewidth = 0.4) +
    ggplot2::coord_cartesian(ylim = c(0, 100)) +
    ggplot2::scale_x_date(date_breaks = "5 years", date_labels = "%Y") +
    ggplot2::scale_fill_manual(
      values = c("outside_analysis_window" = "grey75", "pre_conservation" = "grey45", "post_conservation" = "#3a6ea5"),
      labels = c("outside_analysis_window" = "Outside analysis window", "pre_conservation" = "Pre", "post_conservation" = "Post"),
      na.value = "grey85"
    ) +
    ggplot2::labs(
      title = "Annual inundation history",
      subtitle = "Annual occurrence/area values, not hydroperiod or duration.",
      x = "Water year start",
      y = "Inundated area (%)",
      fill = "Period"
    ) +
    theme_dashboard()

  dashboard_plot <- make_dashboard_header(row) /
    (top_left | gc_history) /
    annual_history +
    patchwork::plot_layout(heights = c(0.70, 2.45, 2.20))

  dashboard_filename <- paste0("dashboard_", plot_id_i, "_review.png")
  dashboard_path <- save_png(dashboard_plot, dashboard_filename, width = DASHBOARD_WIDTH, height = DASHBOARD_HEIGHT)
  consistency_note <- make_visual_consistency_note(row, annual_plot_data)

  dashboard_index <- dplyr::bind_rows(
    dashboard_index,
    tibble::tibble(
      plot_id = plot_id_i,
      occurrence_class = as.character(row$inundation_change_label),
      pre_frequency_pct = row$pre_conservation_inundation_frequency_pct,
      post_frequency_pct = row$post_conservation_inundation_frequency_pct,
      change_pct_points = row$post_minus_pre_inundation_frequency_pct_points,
      delta_total_veg_pct = row$delta_total_veg_pct,
      vegetation_group = row$vegetation_adrian_group,
      dashboard_file = dashboard_filename,
      visual_consistency_note = consistency_note
    )
  )

  add_manifest(
    dashboard_filename,
    paste0("Review dashboard for ", plot_id_i),
    "dashboard",
    "scripts/13_make_adrian_review_png_assets.R",
    "10a_ground_cover_prepost_plot_summary.csv; curated_ground_cover_timeseries.csv; curated_annual_inundation_timeseries.csv",
    dashboard_path,
    consistency_note,
    ifelse(stringr::str_starts(consistency_note, "Review:"), "review_visual_consistency", "review_ready")
  )
}

readr::write_csv(dashboard_index, dashboard_index_path)
message("Wrote: ", dashboard_index_path)


## 4. Ground-cover extraction / calculation examples ----


gc_max_coverage <- raw_ground_cover %>%
  dplyr::group_by(.data$plot_id) %>%
  dplyr::summarise(max_valid_coverage_count = max(.data$valid_coverage_count, na.rm = TRUE), .groups = "drop")

gc_example_rows <- dplyr::bind_rows(
  raw_ground_cover %>%
    dplyr::filter(.data$plot_id == "GA_001", .data$valid_coverage_status == "adequate_coverage", .data$band_number == 1) %>%
    dplyr::slice_head(n = 1) %>%
    dplyr::mutate(example_label = "Adequate valid coverage"),
  raw_ground_cover %>%
    dplyr::filter(.data$plot_id == "GA_001", .data$valid_coverage_status == "no_valid_coverage", .data$band_number == 1) %>%
    dplyr::slice_head(n = 1) %>%
    dplyr::mutate(example_label = "All bands missing"),
  raw_ground_cover %>%
    dplyr::filter(.data$plot_id %in% c("GA_058", "GA_064"), .data$valid_coverage_status == "very_low_coverage", .data$band_number == 1) %>%
    dplyr::slice_head(n = 1) %>%
    dplyr::mutate(example_label = "Very low valid coverage"),
  raw_ground_cover %>%
    dplyr::filter(.data$plot_id %in% c("GA_001", "GA_058", "GA_064"), .data$valid_coverage_status == "low_coverage", .data$band_number == 1) %>%
    dplyr::slice_head(n = 1) %>%
    dplyr::mutate(example_label = "Partial / mixed valid coverage")
) %>%
  dplyr::left_join(gc_max_coverage, by = "plot_id") %>%
  dplyr::mutate(
    valid_fraction = dplyr::if_else(.data$max_valid_coverage_count > 0, .data$valid_coverage_count / .data$max_valid_coverage_count, 0),
    panel_title = paste0(.data$example_label, "\n", .data$plot_id, " | ", .data$date_midpoint),
    panel_subtitle = paste0("Status: ", stringr::str_replace_all(.data$valid_coverage_status, "_", " "), "; valid support approx. ", fmt_num(100 * .data$valid_fraction, 0, "%"))
  )

gc_panels <- lapply(seq_len(nrow(gc_example_rows)), function(i) {
  row <- gc_example_rows[i, ]
  make_support_panel(
    make_support_tiles(row$valid_fraction, mode = "ground_cover"),
    row$panel_title,
    row$panel_subtitle,
    mode = "ground_cover"
  )
})

gc_examples_plot <- patchwork::wrap_plots(gc_panels, ncol = 2, guides = "collect") +
  patchwork::plot_annotation(
    title = "Ground-cover raster extraction support examples",
    subtitle = "Examples illustrate how raster support varies among plots and dates.",
    caption = "Red outline = 1 ha plot. Grey dashed outline = one-pixel contextual buffer for visual QA only; extraction itself is not buffered."
  ) &
  theme_review(base_size = 12) &
  ggplot2::theme(legend.position = "bottom")

gc_examples_path <- save_png(gc_examples_plot, "ground_cover_extraction_examples_panel.png", width = 12, height = 8.8)

add_manifest(
  "ground_cover_extraction_examples_panel.png",
  "Ground-cover raster extraction support examples",
  "extraction_examples",
  "scripts/13_make_adrian_review_png_assets.R",
  "Output/csv/04c_fractional_cover_full.csv; Output/diagnostics/04c_fractional_cover_full_valid_coverage_by_plot.csv",
  gc_examples_path,
  paste0("Simplified support schematic from existing extraction/QA tables. Example plots: ", paste(unique(gc_example_rows$plot_id), collapse = ", "), "."),
  "schematic_review"
)


## 5. Inundation raster extraction / calculation examples ----


annual_examples <- dplyr::bind_rows(
  annual_inundation %>%
    dplyr::filter(.data$inundated_any_pct >= 99) %>%
    dplyr::arrange(dplyr::desc(.data$inundated_any_pct)) %>%
    dplyr::slice_head(n = 1) %>%
    dplyr::mutate(example_label = "Strong / clear inundation support"),
  annual_inundation %>%
    dplyr::filter(.data$inundated_any_pct > 0.5, .data$inundated_any_pct <= 5) %>%
    dplyr::arrange(abs(.data$inundated_any_pct - 2.5)) %>%
    dplyr::slice_head(n = 1) %>%
    dplyr::mutate(example_label = "Edge / small intersection case"),
  annual_inundation %>%
    dplyr::filter(.data$inundated_any_pct >= 35, .data$inundated_any_pct <= 65) %>%
    dplyr::arrange(abs(.data$inundated_any_pct - 50)) %>%
    dplyr::slice_head(n = 1) %>%
    dplyr::mutate(example_label = "Mixed / partial inundation support"),
  annual_inundation %>%
    dplyr::filter(.data$inundated_any_pct == 0) %>%
    dplyr::arrange(.data$plot_id, .data$water_year) %>%
    dplyr::slice_head(n = 1) %>%
    dplyr::mutate(example_label = "Valid dry / no inundation detected")
) %>%
  dplyr::mutate(
    valid_fraction = pmin(.data$valid_coverage_pct / 100, 1),
    wet_fraction = pmin(.data$inundated_any_pct / 100, 1),
    panel_title = paste0(.data$example_label, "\n", .data$plot_id, " | WY ", .data$water_year),
    panel_subtitle = paste0("Inundated area: ", fmt_num(.data$inundated_any_pct, 2, "%"), "; valid coverage: ", fmt_num(.data$valid_coverage_pct, 1, "%"))
  )

inundation_panels <- lapply(seq_len(nrow(annual_examples)), function(i) {
  row <- annual_examples[i, ]
  make_support_panel(
    make_support_tiles(row$valid_fraction, wet_fraction = row$wet_fraction, mode = "inundation"),
    row$panel_title,
    row$panel_subtitle,
    mode = "inundation"
  )
})

inundation_examples_plot <- patchwork::wrap_plots(inundation_panels, ncol = 2, guides = "collect") +
  patchwork::plot_annotation(
    title = "Inundation raster extraction support examples",
    subtitle = "Inundation summaries are derived by intersecting raster cells with 1 ha plots and aggregating plot-level support.",
    caption = "Red outline = 1 ha plot. Grey dashed outline = contextual QA buffer only."
  ) &
  theme_review(base_size = 12) &
  ggplot2::theme(legend.position = "bottom")

inundation_examples_path <- save_png(inundation_examples_plot, "inundation_extraction_examples_panel.png", width = 12, height = 8.8)

add_manifest(
  "inundation_extraction_examples_panel.png",
  "Inundation raster extraction support examples",
  "extraction_examples",
  "scripts/13_make_adrian_review_png_assets.R",
  "Output/csv/curated_annual_inundation_timeseries.csv; Output/diagnostics/05c_landsat_inundation_full_coverage_summary.csv",
  inundation_examples_path,
  paste0("Simplified support schematic from existing annual inundation tables. Example plots: ", paste(unique(annual_examples$plot_id), collapse = ", "), ". Annual table has adequate coverage for all rows; no poor-support annual example was available."),
  "schematic_review"
)


## 6. Treatment sanity-check figure ----


treatment_data <- plot_summary %>%
  dplyr::select("plot_id", "treatment", "delta_total_veg_pct", "delta_bare_ground_pct") %>%
  tidyr::pivot_longer(
    cols = c("delta_total_veg_pct", "delta_bare_ground_pct"),
    names_to = "metric",
    values_to = "delta_pct"
  ) %>%
  dplyr::mutate(metric = dplyr::case_when(
    .data$metric == "delta_total_veg_pct" ~ "Total vegetation",
    .data$metric == "delta_bare_ground_pct" ~ "Bare ground",
    TRUE ~ .data$metric
  ))

treatment_plot <- ggplot2::ggplot(treatment_data, ggplot2::aes(x = .data$treatment, y = .data$delta_pct)) +
  ggplot2::geom_hline(yintercept = 0, colour = "grey45", linewidth = 0.4) +
  ggplot2::geom_boxplot(width = 0.55, fill = "grey93", colour = "grey35", outlier.shape = NA) +
  ggplot2::geom_jitter(ggplot2::aes(colour = .data$metric), width = 0.11, height = 0, size = 2.3, alpha = 0.82) +
  ggplot2::facet_wrap(~ metric, nrow = 1) +
  ggplot2::scale_colour_manual(values = c("Total vegetation" = "#59a14f", "Bare ground" = "#b07d3c")) +
  ggplot2::labs(
    title = "Secondary treatment sanity check",
    subtitle = "Treatment is metadata here; this is not the primary causal story.",
    x = "Treatment metadata",
    y = "Post-minus-pre ground-cover change (percentage points)",
    colour = "Response",
    caption = "Use as a secondary descriptive check alongside inundation-change and vegetation-group summaries."
  ) +
  theme_review(base_size = 13)

treatment_path <- save_png(treatment_plot, "treatment_sanity_check_review.png")

add_manifest(
  "treatment_sanity_check_review.png",
  "Secondary treatment sanity check",
  "treatment_sanity_check",
  "scripts/13_make_adrian_review_png_assets.R",
  "Output/csv/10a_ground_cover_prepost_plot_summary.csv",
  treatment_path,
  "Secondary descriptive check only; treatment is not framed as the primary causal story.",
  "review_ready_secondary"
)


## 7. Dashboard metric explanation mini-figure ----


explanation_data <- tibble::tibble(
  metric = c("Occurrence frequency", "Annual inundated area", "Why they can differ"),
  definition = c(
    "Percent of valid years with any detected inundation.",
    "Percent of the 1 ha plot inundated in each year.",
    "A plot can have fewer wet years but larger inundated area in the years that are wet."
  ),
  slide_note = c(
    "Used for pre/post class labels.",
    "Shown as annual points/boxplots on dashboards.",
    "This can make a drier occurrence class look wetter in annual-area variation."
  )
) %>%
  dplyr::mutate(
    metric_ordered = factor(.data$metric, levels = rev(.data$metric))
)

explanation_plot <- ggplot2::ggplot(explanation_data, ggplot2::aes(y = .data$metric_ordered)) +
  ggplot2::geom_tile(ggplot2::aes(x = 1), width = 0.94, height = 0.82, fill = "#f2f2f2", colour = "white") +
  ggplot2::geom_text(ggplot2::aes(x = 0.55, label = .data$metric), hjust = 0, fontface = "bold", size = 5) +
  ggplot2::geom_text(ggplot2::aes(x = 1.35, label = stringr::str_wrap(.data$definition, 48)), hjust = 0, size = 4.4) +
  ggplot2::geom_text(ggplot2::aes(x = 2.55, label = stringr::str_wrap(.data$slide_note, 44)), hjust = 0, size = 4.0, colour = "grey25") +
  ggplot2::xlim(0.45, 3.55) +
  ggplot2::labs(
    title = "Dashboard metric guide",
    subtitle = "Occurrence frequency and annual inundated area answer related but different questions.",
    x = NULL,
    y = NULL,
    caption = "Descriptive interpretation aid for review dashboards."
  ) +
  theme_review(base_size = 13) +
  ggplot2::theme(
    axis.text = ggplot2::element_blank(),
    panel.grid = ggplot2::element_blank()
  )

explanation_path <- save_png(explanation_plot, "dashboard_metric_explanation.png", width = 12, height = 5.4)

add_manifest(
  "dashboard_metric_explanation.png",
  "Dashboard metric guide",
  "metric_explanation",
  "scripts/13_make_adrian_review_png_assets.R",
  "Conceptual explanation based on curated annual inundation semantics",
  explanation_path,
  "Optional mini-figure explaining why occurrence frequency and annual inundated area variation can differ.",
  "optional_review_ready"
)


## Manifest and handoff ----


readr::write_csv(manifest_rows, figure_manifest_path)
message("Wrote: ", figure_manifest_path)

gc_examples_used <- gc_example_rows %>%
  dplyr::transmute(
    example = .data$example_label,
    plot_id = .data$plot_id,
    date_or_year = as.character(.data$date_midpoint),
    status = .data$valid_coverage_status
  )

inundation_examples_used <- annual_examples %>%
  dplyr::transmute(
    example = .data$example_label,
    plot_id = .data$plot_id,
    date_or_year = as.character(.data$water_year),
    status = paste0("inundated_any_pct=", fmt_num(.data$inundated_any_pct, 2, "%"))
  )

dashboard_selection_notes <- plot_summary %>%
  dplyr::filter(.data$plot_id %in% DASHBOARD_PLOTS) %>%
  dplyr::transmute(
    plot_id = .data$plot_id,
    why_selected = paste0(
      as.character(.data$inundation_change_label),
      "; pre=",
      fmt_num(.data$pre_conservation_inundation_frequency_pct, 1, "%"),
      "; post=",
      fmt_num(.data$post_conservation_inundation_frequency_pct, 1, "%"),
      "; GC d veg=",
      fmt_signed(.data$delta_total_veg_pct, 1, " ppt"),
      ifelse(.data$rarely_inundated, "; rarely inundated example", "")
    )
  )

visual_review_rows <- dashboard_index %>%
  dplyr::filter(stringr::str_starts(.data$visual_consistency_note, "Review:"))

handoff_lines <- c(
  "# Adrian Review PNG Assets Handoff Report",
  "",
  paste0("Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
  "",
  "## Scope",
  "",
  "Created standalone review-ready PNG files for manual PowerPoint updating. No PowerPoint files were created or modified. No extraction, raster processing, BFAST, or tbreak scripts were run.",
  "",
  "## PNGs Created",
  "",
  paste0("- `", manifest_rows$filename, "`: ", manifest_rows$figure_title, " [", manifest_rows$figure_family, "]"),
  "",
  "## Scripts Created Or Modified",
  "",
  "- Created `scripts/13_make_adrian_review_png_assets.R`.",
  "",
  "## Input Data Used",
  "",
  paste0("- `", input_paths, "`"),
  if (file.exists(lag_by_plot_path)) paste0("- `", lag_by_plot_path, "`") else "- Step 12 lag diagnostics by plot was not present; fallback selection would have been used.",
  if (file.exists(gc_coverage_summary_path)) paste0("- `", gc_coverage_summary_path, "`") else "- Ground-cover coverage summary not present.",
  if (file.exists(annual_coverage_summary_path)) paste0("- `", annual_coverage_summary_path, "`") else "- Annual inundation coverage summary not present.",
  "",
  "## Dashboard Sites",
  "",
  paste0("- `", dashboard_selection_notes$plot_id, "`: ", dashboard_selection_notes$why_selected),
  "",
  "## Ground-Cover Extraction Example Plots",
  "",
  paste0("- ", gc_examples_used$example, ": `", gc_examples_used$plot_id, "`, ", gc_examples_used$date_or_year, ", ", gc_examples_used$status),
  "",
  "## Inundation Extraction Example Plots",
  "",
  paste0("- ", inundation_examples_used$example, ": `", inundation_examples_used$plot_id, "`, ", inundation_examples_used$date_or_year, ", ", inundation_examples_used$status),
  "",
  "## Timing Overlap Period",
  "",
  paste0("- Overlap period used: ", overlap_start, " to ", overlap_end, "."),
  "",
  "## Dashboard Visual Consistency",
  "",
  if (nrow(visual_review_rows) == 0) {
    "- No dashboard classifications were flagged as visually inconsistent with the annual inundated-area boxplot."
  } else {
    paste0("- `", visual_review_rows$plot_id, "`: ", visual_review_rows$visual_consistency_note)
  },
  "",
  "## Heavy Processing",
  "",
  "- Heavy raster/extraction scripts run: no.",
  "- PowerPoint files created or modified: no.",
  "",
  "## Unresolved Issues For Human Review",
  "",
  "- Extraction example panels are simplified support schematics derived from existing extraction/QA CSVs, not newly rendered raster cutouts.",
  "- Annual inundation curated rows all have adequate coverage, so the inundation extraction panel uses a valid dry/no-inundation example instead of a true poor-support annual example.",
  "- Review any dashboard rows flagged in `dashboard_index.csv` where occurrence-frequency class and annual-area variation tell different stories."
)

readr::write_lines(handoff_lines, handoff_report_path)
message("Wrote: ", handoff_report_path)

message("Adrian review PNG asset generation complete. PNG count: ", nrow(manifest_rows))
