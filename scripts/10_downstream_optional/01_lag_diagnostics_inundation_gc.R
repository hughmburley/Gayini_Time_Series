## -----------------------------------------------------------------------------
## Gayini remote sensing workflow
## 01_lag_diagnostics_inundation_gc.R
## -----------------------------------------------------------------------------


## Purpose:
## Lightweight missingness and lag diagnostics linking inundation support to
## ground-cover response. This script reads curated/10a CSV outputs only and
## does not run raster processing, BFAST, or tbreak.


## User settings ----


root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", "D:/Github_repos/Gayini"), winslash = "/", mustWork = TRUE)
MANAGEMENT_CHANGE_DATE <- as.Date("2019-07-01")
MONTHLY_LAGS <- c(0L, 3L, 6L, 9L, 12L)
ANNUAL_LAGS <- c(0L, 1L)
MIN_MONTHLY_LAG_PAIRS <- 4L
MIN_ANNUAL_LAG_PAIRS <- 3L
LOW_GC_OBS_THRESHOLD <- 8L
LOW_ANNUAL_YEARS_THRESHOLD <- 4L
LOW_DAILY_MONTHS_THRESHOLD <- 12L
SELECTED_EXAMPLE_PLOTS <- 6L


## Required packages ----


required_packages <- c(
  "dplyr",
  "tidyr",
  "readr",
  "stringr",
  "ggplot2",
  "magrittr",
  "tibble",
  "scales"
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


## Paths ----


csv_dir <- file.path(root_dir, "Output", "csv")
figure_dir <- file.path(root_dir, "Output", "figures", "12_lag_diagnostics")
diagnostics_dir <- file.path(root_dir, "Output", "diagnostics", "12_lag_diagnostics")

dir.create(csv_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(diagnostics_dir, recursive = TRUE, showWarnings = FALSE)

ground_cover_path <- file.path(csv_dir, "curated_ground_cover_timeseries.csv")
annual_inundation_path <- file.path(csv_dir, "curated_annual_inundation_timeseries.csv")
daily_monthly_path <- file.path(csv_dir, "curated_daily_inundation_monthly.csv")
plot_base_path <- file.path(csv_dir, "plot_rs_analysis_base.csv")
gc_prepost_path <- file.path(csv_dir, "10a_ground_cover_prepost_plot_summary.csv")

support_summary_path <- file.path(csv_dir, "12_lag_plot_support_summary.csv")
lag_by_plot_path <- file.path(csv_dir, "12_lag_diagnostics_by_plot.csv")
lag_group_summary_path <- file.path(csv_dir, "12_lag_diagnostics_group_summary.csv")
figure_index_path <- file.path(diagnostics_dir, "12_figure_index.csv")
handoff_report_path <- file.path(diagnostics_dir, "12_codex_handoff_report.md")

input_paths <- c(
  curated_ground_cover_timeseries = ground_cover_path,
  curated_annual_inundation_timeseries = annual_inundation_path,
  curated_daily_inundation_monthly = daily_monthly_path,
  plot_rs_analysis_base = plot_base_path,
  ground_cover_prepost_plot_summary = gc_prepost_path
)

missing_inputs <- names(input_paths)[!file.exists(input_paths)]

if (length(missing_inputs) > 0) {
  stop(
    "Missing required input(s): ",
    paste(missing_inputs, collapse = ", "),
    call. = FALSE
  )
}


## Helpers ----


write_csv_message <- function(x, path) {
  readr::write_csv(x, path)
  message("Wrote: ", path)
  invisible(x)
}


save_png <- function(plot, file_name, width = 12, height = 7.2, dpi = 300) {
  path <- file.path(figure_dir, file_name)
  ggplot2::ggsave(path, plot = plot, width = width, height = height, dpi = dpi)
  message("Wrote: ", path)
  path
}


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


safe_cor <- function(x, y, min_pairs) {
  ok <- !is.na(x) & !is.na(y)

  if (sum(ok) < min_pairs || stats::sd(x[ok]) == 0 || stats::sd(y[ok]) == 0) {
    return(NA_real_)
  }

  stats::cor(x[ok], y[ok])
}


safe_mean <- function(x) {
  if (all(is.na(x))) {
    return(NA_real_)
  }

  mean(x, na.rm = TRUE)
}


safe_median <- function(x) {
  if (all(is.na(x))) {
    return(NA_real_)
  }

  median(x, na.rm = TRUE)
}


month_start <- function(date) {
  as.Date(sprintf("%s-01", format(as.Date(date), "%Y-%m")))
}


add_months_simple <- function(date, n_months) {
  date <- as.Date(date)
  month_index <- as.integer(format(date, "%Y")) * 12L + as.integer(format(date, "%m")) - 1L + n_months
  year <- month_index %/% 12L
  month <- month_index %% 12L + 1L

  as.Date(sprintf("%04d-%02d-01", year, month))
}


water_year_start <- function(water_year) {
  suppressWarnings(as.integer(stringr::str_sub(as.character(water_year), 1, 4)))
}


theme_lag <- function(base_size = 12) {
  ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      plot.title = ggplot2::element_text(face = "bold", size = base_size + 4),
      plot.subtitle = ggplot2::element_text(size = base_size),
      axis.title = ggplot2::element_text(face = "bold"),
      legend.position = "bottom",
      legend.title = ggplot2::element_text(face = "bold"),
      strip.text = ggplot2::element_text(face = "bold")
    )
}


metric_label <- function(x) {
  dplyr::case_when(
    x == "total_veg_pct" ~ "Total vegetation",
    x == "bare_ground_pct" ~ "Bare ground",
    TRUE ~ x
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
    TRUE ~ stringr::str_replace_all(as.character(x), "_", " ")
  )
}


support_class <- function(n_pairs, min_pairs) {
  dplyr::case_when(
    is.na(n_pairs) | n_pairs == 0 ~ "no_pairs",
    n_pairs < min_pairs ~ "low_support",
    TRUE ~ "adequate_support"
  )
}


## Read inputs ----


message("Reading ground cover: ", ground_cover_path)
ground_cover <- readr::read_csv(ground_cover_path, show_col_types = FALSE) %>%
  gayini_standardise_plot_id(object_name = "curated ground cover")

message("Reading annual inundation: ", annual_inundation_path)
annual_inundation <- readr::read_csv(annual_inundation_path, show_col_types = FALSE) %>%
  gayini_standardise_plot_id(object_name = "curated annual inundation")

message("Reading daily/monthly inundation: ", daily_monthly_path)
daily_monthly <- readr::read_csv(daily_monthly_path, show_col_types = FALSE) %>%
  gayini_standardise_plot_id(object_name = "curated daily inundation monthly")

message("Reading plot analysis base: ", plot_base_path)
plot_base <- readr::read_csv(plot_base_path, show_col_types = FALSE) %>%
  gayini_standardise_plot_id(object_name = "plot analysis base")

message("Reading 10a ground-cover pre/post summary: ", gc_prepost_path)
gc_prepost <- readr::read_csv(gc_prepost_path, show_col_types = FALSE) %>%
  gayini_standardise_plot_id(object_name = "10a ground-cover pre/post summary")

require_columns(
  ground_cover,
  c("plot_id", "date_midpoint", "water_year", "period", "total_veg_pct", "bare_ground_pct", "vegetation_adrian_group"),
  "curated ground cover"
)

require_columns(
  annual_inundation,
  c("plot_id", "water_year", "period", "inundated_any_pct"),
  "curated annual inundation"
)

require_columns(
  daily_monthly,
  c("plot_id", "month_start", "water_year", "period", "mean_daily_inundated_pct", "max_daily_inundated_pct"),
  "curated daily/monthly inundation"
)

require_columns(
  plot_base,
  c("plot_id", "treatment", "vegetation_adrian_group", "post_minus_pre_inundation_frequency_pct_points"),
  "plot analysis base"
)

require_columns(
  gc_prepost,
  c("plot_id", "delta_total_veg_pct", "delta_bare_ground_pct"),
  "10a ground-cover pre/post summary"
)


## Standardise working tables ----


plot_context <- plot_base %>%
  dplyr::select(
    "plot_id",
    dplyr::any_of(c(
      "treatment",
      "vegetation",
      "vegetation_adrian_group",
      "pre_conservation_inundation_frequency_pct",
      "post_conservation_inundation_frequency_pct",
      "post_minus_pre_inundation_frequency_pct_points",
      "inundation_change_class"
    ))
  ) %>%
  dplyr::distinct(.data$plot_id, .keep_all = TRUE)

ground_cover_work <- ground_cover %>%
  dplyr::mutate(
    date_midpoint = as.Date(.data$date_midpoint),
    month_start = month_start(.data$date_midpoint),
    total_veg_pct = as.numeric(.data$total_veg_pct),
    bare_ground_pct = as.numeric(.data$bare_ground_pct)
  )

daily_monthly_work <- daily_monthly %>%
  dplyr::mutate(
    month_start = as.Date(.data$month_start),
    mean_daily_inundated_pct = as.numeric(.data$mean_daily_inundated_pct),
    max_daily_inundated_pct = as.numeric(.data$max_daily_inundated_pct)
  )

annual_inundation_work <- annual_inundation %>%
  dplyr::mutate(
    water_year_start = water_year_start(.data$water_year),
    inundated_any_pct = as.numeric(.data$inundated_any_pct)
  )


## Support and missingness by plot ----


gc_support <- ground_cover_work %>%
  dplyr::group_by(.data$plot_id) %>%
  dplyr::summarise(
    n_gc_observations = dplyr::n_distinct(.data$date_midpoint),
    n_pre_gc_observations = dplyr::n_distinct(.data$date_midpoint[.data$period == "pre_conservation"]),
    n_post_gc_observations = dplyr::n_distinct(.data$date_midpoint[.data$period == "post_conservation"]),
    pct_missing_total_veg = 100 * mean(is.na(.data$total_veg_pct)),
    pct_missing_bare_ground = 100 * mean(is.na(.data$bare_ground_pct)),
    first_gc_date = min(.data$date_midpoint, na.rm = TRUE),
    last_gc_date = max(.data$date_midpoint, na.rm = TRUE),
    .groups = "drop"
  )

annual_support <- annual_inundation_work %>%
  dplyr::group_by(.data$plot_id) %>%
  dplyr::summarise(
    n_annual_inundation_years = dplyr::n_distinct(.data$water_year),
    n_pre_annual_inundation_years = dplyr::n_distinct(.data$water_year[.data$period == "pre_conservation"]),
    n_post_annual_inundation_years = dplyr::n_distinct(.data$water_year[.data$period == "post_conservation"]),
    pct_missing_annual_inundated_any = 100 * mean(is.na(.data$inundated_any_pct)),
    .groups = "drop"
  )

daily_support <- daily_monthly_work %>%
  dplyr::group_by(.data$plot_id) %>%
  dplyr::summarise(
    n_daily_monthly_inundation_months = dplyr::n_distinct(.data$month_start),
    n_pre_daily_monthly_inundation_months = dplyr::n_distinct(.data$month_start[.data$period == "pre_conservation"]),
    n_post_daily_monthly_inundation_months = dplyr::n_distinct(.data$month_start[.data$period == "post_conservation"]),
    pct_missing_mean_daily_inundated = 100 * mean(is.na(.data$mean_daily_inundated_pct)),
    .groups = "drop"
  )

plot_support_summary <- plot_context %>%
  dplyr::left_join(gc_support, by = "plot_id") %>%
  dplyr::left_join(annual_support, by = "plot_id") %>%
  dplyr::left_join(daily_support, by = "plot_id") %>%
  dplyr::mutate(
    dplyr::across(
      c(
        "n_gc_observations",
        "n_pre_gc_observations",
        "n_post_gc_observations",
        "n_annual_inundation_years",
        "n_pre_annual_inundation_years",
        "n_post_annual_inundation_years",
        "n_daily_monthly_inundation_months",
        "n_pre_daily_monthly_inundation_months",
        "n_post_daily_monthly_inundation_months"
      ),
      ~ dplyr::coalesce(.x, 0L)
    ),
    low_gc_support = .data$n_gc_observations < LOW_GC_OBS_THRESHOLD,
    low_pre_gc_support = .data$n_pre_gc_observations < 3L,
    low_post_gc_support = .data$n_post_gc_observations < 3L,
    low_annual_inundation_support = .data$n_annual_inundation_years < LOW_ANNUAL_YEARS_THRESHOLD,
    low_daily_monthly_inundation_support = .data$n_daily_monthly_inundation_months < LOW_DAILY_MONTHS_THRESHOLD,
    lag_support_class = dplyr::case_when(
      .data$low_gc_support | .data$low_annual_inundation_support ~ "low_core_support",
      .data$low_daily_monthly_inundation_support ~ "annual_preferred",
      TRUE ~ "monthly_supported"
    )
  ) %>%
  dplyr::arrange(.data$lag_support_class, .data$plot_id)

write_csv_message(plot_support_summary, support_summary_path)


## Aligned monthly and annual tables ----


gc_monthly <- ground_cover_work %>%
  dplyr::group_by(.data$plot_id, .data$month_start, .data$period) %>%
  dplyr::summarise(
    total_veg_pct = safe_mean(.data$total_veg_pct),
    bare_ground_pct = safe_mean(.data$bare_ground_pct),
    n_gc_records_in_month = dplyr::n(),
    .groups = "drop"
  )

monthly_lag_pairs <- dplyr::bind_rows(lapply(MONTHLY_LAGS, function(lag_months) {
  gc_monthly %>%
    dplyr::mutate(
      lag_months = lag_months,
      inundation_month_start = add_months_simple(.data$month_start, -lag_months)
    ) %>%
    dplyr::left_join(
      daily_monthly_work %>%
        dplyr::select(
          "plot_id",
          inundation_month_start = "month_start",
          "mean_daily_inundated_pct",
          "max_daily_inundated_pct",
          "n_daily_observations",
          "n_daily_wet_observations"
        ),
      by = c("plot_id", "inundation_month_start")
    )
}))

gc_annual <- ground_cover_work %>%
  dplyr::mutate(water_year_start = water_year_start(.data$water_year)) %>%
  dplyr::group_by(.data$plot_id, .data$water_year_start, .data$water_year, .data$period) %>%
  dplyr::summarise(
    total_veg_pct = safe_mean(.data$total_veg_pct),
    bare_ground_pct = safe_mean(.data$bare_ground_pct),
    n_gc_records_in_year = dplyr::n(),
    .groups = "drop"
  )

annual_lag_pairs <- dplyr::bind_rows(lapply(ANNUAL_LAGS, function(lag_years) {
  gc_annual %>%
    dplyr::mutate(
      lag_years = lag_years,
      inundation_water_year_start = .data$water_year_start - lag_years
    ) %>%
    dplyr::left_join(
      annual_inundation_work %>%
        dplyr::select(
          "plot_id",
          inundation_water_year_start = "water_year_start",
          annual_inundated_any_pct = "inundated_any_pct",
          dplyr::any_of(c("annual_wet_any", "annual_valid_any"))
        ),
      by = c("plot_id", "inundation_water_year_start")
    )
}))


## Lag diagnostics by plot ----


monthly_diag <- monthly_lag_pairs %>%
  tidyr::pivot_longer(
    cols = c("total_veg_pct", "bare_ground_pct"),
    names_to = "response_variable",
    values_to = "ground_cover_pct"
  ) %>%
  dplyr::group_by(.data$plot_id, .data$lag_months, .data$response_variable) %>%
  dplyr::summarise(
    diagnostic_type = "monthly",
    inundation_metric = "mean_daily_inundated_pct",
    n_pairs = sum(!is.na(.data$ground_cover_pct) & !is.na(.data$mean_daily_inundated_pct)),
    correlation = safe_cor(.data$mean_daily_inundated_pct, .data$ground_cover_pct, MIN_MONTHLY_LAG_PAIRS),
    min_ground_cover_month = min(.data$month_start[!is.na(.data$ground_cover_pct) & !is.na(.data$mean_daily_inundated_pct)], na.rm = TRUE),
    max_ground_cover_month = max(.data$month_start[!is.na(.data$ground_cover_pct) & !is.na(.data$mean_daily_inundated_pct)], na.rm = TRUE),
    .groups = "drop"
  ) %>%
  dplyr::mutate(
    lag_label = paste0(.data$lag_months, " month"),
    support_class = support_class(.data$n_pairs, MIN_MONTHLY_LAG_PAIRS),
    min_ground_cover_month = dplyr::if_else(is.infinite(as.numeric(.data$min_ground_cover_month)), as.Date(NA), .data$min_ground_cover_month),
    max_ground_cover_month = dplyr::if_else(is.infinite(as.numeric(.data$max_ground_cover_month)), as.Date(NA), .data$max_ground_cover_month)
  )

annual_diag <- annual_lag_pairs %>%
  tidyr::pivot_longer(
    cols = c("total_veg_pct", "bare_ground_pct"),
    names_to = "response_variable",
    values_to = "ground_cover_pct"
  ) %>%
  dplyr::group_by(.data$plot_id, .data$lag_years, .data$response_variable) %>%
  dplyr::summarise(
    diagnostic_type = "annual",
    inundation_metric = "annual_inundated_any_pct",
    n_pairs = sum(!is.na(.data$ground_cover_pct) & !is.na(.data$annual_inundated_any_pct)),
    correlation = safe_cor(.data$annual_inundated_any_pct, .data$ground_cover_pct, MIN_ANNUAL_LAG_PAIRS),
    min_ground_cover_year = min(.data$water_year_start[!is.na(.data$ground_cover_pct) & !is.na(.data$annual_inundated_any_pct)], na.rm = TRUE),
    max_ground_cover_year = max(.data$water_year_start[!is.na(.data$ground_cover_pct) & !is.na(.data$annual_inundated_any_pct)], na.rm = TRUE),
    .groups = "drop"
  ) %>%
  dplyr::mutate(
    lag_months = .data$lag_years * 12L,
    lag_label = paste0(.data$lag_years, " water year"),
    support_class = support_class(.data$n_pairs, MIN_ANNUAL_LAG_PAIRS),
    min_ground_cover_month = as.Date(NA),
    max_ground_cover_month = as.Date(NA)
  ) %>%
  dplyr::select(-"lag_years")

lag_diagnostics_by_plot <- dplyr::bind_rows(
  monthly_diag %>%
    dplyr::select(
      "plot_id",
      "diagnostic_type",
      "inundation_metric",
      "response_variable",
      "lag_months",
      "lag_label",
      "n_pairs",
      "correlation",
      "support_class",
      "min_ground_cover_month",
      "max_ground_cover_month"
    ),
  annual_diag %>%
    dplyr::select(
      "plot_id",
      "diagnostic_type",
      "inundation_metric",
      "response_variable",
      "lag_months",
      "lag_label",
      "n_pairs",
      "correlation",
      "support_class",
      "min_ground_cover_month",
      "max_ground_cover_month"
    )
) %>%
  dplyr::left_join(
    plot_support_summary %>%
      dplyr::select("plot_id", "vegetation_adrian_group", "treatment", "lag_support_class"),
    by = "plot_id"
  ) %>%
  dplyr::mutate(
    response_label = metric_label(.data$response_variable),
    interpretation_note = "Descriptive correlation only; inundation leading ground cover does not prove causality."
  ) %>%
  dplyr::arrange(.data$diagnostic_type, .data$response_variable, .data$lag_months, .data$plot_id)

write_csv_message(lag_diagnostics_by_plot, lag_by_plot_path)


## Group summary ----


lag_diagnostics_group_summary <- lag_diagnostics_by_plot %>%
  dplyr::group_by(
    .data$diagnostic_type,
    .data$inundation_metric,
    .data$response_variable,
    .data$response_label,
    .data$lag_months,
    .data$lag_label,
    .data$vegetation_adrian_group,
    .data$support_class
  ) %>%
  dplyr::summarise(
    n_plots = dplyr::n(),
    n_plots_with_correlation = sum(!is.na(.data$correlation)),
    mean_pairs = safe_mean(.data$n_pairs),
    median_pairs = safe_median(.data$n_pairs),
    mean_correlation = safe_mean(.data$correlation),
    median_correlation = safe_median(.data$correlation),
    min_correlation = if (all(is.na(.data$correlation))) NA_real_ else min(.data$correlation, na.rm = TRUE),
    max_correlation = if (all(is.na(.data$correlation))) NA_real_ else max(.data$correlation, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  dplyr::arrange(.data$diagnostic_type, .data$response_variable, .data$lag_months, .data$vegetation_adrian_group)

write_csv_message(lag_diagnostics_group_summary, lag_group_summary_path)


## Figures ----


support_heatmap_data <- plot_support_summary %>%
  dplyr::mutate(
    plot_order_score = .data$n_gc_observations +
      .data$n_annual_inundation_years +
      (.data$n_daily_monthly_inundation_months / 12),
    plot_id_ordered = stats::reorder(.data$plot_id, .data$plot_order_score)
  ) %>%
  dplyr::select(
    "plot_id_ordered",
    "plot_id",
    "lag_support_class",
    "n_gc_observations",
    "n_annual_inundation_years",
    "n_daily_monthly_inundation_months",
    "n_pre_gc_observations",
    "n_post_gc_observations"
  ) %>%
  tidyr::pivot_longer(
    cols = c(
      "n_gc_observations",
      "n_annual_inundation_years",
      "n_daily_monthly_inundation_months",
      "n_pre_gc_observations",
      "n_post_gc_observations"
    ),
    names_to = "support_metric",
    values_to = "support_count"
  ) %>%
  dplyr::mutate(
    support_metric = dplyr::case_when(
      .data$support_metric == "n_gc_observations" ~ "GC observations",
      .data$support_metric == "n_annual_inundation_years" ~ "Annual inundation years",
      .data$support_metric == "n_daily_monthly_inundation_months" ~ "Daily/monthly inundation months",
      .data$support_metric == "n_pre_gc_observations" ~ "Pre GC observations",
      .data$support_metric == "n_post_gc_observations" ~ "Post GC observations",
      TRUE ~ .data$support_metric
    )
  )

fig_support_heatmap <- ggplot2::ggplot(
  support_heatmap_data,
  ggplot2::aes(x = .data$support_metric, y = .data$plot_id_ordered, fill = .data$support_count)
) +
  ggplot2::geom_tile(colour = "white", linewidth = 0.15) +
  ggplot2::scale_fill_viridis_c(option = "C", trans = "sqrt") +
  ggplot2::labs(
    title = "Missingness and support by plot",
    subtitle = "Higher and more uniform support is a good result for this QA/internal check.",
    x = NULL,
    y = "Plot",
    fill = "Count",
    caption = "QA/internal figure. Support differs among ground cover, annual inundation, and daily/monthly inundation."
  ) +
  theme_lag(base_size = 10) +
  ggplot2::theme(
    axis.text.x = ggplot2::element_text(angle = 35, hjust = 1),
    axis.text.y = ggplot2::element_text(size = 6)
  )

support_heatmap_path <- save_png(fig_support_heatmap, "12_missingness_support_heatmap_by_plot.png", width = 10.5, height = 12)

lag_summary_plot_data <- lag_diagnostics_by_plot %>%
  dplyr::filter(.data$diagnostic_type == "monthly") %>%
  dplyr::group_by(.data$response_label, .data$lag_months) %>%
  dplyr::summarise(
    n_plots_with_correlation = sum(!is.na(.data$correlation)),
    median_correlation = safe_median(.data$correlation),
    q25_correlation = if (all(is.na(.data$correlation))) NA_real_ else stats::quantile(.data$correlation, 0.25, na.rm = TRUE),
    q75_correlation = if (all(is.na(.data$correlation))) NA_real_ else stats::quantile(.data$correlation, 0.75, na.rm = TRUE),
    .groups = "drop"
  )

lag_summary_y_limit <- max(
  abs(c(
    lag_summary_plot_data$median_correlation,
    lag_summary_plot_data$q25_correlation,
    lag_summary_plot_data$q75_correlation
  )),
  na.rm = TRUE
)

if (is.infinite(lag_summary_y_limit) || is.na(lag_summary_y_limit)) {
  lag_summary_y_limit <- 0.5
}

lag_summary_y_limit <- max(0.5, min(1, ceiling(lag_summary_y_limit * 10) / 10))

strongest_monthly_lag <- lag_summary_plot_data %>%
  dplyr::filter(!is.na(.data$median_correlation)) %>%
  dplyr::mutate(abs_median_correlation = abs(.data$median_correlation)) %>%
  dplyr::arrange(dplyr::desc(.data$abs_median_correlation)) %>%
  dplyr::slice_head(n = 1) %>%
  dplyr::mutate(
    label = paste0("Strongest median: ", .data$lag_months, " mo")
  )

fig_lag_summary <- ggplot2::ggplot(
  lag_summary_plot_data,
  ggplot2::aes(x = .data$lag_months, y = .data$median_correlation, colour = .data$response_label)
) +
  ggplot2::geom_hline(yintercept = 0, colour = "grey45", linewidth = 0.35) +
  ggplot2::geom_ribbon(
    ggplot2::aes(ymin = .data$q25_correlation, ymax = .data$q75_correlation, fill = .data$response_label),
    alpha = 0.18,
    colour = NA
  ) +
  ggplot2::geom_line(linewidth = 0.9) +
  ggplot2::geom_point(ggplot2::aes(size = .data$n_plots_with_correlation), alpha = 0.9) +
  ggplot2::geom_label(
    data = strongest_monthly_lag,
    ggplot2::aes(label = .data$label),
    show.legend = FALSE,
    linewidth = 0.15,
    size = 3.2,
    vjust = -0.7
  ) +
  ggplot2::scale_x_continuous(breaks = MONTHLY_LAGS) +
  ggplot2::scale_y_continuous(limits = c(-lag_summary_y_limit, lag_summary_y_limit)) +
  ggplot2::scale_colour_manual(values = c("Total vegetation" = "#59a14f", "Bare ground" = "#b07d3c")) +
  ggplot2::scale_fill_manual(values = c("Total vegetation" = "#59a14f", "Bare ground" = "#b07d3c")) +
  ggplot2::labs(
    title = "Monthly lag-correlation summary",
    subtitle = "Descriptive correlations only, not causal evidence; ribbon is the interquartile range across plots.",
    x = "Inundation lead time (months)",
    y = "Correlation",
    colour = "Ground-cover response",
    fill = "Ground-cover response",
    size = "Plots",
    caption = "Descriptive diagnostic only; correlation is not causal evidence."
  ) +
  theme_lag()

lag_summary_path <- save_png(fig_lag_summary, "12_lag_correlation_summary.png")

example_plot_reasons <- lag_diagnostics_by_plot %>%
  dplyr::filter(.data$diagnostic_type == "monthly", .data$support_class == "adequate_support", !is.na(.data$correlation)) %>%
  dplyr::mutate(abs_correlation = abs(.data$correlation)) %>%
  dplyr::group_by(.data$plot_id) %>%
  dplyr::arrange(dplyr::desc(.data$abs_correlation), .by_group = TRUE) %>%
  dplyr::slice_head(n = 1) %>%
  dplyr::ungroup() %>%
  dplyr::arrange(dplyr::desc(.data$abs_correlation)) %>%
  dplyr::slice_head(n = SELECTED_EXAMPLE_PLOTS) %>%
  dplyr::transmute(
    plot_id = .data$plot_id,
    selection_reason = paste0(
      metric_label(.data$response_variable),
      ", ",
      .data$lag_months,
      "-month lag, r=",
      round(.data$correlation, 2)
    ),
    facet_label = paste0(.data$plot_id, "\n", .data$selection_reason)
  )

example_plots <- example_plot_reasons$plot_id

example_data <- monthly_lag_pairs %>%
  dplyr::filter(.data$lag_months == 0L, .data$plot_id %in% example_plots) %>%
  dplyr::select(
    "plot_id",
    "month_start",
    "total_veg_pct",
    "bare_ground_pct",
    inundation_pct = "mean_daily_inundated_pct"
  ) %>%
  tidyr::pivot_longer(
    cols = c("total_veg_pct", "bare_ground_pct", "inundation_pct"),
    names_to = "metric",
    values_to = "value_pct"
  ) %>%
  dplyr::left_join(example_plot_reasons, by = "plot_id") %>%
  dplyr::mutate(
    metric = dplyr::case_when(
      .data$metric == "total_veg_pct" ~ "Total vegetation",
      .data$metric == "bare_ground_pct" ~ "Bare ground",
      .data$metric == "inundation_pct" ~ "Monthly inundation",
      TRUE ~ .data$metric
    )
  )

fig_examples <- ggplot2::ggplot(example_data, ggplot2::aes(x = .data$month_start, y = .data$value_pct, colour = .data$metric)) +
  ggplot2::geom_vline(xintercept = MANAGEMENT_CHANGE_DATE, linetype = "dashed", colour = "grey35", linewidth = 0.45) +
  ggplot2::geom_line(linewidth = 0.65, na.rm = TRUE) +
  ggplot2::geom_point(size = 1.2, alpha = 0.8, na.rm = TRUE) +
  ggplot2::facet_wrap(~ facet_label, ncol = 2) +
  ggplot2::coord_cartesian(ylim = c(0, 100)) +
  ggplot2::scale_colour_manual(values = c("Total vegetation" = "#59a14f", "Bare ground" = "#b07d3c", "Monthly inundation" = "#3a6ea5")) +
  ggplot2::labs(
    title = "Selected plot examples: ground cover and monthly inundation",
    subtitle = "Examples selected by strongest descriptive monthly lag correlation; dashed line is management-change date.",
    x = "Month",
    y = "Percent",
    colour = "Metric",
    caption = "Monthly inundation is a monthly detection metric, not continuous hydroperiod. Visual timing comparison only; not a causal test."
  ) +
  theme_lag(base_size = 10)

examples_path <- save_png(fig_examples, "12_selected_plot_examples.png", width = 12, height = 9)

scatter_data <- gc_prepost %>%
  dplyr::select("plot_id", "delta_total_veg_pct", "delta_bare_ground_pct") %>%
  dplyr::left_join(
    plot_context %>%
      dplyr::select(
        "plot_id",
        "post_minus_pre_inundation_frequency_pct_points",
        "vegetation_adrian_group",
        "inundation_change_class"
      ),
    by = "plot_id"
  ) %>%
  dplyr::left_join(
    plot_support_summary %>%
      dplyr::select("plot_id", "lag_support_class"),
    by = "plot_id"
  ) %>%
  tidyr::pivot_longer(
    cols = c("delta_total_veg_pct", "delta_bare_ground_pct"),
    names_to = "response_variable",
    values_to = "ground_cover_delta_pct_points"
  ) %>%
  dplyr::mutate(response_label = metric_label(stringr::str_remove(.data$response_variable, "^delta_") %>% stringr::str_replace("_veg", "_veg_pct") %>% stringr::str_replace("_ground", "_ground_pct")))

scatter_data <- scatter_data %>%
  dplyr::mutate(
    response_label = dplyr::case_when(
      .data$response_variable == "delta_total_veg_pct" ~ "Total vegetation",
      .data$response_variable == "delta_bare_ground_pct" ~ "Bare ground",
      TRUE ~ .data$response_label
    ),
    inundation_change_label = change_class_label(.data$inundation_change_class)
  )

all_monthly_supported <- scatter_data %>%
  dplyr::distinct(.data$plot_id, .data$lag_support_class) %>%
  dplyr::summarise(
    all_supported = dplyr::n_distinct(.data$lag_support_class) == 1 &&
      dplyr::first(.data$lag_support_class) == "monthly_supported",
    .groups = "drop"
  ) %>%
  dplyr::pull(.data$all_supported)

if (isTRUE(all_monthly_supported)) {
  fig_lag_support_scatter <- ggplot2::ggplot(
    scatter_data,
    ggplot2::aes(
      x = .data$post_minus_pre_inundation_frequency_pct_points,
      y = .data$ground_cover_delta_pct_points,
      colour = .data$inundation_change_label
    )
  ) +
    ggplot2::geom_hline(yintercept = 0, colour = "grey45", linewidth = 0.35) +
    ggplot2::geom_vline(xintercept = 0, colour = "grey45", linewidth = 0.35) +
    ggplot2::geom_point(size = 2.4, alpha = 0.9) +
    ggplot2::geom_smooth(method = "lm", se = FALSE, colour = "grey25", linewidth = 0.7) +
    ggplot2::facet_wrap(~ response_label, scales = "free_y") +
    ggplot2::scale_colour_brewer(palette = "Set2", na.value = "grey70") +
    ggplot2::labs(
      title = "Pre/post inundation change and ground-cover change",
      subtitle = "All plots have monthly lag support; colour shows inundation-change class.",
      x = "Post minus pre inundation frequency (percentage points)",
      y = "Ground-cover change (percentage points)",
      colour = "Inundation change",
      caption = "Trend lines are descriptive only."
    ) +
    theme_lag()
} else {
  fig_lag_support_scatter <- ggplot2::ggplot(
    scatter_data,
    ggplot2::aes(
      x = .data$post_minus_pre_inundation_frequency_pct_points,
      y = .data$ground_cover_delta_pct_points,
      colour = .data$lag_support_class
    )
  ) +
    ggplot2::geom_hline(yintercept = 0, colour = "grey45", linewidth = 0.35) +
    ggplot2::geom_vline(xintercept = 0, colour = "grey45", linewidth = 0.35) +
    ggplot2::geom_point(size = 2.4, alpha = 0.9) +
    ggplot2::geom_smooth(method = "lm", se = FALSE, colour = "grey25", linewidth = 0.7) +
    ggplot2::facet_wrap(~ response_label, scales = "free_y") +
    ggplot2::scale_colour_manual(values = c("monthly_supported" = "#3a6ea5", "annual_preferred" = "#f28e2b", "low_core_support" = "#bdbdbd")) +
    ggplot2::labs(
      title = "Pre/post inundation change and ground-cover change by lag-support class",
      subtitle = "Support class indicates whether monthly lag diagnostics are well supported or annual checks are preferable.",
      x = "Post minus pre inundation frequency (percentage points)",
      y = "Ground-cover change (percentage points)",
      colour = "Lag support class",
      caption = "Trend lines are descriptive only."
    ) +
    theme_lag()
}

lag_support_scatter_path <- save_png(fig_lag_support_scatter, "12_inundation_change_vs_gc_change_lag_support.png")


figure_index <- tibble::tibble(
  figure_id = c("12_01", "12_02", "12_03", "12_04"),
  file_name = basename(c(support_heatmap_path, lag_summary_path, examples_path, lag_support_scatter_path)),
  file_path = c(support_heatmap_path, lag_summary_path, examples_path, lag_support_scatter_path),
  title = c(
    "Missingness/support heatmap by plot",
    "Monthly lag-correlation summary",
    "Selected plot examples",
    "Inundation change vs ground-cover change"
  ),
  figure_role = c(
    "QA/internal",
    "technical deck",
    "technical deck",
    "main deck candidate"
  ),
  notes = c(
    "QA view. Uniform high support is a good result and means missingness is unlikely to dominate these diagnostics.",
    "Descriptive lag-correlation diagnostic only; not causal evidence.",
    "Selected by strongest descriptive monthly lag correlation; monthly inundation is not continuous hydroperiod.",
    ifelse(
      isTRUE(all_monthly_supported),
      "All plots are monthly_supported, so colour shows inundation-change class instead of a constant support class.",
      "Colour shows lag-support class where support differs among plots."
    )
  )
)

write_csv_message(figure_index, figure_index_path)


## Handoff report ----


n_low_core <- sum(plot_support_summary$lag_support_class == "low_core_support", na.rm = TRUE)
n_annual_preferred <- sum(plot_support_summary$lag_support_class == "annual_preferred", na.rm = TRUE)
n_monthly_supported <- sum(plot_support_summary$lag_support_class == "monthly_supported", na.rm = TRUE)
n_monthly_correlations <- lag_diagnostics_by_plot %>%
  dplyr::filter(.data$diagnostic_type == "monthly", !is.na(.data$correlation)) %>%
  nrow()
n_annual_correlations <- lag_diagnostics_by_plot %>%
  dplyr::filter(.data$diagnostic_type == "annual", !is.na(.data$correlation)) %>%
  nrow()

overall_status <- dplyr::case_when(
  nrow(lag_diagnostics_by_plot) == 0 ~ "FAIL",
  n_low_core > 0 ~ "REVIEW",
  TRUE ~ "PASS"
)

report_lines <- c(
  "# 12 Lag Diagnostics Handoff Report",
  "",
  paste0("Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
  "",
  "## Scope",
  "",
  "This Step 12 script performs lightweight missingness and lag diagnostics using curated and 10a CSV outputs only. It does not run raster processing, BFAST, or tbreak.",
  "",
  "## Outputs",
  "",
  paste0("- `", support_summary_path, "`"),
  paste0("- `", lag_by_plot_path, "`"),
  paste0("- `", lag_group_summary_path, "`"),
  paste0("- `", figure_index_path, "`"),
  paste0("- `", support_heatmap_path, "`"),
  paste0("- `", lag_summary_path, "`"),
  paste0("- `", examples_path, "`"),
  paste0("- `", lag_support_scatter_path, "`"),
  "",
  "## Figure Roles",
  "",
  paste0("- `", figure_index$file_name, "`: ", figure_index$figure_role, " - ", figure_index$notes),
  "",
  "## Status",
  "",
  paste0("- Overall status: ", overall_status),
  paste0("- Monthly-supported plots: ", n_monthly_supported),
  paste0("- Annual-preferred plots: ", n_annual_preferred),
  paste0("- Low-core-support plots: ", n_low_core),
  paste0("- Monthly plot-response lag correlations with enough pairs: ", n_monthly_correlations),
  paste0("- Annual plot-response lag correlations with enough pairs: ", n_annual_correlations),
  "",
  "## Assumptions",
  "",
  paste0("- Monthly lag checks use inundation leading ground cover by ", paste(MONTHLY_LAGS, collapse = ", "), " months."),
  paste0("- Annual lag checks use inundation leading ground cover by ", paste(ANNUAL_LAGS, collapse = ", "), " water year(s)."),
  paste0("- Minimum monthly lag pairs per plot-response-lag: ", MIN_MONTHLY_LAG_PAIRS, "."),
  paste0("- Minimum annual lag pairs per plot-response-lag: ", MIN_ANNUAL_LAG_PAIRS, "."),
  "",
  "## Interpretation Cautions",
  "",
  "- Lag correlations are descriptive diagnostics only and do not prove causality.",
  "- Monthly support depends on daily/monthly inundation availability and sensor density.",
  "- Annual inundation is annual occurrence frequency support, not duration or hydroperiod.",
  "- Ground-cover estimates may be uncertain in treed or woody plots.",
  "",
  "## Recommended Next Task",
  "",
  "Review support classes and selected plot examples, then choose a small set of robust lag/missingness figures for the technical deck. Do not move to BFAST/tbreak until these diagnostics have been reviewed."
)

readr::write_lines(report_lines, handoff_report_path)
message("Wrote: ", handoff_report_path)

if (overall_status == "FAIL") {
  stop("Step 12 lag diagnostics failed; see handoff report.", call. = FALSE)
}

if (overall_status == "REVIEW") {
  warning("Step 12 lag diagnostics completed with review flags; see handoff report.", call. = FALSE)
}

message("12 lag diagnostics complete.")
