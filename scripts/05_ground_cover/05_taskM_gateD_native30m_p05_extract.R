# ------------------------------------------------------------------------------
# Script: scripts/05_ground_cover/05_taskM_gateD_native30m_p05_extract.R
# Purpose: Tier 2 · Task M · Gate D §D.2 (Grid 2) — extract the FLOOR percentile
#          (veg_p05) from the NATIVE 30 m FC product, under the focus mask, one
#          row per focus cell. The distribution statistics are computed downstream
#          (taskM_gateD_p05_distribution.py) so Grid 1 (census 24.97 m) and Grid 2
#          (native 30 m) go through one identical stats engine.
#
#          The census is NOT resampled to fake a 30 m answer (spec §D.2). The p05
#          values are the native-grid product total_veg_percentiles_3577.tif; only
#          the focus MASK is carried onto that grid, by nearest-neighbour so class
#          codes are not blended.
#
# Run mode: analysis (read-only inputs) · writes ONE new file · no DB mutation
# Key inputs (read-only):
#   - Output/rasters/fc_intermediate/total_veg_percentiles_3577.tif (5 lyr; p05 first)
#   - Output/rasters/veg_regime_class_8058.tif  (focus mask source)
#   - Output/rasters/flood_zone_8058.tif        (flood-zone tabulation)
# Output:
#   - Output/tables/taskM_gateD_native30m_p05_cells.csv
# ------------------------------------------------------------------------------

FOCUS_CODES <- c(11L, 12L, 13L, 21L, 22L, 23L, 31L, 32L, 33L)  # non-treed focus strata
PIXEL_AREA_HA_30M <- 0.09

root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", getwd()), winslash = "/", mustWork = TRUE)
source(file.path(root_dir, "R", "gayini_output_helpers.R"))
suppressPackageStartupMessages(library(terra))
terra::terraOptions(progress = 0)

rasters_dir <- file.path(root_dir, "Output", "rasters")
OUT_CSV     <- file.path(root_dir, "Output", "tables", "taskM_gateD_native30m_p05_cells.csv")

native_tif <- file.path(rasters_dir, "fc_intermediate", "total_veg_percentiles_3577.tif")
stopifnot(file.exists(native_tif))

p05_native <- terra::rast(native_tif)[[1]]     # layer "p05"
stopifnot(names(p05_native)[1] == "p05")
message("[native] p05 grid: res ", paste(terra::res(p05_native), collapse = " x "),
        "  dims ", paste(dim(p05_native), collapse = " x "))

## Focus mask onto the native grid. Drop categories to raw integer codes first, then
## nearest-neighbour project so codes are carried, never blended.
class_r <- terra::rast(file.path(rasters_dir, "veg_regime_class_8058.tif"))
levels(class_r) <- NULL
terra::coltab(class_r) <- NULL
class_native <- terra::project(class_r, p05_native, method = "near")
names(class_native) <- "veg_regime_class"

fz_r <- terra::rast(file.path(rasters_dir, "flood_zone_8058.tif"))
levels(fz_r) <- NULL
terra::coltab(fz_r) <- NULL
fz_native <- terra::project(fz_r, p05_native, method = "near")
names(fz_native) <- "flood_zone"

## Assemble and keep only focus cells with a non-null p05.
stk <- c(p05_native, class_native, fz_native)
names(stk) <- c("p05", "veg_regime_class", "flood_zone")
v <- terra::values(stk)
code <- v[, "veg_regime_class"]
p05  <- v[, "p05"]
keep <- !is.na(p05) & !is.na(code) & (as.integer(round(code)) %in% FOCUS_CODES)

code_k <- as.integer(round(code[keep]))
community <- ifelse(code_k < 20L, "Aeolian Chenopod Shrublands",
             ifelse(code_k < 30L, "Riverine Chenopod Shrublands",
                                  "Inland Floodplain Shrublands / Swamps"))

out <- data.frame(
  veg_p05    = round(p05[keep], 6),
  community  = community,
  flood_zone = as.integer(round(v[keep, "flood_zone"])),
  stringsAsFactors = FALSE
)

message("[native] focus cells kept: ", nrow(out),
        "  (area ", round(nrow(out) * PIXEL_AREA_HA_30M, 1), " ha at 0.09 ha/px)")
gayini_write_csv(out, OUT_CSV)
message("Done. Per-cell native-30 m p05 written; statistics computed downstream.")
