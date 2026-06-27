## -----------------------------------------------------------------------------
## Gayini remote sensing workflow
## 10b_ground_cover_prepost_figures.R
## -----------------------------------------------------------------------------


## Purpose:
## Create presentation-ready Step 10b ground-cover pre/post figures from existing
## 10a and curated CSV outputs only. This script does not do raster processing.


## User settings ----


root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", "D:/Github_repos/Gayini"), winslash = "/", mustWork = TRUE)
FIGURE_WIDTH <- 12
FIGURE_HEIGHT <- 7.2
FIGURE_DPI <- 300
N_NOTABLE_LABELS <- 10L
N_SIMPLE_LABELS <- 5L
TOP_BOTTOM_N <- 15L
STRONG_TOTAL_VEG_DELTA_PCT <- 10
STRONG_BARE_DELTA_PCT <- 10
WETTER_POST_THRESHOLD_PCT_POINTS <- 5
INCLUDE_SECONDARY_TREATMENT_FIGURE <- TRUE
SCATTER_SMOOTHER <- "lm"
NEAR_ZERO_INUNDATION_POINTS <- 3


## Required packages ----


required_packages <- c(
  "dplyr",
  "tidyr",
  "readr",
  "stringr",
  "ggplot2",
  "magrittr",
  "tibble",
  "scales"
)

source(file.path(root_dir, "R", "gayini_analysis_base_functions.R"))
gayini_check_packages(required_packages)

library(dplyr)
library(tidyr)
library(readr)
library(stringr)
library(ggplot2)
library(magrittr)
library(tibble)
library(scales)

use_ggrepel <- requireNamespace("ggrepel", quietly = TRUE)

if (!use_ggrepel) {
  message("Package ggrepel is not available; using ggplot2::geom_text(check_overlap = TRUE) for plot labels.")
}


## Paths ----


csv_dir <- file.path(root_dir, "Output", "csv")
figure_dir <- file.path(root_dir, "Output", "figures", "10b_ground_cover_prepost_figures")
diagnostics_dir <- file.path(root_dir, "Output", "diagnostics", "10b_ground_cover_prepost_figures")

dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(diagnostics_dir, recursive = TRUE, showWarnings = FALSE)

plot_summary_path <- file.path(csv_dir, "10a_ground_cover_prepost_plot_summary.csv")
group_summary_path <- file.path(csv_dir, "10a_ground_cover_prepost_group_summary.csv")
model_summary_path <- file.path(csv_dir, "10a_ground_cover_prepost_model_summary.csv")
ground_cover_path <- file.path(csv_dir, "curated_ground_cover_timeseries.csv")
plot_base_path <- file.path(csv_dir, "plot_rs_analysis_base.csv")

figure_index_path <- file.path(diagnostics_dir, "10b_figure_index.csv")
handoff_report_path <- file.path(diagnostics_dir, "10b_codex_handoff_report.md")

input_paths <- c(
  plot_summary = plot_summary_path,
  group_summary = group_summary_path,
  model_summary = model_summary_path,
  curated_ground_cover_timeseries = ground_cover_path,
  plot_rs_analysis_base = plot_base_path
)

missing_inputs <- names(input_paths)[!file.exists(input_paths)]

if (length(missing_inputs) > 0) {
  stop(
    "Missing required input(s): ",
    paste(missing_inputs, collapse = ", "),
    call. = FALSE
  )
}


## Helpers ----


require_columns <- function(df, required_cols, object_name) {
  missing_cols <- setdiff(required_cols, names(df))

  if (length(missing_cols) > 0) {
    stop(
      object_name, " is missing required column(s): ",
      paste(missing_cols, collapse = ", "),
      call. = FALSE
    )
  }

  invisible(TRUE)
}


theme_gayini_chart <- function(base_size = 12) {
  ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      plot.title = ggplot2::element_text(face = "bold", size = base_size + 4),
      plot.subtitle = ggplot2::element_text(size = base_size),
      axis.title = ggplot2::element_text(face = "bold"),
      axis.text.x = ggplot2::element_text(angle = 45, hjust = 1),
      legend.position = "bottom",
      legend.title = ggplot2::element_text(face = "bold"),
      strip.text = ggplot2::element_text(face = "bold")
    )
}


theme_scatter_chart <- function(base_size = 12) {
  theme_gayini_chart(base_size = base_size) +
    ggplot2::theme(
      legend.position = "right",
      legend.box = "vertical",
      axis.text.x = ggplot2::element_text(angle = 0, hjust = 0.5)
    )
}


save_figure <- function(plot,
                        figure_id,
                        file_name,
                        title,
                        source_data,
                        role,
                        notes,
                        main_deck_candidate = FALSE,
                        width = FIGURE_WIDTH,
                        height = FIGURE_HEIGHT) {
  path <- file.path(figure_dir, file_name)

  ggplot2::ggsave(
    filename = path,
    plot = plot,
    width = width,
    height = height,
    dpi = FIGURE_DPI
  )

  message("Wrote: ", path)

  tibble::tibble(
    figure_id = figure_id,
    title = title,
    file_name = file_name,
    path = path,
    source_data = source_data,
    role = role,
    main_deck_candidate = main_deck_candidate,
    notes = notes
  )
}


change_class_label <- function(x) {
  dplyr::case_when(
    x == "much_wetter_post" ~ "Much wetter post",
    x == "wetter_post" ~ "Wetter post",
    x == "similar_frequency" ~ "Similar frequency",
    x == "drier_post" ~ "Drier post",
    x == "much_drier_post" ~ "Much drier post",
    x == "no_comparison" ~ "No comparison",
    TRUE ~ stringr::str_replace_all(x, "_", " ")
  )
}


metric_label <- function(x) {
  dplyr::case_when(
    x == "total_veg_pct" ~ "Total vegetation",
    x == "bare_ground_pct" ~ "Bare ground",
    x == "delta_total_veg_pct" ~ "Delta total vegetation",
    x == "delta_bare_ground_pct" ~ "Delta bare ground",
    TRUE ~ x
  )
}


make_notable_labels <- function(df, response_col, threshold) {
  response_values <- df[[response_col]]

  df %>%
    dplyr::mutate(
      abs_response = abs(response_values),
      abs_inundation_change = abs(.data$post_minus_pre_inundation_frequency_pct_points),
      notable = abs_response >= threshold |
        .data$wetter_post_and_greener |
        .data$wetter_post_and_barer |
        .data$rarely_inundated
    ) %>%
    dplyr::filter(.data$notable) %>%
    dplyr::filter(.data$abs_response >= threshold | .data$abs_inundation_change >= NEAR_ZERO_INUNDATION_POINTS) %>%
    dplyr::arrange(dplyr::desc(.data$notable), dplyr::desc(.data$abs_response)) %>%
    dplyr::slice_head(n = N_NOTABLE_LABELS) %>%
    dplyr::mutate(label = .data$plot_id)
}


make_simple_labels <- function(df, response_col, threshold) {
  response_values <- df[[response_col]]

  df %>%
    dplyr::mutate(
      abs_response = abs(response_values),
      abs_inundation_change = abs(.data$post_minus_pre_inundation_frequency_pct_points),
      notable = abs_response >= threshold |
        .data$wetter_post_and_greener |
        .data$wetter_post_and_barer
    ) %>%
    dplyr::filter(.data$notable) %>%
    dplyr::filter(.data$abs_response >= threshold | .data$abs_inundation_change >= NEAR_ZERO_INUNDATION_POINTS) %>%
    dplyr::arrange(dplyr::desc(.data$abs_response), dplyr::desc(.data$abs_inundation_change)) %>%
    dplyr::slice_head(n = N_SIMPLE_LABELS) %>%
    dplyr::mutate(label = .data$plot_id)
}


add_plot_labels <- function(plot,
                            label_data,
                            x_col,
                            y_col,
                            label_size = 3.0) {
  if (nrow(label_data) == 0) {
    return(plot)
  }

  if (use_ggrepel) {
    return(
      plot +
        ggrepel::geom_text_repel(
          data = label_data,
          ggplot2::aes(x = .data[[x_col]], y = .data[[y_col]], label = .data$label),
          inherit.aes = FALSE,
          size = label_size,
          seed = 42,
          max.overlaps = Inf,
          box.padding = 0.35,
          point.padding = 0.25,
          min.segment.length = 0,
          segment.colour = "grey55",
          show.legend = FALSE
        )
    )
  }

  plot +
    ggplot2::geom_text(
      data = label_data,
      ggplot2::aes(x = .data[[x_col]], y = .data[[y_col]], label = .data$label),
      inherit.aes = FALSE,
      size = label_size,
      vjust = -0.85,
      check_overlap = TRUE,
      show.legend = FALSE
    )
}


make_top_bottom_rank_data <- function(df, delta_col, n_each = TOP_BOTTOM_N) {
  low <- df %>%
    dplyr::arrange(.data[[delta_col]]) %>%
    dplyr::slice_head(n = n_each)

  high <- df %>%
    dplyr::arrange(dplyr::desc(.data[[delta_col]])) %>%
    dplyr::slice_head(n = n_each)

  dplyr::bind_rows(low, high) %>%
    dplyr::distinct(.data$plot_id, .keep_all = TRUE) %>%
    dplyr::arrange(.data[[delta_col]]) %>%
    dplyr::mutate(plot_id_ranked = factor(.data$plot_id, levels = .data$plot_id))
}


write_handoff_report <- function(figure_index,
                                 plot_summary,
                                 model_summary,
                                 report_path) {
  primary_model_rows <- model_summary %>%
    dplyr::filter(.data$model_role == "primary_screening", .data$model_status == "run")

  secondary_model_rows <- model_summary %>%
    dplyr::filter(.data$model_role == "secondary_treatment_sanity_check", .data$model_status == "run")

  report_lines <- c(
    "# 10b Ground-Cover Pre/Post Figures Handoff Report",
    "",
    paste0("Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
    "",
    "## Scope",
    "",
    "Step 10b creates descriptive ground-cover pre/post figures from existing 10a and curated CSV outputs only. No raster processing is run.",
    "",
    "## Inputs",
    "",
    paste0("- `", input_paths, "`"),
    "",
    "## Figures Written",
    "",
    paste0("- `", figure_index$file_name, "`: ", figure_index$title, " [", figure_index$role, "]"),
    "",
    "## Recommended Main-Deck Shortlist",
    "",
    paste0("- `", figure_index$file_name[figure_index$main_deck_candidate], "`: ", figure_index$title[figure_index$main_deck_candidate]),
    "",
    "## Status",
    "",
    paste0("- Figures written: ", nrow(figure_index)),
    paste0("- Plot summary rows used: ", nrow(plot_summary)),
    paste0("- Primary screening model coefficient rows available: ", nrow(primary_model_rows)),
    paste0("- Secondary treatment sanity-check model coefficient rows available: ", nrow(secondary_model_rows)),
    "",
    "## Interpretation Cautions",
    "",
    "- Figures are descriptive screening outputs, not proof of causality.",
    "- Inundation change is annual occurrence frequency change in percentage points.",
    "- Ground-cover estimates may be uncertain in treed or woody plots.",
    "- Treatment is kept as metadata and appears only as a secondary sanity-check figure.",
    "",
    "## Recommended Next Task",
    "",
    "Review these figures for presentation candidates, then build a concise Step 10 figure shortlist and inspect lag diagnostics before any BFAST/tbreak decision."
  )

  readr::write_lines(report_lines, report_path)
  message("Wrote: ", report_path)

  invisible(report_lines)
}


## Read inputs ----


message("Reading plot summary: ", plot_summary_path)
plot_summary <- readr::read_csv(plot_summary_path, show_col_types = FALSE) %>%
  gayini_standardise_plot_id(object_name = "10a plot summary")

message("Reading group summary: ", group_summary_path)
group_summary <- readr::read_csv(group_summary_path, show_col_types = FALSE)

message("Reading model summary: ", model_summary_path)
model_summary <- readr::read_csv(model_summary_path, show_col_types = FALSE)

message("Reading curated ground cover: ", ground_cover_path)
ground_cover <- readr::read_csv(ground_cover_path, show_col_types = FALSE) %>%
  gayini_standardise_plot_id(object_name = "curated ground-cover timeseries")

message("Reading plot analysis base: ", plot_base_path)
plot_base <- readr::read_csv(plot_base_path, show_col_types = FALSE) %>%
  gayini_standardise_plot_id(object_name = "plot analysis base")

require_columns(
  plot_summary,
  c(
    "plot_id",
    "treatment",
    "vegetation_adrian_group",
    "inundation_change_class",
    "pre_conservation_inundation_frequency_pct",
    "post_conservation_inundation_frequency_pct",
    "post_minus_pre_inundation_frequency_pct_points",
    "pre_mean_total_veg_pct",
    "post_mean_total_veg_pct",
    "delta_total_veg_pct",
    "pre_mean_bare_ground_pct",
    "post_mean_bare_ground_pct",
    "delta_bare_ground_pct",
    "wetter_post_and_greener",
    "wetter_post_and_barer",
    "rarely_inundated"
  ),
  "10a plot summary"
)

require_columns(
  ground_cover,
  c("plot_id", "date_midpoint", "period", "total_veg_pct", "bare_ground_pct", "vegetation_adrian_group"),
  "curated ground-cover timeseries"
)

require_columns(
  group_summary,
  c("group_type", "group_label", "n_plots", "mean_delta_total_veg_pct", "mean_delta_bare_ground_pct"),
  "10a group summary"
)

plot_summary <- plot_summary %>%
  dplyr::mutate(
    inundation_change_label = change_class_label(.data$inundation_change_class),
    vegetation_adrian_group = stringr::str_wrap(.data$vegetation_adrian_group, width = 26),
    treatment = stringr::str_wrap(.data$treatment, width = 18)
  )

ground_cover <- ground_cover %>%
  dplyr::mutate(
    date_midpoint = as.Date(.data$date_midpoint),
    period_label = dplyr::case_when(
      .data$period == "pre_conservation" ~ "Pre-conservation",
      .data$period == "post_conservation" ~ "Post-conservation",
      TRUE ~ "Outside analysis window"
    )
  )


## Figure 1: full plot-set pre/post summary ----


prepost_long <- plot_summary %>%
  dplyr::select(
    "plot_id",
    "pre_mean_total_veg_pct",
    "post_mean_total_veg_pct",
    "pre_mean_bare_ground_pct",
    "post_mean_bare_ground_pct"
  ) %>%
  tidyr::pivot_longer(
    cols = -"plot_id",
    names_to = "metric_period",
    values_to = "cover_pct"
  ) %>%
  dplyr::mutate(
    period = dplyr::case_when(
      stringr::str_starts(.data$metric_period, "pre_") ~ "Pre-conservation",
      stringr::str_starts(.data$metric_period, "post_") ~ "Post-conservation",
      TRUE ~ NA_character_
    ),
    metric = dplyr::case_when(
      stringr::str_detect(.data$metric_period, "total_veg") ~ "Total vegetation",
      stringr::str_detect(.data$metric_period, "bare_ground") ~ "Bare ground",
      TRUE ~ NA_character_
    ),
    period = factor(.data$period, levels = c("Pre-conservation", "Post-conservation")),
    metric = factor(.data$metric, levels = c("Total vegetation", "Bare ground"))
  )

fig1 <- ggplot2::ggplot(prepost_long, ggplot2::aes(x = .data$period, y = .data$cover_pct)) +
  ggplot2::geom_line(ggplot2::aes(group = .data$plot_id), colour = "grey70", alpha = 0.45, linewidth = 0.35) +
  ggplot2::geom_point(ggplot2::aes(colour = .data$period), alpha = 0.75, size = 1.8, position = ggplot2::position_jitter(width = 0.06, height = 0)) +
  ggplot2::stat_summary(fun = median, geom = "point", shape = 23, size = 4.2, fill = "white", colour = "black") +
  ggplot2::facet_wrap(~ metric, nrow = 1) +
  ggplot2::coord_cartesian(ylim = c(0, 100)) +
  ggplot2::scale_colour_manual(values = c("Pre-conservation" = "#4c78a8", "Post-conservation" = "#59a14f")) +
  ggplot2::labs(
    title = "Ground cover before and after conservation-management change",
    subtitle = "Each line is one plot; diamond markers show the median across plots.",
    x = NULL,
    y = "Cover (%)",
    colour = "Period",
    caption = "Total vegetation = green/PV + non-green/NPV. Bare ground = TERN/JRSRP band 1."
  ) +
  theme_gayini_chart()


## Figure 2: ranked total vegetation change ----


rank_total <- plot_summary %>%
  dplyr::arrange(.data$delta_total_veg_pct) %>%
  dplyr::mutate(plot_id_ranked = factor(.data$plot_id, levels = .data$plot_id))

fig2 <- ggplot2::ggplot(rank_total, ggplot2::aes(x = .data$plot_id_ranked, y = .data$delta_total_veg_pct)) +
  ggplot2::geom_hline(yintercept = 0, colour = "grey30", linewidth = 0.4) +
  ggplot2::geom_col(ggplot2::aes(fill = .data$inundation_change_label), width = 0.78) +
  ggplot2::coord_flip() +
  ggplot2::scale_fill_brewer(palette = "Set2", na.value = "grey70") +
  ggplot2::labs(
    title = "Ranked plot change in total vegetation",
    subtitle = "Post mean minus pre mean; positive values indicate greener plots after the management-change date.",
    x = "Plot",
    y = "Delta total vegetation (percentage points)",
    fill = "Inundation change",
    caption = "Ground-cover response is descriptive screening, not proof of causality."
  ) +
  theme_gayini_chart(base_size = 10) +
  ggplot2::theme(axis.text.y = ggplot2::element_text(size = 6.2))

rank_total_top_bottom <- make_top_bottom_rank_data(
  plot_summary,
  delta_col = "delta_total_veg_pct",
  n_each = TOP_BOTTOM_N
)

fig2a <- ggplot2::ggplot(rank_total_top_bottom, ggplot2::aes(x = .data$plot_id_ranked, y = .data$delta_total_veg_pct)) +
  ggplot2::geom_hline(yintercept = 0, colour = "grey30", linewidth = 0.4) +
  ggplot2::geom_col(ggplot2::aes(fill = .data$inundation_change_label), width = 0.74) +
  ggplot2::coord_flip() +
  ggplot2::scale_fill_brewer(palette = "Set2", na.value = "grey70") +
  ggplot2::labs(
    title = "Largest plot changes in total vegetation",
    subtitle = paste0("Top and bottom ", TOP_BOTTOM_N, " plots by post-minus-pre change."),
    x = "Plot",
    y = "Delta total vegetation (percentage points)",
    fill = "Inundation change",
    caption = "Positive values indicate more total vegetation after conservation-management change."
  ) +
  theme_gayini_chart(base_size = 11) +
  ggplot2::guides(fill = ggplot2::guide_legend(nrow = 2, byrow = TRUE)) +
  ggplot2::theme(axis.text.y = ggplot2::element_text(size = 8.0))


## Figure 3: ranked bare ground change ----


rank_bare <- plot_summary %>%
  dplyr::arrange(.data$delta_bare_ground_pct) %>%
  dplyr::mutate(plot_id_ranked = factor(.data$plot_id, levels = .data$plot_id))

fig3 <- ggplot2::ggplot(rank_bare, ggplot2::aes(x = .data$plot_id_ranked, y = .data$delta_bare_ground_pct)) +
  ggplot2::geom_hline(yintercept = 0, colour = "grey30", linewidth = 0.4) +
  ggplot2::geom_col(ggplot2::aes(fill = .data$inundation_change_label), width = 0.78) +
  ggplot2::coord_flip() +
  ggplot2::scale_fill_brewer(palette = "Set2", na.value = "grey70") +
  ggplot2::labs(
    title = "Ranked plot change in bare ground",
    subtitle = "Post mean minus pre mean; positive values indicate more bare ground after the management-change date.",
    x = "Plot",
    y = "Delta bare ground (percentage points)",
    fill = "Inundation change",
    caption = "Bare ground = TERN/JRSRP band 1."
  ) +
  theme_gayini_chart(base_size = 10) +
  ggplot2::theme(axis.text.y = ggplot2::element_text(size = 6.2))

rank_bare_top_bottom <- make_top_bottom_rank_data(
  plot_summary,
  delta_col = "delta_bare_ground_pct",
  n_each = TOP_BOTTOM_N
)

fig3a <- ggplot2::ggplot(rank_bare_top_bottom, ggplot2::aes(x = .data$plot_id_ranked, y = .data$delta_bare_ground_pct)) +
  ggplot2::geom_hline(yintercept = 0, colour = "grey30", linewidth = 0.4) +
  ggplot2::geom_col(ggplot2::aes(fill = .data$inundation_change_label), width = 0.74) +
  ggplot2::coord_flip() +
  ggplot2::scale_fill_brewer(palette = "Set2", na.value = "grey70") +
  ggplot2::labs(
    title = "Largest plot changes in bare ground",
    subtitle = paste0("Top and bottom ", TOP_BOTTOM_N, " plots by post-minus-pre change."),
    x = "Plot",
    y = "Delta bare ground (percentage points)",
    fill = "Inundation change",
    caption = "Positive values indicate more bare ground after conservation-management change."
  ) +
  theme_gayini_chart(base_size = 11) +
  ggplot2::guides(fill = ggplot2::guide_legend(nrow = 2, byrow = TRUE)) +
  ggplot2::theme(axis.text.y = ggplot2::element_text(size = 8.0))


## Figure 4: inundation change vs total vegetation change ----


labels_total <- make_notable_labels(
  plot_summary,
  response_col = "delta_total_veg_pct",
  threshold = STRONG_TOTAL_VEG_DELTA_PCT
)

fig4 <- ggplot2::ggplot(
  plot_summary,
  ggplot2::aes(
    x = .data$post_minus_pre_inundation_frequency_pct_points,
    y = .data$delta_total_veg_pct
  )
) +
  ggplot2::geom_hline(yintercept = 0, colour = "grey45", linewidth = 0.35) +
  ggplot2::geom_vline(xintercept = 0, colour = "grey45", linewidth = 0.35) +
  ggplot2::geom_smooth(method = SCATTER_SMOOTHER, se = TRUE, colour = "#3a6ea5", fill = "#b9d6f2", linewidth = 0.8) +
  ggplot2::geom_point(ggplot2::aes(colour = .data$vegetation_adrian_group, shape = .data$inundation_change_label), size = 2.7, alpha = 0.9) +
  ggplot2::labs(
    title = "Inundation change and total vegetation response",
    subtitle = "Linear trend is descriptive; labelled plots are large-response or review-flagged plots.",
    x = "Post minus pre inundation frequency (percentage points)",
    y = "Delta total vegetation (percentage points)",
    colour = "Vegetation group",
    shape = "Inundation change",
    caption = "Inundation frequency is annual occurrence frequency, not hydroperiod or duration."
  ) +
  theme_scatter_chart() +
  ggplot2::guides(
    colour = ggplot2::guide_legend(ncol = 1),
    shape = ggplot2::guide_legend(ncol = 1)
  )

fig4 <- add_plot_labels(
  fig4,
  labels_total,
  x_col = "post_minus_pre_inundation_frequency_pct_points",
  y_col = "delta_total_veg_pct",
  label_size = 3.0
)


## Figure 5: inundation change vs bare ground change ----


labels_bare <- make_notable_labels(
  plot_summary,
  response_col = "delta_bare_ground_pct",
  threshold = STRONG_BARE_DELTA_PCT
)

fig5 <- ggplot2::ggplot(
  plot_summary,
  ggplot2::aes(
    x = .data$post_minus_pre_inundation_frequency_pct_points,
    y = .data$delta_bare_ground_pct
  )
) +
  ggplot2::geom_hline(yintercept = 0, colour = "grey45", linewidth = 0.35) +
  ggplot2::geom_vline(xintercept = 0, colour = "grey45", linewidth = 0.35) +
  ggplot2::geom_smooth(method = SCATTER_SMOOTHER, se = TRUE, colour = "#8c6d31", fill = "#dfc27d", linewidth = 0.8) +
  ggplot2::geom_point(ggplot2::aes(colour = .data$vegetation_adrian_group, shape = .data$inundation_change_label), size = 2.7, alpha = 0.9) +
  ggplot2::labs(
    title = "Inundation change and bare ground response",
    subtitle = "Linear trend is descriptive; labelled plots are large-response or review-flagged plots.",
    x = "Post minus pre inundation frequency (percentage points)",
    y = "Delta bare ground (percentage points)",
    colour = "Vegetation group",
    shape = "Inundation change",
    caption = "Positive bare-ground change means more bare ground post-conservation."
  ) +
  theme_scatter_chart() +
  ggplot2::guides(
    colour = ggplot2::guide_legend(ncol = 1),
    shape = ggplot2::guide_legend(ncol = 1)
  )

fig5 <- add_plot_labels(
  fig5,
  labels_bare,
  x_col = "post_minus_pre_inundation_frequency_pct_points",
  y_col = "delta_bare_ground_pct",
  label_size = 3.0
)


## Figures 4a and 5a: simplified main-deck scatters ----


simple_labels_total <- make_simple_labels(
  plot_summary,
  response_col = "delta_total_veg_pct",
  threshold = STRONG_TOTAL_VEG_DELTA_PCT
)

fig4a <- ggplot2::ggplot(
  plot_summary,
  ggplot2::aes(
    x = .data$post_minus_pre_inundation_frequency_pct_points,
    y = .data$delta_total_veg_pct
  )
) +
  ggplot2::geom_hline(yintercept = 0, colour = "grey45", linewidth = 0.35) +
  ggplot2::geom_vline(xintercept = 0, colour = "grey45", linewidth = 0.35) +
  ggplot2::geom_smooth(method = "lm", se = TRUE, colour = "#3a6ea5", fill = "#cfe3f5", linewidth = 0.9) +
  ggplot2::geom_point(fill = "#59a14f", colour = "grey20", shape = 21, size = 3.0, alpha = 0.88) +
  ggplot2::labs(
    title = "Inundation change and total vegetation response",
    subtitle = "Each point is one plot; line is a descriptive linear trend.",
    x = "Post minus pre inundation frequency (percentage points)",
    y = "Delta total vegetation (percentage points)",
    caption = "Descriptive screening only; inundation frequency is annual occurrence frequency."
  ) +
  theme_gayini_chart(base_size = 13) +
  ggplot2::theme(
    legend.position = "none",
    axis.text.x = ggplot2::element_text(angle = 0, hjust = 0.5)
  )

fig4a <- add_plot_labels(
  fig4a,
  simple_labels_total,
  x_col = "post_minus_pre_inundation_frequency_pct_points",
  y_col = "delta_total_veg_pct",
  label_size = 3.2
)

simple_labels_bare <- make_simple_labels(
  plot_summary,
  response_col = "delta_bare_ground_pct",
  threshold = STRONG_BARE_DELTA_PCT
)

fig5a <- ggplot2::ggplot(
  plot_summary,
  ggplot2::aes(
    x = .data$post_minus_pre_inundation_frequency_pct_points,
    y = .data$delta_bare_ground_pct
  )
) +
  ggplot2::geom_hline(yintercept = 0, colour = "grey45", linewidth = 0.35) +
  ggplot2::geom_vline(xintercept = 0, colour = "grey45", linewidth = 0.35) +
  ggplot2::geom_smooth(method = "lm", se = TRUE, colour = "#8c6d31", fill = "#ead9a8", linewidth = 0.9) +
  ggplot2::geom_point(fill = "#b07d3c", colour = "grey20", shape = 21, size = 3.0, alpha = 0.88) +
  ggplot2::labs(
    title = "Inundation change and bare ground response",
    subtitle = "Each point is one plot; line is a descriptive linear trend.",
    x = "Post minus pre inundation frequency (percentage points)",
    y = "Delta bare ground (percentage points)",
    caption = "Positive values mean more bare ground after conservation-management change."
  ) +
  theme_gayini_chart(base_size = 13) +
  ggplot2::theme(
    legend.position = "none",
    axis.text.x = ggplot2::element_text(angle = 0, hjust = 0.5)
  )

fig5a <- add_plot_labels(
  fig5a,
  simple_labels_bare,
  x_col = "post_minus_pre_inundation_frequency_pct_points",
  y_col = "delta_bare_ground_pct",
  label_size = 3.2
)


## Figure 6: grouped summary by vegetation and inundation change ----


primary_group_summary <- group_summary %>%
  dplyr::filter(.data$group_type == "primary_vegetation_by_inundation_change") %>%
  dplyr::mutate(
    vegetation_adrian_group = stringr::str_wrap(.data$vegetation_adrian_group, width = 24),
    inundation_change_label = change_class_label(.data$inundation_change_class)
  ) %>%
  dplyr::select(
    "vegetation_adrian_group",
    "inundation_change_label",
    "n_plots",
    "mean_delta_total_veg_pct",
    "mean_delta_bare_ground_pct"
  ) %>%
  tidyr::pivot_longer(
    cols = c("mean_delta_total_veg_pct", "mean_delta_bare_ground_pct"),
    names_to = "metric",
    values_to = "mean_delta_pct"
  ) %>%
  dplyr::mutate(
    metric = metric_label(stringr::str_remove(.data$metric, "^mean_"))
  )

fig6 <- ggplot2::ggplot(
  primary_group_summary,
  ggplot2::aes(x = .data$inundation_change_label, y = .data$mean_delta_pct, fill = .data$metric)
) +
  ggplot2::geom_hline(yintercept = 0, colour = "grey35", linewidth = 0.35) +
  ggplot2::geom_col(position = ggplot2::position_dodge(width = 0.72), width = 0.64) +
  ggplot2::geom_text(
    ggplot2::aes(label = paste0("n=", .data$n_plots), group = .data$metric),
    position = ggplot2::position_dodge(width = 0.72),
    vjust = -0.45,
    size = 2.8,
    colour = "grey20"
  ) +
  ggplot2::facet_wrap(~ vegetation_adrian_group, scales = "free_x") +
  ggplot2::scale_fill_manual(values = c("Delta total vegetation" = "#59a14f", "Delta bare ground" = "#b07d3c")) +
  ggplot2::labs(
    title = "Ground-cover response by vegetation group and inundation change class",
    subtitle = "Bars show group mean post-minus-pre change; labels show number of plots.",
    x = "Inundation change class",
    y = "Mean change (percentage points)",
    fill = "Metric",
    caption = "Group summaries are descriptive and may be unstable where n is small."
  ) +
  theme_gayini_chart(base_size = 10) +
  ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 35, hjust = 1))


## Figure 7: secondary treatment sanity check ----


if (INCLUDE_SECONDARY_TREATMENT_FIGURE) {
  treatment_long <- plot_summary %>%
    dplyr::select("plot_id", "treatment", "delta_total_veg_pct", "delta_bare_ground_pct") %>%
    tidyr::pivot_longer(
      cols = c("delta_total_veg_pct", "delta_bare_ground_pct"),
      names_to = "metric",
      values_to = "delta_pct"
    ) %>%
    dplyr::mutate(metric = metric_label(.data$metric))

  fig7 <- ggplot2::ggplot(treatment_long, ggplot2::aes(x = .data$treatment, y = .data$delta_pct)) +
    ggplot2::geom_hline(yintercept = 0, colour = "grey40", linewidth = 0.35) +
    ggplot2::geom_boxplot(fill = "grey88", colour = "grey25", outlier.shape = NA, width = 0.55) +
    ggplot2::geom_point(ggplot2::aes(colour = .data$metric), position = ggplot2::position_jitter(width = 0.12, height = 0), size = 2.0, alpha = 0.8) +
    ggplot2::facet_wrap(~ metric, nrow = 1) +
    ggplot2::scale_colour_manual(values = c("Delta total vegetation" = "#59a14f", "Delta bare ground" = "#b07d3c")) +
    ggplot2::labs(
      title = "Secondary sanity check: ground-cover response by grazing metadata",
      subtitle = "Treatment is retained as metadata only; this figure is not the primary causal analysis.",
      x = "Treatment metadata",
      y = "Post-minus-pre change (percentage points)",
      colour = "Metric",
      caption = "Use this only as a secondary check alongside inundation and vegetation-group summaries."
    ) +
    theme_gayini_chart()
}


## Save figures and diagnostics ----


figure_index <- dplyr::bind_rows(
  save_figure(
    fig1,
    "10b_01",
    "10b_01_prepost_total_veg_bare_summary.png",
    "Full plot-set pre/post total vegetation and bare ground summary",
    "10a_ground_cover_prepost_plot_summary.csv",
    "primary_descriptive",
    "Each plot contributes pre and post mean cover values.",
    main_deck_candidate = TRUE
  ),
  save_figure(
    fig2,
    "10b_02",
    "10b_02_ranked_delta_total_veg.png",
    "Ranked plot change for delta_total_veg_pct",
    "10a_ground_cover_prepost_plot_summary.csv",
    "primary_descriptive",
    "Post mean minus pre mean total vegetation."
  ),
  save_figure(
    fig2a,
    "10b_02a",
    "10b_02a_ranked_delta_total_veg_top_bottom_15.png",
    "Slide-friendly top and bottom 15 plot changes for delta_total_veg_pct",
    "10a_ground_cover_prepost_plot_summary.csv",
    "primary_descriptive",
    "Top and bottom plots by total vegetation change; intended for main-deck review.",
    main_deck_candidate = TRUE
  ),
  save_figure(
    fig3,
    "10b_03",
    "10b_03_ranked_delta_bare_ground.png",
    "Ranked plot change for delta_bare_ground_pct",
    "10a_ground_cover_prepost_plot_summary.csv",
    "primary_descriptive",
    "Post mean minus pre mean bare ground."
  ),
  save_figure(
    fig3a,
    "10b_03a",
    "10b_03a_ranked_delta_bare_ground_top_bottom_15.png",
    "Slide-friendly top and bottom 15 plot changes for delta_bare_ground_pct",
    "10a_ground_cover_prepost_plot_summary.csv",
    "primary_descriptive",
    "Top and bottom plots by bare ground change; intended for main-deck review.",
    main_deck_candidate = TRUE
  ),
  save_figure(
    fig4,
    "10b_04",
    "10b_04_inundation_change_vs_total_veg_delta.png",
    "Scatter of inundation change vs delta_total_veg_pct",
    "10a_ground_cover_prepost_plot_summary.csv",
    "primary_descriptive",
    "Linear smoother is descriptive. Labels mark large-response or review-flagged plots."
  ),
  save_figure(
    fig4a,
    "10b_04a",
    "10b_04a_inundation_change_vs_total_veg_delta_simple.png",
    "Simplified main-deck scatter of inundation change vs delta_total_veg_pct",
    "10a_ground_cover_prepost_plot_summary.csv",
    "main_deck_candidate",
    "Simple linear trend, fewer labels, and no complex legend.",
    main_deck_candidate = TRUE
  ),
  save_figure(
    fig5,
    "10b_05",
    "10b_05_inundation_change_vs_bare_ground_delta.png",
    "Scatter of inundation change vs delta_bare_ground_pct",
    "10a_ground_cover_prepost_plot_summary.csv",
    "primary_descriptive",
    "Linear smoother is descriptive. Labels mark large-response or review-flagged plots."
  ),
  save_figure(
    fig5a,
    "10b_05a",
    "10b_05a_inundation_change_vs_bare_ground_delta_simple.png",
    "Simplified main-deck scatter of inundation change vs delta_bare_ground_pct",
    "10a_ground_cover_prepost_plot_summary.csv",
    "main_deck_candidate",
    "Simple linear trend, fewer labels, and no complex legend.",
    main_deck_candidate = TRUE
  ),
  save_figure(
    fig6,
    "10b_06",
    "10b_06_group_summary_vegetation_inundation_change.png",
    "Grouped summary by vegetation_adrian_group and inundation_change_class",
    "10a_ground_cover_prepost_group_summary.csv",
    "subsidiary_appendix",
    "Group means can be unstable where plot counts are small; use as subsidiary or appendix material."
  )
)

if (INCLUDE_SECONDARY_TREATMENT_FIGURE) {
  figure_index <- dplyr::bind_rows(
    figure_index,
    save_figure(
      fig7,
      "10b_07",
      "10b_07_secondary_treatment_sanity_check.png",
      "Secondary treatment sanity-check figure",
      "10a_ground_cover_prepost_plot_summary.csv",
      "subsidiary_appendix_secondary_treatment_sanity_check",
      "Treatment is metadata and not the primary causal story."
    )
  )
}

readr::write_csv(figure_index, figure_index_path)
message("Wrote: ", figure_index_path)

write_handoff_report(
  figure_index = figure_index,
  plot_summary = plot_summary,
  model_summary = model_summary,
  report_path = handoff_report_path
)

message("10b ground-cover pre/post figures complete.")
