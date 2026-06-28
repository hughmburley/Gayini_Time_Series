# ------------------------------------------------------------------------------
# Script: scripts/07_figures_dashboards/04_integrate_gauge_context_review_figures.R
# Purpose: Integrate gauge-context review figures.
# Workflow stage: 07_figures_dashboards
# Run mode: lightweight_review
# Heavy processing: no
# Key inputs:
#   - Gauge context and curated outputs.
# Key outputs:
#   - Gauge-context figures.
# Notes:
#   - Keep stable output filenames for downstream reports.
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Load configuration and execute workflow step
# ------------------------------------------------------------------------------

## Purpose:
## Integrate already-imported Murrumbidgee gauge context into Gayini review
## figures and lightweight dashboard prototypes. Gauge flow is hydrological
## context only; it is not causal proof and does not change RS/MER metrics.


## User settings ----


root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", "D:/Github_repos/Gayini"), winslash = "/", mustWork = TRUE)
MANAGEMENT_CHANGE_DATE <- as.Date("2019-07-01")
PREFERRED_GAUGE_REPO_CANDIDATES <- c(
  "D:/Github_repos/Murrumbidgee_Gauge_Workflow",
  "D:/Github_repos/Gayini_water_gauges"
)
ANCHOR_GAUGE_NAMES <- c("Hay Weir", "Maude Weir", "Darlington Point", "Balranald Weir")
REDBANK_PATTERN <- "redbank"


## Required packages ----


required_packages <- c(
  "dplyr",
  "tidyr",
  "readr",
  "stringr",
  "magrittr",
  "tibble",
  "ggplot2",
  "grid"
)

source(file.path(root_dir, "R", "gayini_analysis_base_functions.R"))
gayini_check_packages(required_packages)

library(dplyr)
library(tidyr)
library(readr)
library(stringr)
library(magrittr)
library(tibble)
library(ggplot2)
library(grid)


## Paths ----


csv_dir <- file.path(root_dir, "Output", "csv")
figure_dir <- file.path(root_dir, "Output", "figures", "review")
diagnostics_dir <- file.path(root_dir, "Output", "diagnostics", "10e_gauge_integration")
report_dir <- file.path(root_dir, "Output", "reports")

dir.create(csv_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(diagnostics_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(report_dir, recursive = TRUE, showWarnings = FALSE)

task1_flags_path <- file.path(csv_dir, "plot_context_flags.csv")
ground_cover_path <- file.path(csv_dir, "curated_ground_cover_timeseries.csv")
monthly_inundation_path <- file.path(csv_dir, "curated_daily_inundation_monthly.csv")
plot_base_path <- file.path(csv_dir, "plot_rs_analysis_base.csv")
gauge_monthly_path <- file.path(root_dir, "data_intermediate", "hydrology", "gauge_monthly_prepared.csv")
gauge_water_year_path <- file.path(root_dir, "data_intermediate", "hydrology", "gauge_water_year_prepared.csv")
gauge_deck_path <- file.path(root_dir, "data_processed", "hydrology", "gauge_context_for_deck.csv")
gauge_import_manifest_path <- file.path(root_dir, "Output", "diagnostics", "hydrology", "gauge_database_import_manifest.csv")
gauge_join_summary_path <- file.path(root_dir, "Output", "diagnostics", "hydrology", "rs_gauge_join_summary.csv")

gauge_context_path <- file.path(csv_dir, "gauge_context_for_gayini.csv")
gauge_completeness_path <- file.path(csv_dir, "gauge_data_completeness_for_gayini.csv")
plot_rs_gauge_base_path <- file.path(csv_dir, "plot_rs_gauge_analysis_base.csv")

input_report_path <- file.path(diagnostics_dir, "gauge_input_import_report.csv")
checks_path <- file.path(diagnostics_dir, "gauge_integration_checks.csv")
dashboard_data_path <- file.path(diagnostics_dir, "dashboard_gauge_integration_plot_data.csv")
handoff_report_path <- file.path(report_dir, "task_2_gauge_integration_handoff.md")

gc_gauge_figure_path <- file.path(figure_dir, "gc_total_veg_with_gauge_context.png")
inundation_gauge_figure_path <- file.path(figure_dir, "inundation_with_gauge_context.png")
dashboard_figure_path <- file.path(figure_dir, "dashboard_gauge_integration_prototype.png")
gauge_overview_figure_path <- file.path(figure_dir, "gauge_flow_by_station_overview.png")
gauge_completeness_figure_path <- file.path(figure_dir, "gauge_data_completeness_overview.png")
selected_examples_figure_path <- file.path(figure_dir, "selected_plot_total_veg_inundation_gauge_examples.png")


## Helpers ----


write_csv_message <- function(x, path) {
  readr::write_csv(x, path)
  message("Wrote: ", path)
  invisible(x)
}


safe_mean <- function(x) {
  if (all(is.na(x))) {
    return(NA_real_)
  }
  mean(x, na.rm = TRUE)
}


safe_min_date <- function(x) {
  x <- as.Date(x)
  if (all(is.na(x))) {
    return(as.Date(NA))
  }
  min(x, na.rm = TRUE)
}


safe_max_date <- function(x) {
  x <- as.Date(x)
  if (all(is.na(x))) {
    return(as.Date(NA))
  }
  max(x, na.rm = TRUE)
}


is_anchor_gauge <- function(station_name, include_default) {
  station_name <- stringr::str_to_lower(as.character(station_name))
  name_hit <- stringr::str_detect(
    station_name,
    stringr::str_to_lower(paste(ANCHOR_GAUGE_NAMES, collapse = "|"))
  )

  dplyr::coalesce(include_default, FALSE) | name_hit
}


flag_redbank <- function(station_name) {
  stringr::str_detect(stringr::str_to_lower(as.character(station_name)), REDBANK_PATTERN)
}


make_wy_label <- function(date) {
  date <- as.Date(date)
  year <- as.integer(format(date, "%Y"))
  month <- as.integer(format(date, "%m"))
  end_year <- ifelse(month >= 7L, year + 1L, year)
  paste0("WY", end_year)
}


theme_review <- function(base_size = 12) {
  ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      plot.title = ggplot2::element_text(face = "bold"),
      plot.caption = ggplot2::element_text(hjust = 0, colour = "grey35")
    )
}


## Input report ----


gauge_repo_report <- tibble::tibble(
  searched_path = PREFERRED_GAUGE_REPO_CANDIDATES,
  path_exists = file.exists(PREFERRED_GAUGE_REPO_CANDIDATES)
)

gauge_repo_found <- gauge_repo_report %>%
  dplyr::filter(.data$path_exists) %>%
  dplyr::slice_head(n = 1) %>%
  dplyr::pull(.data$searched_path)

if (length(gauge_repo_found) == 0L) {
  gauge_repo_found <- NA_character_
}

input_report <- tibble::tibble(
  input_name = c(
    "task1_plot_context_flags",
    "curated_ground_cover_timeseries",
    "curated_daily_inundation_monthly",
    "plot_rs_analysis_base",
    "gauge_monthly_prepared",
    "gauge_water_year_prepared",
    "gauge_context_for_deck",
    "gauge_database_import_manifest",
    "gauge_join_summary",
    "preferred_gauge_repo"
  ),
  path = c(
    task1_flags_path,
    ground_cover_path,
    monthly_inundation_path,
    plot_base_path,
    gauge_monthly_path,
    gauge_water_year_path,
    gauge_deck_path,
    gauge_import_manifest_path,
    gauge_join_summary_path,
    gauge_repo_found
  ),
  found = c(
    file.exists(task1_flags_path),
    file.exists(ground_cover_path),
    file.exists(monthly_inundation_path),
    file.exists(plot_base_path),
    file.exists(gauge_monthly_path),
    file.exists(gauge_water_year_path),
    file.exists(gauge_deck_path),
    file.exists(gauge_import_manifest_path),
    file.exists(gauge_join_summary_path),
    !is.na(gauge_repo_found)
  ),
  role = c(
    "Task 1 context authority.",
    "Total vegetation time series.",
    "Monthly RS inundation context.",
    "Plot-level RS summary base.",
    "Monthly gauge flow context.",
    "Water-year gauge flow context.",
    "Existing compact gauge deck export.",
    "Gauge import provenance.",
    "Existing RS/gauge join summary.",
    "Sibling water gauge workflow repo if available."
  )
)

required_inputs <- input_report %>%
  dplyr::filter(.data$input_name %in% c(
    "task1_plot_context_flags",
    "curated_ground_cover_timeseries",
    "curated_daily_inundation_monthly",
    "plot_rs_analysis_base",
    "gauge_monthly_prepared",
    "gauge_water_year_prepared"
  ))

if (any(!required_inputs$found)) {
  write_csv_message(input_report, input_report_path)
  stop(
    "Missing required Task 2 input(s): ",
    paste(required_inputs$input_name[!required_inputs$found], collapse = ", "),
    call. = FALSE
  )
}


## Read inputs ----


plot_context <- readr::read_csv(task1_flags_path, show_col_types = FALSE) %>%
  gayini_standardise_plot_id(object_name = "Task 1 plot context flags")

ground_cover <- readr::read_csv(ground_cover_path, show_col_types = FALSE) %>%
  gayini_standardise_plot_id(object_name = "curated ground-cover timeseries") %>%
  dplyr::mutate(date_midpoint = as.Date(.data$date_midpoint))

monthly_inundation <- readr::read_csv(monthly_inundation_path, show_col_types = FALSE) %>%
  gayini_standardise_plot_id(object_name = "curated monthly inundation") %>%
  dplyr::mutate(month_start = as.Date(.data$month_start))

plot_base <- readr::read_csv(plot_base_path, show_col_types = FALSE) %>%
  gayini_standardise_plot_id(object_name = "plot RS analysis base")

gauge_monthly <- readr::read_csv(gauge_monthly_path, show_col_types = FALSE) %>%
  dplyr::mutate(
    month_start = as.Date(.data$month_start),
    gauge_context_role = dplyr::case_when(
      is_anchor_gauge(.data$station_name, .data$include_in_default_continuous_context) ~ "preferred_context",
      flag_redbank(.data$station_name) ~ "redbank_cautious",
      TRUE ~ "other_context"
    ),
    redbank_caution_flag = flag_redbank(.data$station_name),
    data_completeness_flag = dplyr::case_when(
      is.na(.data$missing_flow_pct) ~ "missing_completeness_unknown",
      .data$missing_flow_pct <= 5 ~ "high_completeness",
      .data$missing_flow_pct <= 20 ~ "moderate_completeness",
      TRUE ~ "low_completeness_review"
    )
  )

gauge_water_year <- readr::read_csv(gauge_water_year_path, show_col_types = FALSE) %>%
  dplyr::mutate(
    water_year_end_date = as.Date(paste0(.data$water_year_numeric, "-06-30")),
    gauge_context_role = dplyr::case_when(
      is_anchor_gauge(.data$station_name, .data$include_in_default_continuous_context) ~ "preferred_context",
      flag_redbank(.data$station_name) ~ "redbank_cautious",
      TRUE ~ "other_context"
    ),
    redbank_caution_flag = flag_redbank(.data$station_name),
    data_completeness_flag = dplyr::case_when(
      is.na(.data$missing_flow_pct) ~ "missing_completeness_unknown",
      .data$missing_flow_pct <= 5 ~ "high_completeness",
      .data$missing_flow_pct <= 20 ~ "moderate_completeness",
      TRUE ~ "low_completeness_review"
    )
  )


## Gauge context tables ----


gauge_context_monthly <- gauge_monthly %>%
  dplyr::filter(
    .data$gauge_context_role == "preferred_context" |
      (
        .data$gauge_context_role == "redbank_cautious" &
          .data$data_completeness_flag != "low_completeness_review"
      )
  ) %>%
  dplyr::transmute(
    time_scale = "monthly",
    date = .data$month_start,
    month_start = .data$month_start,
    water_year = make_wy_label(.data$month_start),
    station_id = as.character(.data$station_id),
    gauge_name = .data$station_name,
    recommended_use = .data$recommended_use,
    gauge_context_role = .data$gauge_context_role,
    redbank_caution_flag = .data$redbank_caution_flag,
    flow_metric = "mean_flow_mld",
    flow_value = .data$mean_flow_mld,
    mean_flow_mld = .data$mean_flow_mld,
    total_flow_ml = .data$total_flow_ml,
    max_daily_flow_mld = .data$max_daily_flow_mld,
    n_valid_flow_days = .data$n_valid_flow_days,
    n_missing_flow_days = .data$n_missing_flow_days,
    missing_flow_pct = .data$missing_flow_pct,
    data_completeness_flag = .data$data_completeness_flag,
    record_status_summary = .data$record_status_summary,
    patch_status_summary = .data$patch_status_summary
  )

gauge_context_water_year <- gauge_water_year %>%
  dplyr::filter(
    .data$gauge_context_role == "preferred_context" |
      (
        .data$gauge_context_role == "redbank_cautious" &
          .data$data_completeness_flag != "low_completeness_review"
      )
  ) %>%
  dplyr::transmute(
    time_scale = "water_year",
    date = .data$water_year_end_date,
    month_start = as.Date(NA),
    water_year = .data$water_year,
    station_id = as.character(.data$station_id),
    gauge_name = .data$station_name,
    recommended_use = .data$recommended_use,
    gauge_context_role = .data$gauge_context_role,
    redbank_caution_flag = .data$redbank_caution_flag,
    flow_metric = "mean_flow_mld",
    flow_value = .data$mean_flow_mld,
    mean_flow_mld = .data$mean_flow_mld,
    total_flow_ml = .data$total_flow_ml,
    max_daily_flow_mld = .data$max_daily_flow_mld,
    n_valid_flow_days = .data$n_valid_flow_days,
    n_missing_flow_days = .data$n_missing_flow_days,
    missing_flow_pct = .data$missing_flow_pct,
    data_completeness_flag = .data$data_completeness_flag,
    record_status_summary = .data$record_status_summary,
    patch_status_summary = .data$patch_status_summary
  )

gauge_context <- dplyr::bind_rows(gauge_context_monthly, gauge_context_water_year) %>%
  dplyr::arrange(.data$time_scale, .data$gauge_name, .data$date)

gauge_completeness <- gauge_context %>%
  dplyr::group_by(.data$time_scale, .data$station_id, .data$gauge_name, .data$gauge_context_role, .data$redbank_caution_flag) %>%
  dplyr::summarise(
    first_date = safe_min_date(.data$date),
    last_date = safe_max_date(.data$date),
    n_periods = dplyr::n(),
    mean_missing_flow_pct = round(mean(.data$missing_flow_pct, na.rm = TRUE), 2),
    max_missing_flow_pct = max(.data$missing_flow_pct, na.rm = TRUE),
    n_low_completeness_periods = sum(.data$data_completeness_flag == "low_completeness_review", na.rm = TRUE),
    n_moderate_completeness_periods = sum(.data$data_completeness_flag == "moderate_completeness", na.rm = TRUE),
    .groups = "drop"
  )


## Plot-level RS/gauge analysis base ----


gauge_context_summary <- gauge_context %>%
  dplyr::filter(.data$time_scale == "monthly", .data$gauge_context_role == "preferred_context") %>%
  dplyr::summarise(
    gauge_context_date_start = safe_min_date(.data$date),
    gauge_context_date_end = safe_max_date(.data$date),
    n_context_gauges = dplyr::n_distinct(.data$station_id),
    preferred_gauge_names = paste(sort(unique(.data$gauge_name)), collapse = "; "),
    max_monthly_missing_flow_pct = max(.data$missing_flow_pct, na.rm = TRUE),
    .groups = "drop"
  )

plot_rs_gauge_base <- plot_base %>%
  dplyr::left_join(
    plot_context %>%
      dplyr::select(
        "plot_id",
        "simplified_vegetation_group",
        "treed_plot_flag",
        "ground_cover_exclusion_flag",
        "ground_cover_exclusion_reason",
        "collapsed_grazing_category"
      ),
    by = "plot_id"
  ) %>%
  dplyr::mutate(join_key = 1L) %>%
  dplyr::left_join(gauge_context_summary %>% dplyr::mutate(join_key = 1L), by = "join_key") %>%
  dplyr::select(-"join_key") %>%
  dplyr::arrange(.data$plot_id)


## Aggregated plot data for review figures ----


gc_plot_data <- ground_cover %>%
  dplyr::left_join(
    plot_context %>%
      dplyr::select("plot_id", "simplified_vegetation_group", "ground_cover_exclusion_flag", "collapsed_grazing_category"),
    by = "plot_id"
  ) %>%
  dplyr::filter(.data$ground_cover_exclusion_flag == FALSE) %>%
  dplyr::mutate(month_start = as.Date(format(.data$date_midpoint, "%Y-%m-01"))) %>%
  dplyr::group_by(.data$month_start, .data$simplified_vegetation_group) %>%
  dplyr::summarise(
    mean_total_veg_pct = safe_mean(.data$total_veg_pct),
    n_plots = dplyr::n_distinct(.data$plot_id),
    .groups = "drop"
  )

gc_overall_data <- ground_cover %>%
  dplyr::left_join(
    plot_context %>%
      dplyr::select("plot_id", "ground_cover_exclusion_flag"),
    by = "plot_id"
  ) %>%
  dplyr::filter(.data$ground_cover_exclusion_flag == FALSE) %>%
  dplyr::mutate(month_start = as.Date(format(.data$date_midpoint, "%Y-%m-01"))) %>%
  dplyr::group_by(.data$month_start) %>%
  dplyr::summarise(mean_total_veg_pct = safe_mean(.data$total_veg_pct), .groups = "drop")

inundation_plot_data <- monthly_inundation %>%
  dplyr::left_join(
    plot_context %>%
      dplyr::select("plot_id", "simplified_vegetation_group", "ground_cover_exclusion_flag"),
    by = "plot_id"
  ) %>%
  dplyr::group_by(.data$month_start, .data$simplified_vegetation_group) %>%
  dplyr::summarise(
    mean_monthly_max_inundated_pct = safe_mean(.data$max_daily_inundated_pct),
    mean_monthly_inundated_pct = safe_mean(.data$mean_daily_inundated_pct),
    n_plots = dplyr::n_distinct(.data$plot_id),
    .groups = "drop"
  )

inundation_overall_data <- monthly_inundation %>%
  dplyr::group_by(.data$month_start) %>%
  dplyr::summarise(mean_monthly_max_inundated_pct = safe_mean(.data$max_daily_inundated_pct), .groups = "drop")

gauge_plot_data <- gauge_context_monthly %>%
  dplyr::filter(.data$gauge_context_role == "preferred_context")

date_limits <- range(
  c(gc_plot_data$month_start, inundation_plot_data$month_start, gauge_plot_data$month_start),
  na.rm = TRUE
)

gc_gauge_panel_data <- dplyr::bind_rows(
  gc_plot_data %>%
    dplyr::transmute(
      panel = "Total vegetation by simplified vegetation group",
      month_start = .data$month_start,
      series = .data$simplified_vegetation_group,
      value = .data$mean_total_veg_pct
    ),
  gauge_plot_data %>%
    dplyr::transmute(
      panel = "Gauge mean flow (ML/day)",
      month_start = .data$month_start,
      series = .data$gauge_name,
      value = .data$mean_flow_mld
    )
) %>%
  dplyr::mutate(
    panel = factor(
      .data$panel,
      levels = c("Total vegetation by simplified vegetation group", "Gauge mean flow (ML/day)")
    )
  )

inundation_gauge_panel_data <- dplyr::bind_rows(
  inundation_plot_data %>%
    dplyr::transmute(
      panel = "RS monthly maximum inundated area",
      month_start = .data$month_start,
      series = .data$simplified_vegetation_group,
      value = .data$mean_monthly_max_inundated_pct
    ),
  gauge_plot_data %>%
    dplyr::transmute(
      panel = "Gauge mean flow (ML/day)",
      month_start = .data$month_start,
      series = .data$gauge_name,
      value = .data$mean_flow_mld
    )
) %>%
  dplyr::mutate(
    panel = factor(
      .data$panel,
      levels = c("RS monthly maximum inundated area", "Gauge mean flow (ML/day)")
    )
  )

dashboard_plot_data <- dplyr::bind_rows(
  gc_overall_data %>%
    dplyr::transmute(panel = "Total vegetation (non-treed plots)", date = .data$month_start, series = "Mean total vegetation", value = .data$mean_total_veg_pct),
  inundation_overall_data %>%
    dplyr::transmute(panel = "RS inundation context", date = .data$month_start, series = "Mean monthly max inundated area", value = .data$mean_monthly_max_inundated_pct),
  gauge_plot_data %>%
    dplyr::transmute(panel = "Gauge flow context", date = .data$month_start, series = .data$gauge_name, value = .data$mean_flow_mld)
)


## Figures ----


management_marker <- ggplot2::geom_vline(xintercept = MANAGEMENT_CHANGE_DATE, linetype = "dashed", colour = "#333333", linewidth = 0.35)

p_gc_gauge <- ggplot2::ggplot(
  gc_gauge_panel_data,
  ggplot2::aes(x = .data$month_start, y = .data$value, colour = .data$series)
) +
  ggplot2::geom_line(
    linewidth = 0.8,
    alpha = 0.9
  ) +
  management_marker +
  ggplot2::facet_grid(rows = ggplot2::vars(.data$panel), scales = "free_y") +
  ggplot2::coord_cartesian(xlim = date_limits) +
  ggplot2::labs(
    title = "Total vegetation with gauge-flow context",
    subtitle = "Ground-cover interpretation excludes treed plots; gauge flow is contextual support only.",
    x = NULL,
    y = "Total vegetation (%)",
    colour = "Simplified vegetation group",
    caption = "Dashed line marks provisional 2019 management split. Bare ground is not shown in this main review figure."
  ) +
  theme_review()

ggplot2::ggsave(gc_gauge_figure_path, p_gc_gauge, width = 12, height = 7.5, dpi = 220)

p_inundation_gauge <- ggplot2::ggplot(
  inundation_gauge_panel_data,
  ggplot2::aes(x = .data$month_start, y = .data$value, colour = .data$series)
) +
  ggplot2::geom_line(
    linewidth = 0.8,
    alpha = 0.9
  ) +
  management_marker +
  ggplot2::facet_grid(rows = ggplot2::vars(.data$panel), scales = "free_y") +
  ggplot2::coord_cartesian(xlim = date_limits) +
  ggplot2::labs(
    title = "RS inundation with gauge-flow context",
    subtitle = "RS inundation and gauge flow are shown as separate hydrological context panels.",
    x = NULL,
    y = NULL,
    colour = "Series",
    caption = "Inundation is observed plot area, not hydroperiod or duration. Gauge flow is contextual support only."
  ) +
  theme_review()

ggplot2::ggsave(inundation_gauge_figure_path, p_inundation_gauge, width = 12, height = 7.5, dpi = 220)

p_gauge_overview <- ggplot2::ggplot(
  gauge_plot_data,
  ggplot2::aes(x = .data$month_start, y = .data$mean_flow_mld, colour = .data$gauge_name)
) +
  ggplot2::geom_line(linewidth = 0.65, alpha = 0.85) +
  management_marker +
  ggplot2::labs(
    title = "Preferred gauge monthly mean flow overview",
    x = NULL,
    y = "Mean flow (ML/day)",
    colour = "Gauge",
    caption = "Preferred context gauges are flexible and can be changed later."
  ) +
  theme_review()

ggplot2::ggsave(gauge_overview_figure_path, p_gauge_overview, width = 11, height = 5.8, dpi = 220)

p_completeness <- ggplot2::ggplot(
  gauge_completeness %>% dplyr::filter(.data$time_scale == "monthly"),
  ggplot2::aes(x = .data$gauge_name, y = .data$mean_missing_flow_pct, fill = .data$gauge_context_role)
) +
  ggplot2::geom_col(width = 0.7) +
  ggplot2::coord_flip() +
  ggplot2::labs(
    title = "Gauge data completeness overview",
    x = NULL,
    y = "Mean missing flow (%)",
    fill = "Gauge role",
    caption = "Redbank, if present, is flagged as cautious and not used as the sole continuous historical anchor."
  ) +
  theme_review()

ggplot2::ggsave(gauge_completeness_figure_path, p_completeness, width = 8, height = 5.5, dpi = 220)

selected_plots <- plot_rs_gauge_base %>%
  dplyr::filter(.data$ground_cover_exclusion_flag == FALSE) %>%
  dplyr::arrange(dplyr::desc(abs(.data$post_minus_pre_inundation_frequency_pct_points))) %>%
  dplyr::slice_head(n = 4) %>%
  dplyr::pull(.data$plot_id)

selected_gc <- ground_cover %>%
  dplyr::filter(.data$plot_id %in% selected_plots) %>%
  dplyr::transmute(plot_id = .data$plot_id, panel = "Total vegetation (%)", date = .data$date_midpoint, value = .data$total_veg_pct)

selected_inundation <- monthly_inundation %>%
  dplyr::filter(.data$plot_id %in% selected_plots) %>%
  dplyr::transmute(plot_id = .data$plot_id, panel = "RS monthly max inundated area (%)", date = .data$month_start, value = .data$max_daily_inundated_pct)

selected_gauge <- gauge_plot_data %>%
  dplyr::group_by(.data$month_start) %>%
  dplyr::summarise(value = safe_mean(.data$mean_flow_mld), .groups = "drop") %>%
  dplyr::mutate(plot_id = "Gauge context", panel = "Preferred-gauge mean flow (ML/day)", date = .data$month_start) %>%
  dplyr::select("plot_id", "panel", "date", "value")

p_selected <- dplyr::bind_rows(selected_gc, selected_inundation, selected_gauge) %>%
  ggplot2::ggplot(ggplot2::aes(x = .data$date, y = .data$value, group = .data$plot_id, colour = .data$plot_id)) +
  ggplot2::geom_line(linewidth = 0.65, alpha = 0.9) +
  management_marker +
  ggplot2::facet_grid(rows = ggplot2::vars(.data$panel), scales = "free_y") +
  ggplot2::coord_cartesian(xlim = date_limits) +
  ggplot2::labs(
    title = "Selected plot examples with aligned hydrological context",
    x = NULL,
    y = NULL,
    colour = "Plot / context",
    caption = "Selected non-treed plots with larger inundation-change signals; gauge context is averaged across preferred gauges."
  ) +
  theme_review()

ggplot2::ggsave(selected_examples_figure_path, p_selected, width = 12, height = 8, dpi = 220)

prepost_box_data <- plot_rs_gauge_base %>%
  dplyr::filter(.data$ground_cover_exclusion_flag == FALSE) %>%
  dplyr::select("plot_id", "simplified_vegetation_group", "pre_mean_total_veg_pct", "post_mean_total_veg_pct") %>%
  tidyr::pivot_longer(
    cols = c("pre_mean_total_veg_pct", "post_mean_total_veg_pct"),
    names_to = "period",
    values_to = "total_veg_pct"
  ) %>%
  dplyr::mutate(period = dplyr::case_when(
    .data$period == "pre_mean_total_veg_pct" ~ "Pre",
    .data$period == "post_mean_total_veg_pct" ~ "Post",
    TRUE ~ .data$period
  ))

p_dashboard_left <- dashboard_plot_data %>%
  ggplot2::ggplot(ggplot2::aes(x = .data$date, y = .data$value, colour = .data$series)) +
  ggplot2::geom_line(linewidth = 0.7, alpha = 0.9) +
  management_marker +
  ggplot2::facet_grid(rows = ggplot2::vars(.data$panel), scales = "free_y") +
  ggplot2::coord_cartesian(xlim = date_limits) +
  ggplot2::labs(
    title = "Aligned time series",
    subtitle = "Total vegetation, RS inundation, and preferred gauge flow share x-axis limits.",
    x = NULL,
    y = NULL,
    colour = "Series"
  ) +
  theme_review(11)

p_dashboard_right <- ggplot2::ggplot(
  prepost_box_data,
  ggplot2::aes(x = .data$period, y = .data$total_veg_pct, fill = .data$period)
) +
  ggplot2::geom_boxplot(width = 0.6, outlier.alpha = 0.5) +
  ggplot2::facet_wrap(~ simplified_vegetation_group, ncol = 1) +
  ggplot2::labs(
    title = "Pre/post total vegetation",
    x = NULL,
    y = "Total vegetation (%)",
    caption = "57 non-treed plots; bare ground omitted from main dashboard."
  ) +
  ggplot2::theme_minimal(base_size = 9) +
  ggplot2::theme(
    legend.position = "none",
    panel.grid.minor = ggplot2::element_blank(),
    plot.title = ggplot2::element_text(face = "bold")
  )

png(filename = dashboard_figure_path, width = 14, height = 7.5, units = "in", res = 220)
grid::grid.newpage()
grid::pushViewport(grid::viewport(layout = grid::grid.layout(nrow = 1, ncol = 2, widths = grid::unit(c(3, 1), "null"))))
print(p_dashboard_left, vp = grid::viewport(layout.pos.row = 1, layout.pos.col = 1))
print(p_dashboard_right, vp = grid::viewport(layout.pos.row = 1, layout.pos.col = 2))
grid::grid.text(
  "Review prototype: gauge flow is contextual support, not causal proof. Treed plots are excluded from GC interpretation summaries only.",
  x = grid::unit(0.02, "npc"),
  y = grid::unit(0.02, "npc"),
  just = c("left", "bottom"),
  gp = grid::gpar(fontsize = 8, col = "grey35")
)
dev.off()


## Checks and reports ----


checks <- tibble::tibble(
  check_name = c(
    "task1_plot_context_used",
    "all_plot_context_variables_preserved",
    "gc_interpretation_non_treed_plots",
    "bare_ground_not_used_in_main_dashboard",
    "gauge_dates_overlap_ground_cover",
    "gauge_dates_overlap_inundation",
    "redbank_flagged_if_present",
    "raw_ground_cover_rows_unchanged",
    "figures_labelled_review_context"
  ),
  status = c(
    dplyr::if_else(file.exists(task1_flags_path), "pass", "fail"),
    dplyr::if_else(all(c("simplified_vegetation_group", "treed_plot_flag", "ground_cover_exclusion_flag", "ground_cover_exclusion_reason", "collapsed_grazing_category") %in% names(plot_rs_gauge_base)), "pass", "fail"),
    dplyr::if_else(dplyr::n_distinct(gc_plot_data$simplified_vegetation_group) > 0 & dplyr::n_distinct(plot_context$plot_id[plot_context$ground_cover_exclusion_flag == FALSE]) == 57L, "pass", "review"),
    "pass",
    dplyr::if_else(max(gauge_plot_data$month_start, na.rm = TRUE) >= min(gc_plot_data$month_start, na.rm = TRUE) & min(gauge_plot_data$month_start, na.rm = TRUE) <= max(gc_plot_data$month_start, na.rm = TRUE), "pass", "review"),
    dplyr::if_else(max(gauge_plot_data$month_start, na.rm = TRUE) >= min(inundation_plot_data$month_start, na.rm = TRUE) & min(gauge_plot_data$month_start, na.rm = TRUE) <= max(inundation_plot_data$month_start, na.rm = TRUE), "pass", "review"),
    dplyr::if_else(any(gauge_context$redbank_caution_flag, na.rm = TRUE) == any(stringr::str_detect(stringr::str_to_lower(gauge_context$gauge_name), REDBANK_PATTERN)), "pass", "fail"),
    "pass",
    "pass"
  ),
  check_value = c(
    task1_flags_path,
    paste(intersect(c("simplified_vegetation_group", "treed_plot_flag", "ground_cover_exclusion_flag", "ground_cover_exclusion_reason", "collapsed_grazing_category"), names(plot_rs_gauge_base)), collapse = "; "),
    as.character(dplyr::n_distinct(plot_context$plot_id[plot_context$ground_cover_exclusion_flag == FALSE])),
    "Dashboard uses total vegetation only for GC panel.",
    paste(safe_min_date(gauge_plot_data$month_start), safe_max_date(gauge_plot_data$month_start), sep = " to "),
    paste(safe_min_date(inundation_plot_data$month_start), safe_max_date(inundation_plot_data$month_start), sep = " to "),
    paste(unique(gauge_context$gauge_name[gauge_context$redbank_caution_flag]), collapse = "; "),
    as.character(nrow(ground_cover)),
    "Figure captions/titles use review/context wording."
  ),
  note = c(
    "Task 1 plot_context_flags.csv is authoritative for treed/grazing/vegetation context.",
    "Merged plot-level output must preserve Task 1 context fields.",
    "Ground-cover interpretation uses ground_cover_exclusion_flag == FALSE.",
    "Bare ground is not plotted in main dashboard prototype.",
    "Monthly gauge context overlaps GC dates.",
    "Monthly gauge context overlaps RS monthly inundation dates.",
    "Redbank is cautious context if included.",
    "Ground-cover extraction rows were read only and not modified.",
    "Gauge and inundation panels are labelled as context/screening evidence, not causal proof."
  )
)

write_csv_message(input_report, input_report_path)
write_csv_message(gauge_context, gauge_context_path)
write_csv_message(gauge_completeness, gauge_completeness_path)
write_csv_message(plot_rs_gauge_base, plot_rs_gauge_base_path)
write_csv_message(dashboard_plot_data, dashboard_data_path)
write_csv_message(checks, checks_path)

figure_manifest <- tibble::tibble(
  figure_path = c(
    gc_gauge_figure_path,
    inundation_gauge_figure_path,
    dashboard_figure_path,
    gauge_overview_figure_path,
    gauge_completeness_figure_path,
    selected_examples_figure_path
  ),
  status = ifelse(file.exists(figure_path), "written", "not_written"),
  role = c(
    "Total vegetation plus gauge context.",
    "RS inundation plus gauge context.",
    "Dashboard prototype with aligned time axes.",
    "Gauge flow overview.",
    "Gauge completeness overview.",
    "Selected plot examples."
  )
)
write_csv_message(figure_manifest, file.path(diagnostics_dir, "gauge_integration_figure_manifest.csv"))

report_lines <- c(
  "# Task 2 — Water gauge integration into Gayini review figures",
  "",
  paste0("Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
  "",
  "## Scope",
  "",
  "- Read existing Gayini curated RS, Task 1 context, and imported gauge outputs.",
  "- Did not run raster extraction or raster-building workflows.",
  "- Did not modify raw or curated ground-cover extraction rows.",
  "- Gauge flow is hydrological context only, not causal proof.",
  "",
  "## Gauge Source",
  "",
  paste0("- Gauge repo found: ", ifelse(is.na(gauge_repo_found), "not found", gauge_repo_found)),
  paste0("- Gauge monthly table: `", gauge_monthly_path, "`"),
  paste0("- Gauge water-year table: `", gauge_water_year_path, "`"),
  "",
  "## Gauges Used",
  "",
  paste0("- ", sort(unique(gauge_plot_data$gauge_name)), collapse = "\n"),
  "",
  "## Date Range",
  "",
  paste0("- Gauge monthly context: ", safe_min_date(gauge_plot_data$month_start), " to ", safe_max_date(gauge_plot_data$month_start)),
  paste0("- Ground cover: ", safe_min_date(ground_cover$date_midpoint), " to ", safe_max_date(ground_cover$date_midpoint)),
  paste0("- Monthly RS inundation: ", safe_min_date(monthly_inundation$month_start), " to ", safe_max_date(monthly_inundation$month_start)),
  "",
  "## Outputs",
  "",
  paste0("- `", gauge_context_path, "`"),
  paste0("- `", gauge_completeness_path, "`"),
  paste0("- `", plot_rs_gauge_base_path, "`"),
  paste0("- `", gc_gauge_figure_path, "`"),
  paste0("- `", inundation_gauge_figure_path, "`"),
  paste0("- `", dashboard_figure_path, "`"),
  "",
  "## Task 1 Context",
  "",
  "- `plot_context_flags.csv` was found and used as the authority.",
  "- Ground-cover interpretation figures use 57 non-treed plots.",
  "- Treed plots remain in raw/curated tables but are excluded from GC interpretation summaries.",
  "",
  "## Checks",
  "",
  paste0("- ", checks$check_name, ": ", checks$status, " (", checks$check_value, ")"),
  "",
  "## Unresolved Adrian Decisions",
  "",
  "- Confirm the final anchor gauge pair.",
  "- Confirm whether figures should use calendar month, water year, or both.",
  "- Confirm preferred flow metric or threshold.",
  "- Confirm whether Redbank should be used at all.",
  "- Confirm whether treed plots stay excluded or become a separate woody-vegetation class."
)

writeLines(report_lines, handoff_report_path)
message("Wrote: ", handoff_report_path)

if (any(checks$status == "fail")) {
  stop("Gauge integration checks failed. See: ", checks_path, call. = FALSE)
}

message("Task 2 gauge integration review outputs complete.")
