# ------------------------------------------------------------------------------
# Script: scripts/09_qa/internal/01_check_prepost_inundation_raster_outputs_impl.R
# Purpose: Internal implementation module for 09_qa: check prepost inundation
#          raster outputs impl.
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
## Lightweight QA for existing pre/post inundation raster outputs. This script
## reads existing rasters and summaries only; it does not rebuild rasters.


## User settings ----


root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", "D:/Github_repos/Gayini"), winslash = "/", mustWork = TRUE)
PRE_YEARS <- 2014:2019
POST_YEARS <- 2020:2025
DIFF_TOLERANCE <- 1e-4
VALID_COVERAGE_ROUNDING_TOLERANCE <- 1


## Required packages ----


required_packages <- c(
  "terra",
  "dplyr",
  "tidyr",
  "readr",
  "stringr",
  "magrittr",
  "tibble"
)

source(file.path(root_dir, "R", "gayini_analysis_base_functions.R"))
gayini_check_packages(required_packages)

library(terra)
library(dplyr)
library(tidyr)
library(readr)
library(stringr)
library(magrittr)
library(tibble)


## Paths ----


raster_dir <- file.path(root_dir, "Output", "rasters", "inundation_pre_post")
annual_raster_dir <- file.path(raster_dir, "annual")
csv_dir <- file.path(root_dir, "Output", "csv")
diagnostics_dir <- file.path(root_dir, "Output", "diagnostics", "06z_check_prepost_inundation_raster_outputs")

dir.create(diagnostics_dir, recursive = TRUE, showWarnings = FALSE)

inventory_path <- file.path(diagnostics_dir, "06z_raster_file_inventory.csv")
value_ranges_path <- file.path(diagnostics_dir, "06z_raster_value_ranges.csv")
alignment_checks_path <- file.path(diagnostics_dir, "06z_raster_alignment_checks.csv")
logic_checks_path <- file.path(diagnostics_dir, "06z_raster_logic_checks.csv")
handoff_report_path <- file.path(diagnostics_dir, "06z_codex_handoff_report.md")

plot_summary_path <- gayini_find_first_existing(c(
  file.path(csv_dir, "07f_pre_post_inundation_plot_summary_fixed.csv"),
  file.path(root_dir, "data_processed", "plot_pre_post_inundation_frequency_fixed.csv"),
  file.path(csv_dir, "07e_pre_post_inundation_plot_summary.csv"),
  file.path(root_dir, "data_processed", "plot_pre_post_inundation_frequency.csv")
))

coverage_summary_path <- gayini_find_first_existing(c(
  file.path(csv_dir, "curated_annual_inundation_timeseries.csv"),
  file.path(root_dir, "data_processed", "plot_landsat_inundation_timeseries.csv"),
  file.path(csv_dir, "05c_landsat_inundation_full.csv")
))


## Helpers ----


write_csv_message <- function(x, path) {
  readr::write_csv(x, path)
  message("Wrote: ", path)
  invisible(x)
}


status_from_bool <- function(x) {
  dplyr::if_else(isTRUE(x), "pass", "fail")
}


safe_rast <- function(path) {
  if (is.na(path) || !file.exists(path)) {
    return(NULL)
  }

  terra::rast(path)
}


raster_non_na_count <- function(r) {
  if (is.null(r)) {
    return(NA_real_)
  }

  out <- terra::global(!is.na(r), "sum", na.rm = TRUE)
  as.numeric(out[1, 1])
}


raster_value_summary <- function(key, path, expected_min = NA_real_, expected_max = NA_real_, binary_expected = FALSE) {
  if (is.na(path) || !file.exists(path)) {
    return(tibble::tibble(
      raster_key = key,
      path = path,
      min_value = NA_real_,
      max_value = NA_real_,
      non_na_cells = NA_real_,
      unique_values = NA_character_,
      expected_min = expected_min,
      expected_max = expected_max,
      binary_expected = binary_expected,
      status = "missing_file",
      note = "Raster file not found."
    ))
  }

  r <- terra::rast(path)
  minmax <- terra::global(r, c("min", "max"), na.rm = TRUE)
  non_na <- raster_non_na_count(r)
  freq <- tryCatch(terra::freq(r, digits = 12), error = function(e) NULL)
  unique_values <- if (is.null(freq) || !"value" %in% names(freq)) {
    NA_character_
  } else {
    paste(sort(unique(freq$value)), collapse = ";")
  }

  min_value <- as.numeric(minmax[1, "min"])
  max_value <- as.numeric(minmax[1, "max"])

  status <- "pass"
  note <- "Values within expected range."

  if (is.na(non_na) || non_na == 0) {
    status <- "fail"
    note <- "Raster is all NA or has no non-NA cells."
  } else if (binary_expected && !is.null(freq) && any(!freq$value %in% c(0, 1))) {
    status <- "fail"
    note <- "Binary annual raster contains values other than 0/1/NA."
  } else if (!is.na(expected_min) && !is.na(min_value) && min_value < expected_min) {
    status <- "fail"
    note <- "Raster minimum is below expected range."
  } else if (!is.na(expected_max) && !is.na(max_value) && max_value > expected_max) {
    status <- "fail"
    note <- "Raster maximum is above expected range."
  }

  tibble::tibble(
    raster_key = key,
    path = path,
    min_value = min_value,
    max_value = max_value,
    non_na_cells = non_na,
    unique_values = unique_values,
    expected_min = expected_min,
    expected_max = expected_max,
    binary_expected = binary_expected,
    status = status,
    note = note
  )
}


make_alignment_row <- function(reference_path, key, path) {
  if (!file.exists(reference_path) || !file.exists(path)) {
    return(tibble::tibble(
      reference_key = "pre_conservation_inundation_frequency_pct",
      raster_key = key,
      path = path,
      aligned = FALSE,
      status = "missing_file",
      note = "Reference or target raster missing."
    ))
  }

  reference <- terra::rast(reference_path)
  target <- terra::rast(path)
  aligned <- isTRUE(terra::compareGeom(reference, target, stopOnError = FALSE))

  tibble::tibble(
    reference_key = "pre_conservation_inundation_frequency_pct",
    raster_key = key,
    path = path,
    aligned = aligned,
    status = status_from_bool(aligned),
    note = dplyr::if_else(aligned, "Geometry aligned with reference raster.", "Geometry differs from reference raster.")
  )
}


logic_row <- function(check, status, value = NA_character_, note = NA_character_) {
  tibble::tibble(
    check = check,
    status = status,
    value = as.character(value),
    note = note
  )
}


range_check_plot_summary <- function(plot_summary, variable, expected_min, expected_max) {
  if (!variable %in% names(plot_summary)) {
    return(logic_row(
      paste0("plot_summary_", variable, "_range"),
      "review",
      "not_present",
      "Variable not present in plot summary."
    ))
  }

  values <- suppressWarnings(as.numeric(plot_summary[[variable]]))
  min_value <- min(values, na.rm = TRUE)
  max_value <- max(values, na.rm = TRUE)
  ok <- !is.infinite(min_value) && !is.infinite(max_value) &&
    min_value >= expected_min && max_value <= expected_max

  logic_row(
    paste0("plot_summary_", variable, "_range"),
    status_from_bool(ok),
    paste0(round(min_value, 6), " to ", round(max_value, 6)),
    paste0("Expected range: ", expected_min, " to ", expected_max, ".")
  )
}


## Expected raster inventory ----


required_rasters <- tibble::tibble(
  raster_key = c(
    "pre_conservation_inundation_frequency_pct",
    "post_conservation_inundation_frequency_pct",
    "post_minus_pre_inundation_frequency_pct_points",
    "pre_conservation_wet_year_count",
    "pre_conservation_valid_year_count",
    "post_conservation_wet_year_count",
    "post_conservation_valid_year_count"
  ),
  raster_role = c(
    "period_frequency",
    "period_frequency",
    "difference",
    "wet_year_count",
    "valid_year_count",
    "wet_year_count",
    "valid_year_count"
  ),
  path = file.path(raster_dir, paste0(raster_key, ".tif"))
)

annual_expected <- dplyr::bind_rows(
  tibble::tibble(period = "pre_conservation", year = PRE_YEARS),
  tibble::tibble(period = "post_conservation", year = POST_YEARS)
) %>%
  tidyr::expand_grid(raster_type = c("annual_inundated_any", "annual_valid_any")) %>%
  dplyr::mutate(
    raster_key = paste0(.data$raster_type, "_", .data$period, "__", .data$year),
    raster_role = .data$raster_type,
    path = file.path(annual_raster_dir, paste0(.data$raster_key, ".tif"))
  ) %>%
  dplyr::select("raster_key", "raster_role", "raster_type", "period", "year", "path")

raster_inventory <- dplyr::bind_rows(
  required_rasters %>%
    dplyr::mutate(raster_type = NA_character_, period = NA_character_, year = NA_integer_),
  annual_expected
) %>%
  dplyr::mutate(
    exists = file.exists(.data$path),
    file_size_bytes = dplyr::if_else(.data$exists, file.info(.data$path)$size, NA_real_),
    last_write_time = dplyr::if_else(.data$exists, as.character(file.info(.data$path)$mtime), NA_character_)
  )

write_csv_message(raster_inventory, inventory_path)


## Value ranges ----


range_specs <- raster_inventory %>%
  dplyr::mutate(
    expected_min = dplyr::case_when(
      .data$raster_role == "difference" ~ -100,
      TRUE ~ 0
    ),
    expected_max = dplyr::case_when(
      .data$raster_role == "difference" ~ 100,
      .data$raster_role %in% c("annual_inundated_any", "annual_valid_any") ~ 1,
      TRUE ~ 100
    ),
    binary_expected = .data$raster_role %in% c("annual_inundated_any", "annual_valid_any")
  )

raster_value_ranges <- dplyr::bind_rows(lapply(seq_len(nrow(range_specs)), function(i) {
  raster_value_summary(
    key = range_specs$raster_key[[i]],
    path = range_specs$path[[i]],
    expected_min = range_specs$expected_min[[i]],
    expected_max = range_specs$expected_max[[i]],
    binary_expected = range_specs$binary_expected[[i]]
  )
}))

write_csv_message(raster_value_ranges, value_ranges_path)


## Alignment checks ----


reference_path <- required_rasters$path[required_rasters$raster_key == "pre_conservation_inundation_frequency_pct"][[1]]

raster_alignment_checks <- dplyr::bind_rows(lapply(seq_len(nrow(raster_inventory)), function(i) {
  make_alignment_row(
    reference_path = reference_path,
    key = raster_inventory$raster_key[[i]],
    path = raster_inventory$path[[i]]
  )
}))

write_csv_message(raster_alignment_checks, alignment_checks_path)


## Logic checks ----


pre_freq <- safe_rast(required_rasters$path[required_rasters$raster_key == "pre_conservation_inundation_frequency_pct"][[1]])
post_freq <- safe_rast(required_rasters$path[required_rasters$raster_key == "post_conservation_inundation_frequency_pct"][[1]])
diff_freq <- safe_rast(required_rasters$path[required_rasters$raster_key == "post_minus_pre_inundation_frequency_pct_points"][[1]])
pre_wet <- safe_rast(required_rasters$path[required_rasters$raster_key == "pre_conservation_wet_year_count"][[1]])
pre_valid <- safe_rast(required_rasters$path[required_rasters$raster_key == "pre_conservation_valid_year_count"][[1]])
post_wet <- safe_rast(required_rasters$path[required_rasters$raster_key == "post_conservation_wet_year_count"][[1]])
post_valid <- safe_rast(required_rasters$path[required_rasters$raster_key == "post_conservation_valid_year_count"][[1]])

required_file_checks <- raster_inventory %>%
  dplyr::mutate(
    check = paste0("file_exists_", .data$raster_key),
    status = dplyr::if_else(.data$exists, "pass", "fail"),
    value = as.character(.data$exists),
    note = .data$path
  ) %>%
  dplyr::select("check", "status", "value", "note")

annual_year_checks <- annual_expected %>%
  dplyr::group_by(.data$period, .data$raster_type) %>%
  dplyr::summarise(
    expected_years = paste(.data$year, collapse = ";"),
    present_years = paste(.data$year[file.exists(.data$path)], collapse = ";"),
    n_missing = sum(!file.exists(.data$path)),
    .groups = "drop"
  ) %>%
  dplyr::transmute(
    check = paste0("annual_years_present_", .data$raster_type, "_", .data$period),
    status = dplyr::if_else(.data$n_missing == 0, "pass", "fail"),
    value = paste0("present=", .data$present_years, "; expected=", .data$expected_years),
    note = dplyr::if_else(.data$n_missing == 0, "All expected annual rasters present.", paste0(.data$n_missing, " expected annual raster(s) missing."))
  )

wet_valid_checks <- dplyr::bind_rows(
  if (!is.null(pre_wet) && !is.null(pre_valid)) {
    bad <- terra::global(terra::ifel(pre_wet > pre_valid, 1, 0), "sum", na.rm = TRUE)[1, 1]
    logic_row("pre_wet_year_count_not_greater_than_valid_year_count", status_from_bool(bad == 0), bad, "Wet-year counts should not exceed valid-year counts.")
  },
  if (!is.null(post_wet) && !is.null(post_valid)) {
    bad <- terra::global(terra::ifel(post_wet > post_valid, 1, 0), "sum", na.rm = TRUE)[1, 1]
    logic_row("post_wet_year_count_not_greater_than_valid_year_count", status_from_bool(bad == 0), bad, "Wet-year counts should not exceed valid-year counts.")
  }
)

diff_check <- if (!is.null(pre_freq) && !is.null(post_freq) && !is.null(diff_freq)) {
  max_abs_diff <- terra::global(abs((post_freq - pre_freq) - diff_freq), "max", na.rm = TRUE)[1, 1]
  logic_row(
    "post_minus_pre_equals_post_frequency_minus_pre_frequency",
    status_from_bool(!is.na(max_abs_diff) && max_abs_diff <= DIFF_TOLERANCE),
    round(max_abs_diff, 8),
    paste0("Tolerance = ", DIFF_TOLERANCE, ".")
  )
} else {
  logic_row(
    "post_minus_pre_equals_post_frequency_minus_pre_frequency",
    "fail",
    "missing_inputs",
    "Could not run difference check because one or more required rasters are missing."
  )
}

annual_valid_any_note <- logic_row(
  "annual_valid_any_interpretation",
  "info",
  "valid coverage support",
  "annual_valid_any rasters indicate valid coverage support; they do not indicate flooding."
)

plot_summary_checks <- if (!is.na(plot_summary_path) && file.exists(plot_summary_path)) {
  plot_summary <- readr::read_csv(plot_summary_path, show_col_types = FALSE)

  dplyr::bind_rows(
    range_check_plot_summary(plot_summary, "pre_conservation_inundation_frequency_pct", 0, 100),
    range_check_plot_summary(plot_summary, "post_conservation_inundation_frequency_pct", 0, 100),
    range_check_plot_summary(plot_summary, "post_minus_pre_inundation_frequency_pct_points", -100, 100),
    range_check_plot_summary(plot_summary, "pre_conservation_valid_year_count", 0, Inf),
    range_check_plot_summary(plot_summary, "post_conservation_valid_year_count", 0, Inf)
  )
} else {
  logic_row(
    "plot_summary_present",
    "fail",
    "missing",
    "No pre/post plot summary found."
  )
}

coverage_rounding_checks <- if (!is.na(coverage_summary_path) && file.exists(coverage_summary_path)) {
  coverage_summary <- readr::read_csv(coverage_summary_path, show_col_types = FALSE)

  if ("valid_coverage_pct" %in% names(coverage_summary)) {
    values <- suppressWarnings(as.numeric(coverage_summary$valid_coverage_pct))
    n_over_100 <- sum(values > 100, na.rm = TRUE)
    max_value <- max(values, na.rm = TRUE)
    status <- dplyr::case_when(
      n_over_100 == 0 ~ "pass",
      max_value <= 100 + VALID_COVERAGE_ROUNDING_TOLERANCE ~ "review",
      TRUE ~ "fail"
    )

    logic_row(
      "valid_coverage_pct_slightly_over_100",
      status,
      paste0("n_over_100=", n_over_100, "; max=", round(max_value, 6)),
      "Values slightly over 100 are flagged as likely area-rounding artefacts, not silently ignored."
    )
  } else {
    logic_row(
      "valid_coverage_pct_slightly_over_100",
      "info",
      "not_present",
      "No valid_coverage_pct column found in optional coverage summary source."
    )
  }
} else {
  logic_row(
    "valid_coverage_pct_slightly_over_100",
    "info",
    "coverage_summary_missing",
    "No optional coverage summary source found."
  )
}

range_logic_checks <- raster_value_ranges %>%
  dplyr::transmute(
    check = paste0("value_range_", .data$raster_key),
    status = .data$status,
    value = paste0(.data$min_value, " to ", .data$max_value, "; non_na=", .data$non_na_cells),
    note = .data$note
  )

alignment_logic_checks <- raster_alignment_checks %>%
  dplyr::transmute(
    check = paste0("alignment_", .data$raster_key),
    status = .data$status,
    value = as.character(.data$aligned),
    note = .data$note
  )

raster_logic_checks <- dplyr::bind_rows(
  required_file_checks,
  annual_year_checks,
  range_logic_checks,
  alignment_logic_checks,
  wet_valid_checks,
  diff_check,
  annual_valid_any_note,
  plot_summary_checks,
  coverage_rounding_checks
)

write_csv_message(raster_logic_checks, logic_checks_path)


## Handoff report ----


n_fail <- sum(raster_logic_checks$status == "fail", na.rm = TRUE)
n_review <- sum(raster_logic_checks$status == "review", na.rm = TRUE)
overall_status <- dplyr::case_when(
  n_fail > 0 ~ "FAIL",
  n_review > 0 ~ "REVIEW",
  TRUE ~ "PASS"
)

report_lines <- c(
  "# 06z Pre/Post Inundation Raster QA Handoff Report",
  "",
  paste0("Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
  "",
  "## Scope",
  "",
  "This script reads existing pre/post inundation raster outputs and summaries only. It does not rebuild rasters.",
  "",
  "## Status",
  "",
  paste0("- Overall status: ", overall_status),
  paste0("- Failed checks: ", n_fail),
  paste0("- Review checks: ", n_review),
  paste0("- Raster inventory rows: ", nrow(raster_inventory)),
  "",
  "## Outputs",
  "",
  paste0("- `", inventory_path, "`"),
  paste0("- `", value_ranges_path, "`"),
  paste0("- `", alignment_checks_path, "`"),
  paste0("- `", logic_checks_path, "`"),
  "",
  "## Notes",
  "",
  "- annual_valid_any rasters are valid coverage support, not flooding.",
  "- Inundation frequency values are expected in 0-100.",
  "- Post-minus-pre differences are expected in -100 to 100 percentage points.",
  "- valid_coverage_pct values slightly over 100 are flagged as likely area-rounding artefacts.",
  "",
  "## Recommended Next Task",
  "",
  "Review any FAIL or REVIEW rows before using the pre/post rasters in presentation figures or downstream diagnostics."
)

if (n_fail > 0 || n_review > 0) {
  flagged <- raster_logic_checks %>%
    dplyr::filter(.data$status %in% c("fail", "review")) %>%
    dplyr::mutate(line = paste0("- ", .data$status, ": ", .data$check, " (", .data$value, ")"))

  report_lines <- c(
    report_lines,
    "",
    "## Flagged Checks",
    "",
    flagged$line
  )
}

readr::write_lines(report_lines, handoff_report_path)
message("Wrote: ", handoff_report_path)

if (overall_status == "FAIL") {
  warning("06z completed with failed checks. See: ", logic_checks_path, call. = FALSE)
} else if (overall_status == "REVIEW") {
  warning("06z completed with review checks. See: ", logic_checks_path, call. = FALSE)
}

message("06z pre/post inundation raster QA complete.")
