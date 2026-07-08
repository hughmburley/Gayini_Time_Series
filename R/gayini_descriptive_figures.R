####################################################################################################


## GAYINI REMOTE SENSING PROJECT


## Tier 1 · Task B descriptive figures (F2-F4). Database-only; no CRS/raster.
## Each rung ships a figure PAIR: a concept explainer + the real-data figure.


####################################################################################################


## Shared save helper: data -> PNG + PDF, concept -> SVG + PDF ----

gayini_save_figure <- function(plot, out_dir, basename, kind, width, height, dpi = 300) {
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  paths <- if (identical(kind, "data")) {
    list(
      png = file.path(out_dir, paste0(basename, ".png")),
      pdf = file.path(out_dir, paste0(basename, ".pdf"))
    )
  } else {
    list(
      svg = file.path(out_dir, paste0(basename, ".svg")),
      pdf = file.path(out_dir, paste0(basename, ".pdf"))
    )
  }

  if (!is.null(paths$png)) {
    ggplot2::ggsave(paths$png, plot, width = width, height = height, dpi = dpi,
                    device = ragg::agg_png, bg = "white")
    message("Wrote: ", paths$png)
  }
  if (!is.null(paths$svg)) {
    ggplot2::ggsave(paths$svg, plot, width = width, height = height,
                    device = svglite::svglite, bg = "white")
    message("Wrote: ", paths$svg)
  }
  ggplot2::ggsave(paths$pdf, plot, width = width, height = height,
                  device = cairo_pdf, bg = "white")
  message("Wrote: ", paths$pdf)

  paths
}


gayini_year_start <- function(water_year) {
  as.integer(substr(as.character(water_year), 1, 4))
}


## =============================================================================
## F2 — How annual occurrence is computed
## =============================================================================

## Concept: a 35-cell water-year strip for one wet Inland Floodplain plot and one
## dry Aeolian plot; each cell wet / dry / masked; occurrence = 100 x wet-valid
## years / valid years shown beside each strip.

gayini_build_f2_concept <- function(inundation_ts,
                                    wet_plot = "GA_001",
                                    dry_plot = "GA_009",
                                    out_dir = "Output/figures") {

  pal <- gayini_occurrence_cell_palette()

  strip <- inundation_ts |>
    dplyr::filter(.data$plot_id %in% c(wet_plot, dry_plot)) |>
    dplyr::mutate(year_start = gayini_year_start(.data$water_year)) |>
    ## Restrict to the 35 canonical water years (1988-1989 .. 2022-2023); the
    ## view carries 2 trailing Sentinel-era placeholders with no valid obs.
    dplyr::filter(.data$year_start >= 1988, .data$year_start <= 2022) |>
    dplyr::mutate(
      category = dplyr::case_when(
        .data$annual_valid_any == 0 ~ "masked",
        .data$annual_wet_any == 1   ~ "wet",
        TRUE                        ~ "dry"
      ),
      plot_label = dplyr::case_when(
        .data$plot_id == wet_plot ~ paste0(wet_plot, " · Inland Floodplain (wet)"),
        .data$plot_id == dry_plot ~ paste0(dry_plot, " · Aeolian Chenopod (dry)"),
        TRUE ~ .data$plot_id
      )
    )

  strip$plot_label <- factor(strip$plot_label, levels = c(
    paste0(dry_plot, " · Aeolian Chenopod (dry)"),
    paste0(wet_plot, " · Inland Floodplain (wet)")
  ))

  ## occurrence = 100 x wet-valid years / valid years
  occ <- strip |>
    dplyr::group_by(.data$plot_label) |>
    dplyr::summarise(
      valid_years = sum(.data$annual_valid_any == 1, na.rm = TRUE),
      wet_years   = sum(.data$annual_valid_any == 1 & .data$annual_wet_any == 1, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      occurrence = 100 * wet_years / valid_years,
      label = sprintf("occurrence = 100 × %d ÷ %d = %.0f%%", wet_years, valid_years, occurrence)
    )

  year_breaks <- seq(1988, 2022, by = 5)

  p <- ggplot2::ggplot(strip, ggplot2::aes(x = year_start, y = 1, fill = category)) +
    ggplot2::geom_tile(colour = "white", linewidth = 0.4, height = 0.7) +
    ggplot2::geom_text(data = occ, inherit.aes = FALSE,
                       ggplot2::aes(x = 1988, y = 1.55, label = label),
                       hjust = 0, size = 3.1, fontface = "bold", colour = "grey20") +
    ggplot2::facet_wrap(~plot_label, ncol = 1) +
    ggplot2::scale_fill_manual(values = pal, breaks = c("wet", "dry", "masked"),
                               labels = c("wet (inundated)", "dry (valid)", "masked (no valid obs)"),
                               name = NULL) +
    ggplot2::scale_x_continuous(breaks = year_breaks,
                                labels = paste0(year_breaks, "–", (year_breaks + 1) %% 100)) +
    ggplot2::scale_y_continuous(limits = c(0.5, 1.8)) +
    ggplot2::labs(
      title = "F2 concept — how annual wet frequency is computed (headline metric)",
      subtitle = "Each water year is wet, dry, or masked. Annual wet frequency = wet-valid years ÷ valid years, per plot.",
      caption = "This between-year flood frequency is the headline metric that runs the whole ladder (F2→F9). Within-year wet coverage is kept as a separate 'wet extent' metric.",
      x = "Water year (1988–2023)", y = NULL
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      axis.text.y = ggplot2::element_blank(),
      panel.grid = ggplot2::element_blank(),
      legend.position = "bottom",
      strip.text = ggplot2::element_text(face = "bold", hjust = 0),
      plot.title = ggplot2::element_text(face = "bold"),
      plot.subtitle = ggplot2::element_text(size = 9, colour = "grey30"),
      plot.caption = ggplot2::element_text(size = 7.5, colour = "grey45", hjust = 0)
    )

  gayini_save_figure(p, out_dir, "F2_annual_occurrence_concept", "concept", width = 10, height = 5)
}


## Data: site-wide annual wet-frequency time series, 1988-2023 — the share of
## plots inundated each water year (between-year headline, consistent with F2
## concept and F4). Replaces the pre/post map as the "has inundation changed"
## figure.

gayini_build_f2_data <- function(spine, out_dir = "Output/figures") {

  site <- gayini_site_share_plots_wet(spine) |>
    dplyr::mutate(year_start = gayini_year_start(.data$water_year)) |>
    dplyr::arrange(.data$year_start)

  ann <- tibble::tribble(
    ~year_start, ~note,               ~vjust,
    2006,        "2006–07 drought trough", -1.0,
    2010,        "2010–11 flood",          -0.9,
    2016,        "2016–17 flood",          -0.9,
    2022,        "2022–23 flood",          -0.9
  ) |>
    dplyr::left_join(site, by = "year_start")

  p <- ggplot2::ggplot(site, ggplot2::aes(x = year_start, y = pct_plots_wet)) +
    ggplot2::geom_hline(yintercept = mean(site$pct_plots_wet), linetype = "dashed",
                        colour = "grey70", linewidth = 0.4) +
    ggplot2::geom_line(colour = "#2171B5", linewidth = 0.8) +
    ggplot2::geom_point(colour = "#08306B", size = 1.9) +
    ggplot2::geom_point(data = ann, colour = "#B2182B", size = 2.6) +
    ggplot2::geom_text(data = ann, ggplot2::aes(label = note, vjust = vjust),
                       size = 3, fontface = "bold", colour = "#7F1018") +
    ggplot2::scale_x_continuous(breaks = seq(1988, 2022, by = 4),
                                labels = paste0(seq(1988, 2022, by = 4), "–",
                                                (seq(1988, 2022, by = 4) + 1) %% 100)) +
    ggplot2::scale_y_continuous(limits = c(0, max(site$pct_plots_wet) * 1.15),
                                expand = ggplot2::expansion(mult = c(0, 0.02))) +
    ggplot2::labs(
      title = "F2 data — site-wide annual inundation, 1988–2023",
      subtitle = "Share of the 66 plots inundated (wet at least once) in each water year · between-year headline metric",
      caption = "Dashed line = 35-year mean. Replaces the pre/post map as the 'has inundation changed' figure.",
      x = "Water year", y = "Plots inundated that year (%)"
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      axis.text.x = ggplot2::element_text(angle = 45, hjust = 1, size = 8),
      plot.title = ggplot2::element_text(face = "bold"),
      plot.subtitle = ggplot2::element_text(size = 9, colour = "grey30"),
      plot.caption = ggplot2::element_text(size = 7.5, colour = "grey45", hjust = 0)
    )

  gayini_save_figure(p, out_dir, "F2_annual_occurrence_timeseries_data", "data", width = 10, height = 5.5)
}


## =============================================================================
## F3 — The data cube
## =============================================================================

## Concept: schematic of the 66 x 35 plot-year matrix (rows = plots grouped by
## community, cols = water years, cell = occurrence) with the ground-cover layer
## joined behind it.

gayini_build_f3_concept <- function(out_dir = "Output/figures") {

  ramp <- gayini_occurrence_ramp()
  pal  <- gayini_gradient_palette()
  levs <- gayini_gradient_levels()

  ## Small stylised matrix: 12 rows (3 per community, gradient order) x 12 cols.
  n_row <- 12L; n_col <- 12L
  base_wet <- c(0.10, 0.32, 0.62, 0.46)              # per community, dry->wet, context
  ## rows bottom->top = Woodland/Forest .. Aeolian, so Aeolian sits at TOP (matches F3 data).
  row_comm <- rep(rev(levs), each = 3)
  col_flood <- c(.5,.3,.2,.7,.2,.1,.6,.2,.3,.4,.8,.5) # a flood/drought column pattern

  grid <- expand.grid(row = seq_len(n_row), col = seq_len(n_col))
  grid$community <- row_comm[grid$row]
  grid$value <- pmin(1, pmax(0,
    base_wet[match(grid$community, levs)] * (0.5 + col_flood[grid$col])))
  ## Headline metric is binary per plot-year: each cell is wet or dry that year;
  ## a plot's flood frequency is its share of wet cells across the 35 years.
  grid$cell <- ifelse(grid$value > 0.33, "wet", "dry")

  ## Back (ground-cover) face, offset up-right and greyed.
  dx <- 0.9; dy <- 0.9
  back <- grid
  back$row <- back$row + dy
  back$col <- back$col + dx

  comm_strip <- data.frame(
    row = seq_len(n_row),
    community = factor(row_comm, levels = levs)
  )

  p <- ggplot2::ggplot() +
    ## ground-cover layer behind
    ggplot2::geom_tile(data = back, ggplot2::aes(x = col, y = row),
                       fill = "grey82", colour = "white", linewidth = 0.2) +
    ggplot2::annotate("text", x = n_col + dx + 0.2, y = n_row + dy + 0.8,
                      label = "ground cover\n(joined behind)", hjust = 1, size = 2.9,
                      fontface = "italic", colour = "grey45") +
    ## wet/dry matrix in front
    ggplot2::geom_tile(data = grid, ggplot2::aes(x = col, y = row, fill = cell),
                       colour = "white", linewidth = 0.25) +
    ## community colour strip on the left
    ggplot2::geom_tile(data = comm_strip, ggplot2::aes(x = 0.1, y = row),
                       fill = pal[comm_strip$community], width = 0.5, height = 1) +
    ggplot2::scale_fill_manual(values = gayini_occurrence_cell_palette(),
                               breaks = c("wet", "dry"),
                               labels = c("wet year", "dry year"), name = NULL) +
    ggplot2::annotate("segment", x = 1, xend = n_col, y = -0.4, yend = -0.4,
                      arrow = grid::arrow(length = grid::unit(0.15, "cm")), colour = "grey30") +
    ggplot2::annotate("text", x = n_col / 2, y = -1.1, label = "35 water years →", size = 3,
                      colour = "grey30") +
    ggplot2::annotate("segment", x = -0.7, xend = -0.7, y = 1, yend = n_row,
                      arrow = grid::arrow(length = grid::unit(0.15, "cm")), colour = "grey30") +
    ggplot2::annotate("text", x = -1.4, y = n_row / 2, label = "66 plots\n(by community)",
                      angle = 90, size = 3, colour = "grey30") +
    ggplot2::coord_equal(clip = "off") +
    ggplot2::labs(
      title = "F3 concept — the plot-year data cube",
      subtitle = "66 plots × 35 water years; each cell = wet or dry that year (row share = flood frequency), with ground cover joined behind"
    ) +
    ggplot2::theme_void(base_size = 11) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(face = "bold"),
      plot.subtitle = ggplot2::element_text(size = 9, colour = "grey30"),
      plot.margin = ggplot2::margin(10, 40, 20, 30),
      legend.position = "right"
    )

  gayini_save_figure(p, out_dir, "F3_data_cube_concept", "concept", width = 8.5, height = 6.5)
}


## Shared layout for the F3 cube: order plots by the dry->wet gradient (and, so
## the headline reads directly off the picture, by flood frequency within each
## community), a visual gap before the treed context block, a left community
## colour strip, and community group labels.

gayini_f3_plot_layout <- function(spine) {
  df <- gayini_apply_gradient_order(spine)
  df$year_start <- gayini_year_start(df$water_year)

  freq <- gayini_plot_between_year_frequency(spine)

  ## Order within community by headline flood frequency (desc).
  plot_order <- freq |>
    gayini_apply_gradient_order() |>
    dplyr::arrange(.data$simplified_vegetation_group, dplyr::desc(.data$flood_frequency_pct))

  plot_order$block <- ifelse(plot_order$treed_plot_flag == 1, "treed", "nontreed")
  gap <- 2
  plot_order$y_index <- seq_len(nrow(plot_order)) +
    ifelse(plot_order$block == "treed", gap, 0)

  df <- df |> dplyr::left_join(
    dplyr::select(plot_order, plot_id, y_index, flood_frequency_pct),
    by = "plot_id"
  )

  ## Per plot-year wet/dry/masked category (the binary headline substrate).
  df$cell <- dplyr::case_when(
    df$annual_valid_any == 0 ~ "masked",
    df$annual_wet_any == 1   ~ "wet",
    TRUE                     ~ "dry"
  )

  strip <- plot_order
  strip$xstrip <- 1985.5

  group_labels <- plot_order |>
    dplyr::group_by(.data$simplified_vegetation_group) |>
    dplyr::summarise(y_mid = mean(.data$y_index), n = dplyr::n(), .groups = "drop")
  short <- gayini_gradient_short_labels()
  group_labels$label <- paste0(short[as.character(group_labels$simplified_vegetation_group)],
                               "  (n=", group_labels$n, ")")

  treed_boundary <- (max(plot_order$y_index[plot_order$block == "nontreed"]) +
                     min(plot_order$y_index[plot_order$block == "treed"])) / 2

  list(df = df, plot_order = plot_order, strip = strip,
       group_labels = group_labels, treed_boundary = treed_boundary,
       year_breaks = seq(1988, 2022, by = 5))
}


gayini_f3_common_layers <- function(lay, pal) {
  list(
    ggplot2::geom_tile(data = lay$strip, ggplot2::aes(x = xstrip, y = y_index),
                       fill = pal[as.character(lay$strip$simplified_vegetation_group)],
                       width = 1.4, height = 1),
    ggplot2::geom_hline(yintercept = lay$treed_boundary, colour = "grey20", linewidth = 0.6),
    ggplot2::annotate("text", x = 2023.4, y = lay$treed_boundary, label = "← treed\ncontext block",
                      hjust = 0, size = 2.5, colour = "grey35"),
    ggplot2::geom_text(data = lay$group_labels,
                       ggplot2::aes(x = 1984.2, y = y_mid, label = label),
                       hjust = 1, size = 2.7, fontface = "bold", colour = "grey20"),
    ggplot2::scale_x_continuous(breaks = lay$year_breaks,
                                labels = paste0(lay$year_breaks, "–", (lay$year_breaks + 1) %% 100),
                                expand = ggplot2::expansion(mult = c(0.22, 0.14))),
    ggplot2::scale_y_reverse()
  )
}


## Data (HEADLINE): the real 66 x 35 wet/dry cube. Each cell = wet or dry that
## year; a row's share of wet years is that plot's flood frequency. Rows ordered
## by the dry->wet gradient; treed block visually separated.

gayini_build_f3_data <- function(spine, out_dir = "Output/figures") {

  pal <- gayini_gradient_palette()
  lay <- gayini_f3_plot_layout(spine)

  p <- ggplot2::ggplot() +
    ggplot2::geom_tile(data = lay$df, ggplot2::aes(x = year_start, y = y_index, fill = cell)) +
    gayini_f3_common_layers(lay, pal) +
    ggplot2::scale_fill_manual(values = gayini_occurrence_cell_palette(),
                               breaks = c("wet", "dry", "masked"),
                               labels = c("wet (inundated)", "dry", "masked"),
                               name = NULL) +
    ggplot2::labs(
      title = "F3 data — the 66 × 35 plot-year wet/dry cube",
      subtitle = "Each cell = wet or dry that year (row share of wet years = flood frequency). Rows by dry→wet gradient; treed block separated",
      x = "Water year", y = NULL
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      panel.grid = ggplot2::element_blank(),
      axis.text.y = ggplot2::element_blank(),
      axis.text.x = ggplot2::element_text(angle = 45, hjust = 1, size = 8),
      plot.title = ggplot2::element_text(face = "bold"),
      plot.subtitle = ggplot2::element_text(size = 9, colour = "grey30"),
      legend.position = "right"
    )

  gayini_save_figure(p, out_dir, "F3_data_cube_heatmap_data", "data", width = 11, height = 7.5)
}


## Data (SECONDARY): the within-year wet-EXTENT (coverage) heatmap — the same
## cube coloured by annual_occurrence_pct. Kept as the clearly-named secondary
## metric; NOT the headline.

gayini_build_f3_data_coverage_secondary <- function(spine, out_dir = "Output/figures") {

  ramp <- gayini_occurrence_ramp()
  pal  <- gayini_gradient_palette()
  lay  <- gayini_f3_plot_layout(spine)

  p <- ggplot2::ggplot() +
    ggplot2::geom_tile(data = lay$df, ggplot2::aes(x = year_start, y = y_index,
                                                   fill = annual_occurrence_pct)) +
    gayini_f3_common_layers(lay, pal) +
    ggplot2::scale_fill_gradientn(colours = ramp, limits = c(0, 100),
                                  name = "Wet extent\ncoverage (%)") +
    ggplot2::labs(
      title = "F3 data (secondary) — within-year wet-extent coverage cube",
      subtitle = "SECONDARY metric: how much of each plot was wet within the year (annual_occurrence_pct). Not the headline flood-frequency metric",
      x = "Water year", y = NULL
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      panel.grid = ggplot2::element_blank(),
      axis.text.y = ggplot2::element_blank(),
      axis.text.x = ggplot2::element_text(angle = 45, hjust = 1, size = 8),
      plot.title = ggplot2::element_text(face = "bold"),
      plot.subtitle = ggplot2::element_text(size = 9, colour = "grey30"),
      legend.position = "right"
    )

  gayini_save_figure(p, out_dir, "F3_data_cube_coverage_secondary_data", "data", width = 11, height = 7.5)
}


## =============================================================================
## F4 — Inundation regime by vegetation community
## =============================================================================

## Concept: the dry->wet gradient bands — the three non-treed communities as a
## low->high inundation strip.

gayini_build_f4_concept <- function(out_dir = "Output/figures") {

  pal   <- gayini_gradient_palette()
  focus <- gayini_focus_levels()
  short <- gayini_gradient_short_labels()

  bands <- tibble::tibble(
    community = factor(focus, levels = rev(focus)),
    lo  = c(0.00, 0.03, 0.06),
    hi  = c(0.30, 0.45, 0.90),
    mean_pct = c(9, 22, 50)
  )

  p <- ggplot2::ggplot(bands) +
    ggplot2::geom_segment(ggplot2::aes(x = lo, xend = hi, y = community, yend = community,
                                       colour = community), linewidth = 12, alpha = 0.45,
                          lineend = "round") +
    ggplot2::geom_point(ggplot2::aes(x = mean_pct / 100, y = community, colour = community),
                        size = 4) +
    ggplot2::geom_text(ggplot2::aes(x = mean_pct / 100, y = community,
                                    label = paste0("~", mean_pct, "%")),
                       vjust = -1.6, size = 3.2, fontface = "bold", colour = "grey20") +
    ggplot2::annotate("text", x = 0.5, y = 3.75,
                      label = "Floodplain Woodland / Forest (treed, ~44%) shown as context, excluded from focus",
                      size = 2.8, fontface = "italic", colour = "grey55") +
    ggplot2::scale_colour_manual(values = pal[focus], guide = "none") +
    ggplot2::scale_y_discrete(labels = function(x) short[x]) +
    ggplot2::scale_x_continuous(limits = c(0, 1),
                                breaks = c(0.03, 0.5, 0.95),
                                labels = c("drier", "annual wet frequency (% of years) →", "wetter")) +
    ggplot2::labs(
      title = "F4 concept — the dry→wet flooding gradient",
      subtitle = "Three non-treed communities ordered low→high annual wet frequency; each spans a range"
    ) +
    ggplot2::coord_cartesian(ylim = c(0.5, 4)) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      panel.grid.major.y = ggplot2::element_blank(),
      panel.grid.minor = ggplot2::element_blank(),
      axis.title = ggplot2::element_blank(),
      axis.text.y = ggplot2::element_text(size = 9),
      plot.title = ggplot2::element_text(face = "bold"),
      plot.subtitle = ggplot2::element_text(size = 9, colour = "grey30")
    )

  gayini_save_figure(p, out_dir, "F4_inundation_regime_concept", "concept", width = 9, height = 4.6)
}


## Data: distribution of per-plot annual wet FREQUENCY per community (box +
## jitter over plots), three non-treed communities in gradient order as focus,
## Woodland/Forest muted context; each annotated with its mean (~9/22/50/44%).

gayini_build_f4_data <- function(spine, out_dir = "Output/figures") {

  pal <- gayini_gradient_palette()
  freq <- gayini_plot_between_year_frequency(spine) |>
    gayini_apply_gradient_order()

  means <- freq |>
    dplyr::group_by(.data$simplified_vegetation_group) |>
    dplyr::summarise(mean_freq = mean(.data$flood_frequency_pct),
                     n_plots = dplyr::n(), .groups = "drop") |>
    dplyr::mutate(
      is_focus = as.character(.data$simplified_vegetation_group) %in% gayini_focus_levels(),
      label = sprintf("mean %.0f%%\n(n=%d)", .data$mean_freq, .data$n_plots)
    )

  short <- gayini_gradient_short_labels()

  p <- ggplot2::ggplot(freq, ggplot2::aes(x = simplified_vegetation_group,
                                          y = flood_frequency_pct)) +
    ggplot2::geom_boxplot(ggplot2::aes(fill = simplified_vegetation_group,
                                       alpha = is_focus_community),
                          width = 0.55, outlier.shape = NA, colour = "grey25", linewidth = 0.4) +
    ggplot2::geom_jitter(ggplot2::aes(colour = simplified_vegetation_group,
                                      alpha = is_focus_community),
                         width = 0.16, height = 0, size = 1.6) +
    ggplot2::geom_point(data = means, ggplot2::aes(y = mean_freq),
                        shape = 23, size = 3, fill = "white", colour = "grey15", stroke = 0.8) +
    ggplot2::geom_text(data = means,
                       ggplot2::aes(y = mean_freq, label = label),
                       vjust = -0.7, size = 3, fontface = "bold", colour = "grey15") +
    ggplot2::scale_fill_manual(values = pal, guide = "none") +
    ggplot2::scale_colour_manual(values = pal, guide = "none") +
    ggplot2::scale_alpha_manual(values = c("TRUE" = 0.85, "FALSE" = 0.28), guide = "none") +
    ggplot2::scale_x_discrete(labels = function(x) stringr::str_wrap(short[x], 16)) +
    ggplot2::scale_y_continuous(limits = c(0, 105), expand = ggplot2::expansion(mult = c(0.01, 0.03))) +
    ggplot2::labs(
      title = "F4 data — annual wet frequency by vegetation community",
      subtitle = "Per-plot flood frequency = % of valid years the plot was wet (1988–2023). Focus: three non-treed communities in dry→wet order; Woodland / Forest muted (context)",
      caption = "Each point = one plot. White diamond = community mean. Woodland / Forest (treed) shown for context, excluded from the analytical focus.",
      x = NULL, y = "Annual wet frequency (% of years)"
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      panel.grid.major.x = ggplot2::element_blank(),
      plot.title = ggplot2::element_text(face = "bold"),
      plot.subtitle = ggplot2::element_text(size = 8.5, colour = "grey30"),
      plot.caption = ggplot2::element_text(size = 7.5, colour = "grey45", hjust = 0)
    )

  gayini_save_figure(p, out_dir, "F4_inundation_regime_by_community_data", "data", width = 9.5, height = 6)
}
