## 07g plot pre/post inundation summary panels ----

root_dir <- Sys.getenv("GAYINI_ROOT", "D:/Github_repos/Gayini")

TARGET_GROUP_SIZE <- 7
WRITE_FULL_FARM_PANEL <- TRUE
WRITE_CLUSTER_PANELS <- TRUE
WRITE_RANKED_BAR_CHART <- TRUE

required_packages <- c(
  "sf", "terra", "dplyr", "tidyr", "readr", "stringr", "purrr", "ggplot2", "magrittr"
)
missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_packages) > 0) {
  stop("Missing required packages: ", paste(missing_packages, collapse = ", "), call. = FALSE)
}

library(sf)
library(terra)
library(dplyr)
library(tidyr)
library(readr)
library(stringr)
library(purrr)
library(ggplot2)
library(magrittr)

source(file.path(root_dir, "R", "inundation_pre_post_plotting_functions.R"))

plot_summary_path <- gayini_find_first_existing(c(
  file.path(root_dir, "Output", "csv", "07f_pre_post_inundation_plot_summary_fixed.csv"),
  file.path(root_dir, "data_processed", "plot_pre_post_inundation_frequency_fixed.csv"),
  file.path(root_dir, "Output", "csv", "07e_pre_post_inundation_plot_summary.csv"),
  file.path(root_dir, "data_processed", "plot_pre_post_inundation_frequency.csv")
))

if (is.na(plot_summary_path)) {
  stop("Could not find a plot summary table. Run 07f or 07e first.", call. = FALSE)
}

pre_raster_path  <- file.path(root_dir, "Output", "rasters", "inundation_pre_post", "pre_conservation_inundation_frequency_pct.tif")
post_raster_path <- file.path(root_dir, "Output", "rasters", "inundation_pre_post", "post_conservation_inundation_frequency_pct.tif")
diff_raster_path <- file.path(root_dir, "Output", "rasters", "inundation_pre_post", "post_minus_pre_inundation_frequency_pct_points.tif")

plots_path <- gayini_find_first_existing(c(
  file.path(root_dir, "Input", "shapefiles", "gayini_hectare_plots.shp"),
  file.path(root_dir, "data_intermediate", "spatial", "plots_clean.gpkg")
))

boundary_path <- gayini_find_first_existing(c(
  file.path(root_dir, "Input", "shapefiles", "gayini_boundary.shp"),
  file.path(root_dir, "data_intermediate", "spatial", "boundary_clean.gpkg")
))

zones_path <- gayini_find_first_existing(c(
  file.path(root_dir, "Input", "shapefiles", "CA0561_ManagementZones.shp")
))

fig_dir <- file.path(root_dir, "Output", "figures", "07g_prepost_panels")
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)

plot_summary <- readr::read_csv(plot_summary_path, show_col_types = FALSE)
plots_sf <- sf::st_read(plots_path, quiet = TRUE)

## Standardise plot ID fields ----
##
## Some shapefile readers preserve the field as `Gayini Nam`; others convert it
## to `Gayini.Nam`, `Gayini_Nam`, or a truncated shapefile-safe equivalent.
## Standardise both the shapefile and CSV to `plot_id` before joining.

gayini_find_plot_id_column <- function(x) {
  nms <- names(x)

  candidates <- c(
    "plot_id",
    "Plot_ID",
    "PLOT_ID",
    "plotid",
    "PlotID",
    "Plot_Id",
    "Gayini Nam",
    "Gayini.Nam",
    "Gayini_Nam",
    "GayiniNam",
    "Gayini Na",
    "Gayini_Na",
    "Gayini.Na",
    "Gayini"
  )

  hit <- candidates[candidates %in% nms]

  if (length(hit) > 0) {
    return(hit[[1]])
  }

  ## Fallback: find a likely column containing GA_ plot codes.
  for (nm in nms) {
    vals <- as.character(x[[nm]])
    vals <- vals[!is.na(vals)]
    if (length(vals) > 0 && any(grepl("^GA_[0-9]{3}$", vals))) {
      return(nm)
    }
  }

  NA_character_
}

plot_id_col_plots <- gayini_find_plot_id_column(plots_sf)
plot_id_col_table <- gayini_find_plot_id_column(plot_summary)

if (is.na(plot_id_col_plots)) {
  stop(
    "Could not find a plot ID column in plots_sf. Available columns: ",
    paste(names(plots_sf), collapse = ", "),
    call. = FALSE
  )
}

if (is.na(plot_id_col_table)) {
  stop(
    "Could not find a plot ID column in plot_summary. Available columns: ",
    paste(names(plot_summary), collapse = ", "),
    call. = FALSE
  )
}

if (plot_id_col_plots != "plot_id") {
  plots_sf$plot_id <- as.character(plots_sf[[plot_id_col_plots]])
}

if (plot_id_col_table != "plot_id") {
  plot_summary$plot_id <- as.character(plot_summary[[plot_id_col_table]])
}

plots_sf$plot_id <- stringr::str_trim(as.character(plots_sf$plot_id))
plot_summary$plot_id <- stringr::str_trim(as.character(plot_summary$plot_id))

message("Using plot ID column in plots: ", plot_id_col_plots)
message("Using plot ID column in plot summary: ", plot_id_col_table)

missing_from_summary <- setdiff(plots_sf$plot_id, plot_summary$plot_id)
missing_from_shapes <- setdiff(plot_summary$plot_id, plots_sf$plot_id)

if (length(missing_from_summary) > 0) {
  warning(
    "Some plot IDs are present in the plot shapefile but missing from the summary table: ",
    paste(missing_from_summary, collapse = ", "),
    call. = FALSE
  )
}

if (length(missing_from_shapes) > 0) {
  warning(
    "Some plot IDs are present in the summary table but missing from the plot shapefile: ",
    paste(missing_from_shapes, collapse = ", "),
    call. = FALSE
  )
}

plots_sf <- plots_sf %>%
  dplyr::left_join(plot_summary, by = "plot_id")

boundary_sf <- gayini_read_optional_sf(boundary_path)
zones_sf <- gayini_read_optional_sf(zones_path)

cluster_lookup <- gayini_make_plot_clusters(plots_sf, target_group_size = TARGET_GROUP_SIZE)
plots_sf <- plots_sf %>%
  dplyr::left_join(cluster_lookup, by = "plot_id")

readr::write_csv(cluster_lookup, file.path(fig_dir, "07g_plot_cluster_lookup.csv"))

# full-farm raster panel ----
if (WRITE_FULL_FARM_PANEL) {
  pre_r <- terra::rast(pre_raster_path)
  post_r <- terra::rast(post_raster_path)
  diff_r <- terra::rast(diff_raster_path)
  raster_crs <- sf::st_crs(terra::crs(pre_r))

  boundary_r <- gayini_safe_sf_transform(boundary_sf, raster_crs)
  zones_r <- gayini_safe_sf_transform(zones_sf, raster_crs)
  plots_r <- gayini_safe_sf_transform(plots_sf, raster_crs)

  pre_df <- gayini_raster_to_df(pre_r, "value") %>% dplyr::mutate(metric = "pre_conservation_inundation_frequency_pct")
  post_df <- gayini_raster_to_df(post_r, "value") %>% dplyr::mutate(metric = "post_conservation_inundation_frequency_pct")
  diff_df <- gayini_raster_to_df(diff_r, "value") %>% dplyr::mutate(metric = "post_minus_pre_inundation_frequency_pct_points")
  ras_df <- dplyr::bind_rows(pre_df, post_df, diff_df) %>%
    dplyr::mutate(metric_label = gayini_metric_label(.data$metric))

  p <- ggplot() +
    geom_raster(data = dplyr::filter(ras_df, .data$metric != 'post_minus_pre_inundation_frequency_pct_points'), aes(x = x, y = y, fill = value)) +
    scale_fill_gradient(low = '#f7fbff', high = '#08519c', limits = c(0, 100), na.value = 'grey92', name = 'Frequency (%)') +
    geom_sf(data = boundary_r, fill = NA, colour = 'black', linewidth = 0.4) +
    {if (!is.null(zones_r)) geom_sf(data = zones_r, fill = NA, colour = 'grey60', linewidth = 0.2)} +
    geom_sf(data = plots_r, fill = NA, colour = 'black', linewidth = 0.15) +
    facet_wrap(~metric_label, ncol = 3) +
    coord_sf(expand = FALSE) +
    labs(
      title = 'Gayini pre/post inundation frequency rasters',
      subtitle = 'Full-farm panel: pre-conservation, post-conservation, and difference rasters'
    ) +
    gayini_theme_map()

  # build separate diff panel because of diverging scale
  p_diff <- ggplot() +
    geom_raster(data = dplyr::filter(ras_df, .data$metric == 'post_minus_pre_inundation_frequency_pct_points'), aes(x = x, y = y, fill = value)) +
    scale_fill_gradient2(low = '#d6604d', mid = 'white', high = '#4393c3', midpoint = 0, limits = c(-100, 100), na.value = 'grey92', name = 'Post - pre\n(pct points)') +
    geom_sf(data = boundary_r, fill = NA, colour = 'black', linewidth = 0.4) +
    {if (!is.null(zones_r)) geom_sf(data = zones_r, fill = NA, colour = 'grey60', linewidth = 0.2)} +
    geom_sf(data = plots_r, fill = NA, colour = 'black', linewidth = 0.15) +
    coord_sf(expand = FALSE) +
    labs(title = 'Gayini pre/post inundation difference raster', subtitle = 'Post-conservation minus pre-conservation inundation frequency') +
    gayini_theme_map()

  ggplot2::ggsave(file.path(fig_dir, '07g_full_farm_pre_post_panel.png'), plot = p, width = 13, height = 5.3, dpi = 240)
  ggplot2::ggsave(file.path(fig_dir, '07g_full_farm_difference_panel.png'), plot = p_diff, width = 7, height = 6, dpi = 240)
}

# cluster panels ----
if (WRITE_CLUSTER_PANELS) {
  metrics <- c(
    'pre_conservation_inundation_frequency_pct',
    'post_conservation_inundation_frequency_pct',
    'post_minus_pre_inundation_frequency_pct_points'
  )

  raster_crs <- sf::st_crs(plots_sf)
  if (!is.null(boundary_sf)) boundary_sf <- sf::st_transform(boundary_sf, sf::st_crs(plots_sf))
  if (!is.null(zones_sf)) zones_sf <- sf::st_transform(zones_sf, sf::st_crs(plots_sf))

  for (this_cluster in unique(plots_sf$cluster_id)) {
    cluster_plots <- plots_sf %>%
      dplyr::filter(.data$cluster_id == !!this_cluster)

    long_df <- cluster_plots %>%
      sf::st_drop_geometry() %>%
      dplyr::select("plot_id", dplyr::all_of(metrics)) %>%
      tidyr::pivot_longer(cols = dplyr::all_of(metrics), names_to = 'metric', values_to = 'value') %>%
      dplyr::mutate(metric_label = gayini_metric_label(.data$metric))

    cluster_long_sf <- cluster_plots %>%
      dplyr::select("plot_id", geometry) %>%
      dplyr::left_join(long_df, by = 'plot_id')

    cluster_centroids <- suppressWarnings(sf::st_centroid(cluster_plots))

    cluster_centroid_coords <- sf::st_coordinates(cluster_centroids) %>%
      tibble::as_tibble() %>%
      dplyr::rename(x = X, y = Y)

    label_df <- cluster_centroids %>%
      sf::st_drop_geometry() %>%
      dplyr::bind_cols(cluster_centroid_coords)

    bbox_vals <- gayini_cluster_bbox(cluster_plots, expand_factor = 0.18, min_expand = 300)

    zone_crop <- NULL
    if (!is.null(zones_sf)) {
      zone_crop <- suppressWarnings(sf::st_crop(zones_sf, bbox_vals))
    }
    boundary_crop <- NULL
    if (!is.null(boundary_sf)) {
      boundary_crop <- suppressWarnings(sf::st_crop(boundary_sf, bbox_vals))
    }

    p_freq <- ggplot() +
      geom_sf(data = dplyr::filter(cluster_long_sf, .data$metric != 'post_minus_pre_inundation_frequency_pct_points'), aes(fill = value), colour = 'black', linewidth = 0.25) +
      {if (!is.null(zone_crop)) geom_sf(data = zone_crop, fill = NA, colour = 'grey55', linewidth = 0.25)} +
      {if (!is.null(boundary_crop)) geom_sf(data = boundary_crop, fill = NA, colour = 'black', linewidth = 0.4)} +
      geom_text(data = label_df, aes(x = x, y = y, label = plot_id), size = 3.2, fontface = 'bold') +
      scale_fill_gradient(low = '#f7fbff', high = '#08519c', limits = c(0, 100), na.value = 'grey90', name = 'Frequency (%)') +
      facet_wrap(~metric_label, ncol = 2) +
      coord_sf(xlim = c(bbox_vals['xmin'], bbox_vals['xmax']), ylim = c(bbox_vals['ymin'], bbox_vals['ymax']), expand = FALSE) +
      labs(title = paste0('Plot cluster ', this_cluster, ': pre and post inundation frequency'), subtitle = paste0('Grouped nearby plots (n = ', nrow(cluster_plots), ')')) +
      gayini_theme_map()

    p_diff <- ggplot() +
      geom_sf(data = dplyr::filter(cluster_long_sf, .data$metric == 'post_minus_pre_inundation_frequency_pct_points'), aes(fill = value), colour = 'black', linewidth = 0.25) +
      {if (!is.null(zone_crop)) geom_sf(data = zone_crop, fill = NA, colour = 'grey55', linewidth = 0.25)} +
      {if (!is.null(boundary_crop)) geom_sf(data = boundary_crop, fill = NA, colour = 'black', linewidth = 0.4)} +
      geom_text(data = label_df, aes(x = x, y = y, label = plot_id), size = 3.2, fontface = 'bold') +
      scale_fill_gradient2(low = '#d6604d', mid = 'white', high = '#4393c3', midpoint = 0, limits = c(-100, 100), na.value = 'grey90', name = 'Post - pre\n(pct points)') +
      coord_sf(xlim = c(bbox_vals['xmin'], bbox_vals['xmax']), ylim = c(bbox_vals['ymin'], bbox_vals['ymax']), expand = FALSE) +
      labs(title = paste0('Plot cluster ', this_cluster, ': post - pre difference'), subtitle = paste0('Nearby plots, labelled for Adrian review (n = ', nrow(cluster_plots), ')')) +
      gayini_theme_map()

    ggplot2::ggsave(file.path(fig_dir, paste0('07g_', this_cluster, '_pre_post_panel.png')), plot = p_freq, width = 11, height = 7, dpi = 240)
    ggplot2::ggsave(file.path(fig_dir, paste0('07g_', this_cluster, '_difference_panel.png')), plot = p_diff, width = 7.5, height = 7, dpi = 240)
  }
}

# ranked difference chart ----
if (WRITE_RANKED_BAR_CHART) {
  bar_df <- plot_summary %>%
    dplyr::arrange(.data$post_minus_pre_inundation_frequency_pct_points) %>%
    dplyr::mutate(plot_id = factor(.data$plot_id, levels = .data$plot_id))

  p_bar <- ggplot(bar_df, aes(x = plot_id, y = post_minus_pre_inundation_frequency_pct_points, fill = inundation_change_class)) +
    geom_col() +
    coord_flip() +
    scale_fill_manual(values = c(
      'much_drier_post' = '#b2182b',
      'drier_post' = '#ef8a62',
      'similar_frequency' = '#cccccc',
      'wetter_post' = '#67a9cf',
      'much_wetter_post' = '#2166ac',
      'no_comparison' = 'grey80'
    ), drop = FALSE) +
    labs(title = 'Plot-level change in inundation frequency', subtitle = 'Post-conservation minus pre-conservation percentage points', x = 'Plot ID', y = 'Post - pre (pct points)', fill = 'Change class') +
    theme_minimal(base_size = 11) +
    theme(plot.title = element_text(face = 'bold'))

  ggplot2::ggsave(file.path(fig_dir, '07g_ranked_plot_change_bar_chart.png'), plot = p_bar, width = 8.5, height = 11, dpi = 240)
}

message('07g complete. Wrote outputs to: ', fig_dir)
