## -----------------------------------------------------------------------------
## Gayini remote sensing workflow
## gayini_plot_hydrology_figures.R
## -----------------------------------------------------------------------------

## Purpose:
## Task 15 overlap-only hydrology and RS time-series figures.


gayini_make_task15_hydrology_overlap_figures <- function(root_dir,
                                                         input_paths,
                                                         figure_dir) {
  source_script <- "R/gayini_plot_hydrology_figures.R"

  if (is.na(input_paths[["water_year_context_csv"]])) {
    return(list(
      manifest = gayini_task15_skip_row(
        root_dir,
        "P0.7",
        "P0",
        "RS inundation and gauge-flow overlap-only time series",
        source_script,
        "water_year_context_csv",
        "Flow",
        "Joined RS/gauge water-year context table was not found.",
        "Gauges are contextual support, not plot-scale truth."
      ),
      metrics = list()
    ))
  }

  palette <- gayini_signal_palette()
  wy_context <- readr::read_csv(input_paths[["water_year_context_csv"]], show_col_types = FALSE)

  local_context <- wy_context |>
    dplyr::filter(.data$recommended_use == "local_upstream_primary") |>
    dplyr::mutate(water_year_numeric = as.integer(.data$water_year_numeric))

  rs_summary <- local_context |>
    dplyr::filter(!is.na(.data$daily_max_inundated_pct), !is.na(.data$total_flow_ml)) |>
    dplyr::distinct(
      .data$plot_id,
      .data$water_year,
      .data$water_year_numeric,
      .data$daily_max_inundated_pct,
      .data$total_veg_pct
    ) |>
    dplyr::group_by(.data$water_year, .data$water_year_numeric) |>
    dplyr::summarise(
      mean_rs_daily_max_pct = mean(.data$daily_max_inundated_pct, na.rm = TRUE),
      mean_total_veg_pct = mean(.data$total_veg_pct, na.rm = TRUE),
      n_plots = dplyr::n_distinct(.data$plot_id),
      .groups = "drop"
    )

  gauge_summary <- local_context |>
    dplyr::filter(!is.na(.data$total_flow_ml), !is.na(.data$daily_max_inundated_pct)) |>
    dplyr::distinct(
      .data$water_year,
      .data$water_year_numeric,
      .data$station_name,
      .data$total_flow_ml,
      .data$missing_flow_pct
    )

  overlap <- rs_summary |>
    dplyr::inner_join(gauge_summary, by = c("water_year", "water_year_numeric")) |>
    dplyr::arrange(.data$water_year_numeric)

  if (nrow(overlap) == 0L) {
    return(list(
      manifest = gayini_task15_skip_row(
        root_dir,
        "P0.7",
        "P0",
        "RS inundation and gauge-flow overlap-only time series",
        source_script,
        gayini_relative_path(root_dir, input_paths[["water_year_context_csv"]]),
        "Flow",
        "No overlapping local-upstream gauge and daily RS annual maximum rows were available.",
        "Gauges are contextual support, not plot-scale truth."
      ),
      metrics = list()
    ))
  }

  overlap_start <- min(overlap$water_year_numeric, na.rm = TRUE)
  overlap_end <- max(overlap$water_year_numeric, na.rm = TRUE)
  station_label <- unique(overlap$station_name)[1]

  flow_panel <- ggplot2::ggplot(overlap, ggplot2::aes(x = .data$water_year_numeric, y = .data$total_flow_ml / 1e6)) +
    ggplot2::geom_vline(xintercept = 2020, linetype = "dashed", colour = "grey35", linewidth = 0.45) +
    ggplot2::geom_line(colour = palette[["gauge_flow"]], linewidth = 0.9) +
    ggplot2::geom_point(colour = palette[["gauge_flow"]], size = 2.4) +
    ggplot2::scale_x_continuous(breaks = overlap$water_year_numeric) +
    ggplot2::labs(
      title = "Gauge flow context",
      subtitle = station_label,
      x = NULL,
      y = "Total flow (million ML)"
    ) +
    gayini_theme_review(base_size = 11, legend_position = "none")

  rs_panel <- ggplot2::ggplot(overlap, ggplot2::aes(x = .data$water_year_numeric, y = .data$mean_rs_daily_max_pct)) +
    ggplot2::geom_vline(xintercept = 2020, linetype = "dashed", colour = "grey35", linewidth = 0.45) +
    ggplot2::geom_line(colour = palette[["rs_inundation"]], linewidth = 0.9) +
    ggplot2::geom_point(colour = palette[["rs_inundation"]], size = 2.4) +
    ggplot2::coord_cartesian(ylim = c(0, 100)) +
    ggplot2::scale_x_continuous(breaks = overlap$water_year_numeric) +
    ggplot2::labs(
      title = "Remote-sensing inundation",
      subtitle = "Mean plot annual maximum observed daily wet footprint.",
      x = NULL,
      y = "RS wet footprint (%)"
    ) +
    gayini_theme_review(base_size = 11, legend_position = "none")

  veg_panel <- ggplot2::ggplot(overlap, ggplot2::aes(x = .data$water_year_numeric, y = .data$mean_total_veg_pct)) +
    ggplot2::geom_vline(xintercept = 2020, linetype = "dashed", colour = "grey35", linewidth = 0.45) +
    ggplot2::geom_line(colour = palette[["total_vegetation"]], linewidth = 0.9) +
    ggplot2::geom_point(colour = palette[["total_vegetation"]], size = 2.4) +
    ggplot2::coord_cartesian(ylim = c(0, 100)) +
    ggplot2::scale_x_continuous(breaks = overlap$water_year_numeric) +
    ggplot2::labs(
      title = "Total vegetation context",
      subtitle = "Mean plot total vegetation for the same overlap years.",
      x = "Water year ending",
      y = "Total vegetation (%)"
    ) +
    gayini_theme_review(base_size = 11, legend_position = "none")

  overlap_plot <- flow_panel / rs_panel / veg_panel +
    patchwork::plot_annotation(
      title = "Gauge flow, RS inundation and vegetation in the common overlap period",
      subtitle = paste0("Common overlap years: ", overlap_start, " to ", overlap_end, "; dashed line marks the 2019-07-01 transition as WY2020."),
      caption = "Gauge flow is contextual support only and is not plot-scale truth. RS wet footprint is observed extent, not depth, duration or hydroperiod."
    ) &
    ggplot2::theme(plot.background = ggplot2::element_rect(fill = "white", colour = NA))

  output_path <- file.path(figure_dir, "hydrology", "P0_7_RS_gauge_flow_overlap_timeseries.png")
  gayini_save_review_figure(output_path, overlap_plot, height = 8.4)

  manifest <- gayini_task15_manifest_row(
    root_dir = root_dir,
    figure_id = "P0.7",
    priority = "P0",
    figure_title = "RS inundation and gauge-flow overlap-only time series",
    output_path = output_path,
    source_script = source_script,
    source_data = gayini_relative_path(root_dir, input_paths[["water_year_context_csv"]]),
    deck_section = "Flow",
    status = "created",
    caption_suggestion = paste0("Gauge flow, RS annual maximum observed wet footprint and total vegetation for the common overlap period ", overlap_start, "-", overlap_end, "."),
    caveat_text = "Gauges are contextual support, not plot-scale truth; RS inundation is observed wet footprint / occurrence, not hydroperiod, duration or depth.",
    qa_status = "pass",
    qa_notes = paste0("Overlap restricted to ", overlap_start, "-", overlap_end, " using local upstream gauge context.")
  )

  list(
    manifest = manifest,
    metrics = list(overlap_start = overlap_start, overlap_end = overlap_end, overlap_year_count = nrow(overlap))
  )
}
