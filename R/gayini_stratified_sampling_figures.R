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


## Relative-band labelling ----
##
## Regime bands are WITHIN-COMMUNITY terciles, so "high" is a different absolute
## flood frequency in each community (they overlap: Aeolian high ~6-76% vs Inland
## low ~0-19%). Every band figure states this explicitly so the relative choice
## is never merely implied.

gayini_regime_band_legend_title <- function() "Regime band\n(within-community, relative)"


## A compact ggplot "table" of each community's tercile breaks, printed on/beside
## every band figure. breaks_df = regime_band_breaks.csv (community, freq_min_pct,
## tercile_1_pct, tercile_2_pct, freq_max_pct).

gayini_tercile_table_plot <- function(breaks_df,
                                      title = "Within-community tercile breaks — background flood frequency (%)") {

  band_pal <- gayini_regime_band_palette()
  short    <- gayini_gradient_short_labels()

  bd <- breaks_df
  bd$short <- ifelse(!is.na(short[bd$community]), short[bd$community], bd$community)
  n <- nrow(bd)

  ## Explicit x positions so the (long) community names never collide with the
  ## range columns.
  x_comm <- 0.4
  x_band <- c(low = 3.0, mid = 4.0, high = 5.0)

  rng <- function(a, b) sprintf("%.1f–%.1f", a, b)
  cells_ranges <- do.call(rbind, lapply(seq_len(n), function(i) {
    r <- bd[i, ]
    data.frame(
      x = unname(x_band), row = n - i + 1,
      label = c(rng(r$freq_min_pct, r$tercile_1_pct),
                rng(r$tercile_1_pct, r$tercile_2_pct),
                rng(r$tercile_2_pct, r$freq_max_pct))
    )
  }))
  cells_comm <- data.frame(x = x_comm, row = rev(seq_len(n)), label = bd$short)

  header      <- data.frame(x = unname(x_band), row = n + 1, label = c("low", "mid", "high"))
  header_fill <- data.frame(x = unname(x_band), row = n + 1,
                            fill = unname(band_pal[c("low", "mid", "high")]))

  ggplot2::ggplot() +
    ggplot2::geom_tile(data = header_fill, ggplot2::aes(x = x, y = row),
                       fill = header_fill$fill, width = 0.9, height = 0.9, alpha = 0.9) +
    ggplot2::geom_text(data = header, ggplot2::aes(x = x, y = row, label = label),
                       fontface = "bold", size = 3, colour = c("grey20", "white", "white")) +
    ggplot2::annotate("text", x = x_comm, y = n + 1, label = "Community", hjust = 0,
                      fontface = "bold", size = 3, colour = "grey20") +
    ggplot2::geom_text(data = cells_comm, ggplot2::aes(x = x, y = row, label = label),
                       hjust = 0, size = 2.9, colour = "grey20") +
    ggplot2::geom_text(data = cells_ranges, ggplot2::aes(x = x, y = row, label = label),
                       size = 2.9, colour = "grey20") +
    ggplot2::scale_x_continuous(limits = c(0.2, 5.6)) +
    ggplot2::scale_y_continuous(limits = c(0.4, n + 1.7)) +
    ggplot2::labs(title = title,
                  subtitle = "Bands are RELATIVE to each community — they OVERLAP across communities") +
    ggplot2::theme_void(base_size = 10) +
    ggplot2::theme(
      plot.title    = ggplot2::element_text(face = "bold", size = 9.5),
      plot.subtitle = ggplot2::element_text(size = 7.8, colour = "grey35")
    )
}


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
## A 4-panel schematic of the stratified-sampling frame (no real data). The
## conceptual story now runs to the across-draw band, matching the rebalanced
## design ("proportional + repeated"):
##   A · near the plots      — 2 km neighbourhood, footprints + 100 m excluded;
##                             headroom is ample / non-binding (audit result).
##   B · within-community    — ONE community patch split into flood-frequency
##       terciles              terciles (low/mid/high, light->dark) with the
##                             stratified points coloured by band and plot
##                             footprints haloed. Scope = within one community.
##   C · proportional+floor  — ACROSS the three communities: points-per-band
##                             scale with community area (Aeolian ~100 · Riverine
##                             ~270 · Inland ~1,000), a floor of 50 marked. This
##                             is where proportionality lives (terciles within a
##                             community are ~equal area).
##   D · repeat xN seeded    — n_draws (>=100) seeded draws -> each community's
##                             across-draw median flood frequency (Aeolian ~9% ·
##                             Riverine ~22% · Inland ~50%) with a percentile
##                             band; bands OVERLAP (truthful — compare on
##                             frequency). Uncertainty = across-draw spread,
##                             NOT a single-draw CI.
##
## n_draws  : draw count for panel D (a PARAMETER, >= 100; never hardcoded).
## facet_all: panel D shows the 3 community exemplars (FALSE, default) or all 9
##            community x band strata (TRUE).      [FLAGGED OPEN ITEM — default]
## layout   : "grid" (2x2, as mocked; default) or "horizontal" (4-wide strip to
##            match the deck's current F5 slide).  [FLAGGED OPEN ITEM — default]

gayini_build_f5_concept <- function(out_dir, n_draws = 100L,
                                    facet_all = FALSE,
                                    layout = c("grid", "horizontal")) {
  layout <- match.arg(layout)
  stopifnot(n_draws >= 100)

  band_pal  <- gayini_regime_band_palette()
  freq_ramp <- gayini_flood_frequency_ramp()

  ## Community identity for panels C/D (headline gradient palette + medians).
  comm_pal <- gayini_gradient_palette()
  focus    <- gayini_focus_levels()          # dry -> wet, treed community excluded
  comm_df  <- data.frame(
    community = focus,
    short     = c("Aeolian", "Riverine", "Inland"),  # focus is ordered dry -> wet
    median    = c(9, 22, 50),                          # headline community means
    alloc     = c(100, 270, 1000),                     # ~ proportional-to-area target
    colour    = unname(comm_pal[focus]),
    stringsAsFactors = FALSE
  )
  comm_df$short <- factor(comm_df$short, levels = comm_df$short)

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
  halo_rings <- do.call(rbind, lapply(seq_len(nrow(plot_centres)), function(i)
    cbind(id = i, circle(plot_centres$cx[i], plot_centres$cy[i], r = 0.62))))

  patch_rect <- function() ggplot2::annotate("rect", xmin = xlim[1], xmax = xlim[2],
                                              ymin = ylim[1], ymax = ylim[2],
                                              fill = NA, colour = "grey35", linewidth = 0.6)

  base_theme <- ggplot2::theme_void(base_size = 11) +
    ggplot2::theme(plot.subtitle = ggplot2::element_text(face = "bold", size = 10, hjust = 0),
                   plot.caption  = ggplot2::element_text(size = 7, colour = "grey40", hjust = 0),
                   legend.position = "none")

  ## --- Panel A: neighbourhood + exclusion (headroom ample / non-binding) ---
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
    ggplot2::labs(subtitle = "A · Near the plots, minus their footprints",
                  caption = "Candidate headroom is ample — the 2 km neighbourhood is non-binding (audit), not the limiting constraint.") +
    base_theme

  ## --- Panel B: within-community terciles WITH the stratified points ---
  set.seed(1)
  band_pts <- do.call(rbind, lapply(seq_len(nrow(band_bounds)), function(i) {
    bb <- band_bounds[i, ]
    n <- 24
    px <- stats::runif(n, xlim[1] + 0.3, xlim[2] - 0.3)
    py <- stats::runif(n, bb$ymin + 0.25, bb$ymax - 0.25)
    ## drop points that land on a plot footprint (schematic exclusion)
    keep <- rep(TRUE, n)
    for (k in seq_len(nrow(plot_centres))) {
      keep <- keep & sqrt((px - plot_centres$cx[k])^2 + (py - plot_centres$cy[k])^2) > 0.85
    }
    data.frame(x = px[keep], y = py[keep], band = bb$band)
  }))

  panel_b <- ggplot2::ggplot() +
    ggplot2::geom_rect(data = band_bounds,
                       ggplot2::aes(xmin = xlim[1], xmax = xlim[2], ymin = ymin, ymax = ymax),
                       fill = band_bounds$fill, alpha = 0.55) +
    patch_rect() +
    ggplot2::annotate("segment", x = xlim[1], xend = xlim[2], y = 7 / 3, yend = 7 / 3,
                      colour = "white", linewidth = 0.5) +
    ggplot2::annotate("segment", x = xlim[1], xend = xlim[2], y = 14 / 3, yend = 14 / 3,
                      colour = "white", linewidth = 0.5) +
    ## footprint halos, then footprints kept empty over them
    ggplot2::geom_polygon(data = halo_rings,
                          ggplot2::aes(x = x, y = y, group = id),
                          fill = "white", colour = NA, alpha = 0.55) +
    ggplot2::geom_polygon(data = squares,
                          ggplot2::aes(x = x, y = y, group = id),
                          fill = "white", colour = "grey20", linewidth = 0.4) +
    ggplot2::geom_point(data = band_pts, ggplot2::aes(x = x, y = y, colour = band),
                        size = 1.4) +
    ggplot2::scale_colour_manual(values = band_pal) +
    ggplot2::annotate("text", x = 0.4, y = c(7 / 6, 7 / 2, 35 / 6),
                      label = c("low", "mid", "high"), hjust = 0, size = 3.0,
                      fontface = "bold", colour = c("grey25", "grey20", "white")) +
    ggplot2::coord_equal(xlim = xlim, ylim = c(-0.2, 7.2), expand = FALSE) +
    ggplot2::labs(subtitle = "B · Within one community: terciles + stratified points",
                  caption = "Terciles are within THIS community's own flood-frequency range; ~equal area, so bands get ~equal points.") +
    base_theme

  ## --- Panel C: proportional allocation across communities + floor ---
  ## Three community boxes with AREA proportional to allocation, filled at a
  ## constant point density so drawn counts scale with area (proportionality).
  set.seed(7)
  box_side <- sqrt(comm_df$alloc); box_side <- box_side / max(box_side) * 3.2  # tallest ~3.2
  gap <- 0.9
  x0  <- cumsum(c(0, box_side[-length(box_side)] + gap))
  draw_n <- pmax(6, round(comm_df$alloc / 6))   # scaled for legibility; true counts annotated
  boxes  <- do.call(rbind, lapply(seq_len(nrow(comm_df)), function(i) {
    s <- box_side[i]
    data.frame(community = comm_df$short[i],
               xmin = x0[i], xmax = x0[i] + s, ymin = 0, ymax = s,
               colour = comm_df$colour[i])
  }))
  pts_c <- do.call(rbind, lapply(seq_len(nrow(comm_df)), function(i) {
    s <- box_side[i]
    data.frame(community = comm_df$short[i],
               x = stats::runif(draw_n[i], x0[i] + 0.08 * s, x0[i] + 0.92 * s),
               y = stats::runif(draw_n[i], 0.08 * s, 0.92 * s),
               colour = comm_df$colour[i])
  }))
  lab_c <- data.frame(x = x0 + box_side / 2, y = box_side + 0.35,
                      community = comm_df$short,
                      label = sprintf("%s\n~%s pts/band",
                                      comm_df$short, formatC(comm_df$alloc, big.mark = ",", format = "d")),
                      colour = comm_df$colour)
  x_span <- max(x0 + box_side)
  panel_c <- ggplot2::ggplot() +
    ggplot2::geom_rect(data = boxes,
                       ggplot2::aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax),
                       fill = boxes$colour, alpha = 0.12, colour = "grey45", linewidth = 0.4) +
    ggplot2::geom_point(data = pts_c, ggplot2::aes(x = x, y = y),
                        colour = pts_c$colour, size = 0.8, alpha = 0.9) +
    ggplot2::geom_text(data = lab_c, ggplot2::aes(x = x, y = y, label = label),
                       colour = lab_c$colour, fontface = "bold", size = 2.9, lineheight = 0.95) +
    ggplot2::annotate("text", x = 0, y = -0.55, hjust = 0, size = 2.8, colour = "#D7301F",
                      label = "floor = 50 pts/band (small strata bumped up so every band is estimable)") +
    ggplot2::coord_equal(xlim = c(-0.2, x_span + 0.2), ylim = c(-0.9, max(box_side) + 0.9),
                         expand = FALSE) +
    ggplot2::labs(subtitle = "C · Points scale with community area (proportional), floor 50") +
    base_theme

  ## --- Panel D: repeat xN seeded draws -> across-draw percentile band ---
  ## Schematic (no real MC run): seeded draws around each community/stratum's
  ## headline median; the band is the 10-90th percentile ACROSS draws.
  set.seed(20260714)
  draw_band <- function(m, sd_v) {
    d <- pmax(0, pmin(100, stats::rnorm(n_draws, m, sd_v)))
    c(med = stats::median(d), lo = unname(stats::quantile(d, 0.10)),
      hi = unname(stats::quantile(d, 0.90)))
  }
  if (facet_all) {
    ## 9 strata: each community x band, band medians offset around the community median.
    off <- c(low = -0.45, mid = 0, high = 0.55)
    rows <- do.call(rbind, lapply(seq_len(nrow(comm_df)), function(i) {
      do.call(rbind, lapply(names(off), function(b) {
        m  <- max(1, comm_df$median[i] * (1 + off[[b]]))
        st <- draw_band(m, 0.20 * m + 2)
        data.frame(community = comm_df$short[i], band = b,
                   row_lab = sprintf("%s · %s", comm_df$short[i], b),
                   med = st["med"], lo = st["lo"], hi = st["hi"],
                   colour = comm_df$colour[i])
      }))
    }))
    rows$row_lab <- factor(rows$row_lab, levels = rev(rows$row_lab))
    y_aes <- "row_lab"
    d_sub <- "D · Repeat ×N seeded draws — all nine strata (median + 10–90th band)"
  } else {
    rows <- do.call(rbind, lapply(seq_len(nrow(comm_df)), function(i) {
      st <- draw_band(comm_df$median[i], 0.20 * comm_df$median[i] + 2)
      data.frame(community = comm_df$short[i], row_lab = as.character(comm_df$short[i]),
                 med = st["med"], lo = st["lo"], hi = st["hi"], colour = comm_df$colour[i])
    }))
    rows$row_lab <- factor(rows$row_lab, levels = rev(as.character(comm_df$short)))
    y_aes <- "row_lab"
    d_sub <- "D · Repeat ×N seeded draws — across-draw band per community"
  }

  panel_d <- ggplot2::ggplot(rows, ggplot2::aes(y = .data[[y_aes]])) +
    ggplot2::geom_linerange(ggplot2::aes(xmin = lo, xmax = hi),
                            colour = rows$colour, linewidth = 5.5, alpha = 0.30) +
    ggplot2::geom_point(ggplot2::aes(x = med), colour = rows$colour, size = 2.8) +
    ggplot2::geom_text(ggplot2::aes(x = med, label = sprintf("%.0f%%", med)),
                       vjust = -1.1, size = 2.7, colour = "grey20") +
    ggplot2::scale_x_continuous(limits = c(0, 100), name = "Between-year flood frequency (%)") +
    ggplot2::labs(subtitle = d_sub, y = NULL,
                  caption = sprintf("Bands OVERLAP by design (compare on frequency). Spread = across %d seeded draws, NOT a single-draw CI.", n_draws)) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(plot.subtitle = ggplot2::element_text(face = "bold", size = 10, hjust = 0),
                   plot.caption  = ggplot2::element_text(size = 7, colour = "grey40", hjust = 0),
                   panel.grid.major.y = ggplot2::element_blank(),
                   panel.grid.minor = ggplot2::element_blank(),
                   axis.text.y = ggplot2::element_text(face = "bold", colour = "grey20"),
                   legend.position = "none")

  ## --- Compose ---
  title <- cowplot::ggdraw() +
    cowplot::draw_label(
      "F5 concept — the stratified sampling frame (proportional + repeated: community → terciles → area-scaled points → across-draw band)",
      fontface = "bold", size = 12.5, x = 0.01, hjust = 0)

  if (identical(layout, "grid")) {
    body <- cowplot::plot_grid(panel_a, panel_b, panel_c, panel_d,
                               ncol = 2, labels = NULL, rel_widths = c(1, 1))
    concept <- cowplot::plot_grid(title, body, ncol = 1, rel_heights = c(0.06, 1))
    dims <- list(width = 12, height = 9.2)
  } else {
    body <- cowplot::plot_grid(panel_a, panel_b, panel_c, panel_d,
                               ncol = 4, rel_widths = c(1, 1, 1, 1.1))
    concept <- cowplot::plot_grid(title, body, ncol = 1, rel_heights = c(0.10, 1))
    dims <- list(width = 19, height = 4.8)
  }

  gayini_save_figure(concept, out_dir, "F5_stratified_sampling_concept",
                     kind = "concept", width = dims$width, height = dims$height)
}


## F5 data figures — ONE FIGURE = ONE FILE = ONE SLIDE ----
##
## Standing convention (from C3): the whole-property map and the band-reference
## tables are SEPARATE single-slide files. gayini_build_f5_fullfarm_map() is the
## map only; gayini_build_f5_band_reference() is the points matrix + tercile
## table. gayini_build_f5_data() is a thin back-compat wrapper that emits both.


## The one-slide farm overview: surface + band-coloured points + legend + scale
## bar + north arrow ONLY. No tables, no zoom insets.

gayini_build_f5_fullfarm_map <- function(freq_8058,
                                         sample,
                                         boundary,
                                         communities,
                                         plots,
                                         focus_communities,
                                         out_dir) {

  band_pal  <- gayini_regime_band_palette()
  freq_ramp <- gayini_flood_frequency_ramp()

  pts        <- sample$points
  focus_comm <- communities[as.character(communities$simplified_vegetation_group)
                            %in% focus_communities, ]

  bnd_v   <- terra::vect(sf::st_geometry(boundary))
  freq_df <- gayini_raster_to_df(terra::crop(freq_8058, bnd_v), max_cells = 3e5)
  bbox    <- sf::st_bbox(boundary)

  main_map <- ggplot2::ggplot() +
    ggplot2::geom_raster(data = freq_df, ggplot2::aes(x = x, y = y, fill = freq)) +
    ggplot2::scale_fill_gradientn(colours = freq_ramp, limits = c(0, 100),
                                  name = "Background\nflood freq. (%)") +
    ggplot2::geom_sf(data = focus_comm, fill = NA, colour = "grey30", linewidth = 0.3) +
    ggplot2::geom_sf(data = boundary, fill = NA, colour = "grey10", linewidth = 0.6) +
    ggplot2::geom_sf(data = plots, fill = NA, colour = "grey15", linewidth = 0.25) +
    ggplot2::geom_sf(data = pts, ggplot2::aes(colour = regime_band), size = 0.7, alpha = 0.9) +
    ggplot2::scale_colour_manual(values = band_pal, name = gayini_regime_band_legend_title(),
                                 guide = ggplot2::guide_legend(override.aes = list(size = 2.5))) +
    gayini_scalebar_layers(bbox) +
    gayini_north_arrow_layers(bbox) +
    ggplot2::coord_sf(xlim = c(bbox["xmin"], bbox["xmax"]),
                      ylim = c(bbox["ymin"], bbox["ymax"]), expand = FALSE) +
    ggplot2::labs(
      title = "F5 · Stratified sampling frame — whole-farm flood-frequency surface",
      subtitle = "GDA2020 / NSW Lambert (EPSG:8058) · 100 × wet-valid years ÷ valid years, 1988–2023 · points near plots, footprints excluded",
      caption = "Surface = long-run background flood frequency · points coloured by within-community (relative) regime band · plots (outlines) are anchors, not sampled"
    ) +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(
      panel.grid    = ggplot2::element_line(colour = "grey93", linewidth = 0.2),
      plot.title    = ggplot2::element_text(face = "bold", size = 14),
      plot.subtitle = ggplot2::element_text(size = 9.5, colour = "grey30"),
      plot.caption  = ggplot2::element_text(size = 8, colour = "grey40"),
      legend.position = "right"
    )

  paths <- gayini_save_figure(main_map, out_dir, "F5_fullfarm_map_data",
                              kind = "data", width = 12.5, height = 7.2)
  list(png = paths$png, pdf = paths$pdf, has_tables = FALSE)
}


## The one-slide band reference: points-per-community x band matrix + the
## within-community tercile-break table (the "bands are relative / they overlap"
## reference). Its own file.

gayini_build_f5_band_reference <- function(sample_summary,
                                           breaks_df,
                                           focus_communities,
                                           out_dir) {

  summary_plot <- ggplot2::ggplot(
    sample_summary,
    ggplot2::aes(x = regime_band,
                 y = factor(community, levels = rev(focus_communities)))) +
    ggplot2::geom_tile(ggplot2::aes(fill = n_drawn), colour = "white", linewidth = 0.6) +
    ggplot2::geom_text(ggplot2::aes(label = n_drawn), size = 4, fontface = "bold",
                       colour = "grey15") +
    ggplot2::scale_fill_gradient(low = "#EFF3FF", high = "#6BAED6", name = "points drawn") +
    ggplot2::scale_x_discrete(position = "top") +
    ggplot2::labs(title = "Points drawn per community × regime band", x = NULL, y = NULL) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      plot.title  = ggplot2::element_text(face = "bold", size = 11),
      panel.grid  = ggplot2::element_blank(),
      axis.text.y = ggplot2::element_text(size = 9),
      axis.text.x = ggplot2::element_text(size = 10),
      legend.position = "right"
    )

  body <- cowplot::plot_grid(summary_plot, gayini_tercile_table_plot(breaks_df),
                             ncol = 2, rel_widths = c(1, 1.2))

  title <- cowplot::ggdraw() +
    cowplot::draw_label(
      "F5 · Band reference — how many points per stratum, and what each community's terciles mean",
      fontface = "bold", size = 13, x = 0.01, hjust = 0)

  full <- cowplot::plot_grid(title, body, ncol = 1, rel_heights = c(0.1, 1))

  gayini_save_figure(full, out_dir, "F5_band_reference_data",
                     kind = "data", width = 12.5, height = 5.4)
}


## Back-compat wrapper: emits both single-slide files (used by the F5 sampling
## script, which predates the split). Returns the farm-map paths.

gayini_build_f5_data <- function(freq_8058,
                                 sample,
                                 boundary,
                                 communities,
                                 plots,
                                 focus_communities,
                                 out_dir,
                                 breaks_df = NULL) {

  farm <- gayini_build_f5_fullfarm_map(freq_8058, sample, boundary, communities,
                                       plots, focus_communities, out_dir)
  if (!is.null(breaks_df)) {
    gayini_build_f5_band_reference(sample$summary, breaks_df, focus_communities, out_dir)
  }
  farm
}
