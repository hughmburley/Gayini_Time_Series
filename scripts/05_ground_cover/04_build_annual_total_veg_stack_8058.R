# ------------------------------------------------------------------------------
# Script: scripts/05_ground_cover/04_build_annual_total_veg_stack_8058.R
# Purpose: Tier 2 · Task H · Gate E (G1a) — the per-pixel-per-YEAR total-veg stack
#          on the canonical EPSG:8058 census grid. This is the RESPONSE axis for
#          the per-pixel same-year veg x wet-extent response (G1b); it does not
#          yet exist on disk (only the 5 across-series percentile SUMMARIES do).
#
#          Reduces the existing 140-layer seasonal FC total-veg stack (35 water
#          years x 4 seasons, 3577, 30 m) to 35 annual layers, TWO ways, and
#          reports the robustness delta between them rather than committing blind:
#            (A) mean-of-available-seasons  — the natural "same-year cover"
#            (B) fixed growing-season       — mean of JJA + SON only (§6b)
#          Both are computed at native 30 m / 3577, then reprojected ONCE to the
#          8058 census grid with method="bilinear" (continuous cover %, NOT the
#          binary-mask near rule). compareGeom-asserted against the canonical grid.
#
# Workflow stage: 05_ground_cover (raster build) · Tier 2 Task H, Gate E, G1a
# Run mode: analysis / heavy (140-layer reduce + 2x35-layer reproject) · additive · read-only DB
# Key inputs:
#   - Output/rasters/fc_intermediate/fc_total_veg_3577_wy1988_2023.tif   (140 lyr, 3577, 30 m;
#         layer names "<WY>_<season>", built by 02_build_total_veg_percentile_rasters.R §4;
#         WKT is GDA94 Australian Albers CM132 = EPSG:3577 but carries NO authority code -> assigned)
#   - Output/diagnostics/tier2H_h2_fc_water_year_pool.csv                (WY/season provenance, cross-check)
#   - Output/rasters/veg_regime_class_8058.tif                           (canonical 8058 grid TEMPLATE + census footprint)
# Key outputs (additive; Output/ gitignored; NOT registered here — registration is G7, non-destructive):
#   - Output/rasters/veg_annual_8058/total_veg_annual_mean_8058.tif      (35 lyr, 8058; reduction A)
#   - Output/rasters/veg_annual_8058/total_veg_annual_jja_son_8058.tif   (35 lyr, 8058; reduction B)
#   - Output/diagnostics/tier2H_g1a_annual_veg_valid_seasons.csv         (per-WY seasonal coverage caveat)
#   - Output/diagnostics/tier2H_g1a_annual_veg_reduction_delta.csv       (per-WY A-vs-B robustness delta)
#   - Output/diagnostics/tier2H_g1a_qa.json
#
# CAVEATS carried by construction:
#   - SEASONAL COMPOSITION (facts §6b): JJA/SON is the winter-spring GROWING season and is
#     the UNDER-observed half (JJA 20.7% / SON 21.3% nodata vs DJF 8.4% / MAM 6.9%). So (A) mean-
#     of-available-seasons inherits year-to-year seasonal-composition noise, and (B) JJA/SON thins
#     in cloudy years. The per-WY valid-season table makes this visible; neither is "the" answer
#     until the robustness delta is read. This is why the temporal response may be noisier than the
#     clean cross-sectional POC curve.
#   - RESOLUTION (facts §11): FC is natively 30 m; reported on the 24.97 m census grid. Do not
#     over-interpret fine spatial detail introduced by bilinear resampling.
#   - CRS: assign EPSG:3577 to the intermediate BEFORE reprojecting (lossless — the WKT is already
#     GDA94 Albers CM132). Same lossless-assign pattern as 05_build_unified_annual_stack_impl.R.
#   - This gate STOPS at the built stacks. The response raster (G1b) is a separate, later step.
# ------------------------------------------------------------------------------

## 0. Constants ----

SRC_EPSG          <- "EPSG:3577"          # lossless assign onto the intermediate (untagged GDA94 Albers)
TOTAL_VEG_MAX     <- 110                  # valid-pixel envelope (facts §4); >envelope is source overshoot
EXPECTED_N_WY     <- 35L
EXPECTED_N_SEASON <- 140L
SEASONS_GROWING   <- c("JJA", "SON")      # the winter-spring growing season (facts §6b)
FOCUS_CODES       <- c(11L, 12L, 13L, 21L, 22L, 23L, 31L, 32L, 33L)  # census focus strata (footprint for the delta)


## 1. Sources ----

root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", getwd()), winslash = "/", mustWork = TRUE)

source(file.path(root_dir, "R", "gayini_helpers.R"))
source(file.path(root_dir, "R", "gayini_output_helpers.R"))
source(file.path(root_dir, "R", "gayini_output_paths.R"))

suppressPackageStartupMessages({
  library(terra)
  library(dplyr)
})
terra::terraOptions(progress = 0)

rasters_dir     <- file.path(root_dir, "Output", "rasters")
diagnostics_dir <- file.path(root_dir, "Output", "diagnostics")

stack_tif <- file.path(rasters_dir, "fc_intermediate", "fc_total_veg_3577_wy1988_2023.tif")
class_tif <- file.path(rasters_dir, "veg_regime_class_8058.tif")
pool_csv  <- file.path(diagnostics_dir, "tier2H_h2_fc_water_year_pool.csv")
for (p in c(stack_tif, class_tif, pool_csv))
  gayini_stop_if_missing(p, label = basename(p))

out_dir <- file.path(rasters_dir, "veg_annual_8058")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
tmp_dir <- file.path(root_dir, "data_intermediate", "terra_tmp", "annual_veg")
dir.create(tmp_dir, recursive = TRUE, showWarnings = FALSE)
terra::terraOptions(tempdir = tmp_dir)

mean_out   <- file.path(out_dir, "total_veg_annual_mean_8058.tif")
jjason_out <- file.path(out_dir, "total_veg_annual_jja_son_8058.tif")


## 2. Load the 140-layer seasonal stack; reconstruct + cross-check WY/season ----

message("\n================ G1a · load seasonal total-veg stack ================")
tv <- terra::rast(stack_tif)
stopifnot(terra::nlyr(tv) == EXPECTED_N_SEASON)

## Layer names are "<WY>_<season>" (set by 02 §4). Derive WY + season from the names,
## then CROSS-CHECK against the independent pool CSV provenance (retained rows, file order).
lyr_nm  <- names(tv)
lyr_wy  <- substr(lyr_nm, 1, 9)                       # e.g. "1988-1989"
lyr_sea <- sub("^[0-9]{4}-[0-9]{4}_", "", lyr_nm)     # e.g. "JJA"
stopifnot(all(grepl("^[0-9]{4}-[0-9]{4}_(DJF|MAM|JJA|SON)$", lyr_nm)))

pool <- readr::read_csv(pool_csv, show_col_types = FALSE)
kept <- pool[isTRUE(pool$retained) | pool$retained == TRUE, ]
kept <- kept[order(kept$file), ]                     # 02 built the stack from sort(fc_files)
if (nrow(kept) != EXPECTED_N_SEASON)
  stop(sprintf("Pool retained=%d, expected %d — provenance mismatch.", nrow(kept), EXPECTED_N_SEASON), call. = FALSE)
if (!identical(paste0(kept$water_year, "_", kept$season), lyr_nm))
  stop("Layer names do not match the pool CSV WY/season order — STOP (do not reduce a mislabelled stack).", call. = FALSE)

wy_levels <- sort(unique(lyr_wy))
stopifnot(length(wy_levels) == EXPECTED_N_WY)
wy_index  <- match(lyr_wy, wy_levels)                # 1..35, tapp grouping index
message(sprintf("  140 seasonal layers -> %d water years (%s .. %s); WY/season names match pool CSV.",
                length(wy_levels), wy_levels[1], wy_levels[length(wy_levels)]))

## Assign EPSG:3577 losslessly (the WKT is GDA94 Albers CM132, no authority code).
terra::crs(tv) <- SRC_EPSG
message("  assigned ", SRC_EPSG, " to the intermediate (lossless; WKT already GDA94 Albers CM132).")

## Replicate the committed source-overshoot treatment (02_build_total_veg_percentile_rasters.R §5b):
## the ON-DISK intermediate is the PRE-clean stack — 02 masks > TOTAL_VEG_MAX to NA in memory AFTER
## writing it, then computes percentiles from the cleaned version. Those 15/350M JRSRP unmixing
## overshoot cells (facts §4, up to 147) are physically impossible cover, so set to NA (NOT clamp —
## do not invent data). Diluted away by the 4-season mean; NOT by the <=2-season JJA/SON reduction.
n_over <- sum(terra::global(tv > TOTAL_VEG_MAX, "sum", na.rm = TRUE)[[1]])
tv <- terra::ifel(tv > TOTAL_VEG_MAX, NA, tv)
message(sprintf("  masked %d pixel-layers > %d -> NA (source overshoot, facts §4; set to NA not clamped).",
                n_over, TOTAL_VEG_MAX))


## 3. Per-WY valid-season coverage (the seasonal-composition caveat, MEASURED) ----
##    n non-NA seasons per pixel per WY, all-4 pool and JJA/SON pool, on the farm/census footprint.

class_r  <- terra::rast(class_tif)
## Census focus footprint transferred to the 3577 native grid for coverage counting.
focus_8058 <- terra::app(class_r, fun = function(v) ifelse(v %in% FOCUS_CODES, 1, NA))
focus_3577 <- terra::project(focus_8058, tv, method = "near")

is_grow <- lyr_sea %in% SEASONS_GROWING
valid_all  <- terra::tapp(!is.na(tv), index = wy_index, fun = "sum")          # 35 lyr: n valid seasons/WY (of 4)
valid_grow <- terra::tapp(!is.na(tv[[which(is_grow)]]),
                          index = wy_index[is_grow], fun = "sum")             # 35 lyr: n valid JJA/SON/WY (of 2)
names(valid_all)  <- wy_levels
names(valid_grow) <- wy_levels

vall_f  <- terra::mask(valid_all,  focus_3577)
vgrow_f <- terra::mask(valid_grow, focus_3577)
seasons_tbl <- dplyr::bind_rows(lapply(seq_len(EXPECTED_N_WY), function(i) {
  va <- terra::values(vall_f[[i]])[, 1];  va <- va[!is.na(va)]
  vg <- terra::values(vgrow_f[[i]])[, 1]; vg <- vg[!is.na(vg)]
  tibble::tibble(
    water_year          = wy_levels[i],
    census_px           = length(va),
    mean_valid_all      = round(mean(va), 3),
    pct_px_all4         = round(100 * mean(va == 4L), 2),
    mean_valid_jja_son  = round(mean(vg), 3),
    pct_px_jjason_0     = round(100 * mean(vg == 0L), 2),   # WYs where JJA/SON reduction has NO data
    pct_px_jjason_both  = round(100 * mean(vg == 2L), 2)
  )
}))
message("\n  Per-WY seasonal coverage on the census focus footprint (head):")
print(as.data.frame(head(seasons_tbl, 4)), row.names = FALSE)
gayini_write_csv(seasons_tbl, file.path(diagnostics_dir, "tier2H_g1a_annual_veg_valid_seasons.csv"))
worst_jjason <- seasons_tbl$water_year[which.max(seasons_tbl$pct_px_jjason_0)]
message(sprintf("  JJA/SON reduction is thinnest in WY %s (%.1f%% of census px have 0 growing-season obs).",
                worst_jjason, max(seasons_tbl$pct_px_jjason_0)))


## 4. Reduce to 35 annual layers, TWO ways, at native 30 m / 3577 ----

message("\n================ G1a · annual reduction (native 3577, 30 m) ================")
## (A) mean of available seasons per WY.
ann_mean_3577 <- terra::tapp(tv, index = wy_index, fun = "mean", na.rm = TRUE)
names(ann_mean_3577) <- wy_levels
## (B) mean of JJA + SON only per WY.
ann_grow_3577 <- terra::tapp(tv[[which(is_grow)]], index = wy_index[is_grow], fun = "mean", na.rm = TRUE)
names(ann_grow_3577) <- wy_levels
message("  built 2 x 35-layer annual stacks (mean-of-available + JJA/SON).")


## 5. Reproject ONCE to the 8058 census grid — BILINEAR (continuous cover %) ----

message("\n================ G1a · reproject 3577 -> 8058 (bilinear) ================")
ann_mean_8058 <- terra::project(ann_mean_3577, class_r, method = "bilinear")
ann_grow_8058 <- terra::project(ann_grow_3577, class_r, method = "bilinear")
names(ann_mean_8058) <- wy_levels
names(ann_grow_8058) <- wy_levels


## 6. ASSERT grid alignment + value envelope ----

for (nm in c("mean", "jja_son")) {
  r <- if (nm == "mean") ann_mean_8058 else ann_grow_8058
  geom_ok <- terra::compareGeom(r, class_r, lyrs = FALSE, crs = TRUE, ext = TRUE,
                                rowcol = TRUE, res = TRUE, stopOnError = FALSE)
  rng <- terra::minmax(r)
  lo <- min(rng[1, ], na.rm = TRUE); hi <- max(rng[2, ], na.rm = TRUE)
  message(sprintf("  [%-7s] compareGeom(vs veg_regime_class_8058)=%s · value range [%.3f, %.3f] · nlyr=%d",
                  nm, geom_ok, lo, hi, terra::nlyr(r)))
  stopifnot(isTRUE(geom_ok), terra::nlyr(r) == EXPECTED_N_WY,
            lo >= -1e-3, hi <= TOTAL_VEG_MAX + 1)   # bilinear can nudge edges slightly; envelope is source-bounded
}
message("  ==> ALIGNMENT + ENVELOPE ASSERTED for both reductions (not assumed).")


## 7. Robustness delta A vs B, on the census focus footprint ----
##    Per-WY: mean/median/sd of (mean_all - jja_son). Plus a per-pixel TEMPORAL correlation
##    between the two annual series (how much does the reduction choice change the signal a
##    pixel sees over 35 yr) — pairwise-complete raster-algebra estimate (approximate where the
##    two series drop different NA years; adequate as a robustness read, not a published stat).

focus_m <- terra::mask(ann_mean_8058, focus_8058)
focus_g <- terra::mask(ann_grow_8058, focus_8058)
delta   <- focus_m - focus_g

delta_tbl <- dplyr::bind_rows(lapply(seq_len(EXPECTED_N_WY), function(i) {
  d <- terra::values(delta[[i]])[, 1]; d <- d[!is.na(d)]
  tibble::tibble(
    water_year   = wy_levels[i], census_px = length(d),
    mean_delta   = round(mean(d), 3), median_delta = round(stats::median(d), 3),
    sd_delta     = round(stats::sd(d), 3),
    q05_delta    = round(stats::quantile(d, 0.05, names = FALSE), 3),
    q95_delta    = round(stats::quantile(d, 0.95, names = FALSE), 3)
  )
}))
message("\n================ G1a · reduction delta (mean-of-available − JJA/SON), census footprint ================")
message("  delta > 0 => the all-season mean sits ABOVE the growing-season value (summer dry-down pulls it? no —")
message("  DJF/MAM is the summer LOW season, so the all-mean should sit BELOW JJA/SON: expect delta mostly < 0).")
print(as.data.frame(delta_tbl), row.names = FALSE)
gayini_write_csv(delta_tbl, file.path(diagnostics_dir, "tier2H_g1a_annual_veg_reduction_delta.csv"))

## Per-pixel temporal correlation between the two annual series (approximate, pairwise-complete).
temporal_cor <- function(a, b) {
  ma <- terra::app(a, "mean", na.rm = TRUE); mb <- terra::app(b, "mean", na.rm = TRUE)
  da <- a - ma; db <- b - mb
  cov <- terra::app(da * db, "mean", na.rm = TRUE)
  sa  <- terra::app(da * da, "mean", na.rm = TRUE)
  sb  <- terra::app(db * db, "mean", na.rm = TRUE)
  cov / sqrt(sa * sb)
}
rr <- temporal_cor(focus_m, focus_g)
rrv <- terra::values(rr)[, 1]; rrv <- rrv[is.finite(rrv)]
mad_series <- terra::app(abs(delta), "mean", na.rm = TRUE)   # per-pixel mean abs annual difference
madv <- terra::values(mask(mad_series, focus_8058))[, 1]; madv <- madv[!is.na(madv)]
cor_summary <- tibble::tibble(
  metric = c("per_pixel_temporal_r(A,B)", "per_pixel_mean_abs_delta"),
  n_px   = c(length(rrv), length(madv)),
  p05    = c(round(stats::quantile(rrv, 0.05, names = FALSE), 4), round(stats::quantile(madv, 0.05, names = FALSE), 3)),
  median = c(round(stats::median(rrv), 4), round(stats::median(madv), 3)),
  mean   = c(round(mean(rrv), 4), round(mean(madv), 3)),
  p95    = c(round(stats::quantile(rrv, 0.95, names = FALSE), 4), round(stats::quantile(madv, 0.95, names = FALSE), 3))
)
message("\n  Per-pixel A-vs-B agreement over 35 yr (temporal r) + mean abs annual delta (cover %):")
print(as.data.frame(cor_summary), row.names = FALSE)


## 8. Write the two annual products ----

message("\n================ G1a · write products ================")
terra::writeRaster(ann_mean_8058, mean_out,   overwrite = TRUE, datatype = "FLT4S")
terra::writeRaster(ann_grow_8058, jjason_out, overwrite = TRUE, datatype = "FLT4S")
message("  wrote: ", gayini_relative_path(root_dir, mean_out))
message("  wrote: ", gayini_relative_path(root_dir, jjason_out))


## 9. QA json ----

qa <- list(
  step = "G1a annual total-veg 8058 stack",
  generated_by = "scripts/05_ground_cover/04_build_annual_total_veg_stack_8058.R",
  gate = "Tier2 Task H · Gate E · G1a (STOP at built stack, before the response raster)",
  source = list(
    seasonal_stack = gayini_relative_path(root_dir, stack_tif),
    n_seasonal_layers = EXPECTED_N_SEASON, n_water_years = EXPECTED_N_WY,
    src_crs_assigned = SRC_EPSG,
    src_crs_note = "WKT is GDA94 Australian Albers CM132 (= EPSG:3577) with no authority code; assigned losslessly."),
  reductions = list(
    A_mean_of_available = "per-WY mean of available seasons (na.rm); the natural same-year cover",
    B_growing_jja_son   = "per-WY mean of JJA+SON only (facts §6b winter-spring growing season)"),
  reproject = "native 30 m / 3577 arithmetic, ONE bilinear reproject to the 8058 census grid (continuous cover %)",
  outputs = list(
    annual_mean_8058    = gayini_relative_path(root_dir, mean_out),
    annual_jja_son_8058 = gayini_relative_path(root_dir, jjason_out),
    valid_seasons_csv   = "Output/diagnostics/tier2H_g1a_annual_veg_valid_seasons.csv",
    reduction_delta_csv = "Output/diagnostics/tier2H_g1a_annual_veg_reduction_delta.csv"),
  robustness = list(
    per_pixel_temporal_r_median = cor_summary$median[1],
    per_pixel_mean_abs_delta_median = cor_summary$median[2],
    delta_convention = "mean_delta = (mean-of-available) − (JJA/SON); expect mostly < 0 (DJF/MAM summer low season pulls the all-mean down)"),
  caveats = list(
    seasonal_composition = "JJA/SON under-observed (facts §6b): reduction A inherits seasonal noise, B thins in cloudy WYs",
    resolution = "FC natively 30 m; reported on 24.97 m census grid — do not over-interpret fine detail (facts §11)",
    not_registered = "products NOT registered in raster_asset here — registration is G7 (non-destructive)"),
  next_step = "G1b: per-pixel same-year response = temporal r(annual total-veg, annual binary wet/dry) over 35 yr; STOP for review before figures")
jsonlite::write_json(qa, file.path(diagnostics_dir, "tier2H_g1a_qa.json"),
                     auto_unbox = TRUE, pretty = TRUE, digits = 6)


## 10. Summary — STOP at the built stack ----

message("\n==================== G1a COMPLETE — STOP AT THE BUILT STACK ====================")
message(sprintf("Annual total-veg 8058 stacks: 2 x %d layers (%s .. %s), bilinear, compareGeom = TRUE.",
                EXPECTED_N_WY, wy_levels[1], wy_levels[length(wy_levels)]))
message("  A mean-of-available : ", gayini_relative_path(root_dir, mean_out))
message("  B JJA/SON growing   : ", gayini_relative_path(root_dir, jjason_out))
message(sprintf("Robustness: per-pixel temporal r(A,B) median = %.4f · mean abs annual delta median = %.3f cover pts.",
                cor_summary$median[1], cor_summary$median[2]))
message("Seasonal-composition caveat carried per-WY (tier2H_g1a_annual_veg_valid_seasons.csv).")
message("NOT registered (raster_asset) — that is G7, non-destructive. NEXT: G1b response raster (separate gate).")
message("\nSTOP: review the two annual stacks + the robustness delta before computing the response raster.")
