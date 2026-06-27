## -----------------------------------------------------------------------------
## Gayini remote sensing workflow
## 07g_plot_pre_post_inundation_summary_panels_v2.R
## -----------------------------------------------------------------------------


## Purpose:
## Create revised Step 7 pre/post figures for Adrian review.
## Focus on readable plot maps, full-farm dot maps, matrix heatmaps, and ranked
## plot-change summaries using existing Run1 rasters and the fixed 07f plot table.


## User settings ----

root_dir <- normalizePath("D:/Github_repos/Gayini", winslash = "/", mustWork = TRUE)

TARGET_GROUP_SIZE <- 7
DIFF_DISPLAY_LIMIT <- 60
LABEL_CLUSTER_DIFFERENCE_VALUES <- TRUE
WRITE_CLUSTER_PANELS <- TRUE
WRITE_FULL_FARM_RASTER_PANELS <- TRUE
WRITE_DOT_MAP <- TRUE
WRITE_MATRIX_PLOTS <- TRUE


## Required packages ----

required_packages <- c(
  "sf",
  "terra",
  "dplyr",
  "tidyr",
  "readr",
  "stringr",
  "purrr",
  "ggplot2",
  "magrittr",
  "scales"
)

source(file.path(root_dir, "R", "step7_figure_helpers.R"))
gayini_check_packages(required_packages)

library(sf)
library(terra)
library(dplyr)
library(tidyr)
library(readr)
library(stringr)
library(purrr)
library(ggplot2)
library(magrittr)
library(scales)


## Input paths ----

raster_dir <- file.path(root_dir, "Output", "rasters", "inundation_pre_post")

pre_raster_path <- file.path(raster_dir, "pre_conservation_inundation_frequency_pct.tif")
post_raster_path <- file.path(raster_dir, "post_conservation_inundation_frequency_pct.tif")
diff_raster_path <- file.path(raster_dir, "post_minus_pre_inundation_frequency_pct_points.tif")

required_files <- c(pre_raster_path, post_raster_path, diff_raster_path)
missing_files <- required_files[!file.exists(required_files)]

if (length(missing_files) > 0) {
  stop("Missing required raster files:\n", paste(missing_files, collapse = "\n"), call. = FALSE)
}


## Output folders ----

figure_dir <- file.path(root_dir, "Output", "figures", "07g_prepost_panels_v2")
diagnostics_dir <- file.path(root_dir, "Output", "diagnostics", "step7_figure_luts")

dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(diagnostics_dir, recursive = TRUE, showWarnings = FALSE)


## Read data ----

plot_summary <- gayini_read_step7_plot_summary(root_dir) %>%
  gayini_make_period_plot_data()

context <- gayini_load_plot_context(root_dir)

plots_sf <- context$plots_sf %>%
  dplyr::left_join(plot_summary, by = "plot_id")

boundary_sf <- context$boundary_sf
zones_sf <- context$zones_sf

cluster_lookup <- gayini_load_or_make_clusters(root_dir, plots_sf, target_group_size = TARGET_GROUP_SIZE)

plots_sf <- plots_sf %>%
  dplyr::left_join(cluster_lookup %>% dplyr::select("plot_id", "cluster_id"), by = "plot_id")

cluster_size_summary <- plots_sf %>%
  sf::st_drop_geometry() %>%
  dplyr::count(.data$cluster_id, name = "n_plots") %>%
  dplyr::mutate(
    cluster_size_flag = dplyr::case_when(
      .data$n_plots > 8 ~ "large_cluster_review",
      .data$n_plots < 4 ~ "small_cluster_review",
      TRUE ~ "target_size"
    )
  )

readr::write_csv(cluster_lookup, file.path(figure_dir, "07g_plot_cluster_lookup_v2.csv"))
readr::write_csv(cluster_size_summary, file.path(figure_dir, "07g_plot_cluster_size_summary_v2.csv"))


## Read rasters and transform context ----

pre_r <- terra::rast(pre_raster_path)
post_r <- terra::rast(post_raster_path)
diff_r <- terra::rast(diff_raster_path)

raster_crs <- sf::st_crs(terra::crs(pre_r))

plots_r <- plots_sf %>%
  sf::st_transform(raster_crs)

boundary_r <- if (!is.null(boundary_sf)) sf::st_transform(boundary_sf, raster_crs) else NULL
zones_r <- if (!is.null(zones_sf)) sf::st_transform(zones_sf, raster_crs) else NULL

plot_points <- gayini_get_centroid_df(plots_r)

figure_index <- tibble::tibble(
  figure_file = character(),
  figure_type = character(),
  variables = character(),
  intended_use = character(),
  notes = character()
)


## 1. Full-farm dot map of all plots ----

if (WRITE_DOT_MAP) {
  dot_map <- ggplot2::ggplot() +
    {if (!is.null(zones_r)) ggplot2::geom_sf(data = zones_r, fill = NA, colour = "grey75", linewidth = 0.25, inherit.aes = FALSE)} +
    {if (!is.null(boundary_r)) ggplot2::geom_sf(data = boundary_r, fill = NA, colour = "black", linewidth = 0.5, inherit.aes = FALSE)} +
    ggplot2::geom_point(
      data = plot_points,
      ggplot2::aes(
        x = .data$x,
        y = .data$y,
        fill = .data$post_minus_pre_inundation_frequency_pct_points
      ),
      inherit.aes = FALSE,
      shape = 21,
      size = 4.5,
      colour = "black",
      stroke = 0.35,
      alpha = 0.95
    ) +
    ggplot2::scale_fill_gradient2(
      low = "#b2182b",
      mid = "white",
      high = "#2166ac",
      midpoint = 0,
      limits = c(-DIFF_DISPLAY_LIMIT, DIFF_DISPLAY_LIMIT),
      oob = scales::squish,
      name = "Post - pre\n(pct points)"
    ) +
    ggplot2::coord_sf(expand = FALSE) +
    ggplot2::labs(
      title = "Plot-level change in annual inundation occurrence frequency",
      subtitle = "Dots are 1 ha plots. Colour shows post-conservation minus pre-conservation frequency in percentage points."
    ) +
    gayini_theme_map(base_size = 13)

  dot_map_path <- file.path(figure_dir, "07g_all_plots_prepost_change_dot_map.png")

  ggplot2::ggsave(dot_map_path, plot = dot_map, width = 10, height = 7.2, dpi = 300)

  figure_index <- dplyr::bind_rows(
    figure_index,
    tibble::tibble(
      figure_file = basename(dot_map_path),
      figure_type = "full_farm_dot_map",
      variables = "post_minus_pre_inundation_frequency_pct_points",
      intended_use = "Adrian-facing spatial summary",
      notes = "Positive values mean more frequent annual inundation post-conservation."
    )
  )
}


## 2. Full-farm raster panels ----

if (WRITE_FULL_FARM_RASTER_PANELS) {
  pre_df <- gayini_raster_to_df(pre_r, "value") %>%
    dplyr::mutate(metric = "pre_conservation_inundation_frequency_pct")

  post_df <- gayini_raster_to_df(post_r, "value") %>%
    dplyr::mutate(metric = "post_conservation_inundation_frequency_pct")

  freq_df <- dplyr::bind_rows(pre_df, post_df) %>%
    dplyr::mutate(
      metric = factor(
        .data$metric,
        levels = c("pre_conservation_inundation_frequency_pct", "post_conservation_inundation_frequency_pct"),
        labels = c("Pre-conservation\nfrequency (%)", "Post-conservation\nfrequency (%)")
      )
    )

  freq_panel <- ggplot2::ggplot(freq_df, ggplot2::aes(x = .data$x, y = .data$y, fill = .data$value)) +
    ggplot2::geom_raster() +
    ggplot2::scale_fill_gradient(
      low = "#f7fbff",
      high = "#08519c",
      limits = c(0, 100),
      na.value = "grey92",
      name = "Frequency (%)"
    ) +
    {if (!is.null(zones_r)) ggplot2::geom_sf(data = zones_r, fill = NA, colour = "grey65", linewidth = 0.18, inherit.aes = FALSE)} +
    {if (!is.null(boundary_r)) ggplot2::geom_sf(data = boundary_r, fill = NA, colour = "black", linewidth = 0.4, inherit.aes = FALSE)} +
    ggplot2::facet_wrap(~ metric, ncol = 2) +
    ggplot2::coord_sf(expand = FALSE) +
    ggplot2::labs(
      title = "Pre and post annual inundation occurrence frequency",
      subtitle = "Frequency = percent of valid water years where inundation was detected at least once."
    ) +
    gayini_theme_map(base_size = 13)

  freq_panel_path <- file.path(figure_dir, "07g_full_farm_pre_post_frequency_panel_v2.png")
  ggplot2::ggsave(freq_panel_path, plot = freq_panel, width = 12, height = 6.5, dpi = 300)

  diff_df <- gayini_raster_to_df(diff_r, "value")

  diff_panel <- ggplot2::ggplot(diff_df, ggplot2::aes(x = .data$x, y = .data$y, fill = .data$value)) +
    ggplot2::geom_raster() +
    ggplot2::scale_fill_gradient2(
      low = "#b2182b",
      mid = "white",
      high = "#2166ac",
      midpoint = 0,
      limits = c(-DIFF_DISPLAY_LIMIT, DIFF_DISPLAY_LIMIT),
      oob = scales::squish,
      na.value = "grey92",
      name = "Post - pre\n(pct points)"
    ) +
    {if (!is.null(zones_r)) ggplot2::geom_sf(data = zones_r, fill = NA, colour = "grey65", linewidth = 0.18, inherit.aes = FALSE)} +
    {if (!is.null(boundary_r)) ggplot2::geom_sf(data = boundary_r, fill = NA, colour = "black", linewidth = 0.4, inherit.aes = FALSE)} +
    ggplot2::geom_point(
      data = plot_points,
      ggplot2::aes(x = .data$x, y = .data$y),
      inherit.aes = FALSE,
      shape = 21,
      size = 1.8,
      fill = "white",
      colour = "black",
      stroke = 0.2
    ) +
    ggplot2::coord_sf(expand = FALSE) +
    ggplot2::labs(
      title = "Post-minus-pre annual inundation occurrence frequency",
      subtitle = "Difference is in percentage points. Plot locations are overlaid for orientation."
    ) +
    gayini_theme_map(base_size = 13)

  diff_panel_path <- file.path(figure_dir, "07g_full_farm_difference_panel_v2.png")
  ggplot2::ggsave(diff_panel_path, plot = diff_panel, width = 9, height = 7, dpi = 300)

  figure_index <- dplyr::bind_rows(
    figure_index,
    tibble::tibble(
      figure_file = c(basename(freq_panel_path), basename(diff_panel_path)),
      figure_type = c("full_farm_frequency_panel", "full_farm_difference_panel"),
      variables = c("pre/post inundation frequency", "post_minus_pre_inundation_frequency_pct_points"),
      intended_use = c("Adrian-facing raster summary", "Adrian-facing raster summary"),
      notes = c("Pre shown before post.", "Display scale squished for readability; raw raster unchanged.")
    )
  )
}


## 3. Cluster panels ----

if (WRITE_CLUSTER_PANELS) {
  cluster_ids <- sort(unique(plots_r$cluster_id))

  for (this_cluster in cluster_ids) {
    cluster_plots <- plots_r %>%
      dplyr::filter(.data$cluster_id == !!this_cluster)

    if (nrow(cluster_plots) == 0) next

    cluster_points <- gayini_get_centroid_df(cluster_plots)

    cluster_long <- cluster_plots %>%
      dplyr::select(
        "plot_id",
        "pre_conservation_inundation_frequency_pct",
        "post_conservation_inundation_frequency_pct",
        geometry
      ) %>%
      tidyr::pivot_longer(
        cols = c("pre_conservation_inundation_frequency_pct", "post_conservation_inundation_frequency_pct"),
        names_to = "metric",
        values_to = "value"
      ) %>%
      dplyr::mutate(
        metric = factor(
          .data$metric,
          levels = c("pre_conservation_inundation_frequency_pct", "post_conservation_inundation_frequency_pct"),
          labels = c("Pre-conservation\nfrequency (%)", "Post-conservation\nfrequency (%)")
        )
      )

    cluster_bbox <- sf::st_bbox(cluster_plots)
    dx <- as.numeric(cluster_bbox[["xmax"]] - cluster_bbox[["xmin"]])
    dy <- as.numeric(cluster_bbox[["ymax"]] - cluster_bbox[["ymin"]])
    pad_x <- max(dx * 0.25, 350)
    pad_y <- max(dy * 0.25, 350)
    xlim <- c(cluster_bbox[["xmin"]] - pad_x, cluster_bbox[["xmax"]] + pad_x)
    ylim <- c(cluster_bbox[["ymin"]] - pad_y, cluster_bbox[["ymax"]] + pad_y)

    zone_crop <- if (!is.null(zones_r)) suppressWarnings(sf::st_crop(zones_r, c(xmin = xlim[1], xmax = xlim[2], ymin = ylim[1], ymax = ylim[2]))) else NULL
    boundary_crop <- if (!is.null(boundary_r)) suppressWarnings(sf::st_crop(boundary_r, c(xmin = xlim[1], xmax = xlim[2], ymin = ylim[1], ymax = ylim[2]))) else NULL

    prepost_map <- ggplot2::ggplot() +
      {if (!is.null(zone_crop)) ggplot2::geom_sf(data = zone_crop, fill = NA, colour = "grey75", linewidth = 0.25, inherit.aes = FALSE)} +
      {if (!is.null(boundary_crop)) ggplot2::geom_sf(data = boundary_crop, fill = NA, colour = "black", linewidth = 0.35, inherit.aes = FALSE)} +
      ggplot2::geom_sf(data = cluster_long, ggplot2::aes(fill = .data$value), colour = "black", linewidth = 0.35, inherit.aes = FALSE) +
      ggplot2::scale_fill_gradient(low = "#f7fbff", high = "#08519c", limits = c(0, 100), na.value = "grey90", name = "Frequency (%)") +
      ggplot2::facet_wrap(~ metric, ncol = 2) +
      ggplot2::coord_sf(xlim = xlim, ylim = ylim, expand = FALSE) +
      ggplot2::labs(
        title = paste0("Plot cluster ", this_cluster, ": pre and post inundation frequency"),
        subtitle = paste0("Nearby plots, n = ", nrow(cluster_plots), ". Frequency = percent of valid water years inundated at least once.")
      ) +
      gayini_theme_map(base_size = 12)

    prepost_path <- file.path(figure_dir, paste0("07g_", this_cluster, "_pre_post_frequency_panel_v2.png"))
    ggplot2::ggsave(prepost_path, plot = prepost_map, width = 11, height = 6.8, dpi = 300)

    diff_labels <- cluster_points %>%
      dplyr::mutate(diff_label = sprintf("%+.0f", .data$post_minus_pre_inundation_frequency_pct_points))

    difference_map <- ggplot2::ggplot() +
      {if (!is.null(zone_crop)) ggplot2::geom_sf(data = zone_crop, fill = NA, colour = "grey75", linewidth = 0.25, inherit.aes = FALSE)} +
      {if (!is.null(boundary_crop)) ggplot2::geom_sf(data = boundary_crop, fill = NA, colour = "black", linewidth = 0.35, inherit.aes = FALSE)} +
      ggplot2::geom_sf(data = cluster_plots, ggplot2::aes(fill = .data$post_minus_pre_inundation_frequency_pct_points), colour = "black", linewidth = 0.4, inherit.aes = FALSE) +
      ggplot2::scale_fill_gradient2(
        low = "#b2182b",
        mid = "white",
        high = "#2166ac",
        midpoint = 0,
        limits = c(-DIFF_DISPLAY_LIMIT, DIFF_DISPLAY_LIMIT),
        oob = scales::squish,
        na.value = "grey90",
        name = "Post - pre\n(pct points)"
      ) +
      {if (LABEL_CLUSTER_DIFFERENCE_VALUES) ggplot2::geom_text(data = diff_labels, ggplot2::aes(x = .data$x, y = .data$y, label = .data$diff_label), inherit.aes = FALSE, size = 3.8, fontface = "bold")} +
      ggplot2::coord_sf(xlim = xlim, ylim = ylim, expand = FALSE) +
      ggplot2::labs(
        title = paste0("Plot cluster ", this_cluster, ": post - pre difference"),
        subtitle = paste0("Labels are rounded percentage-point differences; n = ", nrow(cluster_plots), ".")
      ) +
      gayini_theme_map(base_size = 12)

    difference_path <- file.path(figure_dir, paste0("07g_", this_cluster, "_difference_panel_v2.png"))
    ggplot2::ggsave(difference_path, plot = difference_map, width = 8.5, height = 7, dpi = 300)

    context_map <- ggplot2::ggplot() +
      {if (!is.null(boundary_r)) ggplot2::geom_sf(data = boundary_r, fill = NA, colour = "black", linewidth = 0.45, inherit.aes = FALSE)} +
      ggplot2::geom_sf(data = plots_r, fill = "grey80", colour = "grey40", linewidth = 0.15, inherit.aes = FALSE) +
      ggplot2::geom_sf(data = cluster_plots, fill = "#2166ac", colour = "black", linewidth = 0.25, inherit.aes = FALSE) +
      ggplot2::coord_sf(expand = FALSE) +
      ggplot2::labs(title = paste0("Cluster context: ", this_cluster), subtitle = "Highlighted plots are shown in the local cluster panels.") +
      gayini_theme_map(base_size = 10) +
      ggplot2::theme(legend.position = "none")

    context_path <- file.path(figure_dir, paste0("07g_", this_cluster, "_whole_farm_context.png"))
    ggplot2::ggsave(context_path, plot = context_map, width = 5.5, height = 4.5, dpi = 250)

    figure_index <- dplyr::bind_rows(
      figure_index,
      tibble::tibble(
        figure_file = c(basename(prepost_path), basename(difference_path), basename(context_path)),
        figure_type = c("cluster_prepost_frequency", "cluster_difference", "cluster_context"),
        variables = c("pre/post inundation frequency", "post_minus_pre_inundation_frequency_pct_points", "cluster_id"),
        intended_use = c("Detailed Adrian review", "Detailed Adrian review", "Spatial orientation"),
        notes = c(
          "Pre shown before post.",
          "Labels show rounded percentage-point difference.",
          "Inset-style context saved as separate file for robustness."
        )
      )
    )
  }
}


## 4. Plot matrix heatmap ----

if (WRITE_MATRIX_PLOTS) {
  matrix_order <- plot_summary %>%
    dplyr::arrange(.data$post_minus_pre_inundation_frequency_pct_points) %>%
    dplyr::pull(.data$plot_id)

  matrix_data <- plot_summary %>%
    dplyr::select(
      "plot_id",
      "pre_conservation_inundation_frequency_pct",
      "post_conservation_inundation_frequency_pct",
      "post_minus_pre_inundation_frequency_pct_points",
      dplyr::any_of(c("pre_conservation_valid_year_count", "post_conservation_valid_year_count"))
    ) %>%
    tidyr::pivot_longer(
      cols = -"plot_id",
      names_to = "metric",
      values_to = "value"
    ) %>%
    dplyr::mutate(
      plot_id = factor(.data$plot_id, levels = matrix_order),
      metric_label = gayini_metric_label(.data$metric),
      metric_label = factor(
        .data$metric_label,
        levels = c(
          "Pre-conservation\nfrequency (%)",
          "Post-conservation\nfrequency (%)",
          "Post - pre\n(pct points)",
          "Pre valid\nyears",
          "Post valid\nyears"
        )
      ),
      display_value = dplyr::case_when(
        stringr::str_detect(.data$metric, "frequency_pct$") ~ .data$value / 100,
        .data$metric == "post_minus_pre_inundation_frequency_pct_points" ~ scales::rescale(scales::squish(.data$value, c(-DIFF_DISPLAY_LIMIT, DIFF_DISPLAY_LIMIT)), to = c(0, 1), from = c(-DIFF_DISPLAY_LIMIT, DIFF_DISPLAY_LIMIT)),
        stringr::str_detect(.data$metric, "valid_year_count$") ~ .data$value / max(.data$value, na.rm = TRUE),
        TRUE ~ NA_real_
      ),
      value_label = dplyr::case_when(
        stringr::str_detect(.data$metric, "valid_year_count$") ~ sprintf("%.0f", .data$value),
        TRUE ~ sprintf("%.0f", .data$value)
      )
    )

  matrix_plot <- ggplot2::ggplot(matrix_data, ggplot2::aes(x = .data$metric_label, y = .data$plot_id, fill = .data$display_value)) +
    ggplot2::geom_tile(colour = "white", linewidth = 0.15) +
    ggplot2::geom_text(ggplot2::aes(label = .data$value_label), size = 2.4) +
    ggplot2::scale_fill_gradient(low = "#f7fbff", high = "#08519c", na.value = "grey90", name = "Relative\ndisplay") +
    ggplot2::labs(
      title = "Plot-level Step 7 metric matrix",
      subtitle = "Numbers are raw values. Fill is scaled within metric type for readability.",
      x = NULL,
      y = "Plot ID"
    ) +
    gayini_theme_chart(base_size = 10) +
    ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 0, hjust = 0.5), panel.grid = ggplot2::element_blank())

  matrix_path <- file.path(figure_dir, "07g_plot_prepost_metric_matrix.png")
  ggplot2::ggsave(matrix_path, plot = matrix_plot, width = 8, height = 13, dpi = 300)

  figure_index <- dplyr::bind_rows(
    figure_index,
    tibble::tibble(
      figure_file = basename(matrix_path),
      figure_type = "plot_metric_matrix",
      variables = "pre/post/difference/valid years",
      intended_use = "Adrian-facing QA scan",
      notes = "Tile fill is relative for display; text labels show raw values."
    )
  )
}


## 5. Ranked and low-inundation plots ----

ranked_data <- plot_summary %>%
  dplyr::arrange(.data$post_minus_pre_inundation_frequency_pct_points) %>%
  dplyr::mutate(plot_id = factor(.data$plot_id, levels = .data$plot_id))

ranked_plot <- ggplot2::ggplot(ranked_data, ggplot2::aes(x = .data$plot_id, y = .data$post_minus_pre_inundation_frequency_pct_points, fill = .data$inundation_change_class)) +
  ggplot2::geom_col() +
  ggplot2::coord_flip() +
  ggplot2::scale_fill_manual(
    values = c(
      "much_drier_post" = "#b2182b",
      "drier_post" = "#ef8a62",
      "similar_frequency" = "#d9d9d9",
      "wetter_post" = "#67a9cf",
      "much_wetter_post" = "#2166ac",
      "no_comparison" = "grey70"
    ),
    labels = gayini_change_class_label,
    drop = FALSE,
    name = "Change class"
  ) +
  ggplot2::labs(
    title = "Ranked plot-level change in annual inundation occurrence frequency",
    subtitle = "Post-conservation minus pre-conservation; units are percentage points.",
    x = "Plot ID",
    y = "Post - pre (pct points)"
  ) +
  gayini_theme_chart(base_size = 11)

ranked_path <- file.path(figure_dir, "07g_ranked_plot_change_bar_chart_v2.png")
ggplot2::ggsave(ranked_path, plot = ranked_plot, width = 8.5, height = 11, dpi = 300)

low_water_data <- plot_summary %>%
  dplyr::arrange(.data$mean_period_frequency_pct) %>%
  dplyr::slice_head(n = 20) %>%
  dplyr::mutate(plot_id = factor(.data$plot_id, levels = rev(.data$plot_id))) %>%
  dplyr::select("plot_id", "pre_conservation_inundation_frequency_pct", "post_conservation_inundation_frequency_pct") %>%
  tidyr::pivot_longer(cols = -"plot_id", names_to = "period", values_to = "frequency_pct") %>%
  dplyr::mutate(
    period = factor(
      .data$period,
      levels = c("pre_conservation_inundation_frequency_pct", "post_conservation_inundation_frequency_pct"),
      labels = c("Pre", "Post")
    )
  )

low_water_plot <- ggplot2::ggplot(low_water_data, ggplot2::aes(x = .data$frequency_pct, y = .data$plot_id, colour = .data$period)) +
  ggplot2::geom_point(size = 2.8) +
  ggplot2::geom_line(ggplot2::aes(group = .data$plot_id), colour = "grey75", linewidth = 0.35) +
  ggplot2::labs(
    title = "Plots with lowest mean pre/post inundation frequency",
    subtitle = "These plots may be dry/edge plots, classification gaps, or genuinely rarely inundated areas.",
    x = "Annual inundation occurrence frequency (%)",
    y = "Plot ID",
    colour = "Period"
  ) +
  gayini_theme_chart(base_size = 11)

low_water_path <- file.path(figure_dir, "07g_low_inundation_plots.png")
ggplot2::ggsave(low_water_path, plot = low_water_plot, width = 8.5, height = 7, dpi = 300)

figure_index <- dplyr::bind_rows(
  figure_index,
  tibble::tibble(
    figure_file = c(basename(ranked_path), basename(low_water_path)),
    figure_type = c("ranked_change_bar_chart", "low_inundation_plot"),
    variables = c("post_minus_pre_inundation_frequency_pct_points", "pre/post inundation frequency"),
    intended_use = c("Adrian-facing ranking", "QA / anomaly review"),
    notes = c("Sorted by change magnitude.", "Shows the 20 lowest mean-frequency plots by default.")
  )
)


## Write figure index ----

figure_index_path <- file.path(figure_dir, "07g_figure_index_v2.csv")
gayini_write_figure_index(figure_index, figure_index_path)

message("07g v2 complete. Wrote figures to: ", figure_dir)
