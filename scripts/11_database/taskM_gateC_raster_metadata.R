# ------------------------------------------------------------------------------
# Script: scripts/11_database/taskM_gateC_raster_metadata.R
# Purpose: Tier 2 · Task M · Gate C — emit CRS / resolution / extent for the
#          rasters Gate C registers, so the Python registrar can populate
#          raster_asset's geometry columns without a GDAL binding.
#
#          Read-only. Writes one new CSV. Registers nothing itself.
#
# Workflow stage: 11_database · Tier 2 Task M, Gate C
# Key inputs:  Output/rasters/task_J/*.tif · Output/rasters/fc_intermediate/{fc_total_veg,fc_pv}_3577_wy1988_2023.tif
# Key output:  Output/tables/taskM_gateC_raster_meta.csv
# ------------------------------------------------------------------------------

root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", getwd()), winslash = "/", mustWork = TRUE)
source(file.path(root_dir, "R", "gayini_output_helpers.R"))
suppressPackageStartupMessages(library(terra))

rasters_dir <- file.path(root_dir, "Output", "rasters")
OUT_CSV     <- file.path(root_dir, "Output", "tables", "taskM_gateC_raster_meta.csv")

targets <- c(
  sort(list.files(file.path(rasters_dir, "task_J"), pattern = "\\.tif$", full.names = TRUE)),
  file.path(rasters_dir, "fc_intermediate", "fc_total_veg_3577_wy1988_2023.tif"),
  file.path(rasters_dir, "fc_intermediate", "fc_pv_3577_wy1988_2023.tif")
)
stopifnot(all(file.exists(targets)))
message("[meta] describing ", length(targets), " rasters ...")

## Some files carry no authority code on the PROJCRS node (terra returns code = NA).
## Where that happens, resolve the EPSG by comparing the proj4 definition against the
## candidate CRS itself, and record that the code was inferred rather than declared —
## never assume one. Four-CRS discipline is a live trap in this project.
CANDIDATES <- c(3577L, 8058L, 28355L, 9473L, 4326L)
proj_of <- function(x) terra::crs(x, proj = TRUE)

resolve_epsg <- function(r) {
  declared <- suppressWarnings(as.integer(terra::crs(r, describe = TRUE)$code))
  if (!is.na(declared)) return(list(epsg = declared, src = "authority_code"))
  p <- proj_of(r)
  for (cand in CANDIDATES) {
    if (identical(p, proj_of(terra::crs(paste0("EPSG:", cand))))) {
      return(list(epsg = cand, src = "inferred_from_proj4_parameters"))
    }
  }
  list(epsg = NA_integer_, src = "unresolved")
}

rows <- lapply(targets, function(p) {
  r <- terra::rast(p)
  e <- terra::ext(r)
  res <- resolve_epsg(r)
  data.frame(
    path            = sub(paste0("^", root_dir, "/"), "", normalizePath(p, winslash = "/")),
    n_layers        = terra::nlyr(r),
    crs             = terra::crs(r, proj = TRUE),
    crs_epsg        = res$epsg,
    crs_epsg_source = res$src,
    resolution_x = terra::res(r)[1],
    resolution_y = terra::res(r)[2],
    xmin = e$xmin, ymin = e$ymin, xmax = e$xmax, ymax = e$ymax,
    stringsAsFactors = FALSE
  )
})

out <- do.call(rbind, rows)
print(out[, c("path", "n_layers", "crs_epsg", "resolution_x")], row.names = FALSE)
gayini_write_csv(out, OUT_CSV)
