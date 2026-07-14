####################################################################################################


## GAYINI REMOTE SENSING PROJECT


## Reusable area-map composer (refactored out of the F5c paddock zooms).
##
## ONE function draws every "area map" in the deck: a background raster fill
## (continuous flood-frequency ramp OR a discrete bivariate class), a heavy focus
## outline, light neighbouring paddocks, optional overlay points, a property-scale
## locator inset, and reserved title / map / caption bands so the inset can never
## collide with text (ONE FIGURE = ONE FILE = ONE SLIDE). F5c, the C1 checkerboard,
## and the D1/D2 dashboards all call this — the plot code is not forked.
##
## Depends on gayini_raster_to_df (continuous) + terra/sf/ggplot2/cowplot.


####################################################################################################


`%||%` <- function(a, b) if (is.null(a)) b else a


## Raster -> ggplot-ready df, category-aware. Continuous layers aggregate by mean
## (as gayini_raster_to_df does); discrete class layers aggregate by MODE so class
## codes are never blended. Value column is always named "value".

gayini_raster_to_df_generic <- function(r, max_cells = 4e5, discrete = FALSE) {
  ## Strip any category/colour table so we work in NUMERIC codes, not factor
  ## labels (terra::as.data.frame would otherwise return the labels for a
  ## categorical raster, breaking the code-keyed fill join).
  if (discrete) {
    levels(r) <- NULL
    terra::coltab(r) <- NULL
  }
  if (terra::ncell(r) > max_cells) {
    fact <- ceiling(sqrt(terra::ncell(r) / max_cells))
    r <- terra::aggregate(r, fact = fact,
                          fun = if (discrete) "modal" else "mean", na.rm = TRUE)
  }
  df <- terra::as.data.frame(r, xy = TRUE, na.rm = TRUE)
  names(df)[3] <- "value"
  df
}


## The bare map (no title/inset/caption bands) — the reusable core every map
## panel draws. Returns a single ggplot. Dashboard map panels (gayini_panel_map)
## call this directly; gayini_plot_area_map() below wraps it with the slide
## title / locator-inset / caption bands.
##
## area       : sf polygon(s) defining the focus area (paddock, or the boundary
##              for the whole-farm map). Drives the view bbox + default outline.
## fill_layer : SpatRaster rendered as the background fill.
## fill_spec  : list(kind = "continuous"|"discrete", ...).
##                continuous -> colours, limits, name (colourbar drawn).
##                discrete   -> classes (data.frame code,label,colour), name;
##                              default fill legend suppressed (use legend_grob).
## points/points_spec : optional sf overlay + list(field, palette, name, size).
## neighbours : sf drawn light for context (NULL to omit).
## outline    : sf drawn heavy (defaults to `area`; NULL to omit).
## extra_layers : optional list of ggplot layers appended after the base layers
##                (e.g. a site radius ring, a stratum class highlight).
## base_size / legend_position : let a compact dashboard panel shrink the map.

gayini_area_map_core <- function(area,
                                 fill_layer,
                                 fill_spec,
                                 points          = NULL,
                                 points_spec     = NULL,
                                 neighbours      = NULL,
                                 outline         = area,
                                 pad_buffer      = 400,
                                 extra_layers    = NULL,
                                 base_size       = 10,
                                 legend_position = "right") {

  discrete <- identical(fill_spec$kind, "discrete")

  ## View window = area bbox + buffer; crop the fill to it.
  z    <- sf::st_bbox(sf::st_buffer(sf::st_geometry(area), pad_buffer))
  clip <- terra::ext(z["xmin"], z["xmax"], z["ymin"], z["ymax"])
  fr   <- terra::crop(fill_layer, clip)
  df   <- gayini_raster_to_df_generic(fr, max_cells = fill_spec$max_cells %||% 4e5,
                                      discrete = discrete)

  map_core <- ggplot2::ggplot()

  if (discrete) {
    cls <- fill_spec$classes
    df$fill_lab <- factor(cls$label[match(df$value, cls$code)], levels = cls$label)
    map_core <- map_core +
      ggplot2::geom_raster(data = df, ggplot2::aes(x = x, y = y, fill = fill_lab)) +
      ggplot2::scale_fill_manual(values = stats::setNames(cls$colour, cls$label),
                                 drop = FALSE, na.value = NA, guide = "none")
  } else {
    map_core <- map_core +
      ggplot2::geom_raster(data = df, ggplot2::aes(x = x, y = y, fill = value)) +
      ggplot2::scale_fill_gradientn(colours = fill_spec$colours, limits = fill_spec$limits,
                                    name = fill_spec$name,
                                    guide = ggplot2::guide_colourbar(barwidth = 0.6, barheight = 4))
  }

  if (!is.null(neighbours))
    map_core <- map_core +
      ggplot2::geom_sf(data = neighbours, fill = NA, colour = "grey70", linewidth = 0.2)

  if (!is.null(outline))
    map_core <- map_core +
      ggplot2::geom_sf(data = outline, fill = NA, colour = "grey10", linewidth = 0.9)

  if (!is.null(points) && nrow(points) > 0) {
    map_core <- map_core +
      ggplot2::geom_sf(data = points,
                       ggplot2::aes(colour = .data[[points_spec$field]]),
                       size = points_spec$size %||% 1.8) +
      ggplot2::scale_colour_manual(values = points_spec$palette,
                                   name = points_spec$name,
                                   guide = ggplot2::guide_legend(override.aes = list(size = 2.5)))
  }

  ## Caller-supplied extra layers (radius ring, class highlight, unit marker...).
  if (!is.null(extra_layers)) for (ly in extra_layers) map_core <- map_core + ly

  map_core +
    ggplot2::coord_sf(xlim = c(z["xmin"], z["xmax"]), ylim = c(z["ymin"], z["ymax"]),
                      expand = FALSE) +
    ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      panel.grid = ggplot2::element_line(colour = "grey93", linewidth = 0.2),
      axis.title = ggplot2::element_blank(),
      legend.position = legend_position
    )
}


## Property-scale farm-locator inset: the whole property (all paddocks faint,
## boundary heavier) with THIS unit filled red. A theme_void mini-map for the
## top-left of a big map (site / paddock dashboards). Reused by gayini_plot_area_map
## (slide inset) and gayini_panel_map (dashboard inset).

gayini_locator_inset <- function(area, boundary, management = NULL) {
  g <- ggplot2::ggplot()
  if (!is.null(management))
    g <- g + ggplot2::geom_sf(data = management, fill = NA, colour = "grey80", linewidth = 0.15)
  g +
    ggplot2::geom_sf(data = boundary, fill = NA, colour = "grey40", linewidth = 0.4) +
    ggplot2::geom_sf(data = area, fill = "#D7301F", colour = "#D7301F", alpha = 0.7) +
    ggplot2::coord_sf(expand = FALSE) +
    ggplot2::theme_void() +
    ggplot2::theme(panel.background = ggplot2::element_rect(fill = "white", colour = "grey60",
                                                           linewidth = 0.4))
}


## The reusable area map (title / locator-inset / caption composed around the core).
##
## boundary/management : property boundary + all paddocks, for the locator inset.
## legend_grob: optional grob placed to the right of the map (e.g. 3x3 bivariate).
##
## Returns list(plot, overlap) and, if out_dir+basename given, saved paths.

gayini_plot_area_map <- function(area,
                                 fill_layer,
                                 fill_spec,
                                 boundary,
                                 management  = NULL,
                                 points      = NULL,
                                 points_spec = NULL,
                                 neighbours  = NULL,
                                 outline     = area,
                                 pad_buffer  = 400,
                                 title       = NULL,
                                 subtitle    = NULL,
                                 caption     = NULL,
                                 inset       = TRUE,
                                 legend_grob = NULL,
                                 out_dir     = NULL,
                                 basename    = NULL,
                                 width       = 9,
                                 height      = 7) {

  ## The bare map (all fill / outline / neighbour / point logic lives in the core).
  map_core <- gayini_area_map_core(
    area = area, fill_layer = fill_layer, fill_spec = fill_spec,
    points = points, points_spec = points_spec, neighbours = neighbours,
    outline = outline, pad_buffer = pad_buffer)

  ## View window (recomputed here for the inset-overlap geometry below).
  z <- sf::st_bbox(sf::st_buffer(sf::st_geometry(area), pad_buffer))

  ## ---- Layout bands (identical geometry to the F5c original) ----
  rh_title <- 0.14; rh_map <- 1.0; rh_cap <- 0.05
  tot      <- rh_title + rh_map + rh_cap
  cap_band_hi   <- rh_cap / tot
  map_band_lo   <- rh_cap / tot
  map_band_hi   <- (rh_cap + rh_map) / tot
  title_band_lo <- (rh_cap + rh_map) / tot
  ins_local_y0 <- 0.64; ins_local_h <- 0.30
  ins_local_x0 <- 0.02; ins_local_w <- 0.28

  map_with_inset <- cowplot::ggdraw(map_core)
  if (inset) {
    if (is.null(management))
      stop("gayini_plot_area_map: inset = TRUE requires `management`.", call. = FALSE)
    locator <- gayini_locator_inset(area, boundary, management)
    map_with_inset <- map_with_inset +
      cowplot::draw_plot(locator, x = ins_local_x0, y = ins_local_y0,
                         width = ins_local_w, height = ins_local_h)
  }

  ## Optional legend grob (e.g. the 3x3 bivariate key) to the right of the map.
  map_row <- if (!is.null(legend_grob)) {
    cowplot::plot_grid(map_with_inset, legend_grob, ncol = 2, rel_widths = c(1, 0.36))
  } else map_with_inset

  title_strip <- cowplot::ggdraw() +
    cowplot::draw_label(title %||% "", fontface = "bold", size = 12,
                        x = 0.01, hjust = 0, y = 0.70) +
    cowplot::draw_label(subtitle %||% "", size = 8.5, colour = "grey30",
                        x = 0.01, hjust = 0, y = 0.28)
  caption_strip <- cowplot::ggdraw() +
    cowplot::draw_label(caption %||% "", size = 7.5, colour = "grey40",
                        x = 0.01, hjust = 0)

  composed <- cowplot::plot_grid(title_strip, map_row, caption_strip,
                                 ncol = 1, rel_heights = c(rh_title, rh_map, rh_cap))

  ## Inset-overlap check (y-bands only; a right legend column doesn't affect it).
  ins_ymin <- map_band_lo + ins_local_y0 * (map_band_hi - map_band_lo)
  ins_ymax <- map_band_lo + (ins_local_y0 + ins_local_h) * (map_band_hi - map_band_lo)
  overlap <- tibble::tibble(
    inset_drawn     = inset,
    inset_ymin      = round(ins_ymin, 3),
    inset_ymax      = round(ins_ymax, 3),
    title_band_lo   = round(title_band_lo, 3),
    caption_band_hi = round(cap_band_hi, 3),
    clears_title    = !inset || ins_ymax < title_band_lo,
    clears_caption  = !inset || ins_ymin > cap_band_hi,
    clear           = !inset || ((ins_ymax < title_band_lo) && (ins_ymin > cap_band_hi))
  )

  paths <- NULL
  if (!is.null(out_dir) && !is.null(basename)) {
    paths <- gayini_save_figure(composed, out_dir, basename, kind = "data",
                                width = width, height = height)
  }

  list(plot = composed, overlap = overlap, paths = paths)
}
