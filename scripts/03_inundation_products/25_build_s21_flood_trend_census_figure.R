# ------------------------------------------------------------------------------
# Script: scripts/03_inundation_products/25_build_s21_flood_trend_census_figure.R
# Purpose: Tier 2 · Task H · Gate E (G5) — S21: the all-pixel (census) flood-trend
#          figure. THE HYDROLOGY HEADLINE — "is flood frequency trending?" answered
#          on every census pixel, not the 40-plot F5 sample. Re-render of the F6
#          3×3 strata-trends in the SAME grammar as the committed plot figure, but:
#            - census verdict = 9 no-trend / 0 non-stationary / 0 directional,
#            - the F5-sample "thinly sampled / provisional" caveat is DROPPED,
#            - panels re-tint automatically to no-trend (grey) from the census data.
#
#          Distinct file from the plot-support F6_strata_trends (which stays 8/1/0
#          on disk) — this is the census version the deck should show.
#
# Workflow stage: 03_inundation_products · Tier 2 Task H, Gate E, G5 (S21 headline)
# Run mode: figure render (re-runs the committed trend test on the census series
#           to regenerate the exact LOESS/OLS fits; script 12 did not persist them) · read-only
# Key inputs:
#   - Output/diagnostics/tier2H_h31_census_stratum_annual_series.csv   (census 9-stratum annual series)
#   - Output/diagnostics/tier2H_h32_census_f6_verdicts.csv             (census verdicts — the 9/0/0 cross-check)
# Key outputs (additive; Output/ gitignored; NOT registered — that is G7):
#   - Output/figures/S21_flood_trend_census_data.{png,pdf}
#
# DISCIPLINE:
#   - HYDROLOGY ONLY (no veg). Headline metric = between-year annual flood frequency.
#   - Verdict test is the committed gayini_run_trend_tests (Theil–Sen + Mann–Kendall,
#     LOESS shape, drop-two-floods) — reused verbatim so the census figure is the SAME test.
#   - Assert the tally reproduces the ratified 9/0/0 (verify against the h32 data, not prose).
#   - Support = PIXEL (census). Supersedes the F5-sample 8/1/0: Riverine low's non-stationary flag
#     was a 40-point sparsity artefact (p<0.05 in 541/1000 random 40-pt draws). Aeolian low is
#     vacuous no-trend (flat-zero, never floods) — reported, not counted as evidence.
# ------------------------------------------------------------------------------

## 1. Sources ----

root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", getwd()), winslash = "/", mustWork = TRUE)

source(file.path(root_dir, "R", "gayini_helpers.R"))
source(file.path(root_dir, "R", "gayini_output_helpers.R"))
source(file.path(root_dir, "R", "gayini_gradient_helpers.R"))
source(file.path(root_dir, "R", "gayini_stratified_sampling_functions.R"))
source(file.path(root_dir, "R", "gayini_trend_test_functions.R"))   # THE trend test (reused verbatim)
source(file.path(root_dir, "R", "gayini_trend_test_figures.R"))     # fit palette/labels
source(file.path(root_dir, "R", "gayini_descriptive_figures.R"))    # gayini_save_figure

suppressPackageStartupMessages({ library(dplyr); library(ggplot2) })

diagnostics_dir <- file.path(root_dir, "Output", "diagnostics")
figures_dir     <- file.path(root_dir, "Output", "figures")
series_csv  <- file.path(diagnostics_dir, "tier2H_h31_census_stratum_annual_series.csv")
verdict_csv <- file.path(diagnostics_dir, "tier2H_h32_census_f6_verdicts.csv")
for (p in c(series_csv, verdict_csv)) gayini_stop_if_missing(p, label = basename(p))

focus_communities <- gayini_focus_levels()
band_levels       <- gayini_regime_band_levels()


## 2. Load the census series, re-run the committed trend test ----

series_long <- readr::read_csv(series_csv, show_col_types = FALSE) |>
  dplyr::mutate(community   = factor(community, levels = focus_communities),
                regime_band = factor(regime_band, levels = band_levels))
stopifnot(nrow(series_long) == 9L * 35L)

stratum_meta <- series_long |>
  dplyr::distinct(stratum, community, regime_band) |>
  dplyr::arrange(community, regime_band)

thresholds <- gayini_trend_thresholds()
trend <- gayini_run_trend_tests(series_long, stratum_meta, thresholds = thresholds)
vt <- trend$verdict_tbl

## Cross-check: the re-run must reproduce the ratified 9/0/0, AND match the committed h32 verdicts.
tally <- table(factor(as.character(vt$verdict), levels = gayini_trend_verdict_levels()))
committed <- readr::read_csv(verdict_csv, show_col_types = FALSE) |>
  dplyr::select(stratum, verdict_committed = verdict)
chk <- vt |> dplyr::select(stratum, verdict) |>
  dplyr::left_join(committed, by = "stratum") |>
  dplyr::mutate(match = as.character(verdict) == as.character(verdict_committed))
message("Census F6 tally (re-run): ", paste(names(tally), unname(tally), sep = "=", collapse = " · "))
stopifnot(as.integer(tally["no_trend"]) == 9L,
          as.integer(tally["non_stationary"]) == 0L,
          as.integer(tally["directional_trend"]) == 0L,
          all(chk$match))
message("  ✓ reproduces the ratified 9 no-trend / 0 / 0 and matches committed h32 verdicts exactly.")


## 3. Assemble the plotting frames (same grammar as gayini_build_f6_strata_trends) ----

fit_pal     <- gayini_trend_fit_palette()
fit_lab     <- gayini_trend_fit_labels()
verdict_pal <- gayini_trend_verdict_palette()
short       <- gayini_gradient_short_labels()

fac_comm <- function(x) factor(unname(short[as.character(x)]), levels = unname(short[focus_communities]))
fac_band <- function(x) factor(as.character(x), levels = band_levels,
                               labels = c("low band", "mid band", "high band"))

ser <- series_long |>
  dplyr::filter(!is.na(.data$freq_pct)) |>
  dplyr::mutate(comm = fac_comm(.data$community), band = fac_band(.data$regime_band))

loess_df <- dplyr::bind_rows(lapply(names(trend$fits), function(k) {
  f <- trend$fits[[k]]; m <- vt[vt$stratum == k, ]
  tibble::tibble(community = m$community, regime_band = m$regime_band,
                 year = f$fit$loess$pred_x, freq_pct = f$fit$loess$pred_y)
})) |> dplyr::mutate(comm = fac_comm(.data$community), band = fac_band(.data$regime_band))

ols_df <- dplyr::bind_rows(lapply(names(trend$fits), function(k) {
  f <- trend$fits[[k]]; m <- vt[vt$stratum == k, ]; xr <- range(f$series$year)
  tibble::tibble(community = m$community, regime_band = m$regime_band,
                 year = xr, freq_pct = f$fit$ols$intercept + f$fit$ols$slope * xr)
})) |> dplyr::mutate(comm = fac_comm(.data$community), band = fac_band(.data$regime_band))

drop_df <- dplyr::bind_rows(lapply(names(trend$fits), function(k) {
  f <- trend$fits[[k]]; m <- vt[vt$stratum == k, ]
  d <- f$series[f$series$year %in% f$dropped_years, c("year", "freq_pct")]
  dplyr::mutate(d, community = m$community, regime_band = m$regime_band)
})) |> dplyr::mutate(comm = fac_comm(.data$community), band = fac_band(.data$regime_band))

## Verdict tint + τ/p tag per panel (all no-trend at census).
tag_df <- vt |>
  dplyr::mutate(comm = fac_comm(.data$community), band = fac_band(.data$regime_band),
                tag = sprintf("%s\nτ=%.2f  p=%.2f",
                              gayini_trend_verdict_labels()[as.character(.data$verdict)],
                              .data$mk_tau, .data$mk_p))


## 4. Build S21 — census framing (headline 9/0/0; provisional caveat dropped) ----

p <- ggplot2::ggplot(ser, ggplot2::aes(.data$year, .data$freq_pct)) +
  ggplot2::geom_rect(data = tag_df, inherit.aes = FALSE, ggplot2::aes(fill = .data$verdict),
                     xmin = -Inf, xmax = Inf, ymin = -Inf, ymax = Inf, alpha = 0.13) +
  ggplot2::geom_point(data = drop_df, ggplot2::aes(colour = "flood"),
                      size = 3.1, shape = 21, stroke = 0.9, fill = NA) +
  ggplot2::geom_line(ggplot2::aes(colour = "series"), linewidth = 0.3, alpha = 0.55) +
  ggplot2::geom_point(ggplot2::aes(colour = "series"), size = 0.9) +
  ggplot2::geom_line(data = loess_df, ggplot2::aes(colour = "loess"), linewidth = 1.0) +
  ggplot2::geom_line(data = ols_df, ggplot2::aes(colour = "ols"), linetype = "dashed", linewidth = 0.6) +
  ggplot2::geom_text(data = tag_df, inherit.aes = FALSE, ggplot2::aes(x = -Inf, y = Inf, label = .data$tag),
                     hjust = -0.05, vjust = 1.1, size = 2.5, colour = "grey15", fontface = "bold",
                     lineheight = 0.95) +
  ggplot2::facet_grid(rows = ggplot2::vars(.data$comm), cols = ggplot2::vars(.data$band)) +
  ggplot2::scale_fill_manual(values = verdict_pal, breaks = gayini_trend_verdict_levels(),
                             labels = gayini_trend_verdict_labels(), name = "Verdict (panel tint)") +
  ggplot2::scale_colour_manual(
    values = c(series = fit_pal[["series"]], loess = fit_pal[["loess"]],
               ols = fit_pal[["ols"]], flood = "#7F0000"),
    breaks = c("series", "loess", "ols", "flood"),
    labels = c(fit_lab[["series"]], fit_lab[["loess"]], fit_lab[["ols"]],
               "Two biggest flood years (dropped in check)"), name = NULL) +
  ggplot2::scale_y_continuous(limits = c(0, 100)) +
  ggplot2::labs(
    title = "S21 · Is flood frequency trending?  All-pixel census — 9 no-trend / 0 non-stationary / 0 directional",
    subtitle = paste0("Every census pixel (1988–2023), not the 40-plot sample. No directional trend in any stratum — ",
                      "flooding is FLOOD-PULSE DRIVEN, not trending.\nRows: community (dry→wet); columns: ",
                      "within-community regime band; panel tint = verdict. Theil–Sen/Mann–Kendall primary; OLS & LOESS for contrast."),
    x = "Water year", y = "Annual flood frequency (%)") +
  ggplot2::guides(
    fill   = ggplot2::guide_legend(order = 1, override.aes = list(alpha = 0.4)),
    colour = ggplot2::guide_legend(order = 2, override.aes = list(
      linetype = c("solid", "solid", "dashed", "blank"),
      shape = c(16, NA, NA, 21), linewidth = c(0.5, 1.0, 0.6, NA)))) +
  ggplot2::labs(caption = paste0(
    "Support = PIXEL (census). Supersedes the F5-sample 8/1/0: Riverine low's non-stationary flag was a 40-point sparsity artefact ",
    "(p<0.05 in 541/1000 random 40-pt draws vs a nominal 5%).\nAeolian low is a vacuous no-trend (flat-zero — never floods in 35 yr): ",
    "reported, not counted as evidence. The census adds no temporal power but removes within-year measurement error, which is why the one ",
    "sample-era flag falls away.")) +
  ggplot2::theme_minimal(base_size = 11) +
  ggplot2::theme(
    plot.title = ggplot2::element_text(face = "bold", size = 12.5),
    plot.subtitle = ggplot2::element_text(size = 8.4, colour = "grey35"),
    plot.caption = ggplot2::element_text(size = 7.4, colour = "grey35", hjust = 0, margin = ggplot2::margin(t = 8)),
    plot.caption.position = "plot", plot.title.position = "plot",
    strip.text = ggplot2::element_text(face = "bold", size = 9),
    panel.grid.minor = ggplot2::element_blank(),
    legend.position = "bottom", legend.box = "vertical")


## 5. Save ----

paths <- gayini_save_figure(p, figures_dir, "S21_flood_trend_census", kind = "data",
                            width = 12, height = 10)

message("\n==================== S21 COMPLETE — STOP FOR REVIEW ====================")
message("Flood-trend census figure: ", paths$png)
message("Headline: 9 no-trend / 0 non-stationary / 0 directional (all census pixels). Provisional caveat dropped.")
message("Distinct from the plot-support F6_strata_trends (8/1/0, unchanged on disk).")
message("NOT registered (G7). STOP: review S21, then the veg-vs-water scatter, then S12, then G6/G7.")
