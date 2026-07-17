# ------------------------------------------------------------------------------
# Script: scripts/03_inundation_products/15_build_pixel_census_parquet.R
# Purpose: Tier 2 · Task H · H4 — assemble the all-pixel census as an external
#          Parquet asset and register it. One row per valid census pixel
#          (veg_regime_class non-NA); 1,080,157 rows. Built strictly to
#          docs/Gayini_pixel_census_data_contract.md.
#
# WHY PARQUET, EXTERNAL (contract §1): the census is the 5th registered asset type
#   alongside raster/figure/report/spatial_layer. It does NOT go into the SQLite
#   (1.08M rows, and a 2nd DB means 2 sets of release checks — that is correction
#   C5 at scale). A `census_asset` row indexes it; CSV is an export, not a store.
#
# pixel_id (contract §2) = terra cell index on the canonical 8058 grid
#   = (row-1)*ncol + col, 1-based row-major. Deterministic, reconstructible to x/y
#   from the grid alone, and joins straight back to any raster on the grid with NO
#   spatial join. That is why C2 (registering veg_regime_class_8058) is load-bearing:
#   the ID is meaningless without a registered grid definition — done at H2.
#
# Workflow stage: 03_inundation_products · Tier 2 Task H
# Run mode: analysis (raster -> table) · additive · post-build DB touch (census_asset)
# Key inputs (ALL asserted compareGeom() vs veg_regime_class_8058.tif first):
#   - Output/rasters/veg_regime_class_8058.tif                 -> pixel_id, class, community, band
#   - Output/rasters/inundation_annual_stack_8058/annual_{wet,valid}_any_*_8058.tif -> wet/valid/freq
#   - Output/rasters/flood_zone_8058.tif                       -> flood_zone
#   - Output/rasters/veg_percentiles_8058/total_veg_p{05..50}_8058.tif -> veg_p05..p50
#   - Output/database/Gayini_Results.sqlite (census_stratum, for the diff=0 check)
# Key outputs:
#   - Output/census/gayini_pixel_census_8058.parquet   (NEVER committed; Output/ gitignored)
#   - Output/diagnostics/tier2H_h4_census_reconciliation.csv
#   - Output/diagnostics/tier2H_h4_qa.json
#   - census_asset row `census_pixel_8058` (idempotent; grid_reference populated)
# Notes:
#   - Post-build mutation (census_asset). Re-run after any full DB rebuild.
#   - veg_p* are NULL where FC has < MIN_SEASONS valid seasons (lake, heavy cloud).
#     Report the null count per column; do NOT drop those rows and do NOT fill.
# ------------------------------------------------------------------------------

## 0. Constants ----

EXPECTED_ROWS   <- 1080157L
GRID_NCOL       <- 4037L
GRID_NROW       <- 2422L
MAX_PIXEL_ID    <- GRID_NCOL * GRID_NROW      # 9,777,614 -> fits int32
FOCUS_VALID_YRS <- 35L
PROB_LABELS     <- c("p05", "p10", "p20", "p30", "p50")
SCHEMA_VERSION  <- "pixel_census_data_contract/2026-07-16"

## 1. Sources ----

root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", getwd()), winslash = "/", mustWork = TRUE)
source(file.path(root_dir, "R", "gayini_helpers.R"))
source(file.path(root_dir, "R", "gayini_output_helpers.R"))
source(file.path(root_dir, "R", "gayini_output_paths.R"))
source(file.path(root_dir, "R", "gayini_gradient_helpers.R"))
source(file.path(root_dir, "R", "gayini_veg_regime_functions.R"))

suppressPackageStartupMessages({
  library(terra); library(dplyr); library(arrow); library(DBI); library(RSQLite)
})
terra::terraOptions(progress = 0)

rasters_dir     <- file.path(root_dir, "Output", "rasters")
diagnostics_dir <- file.path(root_dir, "Output", "diagnostics")
census_dir      <- file.path(root_dir, "Output", "census")
db_path         <- file.path(root_dir, "Output", "database", "Gayini_Results.sqlite")
dir.create(census_dir, recursive = TRUE, showWarnings = FALSE)

class_tif <- file.path(rasters_dir, "veg_regime_class_8058.tif")
stack_dir <- file.path(rasters_dir, "inundation_annual_stack_8058")
zone_tif  <- file.path(rasters_dir, "flood_zone_8058.tif")
pct_tifs  <- file.path(rasters_dir, "veg_percentiles_8058",
                       paste0("total_veg_", PROB_LABELS, "_8058.tif"))
for (p in c(class_tif, zone_tif, pct_tifs,
            file.path(stack_dir, c("annual_wet_any_1988_2023_8058.tif",
                                   "annual_valid_any_1988_2023_8058.tif"))))
  gayini_stop_if_missing(p, label = basename(p))


## 2. Load + grid discipline (every input must match the canonical grid) ----

message("\n[H4] Loading inputs + asserting compareGeom() vs veg_regime_class_8058.tif ...")
class_r <- terra::rast(class_tif)
class_num <- class_r; levels(class_num) <- NULL; terra::coltab(class_num) <- NULL
stopifnot(terra::ncol(class_r) == GRID_NCOL, terra::nrow(class_r) == GRID_NROW)

wet  <- terra::rast(file.path(stack_dir, "annual_wet_any_1988_2023_8058.tif"))
val  <- terra::rast(file.path(stack_dir, "annual_valid_any_1988_2023_8058.tif"))
zone <- terra::rast(zone_tif); zlev <- zone; levels(zlev) <- NULL; terra::coltab(zlev) <- NULL
pct  <- terra::rast(pct_tifs); names(pct) <- PROB_LABELS

for (nm in c("wet", "val", "zone", "pct")) {
  r <- get(nm)
  ok <- terra::compareGeom(r, class_r, lyrs = FALSE, crs = TRUE, ext = TRUE,
                           rowcol = TRUE, res = TRUE, stopOnError = FALSE)
  message(sprintf("  compareGeom(%-4s, veg_regime_class_8058) = %s", nm, ok))
  stopifnot(isTRUE(ok))
}


## 3. Census pixels = veg_regime_class non-NA. Assemble the wide table. ----

message("\n[H4] Assembling the census (one row per valid census pixel) ...")
code_all <- terra::values(class_num)[, 1]
cells    <- which(!is.na(code_all))                 # terra cell index = pixel_id (1-based)
n        <- length(cells)
message(sprintf("  census pixels (veg_regime_class non-NA): %s", format(n, big.mark = ",")))

xy <- terra::xyFromCell(class_r, cells)

## Per-pixel wet/valid counts + headline frequency, from the NN stack.
wet_years <- terra::values(terra::app(wet, "sum", na.rm = TRUE))[cells, 1]
val_years <- terra::values(terra::app(val, "sum", na.rm = TRUE))[cells, 1]
flood_freq <- ifelse(val_years > 0, 100 * wet_years / val_years, NA_real_)

## class -> community / band / treed flag (contract: 4-class simplified group).
lut <- gayini_veg_regime_classes()
mi  <- match(code_all[cells], lut$code)
community   <- lut$community[mi]
regime_band <- lut$band[mi]
treed_flag  <- code_all[cells] == 40L

zone_v <- terra::values(zlev)[cells, 1]
pct_v  <- terra::values(pct)[cells, , drop = FALSE]

census <- tibble::tibble(
  pixel_id    = as.integer(cells),
  x_8058      = as.numeric(xy[, 1]),
  y_8058      = as.numeric(xy[, 2]),
  veg_regime_class = as.integer(code_all[cells]),
  community   = factor(community, levels = unique(lut$community)),
  regime_band = factor(regime_band, levels = c("low", "mid", "high", "context")),
  treed_context_flag = as.logical(treed_flag),
  wet_years   = as.integer(wet_years),
  valid_years = as.integer(val_years),
  flood_freq_pct = as.numeric(flood_freq),
  flood_zone  = as.integer(zone_v),
  veg_p05 = as.numeric(pct_v[, "p05"]), veg_p10 = as.numeric(pct_v[, "p10"]),
  veg_p20 = as.numeric(pct_v[, "p20"]), veg_p30 = as.numeric(pct_v[, "p30"]),
  veg_p50 = as.numeric(pct_v[, "p50"]))


## 4. Acceptance assertions (contract §7) ----

message("\n================ H4 · acceptance assertions ================")

## (1) row count + pixel_id integrity
a_rows <- nrow(census) == EXPECTED_ROWS
a_uniq <- !any(duplicated(census$pixel_id)) && !anyNA(census$pixel_id)
a_max  <- max(census$pixel_id) <= MAX_PIXEL_ID
message(sprintf("  rows = %s (expected %s): %s", format(nrow(census), big.mark = ","),
                format(EXPECTED_ROWS, big.mark = ","), a_rows))
message(sprintf("  pixel_id unique + non-NA: %s ; max %s <= %s: %s",
                a_uniq, format(max(census$pixel_id), big.mark = ","),
                format(MAX_PIXEL_ID, big.mark = ","), a_max))

## (2) reconcile to census_stratum at diff = 0 (a REAL check — independent path)
con <- dbConnect(SQLite(), db_path)
cs <- dbGetQuery(con, "SELECT community, regime_band, n_pixels FROM census_stratum")
dbDisconnect(con)
got <- census |> dplyr::count(community, regime_band, name = "n_census") |>
  dplyr::mutate(community = as.character(community), regime_band = as.character(regime_band))
recon <- dplyr::full_join(cs, got, by = c("community", "regime_band")) |>
  dplyr::mutate(n_pixels = tidyr::replace_na(n_pixels, 0L),
                n_census = tidyr::replace_na(n_census, 0L),
                diff = n_census - n_pixels)
a_recon <- all(recon$diff == 0L)
message(sprintf("  reconciles to census_stratum (all 11 strata, diff = 0): %s  (max |diff| = %d)",
                a_recon, max(abs(recon$diff))))
gayini_write_csv(recon, file.path(diagnostics_dir, "tier2H_h4_census_reconciliation.csv"))

## (3) valid_years == 35 for every FOCUS row; context reported, not asserted
focus <- census[census$regime_band != "context", ]
a_focus35 <- all(focus$valid_years == FOCUS_VALID_YRS)
ctx_dist <- census[census$regime_band == "context", ] |>
  dplyr::count(valid_years, name = "n") |> dplyr::arrange(valid_years)
message(sprintf("  valid_years == 35 for every focus row: %s", a_focus35))
message("  context valid_years distribution (reported, not asserted):")
print(as.data.frame(ctx_dist), row.names = FALSE)

## (4) flood_freq bounded + equals 100*wet/valid
a_freq <- {
  f <- census$flood_freq_pct; ok <- !is.na(f)
  all(f[ok] >= -1e-6 & f[ok] <= 100 + 1e-6) &&
    max(abs(f[ok] - 100 * census$wet_years[ok] / census$valid_years[ok])) < 1e-4
}
message(sprintf("  flood_freq_pct in [0,100] and == 100*wet/valid: %s", a_freq))

## (5) pixel_id -> x/y round-trip within half a pixel
res <- terra::res(class_r); ext <- terra::ext(class_r)
row_ <- ((census$pixel_id - 1L) %/% GRID_NCOL) + 1L
col_ <- ((census$pixel_id - 1L) %% GRID_NCOL) + 1L
x_rt <- ext$xmin + (col_ - 0.5) * res[1]
y_rt <- ext$ymax - (row_ - 0.5) * res[2]
a_rt <- max(abs(x_rt - census$x_8058)) < res[1] / 2 &&
        max(abs(y_rt - census$y_8058)) < res[2] / 2
message(sprintf("  pixel_id -> x/y round-trip within half a pixel: %s (max dx %.3g, dy %.3g m)",
                a_rt, max(abs(x_rt - census$x_8058)), max(abs(y_rt - census$y_8058))))

## (6) per-row monotonicity of the percentiles (where all five are present)
pm <- as.matrix(census[, paste0("veg_", PROB_LABELS)])
row_ok <- stats::complete.cases(pm)
mono_ok <- apply(pm[row_ok, , drop = FALSE], 1, function(v) all(diff(v) >= -1e-4))
a_mono <- all(mono_ok)
message(sprintf("  veg_p05<=p10<=p20<=p30<=p50 per row (of %s complete rows): %s (%d violations)",
                format(sum(row_ok), big.mark = ","), a_mono, sum(!mono_ok)))

## (7) null counts per veg_p* (report; do not drop/fill)
null_counts <- vapply(paste0("veg_", PROB_LABELS),
                      function(c) sum(is.na(census[[c]])), integer(1))
message("  null counts per veg_p* (NULL where FC < MIN_SEASONS; e.g. the lake):")
print(null_counts)
a_null_consistent <- length(unique(null_counts)) == 1L   # same support mask across percentiles

stopifnot(a_rows, a_uniq, a_max, a_recon, a_focus35, a_freq, a_rt, a_mono)
message("\n  ==> ALL HARD ASSERTIONS PASSED.")


## 5. Write parquet (typed) ----

## Build an arrow Table (factors -> dictionary<int32,utf8> automatically), then cast
## the numeric columns to the compact contract types. Keep the inferred dictionary
## types for the two factors.
tbl <- arrow::as_arrow_table(census)
target <- arrow::schema(
  pixel_id = arrow::int32(), x_8058 = arrow::float64(), y_8058 = arrow::float64(),
  veg_regime_class = arrow::int8(),
  community = tbl$schema$GetFieldByName("community")$type,
  regime_band = tbl$schema$GetFieldByName("regime_band")$type,
  treed_context_flag = arrow::bool(),
  wet_years = arrow::int8(), valid_years = arrow::int8(),
  flood_freq_pct = arrow::float32(), flood_zone = arrow::int8(),
  veg_p05 = arrow::float32(), veg_p10 = arrow::float32(), veg_p20 = arrow::float32(),
  veg_p30 = arrow::float32(), veg_p50 = arrow::float32())
census_out <- tbl$cast(target)
parquet_path <- file.path(census_dir, "gayini_pixel_census_8058.parquet")
arrow::write_parquet(census_out, parquet_path, compression = "zstd")
sz <- round(file.info(parquet_path)$size / 1e6, 1)
message(sprintf("\n[H4] wrote %s (%.1f MB, %s rows x %d cols)", parquet_path, sz,
                format(nrow(census), big.mark = ","), ncol(census)))


## 6. Register census_asset (create the table if absent; idempotent row) ----

sha256_of <- function(p) tryCatch(
  if (requireNamespace("digest", quietly = TRUE)) digest::digest(file = p, algo = "sha256")
  else NA_character_, error = function(e) NA_character_)

con <- dbConnect(SQLite(), db_path)
dbExecute(con, "CREATE TABLE IF NOT EXISTS census_asset (
    census_asset_id TEXT PRIMARY KEY, path TEXT NOT NULL, product TEXT, crs_epsg INTEGER,
    grid_reference TEXT, n_rows INTEGER, checksum_sha256 TEXT, path_exists INTEGER,
    qa_status TEXT, run_id TEXT, schema_version TEXT)")
dbExecute(con, "DELETE FROM census_asset WHERE census_asset_id = ?",
          params = list("census_pixel_8058"))
dbExecute(con,
  "INSERT INTO census_asset (census_asset_id, path, product, crs_epsg, grid_reference,
     n_rows, checksum_sha256, path_exists, qa_status, run_id, schema_version)
   VALUES (?,?,?,?,?,?,?,?,?,?,?)",
  params = list("census_pixel_8058", gayini_relative_path(root_dir, parquet_path),
                "pixel_census_8058", 8058L, "raster_veg_regime_class_8058",
                nrow(census), sha256_of(parquet_path), 1L, "REVIEW", "tier2H_h4",
                SCHEMA_VERSION))
grid_ref_ok <- dbGetQuery(con, "SELECT COUNT(*) n FROM raster_asset
                                WHERE raster_asset_id = 'raster_veg_regime_class_8058'")$n == 1
dbDisconnect(con)
message(sprintf("  registered census_asset row; grid_reference resolves in raster_asset: %s",
                grid_ref_ok))
stopifnot(grid_ref_ok)


## 7. QA json ----

qa <- list(
  step = "H4 pixel census parquet",
  generated_by = "scripts/03_inundation_products/15_build_pixel_census_parquet.R",
  parquet = gayini_relative_path(root_dir, parquet_path), size_mb = sz,
  n_rows = nrow(census), n_cols = ncol(census),
  assertions = list(
    row_count = a_rows, pixel_id_unique = a_uniq, pixel_id_max_ok = a_max,
    reconciles_census_stratum_diff0 = a_recon,
    valid_years_35_all_focus = a_focus35, flood_freq_valid = a_freq,
    pixel_id_xy_roundtrip = a_rt, percentiles_monotone = a_mono,
    null_counts_consistent = a_null_consistent),
  null_counts_veg_p = as.list(null_counts),
  context_valid_years = lapply(seq_len(nrow(ctx_dist)), function(i) as.list(ctx_dist[i, ])),
  census_asset_id = "census_pixel_8058", grid_reference = "raster_veg_regime_class_8058",
  schema_version = SCHEMA_VERSION, committed_to_git = FALSE)
jsonlite::write_json(qa, file.path(diagnostics_dir, "tier2H_h4_qa.json"),
                     auto_unbox = TRUE, pretty = TRUE, digits = 6)

message("\n==================== H4 COMPLETE ====================")
message(sprintf("Parquet: %s (%.1f MB, %s rows)", gayini_relative_path(root_dir, parquet_path),
                sz, format(nrow(census), big.mark = ",")))
message("Registered: census_asset.census_pixel_8058 (grid_reference -> raster_veg_regime_class_8058)")
message("Reconciles to census_stratum at diff = 0; all contract §7 assertions pass.")
message("NEVER committed — Output/ is gitignored; commit the code + reconciliation table only.")
