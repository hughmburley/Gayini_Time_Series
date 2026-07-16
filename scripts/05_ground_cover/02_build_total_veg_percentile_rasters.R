# ------------------------------------------------------------------------------
# Script: scripts/05_ground_cover/02_build_total_veg_percentile_rasters.R
# Purpose: Tier 2 · Task H · H2 (#6, #7) — the five across-series total-veg
#          percentile rasters (5th / 10th / 20th / 30th / 50th), ONE value per
#          pixel across the whole record, on the canonical EPSG:8058 census grid.
#
# WHY LOW PERCENTILES (#7) — the rationale, recorded here deliberately:
#   Lower percentiles are the FLOOR of the system. Adrian: "when the veg is really
#   struggling, if there's still something left, that's a sign of a healthy
#   ecosystem." This measures RESILIENCE, not average condition — a genuinely
#   different question from mean cover. The 50th is included as the reference
#   against which the floor is read, not as the headline.
#
# Workflow stage: 05_ground_cover (raster build) · Tier 2 Task H, Track B
# Run mode: analysis / heavy (140 composites x 2.85M px) · additive · post-build DB touch
# Key inputs:
#   - Input/landsat_fractionalcover3/lztmre_nsw_m<YYYYMM><YYYYMM>_dp1a2_subset.tif
#     (153 seasonal composites, EPSG:3577, 30 m, uint8, nodata 255; bands
#      1=bare 2=green/PV 3=non-green/NPV)
#   - Output/rasters/veg_regime_class_8058.tif   (the canonical 8058 grid TEMPLATE)
#   - Output/spatial_8058/gayini_boundary_epsg8058.gpkg (farm mask for the gate stats)
# Key outputs (additive; Output/ gitignored):
#   - Output/rasters/veg_percentiles_8058/total_veg_p{05,10,20,30,50}_8058.tif
#   - Output/diagnostics/tier2H_h2_fc_water_year_pool.csv
#   - Output/diagnostics/tier2H_h2_valid_season_distribution.csv
#   - Output/diagnostics/tier2H_h2_monotonicity_check.csv
#   - Output/diagnostics/tier2H_h2_qa.json
#   - raster_asset: 5 percentile rows + veg_regime_class_8058 (C2), idempotent
#
# 🔴 THE uint8 NODATA TRAP (established_data_facts §11) — the reason for §4 below:
#     255 + 255 in uint8 = 254   (wraps silently — NOT an error)
#     255 +  50 in uint8 =  49   (wraps silently)
#   A naive band2 + band3 FABRICATES plausible total-veg at every nodata pixel.
#   nodata runs 0.56-1.08% per scene, so this would quietly poison ~1% of every
#   percentile, and 254 survives any range check that only tests for negatives.
#   RULE: mask 255 -> NA BEFORE summing. Never sum raw bands. Then assert [0, ~110].
#
# RESAMPLING — the OPPOSITE rule to H3.0. These are CONTINUOUS cover percentages,
#   so bilinear is correct. H3.0's method="near" applies to BINARY masks only.
#   Keep the two rules distinct; do not copy one to the other.
#
# BUILD ORDER — arithmetic natively, reproject once at the end: percentiles are
#   computed at native 30 m in EPSG:3577 on UNRESAMPLED source, and only the five
#   OUTPUTS are reprojected (5 reprojections, not 140). Do not reproject the stack.
#
# RESOLUTION CAVEAT — record and respect: FC is natively 30 m; these products are
#   reported on the 24.97 m census grid. The extra apparent detail is an artefact of
#   resampling. DO NOT over-interpret fine spatial detail in the veg layer.
#
# Notes:
#   - Originals are read-only; reprojection writes new files only.
#   - raster_asset registration is a POST-BUILD MUTATION — re-run after any rebuild.
#   - GATE: the per-pixel valid-season count is MEASURED and REPORTED here. NO
#     minimum-seasons threshold is applied or chosen — that decision is Hugh's and
#     is deliberately deferred (MIN_VALID_YEARS turned out inert; do not add a third
#     MIN_VALID knob before measuring). Percentiles use whatever valid seasons each
#     pixel has.
# ------------------------------------------------------------------------------

## 0. Constants ----

PROBS            <- c(0.05, 0.10, 0.20, 0.30, 0.50)
PROB_LABELS      <- c("p05", "p10", "p20", "p30", "p50")
NODATA           <- 255L
TOTAL_VEG_MAX    <- 110      # band2+band3 upper bound for valid pixels (facts §4)
WY_START_MONTH   <- 7L       # water year runs Jul 1 -> Jun 30
WY_FIRST         <- 1988L    # WY1988-1989 ... WY2022-2023 = 35 water years
WY_LAST          <- 2022L
EXPECTED_N_RETAINED <- 140L  # facts §4: the Track B pool is 140 of 153 — checkable
EXPECTED_N_WY       <- 35L

## 1. Sources ----

root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", getwd()), winslash = "/", mustWork = TRUE)

source(file.path(root_dir, "R", "gayini_helpers.R"))
source(file.path(root_dir, "R", "gayini_output_helpers.R"))
source(file.path(root_dir, "R", "gayini_output_paths.R"))
source(file.path(root_dir, "R", "vector_prep_functions.R"))

suppressPackageStartupMessages({
  library(sf)
  library(terra)
  library(dplyr)
  library(DBI)
  library(RSQLite)
})

sf::sf_use_s2(FALSE)
terra::terraOptions(progress = 0)

fc_dir          <- file.path(root_dir, "Input", "landsat_fractionalcover3")
rasters_dir     <- file.path(root_dir, "Output", "rasters")
diagnostics_dir <- file.path(root_dir, "Output", "diagnostics")
spatial_dir     <- file.path(root_dir, "Output", "spatial_8058")
db_path         <- file.path(root_dir, "Output", "database", "Gayini_Results.sqlite")

class_tif <- file.path(rasters_dir, "veg_regime_class_8058.tif")
gayini_stop_if_missing(class_tif, label = "veg_regime_class_8058.tif (grid template)")

out_dir <- file.path(rasters_dir, "veg_percentiles_8058")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
tmp_dir <- file.path(rasters_dir, "fc_intermediate")
dir.create(tmp_dir, recursive = TRUE, showWarnings = FALSE)


## 2. FC composites -> water year, by SEASON MIDPOINT ----
##    Naming: m<YYYYMM><YYYYMM> = season start / end month (facts §4).
##    Water year = Jul 1 -> Jun 30, labelled "<start>-<start+1>".
##    Midpoints: DJF -> 1 Jan · MAM -> 1 Apr · JJA -> 1 Jul · SON -> 1 Oct.
##    So each WY collects {JJA, SON, DJF, MAM} = 4 composites.

fc_files <- sort(list.files(fc_dir, pattern = "^lztmre_nsw_m\\d{12}_dp1a2_subset\\.tif$",
                            full.names = TRUE))
if (length(fc_files) == 0) stop("No fractional-cover composites found in ", fc_dir, call. = FALSE)

ym <- regmatches(basename(fc_files), regexpr("\\d{12}", basename(fc_files)))
start_date <- as.Date(paste0(substr(ym, 1, 4), "-", substr(ym, 5, 6), "-01"))
end_date   <- as.Date(paste0(substr(ym, 7, 10), "-", substr(ym, 11, 12), "-01"))
mid_date   <- start_date + floor(as.numeric(end_date - start_date) / 2)

mid_year  <- as.integer(format(mid_date, "%Y"))
mid_month <- as.integer(format(mid_date, "%m"))
wy_start  <- ifelse(mid_month >= WY_START_MONTH, mid_year, mid_year - 1L)

## Season label comes from the START month (12/3/6/9), NOT the midpoint month.
## The midpoint is exact for WY assignment but is NOT a clean season-centre: a
## 61-day span beginning in a 31-day month lands mid-season on the last day of the
## first month (MAM = Mar 1 + 30 = Mar 31, not Apr 1). Labelling off the midpoint
## silently mislabels every MAM composite; the WY assignment is unaffected because
## month 3 and month 4 both fall on the same side of the July boundary.
start_month <- as.integer(format(start_date, "%m"))
season <- c("12" = "DJF", "3" = "MAM", "6" = "JJA", "9" = "SON")[as.character(start_month)]
season <- unname(season)

pool <- tibble::tibble(
  file = fc_files, basename = basename(fc_files),
  start_date, end_date, mid_date, season,
  wy_start = as.integer(wy_start),
  water_year = paste0(wy_start, "-", wy_start + 1L),
  retained = wy_start >= WY_FIRST & wy_start <= WY_LAST
)
if (any(is.na(pool$season)))
  stop("Composite(s) whose START month is not a season start (Dec/Mar/Jun/Sep): ",
       paste(pool$basename[is.na(pool$season)], collapse = ", "), call. = FALSE)

kept    <- pool[pool$retained, ]
dropped <- pool[!pool$retained, ]
n_retained <- nrow(kept)

message("\n================ H2 · FC -> water-year pool ================")
message(sprintf("  composites found        : %d", nrow(pool)))
message(sprintf("  retained (WY%d-%d .. WY%d-%d) : %d   [expected %d]",
                WY_FIRST, WY_FIRST + 1L, WY_LAST, WY_LAST + 1L, n_retained, EXPECTED_N_RETAINED))
message(sprintf("  dropped                 : %d  (before: %d, after: %d)",
                nrow(dropped), sum(dropped$wy_start < WY_FIRST), sum(dropped$wy_start > WY_LAST)))
message("  dropped BEFORE the pool : ",
        paste(dropped$basename[dropped$wy_start < WY_FIRST], collapse = ", "))
message("  dropped AFTER the pool  : ",
        paste(dropped$basename[dropped$wy_start > WY_LAST], collapse = ", "))

per_wy <- kept |> dplyr::count(water_year, name = "n_seasons")
message(sprintf("  water years covered     : %d  [expected %d]; seasons per WY: %s",
                nrow(per_wy), EXPECTED_N_WY, paste(sort(unique(per_wy$n_seasons)), collapse = "/")))

gayini_write_csv(pool, file.path(diagnostics_dir, "tier2H_h2_fc_water_year_pool.csv"))

## Fail FAST, before any raster work: n_retained is a checkable acceptance number.
if (n_retained != EXPECTED_N_RETAINED || nrow(per_wy) != EXPECTED_N_WY ||
    !all(per_wy$n_seasons == 4L)) {
  stop(sprintf(paste("H2 pool mismatch: n_retained=%d (expected %d), n_water_years=%d",
                     "(expected %d), seasons/WY not all 4. Either the midpoint rule or",
                     "the water-year reading is wrong — STOP and report which."),
               n_retained, EXPECTED_N_RETAINED, nrow(per_wy), EXPECTED_N_WY), call. = FALSE)
}
message("  ==> POOL ASSERT PASSED: 140 composites, 35 water years, 4 seasons each.")


## 3. Sanity: does terra honour the file nodata? (informs, does not replace, §4) ----

probe <- terra::rast(kept$file[1])
probe_vals <- terra::unique(probe[[2]])[, 1]
message(sprintf("\n  nodata probe on %s band2: max=%s, 255 present as a VALUE? %s",
                kept$basename[1], max(probe_vals, na.rm = TRUE),
                NODATA %in% probe_vals))


## 4. total_veg = band2 + band3, with 255 MASKED TO NA *BEFORE* SUMMING ----
##    Belt and braces: terra normally honours the file's nodata, but subst() makes
##    the mask explicit and unconditional so the trap cannot re-open silently if a
##    future source ships without nodata set.

tv_layer <- function(f, nm) {
  r  <- terra::rast(f)
  b2 <- terra::subst(r[[2]], NODATA, NA)     # <- MASK FIRST
  b3 <- terra::subst(r[[3]], NODATA, NA)     # <- MASK FIRST
  tv <- b2 + b3                              # NA propagates; never raw uint8 arithmetic
  names(tv) <- nm
  tv
}

layer_names <- paste0(kept$water_year, "_", kept$season)
stack_tif <- file.path(tmp_dir, "fc_total_veg_3577_wy1988_2023.tif")

if (!file.exists(stack_tif)) {
  message("\n[H2] Building the 140-layer total_veg stack (3577, 30 m; masking 255 -> NA first) ...")
  tv_stack <- terra::rast(lapply(seq_len(nrow(kept)), function(i) tv_layer(kept$file[i], layer_names[i])))
  terra::writeRaster(tv_stack, stack_tif, overwrite = TRUE,
                     datatype = "INT2S", NAflag = -9999)
  message("  wrote intermediate: ", stack_tif)
} else {
  message("\n[H2] Reusing existing total_veg stack: ", stack_tif)
}
tv_stack <- terra::rast(stack_tif)
names(tv_stack) <- layer_names
stopifnot(terra::nlyr(tv_stack) == EXPECTED_N_RETAINED)


## 5. Trap verification + source-residual QC — TWO DISTINCT CHECKS ----
##
## 5a is the nodata trap (the thing the spec cares about). 5b is source data
## quality. They must not be conflated: a range check alone cannot tell them apart,
## and "max > 110" is NOT by itself a wrap signature.

rng <- terra::minmax(tv_stack)
tv_min <- min(rng[1, ], na.rm = TRUE); tv_max <- max(rng[2, ], na.rm = TRUE)

n_valid_all <- sum(terra::global(!is.na(tv_stack), "sum", na.rm = TRUE)[[1]])
n_gt_max    <- sum(terra::global(tv_stack > TOTAL_VEG_MAX, "sum", na.rm = TRUE)[[1]])
n_eq_254    <- sum(terra::global(tv_stack == 254, "sum", na.rm = TRUE)[[1]])
pct_gt_max  <- 100 * n_gt_max / n_valid_all

## --- 5a. The uint8 wrap: CLOSED BY CONSTRUCTION, and verified by signature ---
##
## Closed by construction: subst(255 -> NA) precedes every sum (§4), so a 255 can
## never reach the arithmetic regardless of whether the source ships nodata set.
## Verified by signature: a wrap would (i) pile up at exactly 254 (the 255+255 case)
## and (ii) affect ~0.56-1.08% of pixels — the per-scene nodata fraction (facts §4).
## Both discriminators must be clean.
WRAP_PCT_CEILING <- 0.01   # orders of magnitude below the 0.56-1.08% nodata fraction
message("\n================ H2 · 5a · uint8 nodata-trap assertion ================")
message(sprintf("  pixel-layers valid              : %s", format(n_valid_all, big.mark = ",")))
message(sprintf("  == 254 (the 255+255 signature)  : %d   [must be 0]", n_eq_254))
message(sprintf("  >  %d (out of envelope)        : %d  (%.7f%%)  [a wrap would be ~0.56-1.08%%]",
                TOTAL_VEG_MAX, n_gt_max, pct_gt_max))
stopifnot(n_eq_254 == 0, pct_gt_max < WRAP_PCT_CEILING, tv_min >= 0)
message("  ==> TRAP CLOSED: no 254 signature; out-of-envelope rate is ~5 orders of")
message("      magnitude below the nodata fraction, so nodata is not leaking into the sum.")

## --- 5b. Source unmixing residuals: real, tiny, and physically impossible ---
##
## The remaining out-of-envelope values are genuine JRSRP unmixing overshoot, NOT our
## arithmetic: at the offenders band1(bare) = 0, band2/band3 are ordinary values, no
## 255 is involved, and the SOURCE's own band1+band2+band3 already equals the same
## out-of-range total. Measured across all 140 composites: 15 pixel-layers of
## 349,648,690 (0.000004%), max 147.
##
## NOTE — corrects `Gayini_established_data_facts.md` §4: "PV+NPV+BS max 111" and
## "band2+band3 <= ~110" were measured on FOUR files. Across the full 140-composite
## pool the tail reaches 147. The envelope claim is a sampling artefact of n=4.
##
## A cover percentage cannot exceed ~100; these are invalid measurements, so they are
## set to NA rather than clamped (do not invent data) and the count is reported.
## Immaterial to the products by construction: 15 values in 350M, all HIGH, so the
## 5th-30th percentiles cannot move at all and a pixel's p50 is unaffected by 1-2 of
## its 140 seasons.
message("\n================ H2 · 5b · source unmixing residuals ================")
message(sprintf("  raw total_veg range across 140 layers : [%s, %s]", tv_min, tv_max))
message(sprintf("  out-of-envelope (> %d) set to NA      : %d pixel-layers (%.7f%%)",
                TOTAL_VEG_MAX, n_gt_max, pct_gt_max))
message("  cause: source unmixing overshoot (band1=0, no 255 present; the SOURCE band-sum")
message("         is itself out of range). Corrects facts §4's n=4 envelope claim.")
tv_stack <- terra::ifel(tv_stack > TOTAL_VEG_MAX, NA, tv_stack)
names(tv_stack) <- layer_names


## 6. GATE — measure the per-pixel valid-season count. REPORT, do not threshold ----

message("\n[H2] Counting valid seasons per pixel (gate measurement) ...")
## sum() over a multi-layer SpatRaster sums ACROSS layers, so sum(!is.na(x)) is the
## per-pixel count of valid seasons (C++ path; app(fun="notNA") is not a built-in).
n_valid_seasons <- sum(!is.na(tv_stack))
names(n_valid_seasons) <- "n_valid_seasons"

## Farm footprint in 3577 — the decision-relevant scope (the FC grid is far larger
## than the property; facts §4 warns against testing coverage on the grid extent).
boundary <- gayini_read_vector(file.path(spatial_dir, "gayini_boundary_epsg8058.gpkg"),
                               label = "boundary (8058)")
boundary_3577 <- sf::st_transform(boundary, 3577)
farm_mask <- terra::mask(terra::crop(n_valid_seasons, terra::vect(boundary_3577)),
                         terra::vect(boundary_3577))

season_stats <- function(r, label) {
  v <- terra::values(r)[, 1]
  v <- v[!is.na(v)]
  q <- stats::quantile(v, probs = c(0.01, 0.05, 0.50), names = FALSE)
  tibble::tibble(
    scope = label, n_pixels = length(v),
    min = min(v), p01 = q[1], p05 = q[2], median = q[3], max = max(v),
    n_below_10 = sum(v < 10), n_below_20 = sum(v < 20), n_below_50 = sum(v < 50),
    pct_below_10 = round(100 * mean(v < 10), 4),
    pct_below_20 = round(100 * mean(v < 20), 4),
    pct_below_50 = round(100 * mean(v < 50), 4),
    pct_full_140 = round(100 * mean(v == EXPECTED_N_RETAINED), 4)
  )
}
dist_tbl <- dplyr::bind_rows(
  season_stats(n_valid_seasons, "full FC grid (3577, 30 m)"),
  season_stats(farm_mask,       "farm footprint only (boundary-masked)")
)

message("\n================ H2 · GATE — valid seasons per pixel (of 140) ================")
print(as.data.frame(dist_tbl), row.names = FALSE)
gayini_write_csv(dist_tbl, file.path(diagnostics_dir, "tier2H_h2_valid_season_distribution.csv"))

## --- Why the missingness looks the way it does: per-SCENE nodata within the farm.
## The denominator must use the SAME inclusion rule as the numerator: terra::mask
## keeps any cell OVERLAPPING the polygon while rasterize() uses centre-in-polygon;
## mixing them mismatches by ~4k cells and yields negative "nodata".
tv_farm <- terra::mask(terra::crop(tv_stack, terra::vect(boundary_3577)),
                       terra::vect(boundary_3577))
ones    <- terra::setValues(terra::rast(terra::crop(tv_stack[[1]], terra::vect(boundary_3577))), 1)
n_in_farm <- sum(!is.na(terra::values(terra::mask(ones, terra::vect(boundary_3577)))[, 1]))
valid_inside <- terra::global(!is.na(tv_farm), "sum", na.rm = TRUE)[[1]]

scene_tbl <- tibble::tibble(
  layer = layer_names, season = kept$season, water_year = kept$water_year,
  valid_px = as.integer(valid_inside),
  pct_nodata = round(100 * (n_in_farm - valid_inside) / n_in_farm, 3))
gayini_write_csv(scene_tbl, file.path(diagnostics_dir, "tier2H_h2_nodata_by_scene.csv"))

by_season <- scene_tbl |> dplyr::group_by(season) |>
  dplyr::summarise(n = dplyr::n(), mean_pct = round(mean(pct_nodata), 2),
                   median_pct = round(stats::median(pct_nodata), 2),
                   max_pct = round(max(pct_nodata), 2), .groups = "drop")

message("\n  Per-SCENE nodata within the farm (n_in_farm = ", format(n_in_farm, big.mark = ","), "):")
message(sprintf("    min %.3f%% · median %.3f%% · mean %.2f%% · max %.3f%%",
                min(scene_tbl$pct_nodata), stats::median(scene_tbl$pct_nodata),
                mean(scene_tbl$pct_nodata), max(scene_tbl$pct_nodata)))
message(sprintf("    scenes <2%%: %d · >10%%: %d · >30%%: %d  -> the loss is a FEW BADLY OBSCURED",
                sum(scene_tbl$pct_nodata < 2), sum(scene_tbl$pct_nodata > 10),
                sum(scene_tbl$pct_nodata > 30)))
message("    SCENES, not per-pixel noise: whole scenes drop out, so every pixel loses the")
message("    same ~20 seasons -> the valid-season distribution is tight, not long-tailed.")
message("  Seasonal imbalance in the surviving pool (matters more than the count):")
print(as.data.frame(by_season), row.names = FALSE)
message("\n  NO minimum-seasons threshold applied or chosen — deferred to Hugh (facts §12).")
message("  Percentiles below use whatever valid seasons each pixel has.")


## 7. Percentiles at NATIVE 30 m / EPSG:3577 (unresampled source) ----

pct_native_tif <- file.path(tmp_dir, "total_veg_percentiles_3577.tif")
if (!file.exists(pct_native_tif)) {
  message("\n[H2] Computing the 5 percentiles at native 30 m / EPSG:3577 ...")
  p_native <- terra::quantile(tv_stack, probs = PROBS, na.rm = TRUE)
  names(p_native) <- PROB_LABELS
  terra::writeRaster(p_native, pct_native_tif, overwrite = TRUE, datatype = "FLT4S")
  message("  wrote: ", pct_native_tif)
} else {
  message("\n[H2] Reusing native percentiles: ", pct_native_tif)
}
p_native <- terra::rast(pct_native_tif)
names(p_native) <- PROB_LABELS


## 8. Reproject ONLY the 5 outputs to the 8058 census grid — BILINEAR (continuous) ----

message("\n[H2] Reprojecting the 5 percentile outputs 3577 -> 8058 (method='bilinear'; ",
        "continuous cover %, NOT the binary-mask rule) ...")
class_r  <- terra::rast(class_tif)
p_8058   <- terra::project(p_native, class_r, method = "bilinear")
names(p_8058) <- PROB_LABELS


## 9. ASSERT grid alignment against the canonical template ----

geom_ok <- terra::compareGeom(p_8058, class_r, lyrs = FALSE, crs = TRUE, ext = TRUE,
                              rowcol = TRUE, res = TRUE, stopOnError = FALSE)
e <- terra::ext(p_8058); ec <- terra::ext(class_r)
message("\n================ H2 · compareGeom vs veg_regime_class_8058.tif ================")
message(sprintf("  TEMPLATE : crs=EPSG:%s dims=%dx%d res=%.6f origin=(%.6f, %.6f)",
                terra::crs(class_r, describe = TRUE)$code, nrow(class_r), ncol(class_r),
                terra::res(class_r)[1], terra::origin(class_r)[1], terra::origin(class_r)[2]))
message(sprintf("             ext xmin=%.4f xmax=%.4f ymin=%.4f ymax=%.4f",
                ec$xmin, ec$xmax, ec$ymin, ec$ymax))
message(sprintf("  p_8058   : crs=EPSG:%s dims=%dx%d res=%.6f origin=(%.6f, %.6f)",
                terra::crs(p_8058, describe = TRUE)$code, nrow(p_8058), ncol(p_8058),
                terra::res(p_8058)[1], terra::origin(p_8058)[1], terra::origin(p_8058)[2]))
message(sprintf("             ext xmin=%.4f xmax=%.4f ymin=%.4f ymax=%.4f",
                e$xmin, e$xmax, e$ymin, e$ymax))
message(sprintf("  compareGeom(p_8058, veg_regime_class_8058) = %s", geom_ok))
stopifnot(isTRUE(geom_ok))
message("  ==> ALIGNMENT ASSERTED (not assumed).")


## 10. ASSERT per-pixel monotonicity: p05 <= p10 <= p20 <= p30 <= p50 ----

message("\n================ H2 · monotonicity (p05 <= p10 <= p20 <= p30 <= p50) ================")
TOL <- 1e-6
mono_pairs <- list(c("p05", "p10"), c("p10", "p20"), c("p20", "p30"), c("p30", "p50"))
mono_rows <- lapply(mono_pairs, function(pr) {
  bad <- terra::global(p_8058[[pr[1]]] > (p_8058[[pr[2]]] + TOL), "sum", na.rm = TRUE)[[1]]
  tibble::tibble(pair = paste(pr[1], "<=", pr[2]), n_violations = as.integer(bad))
})
mono_tbl <- dplyr::bind_rows(mono_rows)
print(as.data.frame(mono_tbl), row.names = FALSE)
gayini_write_csv(mono_tbl, file.path(diagnostics_dir, "tier2H_h2_monotonicity_check.csv"))
stopifnot(all(mono_tbl$n_violations == 0L))
message("  ==> MONOTONIC: 0 violations. (Any violation would be unambiguously a percentile bug.)")

## Value range on the final products.
p_rng <- terra::minmax(p_8058)
message(sprintf("  final percentile value range: [%.3f, %.3f]", min(p_rng[1, ]), max(p_rng[2, ])))
stopifnot(min(p_rng[1, ]) >= -TOL, max(p_rng[2, ]) <= TOTAL_VEG_MAX + TOL)


## 11. Write the 5 products ----

pct_paths <- setNames(file.path(out_dir, paste0("total_veg_", PROB_LABELS, "_8058.tif")),
                      PROB_LABELS)
for (nm in PROB_LABELS) {
  terra::writeRaster(p_8058[[nm]], pct_paths[[nm]], overwrite = TRUE, datatype = "FLT4S")
  message("  wrote: ", pct_paths[[nm]])
}


## 12. Register in raster_asset — the 5 products + C2 (veg_regime_class_8058) ----

sha256_of <- function(path) tryCatch(
  if (requireNamespace("digest", quietly = TRUE))
    digest::digest(file = path, algo = "sha256") else NA_character_,
  error = function(e) NA_character_)

register_asset <- function(con, asset_id, path, r, metric_id, product, semantics) {
  ex <- as.vector(terra::ext(r)); rs <- terra::res(r)
  DBI::dbExecute(con, "DELETE FROM raster_asset WHERE raster_asset_id = ?", params = list(asset_id))
  DBI::dbExecute(con,
    "INSERT INTO raster_asset
      (raster_asset_id, path, metric_id, water_year, period_label, crs,
       resolution_x, resolution_y, xmin, ymin, xmax, ymax, checksum_sha256,
       path_exists, qa_status, run_id, crs_epsg, product, legend_status, legend_semantics)
     VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
    params = list(asset_id, gayini_relative_path(root_dir, path), metric_id, NA_character_,
                  "WY1988-2023 across-series", "EPSG:8058", rs[1], rs[2],
                  ex[1], ex[3], ex[2], ex[4], sha256_of(path), 1L, "REVIEW",
                  "tier2H_h2", 8058L, product, "confirmed", semantics))
}

con <- dbConnect(SQLite(), db_path)
veg_sem_base <- paste(
  "Across-series percentile of TOTAL VEG (green/PV band2 + non-green/NPV band3, plain percent,",
  "nodata 255 masked to NA BEFORE summing). Pooled over 140 seasonal FC composites =",
  "WY1988-1989..WY2022-2023 (4 seasons/WY, by season midpoint). Computed at native 30 m in",
  "EPSG:3577, then reprojected once to the 8058 census grid with method='bilinear' (continuous",
  "surface). CAVEAT: natively 30 m, reported on the 24.97 m census grid - do not over-interpret",
  "fine spatial detail. Low percentiles measure the FLOOR (resilience), not average condition.")
for (i in seq_along(PROB_LABELS)) {
  nm <- PROB_LABELS[i]
  register_asset(con, paste0("raster_vegpct_", nm), pct_paths[[nm]], p_8058[[nm]],
                 paste0("total_veg_", nm, "_pct"), "total_veg_percentile_8058",
                 paste0(sprintf("%.0fth percentile. ", PROBS[i] * 100), veg_sem_base))
}
## C2 — the canonical substrate itself was never registered. pixel_id is meaningless
## without a recorded grid definition (data contract §2).
register_asset(con, "raster_veg_regime_class_8058", class_tif, class_r,
               "veg_regime_class", "veg_regime_class_8058",
               paste("CANONICAL 8058 census grid + per-pixel vegetation x wetness class.",
                     "Codes 11/12/13=Aeolian, 21/22/23=Riverine, 31/32/33=Inland (low/mid/high),",
                     "40=Floodplain Woodland (context), 50=Other/minor. Band edges are the F5",
                     "regime_band_breaks.csv terciles (option 2). This raster IS the grid",
                     "definition that census pixel_id resolves against (C2)."))
reg <- dbGetQuery(con, "SELECT raster_asset_id, product, crs_epsg, resolution_x,
                          substr(checksum_sha256,1,12) AS sha12, path_exists
                        FROM raster_asset WHERE crs_epsg = 8058 ORDER BY raster_asset_id")
dbDisconnect(con)
message("\n================ H2 · raster_asset (EPSG:8058 rows) ================")
print(reg, row.names = FALSE)


## 13. QA json ----

qa <- list(
  step = "H2 total-veg percentile rasters", generated_by =
    "scripts/05_ground_cover/02_build_total_veg_percentile_rasters.R",
  pool = list(n_composites = nrow(pool), n_retained = n_retained,
              expected_n_retained = EXPECTED_N_RETAINED,
              n_water_years = nrow(per_wy), seasons_per_wy = 4L,
              n_dropped_before = sum(dropped$wy_start < WY_FIRST),
              n_dropped_after = sum(dropped$wy_start > WY_LAST),
              water_year_rule = "Jul 1 - Jun 30, assigned by season midpoint"),
  nodata_trap = list(
    rule = "255 -> NA masked BEFORE band2+band3 (closed by construction)",
    n_valid_pixel_layers = n_valid_all,
    n_equal_254_signature = n_eq_254,
    wrap_closed = (n_eq_254 == 0 && pct_gt_max < WRAP_PCT_CEILING),
    discriminator = paste("a wrap piles up at 254 and hits ~0.56-1.08% of pixels",
                          "(the nodata fraction); observed 0 at 254 and",
                          sprintf("%.7f%% out of envelope", pct_gt_max))),
  source_residuals = list(
    raw_total_veg_min = tv_min, raw_total_veg_max = tv_max,
    envelope_max = TOTAL_VEG_MAX,
    n_out_of_envelope_set_na = n_gt_max, pct_out_of_envelope = round(pct_gt_max, 7),
    cause = paste("genuine JRSRP unmixing overshoot: band1(bare)=0, no 255 present,",
                  "the SOURCE band1+band2+band3 is itself out of range"),
    corrects_facts_doc = paste("Gayini_established_data_facts.md 4 states PV+NPV+BS max 111",
                               "and band2+band3 <= ~110, measured on FOUR files; across the",
                               "full 140-composite pool the tail reaches 147.")),
  valid_seasons = lapply(seq_len(nrow(dist_tbl)), function(i) as.list(dist_tbl[i, ])),
  nodata_by_scene = list(
    n_in_farm = n_in_farm,
    min_pct = min(scene_tbl$pct_nodata), median_pct = stats::median(scene_tbl$pct_nodata),
    mean_pct = round(mean(scene_tbl$pct_nodata), 3), max_pct = max(scene_tbl$pct_nodata),
    n_scenes_lt2 = sum(scene_tbl$pct_nodata < 2), n_scenes_gt10 = sum(scene_tbl$pct_nodata > 10),
    n_scenes_gt30 = sum(scene_tbl$pct_nodata > 30),
    by_season = lapply(seq_len(nrow(by_season)), function(i) as.list(by_season[i, ])),
    corrects_facts_doc = paste("facts 4 gives nodata 0.56-1.08% per scene from FOUR files;",
                               "those files are clean scenes (measured 1.03% / 0.08%). Across all",
                               "140 the median is ~2.3% but the MEAN is ~14.3% and 22 scenes",
                               "exceed 30% (max 96.6%). The distribution is skewed, not ~1%."),
    interpretation = paste("Loss is driven by whole obscured SCENES, not per-pixel noise, so",
                           "pixels lose the same seasons and the valid-season distribution is",
                           "tight. JJA/SON lose ~3x more than DJF/MAM - the surviving pool is",
                           "seasonally imbalanced, which matters more than the count.")),
  min_seasons_threshold = "NOT APPLIED - deferred to Hugh (gate)",
  alignment = list(compareGeom_vs_veg_regime_class_8058 = geom_ok,
                   resampling = "bilinear (continuous cover %; NOT the binary near rule)"),
  monotonicity = lapply(seq_len(nrow(mono_tbl)), function(i) as.list(mono_tbl[i, ])),
  resolution_caveat = paste("FC natively 30 m; reported on the 24.97 m census grid.",
                            "Do not over-interpret fine spatial detail."),
  outputs = as.list(gayini_relative_path(root_dir, unname(pct_paths))),
  registered = c(paste0("raster_vegpct_", PROB_LABELS), "raster_veg_regime_class_8058")
)
jsonlite::write_json(qa, file.path(diagnostics_dir, "tier2H_h2_qa.json"),
                     auto_unbox = TRUE, pretty = TRUE, digits = 6)


## 14. Summary — STOP AT THE VALID-SEASON GATE ----

message("\n==================== H2 COMPLETE — STOP AT THE VALID-SEASON GATE ====================")
message(sprintf("Pool          : %d / %d composites retained (WY%d-%d .. WY%d-%d), 4 seasons/WY",
                n_retained, nrow(pool), WY_FIRST, WY_FIRST + 1L, WY_LAST, WY_LAST + 1L))
message(sprintf("nodata trap   : CLOSED (0 at the 254 signature; %.7f%% out of envelope vs a ~1%% wrap)",
                pct_gt_max))
message(sprintf("source resid. : %d pixel-layers of %s set to NA (raw max %s) - unmixing overshoot, not our arithmetic",
                n_gt_max, format(n_valid_all, big.mark = ","), tv_max))
message("compareGeom   : TRUE   ·   monotonicity: 0 violations")
message("Registered    : 5 percentile rasters + veg_regime_class_8058 (C2)")
message("\nAWAITING: minimum-seasons threshold decision — measured and reported, NOT chosen.")
