# ------------------------------------------------------------------------------
# Script: scripts/06_mer/07_build_mer_annual_max_rasters.R
# Purpose: Build MER annual maximum rasters.
# Workflow stage: 06_mer
# Run mode: heavy
# Heavy processing: yes
# Key inputs:
#   - MER raster census outputs and source rasters.
# Key outputs:
#   - Production MER raster outputs.
# Notes:
#   - Heavy step; do not run casually and never from the smoke test.
#   - MER observed wet extent metrics are supplementary and are not
#     hydroperiod.
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Load configuration and execute workflow step
# ------------------------------------------------------------------------------

## Purpose:
## Production MER / Flow_MER-style annual maximum observed wet raster build from
## existing daily / single-date inundation rasters.


MANAGEMENT_CHANGE_DATE <- as.Date("2019-07-01")
DAILY_WET_RULE <- "strict_value_1"
WET_VALUES <- 1
VALID_VALUES <- c(0, 1, 2)
SUPPORT_THRESHOLDS <- c(low_max = 5L, moderate_max = 11L)
OVERWRITE_PRODUCTION_MER_OUTPUTS <- TRUE

root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", "D:/Github_repos/Gayini"), winslash = "/", mustWork = TRUE)

source(file.path(root_dir, "R", "gayini_analysis_base_functions.R"))
source(file.path(root_dir, "R", "gayini_mer_raster_functions.R"))

required_packages <- c("dplyr", "tidyr", "readr", "stringr", "magrittr", "tibble", "purrr", "terra")
gayini_mer_check_packages(required_packages)

library(dplyr)
library(tidyr)
library(readr)
library(stringr)
library(magrittr)
library(tibble)
library(purrr)
library(terra)

## Paths ----

diagnostics_dir <- file.path(root_dir, "Output", "diagnostics", "24_mer_raster_build")
diagnostics_25_dir <- file.path(root_dir, "Output", "diagnostics", "25_mer_annual_max_raster_build")
csv_dir <- file.path(root_dir, "Output", "csv", "MER")
annual_max_dir <- file.path(root_dir, "Output", "rasters", "MER", "annual_max")
period_summary_dir <- file.path(root_dir, "Output", "rasters", "MER", "period_summaries")
report_dir <- file.path(root_dir, "Output", "reports", "MER")
boundary_path <- file.path(root_dir, "data_intermediate", "spatial", "boundary_clean.gpkg")

dir.create(diagnostics_25_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(csv_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(annual_max_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(period_summary_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(report_dir, recursive = TRUE, showWarnings = FALSE)

inventory_path <- file.path(diagnostics_dir, "mer_raster_input_inventory.csv")
grid_path <- file.path(diagnostics_dir, "mer_raster_grid_compatibility.csv")
support_path <- file.path(diagnostics_dir, "mer_raster_water_year_support.csv")
value_schema_path <- file.path(diagnostics_dir, "mer_raster_value_schema.csv")

required_inputs <- c(inventory_path, grid_path, support_path, value_schema_path)
missing_inputs <- required_inputs[!file.exists(required_inputs)]
if (length(missing_inputs) > 0) {
  stop("Missing Task 10 census outputs. Run scripts/06_mer/05_census_mer_raster_inputs.R first: ", paste(missing_inputs, collapse = "; "), call. = FALSE)
}

inventory <- readr::read_csv(inventory_path, show_col_types = FALSE) %>%
  dplyr::mutate(date = as.Date(.data$date))
grid_compatibility <- readr::read_csv(grid_path, show_col_types = FALSE)
water_year_support <- readr::read_csv(support_path, show_col_types = FALSE)
value_schema <- readr::read_csv(value_schema_path, show_col_types = FALSE)

reference_path <- gayini_mer_find_reference_grid(root_dir)
reference_template <- gayini_mer_prepare_reference_template(
  reference_path = reference_path,
  boundary_path = boundary_path
)

reference_metadata <- tibble::tibble(
  reference_path = reference_path,
  crs = terra::crs(reference_template, proj = TRUE),
  xres = terra::res(reference_template)[[1]],
  yres = terra::res(reference_template)[[2]],
  nrow = terra::nrow(reference_template),
  ncol = terra::ncol(reference_template),
  extent = paste(as.vector(terra::ext(reference_template)), collapse = ";"),
  boundary_path = boundary_path,
  boundary_used = file.exists(boundary_path)
)
readr::write_csv(reference_metadata, file.path(diagnostics_25_dir, "mer_reference_grid_metadata.csv"))

## Alignment policy ----

policy_path <- file.path(report_dir, "mer_raster_grid_alignment_policy.md")
writeLines(
  c(
    "# MER Raster Grid Alignment Policy",
    "",
    paste0("Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
    "",
    "## Policy",
    "",
    "1. Canonical reference grid: current annual occurrence/pre-post inundation raster grid.",
    paste0("   Reference raster: `", reference_path, "`."),
    "2. Output CRS: inherited from the canonical annual occurrence raster grid.",
    paste0("   CRS: `", reference_metadata$crs[[1]], "`."),
    paste0("3. Output resolution: ", reference_metadata$xres[[1]], " x ", reference_metadata$yres[[1]], " map units."),
    "4. Output extent: inherited from the canonical annual occurrence raster grid.",
    "5. Output mask: Gayini boundary mask is applied where `data_intermediate/spatial/boundary_clean.gpkg` is available; otherwise the annual occurrence reference mask is used.",
    "6. Alignment: every source daily categorical inundation raster is cropped to the reference extent and aligned to the reference grid.",
    "7. Resampling: categorical inundation rasters are resampled with nearest-neighbour only.",
    "8. Bilinear resampling is not used for categorical water/no-water classes.",
    "9. Exclusions: no water years are excluded from annual maximum production because all selected source rasters exist, open, and share CRS; mixed extent/resolution years are built with explicit nearest-neighbour alignment and reported as `build_with_alignment`.",
    "10. Nodata and invalid handling: strict wet = value 1 only; valid dry/wet/support classes = values 0, 1, 2; values 3, 15, 255 and NA are not counted as valid wet/dry observations.",
    "",
    "## Interpretation Caveats",
    "",
    "- MER annual maximum observed wet extent is not hydroperiod.",
    "- MER observed wet fraction is observed wet fraction, not flood duration.",
    "- Annual occurrence frequency is not flood duration or depth.",
    "- Sequence, duration and start-date metrics remain deferred.",
    "- MER raster products are supplementary to the main Gayini annual occurrence / pre-post framework unless Adrian decides otherwise."
  ),
  policy_path
)

## Build-decision table ----

year_decisions <- inventory %>%
  dplyr::filter(.data$selected_for_mer_raster) %>%
  dplyr::group_by(.data$water_year) %>%
  dplyr::summarise(
    n_source_rasters = dplyr::n(),
    n_valid_source_rasters = sum(.data$exists & .data$can_open),
    first_date = min(.data$date, na.rm = TRUE),
    last_date = max(.data$date, na.rm = TRUE),
    n_sensors = dplyr::n_distinct(.data$sensor),
    sensors = paste(sort(unique(.data$sensor)), collapse = ";"),
    .groups = "drop"
  ) %>%
  dplyr::left_join(
    grid_compatibility %>%
      dplyr::filter(.data$sensor_group == "all_selected") %>%
      dplyr::select("water_year", "grid_status", "safe_for_stack_without_resampling", "n_unique_crs", "n_unique_resolution", "n_unique_extent", "n_unique_dimensions"),
    by = "water_year"
  ) %>%
  dplyr::left_join(
    water_year_support %>%
      dplyr::select("water_year", "n_observation_dates", "median_gap_days", "max_gap_days", "annual_max_readiness", "sequence_metric_readiness"),
    by = "water_year"
  ) %>%
  dplyr::mutate(
    stack_compatible_without_alignment = .data$safe_for_stack_without_resampling,
    needs_crop = .data$grid_status %in% c("mixed_extent", "mixed_resolution") | !.data$safe_for_stack_without_resampling,
    needs_snap = .data$grid_status %in% c("mixed_extent", "mixed_resolution") | !.data$safe_for_stack_without_resampling,
    needs_resample = .data$grid_status %in% c("mixed_extent", "mixed_resolution") | !.data$safe_for_stack_without_resampling,
    has_mixed_resolution = .data$n_unique_resolution > 1,
    has_mixed_crs = .data$n_unique_crs > 1,
    recommended_build_status = dplyr::case_when(
      .data$n_valid_source_rasters < .data$n_source_rasters ~ "skip_grid_issue",
      .data$has_mixed_crs ~ "skip_grid_issue",
      .data$n_observation_dates < 6 ~ "skip_insufficient_support",
      .data$grid_status == "compatible" ~ "build",
      .data$grid_status %in% c("mixed_extent", "mixed_resolution") ~ "build_with_alignment",
      TRUE ~ "manual_review"
    ),
    notes = dplyr::case_when(
      .data$recommended_build_status == "build" ~ "Built directly on reference grid policy; no source-year stack incompatibility flagged by Task 10.",
      .data$recommended_build_status == "build_with_alignment" ~ "Built with explicit nearest-neighbour categorical alignment to the canonical annual occurrence grid.",
      TRUE ~ "Not built; see recommended_build_status."
    )
  )

readr::write_csv(year_decisions, file.path(csv_dir, "mer_raster_input_summary_by_water_year.csv"))
readr::write_csv(year_decisions, file.path(diagnostics_25_dir, "mer_raster_build_decisions_by_water_year.csv"))

build_years <- year_decisions %>%
  dplyr::filter(.data$recommended_build_status %in% c("build", "build_with_alignment")) %>%
  dplyr::arrange(.data$water_year) %>%
  dplyr::pull(.data$water_year)

if (length(build_years) == 0) {
  stop("No water years selected for MER annual maximum production build.", call. = FALSE)
}

output_dirs <- list(
  annual_max = annual_max_dir,
  period_summaries = period_summary_dir
)

## Production annual rasters ----

build_results <- lapply(build_years, function(this_year) {
  message("Building MER annual maximum products for ", this_year)
  year_inventory <- inventory %>%
    dplyr::filter(.data$selected_for_mer_raster, .data$water_year == this_year) %>%
    dplyr::arrange(.data$date, .data$sensor, .data$file_name)

  gayini_mer_build_annual_products_for_year(
    year_inventory = year_inventory,
    template = reference_template,
    output_dirs = output_dirs,
    wet_values = WET_VALUES,
    valid_values = VALID_VALUES,
    support_thresholds = SUPPORT_THRESHOLDS,
    overwrite = OVERWRITE_PRODUCTION_MER_OUTPUTS
  )
})

annual_manifest <- dplyr::bind_rows(lapply(build_results, function(x) {
  x %>% dplyr::select(-"source_log")
}))

source_alignment_log <- dplyr::bind_rows(lapply(build_results, function(x) {
  x$source_log[[1]]
}))

readr::write_csv(source_alignment_log, file.path(diagnostics_25_dir, "mer_source_raster_alignment_log.csv"))

## Input census with aligned pixel counts ----

production_census <- inventory %>%
  dplyr::left_join(
    value_schema %>%
      dplyr::select(
        "source_raster_path",
        pixel_value_schema = "unique_values_sample",
        "other_values_present",
        "strict_wet_rule_supported"
      ),
    by = "source_raster_path"
  ) %>%
  dplyr::left_join(
    source_alignment_log %>%
      dplyr::select("source_raster_path", "valid_pixel_count", "wet_pixel_count"),
    by = "source_raster_path"
  ) %>%
  dplyr::transmute(
    source_raster = .data$source_raster_path,
    date = .data$date,
    water_year = .data$water_year,
    sensor = .data$sensor,
    path_exists = .data$exists,
    can_open = .data$can_open,
    crs = .data$crs,
    resolution_x = .data$raster_xres,
    resolution_y = .data$raster_yres,
    extent = paste(.data$extent_xmin, .data$extent_xmax, .data$extent_ymin, .data$extent_ymax, sep = ";"),
    nrow = .data$raster_nrow,
    ncol = .data$raster_ncol,
    pixel_value_schema = .data$pixel_value_schema,
    wet_values = "1",
    dry_values = "0",
    nodata_values = "3;15;255;NA treated as invalid/non-valid for production strict rule",
    valid_pixel_count = .data$valid_pixel_count,
    wet_pixel_count = .data$wet_pixel_count,
    notes = dplyr::case_when(
      .data$other_values_present %in% TRUE ~ "Extra sampled values present; production strict rule treats them as invalid/non-valid.",
      TRUE ~ "Production strict rule: wet value 1 only; valid values 0,1,2."
    )
  )

readr::write_csv(production_census, file.path(csv_dir, "mer_raster_input_census_production.csv"))

## Period summaries ----

period_manifest <- gayini_mer_build_period_summary_rasters(
  annual_manifest = annual_manifest,
  output_dir = period_summary_dir,
  management_change_date = MANAGEMENT_CHANGE_DATE,
  overwrite = OVERWRITE_PRODUCTION_MER_OUTPUTS
)

## Output manifest ----

annual_output_manifest <- annual_manifest %>%
  tidyr::pivot_longer(
    cols = c("annual_max_path", "valid_count_path", "wet_count_path", "support_class_path", "wet_fraction_path"),
    names_to = "output_type",
    values_to = "path"
  ) %>%
  dplyr::mutate(
    exists = file.exists(.data$path),
    output_family = "annual_max",
    value_definition = dplyr::case_when(
      .data$output_type == "annual_max_path" ~ "1 observed wet at least once; 0 observed valid dry never wet; NA no valid observation/outside mask.",
      .data$output_type == "valid_count_path" ~ "Count of valid observations with pixel class 0, 1 or 2.",
      .data$output_type == "wet_count_path" ~ "Count of strict wet observations with pixel class 1.",
      .data$output_type == "support_class_path" ~ "0 no support; 1 low 1-5; 2 moderate 6-11; 3 high >=12 valid observations.",
      .data$output_type == "wet_fraction_path" ~ "Wet observation count / valid observation count; observed fraction only, not hydroperiod.",
      TRUE ~ NA_character_
    )
  )

period_output_manifest <- period_manifest %>%
  dplyr::transmute(
    water_year = NA_character_,
    year_label = NA_character_,
    output_type = .data$output_type,
    path = .data$path,
    exists = .data$exists,
    output_family = "period_summary",
    value_definition = .data$notes
  )

output_manifest <- dplyr::bind_rows(annual_output_manifest, period_output_manifest) %>%
  dplyr::mutate(
    created_by = "scripts/06_mer/07_build_mer_annual_max_rasters.R",
    created_at = format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"),
    caveat = "MER annual maximum observed wet extent is supplementary and is not hydroperiod, flood duration, or depth."
  )

readr::write_csv(output_manifest, file.path(csv_dir, "mer_raster_output_manifest.csv"))
readr::write_csv(annual_manifest, file.path(diagnostics_25_dir, "mer_annual_raster_build_manifest.csv"))
readr::write_csv(period_manifest, file.path(diagnostics_25_dir, "mer_period_summary_raster_manifest.csv"))

message("Task 12 MER annual maximum raster build complete.")
message("Built water years: ", paste(build_years, collapse = ", "))
message("Annual raster manifest: ", file.path(csv_dir, "mer_raster_output_manifest.csv"))
message("Grid policy: ", policy_path)
