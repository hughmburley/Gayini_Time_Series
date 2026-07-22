# ------------------------------------------------------------------------------
# Script: scripts/03_inundation_products/24_build_figA_floor_gradient_density.R
# Purpose: Tier 2 · Task H · Gate E (G5) — Fig A: the TECHNICAL COMPANION to the
#          response census. The whole per-pixel cloud a journal reviewer expects:
#          the veg FLOOR (veg_p05, across-series 5th percentile of total veg) vs
#          BETWEEN-YEAR flood frequency — the §9 ~40.68 pp cross-sectional gradient
#          — as a 2-D density (viridis) with a GAM central line ±95% CI over it.
#
#          This is a CROSS-SECTIONAL SPATIAL GRADIENT (floor vs how often a pixel
#          floods), a DIFFERENT question from the temporal same-year response
#          (S24/S26). Both are worth keeping; this is the appendix/methods figure,
#          NOT a deck slide, and NOT community-coloured (viridis = data/QA register).
#
# Workflow stage: 03_inundation_products · Tier 2 Task H, Gate E, G5 (Fig A companion)
# Run mode: figure render (raster-derived cloud + GAM on a sample) · additive · read-only
# Key inputs:
#   - Output/rasters/inundation_annual_stack_8058/annual_{wet,valid}_any_1988_2023_8058.tif
#   - Output/rasters/veg_percentiles_8058/total_veg_p05_8058.tif
#   - Output/rasters/veg_regime_class_8058.tif   (focus footprint; grid≠farm trap avoided)
# Key outputs (additive; Output/ gitignored; NOT registered — that is G7):
#   - Output/figures/FigA_floor_gradient_density_data.{png,pdf}
#
# NOTES / DISCIPLINE:
#   - flood_freq is recomputed from the NN 8058 annual stack (100*Σwet/Σvalid) — IDENTICAL
#     to how the census parquet's flood_freq_pct was built (arrow unavailable to read the
#     parquet directly; the rasters are its source, so this is the same number).
#   - GRID ≠ FARM: extract ONLY where veg_regime_class is a focus code, so the cloud is the
#     census farm strata, not the 66%-non-Gayini FC extent (facts §9/§11).
#   - THE SPARSE-TAIL FIX (§F): the GAM wiggle at high flood-freq is fitting noise in a thin
#     tail. The GAM is fit on a SAMPLE (not the raw ~1M) and its line+CI are TRUNCATED to the
#     flood-freq range with adequate support (>= MIN_BIN_N px per 5-pp bin); the sparse tail is
#     labelled, not fit — so tail noise cannot read as a finding. The density layer still shows
#     the whole cloud (honest), including the sparse tail.
#   - Viridis (colour-blind safe), log-count fill so sparse cells stay visible. Appendix/methods.
# ------------------------------------------------------------------------------

## 0. Constants ----

FOCUS_CODES <- c(11L, 12L, 13L, 21L, 22L, 23L, 31L, 32L, 33L)
MIN_BIN_N   <- 2000L     # a 5-pp flood-freq bin below this px count is "sparse tail" (GAM truncated)
GAM_SAMPLE  <- 80000L    # fit the GAM on a sample, not the raw ~1M (§F)
SEED        <- 20260721L


## 1. Sources ----

root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", getwd()), winslash = "/", mustWork = TRUE)

source(file.path(root_dir, "R", "gayini_helpers.R"))
source(file.path(root_dir, "R", "gayini_output_helpers.R"))
source(file.path(root_dir, "R", "gayini_descriptive_figures.R"))

suppressPackageStartupMessages({ library(terra); library(dplyr); library(ggplot2); library(mgcv) })
terra::terraOptions(progress = 0)

rasters_dir <- file.path(root_dir, "Output", "rasters")
figures_dir <- file.path(root_dir, "Output", "figures")
stack_dir <- file.path(rasters_dir, "inundation_annual_stack_8058")
wet_tif   <- file.path(stack_dir, "annual_wet_any_1988_2023_8058.tif")
val_tif   <- file.path(stack_dir, "annual_valid_any_1988_2023_8058.tif")
p05_tif   <- file.path(rasters_dir, "veg_percentiles_8058", "total_veg_p05_8058.tif")
class_tif <- file.path(rasters_dir, "veg_regime_class_8058.tif")
for (p in c(wet_tif, val_tif, p05_tif, class_tif)) gayini_stop_if_missing(p, label = basename(p))


## 2. Load, assert grid, derive flood_freq, extract focus pixels ----

message("\n================ Fig A · load + derive ================")
wet <- terra::rast(wet_tif); val <- terra::rast(val_tif)
p05 <- terra::rast(p05_tif); class_r <- terra::rast(class_tif)
levels(class_r) <- NULL; terra::coltab(class_r) <- NULL
for (nm in c("wet","val","p05")) {
  ok <- terra::compareGeom(get(nm), class_r, lyrs = FALSE, crs = TRUE, ext = TRUE,
                           rowcol = TRUE, res = TRUE, stopOnError = FALSE)
  stopifnot(isTRUE(ok))
}
message("  compareGeom(all inputs, veg_regime_class_8058) = TRUE.")

## flood_freq = 100 * Σwet / Σvalid (NN stack) — identical to census parquet construction.
freq <- 100 * terra::app(wet, "sum", na.rm = TRUE) / terra::app(val, "sum", na.rm = TRUE)
names(freq) <- "flood_freq_pct"

fr <- terra::values(c(class_r, freq, p05))
colnames(fr) <- c("code", "flood_freq_pct", "veg_p05")
fr <- as.data.frame(fr) |>
  dplyr::filter(.data$code %in% FOCUS_CODES, !is.na(.data$flood_freq_pct), !is.na(.data$veg_p05))
message(sprintf("  focus pixels with valid (flood_freq, veg_p05): %s", format(nrow(fr), big.mark = ",")))
message(sprintf("  flood_freq range [%.2f, %.2f] · veg_p05 range [%.2f, %.2f]",
                min(fr$flood_freq_pct), max(fr$flood_freq_pct), min(fr$veg_p05), max(fr$veg_p05)))


## 3. Sparse-tail cutoff: last 5-pp flood-freq bin with adequate support ----

bin5 <- cut(fr$flood_freq_pct, breaks = seq(0, 100, 5), include.lowest = TRUE)
cnt  <- as.data.frame(table(bin5), stringsAsFactors = FALSE)
cnt$upper <- seq(5, 100, 5)
supported <- cnt$upper[cnt$Freq >= MIN_BIN_N]
ff_cut <- if (length(supported)) max(supported) else 100
message(sprintf("  sparse-tail cutoff: GAM fit shown to flood_freq = %d%% (last 5-pp bin with >= %s px)",
                ff_cut, format(MIN_BIN_N, big.mark = ",")))


## 4. GAM on a sample, predicted over the supported range only ----

set.seed(SEED)
samp <- fr[sample.int(nrow(fr), min(GAM_SAMPLE, nrow(fr))), ]
gam_fit <- mgcv::gam(veg_p05 ~ s(flood_freq_pct, k = 12), data = samp, method = "REML")
grid <- data.frame(flood_freq_pct = seq(0, ff_cut, length.out = 240))
pr <- predict(gam_fit, newdata = grid, se.fit = TRUE)
gam_df <- data.frame(flood_freq_pct = grid$flood_freq_pct,
                     fit = pr$fit, lo = pr$fit - 1.96 * pr$se.fit, hi = pr$fit + 1.96 * pr$se.fit)


## 5. Build the figure — viridis density + GAM ±95% CI ----

y_top <- min(110, ceiling(stats::quantile(fr$veg_p05, 0.999) / 10) * 10 + 5)

p <- ggplot2::ggplot(fr, ggplot2::aes(x = flood_freq_pct, y = veg_p05)) +
  ggplot2::geom_bin2d(bins = c(72, 60)) +
  ggplot2::scale_fill_viridis_c(trans = "log10", option = "viridis", name = "pixels",
                                labels = scales::label_number(big.mark = ",")) +
  ## sparse-tail boundary — GAM not fit beyond here.
  ggplot2::geom_vline(xintercept = ff_cut, colour = "grey30", linetype = "22", linewidth = 0.5) +
  ## GAM central line (white halo for contrast on viridis) + ±95% CI as red dashed lines (visible).
  ggplot2::geom_line(data = gam_df, inherit.aes = FALSE,
                     ggplot2::aes(x = flood_freq_pct, y = lo), colour = "#D62728", linewidth = 0.55, linetype = "22") +
  ggplot2::geom_line(data = gam_df, inherit.aes = FALSE,
                     ggplot2::aes(x = flood_freq_pct, y = hi), colour = "#D62728", linewidth = 0.55, linetype = "22") +
  ggplot2::geom_line(data = gam_df, inherit.aes = FALSE,
                     ggplot2::aes(x = flood_freq_pct, y = fit), colour = "white", linewidth = 1.8) +
  ggplot2::geom_line(data = gam_df, inherit.aes = FALSE,
                     ggplot2::aes(x = flood_freq_pct, y = fit), colour = "#D62728", linewidth = 1.0) +
  ggplot2::annotate("text", x = ff_cut - 1.5, y = y_top * 0.05, hjust = 1, size = 2.8, colour = "grey20",
                    label = "sparse tail →\nGAM not fit") +
  ggplot2::scale_x_continuous(name = "Between-year flood frequency  (%)  ·  100 × wet-valid-years ÷ valid-years",
                              breaks = seq(0, 100, 20), limits = c(0, 100),
                              expand = ggplot2::expansion(mult = c(0, 0.01))) +
  ggplot2::scale_y_continuous(name = "Vegetation floor  ·  veg_p05  (5th-percentile total cover, %)",
                              limits = c(0, y_top), expand = ggplot2::expansion(mult = c(0, 0.02))) +
  ggplot2::labs(
    title = "Fig A · Vegetation floor vs flood frequency — the all-pixel gradient (companion / appendix)",
    subtitle = paste0("Cross-sectional SPATIAL gradient (a different question from the same-year response S24/S26): ",
                      "how the veg floor rises with how often a pixel floods.\n",
                      "2-D density of ", format(nrow(fr), big.mark = ","), " census focus pixels (viridis, log count); ",
                      "GAM central line ±95% CI (red) over the well-supported range."),
    caption = paste0(
      "Technical companion, NOT a deck figure — viridis (colour-blind safe) deliberately avoids the community palette so it reads as data/QA. Floor = veg_p05, the across-series 5th percentile of total cover.\n",
      "GAM (red) fit on an ", format(GAM_SAMPLE, big.mark = ","), "-pixel sample, ±95% CI (red dashed), TRUNCATED past the vertical dashed line where < ", format(MIN_BIN_N, big.mark = ","), " px / 5-pp bin — the sparse tail is not fit.\n",
      "Pixel support (census, 24.97 m); grid ≠ farm — only mapped focus strata shown. ~1M pixels are NOT independent n; Landsat FC measures cover, not condition.")) +
  ggplot2::theme_minimal(base_size = 12) +
  ggplot2::theme(
    plot.title = ggplot2::element_text(face = "bold", size = 13),
    plot.subtitle = ggplot2::element_text(size = 9, colour = "grey30", margin = ggplot2::margin(b = 8)),
    plot.caption = ggplot2::element_text(size = 7.6, colour = "grey35", hjust = 0, margin = ggplot2::margin(t = 10)),
    plot.caption.position = "plot", plot.title.position = "plot",
    panel.grid.minor = ggplot2::element_blank(),
    panel.grid.major = ggplot2::element_line(colour = "grey92"),
    legend.position = "right",
    axis.title = ggplot2::element_text(size = 9.5))


## 6. Save ----

paths <- gayini_save_figure(p, figures_dir, "FigA_floor_gradient_density", kind = "data",
                            width = 9.6, height = 6.4, dpi = 300)

message("\n==================== Fig A COMPLETE — STOP FOR REVIEW ====================")
message("Companion figure: ", paths$png)
message(sprintf("Density of %s focus pixels; GAM fit to flood_freq=%d%% (sparse tail truncated).",
                format(nrow(fr), big.mark = ","), ff_cut))
message("Viridis (non-deck), appendix/methods. Cross-sectional gradient — distinct from S24/S26 temporal response.")
message("NOT registered (G7). STOP: review Fig A, then G6 (cleanups) + G7 (registration).")
