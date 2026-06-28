# ------------------------------------------------------------------------------
# Script: scripts/09_qa/internal/02_check_curated_outputs_impl.R
# Purpose: Internal implementation module for 09_qa: check curated outputs
#          impl.
# Workflow stage: 09_qa
# Run mode: qa
# Heavy processing: no
# Key inputs:
#   - Inputs are supplied by the active wrapper or existing workflow outputs.
# Key outputs:
#   - Outputs are written by the implementation module for its active wrapper.
# Notes:
#   - Internal module; run the wrapper script in the parent folder unless
#     debugging.
#   - QA step should read existing products and avoid rebuilding outputs.
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Load configuration and execute workflow step
# ------------------------------------------------------------------------------

## Purpose:
## Lightweight QA checks for curated analysis-base outputs before moving to the
## next analysis step. This script reads existing CSVs only; it does no raster
## processing.


## User settings ----


root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", "D:/Github_repos/Gayini"), winslash = "/", mustWork = TRUE)
diagnostics_dir <- file.path(root_dir, "Output", "diagnostics", "07z_check_curated_outputs")


## Required packages ----


required_packages <- c(
  "dplyr",
  "tidyr",
  "readr",
  "stringr",
  "magrittr",
  "tibble"
)

source(file.path(root_dir, "R", "gayini_analysis_base_functions.R"))
gayini_check_packages(required_packages)

library(dplyr)
library(tidyr)
library(readr)
library(stringr)
library(magrittr)
library(tibble)


## Paths ----


dir.create(diagnostics_dir, recursive = TRUE, showWarnings = FALSE)

input_paths <- c(
  curated_ground_cover_timeseries = file.path(root_dir, "Output", "csv", "curated_ground_cover_timeseries.csv"),
  curated_annual_inundation_timeseries = file.path(root_dir, "Output", "csv", "curated_annual_inundation_timeseries.csv"),
  curated_daily_inundation_monthly = file.path(root_dir, "Output", "csv", "curated_daily_inundation_monthly.csv"),
  plot_rs_analysis_base = file.path(root_dir, "Output", "csv", "plot_rs_analysis_base.csv")
)

missing_inputs <- names(input_paths)[!file.exists(input_paths)]

if (length(missing_inputs) > 0) {
  stop(
    "Missing required curated output(s): ",
    paste(missing_inputs, collapse = ", "),
    call. = FALSE
  )
}

row_counts_path <- file.path(diagnostics_dir, "07z_row_counts.csv")
unique_plot_counts_path <- file.path(diagnostics_dir, "07z_unique_plot_counts.csv")
duplicate_checks_path <- file.path(diagnostics_dir, "07z_duplicate_key_checks.csv")
date_ranges_path <- file.path(diagnostics_dir, "07z_date_ranges.csv")
vegetation_group_counts_path <- file.path(diagnostics_dir, "07z_vegetation_group_counts.csv")
treatment_counts_path <- file.path(diagnostics_dir, "07z_treatment_counts.csv")
variable_ranges_path <- file.path(diagnostics_dir, "07z_variable_ranges.csv")
missingness_path <- file.path(diagnostics_dir, "07z_missingness_summary.csv")
handoff_report_path <- file.path(diagnostics_dir, "07z_codex_handoff_report.md")


## Helpers ----


read_curated <- function(path, dataset_name) {
  message("Reading ", dataset_name, ": ", path)

  readr::read_csv(path, show_col_types = FALSE) %>%
    gayini_standardise_plot_id(object_name = dataset_name)
}


write_diag <- function(x, path) {
  readr::write_csv(x, path)
  message("Wrote: ", path)
  invisible(x)
}


make_duplicate_check <- function(df, dataset_name, key_cols) {
  duplicate_keys <- df %>%
    dplyr::count(dplyr::across(dplyr::all_of(key_cols)), name = "n_rows") %>%
    dplyr::filter(.data$n_rows > 1)

  tibble::tibble(
    dataset = dataset_name,
    key_cols = paste(key_cols, collapse = ";"),
    n_rows = nrow(df),
    n_duplicate_keys = nrow(duplicate_keys),
    n_duplicate_rows = sum(duplicate_keys$n_rows),
    status = dplyr::if_else(nrow(duplicate_keys) == 0, "pass", "fail")
  )
}


make_date_range <- function(df, dataset_name, date_cols) {
  present_date_cols <- date_cols[date_cols %in% names(df)]

  if (length(present_date_cols) == 0) {
    return(tibble::tibble(
      dataset = dataset_name,
      date_column = NA_character_,
      min_date = as.Date(NA),
      max_date = as.Date(NA),
      n_non_missing = 0L
    ))
  }

  dplyr::bind_rows(lapply(present_date_cols, function(date_col) {
    date_values <- as.Date(df[[date_col]])

    tibble::tibble(
      dataset = dataset_name,
      date_column = date_col,
      min_date = suppressWarnings(min(date_values, na.rm = TRUE)),
      max_date = suppressWarnings(max(date_values, na.rm = TRUE)),
      n_non_missing = sum(!is.na(date_values))
    ) %>%
      dplyr::mutate(
        min_date = dplyr::if_else(is.infinite(as.numeric(.data$min_date)), as.Date(NA), .data$min_date),
        max_date = dplyr::if_else(is.infinite(as.numeric(.data$max_date)), as.Date(NA), .data$max_date)
      )
  }))
}


make_count_table <- function(df, dataset_name, count_col) {
  if (!count_col %in% names(df)) {
    return(tibble::tibble(
      dataset = dataset_name,
      variable = count_col,
      value = NA_character_,
      n_rows = 0L
    ))
  }

  df %>%
    dplyr::mutate(count_value = dplyr::coalesce(as.character(.data[[count_col]]), "<missing>")) %>%
    dplyr::count(.data$count_value, name = "n_rows") %>%
    dplyr::transmute(
      dataset = dataset_name,
      variable = count_col,
      value = .data$count_value,
      n_rows = .data$n_rows
    ) %>%
    dplyr::arrange(.data$dataset, .data$variable, .data$value)
}


make_variable_ranges <- function(df, dataset_name, variable_names, expected_min = 0, expected_max = 100) {
  present_variables <- variable_names[variable_names %in% names(df)]

  if (length(present_variables) == 0) {
    return(tibble::tibble(
      dataset = dataset_name,
      variable = NA_character_,
      n_non_missing = 0L,
      min_value = NA_real_,
      max_value = NA_real_,
      expected_min = expected_min,
      expected_max = expected_max,
      n_below_expected = 0L,
      n_above_expected = 0L,
      status = "not_checked_no_variables"
    ))
  }

  dplyr::bind_rows(lapply(present_variables, function(variable_name) {
    values <- suppressWarnings(as.numeric(df[[variable_name]]))

    tibble::tibble(
      dataset = dataset_name,
      variable = variable_name,
      n_non_missing = sum(!is.na(values)),
      min_value = suppressWarnings(min(values, na.rm = TRUE)),
      max_value = suppressWarnings(max(values, na.rm = TRUE)),
      expected_min = expected_min,
      expected_max = expected_max,
      n_below_expected = sum(values < expected_min, na.rm = TRUE),
      n_above_expected = sum(values > expected_max, na.rm = TRUE)
    ) %>%
      dplyr::mutate(
        min_value = dplyr::if_else(is.infinite(.data$min_value), NA_real_, .data$min_value),
        max_value = dplyr::if_else(is.infinite(.data$max_value), NA_real_, .data$max_value),
        status = dplyr::case_when(
          .data$n_below_expected > 0 | .data$n_above_expected > 0 ~ "warning_outside_expected_range",
          TRUE ~ "pass"
        )
      )
  }))
}


make_missingness <- function(df, dataset_name) {
  tibble::tibble(
    variable = names(df),
    n_rows = nrow(df),
    n_missing = vapply(df, function(x) sum(is.na(x)), integer(1)),
    pct_missing = if (nrow(df) == 0) NA_real_ else 100 * .data$n_missing / .data$n_rows
  ) %>%
    dplyr::mutate(dataset = dataset_name) %>%
    dplyr::select("dataset", "variable", "n_rows", "n_missing", "pct_missing")
}


make_report_lines <- function(row_counts,
                              duplicate_checks,
                              variable_ranges,
                              missingness_summary,
                              report_path) {
  failed_duplicate_checks <- duplicate_checks %>%
    dplyr::filter(.data$status != "pass")

  range_warnings <- variable_ranges %>%
    dplyr::filter(.data$status == "warning_outside_expected_range")

  high_missingness <- missingness_summary %>%
    dplyr::filter(.data$pct_missing >= 50) %>%
    dplyr::arrange(dplyr::desc(.data$pct_missing), .data$dataset, .data$variable)

  checks_passed <- nrow(failed_duplicate_checks) == 0 && nrow(range_warnings) == 0

  report_lines <- c(
    "# 07z Curated Output Handoff Report",
    "",
    paste0("Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
    "",
    "## Scope",
    "",
    "This report checks the four curated remote-sensing analysis-base outputs. It reads existing CSVs only and does not run raster processing.",
    "",
    "## Files Checked",
    "",
    paste0("- `", row_counts$path, "`: ", row_counts$n_rows, " rows, ", row_counts$n_cols, " columns"),
    "",
    "## Check Result",
    "",
    paste0("- Overall status: ", if (checks_passed) "PASS" else "REVIEW"),
    paste0("- Duplicate key checks failing: ", nrow(failed_duplicate_checks)),
    paste0("- Variable range warnings: ", nrow(range_warnings)),
    paste0("- Variables with >=50% missingness: ", nrow(high_missingness)),
    "",
    "## Diagnostics Written",
    "",
    "- `07z_row_counts.csv`",
    "- `07z_unique_plot_counts.csv`",
    "- `07z_duplicate_key_checks.csv`",
    "- `07z_date_ranges.csv`",
    "- `07z_vegetation_group_counts.csv`",
    "- `07z_treatment_counts.csv`",
    "- `07z_variable_ranges.csv`",
    "- `07z_missingness_summary.csv`",
    "",
    "## Recommended Next Task",
    "",
    "Use the curated analysis-base outputs to begin lightweight lag/missingness diagnostics before considering any BFAST/tbreak workflow."
  )

  if (nrow(failed_duplicate_checks) > 0) {
    report_lines <- c(
      report_lines,
      "",
      "## Duplicate Check Failures",
      "",
      paste0("- ", failed_duplicate_checks$dataset, " on `", failed_duplicate_checks$key_cols, "`")
    )
  }

  if (nrow(range_warnings) > 0) {
    report_lines <- c(
      report_lines,
      "",
      "## Variable Range Warnings",
      "",
      paste0("- ", range_warnings$dataset, "::", range_warnings$variable, " = ", range_warnings$min_value, " to ", range_warnings$max_value)
    )
  }

  readr::write_lines(report_lines, report_path)
  message("Wrote: ", report_path)

  invisible(tibble::tibble(checks_passed = checks_passed))
}


## Read inputs ----


curated_tables <- list(
  curated_ground_cover_timeseries = read_curated(input_paths[["curated_ground_cover_timeseries"]], "curated_ground_cover_timeseries"),
  curated_annual_inundation_timeseries = read_curated(input_paths[["curated_annual_inundation_timeseries"]], "curated_annual_inundation_timeseries"),
  curated_daily_inundation_monthly = read_curated(input_paths[["curated_daily_inundation_monthly"]], "curated_daily_inundation_monthly"),
  plot_rs_analysis_base = read_curated(input_paths[["plot_rs_analysis_base"]], "plot_rs_analysis_base")
)


## Diagnostics ----


row_counts <- dplyr::bind_rows(lapply(names(curated_tables), function(dataset_name) {
  df <- curated_tables[[dataset_name]]

  tibble::tibble(
    dataset = dataset_name,
    path = input_paths[[dataset_name]],
    n_rows = nrow(df),
    n_cols = ncol(df)
  )
}))

unique_plot_counts <- dplyr::bind_rows(lapply(names(curated_tables), function(dataset_name) {
  df <- curated_tables[[dataset_name]]

  tibble::tibble(
    dataset = dataset_name,
    n_rows = nrow(df),
    n_unique_plots = dplyr::n_distinct(df$plot_id),
    n_missing_plot_id = sum(is.na(df$plot_id) | df$plot_id == "")
  )
}))

duplicate_checks <- dplyr::bind_rows(
  make_duplicate_check(curated_tables$curated_ground_cover_timeseries, "curated_ground_cover_timeseries", c("plot_id", "date_midpoint")),
  make_duplicate_check(curated_tables$curated_annual_inundation_timeseries, "curated_annual_inundation_timeseries", c("plot_id", "water_year")),
  make_duplicate_check(curated_tables$curated_daily_inundation_monthly, "curated_daily_inundation_monthly", c("plot_id", "month_start")),
  make_duplicate_check(curated_tables$plot_rs_analysis_base, "plot_rs_analysis_base", c("plot_id"))
)

date_ranges <- dplyr::bind_rows(
  make_date_range(curated_tables$curated_ground_cover_timeseries, "curated_ground_cover_timeseries", c("date_midpoint")),
  make_date_range(curated_tables$curated_annual_inundation_timeseries, "curated_annual_inundation_timeseries", c("date_start", "date_end")),
  make_date_range(curated_tables$curated_daily_inundation_monthly, "curated_daily_inundation_monthly", c("month_start", "first_observation_date", "last_observation_date")),
  make_date_range(curated_tables$plot_rs_analysis_base, "plot_rs_analysis_base", c("ground_cover_first_date", "ground_cover_last_date", "conservation_date", "pre_start_date", "post_end_date"))
)

vegetation_group_counts <- dplyr::bind_rows(lapply(names(curated_tables), function(dataset_name) {
  make_count_table(curated_tables[[dataset_name]], dataset_name, "vegetation_adrian_group")
}))

treatment_counts <- dplyr::bind_rows(lapply(names(curated_tables), function(dataset_name) {
  make_count_table(curated_tables[[dataset_name]], dataset_name, "treatment")
}))

ground_cover_ranges <- make_variable_ranges(
  curated_tables$curated_ground_cover_timeseries,
  "curated_ground_cover_timeseries",
  c("bare_ground_pct", "green_pv_pct", "non_green_npv_pct", "total_veg_pct"),
  expected_min = 0,
  expected_max = 100
)

annual_inundation_ranges <- make_variable_ranges(
  curated_tables$curated_annual_inundation_timeseries,
  "curated_annual_inundation_timeseries",
  c(
    "inundated_any_pct",
    "count_0_area_pct",
    "count_1_area_pct",
    "count_2_area_pct",
    "count_3_area_pct",
    "other_count_area_pct",
    "valid_coverage_pct"
  ),
  expected_min = 0,
  expected_max = 100
)

daily_inundation_ranges <- make_variable_ranges(
  curated_tables$curated_daily_inundation_monthly,
  "curated_daily_inundation_monthly",
  c("mean_daily_inundated_pct", "max_daily_inundated_pct"),
  expected_min = 0,
  expected_max = 100
)

plot_base_pct_ranges <- make_variable_ranges(
  curated_tables$plot_rs_analysis_base,
  "plot_rs_analysis_base",
  c(
    "pre_conservation_inundation_frequency_pct",
    "post_conservation_inundation_frequency_pct",
    "pre_mean_total_veg_pct",
    "post_mean_total_veg_pct",
    "pre_mean_bare_ground_pct",
    "post_mean_bare_ground_pct",
    "pre_mean_annual_inundated_any_pct",
    "post_mean_annual_inundated_any_pct"
  ),
  expected_min = 0,
  expected_max = 100
)

plot_base_delta_ranges <- make_variable_ranges(
  curated_tables$plot_rs_analysis_base,
  "plot_rs_analysis_base",
  c(
    "post_minus_pre_inundation_frequency_pct_points",
    "delta_total_veg_pct",
    "delta_bare_ground_pct"
  ),
  expected_min = -100,
  expected_max = 100
)

variable_ranges <- dplyr::bind_rows(
  ground_cover_ranges,
  annual_inundation_ranges,
  daily_inundation_ranges,
  plot_base_pct_ranges,
  plot_base_delta_ranges
)

missingness_summary <- dplyr::bind_rows(lapply(names(curated_tables), function(dataset_name) {
  make_missingness(curated_tables[[dataset_name]], dataset_name)
}))


## Write diagnostics ----


write_diag(row_counts, row_counts_path)
write_diag(unique_plot_counts, unique_plot_counts_path)
write_diag(duplicate_checks, duplicate_checks_path)
write_diag(date_ranges, date_ranges_path)
write_diag(vegetation_group_counts, vegetation_group_counts_path)
write_diag(treatment_counts, treatment_counts_path)
write_diag(variable_ranges, variable_ranges_path)
write_diag(missingness_summary, missingness_path)

check_result <- make_report_lines(
  row_counts = row_counts,
  duplicate_checks = duplicate_checks,
  variable_ranges = variable_ranges,
  missingness_summary = missingness_summary,
  report_path = handoff_report_path
)

if (!check_result$checks_passed) {
  warning(
    "Curated output checks completed with review flags. See diagnostics: ",
    diagnostics_dir,
    call. = FALSE
  )
}

message("07z curated output checks complete.")
