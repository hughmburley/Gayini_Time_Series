# ------------------------------------------------------------------------------
# Script: scripts/05_ground_cover/06_taskM_gateD_p05_ge80_contiguity.R
# Purpose: Tier 2 · Task M · Gate D §D.3 — connected-component (contiguity)
#          report for veg_p05 >= 80 over the focus census pixels.
#
#   The threshold 80 was chosen by the human PURELY to make the existing
#   4,179.3 ha figure checkable. It carries NO ecological meaning and is NOT a
#   class. This script reports contiguity as measured; it draws no conclusion
#   about whether the high-floor pixels form coherent patches. That is the
#   human's question, not CC's.
#
# Run mode: analysis (read-only inputs) · writes ONE new file (+ a docs/ copy)
# Key inputs (read-only, EPSG:8058 census grid):
#   - Output/rasters/veg_percentiles_8058/total_veg_p05_8058.tif
#   - Output/rasters/veg_regime_class_8058.tif   (focus mask + community)
#   - Output/rasters/flood_zone_8058.tif         (flood-zone crosstab)
# Output:
#   - Output/tables/taskM_gateD_p05_ge80_contiguity.csv           (authoritative)
#   - docs/change_reports/taskM_gateD_p05_ge80_contiguity.csv     (spec-named copy)
# ------------------------------------------------------------------------------

THRESHOLD     <- 80
FOCUS_CODES   <- c(11L, 12L, 13L, 21L, 22L, 23L, 31L, 32L, 33L)
PIXEL_AREA_HA <- 0.0623512   # EPSG:8058 census pixel (§1.3)

root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", getwd()), winslash = "/", mustWork = TRUE)
source(file.path(root_dir, "R", "gayini_output_helpers.R"))
suppressPackageStartupMessages({ library(terra); library(dplyr) })
terra::terraOptions(progress = 0)

rasters_dir <- file.path(root_dir, "Output", "rasters")
OUT_MAIN <- file.path(root_dir, "Output", "tables", "taskM_gateD_p05_ge80_contiguity.csv")
OUT_DOCS <- file.path(root_dir, "docs", "change_reports", "taskM_gateD_p05_ge80_contiguity.csv")

p05 <- terra::rast(file.path(rasters_dir, "veg_percentiles_8058", "total_veg_p05_8058.tif"))
cls <- terra::rast(file.path(rasters_dir, "veg_regime_class_8058.tif"))
levels(cls) <- NULL; terra::coltab(cls) <- NULL
fz  <- terra::rast(file.path(rasters_dir, "flood_zone_8058.tif"))
levels(fz) <- NULL; terra::coltab(fz) <- NULL
stopifnot(isTRUE(terra::compareGeom(p05, cls, stopOnError = FALSE)),
          isTRUE(terra::compareGeom(p05, fz, stopOnError = FALSE)))

## Focus mask: class in the nine non-treed focus strata.
cls_v   <- as.integer(round(terra::values(cls)[, 1]))
focus_m <- cls_v %in% FOCUS_CODES

## Binary surface: 1 where focus AND p05 >= threshold, else NA (so patches() ignores it).
p05_v <- terra::values(p05)[, 1]
hit   <- focus_m & !is.na(p05_v) & (p05_v >= THRESHOLD)
bin   <- terra::rast(p05); terra::values(bin) <- ifelse(hit, 1L, NA_integer_)

n_hit <- sum(hit)
message("[D.3] focus pixels with p05 >= ", THRESHOLD, ": ", n_hit,
        "  (", round(n_hit * PIXEL_AREA_HA, 1), " ha)")

## 8-connectivity connected components.
pt <- terra::patches(bin, directions = 8, zeroAsNA = TRUE)
comp_id <- terra::values(pt)[, 1]
idx     <- which(!is.na(comp_id))
comp    <- comp_id[idx]
comm_code <- cls_v[idx]
community <- ifelse(comm_code < 20L, "Aeolian Chenopod Shrublands",
             ifelse(comm_code < 30L, "Riverine Chenopod Shrublands",
                                     "Inland Floodplain Shrublands / Swamps"))
zone <- as.integer(round(terra::values(fz)[, 1][idx]))

sizes <- as.integer(table(comp))                 # pixels per component
n_comp <- length(sizes)
total_ha <- n_hit * PIXEL_AREA_HA
message("[D.3] connected components (8-conn): ", n_comp)

rows <- list()
add <- function(section, key, ...) {
  rows[[length(rows) + 1L]] <<- tibble::tibble(section = section, group_key = key, ...)
}

## --- summary + size distribution ---
add("summary", "n_components", value = n_comp)
add("summary", "total_pixels", value = n_hit)
add("summary", "total_area_ha", value = round(total_ha, 2))
qs <- stats::quantile(sizes, c(0, 0.5, 0.9, 1), names = FALSE)
add("size_distribution_px", "min",    value = qs[1])
add("size_distribution_px", "median", value = qs[2])
add("size_distribution_px", "p90",    value = qs[3])
add("size_distribution_px", "max",    value = qs[4])
add("size_distribution_ha", "min",    value = round(qs[1] * PIXEL_AREA_HA, 4))
add("size_distribution_ha", "median", value = round(qs[2] * PIXEL_AREA_HA, 4))
add("size_distribution_ha", "p90",    value = round(qs[3] * PIXEL_AREA_HA, 4))
add("size_distribution_ha", "max",    value = round(qs[4] * PIXEL_AREA_HA, 2))

## --- largest 10 components and their share ---
ord <- order(sizes, decreasing = TRUE)
top <- head(ord, 10)
for (i in seq_along(top)) {
  sz <- sizes[top[i]]
  add("largest_components", paste0("rank_", i),
      component_pixels = sz,
      component_area_ha = round(sz * PIXEL_AREA_HA, 2),
      share_of_total_pct = round(100 * sz / n_hit, 3))
}
add("largest_components", "top10_combined",
    component_pixels = sum(sizes[top]),
    component_area_ha = round(sum(sizes[top]) * PIXEL_AREA_HA, 2),
    share_of_total_pct = round(100 * sum(sizes[top]) / n_hit, 3))

## --- cell-area crosstab by community and by flood_zone ---
ct_comm <- as.data.frame(table(community))
for (i in seq_len(nrow(ct_comm)))
  add("crosstab_by_community", as.character(ct_comm$community[i]),
      pixels = ct_comm$Freq[i],
      area_ha = round(ct_comm$Freq[i] * PIXEL_AREA_HA, 2),
      share_of_total_pct = round(100 * ct_comm$Freq[i] / n_hit, 3))

ct_zone <- as.data.frame(table(zone))
for (i in seq_len(nrow(ct_zone)))
  add("crosstab_by_flood_zone", as.character(ct_zone$zone[i]),
      pixels = ct_zone$Freq[i],
      area_ha = round(ct_zone$Freq[i] * PIXEL_AREA_HA, 2),
      share_of_total_pct = round(100 * ct_zone$Freq[i] / n_hit, 3))

## --- community x flood_zone joint crosstab ---
ct_joint <- as.data.frame(table(community, zone))
ct_joint <- ct_joint[ct_joint$Freq > 0, ]
for (i in seq_len(nrow(ct_joint)))
  add("crosstab_community_x_zone",
      paste0(ct_joint$community[i], " | zone_", ct_joint$zone[i]),
      pixels = ct_joint$Freq[i],
      area_ha = round(ct_joint$Freq[i] * PIXEL_AREA_HA, 2),
      share_of_total_pct = round(100 * ct_joint$Freq[i] / n_hit, 3))

out <- dplyr::bind_rows(rows)
out$threshold <- THRESHOLD
out$grid <- "census_24_97m"
out$pixel_area_ha <- PIXEL_AREA_HA
out$crs_epsg <- 8058L
out$source_artefact <- "Output/rasters/veg_percentiles_8058/total_veg_p05_8058.tif (focus mask: veg_regime_class_8058.tif)"
out <- out[, c("grid", "threshold", "pixel_area_ha", "crs_epsg", "source_artefact",
               "section", "group_key",
               setdiff(names(out), c("grid","threshold","pixel_area_ha","crs_epsg",
                                     "source_artefact","section","group_key")))]

gayini_write_csv(out, OUT_MAIN)
gayini_write_csv(out, OUT_DOCS)
message("[D.3] wrote ", OUT_MAIN, " and the docs/ copy. Contiguity reported as measured; ",
        "no interpretation offered - human review required.")
