## -----------------------------------------------------------------------------
## Gayini remote sensing workflow
## 05c_extract_landsat_inundation_full.R
## -----------------------------------------------------------------------------


## Purpose:
## Scale the Landsat annual inundation extraction from the 05b all-plot
## development-raster test to the full annual Landsat inundation archive.


## Landsat annual inundation values are treated as whole-number inundation counts
## for each water year, based on Adrian's current notes. The primary derived
## metric is inundated_any_pct: the area percentage of each plot with count > 0.


## This is the full Landsat annual inundation extraction step. It writes the
## project-ready Landsat inundation time series for later combination with
## fractional cover and daily/Sentinel-style inundation outputs.


## Setup ----


root_dir <- normalizePath("D:/Github_repos/Gayini", winslash = "/", mustWork = TRUE)


source(file.path(root_dir, "R", "gayini_helpers.R"))
source(file.path(root_dir, "R", "inundation_extraction_functions.R"))


message("Using inundation functions from: ", file.path(root_dir, "R", "inundation_extraction_functions.R"))

if (!exists("gayini_extract_landsat_inundation_collection", mode = "function")) {
  stop(
    "Required function gayini_extract_landsat_inundation_collection() was not loaded.
    Check R/inundation_extraction_functions.R.",
    call. = FALSE
  )
}

required_packages <- c(
  "sf",
  "terra",
  "exactextractr",
  "dplyr",
  "tidyr",
  "readr",
  "tibble",
  "ggplot2"
)

gayini_check_packages(required_packages)


## User settings ----


TARGET_PRODUCT <- "landsat_inundation"
BUFFER_PIXELS <- 0

COUNT_VALUES <- 0:3
NODATA_VALUES <- c(255)

VERY_LOW_COVERAGE_PCT <- 25
ADEQUATE_COVERAGE_PCT <- 75

EXPECTED_PLOTS <- 66
EXPECTED_RASTERS <- 35


## Decision notes ----


## Use all clean hectare plots and all catalogued Landsat annual inundation
## rasters. This follows the passed 05a and 05b tests.


## Preserve annual count values 0, 1, 2 and 3 as separate plot-area percentages.
## The primary derived metric is inundated_any_pct = area percentage where count > 0.


## Do not collapse to majority_count for interpretation. Majority count is only
## retained as a simple diagnostic.


## Treat 255 as NoData even where raster metadata does not expose it
## consistently.


## Coverage thresholds are based on percentage of expected plot coverage, not
## raw cell count, because annual inundation rasters have mixed resolutions.


## Paths ----


plots_path <- file.path(
  root_dir,
  "data_intermediate",
  "spatial",
  "plots_clean.gpkg"
)

raster_catalog_path <- file.path(
  root_dir,
  "data_intermediate",
  "raster_catalog",
  "raster_catalog.csv"
)

output_csv_dir <- file.path(root_dir, "Output", "csv")
output_diagnostics_dir <- file.path(root_dir, "Output", "diagnostics")
output_figures_dir <- file.path(root_dir, "Output", "figures")
data_processed_dir <- file.path(root_dir, "data_processed")

dir.create(output_csv_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(output_diagnostics_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(output_figures_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(data_processed_dir, recursive = TRUE, showWarnings = FALSE)

output_path <- file.path(
  output_csv_dir,
  "05c_landsat_inundation_full.csv"
)

processed_output_path <- file.path(
  data_processed_dir,
  "plot_landsat_inundation_timeseries.csv"
)

checks_path <- file.path(
  output_diagnostics_dir,
  "05c_landsat_inundation_full_checks.csv"
)

count_summary_path <- file.path(
  output_diagnostics_dir,
  "05c_landsat_inundation_full_count_summary.csv"
)

coverage_summary_path <- file.path(
  output_diagnostics_dir,
  "05c_landsat_inundation_full_coverage_summary.csv"
)

plot_summary_path <- file.path(
  output_diagnostics_dir,
  "05c_landsat_inundation_full_plot_summary.csv"
)

treatment_summary_path <- file.path(
  output_diagnostics_dir,
  "05c_landsat_inundation_full_treatment_summary.csv"
)

coverage_status_summary_path <- file.path(
  output_diagnostics_dir,
  "05c_landsat_inundation_full_coverage_status_summary.csv"
)

inundated_heatmap_path <- file.path(
  output_figures_dir,
  "05c_landsat_inundation_full_inundated_any_heatmap.png"
)

treatment_timeseries_path <- file.path(
  output_figures_dir,
  "05c_landsat_inundation_full_mean_inundated_any_by_treatment.png"
)

coverage_heatmap_path <- file.path(
  output_figures_dir,
  "05c_landsat_inundation_full_valid_coverage_heatmap.png"
)

count_area_treatment_path <- file.path(
  output_figures_dir,
  "05c_landsat_inundation_full_count_area_by_treatment.png"
)

majority_count_heatmap_path <- file.path(
  output_figures_dir,
  "05c_landsat_inundation_full_majority_count_heatmap.png"
)


## Clean stale 05c outputs ----


output_files_to_refresh <- c(
  output_path,
  processed_output_path,
  checks_path,
  count_summary_path,
  coverage_summary_path,
  plot_summary_path,
  treatment_summary_path,
  coverage_status_summary_path,
  inundated_heatmap_path,
  treatment_timeseries_path,
  coverage_heatmap_path,
  count_area_treatment_path,
  majority_count_heatmap_path
)

existing_output_files <- output_files_to_refresh[file.exists(output_files_to_refresh)]

if (length(existing_output_files) > 0) {
  file.remove(existing_output_files)
}


## Input checks ----


required_files <- c(
  plots_path,
  raster_catalog_path
)

missing_files <- required_files[!file.exists(required_files)]

if (length(missing_files) > 0) {
  stop(
    "Missing required files:\n",
    paste(missing_files, collapse = "\n"),
    call. = FALSE
  )
}


## Read inputs ----


plots_clean <- sf::st_read(
  plots_path,
  quiet = TRUE
)

message("Clean plots available: ", nrow(plots_clean))

if (nrow(plots_clean) != EXPECTED_PLOTS) {
  warning(
    "Expected ",
    EXPECTED_PLOTS,
    " clean plots, but found ",
    nrow(plots_clean),
    ". Continue, but review vector prep outputs.",
    call. = FALSE
  )
}

raster_catalog <- readr::read_csv(
  raster_catalog_path,
  show_col_types = FALSE
)

message("Raster catalogue rows: ", nrow(raster_catalog))

raster_catalog <- gayini_standardise_inundation_catalog(raster_catalog)


## Prepare plot metadata ----


plot_metadata <- plots_clean |>
  sf::st_drop_geometry() |>
  dplyr::select(
    dplyr::any_of(c("plot_id", "vegetation", "treatment", "area_ha"))
  )

if (!"treatment" %in% names(plot_metadata)) {
  plot_metadata$treatment <- "unknown_treatment"
}

if (!"vegetation" %in% names(plot_metadata)) {
  plot_metadata$vegetation <- "unknown_vegetation"
}

plot_metadata <- plot_metadata |>
  dplyr::select(
    .data$plot_id,
    .data$vegetation,
    .data$treatment,
    dplyr::everything()
  )


## Select full Landsat annual inundation rasters ----


landsat_inundation_catalog <- raster_catalog |>
  dplyr::filter(.data$product == TARGET_PRODUCT) |>
  dplyr::arrange(.data$date_start, .data$file_name)

if (nrow(landsat_inundation_catalog) == 0) {
  stop(
    "No Landsat annual inundation rasters found in the raster catalogue.",
    call. = FALSE
  )
}

if (nrow(landsat_inundation_catalog) != EXPECTED_RASTERS) {
  warning(
    "Expected ",
    EXPECTED_RASTERS,
    " full Landsat annual inundation rasters, but found ",
    nrow(landsat_inundation_catalog),
    ". Continue, but review the raster catalogue.",
    call. = FALSE
  )
}

message("Landsat annual inundation full rasters: ", nrow(landsat_inundation_catalog))
message(
  "Landsat annual inundation sensors: ",
  paste(sort(unique(landsat_inundation_catalog$sensor)), collapse = ", ")
)


## Run extraction ----


extraction_output <- gayini_extract_landsat_inundation_collection(
  raster_catalog = landsat_inundation_catalog,
  plots_sf = plots_clean,
  count_values = COUNT_VALUES,
  nodata_values = NODATA_VALUES,
  buffer_pixels = BUFFER_PIXELS,
  extraction_scope = "landsat_inundation_full",
  legend_status = "unconfirmed",
  very_low_pct = VERY_LOW_COVERAGE_PCT,
  adequate_pct = ADEQUATE_COVERAGE_PCT
)

expected_rows <- nrow(plots_clean) * nrow(landsat_inundation_catalog)

extraction_output <- extraction_output |>
  dplyr::left_join(
    plot_metadata |>
      dplyr::select(
        .data$plot_id,
        .data$vegetation,
        .data$treatment
      ),
    by = "plot_id"
  ) |>
  dplyr::relocate(
    dplyr::any_of(c("vegetation", "treatment")),
    .after = .data$plot_area_ha
  ) |>
  dplyr::mutate(
    valid_coverage_pct_display = pmin(.data$valid_coverage_pct, 100)
  )

required_count_output_columns <- c(
  paste0("count_", COUNT_VALUES, "_area_pct"),
  "other_count_area_pct",
  "inundated_any_pct",
  "mean_inundation_count",
  "majority_count"
)

missing_count_output_columns <- setdiff(required_count_output_columns, names(extraction_output))

if (length(missing_count_output_columns) > 0) {
  stop(
    "The 05c extraction output is missing required count-based columns: ",
    paste(missing_count_output_columns, collapse = ", "),
    ". This usually means the old inundation function file is still being sourced.",
    call. = FALSE
  )
}

legacy_class_columns <- grep("^class_[0-9]+_pct$|^other_class_pct$|^majority_class$", names(extraction_output), value = TRUE)

if (length(legacy_class_columns) > 0) {
  warning(
    "Legacy class-based columns are present in 05c output: ",
    paste(legacy_class_columns, collapse = ", "),
    ". These should be removed before scaling to 05c.",
    call. = FALSE
  )
}


## Create diagnostics ----


checks <- gayini_make_landsat_inundation_checks(
  extraction_output = extraction_output,
  expected_rows = expected_rows
)

count_summary <- gayini_make_landsat_inundation_count_summary(extraction_output)

coverage_summary <- gayini_make_inundation_coverage_summary(extraction_output)

plot_summary <- extraction_output |>
  dplyr::summarise(
    rows                         = dplyr::n(),
    mean_inundated_any_pct       = mean(.data$inundated_any_pct, na.rm = TRUE),
    median_inundated_any_pct     = median(.data$inundated_any_pct, na.rm = TRUE),
    max_inundated_any_pct        = max(.data$inundated_any_pct, na.rm = TRUE),
    mean_inundation_count        = mean(.data$mean_inundation_count, na.rm = TRUE),
    median_valid_coverage_pct    = median(.data$valid_coverage_pct, na.rm = TRUE),
    low_coverage_rows            = sum(.data$valid_coverage_status %in% c("very_low_coverage", "low_coverage"), na.rm = TRUE),
    no_valid_coverage_rows       = sum(.data$valid_coverage_status == "no_valid_coverage", na.rm = TRUE),
    .by = c("plot_id", "vegetation", "treatment")
  ) |>
  dplyr::arrange(.data$plot_id)

treatment_summary <- extraction_output |>
  dplyr::summarise(
    n_plots                      = dplyr::n_distinct(.data$plot_id),
    rows                         = dplyr::n(),
    mean_inundated_any_pct       = mean(.data$inundated_any_pct, na.rm = TRUE),
    median_inundated_any_pct     = median(.data$inundated_any_pct, na.rm = TRUE),
    mean_inundation_count        = mean(.data$mean_inundation_count, na.rm = TRUE),
    median_valid_coverage_pct    = median(.data$valid_coverage_pct, na.rm = TRUE),
    low_coverage_rows            = sum(.data$valid_coverage_status %in% c("very_low_coverage", "low_coverage"), na.rm = TRUE),
    no_valid_coverage_rows       = sum(.data$valid_coverage_status == "no_valid_coverage", na.rm = TRUE),
    .by = c("treatment", "date_start", "date_end", "water_year")
  ) |>
  dplyr::arrange(.data$date_start, .data$treatment)

coverage_status_summary <- extraction_output |>
  dplyr::count(.data$valid_coverage_status, name = "rows") |>
  dplyr::mutate(percent_rows = 100 * .data$rows / sum(.data$rows)) |>
  dplyr::arrange(dplyr::desc(.data$rows))


## Write outputs ----


readr::write_csv(extraction_output, output_path)
readr::write_csv(extraction_output, processed_output_path)
readr::write_csv(checks, checks_path)
readr::write_csv(count_summary, count_summary_path)
readr::write_csv(coverage_summary, coverage_summary_path)
readr::write_csv(plot_summary, plot_summary_path)
readr::write_csv(treatment_summary, treatment_summary_path)
readr::write_csv(coverage_status_summary, coverage_status_summary_path)

message("Wrote: ", output_path)
message("Wrote: ", processed_output_path)
message("Wrote: ", checks_path)
message("Wrote: ", count_summary_path)
message("Wrote: ", coverage_summary_path)
message("Wrote: ", plot_summary_path)
message("Wrote: ", treatment_summary_path)
message("Wrote: ", coverage_status_summary_path)


## Diagnostic figures ----


inundated_heatmap <- ggplot2::ggplot(
  extraction_output,
  ggplot2::aes(
    x = .data$date_start,
    y = .data$plot_id,
    fill = .data$inundated_any_pct
  )
) +
  ggplot2::geom_tile() +
  ggplot2::labs(
    title = "05b Landsat annual inundation full extraction: inundated area",
    subtitle = "All plots; all annual Landsat inundation rasters; inundated_any_pct = area where annual count > 0",
    x = "Raster start date",
    y = "Plot ID",
    fill = "Inundated area (%)"
  ) +
  ggplot2::theme_minimal(base_size = 9) +
  ggplot2::theme(
    plot.title = ggplot2::element_text(size = 11),
    plot.subtitle = ggplot2::element_text(size = 9),
    axis.text.y = ggplot2::element_text(size = 5),
    legend.position = "right"
  )

ggplot2::ggsave(
  filename = inundated_heatmap_path,
  plot = inundated_heatmap,
  width = 11,
  height = 11,
  dpi = 300
)

treatment_timeseries <- ggplot2::ggplot(
  treatment_summary,
  ggplot2::aes(
    x = .data$date_start,
    y = .data$mean_inundated_any_pct,
    colour = .data$treatment,
    group = .data$treatment
  )
) +
  ggplot2::geom_line(linewidth = 0.35, na.rm = TRUE) +
  ggplot2::geom_point(size = 1.2, na.rm = TRUE) +
  ggplot2::labs(
    title = "05b Landsat annual inundation full extraction: mean inundated area by treatment",
    subtitle = "Diagnostic only; treatment comparison is not interpreted at this stage",
    x = "Raster start date",
    y = "Mean inundated area (%)",
    colour = "Treatment"
  ) +
  ggplot2::theme_minimal(base_size = 9) +
  ggplot2::theme(
    plot.title = ggplot2::element_text(size = 11),
    plot.subtitle = ggplot2::element_text(size = 9),
    legend.position = "bottom"
  )

ggplot2::ggsave(
  filename = treatment_timeseries_path,
  plot = treatment_timeseries,
  width = 10,
  height = 6,
  dpi = 300
)

coverage_heatmap <- ggplot2::ggplot(
  extraction_output,
  ggplot2::aes(
    x = .data$date_start,
    y = .data$plot_id,
    fill = .data$valid_coverage_pct_display
  )
) +
  ggplot2::geom_tile() +
  ggplot2::geom_hline(yintercept = 0, alpha = 0) +
  ggplot2::labs(
    title = "05b Landsat annual inundation full extraction: valid coverage",
    subtitle = "Coverage is percent of expected plot coverage at each raster resolution",
    x = "Raster start date",
    y = "Plot ID",
    fill = "Valid coverage (%)
plot cap 100"
  ) +
  ggplot2::theme_minimal(base_size = 9) +
  ggplot2::theme(
    plot.title = ggplot2::element_text(size = 11),
    plot.subtitle = ggplot2::element_text(size = 9),
    axis.text.y = ggplot2::element_text(size = 5),
    legend.position = "right"
  )

ggplot2::ggsave(
  filename = coverage_heatmap_path,
  plot = coverage_heatmap,
  width = 11,
  height = 11,
  dpi = 300
)

count_area_plot_data <- extraction_output |>
  dplyr::select(
    .data$plot_id,
    .data$treatment,
    .data$date_start,
    dplyr::all_of(paste0("count_", COUNT_VALUES, "_area_pct"))
  ) |>
  tidyr::pivot_longer(
    cols = dplyr::all_of(paste0("count_", COUNT_VALUES, "_area_pct")),
    names_to = "inundation_count",
    values_to = "area_pct"
  ) |>
  dplyr::mutate(
    inundation_count = gsub("count_", "", .data$inundation_count),
    inundation_count = gsub("_area_pct", "", .data$inundation_count),
    inundation_count = paste0("Count ", .data$inundation_count)
  ) |>
  dplyr::summarise(
    mean_area_pct = mean(.data$area_pct, na.rm = TRUE),
    .by = c("treatment", "date_start", "inundation_count")
  )

count_area_treatment_plot <- ggplot2::ggplot(
  count_area_plot_data,
  ggplot2::aes(
    x = .data$date_start,
    y = .data$mean_area_pct,
    colour = .data$inundation_count
  )
) +
  ggplot2::geom_line(linewidth = 0.35, na.rm = TRUE) +
  ggplot2::geom_point(size = 1.0, na.rm = TRUE) +
  ggplot2::facet_wrap(~ treatment, ncol = 1) +
  ggplot2::labs(
    title = "05b Landsat annual inundation full extraction: mean count-area percentages by treatment",
    subtitle = "Count values treated as water-year inundation counts; legend unconfirmed",
    x = "Raster start date",
    y = "Mean area within valid plot coverage (%)",
    colour = "Inundation count"
  ) +
  ggplot2::theme_minimal(base_size = 9) +
  ggplot2::theme(
    plot.title = ggplot2::element_text(size = 11),
    plot.subtitle = ggplot2::element_text(size = 9),
    strip.text = ggplot2::element_text(size = 8),
    legend.position = "bottom"
  )

ggplot2::ggsave(
  filename = count_area_treatment_path,
  plot = count_area_treatment_plot,
  width = 10,
  height = 8,
  dpi = 300
)

majority_count_heatmap <- ggplot2::ggplot(
  extraction_output,
  ggplot2::aes(
    x = .data$date_start,
    y = .data$plot_id,
    fill = factor(.data$majority_count)
  )
) +
  ggplot2::geom_tile() +
  ggplot2::labs(
    title = "05b Landsat annual inundation full extraction: majority count",
    subtitle = "Diagnostic only; count-area fractions and inundated_any_pct are primary",
    x = "Raster start date",
    y = "Plot ID",
    fill = "Majority count"
  ) +
  ggplot2::theme_minimal(base_size = 9) +
  ggplot2::theme(
    plot.title = ggplot2::element_text(size = 11),
    plot.subtitle = ggplot2::element_text(size = 9),
    axis.text.y = ggplot2::element_text(size = 5),
    legend.position = "right"
  )

ggplot2::ggsave(
  filename = majority_count_heatmap_path,
  plot = majority_count_heatmap,
  width = 11,
  height = 11,
  dpi = 300
)

message("Wrote: ", inundated_heatmap_path)
message("Wrote: ", treatment_timeseries_path)
message("Wrote: ", coverage_heatmap_path)
message("Wrote: ", count_area_treatment_path)
message("Wrote: ", majority_count_heatmap_path)


## Final checks ----


row_count_matches <- nrow(extraction_output) == expected_rows

if (!row_count_matches) {
  warning(
    "Unexpected row count. Expected ",
    expected_rows,
    " but wrote ",
    nrow(extraction_output),
    ".",
    call. = FALSE
  )
}

unexpected_count_rows <- sum(
  !is.na(extraction_output$other_count_area_pct) &
    extraction_output$other_count_area_pct > 0
)

count_columns_present <- all(
  paste0("count_", COUNT_VALUES, "_area_pct") %in% names(extraction_output)
)

inundated_any_problem_rows <- sum(
  !is.na(extraction_output$inundated_any_pct) &
    (
      extraction_output$inundated_any_pct < 0 |
        extraction_output$inundated_any_pct > 100
    )
)

coverage_problem_rows <- sum(
  extraction_output$valid_coverage_status %in% c("no_valid_coverage", "very_low_coverage", "low_coverage"),
  na.rm = TRUE
)

has_warning <- !row_count_matches |
  !count_columns_present |
  unexpected_count_rows > 0 |
  inundated_any_problem_rows > 0 |
  coverage_problem_rows > 0

message("Landsat inundation 05c full extraction complete.")
message("Rows written: ", nrow(extraction_output))
message("Expected rows: ", expected_rows)
message("Review CSV outputs and diagnostic plots before using the Landsat inundation output for interpretation or combined modelling.")

if (has_warning) {
  warning(
    "Landsat inundation 05c warnings were created. Review: ",
    checks_path,
    call. = FALSE
  )
}



####################################################################################################
############################################ TBC ###################################################
####################################################################################################
