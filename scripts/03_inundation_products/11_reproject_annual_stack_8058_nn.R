# ------------------------------------------------------------------------------
# Script: scripts/03_inundation_products/11_reproject_annual_stack_8058_nn.R
# Purpose: Tier 2 · Task H · H3.0 — bring the 35-layer binary annual inundation
#          stack onto the canonical EPSG:8058 census grid ONCE, by nearest-
#          neighbour reprojection of the BINARY layers (not the bilinear-smoothed
#          continuous frequency surface the F5/census pipeline currently uses).
#          Writes the reprojected stack as a new registered raster product,
#          asserts grid alignment + the legal value set, and reports the NN-vs-
#          bilinear reconciliation delta (footprint, per-class counts, frequency
#          values, terciles) against the existing bilinear-derived products.
# Workflow stage: 03_inundation_products (raster) · Tier 2 Task H, Track A
# Run mode: analysis (real raster work) · additive · post-build DB touch (raster_asset)
# Key inputs:
#   - Output/rasters/inundation_annual_stack/annual_{wet,valid}_any_1988_2023.tif (EPSG:28355, 25 m, 35 lyr)
#   - Output/rasters/veg_regime_class_8058.tif   (EPSG:8058 grid TEMPLATE, 24.97 m)
#   - Output/spatial_8058/{vegetation_communities,gayini_boundary,stratified_sample_points}_epsg8058.gpkg
#   - Output/diagnostics/regime_band_breaks.csv  (OLD bilinear terciles, F5)
#   - Output/database/Gayini_Results.sqlite      (census_stratum, raster_asset)
# Key outputs (ALL ADDITIVE — nothing existing is overwritten):
#   - Output/rasters/inundation_annual_stack_8058/annual_{wet,valid}_any_1988_2023_8058.tif (EPSG:8058, NN)
#   - Output/diagnostics/regime_band_breaks_nn.csv        (NN terciles — NEW file)
#   - Output/diagnostics/tier2H_h30_nn_vs_bilinear_delta.csv
#   - Output/diagnostics/tier2H_h30_reproject_qa.json
#   - raster_asset: 2 new rows (product = 'annual_inundation_stack_8058'), idempotent
# Notes:
#   - Gate 1 signed off; see docs/tier2H_gate1_VERIFIED_20260715.md. Resampling is
#     NEAREST-NEIGHBOUR ONLY (binary masks; bilinear would manufacture fractional
#     'wet' values and corrupt every count). Originals in 28355 are untouched.
#   - annual_valid_any is presence-only {1,255}: there is NO zero. nodata = 255 must
#     survive reprojection as NA, never as a value entering app(sum).
#   - STOP-AND-REPORT step: this does NOT rewrite census_stratum / veg_regime_class /
#     regime_band_breaks.csv. It reports the delta so the NN mechanism can be
#     approved before the census (H3.1+) is computed on top of it.
#   - Post-build DB mutation (raster_asset rows); re-run after any full rebuild.
# ------------------------------------------------------------------------------

## 0. Tunable defaults ----

MIN_VALID_YEARS <- 25L        # census support mask (non-binding: drops 0.025%, valid_count 22-35)
TARGET_CRS      <- 8058L
LEGAL_WET       <- c(0L, 1L)  # annual_wet_any  legal value set (+ NA)
LEGAL_VALID     <- c(1L)      # annual_valid_any legal value set (+ NA) — presence-only, NO zero
NODATA          <- 255L


## 1. Sources ----

root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", getwd()), winslash = "/", mustWork = TRUE)

source(file.path(root_dir, "R", "gayini_helpers.R"))
source(file.path(root_dir, "R", "vector_prep_functions.R"))
source(file.path(root_dir, "R", "gayini_output_helpers.R"))
source(file.path(root_dir, "R", "gayini_output_paths.R"))
source(file.path(root_dir, "R", "gayini_gradient_helpers.R"))
source(file.path(root_dir, "R", "gayini_spatial_8058_functions.R"))
source(file.path(root_dir, "R", "gayini_stratified_sampling_functions.R"))
source(file.path(root_dir, "R", "gayini_pixel_census_functions.R"))

suppressPackageStartupMessages({
  library(sf)
  library(terra)
  library(dplyr)
  library(DBI)
  library(RSQLite)
})

sf::sf_use_s2(FALSE)

rasters_dir     <- file.path(root_dir, "Output", "rasters")
diagnostics_dir <- file.path(root_dir, "Output", "diagnostics")
spatial_dir     <- file.path(root_dir, "Output", "spatial_8058")
db_path         <- file.path(root_dir, "Output", "database", "Gayini_Results.sqlite")

stack_dir_28355 <- file.path(rasters_dir, "inundation_annual_stack")
wet_path   <- file.path(stack_dir_28355, "annual_wet_any_1988_2023.tif")
valid_path <- file.path(stack_dir_28355, "annual_valid_any_1988_2023.tif")
class_tif  <- file.path(rasters_dir, "veg_regime_class_8058.tif")

out_dir       <- file.path(rasters_dir, "inundation_annual_stack_8058")
wet_8058_out  <- file.path(out_dir, "annual_wet_any_1988_2023_8058.tif")
val_8058_out  <- file.path(out_dir, "annual_valid_any_1988_2023_8058.tif")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

for (p in c(wet_path, valid_path, class_tif)) gayini_stop_if_missing(p, label = basename(p))

focus_communities <- gayini_focus_levels()


## 2. Load template + stacks + vectors ----

message("\n[H3.0] Loading grid template + 28355 stacks ...")
class_r <- terra::rast(class_tif)                       # EPSG:8058 grid template (24.97 m)
wet_28355 <- terra::rast(wet_path)                      # 35 lyr, {0,1,255->NA}
val_28355 <- terra::rast(valid_path)                    # 35 lyr, {1,255->NA} (presence-only)

stopifnot(terra::nlyr(wet_28355) == terra::nlyr(val_28355))
n_years <- terra::nlyr(wet_28355)
message(sprintf("  stack: %d layers, native CRS EPSG:%s, res %.3f m",
                n_years, terra::crs(wet_28355, describe = TRUE)$code, terra::res(wet_28355)[1]))

boundary    <- gayini_read_vector(file.path(spatial_dir, "gayini_boundary_epsg8058.gpkg"),  label = "boundary (8058)")
communities <- gayini_read_vector(file.path(spatial_dir, "vegetation_communities_epsg8058.gpkg"), label = "communities (8058)")
points      <- gayini_read_vector(file.path(spatial_dir, "stratified_sample_points.gpkg"),  label = "stratified points (8058)")


## 3. Nearest-neighbour reprojection onto the canonical 8058 grid ----
##    project(x, <template SpatRaster>, method="near") snaps to the template grid
##    exactly, so compareGeom() against veg_regime_class_8058.tif must pass.

message("\n[H3.0] Reprojecting 28355 -> 8058 (method = 'near', binary masks) ...")
wet_8058 <- terra::project(wet_28355, class_r, method = "near")
val_8058 <- terra::project(val_28355, class_r, method = "near")
names(wet_8058) <- names(wet_28355)
names(val_8058) <- names(val_28355)


## 4. ASSERTION A — grid alignment to the canonical census grid (compareGeom) ----

message("\n================ H3.0 ASSERTION A — compareGeom vs veg_regime_class_8058.tif ================")
geom_wet <- terra::compareGeom(wet_8058, class_r, lyrs = FALSE, crs = TRUE, ext = TRUE,
                               rowcol = TRUE, res = TRUE, stopOnError = FALSE)
geom_val <- terra::compareGeom(val_8058, class_r, lyrs = FALSE, crs = TRUE, ext = TRUE,
                               rowcol = TRUE, res = TRUE, stopOnError = FALSE)
grid_report <- function(r, lab) {
  e <- terra::ext(r)
  cat(sprintf("  %-16s crs=EPSG:%s dims=%dx%d res=%.6f origin=(%.6f, %.6f)\n",
              lab, terra::crs(r, describe = TRUE)$code, nrow(r), ncol(r),
              terra::res(r)[1], terra::origin(r)[1], terra::origin(r)[2]))
  cat(sprintf("  %-16s ext xmin=%.4f xmax=%.4f ymin=%.4f ymax=%.4f\n",
              "", e$xmin, e$xmax, e$ymin, e$ymax))
}
grid_report(class_r,  "TEMPLATE(class)")
grid_report(wet_8058, "wet_8058")
grid_report(val_8058, "valid_8058")
cat(sprintf("\n  compareGeom(wet_8058,  class_r) = %s\n", geom_wet))
cat(sprintf("  compareGeom(valid_8058, class_r) = %s\n", geom_val))
stopifnot(isTRUE(geom_wet), isTRUE(geom_val))
cat("  ==> ASSERTION A PASSED: reprojected stack sits exactly on the canonical 8058 grid.\n")


## 5. ASSERTION B — legal value set + nodata survives as NA (never as a value) ----

message("\n================ H3.0 ASSERTION B — legal value set + 255->NA ================")
value_set <- function(r) {
  f <- terra::freq(r, bylayer = FALSE)         # tallies non-NA values across all cells/layers
  sort(unique(f$value[is.finite(f$value)]))
}
wet_vals <- value_set(wet_8058)
val_vals <- value_set(val_8058)
cat(sprintf("  wet_8058   observed value set: {%s}\n", paste(wet_vals, collapse = ", ")))
cat(sprintf("  valid_8058 observed value set: {%s}\n", paste(val_vals, collapse = ", ")))

chk_wet_legal   <- all(wet_vals %in% LEGAL_WET)
chk_val_legal   <- all(val_vals %in% LEGAL_VALID)
chk_wet_no255   <- !(NODATA %in% wet_vals)
chk_val_no255   <- !(NODATA %in% val_vals)
cat(sprintf("  wet   ⊆ {0,1}+NA        : %s\n", chk_wet_legal))
cat(sprintf("  valid ⊆ {1}+NA (no zero): %s\n", chk_val_legal))
cat(sprintf("  255 absent from wet     : %s\n", chk_wet_no255))
cat(sprintf("  255 absent from valid   : %s\n", chk_val_no255))
stopifnot(chk_wet_legal, chk_val_legal, chk_wet_no255, chk_val_no255)
cat("  ==> ASSERTION B PASSED: binary masks intact; 255 survived reprojection as NA.\n")


## 6. Write the reprojected 8058 stack (new files; NAflag=255 preserves nodata) ----

message("\n[H3.0] Writing reprojected 8058 stack (INT1U, NAflag=255) ...")
terra::writeRaster(wet_8058, wet_8058_out, overwrite = TRUE, datatype = "INT1U", NAflag = NODATA)
terra::writeRaster(val_8058, val_8058_out, overwrite = TRUE, datatype = "INT1U", NAflag = NODATA)
message("  wrote: ", wet_8058_out)
message("  wrote: ", val_8058_out)


## 7. NN frequency surface on the 8058 grid (compute AFTER reprojection) ----

wet_count_nn   <- terra::app(wet_8058, fun = "sum", na.rm = TRUE)
valid_count_nn <- terra::app(val_8058, fun = "sum", na.rm = TRUE)
valid_count_nn <- terra::ifel(valid_count_nn == 0, NA, valid_count_nn)
names(valid_count_nn) <- "valid_years"
freq_nn <- 100 * wet_count_nn / valid_count_nn
freq_nn_supported <- terra::ifel(valid_count_nn >= MIN_VALID_YEARS, freq_nn, NA)
names(freq_nn_supported) <- "background_flood_freq"

fr_rng <- as.numeric(terra::minmax(freq_nn_supported))
cat(sprintf("\n  NN freq range: [%.4f, %.4f] (must be within [0,100])\n", fr_rng[1], fr_rng[2]))
stopifnot(fr_rng[1] >= -1e-9, fr_rng[2] <= 100 + 1e-9)


## 8. Bilinear reference surface (existing mechanism) for the delta ----

message("\n[H3.0] Computing the existing BILINEAR surface for the reconciliation delta ...")
surf_bl <- gayini_background_flood_frequency(
  wet_path = wet_path, valid_path = valid_path,
  min_valid_years = MIN_VALID_YEARS, target = TARGET_CRS, out_tif = NULL)
freq_bl        <- surf_bl$freq_8058
valid_count_bl <- surf_bl$valid_8058

## The bilinear surface auto-grids to 8058; it must match the class template grid.
stopifnot(isTRUE(terra::compareGeom(freq_bl, class_r, lyrs = FALSE, crs = TRUE,
                                    ext = TRUE, rowcol = TRUE, res = TRUE, stopOnError = FALSE)))


## 9. DELTA — footprint + frequency values (NN vs bilinear) ----

message("\n================ H3.0 DELTA — NN vs BILINEAR ================")
sup_nn <- !is.na(terra::values(freq_nn_supported)[, 1])
sup_bl <- !is.na(terra::values(freq_bl)[, 1])
n_sup_nn <- sum(sup_nn); n_sup_bl <- sum(sup_bl)
in_nn_not_bl <- sum(sup_nn & !sup_bl)
in_bl_not_nn <- sum(!sup_nn & sup_bl)

fn <- terra::values(freq_nn_supported)[, 1]
fb <- terra::values(freq_bl)[, 1]
both <- sup_nn & sup_bl
d <- fn[both] - fb[both]
freq_delta <- list(
  n_both      = sum(both),
  mean_pp     = mean(d),
  median_pp   = stats::median(d),
  sd_pp       = stats::sd(d),
  pct_gt1pp   = 100 * mean(abs(d) > 1),
  pct_gt5pp   = 100 * mean(abs(d) > 5),
  var_nn      = stats::var(fn[both]),
  var_bl      = stats::var(fb[both])
)

cat("  FOOTPRINT (supported pixels on the 8058 grid):\n")
cat(sprintf("    NN supported px         : %d\n", n_sup_nn))
cat(sprintf("    BILINEAR supported px   : %d\n", n_sup_bl))
cat(sprintf("    difference (NN - BL)    : %+d\n", n_sup_nn - n_sup_bl))
cat(sprintf("    in NN not BL / in BL not NN : %d / %d\n", in_nn_not_bl, in_bl_not_nn))
cat("  FREQUENCY VALUE DELTA (where both defined):\n")
cat(sprintf("    n_both=%d  mean=%+.4f pp  median=%+.4f  sd=%.4f pp  >1pp=%.1f%%  >5pp=%.1f%%\n",
            freq_delta$n_both, freq_delta$mean_pp, freq_delta$median_pp,
            freq_delta$sd_pp, freq_delta$pct_gt1pp, freq_delta$pct_gt5pp))
cat(sprintf("    variance  NN=%.3f  BL=%.3f\n", freq_delta$var_nn, freq_delta$var_bl))


## 10. NN terciles + per-class census counts vs the old bilinear products ----

message("\n[H3.0] Re-deriving terciles from the NN surface + tabulating the NN census ...")
breaks_nn <- gayini_community_regime_bands(freq_nn_supported, communities, focus_communities)

## Old bilinear terciles (F5, source of truth for the current strata definitions).
old_breaks_tbl <- readr::read_csv(file.path(diagnostics_dir, "regime_band_breaks.csv"),
                                  show_col_types = FALSE)
breaks_old <- stats::setNames(lapply(focus_communities, function(g) {
  r <- old_breaks_tbl[old_breaks_tbl$community == g, ]
  c(r$freq_min_pct, r$tercile_1_pct, r$tercile_2_pct, r$freq_max_pct)
}), focus_communities)

## NN census (per community x band) using the NN terciles.
res_nn <- gayini_pixel_census(
  freq_8058 = freq_nn_supported, valid_8058 = valid_count_nn,
  communities = communities, breaks = breaks_nn,
  focus_communities = focus_communities, points = points,
  min_valid_years = MIN_VALID_YEARS)
census_nn <- res_nn$census

## Old census counts (the committed bilinear product).
con <- dbConnect(SQLite(), db_path)
census_old <- dbGetQuery(con, "SELECT community, regime_band, n_pixels FROM census_stratum")
dbDisconnect(con)

## Tercile delta table (NN - bilinear).
tercile_delta <- dplyr::bind_rows(lapply(focus_communities, function(g) {
  bn <- breaks_nn[[g]]; bo <- breaks_old[[g]]
  tibble::tibble(community = g,
                 t1_old = round(bo[2], 3), t1_nn = round(bn[2], 3), t1_delta = round(bn[2] - bo[2], 3),
                 t2_old = round(bo[3], 3), t2_nn = round(bn[3], 3), t2_delta = round(bn[3] - bo[3], 3))
}))

## Per-class count delta (NN vs old census_stratum).
count_delta <- census_nn %>%
  dplyr::select(community, regime_band, n_pixels_nn = n_pixels) %>%
  dplyr::left_join(dplyr::rename(census_old, n_pixels_old = n_pixels),
                   by = c("community", "regime_band")) %>%
  dplyr::mutate(delta = n_pixels_nn - n_pixels_old)

## Per-community totals (independent of terciles — the cleanest footprint check).
comm_delta <- count_delta %>%
  dplyr::group_by(community) %>%
  dplyr::summarise(nn = sum(n_pixels_nn), old = sum(n_pixels_old, na.rm = TRUE),
                   delta = sum(n_pixels_nn) - sum(n_pixels_old, na.rm = TRUE), .groups = "drop")

cat("\n  TERCILE BREAKS (NN - bilinear, percentage points):\n")
print(as.data.frame(tercile_delta), row.names = FALSE)
cat("\n  PER-COMMUNITY PIXEL COUNTS (NN vs old census_stratum):\n")
print(as.data.frame(comm_delta), row.names = FALSE)
cat("\n  PER-CLASS PIXEL COUNTS (NN terciles vs old census_stratum):\n")
print(as.data.frame(count_delta), row.names = FALSE)


## 11. Persist delta tables + NN terciles (NEW files; do NOT overwrite old) ----

readr::write_csv(count_delta,    file.path(diagnostics_dir, "tier2H_h30_nn_vs_bilinear_delta.csv"))
readr::write_csv(tercile_delta,  file.path(diagnostics_dir, "tier2H_h30_tercile_delta.csv"))
readr::write_csv(comm_delta,     file.path(diagnostics_dir, "tier2H_h30_community_delta.csv"))

breaks_nn_tbl <- dplyr::bind_rows(lapply(focus_communities, function(g) {
  b <- breaks_nn[[g]]
  tibble::tibble(community = g, freq_min_pct = b[1], tercile_1_pct = b[2],
                 tercile_2_pct = b[3], freq_max_pct = b[4])
}))
readr::write_csv(breaks_nn_tbl, file.path(diagnostics_dir, "regime_band_breaks_nn.csv"))


## 12. Register the reprojected 8058 stack in raster_asset (idempotent, additive) ----

message("\n[H3.0] Registering the 8058 stack in raster_asset (additive, idempotent) ...")
sha256_of <- function(path) {
  out <- tryCatch(
    if (requireNamespace("digest", quietly = TRUE))
      digest::digest(file = path, algo = "sha256") else NA_character_,
    error = function(e) NA_character_)
  out
}
register_asset <- function(con, asset_id, path, r, product, semantics) {
  e <- as.vector(terra::ext(r)); res <- terra::res(r)
  rel <- gayini_relative_path(root_dir, path)
  DBI::dbExecute(con, "DELETE FROM raster_asset WHERE raster_asset_id = ?", params = list(asset_id))
  DBI::dbExecute(con,
    "INSERT INTO raster_asset
      (raster_asset_id, path, metric_id, water_year, period_label, crs,
       resolution_x, resolution_y, xmin, ymin, xmax, ymax, checksum_sha256,
       path_exists, qa_status, run_id, crs_epsg, product, legend_status, legend_semantics)
     VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
    params = list(asset_id, rel, NA_character_, NA_character_, "annual_1988_2023",
                  paste0("EPSG:", TARGET_CRS), res[1], res[2], e[1], e[3], e[2], e[4],
                  sha256_of(path), 1L, "REVIEW", "tier2H_h30", TARGET_CRS, product,
                  "confirmed", semantics))
}
con <- dbConnect(SQLite(), db_path)
sem_wet <- "Annual wet-any mask, 35 layers (WY1988-WY2023), EPSG:8058 NN-reprojected from 28355. wet=1, dry=0, nodata=255->NA. wet in {1,2} rule applied upstream in the 28355 annual stack."
sem_val <- "Annual valid-any (presence) mask, 35 layers (WY1988-WY2023), EPSG:8058 NN-reprojected from 28355. valid=1 (observed), nodata=255->NA; presence-only, no zero."
register_asset(con, "raster_08058_wet",   wet_8058_out, wet_8058, "annual_inundation_stack_8058", sem_wet)
register_asset(con, "raster_08058_valid", val_8058_out, val_8058, "annual_inundation_stack_8058", sem_val)
n_reg <- dbGetQuery(con, "SELECT COUNT(*) n FROM raster_asset WHERE product = 'annual_inundation_stack_8058'")$n
dbDisconnect(con)
message(sprintf("  registered %d rows under product = 'annual_inundation_stack_8058'.", n_reg))


## 13. QA json ----

qa <- list(
  step                 = "H3.0 NN reprojection of the annual stack onto the 8058 census grid",
  generated_by         = "scripts/03_inundation_products/11_reproject_annual_stack_8058_nn.R",
  target_crs           = TARGET_CRS,
  min_valid_years      = MIN_VALID_YEARS,
  n_years              = n_years,
  assertions = list(
    compareGeom_wet   = geom_wet, compareGeom_valid = geom_val,
    wet_legal = chk_wet_legal, valid_legal = chk_val_legal,
    wet_no_255 = chk_wet_no255, valid_no_255 = chk_val_no255,
    wet_value_set = as.integer(wet_vals), valid_value_set = as.integer(val_vals)
  ),
  delta = list(
    footprint_nn = n_sup_nn, footprint_bl = n_sup_bl,
    footprint_diff = n_sup_nn - n_sup_bl,
    in_nn_not_bl = in_nn_not_bl, in_bl_not_nn = in_bl_not_nn,
    freq = freq_delta,
    per_community = lapply(seq_len(nrow(comm_delta)), function(i)
      as.list(comm_delta[i, ])),
    tercile = lapply(seq_len(nrow(tercile_delta)), function(i)
      as.list(tercile_delta[i, ]))
  ),
  registered_assets = c("raster_08058_wet", "raster_08058_valid"),
  outputs = list(
    wet_8058 = gayini_relative_path(root_dir, wet_8058_out),
    valid_8058 = gayini_relative_path(root_dir, val_8058_out),
    delta_csv = "Output/diagnostics/tier2H_h30_nn_vs_bilinear_delta.csv",
    breaks_nn = "Output/diagnostics/regime_band_breaks_nn.csv"
  )
)
qa_path <- file.path(diagnostics_dir, "tier2H_h30_reproject_qa.json")
jsonlite::write_json(qa, qa_path, auto_unbox = TRUE, pretty = TRUE, digits = 6)
message("  wrote: ", qa_path)


## 14. Summary — STOP AND REPORT ----

message("\n==================== H3.0 COMPLETE — STOP AND REPORT ====================")
message("Reprojected 8058 stack : ", wet_8058_out)
message("                         ", val_8058_out)
message("Grid alignment (compareGeom) : PASS")
message("Legal value set + 255->NA    : PASS")
message(sprintf("Footprint delta (NN - BL)    : %+d px", n_sup_nn - n_sup_bl))
message(sprintf("Freq mean delta              : %+.4f pp", freq_delta$mean_pp))
message("NN terciles + census NOT persisted as canonical — held for review.")
message("Existing veg_regime_class_8058.tif / census_stratum / regime_band_breaks.csv UNTOUCHED.")
message("\nNEXT (after sign-off): H3.1 census veg x wetness matrix on the NN stack.")
