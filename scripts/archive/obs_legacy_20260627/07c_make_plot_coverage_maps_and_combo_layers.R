####################################################################################################


## GAYINI REMOTE SENSING PROJECT


## 07c_make_plot_coverage_maps_and_combo_layers.R


####################################################################################################


## Purpose ----


## Create larger, more readable map figures for Adrian's review.


## This script uses existing extracted tables and clean plot geometries to create:
##
##   1. Plot-level map metrics for ground-cover data coverage and inundation exposure.
##   2. Larger treatment-specific maps.
##   3. Three zone-specific zoom maps, to make individual 1 ha plots readable.
##   4. A combined plot-level hotspot/gap classification for review.
##   5. Optional raster combo layers showing valid-data coverage / inundation frequency
##      across source rasters, if the raw raster files are available locally.


## This script does not rerun polygon extraction.


## Optional raster-combo generation can be slow and requires raw rasters to be
## present at the file paths recorded in raster_catalog.csv.


## Setup ----


default_root <- "D:/Github_repos/Gayini"


helper_path <- file.path(default_root, "R", "gayini_review_figure_functions.R")


if (!file.exists(helper_path)) {
  helper_path <- file.path(getwd(), "R", "gayini_review_figure_functions.R")
}


if (!file.exists(helper_path)) {
  stop(
    "Could not find R/gayini_review_figure_functions.R. Copy the supplied R/ helper file into the project root first.",
    call. = FALSE
  )
}


source(helper_path)


root_dir <- gayini_review_find_root(default_root = default_root)


required_packages <- c(
  "sf",
  "terra",
  "dplyr",
  "tidyr",
  "readr",
  "ggplot2",
  "stringr",
  "tibble"
)


gayini_review_check_packages(required_packages)


library(sf)
library(terra)
library(dplyr)
library(tidyr)
library(readr)
library(ggplot2)
library(stringr)
library(tibble)


## User settings ----


## Main figure settings.

FIGURE_DPI          <- 300
BASE_SIZE           <- 15
ZONE_EXPAND_FRACTION <- 0.18


## The raster-combo section is deliberately off by default because it reads many
## rasters. Turn on only when the raw Input files are available and you want
## raster heatmaps/masks as well as plot-level maps.

RUN_OPTIONAL_COMBO_RASTERS <- FALSE


## Optional raster combo settings.

MAX_RASTERS_PER_COMBO <- Inf


## Paths ----


plots_path <- file.path(
  root_dir,
  "data_intermediate",
  "spatial",
  "plots_clean.gpkg"
)


boundary_path <- file.path(
  root_dir,
  "data_intermediate",
  "spatial",
  "boundary_clean.gpkg"
)


fc_path <- file.path(
  root_dir,
  "Output",
  "csv",
  "04c_fractional_cover_full.csv"
)


annual_inundation_path <- file.path(
  root_dir,
  "Output",
  "csv",
  "05c_landsat_inundation_full.csv"
)


daily_inundation_path <- file.path(
  root_dir,
  "Output",
  "csv",
  "06c_daily_inundation_full.csv"
)


raster_catalog_path <- file.path(
  root_dir,
  "data_intermediate",
  "raster_catalog",
  "raster_catalog.csv"
)


figure_dir <- file.path(
  root_dir,
  "Output",
  "figures",
  "review",
  "plot_maps"
)


csv_dir <- file.path(
  root_dir,
  "Output",
  "csv",
  "review"
)


raster_output_dir <- file.path(
  root_dir,
  "Output",
  "maps",
  "review",
  "combo_rasters"
)


gayini_review_make_dir(figure_dir)
gayini_review_make_dir(csv_dir)
gayini_review_make_dir(raster_output_dir)


plot_metrics_path <- file.path(
  csv_dir,
  "07c_plot_rs_map_metrics.csv"
)


## Read spatial inputs ----


gayini_review_required_file(plots_path)


plots <- sf::st_read(plots_path, quiet = TRUE)


if (!"plot_id" %in% names(plots)) {
  stop("plots_clean.gpkg must contain plot_id.", call. = FALSE)
}


if (file.exists(boundary_path)) {
  boundary <- sf::st_read(boundary_path, quiet = TRUE)
  boundary <- sf::st_transform(boundary, sf::st_crs(plots))
} else {
  boundary <- NULL
}


plots <- gayini_review_make_plot_zones(plots, n_zones = 3)


## Read extracted tables ----


gayini_review_required_file(fc_path)
gayini_review_required_file(annual_inundation_path)
gayini_review_required_file(daily_inundation_path)


fc <- readr::read_csv(fc_path, show_col_types = FALSE)
annual_inundation <- readr::read_csv(annual_inundation_path, show_col_types = FALSE)
daily_inundation <- readr::read_csv(daily_inundation_path, show_col_types = FALSE)


## Build plot-level map metrics ----


fc_date_status <- fc |>
  dplyr::group_by(.data$plot_id, .data$date_midpoint) |>
  dplyr::summarise(
    all_bands_adequate = all(.data$valid_coverage_status == "adequate_coverage", na.rm = TRUE),
    all_bands_missing  = all(is.na(.data$mean_value)),
    any_low_coverage   = any(.data$valid_coverage_status %in% c("low_coverage", "very_low_coverage"), na.rm = TRUE),
    .groups            = "drop"
  )


fc_coverage_summary <- fc_date_status |>
  dplyr::group_by(.data$plot_id) |>
  dplyr::summarise(
    gc_plot_dates                  = dplyr::n(),
    gc_all_bands_adequate_pct      = 100 * mean(.data$all_bands_adequate, na.rm = TRUE),
    gc_all_bands_missing_pct       = 100 * mean(.data$all_bands_missing, na.rm = TRUE),
    gc_any_low_coverage_pct        = 100 * mean(.data$any_low_coverage, na.rm = TRUE),
    .groups                        = "drop"
  )


fc_value_summary <- fc |>
  dplyr::filter(.data$valid_coverage_status == "adequate_coverage") |>
  dplyr::mutate(cover_class = gayini_review_cover_label(.data$band_label)) |>
  dplyr::group_by(.data$plot_id, .data$cover_class) |>
  dplyr::summarise(
    mean_cover_pct = gayini_review_safe_mean(.data$mean_value),
    .groups        = "drop"
  ) |>
  tidyr::pivot_wider(
    names_from  = .data$cover_class,
    values_from = .data$mean_cover_pct,
    names_prefix = "mean_"
  ) |>
  dplyr::rename_with(
    .fn = ~ gsub("[^A-Za-z0-9]+", "_", .x),
    .cols = dplyr::everything()
  )


annual_summary <- annual_inundation |>
  dplyr::group_by(.data$plot_id) |>
  dplyr::summarise(
    annual_rows                         = dplyr::n(),
    annual_mean_inundated_any_pct       = gayini_review_safe_mean(.data$inundated_any_pct),
    annual_max_inundated_any_pct        = gayini_review_safe_max(.data$inundated_any_pct),
    annual_mean_valid_coverage_pct      = gayini_review_safe_mean(.data$valid_coverage_pct),
    annual_min_valid_coverage_pct       = gayini_review_safe_min(.data$valid_coverage_pct),
    .groups                             = "drop"
  )


daily_summary <- daily_inundation |>
  dplyr::group_by(.data$plot_id) |>
  dplyr::summarise(
    daily_rows                             = dplyr::n(),
    daily_mean_inundated_pct               = gayini_review_safe_mean(.data$daily_inundated_pct),
    daily_max_inundated_pct                = gayini_review_safe_max(.data$daily_inundated_pct),
    daily_mean_valid_interpretation_pct    = gayini_review_safe_mean(.data$valid_interpretation_pct),
    daily_min_valid_interpretation_pct     = gayini_review_safe_min(.data$valid_interpretation_pct),
    daily_mean_cloud_shadow_pct            = gayini_review_safe_mean(.data$value_3_cloud_shadow_pct),
    .groups                                = "drop"
  )


plot_metrics <- plots |>
  sf::st_drop_geometry() |>
  dplyr::select(dplyr::any_of(c("plot_id", "treatment", "vegetation", "area_ha", "review_zone"))) |>
  dplyr::left_join(fc_coverage_summary, by = "plot_id") |>
  dplyr::left_join(fc_value_summary, by = "plot_id") |>
  dplyr::left_join(annual_summary, by = "plot_id") |>
  dplyr::left_join(daily_summary, by = "plot_id") |>
  dplyr::mutate(
    gc_data_score = .data$gc_all_bands_adequate_pct,
    inundation_exposure_score = rowMeans(
      cbind(
        gayini_review_rescale_0_100(.data$annual_mean_inundated_any_pct),
        gayini_review_rescale_0_100(.data$daily_mean_inundated_pct)
      ),
      na.rm = TRUE
    ),
    daily_data_score = .data$daily_mean_valid_interpretation_pct,
    annual_data_score = pmin(.data$annual_mean_valid_coverage_pct, 100),
    rs_data_richness_score = rowMeans(
      cbind(
        .data$gc_data_score,
        .data$annual_data_score,
        .data$daily_data_score
      ),
      na.rm = TRUE
    ),
    data_richness_class = dplyr::case_when(
      is.na(.data$rs_data_richness_score)             ~ "unknown data richness",
      .data$rs_data_richness_score >= 90              ~ "very strong RS data",
      .data$rs_data_richness_score >= 80              ~ "strong RS data",
      .data$rs_data_richness_score >= 70              ~ "moderate RS data",
      TRUE                                            ~ "lower RS data"
    ),
    inundation_exposure_class = dplyr::case_when(
      is.na(.data$inundation_exposure_score)          ~ "unknown inundation exposure",
      .data$inundation_exposure_score >= 75           ~ "high inundation exposure",
      .data$inundation_exposure_score >= 50           ~ "moderate inundation exposure",
      .data$inundation_exposure_score >= 25           ~ "low inundation exposure",
      TRUE                                            ~ "very low inundation exposure"
    ),
    rs_hotspot_gap_class = dplyr::case_when(
      .data$rs_data_richness_score >= 80 & .data$inundation_exposure_score >= 50 ~ "data-rich flood-exposed plot",
      .data$rs_data_richness_score >= 80 & .data$inundation_exposure_score <  50 ~ "data-rich drier plot",
      .data$rs_data_richness_score <  80 & .data$inundation_exposure_score >= 50 ~ "data-gap flood-exposed plot",
      .data$rs_data_richness_score <  80 & .data$inundation_exposure_score <  50 ~ "data-gap drier plot",
      TRUE                                                                       ~ "unclassified"
    )
  )


readr::write_csv(plot_metrics, plot_metrics_path)


message("Wrote: ", plot_metrics_path)


plots_map <- plots |>
  dplyr::left_join(plot_metrics, by = c("plot_id", "treatment", "vegetation", "area_ha", "review_zone"))


## Map functions ----


make_metric_map <- function(map_data, metric_column, metric_label, output_path, title, subtitle = NULL, bbox_object = NULL) {

  plot_data <- map_data |>
    dplyr::mutate(metric_to_plot = .data[[metric_column]])

  p <- ggplot2::ggplot() +
    {if (!is.null(boundary)) ggplot2::geom_sf(data = boundary, fill = NA, colour = "grey35", linewidth = 0.35)} +
    ggplot2::geom_sf(data = plots_map, fill = "grey92", colour = "white", linewidth = 0.15) +
    ggplot2::geom_sf(
      data   = plot_data,
      ggplot2::aes(fill = .data$metric_to_plot),
      colour = "black",
      linewidth = 0.2
    ) +
    ggplot2::scale_fill_gradient(
      low      = "grey95",
      high     = "steelblue",
      na.value = "grey80",
      limits   = c(0, 100)
    ) +
    ggplot2::labs(
      title    = title,
      subtitle = subtitle,
      fill     = metric_label
    ) +
    gayini_review_theme(base_size = BASE_SIZE) +
    ggplot2::theme(
      axis.title        = ggplot2::element_blank(),
      axis.text         = ggplot2::element_blank(),
      axis.ticks        = ggplot2::element_blank(),
      panel.grid.major  = ggplot2::element_line(colour = "grey90", linewidth = 0.15),
      legend.key.width  = grid::unit(3.0, "cm"),
      legend.key.height = grid::unit(0.32, "cm")
    ) +
    ggplot2::guides(
      fill = ggplot2::guide_colourbar(
        title.position = "top",
        barwidth       = grid::unit(3.2, "cm"),
        barheight      = grid::unit(0.32, "cm")
      )
    )

  if (!is.null(bbox_object)) {
    bbox <- gayini_review_expanded_bbox(bbox_object, expand_fraction = ZONE_EXPAND_FRACTION)
    p <- p + ggplot2::coord_sf(xlim = bbox$xlim, ylim = bbox$ylim)
  }

  gayini_review_save_png(
    plot   = p,
    path   = output_path,
    width  = 10.5,
    height = 9,
    dpi    = FIGURE_DPI
  )
}


make_class_map <- function(map_data, class_column, output_path, title, subtitle = NULL, bbox_object = NULL) {

  plot_data <- map_data |>
    dplyr::mutate(class_to_plot = .data[[class_column]])

  p <- ggplot2::ggplot() +
    {if (!is.null(boundary)) ggplot2::geom_sf(data = boundary, fill = NA, colour = "grey35", linewidth = 0.35)} +
    ggplot2::geom_sf(data = plots_map, fill = "grey92", colour = "white", linewidth = 0.15) +
    ggplot2::geom_sf(
      data   = plot_data,
      ggplot2::aes(fill = .data$class_to_plot),
      colour = "black",
      linewidth = 0.2
    ) +
    ggplot2::labs(
      title    = title,
      subtitle = subtitle,
      fill     = "Class"
    ) +
    gayini_review_theme(base_size = BASE_SIZE) +
    ggplot2::theme(
      axis.title       = ggplot2::element_blank(),
      axis.text        = ggplot2::element_blank(),
      axis.ticks       = ggplot2::element_blank(),
      panel.grid.major = ggplot2::element_line(colour = "grey90", linewidth = 0.15),
      legend.position  = "bottom"
    )

  if (!is.null(bbox_object)) {
    bbox <- gayini_review_expanded_bbox(bbox_object, expand_fraction = ZONE_EXPAND_FRACTION)
    p <- p + ggplot2::coord_sf(xlim = bbox$xlim, ylim = bbox$ylim)
  }

  gayini_review_save_png(
    plot   = p,
    path   = output_path,
    width  = 10.5,
    height = 9,
    dpi    = FIGURE_DPI
  )
}


## Metric maps: all plots ----


metric_specs <- tibble::tribble(
  ~metric_column,                    ~metric_label,                 ~file_stub,                       ~title,
  "gc_all_bands_adequate_pct",       "Adequate GC (%)",             "gc_adequate_coverage",           "Ground-cover data coverage by plot",
  "annual_mean_inundated_any_pct",   "Annual inundated (%)",        "annual_inundation_mean",         "Annual Landsat inundation exposure by plot",
  "daily_mean_inundated_pct",        "Daily inundated (%)",         "daily_inundation_mean",          "Daily inundation exposure by plot",
  "rs_data_richness_score",          "RS data score",               "rs_data_richness_score",         "Remote-sensing data richness by plot",
  "inundation_exposure_score",       "Flood exposure score",        "inundation_exposure_score",      "Combined inundation exposure by plot"
)


for (i in seq_len(nrow(metric_specs))) {

  make_metric_map(
    map_data      = plots_map,
    metric_column = metric_specs$metric_column[[i]],
    metric_label  = metric_specs$metric_label[[i]],
    output_path   = file.path(figure_dir, paste0("07c_map_all_plots_", metric_specs$file_stub[[i]], ".png")),
    title         = metric_specs$title[[i]],
    subtitle      = "All 1 ha plots; larger map for review rather than compact slide overview."
  )
}


make_class_map(
  map_data     = plots_map,
  class_column = "rs_hotspot_gap_class",
  output_path  = file.path(figure_dir, "07c_map_all_plots_rs_hotspot_gap_class.png"),
  title        = "Plot-level RS hotspot / gap classification",
  subtitle     = "Combines data richness and relative inundation exposure; first-pass review class only."
)


## Treatment-specific maps ----


treatments <- sort(unique(plots_map$treatment))


for (this_treatment in treatments) {

  treatment_data <- plots_map |>
    dplyr::filter(.data$treatment == this_treatment)

  treatment_stub <- gayini_review_clean_filename(this_treatment)

  for (i in seq_len(nrow(metric_specs))) {

    make_metric_map(
      map_data      = treatment_data,
      metric_column = metric_specs$metric_column[[i]],
      metric_label  = metric_specs$metric_label[[i]],
      output_path   = file.path(figure_dir, paste0("07c_map_treatment_", treatment_stub, "_", metric_specs$file_stub[[i]], ".png")),
      title         = paste0(metric_specs$title[[i]], " — ", this_treatment),
      subtitle      = "Focal treatment shown against all plots in grey.",
      bbox_object   = treatment_data
    )
  }

  make_class_map(
    map_data     = treatment_data,
    class_column = "rs_hotspot_gap_class",
    output_path  = file.path(figure_dir, paste0("07c_map_treatment_", treatment_stub, "_rs_hotspot_gap_class.png")),
    title        = paste0("RS hotspot / gap class — ", this_treatment),
    subtitle     = "Focal treatment shown against all plots in grey.",
    bbox_object  = treatment_data
  )
}


## Zone-specific zoom maps ----


zones <- sort(unique(as.character(plots_map$review_zone)))


for (this_zone in zones) {

  zone_data <- plots_map |>
    dplyr::filter(as.character(.data$review_zone) == this_zone)

  zone_stub <- gayini_review_clean_filename(this_zone)

  for (i in seq_len(nrow(metric_specs))) {

    make_metric_map(
      map_data      = zone_data,
      metric_column = metric_specs$metric_column[[i]],
      metric_label  = metric_specs$metric_label[[i]],
      output_path   = file.path(figure_dir, paste0("07c_map_zone_", zone_stub, "_", metric_specs$file_stub[[i]], ".png")),
      title         = paste0(metric_specs$title[[i]], " — ", this_zone),
      subtitle      = "Zoomed zone map to make individual 1 ha plots readable.",
      bbox_object   = zone_data
    )
  }

  make_class_map(
    map_data     = zone_data,
    class_column = "rs_hotspot_gap_class",
    output_path  = file.path(figure_dir, paste0("07c_map_zone_", zone_stub, "_rs_hotspot_gap_class.png")),
    title        = paste0("RS hotspot / gap class — ", this_zone),
    subtitle     = "Zoomed zone map to make individual 1 ha plots readable.",
    bbox_object  = zone_data
  )
}


## Optional combo-raster functions ----


make_ground_cover_valid_combo_raster <- function(raster_catalog, output_path) {

  fc_catalog <- raster_catalog |>
    dplyr::filter(.data$product == "landsat_fractional_cover") |>
    dplyr::filter(file.exists(.data$file_path)) |>
    dplyr::arrange(.data$date_start)

  if (is.finite(MAX_RASTERS_PER_COMBO)) {
    fc_catalog <- fc_catalog |>
      dplyr::slice_head(n = MAX_RASTERS_PER_COMBO)
  }

  if (nrow(fc_catalog) == 0) {
    warning("No readable Landsat fractional-cover raw raster files found for combo raster.")
    return(invisible(NULL))
  }

  accumulator <- NULL
  n_used <- 0L

  for (path in fc_catalog$file_path) {

    message("Adding GC valid-data mask: ", basename(path))

    r <- terra::rast(path)
    valid <- terra::app(r, fun = function(x) as.integer(all(!is.na(x))))

    if (is.null(accumulator)) {
      accumulator <- valid * 0
    }

    valid <- terra::resample(valid, accumulator, method = "near")
    accumulator <- accumulator + valid
    n_used <- n_used + 1L
  }

  coverage_pct <- 100 * accumulator / n_used
  names(coverage_pct) <- "ground_cover_valid_observation_pct"

  terra::writeRaster(coverage_pct, output_path, overwrite = TRUE)

  message("Wrote: ", output_path)

  invisible(output_path)
}


make_annual_inundation_frequency_raster <- function(raster_catalog, output_path) {

  inundation_catalog <- raster_catalog |>
    dplyr::filter(.data$product == "landsat_inundation") |>
    dplyr::filter(file.exists(.data$file_path)) |>
    dplyr::arrange(.data$date_start)

  if (is.finite(MAX_RASTERS_PER_COMBO)) {
    inundation_catalog <- inundation_catalog |>
      dplyr::slice_head(n = MAX_RASTERS_PER_COMBO)
  }

  if (nrow(inundation_catalog) == 0) {
    warning("No readable Landsat inundation raw raster files found for combo raster.")
    return(invisible(NULL))
  }

  wet_count <- NULL
  valid_count <- NULL

  for (path in inundation_catalog$file_path) {

    message("Adding annual inundation mask: ", basename(path))

    r <- terra::rast(path)
    valid <- !is.na(r)
    wet <- r > 0

    if (is.null(wet_count)) {
      wet_count <- wet * 0
      valid_count <- valid * 0
    }

    valid <- terra::resample(valid, wet_count, method = "near")
    wet <- terra::resample(wet, wet_count, method = "near")

    wet_count <- wet_count + wet
    valid_count <- valid_count + valid
  }

  wet_frequency_pct <- 100 * wet_count / valid_count
  names(wet_frequency_pct) <- "annual_inundation_frequency_pct"

  terra::writeRaster(wet_frequency_pct, output_path, overwrite = TRUE)

  message("Wrote: ", output_path)

  invisible(output_path)
}


## Optional combo-raster execution ----


if (isTRUE(RUN_OPTIONAL_COMBO_RASTERS)) {

  gayini_review_required_file(raster_catalog_path)

  raster_catalog <- readr::read_csv(raster_catalog_path, show_col_types = FALSE)

  make_ground_cover_valid_combo_raster(
    raster_catalog = raster_catalog,
    output_path    = file.path(raster_output_dir, "07c_ground_cover_valid_observation_pct.tif")
  )

  make_annual_inundation_frequency_raster(
    raster_catalog = raster_catalog,
    output_path    = file.path(raster_output_dir, "07c_annual_inundation_frequency_pct.tif")
  )
}


## Finish ----


message("07c plot coverage maps and combo-layer script complete.")
message("Figure folder: ", figure_dir)
message("Optional combo-raster output folder: ", raster_output_dir)
