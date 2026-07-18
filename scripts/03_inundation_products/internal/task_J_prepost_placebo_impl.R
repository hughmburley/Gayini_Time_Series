# ------------------------------------------------------------------------------
# Script: scripts/03_inundation_products/internal/task_J_prepost_placebo_impl.R
# Purpose: Tier 1 · Task J — reusable per-date pre/post inundation-change build,
#          computed NATIVELY on the EPSG:28355 binary annual stack. One function
#          builds one cut date's PRE/POST between-year flood-frequency surfaces
#          and their difference; the Gate 2 single-date driver and the Gate 3
#          placebo ladder both call it, so the window mapping and the 255-nodata
#          discipline live in exactly one place.
# Workflow stage: 03_inundation_products (raster) · Tier 1 Task J · additive
# Load-bearing invariants (verified at Gate 1, re-asserted here):
#   - Layer index for water-year START year C is  C - (base_start - 1)  (1988 -> 1).
#   - annual_wet_any   is {0,1}+NA ;  annual_valid_any is {1}+NA (NO zero).
#   - 255 is nodata and MUST be NA on read; a single 255 into a sum destroys it.
#     Value sets are asserted BEFORE any sum so the fast built-in app("sum") is
#     safe (matches the H3.0 idiom in 11_reproject_annual_stack_8058_nn.R).
# ------------------------------------------------------------------------------

suppressPackageStartupMessages({
  library(terra)
  library(dplyr)
})

# Reuse the sound raster QA primitives from the pre/post helper file
# (gayini_raster_min/max/sum, gayini_raster_non_na_count, gayini_make_check_row).
# NOT reused: gayini_classify_plot_inundation_change() [retired change classes]
#             gayini_add_period_metadata_to_plot_summary() [reaches banned 5-class].
if (!exists("gayini_make_check_row")) {
  source(file.path(
    normalizePath(Sys.getenv("GAYINI_ROOT", getwd()), winslash = "/", mustWork = TRUE),
    "R", "inundation_pre_post_raster_functions.R"
  ))
}

TASKJ_LEGAL_WET   <- c(0L, 1L)   # annual_wet_any legal values (+ NA)
TASKJ_LEGAL_VALID <- c(1L)       # annual_valid_any legal values (+ NA) — NO zero
TASKJ_NODATA      <- 255L


## Value set actually present in a raster (finite, non-NA). Mirrors H3.0. ----
taskj_value_set <- function(r) {
  f <- terra::freq(r, bylayer = FALSE)
  sort(unique(f$value[is.finite(f$value)]))
}


## Window layer indices for a cut year C (labelled by water-year START year). ----
## PRE  = start base_start .. (C-2)   [WY1988-89 .. WY(C-2)-(C-1)]
## TRAN = start C-1                    [WY(C-1)-C]  -- always DROPPED
## POST = start C .. (C+4)             [WY C-(C+1) .. WY(C+4)-(C+5)] -- always 5 yrs
taskj_windows <- function(C, base_start = 1988L, n_layers = 35L) {
  idx <- function(sy) as.integer(sy - (base_start - 1L))   # start-year -> layer index
  pre_years  <- base_start:(C - 2L)
  tran_year  <- C - 1L
  post_years <- C:(C + 4L)

  pre_idx  <- idx(pre_years)
  tran_idx <- idx(tran_year)
  post_idx <- idx(post_years)

  # Feasibility / bounds guard: an off-by-one here would silently shift the window.
  all_idx <- c(pre_idx, tran_idx, post_idx)
  if (min(all_idx) < 1L || max(all_idx) > n_layers) {
    stop(sprintf("taskj_windows(C=%d): layer index out of [1,%d] range (pre %d-%d, tran %d, post %d-%d)",
                 C, n_layers, min(pre_idx), max(pre_idx), tran_idx, min(post_idx), max(post_idx)),
         call. = FALSE)
  }
  # Contiguity guard: PRE then TRAN then POST with the transition sitting between.
  stopifnot(max(pre_idx) + 1L == tran_idx, tran_idx + 1L == min(post_idx),
            length(post_idx) == 5L)

  list(
    pre_idx = pre_idx, tran_idx = tran_idx, post_idx = post_idx,
    pre_years = pre_years, tran_year = tran_year, post_years = post_years,
    n_pre = length(pre_idx), n_post = length(post_idx)
  )
}


## 255-safe per-window counts + masked between-year frequency surface. ----
## Requires the caller to have asserted the value sets first (so app("sum") is safe).
taskj_window_freq <- function(wet_sub, valid_sub, min_valid) {
  wet_count   <- terra::app(wet_sub,   fun = "sum", na.rm = TRUE)   # wet years  (0/1 -> count)
  valid_count <- terra::app(valid_sub, fun = "sum", na.rm = TRUE)   # valid years (1s -> count)
  names(wet_count) <- "wet_year_count"; names(valid_count) <- "valid_year_count"

  freq_raw <- 100 * wet_count / valid_count                        # NA where valid_count == 0
  supported <- terra::ifel(valid_count >= min_valid & valid_count > 0, freq_raw, NA)
  names(supported) <- "inundation_frequency_pct"

  list(inundation_frequency_pct = supported, freq_raw = freq_raw,
       wet_year_count = wet_count, valid_year_count = valid_count)
}


## Build one cut date's PRE/POST surfaces + diff. Native 28355; no reprojection. ----
## min_valid_post: absolute (default 4 of 5). pre_valid_frac: fraction of n_pre (default 0.80).
taskj_build_one_date <- function(wet, valid, C,
                                 min_valid_post = 4L, pre_valid_frac = 0.80,
                                 base_start = 1988L) {
  w <- taskj_windows(C, base_start = base_start, n_layers = terra::nlyr(wet))
  min_valid_pre <- as.integer(ceiling(pre_valid_frac * w$n_pre))

  pre <- taskj_window_freq(wet[[w$pre_idx]],  valid[[w$pre_idx]],  min_valid = min_valid_pre)
  post <- taskj_window_freq(wet[[w$post_idx]], valid[[w$post_idx]], min_valid = min_valid_post)

  diff <- post$inundation_frequency_pct - pre$inundation_frequency_pct
  names(diff) <- "diff_pp"

  list(
    C = C, windows = w, min_valid_pre = min_valid_pre, min_valid_post = min_valid_post,
    pre = pre, post = post, diff = diff
  )
}


## Assertions on the binary INPUTS actually used (value set + wet subset valid). ----
## Reuses gayini_make_check_row so output matches the codebase QA shape.
taskj_assert_inputs <- function(wet_sub, valid_sub, label = "window") {
  wet_vals <- taskj_value_set(wet_sub)
  val_vals <- taskj_value_set(valid_sub)

  chk_wet_legal <- all(wet_vals %in% TASKJ_LEGAL_WET)
  chk_val_legal <- all(val_vals %in% TASKJ_LEGAL_VALID)         # NON-vacuous: must be {1} only
  chk_wet_no255 <- !(TASKJ_NODATA %in% wet_vals)
  chk_val_no255 <- !(TASKJ_NODATA %in% val_vals)

  # wet subset valid: count pixels wet==1 where valid is NA or != 1, summed over
  # the window layers. Vectorised (fast); relies on the value-set checks above.
  # Where wet is observed (==1) it is not NA, so the AND is only TRUE for a real
  # wet-but-not-valid pixel; NA-where-wet-is-NA is dropped by na.rm.
  wnv <- (wet_sub == 1) & (is.na(valid_sub) | valid_sub != 1)
  n_wet_not_valid <- sum(as.numeric(terra::global(wnv, "sum", na.rm = TRUE)[, 1]), na.rm = TRUE)

  dplyr::bind_rows(
    gayini_make_check_row(paste0(label, "__wet_subset_{0,1}+NA"), chk_wet_legal,
      paste0("value set {", paste(wet_vals, collapse = ","), "}"), "stop_if_fail"),
    gayini_make_check_row(paste0(label, "__valid_subset_{1}+NA_no_zero"), chk_val_legal,
      paste0("value set {", paste(val_vals, collapse = ","), "} (asserted =={1}, not {0,1})"), "stop_if_fail"),
    gayini_make_check_row(paste0(label, "__255_absent_from_wet"), chk_wet_no255,
      paste0("255 present as value: ", TASKJ_NODATA %in% wet_vals), "stop_if_fail"),
    gayini_make_check_row(paste0(label, "__255_absent_from_valid"), chk_val_no255,
      paste0("255 present as value: ", TASKJ_NODATA %in% val_vals), "stop_if_fail"),
    gayini_make_check_row(paste0(label, "__wet_subset_valid"), n_wet_not_valid == 0,
      paste0(n_wet_not_valid, " pixels wet-but-not-valid across the window layers"), "stop_if_fail")
  )
}


## Write a raster, RE-READ it from disk, and assert the on-disk distribution. ----
## Gate-1 note A: writes are the hazard (NaN NAflag can leave nodata unset on an
## INT1U file -> L31). Every Task J raster write goes through here so the on-disk
## check is emitted as assertion ROWS (group = "ondisk"), never a prose-only claim.
## Returns the check tibble and the re-read raster.
taskj_write_and_assert <- function(r, path, nodata = -9999, datatype = "FLT4S",
                                   lo = -100, hi = 100, gdal = c("COMPRESS=LZW"),
                                   label = "") {
  pfx <- if (nzchar(label)) paste0("ondisk__", label, "__") else "ondisk__"
  n_na_before <- terra::ncell(r) - gayini_raster_non_na_count(r)
  rng_before  <- as.numeric(terra::minmax(r))

  terra::writeRaster(r, path, overwrite = TRUE, datatype = datatype,
                     NAflag = nodata, gdal = gdal)

  disk <- terra::rast(path)                                  # genuine disk read
  vals <- taskj_value_set(disk)
  n_na_after <- terra::ncell(disk) - gayini_raster_non_na_count(disk)
  rng_after  <- as.numeric(terra::minmax(disk))

  chk_sentinel    <- !(nodata %in% vals)
  chk_na          <- (n_na_before == n_na_after)
  chk_range_bound <- rng_after[1] >= lo - 1e-6 && rng_after[2] <= hi + 1e-6
  chk_range_match <- isTRUE(all.equal(rng_before, rng_after, tolerance = 1e-4))

  checks <- dplyr::bind_rows(
    gayini_make_check_row(paste0(pfx, "sentinel_absent_as_value"), chk_sentinel,
      paste0("nodata ", nodata, " present as value: ", nodata %in% vals), "stop_if_fail"),
    gayini_make_check_row(paste0(pfx, "na_count_preserved"), chk_na,
      paste0(n_na_before, " == ", n_na_after), "stop_if_fail"),
    gayini_make_check_row(paste0(pfx, "range_matches_in_memory"), chk_range_bound && chk_range_match,
      paste0(round(rng_after[1], 3), " .. ", round(rng_after[2], 3)), "stop_if_fail")
  )
  checks$group <- "ondisk"
  list(checks = checks, disk = disk, path = path)
}


## Range assertion — the TRUE structural invariant: -100 <= diff <= 100. ----
## Guaranteed by wet ⊆ valid (freq in [0,100] for both windows). A pixel wet in
## ALL n_pre pre-years (freq_pre = 100) and dry in all 5 post-years (freq_post = 0)
## gives diff = -100, LEGALLY, for any window length. The earlier
## -(n_pre-1)/n_pre*100 floor was NOT a structural bound: it inferred a rule from
## 2018's observed -96.552 and does not hold for short/dry-onset windows (retired
## at Gate-3 sign-off). Window LENGTH/POSITION are checked by taskj_assert_layer_names().
taskj_assert_diff_range <- function(diff, label = "diff") {
  dmin <- gayini_raster_min(diff); dmax <- gayini_raster_max(diff)
  ok <- !is.na(dmin) && dmin >= -100 - 1e-4 && dmax <= 100 + 1e-4
  gayini_make_check_row(paste0(label, "__diff_range_[-100,100]"), ok,
    paste0("observed ", round(dmin, 3), " .. ", round(dmax, 3)), "stop_if_fail")
}


## Raster-window mapping check: tie each layer INDEX to its layer NAME -> water year. ----
## This is the real guard on window POSITION (a shifted raster window is invisible to
## the flow join, which derives q_ratio from the gauge table on both sides). Asserts
## the transition, first-PRE, first-POST and last-POST layer names match the expected
## "startYear-endYear" strings for cut year C.
taskj_assert_layer_names <- function(layer_names, w, label = "map") {
  exp <- function(sy) sprintf("%d-%d", sy, sy + 1L)
  got_tran  <- layer_names[w$tran_idx]
  got_pre1  <- layer_names[min(w$pre_idx)]
  got_post1 <- layer_names[min(w$post_idx)]
  got_postN <- layer_names[max(w$post_idx)]
  ok <- got_tran  == exp(w$tran_year) &&
        got_pre1  == exp(min(w$pre_years)) &&
        got_post1 == exp(min(w$post_years)) &&
        got_postN == exp(max(w$post_years))
  gayini_make_check_row(paste0(label, "__layer_names_map_to_windows"), ok,
    paste0("tran '", got_tran, "'==", exp(w$tran_year),
           " ; PRE1 '", got_pre1, "' ; POST ", got_post1, "..", got_postN), "stop_if_fail")
}


## Assertions on the computed PRODUCTS (the sound checks from the pre/post QA). ----
taskj_assert_products <- function(build) {
  pre <- build$pre; post <- build$post; diff <- build$diff

  pre_min <- gayini_raster_min(pre$inundation_frequency_pct)
  pre_max <- gayini_raster_max(pre$inundation_frequency_pct)
  post_min <- gayini_raster_min(post$inundation_frequency_pct)
  post_max <- gayini_raster_max(post$inundation_frequency_pct)
  diff_min <- gayini_raster_min(diff); diff_max <- gayini_raster_max(diff)

  pre_wet_gt_valid  <- gayini_raster_sum(terra::ifel(pre$wet_year_count  > pre$valid_year_count,  1, 0))
  post_wet_gt_valid <- gayini_raster_sum(terra::ifel(post$wet_year_count > post$valid_year_count, 1, 0))

  pre_freq_wo_valid  <- gayini_raster_sum(terra::ifel(!is.na(pre$inundation_frequency_pct)  & pre$valid_year_count  <= 0, 1, 0))
  post_freq_wo_valid <- gayini_raster_sum(terra::ifel(!is.na(post$inundation_frequency_pct) & post$valid_year_count <= 0, 1, 0))

  dplyr::bind_rows(
    gayini_make_check_row("pre_frequency_range_0_100",  !is.na(pre_min)  && pre_min  >= 0 && pre_max  <= 100,
      paste0("range ", round(pre_min, 3), " .. ", round(pre_max, 3)), "stop_if_fail"),
    gayini_make_check_row("post_frequency_range_0_100", !is.na(post_min) && post_min >= 0 && post_max <= 100,
      paste0("range ", round(post_min, 3), " .. ", round(post_max, 3)), "stop_if_fail"),
    gayini_make_check_row("diff_range_-100_100", !is.na(diff_min) && diff_min >= -100 && diff_max <= 100,
      paste0("range ", round(diff_min, 3), " .. ", round(diff_max, 3)), "stop_if_fail"),
    gayini_make_check_row("pre_wet_years_not_gt_valid",  pre_wet_gt_valid  == 0,
      paste0(pre_wet_gt_valid,  " pixels wet_count > valid_count"), "stop_if_fail"),
    gayini_make_check_row("post_wet_years_not_gt_valid", post_wet_gt_valid == 0,
      paste0(post_wet_gt_valid, " pixels wet_count > valid_count"), "stop_if_fail"),
    gayini_make_check_row("pre_frequency_requires_valid",  pre_freq_wo_valid  == 0,
      paste0(pre_freq_wo_valid,  " pixels have freq but no valid pre years"), "stop_if_fail"),
    gayini_make_check_row("post_frequency_requires_valid", post_freq_wo_valid == 0,
      paste0(post_freq_wo_valid, " pixels have freq but no valid post years"), "stop_if_fail")
  )
}
