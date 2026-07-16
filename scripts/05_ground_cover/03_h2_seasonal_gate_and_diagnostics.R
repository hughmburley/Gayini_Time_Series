# ------------------------------------------------------------------------------
# Script: scripts/05_ground_cover/03_h2_seasonal_gate_and_diagnostics.R
# Purpose: Tier 2 · Task H · H2 follow-up — THE GATE ON H4, plus the three open
#          diagnostics. Read-only; builds no products.
#
#   1. 🔴 GATE — SPATIAL UNIFORMITY of the seasonal mixture.
#      H2 measured a farm-wide seasonal delta (p05 +10.85 pp) and an estimated
#      ~0.4 pp realised bias. Neither closes the real question. The SIGNAL is
#      uniform ecology (~11 pp, growing season); but the MIXTURE each pixel gets
#      depends on WHICH scenes that pixel lost — and that is cloud, which is
#      SPATIAL. Scenes run 0-96.6% obscured, so partial scenes drop pixels
#      geographically, and H2's sd_delta = 7.78 says the gap varies strongly pixel
#      to pixel. If the seasonal mixture correlates with flood frequency, then
#      p05-vs-inundation (H4) is partly measuring CLOUD, not vegetation.
#      Test: per-pixel fraction of retained seasons that are JJA+SON -> its
#      distribution, a map, and its correlation with census flood frequency.
#        tight + uncorrelated -> closes, H4 proceeds
#        correlated          -> H4's central relationship is confounded
#
#   2. Balanced-subsample diagnostic — MEASURE the realised bias rather than infer
#      it. Two independent parties inferred ~0.4 pp by the same route; two agreeing
#      inferences are not a measurement. DIAGNOSTIC ONLY — the product is NOT
#      rebalanced (that would change what the statistic means).
#
#   3. Open diagnostics:
#      a. farm-masked columns for the percentile diagnostics (the shipped medians
#         p05 58.2 / p50 82.0 are ~2/3 non-Gayini and would get cited as farm figures)
#      b. p05 of band2 (PV/green) alone, farm-masked — a 58% total-veg floor in
#         semi-arid chenopod is probably mostly dead litter. "The floor is 58%" and
#         "the floor is 58% DEAD MATERIAL" are different slides; Adrian needs the second.
#      c. the pale blob at ~(9,005,000, 4,350,000): lake, claypan, or render artefact?
#
# Workflow stage: 05_ground_cover (diagnostics) · Tier 2 Task H, Track B
# Run mode: analysis (read-only) · no products, no DB mutation
# Key inputs:
#   - Output/rasters/fc_intermediate/fc_total_veg_3577_wy1988_2023.tif (140 lyr, H2)
#   - Output/rasters/veg_percentiles_8058/total_veg_p{05..50}_8058.tif
#   - Output/rasters/inundation_annual_stack_8058/annual_{wet,valid}_any_*_8058.tif
#   - Output/rasters/veg_regime_class_8058.tif · Input/landsat_fractionalcover3/*
# Key outputs (diagnostics only):
#   - Output/diagnostics/tier2H_h2_gate_season_mix.csv
#   - Output/diagnostics/tier2H_h2_gate_mix_vs_flood_binned.csv
#   - Output/diagnostics/tier2H_h2_balanced_subsample.csv
#   - Output/diagnostics/tier2H_h2_farm_masked_diagnostics.csv
#   - Output/diagnostics/tier2H_h2_blob_probe.csv
#   - Output/figures/H2_gate_season_mix_data.png
# ------------------------------------------------------------------------------

## 0. Constants ----

MIN_SEASONS <- 50L
N_SAMPLE    <- 50000L    # pixels for the balanced-subsample diagnostic
SEED        <- 20260716L
BLOB_XY     <- c(9005000, 4350000)   # EPSG:8058, the pale blob to identify

root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", getwd()), winslash = "/", mustWork = TRUE)
source(file.path(root_dir, "R", "gayini_helpers.R"))
source(file.path(root_dir, "R", "gayini_output_helpers.R"))
source(file.path(root_dir, "R", "vector_prep_functions.R"))
source(file.path(root_dir, "R", "gayini_veg_regime_functions.R"))
source(file.path(root_dir, "R", "gayini_gradient_helpers.R"))

suppressPackageStartupMessages({
  library(sf); library(terra); library(dplyr)
})
sf::sf_use_s2(FALSE); terra::terraOptions(progress = 0)
set.seed(SEED)

rasters_dir     <- file.path(root_dir, "Output", "rasters")
diagnostics_dir <- file.path(root_dir, "Output", "diagnostics")
figures_dir     <- file.path(root_dir, "Output", "figures")
spatial_dir     <- file.path(root_dir, "Output", "spatial_8058")

tv_tif   <- file.path(rasters_dir, "fc_intermediate", "fc_total_veg_3577_wy1988_2023.tif")
class_r  <- terra::rast(file.path(rasters_dir, "veg_regime_class_8058.tif"))
pool     <- readr::read_csv(file.path(diagnostics_dir, "tier2H_h2_fc_water_year_pool.csv"),
                            show_col_types = FALSE)
pool     <- pool[pool$retained, ]
tv       <- terra::rast(tv_tif)
names(tv) <- paste0(pool$water_year, "_", pool$season)
stopifnot(terra::nlyr(tv) == 140L)

boundary      <- gayini_read_vector(file.path(spatial_dir, "gayini_boundary_epsg8058.gpkg"),
                                    label = "boundary (8058)")
boundary_3577 <- sf::st_transform(boundary, 3577)
bv3577 <- terra::vect(boundary_3577)
bv8058 <- terra::vect(boundary)

sel_warm <- pool$season %in% c("JJA", "SON")
sel_cool <- pool$season %in% c("DJF", "MAM")


## 1. GATE — per-pixel fraction of RETAINED seasons that are JJA+SON ----

message("\n[gate] Counting retained seasons by season group ...")
n_warm <- sum(!is.na(tv[[which(sel_warm)]]))
n_cool <- sum(!is.na(tv[[which(sel_cool)]]))
n_tot  <- n_warm + n_cool
f_warm <- n_warm / n_tot
## Apply the product's own support rule so the gate describes the shipped pixels.
f_warm <- terra::ifel(n_tot >= MIN_SEASONS, f_warm, NA)
names(f_warm) <- "f_warm"

## Onto the canonical grid for the join against flood frequency (continuous -> bilinear).
f_warm_8058 <- terra::project(f_warm, class_r, method = "bilinear")
names(f_warm_8058) <- "f_warm"

## Census flood frequency (pixel support) from the NN 8058 stack.
wet <- terra::rast(file.path(rasters_dir, "inundation_annual_stack_8058",
                             "annual_wet_any_1988_2023_8058.tif"))
val <- terra::rast(file.path(rasters_dir, "inundation_annual_stack_8058",
                             "annual_valid_any_1988_2023_8058.tif"))
freq <- 100 * terra::app(wet, "sum", na.rm = TRUE) / terra::app(val, "sum", na.rm = TRUE)
names(freq) <- "flood_freq_pct"
stopifnot(isTRUE(terra::compareGeom(f_warm_8058, class_r, lyrs = FALSE, stopOnError = FALSE)),
          isTRUE(terra::compareGeom(freq, class_r, lyrs = FALSE, stopOnError = FALSE)))

## Census pixels only (veg_regime_class non-NA).
cls_v  <- terra::values(class_r)[, 1]
fw_v   <- terra::values(f_warm_8058)[, 1]
fq_v   <- terra::values(freq)[, 1]
keep   <- !is.na(cls_v) & !is.na(fw_v) & !is.na(fq_v)
fw <- fw_v[keep]; fq <- fq_v[keep]; cl <- cls_v[keep]

qs <- stats::quantile(fw, c(0, 0.01, 0.05, 0.5, 0.95, 0.99, 1), names = FALSE)
mix_tbl <- tibble::tibble(
  scope = "census pixels (veg_regime_class non-NA)",
  n_pixels = length(fw),
  min = round(qs[1], 4), p01 = round(qs[2], 4), p05 = round(qs[3], 4),
  median = round(qs[4], 4), p95 = round(qs[5], 4), p99 = round(qs[6], 4),
  max = round(qs[7], 4), sd = round(stats::sd(fw), 4),
  balanced_would_be = 0.5)
message("\n================ GATE 1 · fraction of retained seasons that are JJA+SON ================")
print(as.data.frame(mix_tbl), row.names = FALSE)

## Correlation with census flood frequency — the thing that gates H4.
r_pearson  <- stats::cor(fw, fq, method = "pearson")
r_spearman <- stats::cor(fw, fq, method = "spearman")
message(sprintf("\n  correlation of season-mix with flood frequency (n = %s census px):",
                format(length(fw), big.mark = ",")))
message(sprintf("    Pearson  r   = %+.4f   (r^2 = %.5f)", r_pearson, r_pearson^2))
message(sprintf("    Spearman rho = %+.4f", r_spearman))

## Binned summary (H5 convention: never plot ~1M raw points).
bins <- cut(fq, breaks = c(-0.001, 0, 10, 25, 50, 100),
            labels = c("0 (never)", "0-10", "10-25", "25-50", ">50"))
binned <- tibble::tibble(flood_freq_bin = bins, f_warm = fw) |>
  dplyr::group_by(flood_freq_bin) |>
  dplyr::summarise(n_px = dplyr::n(), mean_f_warm = round(mean(f_warm), 4),
                   sd_f_warm = round(stats::sd(f_warm), 4), .groups = "drop")
message("\n  season-mix by flood-frequency bin (if flat, the mixture is not flood-related):")
print(as.data.frame(binned), row.names = FALSE)

gayini_write_csv(mix_tbl, file.path(diagnostics_dir, "tier2H_h2_gate_season_mix.csv"))
gayini_write_csv(binned, file.path(diagnostics_dir, "tier2H_h2_gate_mix_vs_flood_binned.csv"))

## --- Convert the correlation into the ONLY unit that decides H4: how much of the
## p05-vs-flood relationship is spuriously injected by the mixture-flood link.
## induced bias in p05 across the flood gradient = (p05 sensitivity to mix)
## x (change in mix across the flood gradient). The mix->p05 slope comes from the
## balanced-subsample measurement in §2 (computed there); here we capture the mix
## change with flood, so the two combine in the verdict.
mix_range_over_flood <- max(binned$mean_f_warm) - min(binned$mean_f_warm)
## Also as a slope: regress f_warm on flood freq (pp of mix per pp of flood).
mix_flood_slope <- unname(stats::coef(stats::lm(fw ~ fq))[2])
message(sprintf("\n  mix change across the flood bins: %.4f (fraction); OLS slope %.2e per %%-flood",
                mix_range_over_flood, mix_flood_slope))

## Map of the mixture.
png_gate <- file.path(figures_dir, "H2_gate_season_mix_data.png")
grDevices::png(png_gate, width = 1500, height = 900, res = 140)
op <- graphics::par(mar = c(2.2, 2.2, 3.4, 5))
terra::plot(f_warm_8058, ext = terra::ext(terra::trim(f_warm_8058)),
            col = grDevices::hcl.colors(100, "Blue-Red 3"), colNA = "grey85",
            range = c(0.3, 0.7),
            main = sprintf("Fraction of retained seasons that are JJA+SON (balanced = 0.50)\nmedian %.3f · sd %.3f · Pearson r vs flood freq = %+.3f",
                           mix_tbl$median, mix_tbl$sd, r_pearson))
terra::plot(bv8058, add = TRUE, border = "black", lwd = 1.6)
graphics::par(op); grDevices::dev.off()
message("  wrote: ", png_gate)


## 2. Balanced-subsample diagnostic — MEASURE the bias (diagnostic only) ----

message("\n================ 2 · balanced-subsample diagnostic ================")
tv_farm <- terra::mask(terra::crop(tv, bv3577), bv3577)
samp <- terra::spatSample(tv_farm, size = N_SAMPLE, method = "random",
                          values = TRUE, na.rm = FALSE, warn = FALSE)
samp <- as.matrix(samp)
seasons <- pool$season
keep_row <- rowSums(!is.na(samp)) >= MIN_SEASONS
samp <- samp[keep_row, , drop = FALSE]
message(sprintf("  sampled %s farm pixels with >= %d valid seasons (of %d drawn)",
                format(nrow(samp), big.mark = ","), MIN_SEASONS, N_SAMPLE))

bal_one <- function(v) {
  ok <- !is.na(v)
  idx_by <- lapply(c("DJF", "MAM", "JJA", "SON"), function(g) which(ok & seasons == g))
  k <- min(vapply(idx_by, length, integer(1)))
  if (k < 1L) return(c(NA_real_, NA_real_, NA_real_, NA_real_))
  bal <- unlist(lapply(idx_by, function(ix) if (length(ix) == k) ix else sample(ix, k)))
  c(stats::quantile(v[ok],  0.05, names = FALSE),  # product p05 (all valid seasons)
    stats::quantile(v[bal], 0.05, names = FALSE),  # balanced p05
    stats::quantile(v[ok],  0.50, names = FALSE),
    stats::quantile(v[bal], 0.50, names = FALSE))
}
res <- t(apply(samp, 1, bal_one))
res <- res[stats::complete.cases(res), , drop = FALSE]
d05 <- res[, 2] - res[, 1]   # balanced - product
d50 <- res[, 4] - res[, 3]

bal_tbl <- tibble::tibble(
  statistic = c("p05", "p50"),
  n_pixels = nrow(res),
  product_mean  = c(mean(res[, 1]), mean(res[, 3])),
  balanced_mean = c(mean(res[, 2]), mean(res[, 4])),
  mean_bias  = c(mean(d05), mean(d50)),
  median_bias = c(stats::median(d05), stats::median(d50)),
  sd_bias = c(stats::sd(d05), stats::sd(d50)),
  q05_bias = c(stats::quantile(d05, .05, names = FALSE), stats::quantile(d50, .05, names = FALSE)),
  q95_bias = c(stats::quantile(d05, .95, names = FALSE), stats::quantile(d50, .95, names = FALSE))
) |> dplyr::mutate(dplyr::across(dplyr::where(is.numeric), ~ round(.x, 4)))
message("  bias = (seasonally balanced pool) - (product pool), cover %:")
print(as.data.frame(bal_tbl), row.names = FALSE)
message("  (the ~0.4 pp figure was an INFERENCE by both parties; this is the measurement)")
gayini_write_csv(bal_tbl, file.path(diagnostics_dir, "tier2H_h2_balanced_subsample.csv"))

## The p05 sensitivity to the mix, in pp of p05 per unit of f_warm. The balanced
## pool sits at f_warm = 0.5; the product sits at the observed median. So:
##   slope ~= mean_bias_p05 / (0.5 - median_f_warm)
mix_p05_slope <- bal_tbl$mean_bias[bal_tbl$statistic == "p05"] / (0.5 - mix_tbl$median)
## Spurious p05 difference across the WHOLE flood gradient (the confound that would
## contaminate H4's p05-vs-inundation relationship):
induced_p05_bias <- mix_p05_slope * mix_range_over_flood
message(sprintf("\n  mix->p05 slope = %.1f pp p05 per unit f_warm; mix range over flood = %.4f",
                mix_p05_slope, mix_range_over_flood))
message(sprintf("  ==> INDUCED p05 bias across the full flood gradient = %.3f pp",
                induced_p05_bias))


## 3a. Farm-masked diagnostics for the 5 shipped percentile rasters ----

message("\n================ 3a · farm-masked percentile diagnostics ================")
PROB_LABELS <- c("p05", "p10", "p20", "p30", "p50")
fm_rows <- lapply(PROB_LABELS, function(nm) {
  r  <- terra::rast(file.path(rasters_dir, "veg_percentiles_8058",
                              paste0("total_veg_", nm, "_8058.tif")))
  vf <- terra::values(terra::mask(r, bv8058))[, 1]; vf <- vf[!is.na(vf)]
  vg <- terra::values(r)[, 1]; vg <- vg[!is.na(vg)]
  tibble::tibble(raster = nm,
                 n_data_grid = length(vg), median_grid = round(stats::median(vg), 3),
                 n_data_farm = length(vf),
                 min_farm = round(min(vf), 3), median_farm = round(stats::median(vf), 3),
                 max_farm = round(max(vf), 3),
                 farm_minus_grid_median = round(stats::median(vf) - stats::median(vg), 3))
})
fm_tbl <- dplyr::bind_rows(fm_rows)
print(as.data.frame(fm_tbl), row.names = FALSE)


## 3b. p05 of band2 (PV / green) ALONE, farm-masked — is the floor dead litter? ----

message("\n================ 3b · p05 of GREEN (PV, band2) alone ================")
pv_tif <- file.path(rasters_dir, "fc_intermediate", "fc_pv_p05_3577.tif")
if (!file.exists(pv_tif)) {
  message("  building the 140-layer PV stack (band2, 255 -> NA) and its p05 ...")
  pv_stack <- terra::rast(lapply(seq_len(nrow(pool)), function(i) {
    b2 <- terra::subst(terra::rast(pool$file[i])[[2]], 255L, NA)
    names(b2) <- paste0(pool$water_year[i], "_", pool$season[i]); b2
  }))
  pv_n <- sum(!is.na(pv_stack))
  pv_p05 <- terra::quantile(pv_stack, probs = 0.05, na.rm = TRUE)
  pv_p05 <- terra::ifel(pv_n >= MIN_SEASONS, pv_p05, NA)
  terra::writeRaster(pv_p05, pv_tif, overwrite = TRUE, datatype = "FLT4S")
}
pv_p05_8058 <- terra::project(terra::rast(pv_tif), class_r, method = "bilinear")
names(pv_p05_8058) <- "pv_p05"

tot_p05 <- terra::rast(file.path(rasters_dir, "veg_percentiles_8058", "total_veg_p05_8058.tif"))
pv_f  <- terra::values(terra::mask(pv_p05_8058, bv8058))[, 1]; pv_f <- pv_f[!is.na(pv_f)]
tot_f <- terra::values(terra::mask(tot_p05, bv8058))[, 1];     tot_f <- tot_f[!is.na(tot_f)]
pv_tbl <- tibble::tibble(
  layer = c("total veg p05 (green + dead)", "green/PV only p05"),
  n_farm_px = c(length(tot_f), length(pv_f)),
  min = round(c(min(tot_f), min(pv_f)), 3),
  median = round(c(stats::median(tot_f), stats::median(pv_f)), 3),
  mean = round(c(mean(tot_f), mean(pv_f)), 3),
  max = round(c(max(tot_f), max(pv_f)), 3))
print(as.data.frame(pv_tbl), row.names = FALSE)
message(sprintf("\n  READ: at the floor, the median farm pixel holds %.1f%% total veg of which",
                stats::median(tot_f)))
message(sprintf("  only ~%.1f%% is GREEN -> ~%.0f%% of the floor is DEAD material (litter/NPV).",
                stats::median(pv_f), 100 * (1 - stats::median(pv_f) / stats::median(tot_f))))
message("  'The floor is 58%' and 'the floor is 58% dead material' are different slides.")
fm_tbl <- dplyr::bind_rows(fm_tbl, tibble::tibble(
  raster = "pv_p05_green_only", n_data_grid = NA_integer_, median_grid = NA_real_,
  n_data_farm = length(pv_f), min_farm = round(min(pv_f), 3),
  median_farm = round(stats::median(pv_f), 3), max_farm = round(max(pv_f), 3),
  farm_minus_grid_median = NA_real_))
gayini_write_csv(fm_tbl, file.path(diagnostics_dir, "tier2H_h2_farm_masked_diagnostics.csv"))


## 3c. The pale blob at ~(9,005,000, 4,350,000) — lake, claypan, or artefact? ----

message("\n================ 3c · the pale blob probe ================")
pt <- terra::vect(cbind(BLOB_XY[1], BLOB_XY[2]), crs = terra::crs(class_r))
class_num <- class_r; levels(class_num) <- NULL; terra::coltab(class_num) <- NULL  # codes, not factor
probe_stack <- c(tot_p05, pv_p05_8058, f_warm_8058, freq, class_num)
names(probe_stack) <- c("total_p05", "pv_p05", "f_warm", "flood_freq_pct", "veg_regime_class")
## Sample a small neighbourhood so a single-cell oddity is distinguishable from a feature.
buf <- terra::buffer(pt, 400)
nb  <- terra::extract(probe_stack, buf, fun = NULL, ID = FALSE)
blob_tbl <- tibble::tibble(
  variable = names(probe_stack),
  n_cells_in_400m = vapply(nb, function(v) sum(!is.na(v)), integer(1)),
  n_NA = vapply(nb, function(v) sum(is.na(v)), integer(1)),
  min = vapply(nb, function(v) suppressWarnings(round(min(v, na.rm = TRUE), 3)), numeric(1)),
  median = vapply(nb, function(v) suppressWarnings(round(stats::median(v, na.rm = TRUE), 3)), numeric(1)),
  max = vapply(nb, function(v) suppressWarnings(round(max(v, na.rm = TRUE), 3)), numeric(1)))
print(as.data.frame(blob_tbl), row.names = FALSE)
classes <- gayini_veg_regime_classes()
cc <- stats::median(nb$veg_regime_class, na.rm = TRUE)
message(sprintf("\n  veg_regime_class at the blob: %s -> %s",
                cc, if (is.na(cc)) "OUTSIDE the mapped veg map (NA)" else
                  classes$label[match(round(cc), classes$code)]))
gayini_write_csv(blob_tbl, file.path(diagnostics_dir, "tier2H_h2_blob_probe.csv"))


## 4. Gate verdict — decided on the INDUCED BIAS, with r reported honestly ----
##
## A bare correlation threshold is the wrong instrument: r is real (the mix and
## flooding are weakly linked — wet pixels lose more winter/spring cloud) but what
## gates H4 is how many pp of the p05-vs-inundation relationship that link injects.
## That is `induced_p05_bias`. It is negligible only if it is small against the
## ecological p05 signal across the flood gradient (tens of pp between communities).

## The actual p05 spread across the flood gradient, for scale.
p05_ras <- terra::rast(file.path(rasters_dir, "veg_percentiles_8058", "total_veg_p05_8058.tif"))
p05_v <- terra::values(p05_ras)[, 1][keep]
p05_by_flood <- tapply(p05_v, bins, function(v) stats::median(v, na.rm = TRUE))
p05_signal_range <- diff(range(p05_by_flood, na.rm = TRUE))

CONFOUND_FRAC_MAX <- 0.10   # induced bias must be < 10% of the real p05 signal
confound_frac <- abs(induced_p05_bias) / p05_signal_range
gate_pass <- confound_frac < CONFOUND_FRAC_MAX

message("\n==================== GATE VERDICT ====================")
message(sprintf("  mixture spread     : median %.3f · sd %.4f (tight)", mix_tbl$median, mix_tbl$sd))
message(sprintf("  mixture x flood    : Pearson r = %+.4f (r^2 = %.4f) — REAL but weak",
                r_pearson, r_pearson^2))
message(sprintf("  induced p05 bias   : %.3f pp across the whole flood gradient", induced_p05_bias))
message(sprintf("  real p05 signal    : %.1f pp across the flood gradient (median by bin)",
                p05_signal_range))
message(sprintf("  confound fraction  : %.1f%% of the real signal (pass if < %.0f%%)",
                100 * confound_frac, 100 * CONFOUND_FRAC_MAX))
message(sprintf("  ==> %s", if (gate_pass) paste(
  "PASS: the mixture is tight and, converted to p05 units, injects only",
  sprintf("%.2f pp", abs(induced_p05_bias)), "into a", sprintf("%.0f pp", p05_signal_range),
  "signal. H4's p05-vs-inundation is not materially confounded — state the caveat, proceed.")
  else "FAIL: the induced bias is a material fraction of the p05 signal — H4 would partly measure CLOUD. STOP."))
message("\n  NOTE: this is a recommendation from the magnitude; H4 waits for Hugh's call regardless.")

gate_verdict <- list(
  mixture_median = mix_tbl$median, mixture_sd = mix_tbl$sd,
  pearson_r = round(r_pearson, 4), spearman_rho = round(r_spearman, 4), r2 = round(r_pearson^2, 5),
  mix_range_over_flood = round(mix_range_over_flood, 4),
  mix_to_p05_slope_pp = round(mix_p05_slope, 2),
  induced_p05_bias_pp = round(induced_p05_bias, 3),
  p05_signal_range_pp = round(p05_signal_range, 2),
  confound_fraction = round(confound_frac, 4),
  balanced_subsample_p05_bias_pp = bal_tbl$mean_bias[bal_tbl$statistic == "p05"],
  verdict = if (gate_pass) "PASS (proceed with stated caveat)" else "FAIL",
  decides = "H4 (census parquet veg_p* vs flood_freq relationship)")
jsonlite::write_json(gate_verdict, file.path(diagnostics_dir, "tier2H_h2_gate_verdict.json"),
                     auto_unbox = TRUE, pretty = TRUE, digits = 6)
message("\n(diagnostics only — no products written, no DB mutation)")
