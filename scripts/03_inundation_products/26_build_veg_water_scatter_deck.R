# ------------------------------------------------------------------------------
# Script: scripts/03_inundation_products/26_build_veg_water_scatter_deck.R
# Purpose: Tier 2 · Task H · Gate E (G5) — the veg-vs-water all-pixel scatter, DECK
#          / site-report form, GAM-CLOUD variant. Per-pixel veg vs between-year
#          flood frequency — the ~1M-pixel "more water → more cover" cloud — as a
#          2-D density with a community-hue GAM central line, PER COMMUNITY.
#          Rendered for BOTH y-metrics: veg_p05 (floor) AND veg_p50 (typical cover).
#
#          DECK sibling of Fig A (same substrate) under Fig B colour discipline:
#          GREY sequential density = the mass; COMMUNITY-HUE GAM line ±95% CI =
#          identity. Deliberately NOT viridis — viridis is Fig A / appendix only
#          ("read as data"); the community palette is the deck signature ("Inland
#          blue matches the maps and every deck figure"). Density stays grey so the
#          hue line is the focus and two colour scales don't compete.
#
# Workflow stage: 03_inundation_products · Tier 2 Task H, Gate E, G5 (deck scatter, GAM)
# Run mode: figure render (raster-derived cloud + per-community GAM on a sample) · read-only
# Key inputs:
#   - Output/rasters/inundation_annual_stack_8058/annual_{wet,valid}_any_1988_2023_8058.tif
#   - Output/rasters/veg_percentiles_8058/total_veg_{p05,p50}_8058.tif
#   - Output/rasters/veg_regime_class_8058.tif
# Key outputs (additive; Output/ gitignored; NOT registered — that is G7):
#   - Output/figures/S_veg_water_gam_{p05,p50}_data.{png,pdf}
# ------------------------------------------------------------------------------

## 0. Constants ----

FOCUS_CODES <- c(11L, 12L, 13L, 21L, 22L, 23L, 31L, 32L, 33L)
MIN_BIN_N   <- 500L
GAM_SAMPLE  <- 40000L
SEED        <- 20260721L

METRICS <- list(
  list(id = "p05", tif = "total_veg_p05_8058.tif",
       ylab = "Vegetation floor  ·  veg_p05 (5th-percentile cover, %)",
       word = "floor (worst-season cover a pixel holds)"),
  list(id = "p50", tif = "total_veg_p50_8058.tif",
       ylab = "Typical cover  ·  veg_p50 (median cover, %)",
       word = "typical (median) cover"))


## 1. Sources ----

root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", getwd()), winslash = "/", mustWork = TRUE)
source(file.path(root_dir, "R", "gayini_helpers.R"))
source(file.path(root_dir, "R", "gayini_output_helpers.R"))
source(file.path(root_dir, "R", "gayini_gradient_helpers.R"))
source(file.path(root_dir, "R", "gayini_veg_regime_functions.R"))
source(file.path(root_dir, "R", "gayini_descriptive_figures.R"))

suppressPackageStartupMessages({ library(terra); library(dplyr); library(ggplot2); library(mgcv) })
terra::terraOptions(progress = 0)

rasters_dir <- file.path(root_dir, "Output", "rasters")
figures_dir <- file.path(root_dir, "Output", "figures")
vp_dir    <- file.path(rasters_dir, "veg_percentiles_8058")
stack_dir <- file.path(rasters_dir, "inundation_annual_stack_8058")
wet_tif   <- file.path(stack_dir, "annual_wet_any_1988_2023_8058.tif")
val_tif   <- file.path(stack_dir, "annual_valid_any_1988_2023_8058.tif")
class_tif <- file.path(rasters_dir, "veg_regime_class_8058.tif")
for (p in c(wet_tif, val_tif, class_tif, file.path(vp_dir, vapply(METRICS, `[[`, "", "tif"))))
  gayini_stop_if_missing(p, label = basename(p))

focus    <- gayini_focus_levels()
short    <- gayini_gradient_short_labels()
comm_hue <- gayini_veg_regime_classes() |> dplyr::filter(.data$band == "mid") |>
  (\(x) stats::setNames(x$colour, x$community))()
code_comm <- gayini_veg_regime_classes() |> dplyr::filter(.data$band != "context") |>
  dplyr::transmute(code, community)


## 2. Derive flood_freq + extract both veg metrics for focus pixels (once) ----

message("\n================ veg-water GAM · derive ================")
wet <- terra::rast(wet_tif); val <- terra::rast(val_tif); class_r <- terra::rast(class_tif)
levels(class_r) <- NULL; terra::coltab(class_r) <- NULL
p05 <- terra::rast(file.path(vp_dir, "total_veg_p05_8058.tif"))
p50 <- terra::rast(file.path(vp_dir, "total_veg_p50_8058.tif"))
for (nm in c("wet","val","p05","p50")) stopifnot(isTRUE(terra::compareGeom(
  get(nm), class_r, lyrs = FALSE, crs = TRUE, ext = TRUE, rowcol = TRUE, res = TRUE, stopOnError = FALSE)))

freq <- 100 * terra::app(wet, "sum", na.rm = TRUE) / terra::app(val, "sum", na.rm = TRUE)
fr <- terra::values(c(class_r, freq, p05, p50))
colnames(fr) <- c("code", "flood_freq_pct", "p05", "p50")
fr <- as.data.frame(fr) |>
  dplyr::filter(.data$code %in% FOCUS_CODES, !is.na(.data$flood_freq_pct)) |>
  dplyr::left_join(code_comm, by = "code") |>
  dplyr::mutate(community = factor(community, levels = focus),
                comm_lab  = factor(unname(short[as.character(community)]), levels = unname(short[focus])))
message(sprintf("  focus pixels: %s", format(nrow(fr), big.mark = ",")))


## 3. Render one GAM-cloud figure for a given metric ----

render_gam <- function(m) {
  d0 <- fr[, c("community", "comm_lab", "flood_freq_pct", m$id)]
  names(d0)[4] <- "y"; d0 <- d0[!is.na(d0$y), ]
  y_top <- min(100, ceiling(stats::quantile(d0$y, 0.999) / 10) * 10)

  set.seed(SEED)
  gam_df <- dplyr::bind_rows(lapply(focus, function(cm) {
    d <- d0[d0$community == cm, ]
    b <- cut(d$flood_freq_pct, breaks = seq(0, 100, 5), include.lowest = TRUE)
    ct <- as.data.frame(table(b)); ct$upper <- seq(5, 100, 5)
    cut_ff <- if (any(ct$Freq >= MIN_BIN_N)) max(ct$upper[ct$Freq >= MIN_BIN_N]) else max(d$flood_freq_pct)
    s <- d[sample.int(nrow(d), min(GAM_SAMPLE, nrow(d))), ]
    g <- mgcv::gam(y ~ s(flood_freq_pct, k = 10), data = s, method = "REML")
    grid <- data.frame(flood_freq_pct = seq(0, cut_ff, length.out = 200))
    pr <- predict(g, newdata = grid, se.fit = TRUE)
    tibble::tibble(community = cm, comm_lab = unname(short[cm]), flood_freq_pct = grid$flood_freq_pct,
                   cut_ff = cut_ff, fit = pr$fit, lo = pr$fit - 1.96 * pr$se.fit, hi = pr$fit + 1.96 * pr$se.fit)
  })) |> dplyr::mutate(comm_lab = factor(comm_lab, levels = unname(short[focus])),
                       community = factor(community, levels = focus))
  cut_lab <- gam_df |> dplyr::distinct(comm_lab, community, cut_ff)

  p <- ggplot2::ggplot(d0, ggplot2::aes(flood_freq_pct, y)) +
    ggplot2::geom_bin2d(bins = c(60, 50)) +
    ggplot2::scale_fill_gradient(low = "grey88", high = "grey30", trans = "log10",
                                 name = "pixels", labels = scales::label_number(big.mark = ",")) +
    ggplot2::geom_vline(data = cut_lab, ggplot2::aes(xintercept = cut_ff),
                        colour = "grey45", linetype = "22", linewidth = 0.45) +
    ggplot2::geom_ribbon(data = gam_df, inherit.aes = FALSE,
                         ggplot2::aes(flood_freq_pct, ymin = lo, ymax = hi, group = comm_lab),
                         fill = "white", alpha = 0.35) +
    ggplot2::geom_line(data = gam_df, inherit.aes = FALSE,
                       ggplot2::aes(flood_freq_pct, fit, group = comm_lab), colour = "white", linewidth = 2.2) +
    ggplot2::geom_line(data = gam_df, inherit.aes = FALSE,
                       ggplot2::aes(flood_freq_pct, fit, colour = community), linewidth = 1.2) +
    ggplot2::facet_wrap(~ comm_lab, nrow = 1) +
    ggplot2::scale_colour_manual(values = comm_hue, guide = "none") +
    ggplot2::scale_x_continuous(name = "How often it floods  ·  between-year flood frequency (%)",
                                breaks = seq(0, 100, 25), limits = c(0, 100), expand = ggplot2::expansion(mult = c(0, 0.01))) +
    ggplot2::scale_y_continuous(name = m$ylab, limits = c(0, y_top), expand = ggplot2::expansion(mult = c(0, 0.02))) +
    ggplot2::labs(
      title = sprintf("Vegetation %s vs flooding — every census pixel, by community  [GAM cloud · %s]",
                      m$word, m$id),
      subtitle = paste0("The all-pixel “more water → more cover” cloud (deck / site-report form). ",
                        format(nrow(d0), big.mark = ","), " census pixels.\n",
                        "Grey = where the pixels sit (density, log count); coloured line = how the ", m$id,
                        " rises with flooding (GAM conditional mean ±95% CI). Dashed = sparse-tail boundary; GAM not fit beyond."),
      caption = paste0(
        "Pixel support (census, 24.97 m); grid ≠ farm — only mapped focus strata shown. y = veg_", m$id, " (", m$word, ").\n",
        "Deck form — community palette + Fig B discipline (grey = the mass, community hue = the line). Companion Fig A is the same cloud in viridis for the appendix.\n",
        "~1M pixels collapse SAMPLING uncertainty only — NOT independent n (spatial autocorrelation); Landsat FC measures cover, not condition; a narrow band is not certainty.")) +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(face = "bold", size = 12.5),
      plot.subtitle = ggplot2::element_text(size = 9, colour = "grey30", margin = ggplot2::margin(b = 8)),
      plot.caption = ggplot2::element_text(size = 7.6, colour = "grey35", hjust = 0, margin = ggplot2::margin(t = 10)),
      plot.caption.position = "plot", plot.title.position = "plot",
      strip.text = ggplot2::element_text(face = "bold", size = 10.5),
      panel.grid.minor = ggplot2::element_blank(), panel.grid.major = ggplot2::element_line(colour = "grey92"),
      panel.spacing = ggplot2::unit(1.0, "lines"), legend.position = "right",
      axis.title = ggplot2::element_text(size = 9.5))

  paths <- gayini_save_figure(p, figures_dir, sprintf("S_veg_water_gam_%s", m$id), kind = "data",
                              width = 11.4, height = 5.2, dpi = 300)
  message(sprintf("  [%s] cutoffs: %s", m$id,
                  paste(sprintf("%s=%d%%", cut_lab$community, cut_lab$cut_ff), collapse = " · ")))
  paths
}

for (m in METRICS) render_gam(m)

message("\n==================== veg-water GAM (p05 + p50) COMPLETE — STOP FOR REVIEW ====================")
message("Grey density + community-hue GAM ±CI · sparse tail truncated per community. NOT registered (G7).")
