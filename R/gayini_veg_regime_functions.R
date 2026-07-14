####################################################################################################


## GAYINI REMOTE SENSING PROJECT


## Tier 1 · Task C1 — vegetation x wetness "checkerboard".
##
## Per-pixel (community x within-community wetness tercile) class raster + the
## fixed bivariate palette + the 3x3 legend grob. The class raster is built with
## the SAME support threshold (>= 25/35 valid years) and the SAME tercile breaks
## (regime_band_breaks.csv) as v_pixel_census_by_veg_regime, so per-class pixel
## counts reconcile EXACTLY to the census view.
##
## Bivariate scheme (community = hue, wetness = light -> dark), fixed in the spec;
## do not recompute. Woodland/Forest = muted grey single-shade context; Other/
## minor = light neutral. See [[gayini-tier1-pixel-census]].


####################################################################################################


## Fixed class table: code, community, band, label, colour. Codes are
## community(1..5) x 10 + band(1..3); context communities have band 0.

gayini_veg_regime_classes <- function() {
  focus <- gayini_focus_levels()   # Aeolian, Riverine, Inland (gradient order)
  tibble::tribble(
    ~code, ~community,   ~band,      ~colour,
    11L, focus[1],       "low",      "#E5D3A0",
    12L, focus[1],       "mid",      "#C79A3C",
    13L, focus[1],       "high",     "#8F6E24",
    21L, focus[2],       "low",      "#B3E0D6",
    22L, focus[2],       "mid",      "#3FAE97",
    23L, focus[2],       "high",     "#27725F",
    31L, focus[3],       "low",      "#AAC6E4",
    32L, focus[3],       "mid",      "#2E6DB0",
    33L, focus[3],       "high",     "#1B4270",
    40L, "Floodplain Woodland / Forest", "context", "#9E9E9E",
    50L, "Other / minor units",         "context", "#E0E0E0"
  ) |>
    dplyr::mutate(
      short = ifelse(.data$band == "context",
                     ifelse(.data$code == 40L, "Woodland (context)", "Other / minor"),
                     paste0(gayini_gradient_short_labels()[.data$community], " · ", .data$band)),
      label = ifelse(.data$band == "context",
                     ifelse(.data$code == 40L, "Woodland (context)", "Other / minor"),
                     paste0(.data$community, " · ", .data$band))
    )
}


## Named colour vector keyed by class label (for scale_fill_manual).
gayini_veg_regime_fill_values <- function(classes = gayini_veg_regime_classes()) {
  stats::setNames(classes$colour, classes$label)
}


## Build the per-pixel class raster (categorical, with a RAT).
##
## freq_8058 : background flood-frequency surface, already >= min_valid_years
##             masked (non-NA == valid), EPSG:8058.
## communities: sf of vegetation-community polygons (partition of the farm).
## breaks     : named list per focus community of c(min, q1, q2, max) edges.

gayini_build_veg_regime_class <- function(freq_8058, communities, breaks,
                                          focus_communities) {

  classes    <- gayini_veg_regime_classes()
  comm_order <- c(focus_communities, "Floodplain Woodland / Forest", "Other / minor units")

  comm_v <- terra::vect(communities)
  comm_v$.cid <- as.integer(factor(as.character(comm_v$simplified_vegetation_group),
                                   levels = comm_order))
  comm_r <- terra::rasterize(comm_v, freq_8058, field = ".cid")

  cid  <- terra::values(comm_r)[, 1]
  fr   <- terra::values(freq_8058)[, 1]
  code <- rep(NA_integer_, length(cid))

  ## Valid, in-a-community pixels only (cid is NA outside the farm veg map).
  in_comm <- !is.na(fr) & !is.na(cid)

  ## Focus communities: valid pixel -> community*10 + band (findInterval terciles).
  for (gi in seq_along(focus_communities)) {
    g   <- focus_communities[gi]
    br  <- breaks[[g]]
    sel <- in_comm & cid == gi
    band <- findInterval(fr[sel], c(br[2], br[3]))        # 0 / 1 / 2
    code[sel] <- gi * 10L + pmin(band + 1L, 3L)
  }
  ## Context communities: single class, valid pixels only.
  code[in_comm & cid == 4L] <- 40L
  code[in_comm & cid == 5L] <- 50L

  class_r <- terra::setValues(terra::rast(freq_8058), code)
  names(class_r) <- "veg_regime_class"

  ## Attach a raster attribute table + colour table so the tif is self-describing.
  present <- classes[classes$code %in% sort(unique(stats::na.omit(code))), ]
  levels(class_r) <- data.frame(value = present$code, veg_regime_class = present$label)
  ct <- data.frame(value = present$code,
                   t(grDevices::col2rgb(present$colour, alpha = TRUE)))
  names(ct) <- c("value", "red", "green", "blue", "alpha")
  terra::coltab(class_r) <- ct

  class_r
}


## Tabulate class-raster pixel counts per (community x band), matched to the
## census view's row keys for reconciliation.
gayini_veg_regime_class_counts <- function(class_r,
                                           classes = gayini_veg_regime_classes()) {
  ## Strip categories so freq() reports numeric class codes, not factor labels.
  r2 <- class_r
  levels(r2) <- NULL
  terra::coltab(r2) <- NULL
  ft <- terra::freq(r2)                            # value, count (per class code)
  out <- dplyr::left_join(classes, tibble::tibble(code = as.integer(ft$value),
                                                  n_pixels = as.numeric(ft$count)),
                          by = "code")
  out$n_pixels[is.na(out$n_pixels)] <- 0
  out[, c("code", "community", "band", "n_pixels")]
}


## 3x3 bivariate legend grob (rows = community, cols = low/mid/high) + the two
## context swatches beneath. Matches the deck concept slide.

gayini_bivariate_legend <- function(classes = gayini_veg_regime_classes()) {

  focus <- gayini_focus_levels()
  grid9 <- classes[classes$band %in% c("low", "mid", "high"), ]
  grid9$community <- factor(grid9$community, levels = rev(focus))         # Inland top
  grid9$band      <- factor(grid9$band, levels = c("low", "mid", "high"))
  grid9$comm_lab  <- gayini_gradient_short_labels()[as.character(grid9$community)]
  grid9$comm_lab  <- factor(grid9$comm_lab,
                            levels = gayini_gradient_short_labels()[as.character(rev(focus))])

  ctx <- classes[classes$band == "context", ]
  ctx$x   <- seq_len(nrow(ctx))

  key <- ggplot2::ggplot(grid9, ggplot2::aes(x = band, y = comm_lab, fill = I(colour))) +
    ggplot2::geom_tile(colour = "white", linewidth = 1.1) +
    ggplot2::scale_x_discrete(position = "top") +
    ggplot2::labs(title = "Community x wetness",
                  subtitle = "within-community band (low -> high)",
                  x = NULL, y = NULL) +
    ggplot2::coord_equal(clip = "off") +
    ggplot2::theme_minimal(base_size = 9) +
    ggplot2::theme(
      plot.title    = ggplot2::element_text(face = "bold", size = 9.5, hjust = 0),
      plot.subtitle = ggplot2::element_text(size = 7, colour = "grey30", hjust = 0),
      axis.text     = ggplot2::element_text(size = 8, colour = "grey15"),
      panel.grid    = ggplot2::element_blank(),
      plot.margin   = ggplot2::margin(4, 10, 4, 4)
    )

  ctx_key <- ggplot2::ggplot(ctx, ggplot2::aes(x = x, y = 1, fill = I(colour))) +
    ggplot2::geom_tile(colour = "white", linewidth = 1.1, width = 0.96) +
    ggplot2::geom_text(ggplot2::aes(label = short), size = 2.6, colour = "grey15",
                       nudge_y = -0.8) +
    ggplot2::coord_equal(clip = "off") +
    ggplot2::labs(title = "Context (unbanded)", x = NULL, y = NULL) +
    ggplot2::theme_void(base_size = 9) +
    ggplot2::theme(plot.title = ggplot2::element_text(size = 8, colour = "grey30", hjust = 0),
                   plot.margin = ggplot2::margin(2, 2, 10, 2))

  cowplot::plot_grid(key, ctx_key, ncol = 1, rel_heights = c(1, 0.5))
}


## Compact 3x3 community x wetness key for a dashboard map panel (paddock
## checkerboard). Three focus communities (rows) x low/mid/high band (cols),
## grey context noted in the caption. Small footprint so it can sit in a strip
## under the map or beside it without stealing map width.

gayini_bivariate_legend_mini <- function(classes = gayini_veg_regime_classes()) {
  focus <- gayini_focus_levels()
  short <- stats::setNames(c("Aeolian (dry)", "Riverine", "Inland (wet)"), focus)

  g <- classes[classes$band %in% c("low", "mid", "high"), ]
  g$clab <- factor(short[as.character(g$community)], levels = rev(short[focus]))
  g$band <- factor(g$band, levels = c("low", "mid", "high"))

  ggplot2::ggplot(g, ggplot2::aes(x = band, y = clab, fill = I(colour))) +
    ggplot2::geom_tile(colour = "white", linewidth = 0.8) +
    ggplot2::scale_x_discrete(position = "top") +
    ggplot2::labs(title = "Community x\nwetness", x = NULL, y = NULL,
                  caption = "grey = Woodland /\nOther (context)") +
    ggplot2::coord_equal(clip = "off") +
    ggplot2::theme_minimal(base_size = 7) +
    ggplot2::theme(
      plot.title   = ggplot2::element_text(face = "bold", size = 7.5, hjust = 0),
      axis.text.x  = ggplot2::element_text(size = 6.5, colour = "grey15"),
      axis.text.y  = ggplot2::element_text(size = 6.5, colour = "grey15"),
      panel.grid   = ggplot2::element_blank(),
      plot.caption = ggplot2::element_text(size = 5.5, colour = "grey40", hjust = 0),
      plot.margin  = ggplot2::margin(2, 4, 2, 2)
    )
}
