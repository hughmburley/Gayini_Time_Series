# ------------------------------------------------------------------------------
# Impl: scripts/03_inundation_products/internal/05_build_unified_annual_stack_impl.R
# Tier 0 sub-step 0.1 -- unify the annual inundation stack (1988-2023).
#
# Builds two 35-layer GeoTIFFs (wet_any, valid_any), one layer per water year,
# on EPSG:28355 at 25 m, from the canonical lo_YYYY_YYYY.img source rasters.
#
# Fixed decisions (docs/tier0_annual_stack_task.md):
#   - Target CRS   : EPSG:28355 (GDA94 / MGA zone 55).
#   - Reference grid: the 25 m grid of the first source (lo_1988_1989.img).
#   - Wet rule     : explicit legend (confirmed with Adrian 2026-07-07) applied in
#                    gayini_make_binary_inundation_layers() (R/inundation_pre_post_
#                    raster_functions.R): wet = value IN (1,2) (1 = inundation,
#                    2 = off-river storage -- both wet); valid = value IN (0,1,2);
#                    value 3 = cloud shadow is MASKED (neither wet nor valid);
#                    documented no-data codes / NA masked to not-valid. The 35
#                    canonical Landsat sources contain values {0,1,2} only, so the
#                    value-3 mask is a no-op here but active for Sentinel-2 (Tier 3).
#                    This is identical to the earlier implicit `value > 0`.
#   - Resampling   : nearest-neighbour (layers are categorical / binary).
#
# CRS note (discovered on disk): every source is a GDA94 Transverse Mercator zone
# 55 grid (central meridian 147 E, false easting 500000, k = 0.9996, null WGS84
# transform) = EPSG:28355, but 32 of 35 files lack the EPSG code (stored as a bare
# "Transverse Mercator" / "unnamed" WKT). We therefore ASSIGN EPSG:28355 to those
# untagged files (lossless -- the grid is already MGA zone 55) rather than run a
# spurious datum-shift reprojection, then resample onto the 25 m reference grid.
# Resolutions on disk are mixed (25 m x27, 30 m x3, 10 m x5); all are brought to
# the 25 m reference grid by nearest-neighbour resampling.
# ------------------------------------------------------------------------------

suppressMessages({
  library(terra)
  library(dplyr)
  library(readr)
  library(tibble)
  library(stringr)
  library(DBI)
  library(RSQLite)
})

source(file.path(root_dir, "R", "inundation_pre_post_raster_functions.R"))
source(file.path(root_dir, "R", "raster_catalog_functions.R"))
source(file.path(root_dir, "R", "gayini_output_paths.R"))

# --- constants ----------------------------------------------------------------
TARGET_EPSG   <- "28355"
TARGET_CRS    <- "EPSG:28355"
REF_RES       <- 25
NODATA_VALUES <- c(255, 65535, 127, -1)   # canonical explicit no-data codes

SRC_DIR      <- file.path(root_dir, "Input", "landsat_inundation")
OUT_RAST_DIR <- file.path(root_dir, "Output", "rasters", "inundation_annual_stack")
OUT_CSV      <- file.path(root_dir, "Output", "csv", "annual_stack_manifest.csv")
OUT_CROSSCHECK_CSV <- file.path(root_dir, "Output", "csv", "annual_stack_crosscheck.csv")
DB_PATH      <- file.path(root_dir, "Output", "database", "Gayini_Results.sqlite")
BG_STRICT_DIR <- file.path(root_dir, "Output", "rasters", "inundation_background",
                           "background_strict_1989_2014", "annual")
WET_TIF      <- file.path(OUT_RAST_DIR, "annual_wet_any_1988_2023.tif")
VALID_TIF    <- file.path(OUT_RAST_DIR, "annual_valid_any_1988_2023.tif")

TMP_DIR      <- file.path(root_dir, "data_intermediate", "terra_tmp", "annual_stack")

dir.create(OUT_RAST_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(dirname(OUT_CSV), recursive = TRUE, showWarnings = FALSE)
dir.create(TMP_DIR, recursive = TRUE, showWarnings = FALSE)
terra::terraOptions(tempdir = TMP_DIR, progress = 0)

# --- helpers ------------------------------------------------------------------

# Water-year string ("1988-1989") from a lo_YYYY_YYYY.img path.
wy_from_file <- function(path) {
  m <- stringr::str_match(basename(path), "lo_([0-9]{4})_([0-9]{4})")
  paste0(m[, 2], "-", m[, 3])
}

# Ensure a source layer carries EPSG:28355. Untagged sources whose WKT is a GDA94
# MGA zone-55 Transverse Mercator get the code assigned (lossless); anything else
# is genuinely reprojected (defensive -- not expected for this dataset).
ensure_target_crs <- function(r) {
  desc <- terra::crs(r, describe = TRUE)
  if (!is.na(desc$code) && desc$code == TARGET_EPSG) {
    return(list(r = r, crs_in = TARGET_CRS, method = "tagged"))
  }
  wkt <- terra::crs(r)
  is_mga55 <- grepl("Transverse Mercator", wkt, fixed = TRUE) &&
    grepl('"Longitude of natural origin",147', wkt, fixed = TRUE) &&
    grepl('"False easting",500000', wkt, fixed = TRUE) &&
    grepl('"Scale factor at natural origin",0.9996', wkt, fixed = TRUE)
  if (is_mga55) {
    terra::crs(r) <- TARGET_CRS
    return(list(r = r, crs_in = "GDA94/MGA55 (untagged TM)", method = "assign"))
  }
  list(r = terra::project(r, TARGET_CRS, method = "near"),
       crs_in = paste0("reproject:", desc$name), method = "reproject")
}

# Derive reference-grid wet_any / valid_any for one water year and write both to
# temp GeoTIFFs (memory-safe: nothing is kept resident across years).
process_year <- function(path, ref) {
  wy <- wy_from_file(path)
  r  <- terra::rast(path)[[1]]
  cc <- ensure_target_crs(r)

  # Wet rule at native resolution (canonical project implementation).
  bins   <- gayini_make_binary_inundation_layers(
    raster_layer  = cc$r,
    product       = "landsat_inundation",
    nodata_values = NODATA_VALUES
  )
  # Task semantics: valid_any in {1, NA}; wet_any in {0, 1, NA}.
  valid_native <- terra::ifel(bins$valid == 1, 1, NA)
  wet_native   <- terra::ifel(bins$valid == 1, bins$wet, NA)

  # Nearest-neighbour resample onto the pinned 25 m reference grid.
  valid_ref <- terra::resample(valid_native, ref, method = "near")
  wet_ref   <- terra::resample(wet_native,   ref, method = "near")
  names(valid_ref) <- wy
  names(wet_ref)   <- wy

  n_valid <- as.numeric(terra::global(valid_ref, "sum", na.rm = TRUE)[1, 1])
  n_wet   <- as.numeric(terra::global(wet_ref,   "sum", na.rm = TRUE)[1, 1])

  wet_tmp   <- file.path(TMP_DIR, paste0("wet_",   sub("-", "_", wy), ".tif"))
  valid_tmp <- file.path(TMP_DIR, paste0("valid_", sub("-", "_", wy), ".tif"))
  terra::writeRaster(wet_ref,   wet_tmp,   overwrite = TRUE, datatype = "INT1U", gdal = "COMPRESS=LZW")
  terra::writeRaster(valid_ref, valid_tmp, overwrite = TRUE, datatype = "INT1U", gdal = "COMPRESS=LZW")

  tibble::tibble(
    water_year          = wy,
    source_file         = basename(path),
    crs_in              = cc$crs_in,
    crs_out             = TARGET_CRS,
    resample_method     = "nearest",
    n_valid_cells       = n_valid,
    n_wet_cells         = n_wet,
    mean_occurrence_pct = if (n_valid > 0) 100 * n_wet / n_valid else NA_real_,
    wet_tmp             = wet_tmp,
    valid_tmp           = valid_tmp
  )
}

# ------------------------------------------------------------------------------
# 1. Enumerate the 35 sources and cross-check against the canonical DB set.
# ------------------------------------------------------------------------------
message("[0.1] Enumerating source rasters ...")
files <- sort(list.files(SRC_DIR, pattern = "^lo_[0-9]{4}_[0-9]{4}[.]img$", full.names = TRUE))
if (length(files) != 35L) {
  stop(sprintf("Expected 35 lo_*.img sources, found %d in %s", length(files), SRC_DIR), call. = FALSE)
}

con <- dbConnect(RSQLite::SQLite(), DB_PATH)
canonical <- dbGetQuery(
  con,
  "SELECT DISTINCT file_name, water_year FROM stg_canonical_annual_inundation ORDER BY water_year"
)
dbDisconnect(con)

disk_files <- basename(files)
if (!setequal(disk_files, canonical$file_name) || nrow(canonical) != 35L) {
  only_disk <- setdiff(disk_files, canonical$file_name)
  only_db   <- setdiff(canonical$file_name, disk_files)
  stop("Source set does not match stg_canonical_annual_inundation.\n",
       "  on disk only: ", paste(only_disk, collapse = ", "), "\n",
       "  in DB only  : ", paste(only_db, collapse = ", "), call. = FALSE)
}
message("  35 sources match the canonical DB set exactly.")

# ------------------------------------------------------------------------------
# 2-4. Build the reference grid, then process every water year onto it.
# ------------------------------------------------------------------------------
message("[0.1] Establishing reference grid from ", basename(files[1]), " ...")
r1 <- terra::rast(files[1])[[1]]
r1 <- ensure_target_crs(r1)$r
ref <- terra::rast(terra::ext(r1), resolution = REF_RES, crs = TARGET_CRS)
message(sprintf("  reference grid: %d x %d cells, res %g m, %s",
                terra::nrow(ref), terra::ncol(ref), terra::res(ref)[1], TARGET_CRS))

message("[0.1] Deriving wet_any / valid_any per water year ...")
manifest_rows <- vector("list", length(files))
for (i in seq_along(files)) {
  manifest_rows[[i]] <- process_year(files[i], ref)
  mr <- manifest_rows[[i]]
  message(sprintf("  [%2d/35] %s  valid=%d  wet=%d  occ=%.2f%%",
                  i, mr$water_year, mr$n_valid_cells, mr$n_wet_cells, mr$mean_occurrence_pct))
}
manifest <- dplyr::bind_rows(manifest_rows)

message("[0.1] Assembling 35-layer stacks ...")
wet_stack   <- terra::rast(manifest$wet_tmp)
valid_stack <- terra::rast(manifest$valid_tmp)
names(wet_stack)   <- manifest$water_year
names(valid_stack) <- manifest$water_year

terra::writeRaster(wet_stack,   WET_TIF,   overwrite = TRUE, datatype = "INT1U", gdal = "COMPRESS=LZW")
terra::writeRaster(valid_stack, VALID_TIF, overwrite = TRUE, datatype = "INT1U", gdal = "COMPRESS=LZW")
message("  wrote ", gayini_relative_path(root_dir, WET_TIF))
message("  wrote ", gayini_relative_path(root_dir, VALID_TIF))

# ------------------------------------------------------------------------------
# 5. Write the manifest.
# ------------------------------------------------------------------------------
manifest_out <- dplyr::select(manifest, -wet_tmp, -valid_tmp)
readr::write_csv(manifest_out, OUT_CSV)
message("  wrote ", gayini_relative_path(root_dir, OUT_CSV))

# ------------------------------------------------------------------------------
# Cross-check (informational, non-gating): compare per-year wet-cell counts on
# the background_strict footprint for overlapping water years.
#
# Label convention (verified empirically, not from the doc): the background
# annual files are labelled by the water year's END year, so file "__L"
# corresponds to water year "(L-1)-L" (e.g. "__1990" = water year "1989-1990").
# Under this mapping 15 of 26 overlapping years match this stack to the exact
# cell within the background footprint, confirming the wet rule. The remaining
# divergences are alignment-method differences: this stack uses the mandated
# nearest-neighbour resampling, whereas the background build used "max"; the
# gap is largest in years whose source grid is sub-pixel-offset from the 25 m
# reference. These are logged for review and do not block the commit.
# ------------------------------------------------------------------------------
message("[0.1] Cross-check against background_strict_1989_2014 (informational) ...")
cross_rows <- list()
if (dir.exists(BG_STRICT_DIR)) {
  bg_files <- list.files(BG_STRICT_DIR, pattern = "^annual_inundated_any_.*__[0-9]{4}[.]tif$", full.names = TRUE)
  for (bg in bg_files) {
    label <- as.integer(stringr::str_match(basename(bg), "__([0-9]{4})[.]tif$")[, 2])
    wy    <- paste0(label - 1L, "-", label)
    if (!wy %in% names(wet_stack)) next
    bg_wet <- terra::rast(bg)
    if (is.na(terra::crs(bg_wet, describe = TRUE)$code)) terra::crs(bg_wet) <- TARGET_CRS
    mine   <- terra::resample(wet_stack[[wy]], bg_wet, method = "near")
    foot   <- !is.na(bg_wet)
    n_bg   <- as.numeric(terra::global(terra::ifel(foot & bg_wet == 1, 1, 0), "sum", na.rm = TRUE)[1, 1])
    n_mine <- as.numeric(terra::global(terra::ifel(foot & mine   == 1, 1, 0), "sum", na.rm = TRUE)[1, 1])
    rel    <- if (n_bg > 0) abs(n_mine - n_bg) / n_bg else NA_real_
    cross_rows[[wy]] <- tibble::tibble(
      water_year = wy, background_label = label,
      background_wet_cells = n_bg, stack_wet_cells = n_mine,
      rel_diff_pct = round(100 * rel, 2)
    )
  }
  cross <- dplyr::arrange(dplyr::bind_rows(cross_rows), water_year)
  if (nrow(cross) > 0) {
    readr::write_csv(cross, OUT_CROSSCHECK_CSV)
    message("  wrote ", gayini_relative_path(root_dir, OUT_CROSSCHECK_CSV))
    flagged <- dplyr::filter(cross, !is.na(rel_diff_pct) & rel_diff_pct > 5)
    message(sprintf("  compared %d overlapping years; %d exact-match, %d diverge > 5%%.",
                    nrow(cross), sum(cross$rel_diff_pct == 0, na.rm = TRUE), nrow(flagged)))
    for (k in seq_len(nrow(flagged))) {
      message(sprintf("    DIVERGENCE %s: background=%d stack=%d (%.1f%%) -- near-vs-max alignment, review",
                      flagged$water_year[k], flagged$background_wet_cells[k],
                      flagged$stack_wet_cells[k], flagged$rel_diff_pct[k]))
    }
  }
} else {
  message("  background_strict dir not found; skipping cross-check.")
}

# ------------------------------------------------------------------------------
# 6. Register both stacks in raster_asset (idempotent: delete-by-path, re-insert).
# ------------------------------------------------------------------------------
message("[0.1] Registering stacks in raster_asset ...")
register_stack_asset <- function(con, asset_id, tif_path, metric_id, stack_rast) {
  e   <- as.vector(terra::ext(stack_rast))
  rel <- gayini_relative_path(root_dir, tif_path)
  dbExecute(con, "DELETE FROM raster_asset WHERE path = ? OR raster_asset_id = ?",
            params = list(rel, asset_id))
  dbExecute(con,
    "INSERT INTO raster_asset
       (raster_asset_id, path, metric_id, water_year, period_label, crs,
        resolution_x, resolution_y, xmin, ymin, xmax, ymax,
        checksum_sha256, path_exists, qa_status, run_id)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
    params = list(asset_id, rel, metric_id, NA_character_, "1988-1989..2022-2023", TARGET_CRS,
                  terra::res(stack_rast)[1], terra::res(stack_rast)[2],
                  e[1], e[3], e[2], e[4],
                  NA_character_, 1L, "REVIEW", NA_character_))
}

con <- dbConnect(RSQLite::SQLite(), DB_PATH)
register_stack_asset(con, "stack_annual_wet_any_1988_2023",   WET_TIF,   "inundation_wet_any",   wet_stack)
register_stack_asset(con, "stack_annual_valid_any_1988_2023", VALID_TIF, "inundation_valid_any", valid_stack)
dbDisconnect(con)
message("  registered 2 stack assets (idempotent).")

message("[0.1] Build complete.")
