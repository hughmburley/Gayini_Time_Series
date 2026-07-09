####################################################################################################


## GAYINI REMOTE SENSING PROJECT


## Tier 1 · F6 figure trio — the trend test.
##   Concept : three archetype series (a clean directional trend; a flat no-trend
##             cloud; an episodic/cyclic series a linear fit would misread) — the
##             three-verdict explainer, illustrative geometry, no real data.
##   Data 1  : F6 strata trends — a 3x3 small-multiple (community x regime band),
##             each panel the annual flood-frequency series + LOESS + linear fit,
##             the two biggest flood years marked, panel tinted by its verdict.
##   Data 2  : F6 verdict summary — a table figure: per stratum, Theil-Sen slope,
##             MK tau/p, OLS R^2, flood-drop-robust?, LOESS monotonic?, verdict.
##
## One figure = one file = one slide (C3 standing rule). Depends on
## gayini_trend_test_functions.R (verdict palette) and the shared gradient
## vocabulary + gayini_save_figure().


####################################################################################################


## Shared line styling for the three fits ----

gayini_trend_fit_palette <- function() {
  c(series = "#4292C6",   # observed annual frequency (blue, matches the ladder)
    loess  = "#F46D43",   # LOESS smoother (warm — the shape)
    ols    = "#333333")   # OLS linear reference (near-black, dashed)
}

gayini_trend_fit_labels <- function() {
  c(series = "Annual flood frequency",
    loess  = "LOESS (shape)",
    ols    = "OLS linear (reference)")
}


## 1. F6 concept — the three-verdict explainer ----
##
## Three archetype panels on one row, each tinted by its verdict colour, with a
## plain-language note. Illustrative geometry (allowed for concept figures): the
## point is to make "non-stationary is not a trend" legible.

gayini_build_f6_concept <- function(out_dir, seed = 20260709) {

  set.seed(seed)
  fit_pal     <- gayini_trend_fit_palette()
  verdict_pal <- gayini_trend_verdict_palette()
  yr <- 1:35

  ## (A) Directional trend — clean, roughly linear rise.
  a <- 20 + 1.6 * yr + stats::rnorm(35, sd = 4)
  ## (B) No trend — flat cloud around a level.
  b <- 45 + stats::rnorm(35, sd = 9)
  ## (C) Non-stationary — cyclic/episodic; big late floods pull a naive line up.
  c_ <- 35 + 22 * sin(2 * pi * yr / 16) + stats::rnorm(35, sd = 5)
  c_[c(29, 32)] <- c(95, 92)   # two big flood years late in the record

  arche <- c(A = "Directional trend", B = "No trend", C = "Non-stationary (episodic)")
  verd  <- c(A = "directional_trend", B = "no_trend", C = "non_stationary")

  df <- dplyr::bind_rows(
    tibble::tibble(panel = "A", year = yr, y = a),
    tibble::tibble(panel = "B", year = yr, y = b),
    tibble::tibble(panel = "C", year = yr, y = c_)
  )
  df$facet   <- factor(arche[df$panel], levels = unname(arche))
  df$verdict <- factor(verd[df$panel], levels = gayini_trend_verdict_levels())

  ## LOESS + OLS per panel for the illustrative fits.
  loess_df <- dplyr::bind_rows(lapply(c("A", "B", "C"), function(p) {
    d <- df[df$panel == p, ]
    lo <- gayini_loess_shape(d$year, d$y, span = 0.75)
    tibble::tibble(panel = p, facet = d$facet[1], year = lo$pred_x, y = lo$pred_y)
  }))
  ols_df <- dplyr::bind_rows(lapply(c("A", "B", "C"), function(p) {
    d <- df[df$panel == p, ]; f <- gayini_ols_fit(d$year, d$y)
    tibble::tibble(panel = p, facet = d$facet[1],
                   x = range(d$year), y = f$intercept + f$slope * range(d$year))
  }))

  notes <- tibble::tibble(
    facet = factor(unname(arche), levels = unname(arche)),
    label = c(
      "MK significant · robust to dropping the\ntwo biggest floods · LOESS monotonic ·\nslope ≠ 0 → a real, stable move.",
      "Mann–Kendall not significant → flat.\n“No robust trend” is a legitimate\nresult, not a failure.",
      "MK significant BUT carried by a few floods,\nLOESS non-monotonic, or slope degenerate\n(CI spans 0) → movement ≠ trend."
    )
  )

  tint <- verdict_pal[verd]; names(tint) <- unname(arche)

  p <- ggplot2::ggplot(df, ggplot2::aes(year, y)) +
    ## verdict tint behind each panel
    ggplot2::geom_rect(data = data.frame(facet = factor(unname(arche), levels = unname(arche))),
                       inherit.aes = FALSE,
                       ggplot2::aes(fill = facet),
                       xmin = -Inf, xmax = Inf, ymin = -Inf, ymax = Inf, alpha = 0.12) +
    ggplot2::geom_line(colour = fit_pal["series"], linewidth = 0.3, alpha = 0.6) +
    ggplot2::geom_point(colour = fit_pal["series"], size = 1.1) +
    ggplot2::geom_line(data = loess_df, colour = fit_pal["loess"], linewidth = 1.1) +
    ggplot2::geom_line(data = ols_df, ggplot2::aes(x = x, y = y),
                       colour = fit_pal["ols"], linetype = "dashed", linewidth = 0.7) +
    ggplot2::geom_text(data = notes, inherit.aes = FALSE,
                       ggplot2::aes(x = 1, y = -4, label = label),
                       hjust = 0, vjust = 1, size = 2.7, colour = "grey20", lineheight = 0.95) +
    ggplot2::facet_wrap(~facet, nrow = 1) +
    ggplot2::scale_fill_manual(values = tint, guide = "none") +
    ggplot2::scale_y_continuous(limits = c(-28, 105)) +
    ggplot2::labs(
      title    = "F6 concept — three verdicts: is the water actually moving?",
      subtitle = "Same test, three outcomes. Blue = annual flood frequency · orange = LOESS shape · dashed = OLS line.\nA naïve straight line can misread an episodic record as a trend — that's what the flood-drop robustness check catches.",
      x = "Water year (schematic)", y = "Flood frequency (%)"
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      plot.title    = ggplot2::element_text(face = "bold"),
      plot.subtitle = ggplot2::element_text(size = 8.2, colour = "grey35"),
      strip.text    = ggplot2::element_text(face = "bold", size = 10),
      panel.grid.minor = ggplot2::element_blank()
    )

  gayini_save_figure(p, out_dir, "F6_concept", kind = "concept",
                     width = 11, height = 4.4)
}


## 2. F6 strata trends — the 3x3 small-multiple ----
##
## series_long : stacked per-stratum annual tibble (stratum, community,
##               regime_band, year, freq_pct).
## trend       : output of gayini_run_trend_tests() (verdict_tbl + per-stratum fits).

gayini_build_f6_strata_trends <- function(series_long, trend, out_dir) {

  fit_pal     <- gayini_trend_fit_palette()
  fit_lab     <- gayini_trend_fit_labels()
  verdict_pal <- gayini_trend_verdict_palette()
  short       <- gayini_gradient_short_labels()
  comm_levels <- gayini_focus_levels()
  band_levels <- gayini_regime_band_levels()

  vt <- trend$verdict_tbl

  ## Facet factors, communities in gradient order (short labels), bands low->high.
  fac_comm <- function(x) factor(unname(short[as.character(x)]),
                                 levels = unname(short[comm_levels]))
  fac_band <- function(x) factor(as.character(x), levels = band_levels,
                                 labels = c("low band", "mid band", "high band"))

  ser <- series_long |>
    dplyr::filter(!is.na(.data$freq_pct)) |>
    dplyr::mutate(comm = fac_comm(.data$community), band = fac_band(.data$regime_band))

  ## LOESS + OLS geometry, per stratum, from the stored fits.
  loess_df <- dplyr::bind_rows(lapply(names(trend$fits), function(k) {
    f  <- trend$fits[[k]]; m <- vt[vt$stratum == k, ]
    tibble::tibble(stratum = k, community = m$community, regime_band = m$regime_band,
                   year = f$fit$loess$pred_x, freq_pct = f$fit$loess$pred_y)
  })) |>
    dplyr::mutate(comm = fac_comm(.data$community), band = fac_band(.data$regime_band))

  ols_df <- dplyr::bind_rows(lapply(names(trend$fits), function(k) {
    f <- trend$fits[[k]]; m <- vt[vt$stratum == k, ]
    xr <- range(f$series$year)
    tibble::tibble(stratum = k, community = m$community, regime_band = m$regime_band,
                   year = xr, freq_pct = f$fit$ols$intercept + f$fit$ols$slope * xr)
  })) |>
    dplyr::mutate(comm = fac_comm(.data$community), band = fac_band(.data$regime_band))

  ## The two biggest flood years marked (the episodic-robustness drop set).
  drop_df <- dplyr::bind_rows(lapply(names(trend$fits), function(k) {
    f <- trend$fits[[k]]; m <- vt[vt$stratum == k, ]
    d <- f$series[f$series$year %in% f$dropped_years, c("year", "freq_pct")]
    dplyr::mutate(d, stratum = k, community = m$community, regime_band = m$regime_band)
  })) |>
    dplyr::mutate(comm = fac_comm(.data$community), band = fac_band(.data$regime_band))

  ## Per-panel verdict tint + a compact verdict/stat tag.
  tag_df <- vt |>
    dplyr::mutate(
      comm = fac_comm(.data$community), band = fac_band(.data$regime_band),
      tag  = sprintf("%s\nτ=%.2f  p=%.3f", gayini_trend_verdict_labels()[as.character(.data$verdict)],
                     .data$mk_tau, .data$mk_p)
    )

  p <- ggplot2::ggplot(ser, ggplot2::aes(.data$year, .data$freq_pct)) +
    ## verdict tint behind each panel
    ggplot2::geom_rect(data = tag_df, inherit.aes = FALSE,
                       ggplot2::aes(fill = .data$verdict),
                       xmin = -Inf, xmax = Inf, ymin = -Inf, ymax = Inf, alpha = 0.13) +
    ## big flood years (drop set) highlighted underneath the series
    ggplot2::geom_point(data = drop_df, ggplot2::aes(colour = "flood"),
                        size = 3.1, shape = 21, stroke = 0.9, fill = NA) +
    ggplot2::geom_line(ggplot2::aes(colour = "series"), linewidth = 0.3, alpha = 0.55) +
    ggplot2::geom_point(ggplot2::aes(colour = "series"), size = 0.9) +
    ggplot2::geom_line(data = loess_df, ggplot2::aes(colour = "loess"), linewidth = 1.0) +
    ggplot2::geom_line(data = ols_df, ggplot2::aes(colour = "ols"),
                       linetype = "dashed", linewidth = 0.6) +
    ggplot2::geom_text(data = tag_df, inherit.aes = FALSE,
                       ggplot2::aes(x = -Inf, y = Inf, label = .data$tag),
                       hjust = -0.05, vjust = 1.1, size = 2.5, colour = "grey15",
                       fontface = "bold", lineheight = 0.95) +
    ggplot2::facet_grid(rows = ggplot2::vars(.data$comm), cols = ggplot2::vars(.data$band)) +
    ggplot2::scale_fill_manual(values = verdict_pal, breaks = gayini_trend_verdict_levels(),
                               labels = gayini_trend_verdict_labels(),
                               name = "Verdict (panel tint)") +
    ggplot2::scale_colour_manual(
      values = c(series = fit_pal[["series"]], loess = fit_pal[["loess"]],
                 ols = fit_pal[["ols"]], flood = "#7F0000"),
      breaks = c("series", "loess", "ols", "flood"),
      labels = c(fit_lab[["series"]], fit_lab[["loess"]], fit_lab[["ols"]],
                 "Two biggest flood years (dropped in check)"),
      name = NULL) +
    ggplot2::scale_y_continuous(limits = c(0, 100)) +
    ggplot2::labs(
      title    = "F6 strata trends — does flood frequency move? (per vegetation × regime stratum)",
      subtitle = "Rows: community (dry→wet).  Columns: within-community regime band.  Panel tint = trend verdict.  Theil–Sen/Mann–Kendall is primary; OLS & LOESS shown for contrast.",
      x = "Water year", y = "Annual flood frequency (%)"
    ) +
    ggplot2::guides(
      fill   = ggplot2::guide_legend(order = 1, override.aes = list(alpha = 0.4)),
      colour = ggplot2::guide_legend(order = 2, override.aes = list(
        linetype = c("solid", "solid", "dashed", "blank"),
        shape    = c(16, NA, NA, 21),
        linewidth = c(0.5, 1.0, 0.6, NA)))) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      plot.title    = ggplot2::element_text(face = "bold"),
      plot.subtitle = ggplot2::element_text(size = 8.4, colour = "grey35"),
      strip.text    = ggplot2::element_text(face = "bold", size = 9),
      panel.grid.minor = ggplot2::element_blank(),
      legend.position = "bottom", legend.box = "vertical"
    )

  gayini_save_figure(p, out_dir, "F6_strata_trends_data", kind = "data",
                     width = 12, height = 10)
}


## 3. F6 verdict summary — the table figure ----
##
## One row per stratum: Theil-Sen slope (ppt/yr), MK tau + p, OLS R^2, flood-drop
## robust? (Y/N), LOESS monotonic? (Y/N), and the verdict (cell coloured).

gayini_build_f6_verdict_summary <- function(trend, out_dir) {

  verdict_pal <- gayini_trend_verdict_palette()
  verdict_lab <- gayini_trend_verdict_labels()
  short       <- gayini_gradient_short_labels()
  comm_levels <- gayini_focus_levels()
  band_levels <- gayini_regime_band_levels()

  vt <- trend$verdict_tbl |>
    dplyr::mutate(
      community   = factor(as.character(.data$community), levels = comm_levels),
      regime_band = factor(as.character(.data$regime_band), levels = band_levels)
    ) |>
    dplyr::arrange(.data$community, .data$regime_band)

  n <- nrow(vt)
  alpha <- trend$thresholds$MK_P_ALPHA
  ## The flood-drop and LOESS-shape checks only DISCRIMINATE once Mann-Kendall
  ## (primary) is significant; on a no-trend row they didn't decide anything, so
  ## show "n/a" rather than a Y/– that reads as if they had.
  yn <- function(x, significant) ifelse(!significant, "n/a", ifelse(x, "Y", "–"))

  ## Column layout (x positions) — generous spacing so nothing collides.
  cols <- c(comm = 0.3, band = 3.1, ts = 4.4, tau = 5.5, p = 6.5,
            r2 = 7.5, drop = 8.7, mono = 9.9, verdict = 11.1)
  headers <- c(comm = "Community", band = "Band", ts = "Theil–Sen\n(ppt/yr)",
               tau = "MK τ", p = "MK p", r2 = "OLS R²",
               drop = "Drop-2\nrobust?", mono = "LOESS\nmono?", verdict = "Verdict")

  row_y <- function(i) n - i + 1
  cell <- function(col, i, label, ...) data.frame(x = cols[[col]], y = row_y(i), label = label, ...)

  body <- do.call(rbind, lapply(seq_len(n), function(i) {
    r <- vt[i, ]
    rbind(
      cell("comm", i, unname(short[as.character(r$community)]), hjust = 0),
      cell("band", i, as.character(r$regime_band), hjust = 0.5),
      cell("ts",   i, sprintf("%+.2f", r$theil_sen_slope), hjust = 0.5),
      cell("tau",  i, sprintf("%+.2f", r$mk_tau), hjust = 0.5),
      cell("p",    i, sprintf("%.3f", r$mk_p), hjust = 0.5),
      cell("r2",   i, sprintf("%.2f", r$ols_r2), hjust = 0.5),
      cell("drop", i, yn(r$flood_drop_robust, r$mk_p < alpha), hjust = 0.5),
      cell("mono", i, yn(r$loess_monotonic, r$mk_p < alpha), hjust = 0.5)
    )
  }))

  ## Verdict cells, coloured tiles.
  verd_tiles <- data.frame(
    x = cols[["verdict"]], y = vapply(seq_len(n), row_y, numeric(1)),
    fill = unname(verdict_pal[as.character(vt$verdict)])
  )
  verd_text <- data.frame(
    x = cols[["verdict"]], y = vapply(seq_len(n), row_y, numeric(1)),
    label = unname(verdict_lab[as.character(vt$verdict)])
  )

  header_df <- data.frame(x = unname(cols), y = n + 1,
                          label = unname(headers[names(cols)]),
                          hjust = c(0, rep(0.5, length(cols) - 1)))

  ## Light zebra striping for row legibility.
  stripes <- data.frame(y = vapply(seq(1, n, by = 2), row_y, numeric(1)))

  p <- ggplot2::ggplot() +
    ggplot2::geom_rect(data = stripes, inherit.aes = FALSE,
                       ggplot2::aes(ymin = y - 0.5, ymax = y + 0.5),
                       xmin = 0, xmax = 12, fill = "grey95") +
    ggplot2::geom_hline(yintercept = n + 0.5, colour = "grey70", linewidth = 0.4) +
    ggplot2::geom_tile(data = verd_tiles, ggplot2::aes(x = x, y = y),
                       fill = verd_tiles$fill, width = 1.7, height = 0.72, alpha = 0.85) +
    ggplot2::geom_text(data = header_df, ggplot2::aes(x = x, y = y, label = label, hjust = hjust),
                       fontface = "bold", size = 3, colour = "grey15", lineheight = 0.9) +
    ggplot2::geom_text(data = body, ggplot2::aes(x = x, y = y, label = label, hjust = hjust),
                       size = 2.9, colour = "grey15") +
    ggplot2::geom_text(data = verd_text, ggplot2::aes(x = x, y = y, label = label),
                       size = 2.7, colour = "white", fontface = "bold") +
    ggplot2::scale_x_continuous(limits = c(0.1, 12.1)) +
    ggplot2::scale_y_continuous(limits = c(0.4, n + 1.8)) +
    ggplot2::labs(
      title    = "F6 verdict summary — per vegetation × regime stratum",
      subtitle = "Theil–Sen/Mann–Kendall primary. Verdict = no-trend (grey) / directional (green) / non-stationary (amber). Thresholds: MK p<0.10, drop 2 biggest floods, LOESS monotonicity — flagged for stats review."
    ) +
    ggplot2::theme_void(base_size = 11) +
    ggplot2::theme(
      plot.title    = ggplot2::element_text(face = "bold", size = 12),
      plot.subtitle = ggplot2::element_text(size = 8, colour = "grey35"),
      plot.margin   = ggplot2::margin(12, 12, 12, 12)
    )

  gayini_save_figure(p, out_dir, "F6_verdict_summary_data", kind = "data",
                     width = 12, height = 5.2)
}
