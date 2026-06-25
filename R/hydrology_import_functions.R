## hydrology_import_functions.R
## Import helpers for Murrumbidgee gauge products used as Gayini hydrology context.

gauge_role_lookup <- function() {
  tibble::tribble(
    ~station_id, ~recommended_use, ~interpretation, ~include_in_default_continuous_context, ~not_required_for_mer_metrics,
    "410021", "upstream_context_primary", "Strong upstream context gauge.", TRUE, TRUE,
    "410136", "lower_murrumbidgee_context_primary", "Important Kingsford-style lower Murrumbidgee context.", TRUE, TRUE,
    "410040", "local_upstream_primary", "High-priority local/Lowbidgee context.", TRUE, TRUE,
    "410130", "downstream_context_flagged", "Useful downstream context; keep 1990-1991 suspect-zero flag.", TRUE, TRUE,
    "410041", "use_outside_major_gap_only", "Spatially important, but exclude from continuous historical context because the 1993-2006 gap is unresolved.", FALSE, TRUE,
    "41000281", "use_outside_major_gap_only", "Support/recent context only, but exclude from continuous historical context because the 1988-1995 gap is unresolved.", FALSE, TRUE
  )
}

selected_gauge_database_tables <- function() {
  c(
    "gauge_sites",
    "daily_flow_wide",
    "monthly_flow",
    "water_year_flow",
    "completeness_by_gauge",
    "completeness_overall",
    "remaining_gaps",
    "large_gap_recovery_status"
  )
}

find_gauge_context_database <- function(gayini_root) {
  candidates <- file.path(
    gayini_root,
    "Input",
    "hydrology",
    c("gayini_murrumbidgee_gauges.gpkg", "gayini_murrumbidgee_gauges.sqlite")
  )
  existing <- candidates[file.exists(candidates)]
  if (length(existing) == 0L) {
    return(NA_character_)
  }
  existing[[1]]
}

water_year_label_from_numeric <- function(water_year) {
  year <- as.integer(water_year)
  paste0(year - 1L, "-", year)
}

source_file_lookup <- function(source_root) {
  patched <- tibble::tribble(
    ~product, ~source_path, ~import_path, ~preferred,
    "daily", "data_processed/murrumbidgee_daily_flow_patched.csv", "Input/hydrology/gayini_gauge_daily.csv", TRUE,
    "monthly", "data_processed/murrumbidgee_monthly_flow_patched.csv", "Input/hydrology/gayini_gauge_monthly.csv", TRUE,
    "water_year", "data_processed/murrumbidgee_water_year_flow_patched.csv", "Input/hydrology/gayini_gauge_water_year.csv", TRUE,
    "gauge_record_quality_summary", "Output/diagnostics/gauge_patch_summary.csv", "Input/hydrology/gauge_record_quality_summary.csv", TRUE,
    "gauge_remaining_gaps_after_patch", "Output/diagnostics/gauge_remaining_gaps_after_patch.csv", "Input/hydrology/gauge_remaining_gaps_after_patch.csv", TRUE
  )

  fallback <- tibble::tribble(
    ~product, ~source_path, ~import_path, ~preferred,
    "daily", "data_processed/murrumbidgee_daily_flow_record_status.csv", "Input/hydrology/gayini_gauge_daily.csv", FALSE,
    "monthly", "data_processed/murrumbidgee_monthly_flow_record_status_summary.csv", "Input/hydrology/gayini_gauge_monthly.csv", FALSE,
    "water_year", "data_processed/murrumbidgee_water_year_flow_with_drought_context.csv", "Input/hydrology/gayini_gauge_water_year.csv", FALSE,
    "gauge_record_quality_summary", "Output/diagnostics/gauge_record_quality_summary.csv", "Input/hydrology/gauge_record_quality_summary.csv", FALSE
  )

  optional <- tibble::tribble(
    ~product, ~source_path, ~import_path, ~preferred,
    "kingsford_style_flow_ratio_water_year", "data_processed/kingsford_style_flow_ratio_water_year.csv", "Input/hydrology/kingsford_style_flow_ratio_water_year.csv", TRUE,
    "kingsford_style_flow_ratio_nov_oct_year", "data_processed/kingsford_style_flow_ratio_nov_oct_year.csv", "Input/hydrology/kingsford_style_flow_ratio_nov_oct_year.csv", TRUE
  )

  patched_available <- all(file.exists(file.path(source_root, patched$source_path[patched$product %in% c("daily", "monthly", "water_year")])))
  chosen <- if (patched_available) patched else fallback

  dplyr::bind_rows(chosen, optional) |>
    dplyr::mutate(
      source_root = source_root,
      absolute_source_path = file.path(.data$source_root, .data$source_path),
      source_exists = file.exists(.data$absolute_source_path),
      source_set = ifelse(.data$preferred & patched_available, "patched_preferred", "fallback_or_optional")
    )
}

copy_hydrology_exports <- function(file_lookup, gayini_root) {
  dplyr::bind_rows(lapply(seq_len(nrow(file_lookup)), function(i) {
    row <- file_lookup[i, ]
    destination <- file.path(gayini_root, row$import_path)
    dir.create(dirname(destination), recursive = TRUE, showWarnings = FALSE)

    copied <- FALSE
    if (isTRUE(row$source_exists)) {
      copied <- file.copy(row$absolute_source_path, destination, overwrite = TRUE)
    }

    tibble::tibble(
      product = row$product,
      source_path = row$absolute_source_path,
      import_path = destination,
      source_exists = row$source_exists,
      copied = copied,
      source_set = row$source_set
    )
  }))
}

read_hydrology_csv <- function(path) {
  readr::read_csv(
    path,
    show_col_types = FALSE,
    col_types = readr::cols(.default = readr::col_guess(), station_id = readr::col_character())
  ) |>
    dplyr::mutate(station_id = as.character(.data$station_id))
}

add_gauge_roles <- function(data) {
  data |>
    dplyr::left_join(gauge_role_lookup(), by = "station_id") |>
    dplyr::mutate(
      recommended_use = dplyr::coalesce(.data$recommended_use, "unclassified_gauge"),
      interpretation = dplyr::coalesce(.data$interpretation, "No current role assigned."),
      include_in_default_continuous_context = dplyr::coalesce(.data$include_in_default_continuous_context, FALSE),
      not_required_for_mer_metrics = dplyr::coalesce(.data$not_required_for_mer_metrics, TRUE)
    )
}

make_gauge_metadata <- function(daily) {
  daily |>
    dplyr::group_by(.data$station_id, .data$station_name, .data$recommended_use, .data$interpretation) |>
    dplyr::summarise(
      first_date = min(as.Date(.data$date), na.rm = TRUE),
      last_date = max(as.Date(.data$date), na.rm = TRUE),
      n_days = dplyr::n(),
      n_flow_days = sum(!is.na(.data$flow_mld)),
      n_missing_flow_days = sum(is.na(.data$flow_mld)),
      missing_flow_pct = round(100 * sum(is.na(.data$flow_mld)) / dplyr::n(), 2),
      source_system_summary = paste(sort(unique(stats::na.omit(.data$source_system))), collapse = "; "),
      patch_status_summary = paste(sort(unique(stats::na.omit(.data$patch_status))), collapse = "; "),
      .groups = "drop"
    )
}

make_hydrology_import_checks <- function(daily, monthly, water_year, copied_files) {
  tibble::tibble(
    check_name = c(
      "daily_file_imported",
      "monthly_file_imported",
      "water_year_file_imported",
      "daily_no_duplicate_station_date",
      "monthly_no_duplicate_station_month",
      "water_year_no_duplicate_station_year",
      "flow_units_are_mld_or_ml",
      "provenance_fields_present",
      "all_gauges_have_recommended_use"
    ),
    status = c(
      ifelse(any(copied_files$product == "daily" & copied_files$copied), "pass", "fail"),
      ifelse(any(copied_files$product == "monthly" & copied_files$copied), "pass", "fail"),
      ifelse(any(copied_files$product == "water_year" & copied_files$copied), "pass", "fail"),
      ifelse(nrow(daily |> dplyr::count(.data$station_id, .data$date) |> dplyr::filter(.data$n > 1)) == 0, "pass", "fail"),
      ifelse(nrow(monthly |> dplyr::count(.data$station_id, .data$month_start) |> dplyr::filter(.data$n > 1)) == 0, "pass", "fail"),
      ifelse(nrow(water_year |> dplyr::count(.data$station_id, .data$water_year) |> dplyr::filter(.data$n > 1)) == 0, "pass", "fail"),
      ifelse(all(c("flow_mld", "flow_m3s") %in% names(daily)) && all(c("mean_flow_mld", "total_flow_ml") %in% names(water_year)), "pass", "fail"),
      ifelse(any(c("patch_status", "record_status") %in% names(daily)) && any(c("patch_source", "source_system") %in% names(daily)), "pass", "fail"),
      ifelse(all(!is.na(daily$recommended_use)), "pass", "fail")
    ),
    note = c(
      "Daily gauge CSV copied into Input/hydrology.",
      "Monthly gauge CSV copied into Input/hydrology.",
      "Water-year gauge CSV copied into Input/hydrology.",
      "Imported daily table must be unique by station_id/date.",
      "Imported monthly table must be unique by station_id/month_start.",
      "Imported water-year table must be unique by station_id/water_year.",
      "Daily/monthly mean flows in ML/day; totals in ML.",
      "Hydrology import must retain source/provenance and patch or record status fields.",
      "All imported gauge records must map to a provisional Gayini recommended_use role."
    )
  )
}
