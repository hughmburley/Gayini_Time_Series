## rs_gauge_join_functions.R
## Join helpers for Gayini remote-sensing time series and Murrumbidgee gauge context.

management_change_date <- as.Date("2019-07-01")

pre_post_period_from_date <- function(date) {
  dplyr::if_else(as.Date(date) < management_change_date, "pre_2019_07_management_change", "post_2019_07_management_change")
}

water_year_end_from_label <- function(water_year_label) {
  suppressWarnings(as.integer(stringr::str_sub(as.character(water_year_label), -4, -1)))
}

month_start_from_date <- function(date) {
  date <- as.Date(date)
  as.Date(sprintf("%04d-%02d-01", lubridate::year(date), lubridate::month(date)))
}

annualise_landsat_inundation <- function(path) {
  readr::read_csv(path, show_col_types = FALSE) |>
    dplyr::mutate(
      water_year = as.character(.data$water_year),
      inundated_any_pct = as.numeric(.data$inundated_any_pct),
      mean_inundation_count = as.numeric(.data$mean_inundation_count),
      valid_coverage_pct = as.numeric(.data$valid_coverage_pct)
    ) |>
    dplyr::group_by(.data$plot_id, .data$water_year, .data$treatment, .data$vegetation) |>
    dplyr::summarise(
      annual_inundated_any_pct = mean(.data$inundated_any_pct, na.rm = TRUE),
      annual_mean_inundation_count = mean(.data$mean_inundation_count, na.rm = TRUE),
      annual_valid_coverage_pct = mean(.data$valid_coverage_pct, na.rm = TRUE),
      n_landsat_annual_records = dplyr::n(),
      .groups = "drop"
    )
}

annualise_daily_inundation <- function(path) {
  readr::read_csv(path, show_col_types = FALSE) |>
    dplyr::mutate(
      water_year = as.character(.data$water_year),
      daily_inundated_pct = as.numeric(.data$daily_inundated_pct),
      valid_interpretation_pct = as.numeric(.data$valid_interpretation_pct),
      date_midpoint = as.Date(.data$date_midpoint)
    ) |>
    dplyr::group_by(.data$plot_id, .data$water_year) |>
    dplyr::summarise(
      daily_obs_count = dplyr::n(),
      daily_mean_inundated_pct = mean(.data$daily_inundated_pct, na.rm = TRUE),
      daily_max_inundated_pct = max(.data$daily_inundated_pct, na.rm = TRUE),
      daily_valid_interpretation_pct = mean(.data$valid_interpretation_pct, na.rm = TRUE),
      .groups = "drop"
    )
}

annualise_fractional_cover <- function(path) {
  readr::read_csv(path, show_col_types = FALSE) |>
    dplyr::mutate(
      water_year = as.character(.data$water_year),
      mean_value = as.numeric(.data$mean_value)
    ) |>
    dplyr::select(
      "plot_id",
      "water_year",
      "treatment",
      "vegetation",
      "band_label",
      "mean_value"
    ) |>
    tidyr::pivot_wider(names_from = "band_label", values_from = "mean_value", values_fn = mean) |>
    dplyr::mutate(
      total_veg_pct = .data$green_or_pv + .data$non_green_or_npv
    ) |>
    dplyr::group_by(.data$plot_id, .data$water_year, .data$treatment, .data$vegetation) |>
    dplyr::summarise(
      total_veg_pct = mean(.data$total_veg_pct, na.rm = TRUE),
      green_or_pv_pct = mean(.data$green_or_pv, na.rm = TRUE),
      non_green_or_npv_pct = mean(.data$non_green_or_npv, na.rm = TRUE),
      bare_ground_pct = mean(.data$bare_ground, na.rm = TRUE),
      .groups = "drop"
    )
}

monthly_daily_inundation <- function(path) {
  readr::read_csv(path, show_col_types = FALSE) |>
    dplyr::mutate(
      date_midpoint = as.Date(.data$date_midpoint),
      month_start = month_start_from_date(.data$date_midpoint),
      daily_inundated_pct = as.numeric(.data$daily_inundated_pct)
    ) |>
    dplyr::group_by(.data$plot_id, .data$month_start) |>
    dplyr::summarise(
      daily_obs_count = dplyr::n(),
      monthly_mean_inundated_pct = mean(.data$daily_inundated_pct, na.rm = TRUE),
      monthly_max_inundated_pct = max(.data$daily_inundated_pct, na.rm = TRUE),
      .groups = "drop"
    )
}

monthly_fractional_cover <- function(path) {
  readr::read_csv(path, show_col_types = FALSE) |>
    dplyr::mutate(
      date_midpoint = as.Date(.data$date_midpoint),
      month_start = month_start_from_date(.data$date_midpoint),
      mean_value = as.numeric(.data$mean_value)
    ) |>
    dplyr::select("plot_id", "month_start", "treatment", "vegetation", "band_label", "mean_value") |>
    tidyr::pivot_wider(names_from = "band_label", values_from = "mean_value", values_fn = mean) |>
    dplyr::mutate(total_veg_pct = .data$green_or_pv + .data$non_green_or_npv) |>
    dplyr::group_by(.data$plot_id, .data$month_start, .data$treatment, .data$vegetation) |>
    dplyr::summarise(
      total_veg_pct = mean(.data$total_veg_pct, na.rm = TRUE),
      green_or_pv_pct = mean(.data$green_or_pv, na.rm = TRUE),
      non_green_or_npv_pct = mean(.data$non_green_or_npv, na.rm = TRUE),
      bare_ground_pct = mean(.data$bare_ground, na.rm = TRUE),
      .groups = "drop"
    )
}

prepare_gauge_water_year <- function(water_year) {
  if (!"include_in_default_continuous_context" %in% names(water_year)) {
    water_year$include_in_default_continuous_context <- water_year$recommended_use %in% c(
      "upstream_context_primary",
      "lower_murrumbidgee_context_primary",
      "local_upstream_primary",
      "downstream_context_flagged"
    )
  }
  if (!"not_required_for_mer_metrics" %in% names(water_year)) {
    water_year$not_required_for_mer_metrics <- TRUE
  }

  water_year |>
    dplyr::mutate(
      water_year_numeric = as.integer(.data$water_year),
      water_year = water_year_label_from_numeric(.data$water_year_numeric),
      pre_post_period = dplyr::if_else(.data$water_year_numeric < 2020L, "pre_2019_07_management_change", "post_2019_07_management_change"),
      record_status_summary = dplyr::coalesce(.data$record_status_summary, NA_character_),
      patch_status_summary = dplyr::coalesce(.data$patch_status_summary, NA_character_)
    ) |>
    dplyr::select(
      "station_id",
      "station_name",
      "recommended_use",
      "interpretation",
      "include_in_default_continuous_context",
      "not_required_for_mer_metrics",
      "water_year",
      "water_year_numeric",
      "mean_flow_mld",
      "total_flow_ml",
      "max_daily_flow_mld",
      "n_valid_flow_days",
      "n_missing_flow_days",
      "missing_flow_pct",
      "record_status_summary",
      "patch_status_summary",
      "drought_context_class",
      "pre_post_period"
    )
}

prepare_gauge_monthly <- function(monthly) {
  if (!"include_in_default_continuous_context" %in% names(monthly)) {
    monthly$include_in_default_continuous_context <- monthly$recommended_use %in% c(
      "upstream_context_primary",
      "lower_murrumbidgee_context_primary",
      "local_upstream_primary",
      "downstream_context_flagged"
    )
  }
  if (!"not_required_for_mer_metrics" %in% names(monthly)) {
    monthly$not_required_for_mer_metrics <- TRUE
  }

  monthly |>
    dplyr::mutate(
      month_start = as.Date(.data$month_start),
      pre_post_period = pre_post_period_from_date(.data$month_start),
      record_status_summary = dplyr::coalesce(.data$record_status_summary, NA_character_),
      patch_status_summary = dplyr::coalesce(.data$patch_status_summary, NA_character_)
    ) |>
    dplyr::select(
      "station_id",
      "station_name",
      "recommended_use",
      "interpretation",
      "include_in_default_continuous_context",
      "not_required_for_mer_metrics",
      "month_start",
      "mean_flow_mld",
      "total_flow_ml",
      "max_daily_flow_mld",
      "n_valid_flow_days",
      "n_missing_flow_days",
      "missing_flow_pct",
      "record_status_summary",
      "patch_status_summary",
      "drought_context_class",
      "pre_post_period"
    )
}

make_water_year_rs_table <- function(landsat_annual, daily_annual, fcover_annual) {
  joined <- landsat_annual |>
    dplyr::full_join(daily_annual, by = c("plot_id", "water_year")) |>
    dplyr::full_join(fcover_annual, by = c("plot_id", "water_year"), suffix = c("", "_fcover"))

  if (!"treatment_fcover" %in% names(joined)) joined$treatment_fcover <- NA_character_
  if (!"vegetation_fcover" %in% names(joined)) joined$vegetation_fcover <- NA_character_

  joined |>
    dplyr::mutate(
      treatment = dplyr::coalesce(.data$treatment, .data$treatment_fcover),
      vegetation = dplyr::coalesce(.data$vegetation, .data$vegetation_fcover)
    ) |>
    dplyr::select(-dplyr::any_of(c("treatment_fcover", "vegetation_fcover")))
}

join_water_year_gauge_context <- function(rs_water_year, gauge_water_year) {
  gauge_keys <- gauge_water_year |>
    dplyr::filter(.data$include_in_default_continuous_context) |>
    dplyr::distinct(
      .data$station_id,
      .data$station_name,
      .data$recommended_use,
      .data$interpretation,
      .data$include_in_default_continuous_context,
      .data$not_required_for_mer_metrics
    )

  tidyr::crossing(rs_water_year, gauge_keys) |>
    dplyr::left_join(
      gauge_water_year |>
        dplyr::select(-dplyr::any_of(c(
          "station_name",
          "recommended_use",
          "interpretation",
          "include_in_default_continuous_context",
          "not_required_for_mer_metrics"
        ))),
      by = c("water_year", "station_id")
    )
}

make_monthly_rs_table <- function(daily_monthly, fcover_monthly) {
  joined <- daily_monthly |>
    dplyr::full_join(fcover_monthly, by = c("plot_id", "month_start"), suffix = c("", "_fcover"))

  if (!"treatment" %in% names(joined)) joined$treatment <- NA_character_
  if (!"vegetation" %in% names(joined)) joined$vegetation <- NA_character_
  if (!"treatment_fcover" %in% names(joined)) joined$treatment_fcover <- NA_character_
  if (!"vegetation_fcover" %in% names(joined)) joined$vegetation_fcover <- NA_character_

  joined |>
    dplyr::mutate(
      treatment = dplyr::coalesce(.data$treatment, .data$treatment_fcover),
      vegetation = dplyr::coalesce(.data$vegetation, .data$vegetation_fcover)
    ) |>
    dplyr::select(-dplyr::any_of(c("treatment_fcover", "vegetation_fcover")))
}

join_monthly_gauge_context <- function(rs_monthly, gauge_monthly) {
  gauge_keys <- gauge_monthly |>
    dplyr::filter(.data$include_in_default_continuous_context) |>
    dplyr::distinct(
      .data$station_id,
      .data$station_name,
      .data$recommended_use,
      .data$interpretation,
      .data$include_in_default_continuous_context,
      .data$not_required_for_mer_metrics
    )

  tidyr::crossing(rs_monthly, gauge_keys) |>
    dplyr::left_join(
      gauge_monthly |>
        dplyr::select(-dplyr::any_of(c(
          "station_name",
          "recommended_use",
          "interpretation",
          "include_in_default_continuous_context",
          "not_required_for_mer_metrics"
        ))),
      by = c("month_start", "station_id")
    )
}

make_join_key_checks <- function(rs_water_year, water_year_join, rs_monthly, monthly_join) {
  tibble::tibble(
    check_name = c(
      "water_year_rs_plot_years_retained",
      "monthly_rs_plot_months_retained",
      "water_year_join_has_gauges",
      "monthly_join_has_gauges"
    ),
    status = c(
      ifelse(dplyr::n_distinct(paste(rs_water_year$plot_id, rs_water_year$water_year)) ==
               dplyr::n_distinct(paste(water_year_join$plot_id, water_year_join$water_year)), "pass", "fail"),
      ifelse(dplyr::n_distinct(paste(rs_monthly$plot_id, rs_monthly$month_start)) ==
               dplyr::n_distinct(paste(monthly_join$plot_id, monthly_join$month_start)), "pass", "fail"),
      ifelse(dplyr::n_distinct(water_year_join$station_id) >= 4, "pass", "warn"),
      ifelse(dplyr::n_distinct(monthly_join$station_id) >= 4, "pass", "warn")
    ),
    check_value = c(
      dplyr::n_distinct(paste(water_year_join$plot_id, water_year_join$water_year)),
      dplyr::n_distinct(paste(monthly_join$plot_id, monthly_join$month_start)),
      dplyr::n_distinct(water_year_join$station_id),
      dplyr::n_distinct(monthly_join$station_id)
    ),
    note = c(
      "No accidental loss of plot x water_year rows during gauge context join.",
      "No accidental loss of plot x month rows during gauge context join.",
      "Expected the four default continuous-context Murrumbidgee gauges in water-year context.",
      "Expected the four default continuous-context Murrumbidgee gauges in monthly context."
    )
  )
}
