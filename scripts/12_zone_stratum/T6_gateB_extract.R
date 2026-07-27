#!/usr/bin/env Rscript
# T6 Gate B (part 2) - three-arm extraction at STRATUM grain (community x regime_band),
# so wetness is controlled by construction (Gate A drier-skew confound is designed out).
# Reuses T2's method: same 8058 stacks, same veg_p05_spatial (within-year spatial pctl),
# raw values. Produces two grains from ONE pass over all 988,831 in-scope pixels:
#   (A) three-arm stratum : arm x community x regime_band x year x variant  -> comparison
#   (B) unzoned component : component x community x regime_band x year x variant -> spread
# arm: zone_fid NULL -> unzoned_inferred_standard; grazing_excluded=1 -> not_grazed; else grazed_14day.

suppressPackageStartupMessages({library(terra)})
root <- normalizePath(".", winslash = "/")
source(file.path(root, "R/gayini_params.R"))
tbl <- file.path(root, "Output/tables")
PXHA <- GAYINI_PARAMS$PIXEL_AREA_HA
MIN_ABS <- 500L

pts <- utils::read.csv(file.path(tbl, "T6_in_scope_points.csv"))
armmap <- utils::read.csv(file.path(tbl, "T6_zone_arm_map.csv"))
pc <- utils::read.csv(file.path(tbl, "T6_unzoned_pixel_component.csv"))
comps <- utils::read.csv(file.path(tbl, "T6_components.csv"))

# arm per pixel
a2 <- setNames(armmap$treatment_arm, as.character(armmap$zone_fid))
pts$arm <- ifelse(is.na(pts$zone_fid), "unzoned_inferred_standard",
                  a2[as.character(pts$zone_fid)])
# component per pixel (unzoned only); qualifying flag
pts <- merge(pts, pc, by = "pixel_id", all.x = TRUE, sort = FALSE)
qual_ids <- comps$component_id[comps$is_qualifying == 1]
pts$qual_comp <- ifelse(!is.na(pts$component_id) & pts$component_id %in% qual_ids,
                        pts$component_id, NA_integer_)
# re-sort to CSV order lost by merge is irrelevant (extract by coords per-row)
coords <- as.matrix(pts[, c("x_8058", "y_8058")])

paths <- list(mean_of_seasons = "Output/rasters/veg_annual_8058/total_veg_annual_mean_8058.tif",
              jja_son = "Output/rasters/veg_annual_8058/total_veg_annual_jja_son_8058.tif")
wet_p <- "Output/rasters/inundation_annual_stack_8058/annual_wet_any_1988_2023_8058.tif"
val_p <- "Output/rasters/inundation_annual_stack_8058/annual_valid_any_1988_2023_8058.tif"
emat <- function(p) as.matrix(terra::extract(rast(p), coords))
q <- function(x, p) as.numeric(stats::quantile(x, p, type = 7, names = FALSE))
years_of <- function(r) as.integer(substr(names(r), 1, 4))

# grouping factors: band-level (within-stratum) and community-level (band pooled, 'ALL')
armK <- with(pts, paste(arm, community, regime_band, sep = "||"))
armKc <- with(pts, paste(arm, community, "ALL", sep = "||"))
compK <- with(pts, ifelse(is.na(qual_comp), NA,
                          paste(qual_comp, community, regime_band, sep = "||")))
compKc <- with(pts, ifelse(is.na(qual_comp), NA,
                           paste(qual_comp, community, "ALL", sep = "||")))  # for Gate E trajectories
# plot-confirmed unzoned subset (correction 2): a 4th arm overlapping the full unzoned,
# so Gate D reports both. Confirmed = qualifying components that contain a standard plot.
pc_ids <- comps$component_id[comps$plot_confirmed == 1 & comps$is_qualifying == 1]
is_pc <- !is.na(pts$qual_comp) & pts$qual_comp %in% pc_ids
pcK  <- ifelse(is_pc, paste("unzoned_plot_confirmed", pts$community, pts$regime_band, sep = "||"), NA)
pcKc <- ifelse(is_pc, paste("unzoned_plot_confirmed", pts$community, "ALL", sep = "||"), NA)
uvec <- ifelse(pts$arm == "unzoned_inferred_standard", pts$qual_comp, pts$zone_fid)
nuf <- function(v) length(unique(v[!is.na(v)]))
arm_units <- c(tapply(uvec, armK, nuf), tapply(uvec, armKc, nuf),
               tapply(uvec, pcK, nuf), tapply(uvec, pcKc, nuf))
comp_area <- c(tapply(rep(1L, nrow(pts)), compK, sum),
               tapply(rep(1L, nrow(pts)), compKc, sum))

agg_veg <- function(M, variant, keyvec, extra = NULL) {
  out <- list(); wy <- years_of(rast(paths[[variant]]))
  for (j in seq_len(ncol(M))) {
    v <- M[, j]; ok <- !is.na(v) & !is.na(keyvec)
    k <- factor(keyvec[ok]); vv <- v[ok]
    n <- tapply(vv, k, length); lv <- names(n)
    df <- data.frame(key = lv, water_year = wy[j], series_variant = variant,
                     n_pixels_valid = as.integer(n),
                     veg_mean = as.numeric(tapply(vv, k, mean)),
                     veg_median = as.numeric(tapply(vv, k, median)),
                     veg_p05_spatial = as.numeric(tapply(vv, k, q, 0.05)),
                     veg_p10_spatial = as.numeric(tapply(vv, k, q, 0.10)),
                     stringsAsFactors = FALSE)
    out[[length(out) + 1L]] <- df
  }
  do.call(rbind, out)
}
agg_inun <- function(Ew, Ev, keyvec) {
  out <- list(); wy <- years_of(rast(val_p))
  for (j in seq_len(ncol(Ev))) {
    w <- Ew[, j]; vl <- Ev[, j]; ok <- !is.na(keyvec)
    k <- factor(keyvec[ok])
    vok <- !is.na(vl[ok]) & vl[ok] == 1; wok <- !is.na(w[ok]) & w[ok] == 1
    out[[length(out) + 1L]] <- data.frame(
      key = levels(k), water_year = wy[j],
      valid_pixels = as.integer(tapply(vok, k, sum)),
      wet_pixels = as.integer(tapply(wok, k, sum)), stringsAsFactors = FALSE)
  }
  r <- do.call(rbind, out)
  r$flood_frac_pct <- ifelse(r$valid_pixels > 0, 100 * r$wet_pixels / r$valid_pixels, NA)
  r
}

veg <- list(); comp_veg <- list()
for (variant in names(paths)) {
  M <- emat(paths[[variant]])
  veg[[variant]] <- rbind(agg_veg(M, variant, armK), agg_veg(M, variant, armKc),
                          agg_veg(M, variant, pcK), agg_veg(M, variant, pcKc))
  comp_veg[[variant]] <- rbind(agg_veg(M, variant, compK), agg_veg(M, variant, compKc))
  rm(M); gc()
}
Ew <- emat(wet_p); Ev <- emat(val_p)
arm_inun <- rbind(agg_inun(Ew, Ev, armK), agg_inun(Ew, Ev, armKc),
                  agg_inun(Ew, Ev, pcK), agg_inun(Ew, Ev, pcKc))
comp_inun <- rbind(agg_inun(Ew, Ev, compK), agg_inun(Ew, Ev, compKc))

## ---- (A) three-arm stratum ----
A <- do.call(rbind, veg)
A <- merge(A, arm_inun, by = c("key", "water_year"), all.x = TRUE)
kp <- do.call(rbind, strsplit(A$key, "\\|\\|"))
A$treatment_arm <- kp[, 1]; A$community <- kp[, 2]; A$regime_band <- kp[, 3]
A$n_units <- as.integer(arm_units[A$key])
A$support_level <- "pixel"; A$aggregation_unit <- "arm_community_band_year"
A$key <- NULL
utils::write.csv(A, file.path(tbl, "T6_fact_three_arm_stratum.csv"), row.names = FALSE)

## ---- (B) unzoned per-component ----
B <- do.call(rbind, comp_veg)
B <- merge(B, comp_inun, by = c("key", "water_year"), all.x = TRUE)
kp <- do.call(rbind, strsplit(B$key, "\\|\\|"))
B$component_id <- as.integer(kp[, 1]); B$community <- kp[, 2]; B$regime_band <- kp[, 3]
B$area_ha <- as.numeric(comp_area[B$key]) * PXHA
B$below_min_support <- as.integer(B$n_pixels_valid < MIN_ABS)
np <- setNames(comps$n_plots, comps$component_id)
B$n_plots <- as.integer(np[as.character(B$component_id)])
B$plot_confirmed <- as.integer(B$n_plots > 0)
B$treatment_arm <- "unzoned_inferred_standard"
B$support_level <- "pixel"; B$aggregation_unit <- "component_community_band_year"
B$key <- NULL
utils::write.csv(B, file.path(tbl, "T6_fact_unzoned_component.csv"), row.names = FALSE)

cat(sprintf("(A) three-arm stratum rows: %d  arms=%s\n", nrow(A),
            paste(sort(unique(A$treatment_arm)), collapse = ",")))
cat("   arm x stratum cells (per variant/year distinct):\n")
print(table(A$treatment_arm, A$community))
cat(sprintf("(B) unzoned per-component rows: %d  components=%d  below_min_support=%d\n",
            nrow(B), length(unique(B$component_id)), sum(B$below_min_support)))
cat(sprintf("veg_p05_spatial range A=[%.1f,%.1f] B=[%.1f,%.1f]\n",
            min(A$veg_p05_spatial), max(A$veg_p05_spatial),
            min(B$veg_p05_spatial), max(B$veg_p05_spatial)))
cat("DONE\n")
