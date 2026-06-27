####################################################################################################


## GAYINI REMOTE SENSING PROJECT


## 07d_make_selected_plot_dashboards.R


####################################################################################################


## Purpose ----


## Create pre-BFAST plot dashboards for selected 1 ha plots.


## Each dashboard is intended as an Adrian-review page for a single plot, showing:
##
##   1. Plot metadata and first-pass interpretation notes.
##   2. Ground-cover history from the 04c Landsat fractional-cover extraction.
##   3. Annual Landsat inundation history from 05c.
##   4. Monthly daily-inundation history from 06c, separated by sensor.
##
## This script comes before BFAST/tbreak. It is descriptive only and does not make
## causal claims about treatment effects or change points.


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


HAS_PATCHWORK <- requireNamespace("patchwork", quietly = TRUE)


if (!HAS_PATCHWORK) {
  message("Package patchwork not installed. Dashboards will be written as separate panel PNGs plus summary CSV rows.")
}


## User settings ----


## Add known/anomalous plots here. GA_029 is useful because it was flagged as a
## small/clipped plot; GA_032 appeared in low-valid-coverage checks.

MANUAL_PLOT_IDS <- c("GA_029", "GA_032")


## The script also auto-selects examples: wettest, driest, greenest, barest and
## lowest ground-cover data coverage.

USE_AUTO_SELECTED_PLOTS <- TRUE
MAX_AUTO_SELECTED_PLOTS <- 6


## Ground-cover dashboard panels use adequate-coverage observations only.

USE_ADEQUATE_GC_ONLY <- TRUE


FIGURE_DPI <- 300
BASE_SIZE  <- 14


## Paths ----


plot_master_path <- file.path(
  root_dir,
  "data_processed",
  "plot_master.csv"
)


fc_path <- file.path(
  root_dir,
  "Output",
  "csv",
  "04c_fractional_cover_full.csv"
)


annual_inundation_path <- file.path(
  root_dir,
  "Output",
  "csv",
  "05c_landsat_inundation_full.csv"
)


daily_inundation_path <- file.path(
  root_dir,
  "Output",
  "csv",
  "06c_daily_inundation_full.csv"
)


output_dir <- file.path(
  root_dir,
  "Output",
  "figures",
  "review",
  "plot_dashboards"
)


panel_dir <- file.path(
  output_dir,
  "panels_if_no_patchwork"
)


csv_dir <- file.path(
  root_dir,
  "Output",
  "csv",
  "review"
)


gayini_review_make_dir(output_dir)
gayini_review_make_dir(panel_dir)
gayini_review_make_dir(csv_dir)


dashboard_summary_path <- file.path(
  csv_dir,
  "07d_selected_plot_dashboard_summary.csv"
)


## Read data ----


gayini_review_required_file(plot_master_path)
gayini_review_required_file(fc_path)
gayini_review_required_file(annual_inundation_path)
gayini_review_required_file(daily_inundation_path)


plot_master <- readr::read_csv(plot_master_path, show_col_types = FALSE)
fc <- readr::read_csv(fc_path, show_col_types = FALSE)
annual_inundation <- readr::read_csv(annual_inundation_path, show_col_types = FALSE)
daily_inundation <- readr::read_csv(daily_inundation_path, show_col_types = FALSE)


## Prepare summaries for selection and dashboard notes ----


fc_date_status <- fc |>
  dplyr::group_by(.data$plot_id, .data$date_midpoint) |>
  dplyr::summarise(
    all_bands_adequate = all(.data$valid_coverage_status == "adequate_coverage", na.rm = TRUE),
    all_bands_missing  = all(is.na(.data$mean_value)),
    .groups            = "drop"
  )


fc_coverage_summary <- fc_date_status |>
  dplyr::group_by(.data$plot_id) |>
  dplyr::summarise(
    gc_plot_dates             = dplyr::n(),
    gc_all_bands_adequate_pct = 100 * mean(.data$all_bands_adequate, na.rm = TRUE),
    gc_all_bands_missing_pct  = 100 * mean(.data$all_bands_missing, na.rm = TRUE),
    .groups                   = "drop"
  )


fc_value_summary <- fc |>
  dplyr::filter(.data$valid_coverage_status == "adequate_coverage") |>
  dplyr::mutate(cover_class = gayini_review_cover_label(.data$band_label)) |>
  dplyr::group_by(.data$plot_id, .data$cover_class) |>
  dplyr::summarise(
    mean_cover_pct = gayini_review_safe_mean(.data$mean_value),
    .groups        = "drop"
  ) |>
  tidyr::pivot_wider(
    names_from   = .data$cover_class,
    values_from  = .data$mean_cover_pct,
    names_prefix = "mean_"
  ) |>
  dplyr::rename_with(
    .fn = ~ gsub("[^A-Za-z0-9]+", "_", .x),
    .cols = dplyr::everything()
  )


annual_summary <- annual_inundation |>
  dplyr::group_by(.data$plot_id) |>
  dplyr::summarise(
    annual_mean_inundated_any_pct = gayini_review_safe_mean(.data$inundated_any_pct),
    annual_max_inundated_any_pct  = gayini_review_safe_max(.data$inundated_any_pct),
    annual_years_with_flood       = sum(.data$inundated_any_pct > 0, na.rm = TRUE),
    annual_rows                   = dplyr::n(),
    .groups                       = "drop"
  )


daily_summary <- daily_inundation |>
  dplyr::group_by(.data$plot_id) |>
  dplyr::summarise(
    daily_mean_inundated_pct             = gayini_review_safe_mean(.data$daily_inundated_pct),
    daily_max_inundated_pct              = gayini_review_safe_max(.data$daily_inundated_pct),
    daily_mean_valid_interpretation_pct  = gayini_review_safe_mean(.data$valid_interpretation_pct),
    daily_mean_cloud_shadow_pct          = gayini_review_safe_mean(.data$value_3_cloud_shadow_pct),
    daily_rows                           = dplyr::n(),
    .groups                              = "drop"
  )


plot_summary <- plot_master |>
  dplyr::left_join(fc_coverage_summary, by = "plot_id") |>
  dplyr::left_join(fc_value_summary, by = "plot_id") |>
  dplyr::left_join(annual_summary, by = "plot_id") |>
  dplyr::left_join(daily_summary, by = "plot_id")


## Add first-pass flags ----


bare_col  <- "mean_Bare_ground"
green_col <- "mean_Green_PV"


if (!bare_col %in% names(plot_summary)) {
  plot_summary[[bare_col]] <- NA_real_
}


if (!green_col %in% names(plot_summary)) {
  plot_summary[[green_col]] <- NA_real_
}


bare_q75 <- stats::quantile(plot_summary[[bare_col]], probs = 0.75, na.rm = TRUE)
green_q75 <- stats::quantile(plot_summary[[green_col]], probs = 0.75, na.rm = TRUE)
annual_wet_q75 <- stats::quantile(plot_summary$annual_mean_inundated_any_pct, probs = 0.75, na.rm = TRUE)


plot_summary <- plot_summary |>
  dplyr::rowwise() |>
  dplyr::mutate(
    flag_low_gc_coverage = !is.na(.data$gc_all_bands_adequate_pct) && .data$gc_all_bands_adequate_pct < 80,
    flag_high_bare       = !is.na(.data[[bare_col]]) && .data[[bare_col]] >= bare_q75,
    flag_high_green      = !is.na(.data[[green_col]]) && .data[[green_col]] >= green_q75,
    flag_wet             = !is.na(.data$annual_mean_inundated_any_pct) && .data$annual_mean_inundated_any_pct >= annual_wet_q75,
    flag_rarely_wet      = !is.na(.data$annual_max_inundated_any_pct) && .data$annual_max_inundated_any_pct < 1,
    review_notes         = gayini_review_collapse_notes(c(
      if (flag_low_gc_coverage) "lower ground-cover data coverage",
      if (flag_high_bare) "relatively high bare-ground signal",
      if (flag_high_green) "relatively high green-cover signal",
      if (flag_wet) "relatively wet / flood-exposed plot",
      if (flag_rarely_wet) "rarely inundated in annual product"
    ))
  ) |>
  dplyr::ungroup()


## Select plots ----


auto_plot_ids <- character(0)


if (isTRUE(USE_AUTO_SELECTED_PLOTS)) {

  auto_plot_ids <- c(
    plot_summary |>
      dplyr::slice_max(.data$annual_mean_inundated_any_pct, n = 1, with_ties = FALSE) |>
      dplyr::pull(.data$plot_id),
    plot_summary |>
      dplyr::slice_min(.data$annual_mean_inundated_any_pct, n = 1, with_ties = FALSE) |>
      dplyr::pull(.data$plot_id),
    plot_summary |>
      dplyr::slice_max(.data[[bare_col]], n = 1, with_ties = FALSE) |>
      dplyr::pull(.data$plot_id),
    plot_summary |>
      dplyr::slice_max(.data[[green_col]], n = 1, with_ties = FALSE) |>
      dplyr::pull(.data$plot_id),
    plot_summary |>
      dplyr::slice_min(.data$gc_all_bands_adequate_pct, n = 1, with_ties = FALSE) |>
      dplyr::pull(.data$plot_id)
  )

  auto_plot_ids <- unique(auto_plot_ids)
  auto_plot_ids <- utils::head(auto_plot_ids, MAX_AUTO_SELECTED_PLOTS)
}


selected_plot_ids <- unique(c(MANUAL_PLOT_IDS, auto_plot_ids))
selected_plot_ids <- selected_plot_ids[selected_plot_ids %in% plot_summary$plot_id]


if (length(selected_plot_ids) == 0) {
  stop("No selected plots were found in plot_master.csv.", call. = FALSE)
}


selected_summary <- plot_summary |>
  dplyr::filter(.data$plot_id %in% selected_plot_ids) |>
  dplyr::mutate(selection_order = match(.data$plot_id, selected_plot_ids)) |>
  dplyr::arrange(.data$selection_order)


readr::write_csv(selected_summary, dashboard_summary_path)


message("Wrote: ", dashboard_summary_path)
message("Selected plots: ", paste(selected_plot_ids, collapse = ", "))


## Dashboard data ----


fc_dashboard <- fc |>
  dplyr::mutate(
    date_plot   = as.Date(.data$date_midpoint),
    cover_class = gayini_review_cover_label(.data$band_label)
  )


if (isTRUE(USE_ADEQUATE_GC_ONLY)) {
  fc_dashboard <- fc_dashboard |>
    dplyr::filter(.data$valid_coverage_status == "adequate_coverage")
}


daily_monthly <- daily_inundation |>
  dplyr::mutate(
    date_start = as.Date(.data$date_start),
    month      = lubridate::floor_date(.data$date_start, unit = "month")
  ) |>
  dplyr::group_by(.data$plot_id, .data$sensor, .data$month) |>
  dplyr::summarise(
    monthly_mean_daily_inundated_pct      = gayini_review_safe_mean(.data$daily_inundated_pct),
    monthly_max_daily_inundated_pct       = gayini_review_safe_max(.data$daily_inundated_pct),
    monthly_mean_valid_interpretation_pct = gayini_review_safe_mean(.data$valid_interpretation_pct),
    n_daily_observations                  = dplyr::n_distinct(.data$date_start),
    .groups                               = "drop"
  )


## Plot-panel functions ----


make_notes_panel <- function(plot_id) {

  s <- plot_summary |>
    dplyr::filter(.data$plot_id == !!plot_id) |>
    dplyr::slice(1)

  label_lines <- c(
    paste0("Plot ", plot_id),
    paste0("Treatment: ", s$treatment, " | Vegetation: ", s$vegetation),
    paste0("Area: ", round(s$area_ha, 3), " ha"),
    paste0(
      "GC adequate: ", round(s$gc_all_bands_adequate_pct, 1), "% | ",
      "Annual mean inundated: ", round(s$annual_mean_inundated_any_pct, 1), "% | ",
      "Daily mean inundated: ", round(s$daily_mean_inundated_pct, 1), "%"
    ),
    paste0(
      "Mean green/PV: ", round(s[[green_col]], 1), "% | ",
      "Mean bare: ", round(s[[bare_col]], 1), "%"
    ),
    paste0("Review notes: ", s$review_notes)
  )

  label_text <- stringr::str_wrap(paste(label_lines, collapse = "\n"), width = 140)

  ggplot2::ggplot() +
    ggplot2::annotate(
      geom  = "text",
      x     = 0,
      y     = 1,
      label = label_text,
      hjust = 0,
      vjust = 1,
      size  = 4.7
    ) +
    ggplot2::xlim(0, 1) +
    ggplot2::ylim(0, 1) +
    ggplot2::labs(title = "Plot summary") +
    ggplot2::theme_void(base_size = BASE_SIZE) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(size = BASE_SIZE + 2, face = "bold", hjust = 0)
    )
}


make_ground_cover_panel <- function(plot_id) {

  plot_data <- fc_dashboard |>
    dplyr::filter(.data$plot_id == !!plot_id)

  ggplot2::ggplot(
    plot_data,
    ggplot2::aes(
      x      = .data$date_plot,
      y      = .data$mean_value,
      group  = .data$cover_class,
      colour = .data$cover_class
    )
  ) +
    ggplot2::geom_line(linewidth = 0.65, na.rm = TRUE) +
    ggplot2::geom_point(size = 1.1, alpha = 0.8, na.rm = TRUE) +
    ggplot2::coord_cartesian(ylim = c(0, 100)) +
    ggplot2::scale_x_date(date_breaks = "5 years", date_labels = "%Y") +
    ggplot2::labs(
      title    = "Ground-cover history",
      subtitle = "04c Landsat fractional cover; adequate coverage only; cover labels provisional.",
      x        = "Date",
      y        = "Cover (%)",
      colour   = "Cover class"
    ) +
    gayini_review_theme(base_size = BASE_SIZE) +
    ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 45, hjust = 1))
}


make_annual_inundation_panel <- function(plot_id) {

  plot_data <- annual_inundation |>
    dplyr::filter(.data$plot_id == !!plot_id) |>
    dplyr::mutate(date_plot = as.Date(.data$date_start))

  ggplot2::ggplot(
    plot_data,
    ggplot2::aes(
      x = .data$date_plot,
      y = .data$inundated_any_pct
    )
  ) +
    ggplot2::geom_col(width = 250, alpha = 0.85, na.rm = TRUE) +
    ggplot2::coord_cartesian(ylim = c(0, 100)) +
    ggplot2::scale_x_date(date_breaks = "5 years", date_labels = "%Y") +
    ggplot2::labs(
      title    = "Annual Landsat inundation history",
      subtitle = "05c annual/water-year product; metric = area with annual inundation count > 0.",
      x        = "Water year start",
      y        = "Inundated area (%)"
    ) +
    gayini_review_theme(base_size = BASE_SIZE) +
    ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 45, hjust = 1))
}


make_daily_monthly_panel <- function(plot_id) {

  plot_data <- daily_monthly |>
    dplyr::filter(.data$plot_id == !!plot_id)

  ggplot2::ggplot(
    plot_data,
    ggplot2::aes(
      x      = .data$month,
      y      = .data$monthly_mean_daily_inundated_pct,
      group  = .data$sensor,
      colour = .data$sensor
    )
  ) +
    ggplot2::geom_line(linewidth = 0.65, na.rm = TRUE) +
    ggplot2::geom_point(size = 1.1, alpha = 0.85, na.rm = TRUE) +
    ggplot2::coord_cartesian(ylim = c(0, 100)) +
    ggplot2::scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
    ggplot2::labs(
      title    = "Monthly daily-inundation history",
      subtitle = "06c daily product aggregated to monthly mean; sensor groups retained separately.",
      x        = "Month",
      y        = "Mean daily inundated area (%)",
      colour   = "Sensor"
    ) +
    gayini_review_theme(base_size = BASE_SIZE) +
    ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 45, hjust = 1))
}


## Create dashboards ----


for (plot_id in selected_plot_ids) {

  message("Creating dashboard for ", plot_id)

  notes_panel  <- make_notes_panel(plot_id)
  gc_panel     <- make_ground_cover_panel(plot_id)
  annual_panel <- make_annual_inundation_panel(plot_id)
  daily_panel  <- make_daily_monthly_panel(plot_id)

  plot_stub <- gayini_review_clean_filename(plot_id)

  if (HAS_PATCHWORK) {

    dashboard <- patchwork::wrap_plots(
      list(notes_panel, gc_panel, annual_panel, daily_panel),
      ncol    = 1,
      heights = c(1.05, 2.4, 1.75, 1.95)
    )

    dashboard_path <- file.path(
      output_dir,
      paste0("07d_plot_dashboard_", plot_stub, ".png")
    )

    gayini_review_save_png(
      plot   = dashboard,
      path   = dashboard_path,
      width  = 13.5,
      height = 15,
      dpi    = FIGURE_DPI
    )

  } else {

    gayini_review_save_png(
      plot   = notes_panel,
      path   = file.path(panel_dir, paste0("07d_", plot_stub, "_01_notes.png")),
      width  = 13.5,
      height = 3.0,
      dpi    = FIGURE_DPI
    )

    gayini_review_save_png(
      plot   = gc_panel,
      path   = file.path(panel_dir, paste0("07d_", plot_stub, "_02_ground_cover.png")),
      width  = 13.5,
      height = 5.0,
      dpi    = FIGURE_DPI
    )

    gayini_review_save_png(
      plot   = annual_panel,
      path   = file.path(panel_dir, paste0("07d_", plot_stub, "_03_annual_inundation.png")),
      width  = 13.5,
      height = 4.0,
      dpi    = FIGURE_DPI
    )

    gayini_review_save_png(
      plot   = daily_panel,
      path   = file.path(panel_dir, paste0("07d_", plot_stub, "_04_daily_monthly_inundation.png")),
      width  = 13.5,
      height = 4.5,
      dpi    = FIGURE_DPI
    )
  }
}


## Finish ----


message("07d selected plot dashboards complete.")
message("Dashboard folder: ", output_dir)
message("Summary table: ", dashboard_summary_path)
