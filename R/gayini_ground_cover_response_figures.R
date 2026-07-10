####################################################################################################


## GAYINI REMOTE SENSING PROJECT


## Tier 1 · F7 figure set — the ground-cover response test.
##   Concept        : the within-strata response explainer — headline (where /
##                    whether) vs intensity (how much, the response axis) stated
##                    in words; a wet pulse -> green flush (PV) -> decay to NPV,
##                    bare ground down; and the short-lag idea. Illustrative.
##   Response by
##     community     : the PRIMARY result — total veg vs wet-extent intensity for
##                     the three non-treed communities in dry->wet order, per-plot
##                     slopes drawn (spaghetti) + the community summary. The
##                     dry->wet strengthening should be legible.
##   Strata panel    : a 3x3 small-multiple (community x regime band) mirroring
##                     F6, each cell the per-plot r distribution + per-cell n,
##                     tinted by verdict. Small-n caution captioned.
##   Lag profile     : median cover-intensity correlation vs lag (0/3/6/9/12 mo)
##                     per community, peak lag marked.
##   Response summary: a table figure — per stratum n, median r (veg & bare),
##                     sign-consistency, bootstrap CI, peak lag, verdict.
##
## One figure = one file = one slide (C3 standing rule). Depends on
## gayini_ground_cover_response_functions.R (verdicts/thresholds), the shared
## gradient vocabulary, and gayini_save_figure().


####################################################################################################


## Shared response-variable palette (green flush / dry matter / bare ground) ----

gayini_f7_response_palette <- function() {
  c(veg  = "#2E7D32",   # total vegetation (green)
    pv   = "#66BB6A",   # green PV (light green — the flush)
    npv  = "#B07D3C",   # non-green NPV (tan — standing dry matter)
    bare = "#8D6E63")   # bare ground (brown)
}


## 1. F7 concept — the within-strata response explainer ----
##
## Left: a schematic pulse -> response time series (intensity pulse, PV flush that
## decays to NPV, bare ground falling), with the short-lag arrow. Right: the
## metric-discipline note (headline defines WHERE; intensity carries HOW MUCH).
## Illustrative geometry (allowed for concept figures).

gayini_build_f7_concept <- function(out_dir, seed = 20260709) {

  set.seed(seed)
  pal <- gayini_f7_response_palette()
  mo  <- 0:36

  ## A single wet pulse mid-record.
  pulse <- 70 * exp(-((mo - 10)^2) / (2 * 3^2))
  ## PV flushes ~3 months after the pulse, then decays.
  pv    <- 12 + 42 * exp(-((mo - 13)^2) / (2 * 4^2))
  ## NPV rises as PV decays (standing dry matter), lagging further.
  npv   <- 20 + 26 * exp(-((mo - 20)^2) / (2 * 6^2))
  ## Bare ground is suppressed while cover is up (mirror).
  bare  <- 55 - 34 * exp(-((mo - 15)^2) / (2 * 5^2))

  df <- dplyr::bind_rows(
    tibble::tibble(mo = mo, y = pulse, series = "Wet-extent intensity (pulse)"),
    tibble::tibble(mo = mo, y = pv,    series = "Green flush (PV)"),
    tibble::tibble(mo = mo, y = npv,   series = "Standing dry matter (NPV)"),
    tibble::tibble(mo = mo, y = bare,  series = "Bare ground")
  )
  ser_levels <- c("Wet-extent intensity (pulse)", "Green flush (PV)",
                  "Standing dry matter (NPV)", "Bare ground")
  df$series <- factor(df$series, levels = ser_levels)
  ser_pal <- c("Wet-extent intensity (pulse)" = "#2166AC",
               "Green flush (PV)" = pal[["pv"]],
               "Standing dry matter (NPV)" = pal[["npv"]],
               "Bare ground" = pal[["bare"]])

  note <- paste(
    "Headline (WHERE / WHETHER): between-year flood frequency",
    "fixes each plot's stratum — it does not move the response.",
    "",
    "Intensity (HOW MUCH): the labelled SECONDARY wet-extent",
    "metric carries the response — annual occurrence (same-year)",
    "and monthly inundation (lag). This is the one rung where the",
    "secondary metric legitimately drives the signal.",
    "",
    "Flood-pulse ecology: a wet pulse drives a green flush (PV),",
    "which decays to standing dry matter (NPV) as bare ground is",
    "suppressed — expected strongest where flooding is frequent,",
    "and after a SHORT LAG, not purely the same month.",
    sep = "\n"
  )

  p_ts <- ggplot2::ggplot(df, ggplot2::aes(.data$mo, .data$y, colour = .data$series)) +
    ggplot2::annotate("segment", x = 10, xend = 13, y = 96, yend = 96,
                      arrow = grid::arrow(length = grid::unit(0.16, "cm"), ends = "last"),
                      colour = "grey35", linewidth = 0.5) +
    ggplot2::annotate("text", x = 11.5, y = 101, label = "short lag", size = 2.7, colour = "grey30") +
    ggplot2::geom_line(linewidth = 1.05) +
    ggplot2::scale_colour_manual(values = ser_pal, name = NULL) +
    ggplot2::scale_y_continuous(limits = c(0, 105)) +
    ggplot2::labs(x = "Months (schematic)", y = "Percent (schematic)") +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(legend.position = "bottom",
                   panel.grid.minor = ggplot2::element_blank()) +
    ggplot2::guides(colour = ggplot2::guide_legend(nrow = 2, byrow = TRUE))

  p_note <- ggplot2::ggplot() +
    ggplot2::annotate("text", x = 0, y = 1, label = note, hjust = 0, vjust = 1,
                      size = 3.0, colour = "grey20", lineheight = 1.05) +
    ggplot2::scale_x_continuous(limits = c(0, 1)) +
    ggplot2::scale_y_continuous(limits = c(0, 1)) +
    ggplot2::theme_void()

  p <- patchwork::wrap_plots(p_ts, p_note, widths = c(1.35, 1)) +
    patchwork::plot_annotation(
      title = "F7 concept — does ground cover track the flood pulses within each stratum?",
      subtitle = "Descriptive support, not a trend or a surface. Headline flood frequency defines the stratum; the labelled secondary wet-extent intensity carries the response.",
      theme = ggplot2::theme(
        plot.title    = ggplot2::element_text(face = "bold", size = 13),
        plot.subtitle = ggplot2::element_text(size = 9, colour = "grey35")
      )
    )

  gayini_save_figure(p, out_dir, "F7_concept", kind = "concept", width = 12, height = 5.4)
}


## 2. F7 response by community (data) — the primary result ----
##
## plot_year_masked : per plot-year (plot_id, community, intensity, total_veg)
##                    after the non-treed + valid-coverage mask (usable plots only).
## community_summary: per-community median veg r + n (for the panel annotation).

gayini_build_f7_response_by_community <- function(plot_year_masked, community_summary, out_dir) {

  short       <- gayini_gradient_short_labels()
  comm_levels <- gayini_focus_levels()
  pal         <- gayini_gradient_palette()

  fac <- function(x) factor(unname(short[as.character(x)]), levels = unname(short[comm_levels]))

  pym <- plot_year_masked |>
    dplyr::mutate(comm = fac(.data$community))

  ## Per-community annotation: median r + n plots, positioned top-left.
  ann <- community_summary |>
    dplyr::mutate(
      comm  = fac(.data$community),
      label = sprintf("median r = %.2f\nn = %d plots", .data$median_r_veg, .data$n_plots)
    )

  comm_cols <- stats::setNames(unname(pal[comm_levels]), unname(short[comm_levels]))

  p <- ggplot2::ggplot(pym, ggplot2::aes(.data$annual_occurrence_pct, .data$total_veg_pct)) +
    ## per-plot spaghetti (each plot's own same-year slope)
    ggplot2::geom_line(ggplot2::aes(group = .data$plot_id, colour = .data$comm),
                       stat = "smooth", method = "lm", formula = y ~ x, se = FALSE,
                       linewidth = 0.35, alpha = 0.35) +
    ggplot2::geom_point(ggplot2::aes(colour = .data$comm), size = 0.5, alpha = 0.18) +
    ## community-level fit (heavy)
    ggplot2::geom_smooth(method = "lm", formula = y ~ x, se = FALSE,
                         colour = "grey15", linewidth = 1.1) +
    ggplot2::geom_text(data = ann, inherit.aes = FALSE,
                       ggplot2::aes(x = -Inf, y = Inf, label = .data$label),
                       hjust = -0.08, vjust = 1.15, size = 3, colour = "grey15",
                       fontface = "bold", lineheight = 0.95) +
    ggplot2::facet_wrap(~ .data$comm, nrow = 1) +
    ggplot2::scale_colour_manual(values = comm_cols, guide = "none") +
    ggplot2::coord_cartesian(ylim = c(0, 100)) +
    ggplot2::labs(
      title    = "F7 response by community — does ground cover track wet-extent intensity? (same-year)",
      subtitle = "Three non-treed communities, dry->wet. Thin lines = per-plot same-year slopes; heavy line = community fit. Response strengthens along the gradient.",
      x = "Wet-extent intensity — annual occurrence (%)  [SECONDARY metric, the response axis]",
      y = "Total vegetation cover (%)"
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      plot.title    = ggplot2::element_text(face = "bold"),
      plot.subtitle = ggplot2::element_text(size = 8.6, colour = "grey35"),
      strip.text    = ggplot2::element_text(face = "bold", size = 10),
      panel.grid.minor = ggplot2::element_blank()
    )

  gayini_save_figure(p, out_dir, "F7_response_by_community_data", kind = "data",
                     width = 12, height = 5.2)
}


## 3. F7 strata panel (data) — the 3x3 small-multiple ----
##
## response_by_plot : per-plot r_veg + community + regime_band (usable plots).
## response_summary : per stratum median_r_veg, n_plots, verdict (panel tint + tag).

gayini_build_f7_strata_panel <- function(response_by_plot, response_summary, out_dir,
                                         thresholds = gayini_f7_thresholds()) {

  verdict_pal <- gayini_f7_verdict_palette()
  verdict_lab <- gayini_f7_verdict_labels()
  short       <- gayini_gradient_short_labels()
  comm_levels <- gayini_focus_levels()
  band_levels <- gayini_regime_band_levels()

  fac_comm <- function(x) factor(unname(short[as.character(x)]), levels = unname(short[comm_levels]))
  fac_band <- function(x) factor(as.character(x), levels = band_levels,
                                 labels = c("low band", "mid band", "high band"))

  pts <- response_by_plot |>
    dplyr::filter(.data$usable) |>
    dplyr::mutate(comm = fac_comm(.data$community), band = fac_band(.data$regime_band))

  tag <- response_summary |>
    dplyr::mutate(
      comm = fac_comm(.data$community), band = fac_band(.data$regime_band),
      label = sprintf("%s\nmedian r = %.2f\nn = %d",
                      verdict_lab[as.character(.data$verdict)], .data$median_r_veg, .data$n_plots)
    )

  p <- ggplot2::ggplot(pts, ggplot2::aes(x = .data$r_veg, y = 0)) +
    ## verdict tint behind each panel
    ggplot2::geom_rect(data = tag, inherit.aes = FALSE,
                       ggplot2::aes(fill = .data$verdict),
                       xmin = -Inf, xmax = Inf, ymin = -Inf, ymax = Inf, alpha = 0.13) +
    ggplot2::geom_vline(xintercept = 0, colour = "grey55", linewidth = 0.4) +
    ggplot2::geom_vline(xintercept = thresholds$R_RESPOND, colour = "grey55",
                        linetype = "dashed", linewidth = 0.4) +
    ## per-plot r as a strip of points
    ggplot2::geom_jitter(ggplot2::aes(y = 0), width = 0, height = 0.5,
                         size = 1.5, alpha = 0.7, colour = "#2E7D32") +
    ## stratum median r as a heavy tick
    ggplot2::geom_segment(data = tag, inherit.aes = FALSE,
                          ggplot2::aes(x = .data$median_r_veg, xend = .data$median_r_veg,
                                       y = -0.85, yend = 0.85),
                          colour = "grey10", linewidth = 0.9) +
    ggplot2::geom_text(data = tag, inherit.aes = FALSE,
                       ggplot2::aes(x = -Inf, y = Inf, label = .data$label),
                       hjust = -0.06, vjust = 1.12, size = 2.6, colour = "grey15",
                       fontface = "bold", lineheight = 0.95) +
    ggplot2::facet_grid(rows = ggplot2::vars(.data$comm), cols = ggplot2::vars(.data$band)) +
    ggplot2::scale_fill_manual(values = verdict_pal, breaks = gayini_f7_verdict_levels(),
                               labels = gayini_f7_verdict_labels(), name = "Verdict (panel tint)",
                               drop = FALSE) +
    ggplot2::scale_x_continuous(limits = c(-0.5, 1)) +
    ggplot2::scale_y_continuous(limits = c(-1.2, 1.6), breaks = NULL) +
    ggplot2::labs(
      title    = "F7 strata panel — same-year cover response per vegetation × regime stratum",
      subtitle = "Rows: community (dry->wet). Columns: within-community regime band. Each dot = one plot's same-year veg~intensity r; heavy tick = stratum median. Dashed line = respond threshold (0.20).",
      x = "Per-plot same-year correlation r (total veg ~ wet-extent intensity)", y = NULL,
      caption = "Small-n caution: cells hold ~3-8 plots — read the community-level result (F7 response by community) as the robust signal; do not over-read a single cell."
    ) +
    ggplot2::guides(fill = ggplot2::guide_legend(override.aes = list(alpha = 0.4))) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      plot.title    = ggplot2::element_text(face = "bold"),
      plot.subtitle = ggplot2::element_text(size = 8.2, colour = "grey35"),
      plot.caption  = ggplot2::element_text(size = 8, colour = "grey35", hjust = 0),
      strip.text    = ggplot2::element_text(face = "bold", size = 9),
      panel.grid.minor = ggplot2::element_blank(),
      legend.position = "bottom"
    )

  gayini_save_figure(p, out_dir, "F7_strata_panel_data", kind = "data",
                     width = 12, height = 8.4)
}


## 4. F7 lag profile (data) — median cover-intensity r vs lag ----

gayini_build_f7_lag_profile <- function(lag_profile, peak_lag, out_dir) {

  short       <- gayini_gradient_short_labels()
  comm_levels <- gayini_focus_levels()
  pal         <- gayini_gradient_palette()
  lab         <- unname(short[comm_levels])

  lp <- lag_profile |>
    dplyr::filter(as.character(.data$simplified_vegetation_group) %in% comm_levels) |>
    dplyr::mutate(comm = factor(unname(short[as.character(.data$simplified_vegetation_group)]),
                                levels = lab))

  pk <- peak_lag |>
    dplyr::filter(as.character(.data$simplified_vegetation_group) %in% comm_levels) |>
    dplyr::mutate(comm = factor(unname(short[as.character(.data$simplified_vegetation_group)]),
                                levels = lab),
                  label = sprintf("peak %d mo (r=%.2f)", .data$peak_lag_months, .data$peak_median_r))

  comm_cols <- stats::setNames(unname(pal[comm_levels]), lab)

  p <- ggplot2::ggplot(lp, ggplot2::aes(.data$lag_months, .data$median_r, colour = .data$comm)) +
    ggplot2::geom_hline(yintercept = 0, colour = "grey55", linewidth = 0.4) +
    ggplot2::geom_ribbon(ggplot2::aes(ymin = .data$q25_r, ymax = .data$q75_r, fill = .data$comm),
                         alpha = 0.14, colour = NA) +
    ggplot2::geom_line(linewidth = 1.0, na.rm = TRUE) +
    ggplot2::geom_point(ggplot2::aes(size = .data$n_plots), alpha = 0.9, na.rm = TRUE) +
    ggplot2::geom_point(data = pk, ggplot2::aes(.data$peak_lag_months, .data$peak_median_r),
                        shape = 21, size = 4.2, stroke = 1.1, fill = NA, colour = "grey10") +
    ggplot2::geom_text(data = pk, ggplot2::aes(.data$peak_lag_months, .data$peak_median_r, label = .data$label),
                       vjust = -1.3, size = 2.9, fontface = "bold", show.legend = FALSE) +
    ggplot2::facet_wrap(~ .data$comm, nrow = 1) +
    ggplot2::scale_x_continuous(breaks = c(0, 3, 6, 9, 12)) +
    ggplot2::scale_colour_manual(values = comm_cols, guide = "none") +
    ggplot2::scale_fill_manual(values = comm_cols, guide = "none") +
    ggplot2::scale_size_continuous(range = c(1.5, 5), name = "Plots") +
    ggplot2::labs(
      title    = "F7 lag profile — how long after a wet pulse does cover respond? (secondary)",
      subtitle = "Median per-plot correlation of monthly total veg on monthly inundation intensity at t - lag. Ribbon = IQR across plots. Circled = community peak lag.",
      x = "Inundation lead time (months)", y = "Median cover–intensity correlation r",
      caption = "Descriptive correlation only, not a causal test. Monthly inundation is a detection metric, not continuous hydroperiod; sub-annual record is recent (daily product), so plot counts are lower than the same-year read."
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      plot.title    = ggplot2::element_text(face = "bold"),
      plot.subtitle = ggplot2::element_text(size = 8.6, colour = "grey35"),
      plot.caption  = ggplot2::element_text(size = 8, colour = "grey35", hjust = 0),
      strip.text    = ggplot2::element_text(face = "bold", size = 10),
      panel.grid.minor = ggplot2::element_blank(),
      legend.position = "bottom"
    )

  gayini_save_figure(p, out_dir, "F7_lag_profile_data", kind = "data", width = 12, height = 5.4)
}


## 5. F7 response summary (data) — the table figure ----
##
## One row per stratum: n plots, median r (veg & bare), sign-consistency, the
## bootstrap CI on median veg r, the community peak lag, and the verdict (cell
## coloured). Peak lag is a per-COMMUNITY quantity (the lag deliverable), joined
## onto each of the community's strata and labelled as such.

gayini_build_f7_response_summary <- function(response_summary, peak_lag, out_dir) {

  verdict_pal <- gayini_f7_verdict_palette()
  verdict_lab <- gayini_f7_verdict_labels()
  short       <- gayini_gradient_short_labels()
  comm_levels <- gayini_focus_levels()
  band_levels <- gayini_regime_band_levels()

  tbl <- response_summary |>
    dplyr::left_join(peak_lag, by = c("community" = "simplified_vegetation_group")) |>
    dplyr::mutate(
      community   = factor(as.character(.data$community), levels = comm_levels),
      regime_band = factor(as.character(.data$regime_band), levels = band_levels)
    ) |>
    dplyr::arrange(.data$community, .data$regime_band)

  n <- nrow(tbl)

  cols <- c(comm = 0.3, band = 3.2, np = 4.3, rveg = 5.4, rbare = 6.6,
            sign = 7.8, ci = 9.2, peak = 10.9, verdict = 12.4)
  headers <- c(comm = "Community", band = "Band", np = "n\nplots",
               rveg = "median r\n(veg)", rbare = "median r\n(bare)",
               sign = "sign +ve\n(veg)", ci = "95% CI\n(median r veg)",
               peak = "peak lag\n(community)", verdict = "Verdict")

  row_y <- function(i) n - i + 1
  cell  <- function(col, i, label, hjust = 0.5) data.frame(x = cols[[col]], y = row_y(i), label = label, hjust = hjust)

  fmt_ci <- function(lo, hi) if (is.na(lo) || is.na(hi)) "n/a" else sprintf("[%.2f, %.2f]", lo, hi)
  fmt_peak <- function(m, r) if (is.na(m)) "n/a" else sprintf("%d mo", m)

  body <- do.call(rbind, lapply(seq_len(n), function(i) {
    r <- tbl[i, ]
    rbind(
      cell("comm",  i, unname(short[as.character(r$community)]), hjust = 0),
      cell("band",  i, as.character(r$regime_band)),
      cell("np",    i, as.character(r$n_plots)),
      cell("rveg",  i, sprintf("%+.2f", r$median_r_veg)),
      cell("rbare", i, sprintf("%+.2f", r$median_r_bare)),
      cell("sign",  i, sprintf("%.0f%%", 100 * r$sign_frac_pos)),
      cell("ci",    i, fmt_ci(r$ci_lo_veg, r$ci_hi_veg)),
      cell("peak",  i, fmt_peak(r$peak_lag_months, r$peak_median_r))
    )
  }))

  verd_tiles <- data.frame(
    x = cols[["verdict"]], y = vapply(seq_len(n), row_y, numeric(1)),
    fill = unname(verdict_pal[as.character(tbl$verdict)])
  )
  verd_text <- data.frame(
    x = cols[["verdict"]], y = vapply(seq_len(n), row_y, numeric(1)),
    label = unname(verdict_lab[as.character(tbl$verdict)])
  )

  header_df <- data.frame(x = unname(cols), y = n + 1,
                          label = unname(headers[names(cols)]),
                          hjust = c(0, rep(0.5, length(cols) - 1)))

  stripes <- data.frame(y = vapply(seq(1, n, by = 2), row_y, numeric(1)))
  xmax <- 13.6

  p <- ggplot2::ggplot() +
    ggplot2::geom_rect(data = stripes, inherit.aes = FALSE,
                       ggplot2::aes(ymin = y - 0.5, ymax = y + 0.5),
                       xmin = 0, xmax = xmax, fill = "grey95") +
    ggplot2::geom_hline(yintercept = n + 0.5, colour = "grey70", linewidth = 0.4) +
    ggplot2::geom_tile(data = verd_tiles, ggplot2::aes(x = x, y = y),
                       fill = verd_tiles$fill, width = 2.0, height = 0.72, alpha = 0.85) +
    ggplot2::geom_text(data = header_df, ggplot2::aes(x = x, y = y, label = label, hjust = hjust),
                       fontface = "bold", size = 2.9, colour = "grey15", lineheight = 0.9) +
    ggplot2::geom_text(data = body, ggplot2::aes(x = x, y = y, label = label, hjust = hjust),
                       size = 2.8, colour = "grey15") +
    ggplot2::geom_text(data = verd_text, ggplot2::aes(x = x, y = y, label = label),
                       size = 2.5, colour = "white", fontface = "bold") +
    ggplot2::scale_x_continuous(limits = c(0.1, xmax + 0.1)) +
    ggplot2::scale_y_continuous(limits = c(0.4, n + 1.9)) +
    ggplot2::labs(
      title    = "F7 response summary — same-year cover response per vegetation × regime stratum",
      subtitle = "Headline defines the stratum; the labelled secondary wet-extent intensity carries the response. Verdict thresholds (median r >= 0.20, >= 70% sign-consistent, bootstrap CI excludes 0) are flagged for Adrian. Peak lag is community-level."
    ) +
    ggplot2::theme_void(base_size = 11) +
    ggplot2::theme(
      plot.title    = ggplot2::element_text(face = "bold", size = 12),
      plot.subtitle = ggplot2::element_text(size = 7.8, colour = "grey35"),
      plot.margin   = ggplot2::margin(12, 12, 12, 12)
    )

  gayini_save_figure(p, out_dir, "F7_response_summary_data", kind = "data",
                     width = 12, height = 5.4)
}
