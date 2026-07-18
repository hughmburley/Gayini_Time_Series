# ------------------------------------------------------------------------------
# Script: scripts/03_inundation_products/16_task_J_gate2_single_date_2018.R
# Purpose: Tier 1 · Task J · GATE 2 — build the SINGLE real cut date (C = 2018)
#          pre/post between-year flood-frequency change, alone, and verify it
#          before the placebo ladder (Gate 3) is ever touched. Reports the
#          assertion output, the boundary-clipped whole-farm mean diff_pp, the
#          per-community means (4 canonical + Other as a residual line), the
#          contributing pixel counts, and the MIN_VALID failures before AND
#          after the boundary clip. Descriptive only; NOT an effect estimate.
# Workflow stage: 03_inundation_products (raster) · Tier 1 Task J · additive
# Run mode: analysis (real raster work). Stops at Gate 2 — no ladder, no figures.
# Key inputs:
#   - Output/rasters/inundation_annual_stack/annual_{wet,valid}_any_1988_2023.tif
#     (EPSG:28355, 25.0 m, 35 layers; wet {0,1}+NA, valid {1}+NA, nodata 255)
#   - Output/spatial_8058/gayini_boundary_epsg8058.gpkg          (EPSG:8058)
#   - Output/spatial_8058/vegetation_communities_epsg8058.gpkg   (EPSG:8058, 5 groups)
# Key outputs (ADDITIVE):
#   - Output/rasters/task_J/diff_pp_2018_28355.tif      (native 28355, FLT4S; gitignored)
#   - Output/tables/task_J_gate2_2018_summary.csv       (small; committable via git add -f)
#   - Output/tables/task_J_gate2_2018_assertions.csv    (small; committable via git add -f)
# Notes / hard rules honoured:
#   - Layer index for START-year C is C-1987 (Gate-1 verified). 2018 -> layer 31.
#     PRE = layers 1..29 ; TRANSITION = layer 30 (2017-2018) DROPPED ; POST = 31..35.
#   - valid is presence-only {1}+NA: value sets asserted BEFORE any sum (H3.0 idiom).
#   - ALL statistics native 28355. Per Gate-1 note B, pixel counts are labelled with
#     their CRS and are internal-support only; NO hectares/% of farm off the 28355 grid.
#   - Note A (NaN NAflag = live L31 hazard): the diff raster is re-read from disk and
#     its on-disk value distribution asserted; we report the assertion, not a claim.
# ------------------------------------------------------------------------------

## 0. Tunables ----
CUT_YEAR       <- 2018L
MIN_VALID_POST <- 4L      # >= 4 of 5 post years
PRE_VALID_FRAC <- 0.80    # >= 80% of pre years
DIFF_NODATA    <- -9999   # explicit float nodata so the on-disk 255/sentinel check is meaningful

## 1. Sources ----
root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", getwd()), winslash = "/", mustWork = TRUE)
source(file.path(root_dir, "R", "inundation_pre_post_raster_functions.R"))
source(file.path(root_dir, "scripts", "03_inundation_products", "internal", "task_J_prepost_placebo_impl.R"))

suppressPackageStartupMessages({ library(terra); library(sf); library(dplyr); library(readr) })
sf::sf_use_s2(FALSE)

rasters_dir <- file.path(root_dir, "Output", "rasters")
spatial_dir <- file.path(root_dir, "Output", "spatial_8058")
tables_dir  <- file.path(root_dir, "Output", "tables")
taskj_rdir  <- file.path(rasters_dir, "task_J")
dir.create(taskj_rdir, recursive = TRUE, showWarnings = FALSE)
dir.create(tables_dir, recursive = TRUE, showWarnings = FALSE)

wet_path   <- file.path(rasters_dir, "inundation_annual_stack", "annual_wet_any_1988_2023.tif")
valid_path <- file.path(rasters_dir, "inundation_annual_stack", "annual_valid_any_1988_2023.tif")

wet   <- terra::rast(wet_path)
valid <- terra::rast(valid_path)
stopifnot(terra::nlyr(wet) == 35L, terra::nlyr(valid) == 35L)

## 2. Window mapping — print it, it is load-bearing ----
w <- taskj_windows(CUT_YEAR, n_layers = terra::nlyr(wet))
cat("================ TASK J · GATE 2 · C =", CUT_YEAR, "================\n")
cat(sprintf("Layer index rule: start-year C -> layer C-1987. %d -> layer %d\n", CUT_YEAR, CUT_YEAR - 1987L))
cat(sprintf("PRE   layers %d..%d  (WY %d-%d .. %d-%d) : %d years\n",
            min(w$pre_idx), max(w$pre_idx), min(w$pre_years), min(w$pre_years)+1L,
            max(w$pre_years), max(w$pre_years)+1L, w$n_pre))
cat(sprintf("TRAN  layer  %d      (WY %d-%d) : DROPPED\n", w$tran_idx, w$tran_year, w$tran_year+1L))
cat(sprintf("POST  layers %d..%d  (WY %d-%d .. %d-%d) : %d years\n",
            min(w$post_idx), max(w$post_idx), min(w$post_years), min(w$post_years)+1L,
            max(w$post_years), max(w$post_years)+1L, w$n_post))
# Prove layer 30 name is the transition and is in neither window:
cat(sprintf("Verify: layer %d name = '%s' (transition, excluded)\n", w$tran_idx, names(wet)[w$tran_idx]))
cat(sprintf("Verify: layer %d name = '%s' (first PRE)  ; layer %d name = '%s' (first POST)\n",
            min(w$pre_idx), names(wet)[min(w$pre_idx)], min(w$post_idx), names(wet)[min(w$post_idx)]))
stopifnot(names(wet)[w$tran_idx] == paste0(w$tran_year, "-", w$tran_year + 1L))

## 3. INPUT ASSERTIONS on the layers actually used (255-safe, non-vacuous) ----
cat("\n---- INPUT ASSERTIONS (window layers only) ----\n")
inp_pre  <- taskj_assert_inputs(wet[[w$pre_idx]],  valid[[w$pre_idx]],  label = "pre")
inp_post <- taskj_assert_inputs(wet[[w$post_idx]], valid[[w$post_idx]], label = "post")
input_checks <- dplyr::bind_rows(inp_pre, inp_post)
print(as.data.frame(input_checks), row.names = FALSE)
stopifnot(all(input_checks$passed))

## 4. Build 2018 (native 28355) ----
build <- taskj_build_one_date(wet, valid, CUT_YEAR,
                              min_valid_post = MIN_VALID_POST, pre_valid_frac = PRE_VALID_FRAC)
min_valid_pre <- build$min_valid_pre   # capture before rm(build) at the write step
cat(sprintf("\nMIN_VALID: post >= %d of %d ; pre >= %d of %d (%.0f%%)\n",
            build$min_valid_post, w$n_post, build$min_valid_pre, w$n_pre, 100*PRE_VALID_FRAC))

## 5. PRODUCT ASSERTIONS (the sound pre/post checks) ----
cat("\n---- PRODUCT ASSERTIONS ----\n")
prod_checks <- taskj_assert_products(build)
print(as.data.frame(prod_checks), row.names = FALSE)
stopifnot(all(prod_checks$passed))

## 6. Boundary clip (reproject boundary 8058 -> 28355; rasterize a 1/NA mask) ----
boundary <- sf::st_read(file.path(spatial_dir, "gayini_boundary_epsg8058.gpkg"), quiet = TRUE)
boundary_28355 <- sf::st_transform(boundary, terra::crs(build$diff))
bmask <- terra::rasterize(terra::vect(boundary_28355), build$diff, field = 1)
names(bmask) <- "farm"

diff_farm <- terra::mask(build$diff, bmask)

## 7. Whole-farm mean diff_pp (boundary-clipped) + contributing pixels ----
farm_mean_diff <- as.numeric(terra::global(diff_farm, "mean", na.rm = TRUE)[1, 1])
n_contrib_farm <- gayini_raster_non_na_count(diff_farm)         # boundary AND diff not NA
cat(sprintf("\n---- WHOLE-FARM (boundary-clipped) ----\n"))
cat(sprintf("mean diff_pp (2018)          : %+0.4f pp\n", farm_mean_diff))
cat(sprintf("contributing pixels          : %d  [28355 grid, internal support]\n", n_contrib_farm))

## 8. Per-community means (rasterize veg 8058 -> 28355; 4 canonical + Other) ----
veg <- sf::st_read(file.path(spatial_dir, "vegetation_communities_epsg8058.gpkg"), quiet = TRUE)
veg_28355 <- sf::st_transform(veg, terra::crs(build$diff))
veg_28355$grp_id <- seq_len(nrow(veg_28355))
vgrid <- terra::rasterize(terra::vect(veg_28355), build$diff, field = "grp_id")

zon <- terra::zonal(build$diff, vgrid, fun = "mean", na.rm = TRUE)
zon_n <- terra::zonal(terra::ifel(!is.na(build$diff), 1, 0), vgrid, fun = "sum", na.rm = TRUE)
names(zon)   <- c("grp_id", "diff_pp")
names(zon_n) <- c("grp_id", "n_px_28355")
comm <- dplyr::tibble(grp_id = veg_28355$grp_id,
                      community = veg_28355$simplified_vegetation_group) |>
  dplyr::left_join(zon,   by = "grp_id") |>
  dplyr::left_join(zon_n, by = "grp_id") |>
  dplyr::mutate(is_canonical = community != "Other / minor units") |>
  dplyr::arrange(dplyr::desc(is_canonical), community)
cat("\n---- PER-COMMUNITY mean diff_pp (4 canonical, then Other residual) ----\n")
print(as.data.frame(comm |> dplyr::transmute(community, diff_pp = round(diff_pp, 4),
                                             n_px_28355, line = ifelse(is_canonical, "canonical", "residual"))),
      row.names = FALSE)

## 9. MIN_VALID failures BEFORE and AFTER the boundary clip ----
vpre  <- build$pre$valid_year_count
vpost <- build$post$valid_year_count
has_data <- (vpre > 0) & (vpost > 0)
fail <- has_data & ((vpre < build$min_valid_pre) | (vpost < build$min_valid_post))
n_fail_tile <- gayini_raster_sum(terra::ifel(fail, 1, 0))
n_fail_farm <- gayini_raster_sum(terra::ifel(fail & !is.na(bmask), 1, 0))
cat("\n---- MIN_VALID failures ----\n")
cat(sprintf("failing pixels, whole tile   : %d  [28355 grid]\n", n_fail_tile))
cat(sprintf("failing pixels, within farm  : %d  [28355 grid]  (expected 0 -> MIN_VALID inert)\n", n_fail_farm))

## 10. WRITE + RE-READ + ASSERT ON DISK (Gate-1 note A: writes are the hazard) ----
## Emitted as assertion ROWS (group "ondisk"), the same code that performs the check.
diff_out <- file.path(taskj_rdir, "diff_pp_2018_28355.tif")
wr <- taskj_write_and_assert(build$diff, diff_out, nodata = DIFF_NODATA,
                             datatype = "FLT4S", lo = -100, hi = 100)
ondisk_checks <- wr$checks
cat("\n---- ON-DISK RE-READ ASSERTION (diff_pp_2018_28355.tif) ----\n")
print(as.data.frame(ondisk_checks[, c("check", "status", "detail")]), row.names = FALSE)
stopifnot(all(ondisk_checks$passed))
cat("==> ON-DISK ASSERTION PASSED: nodata landed as NA, not as a value.\n")
rm(build)

## 11. Emit small results tables (committable via git add -f) ----
summary_tbl <- dplyr::tibble(
  cut_year = CUT_YEAR, is_real = TRUE,
  n_pre_years = w$n_pre, n_post_years = w$n_post,
  min_valid_pre = min_valid_pre,
  min_valid_post = MIN_VALID_POST,
  farm_mean_diff_pp = round(farm_mean_diff, 4),
  n_px_contrib_farm_28355 = n_contrib_farm,
  n_px_fail_minvalid_tile_28355 = n_fail_tile,
  n_px_fail_minvalid_farm_28355 = n_fail_farm,
  crs_stats = "EPSG:28355 (native; pixel counts internal-support only)"
)
readr::write_csv(summary_tbl, file.path(tables_dir, "task_J_gate2_2018_summary.csv"))

comm_out <- comm |>
  dplyr::transmute(cut_year = CUT_YEAR, community,
                   line = ifelse(is_canonical, "canonical", "residual"),
                   diff_pp = round(diff_pp, 4), n_px_28355)
readr::write_csv(comm_out, file.path(tables_dir, "task_J_gate2_2018_by_community.csv"))

all_checks <- dplyr::bind_rows(
  input_checks |> dplyr::mutate(group = "input"),
  prod_checks  |> dplyr::mutate(group = "product"),
  ondisk_checks
)
readr::write_csv(all_checks, file.path(tables_dir, "task_J_gate2_2018_assertions.csv"))

cat("\nWrote:\n")
cat("  ", file.path(tables_dir, "task_J_gate2_2018_summary.csv"), "\n")
cat("  ", file.path(tables_dir, "task_J_gate2_2018_by_community.csv"), "\n")
cat("  ", file.path(tables_dir, "task_J_gate2_2018_assertions.csv"), "\n")
cat("  ", diff_out, " [gitignored raster]\n")
cat("\n================ GATE 2 COMPLETE — STOP ================\n")
