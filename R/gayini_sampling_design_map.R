####################################################################################################


## GAYINI REMOTE SENSING PROJECT


## Tier 1 · F1 sampling-design map (data figure) and its concept explainer.


## Convention established here: every analytical step ships a FIGURE PAIR — a
## concept figure (explainer of what the code is doing) and the data figure it
## produces. Both are registered in Output/figures/figures_manifest.csv under the
## {step}_{concept|data} naming convention.


####################################################################################################


## Community colour palette (Dark2-based, colourblind-safe). Order matches
## gayini_community_levels(); "Other / minor units" is neutral context grey.

gayini_community_palette <- function() {
  c(
    "Inland Floodplain Shrublands / Swamps" = "#1B9E77",
    "Riverine Chenopod Shrublands"          = "#7570B3",
    "Aeolian Chenopod Shrublands"           = "#E6AB02",
    "Floodplain Woodland / Forest"          = "#D95F02",
    "Other / minor units"                   = "#CFCFC7"
  )
}


## Small cartographic furniture (no ggspatial dependency) ----

gayini_nice_round <- function(x) {
  ## Largest "nice" number (1/2/5 x 10^k) not exceeding x.
  if (x <= 0) return(1)
  p <- 10^floor(log10(x))
  m <- x / p
  base <- if (m >= 5) 5 else if (m >= 2) 2 else 1
  base * p
}


gayini_scalebar_layers <- function(bbox, target_frac = 0.25) {

  w <- bbox["xmax"] - bbox["xmin"]
  h <- bbox["ymax"] - bbox["ymin"]

  bar_len <- gayini_nice_round(as.numeric(w) * target_frac)  # metres

  x0 <- as.numeric(bbox["xmin"] + 0.06 * w)
  y0 <- as.numeric(bbox["ymin"] + 0.06 * h)

  label <- if (bar_len >= 1000) paste0(bar_len / 1000, " km") else paste0(bar_len, " m")

  list(
    ggplot2::annotate("segment", x = x0, xend = x0 + bar_len, y = y0, yend = y0,
                      linewidth = 1.1, colour = "grey15"),
    ggplot2::annotate("segment", x = x0, xend = x0, y = y0 - 0.008 * h, yend = y0 + 0.008 * h,
                      linewidth = 1.1, colour = "grey15"),
    ggplot2::annotate("segment", x = x0 + bar_len, xend = x0 + bar_len,
                      y = y0 - 0.008 * h, yend = y0 + 0.008 * h,
                      linewidth = 1.1, colour = "grey15"),
    ggplot2::annotate("text", x = x0 + bar_len / 2, y = y0 + 0.025 * h,
                      label = label, size = 3, colour = "grey15")
  )

}


gayini_north_arrow_layers <- function(bbox) {

  w <- bbox["xmax"] - bbox["xmin"]
  h <- bbox["ymax"] - bbox["ymin"]

  x0 <- as.numeric(bbox["xmax"] - 0.06 * w)
  y0 <- as.numeric(bbox["ymin"] + 0.06 * h)

  list(
    ggplot2::annotate("segment", x = x0, xend = x0, y = y0, yend = y0 + 0.06 * h,
                      arrow = grid::arrow(length = grid::unit(0.18, "cm"), type = "closed"),
                      linewidth = 1.1, colour = "grey15"),
    ggplot2::annotate("text", x = x0, y = y0 + 0.085 * h, label = "N", size = 3.2,
                      fontface = "bold", colour = "grey15")
  )

}


## F1 data figure — the sampling-design map ----

gayini_build_sampling_design_map <- function(reproj,
                                             plots_qa,
                                             root = getwd(),
                                             out_dir = gayini_path("Output", "figures", root = root)) {

  pal <- gayini_community_palette()
  community_levels <- gayini_community_levels()

  boundary    <- reproj$boundary
  communities <- reproj$communities
  management  <- reproj$management

  ## Plots carry their authoritative community + treed flag (from QA join).
  plots <- plots_qa
  plots$simplified_vegetation_group <- factor(
    as.character(plots$simplified_vegetation_group),
    levels = community_levels
  )
  plots$treed_label <- ifelse(plots$treed_plot_flag == 1, "Treed plot", "Non-treed plot")
  plot_points <- sf::st_point_on_surface(plots)

  bbox <- sf::st_bbox(boundary)

  ## Vegetation split: four communities (coloured) vs other (grey context).
  comm_four  <- communities[communities$simplified_vegetation_group %in% community_levels, ]
  comm_four$simplified_vegetation_group <- factor(
    as.character(comm_four$simplified_vegetation_group), levels = community_levels
  )
  comm_other <- communities[communities$simplified_vegetation_group == GAYINI_OTHER_COMMUNITY, ]

  main_map <- ggplot2::ggplot() +
    ggplot2::geom_sf(data = management, fill = NA, colour = "grey78", linewidth = 0.15) +
    { if (nrow(comm_other) > 0)
        ggplot2::geom_sf(data = comm_other, fill = pal[[GAYINI_OTHER_COMMUNITY]],
                         colour = NA, alpha = 0.55) } +
    ggplot2::geom_sf(data = comm_four,
                     ggplot2::aes(fill = .data$simplified_vegetation_group),
                     colour = NA, alpha = 0.68) +
    ggplot2::geom_sf(data = boundary, fill = NA, colour = "grey15", linewidth = 0.6) +
    ## Plots at true orientation (tiny squares) plus a locatable centroid symbol.
    ggplot2::geom_sf(data = plots, fill = NA, colour = "grey10", linewidth = 0.2) +
    ggplot2::geom_sf(data = plot_points,
                     ggplot2::aes(colour = .data$simplified_vegetation_group,
                                  shape = .data$treed_label),
                     size = 1.7, stroke = 0.6) +
    ggplot2::scale_fill_manual(values = pal[community_levels], drop = FALSE,
                               name = "Vegetation community") +
    ggplot2::scale_colour_manual(values = pal[community_levels], drop = FALSE,
                                 guide = "none") +
    ggplot2::scale_shape_manual(values = c("Non-treed plot" = 16, "Treed plot" = 17),
                                name = "1 ha plot") +
    gayini_scalebar_layers(bbox) +
    gayini_north_arrow_layers(bbox) +
    ggplot2::coord_sf(expand = FALSE) +
    ggplot2::labs(
      title = "Gayini sampling design — 66 monitoring plots across four vegetation communities",
      subtitle = "GDA2020 / NSW Lambert (EPSG:8058) · plots drawn at true survey orientation",
      caption = "Boundary (dark) · management zones (light) · vegetation communities (fill) · plots (symbols)"
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      panel.grid = ggplot2::element_line(colour = "grey93", linewidth = 0.2),
      legend.position = "right",
      plot.title = ggplot2::element_text(face = "bold", size = 12),
      plot.subtitle = ggplot2::element_text(size = 9, colour = "grey30")
    )

  ## --- per-community zoom insets ---
  insets <- lapply(community_levels, function(g) {
    gayini_community_inset(g, comm_four, boundary, plots, pal)
  })
  inset_grid <- cowplot::plot_grid(plotlist = insets, ncol = 2, labels = NULL)

  full <- cowplot::plot_grid(
    main_map, inset_grid,
    ncol = 1, rel_heights = c(1.6, 1)
  )

  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  png_path <- file.path(out_dir, "F1_sampling_design_map_data.png")
  pdf_path <- file.path(out_dir, "F1_sampling_design_map_data.pdf")

  ggplot2::ggsave(png_path, full, width = 11, height = 12.5, dpi = 300,
                  device = ragg::agg_png, bg = "white")
  ggplot2::ggsave(pdf_path, full, width = 11, height = 12.5, device = cairo_pdf, bg = "white")

  message("Wrote: ", png_path)
  message("Wrote: ", pdf_path)

  list(png = png_path, pdf = pdf_path)

}


gayini_community_inset <- function(group, comm_four, boundary, plots, pal) {

  poly <- comm_four[comm_four$simplified_vegetation_group == group, ]
  grp_plots <- plots[as.character(plots$simplified_vegetation_group) == group, ]

  ## Zoom to the group's plots (buffered), so the true-orientation squares read.
  if (nrow(grp_plots) > 0) {
    z <- sf::st_bbox(grp_plots)
    padx <- max(as.numeric(z["xmax"] - z["xmin"]) * 0.15, 800)
    pady <- max(as.numeric(z["ymax"] - z["ymin"]) * 0.15, 800)
    xlim <- c(z["xmin"] - padx, z["xmax"] + padx)
    ylim <- c(z["ymin"] - pady, z["ymax"] + pady)
  } else {
    z <- sf::st_bbox(poly)
    xlim <- c(z["xmin"], z["xmax"]); ylim <- c(z["ymin"], z["ymax"])
  }

  ggplot2::ggplot() +
    ggplot2::geom_sf(data = boundary, fill = NA, colour = "grey80", linewidth = 0.25) +
    ggplot2::geom_sf(data = poly, fill = pal[[group]], colour = NA, alpha = 0.35) +
    ggplot2::geom_sf(data = grp_plots, fill = pal[[group]], colour = "grey10", linewidth = 0.3) +
    ggplot2::coord_sf(xlim = as.numeric(xlim), ylim = as.numeric(ylim), expand = FALSE) +
    ggplot2::labs(title = paste0(group, "  (n = ", nrow(grp_plots), ")")) +
    ggplot2::theme_minimal(base_size = 8) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(size = 8, face = "bold"),
      axis.text = ggplot2::element_text(size = 5, colour = "grey55"),
      panel.grid = ggplot2::element_line(colour = "grey94", linewidth = 0.15)
    )

}


## F1 concept figure — the explainer ----
##
## Two panels, schematic (no real data):
##   (L) a 1 ha plot square sits at an angle ON the pixel grid — surveyed at its
##       true orientation, NOT snapped to the raster grid.
##   (R) each vegetation community spans a RANGE of inundation regimes (dry ->
##       wet), so plots within a community are not hydrologically identical.

gayini_build_concept_figure <- function(root = getwd(),
                                        out_dir = gayini_path("Output", "figures", root = root)) {

  pal <- gayini_community_palette()

  ## --- Panel L: angled plot on pixel grid ---
  cell <- 1
  grid_df <- expand.grid(x = 0:5, y = 0:5)
  hlines <- data.frame(y = 0:5, x = 0, xend = 5)
  vlines <- data.frame(x = 0:5, y = 0, yend = 5)

  ## A ~1.6-unit square rotated ~22 degrees, centred on the grid.
  cx <- 2.6; cy <- 2.6; s <- 0.8; theta <- 22 * pi / 180
  corners <- data.frame(dx = c(-s, s, s, -s), dy = c(-s, -s, s, s))
  rot <- data.frame(
    x = cx + corners$dx * cos(theta) - corners$dy * sin(theta),
    y = cy + corners$dx * sin(theta) + corners$dy * cos(theta)
  )

  panel_l <- ggplot2::ggplot() +
    ggplot2::geom_segment(data = hlines, ggplot2::aes(x = x, xend = xend, y = y, yend = y),
                          colour = "grey75", linewidth = 0.3) +
    ggplot2::geom_segment(data = vlines, ggplot2::aes(x = x, xend = x, y = y, yend = yend),
                          colour = "grey75", linewidth = 0.3) +
    ggplot2::geom_polygon(data = rot, ggplot2::aes(x = x, y = y),
                          fill = "#1B9E77", alpha = 0.4, colour = "#0E5A45", linewidth = 0.9) +
    ggplot2::annotate("text", x = cx, y = cy, label = "1 ha plot", size = 3, fontface = "bold",
                      colour = "#0E5A45") +
    ggplot2::annotate("text", x = 2.5, y = 5.5,
                      label = "Plots are surveyed at their TRUE orientation —\nnot snapped to the pixel grid",
                      size = 3, colour = "grey20") +
    ggplot2::annotate("text", x = 4.4, y = 0.4, label = "raster pixels (25 m)", size = 2.6,
                      colour = "grey55") +
    ggplot2::coord_equal(xlim = c(-0.2, 5.2), ylim = c(-0.2, 6.2)) +
    ggplot2::labs(subtitle = "A · Plot geometry vs the pixel grid") +
    ggplot2::theme_void(base_size = 11) +
    ggplot2::theme(plot.subtitle = ggplot2::element_text(face = "bold", size = 10, hjust = 0))

  ## --- Panel R: communities span a range of inundation ---
  community_levels <- gayini_community_levels()
  ## Schematic dry->wet ranges (illustrative, not fitted): drier communities to
  ## the left, wetter floodplain communities to the right.
  ranges <- tibble::tibble(
    community = factor(community_levels, levels = rev(community_levels)),
    lo = c(0.30, 0.10, 0.02, 0.35),
    hi = c(0.80, 0.45, 0.20, 0.90),
    mid = (lo + hi) / 2
  )

  ## A few illustrative plot points scattered within each range.
  set_pts <- do.call(rbind, lapply(seq_len(nrow(ranges)), function(i) {
    r <- ranges[i, ]
    xs <- seq(r$lo + 0.03, r$hi - 0.03, length.out = 5)
    data.frame(community = r$community, x = xs, y = as.numeric(ranges$community[i]))
  }))

  panel_r <- ggplot2::ggplot(ranges) +
    ggplot2::annotate("rect", xmin = 0, xmax = 1, ymin = 0.4, ymax = nrow(ranges) + 0.6,
                      fill = NA) +
    ggplot2::geom_segment(ggplot2::aes(x = lo, xend = hi, y = community, yend = community,
                                       colour = community), linewidth = 6, alpha = 0.35,
                          lineend = "round") +
    ggplot2::geom_point(data = set_pts, ggplot2::aes(x = x, y = community, colour = community),
                        size = 1.8) +
    ggplot2::scale_colour_manual(values = pal[community_levels], guide = "none") +
    ggplot2::scale_x_continuous(limits = c(0, 1),
                                breaks = c(0.05, 0.5, 0.95),
                                labels = c("drier", "inundation regime", "wetter")) +
    ggplot2::labs(subtitle = "B · Each community spans a range of inundation") +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      plot.subtitle = ggplot2::element_text(face = "bold", size = 10),
      panel.grid.major.y = ggplot2::element_blank(),
      panel.grid.minor = ggplot2::element_blank(),
      axis.title = ggplot2::element_blank(),
      axis.text.y = ggplot2::element_text(size = 8)
    )

  concept <- cowplot::plot_grid(panel_l, panel_r, ncol = 2, rel_widths = c(1, 1.15))

  title <- cowplot::ggdraw() +
    cowplot::draw_label(
      "F1 concept — what the sampling-design map shows",
      fontface = "bold", size = 13, x = 0.01, hjust = 0
    )
  concept <- cowplot::plot_grid(title, concept, ncol = 1, rel_heights = c(0.08, 1))

  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
  svg_path <- file.path(out_dir, "F1_sampling_design_concept.svg")
  pdf_path <- file.path(out_dir, "F1_sampling_design_concept.pdf")

  ggplot2::ggsave(svg_path, concept, width = 11, height = 4.6, device = svglite::svglite, bg = "white")
  ggplot2::ggsave(pdf_path, concept, width = 11, height = 4.6, device = cairo_pdf, bg = "white")

  message("Wrote: ", svg_path)
  message("Wrote: ", pdf_path)

  list(svg = svg_path, pdf = pdf_path)

}
