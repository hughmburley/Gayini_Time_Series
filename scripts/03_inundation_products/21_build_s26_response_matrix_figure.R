# ------------------------------------------------------------------------------
# Script: scripts/03_inundation_products/21_build_s26_response_matrix_figure.R
# Purpose: Tier 2 · Task H · Gate E (G5, matrix-first) — S26: the 3x3
#          community x wetness veg-response matrix. Fig B style (§F): p50 in the
#          community hue, graded NEUTRAL GREY quantile bands. Renders the G1b
#          per-pixel same-year response as the PRIMARY encoding (r quantile bands),
#          with the wet-dry cover magnitude as a per-cell annotation so low-r is
#          never misread as no-effect, the two special cells handled honestly, and
#          the plot-support r kept visible as a reference (Aeolian-high inversion).
#
# Workflow stage: 03_inundation_products · Tier 2 Task H, Gate E, G5 (S26 first)
# Run mode: figure render (reads the committed G1b table) · additive · read-only
# Key inputs:
#   - Output/diagnostics/tier2H_g1b_census_veg_wet_response_by_stratum.csv  (G1b; # caveat header)
# Key outputs (additive; Output/ gitignored; NOT registered — that is G7):
#   - Output/figures/S26_response_matrix_data.{png,pdf}
#
# PALETTE — sourced from the repo, NOT retyped (audit resolved 2026-07-21, Hugh):
#   Fig B p50 = the C1 CHECKERBOARD community hues = gayini_veg_regime_classes() mid band
#   (Aeolian #C79A3C · Riverine #3FAE97 · Inland #2E6DB0). This is committed and drives the
#   C1 checkerboard + flood-zone maps; §F names C1 as the consistency target. (The
#   "biodiversity-config" hues §F cites are NOT committed anywhere; the F7 gradient palette is a
#   SECOND committed set — deck was carrying two. Recorded in the change report for §F/CLAUDE fix.)
#
# HONESTY (per §F + Hugh, printed in the caption):
#   - r measures the CONSISTENCY of the response, not its SIZE. Dry bands have the largest
#     wet-dry cover jumps (Δ, annotated) but the lowest r — saturation, not "no effect".
#   - Aeolian low NEVER floods -> a same-year response cannot be asked there: a distinct
#     "not measurable" state, NOT a low or blank band.
#   - ~1M pixels collapse SAMPLING uncertainty only; pixels are NOT independent n (spatial +
#     temporal autocorrelation), and Landsat FC measures cover, not ecological condition.
#   - Hollow marker = plot-support r (reference). Aeolian-high plot->census inversion left visible;
#     Aeolian-low shows a plot r (plots pool ~16 px, any-water rule) where the census per-pixel is
#     undefined — the plot-vs-pixel support difference, made visible.
# ------------------------------------------------------------------------------

## 1. Sources ----

root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", getwd()), winslash = "/", mustWork = TRUE)

source(file.path(root_dir, "R", "gayini_helpers.R"))
source(file.path(root_dir, "R", "gayini_output_helpers.R"))
source(file.path(root_dir, "R", "gayini_gradient_helpers.R"))
source(file.path(root_dir, "R", "gayini_veg_regime_functions.R"))   # C1 palette (committed source of truth)
source(file.path(root_dir, "R", "gayini_descriptive_figures.R"))    # gayini_save_figure

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
})

diagnostics_dir <- file.path(root_dir, "Output", "diagnostics")
figures_dir     <- file.path(root_dir, "Output", "figures")
strat_csv <- file.path(diagnostics_dir, "tier2H_g1b_census_veg_wet_response_by_stratum.csv")
gayini_stop_if_missing(strat_csv, label = "G1b by-stratum table")

R_RESPOND <- 0.20   # the "responds" reference (matches G1b verdict logic; flagged Adrian Q3 family)


## 2. Community hues — from the committed C1 palette, keyed by community ----

classes  <- gayini_veg_regime_classes()
mid_hue  <- classes |> dplyr::filter(.data$band == "mid")
comm_hue <- stats::setNames(mid_hue$colour, mid_hue$community)   # Aeolian/Riverine/Inland -> hex
focus    <- gayini_focus_levels()
band_lv  <- c("high", "mid", "low")   # REVERSED so low plots at TOP -> dry→wet climbs downward
                                      # (was c("low","mid","high") — my earlier choice, not a factor default)


## 3. Load the G1b cell table (skip the # caveat header) ----

d <- readr::read_csv(strat_csv, comment = "#", show_col_types = FALSE) |>
  dplyr::mutate(
    community   = factor(community, levels = focus),
    regime_band = factor(regime_band, levels = band_lv),
    measurable  = .data$n_pixels_response > 0
  )
stopifnot(nrow(d) == 9L, all(!is.na(d$community)), all(!is.na(d$regime_band)))

meas   <- d |> dplyr::filter(.data$measurable)
unmeas <- d |> dplyr::filter(!.data$measurable)   # Aeolian low (never floods)

## Right-hand gutter positions for annotations (kept off the data range).
X_MIN <- -0.12; X_DATA_MAX <- 0.56
X_BAR0    <- 0.60           # common left origin for the Δ magnitude bars (all bars share it)
DELTA_SCALE <- 0.011       # cover-points -> x-units for the Δ bar (max Δ ~11.1 -> ~0.12 wide)
X_VERDICT <- 0.86; X_MAX <- 1.06
BAND_H    <- 0.30          # half-height of the p25-p75 box in y-units
Y_HEADER  <- 3.72          # gutter/threshold header row, above the top (low) band


## 4. Build the figure ----

verdict_lab <- c(responds = "responds", weak_or_none = "weak / none",
                 mixed = "mixed", coverage_limited = "coverage-limited",
                 undetermined = "not measurable")

## Native per-community grouping: one faint hue wash per panel (flip-proof; no fixed-y rects).
bg  <- tibble::tibble(community = factor(focus, levels = focus))
## Gutter/threshold headers live in the top (Aeolian) panel only.
hdr <- tibble::tibble(community = factor(focus[1], levels = focus))

p <- ggplot2::ggplot(meas, ggplot2::aes(y = regime_band)) +
  ## per-community ~6% hue wash — groups the three bands as a real panel background.
  ggplot2::geom_rect(data = bg, inherit.aes = FALSE,
                     ggplot2::aes(xmin = -Inf, xmax = Inf, ymin = -Inf, ymax = Inf, fill = community),
                     alpha = 0.06) +
  ## reference lines: no response (0) and the "responds" threshold (darker, labelled below).
  ggplot2::geom_vline(xintercept = 0,          colour = "grey55", linewidth = 0.5) +
  ggplot2::geom_vline(xintercept = R_RESPOND,  colour = "grey40", linewidth = 0.6, linetype = "22") +
  ## outer band p10-p90 (light grey whisker).
  ggplot2::geom_linerange(ggplot2::aes(xmin = r_p10, xmax = r_p90),
                          colour = "grey78", linewidth = 1.1) +
  ## inner band p25-p75 (darker grey box).
  ggplot2::geom_rect(ggplot2::aes(xmin = r_p25, xmax = r_p75,
                                  ymin = as.integer(regime_band) - BAND_H,
                                  ymax = as.integer(regime_band) + BAND_H),
                     fill = "grey52", colour = NA) +
  ## p50 median = community hue (identity). Vertical tick.
  ggplot2::geom_segment(ggplot2::aes(x = r_p50, xend = r_p50,
                                     y = as.integer(regime_band) - BAND_H - 0.04,
                                     yend = as.integer(regime_band) + BAND_H + 0.04,
                                     colour = community), linewidth = 1.7) +
  ## r value above each box (lifted clear of the band above).
  ggplot2::geom_text(ggplot2::aes(x = r_p50, y = as.integer(regime_band) + BAND_H + 0.25,
                                  label = sprintf("r = %.2f", median_r)),
                     size = 2.8, colour = "grey25") +
  ## plot-support r reference (hollow diamond) — measurable rows.
  ggplot2::geom_point(ggplot2::aes(x = plot_median_r_veg, shape = "Plot-support r (reference)"),
                      size = 2.5, stroke = 0.7, fill = NA, colour = "grey15") +
  ## --- Δ wet-dry magnitude: a community-hue BAR scaled to Δ (co-equal to the r line) + bold value ---
  ggplot2::geom_rect(ggplot2::aes(xmin = X_BAR0, xmax = X_BAR0 + wet_minus_dry_veg_pts * DELTA_SCALE,
                                  ymin = as.integer(regime_band) - 0.11,
                                  ymax = as.integer(regime_band) + 0.11, fill = community),
                     colour = NA) +
  ggplot2::geom_text(ggplot2::aes(x = X_BAR0 + wet_minus_dry_veg_pts * DELTA_SCALE + 0.012,
                                  label = sprintf("+%.1f", wet_minus_dry_veg_pts)),
                     size = 3.1, hjust = 0, fontface = "bold", colour = "grey15") +
  ## verdict text, far-right gutter.
  ggplot2::geom_text(ggplot2::aes(x = X_VERDICT, label = verdict_lab[verdict]),
                     size = 2.8, hjust = 0, colour = "grey35") +
  ## --- unmeasurable cell (Aeolian low): distinct "never floods" state ---
  ggplot2::geom_rect(data = unmeas, inherit.aes = FALSE,
                     ggplot2::aes(xmin = X_MIN, xmax = X_DATA_MAX,
                                  ymin = as.integer(regime_band) - BAND_H - 0.06,
                                  ymax = as.integer(regime_band) + BAND_H + 0.06),
                     fill = "grey92", colour = "grey70", linetype = "33") +
  ggplot2::geom_text(data = unmeas, inherit.aes = FALSE,
                     ggplot2::aes(x = (X_MIN + X_DATA_MAX) / 2, y = regime_band,
                                  label = "never floods — same-year response not measurable"),
                     size = 2.9, fontface = "italic", colour = "grey35") +
  ## plot r still shown on the unmeasurable row (plots pool ~16 px, any-water rule).
  ggplot2::geom_point(data = unmeas, inherit.aes = FALSE,
                      ggplot2::aes(x = plot_median_r_veg, y = regime_band, shape = "Plot-support r (reference)"),
                      size = 2.5, stroke = 0.7, fill = NA, colour = "grey15") +
  ## --- headers (top Aeolian panel only): threshold label + Δ gutter label ---
  ggplot2::geom_text(data = hdr, inherit.aes = FALSE,
                     ggplot2::aes(x = R_RESPOND + 0.008, y = Y_HEADER, label = "‘responds’ ≥ 0.20"),
                     size = 2.7, hjust = 0, colour = "grey40") +
  ggplot2::geom_text(data = hdr, inherit.aes = FALSE,
                     ggplot2::aes(x = X_BAR0, y = Y_HEADER, label = "wet − dry cover (Δ, pts)"),
                     size = 2.7, hjust = 0, colour = "grey40") +
  ggplot2::facet_grid(rows = ggplot2::vars(community), switch = "y",
                      scales = "free_y", space = "free_y",
                      labeller = ggplot2::labeller(community = function(x) gsub(" / ", " /\n", x))) +
  ggplot2::scale_colour_manual(values = comm_hue, guide = "none") +
  ggplot2::scale_fill_manual(values = comm_hue, guide = "none") +
  ggplot2::scale_shape_manual(name = NULL, values = c("Plot-support r (reference)" = 5)) +
  ggplot2::scale_x_continuous(
    name = "Per-pixel same-year response  r (annual total-veg vs annual wet/dry state, 1988–2023)",
    breaks = c(0, 0.2, 0.4), limits = c(X_MIN, X_MAX),
    expand = ggplot2::expansion(mult = c(0, 0))) +
  ggplot2::scale_y_discrete(name = NULL, expand = ggplot2::expansion(add = 0.9)) +
  ggplot2::labs(
    title = "S26 · The veg × wetness response census (per-pixel, same-year)",
    subtitle = paste0("Pixel support (census, 24.97 m), all census pixels, 1988–2023.\n",
                      "Coloured line = median response (community hue); grey bands = per-pixel spread ",
                      "(p25–p75 dark, p10–p90 light); dashed = “responds” ≥ 0.20."),
    caption = paste0(
      "r measures the CONSISTENCY of the response, not its size: the driest bands show the LARGEST per-flood cover gains (Δ = median wet-year − dry-year cover) but the LOWEST r — saturation, not “no effect”.\n",
      "Aeolian low never floods in 35 years, so a same-year response cannot be asked there — a result, not a gap.\n",
      "The ~1M pixels collapse SAMPLING uncertainty only: they are NOT independent n (spatial + temporal autocorrelation), and Landsat fractional cover measures COVER, not condition — a narrow band is not certainty.\n",
      "Hollow diamond = plot-support r (reference): note Aeolian high (plots ‘responds’, census does not), and Aeolian low (a plot r exists where the per-pixel census is undefined — the plot-vs-pixel support difference).")) +
  ggplot2::theme_minimal(base_size = 12) +
  ggplot2::theme(
    plot.title = ggplot2::element_text(face = "bold", size = 13.5),
    plot.subtitle = ggplot2::element_text(size = 9.5, colour = "grey30", margin = ggplot2::margin(b = 8)),
    plot.caption = ggplot2::element_text(size = 7.6, colour = "grey35", hjust = 0,
                                         margin = ggplot2::margin(t = 10)),
    plot.caption.position = "plot",
    plot.title.position = "plot",
    strip.text.y.left = ggplot2::element_text(angle = 0, face = "bold", size = 9.5, hjust = 1),
    strip.placement = "outside",
    panel.border = ggplot2::element_rect(colour = "grey85", fill = NA, linewidth = 0.4),
    panel.grid.major.y = ggplot2::element_blank(),
    panel.grid.minor = ggplot2::element_blank(),
    panel.grid.major.x = ggplot2::element_line(colour = "grey93"),
    panel.spacing = ggplot2::unit(0.7, "lines"),
    axis.text.y = ggplot2::element_text(size = 9),
    ## title centred under the DATA region, not the full panel (which includes the right gutter).
    axis.title.x = ggplot2::element_text(size = 9.5, hjust = 0.32, margin = ggplot2::margin(t = 6)),
    legend.position = "top", legend.justification = "right",
    legend.margin = ggplot2::margin(b = -4))


## 5. Save (one figure = one file = one slide) ----

paths <- gayini_save_figure(p, figures_dir, "S26_response_matrix", kind = "data",
                            width = 10.8, height = 7.8, dpi = 300)

message("\n==================== G5 (S26) COMPLETE — STOP FOR REVIEW ====================")
message("Matrix figure: ", paths$png)
message("Palette: C1 checkerboard community hues (committed), grey uncertainty bands, Fig B style.")
message("Encodes: response r (primary, quantile bands) + wet-dry Δ (annotation) + plot-r (reference).")
message("Aeolian low rendered as 'not measurable'; Aeolian-high inversion visible.")
message("NOT registered (G7). STOP: review S26 before S24 (collapse) / S25 (lag).")
