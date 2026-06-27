## -----------------------------------------------------------------------------
## Gayini remote sensing workflow
## 24b_build_mer_annual_max_raster_smoke_test.R
## -----------------------------------------------------------------------------


## Purpose:
## Controlled one-water-year smoke test for MER annual maximum observed inundation
## rasters. This is not a full all-year MER raster build.


RUN_SMOKE_TEST <- TRUE
RUN_FULL_BUILD <- FALSE
WRITE_SEQUENCE_RASTERS <- FALSE
OVERWRITE_OUTPUTS <- FALSE
SMOKE_TEST_PLOT_CROP_N <- 12

root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", "D:/Github_repos/Gayini"), winslash = "/", mustWork = TRUE)

source(file.path(root_dir, "R", "gayini_analysis_base_functions.R"))
source(file.path(root_dir, "R", "gayini_mer_raster_functions.R"))

required_packages <- c("dplyr", "readr", "stringr", "magrittr", "tibble", "ggplot2", "terra")
gayini_mer_check_packages(required_packages)

library(dplyr)
library(readr)
library(stringr)
library(magrittr)
library(tibble)
library(ggplot2)
library(terra)

if (RUN_FULL_BUILD) {
  stop("RUN_FULL_BUILD must remain FALSE for Task 10.", call. = FALSE)
}

if (WRITE_SEQUENCE_RASTERS) {
  stop("WRITE_SEQUENCE_RASTERS must remain FALSE for Task 10.", call. = FALSE)
}

if (!RUN_SMOKE_TEST) {
  message("RUN_SMOKE_TEST is FALSE; no raster written.")
  quit(save = "no", status = 0)
}

gayini_mer_make_dirs(root_dir)

diagnostics_dir <- file.path(root_dir, "Output", "diagnostics", "24_mer_raster_build")
csv_dir <- file.path(root_dir, "Output", "csv", "MER", "raster_build")
figure_dir <- file.path(root_dir, "Output", "figures", "review", "MER", "raster_build")
annual_max_dir <- file.path(root_dir, "Output", "rasters", "MER", "annual_max")
support_dir <- file.path(root_dir, "Output", "rasters", "MER", "support")
report_dir <- file.path(root_dir, "Output", "reports", "MER")

required_census <- c(
  file.path(diagnostics_dir, "mer_raster_input_inventory.csv"),
  file.path(diagnostics_dir, "mer_raster_grid_compatibility.csv"),
  file.path(diagnostics_dir, "mer_raster_water_year_support.csv"),
  file.path(diagnostics_dir, "mer_raster_value_schema.csv"),
  file.path(diagnostics_dir, "mer_raster_build_readiness_checks.csv")
)

missing_census <- required_census[!file.exists(required_census)]
if (length(missing_census) > 0) {
  stop("Run scripts/24a_census_mer_raster_inputs.R first. Missing: ", paste(missing_census, collapse = "; "), call. = FALSE)
}

inventory <- readr::read_csv(file.path(diagnostics_dir, "mer_raster_input_inventory.csv"), show_col_types = FALSE) %>%
  dplyr::mutate(date = as.Date(.data$date))
grid_compatibility <- readr::read_csv(file.path(diagnostics_dir, "mer_raster_grid_compatibility.csv"), show_col_types = FALSE)
water_year_support <- readr::read_csv(file.path(diagnostics_dir, "mer_raster_water_year_support.csv"), show_col_types = FALSE)
readiness <- readr::read_csv(file.path(diagnostics_dir, "mer_raster_build_readiness_checks.csv"), show_col_types = FALSE)

blocking_failures <- readiness %>%
  dplyr::filter(.data$status == "FAIL")

if (nrow(blocking_failures) > 0) {
  reason_path <- file.path(report_dir, "mer_raster_smoke_test_not_run_reason.md")
  writeLines(
    c(
      "# MER Raster Smoke Test Not Run",
      "",
      "The smoke test was not run because readiness checks failed.",
      "",
      paste0("- ", blocking_failures$check_id, ": ", blocking_failures$check_name, " - ", blocking_failures$evidence)
    ),
    reason_path
  )
  stop("Smoke test not safe. See: ", reason_path, call. = FALSE)
}

candidate_years <- water_year_support %>%
  dplyr::left_join(
    grid_compatibility %>%
      dplyr::filter(.data$sensor_group == "all_selected") %>%
      dplyr::select("water_year", "grid_status", "safe_for_stack_without_resampling"),
    by = "water_year",
    suffix = c("", "_grid")
  ) %>%
  dplyr::filter(
    .data$annual_max_readiness == "Ready for smoke test",
    .data$safe_for_stack_without_resampling %in% TRUE
  ) %>%
  dplyr::arrange(.data$n_observation_dates, .data$max_gap_days)

if (nrow(candidate_years) == 0) {
  reason_path <- file.path(report_dir, "mer_raster_smoke_test_not_run_reason.md")
  writeLines(
    c(
      "# MER Raster Smoke Test Not Run",
      "",
      "No water year passed both annual maximum readiness and stack-safe grid compatibility.",
      "",
      "Recommended action: review `mer_raster_grid_compatibility.csv` and decide whether a sensor-specific or explicit alignment policy is acceptable."
    ),
    reason_path
  )
  stop("Smoke test not safe. See: ", reason_path, call. = FALSE)
}

smoke_water_year <- candidate_years$water_year[[1]]
smoke_label <- paste0("WY", substr(smoke_water_year, 6, 9))

smoke_inventory <- inventory %>%
  dplyr::filter(.data$selected_for_mer_raster, .data$water_year == smoke_water_year) %>%
  dplyr::arrange(.data$date, .data$sensor, .data$file_name)

if (!all(smoke_inventory$exists) || !all(smoke_inventory$can_open)) {
  stop("Selected smoke-test year has missing or unopenable rasters, despite readiness table. Re-run census.", call. = FALSE)
}

annual_max_path <- file.path(
  annual_max_dir,
  paste0("mer_annual_max_observed_inundation_", smoke_label, "_strict_value_1_SMOKE_TEST.tif")
)
observation_count_path <- file.path(
  support_dir,
  paste0("mer_observation_count_", smoke_label, "_SMOKE_TEST.tif")
)
valid_count_path <- file.path(
  support_dir,
  paste0("mer_valid_observation_count_", smoke_label, "_SMOKE_TEST.tif")
)

plots_path <- file.path(root_dir, "data_intermediate", "spatial", "plots_clean.gpkg")
crop_extent <- NULL
crop_note <- "full raster extent"
if (file.exists(plots_path)) {
  reference_raster <- terra::rast(smoke_inventory$source_raster_path[[1]])
  plots_vect <- terra::vect(plots_path)
  plots_vect <- terra::project(plots_vect, terra::crs(reference_raster))
  plot_centroids <- terra::centroids(plots_vect)
  centroid_xy <- terra::crds(plot_centroids)
  centre_xy <- c(stats::median(centroid_xy[, 1]), stats::median(centroid_xy[, 2]))
  distance_to_centre <- sqrt((centroid_xy[, 1] - centre_xy[[1]])^2 + (centroid_xy[, 2] - centre_xy[[2]])^2)
  crop_rows <- order(distance_to_centre)[seq_len(min(SMOKE_TEST_PLOT_CROP_N, length(distance_to_centre)))]
  plots_crop_vect <- plots_vect[crop_rows, ]
  plot_extent <- terra::ext(plots_crop_vect)
  x_pad <- max(terra::res(reference_raster)[[1]] * 10, 300)
  y_pad <- max(abs(terra::res(reference_raster)[[2]]) * 10, 300)
  crop_extent <- terra::ext(
    plot_extent$xmin - x_pad,
    plot_extent$xmax + x_pad,
    plot_extent$ymin - y_pad,
    plot_extent$ymax + y_pad
  )
  crop_note <- paste0("central ", length(crop_rows), "-plot envelope plus 300 m / 10 pixel buffer")
}

build_mer_annual_max_observed_raster(
  raster_paths = smoke_inventory$source_raster_path,
  output_path = annual_max_path,
  wet_values = 1,
  crop_extent = crop_extent,
  overwrite = OVERWRITE_OUTPUTS
)

build_mer_observation_support_raster(
  raster_paths = smoke_inventory$source_raster_path,
  observation_count_path = observation_count_path,
  valid_observation_count_path = valid_count_path,
  crop_extent = crop_extent,
  overwrite = OVERWRITE_OUTPUTS
)

existing_mer_path <- file.path(root_dir, "Output", "csv", "05b_MER_plot_inundation_dynamic_metrics.csv")

plot_qa <- extract_mer_raster_to_plots_for_qa(
  raster_path = annual_max_path,
  plots_path = plots_path,
  plot_id_col = "plot_id"
) %>%
  compare_raster_mer_to_existing_plot_mer(
    existing_mer_path = existing_mer_path,
    smoke_water_year = smoke_water_year
  ) %>%
  dplyr::mutate(
    smoke_water_year = smoke_water_year,
    annual_max_raster_path = annual_max_path,
    observation_count_raster_path = observation_count_path,
    valid_observation_count_raster_path = valid_count_path,
    covered_by_smoke_extent = !is.na(.data$raster_annual_max_observed_inundated_pct)
  )

plot_qa_path <- file.path(csv_dir, "mer_raster_smoke_test_plot_qa.csv")
readr::write_csv(plot_qa, plot_qa_path)

if (nrow(plot_qa) > 0 && "plot_mer_annual_max_observed_inundated_pct" %in% names(plot_qa)) {
  p_qa <- ggplot2::ggplot(
    dplyr::filter(plot_qa, .data$covered_by_smoke_extent),
    ggplot2::aes(
      x = .data$plot_mer_annual_max_observed_inundated_pct,
      y = .data$raster_annual_max_observed_inundated_pct
    )
  ) +
    ggplot2::geom_abline(slope = 1, intercept = 0, colour = "grey45", linewidth = 0.4) +
    ggplot2::geom_point(size = 2.2, alpha = 0.82, colour = "#2f6f4e") +
    ggplot2::labs(
      x = "Existing plot-table MER annual max observed inundated area (%)",
      y = "Smoke-test raster extracted annual max observed inundated area (%)",
      title = paste0("MER raster smoke-test QA: ", smoke_water_year),
      subtitle = "One-year annual maximum observed inundation footprint; not hydroperiod or duration.",
      caption = "Differences can reflect raster-to-polygon extraction method and grid handling."
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank())
} else {
  p_qa <- ggplot2::ggplot() +
    ggplot2::annotate("text", x = 0, y = 0, label = "Plot vector or existing MER table unavailable; raster smoke test created but plot QA skipped.") +
    ggplot2::theme_void()
}

qa_figure_path <- file.path(figure_dir, "mer_raster_smoke_test_qa.png")
ggplot2::ggsave(qa_figure_path, p_qa, width = 7.2, height = 5.4, dpi = 220)

smoke_manifest <- tibble::tibble(
  output_type = c("annual_max_raster", "observation_count_raster", "valid_observation_count_raster", "plot_qa_csv", "qa_figure"),
  path = c(annual_max_path, observation_count_path, valid_count_path, plot_qa_path, qa_figure_path),
  exists = file.exists(c(annual_max_path, observation_count_path, valid_count_path, plot_qa_path, qa_figure_path)),
  smoke_water_year = smoke_water_year,
  note = paste0("Task 10 smoke-test output only; not a full all-year MER raster build. Spatial extent: ", crop_note, ".")
)
readr::write_csv(smoke_manifest, file.path(diagnostics_dir, "mer_raster_smoke_test_manifest.csv"))

message("MER raster smoke test complete for ", smoke_water_year)
message("Annual max raster: ", annual_max_path)
message("Observation count raster: ", observation_count_path)
message("Valid observation count raster: ", valid_count_path)
message("Plot QA: ", plot_qa_path)
message("QA figure: ", qa_figure_path)
