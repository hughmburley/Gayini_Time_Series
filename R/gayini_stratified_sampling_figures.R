####################################################################################################


## GAYINI REMOTE SENSING PROJECT


## Tier 1 · F5 figure pair — the stratified-sampling frame.
##   Concept : community -> within-community regime bands -> random points near
##             plots, footprint excluded (schematic, no real data).
##   Data    : the background flood-frequency surface with the drawn points and
##             plots, per-community zooms for the three focus communities, and a
##             sample-summary panel (points per community x regime band).
##
## Depends on gayini_stratified_sampling_functions.R (band palette + ramp) and
## gayini_sampling_design_map.R (scale bar / north arrow furniture).


####################################################################################################


## Raster -> ggplot-ready data frame (aggregated so ggplot stays light) ----

gayini_raster_to_df <- function(r, max_cells = 4e5) {
  if (terra::ncell(r) > max_cells) {
    fact <- ceiling(sqrt(terra::ncell(r) / max_cells))
    r <- terra::aggregate(r, fact = fact, fun = "mean", na.rm = TRUE)
  }
  df <- terra::as.data.frame(r, xy = TRUE, na.rm = TRUE)
  names(df)[3] <- "freq"
  df
}


## F5 concept figure ----
##
## A left-to-right three-step schematic on one "community patch": (A) plots with
## their 2 km neighbourhood and footprint + 100 m exclusion; (B) the patch split
## into within-community flood-frequency terciles (low / mid / high); (C) the
## stratified random points, N per band, footprints kept empty.

gayini_build_f5_concept <- function(out_dir) {

  band_pal <- gayini_regime_band_palette()
  freq_ramp <- gayini_flood_frequency_ramp()

  ## Shared schematic geometry: a rectangular "community patch" with three
  ## horizontal flood-frequency bands and three angled 1 ha plots.
  xlim <- c(0, 10); ylim <- c(0, 7)
  band_bounds <- data.frame(
    band = factor(c("low", "mid", "high"), levels = c("low", "mid", "high")),
    ymin = c(0, 7 / 3, 14 / 3),
    ymax = c(7 / 3, 14 / 3, 7),
    fill = c(freq_ramp[2], freq_ramp[5], freq_ramp[8])
  )

  ## Three angled plots (rotated squares).
  plot_centres <- data.frame(cx = c(2.4, 5.4, 7.8), cy = c(1.7, 4.2, 5.3))
  make_square <- function(cx, cy, s = 0.42, theta = 20 * pi / 180, id) {
    dx <- c(-s, s, s, -s); dy <- c(-s, -s, s, s)
    data.frame(
      id = id,
      x = cx + dx * cos(theta) - dy * sin(theta),
      y = cy + dx * sin(theta) + dy * cos(theta)
    )
  }
  squares <- do.call(rbind, lapply(seq_len(nrow(plot_centres)), function(i)
    make_square(plot_centres$cx[i], plot_centres$cy[i], id = i)))

  circle <- function(cx, cy, r, n = 80) {
    a <- seq(0, 2 * pi, length.out = n)
    data.frame(x = cx + r * cos(a), y = cy + r * sin(a))
  }
  nbhd_rings <- do.call(rbind, lapply(seq_len(nrow(plot_centres)), function(i)
    cbind(id = i, circle(plot_centres$cx[i], plot_centres$cy[i], r = 2.1))))
  excl_rings <- do.call(rbind, lapply(seq_len(nrow(plot_centres)), function(i)
    cbind(id = i, circle(plot_centres$cx[i], plot_centres$cy[i], r = 0.75))))

  patch_rect <- function() ggplot2::annotate("rect", xmin = xlim[1], xmax = xlim[2],
                                              ymin = ylim[1], ymax = ylim[2],
                                              fill = NA, colour = "grey35", linewidth = 0.6)

  base_theme <- ggplot2::theme_void(base_size = 11) +
    ggplot2::theme(plot.subtitle = ggplot2::element_text(face = "bold", size = 10, hjust = 0),
                   legend.position = "none")

  ## --- Panel A: neighbourhood + exclusion ---
  panel_a <- ggplot2::ggplot() +
    patch_rect() +
    ggplot2::geom_polygon(data = nbhd_rings,
                          ggplot2::aes(x = x, y = y, group = id),
                          fill = "#3182BD", alpha = 0.10, colour = "#3182BD",
                          linetype = "dashed", linewidth = 0.4) +
    ggplot2::geom_polygon(data = excl_rings,
                          ggplot2::aes(x = x, y = y, group = id),
                          fill = "#D7301F", alpha = 0.18, colour = "#D7301F", linewidth = 0.3) +
    ggplot2::geom_polygon(data = squares,
                          ggplot2::aes(x = x, y = y, group = id),
                          fill = "grey20", colour = "grey10", linewidth = 0.4) +
    ggplot2::annotate("text", x = 5, y = 6.6, size = 2.9, colour = "grey20",
                      label = "2 km neighbourhood (dashed) · plot footprint + 100 m excluded (red)") +
    ggplot2::coord_equal(xlim = xlim, ylim = c(-0.2, 7.2), expand = FALSE) +
    ggplot2::labs(subtitle = "A · Near the plots, minus their footprints") +
    base_theme

  ## --- Panel B: within-community regime bands ---
  panel_b <- ggplot2::ggplot() +
    ggplot2::geom_rect(data = band_bounds,
                       ggplot2::aes(xmin = xlim[1], xmax = xlim[2], ymin = ymin, ymax = ymax),
                       fill = band_bounds$fill, alpha = 0.85) +
    patch_rect() +
    ggplot2::annotate("segment", x = xlim[1], xend = xlim[2], y = 7 / 3, yend = 7 / 3,
                      colour = "white", linewidth = 0.5) +
    ggplot2::annotate("segment", x = xlim[1], xend = xlim[2], y = 14 / 3, yend = 14 / 3,
                      colour = "white", linewidth = 0.5) +
    ggplot2::annotate("text", x = 0.4, y = c(7 / 6, 7 / 2, 35 / 6),
                      label = c("low", "mid", "high"), hjust = 0, size = 3.2,
                      fontface = "bold", colour = c("grey25", "white", "white")) +
    ggplot2::annotate("text", x = 9.6, y = 3.5, angle = 90, size = 2.9, colour = "grey25",
                      label = "flood frequency (this community's own range)") +
    ggplot2::coord_equal(xlim = xlim, ylim = c(-0.2, 7.2), expand = FALSE) +
    ggplot2::labs(subtitle = "B · Split into within-community terciles") +
    base_theme

  ## --- Panel C: stratified random points ---
  set.seed(1)
  band_pts <- do.call(rbind, lapply(seq_len(nrow(band_bounds)), function(i) {
    bb <- band_bounds[i, ]
    n <- 22
    px <- stats::runif(n, xlim[1] + 0.3, xlim[2] - 0.3)
    py <- stats::runif(n, bb$ymin + 0.25, bb$ymax - 0.25)
    ## drop points that land on a plot footprint (schematic exclusion)
    keep <- rep(TRUE, n)
    for (k in seq_len(nrow(plot_centres))) {
      keep <- keep & sqrt((px - plot_centres$cx[k])^2 + (py - plot_centres$cy[k])^2) > 0.85
    }
    data.frame(x = px[keep], y = py[keep], band = bb$band)
  }))

  panel_c <- ggplot2::ggplot() +
    ggplot2::geom_rect(data = band_bounds,
                       ggplot2::aes(xmin = xlim[1], xmax = xlim[2], ymin = ymin, ymax = ymax),
                       fill = band_bounds$fill, alpha = 0.30) +
    patch_rect() +
    ggplot2::geom_polygon(data = excl_rings,
                          ggplot2::aes(x = x, y = y, group = id),
                          fill = "white", colour = "grey70", linewidth = 0.2) +
    ggplot2::geom_polygon(data = squares,
                          ggplot2::aes(x = x, y = y, group = id),
                          fill = "grey20", colour = "grey10", linewidth = 0.4) +
    ggplot2::geom_point(data = band_pts, ggplot2::aes(x = x, y = y, colour = band),
                        size = 1.5) +
    ggplot2::scale_colour_manual(values = band_pal) +
    ggplot2::annotate("text", x = 5, y = 6.6, size = 2.9, colour = "grey20",
                      label = "N random points per band (here schematic)") +
    ggplot2::coord_equal(xlim = xlim, ylim = c(-0.2, 7.2), expand = FALSE) +
    ggplot2::labs(subtitle = "C · Stratified random sample") +
    base_theme

  concept <- cowplot::plot_grid(panel_a, panel_b, panel_c, ncol = 3, rel_widths = c(1, 1, 1))
  title <- cowplot::ggdraw() +
    cowplot::draw_label(
      "F5 concept — the stratified sampling frame (community → regime bands → random points near plots)",
      fontface = "bold", size = 13, x = 0.01, hjust = 0)
  concept <- cowplot::plot_grid(title, concept, ncol = 1, rel_heights = c(0.09, 1))

  gayini_save_figure(concept, out_dir, "F5_stratified_sampling_concept",
                     kind = "concept", width = 13, height = 4.4)
}


## F5 data figure ----

gayini_build_f5_data <- function(freq_8058,
                                 sample,             # list(points, summary)
                                 boundary,
                                 communities,
                                 plots,
                                 focus_communities,
                                 out_dir) {

  band_pal  <- gayini_regime_band_palette()
  freq_ramp <- gayini_flood_frequency_ramp()

  pts        <- sample$points
  summary_df <- sample$summary

  focus_comm <- communities[as.character(communities$simplified_vegetation_group)
                            %in% focus_communities, ]

  ## --- main map (overview) ---
  bnd_v   <- terra::vect(sf::st_geometry(boundary))
  freq_main <- terra::crop(freq_8058, bnd_v)
  freq_df   <- gayini_raster_to_df(freq_main, max_cells = 3e5)
  bbox      <- sf::st_bbox(boundary)

  main_map <- ggplot2::ggplot() +
    ggplot2::geom_raster(data = freq_df, ggplot2::aes(x = x, y = y, fill = freq)) +
    ggplot2::scale_fill_gradientn(colours = freq_ramp, limits = c(0, 100),
                                  name = "Background\nflood freq. (%)") +
    ggplot2::geom_sf(data = focus_comm, fill = NA, colour = "grey30", linewidth = 0.3) +
    ggplot2::geom_sf(data = boundary, fill = NA, colour = "grey10", linewidth = 0.6) +
    ggplot2::geom_sf(data = plots, fill = NA, colour = "grey15", linewidth = 0.25) +
    ggplot2::geom_sf(data = pts, ggplot2::aes(colour = regime_band), size = 0.5, alpha = 0.9) +
    ggplot2::scale_colour_manual(values = band_pal, name = "Regime band",
                                 guide = ggplot2::guide_legend(override.aes = list(size = 2.5))) +
    gayini_scalebar_layers(bbox) +
    gayini_north_arrow_layers(bbox) +
    ggplot2::coord_sf(xlim = c(bbox["xmin"], bbox["xmax"]),
                      ylim = c(bbox["ymin"], bbox["ymax"]), expand = FALSE) +
    ggplot2::labs(
      title = "F5 · Stratified sampling frame on the background flood-frequency surface",
      subtitle = "GDA2020 / NSW Lambert (EPSG:8058) · 100 × wet-valid years ÷ valid years, 1988–2023 · points near plots, footprints excluded",
      caption = "Surface = long-run background flood frequency · points coloured by within-community regime band · plots (outlines) are anchors, not sampled"
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      panel.grid = ggplot2::element_line(colour = "grey93", linewidth = 0.2),
      plot.title = ggplot2::element_text(face = "bold", size = 12),
      plot.subtitle = ggplot2::element_text(size = 8.5, colour = "grey30"),
      legend.position = "right"
    )

  ## --- per-community zoom insets ---
  insets <- lapply(focus_communities, function(g) {
    poly   <- focus_comm[as.character(focus_comm$simplified_vegetation_group) == g, ]
    g_pts  <- pts[as.character(pts$community) == g, ]
    g_plt  <- plots[as.character(plots$simplified_vegetation_group) == g, ]

    z <- sf::st_bbox(poly)
    v <- terra::vect(sf::st_geometry(poly))
    fr <- terra::mask(terra::crop(freq_8058, v), v)
    df <- gayini_raster_to_df(fr, max_cells = 1.2e5)

    ggplot2::ggplot() +
      ggplot2::geom_raster(data = df, ggplot2::aes(x = x, y = y, fill = freq)) +
      ggplot2::scale_fill_gradientn(colours = freq_ramp, limits = c(0, 100), guide = "none") +
      ggplot2::geom_sf(data = poly, fill = NA, colour = "grey30", linewidth = 0.3) +
      ggplot2::geom_sf(data = g_plt, fill = NA, colour = "grey15", linewidth = 0.35) +
      ggplot2::geom_sf(data = g_pts, ggplot2::aes(colour = regime_band), size = 0.7) +
      ggplot2::scale_colour_manual(values = band_pal, guide = "none") +
      ggplot2::coord_sf(xlim = c(z["xmin"], z["xmax"]), ylim = c(z["ymin"], z["ymax"]),
                        expand = FALSE) +
      ggplot2::labs(title = paste0(g, "  (", nrow(g_pts), " pts)")) +
      ggplot2::theme_minimal(base_size = 8) +
      ggplot2::theme(
        plot.title = ggplot2::element_text(size = 7.5, face = "bold"),
        axis.text  = ggplot2::element_text(size = 5, colour = "grey55"),
        panel.grid = ggplot2::element_line(colour = "grey94", linewidth = 0.15)
      )
  })
  inset_row <- cowplot::plot_grid(plotlist = insets, ncol = 3)

  ## --- sample-summary panel (points per community x band) ---
  summary_plot <- ggplot2::ggplot(
    summary_df,
    ggplot2::aes(x = regime_band,
                 y = factor(community, levels = rev(focus_communities)))) +
    ggplot2::geom_tile(ggplot2::aes(fill = n_drawn), colour = "white", linewidth = 0.6) +
    ggplot2::geom_text(ggplot2::aes(label = n_drawn), size = 3.2, fontface = "bold",
                       colour = "grey15") +
    ggplot2::scale_fill_gradient(low = "#EFF3FF", high = "#6BAED6", name = "points drawn") +
    ggplot2::scale_x_discrete(position = "top") +
    ggplot2::labs(title = "Points drawn per community × regime band",
                  x = NULL, y = NULL) +
    ggplot2::theme_minimal(base_size = 9) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(face = "bold", size = 9.5),
      panel.grid = ggplot2::element_blank(),
      axis.text.y = ggplot2::element_text(size = 8),
      legend.position = "right"
    )

  bottom <- cowplot::plot_grid(inset_row, summary_plot, ncol = 1, rel_heights = c(1, 0.75))
  full   <- cowplot::plot_grid(main_map, bottom, ncol = 1, rel_heights = c(1.55, 1.35))

  gayini_save_figure(full, out_dir, "F5_stratified_sampling_map_data",
                     kind = "data", width = 11, height = 14)
}
