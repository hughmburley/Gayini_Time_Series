## -----------------------------------------------------------------------------
## Gayini remote sensing workflow
## step7_figure_helpers.R
## -----------------------------------------------------------------------------


## Purpose:
## Shared helper functions for Step 7 figure and LUT scripts.
## These helpers deliberately use magrittr %>% pipes, matching the project style.


`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0 || all(is.na(x))) y else x
}


gayini_check_packages <- function(required_packages) {
  missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]

  if (length(missing_packages) > 0) {
    stop(
      "Missing required packages: ",
      paste(missing_packages, collapse = ", "),
      call. = FALSE
    )
  }

  invisible(TRUE)
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

  for (nm in nms) {
    vals <- as.character(x[[nm]])
    vals <- vals[!is.na(vals)]

    if (length(vals) > 0 && any(grepl("^GA_[0-9]{3}$", vals))) {
      return(nm)
    }
  }

  NA_character_
}


gayini_standardise_plot_id <- function(x, object_name = "object") {
  id_col <- gayini_find_plot_id_column(x)

  if (is.na(id_col)) {
    stop(
      "Could not find a plot ID column in ", object_name,
      ". Available columns: ", paste(names(x), collapse = ", "),
      call. = FALSE
    )
  }

  x$plot_id <- stringr::str_trim(as.character(x[[id_col]]))

  message("Using plot ID column in ", object_name, ": ", id_col)

  x
}


gayini_read_step7_plot_summary <- function(root_dir) {
  plot_summary_path <- gayini_find_first_existing(c(
    file.path(root_dir, "Output", "csv", "07f_pre_post_inundation_plot_summary_fixed.csv"),
    file.path(root_dir, "data_processed", "plot_pre_post_inundation_frequency_fixed.csv"),
    file.path(root_dir, "Output", "csv", "07e_pre_post_inundation_plot_summary.csv"),
    file.path(root_dir, "data_processed", "plot_pre_post_inundation_frequency.csv")
  ))

  if (is.na(plot_summary_path)) {
    stop("Could not find a Step 7 plot summary table. Run 07f or 07e first.", call. = FALSE)
  }

  message("Reading Step 7 plot summary: ", plot_summary_path)

  readr::read_csv(plot_summary_path, show_col_types = FALSE) %>%
    gayini_standardise_plot_id(object_name = "plot summary")
}


gayini_get_first_existing_column <- function(df, candidates, default = NA) {
  hit <- candidates[candidates %in% names(df)]

  if (length(hit) > 0) {
    return(df[[hit[[1]]]])
  }

  if (length(default) == 1) {
    return(rep(default, nrow(df)))
  }

  default
}


gayini_fc_band_lookup <- function() {
  tibble::tibble(
    band_number = c(1L, 2L, 3L),
    cover_key = c("bare_ground", "green_pv", "non_green_npv"),
    cover_class = c("Bare ground", "Green / PV", "Non-green / NPV"),
    display_order = c(2L, 1L, 3L),
    units = "percent",
    nodata_value = 255L,
    source = "TERN/JRSRP seasonal ground cover metadata"
  )
}


gayini_recode_ground_cover_class <- function(df) {
  n <- nrow(df)

  band_number <- if ("band_number" %in% names(df)) {
    suppressWarnings(as.integer(df$band_number))
  } else {
    rep(NA_integer_, n)
  }

  band_label <- if ("band_label" %in% names(df)) {
    stringr::str_to_lower(as.character(df$band_label))
  } else {
    rep(NA_character_, n)
  }

  dplyr::case_when(
    !is.na(band_number) & band_number == 1L ~ "Bare ground",
    !is.na(band_number) & band_number == 2L ~ "Green / PV",
    !is.na(band_number) & band_number == 3L ~ "Non-green / NPV",
    is.na(band_number) & stringr::str_detect(band_label, "bare") ~ "Bare ground",
    is.na(band_number) & stringr::str_detect(band_label, "non|npv") ~ "Non-green / NPV",
    is.na(band_number) & stringr::str_detect(band_label, "green|pv") ~ "Green / PV",
    TRUE ~ "cover_unknown"
  )
}


gayini_make_band_label <- function(df) {
  gayini_recode_ground_cover_class(df)
}


gayini_prepare_ground_cover_long <- function(fc_path,
                                             only_adequate_coverage = TRUE,
                                             value_column_candidates = c("mean_value", "median_value", "cover_value"),
                                             object_name = "fractional-cover table") {
  fc_data <- readr::read_csv(fc_path, show_col_types = FALSE) %>%
    gayini_standardise_plot_id(object_name = object_name)

  fc_data$date_plot <- as.Date(gayini_get_first_existing_column(fc_data, c("date_midpoint", "date_start", "date_end")))
  fc_data$cover_value <- as.numeric(gayini_get_first_existing_column(fc_data, value_column_candidates, default = NA_real_))
  fc_data$cover_class <- gayini_recode_ground_cover_class(fc_data)

  if ("band_number" %in% names(fc_data)) {
    fc_data$band_number <- suppressWarnings(as.integer(fc_data$band_number))
  }

  fc_data <- fc_data %>%
    dplyr::mutate(
      cover_value = dplyr::if_else(.data$cover_value == 255, NA_real_, .data$cover_value),
      cover_value = pmax(pmin(.data$cover_value, 100), 0),
      tern_band_mapping_used = TRUE,
      tern_band_mapping_note = "TERN/JRSRP mapping: band 1 bare, band 2 green, band 3 non-green; 255 NoData."
    )

  if (only_adequate_coverage && "valid_coverage_status" %in% names(fc_data)) {
    fc_data <- fc_data %>%
      dplyr::filter(.data$valid_coverage_status == "adequate_coverage")
  }

  fc_data %>%
    dplyr::filter(!is.na(.data$date_plot), !is.na(.data$cover_value), .data$cover_class != "cover_unknown")
}


gayini_prepare_ground_cover_total_bare <- function(fc_long) {
  wide <- fc_long %>%
    dplyr::mutate(
      cover_key = dplyr::case_when(
        .data$cover_class == "Bare ground" ~ "bare_ground_pct",
        .data$cover_class == "Green / PV" ~ "green_pv_pct",
        .data$cover_class == "Non-green / NPV" ~ "non_green_npv_pct",
        TRUE ~ NA_character_
      )
    ) %>%
    dplyr::filter(!is.na(.data$cover_key)) %>%
    dplyr::group_by(.data$plot_id, .data$date_plot, .data$cover_key) %>%
    dplyr::summarise(
      cover_value = mean(.data$cover_value, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    tidyr::pivot_wider(names_from = "cover_key", values_from = "cover_value")

  for (nm in c("bare_ground_pct", "green_pv_pct", "non_green_npv_pct")) {
    if (!nm %in% names(wide)) {
      wide[[nm]] <- NA_real_
    }
  }

  wide %>%
    dplyr::mutate(
      total_vegetation_pct = dplyr::if_else(
        is.na(.data$green_pv_pct) & is.na(.data$non_green_npv_pct),
        NA_real_,
        rowSums(dplyr::pick("green_pv_pct", "non_green_npv_pct"), na.rm = TRUE)
      )
    ) %>%
    dplyr::select("plot_id", "date_plot", "total_vegetation_pct", "bare_ground_pct") %>%
    tidyr::pivot_longer(
      cols = c("total_vegetation_pct", "bare_ground_pct"),
      names_to = "metric_key",
      values_to = "cover_pct"
    ) %>%
    dplyr::mutate(
      metric = dplyr::case_when(
        .data$metric_key == "total_vegetation_pct" ~ "Total vegetation",
        .data$metric_key == "bare_ground_pct" ~ "Bare ground",
        TRUE ~ .data$metric_key
      ),
      metric_note = dplyr::case_when(
        .data$metric == "Total vegetation" ~ "Green / PV + Non-green / NPV",
        .data$metric == "Bare ground" ~ "TERN/JRSRP band 1",
        TRUE ~ NA_character_
      )
    ) %>%
    dplyr::filter(!is.na(.data$cover_pct))
}


gayini_add_gap_segments <- function(df,
                                    date_col = "date_plot",
                                    group_cols = c("plot_id", "metric"),
                                    gap_days_for_new_segment = 550) {
  df %>%
    dplyr::arrange(dplyr::across(dplyr::all_of(group_cols)), .data[[date_col]]) %>%
    dplyr::group_by(dplyr::across(dplyr::all_of(group_cols))) %>%
    dplyr::mutate(
      gap_days = as.numeric(.data[[date_col]] - dplyr::lag(.data[[date_col]])),
      segment_id = cumsum(dplyr::coalesce(.data$gap_days > gap_days_for_new_segment, FALSE))
    ) %>%
    dplyr::ungroup()
}


gayini_metric_label <- function(metric) {
  dplyr::case_when(
    metric == "pre_conservation_inundation_frequency_pct" ~ "Pre-conservation\nfrequency (%)",
    metric == "post_conservation_inundation_frequency_pct" ~ "Post-conservation\nfrequency (%)",
    metric == "post_minus_pre_inundation_frequency_pct_points" ~ "Post - pre\n(pct points)",
    metric == "pre_conservation_valid_year_count" ~ "Pre valid\nyears",
    metric == "post_conservation_valid_year_count" ~ "Post valid\nyears",
    metric == "mean_period_frequency_pct" ~ "Mean pre/post\nfrequency (%)",
    TRUE ~ metric
  )
}


gayini_change_class_label <- function(x) {
  dplyr::case_when(
    x == "much_wetter_post" ~ "Much wetter post",
    x == "wetter_post" ~ "Wetter post",
    x == "similar_frequency" ~ "Similar frequency",
    x == "drier_post" ~ "Drier post",
    x == "much_drier_post" ~ "Much drier post",
    x == "no_comparison" ~ "No comparison",
    TRUE ~ x
  )
}


gayini_classify_change <- function(x) {
  dplyr::case_when(
    is.na(x) ~ "no_comparison",
    x >= 20 ~ "much_wetter_post",
    x >= 5 ~ "wetter_post",
    x <= -20 ~ "much_drier_post",
    x <= -5 ~ "drier_post",
    TRUE ~ "similar_frequency"
  )
}


gayini_theme_map <- function(base_size = 12) {
  ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      panel.grid = ggplot2::element_blank(),
      strip.text = ggplot2::element_text(face = "bold", size = base_size),
      plot.title = ggplot2::element_text(face = "bold", size = base_size + 4),
      plot.subtitle = ggplot2::element_text(size = base_size),
      axis.title = ggplot2::element_blank(),
      axis.text = ggplot2::element_blank(),
      axis.ticks = ggplot2::element_blank(),
      legend.title = ggplot2::element_text(face = "bold"),
      legend.position = "right"
    )
}


gayini_theme_chart <- function(base_size = 12) {
  ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(face = "bold", size = base_size + 4),
      plot.subtitle = ggplot2::element_text(size = base_size),
      axis.text.x = ggplot2::element_text(angle = 45, hjust = 1),
      legend.position = "bottom",
      legend.title = ggplot2::element_text(face = "bold")
    )
}


gayini_raster_to_df <- function(r, value_name = names(r)[[1]]) {
  out <- terra::as.data.frame(r, xy = TRUE, na.rm = FALSE)

  if (!value_name %in% names(out)) {
    names(out)[3] <- value_name
  }

  out
}


gayini_get_centroid_df <- function(plots_sf) {
  centroids <- suppressWarnings(sf::st_centroid(plots_sf))
  coords <- sf::st_coordinates(centroids) %>%
    tibble::as_tibble() %>%
    dplyr::rename(x = X, y = Y)

  centroids %>%
    sf::st_drop_geometry() %>%
    dplyr::bind_cols(coords)
}


gayini_load_plot_context <- function(root_dir) {
  plots_path <- gayini_find_first_existing(c(
    file.path(root_dir, "Input", "shapefiles", "gayini_hectare_plots.shp"),
    file.path(root_dir, "data_intermediate", "spatial", "plots_clean.gpkg")
  ))

  boundary_path <- gayini_find_first_existing(c(
    file.path(root_dir, "Input", "shapefiles", "gayini_boundary.shp"),
    file.path(root_dir, "data_intermediate", "spatial", "boundary_clean.gpkg")
  ))

  zones_path <- gayini_find_first_existing(c(
    file.path(root_dir, "Input", "shapefiles", "CA0561_ManagementZones.shp"),
    file.path(root_dir, "Input", "shapefiles", "management_zones.shp"),
    file.path(root_dir, "data_intermediate", "spatial", "management_zones_clean.gpkg")
  ))

  if (is.na(plots_path)) {
    stop("Could not find plot spatial data.", call. = FALSE)
  }

  plots_sf <- sf::st_read(plots_path, quiet = TRUE) %>%
    gayini_standardise_plot_id(object_name = "plots spatial data") %>%
    sf::st_make_valid()

  list(
    plots_sf = plots_sf,
    boundary_sf = gayini_read_optional_sf(boundary_path),
    zones_sf = gayini_read_optional_sf(zones_path),
    plots_path = plots_path,
    boundary_path = boundary_path,
    zones_path = zones_path
  )
}


gayini_load_or_make_clusters <- function(root_dir, plots_sf, target_group_size = 7) {
  cluster_path <- gayini_find_first_existing(c(
    file.path(root_dir, "Output", "figures", "07g_prepost_panels_v2", "07g_plot_cluster_lookup_v2.csv"),
    file.path(root_dir, "Output", "figures", "07g_prepost_panels", "07g_plot_cluster_lookup.csv")
  ))

  if (!is.na(cluster_path)) {
    message("Reading existing cluster lookup: ", cluster_path)

    cluster_lookup <- readr::read_csv(cluster_path, show_col_types = FALSE) %>%
      gayini_standardise_plot_id(object_name = "cluster lookup")

    if (!"cluster_id" %in% names(cluster_lookup)) {
      stop("Cluster lookup exists but does not contain cluster_id: ", cluster_path, call. = FALSE)
    }

    return(cluster_lookup %>% dplyr::select("plot_id", "cluster_id", dplyr::everything()))
  }

  message("No existing cluster lookup found. Creating approximate k-means groups.")

  centroid_df <- gayini_get_centroid_df(plots_sf)
  coords <- as.matrix(centroid_df[, c("x", "y")])
  n_groups <- max(1, ceiling(nrow(plots_sf) / target_group_size))

  set.seed(42)
  km <- stats::kmeans(coords, centers = n_groups, iter.max = 100)

  cluster_order <- centroid_df %>%
    dplyr::mutate(cluster_raw = km$cluster) %>%
    dplyr::group_by(.data$cluster_raw) %>%
    dplyr::summarise(x = mean(.data$x), y = mean(.data$y), n_plots = dplyr::n(), .groups = "drop") %>%
    dplyr::arrange(dplyr::desc(.data$y), .data$x) %>%
    dplyr::mutate(cluster_id = paste0("cluster_", stringr::str_pad(dplyr::row_number(), 2, pad = "0")))

  centroid_df %>%
    dplyr::mutate(cluster_raw = km$cluster) %>%
    dplyr::left_join(cluster_order, by = "cluster_raw", suffix = c("", "_cluster")) %>%
    dplyr::select("plot_id", "cluster_id", "n_plots")
}


gayini_make_period_plot_data <- function(plot_summary) {
  out <- plot_summary

  if (!"post_minus_pre_inundation_frequency_pct_points" %in% names(out)) {
    out$post_minus_pre_inundation_frequency_pct_points <-
      out$post_conservation_inundation_frequency_pct - out$pre_conservation_inundation_frequency_pct
  }

  if (!"inundation_change_class" %in% names(out)) {
    out$inundation_change_class <- gayini_classify_change(out$post_minus_pre_inundation_frequency_pct_points)
  }

  out$mean_period_frequency_pct <- rowMeans(
    out[, c("pre_conservation_inundation_frequency_pct", "post_conservation_inundation_frequency_pct")],
    na.rm = TRUE
  )

  out %>%
    dplyr::mutate(
      low_inundation_flag = .data$pre_conservation_inundation_frequency_pct < 5 &
        .data$post_conservation_inundation_frequency_pct < 5,
      strong_increase_flag = .data$post_minus_pre_inundation_frequency_pct_points >= 20,
      strong_decrease_flag = .data$post_minus_pre_inundation_frequency_pct_points <= -20,
      review_flag = dplyr::case_when(
        .data$strong_increase_flag ~ "strong increase",
        .data$strong_decrease_flag ~ "strong decrease",
        .data$low_inundation_flag ~ "rarely inundated",
        TRUE ~ "standard review"
      )
    )
}


gayini_write_figure_index <- function(figure_index, path) {
  readr::write_csv(figure_index, path)
  message("Wrote: ", path)
  invisible(figure_index)
}
