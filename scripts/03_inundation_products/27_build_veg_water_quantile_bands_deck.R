# ------------------------------------------------------------------------------
# Script: scripts/03_inundation_products/27_build_veg_water_quantile_bands_deck.R
# Purpose: Tier 2 · Task H · Gate E (G5) — the veg-vs-water all-pixel scatter, DECK
#          / site-report form, QUANTILE-BAND variant (POC3 / Fig B). Per flood-freq
#          bin, the conditional distribution of veg: p50 line (community hue) with
#          p10/p25/p50/p75/p90 grey bands, PER COMMUNITY. Both y-metrics: veg_p05
#          (floor) AND veg_p50 (typical cover).
#
#          COMPLEMENT to the GAM-cloud form (script 26), not a replacement: the GAM
#          cloud shows WHERE the pixels sit (intuitive headline); the quantile bands
#          show the conditional SPREAD explicitly (precise, methods-facing). Same
#          community palette, same 3-facet form, so they read as one family.
#
#          SPARSE-TAIL DISCIPLINE (Hugh): the POC3 had a thin-bin spike near
#          flood-freq 47 where the lower band dropped — an artefact of a sparse
#          discrete bin, NOT a real dip. Fixed here with 5-pp bins AND a per-bin
#          minimum pixel count: bands are truncated to the contiguous well-supported
#          range per community (same cutoff logic as the GAM form).
#
# Workflow stage: 03_inundation_products · Tier 2 Task H, Gate E, G5 (deck scatter, quantile bands)
# Run mode: figure render (raster-derived per-bin quantiles) · read-only
# Key inputs: as script 26 (annual stack, veg_p05/p50 rasters, veg_regime_class).
# Key outputs (additive; Output/ gitignored; NOT registered — that is G7):
#   - Output/figures/S_veg_water_qband_{p05,p50}_data.{png,pdf}
# ------------------------------------------------------------------------------

## 0. Constants ----

FOCUS_CODES <- c(11L, 12L, 13L, 21L, 22L, 23L, 31L, 32L, 33L)
BIN_W       <- 10L       # flood-freq bin width (pp). 10 (not 5) so per-bin deciles are stable and a
                         # noisy lower-tail bin can't render as a spurious V (the POC3 ~47% dip). Still
                         # ≥3 bins for Aeolian (cutoff ~35%) and ~9 for Inland (~95%).
MIN_BIN_N   <- 500L      # a community × bin below this px count is dropped (sparse-tail truncation)

METRICS <- list(
  list(id = "p05", tif = "total_veg_p05_8058.tif",
       ylab = "Vegetation floor  ·  veg_p05 (5th-percentile cover, %)", word = "floor"),
  list(id = "p50", tif = "total_veg_p50_8058.tif",
       ylab = "Typical cover  ·  veg_p50 (median cover, %)", word = "typical (median) cover"))


## 1. Sources ----

root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", getwd()), winslash = "/", mustWork = TRUE)
source(file.path(root_dir, "R", "gayini_helpers.R"))
source(file.path(root_dir, "R", "gayini_output_helpers.R"))
source(file.path(root_dir, "R", "gayini_gradient_helpers.R"))
source(file.path(root_dir, "R", "gayini_veg_regime_functions.R"))
source(file.path(root_dir, "R", "gayini_descriptive_figures.R"))

suppressPackageStartupMessages({ library(terra); library(dplyr); library(ggplot2) })
terra::terraOptions(progress = 0)

rasters_dir <- file.path(root_dir, "Output", "rasters")
figures_dir <- file.path(root_dir, "Output", "figures")
vp_dir    <- file.path(rasters_dir, "veg_percentiles_8058")
stack_dir <- file.path(rasters_dir, "inundation_annual_stack_8058")
wet_tif   <- file.path(stack_dir, "annual_wet_any_1988_2023_8058.tif")
val_tif   <- file.path(stack_dir, "annual_valid_any_1988_2023_8058.tif")
class_tif <- file.path(rasters_dir, "veg_regime_class_8058.tif")

focus    <- gayini_focus_levels()
short    <- gayini_gradient_short_labels()
comm_hue <- gayini_veg_regime_classes() |> dplyr::filter(.data$band == "mid") |>
  (\(x) stats::setNames(x$colour, x$community))()
code_comm <- gayini_veg_regime_classes() |> dplyr::filter(.data$band != "context") |>
  dplyr::transmute(code, community)


## 2. Derive flood_freq + both metrics (once) ----

message("\n================ veg-water quantile bands · derive ================")
wet <- terra::rast(wet_tif); val <- terra::rast(val_tif); class_r <- terra::rast(class_tif)
levels(class_r) <- NULL; terra::coltab(class_r) <- NULL
p05 <- terra::rast(file.path(vp_dir, "total_veg_p05_8058.tif"))
p50 <- terra::rast(file.path(vp_dir, "total_veg_p50_8058.tif"))
freq <- 100 * terra::app(wet, "sum", na.rm = TRUE) / terra::app(val, "sum", na.rm = TRUE)
fr <- terra::values(c(class_r, freq, p05, p50))
colnames(fr) <- c("code", "flood_freq_pct", "p05", "p50")
fr <- as.data.frame(fr) |>
  dplyr::filter(.data$code %in% FOCUS_CODES, !is.na(.data$flood_freq_pct)) |>
  dplyr::left_join(code_comm, by = "code") |>
  dplyr::mutate(community = factor(community, levels = focus),
                bin = floor(pmin(.data$flood_freq_pct, 99.999) / BIN_W) * BIN_W + BIN_W / 2)  # bin midpoint
message(sprintf("  focus pixels: %s", format(nrow(fr), big.mark = ",")))


## 3. Render one quantile-band figure for a given metric ----

render_qband <- function(m) {
  d0 <- fr[!is.na(fr[[m$id]]), c("community", "bin", m$id)]
  names(d0)[3] <- "y"

  q <- d0 |>
    dplyr::group_by(community, bin) |>
    dplyr::summarise(n = dplyr::n(),
                     p10 = stats::quantile(y, 0.10, names = FALSE), p25 = stats::quantile(y, 0.25, names = FALSE),
                     p50 = stats::quantile(y, 0.50, names = FALSE), p75 = stats::quantile(y, 0.75, names = FALSE),
                     p90 = stats::quantile(y, 0.90, names = FALSE), .groups = "drop")

  ## Sparse-tail truncation: keep the CONTIGUOUS well-supported bins from the low end
  ## (so a single sparse bin can't create a spike, and gaps can't make the ribbon jump).
  q <- q |> dplyr::arrange(community, bin) |>
    dplyr::group_by(community) |>
    dplyr::mutate(ok = n >= MIN_BIN_N, keep = cumprod(as.integer(ok)) == 1L) |>
    dplyr::ungroup() |> dplyr::filter(keep) |>
    dplyr::mutate(comm_lab = factor(unname(short[as.character(community)]), levels = unname(short[focus])))

  cut_lab <- q |> dplyr::group_by(community, comm_lab) |>
    dplyr::summarise(cut_ff = max(bin) + BIN_W / 2, .groups = "drop")
  y_top <- min(100, ceiling(max(q$p90) / 10) * 10)

  p <- ggplot2::ggplot(q, ggplot2::aes(x = bin)) +
    ## grey bands: outer p10–p90 (light), inner p25–p75 (dark).
    ggplot2::geom_ribbon(ggplot2::aes(ymin = p10, ymax = p90), fill = "grey82") +
    ggplot2::geom_ribbon(ggplot2::aes(ymin = p25, ymax = p75), fill = "grey60") +
    ## p50 line = community hue (white halo for lift off the grey bands).
    ggplot2::geom_line(ggplot2::aes(y = p50, group = community), colour = "white", linewidth = 2.1) +
    ggplot2::geom_line(ggplot2::aes(y = p50, colour = community), linewidth = 1.2) +
    ggplot2::geom_vline(data = cut_lab, ggplot2::aes(xintercept = cut_ff),
                        colour = "grey45", linetype = "22", linewidth = 0.45) +
    ggplot2::facet_wrap(~ comm_lab, nrow = 1) +
    ggplot2::scale_colour_manual(values = comm_hue, guide = "none") +
    ggplot2::scale_x_continuous(name = "How often it floods  ·  between-year flood frequency (%)",
                                breaks = seq(0, 100, 25), limits = c(0, 100), expand = ggplot2::expansion(mult = c(0.01, 0.01))) +
    ggplot2::scale_y_continuous(name = m$ylab, limits = c(0, y_top), expand = ggplot2::expansion(mult = c(0, 0.02))) +
    ggplot2::labs(
      title = sprintf("Vegetation %s vs flooding — conditional distribution, by community  [quantile bands · %s]",
                      m$word, m$id),
      subtitle = paste0("The all-pixel conditional distribution of veg_", m$id, " across the flood gradient (deck / methods form). ",
                        format(nrow(d0), big.mark = ","), " census pixels, ", BIN_W, "-pp bins.\n",
                        "Coloured line = median (p50, community hue); grey bands = p25–p75 (dark) and p10–p90 (light). ",
                        "Dashed = sparse-tail boundary (bins < ", format(MIN_BIN_N, big.mark = ","), " px dropped)."),
      caption = paste0(
        "Pixel support (census, 24.97 m); grid ≠ farm — only mapped focus strata shown. y = veg_", m$id, " (", m$word, ").\n",
        "Complement to the GAM-cloud form (same substrate): bands show the conditional SPREAD explicitly. Community palette + Fig B discipline (grey = spread, community hue = median).\n",
        "Bins are truncated to the contiguously well-supported range per community, so a thin discrete bin cannot read as a real dip. ~1M pixels are NOT independent n; Landsat FC measures cover, not condition.")) +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(face = "bold", size = 12.5),
      plot.subtitle = ggplot2::element_text(size = 9, colour = "grey30", margin = ggplot2::margin(b = 8)),
      plot.caption = ggplot2::element_text(size = 7.6, colour = "grey35", hjust = 0, margin = ggplot2::margin(t = 10)),
      plot.caption.position = "plot", plot.title.position = "plot",
      strip.text = ggplot2::element_text(face = "bold", size = 10.5),
      panel.grid.minor = ggplot2::element_blank(), panel.grid.major = ggplot2::element_line(colour = "grey92"),
      panel.spacing = ggplot2::unit(1.0, "lines"), axis.title = ggplot2::element_text(size = 9.5))

  paths <- gayini_save_figure(p, figures_dir, sprintf("S_veg_water_qband_%s", m$id), kind = "data",
                              width = 11.0, height = 5.2, dpi = 300)
  message(sprintf("  [%s] per-community cutoffs: %s", m$id,
                  paste(sprintf("%s=%g%%", cut_lab$community, cut_lab$cut_ff), collapse = " · ")))
  paths
}

for (m in METRICS) render_qband(m)

message("\n==================== veg-water QUANTILE BANDS (p05 + p50) COMPLETE — STOP FOR REVIEW ====================")
message("Community-hue p50 line + grey p10–p90 / p25–p75 bands · sparse bins dropped. NOT registered (G7).")
