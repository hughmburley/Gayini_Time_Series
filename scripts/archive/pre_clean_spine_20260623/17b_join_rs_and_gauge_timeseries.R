## 17b_join_rs_and_gauge_timeseries.R
## Join Gayini remote-sensing time series with imported Murrumbidgee gauge context.

root_dir <- Sys.getenv("GAYINI_ROOT", unset = getwd())
setwd(root_dir)

required_packages <- c("dplyr", "lubridate", "readr", "stringr", "tibble", "tidyr")
missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]
if (length(missing_packages) > 0) {
  stop("Install missing packages before continuing: ", paste(missing_packages, collapse = ", "))
}

source(file.path(root_dir, "R/hydrology_import_functions.R"))
source(file.path(root_dir, "R/rs_gauge_join_functions.R"))

dir.create(file.path(root_dir, "data_processed/hydrology"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(root_dir, "data_intermediate/hydrology"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(root_dir, "Output/diagnostics/hydrology"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(root_dir, "Output/logs"), recursive = TRUE, showWarnings = FALSE)

required_inputs <- c(
  "data_intermediate/hydrology/gayini_gauge_monthly_imported.csv",
  "data_intermediate/hydrology/gayini_gauge_water_year_imported.csv",
  "data_processed/plot_landsat_inundation_timeseries.csv",
  "data_processed/plot_daily_inundation_timeseries.csv",
  "data_processed/plot_fractional_cover_timeseries.csv"
)
missing_inputs <- required_inputs[!file.exists(file.path(root_dir, required_inputs))]
if (length(missing_inputs) > 0) {
  stop("Missing Task 04b join inputs: ", paste(missing_inputs, collapse = ", "))
}

gauge_monthly <- read_hydrology_csv(file.path(root_dir, "data_intermediate/hydrology/gayini_gauge_monthly_imported.csv"))
gauge_water_year <- read_hydrology_csv(file.path(root_dir, "data_intermediate/hydrology/gayini_gauge_water_year_imported.csv"))

gauge_monthly_prepared <- prepare_gauge_monthly(gauge_monthly)
gauge_water_year_prepared <- prepare_gauge_water_year(gauge_water_year)

landsat_annual <- annualise_landsat_inundation(file.path(root_dir, "data_processed/plot_landsat_inundation_timeseries.csv"))
daily_annual <- annualise_daily_inundation(file.path(root_dir, "data_processed/plot_daily_inundation_timeseries.csv"))
fcover_annual <- annualise_fractional_cover(file.path(root_dir, "data_processed/plot_fractional_cover_timeseries.csv"))

rs_water_year <- make_water_year_rs_table(landsat_annual, daily_annual, fcover_annual)
water_year_context <- join_water_year_gauge_context(rs_water_year, gauge_water_year_prepared) |>
  dplyr::arrange(.data$plot_id, .data$water_year, .data$station_id)

daily_monthly <- monthly_daily_inundation(file.path(root_dir, "data_processed/plot_daily_inundation_timeseries.csv"))
fcover_monthly <- monthly_fractional_cover(file.path(root_dir, "data_processed/plot_fractional_cover_timeseries.csv"))
rs_monthly <- make_monthly_rs_table(daily_monthly, fcover_monthly)
monthly_context <- join_monthly_gauge_context(rs_monthly, gauge_monthly_prepared) |>
  dplyr::arrange(.data$plot_id, .data$month_start, .data$station_id)

gauge_context_for_deck <- dplyr::bind_rows(
  gauge_monthly_prepared |>
    dplyr::filter(.data$recommended_use %in% c("upstream_context_primary", "lower_murrumbidgee_context_primary", "local_upstream_primary", "downstream_context_flagged")) |>
    dplyr::transmute(
      time_scale = "monthly",
      date = .data$month_start,
      water_year = NA_character_,
      station_id,
      station_name,
      recommended_use,
      mean_flow_mld,
      total_flow_ml,
      max_daily_flow_mld,
      n_valid_flow_days,
      n_missing_flow_days,
      missing_flow_pct,
      patch_status_summary,
      record_status_summary
    ),
  gauge_water_year_prepared |>
    dplyr::filter(.data$recommended_use %in% c("upstream_context_primary", "lower_murrumbidgee_context_primary", "local_upstream_primary", "downstream_context_flagged")) |>
    dplyr::transmute(
      time_scale = "water_year",
      date = as.Date(paste0(.data$water_year_numeric, "-06-30")),
      water_year,
      station_id,
      station_name,
      recommended_use,
      mean_flow_mld,
      total_flow_ml,
      max_daily_flow_mld,
      n_valid_flow_days,
      n_missing_flow_days,
      missing_flow_pct,
      patch_status_summary,
      record_status_summary
    )
)

readr::write_csv(gauge_water_year_prepared, file.path(root_dir, "data_intermediate/hydrology/gauge_water_year_prepared.csv"))
readr::write_csv(gauge_monthly_prepared, file.path(root_dir, "data_intermediate/hydrology/gauge_monthly_prepared.csv"))
readr::write_csv(rs_water_year, file.path(root_dir, "data_intermediate/hydrology/rs_water_year_context_base.csv"))
readr::write_csv(rs_monthly, file.path(root_dir, "data_intermediate/hydrology/rs_monthly_context_base.csv"))

readr::write_csv(water_year_context, file.path(root_dir, "data_processed/hydrology/plot_rs_gauge_water_year_context.csv"))
readr::write_csv(monthly_context, file.path(root_dir, "data_processed/hydrology/plot_rs_gauge_monthly_context.csv"))
readr::write_csv(gauge_context_for_deck, file.path(root_dir, "data_processed/hydrology/gauge_context_for_deck.csv"))

join_checks <- make_join_key_checks(rs_water_year, water_year_context, rs_monthly, monthly_context)
missingness_by_period <- gauge_water_year_prepared |>
  dplyr::group_by(.data$station_id, .data$station_name, .data$recommended_use, .data$pre_post_period) |>
  dplyr::summarise(
    n_water_years = dplyr::n(),
    mean_missing_flow_pct = round(mean(.data$missing_flow_pct, na.rm = TRUE), 2),
    max_missing_flow_pct = max(.data$missing_flow_pct, na.rm = TRUE),
    years_over_20_pct_missing = sum(.data$missing_flow_pct > 20, na.rm = TRUE),
    .groups = "drop"
  )

join_summary <- tibble::tibble(
  output = c("plot_rs_gauge_water_year_context", "plot_rs_gauge_monthly_context", "gauge_context_for_deck"),
  rows = c(nrow(water_year_context), nrow(monthly_context), nrow(gauge_context_for_deck)),
  plots = c(dplyr::n_distinct(water_year_context$plot_id), dplyr::n_distinct(monthly_context$plot_id), NA_integer_),
  gauges = c(dplyr::n_distinct(water_year_context$station_id), dplyr::n_distinct(monthly_context$station_id), dplyr::n_distinct(gauge_context_for_deck$station_id)),
  note = c(
    "Annual RS context expanded by imported gauge water-year summaries.",
    "Monthly RS context expanded by imported gauge monthly summaries.",
    "Gauge-only compact table for deck figures."
  )
)

readr::write_csv(join_checks, file.path(root_dir, "Output/diagnostics/hydrology/hydrology_join_key_checks.csv"))
readr::write_csv(missingness_by_period, file.path(root_dir, "Output/diagnostics/hydrology/hydrology_missingness_by_period.csv"))
readr::write_csv(join_summary, file.path(root_dir, "Output/diagnostics/hydrology/rs_gauge_join_summary.csv"))

if (any(join_checks$status == "fail")) {
  stop("Hydrology join checks failed. See Output/diagnostics/hydrology/hydrology_join_key_checks.csv")
}

writeLines(capture.output(sessionInfo()), file.path(root_dir, "Output/logs/17b_join_rs_and_gauge_timeseries_session_info.txt"))

message("Task 04b/17b RS-gauge joins complete.")
message("Water-year context rows: ", nrow(water_year_context))
message("Monthly context rows: ", nrow(monthly_context))
