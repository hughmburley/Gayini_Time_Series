#!/usr/bin/env Rscript
# T1 Gate A - Recon (READ-ONLY). Spec: docs/T1_zone_stratum_census_join.md v3.
# No DB writes. Reads the 8058 zone layer, the rasters (headers only), and the
# MODIS context CSV; emits recon CSVs to Output/tables/ and prints a summary.
#
# Covers Gate A steps 3 (geometry via terra + compareGeom), 4 (treatment),
# 5 (zone-identity margin test vs area_ha_computed), 6 (Area_MW vs computed).
# Steps 1, 2, 7 are done in Python (paths / parquet / land-use scan).

suppressPackageStartupMessages({
  library(sf); library(terra); library(dplyr)
})

root      <- normalizePath(".", winslash = "/")
gpkg      <- file.path(root, "Output/spatial_8058/management_zones_epsg8058.gpkg")
modis_csv <- file.path(root, "Output/csv/MODIS/modis_context_units_summary.csv")
out_dir   <- file.path(root, "Output/tables"); dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

grid_ref  <- file.path(root, "Output/rasters/veg_regime_class_8058.tif")
products  <- c(
  veg_regime_class_8058 = "Output/rasters/veg_regime_class_8058.tif",
  flood_zone_8058       = "Output/rasters/flood_zone_8058.tif",
  total_veg_p05_8058    = "Output/rasters/veg_percentiles_8058/total_veg_p05_8058.tif",
  total_veg_p10_8058    = "Output/rasters/veg_percentiles_8058/total_veg_p10_8058.tif",
  total_veg_p20_8058    = "Output/rasters/veg_percentiles_8058/total_veg_p20_8058.tif",
  total_veg_p30_8058    = "Output/rasters/veg_percentiles_8058/total_veg_p30_8058.tif",
  total_veg_p50_8058    = "Output/rasters/veg_percentiles_8058/total_veg_p50_8058.tif"
)

cat("======================================================================\n")
cat("T1 GATE A RECON (read-only)\n")
cat("======================================================================\n")

## ---- Step 4 + zone table: read 8058 gpkg -----------------------------------
z <- sf::st_read(gpkg, quiet = TRUE)
# sf reserves the gpkg `fid` primary key and drops it from attributes, so pull
# the fid<->ManagmentZ map straight from the gpkg (a SQLite file) and join on
# the unique paddock name.
gc  <- DBI::dbConnect(RSQLite::SQLite(), gpkg, flags = RSQLite::SQLITE_RO)
fidmap <- DBI::dbGetQuery(
  gc, "SELECT fid, ManagmentZ FROM management_zones_epsg8058")
DBI::dbDisconnect(gc)
stopifnot(!anyDuplicated(fidmap$ManagmentZ))
z$fid <- as.integer(fidmap$fid[match(as.character(z$ManagmentZ), fidmap$ManagmentZ)])
stopifnot(nrow(z) == 64L, "fid" %in% names(z), !anyNA(z$fid),
          !anyDuplicated(z$fid))
cat(sprintf("\n[4] Zone layer: %d features, CRS EPSG:%s\n",
            nrow(z), sf::st_crs(z)$epsg))

# defensive control-char strip incl. NUL (a no-op on this layer; protects the
# companion layer). [[:cntrl:]] covers \x00 without a nul string literal, which R forbids.
strip_nul <- function(x) if (is.character(x)) trimws(gsub("[[:cntrl:]]", "", x, useBytes = TRUE)) else x
z$ManagmentZ <- strip_nul(as.character(z$ManagmentZ))
z$Treatment  <- strip_nul(as.character(z$Treatment))
z$Plots      <- strip_nul(as.character(z$Plots))

cat("[4] Treatment distribution (after defensive strip):\n")
print(table(z$Treatment, useNA = "ifany"))
cat("[4] Any Treatment != 'No grazing' comparison works directly: ",
    sum(z$Treatment == "No grazing"), " No grazing, ",
    sum(z$Treatment == "14-day grazing"), " 14-day grazing\n", sep = "")
cat("[4] Plots distribution:\n"); print(table(z$Plots, useNA = "ifany"))

## ---- Step 6: area_ha_computed (8058 geometry) vs Area_MW --------------------
z$area_ha_computed <- as.numeric(sf::st_area(z)) / 1e4
zt <- sf::st_drop_geometry(z)
zt <- zt[order(zt$fid), ]
area_tab <- data.frame(
  fid              = zt$fid,
  zone_name        = zt$ManagmentZ,
  treatment        = zt$Treatment,
  plots            = zt$Plots,
  area_ha_source   = as.numeric(zt$Area_MW),
  area_ha_computed = round(zt$area_ha_computed, 4),
  area_ha_diff_pct = round(100 * (zt$area_ha_computed - as.numeric(zt$Area_MW)) / as.numeric(zt$Area_MW), 3)
)
write.csv(area_tab, file.path(out_dir, "T1_gateA_zone_areas.csv"), row.names = FALSE)
cat(sprintf("\n[6] Area_MW vs area_ha_computed: diff_pct min=%.2f median=%.2f max=%.2f\n",
            min(area_tab$area_ha_diff_pct), median(area_tab$area_ha_diff_pct), max(area_tab$area_ha_diff_pct)))
cat(sprintf("[6] Sum area_ha_computed = %.2f ha ; Sum Area_MW = %.2f ha\n",
            sum(area_tab$area_ha_computed), sum(area_tab$area_ha_source)))

## ---- Step 5: zone-identity MARGIN test (vs area_ha_computed) ----------------
modis <- read.csv(modis_csv, stringsAsFactors = FALSE)
mz <- modis[grepl("^management_zone_", modis$unit_id), ]
mz$idx <- as.integer(sub("management_zone_", "", mz$unit_id))
mz <- mz[order(mz$idx), ]
stopifnot(nrow(mz) == 64L)

C <- setNames(area_tab$area_ha_computed, area_tab$fid)   # computed area by fid
rows <- lapply(mz$idx, function(i) {
  Mi <- mz$area_ha[mz$idx == i]
  err <- abs(C - Mi) / Mi * 100                          # % error to every fid
  err_assumed <- err[as.character(i)]
  others <- err[names(err) != as.character(i)]
  comp_err <- min(others)
  comp_fid <- as.integer(names(others)[which.min(others)])
  nearest_fid <- as.integer(names(err)[which.min(err)])
  data.frame(
    modis_idx = i, modis_area_ha = round(Mi, 2),
    assumed_fid = i, assumed_area_ha = round(C[as.character(i)], 2),
    err_assumed_pct = round(err_assumed, 3),
    nearest_fid = nearest_fid,
    competitor_fid = comp_fid, competitor_err_pct = round(comp_err, 3),
    margin_pp = round(comp_err - err_assumed, 3),
    assumed_is_nearest = (nearest_fid == i)
  )
})
mtab <- do.call(rbind, rows)
# proved: assumed partner is the unique nearest AND competitor is clear by >= 2 pp
mtab$proved <- mtab$assumed_is_nearest & (mtab$margin_pp >= 2)
mtab$flag_within_2pct <- mtab$competitor_err_pct < 2   # a competitor sitting within 2%
write.csv(mtab, file.path(out_dir, "T1_gateA_identity_margin.csv"), row.names = FALSE)

cat("\n[5] ZONE-IDENTITY MARGIN TEST (area_ha_computed vs MODIS area_ha)\n")
cat(sprintf("    proved (assumed is unique nearest, margin >= 2pp): %d / 64\n", sum(mtab$proved)))
cat(sprintf("    assumed partner NOT the nearest match           : %d\n", sum(!mtab$assumed_is_nearest)))
cat(sprintf("    err_assumed_pct : min=%.2f median=%.2f max=%.2f\n",
            min(mtab$err_assumed_pct), median(mtab$err_assumed_pct), max(mtab$err_assumed_pct)))
cat(sprintf("    margin_pp       : min=%.2f median=%.2f max=%.2f\n",
            min(mtab$margin_pp), median(mtab$margin_pp), max(mtab$margin_pp)))
amb <- mtab[!mtab$proved, ]
if (nrow(amb)) {
  cat("    UNPROVED / ambiguous zones (assumed not nearest, or margin < 2pp):\n")
  print(amb[, c("modis_idx","assumed_fid","err_assumed_pct","nearest_fid",
                "competitor_fid","competitor_err_pct","margin_pp","assumed_is_nearest")],
        row.names = FALSE)
} else {
  cat("    All 64 zones proved by a clear (>=2pp) margin.\n")
}

## ---- Step 3: raster geometry (headers) + compareGeom -----------------------
cat("\n[3] Raster geometry (terra headers) + compareGeom vs veg_regime_class_8058\n")
ref <- terra::rast(grid_ref)
geom_rows <- lapply(names(products), function(nm) {
  r <- terra::rast(file.path(root, products[[nm]]))
  e <- as.vector(terra::ext(r)); rs <- terra::res(r)
  cg <- tryCatch(
    terra::compareGeom(ref, r, crs = TRUE, ext = TRUE, rowcol = TRUE, res = TRUE,
                       stopOnError = FALSE, messages = FALSE),
    error = function(err) FALSE)
  data.frame(
    raster = nm,
    crs_epsg = terra::crs(r, describe = TRUE)$code,
    res_x = round(rs[1], 6), res_y = round(rs[2], 6),
    xmin = e["xmin"], ymin = e["ymin"], xmax = e["xmax"], ymax = e["ymax"],
    nrow = terra::nrow(r), ncol = terra::ncol(r),
    compareGeom_vs_ref = cg
  )
})
gtab <- do.call(rbind, geom_rows)
rownames(gtab) <- NULL
write.csv(gtab, file.path(out_dir, "T1_gateA_raster_geom.csv"), row.names = FALSE)
print(gtab[, c("raster","crs_epsg","res_x","xmin","ymin","nrow","ncol","compareGeom_vs_ref")], row.names = FALSE)
cat(sprintf("\n[3] compareGeom TRUE for %d / %d 8058 products.\n",
            sum(gtab$compareGeom_vs_ref), nrow(gtab)))

## ---- cross-check stored raster_asset extents vs headers --------------------
db <- file.path(root, "Output/database/Gayini_Results.sqlite")
con <- DBI::dbConnect(RSQLite::SQLite(), db, flags = RSQLite::SQLITE_RO)
stored <- DBI::dbGetQuery(con, "SELECT raster_asset_id, path, xmin, ymin, xmax, ymax FROM raster_asset WHERE crs_epsg=8058")
DBI::dbDisconnect(con)
ref_e <- as.vector(terra::ext(ref))
vr <- stored[grepl("veg_regime_class_8058", stored$path), ]
if (nrow(vr)) {
  cat(sprintf("[3] Stored extent (veg_regime_class_8058) vs header: dxmin=%.4f dxmax=%.4f (0 = match)\n",
              vr$xmin[1] - ref_e["xmin"], vr$xmax[1] - ref_e["xmax"]))
}
cat(sprintf("[3] raster_asset 8058 rows with NULL extent needing backfill: %d (0 => backfill is a no-op)\n",
            sum(is.na(stored$xmin) | is.na(stored$xmax))))

## ---- Step 3b: compareGeom across ALL 18 crs_epsg=8058 rasters --------------
## Cheap extra for T2's Gate A: total_veg_annual_8058 (2), task_J_difference_pp
## (6), veg_wet_response_8058 (1) beyond T1's 7 census products.
con2 <- DBI::dbConnect(RSQLite::SQLite(), db, flags = RSQLite::SQLITE_RO)
r8058 <- DBI::dbGetQuery(
  con2, "SELECT raster_asset_id, path, product FROM raster_asset WHERE crs_epsg=8058 ORDER BY product, raster_asset_id")
DBI::dbDisconnect(con2)
all_rows <- lapply(seq_len(nrow(r8058)), function(k) {
  r <- terra::rast(file.path(root, r8058$path[k]))
  cg <- tryCatch(
    terra::compareGeom(ref, r, crs = TRUE, ext = TRUE, rowcol = TRUE, res = TRUE,
                       stopOnError = FALSE, messages = FALSE),
    error = function(e) FALSE)
  data.frame(raster_asset_id = r8058$raster_asset_id[k], product = r8058$product[k],
             crs_epsg = terra::crs(r, describe = TRUE)$code,
             res_x = round(terra::res(r)[1], 6),
             nrow = terra::nrow(r), ncol = terra::ncol(r),
             compareGeom_vs_ref = cg)
})
atab <- do.call(rbind, all_rows); rownames(atab) <- NULL
write.csv(atab, file.path(out_dir, "T1_gateA_raster_geom_all18.csv"), row.names = FALSE)
cat(sprintf("\n[3b] compareGeom across ALL %d 8058 rasters vs veg_regime_class_8058: %d TRUE\n",
            nrow(atab), sum(atab$compareGeom_vs_ref)))
print(atab[, c("raster_asset_id","product","crs_epsg","res_x","nrow","ncol","compareGeom_vs_ref")],
      row.names = FALSE)
fails <- atab[!atab$compareGeom_vs_ref, ]
if (nrow(fails)) {
  cat("[3b] MISMATCHES (T2 must not inherit these as an assumption):\n"); print(fails, row.names = FALSE)
} else {
  cat("[3b] All 18 share the census grid exactly.\n")
}

cat("\n[done] recon CSVs -> Output/tables/T1_gateA_{zone_areas,identity_margin,raster_geom,raster_geom_all18}.csv\n")
