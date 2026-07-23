# ------------------------------------------------------------------------------
# Task L — veg×water census panels. Propagates the Gate E GAM-cloud
# (scripts/03_inundation_products/26_build_veg_water_scatter_deck.R) to units.
#
# RASTER path: the substrate is re-derived from the three rasters — identical to
# the Gate E script — not the parquet (no arrow/duckdb in R). Numbers reconcile to
# the parquet by construction (same rasters). Marker = MEAN over the unit's own
# census pixels (median printed alongside); both functions filter !is.na(veg_p05).
#
# gayini_canonical_paddocks()                 — the pinned 21 (C1 set), never the 64-zone layer.
# gayini_census_context()                     — substrate + per-community p05 cloud/GAM cache.
# gayini_unit_census_marker()                 — mean/median over a unit's own pixels.
# gayini_veg_water_community_marker_panel()   — (a) shared dashboard panel, sites + paddocks.
# gayini_paddock_own_cloud()                  — (b) paddock report centrepiece.
# ------------------------------------------------------------------------------

FOCUS_CODES_L <- c(11L,12L,13L,21L,22L,23L,31L,32L,33L)
MIN_BIN_N_L   <- 500L
GAM_SAMPLE_L  <- 40000L
SEED_L        <- 20260721L
MARKER_FILL   <- "#D7263D"   # red diamond, matches the "where it sits" convention

## The pinned canonical 21 paddocks — the C1 checkerboard set. NOT the 64-zone
## management layer (deriving from the layer silently triples the build). ----
gayini_canonical_paddocks <- function() {
  c("Bala 6","Bala 12","Bala 17","Bala 19","Bala 20","Bala 21","Bala 23",
    "Bala 26ca","Bala 28ca","Bala 29ca","Bala 8/11","Dinan 1","Dinan 3",
    "Dinan 6","Dinan 8","Dinan 10","Dinan 12","Mara 7","Mara 8","Mara 13","Mara 21")
}

## Fit one community GAM (Gate E recipe: 5-pp bin cutoff, 40k sample, k=10, REML). ----
## Returns the GAM prediction frame, or NULL when the sample has too few unique
## flood-frequency values to fit a smooth (a thin second community in a paddock —
## the caller draws density only for it). Full-community fits (nuf≈36) are k=10 as
## in Gate E; k is capped only when the subset can't support it.
gayini_fit_community_gam <- function(d) {
  d <- d[!is.na(d$y) & !is.na(d$flood_freq_pct), ]
  b  <- cut(d$flood_freq_pct, breaks = seq(0, 100, 5), include.lowest = TRUE)
  ct <- as.data.frame(table(b)); ct$upper <- seq(5, 100, 5)
  ## DENSITY-ONLY when no flood-freq bin clears the support floor. The old ELSE
  ## branch (fit the FULL range when NO bin >=500) inverted the safeguard — it fit
  ## a k=10 spline across 1–23 points per sparse bin, fabricating an oscillation
  ## exactly where support was worst (Mara 7 Riverine etc). Return NULL → the
  ## caller draws density only. Full communities always have >=500 low-flood bins,
  ## so their cloud/marker lines are unaffected; only thin within-paddock subsets are.
  if (!any(ct$Freq >= MIN_BIN_N_L)) return(NULL)
  cut_ff <- max(ct$upper[ct$Freq >= MIN_BIN_N_L])
  s   <- d[sample.int(nrow(d), min(GAM_SAMPLE_L, nrow(d))), ]
  nuf <- length(unique(s$flood_freq_pct))
  if (nuf < 6) return(NULL)                     # too few unique x for a stable smooth
  k_use <- min(10L, nuf - 1L)                   # mgcv needs k < unique covariate combinations
  g  <- mgcv::gam(y ~ s(flood_freq_pct, k = k_use), data = s, method = "REML")
  grid <- data.frame(flood_freq_pct = seq(0, cut_ff, length.out = 200))
  pr <- predict(g, newdata = grid, se.fit = TRUE)
  data.frame(flood_freq_pct = grid$flood_freq_pct, fit = pr$fit,
             lo = pr$fit - 1.96 * pr$se.fit, hi = pr$fit + 1.96 * pr$se.fit, cut_ff = cut_ff)
}

## Context: derive the census substrate from rasters once; cache the per-community
## p05 cloud + GAM so every unit panel reuses one fit per community (not per render). ----
gayini_census_context <- function(root, metric = "p05") {
  rd   <- file.path(root, "Output", "rasters")
  vp   <- file.path(rd, "veg_percentiles_8058")
  sdir <- file.path(rd, "inundation_annual_stack_8058")
  wet  <- terra::rast(file.path(sdir, "annual_wet_any_1988_2023_8058.tif"))
  val  <- terra::rast(file.path(sdir, "annual_valid_any_1988_2023_8058.tif"))
  cls  <- terra::rast(file.path(rd, "veg_regime_class_8058.tif"))
  levels(cls) <- NULL; terra::coltab(cls) <- NULL
  p05  <- terra::rast(file.path(vp, "total_veg_p05_8058.tif"))
  p50  <- terra::rast(file.path(vp, "total_veg_p50_8058.tif"))
  for (r in list(wet, val, p05, p50))
    stopifnot(isTRUE(terra::compareGeom(r, cls, lyrs = FALSE, crs = TRUE, ext = TRUE,
                                        rowcol = TRUE, res = TRUE, stopOnError = FALSE)))
  wet_sum <- terra::app(wet, "sum", na.rm = TRUE); names(wet_sum) <- "wet_sum"
  val_sum <- terra::app(val, "sum", na.rm = TRUE); names(val_sum) <- "val_sum"
  freq    <- 100 * wet_sum / val_sum;              names(freq)    <- "flood_freq_pct"
  names(p05) <- "p05"; names(p50) <- "p50"; names(cls) <- "code"

  classes   <- gayini_veg_regime_classes()
  code_comm <- classes |> dplyr::filter(.data$band != "context") |> dplyr::transmute(code, community)
  focus     <- gayini_focus_levels()
  fr <- terra::values(c(cls, freq, p05, p50))
  colnames(fr) <- c("code", "flood_freq_pct", "p05", "p50")
  fr <- as.data.frame(fr) |>
    dplyr::filter(.data$code %in% FOCUS_CODES_L, !is.na(.data$flood_freq_pct)) |>
    dplyr::left_join(code_comm, by = "code") |>
    dplyr::mutate(community = factor(community, levels = focus))
  comm_hue <- classes |> dplyr::filter(.data$band == "mid") |>
    (\(x) stats::setNames(x$colour, x$community))()

  ## Per-community cloud + GAM cache for the headline metric.
  cloud <- stats::setNames(lapply(focus, function(cm) {
    d0 <- fr[fr$community == cm, c("flood_freq_pct", metric)]
    names(d0)[2] <- "y"; d0 <- d0[!is.na(d0$y), ]
    set.seed(SEED_L)
    list(d0 = d0, gam = gayini_fit_community_gam(d0),
         y_top = min(100, ceiling(stats::quantile(d0$y, 0.999) / 10) * 10))
  }), focus)

  list(freq = freq, p05 = p05, p50 = p50, code = cls, wet_sum = wet_sum, val_sum = val_sum,
       fr = fr, code_comm = code_comm, comm_hue = comm_hue, focus = focus, metric = metric,
       cloud = cloud, short = gayini_gradient_short_labels())
}

## Marker = census aggregate over the unit's OWN pixels (dominant community, NaN-filtered). ----
gayini_unit_census_marker <- function(unit_geom_8058, community, cc, metric = cc$metric) {
  v  <- terra::vect(sf::st_geometry(unit_geom_8058))
  st <- c(cc$code, cc$freq, cc[[metric]], cc$wet_sum, cc$val_sum)
  names(st) <- c("code", "flood_freq_pct", "y", "wet_sum", "val_sum")
  ex <- terra::extract(st, v, ID = FALSE)
  keep_codes <- cc$code_comm$code[cc$code_comm$community == community]
  ex <- ex[ex$code %in% keep_codes & !is.na(ex$y) & !is.na(ex$flood_freq_pct), , drop = FALSE]
  list(n = nrow(ex),
       x_mean = mean(ex$flood_freq_pct), x_med = stats::median(ex$flood_freq_pct),
       y_mean = mean(ex$y),              y_med = stats::median(ex$y),
       poly_freq = 100 * sum(ex$wet_sum) / sum(ex$val_sum))
}

## Shared theme for the census panels (works in-grid and standalone). ----
gayini_census_panel_theme <- function(base_size = 10) {
  ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      plot.title    = ggplot2::element_text(face = "bold", size = base_size + 1),
      plot.subtitle = ggplot2::element_text(size = base_size - 1.5, colour = "grey30",
                                            margin = ggplot2::margin(b = 5)),
      plot.caption  = ggplot2::element_text(size = base_size - 2.6, colour = "grey35", hjust = 0,
                                            margin = ggplot2::margin(t = 7)),
      plot.caption.position = "plot", plot.title.position = "plot",
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major = ggplot2::element_line(colour = "grey92"),
      legend.position = "none",
      axis.title = ggplot2::element_text(size = base_size - 1.5))
}

# Two honesty lines, each short enough to fit a 7.2-in figure width without clipping.
HONESTY1 <- "~1M pixels = SAMPLING uncertainty only, NOT independent n (spatial autocorrelation)."
HONESTY2 <- "Landsat FC measures cover, not ecological condition — a narrow band is not certainty."

## (a) Community cloud + unit marker — shared, sites AND paddocks. ----
##   context_note : appended to the subtitle (paddocks: "shown on X — Y% of this paddock").
##   title_flag   : appended to the title (Mara-13-style majority-Woodland flag).
##   haze_geom : optional polygon (a site's paddock) whose community pixels are
##               drawn as a translucent hue "region" (V2) nested in the cloud —
##               community (grey) → paddock (haze) → site marker. NULL = no haze.
gayini_veg_water_community_marker_panel <- function(unit_geom_8058, community, cc,
                                                    unit_label, base_size = 10,
                                                    context_note = NULL, title_flag = NULL,
                                                    haze_geom = NULL) {
  hue <- unname(cc$comm_hue[community]); csl <- unname(cc$short[community])
  cl  <- cc$cloud[[community]]
  d0  <- cl$d0; gam_df <- cl$gam; y_top <- cl$y_top

  mk  <- gayini_unit_census_marker(unit_geom_8058, community, cc)
  has_marker <- mk$n > 0 && is.finite(mk$x_mean) && is.finite(mk$y_mean)
  lab <- if (has_marker)
    sprintf("%s\nflood freq %.1f%%  ·  floor %.0f%%\nn = %s census px",
            unit_label, mk$x_mean, mk$y_mean, format(mk$n, big.mark = ","))
  else  # graceful degradation: footprint has no census pixels of this community (edge/unmapped)
    sprintf("%s\nno census pixels of this community\nin the footprint (edge / unmapped)", unit_label)

  ## (c) V2 paddock haze — the site's paddock's community pixels as a translucent
  ## hue region (constant fill, alpha-stacked). Skips cleanly if no paddock / too thin.
  haze_layer <- NULL; has_haze <- FALSE
  if (!is.null(haze_geom)) {
    hx <- terra::extract(c(cc$code, cc$freq, cc[[cc$metric]]),
                         terra::vect(sf::st_geometry(haze_geom)), ID = FALSE)
    names(hx) <- c("code", "flood_freq_pct", "y")
    keep <- cc$code_comm$code[cc$code_comm$community == community]
    hx <- hx[hx$code %in% keep & !is.na(hx$y) & !is.na(hx$flood_freq_pct), , drop = FALSE]
    if (nrow(hx) >= 50 && length(unique(hx$flood_freq_pct)) >= 4) {
      has_haze <- TRUE
      haze_layer <- ggplot2::stat_density_2d(data = hx, inherit.aes = FALSE,
                       ggplot2::aes(flood_freq_pct, y), geom = "polygon", bins = 5,
                       fill = hue, colour = NA, alpha = 0.20)   # Gate 3.1: 0.15 -> 0.20 (in-grid legibility)
    }
  }

  title <- if (is.null(title_flag)) "Vegetation response — where this unit sits on its community"
           else paste0("Vegetation response — ", title_flag)
  subtitle <- if (has_haze)
    sprintf("Grey = %s community; shaded = this site's paddock; line = GAM floor ±95%% CI; red ◆ = this site.", csl)
  else sprintf("Grey = %s census pixels; line = GAM floor ±95%% CI; red ◆ = this unit.", csl)
  if (!is.null(context_note)) subtitle <- paste0(subtitle, "\n", context_note, ".")   # 2nd line: avoids in-grid clip

  ## (d) caption: support + sparse-tail note (+ thin-n note when the marker rests
  ## on ≤5 census pixels) + the two honesty lines.
  cap <- c("Pixel census, between-year flood frequency (24.97 m). Marker = mean over the unit's census pixels.",
           "Dashed line = sparse-tail boundary: GAM floor trend fit only to its left (≥500 community pixels per flood-freq bin).",
           HONESTY1, HONESTY2)
  if (has_marker && mk$n <= 5)
    cap <- append(cap, sprintf("Marker rests on only %d census pixels — a very small footprint sample.", mk$n), after = 1)

  p <- ggplot2::ggplot(d0, ggplot2::aes(flood_freq_pct, y)) +
    ggplot2::geom_bin2d(bins = c(60, 50)) +
    ggplot2::scale_fill_gradient(low = "grey88", high = "grey30", trans = "log10", guide = "none") +
    haze_layer +                                            # NULL is a no-op in ggplot2
    ggplot2::geom_vline(xintercept = gam_df$cut_ff[1], colour = "grey45", linetype = "22", linewidth = 0.4) +
    ggplot2::geom_ribbon(data = gam_df, inherit.aes = FALSE,
                         ggplot2::aes(flood_freq_pct, ymin = lo, ymax = hi), fill = "white", alpha = 0.35) +
    ggplot2::geom_line(data = gam_df, inherit.aes = FALSE,
                       ggplot2::aes(flood_freq_pct, fit), colour = "white", linewidth = 2.0) +
    ggplot2::geom_line(data = gam_df, inherit.aes = FALSE,
                       ggplot2::aes(flood_freq_pct, fit), colour = hue, linewidth = 1.1)
  if (has_marker)
    p <- p + ggplot2::geom_point(data = data.frame(x = mk$x_mean, y = mk$y_mean), inherit.aes = FALSE,
                                 ggplot2::aes(x, y), shape = 23, size = 3.4, stroke = 1.1,
                                 fill = MARKER_FILL, colour = "white")
  p +
    ggplot2::annotate("text", x = Inf, y = -Inf, hjust = 1.03, vjust = -0.4,
                      size = base_size / 3.4, colour = "grey20", label = lab) +
    ggplot2::scale_x_continuous(name = "How often it floods · between-year flood frequency (%)",
                                breaks = seq(0, 100, 25), limits = c(0, 100),
                                expand = ggplot2::expansion(mult = c(0, 0.01))) +
    ggplot2::scale_y_continuous(name = sprintf("Vegetation floor · veg_%s (%%)", cc$metric),
                                limits = c(0, y_top), expand = ggplot2::expansion(mult = c(0, 0.02))) +
    ggplot2::labs(title = title, subtitle = subtitle, caption = paste(cap, collapse = "\n")) +
    gayini_census_panel_theme(base_size)
}

## (b) Paddock's OWN all-pixel cloud — report centrepiece. Overlaid per-community lines. ----
gayini_paddock_own_cloud <- function(paddock_geom_8058, cc, dominant, paddock_label,
                                     base_size = 11, metric = cc$metric) {
  v  <- terra::vect(sf::st_geometry(paddock_geom_8058))
  st <- c(cc$code, cc$freq, cc[[metric]])
  names(st) <- c("code", "flood_freq_pct", "y")
  ex <- terra::extract(st, v, ID = FALSE)
  ex <- ex[ex$code %in% FOCUS_CODES_L & !is.na(ex$y) & !is.na(ex$flood_freq_pct), , drop = FALSE]
  ex <- dplyr::left_join(ex, cc$code_comm, by = "code")
  ex$community <- factor(ex$community, levels = cc$focus)
  y_top <- min(100, ceiling(stats::quantile(ex$y, 0.999) / 10) * 10)

  present <- ex |> dplyr::count(community, .drop = TRUE) |> dplyr::filter(.data$n >= MIN_BIN_N_L)
  set.seed(SEED_L)
  lines <- dplyr::bind_rows(lapply(as.character(present$community), function(cm) {
    g <- gayini_fit_community_gam(ex[ex$community == cm, c("flood_freq_pct", "y")])
    if (is.null(g)) return(NULL)                 # too few unique x — density only for this community
    g$community <- factor(cm, levels = cc$focus); g
  }))
  n_span       <- nrow(present)                                                   # communities with >= MIN_BIN_N px
  line_comms   <- if (nrow(lines)) length(unique(as.character(lines$community))) else 0L
  n_density    <- dplyr::n_distinct(ex$community) - line_comms                    # communities shown as density only
  legend_on    <- line_comms > 1

  p <- ggplot2::ggplot(ex, ggplot2::aes(flood_freq_pct, y)) +
    ggplot2::geom_bin2d(bins = c(50, 45)) +
    ggplot2::scale_fill_gradient(low = "grey88", high = "grey30", trans = "log10", guide = "none")
  if (nrow(lines)) {
    p <- p +
      ggplot2::geom_line(data = lines, inherit.aes = FALSE,
                         ggplot2::aes(flood_freq_pct, fit, group = community), colour = "white", linewidth = 2.0) +
      ggplot2::geom_line(data = lines, inherit.aes = FALSE,
                         ggplot2::aes(flood_freq_pct, fit, colour = community), linewidth = 1.15) +
      ggplot2::scale_colour_manual(values = cc$comm_hue, name = NULL,
                                   labels = function(x) unname(cc$short[x]),
                                   guide = if (legend_on) ggplot2::guide_legend() else "none")
  }
  sub <- if (n_span > 1)
    sprintf("%s pixels · spans %d communities · dominant %s",
            format(nrow(ex), big.mark = ","), n_span, cc$short[dominant])
  else sprintf("%s pixels · dominant %s", format(nrow(ex), big.mark = ","), cc$short[dominant])
  drop_note <- if (n_density > 0)
    sprintf(" %d %s shown as density only.", n_density, if (n_density == 1) "community" else "communities") else ""
  p +
    ggplot2::scale_x_continuous(name = "How often it floods · between-year flood frequency (%)",
                                breaks = seq(0, 100, 25), limits = c(0, 100),
                                expand = ggplot2::expansion(mult = c(0, 0.01))) +
    ggplot2::scale_y_continuous(name = sprintf("Vegetation floor · veg_%s (%%)", metric),
                                limits = c(0, y_top), expand = ggplot2::expansion(mult = c(0, 0.02))) +
    ggplot2::labs(
      title = sprintf("%s — how cover responds to water", paddock_label),
      subtitle = sub,
      caption = paste0("Pixel census, between-year flood frequency (24.97 m); this paddock's own pixels only.", drop_note, "\n",
                       "Each community line is drawn only over its well-supported flood range (≥500 pixels per flood-freq bin).\n",
                       HONESTY1, "\n", HONESTY2)) +
    gayini_census_panel_theme(base_size) +
    (if (legend_on) ggplot2::theme(
       legend.position = c(0.99, 0.99), legend.justification = c(1, 1),
       legend.background = ggplot2::element_rect(fill = grDevices::adjustcolor("white", 0.7), colour = NA),
       legend.key = ggplot2::element_rect(fill = NA, colour = NA),
       legend.text = ggplot2::element_text(size = base_size - 2)) else ggplot2::theme())
}
