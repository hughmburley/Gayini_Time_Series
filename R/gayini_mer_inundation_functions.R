## -----------------------------------------------------------------------------
## Gayini remote sensing workflow
## gayini_mer_inundation_functions.R
## -----------------------------------------------------------------------------


## Purpose:
## Add a compact Flow_MER-inspired plot-level inundation summary from the
## existing daily inundation extraction. This script does not read or write
## rasters; it consumes the current 06c daily extraction table.


## User settings ----


run_gayini_mer_inundation <- function(root_dir = Sys.getenv("GAYINI_ROOT", "D:/Github_repos/Gayini")) {
root_dir <- normalizePath(root_dir, winslash = "/", mustWork = TRUE)
MANAGEMENT_CHANGE_DATE <- as.Date("2019-07-01")
PRE_START_DATE <- as.Date("2013-07-01")
POST_END_DATE <- as.Date("2026-06-30")
WATER_YEAR_START_MONTH <- 7
ONLY_ADEQUATE_COVERAGE <- TRUE
DAILY_WET_RULE <- "strict_value_1"
SENSITIVITY_WET_RULE <- "value_1_plus_2"
MIN_WET_AREA_PCT_FOR_OBSERVED_WET <- 0
MAX_GAP_DAYS_IN_OBSERVED_SEQUENCE <- 45


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
processed_dir <- file.path(root_dir, "data_processed")
diagnostics_dir <- file.path(root_dir, "Output", "diagnostics", "06_MER_inundation")
historical_diagnostics_dir <- file.path(root_dir, "Output", "diagnostics", "05b_MER_inundation")
figure_dir <- file.path(root_dir, "Output", "figures", "06_MER_inundation")

dir.create(csv_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(processed_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(diagnostics_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)

daily_inundation_path <- gayini_find_first_existing(c(
  file.path(root_dir, "data_processed", "plot_daily_inundation_timeseries.csv"),
  file.path(root_dir, "Output", "csv", "06c_daily_inundation_full.csv")
))

plot_metadata_path <- gayini_find_first_existing(c(
  file.path(root_dir, "Output", "csv", "plot_rs_analysis_base.csv"),
  file.path(root_dir, "Output", "csv", "07f_pre_post_inundation_plot_summary_fixed.csv"),
  file.path(root_dir, "data_processed", "plot_pre_post_inundation_frequency_fixed.csv")
))

if (is.na(daily_inundation_path)) {
  stop("Missing required daily inundation input. Expected data_processed/plot_daily_inundation_timeseries.csv or Output/csv/06c_daily_inundation_full.csv.", call. = FALSE)
}

annual_dynamic_path <- file.path(csv_dir, "05b_MER_plot_inundation_dynamic_metrics.csv")
annual_dynamic_processed_path <- file.path(processed_dir, "plot_inundation_dynamic_metrics.csv")
monthly_seasonal_path <- file.path(csv_dir, "05b_MER_plot_inundation_monthly_seasonal_max.csv")

plot_date_support_path <- file.path(diagnostics_dir, "selected_plot_date_daily_support.csv")
row_count_by_plot_year_sensor_path <- file.path(diagnostics_dir, "row_counts_by_plot_water_year_sensor_source.csv")
unique_dates_by_year_path <- file.path(diagnostics_dir, "unique_observation_dates_by_water_year.csv")
duplicate_key_check_path <- file.path(diagnostics_dir, "duplicate_key_checks.csv")
missingness_check_path <- file.path(diagnostics_dir, "missingness_checks.csv")
value_range_check_path <- file.path(diagnostics_dir, "value_range_checks.csv")
metric_reproducibility_path <- file.path(diagnostics_dir, "metric_reproducibility_checks.csv")
sequence_reproducibility_path <- file.path(diagnostics_dir, "sequence_reproducibility_checks.csv")
support_metrics_path <- file.path(diagnostics_dir, "support_metrics_by_plot_water_year.csv")
prepost_mer_support_path <- file.path(diagnostics_dir, "prepost_mer_metric_support_caveats.csv")
mer_vs_annual_occurrence_path <- file.path(diagnostics_dir, "mer_vs_annual_occurrence_flags.csv")
common_period_comparison_path <- file.path(diagnostics_dir, "mer_vs_annual_occurrence_common_period.csv")
value_check_path <- file.path(diagnostics_dir, "dynamic_metric_value_checks.csv")
invalid_summary_path <- file.path(diagnostics_dir, "invalid_observation_summary_by_year.csv")
duplicate_log_path <- file.path(diagnostics_dir, "duplicate_daily_raster_resolution_log.csv")
observation_density_path <- file.path(diagnostics_dir, "observation_density_by_water_year.csv")
interpretation_lut_path <- file.path(diagnostics_dir, "dynamic_metric_interpretation_lookup.csv")
row_count_path <- file.path(diagnostics_dir, "06_MER_row_counts.csv")
run_status_path <- file.path(diagnostics_dir, "run_status_register.csv")

annual_max_figure_path <- file.path(figure_dir, "annual_max_inundated_area_by_plot_water_year.png")
prepost_figure_path <- file.path(figure_dir, "prepost_annual_max_inundated_area.png")
support_figure_path <- file.path(figure_dir, "observation_support_by_water_year_sensor.png")
ranked_prepost_change_figure_path <- file.path(figure_dir, "ranked_post_minus_pre_annual_max_inundated_area.png")
annual_occurrence_figure_path <- file.path(figure_dir, "mer_annual_max_vs_annual_occurrence.png")


## Helper functions ----


assign_mer_season <- function(date) {
  month <- as.integer(format(as.Date(date), "%m"))

  dplyr::case_when(
    month %in% c(12, 1, 2) ~ "summer",
    month %in% c(3, 4, 5) ~ "autumn",
    month %in% c(6, 7, 8) ~ "winter",
    month %in% c(9, 10, 11) ~ "spring",
    TRUE ~ NA_character_
  )
}


season_start_date <- function(date) {
  date <- as.Date(date)
  year <- as.integer(format(date, "%Y"))
  month <- as.integer(format(date, "%m"))
  start_year <- dplyr::if_else(month %in% c(1, 2), year - 1L, year)
  start_month <- dplyr::case_when(
    month %in% c(12, 1, 2) ~ 12L,
    month %in% c(3, 4, 5) ~ 3L,
    month %in% c(6, 7, 8) ~ 6L,
    month %in% c(9, 10, 11) ~ 9L,
    TRUE ~ NA_integer_
  )

  as.Date(sprintf("%04d-%02d-01", start_year, start_month))
}


coalesce_metadata <- function(df) {
  for (nm in c("treatment", "vegetation", "vegetation_adrian_group", "area_ha")) {
    plot_nm <- paste0(nm, "_plot")

    if (!nm %in% names(df)) {
      df[[nm]] <- NA
    }

    if (plot_nm %in% names(df)) {
      df[[nm]] <- dplyr::coalesce(df[[nm]], df[[plot_nm]])
      df[[plot_nm]] <- NULL
    }
  }

  df
}


safe_mean <- function(x) {
  out <- mean(x, na.rm = TRUE)
  if (is.nan(out)) NA_real_ else out
}


safe_max <- function(x) {
  out <- max(x, na.rm = TRUE)
  if (is.infinite(out)) NA_real_ else out
}


classify_observation_density <- function(n_valid_observations) {
  dplyr::case_when(
    is.na(n_valid_observations) ~ "missing_support",
    n_valid_observations <= 1 ~ "single_observation",
    n_valid_observations <= 3 ~ "very_low_density",
    n_valid_observations <= 8 ~ "moderate_density",
    TRUE ~ "high_density"
  )
}


sensor_mix_label <- function(x) {
  x <- sort(unique(stats::na.omit(x)))
  if (length(x) == 0L) {
    return(NA_character_)
  }

  paste(x, collapse = "; ")
}


summarise_observed_sequence <- function(df) {
  df <- df %>%
    dplyr::arrange(.data$date_midpoint) %>%
    dplyr::mutate(
      is_wet_observation = !is.na(.data$daily_inundated_pct) &
        .data$daily_inundated_pct > MIN_WET_AREA_PCT_FOR_OBSERVED_WET,
      gap_days = as.numeric(.data$date_midpoint - dplyr::lag(.data$date_midpoint)),
      new_observed_sequence = .data$is_wet_observation &
        (
          is.na(dplyr::lag(.data$is_wet_observation)) |
            !dplyr::lag(.data$is_wet_observation) |
            is.na(.data$gap_days) |
            .data$gap_days > MAX_GAP_DAYS_IN_OBSERVED_SEQUENCE
        ),
      observed_sequence_id = cumsum(dplyr::coalesce(.data$new_observed_sequence, FALSE))
    )

  if (!any(df$is_wet_observation, na.rm = TRUE)) {
    return(tibble::tibble(
      longest_observed_wet_sequence_days = 0,
      start_day_of_longest_observed_wet_sequence = NA_integer_,
      observed_sequence_start_date = as.Date(NA),
      observed_sequence_end_date = as.Date(NA),
      n_wet_observations_in_longest_sequence = 0L,
      max_inundated_pct_in_longest_sequence = NA_real_
    ))
  }

  wet_sequences <- df %>%
    dplyr::filter(.data$is_wet_observation) %>%
    dplyr::group_by(.data$observed_sequence_id) %>%
    dplyr::summarise(
      observed_sequence_start_date = min(.data$date_midpoint, na.rm = TRUE),
      observed_sequence_end_date = max(.data$date_midpoint, na.rm = TRUE),
      n_wet_observations_in_sequence = dplyr::n(),
      max_inundated_pct_in_sequence = max(.data$daily_inundated_pct, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    dplyr::mutate(
      longest_observed_wet_sequence_days = as.numeric(
        .data$observed_sequence_end_date - .data$observed_sequence_start_date
      ) + 1
    ) %>%
    dplyr::arrange(
      dplyr::desc(.data$longest_observed_wet_sequence_days),
      .data$observed_sequence_start_date
    )

  longest <- wet_sequences %>%
    dplyr::slice(1)

  water_year_start <- unique(df$water_year_start_date)
  if (length(water_year_start) != 1 || is.na(water_year_start)) {
    start_day <- NA_integer_
  } else {
    start_day <- as.integer(longest$observed_sequence_start_date - water_year_start) + 1L
  }

  tibble::tibble(
    longest_observed_wet_sequence_days = longest$longest_observed_wet_sequence_days,
    start_day_of_longest_observed_wet_sequence = start_day,
    observed_sequence_start_date = longest$observed_sequence_start_date,
    observed_sequence_end_date = longest$observed_sequence_end_date,
    n_wet_observations_in_longest_sequence = longest$n_wet_observations_in_sequence,
    max_inundated_pct_in_longest_sequence = longest$max_inundated_pct_in_sequence
  )
}


## Read and prepare inputs ----


message("Reading daily inundation table: ", daily_inundation_path)
daily_raw <- readr::read_csv(daily_inundation_path, show_col_types = FALSE) %>%
  gayini_standardise_plot_id(object_name = "daily inundation table")

if (!is.na(plot_metadata_path)) {
  message("Reading plot metadata table: ", plot_metadata_path)
  plot_metadata <- readr::read_csv(plot_metadata_path, show_col_types = FALSE) %>%
    gayini_standardise_plot_id(object_name = "plot metadata table") %>%
    gayini_recode_vegetation_groups() %>%
    dplyr::select(dplyr::any_of(c("plot_id", "treatment", "vegetation", "vegetation_adrian_group", "area_ha"))) %>%
    dplyr::distinct(.data$plot_id, .keep_all = TRUE)
} else {
  message("No plot metadata table found; MER outputs will retain metadata present in the daily table only.")
  plot_metadata <- tibble::tibble(plot_id = unique(daily_raw$plot_id))
}

daily_work <- daily_raw %>%
  dplyr::left_join(plot_metadata, by = "plot_id", suffix = c("", "_plot")) %>%
  coalesce_metadata() %>%
  dplyr::mutate(
    date_midpoint = as.Date(gayini_get_first_existing_column(
      .,
      c("date_midpoint", "date_start", "date_end")
    )),
    water_year = gayini_assign_water_year(
      .data$date_midpoint,
      water_year_start_month = WATER_YEAR_START_MONTH
    ),
    water_year_start_date = as.Date(paste0(substr(.data$water_year, 1, 4), "-", sprintf("%02d", WATER_YEAR_START_MONTH), "-01")),
    period = gayini_assign_period(
      .data$date_midpoint,
      management_change_date = MANAGEMENT_CHANGE_DATE,
      pre_start_date = PRE_START_DATE,
      post_end_date = POST_END_DATE
    ),
    month_start = as.Date(sprintf("%s-01", format(.data$date_midpoint, "%Y-%m"))),
    season = assign_mer_season(.data$date_midpoint),
    season_start = season_start_date(.data$date_midpoint),
    daily_inundated_pct = as.numeric(gayini_get_first_existing_column(
      .,
      c("daily_inundated_pct", "value_1_inundated_pct"),
      default = NA_real_
    )),
    value_1_inundated_pct = as.numeric(gayini_get_first_existing_column(., c("value_1_inundated_pct"), default = NA_real_)),
    value_2_ors_water_pct = as.numeric(gayini_get_first_existing_column(., c("value_2_ors_water_pct"), default = 0)),
    value_3_cloud_shadow_pct = as.numeric(gayini_get_first_existing_column(., c("value_3_cloud_shadow_pct"), default = 0)),
    explicit_nodata_area_pct = as.numeric(gayini_get_first_existing_column(., c("explicit_nodata_area_pct"), default = 0)),
    other_value_area_pct = as.numeric(gayini_get_first_existing_column(., c("other_value_area_pct"), default = 0)),
    valid_interpretation_pct = as.numeric(gayini_get_first_existing_column(., c("valid_interpretation_pct"), default = NA_real_)),
    daily_inundated_pct_value_1_plus_2 = .data$value_1_inundated_pct + .data$value_2_ors_water_pct,
    invalid_observation_pct = .data$value_3_cloud_shadow_pct + .data$explicit_nodata_area_pct + .data$other_value_area_pct,
    sensor_clean = dplyr::case_when(
      .data$sensor %in% c("s2", "s2_inferred_10m") ~ "s2",
      .data$sensor %in% c("l7", "l8", "l9") ~ as.character(.data$sensor),
      TRUE ~ "unknown"
    ),
    has_cloud3_name = as.logical(.data$has_cloud3_name),
    has_ors2_name = as.logical(.data$has_ors2_name)
  ) %>%
  gayini_recode_vegetation_groups() %>%
  dplyr::filter(!is.na(.data$date_midpoint), !is.na(.data$water_year))

daily_precoverage <- daily_work

if (ONLY_ADEQUATE_COVERAGE && "valid_coverage_status" %in% names(daily_work)) {
  daily_work <- daily_work %>%
    dplyr::filter(.data$valid_coverage_status == "adequate_coverage")
}


## Same-day duplicate handling ----


daily_raster_index <- daily_work %>%
  dplyr::distinct(
    .data$date_midpoint,
    .data$water_year,
    .data$period,
    .data$product,
    .data$sensor_clean,
    .data$file_name,
    .data$file_path,
    .data$has_cloud3_name,
    .data$has_ors2_name
  )

selected_raster_index <- daily_raster_index %>%
  dplyr::arrange(
    .data$date_midpoint,
    .data$sensor_clean,
    dplyr::desc(.data$has_cloud3_name),
    dplyr::desc(.data$has_ors2_name),
    .data$file_name
  ) %>%
  dplyr::group_by(.data$date_midpoint, .data$sensor_clean) %>%
  dplyr::mutate(
    duplicate_group_size = dplyr::n(),
    selected_for_mer_dynamic_metrics = dplyr::row_number() == 1L
  ) %>%
  dplyr::ungroup()

duplicate_log <- selected_raster_index %>%
  dplyr::filter(.data$duplicate_group_size > 1L) %>%
  dplyr::mutate(
    duplicate_resolution_rule = "same_date_same_sensor_keep_cloud3_then_ors2_then_filename",
    action = dplyr::if_else(.data$selected_for_mer_dynamic_metrics, "kept", "dropped")
  ) %>%
  dplyr::select(
    "date_midpoint",
    "water_year",
    "period",
    "product",
    "sensor_clean",
    "file_name",
    "file_path",
    "duplicate_group_size",
    "has_cloud3_name",
    "has_ors2_name",
    "selected_for_mer_dynamic_metrics",
    "action",
    "duplicate_resolution_rule"
  ) %>%
  dplyr::arrange(.data$date_midpoint, .data$sensor_clean, dplyr::desc(.data$selected_for_mer_dynamic_metrics), .data$file_name)

daily_selected <- daily_work %>%
  dplyr::inner_join(
    selected_raster_index %>%
      dplyr::filter(.data$selected_for_mer_dynamic_metrics) %>%
      dplyr::select("date_midpoint", "sensor_clean", "file_name"),
    by = c("date_midpoint", "sensor_clean", "file_name")
  )

plot_date_daily <- daily_selected %>%
  dplyr::group_by(
    .data$plot_id,
    .data$date_midpoint,
    .data$water_year,
    .data$water_year_start_date,
    .data$period,
    .data$month_start,
    .data$season,
    .data$season_start,
    .data$treatment,
    .data$vegetation,
    .data$vegetation_adrian_group,
    .data$area_ha
  ) %>%
  dplyr::summarise(
    daily_inundated_pct = max(.data$daily_inundated_pct, na.rm = TRUE),
    daily_inundated_pct_value_1_plus_2 = max(.data$daily_inundated_pct_value_1_plus_2, na.rm = TRUE),
    mean_invalid_observation_pct = mean(.data$invalid_observation_pct, na.rm = TRUE),
    mean_valid_interpretation_pct = mean(.data$valid_interpretation_pct, na.rm = TRUE),
    sensor_count = dplyr::n_distinct(.data$sensor_clean),
    sensors = paste(sort(unique(.data$sensor_clean)), collapse = "; "),
    source_products = sensor_mix_label(.data$product),
    .groups = "drop"
  ) %>%
  dplyr::mutate(
    daily_inundated_pct = dplyr::if_else(is.infinite(.data$daily_inundated_pct), NA_real_, .data$daily_inundated_pct),
    daily_inundated_pct_value_1_plus_2 = dplyr::if_else(is.infinite(.data$daily_inundated_pct_value_1_plus_2), NA_real_, .data$daily_inundated_pct_value_1_plus_2),
    mean_invalid_observation_pct = dplyr::if_else(is.nan(.data$mean_invalid_observation_pct), NA_real_, .data$mean_invalid_observation_pct),
    mean_valid_interpretation_pct = dplyr::if_else(is.nan(.data$mean_valid_interpretation_pct), NA_real_, .data$mean_valid_interpretation_pct),
    n_sensor_dates = .data$sensor_count,
    sensor_mix = .data$sensors
  )


## MER dynamic summaries ----


sequence_summary <- plot_date_daily %>%
  dplyr::group_by(.data$plot_id, .data$water_year) %>%
  dplyr::group_modify(~ summarise_observed_sequence(.x)) %>%
  dplyr::ungroup()

annual_dynamic <- plot_date_daily %>%
  dplyr::group_by(
    .data$plot_id,
    .data$water_year,
    .data$water_year_start_date,
    .data$period,
    .data$treatment,
    .data$vegetation,
    .data$vegetation_adrian_group,
    .data$area_ha
  ) %>%
  dplyr::summarise(
    n_valid_observations = dplyr::n(),
    n_wet_observations = sum(.data$daily_inundated_pct > MIN_WET_AREA_PCT_FOR_OBSERVED_WET, na.rm = TRUE),
    n_sensor_dates = sum(.data$n_sensor_dates, na.rm = TRUE),
    annual_max_inundated_area_pct = safe_max(.data$daily_inundated_pct),
    annual_mean_inundated_area_pct = safe_mean(.data$daily_inundated_pct),
    annual_max_inundated_area_pct_value_1_plus_2 = safe_max(.data$daily_inundated_pct_value_1_plus_2),
    mean_invalid_observation_pct = safe_mean(.data$mean_invalid_observation_pct),
    max_invalid_observation_pct = safe_max(.data$mean_invalid_observation_pct),
    mean_valid_interpretation_pct = safe_mean(.data$mean_valid_interpretation_pct),
    first_observation_date = min(.data$date_midpoint, na.rm = TRUE),
    last_observation_date = max(.data$date_midpoint, na.rm = TRUE),
    n_unique_observation_dates = dplyr::n_distinct(.data$date_midpoint),
    sensor_count = dplyr::n_distinct(.data$sensor_mix),
    sensor_mix = sensor_mix_label(unlist(strsplit(.data$sensor_mix, "; ", fixed = TRUE))),
    source_products = sensor_mix_label(unlist(strsplit(.data$source_products, "; ", fixed = TRUE))),
    .groups = "drop"
  ) %>%
  dplyr::left_join(sequence_summary, by = c("plot_id", "water_year")) %>%
  dplyr::mutate(
    observation_density_class = classify_observation_density(.data$n_valid_observations),
    daily_wet_rule = DAILY_WET_RULE,
    sensitivity_wet_rule = SENSITIVITY_WET_RULE,
    observed_sequence_gap_rule_days = MAX_GAP_DAYS_IN_OBSERVED_SEQUENCE,
    duration_interpretation = "observed_sequence_not_hydroperiod",
    start_date_longest_observed_wet_sequence = .data$observed_sequence_start_date,
    end_date_longest_observed_wet_sequence = .data$observed_sequence_end_date
  ) %>%
  dplyr::arrange(.data$plot_id, .data$water_year)

monthly_max <- plot_date_daily %>%
  dplyr::group_by(
    .data$plot_id,
    .data$month_start,
    .data$water_year,
    .data$period,
    .data$treatment,
    .data$vegetation,
    .data$vegetation_adrian_group
  ) %>%
  dplyr::summarise(
    temporal_unit = "month",
    period_start = min(.data$month_start, na.rm = TRUE),
    period_label = format(.data$month_start[[1]], "%Y-%m"),
    n_valid_observations = dplyr::n(),
    n_wet_observations = sum(.data$daily_inundated_pct > MIN_WET_AREA_PCT_FOR_OBSERVED_WET, na.rm = TRUE),
    n_sensor_dates = sum(.data$n_sensor_dates, na.rm = TRUE),
    monthly_max_inundated_pct = safe_max(.data$daily_inundated_pct),
    seasonal_max_inundated_pct = NA_real_,
    mean_invalid_observation_pct = safe_mean(.data$mean_invalid_observation_pct),
    sensor_count = dplyr::n_distinct(.data$sensors),
    sensor_mix = sensor_mix_label(unlist(strsplit(.data$sensor_mix, "; ", fixed = TRUE))),
    .groups = "drop"
  )

seasonal_max <- plot_date_daily %>%
  dplyr::group_by(
    .data$plot_id,
    .data$season_start,
    .data$season,
    .data$water_year,
    .data$period,
    .data$treatment,
    .data$vegetation,
    .data$vegetation_adrian_group
  ) %>%
  dplyr::summarise(
    temporal_unit = "season",
    period_start = min(.data$season_start, na.rm = TRUE),
    period_label = paste0(.data$season[[1]], "_", format(.data$season_start[[1]], "%Y")),
    n_valid_observations = dplyr::n(),
    n_wet_observations = sum(.data$daily_inundated_pct > MIN_WET_AREA_PCT_FOR_OBSERVED_WET, na.rm = TRUE),
    n_sensor_dates = sum(.data$n_sensor_dates, na.rm = TRUE),
    monthly_max_inundated_pct = NA_real_,
    seasonal_max_inundated_pct = safe_max(.data$daily_inundated_pct),
    mean_invalid_observation_pct = safe_mean(.data$mean_invalid_observation_pct),
    sensor_count = dplyr::n_distinct(.data$sensors),
    sensor_mix = sensor_mix_label(unlist(strsplit(.data$sensor_mix, "; ", fixed = TRUE))),
    .groups = "drop"
  )

monthly_seasonal <- dplyr::bind_rows(monthly_max, seasonal_max) %>%
  dplyr::mutate(
    observation_density_class = classify_observation_density(.data$n_valid_observations),
    daily_wet_rule = DAILY_WET_RULE,
    duration_interpretation = "extent_maximum_not_duration"
  ) %>%
  dplyr::arrange(.data$plot_id, .data$temporal_unit, .data$period_start)


## Diagnostics ----


value_checks <- daily_work %>%
  dplyr::summarise(
    n_rows = dplyr::n(),
    min_observed_value = min(.data$observed_min_value, na.rm = TRUE),
    max_observed_value = max(.data$observed_max_value, na.rm = TRUE),
    rows_with_value_1_wet = sum(.data$value_1_inundated_pct > 0, na.rm = TRUE),
    rows_with_value_2_ors = sum(.data$value_2_ors_water_pct > 0, na.rm = TRUE),
    rows_with_value_3_cloud_shadow = sum(.data$value_3_cloud_shadow_pct > 0, na.rm = TRUE),
    rows_with_explicit_nodata = sum(.data$explicit_nodata_area_pct > 0, na.rm = TRUE),
    max_value_2_ors_water_pct = max(.data$value_2_ors_water_pct, na.rm = TRUE),
    max_value_3_cloud_shadow_pct = max(.data$value_3_cloud_shadow_pct, na.rm = TRUE),
    max_explicit_nodata_area_pct = max(.data$explicit_nodata_area_pct, na.rm = TRUE),
    primary_wet_rule = DAILY_WET_RULE,
    sensitivity_wet_rule = SENSITIVITY_WET_RULE,
    value_3_handling = "invalid_cloud_shadow",
    explicit_nodata_handling = "invalid"
  )

invalid_summary <- plot_date_daily %>%
  dplyr::group_by(.data$water_year, .data$period) %>%
  dplyr::summarise(
    n_plot_date_rows = dplyr::n(),
    n_plots = dplyr::n_distinct(.data$plot_id),
    mean_invalid_observation_pct = safe_mean(.data$mean_invalid_observation_pct),
    max_invalid_observation_pct = safe_max(.data$mean_invalid_observation_pct),
    mean_valid_interpretation_pct = safe_mean(.data$mean_valid_interpretation_pct),
    .groups = "drop"
  ) %>%
  dplyr::arrange(.data$water_year)

observation_density <- selected_raster_index %>%
  dplyr::filter(.data$selected_for_mer_dynamic_metrics) %>%
  dplyr::group_by(.data$water_year, .data$period) %>%
  dplyr::summarise(
    n_rasters = dplyr::n(),
    n_unique_dates = dplyr::n_distinct(.data$date_midpoint),
    n_l7_rasters = sum(.data$sensor_clean == "l7", na.rm = TRUE),
    n_l8_rasters = sum(.data$sensor_clean == "l8", na.rm = TRUE),
    n_l9_rasters = sum(.data$sensor_clean == "l9", na.rm = TRUE),
    n_s2_rasters = sum(.data$sensor_clean == "s2", na.rm = TRUE),
    n_unknown_rasters = sum(.data$sensor_clean == "unknown", na.rm = TRUE),
    n_cloud3_named_rasters = sum(.data$has_cloud3_name, na.rm = TRUE),
    first_observation_date = min(.data$date_midpoint, na.rm = TRUE),
    last_observation_date = max(.data$date_midpoint, na.rm = TRUE),
    sensors = paste(sort(unique(.data$sensor_clean)), collapse = "; "),
    .groups = "drop"
  ) %>%
  dplyr::mutate(
    observation_density_class = dplyr::case_when(
      .data$n_unique_dates <= 1 ~ "single_observation",
      .data$n_unique_dates <= 3 ~ "very_low_density",
      .data$n_unique_dates <= 8 ~ "moderate_density",
      TRUE ~ "high_density"
    )
  ) %>%
  dplyr::arrange(.data$water_year)

row_counts_by_plot_year_sensor_source <- daily_selected %>%
  dplyr::group_by(.data$plot_id, .data$water_year, .data$sensor_clean, .data$product) %>%
  dplyr::summarise(
    n_rows = dplyr::n(),
    n_unique_observation_dates = dplyr::n_distinct(.data$date_midpoint),
    n_wet_rows = sum(.data$daily_inundated_pct > MIN_WET_AREA_PCT_FOR_OBSERVED_WET, na.rm = TRUE),
    n_valid_rows = sum(!is.na(.data$daily_inundated_pct)),
    .groups = "drop"
  ) %>%
  dplyr::arrange(.data$plot_id, .data$water_year, .data$sensor_clean, .data$product)

unique_dates_by_year <- selected_raster_index %>%
  dplyr::filter(.data$selected_for_mer_dynamic_metrics) %>%
  dplyr::group_by(.data$water_year, .data$period) %>%
  dplyr::summarise(
    n_unique_observation_dates = dplyr::n_distinct(.data$date_midpoint),
    n_sensor_dates = dplyr::n(),
    first_observation_date = min(.data$date_midpoint, na.rm = TRUE),
    last_observation_date = max(.data$date_midpoint, na.rm = TRUE),
    sensor_mix = sensor_mix_label(.data$sensor_clean),
    .groups = "drop"
  ) %>%
  dplyr::arrange(.data$water_year)

duplicate_key_checks <- tibble::tibble(
  check_name = c(
    "daily_selected_plot_date_sensor_file",
    "plot_date_daily_plot_date",
    "annual_dynamic_plot_water_year",
    "monthly_seasonal_plot_water_year_temporal_unit_period"
  ),
  duplicate_rows = c(
    daily_selected %>%
      dplyr::count(.data$plot_id, .data$date_midpoint, .data$sensor_clean, .data$file_name) %>%
      dplyr::filter(.data$n > 1L) %>%
      nrow(),
    plot_date_daily %>%
      dplyr::count(.data$plot_id, .data$date_midpoint) %>%
      dplyr::filter(.data$n > 1L) %>%
      nrow(),
    annual_dynamic %>%
      dplyr::count(.data$plot_id, .data$water_year) %>%
      dplyr::filter(.data$n > 1L) %>%
      nrow(),
    monthly_seasonal %>%
      dplyr::count(.data$plot_id, .data$water_year, .data$temporal_unit, .data$period_start) %>%
      dplyr::filter(.data$n > 1L) %>%
      nrow()
  ),
  status = dplyr::if_else(.data$duplicate_rows == 0L, "pass", "fail")
)

missingness_checks <- daily_precoverage %>%
  dplyr::group_by(.data$water_year, .data$period, .data$valid_coverage_status) %>%
  dplyr::summarise(
    n_rows = dplyr::n(),
    n_missing_daily_inundated_pct = sum(is.na(.data$daily_inundated_pct)),
    n_rows_with_cloud_shadow = sum(.data$value_3_cloud_shadow_pct > 0, na.rm = TRUE),
    n_rows_with_explicit_nodata = sum(.data$explicit_nodata_area_pct > 0, na.rm = TRUE),
    mean_invalid_observation_pct = safe_mean(.data$invalid_observation_pct),
    mean_valid_interpretation_pct = safe_mean(.data$valid_interpretation_pct),
    .groups = "drop"
  ) %>%
  dplyr::arrange(.data$water_year, .data$period, .data$valid_coverage_status)

value_range_checks <- plot_date_daily %>%
  dplyr::summarise(
    n_plot_date_rows = dplyr::n(),
    n_daily_pct_below_0 = sum(.data$daily_inundated_pct < 0, na.rm = TRUE),
    n_daily_pct_above_100 = sum(.data$daily_inundated_pct > 100, na.rm = TRUE),
    n_value_1_plus_2_above_100 = sum(.data$daily_inundated_pct_value_1_plus_2 > 100, na.rm = TRUE),
    n_invalid_pct_below_0 = sum(.data$mean_invalid_observation_pct < 0, na.rm = TRUE),
    n_invalid_pct_above_100 = sum(.data$mean_invalid_observation_pct > 100, na.rm = TRUE),
    min_daily_inundated_pct = min(.data$daily_inundated_pct, na.rm = TRUE),
    max_daily_inundated_pct = max(.data$daily_inundated_pct, na.rm = TRUE),
    status = dplyr::if_else(
      .data$n_daily_pct_below_0 == 0L &
        .data$n_daily_pct_above_100 == 0L &
        .data$n_value_1_plus_2_above_100 == 0L &
        .data$n_invalid_pct_below_0 == 0L &
        .data$n_invalid_pct_above_100 == 0L,
      "pass",
      "fail"
    )
  )

annual_recalc <- plot_date_daily %>%
  dplyr::group_by(.data$plot_id, .data$water_year) %>%
  dplyr::summarise(recomputed_annual_max_inundated_area_pct = safe_max(.data$daily_inundated_pct), .groups = "drop")

monthly_recalc <- plot_date_daily %>%
  dplyr::group_by(.data$plot_id, .data$month_start) %>%
  dplyr::summarise(recomputed_monthly_max_inundated_pct = safe_max(.data$daily_inundated_pct), .groups = "drop")

seasonal_recalc <- plot_date_daily %>%
  dplyr::group_by(.data$plot_id, .data$water_year, .data$season_start) %>%
  dplyr::summarise(recomputed_seasonal_max_inundated_pct = safe_max(.data$daily_inundated_pct), .groups = "drop")

metric_reproducibility_checks <- dplyr::bind_rows(
  annual_dynamic %>%
    dplyr::left_join(annual_recalc, by = c("plot_id", "water_year")) %>%
    dplyr::transmute(
      check_name = "annual_max_equals_selected_daily_max",
      plot_id = .data$plot_id,
      period_start = as.Date(NA),
      water_year = .data$water_year,
      reported_value = .data$annual_max_inundated_area_pct,
      recomputed_value = .data$recomputed_annual_max_inundated_area_pct
    ),
  monthly_seasonal %>%
    dplyr::filter(.data$temporal_unit == "month") %>%
    dplyr::left_join(monthly_recalc, by = c("plot_id", "period_start" = "month_start")) %>%
    dplyr::transmute(
      check_name = "monthly_max_equals_selected_daily_max",
      plot_id = .data$plot_id,
      period_start = .data$period_start,
      water_year = .data$water_year,
      reported_value = .data$monthly_max_inundated_pct,
      recomputed_value = .data$recomputed_monthly_max_inundated_pct
    ),
  monthly_seasonal %>%
    dplyr::filter(.data$temporal_unit == "season") %>%
    dplyr::left_join(seasonal_recalc, by = c("plot_id", "water_year", "period_start" = "season_start")) %>%
    dplyr::transmute(
      check_name = "seasonal_max_equals_selected_daily_max",
      plot_id = .data$plot_id,
      period_start = .data$period_start,
      water_year = .data$water_year,
      reported_value = .data$seasonal_max_inundated_pct,
      recomputed_value = .data$recomputed_seasonal_max_inundated_pct
    )
) %>%
  dplyr::mutate(
    absolute_difference = abs(.data$reported_value - .data$recomputed_value),
    status = dplyr::case_when(
      is.na(.data$reported_value) & is.na(.data$recomputed_value) ~ "pass",
      is.na(.data$absolute_difference) ~ "fail",
      .data$absolute_difference <= 1e-9 ~ "pass",
      TRUE ~ "fail"
    )
  ) %>%
  dplyr::arrange(.data$check_name, .data$plot_id, .data$water_year, .data$period_start)

sequence_recheck <- plot_date_daily %>%
  dplyr::group_by(.data$plot_id, .data$water_year) %>%
  dplyr::group_modify(~ summarise_observed_sequence(.x)) %>%
  dplyr::ungroup()

sequence_reproducibility_checks <- annual_dynamic %>%
  dplyr::select(
    "plot_id",
    "water_year",
    "longest_observed_wet_sequence_days",
    "start_date_longest_observed_wet_sequence"
  ) %>%
  dplyr::left_join(
    sequence_recheck %>%
      dplyr::select(
        "plot_id",
        "water_year",
        recomputed_longest_observed_wet_sequence_days = "longest_observed_wet_sequence_days",
        recomputed_start_date_longest_observed_wet_sequence = "observed_sequence_start_date"
      ),
    by = c("plot_id", "water_year")
  ) %>%
  dplyr::mutate(
    status = dplyr::if_else(
      .data$longest_observed_wet_sequence_days == .data$recomputed_longest_observed_wet_sequence_days &
        (
          is.na(.data$start_date_longest_observed_wet_sequence) &
            is.na(.data$recomputed_start_date_longest_observed_wet_sequence) |
            .data$start_date_longest_observed_wet_sequence == .data$recomputed_start_date_longest_observed_wet_sequence
        ),
      "pass",
      "fail"
    )
  )

support_metrics_by_plot_water_year <- annual_dynamic %>%
  dplyr::select(
    "plot_id",
    "water_year",
    "period",
    "n_valid_observations",
    "n_wet_observations",
    "n_sensor_dates",
    "n_unique_observation_dates",
    "sensor_mix",
    "source_products",
    "observation_density_class",
    "mean_invalid_observation_pct",
    "mean_valid_interpretation_pct"
  ) %>%
  dplyr::arrange(.data$plot_id, .data$water_year)

prepost_mer_metric_support <- annual_dynamic %>%
  dplyr::filter(.data$period %in% c("pre_conservation", "post_conservation")) %>%
  dplyr::group_by(.data$plot_id, .data$period) %>%
  dplyr::summarise(
    n_water_years = dplyr::n(),
    mean_annual_max_inundated_area_pct = safe_mean(.data$annual_max_inundated_area_pct),
    max_annual_max_inundated_area_pct = safe_max(.data$annual_max_inundated_area_pct),
    mean_longest_observed_wet_sequence_days = safe_mean(.data$longest_observed_wet_sequence_days),
    mean_valid_observations = safe_mean(.data$n_valid_observations),
    min_valid_observations = min(.data$n_valid_observations, na.rm = TRUE),
    low_support_years = sum(.data$observation_density_class %in% c("single_observation", "very_low_density"), na.rm = TRUE),
    sensor_mix = sensor_mix_label(unlist(strsplit(.data$sensor_mix, "; ", fixed = TRUE))),
    .groups = "drop"
  ) %>%
  dplyr::mutate(
    support_caveat = dplyr::case_when(
      .data$n_water_years <= 1L ~ "only_one_water_year_in_period",
      .data$low_support_years > 0L ~ "contains_low_observation_support_years",
      TRUE ~ "support_reasonable_for_observed_metric"
    )
  ) %>%
  dplyr::arrange(.data$plot_id, .data$period)

annual_occurrence_context_path <- gayini_find_first_existing(c(
  file.path(root_dir, "Output", "csv", "plot_rs_analysis_base.csv"),
  file.path(root_dir, "Output", "csv", "07f_pre_post_inundation_plot_summary_fixed.csv"),
  file.path(root_dir, "data_processed", "plot_pre_post_inundation_frequency_fixed.csv")
))

if (!is.na(annual_occurrence_context_path)) {
  annual_occurrence_context <- readr::read_csv(annual_occurrence_context_path, show_col_types = FALSE) %>%
    gayini_standardise_plot_id(object_name = "annual occurrence context table") %>%
    dplyr::select(dplyr::any_of(c(
      "plot_id",
      "pre_conservation_inundation_frequency_pct",
      "post_conservation_inundation_frequency_pct",
      "post_minus_pre_inundation_frequency_pct_points"
    ))) %>%
    dplyr::distinct(.data$plot_id, .keep_all = TRUE)
} else {
  annual_occurrence_context <- tibble::tibble(plot_id = unique(annual_dynamic$plot_id))
}

mer_prepost_wide <- prepost_mer_metric_support %>%
  dplyr::select(
    "plot_id",
    "period",
    "n_water_years",
    "mean_annual_max_inundated_area_pct",
    "max_annual_max_inundated_area_pct",
    "mean_longest_observed_wet_sequence_days",
    "mean_valid_observations",
    "low_support_years",
    "support_caveat"
  ) %>%
  tidyr::pivot_wider(
    names_from = "period",
    values_from = c(
      "n_water_years",
      "mean_annual_max_inundated_area_pct",
      "max_annual_max_inundated_area_pct",
      "mean_longest_observed_wet_sequence_days",
      "mean_valid_observations",
      "low_support_years",
      "support_caveat"
    )
  )

mer_vs_annual_occurrence_flags <- annual_occurrence_context %>%
  dplyr::left_join(mer_prepost_wide, by = "plot_id") %>%
  dplyr::mutate(
    mer_post_minus_pre_mean_annual_max_pct = .data$mean_annual_max_inundated_area_pct_post_conservation -
      .data$mean_annual_max_inundated_area_pct_pre_conservation,
    mer_post_minus_pre_max_annual_max_pct = .data$max_annual_max_inundated_area_pct_post_conservation -
      .data$max_annual_max_inundated_area_pct_pre_conservation,
    occurrence_direction = dplyr::case_when(
      is.na(.data$post_minus_pre_inundation_frequency_pct_points) ~ "missing_annual_occurrence",
      .data$post_minus_pre_inundation_frequency_pct_points > 0 ~ "higher_post",
      .data$post_minus_pre_inundation_frequency_pct_points < 0 ~ "lower_post",
      TRUE ~ "no_change"
    ),
    mer_direction = dplyr::case_when(
      is.na(.data$mer_post_minus_pre_mean_annual_max_pct) ~ "missing_mer",
      .data$mer_post_minus_pre_mean_annual_max_pct > 0 ~ "higher_post",
      .data$mer_post_minus_pre_mean_annual_max_pct < 0 ~ "lower_post",
      TRUE ~ "no_change"
    ),
    support_flag = dplyr::case_when(
      is.na(.data$mean_valid_observations_pre_conservation) | is.na(.data$mean_valid_observations_post_conservation) ~ "missing_support",
      .data$low_support_years_pre_conservation > 0 | .data$low_support_years_post_conservation > 0 ~ "low_support_caveat",
      TRUE ~ "support_ok"
    ),
    comparison_flag = dplyr::case_when(
      .data$occurrence_direction == "missing_annual_occurrence" | .data$mer_direction == "missing_mer" ~ "missing_comparison",
      .data$support_flag != "support_ok" ~ "interpret_with_observation_support_caveat",
      .data$occurrence_direction == .data$mer_direction ~ "directions_agree",
      .data$occurrence_direction == "no_change" | .data$mer_direction == "no_change" ~ "one_metric_near_no_change",
      TRUE ~ "directions_disagree_review"
    )
  ) %>%
  dplyr::arrange(.data$comparison_flag, .data$plot_id)

annual_occurrence_timeseries_path <- gayini_find_first_existing(c(
  file.path(root_dir, "Output", "csv", "curated_annual_inundation_timeseries.csv"),
  file.path(root_dir, "data_processed", "plot_landsat_inundation_timeseries.csv"),
  file.path(root_dir, "Output", "csv", "05c_landsat_inundation_full.csv")
))

if (!is.na(annual_occurrence_timeseries_path)) {
  annual_occurrence_timeseries <- readr::read_csv(annual_occurrence_timeseries_path, show_col_types = FALSE) %>%
    gayini_standardise_plot_id(object_name = "annual occurrence time series") %>%
    dplyr::mutate(
      water_year = as.character(.data$water_year),
      annual_occurrence_pct = as.numeric(gayini_get_first_existing_column(
        .,
        c("annual_inundated_any_pct", "inundated_any_pct"),
        default = NA_real_
      ))
    ) %>%
    dplyr::select("plot_id", "water_year", "annual_occurrence_pct") %>%
    dplyr::group_by(.data$plot_id, .data$water_year) %>%
    dplyr::summarise(
      annual_occurrence_pct = mean(.data$annual_occurrence_pct, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    dplyr::mutate(
      annual_occurrence_pct = dplyr::if_else(is.nan(.data$annual_occurrence_pct), NA_real_, .data$annual_occurrence_pct)
    )

  mer_vs_annual_occurrence_common_period <- annual_dynamic %>%
    dplyr::select(
      "plot_id",
      "water_year",
      "period",
      "annual_max_inundated_area_pct",
      "n_valid_observations",
      "n_wet_observations",
      "n_sensor_dates",
      "sensor_mix",
      "observation_density_class"
    ) %>%
    dplyr::inner_join(annual_occurrence_timeseries, by = c("plot_id", "water_year")) %>%
    dplyr::mutate(
      common_period_check = "same_plot_water_year_mer_daily_vs_annual_occurrence",
      comparison_caveat = "metrics_have_different_meaning_extent_maximum_vs_annual_occurrence"
    ) %>%
    dplyr::arrange(.data$plot_id, .data$water_year)
} else {
  mer_vs_annual_occurrence_common_period <- tibble::tibble(
    status = "annual_occurrence_timeseries_missing",
    expected_inputs = "Output/csv/curated_annual_inundation_timeseries.csv; data_processed/plot_landsat_inundation_timeseries.csv; Output/csv/05c_landsat_inundation_full.csv"
  )
}

interpretation_lut <- tibble::tribble(
  ~variable_name, ~label, ~units, ~definition, ~caution,
  "annual_max_inundated_area_pct", "Annual maximum inundated plot area", "percent", "Maximum daily strict value-1 inundated area percentage observed for a plot in a water year.", "Annual maximum extent is observation-density dependent and is not duration.",
  "annual_max_inundated_area_pct_value_1_plus_2", "Annual maximum inundated plot area sensitivity", "percent", "Maximum daily area percentage using value 1 plus value 2 as wet.", "Sensitivity only; keep separate from the primary strict value-1 metric.",
  "monthly_max_inundated_pct", "Monthly maximum inundated plot area", "percent", "Maximum strict value-1 inundated area percentage observed for a plot in a calendar month.", "Use with observation-density support.",
  "seasonal_max_inundated_pct", "Seasonal maximum inundated plot area", "percent", "Maximum strict value-1 inundated area percentage observed for a plot in a meteorological season.", "Use with observation-density support.",
  "longest_observed_wet_sequence_days", "Longest observed wet sequence", "days", "Longest run of wet observations where gaps between wet observations do not exceed the configured gap rule.", "Observed sequence only; not hydroperiod or proof of continuous inundation.",
  "start_day_of_longest_observed_wet_sequence", "Start day of longest observed wet sequence", "day of water year", "Day number from water-year start for the longest observed wet sequence.", "Depends on satellite observation timing.",
  "n_valid_observations", "Valid daily observations", "count", "Number of selected daily observations available after same-date duplicate handling.", "Observation density affects detectability of short wet events.",
  "n_wet_observations", "Wet daily observations", "count", "Number of selected daily observations with strict value-1 inundated area greater than the wet threshold.", "Count of observed wet detections, not number of wet days.",
  "observation_density_class", "Observation density class", NA_character_, "Simple support class based on number of selected daily observations.", "Use as interpretation support, not as an ecological response metric."
)


## QA/review figures ----


ggplot2::ggsave(
  annual_max_figure_path,
  plot = annual_dynamic %>%
    dplyr::mutate(plot_id = factor(.data$plot_id)) %>%
    ggplot2::ggplot(ggplot2::aes(x = .data$water_year, y = .data$plot_id, fill = .data$annual_max_inundated_area_pct)) +
    ggplot2::geom_tile() +
    ggplot2::scale_fill_viridis_c(option = "C", na.value = "grey90") +
    ggplot2::labs(
      x = "Water year",
      y = "Plot",
      fill = "Annual max inundated area (%)",
      title = "MER observed annual maximum inundated area",
      subtitle = "Observed extent maximum from selected valid daily observations; not hydroperiod"
    ) +
    ggplot2::theme_minimal(base_size = 10) +
    ggplot2::theme(axis.text.y = ggplot2::element_text(size = 5)),
  width = 10,
  height = 8,
  dpi = 180
)

ggplot2::ggsave(
  prepost_figure_path,
  plot = annual_dynamic %>%
    dplyr::filter(.data$period %in% c("pre_conservation", "post_conservation")) %>%
    ggplot2::ggplot(ggplot2::aes(x = .data$period, y = .data$annual_max_inundated_area_pct, fill = .data$period)) +
    ggplot2::geom_boxplot(outlier.alpha = 0.35) +
    ggplot2::geom_jitter(width = 0.12, alpha = 0.25, size = 0.8) +
    ggplot2::labs(
      x = NULL,
      y = "Annual max inundated area (%)",
      title = "Pre/post comparison of MER observed annual maxima",
      subtitle = "Interpret with observation-density support caveats"
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(legend.position = "none"),
  width = 7,
  height = 5,
  dpi = 180
)

support_by_sensor <- selected_raster_index %>%
  dplyr::filter(.data$selected_for_mer_dynamic_metrics) %>%
  dplyr::count(.data$water_year, .data$sensor_clean, name = "n_sensor_dates")

ggplot2::ggsave(
  support_figure_path,
  plot = support_by_sensor %>%
    ggplot2::ggplot(ggplot2::aes(x = .data$water_year, y = .data$n_sensor_dates, fill = .data$sensor_clean)) +
    ggplot2::geom_col() +
    ggplot2::labs(
      x = "Water year",
      y = "Selected sensor-date count",
      fill = "Sensor",
      title = "MER observation support by water year and sensor"
    ) +
    ggplot2::theme_minimal(base_size = 11),
  width = 9,
  height = 5,
  dpi = 180
)

ranked_mer_change <- mer_vs_annual_occurrence_flags %>%
  dplyr::filter(!is.na(.data$mer_post_minus_pre_mean_annual_max_pct)) %>%
  dplyr::arrange(.data$mer_post_minus_pre_mean_annual_max_pct) %>%
  dplyr::mutate(plot_rank = dplyr::row_number())

ggplot2::ggsave(
  ranked_prepost_change_figure_path,
  plot = ranked_mer_change %>%
    ggplot2::ggplot(ggplot2::aes(
      x = .data$plot_rank,
      y = .data$mer_post_minus_pre_mean_annual_max_pct,
      colour = .data$comparison_flag
    )) +
    ggplot2::geom_hline(yintercept = 0, colour = "grey65") +
    ggplot2::geom_point(size = 2, alpha = 0.85) +
    ggplot2::labs(
      x = "Plot rank",
      y = "Post minus pre MER mean annual max area (%)",
      colour = "Annual occurrence comparison",
      title = "Ranked post-minus-pre MER observed annual maximum change",
      subtitle = "Remote-sensing derived extent metric; review disagreement flags before deck use"
    ) +
    ggplot2::theme_minimal(base_size = 11),
  width = 8,
  height = 5,
  dpi = 180
)

ggplot2::ggsave(
  annual_occurrence_figure_path,
  plot = mer_vs_annual_occurrence_flags %>%
    ggplot2::ggplot(ggplot2::aes(
      x = .data$post_minus_pre_inundation_frequency_pct_points,
      y = .data$mer_post_minus_pre_mean_annual_max_pct,
      colour = .data$comparison_flag
    )) +
    ggplot2::geom_hline(yintercept = 0, colour = "grey65") +
    ggplot2::geom_vline(xintercept = 0, colour = "grey65") +
    ggplot2::geom_point(alpha = 0.75, size = 2) +
    ggplot2::labs(
      x = "Post minus pre annual occurrence frequency (percentage points)",
      y = "Post minus pre MER mean annual max area (%)",
      colour = "Flag",
      title = "MER observed extent change versus annual occurrence change",
      subtitle = "Disagreements and low-support years should be manually reviewed"
    ) +
    ggplot2::theme_minimal(base_size = 11),
  width = 8,
  height = 6,
  dpi = 180
)

figure_manifest <- tibble::tibble(
  figure_path = c(
    annual_max_figure_path,
    prepost_figure_path,
    support_figure_path,
    ranked_prepost_change_figure_path,
    annual_occurrence_figure_path
  ),
  figure_type = c(
    "annual_max_heatmap",
    "prepost_boxplot",
    "support_by_sensor",
    "ranked_post_minus_pre_change",
    "mer_vs_annual_occurrence"
  ),
  status = ifelse(file.exists(c(
    annual_max_figure_path,
    prepost_figure_path,
    support_figure_path,
    ranked_prepost_change_figure_path,
    annual_occurrence_figure_path
  )), "written", "not_written"),
  interpretation_caveat = c(
    "Observed extent maximum only; not hydroperiod.",
    "Pre/post comparison depends on observation density.",
    "Sensor-date counts support interpretation.",
    "Ranked post-minus-pre observed extent change; not ecological watering.",
    "Agreement/disagreement is diagnostic, not causal inference."
  )
)


## Write outputs ----


readr::write_csv(annual_dynamic, annual_dynamic_path)
readr::write_csv(annual_dynamic, annual_dynamic_processed_path)
readr::write_csv(monthly_seasonal, monthly_seasonal_path)
readr::write_csv(plot_date_daily, plot_date_support_path)
readr::write_csv(row_counts_by_plot_year_sensor_source, row_count_by_plot_year_sensor_path)
readr::write_csv(unique_dates_by_year, unique_dates_by_year_path)
readr::write_csv(duplicate_key_checks, duplicate_key_check_path)
readr::write_csv(missingness_checks, missingness_check_path)
readr::write_csv(value_range_checks, value_range_check_path)
readr::write_csv(metric_reproducibility_checks, metric_reproducibility_path)
readr::write_csv(sequence_reproducibility_checks, sequence_reproducibility_path)
readr::write_csv(support_metrics_by_plot_water_year, support_metrics_path)
readr::write_csv(prepost_mer_metric_support, prepost_mer_support_path)
readr::write_csv(mer_vs_annual_occurrence_flags, mer_vs_annual_occurrence_path)
readr::write_csv(mer_vs_annual_occurrence_common_period, common_period_comparison_path)
readr::write_csv(figure_manifest, file.path(diagnostics_dir, "figure_manifest.csv"))
readr::write_csv(value_checks, value_check_path)
readr::write_csv(invalid_summary, invalid_summary_path)
readr::write_csv(duplicate_log, duplicate_log_path)
readr::write_csv(observation_density, observation_density_path)
readr::write_csv(interpretation_lut, interpretation_lut_path)

gayini_write_row_count_diagnostics(
  tables = list(
    input_daily_inundation = daily_raw,
    selected_plot_date_daily = plot_date_daily,
    annual_dynamic = annual_dynamic,
    monthly_seasonal = monthly_seasonal,
    row_counts_by_plot_year_sensor_source = row_counts_by_plot_year_sensor_source,
    unique_dates_by_year = unique_dates_by_year,
    duplicate_key_checks = duplicate_key_checks,
    missingness_checks = missingness_checks,
    value_range_checks = value_range_checks,
    metric_reproducibility_checks = metric_reproducibility_checks,
    sequence_reproducibility_checks = sequence_reproducibility_checks,
    support_metrics_by_plot_water_year = support_metrics_by_plot_water_year,
    prepost_mer_metric_support = prepost_mer_metric_support,
    mer_vs_annual_occurrence_flags = mer_vs_annual_occurrence_flags,
    mer_vs_annual_occurrence_common_period = mer_vs_annual_occurrence_common_period,
    duplicate_daily_raster_resolution_log = duplicate_log,
    observation_density_by_water_year = observation_density
  ),
  paths = list(
    input_daily_inundation = daily_inundation_path,
    selected_plot_date_daily = NA_character_,
    annual_dynamic = annual_dynamic_path,
    monthly_seasonal = monthly_seasonal_path,
    row_counts_by_plot_year_sensor_source = row_count_by_plot_year_sensor_path,
    unique_dates_by_year = unique_dates_by_year_path,
    duplicate_key_checks = duplicate_key_check_path,
    missingness_checks = missingness_check_path,
    value_range_checks = value_range_check_path,
    metric_reproducibility_checks = metric_reproducibility_path,
    sequence_reproducibility_checks = sequence_reproducibility_path,
    support_metrics_by_plot_water_year = support_metrics_path,
    prepost_mer_metric_support = prepost_mer_support_path,
    mer_vs_annual_occurrence_flags = mer_vs_annual_occurrence_path,
    mer_vs_annual_occurrence_common_period = common_period_comparison_path,
    duplicate_daily_raster_resolution_log = duplicate_log_path,
    observation_density_by_water_year = observation_density_path
  ),
  output_path = row_count_path
)

run_status <- tibble::tibble(
  output_name = c(
    "annual_dynamic",
    "annual_dynamic_processed",
    "monthly_seasonal",
    "plot_date_daily_support",
    "row_counts_by_plot_year_sensor_source",
    "unique_dates_by_year",
    "duplicate_key_checks",
    "missingness_checks",
    "value_range_checks",
    "metric_reproducibility_checks",
    "sequence_reproducibility_checks",
    "support_metrics_by_plot_water_year",
    "prepost_mer_metric_support",
    "mer_vs_annual_occurrence_flags",
    "mer_vs_annual_occurrence_common_period",
    "figure_manifest",
    "value_checks",
    "invalid_summary",
    "duplicate_log",
    "observation_density",
    "interpretation_lut"
  ),
  output_path = c(
    annual_dynamic_path,
    annual_dynamic_processed_path,
    monthly_seasonal_path,
    plot_date_support_path,
    row_count_by_plot_year_sensor_path,
    unique_dates_by_year_path,
    duplicate_key_check_path,
    missingness_check_path,
    value_range_check_path,
    metric_reproducibility_path,
    sequence_reproducibility_path,
    support_metrics_path,
    prepost_mer_support_path,
    mer_vs_annual_occurrence_path,
    common_period_comparison_path,
    file.path(diagnostics_dir, "figure_manifest.csv"),
    value_check_path,
    invalid_summary_path,
    duplicate_log_path,
    observation_density_path,
    interpretation_lut_path
  ),
  status = "written",
  run_timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
  source_daily_inundation_path = daily_inundation_path,
  daily_wet_rule = DAILY_WET_RULE,
  sensitivity_wet_rule = SENSITIVITY_WET_RULE,
  observed_sequence_gap_rule_days = MAX_GAP_DAYS_IN_OBSERVED_SEQUENCE
)

readr::write_csv(run_status, run_status_path)

message("Wrote: ", annual_dynamic_path)
message("Wrote: ", annual_dynamic_processed_path)
message("Wrote: ", monthly_seasonal_path)
message("Wrote diagnostics under: ", diagnostics_dir)
message("MER daily inundation summary complete.")

}


write_gayini_mer_deck_outputs <- function(root_dir = Sys.getenv("GAYINI_ROOT", "D:/Github_repos/Gayini"), top_n = 10L) {
  root_dir <- normalizePath(root_dir, winslash = "/", mustWork = TRUE)

  required_packages <- c("dplyr", "readr", "tidyr", "tibble", "ggplot2", "stringr")
  missing_packages <- required_packages[
    !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
  ]
  if (length(missing_packages) > 0) {
    stop("Install missing packages before continuing: ", paste(missing_packages, collapse = ", "))
  }

  diagnostics_dir <- file.path(root_dir, "Output", "diagnostics", "06_MER_inundation")
  figure_dir <- file.path(root_dir, "Output", "figures", "06_MER_inundation")
  deck_dir <- file.path(figure_dir, "deck_candidates")
  dir.create(diagnostics_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(deck_dir, recursive = TRUE, showWarnings = FALSE)

  flags_path <- file.path(diagnostics_dir, "mer_vs_annual_occurrence_flags.csv")
  annual_path <- file.path(root_dir, "Output", "csv", "05b_MER_plot_inundation_dynamic_metrics.csv")
  monthly_seasonal_path <- file.path(root_dir, "Output", "csv", "05b_MER_plot_inundation_monthly_seasonal_max.csv")
  support_path <- file.path(diagnostics_dir, "support_metrics_by_plot_water_year.csv")
  analysis_base_path <- file.path(root_dir, "Output", "csv", "plot_rs_analysis_base.csv")

  inputs <- c(flags_path, annual_path, monthly_seasonal_path, support_path, analysis_base_path)
  missing_inputs <- inputs[!file.exists(inputs)]
  if (length(missing_inputs) > 0) {
    stop("Missing MER deck input(s): ", paste(missing_inputs, collapse = ", "), call. = FALSE)
  }

  flags <- readr::read_csv(flags_path, show_col_types = FALSE)
  annual_dynamic <- readr::read_csv(annual_path, show_col_types = FALSE)
  monthly_seasonal <- readr::read_csv(monthly_seasonal_path, show_col_types = FALSE)
  support_metrics <- readr::read_csv(support_path, show_col_types = FALSE)
  analysis_base <- readr::read_csv(analysis_base_path, show_col_types = FALSE)

  ranked_flags <- flags |>
    dplyr::mutate(
      wetter_rank = dplyr::min_rank(dplyr::desc(.data$mer_post_minus_pre_mean_annual_max_pct)),
      drier_rank = dplyr::min_rank(.data$mer_post_minus_pre_mean_annual_max_pct),
      is_top_wetter_post = .data$wetter_rank <= top_n,
      is_top_drier_post = .data$drier_rank <= top_n,
      is_disagreement_review = .data$comparison_flag == "directions_disagree_review",
      is_near_no_change = .data$comparison_flag == "one_metric_near_no_change",
      shortlist_reason = dplyr::case_when(
        .data$is_top_wetter_post & .data$is_disagreement_review ~ "top_wetter_post; disagreement_review",
        .data$is_top_drier_post & .data$is_disagreement_review ~ "top_drier_post; disagreement_review",
        .data$is_top_wetter_post ~ "top_wetter_post",
        .data$is_top_drier_post ~ "top_drier_post",
        .data$is_disagreement_review ~ "disagreement_review",
        .data$is_near_no_change ~ "near_no_change_context",
        TRUE ~ NA_character_
      ),
      observation_support_caveat = dplyr::case_when(
        .data$support_flag != "adequate_support" ~ paste("Review support:", .data$support_flag),
        .data$low_support_years_pre_conservation > 0 | .data$low_support_years_post_conservation > 0 ~
          "Annual support adequate overall, but at least one low-support year is present.",
        TRUE ~ "Annual MER support adequate; monthly/seasonal bins remain lower-confidence."
      ),
      suggested_deck_review_use = dplyr::case_when(
        .data$is_disagreement_review ~ "Manual review before deck use; MER and annual occurrence directions differ.",
        .data$is_top_wetter_post ~ "Candidate deck example for wetter-post observed annual maximum extent.",
        .data$is_top_drier_post ~ "Candidate deck example for drier-post observed annual maximum extent.",
        .data$is_near_no_change ~ "Context/check only; one metric is near no-change.",
        TRUE ~ "Not shortlisted."
      )
    )

  review_shortlist <- ranked_flags |>
    dplyr::filter(!is.na(.data$shortlist_reason)) |>
    dplyr::arrange(
      dplyr::desc(.data$is_disagreement_review),
      dplyr::desc(abs(.data$mer_post_minus_pre_mean_annual_max_pct)),
      .data$plot_id
    ) |>
    dplyr::select(
      "plot_id",
      "shortlist_reason",
      "suggested_deck_review_use",
      pre_post_annual_occurrence_change_pct_points = "post_minus_pre_inundation_frequency_pct_points",
      pre_post_mer_annual_max_change_pct = "mer_post_minus_pre_mean_annual_max_pct",
      pre_post_mer_max_annual_max_change_pct = "mer_post_minus_pre_max_annual_max_pct",
      "comparison_flag",
      "occurrence_direction",
      "mer_direction",
      "support_flag",
      "observation_support_caveat",
      "mean_valid_observations_pre_conservation",
      "mean_valid_observations_post_conservation",
      "low_support_years_pre_conservation",
      "low_support_years_post_conservation",
      "support_caveat_pre_conservation",
      "support_caveat_post_conservation"
    )

  readr::write_csv(review_shortlist, file.path(diagnostics_dir, "mer_plot_review_shortlist.csv"))

  monthly_support_summary <- monthly_seasonal |>
    dplyr::count(.data$temporal_unit, .data$observation_density_class, name = "n_rows") |>
    dplyr::group_by(.data$temporal_unit) |>
    dplyr::mutate(row_pct = round(100 * .data$n_rows / sum(.data$n_rows), 1)) |>
    dplyr::ungroup()

  annual_support_summary <- support_metrics |>
    dplyr::count(.data$observation_density_class, name = "n_plot_years") |>
    dplyr::mutate(plot_year_pct = round(100 * .data$n_plot_years / sum(.data$n_plot_years), 1))

  metric_use_notes <- tibble::tibble(
    topic = c(
      "annual_mer_metrics",
      "monthly_seasonal_mer_metrics",
      "longest_observed_wet_sequence_days",
      "sensor_support"
    ),
    deck_use = c(
      "Preferred MER headline level for current deck.",
      "Do not use as headline metrics yet.",
      "Support/timing diagnostic only.",
      "Use as an interpretation caveat."
    ),
    note = c(
      "Annual plot-year MER support is currently stronger than monthly/seasonal support.",
      "Many monthly/seasonal bins have low observation density; retain for QA and targeted review.",
      "This is not hydroperiod, true duration or wet days; do not headline without sensitivity checks.",
      "Landsat and Sentinel-2 differ in sensor history, cadence and pixel scale, so sensor-date counts describe observation support rather than ecological response."
    )
  )

  readr::write_csv(monthly_support_summary, file.path(diagnostics_dir, "mer_monthly_seasonal_support_summary.csv"))
  readr::write_csv(annual_support_summary, file.path(diagnostics_dir, "mer_annual_support_summary.csv"))
  readr::write_csv(metric_use_notes, file.path(diagnostics_dir, "mer_deck_metric_use_notes.csv"))

  top_wetter_5 <- ranked_flags |>
    dplyr::arrange(dplyr::desc(.data$mer_post_minus_pre_mean_annual_max_pct)) |>
    dplyr::slice_head(n = 5)
  top_drier_5 <- ranked_flags |>
    dplyr::arrange(.data$mer_post_minus_pre_mean_annual_max_pct) |>
    dplyr::slice_head(n = 5)
  disagreement_clear <- ranked_flags |>
    dplyr::filter(.data$is_disagreement_review, abs(.data$mer_post_minus_pre_mean_annual_max_pct) >= 5)
  ranked_label_plots <- dplyr::bind_rows(top_wetter_5, top_drier_5, disagreement_clear) |>
    dplyr::distinct(.data$plot_id, .keep_all = TRUE)
  map_label_plots <- dplyr::bind_rows(top_wetter_5, top_drier_5) |>
    dplyr::distinct(.data$plot_id, .keep_all = TRUE)

  deck_summary_table <- tibble::tibble(
    metric = c(
      "Mean pre annual max observed inundated area",
      "Mean post annual max observed inundated area",
      "Top wetter plots",
      "Top drier plots",
      "MER/annual occurrence agreement",
      "Observation support",
      "Monthly/seasonal caveat",
      "Observed sequence caveat"
    ),
    result = c(
      paste0(round(mean(ranked_flags$mean_annual_max_inundated_area_pct_pre_conservation, na.rm = TRUE), 1), "%"),
      paste0(round(mean(ranked_flags$mean_annual_max_inundated_area_pct_post_conservation, na.rm = TRUE), 1), "%"),
      paste(top_wetter_5$plot_id, collapse = "; "),
      paste(top_drier_5$plot_id, collapse = "; "),
      paste0(
        sum(ranked_flags$comparison_flag == "directions_agree", na.rm = TRUE), " agree / ",
        sum(ranked_flags$comparison_flag == "directions_disagree_review", na.rm = TRUE), " review / ",
        sum(ranked_flags$comparison_flag == "one_metric_near_no_change", na.rm = TRUE), " near-no-change"
      ),
      paste0(sum(support_metrics$observation_density_class == "high_density", na.rm = TRUE), " of ", nrow(support_metrics), " annual plot-years high-density"),
      paste(monthly_support_summary$temporal_unit, monthly_support_summary$observation_density_class, monthly_support_summary$row_pct, "%", collapse = "; "),
      "Retained as timing/support diagnostic only"
    ),
    interpretation = c(
      "Average pre-management annual maximum observed wet footprint across plots.",
      "Average post-management annual maximum observed wet footprint across plots.",
      "Plots with strongest positive post-minus-pre MER annual maximum change.",
      "Plots with strongest negative post-minus-pre MER annual maximum change.",
      "Comparison of MER footprint-change direction against annual occurrence-change direction.",
      "Annual MER support is strong after the adequate-coverage filter.",
      "Monthly/seasonal bins are more observation-limited than annual summaries.",
      "Observed sequence depends on satellite timing and the configured gap rule."
    ),
    deck_use = c(
      "Supporting context number.",
      "Supporting context number.",
      "Candidate labels/examples for ranked and map figures.",
      "Candidate labels/examples for ranked and map figures.",
      "Use to frame review confidence and manual checks.",
      "Use as a caveat/support figure.",
      "Do not headline.",
      "Do not headline as hydroperiod."
    ),
    caveat = c(
      "Observed annual maximum area, not annual frequency or duration.",
      "Observed annual maximum area, not annual frequency or duration.",
      "Review plot labels and spatial context before final deck selection.",
      "Review plot labels and spatial context before final deck selection.",
      "Disagreement does not imply an error; metrics answer different questions.",
      "Sensor mix differs through time; support is not ecological response.",
      "Keep for QA/targeted review until support sensitivity is checked.",
      "Not hydroperiod, true duration or wet days."
    )
  )
  readr::write_csv(deck_summary_table, file.path(diagnostics_dir, "mer_deck_summary_table.csv"))

  label_layer <- function(data, mapping) {
    if (requireNamespace("ggrepel", quietly = TRUE)) {
      ggrepel::geom_text_repel(data = data, mapping = mapping, size = 3, max.overlaps = Inf, min.segment.length = 0)
    } else {
      ggplot2::geom_text(data = data, mapping = mapping, size = 3, vjust = -0.6, check_overlap = TRUE)
    }
  }

  ranked_plot <- ranked_flags |>
    dplyr::arrange(.data$mer_post_minus_pre_mean_annual_max_pct) |>
    dplyr::mutate(plot_order = dplyr::row_number())
  ranked_plot_labels <- ranked_plot |>
    dplyr::filter(.data$plot_id %in% ranked_label_plots$plot_id)

  p_ranked <- ggplot2::ggplot(
    ranked_plot,
    ggplot2::aes(x = .data$plot_order, y = .data$mer_post_minus_pre_mean_annual_max_pct)
  ) +
    ggplot2::geom_hline(yintercept = 0, linewidth = 0.3, colour = "grey45") +
    ggplot2::geom_col(ggplot2::aes(fill = .data$comparison_flag), width = 0.85) +
    label_layer(
      ranked_plot_labels,
      ggplot2::aes(
        x = .data$plot_order,
        y = .data$mer_post_minus_pre_mean_annual_max_pct,
        label = .data$plot_id
      )
    ) +
    ggplot2::scale_fill_manual(
      values = c(
        directions_agree = "#2f6f4e",
        directions_disagree_review = "#b44f3f",
        one_metric_near_no_change = "#7d8794"
      ),
      drop = FALSE
    ) +
    ggplot2::labs(
      x = "Plots ranked by MER change",
      y = "MER annual maximum observed\ninundated area change (percentage points)",
      fill = "MER vs annual occurrence",
      title = "Ranked MER annual maximum observed inundation change"
    ) +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      plot.margin = ggplot2::margin(10, 20, 10, 38)
    )

  ggplot2::ggsave(
    file.path(deck_dir, "01_ranked_mer_annual_max_change_labelled.png"),
    p_ranked,
    width = 12,
    height = 6.2,
    dpi = 220
  )

  map_data <- ranked_flags |>
    dplyr::left_join(
      analysis_base |>
        dplyr::select("plot_id", "centroid_x", "centroid_y", "vegetation", "treatment"),
      by = "plot_id"
    ) |>
    dplyr::filter(!is.na(.data$centroid_x), !is.na(.data$centroid_y))

  map_labels <- map_data |>
    dplyr::filter(.data$plot_id %in% map_label_plots$plot_id)
  map_note <- "Centroid-only fallback; boundary/paddock overlay unavailable."
  map_context_status <- "centroid_only_fallback"
  boundary_path <- file.path(root_dir, "data_intermediate", "spatial", "boundary_clean.gpkg")
  paddocks_path <- file.path(root_dir, "data_intermediate", "spatial", "management_zones_clean.gpkg")
  if (!file.exists(paddocks_path)) {
    paddocks_path <- file.path(root_dir, "data_intermediate", "spatial", "vegetation_classes_clean.gpkg")
  }

  if (requireNamespace("sf", quietly = TRUE) && file.exists(boundary_path)) {
    map_crs <- sf::st_crs(3577)
    boundary <- sf::st_read(boundary_path, quiet = TRUE) |>
      sf::st_transform(map_crs)
    paddocks <- if (file.exists(paddocks_path)) {
      sf::st_read(paddocks_path, quiet = TRUE) |>
        sf::st_transform(map_crs)
    } else {
      NULL
    }

    boundary_bbox <- sf::st_bbox(boundary)
    x_pad <- as.numeric(boundary_bbox["xmax"] - boundary_bbox["xmin"]) * 0.04
    y_pad <- as.numeric(boundary_bbox["ymax"] - boundary_bbox["ymin"]) * 0.04
    map_note <- if (is.null(paddocks)) {
      "Plot centroids over Gayini boundary. Paddock/management boundary layer not found."
    } else {
      "Plot centroids over Gayini boundary and available management/vegetation boundaries."
    }
    map_context_status <- if (is.null(paddocks)) "boundary_only" else "boundary_and_paddocks"

    p_map <- ggplot2::ggplot() +
      {if (!is.null(paddocks)) ggplot2::geom_sf(data = paddocks, fill = "#f7f7f2", colour = "#d5d7cf", linewidth = 0.18)} +
      ggplot2::geom_sf(data = boundary, fill = NA, colour = "#333333", linewidth = 0.55) +
      ggplot2::geom_point(
        data = map_data,
        ggplot2::aes(x = .data$centroid_x, y = .data$centroid_y, colour = .data$mer_post_minus_pre_mean_annual_max_pct),
        size = 3.1,
        alpha = 0.9
      ) +
      label_layer(
        map_labels,
        ggplot2::aes(x = .data$centroid_x, y = .data$centroid_y, label = .data$plot_id)
      ) +
      ggplot2::scale_colour_gradient2(
        low = "#a23b3b",
        mid = "#f3f1e8",
        high = "#19735a",
        midpoint = 0,
        name = "MER change\n(pp)"
      ) +
      ggplot2::coord_sf(
        crs = map_crs,
        xlim = c(boundary_bbox["xmin"] - x_pad, boundary_bbox["xmax"] + x_pad),
        ylim = c(boundary_bbox["ymin"] - y_pad, boundary_bbox["ymax"] + y_pad),
        expand = FALSE
      ) +
      ggplot2::labs(
        title = "MER annual maximum observed inundation change",
        subtitle = "Post-minus-pre change at plot centroids",
        caption = map_note
      ) +
      ggplot2::theme_void(base_size = 12) +
      ggplot2::theme(
        plot.background = ggplot2::element_rect(fill = "white", colour = NA),
        panel.background = ggplot2::element_rect(fill = "white", colour = NA),
        legend.position = "right",
        plot.title = ggplot2::element_text(face = "bold"),
        plot.caption = ggplot2::element_text(colour = "grey35", hjust = 0)
      )
  } else {
    p_map <- ggplot2::ggplot(
      map_data,
      ggplot2::aes(x = .data$centroid_x, y = .data$centroid_y, colour = .data$mer_post_minus_pre_mean_annual_max_pct)
    ) +
      ggplot2::geom_point(size = 3.1, alpha = 0.9) +
      label_layer(
        map_labels,
        ggplot2::aes(x = .data$centroid_x, y = .data$centroid_y, label = .data$plot_id)
      ) +
      ggplot2::scale_colour_gradient2(low = "#a23b3b", mid = "#f3f1e8", high = "#19735a", midpoint = 0, name = "MER change\n(pp)") +
      ggplot2::coord_equal() +
      ggplot2::labs(
        x = NULL,
        y = NULL,
        title = "MER annual maximum observed inundation change",
        subtitle = "Centroid-only fallback",
        caption = map_note
      ) +
      ggplot2::theme_minimal(base_size = 12) +
      ggplot2::theme(
        plot.background = ggplot2::element_rect(fill = "white", colour = NA),
        panel.background = ggplot2::element_rect(fill = "white", colour = NA),
        panel.grid = ggplot2::element_line(colour = "grey90")
      )
  }

  readr::write_csv(
    tibble::tibble(
      map_context_status = map_context_status,
      boundary_path = boundary_path,
      boundary_available = file.exists(boundary_path),
      paddock_or_management_path = paddocks_path,
      paddock_or_management_available = file.exists(paddocks_path),
      centroid_crs_epsg = 3577,
      note = map_note
    ),
    file.path(diagnostics_dir, "mer_deck_map_spatial_context_note.csv")
  )

  ggplot2::ggsave(
    file.path(deck_dir, "02_mer_change_plot_centroid_map.png"),
    p_map,
    width = 8.5,
    height = 7,
    dpi = 220
  )

  scatter_labels <- dplyr::bind_rows(
    ranked_flags |>
      dplyr::filter(.data$is_disagreement_review) |>
      dplyr::arrange(dplyr::desc(abs(.data$mer_post_minus_pre_mean_annual_max_pct))) |>
      dplyr::slice_head(n = 5),
    ranked_flags |>
      dplyr::filter(abs(.data$mer_post_minus_pre_mean_annual_max_pct) >= stats::quantile(abs(.data$mer_post_minus_pre_mean_annual_max_pct), 0.92, na.rm = TRUE)),
    ranked_flags |>
      dplyr::filter(abs(.data$post_minus_pre_inundation_frequency_pct_points) >= stats::quantile(abs(.data$post_minus_pre_inundation_frequency_pct_points), 0.92, na.rm = TRUE))
  ) |>
    dplyr::distinct(.data$plot_id, .keep_all = TRUE)

  p_scatter <- ggplot2::ggplot(
    ranked_flags,
    ggplot2::aes(
      x = .data$post_minus_pre_inundation_frequency_pct_points,
      y = .data$mer_post_minus_pre_mean_annual_max_pct
    )
  ) +
    ggplot2::geom_hline(yintercept = 0, linewidth = 0.3, colour = "grey55") +
    ggplot2::geom_vline(xintercept = 0, linewidth = 0.3, colour = "grey55") +
    ggplot2::geom_point(ggplot2::aes(colour = .data$comparison_flag), size = 2.4, alpha = 0.72) +
    ggplot2::geom_point(
      data = dplyr::filter(ranked_flags, .data$is_disagreement_review),
      ggplot2::aes(
        x = .data$post_minus_pre_inundation_frequency_pct_points,
        y = .data$mer_post_minus_pre_mean_annual_max_pct
      ),
      shape = 21,
      size = 3.8,
      stroke = 0.8,
      fill = NA,
      colour = "#7f1d1d"
    ) +
    label_layer(
      scatter_labels,
      ggplot2::aes(
        x = .data$post_minus_pre_inundation_frequency_pct_points,
        y = .data$mer_post_minus_pre_mean_annual_max_pct,
        label = .data$plot_id
      )
    ) +
    ggplot2::scale_colour_manual(
      values = c(
        directions_agree = "#2f6f4e",
        directions_disagree_review = "#b44f3f",
        one_metric_near_no_change = "#7d8794"
      ),
      drop = FALSE
    ) +
    ggplot2::labs(
      x = "Post-minus-pre annual occurrence frequency (percentage points)",
      y = "Post-minus-pre MER annual maximum\nobserved inundated area (percentage points)",
      colour = "Comparison flag",
      title = "MER annual maximum change versus annual occurrence change",
      subtitle = "Disagreement-review plots are circled; labels show strongest disagreements and outliers"
    ) +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      plot.margin = ggplot2::margin(10, 24, 10, 38)
    )

  ggplot2::ggsave(
    file.path(deck_dir, "03_mer_vs_annual_occurrence_scatter_labelled.png"),
    p_scatter,
    width = 8.5,
    height = 6.4,
    dpi = 220
  )

  ordered_plots <- ranked_flags |>
    dplyr::arrange(.data$mer_post_minus_pre_mean_annual_max_pct) |>
    dplyr::pull(.data$plot_id)

  water_year_levels <- sort(unique(annual_dynamic$water_year))
  water_year_labels <- paste0("WY", stringr::str_extract(water_year_levels, "\\d{4}$"))

  p_heatmap <- annual_dynamic |>
    dplyr::mutate(
      plot_id = factor(.data$plot_id, levels = ordered_plots),
      water_year_label = factor(.data$water_year, levels = water_year_levels, labels = water_year_labels)
    ) |>
    ggplot2::ggplot(ggplot2::aes(x = .data$water_year_label, y = .data$plot_id, fill = .data$annual_max_inundated_area_pct)) +
    ggplot2::geom_tile() +
    ggplot2::scale_fill_viridis_c(option = "C", na.value = "grey92") +
    ggplot2::labs(
      x = "Water year",
      y = "Plots ordered by MER post-minus-pre change",
      fill = "Annual max (%)",
      title = "Annual maximum observed inundation by plot",
      caption = "Colours show annual maximum observed inundated area, not annual frequency, hydroperiod or duration."
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      axis.text.y = ggplot2::element_blank(),
      axis.ticks.y = ggplot2::element_blank(),
      axis.text.x = ggplot2::element_text(angle = 45, hjust = 1),
      panel.grid = ggplot2::element_blank()
    )

  ggplot2::ggsave(
    file.path(deck_dir, "04_annual_max_heatmap_ordered_by_mer_change.png"),
    p_heatmap,
    width = 9.5,
    height = 8,
    dpi = 220
  )

  support_long <- readr::read_csv(file.path(diagnostics_dir, "observation_density_by_water_year.csv"), show_col_types = FALSE) |>
    dplyr::select(
      "water_year",
      l7 = "n_l7_rasters",
      l8 = "n_l8_rasters",
      l9 = "n_l9_rasters",
      s2 = "n_s2_rasters",
      unknown = "n_unknown_rasters"
    ) |>
    tidyr::pivot_longer(-"water_year", names_to = "sensor", values_to = "n_observations") |>
    dplyr::mutate(
      sensor = stringr::str_to_upper(.data$sensor),
      water_year_label = factor(
        .data$water_year,
        levels = water_year_levels,
        labels = water_year_labels
      )
    )

  p_support <- ggplot2::ggplot(
    support_long,
    ggplot2::aes(x = .data$water_year_label, y = .data$n_observations, fill = .data$sensor)
  ) +
    ggplot2::geom_col(width = 0.75) +
    ggplot2::scale_fill_manual(
      values = c(L7 = "#756bb1", L8 = "#3182bd", L9 = "#41ab5d", S2 = "#e6550d", UNKNOWN = "#969696"),
      drop = FALSE
    ) +
    ggplot2::labs(
      x = "Water year",
      y = "Selected raster observations",
      fill = "Sensor",
      title = "MER observation support by water year and sensor",
      caption = "Support only: Landsat and Sentinel-2 differ in cadence, pixel size and history."
    ) +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      axis.text.x = ggplot2::element_text(angle = 45, hjust = 1)
    )

  ggplot2::ggsave(
    file.path(deck_dir, "05_observation_support_sensor_note.png"),
    p_support,
    width = 8.5,
    height = 5.4,
    dpi = 220
  )

  deck_manifest <- tibble::tibble(
    figure_name = c(
      "01_ranked_mer_annual_max_change_labelled.png",
      "02_mer_change_plot_centroid_map.png",
      "03_mer_vs_annual_occurrence_scatter_labelled.png",
      "04_annual_max_heatmap_ordered_by_mer_change.png",
      "05_observation_support_sensor_note.png"
    ),
    figure_path = file.path(deck_dir, figure_name),
    status = ifelse(file.exists(file.path(deck_dir, figure_name)), "written", "not_written"),
    deck_use = c(
      "Candidate headline/support figure after plot-label review.",
      "Candidate spatial overview using plot centroids and available vector layers.",
      "Candidate review figure for metric agreement/disagreement.",
      "Candidate supporting heatmap; ordered by MER change for scanability.",
      "Candidate support/caveat figure; not an ecological response figure."
    )
  )
  readr::write_csv(deck_manifest, file.path(deck_dir, "deck_candidate_figure_manifest.csv"))

  message("Wrote MER review shortlist and deck candidates under: ", deck_dir)
  invisible(
    list(
      review_shortlist = review_shortlist,
      deck_manifest = deck_manifest,
      metric_use_notes = metric_use_notes
    )
  )
}
