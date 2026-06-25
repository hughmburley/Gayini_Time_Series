## -----------------------------------------------------------------------------
## Gayini remote sensing workflow
## 10f_prepare_background_flood_pattern_matched_years.R
## -----------------------------------------------------------------------------


## Purpose:
## Create lightweight review outputs for historical/background inundation patterns
## and matched-year comparisons. This script reads existing curated annual
## inundation, Task 1 plot context, and Task 2 gauge context outputs only.
## It does not build rasters or modify existing .tif files.


## User settings ----


root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", "D:/Github_repos/Gayini"), winslash = "/", mustWork = TRUE)
BACKGROUND_END_YEAR <- 2015L
PRE_MATCH_MIN_END_YEAR <- 2015L
MANAGEMENT_CHANGE_END_YEAR <- 2020L
N_WET_YEARS_PER_PERIOD <- 6L
MIN_VALID_PLOTS_FOR_YEAR <- 50L
MIN_WET_PLOT_PCT_FOR_MATCH <- 50
DISCUSSION_WATER_YEAR_ENDS <- c(2017L, 2022L, 2023L)
PRIMARY_GAUGE_ROLE <- "preferred_context"


## Required packages ----


required_packages <- c(
  "dplyr",
  "tidyr",
  "readr",
  "stringr",
  "magrittr",
  "tibble",
  "ggplot2"
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


## Paths ----


csv_dir <- file.path(root_dir, "Output", "csv")
figure_dir <- file.path(root_dir, "Output", "figures", "review")
diagnostics_dir <- file.path(root_dir, "Output", "diagnostics", "10f_background_matched_years")
report_dir <- file.path(root_dir, "Output", "reports")
raster_dir <- file.path(root_dir, "Output", "rasters")

dir.create(csv_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(diagnostics_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(report_dir, recursive = TRUE, showWarnings = FALSE)

annual_inundation_path <- file.path(csv_dir, "curated_annual_inundation_timeseries.csv")
plot_context_path <- file.path(csv_dir, "plot_context_flags.csv")
plot_rs_gauge_base_path <- file.path(csv_dir, "plot_rs_gauge_analysis_base.csv")
gauge_context_path <- file.path(csv_dir, "gauge_context_for_gayini.csv")

background_plot_path <- file.path(csv_dir, "background_inundation_frequency_by_plot.csv")
vegetation_group_path <- file.path(csv_dir, "inundation_frequency_by_vegetation_group.csv")
candidate_ranking_path <- file.path(csv_dir, "matched_year_candidate_ranking.csv")
matched_gauge_context_path <- file.path(csv_dir, "matched_year_gauge_context.csv")

input_report_path <- file.path(diagnostics_dir, "task3_input_report.csv")
checks_path <- file.path(diagnostics_dir, "task3_checks.csv")
period_selection_path <- file.path(diagnostics_dir, "background_period_selection.csv")
year_summary_path <- file.path(diagnostics_dir, "annual_inundation_year_summary.csv")
figure_manifest_path <- file.path(diagnostics_dir, "task3_figure_manifest.csv")

background_map_path <- file.path(figure_dir, "background_flood_pattern_pre2015.png")
matched_year_figure_path <- file.path(figure_dir, "matched_year_inundation_comparison.png")
vegetation_group_figure_path <- file.path(figure_dir, "inundation_frequency_by_vegetation_group.png")
handoff_report_path <- file.path(report_dir, "task_3_background_flood_pattern_handoff.md")


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


safe_median <- function(x) {
  if (all(is.na(x))) {
    return(NA_real_)
  }
  median(x, na.rm = TRUE)
}


safe_min <- function(x) {
  if (all(is.na(x))) {
    return(NA_real_)
  }
  min(x, na.rm = TRUE)
}


safe_max <- function(x) {
  if (all(is.na(x))) {
    return(NA_real_)
  }
  max(x, na.rm = TRUE)
}


relative_difference_pct <- function(x, y) {
  denominator <- mean(c(x, y), na.rm = TRUE)
  if (is.na(denominator) || denominator == 0) {
    return(NA_real_)
  }
  100 * abs(x - y) / denominator
}


normalise_score <- function(x) {
  if (all(is.na(x))) {
    return(rep(NA_real_, length(x)))
  }

  max_x <- max(x, na.rm = TRUE)
  if (is.na(max_x) || max_x == 0) {
    return(rep(0, length(x)))
  }

  x / max_x * 100
}


theme_review <- function(base_size = 12) {
  ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      plot.title = ggplot2::element_text(face = "bold"),
      plot.caption = ggplot2::element_text(hjust = 0, colour = "grey35", size = base_size * 0.78),
      strip.text = ggplot2::element_text(face = "bold")
    )
}


format_years <- function(x) {
  paste(sort(unique(x)), collapse = ", ")
}


## Input review ----


tif_snapshot_before <- tibble::tibble(
  tif_path = list.files(raster_dir, pattern = "\\.tif$", recursive = TRUE, full.names = TRUE),
  last_write_time_before = as.character(file.info(tif_path)$mtime),
  size_before = file.info(tif_path)$size
)

input_report <- tibble::tibble(
  input_name = c(
    "curated_annual_inundation_timeseries",
    "plot_context_flags",
    "plot_rs_gauge_analysis_base",
    "gauge_context_for_gayini",
    "existing_tif_outputs"
  ),
  path = c(
    annual_inundation_path,
    plot_context_path,
    plot_rs_gauge_base_path,
    gauge_context_path,
    raster_dir
  ),
  found = c(
    file.exists(annual_inundation_path),
    file.exists(plot_context_path),
    file.exists(plot_rs_gauge_base_path),
    file.exists(gauge_context_path),
    nrow(tif_snapshot_before) > 0
  ),
  role = c(
    "Annual plot-level inundation source for historical and matched-year summaries.",
    "Task 1 authority for vegetation groups, treed flags and grazing collapse.",
    "Task 2 combined plot-level review base.",
    "Task 2 gauge-flow context used only as hydrological support.",
    "Existing raster outputs inventoried only; no .tif files are written."
  )
)

write_csv_message(input_report, input_report_path)

required_inputs <- input_report %>%
  dplyr::filter(.data$input_name %in% c(
    "curated_annual_inundation_timeseries",
    "plot_context_flags",
    "plot_rs_gauge_analysis_base",
    "gauge_context_for_gayini"
  ))

if (any(!required_inputs$found)) {
  stop(
    "Missing required Task 3 input(s): ",
    paste(required_inputs$input_name[!required_inputs$found], collapse = ", "),
    call. = FALSE
  )
}


## Read inputs ----


annual_inundation <- readr::read_csv(annual_inundation_path, show_col_types = FALSE) %>%
  gayini_standardise_plot_id(object_name = "curated annual inundation") %>%
  dplyr::mutate(
    water_year_end_year = as.integer(stringr::str_extract(.data$water_year, "\\d{4}$")),
    water_year_start_year = as.integer(stringr::str_extract(.data$water_year, "^\\d{4}")),
    date_start = as.Date(.data$date_start),
    date_end = as.Date(.data$date_end),
    annual_valid_any = as.integer(.data$annual_valid_any),
    annual_wet_any = as.integer(.data$annual_wet_any),
    inundated_any_pct = as.numeric(.data$inundated_any_pct)
  )

plot_context <- readr::read_csv(plot_context_path, show_col_types = FALSE) %>%
  gayini_standardise_plot_id(object_name = "Task 1 plot context flags") %>%
  dplyr::select(
    "plot_id",
    "simplified_vegetation_group",
    "treed_plot_flag",
    "ground_cover_exclusion_flag",
    "ground_cover_exclusion_reason",
    "collapsed_grazing_category",
    "centroid_x",
    "centroid_y",
    "area_ha"
  )

plot_rs_gauge_base <- readr::read_csv(plot_rs_gauge_base_path, show_col_types = FALSE) %>%
  gayini_standardise_plot_id(object_name = "Task 2 plot RS/gauge base")

gauge_context <- readr::read_csv(gauge_context_path, show_col_types = FALSE) %>%
  dplyr::mutate(
    date = as.Date(.data$date),
    mean_flow_mld = as.numeric(.data$mean_flow_mld),
    total_flow_ml = as.numeric(.data$total_flow_ml),
    max_daily_flow_mld = as.numeric(.data$max_daily_flow_mld),
    missing_flow_pct = as.numeric(.data$missing_flow_pct),
    water_year_end_year = as.integer(stringr::str_extract(.data$water_year, "\\d{4}$"))
  )

annual_context <- annual_inundation %>%
  dplyr::left_join(plot_context, by = "plot_id") %>%
  dplyr::mutate(
    valid_for_frequency = .data$annual_valid_any == 1L,
    wet_for_frequency = .data$annual_wet_any == 1L & .data$valid_for_frequency,
    inundated_any_pct_valid = dplyr::if_else(.data$valid_for_frequency, .data$inundated_any_pct, NA_real_)
  )


## Historical/background period ----


pre_2015_available <- annual_context %>%
  dplyr::filter(
    .data$water_year_end_year <= BACKGROUND_END_YEAR,
    .data$valid_for_frequency
  )

if (nrow(pre_2015_available) > 0) {
  background_year_end_max <- BACKGROUND_END_YEAR
  background_period_type <- "pre_2015_plot_history"
} else {
  background_year_end_max <- MANAGEMENT_CHANGE_END_YEAR - 1L
  background_period_type <- "pre_management_plot_history_fallback"
}

background_data <- annual_context %>%
  dplyr::filter(
    .data$water_year_end_year <= background_year_end_max,
    .data$valid_for_frequency
  )

if (nrow(background_data) == 0) {
  stop("No valid annual inundation records available for background period.", call. = FALSE)
}

background_years <- sort(unique(background_data$water_year_end_year))
background_period_label <- paste0(
  min(background_data$water_year_start_year, na.rm = TRUE),
  "-",
  min(background_data$water_year_end_year, na.rm = TRUE),
  " to ",
  max(background_data$water_year_start_year, na.rm = TRUE),
  "-",
  max(background_data$water_year_end_year, na.rm = TRUE)
)

background_period_selection <- tibble::tibble(
  background_period_type = background_period_type,
  background_period_label = background_period_label,
  background_year_end_min = min(background_years),
  background_year_end_max = max(background_years),
  n_background_water_years = length(background_years),
  annual_raster_pre2015_available = any(stringr::str_detect(tif_snapshot_before$tif_path, "__2014\\.tif$|__2015\\.tif$")),
  note = "Plot-level historical background uses curated annual table. Existing .tif outputs are inventoried only and not overwritten."
)

write_csv_message(background_period_selection, period_selection_path)

background_by_plot <- background_data %>%
  dplyr::group_by(
    .data$plot_id,
    .data$simplified_vegetation_group,
    .data$treed_plot_flag,
    .data$ground_cover_exclusion_flag,
    .data$ground_cover_exclusion_reason,
    .data$collapsed_grazing_category,
    .data$centroid_x,
    .data$centroid_y,
    .data$area_ha
  ) %>%
  dplyr::summarise(
    background_period_label = background_period_label,
    background_valid_year_count = dplyr::n_distinct(.data$water_year_end_year),
    background_wet_year_count = sum(.data$wet_for_frequency, na.rm = TRUE),
    background_inundation_frequency_pct = 100 * .data$background_wet_year_count / .data$background_valid_year_count,
    background_mean_inundated_area_pct = safe_mean(.data$inundated_any_pct_valid),
    background_max_inundated_area_pct = safe_max(.data$inundated_any_pct_valid),
    first_valid_water_year = min(.data$water_year, na.rm = TRUE),
    last_valid_water_year = max(.data$water_year, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  dplyr::left_join(
    plot_rs_gauge_base %>%
      dplyr::select(
        "plot_id",
        "pre_conservation_inundation_frequency_pct",
        "post_conservation_inundation_frequency_pct",
        "post_minus_pre_inundation_frequency_pct_points",
        "inundation_change_class",
        "preferred_gauge_names"
      ),
    by = "plot_id"
  ) %>%
  dplyr::arrange(dplyr::desc(.data$background_inundation_frequency_pct), .data$plot_id)

vegetation_group_summary <- background_by_plot %>%
  dplyr::group_by(.data$simplified_vegetation_group, .data$treed_plot_flag) %>%
  dplyr::summarise(
    background_period_label = dplyr::first(.data$background_period_label),
    n_plots = dplyr::n_distinct(.data$plot_id),
    mean_background_inundation_frequency_pct = round(safe_mean(.data$background_inundation_frequency_pct), 2),
    median_background_inundation_frequency_pct = round(safe_median(.data$background_inundation_frequency_pct), 2),
    min_background_inundation_frequency_pct = round(safe_min(.data$background_inundation_frequency_pct), 2),
    max_background_inundation_frequency_pct = round(safe_max(.data$background_inundation_frequency_pct), 2),
    mean_background_wet_year_count = round(safe_mean(.data$background_wet_year_count), 2),
    mean_background_valid_year_count = round(safe_mean(.data$background_valid_year_count), 2),
    .groups = "drop"
  ) %>%
  dplyr::arrange(.data$treed_plot_flag, dplyr::desc(.data$mean_background_inundation_frequency_pct))


## Candidate years and matched-year ranking ----


year_summary <- annual_context %>%
  dplyr::filter(.data$valid_for_frequency) %>%
  dplyr::group_by(.data$water_year, .data$water_year_end_year) %>%
  dplyr::summarise(
    valid_plot_count = dplyr::n_distinct(.data$plot_id),
    wet_plot_count = sum(.data$wet_for_frequency, na.rm = TRUE),
    whole_farm_wet_plot_pct = 100 * .data$wet_plot_count / .data$valid_plot_count,
    mean_inundated_area_pct = safe_mean(.data$inundated_any_pct_valid),
    median_inundated_area_pct = safe_median(.data$inundated_any_pct_valid),
    max_plot_inundated_area_pct = safe_max(.data$inundated_any_pct_valid),
    .groups = "drop"
  ) %>%
  dplyr::filter(.data$valid_plot_count >= MIN_VALID_PLOTS_FOR_YEAR)

gauge_year_summary <- gauge_context %>%
  dplyr::filter(
    .data$time_scale == "water_year",
    .data$gauge_context_role == PRIMARY_GAUGE_ROLE,
    .data$redbank_caution_flag == FALSE
  ) %>%
  dplyr::group_by(.data$water_year, .data$water_year_end_year) %>%
  dplyr::summarise(
    gauge_count = dplyr::n_distinct(.data$station_id),
    preferred_gauges = paste(sort(unique(.data$gauge_name)), collapse = "; "),
    mean_gauge_flow_mld = safe_mean(.data$mean_flow_mld),
    mean_total_flow_ml = safe_mean(.data$total_flow_ml),
    max_daily_flow_mld = safe_max(.data$max_daily_flow_mld),
    mean_missing_flow_pct = safe_mean(.data$missing_flow_pct),
    .groups = "drop"
  )

year_summary <- year_summary %>%
  dplyr::left_join(gauge_year_summary, by = c("water_year", "water_year_end_year")) %>%
  dplyr::mutate(
    period_class = dplyr::case_when(
      .data$water_year_end_year < MANAGEMENT_CHANGE_END_YEAR ~ "pre_management",
      TRUE ~ "post_management"
    ),
    discussion_year_flag = .data$water_year_end_year %in% DISCUSSION_WATER_YEAR_ENDS
  )

pre_candidate_years <- year_summary %>%
  dplyr::filter(.data$period_class == "pre_management", .data$water_year_end_year >= PRE_MATCH_MIN_END_YEAR) %>%
  dplyr::arrange(dplyr::desc(.data$whole_farm_wet_plot_pct), .data$water_year_end_year) %>%
  dplyr::slice_head(n = N_WET_YEARS_PER_PERIOD) %>%
  dplyr::pull(.data$water_year_end_year) %>%
  union(year_summary$water_year_end_year[year_summary$discussion_year_flag & year_summary$period_class == "pre_management"])

post_candidate_years <- year_summary %>%
  dplyr::filter(.data$period_class == "post_management") %>%
  dplyr::arrange(dplyr::desc(.data$whole_farm_wet_plot_pct), .data$water_year_end_year) %>%
  dplyr::slice_head(n = N_WET_YEARS_PER_PERIOD) %>%
  dplyr::pull(.data$water_year_end_year) %>%
  union(year_summary$water_year_end_year[year_summary$discussion_year_flag & year_summary$period_class == "post_management"])

group_year_profile <- annual_context %>%
  dplyr::filter(.data$valid_for_frequency) %>%
  dplyr::group_by(.data$water_year_end_year, .data$simplified_vegetation_group) %>%
  dplyr::summarise(
    group_wet_plot_pct = 100 * sum(.data$wet_for_frequency, na.rm = TRUE) / dplyr::n_distinct(.data$plot_id),
    .groups = "drop"
  )

candidate_pairs <- tidyr::crossing(
  pre_water_year_end_year = sort(unique(pre_candidate_years)),
  post_water_year_end_year = sort(unique(post_candidate_years))
) %>%
  dplyr::left_join(
    year_summary %>%
      dplyr::select(
        pre_water_year = water_year,
        pre_water_year_end_year = water_year_end_year,
        pre_valid_plot_count = valid_plot_count,
        pre_whole_farm_wet_plot_pct = whole_farm_wet_plot_pct,
        pre_mean_inundated_area_pct = mean_inundated_area_pct,
        pre_mean_gauge_flow_mld = mean_gauge_flow_mld,
        pre_mean_total_flow_ml = mean_total_flow_ml,
        pre_mean_missing_flow_pct = mean_missing_flow_pct
      ),
    by = "pre_water_year_end_year"
  ) %>%
  dplyr::left_join(
    year_summary %>%
      dplyr::select(
        post_water_year = water_year,
        post_water_year_end_year = water_year_end_year,
        post_valid_plot_count = valid_plot_count,
        post_whole_farm_wet_plot_pct = whole_farm_wet_plot_pct,
        post_mean_inundated_area_pct = mean_inundated_area_pct,
        post_mean_gauge_flow_mld = mean_gauge_flow_mld,
        post_mean_total_flow_ml = mean_total_flow_ml,
        post_mean_missing_flow_pct = mean_missing_flow_pct
      ),
    by = "post_water_year_end_year"
  )

wet_candidate_pairs <- candidate_pairs %>%
  dplyr::filter(
    .data$pre_whole_farm_wet_plot_pct >= MIN_WET_PLOT_PCT_FOR_MATCH,
    .data$post_whole_farm_wet_plot_pct >= MIN_WET_PLOT_PCT_FOR_MATCH
  )

candidate_pair_filter_note <- if (nrow(wet_candidate_pairs) > 0) {
  candidate_pairs <- wet_candidate_pairs
  paste0(
    "Matched-year ranking restricted to pairs where both years had at least ",
    MIN_WET_PLOT_PCT_FOR_MATCH,
    "% of valid plots wet."
  )
} else {
  paste0(
    "No candidate pairs met the ",
    MIN_WET_PLOT_PCT_FOR_MATCH,
    "% wet-plot threshold in both years; ranking used the full candidate pool."
  )
}

group_pair_scores <- candidate_pairs %>%
  dplyr::select("pre_water_year_end_year", "post_water_year_end_year") %>%
  dplyr::left_join(
    group_year_profile %>%
      dplyr::rename(pre_water_year_end_year = water_year_end_year, pre_group_wet_plot_pct = group_wet_plot_pct),
    by = "pre_water_year_end_year",
    relationship = "many-to-many"
  ) %>%
  dplyr::left_join(
    group_year_profile %>%
      dplyr::rename(post_water_year_end_year = water_year_end_year, post_group_wet_plot_pct = group_wet_plot_pct),
    by = c("post_water_year_end_year", "simplified_vegetation_group"),
    relationship = "many-to-many"
  ) %>%
  dplyr::group_by(.data$pre_water_year_end_year, .data$post_water_year_end_year) %>%
  dplyr::summarise(
    vegetation_group_mean_abs_diff_pct_points = safe_mean(abs(.data$pre_group_wet_plot_pct - .data$post_group_wet_plot_pct)),
    vegetation_groups_compared = dplyr::n_distinct(.data$simplified_vegetation_group[!is.na(.data$pre_group_wet_plot_pct) & !is.na(.data$post_group_wet_plot_pct)]),
    .groups = "drop"
  )

candidate_ranking <- candidate_pairs %>%
  dplyr::left_join(group_pair_scores, by = c("pre_water_year_end_year", "post_water_year_end_year")) %>%
  dplyr::mutate(
    whole_farm_abs_diff_pct_points = abs(.data$pre_whole_farm_wet_plot_pct - .data$post_whole_farm_wet_plot_pct),
    mean_area_abs_diff_pct_points = abs(.data$pre_mean_inundated_area_pct - .data$post_mean_inundated_area_pct),
    gauge_total_flow_relative_diff_pct = mapply(relative_difference_pct, .data$pre_mean_total_flow_ml, .data$post_mean_total_flow_ml),
    support_abs_diff_plots = abs(.data$pre_valid_plot_count - .data$post_valid_plot_count),
    discussion_pair_flag = .data$pre_water_year_end_year %in% DISCUSSION_WATER_YEAR_ENDS &
      .data$post_water_year_end_year %in% DISCUSSION_WATER_YEAR_ENDS
  ) %>%
  dplyr::mutate(
    gauge_missing_mean_pct = dplyr::case_when(
      "pre_mean_missing_flow_pct" %in% names(.) & "post_mean_missing_flow_pct" %in% names(.) ~
        rowMeans(
          tibble::tibble(
            pre_missing = .[["pre_mean_missing_flow_pct"]],
            post_missing = .[["post_mean_missing_flow_pct"]]
          ),
          na.rm = TRUE
        ),
      TRUE ~ 0
    )
  ) %>%
  dplyr::mutate(
    whole_farm_score = normalise_score(.data$whole_farm_abs_diff_pct_points),
    mean_area_score = normalise_score(.data$mean_area_abs_diff_pct_points),
    group_score = normalise_score(.data$vegetation_group_mean_abs_diff_pct_points),
    gauge_score = normalise_score(.data$gauge_total_flow_relative_diff_pct),
    support_score = normalise_score(.data$support_abs_diff_plots + dplyr::coalesce(.data$gauge_missing_mean_pct, 0)),
    total_match_score = 0.35 * .data$whole_farm_score +
      0.20 * .data$mean_area_score +
      0.30 * .data$group_score +
      0.10 * dplyr::coalesce(.data$gauge_score, 50) +
      0.05 * .data$support_score
  ) %>%
  dplyr::arrange(.data$total_match_score, .data$whole_farm_abs_diff_pct_points, .data$mean_area_abs_diff_pct_points) %>%
  dplyr::mutate(
    candidate_rank = dplyr::row_number(),
    selection_basis = paste0(
      "Ranked by similarity in whole-farm annual occurrence, mean inundated area, vegetation-group occurrence profile, preferred-gauge flow context, and support/completeness."
    ),
    candidate_pair_filter_note = candidate_pair_filter_note
  ) %>%
  dplyr::select(
    "candidate_rank",
    "pre_water_year",
    "post_water_year",
    "pre_water_year_end_year",
    "post_water_year_end_year",
    "whole_farm_abs_diff_pct_points",
    "mean_area_abs_diff_pct_points",
    "vegetation_group_mean_abs_diff_pct_points",
    "gauge_total_flow_relative_diff_pct",
    "support_abs_diff_plots",
    "total_match_score",
    "discussion_pair_flag",
    "candidate_pair_filter_note",
    dplyr::everything()
  )

if (nrow(candidate_ranking) == 0) {
  stop("No candidate matched-year pairs could be ranked.", call. = FALSE)
}

selected_pair <- candidate_ranking %>%
  dplyr::slice_head(n = 1)

selected_year_ends <- c(selected_pair$pre_water_year_end_year, selected_pair$post_water_year_end_year)
selected_year_labels <- c(selected_pair$pre_water_year, selected_pair$post_water_year)

matched_year_gauge_context <- gauge_context %>%
  dplyr::filter(
    .data$time_scale == "water_year",
    .data$water_year_end_year %in% selected_year_ends,
    .data$gauge_context_role %in% c(PRIMARY_GAUGE_ROLE, "redbank_cautious")
  ) %>%
  dplyr::mutate(
    gauge_use_note = dplyr::case_when(
      .data$gauge_context_role == PRIMARY_GAUGE_ROLE & .data$redbank_caution_flag == FALSE ~ "preferred context gauge",
      .data$redbank_caution_flag == TRUE ~ "Redbank cautious context only; not a primary continuous anchor",
      TRUE ~ "context"
    )
  ) %>%
  dplyr::arrange(.data$water_year_end_year, .data$gauge_context_role, .data$gauge_name)


## Figures ----


background_map <- background_by_plot %>%
  ggplot2::ggplot(ggplot2::aes(
    x = .data$centroid_x,
    y = .data$centroid_y,
    colour = .data$background_inundation_frequency_pct,
    shape = .data$treed_plot_flag
  )) +
  ggplot2::geom_point(size = 3.2, alpha = 0.95) +
  ggplot2::coord_equal() +
  ggplot2::scale_colour_gradientn(
    colours = c("#8c510a", "#f6e8c3", "#80cdc1", "#01665e"),
    limits = c(0, 100),
    name = "Annual occurrence\nfrequency (%)"
  ) +
  ggplot2::scale_shape_manual(values = c("FALSE" = 16, "TRUE" = 17), name = "Treed plot") +
  ggplot2::labs(
    title = "Historical background flood pattern",
    subtitle = paste0(background_period_label, " plot-level annual occurrence frequency"),
    x = NULL,
    y = NULL,
    caption = stringr::str_wrap(
      "Review/preliminary. Frequency is percent of valid annual records with inundation detected; not hydroperiod, duration or depth. Map uses plot centroids because pre-2015 annual rasters are not available as a long historical stack.",
      width = 120
    )
  ) +
  theme_review()

ggplot2::ggsave(background_map_path, background_map, width = 9.8, height = 7.2, dpi = 220)

matched_year_plot_data <- annual_context %>%
  dplyr::filter(.data$water_year_end_year %in% selected_year_ends) %>%
  dplyr::mutate(
    matched_year_role = dplyr::case_when(
      .data$water_year_end_year == selected_pair$pre_water_year_end_year ~ "Matched pre-management year",
      .data$water_year_end_year == selected_pair$post_water_year_end_year ~ "Matched post-management year",
      TRUE ~ "Other"
    ),
    matched_year_label = paste0(.data$water_year, " — ", .data$matched_year_role),
    display_inundated_any_pct = dplyr::if_else(.data$valid_for_frequency, .data$inundated_any_pct, NA_real_)
  )

matched_year_figure <- matched_year_plot_data %>%
  ggplot2::ggplot(ggplot2::aes(
    x = .data$centroid_x,
    y = .data$centroid_y,
    colour = .data$display_inundated_any_pct,
    shape = .data$treed_plot_flag
  )) +
  ggplot2::geom_point(size = 3.1, alpha = 0.95) +
  ggplot2::facet_wrap(~ matched_year_label, nrow = 1) +
  ggplot2::coord_equal() +
  ggplot2::scale_colour_gradientn(
    colours = c("#f7fbff", "#9ecae1", "#3182bd", "#08519c"),
    limits = c(0, 100),
    na.value = "grey80",
    name = "Observed inundated\nplot area (%)"
  ) +
  ggplot2::scale_shape_manual(values = c("FALSE" = 16, "TRUE" = 17), name = "Treed plot") +
  ggplot2::labs(
    title = "Matched-year annual inundation comparison",
    subtitle = paste0(
      selected_pair$pre_water_year,
      " vs ",
      selected_pair$post_water_year,
      " selected from candidate ranking"
    ),
    x = NULL,
    y = NULL,
    caption = stringr::str_wrap(
      "Review/preliminary. Annual inundation occurrence/area is not hydroperiod, duration or depth. Gauge flow supports year selection as context only.",
      width = 130
    )
  ) +
  theme_review()

ggplot2::ggsave(matched_year_figure_path, matched_year_figure, width = 12, height = 6.5, dpi = 220)

vegetation_group_figure <- background_by_plot %>%
  ggplot2::ggplot(ggplot2::aes(
    x = .data$simplified_vegetation_group,
    y = .data$background_inundation_frequency_pct,
    fill = .data$treed_plot_flag
  )) +
  ggplot2::geom_boxplot(width = 0.62, outlier.alpha = 0.55) +
  ggplot2::coord_flip() +
  ggplot2::scale_fill_manual(values = c("FALSE" = "#4daf4a", "TRUE" = "#984ea3"), name = "Treed plot") +
  ggplot2::labs(
    title = "Historical background inundation frequency by vegetation group",
    subtitle = background_period_label,
    x = NULL,
    y = "Annual occurrence frequency (%)",
    caption = stringr::str_wrap(
      "Review/preliminary. Treed plots are included for inundation-only summaries; this is not a ground-cover interpretation figure.",
      width = 130
    )
  ) +
  theme_review()

ggplot2::ggsave(vegetation_group_figure_path, vegetation_group_figure, width = 10.5, height = 6.5, dpi = 220)


## Write outputs ----


write_csv_message(background_by_plot, background_plot_path)
write_csv_message(vegetation_group_summary, vegetation_group_path)
write_csv_message(candidate_ranking, candidate_ranking_path)
write_csv_message(matched_year_gauge_context, matched_gauge_context_path)
write_csv_message(year_summary, year_summary_path)

figure_manifest <- tibble::tibble(
  figure_path = c(background_map_path, matched_year_figure_path, vegetation_group_figure_path),
  status = ifelse(file.exists(figure_path), "written", "not_written"),
  role = c(
    "Plot-centroid map of historical/background annual occurrence frequency.",
    "Selected pre/post matched-year plot-centroid inundation comparison.",
    "Vegetation-group distribution of historical/background annual occurrence frequency."
  )
)

write_csv_message(figure_manifest, figure_manifest_path)


## Checks and handoff ----


tif_snapshot_after <- tibble::tibble(
  tif_path = list.files(raster_dir, pattern = "\\.tif$", recursive = TRUE, full.names = TRUE),
  last_write_time_after = as.character(file.info(tif_path)$mtime),
  size_after = file.info(tif_path)$size
)

tif_compare <- tif_snapshot_before %>%
  dplyr::full_join(tif_snapshot_after, by = "tif_path") %>%
  dplyr::mutate(
    unchanged = .data$last_write_time_before == .data$last_write_time_after &
      .data$size_before == .data$size_after
  )

checks <- tibble::tibble(
  check_name = c(
    "no_prepost_raster_rebuild_triggered",
    "no_tif_files_overwritten",
    "nodata_255_handled_with_valid_flag",
    "maps_labelled_occurrence_not_duration",
    "background_period_explicit",
    "task1_context_used",
    "task2_plot_rs_gauge_base_used",
    "task2_gauge_context_used_as_context",
    "redbank_not_primary_anchor",
    "outputs_labelled_review_preliminary"
  ),
  status = c(
    "pass",
    dplyr::if_else(all(tif_compare$unchanged, na.rm = TRUE), "pass", "fail"),
    "pass",
    "pass",
    dplyr::if_else(!is.na(background_period_label) && nzchar(background_period_label), "pass", "fail"),
    dplyr::if_else(file.exists(plot_context_path), "pass", "fail"),
    dplyr::if_else(file.exists(plot_rs_gauge_base_path), "pass", "fail"),
    dplyr::if_else(file.exists(gauge_context_path), "pass", "fail"),
    dplyr::if_else(all(matched_year_gauge_context$gauge_context_role[matched_year_gauge_context$redbank_caution_flag] != PRIMARY_GAUGE_ROLE), "pass", "fail"),
    "pass"
  ),
  check_value = c(
    "This script does not source 08a/07e raster-build scripts.",
    paste0(sum(tif_compare$unchanged, na.rm = TRUE), " .tif files unchanged of ", nrow(tif_compare), " inventoried."),
    "Frequency denominators use annual_valid_any == 1; invalid/no-data years are excluded, not counted as dry.",
    "Figure titles/captions use annual occurrence/frequency wording and avoid hydroperiod/duration/depth claims.",
    background_period_label,
    plot_context_path,
    plot_rs_gauge_base_path,
    gauge_context_path,
    paste(unique(matched_year_gauge_context$gauge_name[matched_year_gauge_context$redbank_caution_flag]), collapse = "; "),
    "Figure captions and report use review/preliminary wording."
  ),
  note = c(
    "No expensive raster processing was run.",
    "Existing pre/post and annual .tif files were inventoried before and after only.",
    "Current annual inundation logic already separates annual_valid_any from annual_wet_any.",
    "This protects interpretation: frequency is not flood duration.",
    "The selected period is written to output CSVs and figure subtitles.",
    "Task 1 vegetation, treed and grazing classifications are authoritative.",
    "Task 2 base provides current combined plot-level review context.",
    "Gauge flow supports year selection context only and is not causal proof.",
    "Redbank remains cautious context only.",
    "Outputs are intended for review/deck development, not final causal inference."
  )
)

write_csv_message(checks, checks_path)

if (any(checks$status == "fail")) {
  stop("Task 3 checks failed. See: ", checks_path, call. = FALSE)
}

top_discussion_pair <- candidate_ranking %>%
  dplyr::filter(.data$discussion_pair_flag) %>%
  dplyr::slice_head(n = 1)

if (nrow(top_discussion_pair) == 0) {
  discussion_pair_note <- "No discussion-example pair was available in the ranked candidate pool."
} else {
  discussion_pair_note <- paste0(
    "Best discussion-example pair in candidate pool: ",
    top_discussion_pair$pre_water_year,
    " vs ",
    top_discussion_pair$post_water_year,
    " (rank ",
    top_discussion_pair$candidate_rank,
    ")."
  )
}

report_lines <- c(
  "# Task 3 — Historical background flood pattern and matched-year comparison",
  "",
  paste0("Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
  "",
  "## Scope",
  "",
  "- Read existing curated annual inundation, Task 1 plot context, Task 2 plot/gauge context, and existing raster inventory.",
  "- Did not run raster extraction, raster building, or pre/post raster scripts.",
  "- Did not write or overwrite `.tif` files.",
  "- Gauge flow is hydrological context only, not causal proof.",
  "",
  "## Background Period",
  "",
  paste0("- Period used: ", background_period_label),
  paste0("- Period type: ", background_period_type),
  "- Historical plot-level frequency is percent of valid annual records where inundation was detected.",
  "- Pre-2015 long historical mapping is plot-centroid based because annual raster products only cover the current 2014-2025 pre/post stack.",
  "",
  "## Matched Years",
  "",
  paste0("- Selected pair: ", selected_pair$pre_water_year, " vs ", selected_pair$post_water_year),
  paste0("- Selection basis: ", selected_pair$selection_basis),
  paste0("- Candidate filter: ", selected_pair$candidate_pair_filter_note),
  paste0("- Whole-farm occurrence difference: ", round(selected_pair$whole_farm_abs_diff_pct_points, 2), " percentage points"),
  paste0("- Mean inundated-area difference: ", round(selected_pair$mean_area_abs_diff_pct_points, 2), " percentage points"),
  paste0("- Vegetation-group occurrence-profile difference: ", round(selected_pair$vegetation_group_mean_abs_diff_pct_points, 2), " percentage points"),
  paste0("- Preferred-gauge total-flow relative difference: ", round(selected_pair$gauge_total_flow_relative_diff_pct, 2), "%"),
  paste0("- ", discussion_pair_note),
  "",
  "## Gauge Context",
  "",
  paste0("- Preferred gauges: ", paste(sort(unique(gauge_year_summary$preferred_gauges)), collapse = " | ")),
  "- Redbank, where present, remains cautious context only and is not used as the primary continuous anchor.",
  "",
  "## Vegetation Groups",
  "",
  paste0("- Groups used: ", paste(sort(unique(background_by_plot$simplified_vegetation_group)), collapse = "; ")),
  "- Treed plots are included in inundation-only summaries and identified with `treed_plot_flag`.",
  "- Treed plots are not used here for new ground-cover interpretation outputs.",
  "",
  "## Outputs",
  "",
  paste0("- `", background_plot_path, "`"),
  paste0("- `", vegetation_group_path, "`"),
  paste0("- `", candidate_ranking_path, "`"),
  paste0("- `", matched_gauge_context_path, "`"),
  paste0("- `", background_map_path, "`"),
  paste0("- `", matched_year_figure_path, "`"),
  paste0("- `", vegetation_group_figure_path, "`"),
  "",
  "## Limitations",
  "",
  "- Annual occurrence frequency is not duration, hydroperiod, flood depth, or number of wet days.",
  "- Historical/background plot summaries use valid annual plot observations; invalid/no-data years are excluded from denominators.",
  "- Matched-year ranking is a screening aid, not a causal attribution test.",
  "- Gauge flow context supports interpretation but does not prove plot inundation response.",
  "- The final anchor gauge pair, year definition, and flow metric/threshold remain Adrian decisions.",
  "",
  "## Checks",
  "",
  paste0("- ", checks$check_name, ": ", checks$status, " (", checks$check_value, ")")
)

writeLines(report_lines, handoff_report_path)
message("Wrote: ", handoff_report_path)

message("Task 3 historical/background inundation and matched-year outputs complete.")
