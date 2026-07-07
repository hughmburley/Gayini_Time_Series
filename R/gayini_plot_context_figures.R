## -----------------------------------------------------------------------------
## Gayini remote sensing workflow
## gayini_plot_context_figures.R
## -----------------------------------------------------------------------------

## Purpose:
## Task 15 plot-context figures: vegetation, interpretation status and grazing.


gayini_task15_read_plot_context <- function(path) {
  context_raw <- readr::read_csv(path, show_col_types = FALSE)

  context <- context_raw |>
    dplyr::mutate(
      plot_id = as.character(.data$plot_id),
      simplified_vegetation_group = dplyr::coalesce(
        gayini_column(context_raw, c("simplified_vegetation_group")),
        gayini_column(context_raw, c("vegetation_adrian_group", "vegetation")),
        "Unknown"
      ),
      original_grazing_category = gayini_column(
        context_raw,
        c("original_grazing_treatment_category", "treatment", "collapsed_grazing_category"),
        default = NA_character_
      ),
      collapsed_grazing_category = gayini_collapse_grazing(
        dplyr::coalesce(
          gayini_column(context_raw, c("collapsed_grazing_category"), default = NA_character_),
          .data$original_grazing_category
        )
      ),
      treed_plot_flag = as.logical(.data$treed_plot_flag),
      ground_cover_exclusion_flag = as.logical(.data$ground_cover_exclusion_flag),
      interpretation_status = dplyr::if_else(
        dplyr::coalesce(.data$treed_plot_flag, FALSE) |
          dplyr::coalesce(.data$ground_cover_exclusion_flag, FALSE),
        "Treed / flagged",
        "Ground-cover interpretation"
      )
    )

  context |>
    dplyr::mutate(
      interpretation_status = factor(
        .data$interpretation_status,
        levels = c("Ground-cover interpretation", "Treed / flagged")
      ),
      collapsed_grazing_category = factor(
        .data$collapsed_grazing_category,
        levels = c("No grazing", "Any grazing", "Unknown")
      )
    )
}


gayini_task15_write_grazing_mapping <- function(context, path) {
  mapping <- context |>
    dplyr::count(
      .data$original_grazing_category,
      .data$collapsed_grazing_category,
      name = "plot_count"
    ) |>
    dplyr::arrange(.data$collapsed_grazing_category, .data$original_grazing_category)

  gayini_write_csv(mapping, path)
  mapping
}


gayini_make_task15_context_figures <- function(root_dir,
                                               input_paths,
                                               figure_dir,
                                               report_dir) {
  source_script <- "R/gayini_plot_context_figures.R"
  manifest <- list()

  if (is.na(input_paths[["plot_context_flags_csv"]])) {
    return(list(
      manifest = gayini_task15_skip_row(
        root_dir,
        "P0.4-P0.6",
        "P0",
        "Plot context figures",
        source_script,
        "plot_context_flags_csv",
        "Context",
        "Plot context flags CSV was not found."
      ),
      metrics = list()
    ))
  }

  context <- gayini_task15_read_plot_context(input_paths[["plot_context_flags_csv"]])
  mapping <- gayini_task15_write_grazing_mapping(
    context,
    file.path(report_dir, "task15_grazing_category_mapping.csv")
  )

  total_plots <- dplyr::n_distinct(context$plot_id)
  interpretation_n <- dplyr::n_distinct(context$plot_id[context$interpretation_status == "Ground-cover interpretation"])
  flagged_n <- dplyr::n_distinct(context$plot_id[context$interpretation_status == "Treed / flagged"])

  veg_counts <- context |>
    dplyr::count(.data$simplified_vegetation_group, .data$interpretation_status, name = "n") |>
    dplyr::group_by(.data$simplified_vegetation_group) |>
    dplyr::mutate(total_n = sum(.data$n)) |>
    dplyr::ungroup() |>
    dplyr::mutate(
      vegetation_label = factor(
        .data$simplified_vegetation_group,
        levels = rev(unique(.data$simplified_vegetation_group[order(.data$total_n, .data$simplified_vegetation_group)]))
      ),
      label = paste0("n=", .data$n)
    )

  status_cols <- c(
    "Ground-cover interpretation" = "#2E8B57",
    "Treed / flagged" = "#9c6b30"
  )

  veg_plot <- ggplot2::ggplot(
    veg_counts,
    ggplot2::aes(x = .data$vegetation_label, y = .data$n, fill = .data$interpretation_status)
  ) +
    ggplot2::geom_col(width = 0.68, colour = "white", linewidth = 0.35) +
    ggplot2::geom_text(
      ggplot2::aes(label = .data$label),
      position = ggplot2::position_stack(vjust = 0.5),
      size = 3.7,
      colour = "white",
      fontface = "bold"
    ) +
    ggplot2::coord_flip() +
    ggplot2::scale_fill_manual(values = status_cols, drop = FALSE) +
    ggplot2::labs(
      title = "Plot context by vegetation group",
      subtitle = paste0(total_plots, " monitoring plots; ", interpretation_n, " ground-cover interpretation plots; ", flagged_n, " treed / flagged plots."),
      x = NULL,
      y = "Plot count",
      fill = "Interpretation status",
      caption = "Treed / flagged plots are retained for mapped context but excluded from ground-cover interpretation summaries."
    ) +
    gayini_theme_review(base_size = 13, legend_position = "bottom")

  veg_path <- file.path(figure_dir, "context", "P0_4_plot_context_vegetation_interpretation.png")
  gayini_save_review_figure(veg_path, veg_plot)

  manifest[[length(manifest) + 1L]] <- gayini_task15_manifest_row(
    root_dir = root_dir,
    figure_id = "P0.4",
    priority = "P0",
    figure_title = "Plot context: vegetation group and interpretation status",
    output_path = veg_path,
    source_script = source_script,
    source_data = gayini_relative_path(root_dir, input_paths[["plot_context_flags_csv"]]),
    deck_section = "Context",
    status = "created",
    caption_suggestion = "Monitoring plots grouped by simplified vegetation group and ground-cover interpretation status.",
    caveat_text = "Treed / flagged plots are shown for context but not silently included in ground-cover interpretation summaries.",
    qa_status = if (total_plots == 66 && interpretation_n == 57 && flagged_n == 9) "pass" else "warning",
    qa_notes = paste0("Counts recomputed: total=", total_plots, "; interpretation=", interpretation_n, "; treed/flagged=", flagged_n, ".")
  )

  grazing_counts <- context |>
    dplyr::filter(.data$collapsed_grazing_category %in% c("No grazing", "Any grazing")) |>
    dplyr::count(.data$collapsed_grazing_category, .data$interpretation_status, name = "n") |>
    dplyr::mutate(label = paste0("n=", .data$n))

  grazing_plot <- ggplot2::ggplot(
    grazing_counts,
    ggplot2::aes(x = .data$collapsed_grazing_category, y = .data$n, fill = .data$interpretation_status)
  ) +
    ggplot2::geom_col(width = 0.62, colour = "white", linewidth = 0.35) +
    ggplot2::geom_text(
      ggplot2::aes(label = .data$label),
      position = ggplot2::position_stack(vjust = 0.5),
      size = 4.0,
      colour = "white",
      fontface = "bold"
    ) +
    ggplot2::scale_fill_manual(values = status_cols, drop = FALSE) +
    ggplot2::labs(
      title = "Plot context by collapsed grazing category",
      subtitle = "Grazing categories are collapsed to Any grazing and No grazing for current review figures.",
      x = NULL,
      y = "Plot count",
      fill = "Interpretation status",
      caption = "Detailed grazing labels are retained only in the mapping table, not as separate review-figure groups."
    ) +
    gayini_theme_review(base_size = 13, legend_position = "bottom")

  grazing_count_path <- file.path(figure_dir, "context", "P0_5_plot_context_grazing_counts.png")
  gayini_save_review_figure(grazing_count_path, grazing_plot)

  manifest[[length(manifest) + 1L]] <- gayini_task15_manifest_row(
    root_dir = root_dir,
    figure_id = "P0.5",
    priority = "P0",
    figure_title = "Plot context: grazing and no-grazing counts",
    output_path = grazing_count_path,
    source_script = source_script,
    source_data = paste(
      gayini_relative_path(root_dir, input_paths[["plot_context_flags_csv"]]),
      "Output/reports/figure_refresh/task15_grazing_category_mapping.csv",
      sep = "; "
    ),
    deck_section = "Context",
    status = "created",
    caption_suggestion = "Monitoring plots grouped by collapsed grazing status and interpretation status.",
    caveat_text = "Grazing groups are descriptive only and may be confounded with vegetation group, hydrology, paddock context and site placement.",
    qa_status = if (all(unique(as.character(context$collapsed_grazing_category)) %in% c("No grazing", "Any grazing", "Unknown"))) "pass" else "warning",
    qa_notes = paste0("Collapsed category mapping rows: ", nrow(mapping), ".")
  )

  if (!is.na(input_paths[["plot_spatial_gpkg"]]) && !is.na(input_paths[["boundary_gpkg"]])) {
    plots_sf <- sf::st_read(input_paths[["plot_spatial_gpkg"]], quiet = TRUE) |>
      dplyr::left_join(
        context |>
          dplyr::select(
            "plot_id",
            "collapsed_grazing_category",
            "interpretation_status",
            "treed_plot_flag",
            "ground_cover_exclusion_flag"
          ),
        by = "plot_id"
      )
    boundary <- sf::st_read(input_paths[["boundary_gpkg"]], quiet = TRUE) |>
      sf::st_transform(sf::st_crs(plots_sf))
    plot_points <- suppressWarnings(sf::st_point_on_surface(plots_sf))

    grazing_map <- ggplot2::ggplot() +
      ggplot2::geom_sf(data = boundary, fill = "white", colour = "#2f2f2f", linewidth = 0.5) +
      ggplot2::geom_sf(
        data = plots_sf,
        fill = NA,
        colour = "#8f8f8f",
        linewidth = 0.18
      ) +
      ggplot2::geom_sf(
        data = plot_points,
        ggplot2::aes(
          fill = .data$collapsed_grazing_category,
          colour = .data$interpretation_status,
          shape = .data$interpretation_status
        ),
        size = 3.2,
        stroke = 0.8,
        alpha = 0.95
      ) +
      ggplot2::scale_fill_manual(
        values = gayini_grazing_palette()[c("No grazing", "Any grazing")],
        drop = TRUE,
        na.value = "#BDBDBD"
      ) +
      ggplot2::scale_colour_manual(values = c("Ground-cover interpretation" = "#404040", "Treed / flagged" = "#C0392B"), drop = FALSE) +
      ggplot2::scale_shape_manual(values = c("Ground-cover interpretation" = 21, "Treed / flagged" = 24), drop = FALSE) +
      ggplot2::labs(
        title = "Monitoring plot network by collapsed grazing category",
        subtitle = "Symbol fill shows grazing category; red triangle outlines identify treed / flagged plots retained for mapped context.",
        fill = "Grazing category",
        colour = "Interpretation status",
        shape = "Interpretation status",
        caption = "Grazing categories are descriptive only; they should not be read as causal treatment groups."
      ) +
      ggplot2::guides(
        fill = ggplot2::guide_legend(override.aes = list(shape = 21, colour = "#404040", size = 4)),
        colour = ggplot2::guide_legend(override.aes = list(fill = "white", size = 4)),
        shape = ggplot2::guide_legend(override.aes = list(fill = "white", size = 4))
      ) +
      gayini_theme_map(base_size = 12, legend_position = "bottom")

    grazing_map_path <- file.path(figure_dir, "context", "P0_6_plot_context_grazing_map.png")
    gayini_save_review_figure(grazing_map_path, grazing_map)

    manifest[[length(manifest) + 1L]] <- gayini_task15_manifest_row(
      root_dir = root_dir,
      figure_id = "P0.6",
      priority = "P0",
      figure_title = "Plot context: grazing and no-grazing map",
      output_path = grazing_map_path,
      source_script = source_script,
      source_data = paste(
        gayini_relative_path(root_dir, input_paths[["plot_context_flags_csv"]]),
        gayini_relative_path(root_dir, input_paths[["plot_spatial_gpkg"]]),
        gayini_relative_path(root_dir, input_paths[["boundary_gpkg"]]),
        sep = "; "
      ),
      deck_section = "Context",
      status = "created",
      caption_suggestion = "Map of the monitoring plot network by collapsed grazing status.",
      caveat_text = "Grazing groups are descriptive and may be confounded with vegetation group, hydrology and site placement.",
      qa_status = "pass",
      qa_notes = "White map background used; treed / flagged plots outlined separately."
    )
  } else {
    manifest[[length(manifest) + 1L]] <- gayini_task15_skip_row(
      root_dir,
      "P0.6",
      "P0",
      "Plot context: grazing and no-grazing map",
      source_script,
      paste(
        gayini_relative_path(root_dir, input_paths[["plot_context_flags_csv"]]),
        "plot_spatial_gpkg",
        "boundary_gpkg",
        sep = "; "
      ),
      "Context",
      "Plot spatial layer or boundary layer was not available."
    )
  }

  list(
    manifest = dplyr::bind_rows(manifest),
    metrics = list(
      total_plots = total_plots,
      interpretation_plots = interpretation_n,
      treed_flagged_plots = flagged_n
    )
  )
}
