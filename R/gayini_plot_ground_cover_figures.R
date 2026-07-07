## -----------------------------------------------------------------------------
## Gayini remote sensing workflow
## gayini_plot_ground_cover_figures.R
## -----------------------------------------------------------------------------

## Purpose:
## Task 15 ground-cover response figures for interpretation plots.


gayini_task15_read_ground_cover_interpretation <- function(path) {
  gc_raw <- readr::read_csv(path, show_col_types = FALSE)

  gc_raw |>
    dplyr::mutate(
      plot_id = as.character(.data$plot_id),
      simplified_vegetation_group = dplyr::coalesce(
        gayini_column(gc_raw, c("simplified_vegetation_group")),
        gayini_column(gc_raw, c("vegetation_adrian_group")),
        "Unknown"
      ),
      collapsed_grazing_category = gayini_collapse_grazing(
        dplyr::coalesce(
          gayini_column(gc_raw, c("collapsed_grazing_category"), default = NA_character_),
          gayini_column(gc_raw, c("original_grazing_treatment_category", "treatment"), default = NA_character_)
        )
      ),
      treed_plot_flag = as.logical(.data$treed_plot_flag),
      ground_cover_exclusion_flag = as.logical(.data$ground_cover_exclusion_flag)
    ) |>
    dplyr::filter(
      !dplyr::coalesce(.data$treed_plot_flag, FALSE),
      !dplyr::coalesce(.data$ground_cover_exclusion_flag, FALSE)
    )
}


gayini_task15_ground_cover_long <- function(gc_interp, group_col) {
  gc_interp |>
    dplyr::select(
      "plot_id",
      group = dplyr::all_of(group_col),
      "delta_total_veg_pct",
      "delta_bare_ground_pct",
      "post_minus_pre_inundation_frequency_pct_points"
    ) |>
    tidyr::pivot_longer(
      cols = c("delta_total_veg_pct", "delta_bare_ground_pct"),
      names_to = "metric",
      values_to = "delta_pct"
    ) |>
    dplyr::mutate(
      metric = dplyr::case_when(
        .data$metric == "delta_total_veg_pct" ~ "Total vegetation",
        .data$metric == "delta_bare_ground_pct" ~ "Bare ground",
        TRUE ~ .data$metric
      ),
      group = dplyr::if_else(is.na(.data$group) | !nzchar(as.character(.data$group)), "Unknown", as.character(.data$group))
    )
}


gayini_task15_ground_cover_group_plot <- function(gc_long,
                                                  title,
                                                  subtitle,
                                                  caption,
                                                  x_label = NULL) {
  summary <- gc_long |>
    dplyr::group_by(.data$group, .data$metric) |>
    dplyr::summarise(
      mean_delta = mean(.data$delta_pct, na.rm = TRUE),
      n = dplyr::n_distinct(.data$plot_id),
      mean_inundation_change = mean(.data$post_minus_pre_inundation_frequency_pct_points, na.rm = TRUE),
      .groups = "drop"
    )

  ordering <- summary |>
    dplyr::filter(.data$metric == "Total vegetation") |>
    dplyr::arrange(.data$mean_delta, .data$group) |>
    dplyr::pull(.data$group)

  gc_long <- gc_long |>
    dplyr::mutate(group_label = factor(.data$group, levels = ordering))
  summary <- summary |>
    dplyr::mutate(group_label = factor(.data$group, levels = ordering))

  label_data <- summary |>
    dplyr::group_by(.data$group, .data$group_label) |>
    dplyr::summarise(
      n = max(.data$n),
      mean_inundation_change = mean(.data$mean_inundation_change, na.rm = TRUE),
      .groups = "drop"
    )

  y_max <- max(c(summary$mean_delta, gc_long$delta_pct, 0), na.rm = TRUE)
  y_min <- min(c(summary$mean_delta, gc_long$delta_pct, 0), na.rm = TRUE)
  label_y <- y_max + max(1.5, 0.08 * (y_max - y_min))

  metric_cols <- c(
    "Total vegetation" = gayini_signal_palette()[["total_vegetation"]],
    "Bare ground" = gayini_signal_palette()[["bare_ground"]]
  )

  ggplot2::ggplot(summary, ggplot2::aes(x = .data$group_label, y = .data$mean_delta, fill = .data$metric)) +
    ggplot2::geom_hline(yintercept = 0, colour = "grey40", linewidth = 0.45) +
    ggplot2::geom_col(
      position = ggplot2::position_dodge(width = 0.72),
      width = 0.62,
      alpha = 0.92
    ) +
    ggplot2::geom_point(
      data = gc_long,
      ggplot2::aes(x = .data$group_label, y = .data$delta_pct, colour = .data$metric),
      inherit.aes = FALSE,
      position = ggplot2::position_jitterdodge(jitter.width = 0.10, dodge.width = 0.72),
      size = 1.4,
      alpha = 0.45
    ) +
    ggplot2::geom_text(
      data = label_data,
      ggplot2::aes(x = .data$group_label, y = label_y, label = paste0("n=", .data$n)),
      inherit.aes = FALSE,
      size = 3.4,
      fontface = "bold",
      colour = "grey25"
    ) +
    ggplot2::coord_flip(clip = "off") +
    ggplot2::scale_fill_manual(values = metric_cols, drop = FALSE) +
    ggplot2::scale_colour_manual(values = metric_cols, drop = FALSE) +
    ggplot2::labs(
      title = title,
      subtitle = subtitle,
      x = x_label,
      y = "Post-minus-pre ground-cover change (percentage points)",
      fill = "Metric",
      colour = "Metric",
      caption = caption
    ) +
    gayini_theme_review(base_size = 12, legend_position = "bottom") +
    ggplot2::theme(plot.margin = ggplot2::margin(14, 42, 14, 18))
}


gayini_make_task15_ground_cover_figures <- function(root_dir,
                                                    input_paths,
                                                    figure_dir) {
  source_script <- "R/gayini_plot_ground_cover_figures.R"

  if (is.na(input_paths[["ground_cover_interpretation_csv"]])) {
    return(list(
      manifest = dplyr::bind_rows(
        gayini_task15_skip_row(root_dir, "P0.8", "P0", "Ground-cover change by vegetation group", source_script, "ground_cover_interpretation_csv", "Ground cover", "Ground-cover interpretation table was not found."),
        gayini_task15_skip_row(root_dir, "P0.9", "P0", "Ground-cover change by grazing / no grazing", source_script, "ground_cover_interpretation_csv", "Ground cover", "Ground-cover interpretation table was not found.")
      ),
      metrics = list()
    ))
  }

  gc_interp <- gayini_task15_read_ground_cover_interpretation(input_paths[["ground_cover_interpretation_csv"]])
  n_interp <- dplyr::n_distinct(gc_interp$plot_id)
  mean_total_veg_change <- mean(gc_interp$delta_total_veg_pct, na.rm = TRUE)

  veg_long <- gayini_task15_ground_cover_long(gc_interp, "simplified_vegetation_group")
  veg_plot <- gayini_task15_ground_cover_group_plot(
    veg_long,
    title = "Ground-cover change by vegetation group",
    subtitle = paste0(n_interp, " non-treed interpretation plots; bars are group means and points are plots."),
    caption = "Descriptive review figure only. Responses are modest, variable and community-dependent; annual occurrence change is context, not causal proof.",
    x_label = NULL
  )
  veg_path <- file.path(figure_dir, "ground_cover", "P0_8_ground_cover_change_by_vegetation_group.png")
  gayini_save_review_figure(veg_path, veg_plot)

  grazing_long <- gayini_task15_ground_cover_long(gc_interp, "collapsed_grazing_category") |>
    dplyr::filter(.data$group %in% c("No grazing", "Any grazing"))
  grazing_plot <- gayini_task15_ground_cover_group_plot(
    grazing_long,
    title = "Ground-cover change by collapsed grazing category",
    subtitle = paste0(n_interp, " non-treed interpretation plots; grazing categories collapsed to Any grazing and No grazing."),
    caption = "Descriptive review figure only. Grazing groups may be confounded with vegetation group, hydrology, paddock context and site placement.",
    x_label = NULL
  )
  grazing_path <- file.path(figure_dir, "ground_cover", "P0_9_ground_cover_change_by_grazing.png")
  gayini_save_review_figure(grazing_path, grazing_plot)

  manifest <- dplyr::bind_rows(
    gayini_task15_manifest_row(
      root_dir,
      "P0.8",
      "P0",
      "Ground-cover change by vegetation group",
      veg_path,
      source_script,
      gayini_relative_path(root_dir, input_paths[["ground_cover_interpretation_csv"]]),
      "Ground cover",
      status = "created",
      caption_suggestion = "Post-minus-pre total vegetation and bare ground change by vegetation group for non-treed interpretation plots.",
      caveat_text = "Descriptive review figure only; responses are modest, variable and community-dependent, and annual occurrence change is not causal proof.",
      qa_status = if (n_interp == 57) "pass" else "warning",
      qa_notes = paste0("Non-treed interpretation plots used: ", n_interp, ".")
    ),
    gayini_task15_manifest_row(
      root_dir,
      "P0.9",
      "P0",
      "Ground-cover change by grazing / no grazing",
      grazing_path,
      source_script,
      gayini_relative_path(root_dir, input_paths[["ground_cover_interpretation_csv"]]),
      "Ground cover",
      status = "created",
      caption_suggestion = "Post-minus-pre total vegetation and bare ground change by collapsed grazing category.",
      caveat_text = "Grazing categories are descriptive and may be confounded with vegetation group, hydrology, paddock context and site placement.",
      qa_status = if (all(unique(grazing_long$group) %in% c("No grazing", "Any grazing"))) "pass" else "warning",
      qa_notes = paste0("Non-treed interpretation plots used: ", n_interp, "; categories shown: ", paste(sort(unique(grazing_long$group)), collapse = ", "), ".")
    )
  )

  list(
    manifest = manifest,
    metrics = list(
      ground_cover_interpretation_plots = n_interp,
      mean_total_vegetation_change = mean_total_veg_change
    )
  )
}
