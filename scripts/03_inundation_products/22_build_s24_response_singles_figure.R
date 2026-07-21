# ------------------------------------------------------------------------------
# Script: scripts/03_inundation_products/22_build_s24_response_singles_figure.R
# Purpose: Tier 2 · Task H · Gate E (G5) — S24: the per-community response singles,
#          the COLLAPSE of the S26 matrix (pool wetness bands within community).
#          Same Fig B style as S26 (p50 in the community hue, grey quantile bands),
#          the same Δ wet-dry magnitude bar, and the same plot-support r diamond.
#
#          One row per community (3), each the per-pixel same-year response pooled
#          over all wetness bands. Derived from the SAME G1b computation as S26 —
#          this is a reduction of the matrix, not a separate analysis.
#
# Workflow stage: 03_inundation_products · Tier 2 Task H, Gate E, G5 (S24 = S26 collapsed)
# Run mode: figure render (reads the committed G1b by-community table) · additive · read-only
# Key inputs:
#   - Output/diagnostics/tier2H_g1b_census_veg_wet_response_by_community.csv  (G1b; # caveat header)
# Key outputs (additive; Output/ gitignored; NOT registered — that is G7):
#   - Output/figures/S24_response_singles_data.{png,pdf}
#
# PALETTE: C1 checkerboard community hues from gayini_veg_regime_classes() (committed; see S26 note).
# HONESTY (same as S26): r = CONSISTENCY not size (Δ is the magnitude); pixels are NOT independent n;
#   FC measures cover, not condition. Aeolian pools to a measurable r because its mid/high bands DO
#   flood — but 42% of Aeolian pixels never flood (stated in the subtitle), so its community r sits on
#   the floodable minority. Plot-support r kept as a hollow-diamond reference (Aeolian/Riverine on-plot;
#   Inland pulled DOWN vs the plots — the all-pixel correction).
# ------------------------------------------------------------------------------

## 1. Sources ----

root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", getwd()), winslash = "/", mustWork = TRUE)

source(file.path(root_dir, "R", "gayini_helpers.R"))
source(file.path(root_dir, "R", "gayini_output_helpers.R"))
source(file.path(root_dir, "R", "gayini_gradient_helpers.R"))
source(file.path(root_dir, "R", "gayini_veg_regime_functions.R"))
source(file.path(root_dir, "R", "gayini_descriptive_figures.R"))

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
})

diagnostics_dir <- file.path(root_dir, "Output", "diagnostics")
figures_dir     <- file.path(root_dir, "Output", "figures")
comm_csv <- file.path(diagnostics_dir, "tier2H_g1b_census_veg_wet_response_by_community.csv")
gayini_stop_if_missing(comm_csv, label = "G1b by-community table")

R_RESPOND <- 0.20


## 2. Palette + data ----

classes  <- gayini_veg_regime_classes()
comm_hue <- classes |> dplyr::filter(.data$band == "mid") |>
  (\(x) stats::setNames(x$colour, x$community))()
focus    <- gayini_focus_levels()

d <- readr::read_csv(comm_csv, comment = "#", show_col_types = FALSE) |>
  dplyr::mutate(community = factor(community, levels = rev(focus)))   # rev -> Aeolian TOP, Inland bottom
stopifnot(nrow(d) == 3L, all(!is.na(d$community)))

verdict_lab <- c(responds = "responds", weak_or_none = "weak / none",
                 mixed = "mixed", coverage_limited = "coverage-limited",
                 undetermined = "not measurable")

## Gutter geometry (shared idiom with S26).
X_MIN <- -0.12; X_BAR0 <- 0.60; DELTA_SCALE <- 0.011
X_VERDICT <- 0.86; X_MAX <- 1.06; BAND_H <- 0.30; Y_HEADER <- 3.62


## 3. Build ----

## Per-row faint hue wash (single panel, no band-flip -> fixed-y rects are safe here).
bg <- d |> dplyr::transmute(community,
                            yc = as.integer(community),
                            ymin = yc - 0.5, ymax = yc + 0.5)

p <- ggplot2::ggplot(d, ggplot2::aes(y = community)) +
  ggplot2::geom_rect(data = bg, inherit.aes = FALSE,
                     ggplot2::aes(xmin = -Inf, xmax = Inf, ymin = ymin, ymax = ymax, fill = community),
                     alpha = 0.06) +
  ggplot2::geom_vline(xintercept = 0,         colour = "grey55", linewidth = 0.5) +
  ggplot2::geom_vline(xintercept = R_RESPOND, colour = "grey40", linewidth = 0.6, linetype = "22") +
  ## outer p10-p90 whisker + inner p25-p75 box.
  ggplot2::geom_linerange(ggplot2::aes(xmin = r_p10, xmax = r_p90), colour = "grey78", linewidth = 1.2) +
  ggplot2::geom_rect(ggplot2::aes(xmin = r_p25, xmax = r_p75,
                                  ymin = as.integer(community) - BAND_H,
                                  ymax = as.integer(community) + BAND_H),
                     fill = "grey52", colour = NA) +
  ## p50 median = community hue.
  ggplot2::geom_segment(ggplot2::aes(x = r_p50, xend = r_p50,
                                     y = as.integer(community) - BAND_H - 0.04,
                                     yend = as.integer(community) + BAND_H + 0.04,
                                     colour = community), linewidth = 1.9) +
  ggplot2::geom_text(ggplot2::aes(x = r_p50, y = as.integer(community) + BAND_H + 0.22,
                                  label = sprintf("r = %.2f", median_r)),
                     size = 3.0, colour = "grey25") +
  ## plot-support r reference (hollow diamond).
  ggplot2::geom_point(ggplot2::aes(x = plot_median_r_veg, shape = "Plot-support r (reference)"),
                      size = 2.7, stroke = 0.8, fill = NA, colour = "grey15") +
  ## Δ wet-dry magnitude bar (community hue, co-equal to the r line) + bold value.
  ggplot2::geom_rect(ggplot2::aes(xmin = X_BAR0, xmax = X_BAR0 + wet_minus_dry_veg_pts * DELTA_SCALE,
                                  ymin = as.integer(community) - 0.12,
                                  ymax = as.integer(community) + 0.12, fill = community), colour = NA) +
  ggplot2::geom_text(ggplot2::aes(x = X_BAR0 + wet_minus_dry_veg_pts * DELTA_SCALE + 0.012,
                                  label = sprintf("+%.1f", wet_minus_dry_veg_pts)),
                     size = 3.3, hjust = 0, fontface = "bold", colour = "grey15") +
  ggplot2::geom_text(ggplot2::aes(x = X_VERDICT, label = verdict_lab[verdict]),
                     size = 3.0, hjust = 0, colour = "grey35") +
  ## headers (top row).
  ggplot2::geom_text(data = d[1, ], inherit.aes = FALSE,
                     ggplot2::aes(x = R_RESPOND + 0.008, y = Y_HEADER, label = "‘responds’ ≥ 0.20"),
                     size = 2.8, hjust = 0, colour = "grey40") +
  ggplot2::geom_text(data = d[1, ], inherit.aes = FALSE,
                     ggplot2::aes(x = X_BAR0, y = Y_HEADER, label = "wet − dry cover (Δ, pts)"),
                     size = 2.8, hjust = 0, colour = "grey40") +
  ggplot2::scale_colour_manual(values = comm_hue, guide = "none") +
  ggplot2::scale_fill_manual(values = comm_hue, guide = "none") +
  ggplot2::scale_shape_manual(name = NULL, values = c("Plot-support r (reference)" = 5)) +
  ggplot2::scale_x_continuous(
    name = "Per-pixel same-year response  r (annual total-veg vs annual wet/dry state, 1988–2023)",
    breaks = c(0, 0.2, 0.4), limits = c(X_MIN, X_MAX), expand = ggplot2::expansion(mult = c(0, 0))) +
  ggplot2::scale_y_discrete(name = NULL, expand = ggplot2::expansion(add = 0.75),
                            labels = function(x) gsub(" / ", " /\n", x)) +
  ggplot2::labs(
    title = "S24 · The veg × wetness response, per community (matrix collapsed)",
    subtitle = paste0("Pixel support (census, 24.97 m); wetness bands pooled within community. ",
                      "Response measurable on 58% / 86% / 97% of Aeolian / Riverine / Inland pixels\n",
                      "(the remainder never flood). Coloured line = median response (community hue); ",
                      "grey bands = per-pixel spread (p25–p75 dark, p10–p90 light); dashed = “responds” ≥ 0.20."),
    caption = paste0(
      "r measures the CONSISTENCY of the response, not its size — the Δ bar is the magnitude (median wet-year − dry-year cover). Aeolian pools to a measurable r on its floodable pixels.\n",
      "The dry→wet strengthening is sharpened at census (r 0.17 → 0.23 → 0.35). The ~1M pixels collapse SAMPLING uncertainty only: NOT independent n (spatial + temporal autocorrelation);\n",
      "Landsat fractional cover measures COVER, not condition — a narrow band is not certainty. Hollow diamond = plot-support r (reference): Aeolian/Riverine on-plot, Inland pulled DOWN vs the plots (0.35 vs 0.42).")) +
  ggplot2::theme_minimal(base_size = 12) +
  ggplot2::theme(
    plot.title = ggplot2::element_text(face = "bold", size = 13.5),
    plot.subtitle = ggplot2::element_text(size = 9.5, colour = "grey30", margin = ggplot2::margin(b = 8)),
    plot.caption = ggplot2::element_text(size = 7.6, colour = "grey35", hjust = 0, margin = ggplot2::margin(t = 10)),
    plot.caption.position = "plot", plot.title.position = "plot",
    panel.grid.major.y = ggplot2::element_blank(), panel.grid.minor = ggplot2::element_blank(),
    panel.grid.major.x = ggplot2::element_line(colour = "grey93"),
    axis.text.y = ggplot2::element_text(size = 10, face = "bold", lineheight = 0.9),
    axis.title.x = ggplot2::element_text(size = 9.5, hjust = 0.32, margin = ggplot2::margin(t = 6)),
    legend.position = "top", legend.justification = "right", legend.margin = ggplot2::margin(b = -4))


## 4. Save ----

paths <- gayini_save_figure(p, figures_dir, "S24_response_singles", kind = "data",
                            width = 10.8, height = 5.4, dpi = 300)

message("\n==================== G5 (S24) COMPLETE — STOP FOR REVIEW ====================")
message("Singles figure: ", paths$png)
message("Collapse of S26 (wetness pooled within community). Same Fig B style + Δ bar + plot diamond.")
message("Dry→wet strengthening: r 0.17 → 0.23 → 0.35; Inland pulled down vs plots (0.35 vs 0.42).")
message("NOT registered (G7). STOP: review S24 before S25 (record-limited lag).")
