# ------------------------------------------------------------------------------
# Script: scripts/03_inundation_products/internal/03_curate_rs_analysis_base_impl.R
# Purpose: Internal implementation module for 03_inundation_products: curate
#          rs analysis base impl.
# Workflow stage: 03_inundation_products
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
## Create canonical analysis-ready CSVs from existing extraction and Step 7
## outputs. This script does not do raster processing and does not run 07e.


## User settings ----


root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", "D:/Github_repos/Gayini"), winslash = "/", mustWork = TRUE)
MANAGEMENT_CHANGE_DATE <- as.Date("2019-07-01")
PRE_START_DATE <- as.Date("2013-07-01")
POST_END_DATE <- as.Date("2026-06-30")
WATER_YEAR_START_MONTH <- 7
ONLY_ADEQUATE_COVERAGE <- TRUE
EXCLUDE_TREE_FLAGGED_PLOTS <- FALSE
DAILY_WET_RULE <- "strict_value_1"
GAP_DAYS_FOR_NEW_SEGMENT <- 550


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
diagnostics_dir <- file.path(root_dir, "Output", "diagnostics", "07_curate_rs_analysis_base")

dir.create(csv_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(diagnostics_dir, recursive = TRUE, showWarnings = FALSE)

ground_cover_path <- gayini_find_first_existing(c(
  file.path(root_dir, "data_processed", "plot_fractional_cover_timeseries.csv"),
  file.path(root_dir, "Output", "csv", "04c_fractional_cover_full.csv")
))

annual_inundation_path <- gayini_find_first_existing(c(
  file.path(root_dir, "data_processed", "plot_landsat_inundation_timeseries.csv"),
  file.path(root_dir, "Output", "csv", "05c_landsat_inundation_full.csv")
))

daily_inundation_path <- gayini_find_first_existing(c(
  file.path(root_dir, "data_processed", "plot_daily_inundation_timeseries.csv"),
  file.path(root_dir, "Output", "csv", "06c_daily_inundation_full.csv")
))

mer_dynamic_path <- gayini_find_first_existing(c(
  file.path(root_dir, "data_processed", "plot_inundation_dynamic_metrics.csv"),
  file.path(root_dir, "Output", "csv", "05b_MER_plot_inundation_dynamic_metrics.csv")
))

pre_post_path <- gayini_find_first_existing(c(
  file.path(root_dir, "Output", "csv", "07f_pre_post_inundation_plot_summary_fixed.csv"),
  file.path(root_dir, "data_processed", "plot_pre_post_inundation_frequency_fixed.csv"),
  file.path(root_dir, "Output", "csv", "07e_pre_post_inundation_plot_summary.csv"),
  file.path(root_dir, "data_processed", "plot_pre_post_inundation_frequency.csv")
))

required_inputs <- c(
  ground_cover_path = ground_cover_path,
  annual_inundation_path = annual_inundation_path,
  pre_post_path = pre_post_path
)

missing_required_inputs <- names(required_inputs)[is.na(required_inputs)]

if (length(missing_required_inputs) > 0) {
  stop(
    "Missing required input(s): ",
    paste(missing_required_inputs, collapse = ", "),
    call. = FALSE
  )
}

curated_ground_cover_path <- file.path(csv_dir, "curated_ground_cover_timeseries.csv")
curated_annual_inundation_path <- file.path(csv_dir, "curated_annual_inundation_timeseries.csv")
curated_daily_monthly_path <- file.path(csv_dir, "curated_daily_inundation_monthly.csv")
plot_analysis_base_path <- file.path(csv_dir, "plot_rs_analysis_base.csv")

row_count_path <- file.path(diagnostics_dir, "07_curate_row_counts.csv")
duplicate_check_path <- file.path(diagnostics_dir, "07_curate_duplicate_checks.csv")
variable_lut_path <- file.path(diagnostics_dir, "07_curate_variable_lut.csv")
vegetation_group_counts_path <- file.path(diagnostics_dir, "07_curate_vegetation_group_counts.csv")


## Read inputs ----


message("Reading ground-cover table: ", ground_cover_path)
ground_cover_raw <- readr::read_csv(ground_cover_path, show_col_types = FALSE) %>%
  gayini_standardise_plot_id(object_name = "ground-cover table")

message("Reading annual inundation table: ", annual_inundation_path)
annual_inundation_raw <- readr::read_csv(annual_inundation_path, show_col_types = FALSE) %>%
  gayini_standardise_plot_id(object_name = "annual inundation table")

message("Reading pre/post inundation plot summary: ", pre_post_path)
pre_post_raw <- readr::read_csv(pre_post_path, show_col_types = FALSE) %>%
  gayini_standardise_plot_id(object_name = "pre/post inundation plot summary")

if (!is.na(daily_inundation_path)) {
  message("Reading daily inundation table: ", daily_inundation_path)
  daily_inundation_raw <- readr::read_csv(daily_inundation_path, show_col_types = FALSE) %>%
    gayini_standardise_plot_id(object_name = "daily inundation table")
} else {
  message("No daily inundation table found; monthly daily output will not be written.")
  daily_inundation_raw <- NULL
}

if (!is.na(mer_dynamic_path)) {
  message("Reading MER inundation dynamic metrics: ", mer_dynamic_path)
  mer_dynamic_raw <- readr::read_csv(mer_dynamic_path, show_col_types = FALSE) %>%
    gayini_standardise_plot_id(object_name = "MER inundation dynamic metrics")
} else {
  message("No MER inundation dynamic metrics found; plot base will omit MER dynamic fields.")
  mer_dynamic_raw <- NULL
}

plot_metadata <- pre_post_raw %>%
  gayini_recode_vegetation_groups() %>%
  dplyr::select(dplyr::any_of(c("plot_id", "treatment", "vegetation", "vegetation_adrian_group"))) %>%
  dplyr::distinct(.data$plot_id, .keep_all = TRUE)

coalesce_joined_plot_metadata <- function(df) {
  for (nm in c("treatment", "vegetation", "vegetation_adrian_group")) {
    plot_nm <- paste0(nm, "_plot")

    if (!nm %in% names(df)) {
      df[[nm]] <- NA_character_
    }

    if (plot_nm %in% names(df)) {
      df[[nm]] <- dplyr::coalesce(as.character(df[[nm]]), as.character(df[[plot_nm]]))
      df[[plot_nm]] <- NULL
    }
  }

  df
}


## Curate ground cover ----


ground_cover_long <- ground_cover_raw %>%
  dplyr::mutate(
    date_midpoint = as.Date(gayini_get_first_existing_column(
      .,
      c("date_midpoint", "date_start", "date_end")
    )),
    water_year = gayini_assign_water_year(
      .data$date_midpoint,
      water_year_start_month = WATER_YEAR_START_MONTH
    ),
    period = gayini_assign_period(
      .data$date_midpoint,
      management_change_date = MANAGEMENT_CHANGE_DATE,
      pre_start_date = PRE_START_DATE,
      post_end_date = POST_END_DATE
    )
  ) %>%
  gayini_recode_vegetation_groups() %>%
  gayini_recode_ground_cover_bands() %>%
  dplyr::filter(!is.na(.data$date_midpoint), !is.na(.data$cover_key))

if (ONLY_ADEQUATE_COVERAGE && "valid_coverage_status" %in% names(ground_cover_long)) {
  ground_cover_long <- ground_cover_long %>%
    dplyr::filter(.data$valid_coverage_status == "adequate_coverage")
}

if (EXCLUDE_TREE_FLAGGED_PLOTS && "tree_flag" %in% names(ground_cover_long)) {
  ground_cover_long <- ground_cover_long %>%
    dplyr::filter(!(.data$tree_flag %in% c(TRUE, "TRUE", "true", "tree_flagged")))
}

ground_cover_key_check <- gayini_check_duplicate_keys(
  ground_cover_long,
  key_cols = c("plot_id", "date_midpoint", "cover_key"),
  dataset_name = "ground_cover_long_plot_date_cover_key",
  stop_on_duplicates = TRUE
)

ground_cover_metadata_cols <- intersect(
  c(
    "plot_id",
    "date_midpoint",
    "water_year",
    "period",
    "treatment",
    "vegetation",
    "vegetation_adrian_group",
    "area_ha",
    "valid_coverage_status",
    "valid_coverage_status_note",
    "valid_coverage_count",
    "value_scale_factor",
    "product",
    "sensor",
    "extraction_scope",
    "summary_method_primary",
    "summary_method_secondary"
  ),
  names(ground_cover_long)
)

ground_cover_metadata <- ground_cover_long %>%
  dplyr::select(dplyr::all_of(ground_cover_metadata_cols)) %>%
  dplyr::distinct(.data$plot_id, .data$date_midpoint, .keep_all = TRUE)

ground_cover_wide <- ground_cover_long %>%
  dplyr::select("plot_id", "date_midpoint", "cover_key", "ground_cover_pct") %>%
  tidyr::pivot_wider(names_from = "cover_key", values_from = "ground_cover_pct") %>%
  gayini_add_total_vegetation()

curated_ground_cover <- ground_cover_metadata %>%
  dplyr::left_join(ground_cover_wide, by = c("plot_id", "date_midpoint")) %>%
  gayini_add_gap_segments(
    date_col = "date_midpoint",
    group_cols = c("plot_id"),
    gap_days_for_new_segment = GAP_DAYS_FOR_NEW_SEGMENT
  ) %>%
  dplyr::arrange(.data$plot_id, .data$date_midpoint)

ground_cover_plot_date_check <- gayini_check_duplicate_keys(
  curated_ground_cover,
  key_cols = c("plot_id", "date_midpoint"),
  dataset_name = "curated_ground_cover_timeseries",
  stop_on_duplicates = TRUE
)

readr::write_csv(curated_ground_cover, curated_ground_cover_path)
message("Wrote: ", curated_ground_cover_path)


## Curate annual inundation ----


curated_annual_inundation <- annual_inundation_raw %>%
  dplyr::mutate(
    date_start = as.Date(gayini_get_first_existing_column(., c("date_start", "date_midpoint", "date_end"))),
    date_end = as.Date(gayini_get_first_existing_column(., c("date_end", "date_midpoint", "date_start"))),
    water_year = dplyr::coalesce(
      as.character(gayini_get_first_existing_column(., c("water_year"), default = NA_character_)),
      gayini_assign_water_year(.data$date_start, water_year_start_month = WATER_YEAR_START_MONTH)
    ),
    period = gayini_assign_period(
      .data$date_start,
      management_change_date = MANAGEMENT_CHANGE_DATE,
      pre_start_date = PRE_START_DATE,
      post_end_date = POST_END_DATE
    )
  ) %>%
  gayini_recode_vegetation_groups()

if (ONLY_ADEQUATE_COVERAGE && "valid_coverage_status" %in% names(curated_annual_inundation)) {
  curated_annual_inundation <- curated_annual_inundation %>%
    dplyr::filter(.data$valid_coverage_status == "adequate_coverage")
}

if ("inundated_any_pct" %in% names(curated_annual_inundation)) {
  curated_annual_inundation <- curated_annual_inundation %>%
    dplyr::mutate(
      annual_wet_any = dplyr::case_when(
        is.na(.data$inundated_any_pct) ~ NA_integer_,
        .data$inundated_any_pct > 0 ~ 1L,
        TRUE ~ 0L
      ),
      annual_valid_any = dplyr::case_when(
        is.na(.data$inundated_any_pct) ~ 0L,
        TRUE ~ 1L
      )
    )
}

annual_select_cols <- intersect(
  c(
    "plot_id",
    "water_year",
    "date_start",
    "date_end",
    "period",
    "treatment",
    "vegetation",
    "vegetation_adrian_group",
    "plot_area_ha",
    "inundated_any_pct",
    "annual_wet_any",
    "annual_valid_any",
    "count_0_area_pct",
    "count_1_area_pct",
    "count_2_area_pct",
    "count_3_area_pct",
    "other_count_area_pct",
    "mean_inundation_count",
    "max_inundation_count",
    "majority_count",
    "n_valid_counts",
    "valid_coverage_count",
    "expected_coverage_count",
    "valid_coverage_pct",
    "valid_coverage_status",
    "product",
    "sensor",
    "file_name",
    "primary_metric",
    "value_semantics",
    "legend_status",
    "reference_product"
  ),
  names(curated_annual_inundation)
)

curated_annual_inundation <- curated_annual_inundation %>%
  dplyr::select(dplyr::all_of(annual_select_cols), dplyr::everything()) %>%
  dplyr::arrange(.data$plot_id, .data$water_year)

annual_key_check <- gayini_check_duplicate_keys(
  curated_annual_inundation,
  key_cols = c("plot_id", "water_year"),
  dataset_name = "curated_annual_inundation_timeseries",
  stop_on_duplicates = TRUE
)

readr::write_csv(curated_annual_inundation, curated_annual_inundation_path)
message("Wrote: ", curated_annual_inundation_path)


## Curate daily inundation to monthly summaries ----


if (!is.null(daily_inundation_raw)) {
  daily_work <- daily_inundation_raw %>%
    dplyr::left_join(plot_metadata, by = "plot_id", suffix = c("", "_plot")) %>%
    coalesce_joined_plot_metadata() %>%
    dplyr::mutate(
      date_midpoint = as.Date(gayini_get_first_existing_column(
        .,
        c("date_midpoint", "date_start", "date_end")
      )),
      month_start = as.Date(sprintf("%s-01", format(.data$date_midpoint, "%Y-%m"))),
      water_year = gayini_assign_water_year(
        .data$date_midpoint,
        water_year_start_month = WATER_YEAR_START_MONTH
      ),
      period = gayini_assign_period(
        .data$date_midpoint,
        management_change_date = MANAGEMENT_CHANGE_DATE,
        pre_start_date = PRE_START_DATE,
        post_end_date = POST_END_DATE
      ),
      daily_inundated_pct = as.numeric(gayini_get_first_existing_column(
        .,
        c("daily_inundated_pct", "value_1_inundated_pct"),
        default = NA_real_
      ))
    ) %>%
    gayini_recode_vegetation_groups() %>%
    dplyr::filter(!is.na(.data$date_midpoint), !is.na(.data$month_start))

  if (ONLY_ADEQUATE_COVERAGE && "valid_coverage_status" %in% names(daily_work)) {
    daily_work <- daily_work %>%
      dplyr::filter(.data$valid_coverage_status == "adequate_coverage")
  }

  curated_daily_monthly <- daily_work %>%
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
      n_daily_observations = dplyr::n(),
      n_daily_wet_observations = sum(.data$daily_inundated_pct > 0, na.rm = TRUE),
      mean_daily_inundated_pct = mean(.data$daily_inundated_pct, na.rm = TRUE),
      max_daily_inundated_pct = max(.data$daily_inundated_pct, na.rm = TRUE),
      first_observation_date = min(.data$date_midpoint, na.rm = TRUE),
      last_observation_date = max(.data$date_midpoint, na.rm = TRUE),
      daily_wet_rule = DAILY_WET_RULE,
      sensor_count = dplyr::n_distinct(.data$sensor),
      .groups = "drop"
    ) %>%
    dplyr::mutate(
      mean_daily_inundated_pct = dplyr::if_else(
        is.nan(.data$mean_daily_inundated_pct),
        NA_real_,
        .data$mean_daily_inundated_pct
      ),
      max_daily_inundated_pct = dplyr::if_else(
        is.infinite(.data$max_daily_inundated_pct),
        NA_real_,
        .data$max_daily_inundated_pct
      )
    ) %>%
    dplyr::arrange(.data$plot_id, .data$month_start)

  daily_monthly_key_check <- gayini_check_duplicate_keys(
    curated_daily_monthly,
    key_cols = c("plot_id", "month_start"),
    dataset_name = "curated_daily_inundation_monthly",
    stop_on_duplicates = TRUE
  )

  readr::write_csv(curated_daily_monthly, curated_daily_monthly_path)
  message("Wrote: ", curated_daily_monthly_path)
} else {
  curated_daily_monthly <- NULL
  daily_monthly_key_check <- tibble::tibble(
    dataset = "curated_daily_inundation_monthly",
    key_cols = "plot_id;month_start",
    n_rows = 0L,
    n_duplicate_keys = 0L,
    n_duplicate_rows = 0L,
    status = "not_written_no_daily_input"
  )
}


## Curate plot-level analysis base ----


ground_cover_support <- curated_ground_cover %>%
  dplyr::filter(.data$period %in% c("pre_conservation", "post_conservation")) %>%
  dplyr::group_by(.data$plot_id) %>%
  dplyr::summarise(
    ground_cover_first_date = min(.data$date_midpoint, na.rm = TRUE),
    ground_cover_last_date = max(.data$date_midpoint, na.rm = TRUE),
    n_ground_cover_dates = dplyr::n_distinct(.data$date_midpoint),
    n_pre_ground_cover_dates = dplyr::n_distinct(.data$date_midpoint[.data$period == "pre_conservation"]),
    n_post_ground_cover_dates = dplyr::n_distinct(.data$date_midpoint[.data$period == "post_conservation"]),
    pre_mean_total_veg_pct = mean(.data$total_veg_pct[.data$period == "pre_conservation"], na.rm = TRUE),
    post_mean_total_veg_pct = mean(.data$total_veg_pct[.data$period == "post_conservation"], na.rm = TRUE),
    pre_mean_bare_ground_pct = mean(.data$bare_ground_pct[.data$period == "pre_conservation"], na.rm = TRUE),
    post_mean_bare_ground_pct = mean(.data$bare_ground_pct[.data$period == "post_conservation"], na.rm = TRUE),
    .groups = "drop"
  ) %>%
  dplyr::mutate(
    dplyr::across(
      c(
        "pre_mean_total_veg_pct",
        "post_mean_total_veg_pct",
        "pre_mean_bare_ground_pct",
        "post_mean_bare_ground_pct"
      ),
      ~ dplyr::if_else(is.nan(.x), NA_real_, .x)
    ),
    delta_total_veg_pct = .data$post_mean_total_veg_pct - .data$pre_mean_total_veg_pct,
    delta_bare_ground_pct = .data$post_mean_bare_ground_pct - .data$pre_mean_bare_ground_pct
  )

annual_support <- curated_annual_inundation %>%
  dplyr::filter(.data$period %in% c("pre_conservation", "post_conservation")) %>%
  dplyr::group_by(.data$plot_id) %>%
  dplyr::summarise(
    n_annual_inundation_years = dplyr::n_distinct(.data$water_year),
    n_pre_annual_inundation_years = dplyr::n_distinct(.data$water_year[.data$period == "pre_conservation"]),
    n_post_annual_inundation_years = dplyr::n_distinct(.data$water_year[.data$period == "post_conservation"]),
    pre_mean_annual_inundated_any_pct = mean(.data$inundated_any_pct[.data$period == "pre_conservation"], na.rm = TRUE),
    post_mean_annual_inundated_any_pct = mean(.data$inundated_any_pct[.data$period == "post_conservation"], na.rm = TRUE),
    .groups = "drop"
  ) %>%
  dplyr::mutate(
    dplyr::across(
      c("pre_mean_annual_inundated_any_pct", "post_mean_annual_inundated_any_pct"),
      ~ dplyr::if_else(is.nan(.x), NA_real_, .x)
    )
  )

if (!is.null(mer_dynamic_raw)) {
  mer_dynamic_support <- mer_dynamic_raw %>%
    dplyr::filter(.data$period %in% c("pre_conservation", "post_conservation")) %>%
    dplyr::group_by(.data$plot_id) %>%
    dplyr::summarise(
      n_mer_dynamic_years = dplyr::n_distinct(.data$water_year),
      n_pre_mer_dynamic_years = dplyr::n_distinct(.data$water_year[.data$period == "pre_conservation"]),
      n_post_mer_dynamic_years = dplyr::n_distinct(.data$water_year[.data$period == "post_conservation"]),
      pre_mean_annual_max_inundated_area_pct = mean(.data$annual_max_inundated_area_pct[.data$period == "pre_conservation"], na.rm = TRUE),
      post_mean_annual_max_inundated_area_pct = mean(.data$annual_max_inundated_area_pct[.data$period == "post_conservation"], na.rm = TRUE),
      pre_max_annual_max_inundated_area_pct = max(.data$annual_max_inundated_area_pct[.data$period == "pre_conservation"], na.rm = TRUE),
      post_max_annual_max_inundated_area_pct = max(.data$annual_max_inundated_area_pct[.data$period == "post_conservation"], na.rm = TRUE),
      pre_mean_longest_observed_wet_sequence_days = mean(.data$longest_observed_wet_sequence_days[.data$period == "pre_conservation"], na.rm = TRUE),
      post_mean_longest_observed_wet_sequence_days = mean(.data$longest_observed_wet_sequence_days[.data$period == "post_conservation"], na.rm = TRUE),
      pre_mean_mer_valid_observations = mean(.data$n_valid_observations[.data$period == "pre_conservation"], na.rm = TRUE),
      post_mean_mer_valid_observations = mean(.data$n_valid_observations[.data$period == "post_conservation"], na.rm = TRUE),
      mer_dynamic_duration_interpretation = paste(sort(unique(.data$duration_interpretation)), collapse = "; "),
      .groups = "drop"
    ) %>%
    dplyr::mutate(
      dplyr::across(
        c(
          "pre_mean_annual_max_inundated_area_pct",
          "post_mean_annual_max_inundated_area_pct",
          "pre_mean_longest_observed_wet_sequence_days",
          "post_mean_longest_observed_wet_sequence_days",
          "pre_mean_mer_valid_observations",
          "post_mean_mer_valid_observations"
        ),
        ~ dplyr::if_else(is.nan(.x), NA_real_, .x)
      ),
      dplyr::across(
        c(
          "pre_max_annual_max_inundated_area_pct",
          "post_max_annual_max_inundated_area_pct"
        ),
        ~ dplyr::if_else(is.infinite(.x), NA_real_, .x)
      )
    )
} else {
  mer_dynamic_support <- tibble::tibble(plot_id = character())
}

pre_post <- pre_post_raw %>%
  gayini_recode_vegetation_groups()

plot_analysis_base <- pre_post %>%
  dplyr::left_join(ground_cover_support, by = "plot_id") %>%
  dplyr::left_join(annual_support, by = "plot_id") %>%
  dplyr::left_join(mer_dynamic_support, by = "plot_id") %>%
  dplyr::select(
    "plot_id",
    dplyr::any_of(c(
      "treatment",
      "vegetation",
      "vegetation_adrian_group",
      "area_ha",
      "centroid_x",
      "centroid_y",
      "pre_conservation_inundation_frequency_pct",
      "post_conservation_inundation_frequency_pct",
      "post_minus_pre_inundation_frequency_pct_points",
      "inundation_change_class",
      "pre_conservation_valid_year_count",
      "post_conservation_valid_year_count",
      "ground_cover_first_date",
      "ground_cover_last_date",
      "n_ground_cover_dates",
      "n_pre_ground_cover_dates",
      "n_post_ground_cover_dates",
      "pre_mean_total_veg_pct",
      "post_mean_total_veg_pct",
      "delta_total_veg_pct",
      "pre_mean_bare_ground_pct",
      "post_mean_bare_ground_pct",
      "delta_bare_ground_pct",
      "n_annual_inundation_years",
      "n_pre_annual_inundation_years",
      "n_post_annual_inundation_years",
      "pre_mean_annual_inundated_any_pct",
      "post_mean_annual_inundated_any_pct",
      "n_mer_dynamic_years",
      "n_pre_mer_dynamic_years",
      "n_post_mer_dynamic_years",
      "pre_mean_annual_max_inundated_area_pct",
      "post_mean_annual_max_inundated_area_pct",
      "pre_max_annual_max_inundated_area_pct",
      "post_max_annual_max_inundated_area_pct",
      "pre_mean_longest_observed_wet_sequence_days",
      "post_mean_longest_observed_wet_sequence_days",
      "pre_mean_mer_valid_observations",
      "post_mean_mer_valid_observations",
      "mer_dynamic_duration_interpretation",
      "conservation_date",
      "pre_start_date",
      "post_end_date",
      "daily_wet_rule",
      "reference_product"
    )),
    dplyr::everything()
  ) %>%
  dplyr::arrange(.data$plot_id)

plot_base_key_check <- gayini_check_duplicate_keys(
  plot_analysis_base,
  key_cols = c("plot_id"),
  dataset_name = "plot_rs_analysis_base",
  stop_on_duplicates = TRUE
)

readr::write_csv(plot_analysis_base, plot_analysis_base_path)
message("Wrote: ", plot_analysis_base_path)


## Diagnostics ----


duplicate_checks <- dplyr::bind_rows(
  ground_cover_key_check,
  ground_cover_plot_date_check,
  annual_key_check,
  daily_monthly_key_check,
  plot_base_key_check
)

readr::write_csv(duplicate_checks, duplicate_check_path)
message("Wrote: ", duplicate_check_path)

diagnostic_tables <- list(
  input_ground_cover = ground_cover_raw,
  input_annual_inundation = annual_inundation_raw,
  input_pre_post = pre_post_raw,
  curated_ground_cover_timeseries = curated_ground_cover,
  curated_annual_inundation_timeseries = curated_annual_inundation,
  plot_rs_analysis_base = plot_analysis_base
)

diagnostic_paths <- list(
  input_ground_cover = ground_cover_path,
  input_annual_inundation = annual_inundation_path,
  input_pre_post = pre_post_path,
  curated_ground_cover_timeseries = curated_ground_cover_path,
  curated_annual_inundation_timeseries = curated_annual_inundation_path,
  plot_rs_analysis_base = plot_analysis_base_path
)

if (!is.null(curated_daily_monthly)) {
  diagnostic_tables$input_daily_inundation <- daily_inundation_raw
  diagnostic_tables$curated_daily_inundation_monthly <- curated_daily_monthly
  diagnostic_paths$input_daily_inundation <- daily_inundation_path
  diagnostic_paths$curated_daily_inundation_monthly <- curated_daily_monthly_path
}

if (!is.null(mer_dynamic_raw)) {
  diagnostic_tables$input_mer_dynamic_metrics <- mer_dynamic_raw
  diagnostic_tables$plot_mer_dynamic_support <- mer_dynamic_support
  diagnostic_paths$input_mer_dynamic_metrics <- mer_dynamic_path
  diagnostic_paths$plot_mer_dynamic_support <- NA_character_
}

gayini_write_row_count_diagnostics(
  tables = diagnostic_tables,
  paths = diagnostic_paths,
  output_path = row_count_path
)

readr::write_csv(gayini_variable_lut(), variable_lut_path)
message("Wrote: ", variable_lut_path)

vegetation_group_counts <- dplyr::bind_rows(
  curated_ground_cover %>%
    dplyr::count(.data$vegetation_adrian_group, name = "n_rows") %>%
    dplyr::mutate(dataset = "curated_ground_cover_timeseries"),
  curated_annual_inundation %>%
    dplyr::count(.data$vegetation_adrian_group, name = "n_rows") %>%
    dplyr::mutate(dataset = "curated_annual_inundation_timeseries"),
  curated_daily_monthly %>%
    dplyr::count(.data$vegetation_adrian_group, name = "n_rows") %>%
    dplyr::mutate(dataset = "curated_daily_inundation_monthly"),
  plot_analysis_base %>%
    dplyr::count(.data$vegetation_adrian_group, name = "n_rows") %>%
    dplyr::mutate(dataset = "plot_rs_analysis_base")
) %>%
  dplyr::select("dataset", "vegetation_adrian_group", "n_rows") %>%
  dplyr::arrange(.data$dataset, .data$vegetation_adrian_group)

readr::write_csv(vegetation_group_counts, vegetation_group_counts_path)
message("Wrote: ", vegetation_group_counts_path)

message("Curated analysis-base pass complete.")
