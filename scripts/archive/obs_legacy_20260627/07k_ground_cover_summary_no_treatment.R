## -----------------------------------------------------------------------------
## Gayini remote sensing workflow
## 07k_ground_cover_summary_no_treatment.R
## -----------------------------------------------------------------------------


## Purpose:
## Rework ground-cover summary figures so they do not use treatment as the main
## factor. The primary figure now shows total vegetation and bare ground:
##   total vegetation = green / PV + non-green / NPV
##   bare ground      = TERN/JRSRP band 1


## User settings ----


root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", "D:/Github_repos/Gayini"), winslash = "/", mustWork = TRUE)
MANAGEMENT_CHANGE_DATE <- as.Date("2019-07-01")
GAP_DAYS_FOR_NEW_SEGMENT <- 550
ONLY_ADEQUATE_COVERAGE <- TRUE
WRITE_COMPONENT_SUPPLEMENT <- TRUE


## Required packages ----


required_packages <- c(
  "dplyr",
  "tidyr",
  "readr",
  "stringr",
  "purrr",
  "ggplot2",
  "magrittr",
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
library(scales)


## Paths ----


fc_path <- gayini_find_first_existing(c(
  file.path(root_dir, "data_processed", "plot_fractional_cover_timeseries.csv"),
  file.path(root_dir, "Output", "csv", "04c_fractional_cover_full.csv")
))

if (is.na(fc_path)) {
  stop("Could not find fractional-cover output. Run 04c first.", call. = FALSE)
}

figure_dir <- file.path(root_dir, "Output", "figures", "07k_ground_cover_no_treatment")
diagnostics_dir <- file.path(root_dir, "Output", "diagnostics", "step7_figure_luts")

dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(diagnostics_dir, recursive = TRUE, showWarnings = FALSE)

band_check_path <- file.path(diagnostics_dir, "07k_ground_cover_band_mapping_check.csv")
summary_path <- file.path(diagnostics_dir, "07k_ground_cover_total_veg_bare_summary.csv")
component_summary_path <- file.path(diagnostics_dir, "07k_ground_cover_component_summary.csv")
valid_count_path <- file.path(diagnostics_dir, "07k_ground_cover_valid_plot_count_by_date.csv")


## Read and standardise data ----


fc_long <- gayini_prepare_ground_cover_long(
  fc_path = fc_path,
  only_adequate_coverage = ONLY_ADEQUATE_COVERAGE,
  object_name = "fractional-cover table"
)

band_check <- fc_long %>%
  dplyr::count(.data$band_number, .data$cover_class, .data$tern_band_mapping_note, name = "n_rows") %>%
  dplyr::arrange(.data$band_number, .data$cover_class)

readr::write_csv(band_check, band_check_path)
message("Wrote: ", band_check_path)

if (!all(c("Bare ground", "Green / PV", "Non-green / NPV") %in% unique(fc_long$cover_class))) {
  warning(
    "Not all expected TERN/JRSRP ground-cover classes are present after recoding. Inspect: ",
    band_check_path,
    call. = FALSE
  )
}

fc_total_bare <- gayini_prepare_ground_cover_total_bare(fc_long)


## Plot bounds and pre/post shading ----


observed_date_min <- min(fc_total_bare$date_plot, na.rm = TRUE)
observed_date_max <- max(fc_total_bare$date_plot, na.rm = TRUE)
plot_x_min <- observed_date_min - 180
plot_x_max <- observed_date_max + 180

period_rects <- tibble::tibble(
  period = c("Pre-conservation", "Post-conservation"),
  xmin = c(plot_x_min, max(MANAGEMENT_CHANGE_DATE, plot_x_min)),
  xmax = c(min(MANAGEMENT_CHANGE_DATE, plot_x_max), plot_x_max),
  fill = c("pre", "post")
) %>%
  dplyr::filter(.data$xmin < .data$xmax)


## Summary across plots by date and metric ----


gc_summary <- fc_total_bare %>%
  dplyr::filter(!is.na(.data$date_plot), !is.na(.data$cover_pct)) %>%
  dplyr::group_by(.data$metric, .data$metric_key, .data$metric_note, .data$date_plot) %>%
  dplyr::summarise(
    n_plots = dplyr::n_distinct(.data$plot_id),
    median_cover_pct = median(.data$cover_pct, na.rm = TRUE),
    q25_cover_pct = stats::quantile(.data$cover_pct, probs = 0.25, na.rm = TRUE),
    q75_cover_pct = stats::quantile(.data$cover_pct, probs = 0.75, na.rm = TRUE),
    mean_cover_pct = mean(.data$cover_pct, na.rm = TRUE),
    sd_cover_pct = stats::sd(.data$cover_pct, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  dplyr::arrange(.data$metric, .data$date_plot) %>%
  gayini_add_gap_segments(
    date_col = "date_plot",
    group_cols = c("metric"),
    gap_days_for_new_segment = GAP_DAYS_FOR_NEW_SEGMENT
  )

readr::write_csv(gc_summary, summary_path)
message("Wrote: ", summary_path)

valid_count <- fc_total_bare %>%
  dplyr::filter(!is.na(.data$date_plot)) %>%
  dplyr::group_by(.data$date_plot) %>%
  dplyr::summarise(n_plots_with_valid_fc = dplyr::n_distinct(.data$plot_id[!is.na(.data$cover_pct)]), .groups = "drop")

readr::write_csv(valid_count, valid_count_path)
message("Wrote: ", valid_count_path)


## Primary total vegetation / bare ground figure ----


primary_plot <- ggplot2::ggplot(gc_summary, ggplot2::aes(x = .data$date_plot, y = .data$median_cover_pct)) +
  ggplot2::geom_rect(
    data = period_rects,
    ggplot2::aes(xmin = .data$xmin, xmax = .data$xmax, ymin = -Inf, ymax = Inf, fill = .data$fill),
    inherit.aes = FALSE,
    alpha = 0.22,
    show.legend = FALSE
  ) +
  ggplot2::scale_fill_manual(values = c(pre = "grey88", post = "grey97")) +
  ggplot2::geom_ribbon(
    ggplot2::aes(ymin = .data$q25_cover_pct, ymax = .data$q75_cover_pct, group = interaction(.data$metric, .data$segment_id)),
    fill = "grey75",
    alpha = 0.35
  ) +
  ggplot2::geom_line(
    ggplot2::aes(colour = .data$metric, group = interaction(.data$metric, .data$segment_id)),
    linewidth = 0.65
  ) +
  ggplot2::geom_point(ggplot2::aes(colour = .data$metric), size = 0.85) +
  ggplot2::geom_vline(xintercept = MANAGEMENT_CHANGE_DATE, linetype = "dashed", colour = "grey20") +
  ggplot2::coord_cartesian(xlim = c(plot_x_min, plot_x_max), ylim = c(0, 100)) +
  ggplot2::scale_x_date(date_breaks = "5 years", date_labels = "%Y") +
  ggplot2::scale_colour_manual(values = c("Total vegetation" = "#1a9850", "Bare ground" = "#8c510a")) +
  ggplot2::labs(
    title = "Landsat ground cover: total vegetation and bare ground",
    subtitle = "Median across suitable 1 ha plots; ribbon = interquartile range. Treatment is not used as the grouping.",
    x = "Raster midpoint date",
    y = "Cover (%)",
    colour = "Metric",
    caption = "Total vegetation = TERN/JRSRP band 2 Green/PV + band 3 Non-green/NPV. Bare ground = band 1. Dashed line = management-change date."
  ) +
  gayini_theme_chart(base_size = 12)

primary_plot_path <- file.path(figure_dir, "07k_gc_total_vegetation_and_bare_median_iqr.png")
ggplot2::ggsave(primary_plot_path, plot = primary_plot, width = 12.5, height = 7.0, dpi = 300)
message("Wrote: ", primary_plot_path)


## Supplementary component figure ----


if (WRITE_COMPONENT_SUPPLEMENT) {

  component_summary <- fc_long %>%
    dplyr::filter(!is.na(.data$date_plot), !is.na(.data$cover_value)) %>%
    dplyr::group_by(.data$cover_class, .data$date_plot) %>%
    dplyr::summarise(
      n_plots = dplyr::n_distinct(.data$plot_id),
      median_cover_pct = median(.data$cover_value, na.rm = TRUE),
      q25_cover_pct = stats::quantile(.data$cover_value, probs = 0.25, na.rm = TRUE),
      q75_cover_pct = stats::quantile(.data$cover_value, probs = 0.75, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    gayini_add_gap_segments(
      date_col = "date_plot",
      group_cols = c("cover_class"),
      gap_days_for_new_segment = GAP_DAYS_FOR_NEW_SEGMENT
    )

  readr::write_csv(component_summary, component_summary_path)
  message("Wrote: ", component_summary_path)

  component_plot <- ggplot2::ggplot(component_summary, ggplot2::aes(x = .data$date_plot, y = .data$median_cover_pct)) +
    ggplot2::geom_rect(
      data = period_rects,
      ggplot2::aes(xmin = .data$xmin, xmax = .data$xmax, ymin = -Inf, ymax = Inf, fill = .data$fill),
      inherit.aes = FALSE,
      alpha = 0.22,
      show.legend = FALSE
    ) +
    ggplot2::scale_fill_manual(values = c(pre = "grey88", post = "grey97")) +
    ggplot2::geom_ribbon(
      ggplot2::aes(ymin = .data$q25_cover_pct, ymax = .data$q75_cover_pct, group = interaction(.data$cover_class, .data$segment_id)),
      fill = "grey75",
      alpha = 0.30
    ) +
    ggplot2::geom_line(ggplot2::aes(colour = .data$cover_class, group = interaction(.data$cover_class, .data$segment_id)), linewidth = 0.55) +
    ggplot2::geom_point(ggplot2::aes(colour = .data$cover_class), size = 0.75) +
    ggplot2::geom_vline(xintercept = MANAGEMENT_CHANGE_DATE, linetype = "dashed", colour = "grey20") +
    ggplot2::coord_cartesian(xlim = c(plot_x_min, plot_x_max), ylim = c(0, 100)) +
    ggplot2::scale_x_date(date_breaks = "5 years", date_labels = "%Y") +
    ggplot2::scale_colour_manual(values = c("Bare ground" = "#8c510a", "Green / PV" = "#1a9850", "Non-green / NPV" = "#80cdc1")) +
    ggplot2::labs(
      title = "Landsat ground-cover components",
      subtitle = "Supplementary median/IQR view using TERN/JRSRP bands. Primary interpretation should use total vegetation + bare ground.",
      x = "Raster midpoint date",
      y = "Cover (%)",
      colour = "Cover class"
    ) +
    gayini_theme_chart(base_size = 12)

  component_plot_path <- file.path(figure_dir, "07k_gc_component_median_iqr_supplement.png")
  ggplot2::ggsave(component_plot_path, plot = component_plot, width = 12.5, height = 7.0, dpi = 300)
  message("Wrote: ", component_plot_path)

}


## Valid plot count over time ----


valid_count_plot <- ggplot2::ggplot(valid_count, ggplot2::aes(x = .data$date_plot, y = .data$n_plots_with_valid_fc)) +
  ggplot2::geom_col(width = 45, fill = "grey55") +
  ggplot2::geom_vline(xintercept = MANAGEMENT_CHANGE_DATE, linetype = "dashed", colour = "grey25") +
  ggplot2::coord_cartesian(xlim = c(plot_x_min, plot_x_max)) +
  ggplot2::scale_x_date(date_breaks = "5 years", date_labels = "%Y") +
  ggplot2::labs(
    title = "Ground-cover data support over time",
    subtitle = "Number of plots with valid fractional-cover observations after the current QA filter.",
    x = "Raster midpoint date",
    y = "Plots with valid data"
  ) +
  gayini_theme_chart(base_size = 12)

valid_count_plot_path <- file.path(figure_dir, "07k_gc_valid_plot_count_by_date.png")
ggplot2::ggsave(valid_count_plot_path, plot = valid_count_plot, width = 12, height = 5.5, dpi = 300)
message("Wrote: ", valid_count_plot_path)

message("07k complete. Wrote outputs to: ", figure_dir)
