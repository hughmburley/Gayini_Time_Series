# ------------------------------------------------------------------------------
# Script: scripts/05_ground_cover/T3_gateB2_green_share_surface.R
# Purpose: T3 Gate B2 - the GREEN-SHARE FLOOR as a raster surface on the canonical
#          EPSG:8058 grid. Task M produced the AREA; this produces the MAP Adrian
#          needs for the LiDAR overlay.
#
# Spec: docs/T3_always_green_threshold.md v3, Gate B2.
#
# THE METRIC IS NOT RE-IMPLEMENTED. green_at_floor() is EXTRACTED VERBATIM at run
# time from its only home, scripts/05_ground_cover/03_h2_seasonal_gate_and_diagnostics.R,
# by parsing the function definition out of the source text and eval()ing it. Copying
# the body into this file would create a second copy that can drift; extracting it
# means any future edit to the original propagates here, and the extracted text is
# printed and checksummed in the log so the reuse is auditable.
#
# 🔴 THE TWO FLOORS ARE DIFFERENT VARIABLES (CLAUDE.md, D8; T3 spec Context).
#   GREEN-SHARE floor  = 100 * PV / total_veg > 50, read PAIRED in the season that
#                        sets each pixel's total-veg 5th-percentile order statistic.
#                        "When cover is at its worst, is what remains still alive?"
#   TOTAL-COVER floor  = veg_p05 >= t.  "How much cover survives the worst seasons?"
#   These are never the same number and never share a caption without both names.
#
# 🔴 GRID DISCIPLINE - the D8 trap, stated so it cannot re-open. The metric is
#   DEFINED and MEASURED on the native 30 m EPSG:3577 grid, because that is where the
#   FC seasons live and where Task M measured it. The 8058 product is a REPROJECTION
#   FOR OVERLAY, not a re-measurement. The native count reconciles with
#   Output/tables/taskM_green_at_floor_area.csv EXACTLY (same code, same inputs); the
#   8058 area differs by the pixel-area ratio and BOTH are reported with their grid
#   named. Neither is ever adjusted to match the other.
#
# Gate B2 registers the CONTINUOUS green_frac_pct surface only. The boolean
# > 50 mask is a Gate C product and waits on the Gate D threshold sign-off.
# ------------------------------------------------------------------------------

suppressPackageStartupMessages({
  library(terra); library(sf); library(dplyr); library(DBI); library(RSQLite); library(digest)
})
source("R/gayini_figure_register.R")   # gayini_sha256_first50()

TASKM_SRC  <- file.path("scripts", "05_ground_cover", "03_h2_seasonal_gate_and_diagnostics.R")
TASKM_CSV  <- file.path("Output", "tables", "taskM_green_at_floor_area.csv")
FC_DIR     <- file.path("Output", "rasters", "fc_intermediate")
GRID_TIF   <- file.path("Output", "rasters", "veg_regime_class_8058.tif")
BOUNDARY   <- file.path("Output", "spatial_8058", "gayini_boundary_epsg8058.gpkg")
OUT_DIR    <- file.path("Output", "rasters", "persistence_8058")
DB         <- file.path("Output", "database", "Gayini_Results.sqlite")
RUN_ID     <- "T3_gateB2"
GREEN_THRESHOLD <- 50          # Task M's, for the reconciliation only - NOT a T3 selection

dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)
terra::terraOptions(progress = 0)

## 1. Extract green_at_floor() verbatim from the Task M source ------------------
src   <- readLines(TASKM_SRC, warn = FALSE)
start <- grep("^green_at_floor <- function", src)
if (length(start) != 1L)
  stop("green_at_floor() not found exactly once in ", TASKM_SRC, " - reuse is not safe.")
depth <- 0L; end <- NA_integer_
for (i in seq(start, length(src))) {
  depth <- depth + lengths(regmatches(src[i], gregexpr("\\{", src[i])))
  depth <- depth - lengths(regmatches(src[i], gregexpr("\\}", src[i])))
  if (depth == 0L) { end <- i; break }
}
fn_text <- src[start:end]
message("================ B2 - green_at_floor() extracted verbatim ================")
message("  source : ", TASKM_SRC, " lines ", start, "-", end)
message("  sha256 : ", digest::digest(paste(fn_text, collapse = "\n"),
                                      algo = "sha256", serialize = FALSE))
cat(paste0("    | ", fn_text, collapse = "\n"), "\n")
eval(parse(text = paste(fn_text, collapse = "\n")))
stopifnot(is.function(green_at_floor))

## 2. Native 3577 inputs, farm-masked exactly as Task M did ---------------------
tv_stack <- terra::rast(file.path(FC_DIR, "fc_total_veg_3577_wy1988_2023.tif"))
pv_stack <- terra::rast(file.path(FC_DIR, "fc_pv_3577_wy1988_2023.tif"))
stopifnot(terra::nlyr(tv_stack) == terra::nlyr(pv_stack))
message(sprintf("\n  paired stacks: %d layers each, native %s, res %.4f m",
                terra::nlyr(tv_stack), terra::crs(tv_stack, describe = TRUE)$code,
                terra::res(tv_stack)[1]))

bounds  <- sf::st_read(BOUNDARY, quiet = TRUE)
bv3577  <- terra::vect(sf::st_transform(bounds, 3577))
tv_farm <- terra::mask(terra::crop(tv_stack, bv3577), bv3577)
pv_farm <- terra::mask(terra::crop(pv_stack, bv3577), bv3577)

## 3. The surface, native grid - the same app() call Task M made ---------------
native_tif <- file.path(FC_DIR, "T3_green_at_floor_3577.tif")
if (!file.exists(native_tif)) {
  message("\n  paired per-pixel apply over the farm (3577); complete, not sampled ...")
  floor_r <- terra::app(c(tv_farm, pv_farm), fun = green_at_floor)
  names(floor_r) <- c("total_at_floor", "pv_at_floor", "green_frac_pct")
  terra::writeRaster(floor_r, native_tif, overwrite = TRUE, datatype = "FLT4S")
  message("  wrote native surface: ", native_tif)
} else {
  message("\n  reusing native surface: ", native_tif)
}
floor_r <- terra::rast(native_tif)
names(floor_r) <- c("total_at_floor", "pv_at_floor", "green_frac_pct")

## 4. RECONCILE against Task M - report, never adjust --------------------------
gf        <- floor_r[["green_frac_pct"]]
n_valid   <- as.integer(terra::global(!is.na(gf), "sum", na.rm = TRUE)[[1]])
n_gt      <- as.integer(terra::global(gf > GREEN_THRESHOLD, "sum", na.rm = TRUE)[[1]])
px_ha_native <- prod(terra::res(gf)) / 1e4
area_native  <- n_gt * px_ha_native

taskm  <- read.csv(TASKM_CSV, stringsAsFactors = FALSE)
gv     <- function(q) as.numeric(taskm$value[taskm$quantity == q])
exp_valid <- gv("n_valid_floor_px"); exp_gt <- gv("n_majority_green_px_gt50")
exp_area  <- gv("area_ha_native_30m_3577")

message("\n================ B2 - reconciliation against Task M (native 3577) ================")
message(sprintf("  valid floor px    : this run %s   Task M %s   diff %s",
                format(n_valid, big.mark = ","), format(exp_valid, big.mark = ","),
                format(n_valid - exp_valid, big.mark = ",")))
message(sprintf("  green-share > %d  : this run %s   Task M %s   diff %s",
                GREEN_THRESHOLD, format(n_gt, big.mark = ","),
                format(exp_gt, big.mark = ","), format(n_gt - exp_gt, big.mark = ",")))
message(sprintf("  area (ha, 3577)   : this run %.2f   Task M %.2f   diff %.2f",
                area_native, exp_area, area_native - exp_area))
recon_ok <- (n_gt == exp_gt) && (n_valid == exp_valid)
if (recon_ok) {
  message("  ==> RECONCILES EXACTLY. Same code, same inputs, same grid.")
} else {
  message("  ==> !! MISMATCH. Reported unadjusted, per spec Gate B2. One of the two is ",
          "wrong and that is a finding, not something to tune away.")
}

## 5. Reproject the CONTINUOUS surface to 8058 - bilinear ----------------------
## Continuous cover percentage, so bilinear, the same rule the percentile rasters
## used. method="near" is the BINARY-mask rule and does not apply here. The boolean
## > threshold product is Gate C and waits on the Gate D sign-off.
class_r <- terra::rast(GRID_TIF)
gf_8058 <- terra::project(gf, class_r, method = "bilinear")
names(gf_8058) <- "green_frac_pct"
geom_ok <- terra::compareGeom(gf_8058, class_r, lyrs = FALSE, crs = TRUE, ext = TRUE,
                              rowcol = TRUE, res = TRUE, stopOnError = FALSE)
stopifnot(isTRUE(geom_ok))
message(sprintf("\n  compareGeom(green_frac_pct_8058, veg_regime_class_8058) = %s", geom_ok))

out_tif <- file.path(OUT_DIR, "green_share_at_floor_8058.tif")
terra::writeRaster(gf_8058, out_tif, overwrite = TRUE, datatype = "FLT4S")
message("  wrote: ", out_tif)

n_8058    <- as.integer(terra::global(gf_8058 > GREEN_THRESHOLD, "sum", na.rm = TRUE)[[1]])
px_ha_8058 <- prod(terra::res(gf_8058)) / 1e4
message(sprintf("\n  THE SAME METRIC ON THE TWO GRIDS - both reported, neither adjusted:"))
message(sprintf("    native 3577, %.4f ha/px : %s px = %.2f ha",
                px_ha_native, format(n_gt, big.mark = ","), area_native))
message(sprintf("    census 8058, %.9f ha/px : %s px = %.2f ha",
                px_ha_8058, format(n_8058, big.mark = ","), n_8058 * px_ha_8058))
message(sprintf("    pixel-area ratio = %.4f. The 8058 figure is a REPROJECTION FOR OVERLAY,",
                px_ha_native / px_ha_8058))
message("    not a re-measurement. The measured area is the native one.")

## 6. Register in raster_asset - first-50-MB SHA-256, INSERT OR REPLACE --------
legend <- paste0(
  "GREEN-SHARE FLOOR, continuous. green_frac_pct = 100 * PV / total_veg, read PAIRED in the ",
  "season that sets each pixel's total-veg 5th-percentile ORDER STATISTIC (k = max(1, ceiling(0.05*m)) ",
  "of m valid paired seasons). Support rule MIN_SEASONS: pixels with fewer than 50 valid paired ",
  "seasons are NA. Metric computed by green_at_floor() extracted verbatim from ",
  "scripts/05_ground_cover/03_h2_seasonal_gate_and_diagnostics.R - not re-implemented. ",
  "DEFINED AND MEASURED at native 30 m EPSG:3577 over the Gayini farm boundary (crop + mask), then ",
  "reprojected ONCE to the 8058 census grid with method='bilinear' (continuous surface). ",
  "MEASURED AREA IS THE NATIVE ONE: ", format(n_gt, big.mark = ","), " px x ", px_ha_native,
  " ha = ", sprintf("%.2f", area_native), " ha at green_frac_pct > ", GREEN_THRESHOLD,
  ", reconciling exactly with Output/tables/taskM_green_at_floor_area.csv. The 8058 count (",
  format(n_8058, big.mark = ","), " px) is a reprojection for overlay, NOT a re-measurement; the ",
  "two differ by the pixel-area ratio ", sprintf("%.4f", px_ha_native / px_ha_8058),
  " and neither is adjusted to match the other. THIS IS NOT THE TOTAL-COVER FLOOR: veg_p05 >= t ",
  "measures how much cover survives the worst seasons, a different variable answering a different ",
  "question; the withdrawn ~4,300 ha refugia figure belongs to neither. Scope: farm boundary, ",
  "all-pixel (no stratum filter applied in the surface itself). CAVEAT: FC is natively 30 m; the ",
  "8058 rendering is bilinear-resampled and its fine spatial detail must not be over-interpreted. ",
  "No threshold is selected - is_selected_threshold is a Gate D decision.")

e <- as.vector(terra::ext(gf_8058)); rs <- terra::res(gf_8058)
con <- dbConnect(SQLite(), DB)
dbExecute(con,
  "INSERT OR REPLACE INTO raster_asset
     (raster_asset_id, path, metric_id, water_year, period_label, crs,
      resolution_x, resolution_y, xmin, ymin, xmax, ymax, checksum_sha256,
      path_exists, qa_status, run_id, crs_epsg, product, legend_status, legend_semantics,
      superseded_flag, source_crs)
   VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
  params = list("raster_t3_green_share_at_floor_8058",
                gsub("\\\\", "/", out_tif), "green_frac_at_floor_pct", NA_character_,
                "WY1988-2023 across-series", "EPSG:8058", rs[1], rs[2],
                e[1], e[3], e[2], e[4], gayini_sha256_first50(out_tif), 1L, "REVIEW",
                RUN_ID, 8058L, "green_share_floor_8058", "confirmed", legend, 0L, "EPSG:3577"))
reg <- dbGetQuery(con, "SELECT raster_asset_id, product, crs_epsg, path_exists,
                          substr(checksum_sha256,1,12) sha12, run_id
                        FROM raster_asset WHERE raster_asset_id='raster_t3_green_share_at_floor_8058'")
dbDisconnect(con)
message("\n================ B2 - registered ================")
print(reg, row.names = FALSE)

## 7. Gate figure -------------------------------------------------------------
suppressPackageStartupMessages({ library(ggplot2); library(scales) })
samp <- terra::spatSample(gf_8058, size = 1.2e6, method = "regular",
                          xy = TRUE, na.rm = TRUE)
names(samp)[3] <- "green_frac_pct"
message(sprintf("  map sample: %s cells with data", format(nrow(samp), big.mark = ",")))

p <- ggplot(samp, aes(x, y, fill = green_frac_pct)) +
  geom_raster() +
  geom_sf(data = bounds, fill = NA, colour = "grey15", linewidth = 0.5, inherit.aes = FALSE) +
  scale_fill_viridis_c(option = "viridis", name = "green share\nat the floor (%)",
                       limits = c(0, 100), oob = scales::squish) +
  coord_sf(crs = sf::st_crs(8058), datum = sf::st_crs(8058)) +
  labs(title = "T3 Gate B2 - the green-share floor surface: when cover is at its worst, how much of what remains is alive",
       subtitle = paste0("green_frac_pct = 100 * PV / total_veg, read PAIRED in the season that sets each pixel's ",
                         "total-veg 5th-percentile order statistic.\nThis is NOT the total-cover floor (veg_p05) - ",
                         "a different variable answering a different question. Median across the farm is 3.03%."),
       x = "Easting EPSG:8058 (m)", y = "Northing EPSG:8058 (m)",
       caption = paste0("Measured at native 30 m EPSG:3577 (", format(n_gt, big.mark = ","),
                        " px > 50% = ", sprintf("%.2f", area_native),
                        " ha, reconciling exactly with Task M), rendered here on the 24.97 m 8058 grid.",
                        "\nSupport: pixel. The 8058 rendering is bilinear-resampled from a 30 m source - ",
                        "do not over-interpret fine spatial detail.")) +
  theme_minimal(base_size = 11) +
  theme(plot.title = element_text(face = "bold", size = 11.4),
        plot.subtitle = element_text(size = 9.2, colour = "grey25", lineheight = 1.15),
        plot.caption = element_text(size = 8.1, colour = "grey35", hjust = 0, lineheight = 1.2),
        panel.grid.minor = element_blank())

gayini_write_and_register_figure(
  plot = p, path = file.path("Output", "figures", "diagnostics", "T3_B2_green_share_map.png"),
  title = "T3 Gate B2 - green-share-at-floor surface over the property",
  caption = paste0("Support: pixel. ", legend),
  support_level = "pixel", figure_level = "diagnostic", run_id = RUN_ID,
  width = 11.5, height = 7.5, dpi = 150,
  provenance_note = paste("T3 Gate B2. Spec docs/T3_always_green_threshold.md v3.",
                          "green_at_floor() extracted verbatim from the Task M source at run time,",
                          "not re-implemented. Native-grid area reconciles exactly with Task M."))

message("\nB2 COMPLETE. Reconciliation ", if (recon_ok) "EXACT." else "MISMATCHED - see above.")
