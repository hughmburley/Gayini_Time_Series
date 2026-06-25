## Inundation plotting helper functions ----

`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0 || all(is.na(x))) y else x
}


gayini_find_first_existing <- function(paths) {
  existing <- paths[file.exists(paths)]
  if (length(existing) == 0) {
    return(NA_character_)
  }
  existing[[1]]
}


gayini_read_optional_sf <- function(path) {
  if (is.na(path) || !file.exists(path)) {
    return(NULL)
  }
  sf::st_read(path, quiet = TRUE)
}


gayini_make_plot_clusters <- function(plots_sf,
                                      target_group_size = 7,
                                      seed = 42) {
  stopifnot(inherits(plots_sf, 'sf'))

  centroids <- suppressWarnings(sf::st_centroid(plots_sf))
  coords <- sf::st_coordinates(centroids)

  n_groups <- max(1, ceiling(nrow(plots_sf) / target_group_size))

  set.seed(seed)
  km <- stats::kmeans(coords, centers = n_groups, iter.max = 100)

  cluster_df <- tibble::tibble(
    plot_id = plots_sf$plot_id %||% plots_sf$`Gayini Nam`,
    cluster_raw = km$cluster,
    x = coords[, 1],
    y = coords[, 2]
  ) %>%
    dplyr::group_by(.data$cluster_raw) %>%
    dplyr::summarise(x = mean(.data$x), y = mean(.data$y), n_plots = dplyr::n(), .groups = 'drop') %>%
    dplyr::arrange(dplyr::desc(.data$y), .data$x) %>%
    dplyr::mutate(cluster_id = paste0('cluster_', stringr::str_pad(dplyr::row_number(), 2, pad = '0')))

  tibble::tibble(
    plot_id = plots_sf$plot_id %||% plots_sf$`Gayini Nam`,
    cluster_raw = km$cluster
  ) %>%
    dplyr::left_join(cluster_df, by = 'cluster_raw') %>%
    dplyr::select("plot_id", "cluster_id", "n_plots")
}


gayini_cluster_bbox <- function(sf_obj, expand_factor = 0.15, min_expand = 250) {
  bb <- sf::st_bbox(sf_obj)
  dx <- as.numeric(bb[['xmax']] - bb[['xmin']])
  dy <- as.numeric(bb[['ymax']] - bb[['ymin']])
  pad_x <- max(dx * expand_factor, min_expand)
  pad_y <- max(dy * expand_factor, min_expand)
  c(xmin = bb[['xmin']] - pad_x,
    xmax = bb[['xmax']] + pad_x,
    ymin = bb[['ymin']] - pad_y,
    ymax = bb[['ymax']] + pad_y)
}


gayini_raster_to_df <- function(r, value_name = names(r)[1]) {
  out <- terra::as.data.frame(r, xy = TRUE, na.rm = FALSE)
  if (!value_name %in% names(out)) {
    names(out)[3] <- value_name
  }
  out
}


gayini_safe_sf_transform <- function(x, target_crs) {
  if (is.null(x)) return(NULL)
  sf::st_transform(x, target_crs)
}


gayini_theme_map <- function() {
  ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(
      panel.grid = ggplot2::element_blank(),
      strip.text = ggplot2::element_text(face = 'bold', size = 11),
      plot.title = ggplot2::element_text(face = 'bold', size = 15),
      plot.subtitle = ggplot2::element_text(size = 11),
      legend.title = ggplot2::element_text(face = 'bold'),
      axis.title = ggplot2::element_blank(),
      axis.text = ggplot2::element_blank(),
      axis.ticks = ggplot2::element_blank()
    )
}


gayini_metric_label <- function(metric) {
  dplyr::case_when(
    metric == 'pre_conservation_inundation_frequency_pct' ~ 'Pre-conservation
inundation frequency (%)',
    metric == 'post_conservation_inundation_frequency_pct' ~ 'Post-conservation
inundation frequency (%)',
    metric == 'post_minus_pre_inundation_frequency_pct_points' ~ 'Post - pre
(pct points)',
    metric == 'pre_conservation_valid_year_count' ~ 'Pre valid
year count',
    metric == 'post_conservation_valid_year_count' ~ 'Post valid
year count',
    TRUE ~ metric
  )
}
