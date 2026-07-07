## -----------------------------------------------------------------------------
## Gayini remote sensing workflow
## gayini_dashboard_figures.R
## -----------------------------------------------------------------------------

## Purpose:
## Task 15 selected plot dashboards with fixed semantic colours.


gayini_task15_change_class_label <- function(x) {
  dplyr::case_when(
    x == "much_wetter_post" ~ "Much wetter post",
    x == "wetter_post" ~ "Wetter post",
    x == "similar_frequency" ~ "Similar frequency",
    x == "drier_post" ~ "Drier post",
    x == "much_drier_post" ~ "Much drier post",
    TRUE ~ stringr::str_to_sentence(stringr::str_replace_all(as.character(x), "_", " "))
  )
}


gayini_task15_dashboard_one_plot <- function(plot_id,
                                             water_year_context,
                                             plot_context) {
  palette <- gayini_signal_palette()

  row <- plot_context |>
    dplyr::filter(.data$plot_id == plot_id) |>
    dplyr::slice_head(n = 1)

  ts <- water_year_context |>
    dplyr::filter(.data$plot_id == plot_id, .data$recommended_use == "local_upstream_primary") |>
    dplyr::mutate(water_year_numeric = as.integer(.data$water_year_numeric)) |>
    dplyr::filter(!is.na(.data$water_year_numeric)) |>
    dplyr::distinct(
      .data$plot_id,
      .data$water_year,
      .data$water_year_numeric,
      .data$station_name,
      .data$total_flow_ml,
      .data$daily_max_inundated_pct,
      .data$total_veg_pct,
      .data$bare_ground_pct
    ) |>
    dplyr::filter(
      .data$water_year_numeric >= 2015,
      .data$water_year_numeric <= 2023
    ) |>
    dplyr::arrange(.data$water_year_numeric)

  if (nrow(ts) == 0L) {
    return(NULL)
  }

  title_bits <- c(
    plot_id,
    if ("simplified_vegetation_group" %in% names(row)) row$simplified_vegetation_group[[1]] else NA_character_,
    if ("collapsed_grazing_category" %in% names(row)) row$collapsed_grazing_category[[1]] else NA_character_
  )
  title_bits <- title_bits[!is.na(title_bits) & nzchar(title_bits)]

  flow_panel <- ggplot2::ggplot(ts, ggplot2::aes(x = .data$water_year_numeric, y = .data$total_flow_ml / 1e6)) +
    ggplot2::geom_vline(xintercept = 2020, linetype = "dashed", colour = "grey35", linewidth = 0.42) +
    ggplot2::geom_line(colour = palette[["gauge_flow"]], linewidth = 0.85, na.rm = TRUE) +
    ggplot2::geom_point(colour = palette[["gauge_flow"]], size = 2.1, na.rm = TRUE) +
    ggplot2::scale_x_continuous(breaks = ts$water_year_numeric) +
    ggplot2::labs(title = "Gauge flow", x = NULL, y = "Million ML") +
    gayini_theme_review(base_size = 10, legend_position = "none")

  rs_panel <- ggplot2::ggplot(ts, ggplot2::aes(x = .data$water_year_numeric, y = .data$daily_max_inundated_pct)) +
    ggplot2::geom_vline(xintercept = 2020, linetype = "dashed", colour = "grey35", linewidth = 0.42) +
    ggplot2::geom_line(colour = palette[["rs_inundation"]], linewidth = 0.85, na.rm = TRUE) +
    ggplot2::geom_point(colour = palette[["rs_inundation"]], size = 2.1, na.rm = TRUE) +
    ggplot2::coord_cartesian(ylim = c(0, 100)) +
    ggplot2::scale_x_continuous(breaks = ts$water_year_numeric) +
    ggplot2::labs(title = "RS annual maximum observed wet footprint", x = NULL, y = "Wet footprint (%)") +
    gayini_theme_review(base_size = 10, legend_position = "none")

  cover_long <- ts |>
    dplyr::select("water_year_numeric", "total_veg_pct", "bare_ground_pct") |>
    tidyr::pivot_longer(
      cols = c("total_veg_pct", "bare_ground_pct"),
      names_to = "metric",
      values_to = "value_pct"
    ) |>
    dplyr::mutate(metric = dplyr::case_when(
      .data$metric == "total_veg_pct" ~ "Total vegetation",
      .data$metric == "bare_ground_pct" ~ "Bare ground",
      TRUE ~ .data$metric
    ))

  cover_panel <- ggplot2::ggplot(cover_long, ggplot2::aes(x = .data$water_year_numeric, y = .data$value_pct, colour = .data$metric)) +
    ggplot2::geom_vline(xintercept = 2020, linetype = "dashed", colour = "grey35", linewidth = 0.42) +
    ggplot2::geom_line(linewidth = 0.85, na.rm = TRUE) +
    ggplot2::geom_point(size = 2.1, na.rm = TRUE) +
    ggplot2::coord_cartesian(ylim = c(0, 100)) +
    ggplot2::scale_x_continuous(breaks = ts$water_year_numeric) +
    ggplot2::scale_colour_manual(
      values = c("Total vegetation" = palette[["total_vegetation"]], "Bare ground" = palette[["bare_ground"]])
    ) +
    ggplot2::labs(title = "Ground cover", x = "Water year ending", y = "Cover (%)", colour = "Metric") +
    gayini_theme_review(base_size = 10, legend_position = "bottom")

  (flow_panel / rs_panel / cover_panel) +
    patchwork::plot_annotation(
      title = paste(title_bits, collapse = " | "),
      subtitle = "Selected review dashboard using fixed semantic colours.",
      caption = "Diagnostic/archetype product only. Gauge flow is contextual support; RS wet footprint is not depth, duration or hydroperiod."
    ) &
    ggplot2::theme(plot.background = ggplot2::element_rect(fill = "white", colour = NA))
}


gayini_task15_make_dashboard_site_map <- function(root_dir,
                                                  input_paths,
                                                  figure_dir,
                                                  dashboard_plots,
                                                  plot_context) {
  if (is.na(input_paths[["plot_spatial_gpkg"]]) || is.na(input_paths[["boundary_gpkg"]])) {
    return(gayini_task15_skip_row(
      root_dir,
      "P1.2",
      "P1",
      "Selected dashboard-site map",
      "R/gayini_dashboard_figures.R",
      "plot_spatial_gpkg; boundary_gpkg",
      "Dashboards",
      "Plot spatial layer or boundary layer was not available."
    ))
  }

  plots_sf <- sf::st_read(input_paths[["plot_spatial_gpkg"]], quiet = TRUE) |>
    dplyr::left_join(plot_context, by = "plot_id") |>
    dplyr::mutate(
      dashboard_selected = .data$plot_id %in% dashboard_plots,
      change_label = gayini_task15_change_class_label(.data$inundation_change_class)
    )

  boundary <- sf::st_read(input_paths[["boundary_gpkg"]], quiet = TRUE) |>
    sf::st_transform(sf::st_crs(plots_sf))

  selected <- plots_sf |>
    dplyr::filter(.data$dashboard_selected)
  label_points <- sf::st_point_on_surface(selected)
  label_coords <- sf::st_coordinates(label_points)
  label_df <- dplyr::bind_cols(
    sf::st_drop_geometry(selected),
    tibble::as_tibble(label_coords)
  )

  change_cols <- c(
    "Drier post" = "#b84a4a",
    "Similar frequency" = "#777777",
    "Wetter post" = "#2f74b5",
    "Much wetter post" = "#08519c",
    "Much drier post" = "#8c510a"
  )

  map_plot <- ggplot2::ggplot() +
    ggplot2::geom_sf(data = boundary, fill = "white", colour = "#303030", linewidth = 0.5) +
    ggplot2::geom_sf(data = plots_sf, fill = "#f2f2f2", colour = "#bdbdbd", linewidth = 0.25) +
    ggplot2::geom_sf(data = selected, ggplot2::aes(fill = .data$change_label), colour = "#1f2d2a", linewidth = 0.75) +
    ggplot2::geom_point(
      data = label_df,
      ggplot2::aes(x = .data$X, y = .data$Y, shape = .data$collapsed_grazing_category),
      inherit.aes = FALSE,
      size = 3.0,
      colour = "#1f2d2a",
      fill = "white"
    ) +
    ggrepel::geom_text_repel(
      data = label_df,
      ggplot2::aes(x = .data$X, y = .data$Y, label = .data$plot_id),
      inherit.aes = FALSE,
      size = 3.0,
      colour = "#1f2d2a",
      min.segment.length = 0,
      box.padding = 0.35,
      seed = 42
    ) +
    ggplot2::scale_fill_manual(values = change_cols, na.value = "#bdbdbd") +
    ggplot2::scale_shape_manual(values = c("No grazing" = 21, "Any grazing" = 24, "Unknown" = 22), drop = FALSE) +
    ggplot2::labs(
      title = "Selected dashboard review sites",
      subtitle = "Highlighted plots are the refreshed dashboard set.",
      fill = "Annual occurrence class",
      shape = "Grazing category",
      caption = "Site selection is for diagnostic review coverage, not causal ranking."
    ) +
    gayini_theme_map(base_size = 12, legend_position = "bottom")

  output_path <- file.path(figure_dir, "dashboards", "P1_2_selected_dashboard_site_map.png")
  gayini_save_review_figure(output_path, map_plot)

  gayini_task15_manifest_row(
    root_dir,
    "P1.2",
    "P1",
    "Selected dashboard-site map",
    output_path,
    "R/gayini_dashboard_figures.R",
    paste(
      gayini_relative_path(root_dir, input_paths[["plot_spatial_gpkg"]]),
      gayini_relative_path(root_dir, input_paths[["boundary_gpkg"]]),
      gayini_relative_path(root_dir, input_paths[["plot_context_flags_csv"]]),
      sep = "; "
    ),
    "Dashboards",
    status = "created",
    caption_suggestion = "Map of selected dashboard review sites, coloured by annual occurrence change class.",
    caveat_text = "Dashboard sites are diagnostic examples and do not imply causal ranking.",
    qa_status = "pass",
    qa_notes = paste0("Selected dashboard plots mapped: ", paste(dashboard_plots, collapse = ", "), ".")
  )
}


gayini_make_task15_dashboard_figures <- function(root_dir,
                                                 input_paths,
                                                 figure_dir,
                                                 dashboard_plots = c("GA_019", "GA_052", "GA_032", "GA_001", "GA_003", "GA_026", "GA_035", "GA_043")) {
  source_script <- "R/gayini_dashboard_figures.R"

  if (is.na(input_paths[["water_year_context_csv"]]) || is.na(input_paths[["plot_context_flags_csv"]])) {
    return(list(
      manifest = gayini_task15_skip_row(
        root_dir,
        "P0.10",
        "P0",
        "Dashboard colour refresh",
        source_script,
        "water_year_context_csv; plot_context_flags_csv",
        "Dashboards",
        "Joined water-year context table or plot context flags were not found.",
        "Dashboard outputs are diagnostic/archetype products, not causal proof."
      ),
      metrics = list()
    ))
  }

  water_year_context <- readr::read_csv(input_paths[["water_year_context_csv"]], show_col_types = FALSE)
  plot_context <- gayini_task15_read_plot_context(input_paths[["plot_context_flags_csv"]])
  if (!"inundation_change_class" %in% names(plot_context)) {
    plot_context$inundation_change_class <- NA_character_
  }

  dashboard_rows <- list()
  dashboard_index <- list()

  for (plot_id in dashboard_plots) {
    dashboard_plot <- gayini_task15_dashboard_one_plot(plot_id, water_year_context, plot_context)
    if (is.null(dashboard_plot)) {
      dashboard_rows[[length(dashboard_rows) + 1L]] <- gayini_task15_skip_row(
        root_dir,
        paste0("P0.10.", plot_id),
        "P0",
        paste0("Dashboard colour refresh: ", plot_id),
        source_script,
        gayini_relative_path(root_dir, input_paths[["water_year_context_csv"]]),
        "Dashboards",
        paste0("No overlapping dashboard time-series rows available for ", plot_id, "."),
        "Dashboard outputs are diagnostic/archetype products, not causal proof."
      )
      next
    }

    output_path <- file.path(figure_dir, "dashboards", paste0("P0_10_dashboard_", plot_id, ".png"))
    gayini_save_review_figure(output_path, dashboard_plot, height = 8.4)

    dashboard_rows[[length(dashboard_rows) + 1L]] <- gayini_task15_manifest_row(
      root_dir,
      paste0("P0.10.", plot_id),
      "P0",
      paste0("Dashboard colour refresh: ", plot_id),
      output_path,
      source_script,
      paste(
        gayini_relative_path(root_dir, input_paths[["water_year_context_csv"]]),
        gayini_relative_path(root_dir, input_paths[["plot_context_flags_csv"]]),
        sep = "; "
      ),
      "Dashboards",
      status = "created",
      caption_suggestion = paste0("Diagnostic dashboard for ", plot_id, " with fixed semantic colours."),
      caveat_text = "Dashboard outputs are diagnostic/archetype products; gauge flow is context and RS wet footprint is not hydroperiod or depth.",
      qa_status = "pass",
      qa_notes = "Gauge flow dark blue, RS inundation light blue, total vegetation emerald green and bare ground brown."
    )

    dashboard_index[[length(dashboard_index) + 1L]] <- tibble::tibble(
      plot_id = plot_id,
      output_path = gayini_relative_path(root_dir, output_path),
      status = "created"
    )
  }

  site_map_row <- gayini_task15_make_dashboard_site_map(
    root_dir = root_dir,
    input_paths = input_paths,
    figure_dir = figure_dir,
    dashboard_plots = dashboard_plots,
    plot_context = plot_context
  )

  index <- dplyr::bind_rows(dashboard_index)
  if (nrow(index) > 0L) {
    gayini_write_csv(index, file.path(root_dir, "Output", "reports", "figure_refresh", "task15_dashboard_index.csv"))
  }

  list(
    manifest = dplyr::bind_rows(dashboard_rows, site_map_row),
    metrics = list(dashboard_created_count = sum(vapply(dashboard_rows, function(x) any(x$status == "created"), logical(1))))
  )
}
