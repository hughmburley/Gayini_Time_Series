#!/usr/bin/env Rscript
# T12 · Gate B — zonal/plot/farm/community extraction of DEA Land Cover Level 3.
# Spec docs/reference_update/T12_dea_landcover_l3_extraction.md v3, Gate B (unchanged v2->v3).
#
# Method (spec Gate B):
#  - Reproject VECTORS to the raster CRS (7854); never the categorical raster.
#  - All-touched OFF: pixel-centroid containment (terra rasterize/extract touches=FALSE).
#  - Retain n_pixels_nodata explicitly (255 never occurs -> 0; the geometry mask, not a
#    nodata value, restricts to the property; see spec 2.1 denominator note).
#  - suspect_year_flag per 2.6 from the YEAR ALONE. No 2.4 thresholds here.
#  - Do NOT compute dea_cultivation_class.
#
# Farm-level and community-level: spec offers "same tables w/ sentinel keys, OR separate
# views - CC's call". Chosen: SEPARATE dea_-prefixed tables (fact_dea_landcover_farm_year,
# fact_dea_landcover_community_year) - keeps one support_level per table (project's
# support-purity rule); separate-views was infeasible as communities do not decompose from
# the zone table. Flagged in the change report.
#
# Pixel area: DEA is genuinely 30 m -> 0.09 ha/px, DERIVED from res(), NOT the census
# 0.0623 ha/px constant. Different grid, different constant.
#
# Usage: Rscript T12_gateB_extract.R [check|execute]   (default check; check does no DB write)

suppressPackageStartupMessages({library(terra); library(sf); library(DBI); library(RSQLite)})
args <- commandArgs(trailingOnly = TRUE); mode <- if (length(args)) args[1] else "check"
stopifnot(mode %in% c("check", "execute"))
root <- "d:/Github_repos/Gayini"
db <- file.path(root, "Output/database/Gayini_Results.sqlite")
RUN_ID <- "T12_gateB"; SRC <- "dea_landcover_l3"
CLASS_VALS <- c(111, 112, 124, 215, 216, 220, 255)

# ---- resolve paths from the DB (never hardcode) ----------------------------
con <- dbConnect(SQLite(), db, flags = SQLITE_RO)
sla <- dbGetQuery(con, "SELECT spatial_layer_asset_id, path FROM spatial_layer_asset
                        WHERE spatial_layer_asset_id IN ('spatial_006','spatial_007','spatial_008','spatial_009')")
dmz <- dbGetQuery(con, "SELECT zone_fid, zone_name FROM dim_management_zone")
dbDisconnect(con)
p <- setNames(sla$path, sla$spatial_layer_asset_id)

# ---- DEA raster stack (38 files, sorted by year) ---------------------------
dir <- file.path(root, "Input/landsat_landcover/level3")
files <- sort(list.files(dir, pattern = "^LLC3_\\d{4}_MGA54\\.tif$", full.names = TRUE))
years <- as.integer(sub(".*LLC3_(\\d{4}).*", "\\1", basename(files)))
dea <- rast(files); names(dea) <- years
pixel_area_ha <- prod(res(dea)) / 1e4   # 30*30/1e4 = 0.09, derived
cat(sprintf("DEA stack: %d layers %d-%d | res %g | pixel_area_ha %.4f\n",
            nlyr(dea), min(years), max(years), res(dea)[1], pixel_area_ha))

# ---- vectors -> 7854, build key rasters (centroid containment) -------------
to7854 <- function(path, layer = NULL) project(vect(file.path(root, path)), "EPSG:7854")

zones <- to7854(p["spatial_006"])
znm <- as.data.frame(zones)$ManagmentZ
zones$zone_fid <- dmz$zone_fid[match(znm, dmz$zone_name)]
if (any(is.na(zones$zone_fid))) stop("zone name join incomplete: ",
    paste(znm[is.na(zones$zone_fid)], collapse = ", "))

# plot_id is a TEXT code (e.g. 'GA_015'); use an integer surrogate to rasterize, map back.
plots <- to7854(p["spatial_008"])
plot_id_chr <- as.data.frame(plots)$plot_id
if (any(is.na(plot_id_chr) | plot_id_chr == "")) stop("plot_id missing on some plot features")
plots$plot_key <- as.integer(factor(plot_id_chr))
plot_map <- data.frame(plot_key = plots$plot_key, plot_id = plot_id_chr, stringsAsFactors = FALSE)
plot_map <- plot_map[!duplicated(plot_map$plot_key), ]

comm <- to7854(p["spatial_009"])
comm_names <- as.data.frame(comm)$simplified_vegetation_group
comm$comm_id <- as.integer(factor(comm_names))
comm_map <- data.frame(comm_id = comm$comm_id, community = comm_names)
comm_map <- comm_map[!duplicated(comm_map$comm_id), ]

farm <- to7854(p["spatial_007"]); farm$fid1 <- 1L

grid <- dea[[1]]
kz <- rasterize(zones, grid, field = "zone_fid", touches = FALSE)
kp <- rasterize(plots, grid, field = "plot_key", touches = FALSE)
kc <- rasterize(comm,  grid, field = "comm_id",  touches = FALSE)
kf <- rasterize(farm,  grid, field = "fid1",     touches = FALSE)
vz <- values(kz)[, 1]; vp <- values(kp)[, 1]; vc <- values(kc)[, 1]; vf <- values(kf)[, 1]
cat(sprintf("key coverage (pixels): zones %d | plots %d | community %d | farm %d\n",
            sum(!is.na(vz)), sum(!is.na(vp)), sum(!is.na(vc)), sum(!is.na(vf))))

# ---- suspect-year flag/reason per 2.6 (year alone) -------------------------
suspect <- function(y) {
  parts <- c(
    if (y >= 1988 && y <= 1999) "Landsat 5 TM only; single-sensor, lowest observation density (1988-1999)",
    if (y >= 1999 && y <= 2003) "single-sensor period, reduced observation density (1999-2003)",
    if (y >= 2003 && y <= 2011) "Landsat 7 SLC-off striping, increased in Collection 3 (2003-2011)",
    if (y >= 2011 && y <= 2012) "Landsat 7 only, impaired data quality (2011-2012)",
    if (y == 2010) "2010 anomalous national rainfall CTV false positives; major Murrumbidgee flood year")
  if (length(parts)) paste(parts, collapse = "; ") else NA_character_
}

# ---- crosstab per year, per geometry set -----------------------------------
# returns long df: key, dea_calendar_year, counts by class, shares, area, flags
build <- function(keyvec, keys, keyname) {
  out <- list()
  for (i in seq_along(years)) {
    cv <- values(dea[[i]])[, 1]
    keep <- !is.na(keyvec)
    tb <- table(factor(keyvec[keep], levels = keys),
                factor(cv[keep], levels = CLASS_VALS))
    m <- matrix(as.integer(tb), nrow = length(keys),
                dimnames = list(as.character(keys), as.character(CLASS_VALS)))
    n_nodata <- m[, "255"]
    n_valid  <- rowSums(m[, as.character(setdiff(CLASS_VALS, 255)), drop = FALSE])
    sh <- function(code) ifelse(n_valid > 0, 100 * m[, as.character(code)] / n_valid, NA_real_)
    y <- years[i]
    out[[i]] <- data.frame(
      key = keys, dea_calendar_year = y,
      n_pixels_valid = n_valid, n_pixels_nodata = n_nodata,
      area_ha = n_valid * pixel_area_ha,
      dea_ctv_pct = sh(111), dea_ntv_pct = sh(112), dea_ns_pct = sh(216),
      dea_water_pct = sh(220), dea_nav_pct = sh(124), dea_as_pct = sh(215),
      suspect_year_flag = as.integer(y >= 1988 & y <= 2012),
      suspect_reason = suspect(y),
      source_product_id = SRC, run_id = RUN_ID, row.names = NULL, stringsAsFactors = FALSE)
    out[[i]][[keyname]] <- out[[i]]$key; out[[i]]$key <- NULL
    out[[i]] <- out[[i]][n_valid > 0 | TRUE, ]  # keep all; zero-valid reported
  }
  do.call(rbind, out)
}

zone_df <- build(vz, sort(unique(zones$zone_fid)), "zone_fid"); zone_df$support_level <- "pixel_within_zone_dea_l3"
plot_df <- build(vp, sort(unique(plots$plot_key)), "plot_key")
plot_df <- merge(plot_df, plot_map, by = "plot_key"); plot_df$plot_key <- NULL
plot_df$support_level <- "pixel_within_plot_dea_l3"
comm_df <- build(vc, sort(unique(comm$comm_id)),   "comm_id");  comm_df$support_level <- "pixel_within_community_dea_l3"
comm_df <- merge(comm_df, comm_map, by = "comm_id"); comm_df$comm_id <- NULL
farm_df <- build(vf, 1L, "fid1"); farm_df$fid1 <- NULL; farm_df$support_level <- "pixel_within_property_dea_l3"

# ---- share-sum + coverage checks -------------------------------------------
chk <- function(df, lab) {
  s <- with(df, dea_ctv_pct + dea_ntv_pct + dea_ns_pct + dea_water_pct + dea_nav_pct + dea_as_pct)
  bad <- sum(abs(s - 100) > 0.01, na.rm = TRUE); zero <- sum(df$n_pixels_valid == 0)
  cat(sprintf("  %-10s rows %4d | share!=100(>0.01): %d | zero-valid rows: %d | nodata max: %d\n",
              lab, nrow(df), bad, zero, max(df$n_pixels_nodata)))
  invisible(bad)
}
cat("=== checks ===\n")
chk(zone_df, "zone");  chk(plot_df, "plot");  chk(comm_df, "community"); chk(farm_df, "farm")
cat(sprintf("expected rows: zone %d, plot %d, community %d, farm %d\n",
            64 * 38, 66 * 38, nrow(comm_map) * 38, 38))
cat("\nsuspect split: flag=1 years", paste(range(years[years <= 2012]), collapse = "-"),
    "| flag=0 years", paste(range(years[years > 2012]), collapse = "-"), "\n")
cat("farm-mean CTV 2023-25 (false-positive floor sanity, expect ~6-7%): ",
    round(mean(farm_df$dea_ctv_pct[farm_df$dea_calendar_year >= 2023]), 2), "%\n")
cat("farm CTV 2014 / 2016 (expect ~44-48%): ",
    round(farm_df$dea_ctv_pct[farm_df$dea_calendar_year == 2014], 2), "/",
    round(farm_df$dea_ctv_pct[farm_df$dea_calendar_year == 2016], 2), "\n")

if (mode == "check") { cat("\n[check] NO DB WRITE.\n"); quit(status = 0) }

# ---- execute: write four fact tables (additive, INSERT OR REPLACE) ----------
con <- dbConnect(SQLite(), db)
dbExecute(con, "PRAGMA foreign_keys=OFF")
mk <- function(tbl, keycol) dbExecute(con, sprintf(
  "CREATE TABLE IF NOT EXISTS %s (
     %s, dea_calendar_year INTEGER, n_pixels_valid INTEGER, n_pixels_nodata INTEGER,
     area_ha REAL, dea_ctv_pct REAL, dea_ntv_pct REAL, dea_ns_pct REAL, dea_water_pct REAL,
     dea_nav_pct REAL, dea_as_pct REAL, suspect_year_flag INTEGER, suspect_reason TEXT,
     support_level TEXT, source_product_id TEXT, run_id TEXT,
     PRIMARY KEY (%s, dea_calendar_year))", tbl, keycol,
     sub(" .*", "", keycol)))
mk("fact_dea_landcover_zone_year",      "zone_fid INTEGER")
mk("fact_dea_landcover_plot_year",      "plot_id TEXT")
mk("fact_dea_landcover_community_year", "community TEXT")
# farm PK is the year alone (one property, one row per year) — explicit single-col PK:
dbExecute(con, "CREATE TABLE IF NOT EXISTS fact_dea_landcover_farm_year (
   dea_calendar_year INTEGER PRIMARY KEY, n_pixels_valid INTEGER, n_pixels_nodata INTEGER,
   area_ha REAL, dea_ctv_pct REAL, dea_ntv_pct REAL, dea_ns_pct REAL, dea_water_pct REAL,
   dea_nav_pct REAL, dea_as_pct REAL, suspect_year_flag INTEGER, suspect_reason TEXT,
   support_level TEXT, source_product_id TEXT, run_id TEXT)")

writetab <- function(tbl, df, cols) {
  df <- df[, cols]
  ph <- paste(rep("?", length(cols)), collapse = ",")
  dbExecute(con, sprintf("INSERT OR REPLACE INTO %s (%s) VALUES (%s)",
                         tbl, paste(cols, collapse = ","), ph),
            params = unname(as.list(df)))
}
common <- c("dea_calendar_year","n_pixels_valid","n_pixels_nodata","area_ha",
            "dea_ctv_pct","dea_ntv_pct","dea_ns_pct","dea_water_pct","dea_nav_pct","dea_as_pct",
            "suspect_year_flag","suspect_reason","support_level","source_product_id","run_id")
dbBegin(con)
writetab("fact_dea_landcover_zone_year",      zone_df, c("zone_fid", common))
writetab("fact_dea_landcover_plot_year",      plot_df, c("plot_id", common))
writetab("fact_dea_landcover_community_year", comm_df, c("community", common))
writetab("fact_dea_landcover_farm_year",      farm_df, common)
dbCommit(con)
for (t in c("fact_dea_landcover_zone_year","fact_dea_landcover_plot_year",
            "fact_dea_landcover_community_year","fact_dea_landcover_farm_year"))
  cat(sprintf("  %s rows: %d\n", t, dbGetQuery(con, sprintf("SELECT COUNT(*) n FROM %s", t))$n))
dbDisconnect(con)
cat("[execute] Gate B fact tables written.\n")
