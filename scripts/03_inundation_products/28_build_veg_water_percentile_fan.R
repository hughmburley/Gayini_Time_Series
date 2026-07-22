# ------------------------------------------------------------------------------
# Script: scripts/03_inundation_products/28_build_veg_water_percentile_fan.R
# Purpose: Tier 2 · Task H · Gate E (G5) — the veg-vs-water PERCENTILE FAN. All five
#          stored per-pixel cover percentiles (veg_p05/p10/p20/p30/p50) as lines on
#          ONE panel per community, so the WHOLE conditional cover distribution's
#          shift with flooding reads at once — and the "signal is in the floor"
#          finding shows directly: the fan is TALL where flooding is rare (floors
#          sit far below medians) and COMPRESSES where flooding is frequent (floors
#          rise toward medians) — the drought-resilience mechanism in one figure.
#
#          Only the five stored percentiles are used (all the parquet has); p40/p60
#          etc. would need recomputation — deliberately NOT done.
#
# Workflow stage: 03_inundation_products · Tier 2 Task H, Gate E, G5 (percentile fan)
# Run mode: figure render (raster-derived per-bin conditional percentiles) · read-only
# Key inputs:
#   - Output/rasters/inundation_annual_stack_8058/annual_{wet,valid}_any_1988_2023_8058.tif
#   - Output/rasters/veg_percentiles_8058/total_veg_{p05,p10,p20,p30,p50}_8058.tif
#   - Output/rasters/veg_regime_class_8058.tif
# Key outputs (additive; Output/ gitignored; NOT registered — that is G7):
#   - Output/figures/S_veg_water_percentile_fan_data.{png,pdf}
#
# HONESTY (Hugh's caution — captioned):
#   - Each line = the ACROSS-PIXEL MEDIAN of that stored per-pixel percentile at each flood
#     frequency. These are POPULATION ORDER STATISTICS (median-of-floors vs median-of-medians),
#     so the vertical gap between lines is a POPULATION summary — "low-cover pixels sit this far
#     below the median here" — NOT any single pixel's variance.
#   - Percentiles are NOT subtracted (§11): each line is a measured percentile plotted directly.
#   - Community palette (graded light→dark for p05→p50, from the committed low/high band shades).
#     Sparse-tail truncation kept (10-pp bins, per-community).
# ------------------------------------------------------------------------------

## 0. Constants ----

FOCUS_CODES <- c(11L, 12L, 13L, 21L, 22L, 23L, 31L, 32L, 33L)
BIN_W       <- 10L
MIN_BIN_N   <- 500L
PCTS        <- c("p05", "p10", "p20", "p30", "p50")


## 1. Sources ----

root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", getwd()), winslash = "/", mustWork = TRUE)
source(file.path(root_dir, "R", "gayini_helpers.R"))
source(file.path(root_dir, "R", "gayini_output_helpers.R"))
source(file.path(root_dir, "R", "gayini_gradient_helpers.R"))
source(file.path(root_dir, "R", "gayini_veg_regime_functions.R"))
source(file.path(root_dir, "R", "gayini_descriptive_figures.R"))

suppressPackageStartupMessages({ library(terra); library(dplyr); library(tidyr); library(ggplot2) })
terra::terraOptions(progress = 0)

rasters_dir <- file.path(root_dir, "Output", "rasters")
figures_dir <- file.path(root_dir, "Output", "figures")
vp_dir    <- file.path(rasters_dir, "veg_percentiles_8058")
stack_dir <- file.path(rasters_dir, "inundation_annual_stack_8058")
wet_tif   <- file.path(stack_dir, "annual_wet_any_1988_2023_8058.tif")
val_tif   <- file.path(stack_dir, "annual_valid_any_1988_2023_8058.tif")
class_tif <- file.path(rasters_dir, "veg_regime_class_8058.tif")

focus     <- gayini_focus_levels()
short     <- gayini_gradient_short_labels()
cls       <- gayini_veg_regime_classes()
code_comm <- cls |> dplyr::filter(.data$band != "context") |> dplyr::transmute(code, community)

## Per-community 5-step ramp (low-band light -> high-band dark) mapped to p05..p50.
ramp_lut <- dplyr::bind_rows(lapply(focus, function(cm) {
  lo <- cls$colour[cls$community == cm & cls$band == "low"]
  hi <- cls$colour[cls$community == cm & cls$band == "high"]
  tibble::tibble(community = cm, percentile = PCTS,
                 hex = grDevices::colorRampPalette(c(lo, hi))(length(PCTS)))
}))


## 2. Derive flood_freq + extract all five percentiles for focus pixels ----

message("\n================ percentile fan · derive ================")
wet <- terra::rast(wet_tif); val <- terra::rast(val_tif); class_r <- terra::rast(class_tif)
levels(class_r) <- NULL; terra::coltab(class_r) <- NULL
pct_r <- terra::rast(file.path(vp_dir, paste0("total_veg_", PCTS, "_8058.tif")))
names(pct_r) <- PCTS
for (nm in c("wet","val")) stopifnot(isTRUE(terra::compareGeom(
  get(nm), class_r, lyrs = FALSE, crs = TRUE, ext = TRUE, rowcol = TRUE, res = TRUE, stopOnError = FALSE)))
stopifnot(isTRUE(terra::compareGeom(pct_r, class_r, lyrs = FALSE, crs = TRUE, ext = TRUE,
                                    rowcol = TRUE, res = TRUE, stopOnError = FALSE)))

freq <- 100 * terra::app(wet, "sum", na.rm = TRUE) / terra::app(val, "sum", na.rm = TRUE)
fr <- terra::values(c(class_r, freq, pct_r))
colnames(fr) <- c("code", "flood_freq_pct", PCTS)
fr <- as.data.frame(fr) |>
  dplyr::filter(.data$code %in% FOCUS_CODES, !is.na(.data$flood_freq_pct), !is.na(.data$p05)) |>
  dplyr::left_join(code_comm, by = "code") |>
  dplyr::mutate(community = factor(community, levels = focus),
                bin = floor(pmin(.data$flood_freq_pct, 99.999) / BIN_W) * BIN_W + BIN_W / 2)
message(sprintf("  focus pixels: %s", format(nrow(fr), big.mark = ",")))


## 3. Conditional MEDIAN of each stored percentile per flood-freq bin (population order stats) ----

fan <- fr |>
  dplyr::group_by(community, bin) |>
  dplyr::summarise(n = dplyr::n(),
                   dplyr::across(dplyr::all_of(PCTS), ~ stats::median(.x), .names = "{.col}"),
                   .groups = "drop") |>
  ## sparse-tail truncation: contiguous well-supported bins from the low end.
  dplyr::arrange(community, bin) |>
  dplyr::group_by(community) |>
  dplyr::mutate(keep = cumprod(as.integer(n >= MIN_BIN_N)) == 1L) |>
  dplyr::ungroup() |>
  dplyr::filter(keep) |>
  tidyr::pivot_longer(dplyr::all_of(PCTS), names_to = "percentile", values_to = "value") |>
  dplyr::left_join(ramp_lut, by = c("community", "percentile")) |>
  dplyr::mutate(comm_lab = factor(unname(short[as.character(community)]), levels = unname(short[focus])),
                percentile = factor(percentile, levels = PCTS))

## End-of-line labels in the widest facet (Inland) so the fan is self-legending.
end_lab <- fan |>
  dplyr::filter(community == focus[3]) |>
  dplyr::group_by(percentile) |>
  dplyr::slice_max(bin, n = 1, with_ties = FALSE) |>
  dplyr::ungroup()

cut_lab <- fan |> dplyr::group_by(community, comm_lab) |>
  dplyr::summarise(cut_ff = max(bin) + BIN_W / 2, .groups = "drop")
y_top <- min(100, ceiling(max(fan$value) / 10) * 10)


## 4. Build ----

p <- ggplot2::ggplot(fan, ggplot2::aes(x = bin, y = value, group = percentile, colour = hex)) +
  ggplot2::geom_line(linewidth = 1.15) +
  ggplot2::geom_point(size = 1.1) +
  ggplot2::geom_vline(data = cut_lab, inherit.aes = FALSE, ggplot2::aes(xintercept = cut_ff),
                      colour = "grey55", linetype = "22", linewidth = 0.4) +
  ggplot2::geom_text(data = end_lab, inherit.aes = FALSE,
                     ggplot2::aes(x = bin + 1.5, y = value, label = percentile, colour = hex),
                     hjust = 0, size = 2.9, fontface = "bold") +
  ggplot2::facet_wrap(~ comm_lab, nrow = 1) +
  ggplot2::scale_colour_identity() +
  ggplot2::scale_x_continuous(name = "How often it floods  ·  between-year flood frequency (%)",
                              breaks = seq(0, 100, 25), limits = c(0, 108),
                              expand = ggplot2::expansion(mult = c(0.01, 0))) +
  ggplot2::scale_y_continuous(name = "Total vegetation cover (%)  ·  stored percentiles p05 → p50",
                              limits = c(0, y_top), expand = ggplot2::expansion(mult = c(0, 0.02))) +
  ggplot2::labs(
    title = "The signal is in the floor — cover percentiles vs flooding, by community",
    subtitle = paste0("Each line = the across-pixel MEDIAN of a stored per-pixel percentile at each flood frequency ",
                      "(bottom→top: p05 floor → p50 median), ", BIN_W, "-pp bins.\n",
                      "The fan is TALL where flooding is rare and COMPRESSES where it is frequent: the low percentiles ",
                      "(floor) rise toward the median — the drought-resilience signal."),
    caption = paste0(
      "Pixel support (census, 24.97 m); grid ≠ farm — only mapped focus strata shown. Lines graded light→dark = p05→p50; dashed = sparse-tail boundary (bins < ",
      format(MIN_BIN_N, big.mark = ","), " px dropped).\n",
      "These are POPULATION order statistics (the median pixel's floor vs the median pixel's median): the gap between lines is “low-cover pixels sit this far below the median here”, NOT any single pixel's variance.\n",
      "Percentiles are plotted as measured — never differenced (§11). ~1M pixels are NOT independent n (spatial autocorrelation); Landsat FC measures cover, not ecological condition.")) +
  ggplot2::theme_minimal(base_size = 12) +
  ggplot2::theme(
    plot.title = ggplot2::element_text(face = "bold", size = 13),
    plot.subtitle = ggplot2::element_text(size = 9, colour = "grey30", margin = ggplot2::margin(b = 8)),
    plot.caption = ggplot2::element_text(size = 7.6, colour = "grey35", hjust = 0, margin = ggplot2::margin(t = 10)),
    plot.caption.position = "plot", plot.title.position = "plot",
    strip.text = ggplot2::element_text(face = "bold", size = 10.5),
    panel.grid.minor = ggplot2::element_blank(), panel.grid.major = ggplot2::element_line(colour = "grey92"),
    panel.spacing = ggplot2::unit(1.0, "lines"), axis.title = ggplot2::element_text(size = 9.5))


## 5. Save + report the mechanism numerically ----

paths <- gayini_save_figure(p, figures_dir, "S_veg_water_percentile_fan", kind = "data",
                            width = 11.4, height = 5.4, dpi = 300)

## The fan-compression check: (p50 line − p05 line) at the driest vs wettest supported bin.
span <- fan |>
  dplyr::select(community, bin, percentile, value) |>
  tidyr::pivot_wider(names_from = percentile, values_from = value) |>
  dplyr::group_by(community) |>
  dplyr::summarise(dry_bin = min(bin), wet_bin = max(bin),
                   fan_dry = round(p50[which.min(bin)] - p05[which.min(bin)], 1),
                   fan_wet = round(p50[which.max(bin)] - p05[which.max(bin)], 1),
                   .groups = "drop")
message("\n  Fan height (median p50-line − p05-line), driest vs wettest supported bin:")
print(as.data.frame(span), row.names = FALSE)
message("\n==================== percentile fan COMPLETE — STOP FOR REVIEW ====================")
message("Five stored percentiles as a fan, per community. Compression = the drought-resilience signal.")
message("NOT registered (G7). STOP: review, then S12, then G6/G7.")
