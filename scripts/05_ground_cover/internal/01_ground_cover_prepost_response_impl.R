# ------------------------------------------------------------------------------
# Script: scripts/05_ground_cover/internal/01_ground_cover_prepost_response_impl.R
# Purpose: Internal implementation module for 05_ground_cover: ground cover
#          prepost response impl.
# Workflow stage: 05_ground_cover
# Run mode: lightweight_review
# Heavy processing: no
# Key inputs:
#   - Inputs are supplied by the active wrapper or existing workflow outputs.
# Key outputs:
#   - Outputs are written by the implementation module for its active wrapper.
# Notes:
#   - Internal module; run the wrapper script in the parent folder unless
#     debugging.
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Load configuration and execute workflow step
# ------------------------------------------------------------------------------

## Purpose:
## Create a first-pass ground-cover pre/post response analysis from curated CSV
## outputs only. This script does not do raster processing.


## User settings ----


root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", "D:/Github_repos/Gayini"), winslash = "/", mustWork = TRUE)
MIN_PRE_SEASONS <- 3L
MIN_POST_SEASONS <- 3L
STRONG_TOTAL_VEG_DELTA_PCT <- 10
STRONG_BARE_DELTA_PCT <- 10
WETTER_POST_THRESHOLD_PCT_POINTS <- 5
RARELY_INUNDATED_THRESHOLD_PCT <- 5
RUN_SECONDARY_TREATMENT_SANITY_MODELS <- TRUE


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


csv_dir <- file.path(root_dir, "Output", "csv")
diagnostics_dir <- file.path(root_dir, "Output", "diagnostics", "10a_ground_cover_prepost_response")

dir.create(csv_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(diagnostics_dir, recursive = TRUE, showWarnings = FALSE)

ground_cover_path <- file.path(csv_dir, "curated_ground_cover_timeseries.csv")
plot_base_path <- file.path(csv_dir, "plot_rs_analysis_base.csv")

plot_summary_path <- file.path(csv_dir, "10a_ground_cover_prepost_plot_summary.csv")
group_summary_path <- file.path(csv_dir, "10a_ground_cover_prepost_group_summary.csv")
model_summary_path <- file.path(csv_dir, "10a_ground_cover_prepost_model_summary.csv")

row_counts_path <- file.path(diagnostics_dir, "10a_row_counts.csv")
variable_ranges_path <- file.path(diagnostics_dir, "10a_variable_ranges.csv")
review_flags_path <- file.path(diagnostics_dir, "10a_review_flags.csv")
handoff_report_path <- file.path(diagnostics_dir, "10a_codex_handoff_report.md")

input_paths <- c(
  curated_ground_cover_timeseries = ground_cover_path,
  plot_rs_analysis_base = plot_base_path
)

missing_inputs <- names(input_paths)[!file.exists(input_paths)]

if (length(missing_inputs) > 0) {
  stop(
    "Missing required curated input(s): ",
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


make_plot_period_summary <- function(ground_cover) {
  ground_cover %>%
    dplyr::filter(.data$period %in% c("pre_conservation", "post_conservation")) %>%
    dplyr::group_by(.data$plot_id, .data$period) %>%
    dplyr::summarise(
      n_seasons = dplyr::n_distinct(.data$date_midpoint),
      mean_total_veg_pct = safe_mean(.data$total_veg_pct),
      mean_bare_ground_pct = safe_mean(.data$bare_ground_pct),
      median_total_veg_pct = safe_median(.data$total_veg_pct),
      median_bare_ground_pct = safe_median(.data$bare_ground_pct),
      .groups = "drop"
    ) %>%
    tidyr::pivot_wider(
      names_from = "period",
      values_from = c(
        "n_seasons",
        "mean_total_veg_pct",
        "mean_bare_ground_pct",
        "median_total_veg_pct",
        "median_bare_ground_pct"
      ),
      names_glue = "{period}_{.value}"
    ) %>%
    dplyr::rename(
      n_pre_seasons = "pre_conservation_n_seasons",
      n_post_seasons = "post_conservation_n_seasons",
      pre_mean_total_veg_pct = "pre_conservation_mean_total_veg_pct",
      post_mean_total_veg_pct = "post_conservation_mean_total_veg_pct",
      pre_mean_bare_ground_pct = "pre_conservation_mean_bare_ground_pct",
      post_mean_bare_ground_pct = "post_conservation_mean_bare_ground_pct",
      pre_median_total_veg_pct = "pre_conservation_median_total_veg_pct",
      post_median_total_veg_pct = "post_conservation_median_total_veg_pct",
      pre_median_bare_ground_pct = "pre_conservation_median_bare_ground_pct",
      post_median_bare_ground_pct = "post_conservation_median_bare_ground_pct"
    ) %>%
    dplyr::mutate(
      n_pre_seasons = dplyr::coalesce(.data$n_pre_seasons, 0L),
      n_post_seasons = dplyr::coalesce(.data$n_post_seasons, 0L),
      delta_total_veg_pct = .data$post_mean_total_veg_pct - .data$pre_mean_total_veg_pct,
      delta_bare_ground_pct = .data$post_mean_bare_ground_pct - .data$pre_mean_bare_ground_pct
    )
}


add_review_flags <- function(plot_summary) {
  plot_summary %>%
    dplyr::mutate(
      low_pre_gc_support = .data$n_pre_seasons < MIN_PRE_SEASONS,
      low_post_gc_support = .data$n_post_seasons < MIN_POST_SEASONS,
      strong_total_veg_increase = .data$delta_total_veg_pct >= STRONG_TOTAL_VEG_DELTA_PCT,
      strong_total_veg_decrease = .data$delta_total_veg_pct <= -STRONG_TOTAL_VEG_DELTA_PCT,
      strong_bare_increase = .data$delta_bare_ground_pct >= STRONG_BARE_DELTA_PCT,
      strong_bare_decrease = .data$delta_bare_ground_pct <= -STRONG_BARE_DELTA_PCT,
      wetter_post_and_greener = .data$post_minus_pre_inundation_frequency_pct_points >= WETTER_POST_THRESHOLD_PCT_POINTS &
        .data$delta_total_veg_pct >= STRONG_TOTAL_VEG_DELTA_PCT,
      wetter_post_and_barer = .data$post_minus_pre_inundation_frequency_pct_points >= WETTER_POST_THRESHOLD_PCT_POINTS &
        .data$delta_bare_ground_pct >= STRONG_BARE_DELTA_PCT,
      rarely_inundated = .data$pre_conservation_inundation_frequency_pct < RARELY_INUNDATED_THRESHOLD_PCT &
        .data$post_conservation_inundation_frequency_pct < RARELY_INUNDATED_THRESHOLD_PCT
    )
}


summarise_group <- function(df, group_cols, group_type) {
  df %>%
    dplyr::group_by(dplyr::across(dplyr::all_of(group_cols))) %>%
    dplyr::summarise(
      n_plots = dplyr::n(),
      n_low_pre_gc_support = sum(.data$low_pre_gc_support, na.rm = TRUE),
      n_low_post_gc_support = sum(.data$low_post_gc_support, na.rm = TRUE),
      mean_delta_total_veg_pct = safe_mean(.data$delta_total_veg_pct),
      median_delta_total_veg_pct = safe_median(.data$delta_total_veg_pct),
      mean_delta_bare_ground_pct = safe_mean(.data$delta_bare_ground_pct),
      median_delta_bare_ground_pct = safe_median(.data$delta_bare_ground_pct),
      mean_inundation_delta_pct_points = safe_mean(.data$post_minus_pre_inundation_frequency_pct_points),
      n_strong_total_veg_increase = sum(.data$strong_total_veg_increase, na.rm = TRUE),
      n_strong_total_veg_decrease = sum(.data$strong_total_veg_decrease, na.rm = TRUE),
      n_strong_bare_increase = sum(.data$strong_bare_increase, na.rm = TRUE),
      n_strong_bare_decrease = sum(.data$strong_bare_decrease, na.rm = TRUE),
      n_wetter_post_and_greener = sum(.data$wetter_post_and_greener, na.rm = TRUE),
      n_wetter_post_and_barer = sum(.data$wetter_post_and_barer, na.rm = TRUE),
      n_rarely_inundated = sum(.data$rarely_inundated, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    dplyr::mutate(
      group_type = group_type,
      group_label = do.call(paste, c(dplyr::select(., dplyr::all_of(group_cols)), sep = " | "))
    ) %>%
    dplyr::select("group_type", "group_label", dplyr::all_of(group_cols), dplyr::everything())
}


tidy_lm_summary <- function(model_data, formula, model_name, response_variable, model_role) {
  complete_data <- stats::model.frame(formula, data = model_data, na.action = stats::na.omit)

  if (nrow(complete_data) < 10) {
    return(tibble::tibble(
      model_name = model_name,
      model_role = model_role,
      response_variable = response_variable,
      term = NA_character_,
      estimate = NA_real_,
      std_error = NA_real_,
      statistic = NA_real_,
      p_value = NA_real_,
      n_obs = nrow(complete_data),
      r_squared = NA_real_,
      adjusted_r_squared = NA_real_,
      model_status = "not_run_too_few_complete_cases"
    ))
  }

  fit <- stats::lm(formula, data = complete_data)
  fit_summary <- summary(fit)
  coef_df <- as.data.frame(fit_summary$coefficients)

  tibble::tibble(
    model_name = model_name,
    model_role = model_role,
    response_variable = response_variable,
    term = rownames(coef_df),
    estimate = coef_df[["Estimate"]],
    std_error = coef_df[["Std. Error"]],
    statistic = coef_df[["t value"]],
    p_value = coef_df[["Pr(>|t|)"]],
    n_obs = stats::nobs(fit),
    r_squared = unname(fit_summary$r.squared),
    adjusted_r_squared = unname(fit_summary$adj.r.squared),
    model_status = "run"
  )
}


make_variable_ranges <- function(df, variables, expected_min, expected_max) {
  dplyr::bind_rows(lapply(variables, function(variable_name) {
    values <- suppressWarnings(as.numeric(df[[variable_name]]))

    tibble::tibble(
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
          .data$n_below_expected > 0 | .data$n_above_expected > 0 ~ "review",
          TRUE ~ "pass"
        )
      )
  }))
}


make_handoff_report <- function(row_counts,
                                variable_ranges,
                                review_flags,
                                model_summary,
                                report_path) {
  range_reviews <- variable_ranges %>%
    dplyr::filter(.data$status != "pass")

  model_status_counts <- model_summary %>%
    dplyr::distinct(.data$model_name, .data$model_status) %>%
    dplyr::count(.data$model_status, name = "n_models")

  status <- dplyr::case_when(
    nrow(range_reviews) > 0 ~ "REVIEW",
    any(model_summary$model_status != "run") ~ "REVIEW",
    TRUE ~ "PASS"
  )

  report_lines <- c(
    "# 10a Ground-Cover Pre/Post Response Handoff Report",
    "",
    paste0("Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
    "",
    "## Scope",
    "",
    "Step 10a summarises plot-level pre/post changes in total vegetation and bare ground using curated CSV outputs only.",
    "",
    "## Inputs",
    "",
    paste0("- `", ground_cover_path, "`"),
    paste0("- `", plot_base_path, "`"),
    "",
    "## Outputs",
    "",
    paste0("- `", plot_summary_path, "`"),
    paste0("- `", group_summary_path, "`"),
    paste0("- `", model_summary_path, "`"),
    paste0("- `", row_counts_path, "`"),
    paste0("- `", variable_ranges_path, "`"),
    paste0("- `", review_flags_path, "`"),
    "",
    "## Status",
    "",
    paste0("- Overall status: ", status),
    paste0("- Variable range review rows: ", nrow(range_reviews)),
    paste0("- Models run: ", sum(model_status_counts$n_models[model_status_counts$model_status == "run"] %||% 0)),
    "",
    "## Row Counts",
    "",
    paste0("- ", row_counts$dataset, ": ", row_counts$n_rows, " rows, ", row_counts$n_cols, " columns"),
    "",
    "## Review Flag Totals",
    "",
    paste0("- ", review_flags$review_flag, ": ", review_flags$n_flagged),
    "",
    "## Interpretation Cautions",
    "",
    "- Ground-cover response is descriptive screening, not proof of causality.",
    "- Inundation frequency is annual occurrence frequency, not hydroperiod, duration, depth, or wet days.",
    "- Treatment is retained as metadata and optional sanity-check factor, not the primary causal story.",
    "- Ground-cover estimates may be uncertain in treed or woody plots.",
    "",
    "## Recommended Next Task",
    "",
    "Use the 10a plot summary to build presentation-oriented Step 10 figures and then inspect lag diagnostics before any BFAST/tbreak decision."
  )

  if (nrow(range_reviews) > 0) {
    report_lines <- c(
      report_lines,
      "",
      "## Range Review Rows",
      "",
      paste0("- ", range_reviews$variable, ": ", range_reviews$min_value, " to ", range_reviews$max_value)
    )
  }

  readr::write_lines(report_lines, report_path)
  message("Wrote: ", report_path)

  invisible(status)
}


## Read inputs ----


message("Reading curated ground cover: ", ground_cover_path)
ground_cover <- readr::read_csv(ground_cover_path, show_col_types = FALSE) %>%
  gayini_standardise_plot_id(object_name = "curated ground-cover timeseries")

message("Reading plot analysis base: ", plot_base_path)
plot_base <- readr::read_csv(plot_base_path, show_col_types = FALSE) %>%
  gayini_standardise_plot_id(object_name = "plot analysis base")

require_columns(
  ground_cover,
  c("plot_id", "date_midpoint", "period", "total_veg_pct", "bare_ground_pct"),
  "curated ground-cover timeseries"
)

require_columns(
  plot_base,
  c(
    "plot_id",
    "pre_conservation_inundation_frequency_pct",
    "post_conservation_inundation_frequency_pct",
    "post_minus_pre_inundation_frequency_pct_points",
    "inundation_change_class",
    "treatment",
    "vegetation_adrian_group"
  ),
  "plot analysis base"
)

ground_cover <- ground_cover %>%
  dplyr::mutate(
    date_midpoint = as.Date(.data$date_midpoint),
    total_veg_pct = as.numeric(.data$total_veg_pct),
    bare_ground_pct = as.numeric(.data$bare_ground_pct)
  )


## Plot-level pre/post response ----


plot_period_summary <- make_plot_period_summary(ground_cover)

inundation_context <- plot_base %>%
  dplyr::select(
    "plot_id",
    "pre_conservation_inundation_frequency_pct",
    "post_conservation_inundation_frequency_pct",
    "post_minus_pre_inundation_frequency_pct_points",
    "inundation_change_class",
    "treatment",
    "vegetation_adrian_group"
  ) %>%
  dplyr::distinct(.data$plot_id, .keep_all = TRUE)

plot_summary <- plot_period_summary %>%
  dplyr::left_join(inundation_context, by = "plot_id") %>%
  add_review_flags() %>%
  dplyr::select(
    "plot_id",
    "treatment",
    "vegetation_adrian_group",
    "inundation_change_class",
    "pre_conservation_inundation_frequency_pct",
    "post_conservation_inundation_frequency_pct",
    "post_minus_pre_inundation_frequency_pct_points",
    "n_pre_seasons",
    "n_post_seasons",
    "pre_mean_total_veg_pct",
    "post_mean_total_veg_pct",
    "delta_total_veg_pct",
    "pre_mean_bare_ground_pct",
    "post_mean_bare_ground_pct",
    "delta_bare_ground_pct",
    "pre_median_total_veg_pct",
    "post_median_total_veg_pct",
    "pre_median_bare_ground_pct",
    "post_median_bare_ground_pct",
    "low_pre_gc_support",
    "low_post_gc_support",
    "strong_total_veg_increase",
    "strong_total_veg_decrease",
    "strong_bare_increase",
    "strong_bare_decrease",
    "wetter_post_and_greener",
    "wetter_post_and_barer",
    "rarely_inundated"
  ) %>%
  dplyr::arrange(.data$vegetation_adrian_group, .data$plot_id)

plot_summary_duplicate_keys <- plot_summary %>%
  dplyr::count(.data$plot_id, name = "n_rows") %>%
  dplyr::filter(.data$n_rows > 1)

if (nrow(plot_summary_duplicate_keys) > 0) {
  stop("10a plot summary has duplicate plot_id rows.", call. = FALSE)
}

write_csv_message(plot_summary, plot_summary_path)


## Group summaries ----


primary_group_summary <- summarise_group(
  plot_summary,
  group_cols = c("vegetation_adrian_group", "inundation_change_class"),
  group_type = "primary_vegetation_by_inundation_change"
)

secondary_treatment_group_summary <- summarise_group(
  plot_summary,
  group_cols = c("treatment"),
  group_type = "secondary_treatment_sanity_check"
)

group_summary <- dplyr::bind_rows(
  primary_group_summary,
  secondary_treatment_group_summary
) %>%
  dplyr::arrange(.data$group_type, .data$group_label)

write_csv_message(group_summary, group_summary_path)


## Screening models ----


model_data <- plot_summary %>%
  dplyr::mutate(
    vegetation_adrian_group = as.factor(.data$vegetation_adrian_group),
    treatment = as.factor(.data$treatment)
  )

model_summary <- dplyr::bind_rows(
  tidy_lm_summary(
    model_data = model_data,
    formula = delta_total_veg_pct ~ post_minus_pre_inundation_frequency_pct_points +
      pre_conservation_inundation_frequency_pct +
      vegetation_adrian_group,
    model_name = "delta_total_veg_inundation_vegetation_group",
    response_variable = "delta_total_veg_pct",
    model_role = "primary_screening"
  ),
  tidy_lm_summary(
    model_data = model_data,
    formula = delta_bare_ground_pct ~ post_minus_pre_inundation_frequency_pct_points +
      pre_conservation_inundation_frequency_pct +
      vegetation_adrian_group,
    model_name = "delta_bare_ground_inundation_vegetation_group",
    response_variable = "delta_bare_ground_pct",
    model_role = "primary_screening"
  )
)

if (RUN_SECONDARY_TREATMENT_SANITY_MODELS) {
  treatment_model_summary <- dplyr::bind_rows(
    tidy_lm_summary(
      model_data = model_data,
      formula = delta_total_veg_pct ~ post_minus_pre_inundation_frequency_pct_points +
        pre_conservation_inundation_frequency_pct +
        vegetation_adrian_group +
        treatment,
      model_name = "delta_total_veg_secondary_treatment_sanity_check",
      response_variable = "delta_total_veg_pct",
      model_role = "secondary_treatment_sanity_check"
    ),
    tidy_lm_summary(
      model_data = model_data,
      formula = delta_bare_ground_pct ~ post_minus_pre_inundation_frequency_pct_points +
        pre_conservation_inundation_frequency_pct +
        vegetation_adrian_group +
        treatment,
      model_name = "delta_bare_ground_secondary_treatment_sanity_check",
      response_variable = "delta_bare_ground_pct",
      model_role = "secondary_treatment_sanity_check"
    )
  )

  model_summary <- dplyr::bind_rows(model_summary, treatment_model_summary)
}

write_csv_message(model_summary, model_summary_path)


## Diagnostics ----


row_counts <- tibble::tibble(
  dataset = c(
    "curated_ground_cover_timeseries",
    "plot_rs_analysis_base",
    "10a_ground_cover_prepost_plot_summary",
    "10a_ground_cover_prepost_group_summary",
    "10a_ground_cover_prepost_model_summary"
  ),
  path = c(
    ground_cover_path,
    plot_base_path,
    plot_summary_path,
    group_summary_path,
    model_summary_path
  ),
  n_rows = c(
    nrow(ground_cover),
    nrow(plot_base),
    nrow(plot_summary),
    nrow(group_summary),
    nrow(model_summary)
  ),
  n_cols = c(
    ncol(ground_cover),
    ncol(plot_base),
    ncol(plot_summary),
    ncol(group_summary),
    ncol(model_summary)
  )
)

variable_ranges <- dplyr::bind_rows(
  make_variable_ranges(
    plot_summary,
    c(
      "pre_mean_total_veg_pct",
      "post_mean_total_veg_pct",
      "pre_mean_bare_ground_pct",
      "post_mean_bare_ground_pct",
      "pre_median_total_veg_pct",
      "post_median_total_veg_pct",
      "pre_median_bare_ground_pct",
      "post_median_bare_ground_pct",
      "pre_conservation_inundation_frequency_pct",
      "post_conservation_inundation_frequency_pct"
    ),
    expected_min = 0,
    expected_max = 100
  ),
  make_variable_ranges(
    plot_summary,
    c(
      "delta_total_veg_pct",
      "delta_bare_ground_pct",
      "post_minus_pre_inundation_frequency_pct_points"
    ),
    expected_min = -100,
    expected_max = 100
  ),
  make_variable_ranges(
    plot_summary,
    c("n_pre_seasons", "n_post_seasons"),
    expected_min = 0,
    expected_max = Inf
  )
)

review_flag_cols <- c(
  "low_pre_gc_support",
  "low_post_gc_support",
  "strong_total_veg_increase",
  "strong_total_veg_decrease",
  "strong_bare_increase",
  "strong_bare_decrease",
  "wetter_post_and_greener",
  "wetter_post_and_barer",
  "rarely_inundated"
)

review_flags <- dplyr::bind_rows(lapply(review_flag_cols, function(flag_col) {
  tibble::tibble(
    review_flag = flag_col,
    n_flagged = sum(plot_summary[[flag_col]], na.rm = TRUE),
    pct_flagged = 100 * sum(plot_summary[[flag_col]], na.rm = TRUE) / nrow(plot_summary)
  )
}))

write_csv_message(row_counts, row_counts_path)
write_csv_message(variable_ranges, variable_ranges_path)
write_csv_message(review_flags, review_flags_path)

status <- make_handoff_report(
  row_counts = row_counts,
  variable_ranges = variable_ranges,
  review_flags = review_flags,
  model_summary = model_summary,
  report_path = handoff_report_path
)

if (status != "PASS") {
  warning(
    "10a completed with review flags. See diagnostics: ",
    diagnostics_dir,
    call. = FALSE
  )
}

message("10a ground-cover pre/post response analysis complete.")
