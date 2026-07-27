#!/usr/bin/env Rscript
# T2 Gate B - per-zone annual vegetation extraction.
# Extracts the four 8058 stacks at the 795,602 in-scope zoned census centroids
# (SCOPE_NON_TREED = treed_context_flag=0 AND regime_band<>'context'; zoned only),
# and aggregates to two grains, from the SAME extraction:
#   (1) zone x water_year x variant  -> fact_zone_veg_annual   (registered substrate)
#   (2) zone x community x water_year x variant -> Gate E faceting grain
# veg percentiles are WITHIN-zone WITHIN-year SPATIAL percentiles (veg_p05_spatial),
# never the census temporal veg_p05. Inundation (wet/valid) is variant-independent.
# Values kept RAW: >100 is bilinear-resampling overshoot (I-01/C-10), flagged not clamped.
# Writes CSV aggregates only; DB load is a separate step (verify before the DB is touched).

suppressPackageStartupMessages({library(terra)})
root    <- normalizePath(".", winslash = "/")
source(file.path(root, "R/gayini_params.R"))
outdir  <- file.path(root, "Output/tables"); dir.create(outdir, showWarnings = FALSE, recursive = TRUE)

# inputs are DB/sidecar-derived and repo-relative (T2_gateB_prep.py), never temp.
pts <- utils::read.csv(file.path(outdir, "T2_in_scope_points.csv"))
den <- utils::read.csv(file.path(outdir, "T2_zone_denominator.csv"))
stopifnot(nrow(pts) == 795602L, all(pts$zone_fid %in% den$zone_fid))

coords <- as.matrix(pts[, c("x_8058", "y_8058")])
zone   <- pts$zone_fid
comm   <- pts$community
zfac   <- factor(zone)
zcfac  <- factor(paste(zone, comm, sep = "||"))

# min-support rule: NULL a zone-year where n_pixels_valid < max(500, 30% of zone non-treed px)
MIN_ABS <- 500L; MIN_FRAC <- 0.30
den$min_valid <- pmax(MIN_ABS, ceiling(MIN_FRAC * den$zone_nontreed_px))
minmap <- setNames(den$min_valid, as.character(den$zone_fid))
MIN_RULE <- sprintf("n_pixels_valid >= max(%d, ceil(%.2f * zone_nontreed_px))", MIN_ABS, MIN_FRAC)

paths <- list(
  mean_of_seasons = "Output/rasters/veg_annual_8058/total_veg_annual_mean_8058.tif",
  jja_son         = "Output/rasters/veg_annual_8058/total_veg_annual_jja_son_8058.tif")
wet_path   <- "Output/rasters/inundation_annual_stack_8058/annual_wet_any_1988_2023_8058.tif"
valid_path <- "Output/rasters/inundation_annual_stack_8058/annual_valid_any_1988_2023_8058.tif"

emat <- function(p) {
  e <- terra::extract(rast(p), coords)      # matrix input -> values only, no ID col
  as.matrix(e)
}
q <- function(x, p) as.numeric(stats::quantile(x, p, type = 7, names = FALSE))

years_of <- function(r) {                          # band 'YYYY-YYYY+1' -> WY start int
  as.integer(substr(names(r), 1, 4)) }

## ---- veg aggregation (both grains, both variants) ----
zone_rows <- list(); comm_rows <- list()
for (variant in names(paths)) {
  M  <- emat(paths[[variant]])
  wy <- years_of(rast(paths[[variant]]))
  for (j in seq_len(ncol(M))) {
    v <- M[, j]; ok <- !is.na(v)
    # grain 1: zone x year   (droplevels: no NA rows for zones absent this year)
    z <- droplevels(zfac[ok]); vv <- v[ok]
    n   <- tapply(vv, z, length)
    lev <- as.integer(names(n))
    zone_rows[[length(zone_rows) + 1L]] <- data.frame(
      zone_fid = lev, water_year = wy[j], series_variant = variant,
      n_pixels_valid = as.integer(n),
      veg_mean        = as.numeric(tapply(vv, z, mean)),
      veg_median      = as.numeric(tapply(vv, z, median)),
      veg_p05_spatial = as.numeric(tapply(vv, z, q, 0.05)),
      veg_p10_spatial = as.numeric(tapply(vv, z, q, 0.10)),
      veg_p25_spatial = as.numeric(tapply(vv, z, q, 0.25)),
      n_px_over_100   = as.integer(tapply(vv, z, function(x) sum(x > 100))),
      stringsAsFactors = FALSE)
    # grain 2: zone x community x year
    zc <- droplevels(zcfac[ok])
    nc <- tapply(vv, zc, length)
    key <- do.call(rbind, strsplit(names(nc), "\\|\\|"))
    comm_rows[[length(comm_rows) + 1L]] <- data.frame(
      zone_fid = as.integer(key[, 1]), community = key[, 2],
      water_year = wy[j], series_variant = variant,
      n_pixels_valid  = as.integer(nc),
      veg_mean        = as.numeric(tapply(vv, zc, mean)),
      veg_p05_spatial = as.numeric(tapply(vv, zc, q, 0.05)),
      stringsAsFactors = FALSE)
  }
  rm(M); gc()
}
ZY_agg <- do.call(rbind, zone_rows)
ZC <- do.call(rbind, comm_rows)

# full 64 x 35 x 2 grid so drop accounting is exact (zone-years with 0 valid
# veg pixels become n_pixels_valid = 0 rows, then fall to the low-support drop).
grid <- expand.grid(zone_fid = 1:64, water_year = sort(unique(ZY_agg$water_year)),
                    series_variant = names(paths), stringsAsFactors = FALSE)
ZY <- merge(grid, ZY_agg, by = c("zone_fid","water_year","series_variant"), all.x = TRUE)
ZY$n_pixels_valid[is.na(ZY$n_pixels_valid)] <- 0L
ZY$n_px_over_100[is.na(ZY$n_px_over_100)]   <- 0L

## ---- inundation (variant-independent): zone x year and community x year ----
Ew <- emat(wet_path); Ev <- emat(valid_path); wy <- years_of(rast(valid_path))
inz <- list(); inc <- list()
cfac <- factor(comm)
for (j in seq_len(ncol(Ev))) {
  w <- Ew[, j]; vl <- Ev[, j]
  vok <- !is.na(vl) & vl == 1                 # valid_any presence-only {1}
  wok <- !is.na(w)  & w  == 1
  vz <- tapply(vok, zfac, sum); wz <- tapply(wok, zfac, sum)
  inz[[j]] <- data.frame(zone_fid = as.integer(names(vz)), water_year = wy[j],
                         valid_pixels = as.integer(vz), wet_pixels = as.integer(wz))
  vc <- tapply(vok, cfac, sum); wc <- tapply(wok, cfac, sum)
  inc[[j]] <- data.frame(community = names(vc), water_year = wy[j],
                         valid_pixels = as.integer(vc), wet_pixels = as.integer(wc))
}
INZ <- do.call(rbind, inz); INC <- do.call(rbind, inc)
INZ$flood_frac_pct <- ifelse(INZ$valid_pixels > 0, 100 * INZ$wet_pixels / INZ$valid_pixels, NA)
INC$flood_frac_pct <- ifelse(INC$valid_pixels > 0, 100 * INC$wet_pixels / INC$valid_pixels, NA)

## ---- assemble fact_zone_veg_annual (grain 1) ----
ZY$pct_px_over_100 <- ifelse(ZY$n_pixels_valid > 0,
                             100 * ZY$n_px_over_100 / ZY$n_pixels_valid, NA)
ZY <- merge(ZY, INZ, by = c("zone_fid", "water_year"), all.x = TRUE)
ZY$min_valid       <- as.integer(minmap[as.character(ZY$zone_fid)])
ZY$low_support     <- ZY$n_pixels_valid < ZY$min_valid
ZY$min_support_rule <- MIN_RULE
ZY$support_level    <- "pixel"
ZY$aggregation_unit <- "zone_year"

dropped <- ZY[ZY$low_support, ]
kept    <- ZY[!ZY$low_support, ]
ZY_ord <- c("zone_fid","water_year","series_variant","n_pixels_valid","min_valid",
            "veg_mean","veg_median","veg_p05_spatial","veg_p10_spatial","veg_p25_spatial",
            "n_px_over_100","pct_px_over_100","wet_pixels","valid_pixels","flood_frac_pct",
            "min_support_rule","support_level","aggregation_unit")
kept <- kept[order(kept$zone_fid, kept$water_year, kept$series_variant), ZY_ord]

utils::write.csv(kept,     file.path(outdir, "T2_fact_zone_veg_annual.csv"),          row.names = FALSE)
utils::write.csv(ZC,       file.path(outdir, "T2_fact_zone_community_veg_annual.csv"), row.names = FALSE)
utils::write.csv(INC,      file.path(outdir, "T2_community_year_flood.csv"),           row.names = FALSE)
# drop log by zone
drp <- as.data.frame(table(zone_fid = dropped$zone_fid), stringsAsFactors = FALSE)
utils::write.csv(dropped, file.path(outdir, "T2_dropped_zone_years.csv"), row.names = FALSE)

cat(sprintf("grain1 kept rows        : %d  (of %d = 64*35*2)\n", nrow(kept), 64L*35L*2L))
cat(sprintf("grain1 dropped rows     : %d\n", nrow(dropped)))
cat(sprintf("grain2 (zone x comm x y): %d rows\n", nrow(ZC)))
cat(sprintf("veg range kept          : [%.3f, %.3f]\n", min(kept$veg_mean), max(kept$veg_mean)))
cat(sprintf("any veg col < 0 or NA   : %s\n",
            any(is.na(kept[,c("veg_mean","veg_p05_spatial")])) ||
            min(kept$veg_p05_spatial) < 0))
cat(sprintf("total n_px_over_100     : %d\n", sum(kept$n_px_over_100)))
if (nrow(dropped)) { cat("dropped by zone_fid:\n"); print(drp) }
cat("DONE\n")
