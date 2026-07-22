# ------------------------------------------------------------------------------
# Script: scripts/03_inundation_products/23_build_s25_lag_profile_figure.R
# Purpose: Tier 2 · Task H · Gate E (G5) — S25: the cover→inundation LAG profile.
#          This is the one figure that STAYS PLOT SUPPORT, deliberately and
#          visibly. The lag needs sub-annual per-pixel inundation, which exists
#          only from 2014 and was never built per-pixel — so a per-pixel lag is
#          NOT available without a heavy new product (a separate gate). Rendering
#          the committed plot-support lag instead, with the reduced support made
#          UNMISSABLE so it can never borrow S24/S26's ~1M-pixel authority:
#            - point SIZE ∝ n_plots (Aeolian n=2–3 tiny · Inland n=15–17 large),
#            - n labelled at every point,
#            - a "PLOT SUPPORT — NOT all-pixel" banner + the 2014–2025 window.
#
# Workflow stage: 03_inundation_products · Tier 2 Task H, Gate E, G5 (S25)
# Run mode: figure render (reads the committed plot lag table) · additive · read-only
# Key inputs:
#   - Output/csv/f7_lag_profile.csv  (per community x lag: n_plots, median_r, q25_r, q75_r)
# Key outputs (additive; Output/ gitignored; NOT registered — that is G7):
#   - Output/figures/S25_lag_profile_data.{png,pdf}
#
# SUPPORT DISCIPLINE (the whole point of this figure):
#   Same-year (S24/S26) is FULLY ALL-PIXEL. The lag is PLOT SUPPORT and record-limited
#   (monthly inundation 2014-08→2025-05; ~11 yr; n = 2–17 plots per lag). Never merge the
#   two supports into one "F7 is all-pixel" claim. Fig B style otherwise (community-hue
#   line, grey q25–q75 band). Peak response at ~3 months for all three communities.
# ------------------------------------------------------------------------------

## 1. Sources ----

root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", getwd()), winslash = "/", mustWork = TRUE)

source(file.path(root_dir, "R", "gayini_helpers.R"))
source(file.path(root_dir, "R", "gayini_output_helpers.R"))
source(file.path(root_dir, "R", "gayini_gradient_helpers.R"))
source(file.path(root_dir, "R", "gayini_veg_regime_functions.R"))
source(file.path(root_dir, "R", "gayini_descriptive_figures.R"))

suppressPackageStartupMessages({ library(dplyr); library(ggplot2) })

csv_dir     <- file.path(root_dir, "Output", "csv")
figures_dir <- file.path(root_dir, "Output", "figures")
lag_csv <- file.path(csv_dir, "f7_lag_profile.csv")
gayini_stop_if_missing(lag_csv, label = "plot lag profile (f7_lag_profile.csv)")


## 2. Palette + data ----

classes  <- gayini_veg_regime_classes()
comm_hue <- classes |> dplyr::filter(.data$band == "mid") |>
  (\(x) stats::setNames(x$colour, x$community))()
focus    <- gayini_focus_levels()

## Short facet labels keep the small panels readable.
short_lab <- stats::setNames(c("Aeolian (dry)", "Riverine", "Inland (wet)"), focus)

d <- readr::read_csv(lag_csv, show_col_types = FALSE) |>
  dplyr::rename(community = simplified_vegetation_group) |>
  dplyr::filter(.data$community %in% focus) |>
  dplyr::mutate(community = factor(community, levels = focus))
stopifnot(nrow(d) >= 12L, all(c(0,3,6,9,12) %in% d$lag_months))

## Peak lag per community (the "~3-month" story), for the marker.
peak <- d |> dplyr::group_by(community) |>
  dplyr::slice_max(median_r, n = 1, with_ties = FALSE) |> dplyr::ungroup()


## 3. Build (Fig B style: community-hue line, grey q25–q75 band; reduced n made visible) ----

p <- ggplot2::ggplot(d, ggplot2::aes(x = lag_months, y = median_r)) +
  ggplot2::geom_hline(yintercept = 0, colour = "grey60", linewidth = 0.4) +
  ## shared "~3-month peak" guide.
  ggplot2::geom_vline(xintercept = 3, colour = "grey75", linewidth = 0.4, linetype = "22") +
  ## grey uncertainty band = per-plot IQR (q25–q75).
  ggplot2::geom_ribbon(ggplot2::aes(ymin = q25_r, ymax = q75_r), fill = "grey75", alpha = 0.55) +
  ## community-hue central line (identity).
  ggplot2::geom_line(ggplot2::aes(colour = community), linewidth = 1.1) +
  ## points SIZED by n_plots — the reduced support, made visible (tiny = few plots).
  ggplot2::geom_point(ggplot2::aes(colour = community, size = n_plots)) +
  ## n labelled at every point (belt and braces on the support).
  ggplot2::geom_text(ggplot2::aes(label = paste0("n=", n_plots)),
                     vjust = -1.1, size = 2.6, colour = "grey30") +
  ## mark the peak lag.
  ggplot2::geom_point(data = peak, ggplot2::aes(x = lag_months, y = median_r),
                      shape = 21, size = 5, stroke = 0.8, colour = "grey20", fill = NA) +
  ggplot2::facet_wrap(~ community, nrow = 1,
                      labeller = ggplot2::labeller(community = short_lab)) +
  ggplot2::scale_colour_manual(values = comm_hue, guide = "none") +
  ggplot2::scale_size_continuous(name = "plots (n)", range = c(1.6, 5.2),
                                 breaks = c(3, 8, 15), limits = c(0, 18)) +
  ggplot2::scale_x_continuous(name = "lag (months): cover at t  vs  inundation intensity at t − lag",
                              breaks = c(0, 3, 6, 9, 12)) +
  ggplot2::scale_y_continuous(name = "median per-plot correlation  r",
                              limits = c(min(d$q25_r) - 0.05, max(d$q75_r) + 0.1)) +
  ggplot2::labs(
    title = "S25 · Cover response lag — PLOT SUPPORT (not all-pixel)",
    subtitle = paste0("⚠ PLOT SUPPORT: n = 2–17 plots per lag (point size = n), monthly window 2014–2025. ",
                      "This is NOT all-pixel, unlike S24/S26 —\na per-pixel lag needs sub-annual per-pixel ",
                      "inundation, which exists only from 2014 and is not built. Peak response ≈ 3 months (ringed)."),
    caption = paste0(
      "SUPPORT: same-year response (S24/S26) is fully all-pixel (~1M pixels); this lag is PLOT support and record-limited — never merge the two. ",
      "Point size and the n labels show the support directly: Aeolian rests on 2–3 plots.\n",
      "Line = median per-plot r (community hue); grey band = per-plot IQR (q25–q75). Small n → wide, unstable intervals: do not over-read a single community's curve. ",
      "Landsat FC measures cover, not ecological condition.")) +
  ggplot2::theme_minimal(base_size = 12) +
  ggplot2::theme(
    plot.title = ggplot2::element_text(face = "bold", size = 13.5),
    plot.subtitle = ggplot2::element_text(size = 9, colour = "grey25", margin = ggplot2::margin(b = 8)),
    plot.caption = ggplot2::element_text(size = 7.6, colour = "grey35", hjust = 0, margin = ggplot2::margin(t = 10)),
    plot.caption.position = "plot", plot.title.position = "plot",
    strip.text = ggplot2::element_text(face = "bold", size = 10.5),
    panel.grid.minor = ggplot2::element_blank(),
    panel.spacing = ggplot2::unit(1.1, "lines"),
    legend.position = "top", legend.justification = "right", legend.margin = ggplot2::margin(b = -4))


## 4. Save ----

paths <- gayini_save_figure(p, figures_dir, "S25_lag_profile", kind = "data",
                            width = 10.4, height = 4.8, dpi = 300)

message("\n==================== G5 (S25) COMPLETE — STOP FOR REVIEW ====================")
message("Lag figure: ", paths$png)
message("PLOT SUPPORT (n = 2–17 plots), 2014–2025 window — reduced support shown via point size + n labels + banner.")
message("Peak ~3 months all communities. Same-year (S24/S26) all-pixel; lag plot-support — supports NOT merged.")
message("NOT registered (G7). STOP: review S25, then G6 (cleanups) + G7 (non-destructive registration).")
