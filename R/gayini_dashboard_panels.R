####################################################################################################


## GAYINI REMOTE SENSING PROJECT


## Tier 1 · Dashboards — modular PANEL functions.
##
## Each function returns a single ggplot / cowplot object for ONE panel; the
## composer (gayini_dashboard_compose.R) arranges them into layouts A/B/C. No
## panel saves a file. Panels reuse:
##   - gayini_area_map_core()          (map panels)
##   - gayini_plot_between_year_frequency() + gradient palette (where-it-sits box)
##   - F7 plot_year_masked scatter + community lm fit (vegetation response)
##
## HARD RULES honoured here: no pre/post anything (no 2019/2020 transition line,
## no drier_post label, no pre/post boxplot); trend wording is provisional; the
## boxplot compares on ABSOLUTE flood frequency, never band label; EPSG:8058.


####################################################################################################


## Shared bits ----

gayini_dashboard_theme <- function(base_size = 10) {
  ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      plot.title      = ggplot2::element_text(face = "bold", size = base_size + 1),
      plot.subtitle   = ggplot2::element_text(size = base_size - 2.5, colour = "grey35"),
      plot.caption    = ggplot2::element_text(size = base_size - 3, colour = "grey45", hjust = 0),
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major = ggplot2::element_line(colour = "grey92", linewidth = 0.2),
      axis.title      = ggplot2::element_text(size = base_size - 2, colour = "grey30")
    )
}

## Colours reused across panels.
gayini_dashboard_cols <- function() {
  c(flood = "#2171B5", total_veg = "#2E7D32", bare = "#8D6E63", gauge = "#7B6BA8",
    wetter = "#2171B5", same = "#9E9E9E", drier = "#B2182B", mark = "#D7301F")
}

## Annual series carry an integer `year`; the time panels plot on a Date axis so
## they can share ONE x scale with the (sub-annual) ground-cover series (G3).
## Anchor each year at 1 Jan so annual points sit on the yearly gridline.
gayini_year_to_date <- function(y) as.Date(sprintf("%d-01-01", as.integer(y)))

## Common date x-scale for the aligned time-series column (G3). date_lim /
## date_breaks come from the composer so flooding / total-veg / gauge-flow share
## identical limits + breaks and a year reads straight down. NULL -> ggplot default.
gayini_series_date_scale <- function(date_lim = NULL, date_breaks = NULL) {
  if (is.null(date_lim)) return(NULL)
  ggplot2::scale_x_date(limits = date_lim, breaks = date_breaks, date_labels = "%Y",
                        expand = ggplot2::expansion(mult = c(0.01, 0.01)))
}


## 1. MAP panel ----
##
## paddock -> checkerboard (veg_regime_class); site -> flood-frequency + radius
## ring; stratum -> checkerboard with THIS class highlighted, others muted.

gayini_panel_map <- function(spec, ctx, base_size = 9) {

  cols <- gayini_dashboard_cols()

  ## Farm-locator inset (top-left) for site + paddock maps (G4). The stratum map
  ## already shows the whole farm with the class highlighted, so it gets none
  ## (flagged open item — default: no stratum inset).
  add_locator <- function(core_plot, unit_area) {
    loc <- gayini_locator_inset(unit_area, ctx$boundary, ctx$management)
    cowplot::ggdraw(core_plot) +
      cowplot::draw_plot(loc, x = 0.015, y = 0.66, width = 0.26, height = 0.30)
  }

  if (spec$type == "site") {
    ring   <- spec$ring                          # sf circle (radius R), 8058
    ring_line <- ggplot2::geom_sf(data = sf::st_cast(sf::st_boundary(ring), "MULTILINESTRING"),
                                  fill = NA, colour = cols[["mark"]], linewidth = 0.7,
                                  linetype = "22")
    footprint <- if (!is.null(spec$footprint))
      ggplot2::geom_sf(data = spec$footprint, fill = NA, colour = "grey10", linewidth = 0.8) else NULL
    core <- gayini_area_map_core(
      area = ring, fill_layer = ctx$freq_layer,
      fill_spec = list(kind = "continuous", colours = ctx$freq_ramp, limits = c(0, 100),
                       name = "Flood\nfreq. (%)"),
      neighbours = spec$neighbours, outline = NULL,
      pad_buffer = spec$pad_buffer %||% 150,
      extra_layers = c(list(ring_line), if (!is.null(footprint)) list(footprint)),
      base_size = base_size, legend_position = "right")
    core <- core +
      ggplot2::labs(subtitle = sprintf("Flood frequency; %s neighbourhood ring (dashed), plot footprint",
                                       spec$radius_label))
    return(add_locator(core, spec$footprint %||% ring))
  }

  ## paddock / stratum -> discrete checkerboard
  classes <- ctx$classes
  if (spec$type == "stratum") {
    classes <- dplyr::mutate(classes,
      colour = ifelse(.data$code == spec$target_code, .data$colour, "#E6E6E6"))
    area <- ctx$boundary; outline <- ctx$boundary; neighbours <- ctx$management
    pad_buffer <- 200
    sub <- sprintf("Checkerboard, %s highlighted (others muted)", spec$label)
  } else {  # paddock
    area <- spec$geom; outline <- spec$geom; neighbours <- spec$neighbours
    pad_buffer <- spec$pad_buffer %||% 300
    sub <- "Community x wetness class per pixel (checkerboard)"
  }

  core <- gayini_area_map_core(
    area = area, fill_layer = ctx$class_layer,
    fill_spec = list(kind = "discrete", classes = classes),
    neighbours = neighbours, outline = outline, pad_buffer = pad_buffer,
    base_size = base_size, legend_position = "none")
  core <- core + ggplot2::labs(subtitle = sub)

  if (spec$type == "paddock") {
    ## Paddock: farm-locator inset top-left + the 3x3 community x wetness key as a
    ## boxed inset in the map's BOTTOM-RIGHT corner (on the raster, not a strip).
    legend_mini <- gayini_bivariate_legend_mini(ctx$classes, boxed = TRUE)
    cowplot::ggdraw(core) +
      cowplot::draw_plot(gayini_locator_inset(spec$geom, ctx$boundary, ctx$management),
                         x = 0.015, y = 0.66, width = 0.26, height = 0.30) +
      cowplot::draw_plot(legend_mini, x = 0.70, y = 0.10, width = 0.28, height = 0.40)
  } else {
    ## Stratum: whole-farm map with the class highlighted; subtitle names it, no key.
    core
  }
}


## 2. ANNUAL FLOODING panel ----
##
## Per-year between-year flood frequency (wet / valid years) for the unit, line +
## 35-yr mean. NO transition line. `series` = data.frame(year, freq_pct[, n_valid]).

gayini_panel_annual_flooding <- function(series, base_size = 10, unit_note = NULL,
                                         date_lim = NULL, date_breaks = NULL) {
  cols <- gayini_dashboard_cols()
  mean_freq <- mean(series$freq_pct, na.rm = TRUE)
  series$date <- gayini_year_to_date(series$year)

  ggplot2::ggplot(series, ggplot2::aes(x = date, y = freq_pct)) +
    ggplot2::geom_hline(yintercept = mean_freq, linetype = "dashed",
                        colour = "grey55", linewidth = 0.4) +
    ggplot2::annotate("text", x = min(series$date), y = mean_freq, vjust = -0.5, hjust = 0,
                      size = base_size / 3.6, colour = "grey45",
                      label = sprintf("35-yr mean %.0f%%", mean_freq)) +
    ggplot2::geom_line(colour = cols[["flood"]], linewidth = 0.6) +
    ggplot2::geom_point(colour = cols[["flood"]], size = 1.1) +
    gayini_series_date_scale(date_lim, date_breaks) +
    ggplot2::scale_y_continuous(limits = c(0, 100)) +
    ggplot2::labs(title = "Annual flooding, 1988-2023",
                  subtitle = paste0("Share of the unit wet each year (wet / valid years)",
                                    if (!is.null(unit_note)) paste0(" - ", unit_note) else ""),
                  x = NULL, y = "Flood freq. (%)") +
    gayini_dashboard_theme(base_size)
}


## 3. TOTAL VEGETATION panel ----
##
## `gc` = data.frame(date[Date], total_veg_pct, bare_ground_pct); aggregated for
## the unit upstream. No transition line.

gayini_panel_total_veg <- function(gc, base_size = 10, unit_note = NULL,
                                   date_lim = NULL, date_breaks = NULL,
                                   green_only = FALSE) {
  cols  <- gayini_dashboard_cols()
  ## green_only (stratum): plot the total-vegetation trace only, drop bare ground.
  covers <- if (green_only) "total_veg_pct" else c("total_veg_pct", "bare_ground_pct")
  long <- tidyr::pivot_longer(gc, dplyr::all_of(covers),
                              names_to = "cover", values_to = "pct")
  long$cover <- factor(long$cover, levels = c("total_veg_pct", "bare_ground_pct"),
                       labels = c("Total vegetation", "Bare ground"))

  p <- ggplot2::ggplot(long, ggplot2::aes(x = date, y = pct, colour = cover)) +
    ggplot2::geom_line(linewidth = 0.5, na.rm = TRUE) +
    ggplot2::scale_colour_manual(values = c("Total vegetation" = cols[["total_veg"]],
                                            "Bare ground" = cols[["bare"]]),
                                 name = NULL, drop = TRUE) +
    gayini_series_date_scale(date_lim, date_breaks) +
    ggplot2::scale_y_continuous(limits = c(0, 100)) +
    ggplot2::labs(title = if (green_only) "Total vegetation (green cover)" else "Total vegetation",
                  subtitle = paste0("Ground-cover series (remote sensing)",
                                    if (!is.null(unit_note)) paste0(" - ", unit_note) else ""),
                  x = NULL, y = "Cover (%)") +
    gayini_dashboard_theme(base_size)
  ## No legend needed when only the green line is drawn.
  if (green_only) p + ggplot2::theme(legend.position = "none")
  else p + ggplot2::theme(legend.position = "bottom",
                          legend.margin = ggplot2::margin(0, 0, 0, 0))
}


## 4. VEGETATION RESPONSE panel (F7) ----
##
## `resp` = list(subset (usable plot-years for the unit's plots),
##               community (usable plot-years for the whole community, context fit),
##               n_plots, community, colour, fallback[logical], small_n[logical]).
## x = annual_occurrence_pct (SECONDARY within-year wet-extent intensity).

gayini_panel_veg_response <- function(resp, base_size = 10) {
  comm_col <- resp$colour

  csl <- unname(gayini_gradient_short_labels()[resp$community_name])
  lab <- if (resp$fallback)
    sprintf("0 plots in unit\ncommunity context: %s", csl)
  else
    sprintf("n = %d plot%s in\n%s%s", resp$n_plots, ifelse(resp$n_plots == 1, "", "s"),
            csl, if (isTRUE(resp$small_n)) "  (small n)" else "")

  ## Default data = the community context points, so the binned-mean trend layer
  ## (which carries no data of its own) inherits it.
  p <- ggplot2::ggplot(resp$community,
                       ggplot2::aes(x = annual_occurrence_pct, y = total_veg_pct))
  if (nrow(resp$community) > 1) {
    p <- p +
      ggplot2::geom_point(data = resp$community, colour = comm_col, size = 0.5, alpha = 0.10) +
      ## binned conditional mean (+/-95% CI) reads the rise through the overplotting
      gayini_veg_response_trend(colour = "grey15")
  }
  if (!resp$fallback && nrow(resp$subset) > 0) {
    p <- p + ggplot2::geom_point(data = resp$subset, colour = comm_col, size = 1.7, alpha = 0.9)
  }
  p +
    ## annotation moved to the clear bottom-right corner (wet years rarely have low veg)
    ggplot2::annotate("text", x = Inf, y = -Inf, hjust = 1.05, vjust = -0.6,
                      size = base_size / 3.2, colour = "grey25", label = lab) +
    gayini_veg_response_scale(y_lo = 35) +
    ggplot2::labs(title = "Vegetation response",
                  subtitle = "Total veg vs wet-extent intensity (secondary; sqrt-x); grey = binned mean +/-95% CI",
                  x = "Annual wet extent (%, within-year, sqrt)", y = "Total veg (%)") +
    gayini_dashboard_theme(base_size)
}


## 5. BASELINE GAUGE panel (snapshot, not trend) ----
##
## recent window mean vs the unit's OWN long-run mean of the annual flooding
## series -> wetter / about the same / drier. Descriptive snapshot.

gayini_panel_baseline_gauge <- function(series, recent_n = 5, same_thresh = 5, base_size = 10,
                                        compact = FALSE) {
  cols <- gayini_dashboard_cols()
  longrun <- mean(series$freq_pct, na.rm = TRUE)
  recent  <- mean(utils::tail(series$freq_pct[order(series$year)], recent_n), na.rm = TRUE)
  delta   <- recent - longrun

  verdict <- if (abs(delta) < same_thresh) "About the same"
             else if (delta >= same_thresh) "Wetter than its own average"
             else "Drier than its own average"
  vcol <- if (abs(delta) < same_thresh) cols[["same"]]
          else if (delta >= same_thresh) cols[["wetter"]] else cols[["drier"]]

  marks <- data.frame(
    x = c(longrun, recent),
    lab = c(sprintf("long-run %.0f%%", longrun), sprintf("recent %.0f%%", recent)),
    kind = c("long-run", paste0("recent ", recent_n, " yr")))

  ## Compact (G4): a thin horizontal bar carrying the one comparison. The verdict
  ## rides in the subtitle; the track keeps both marks so the delta stays visible.
  if (compact) {
    return(
      ggplot2::ggplot() +
        ggplot2::geom_segment(ggplot2::aes(x = 0, xend = 100, y = 1, yend = 1),
                              colour = "grey85", linewidth = 3.0, lineend = "round") +
        ggplot2::geom_point(data = marks, ggplot2::aes(x = x, y = 1, shape = kind),
                            colour = c("grey40", vcol), size = c(3.2, 4.6)) +
        ggplot2::geom_text(data = marks, ggplot2::aes(x = x, y = 1, label = lab),
                           vjust = c(2.4, -1.8), size = base_size / 3.8,
                           colour = c("grey40", vcol)) +
        ggplot2::scale_shape_manual(values = c(18, 16), guide = "none") +
        ggplot2::scale_x_continuous(limits = c(0, 100)) +
        ggplot2::scale_y_continuous(limits = c(0.5, 1.5)) +
        ggplot2::labs(title = sprintf("Baseline gauge — %s (%+.0f pp)", verdict, delta),
                      x = "Flood freq. (%)", y = NULL) +
        gayini_dashboard_theme(base_size) +
        ggplot2::theme(axis.text.y = ggplot2::element_blank(),
                       panel.grid.major.y = ggplot2::element_blank(),
                       panel.grid.minor.x = ggplot2::element_blank(),
                       plot.title = ggplot2::element_text(face = "bold", colour = vcol,
                                                          size = base_size - 1)))
  }

  ggplot2::ggplot() +
    ggplot2::geom_segment(ggplot2::aes(x = 0, xend = 100, y = 1, yend = 1),
                          colour = "grey85", linewidth = 3.2, lineend = "round") +
    ggplot2::geom_point(data = marks, ggplot2::aes(x = x, y = 1, shape = kind),
                        colour = c("grey40", vcol), size = c(4, 5.5)) +
    ggplot2::geom_text(data = marks, ggplot2::aes(x = x, y = 1, label = lab),
                       vjust = c(2.6, -2.0), size = base_size / 3.4, colour = c("grey40", vcol)) +
    ggplot2::scale_shape_manual(values = c(18, 16), guide = "none") +
    ggplot2::scale_x_continuous(limits = c(0, 100)) +
    ggplot2::scale_y_continuous(limits = c(0.4, 1.6)) +
    ggplot2::labs(title = "Baseline gauge",
                  subtitle = paste0(verdict, "  (Δ ", sprintf("%+.0f pp", delta), ")"),
                  caption = "Recent window vs the unit's own long-run average. Snapshot, not trend.",
                  x = "Flood freq. (%)", y = NULL) +
    gayini_dashboard_theme(base_size) +
    ggplot2::theme(axis.text.y = ggplot2::element_blank(),
                   panel.grid.major.y = ggplot2::element_blank(),
                   plot.subtitle = ggplot2::element_text(face = "bold", colour = vcol,
                                                         size = base_size - 1))
}


## 6. "WHERE IT SITS" boxplot (F4-style) ----
##
## ABSOLUTE between-year flood frequency boxed by community (3 focus dry->wet +
## Woodland context), with THIS unit's value marked. Bands are relative and
## overlap across communities, so comparison is on absolute frequency only.
## `freq_by_plot` = gayini_plot_between_year_frequency(spine) |> gayini_apply_gradient_order().

gayini_panel_where_it_sits <- function(freq_by_plot, unit_value, unit_community,
                                       base_size = 10, show_kw = TRUE) {
  cols  <- gayini_dashboard_cols()
  pal   <- gayini_gradient_palette()
  short <- gayini_gradient_short_labels()

  kw_cap <- NULL
  if (show_kw) {
    kw <- tryCatch(stats::kruskal.test(flood_frequency_pct ~ simplified_vegetation_group,
                                       data = freq_by_plot), error = function(e) NULL)
    if (!is.null(kw))
      kw_cap <- sprintf("Kruskal-Wallis across communities: p = %s (descriptive)",
                        format.pval(kw$p.value, digits = 2, eps = 1e-3))
  }

  mark_df <- data.frame(simplified_vegetation_group = factor(unit_community, levels = levels(freq_by_plot$simplified_vegetation_group)),
                        flood_frequency_pct = unit_value)

  ggplot2::ggplot(freq_by_plot,
                  ggplot2::aes(x = simplified_vegetation_group, y = flood_frequency_pct)) +
    ggplot2::geom_boxplot(ggplot2::aes(fill = simplified_vegetation_group,
                                       alpha = is_focus_community),
                          width = 0.55, outlier.shape = NA, colour = "grey25", linewidth = 0.4) +
    ggplot2::geom_jitter(ggplot2::aes(colour = simplified_vegetation_group,
                                      alpha = is_focus_community),
                         width = 0.14, height = 0, size = 1.1) +
    ggplot2::geom_point(data = mark_df, shape = 23, size = 4.2, stroke = 1.1,
                        fill = cols[["mark"]], colour = "black") +
    ggplot2::annotate("text", x = mark_df$simplified_vegetation_group[1], y = unit_value,
                      label = sprintf("  this unit %.0f%%", unit_value),
                      hjust = 0, vjust = -1.1, size = base_size / 3.3, fontface = "bold",
                      colour = cols[["mark"]]) +
    ggplot2::scale_fill_manual(values = pal, guide = "none") +
    ggplot2::scale_colour_manual(values = pal, guide = "none") +
    ggplot2::scale_alpha_manual(values = c("TRUE" = 0.85, "FALSE" = 0.30), guide = "none") +
    ggplot2::scale_x_discrete(labels = function(x) stringr::str_wrap(short[x], 12)) +
    ggplot2::scale_y_continuous(limits = c(0, 105)) +
    ggplot2::labs(title = "Where it sits (by community)",
                  subtitle = "Absolute annual wet frequency; bands overlap across communities, so compare on frequency",
                  caption = kw_cap, x = NULL, y = "Annual wet freq. (% of years)") +
    gayini_dashboard_theme(base_size) +
    ggplot2::theme(axis.text.x = ggplot2::element_text(size = base_size - 3))
}


## 7. GAUGE FLOW context panel (SITE only, secondary) ----
##
## `gauge` = data.frame(year, flow_mld); a background hydrology strip.

gayini_panel_gauge_flow <- function(gauge, station_label = NULL, base_size = 10,
                                    date_lim = NULL, date_breaks = NULL) {
  cols <- gayini_dashboard_cols()
  gauge$date <- gayini_year_to_date(gauge$year)
  ggplot2::ggplot(gauge, ggplot2::aes(x = date, y = flow_mld)) +
    ggplot2::geom_line(colour = cols[["gauge"]], linewidth = 0.5) +
    ggplot2::geom_point(colour = cols[["gauge"]], size = 0.9) +
    gayini_series_date_scale(date_lim, date_breaks) +
    ggplot2::labs(title = "Gauge flow context (background)",
                  subtitle = paste0("Murrumbidgee water-year mean flow",
                                    if (!is.null(station_label)) paste0(" - ", station_label) else ""),
                  x = NULL, y = "Flow (ML/d)") +
    gayini_dashboard_theme(base_size)
}
