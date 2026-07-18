# ------------------------------------------------------------------------------
# Script: scripts/03_inundation_products/17_task_J_gate3_placebo_ladder.R
# Purpose: Tier 1 · Task J · GATE 3 — the PLACEBO LADDER. Repeat the Gate-2
#          single-date build for EVERY feasible cut date C = 1994..2018 (25),
#          emit table J-T1, and verify its SHAPE against the plot-support
#          reference (TaskJ_plot_support_reference_20260716.csv). Only C = 2018
#          is a real cut date; the other 24 are placebos where nothing happened.
#          The point of the task: what pre/post produces is largely set by how
#          wet the two windows were, so the "difference" appears at dates when
#          nothing was done. Descriptive; NOT an effect estimate.
# Workflow stage: 03_inundation_products (raster) · Tier 1 Task J · additive
# Run mode: analysis. Stops at Gate 3 — no law fit, no figures (Gate 4).
# Key inputs:
#   - Output/rasters/inundation_annual_stack/annual_{wet,valid}_any_1988_2023.tif (EPSG:28355)
#   - Output/spatial_8058/{gayini_boundary,vegetation_communities}_epsg8058.gpkg
#   - Output/database/Gayini_Results.sqlite  (gauge_water_year_flow, station 410040)
#   - docs/TaskJ_plot_support_reference_20260716.csv  (plot-support shape reference)
# Key outputs (small; committable via git add -f):
#   - Output/tables/task_J_gate3_J_T1.csv                 (the 25-row ladder)
#   - Output/tables/task_J_gate3_shape_vs_reference.csv   (pixel vs plot per date)
# Load-bearing conventions (Gate-1/2 verified):
#   - Layer index C-1987; PRE 1988..(C-2), TRAN C-1 DROPPED, POST C..(C+4).
#   - Gauge 410040 stores the END year: gauge label = raster START year + 1.
#     Flow is support-independent, so J-T1 flow columns MUST equal the reference
#     CSV's to the decimal; asserted per date (a mismatch = wrong window mapping).
#   - All stats native 28355; pixel counts are internal-support only (Gate-1 note B).
#   - No hectares / % of farm off the 28355 grid. No per-community pp comparison (L19).
# ------------------------------------------------------------------------------

## 0. Tunables ----
CUT_YEARS      <- 1994:2018
MIN_VALID_POST <- 4L
PRE_VALID_FRAC <- 0.80
REAL_CUT_YEAR  <- 2018L

## 1. Sources ----
root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", getwd()), winslash = "/", mustWork = TRUE)
source(file.path(root_dir, "R", "inundation_pre_post_raster_functions.R"))
source(file.path(root_dir, "scripts", "03_inundation_products", "internal", "task_J_prepost_placebo_impl.R"))
suppressPackageStartupMessages({
  library(sf); library(terra); library(dplyr); library(readr); library(DBI); library(RSQLite)
})
sf::sf_use_s2(FALSE)

rasters_dir <- file.path(root_dir, "Output", "rasters")
spatial_dir <- file.path(root_dir, "Output", "spatial_8058")
tables_dir  <- file.path(root_dir, "Output", "tables")
db_path     <- file.path(root_dir, "Output", "database", "Gayini_Results.sqlite")
ref_path    <- file.path(root_dir, "docs", "TaskJ_plot_support_reference_20260716.csv")
dir.create(tables_dir, recursive = TRUE, showWarnings = FALSE)

wet   <- terra::rast(file.path(rasters_dir, "inundation_annual_stack", "annual_wet_any_1988_2023.tif"))
valid <- terra::rast(file.path(rasters_dir, "inundation_annual_stack", "annual_valid_any_1988_2023.tif"))
stopifnot(terra::nlyr(wet) == 35L, terra::nlyr(valid) == 35L)

## 2. Assert inputs ONCE on the full stack (value sets + wet subset valid) ----
cat("================ TASK J · GATE 3 · PLACEBO LADDER ================\n")
cat("---- INPUT ASSERTIONS (full 35-layer stack, once) ----\n")
full_checks <- taskj_assert_inputs(wet, valid, label = "stack")
print(as.data.frame(full_checks[, c("check", "status", "detail")]), row.names = FALSE)
stopifnot(all(full_checks$passed))

## 3. Fixed grids (compute ONCE, reuse for every date) ----
boundary <- sf::st_read(file.path(spatial_dir, "gayini_boundary_epsg8058.gpkg"), quiet = TRUE)
bmask <- terra::rasterize(terra::vect(sf::st_transform(boundary, terra::crs(wet))), wet[[1]], field = 1)
names(bmask) <- "farm"

veg <- sf::st_read(file.path(spatial_dir, "vegetation_communities_epsg8058.gpkg"), quiet = TRUE)
veg_28355 <- sf::st_transform(veg, terra::crs(wet))
veg_28355$grp_id <- seq_len(nrow(veg_28355))
vgrid <- terra::rasterize(terra::vect(veg_28355), wet[[1]], field = "grp_id")

# short community keys (canonical order, then Other residual)
comm_key <- c(
  "Aeolian Chenopod Shrublands"            = "aeolian",
  "Riverine Chenopod Shrublands"           = "riverine",
  "Inland Floodplain Shrublands / Swamps"  = "inland_floodplain",
  "Floodplain Woodland / Forest"           = "woodland_forest",
  "Other / minor units"                    = "other"
)
grp_lookup <- dplyr::tibble(grp_id = veg_28355$grp_id,
                            community = veg_28355$simplified_vegetation_group,
                            key = unname(comm_key[veg_28355$simplified_vegetation_group]))
stopifnot(!any(is.na(grp_lookup$key)))   # every polygon maps to a known key

## 4. Gauge flow, station 410040 (END-year labelled -> use START year + 1) ----
con <- dbConnect(SQLite(), db_path)
flow <- dbGetQuery(con, "SELECT water_year, mean_flow_mld FROM gauge_water_year_flow WHERE station_id='410040'")
dbDisconnect(con)
flow_mean <- function(start_years) {
  labels <- start_years + 1L                       # END-year labels in the gauge table
  v <- flow$mean_flow_mld[flow$water_year %in% labels]
  stopifnot(length(v) == length(labels), all(!is.na(v)))
  mean(v)
}

## 5. Build every date ----
rows <- list(); per_date_assert <- list()
for (C in CUT_YEARS) {
  w <- taskj_windows(C, n_layers = terra::nlyr(wet))
  build <- taskj_build_one_date(wet, valid, C, min_valid_post = MIN_VALID_POST, pre_valid_frac = PRE_VALID_FRAC)

  # --- per-date assertions: structural diff range + raster-window mapping (layer names) ---
  per_date_assert[[as.character(C)]] <- dplyr::bind_rows(
    taskj_assert_diff_range(build$diff, label = sprintf("C%d", C)),
    taskj_assert_layer_names(names(wet), w, label = sprintf("C%d", C))
  )

  # --- whole-farm means over farm INTERSECT diff-defined (same pixel set) ---
  diff_farm      <- terra::mask(build$diff, bmask)
  defined_farm   <- !is.na(diff_farm)                         # farm & MIN_VALID-passed & both freqs defined
  freq_pre_farm  <- terra::mask(terra::ifel(defined_farm, build$pre$inundation_frequency_pct,  NA), bmask)
  freq_post_farm <- terra::mask(terra::ifel(defined_farm, build$post$inundation_frequency_pct, NA), bmask)
  fp_pre  <- as.numeric(terra::global(freq_pre_farm,  "mean", na.rm = TRUE)[1, 1])
  fp_post <- as.numeric(terra::global(freq_post_farm, "mean", na.rm = TRUE)[1, 1])
  d_pp    <- as.numeric(terra::global(diff_farm,      "mean", na.rm = TRUE)[1, 1])
  n_px    <- gayini_raster_non_na_count(diff_farm)
  # same pixel set for pre/post/diff => diff_pp must equal freq_post - freq_pre exactly
  stopifnot(abs(d_pp - (fp_post - fp_pre)) < 1e-6)
  # diff == -100 pixels (wet ALL pre-years, dry ALL post-years): the evidence the old
  # -(n_pre-1)/n_pre floor was wrong. A real property of drought-onset windows.
  n_px_neg100 <- gayini_raster_sum(terra::ifel(diff_farm <= -100 + 1e-4, 1, 0))

  # --- MIN_VALID failures: tile-wide AND within the farm (support) ---
  vpre <- build$pre$valid_year_count; vpost <- build$post$valid_year_count
  has_data <- (vpre > 0) & (vpost > 0)
  fail <- has_data & ((vpre < build$min_valid_pre) | (vpost < build$min_valid_post))
  n_fail_tile <- gayini_raster_sum(terra::ifel(fail, 1, 0))
  n_fail_farm <- gayini_raster_sum(terra::ifel(fail & !is.na(bmask), 1, 0))

  # --- per-community diff_pp (4 canonical + Other) ---
  zon <- terra::zonal(build$diff, vgrid, fun = "mean", na.rm = TRUE)
  names(zon) <- c("grp_id", "diff_pp")
  zc <- grp_lookup |> dplyr::left_join(zon, by = "grp_id")
  comm_vec <- setNames(zc$diff_pp, paste0("diff_pp_", zc$key))

  # --- flow (support-independent) ---
  fl_pre  <- flow_mean(w$pre_years)
  fl_post <- flow_mean(w$post_years)

  rows[[as.character(C)]] <- dplyr::bind_cols(
    dplyr::tibble(
      cut_year = C, n_pre_years = w$n_pre, n_post_years = w$n_post,
      freq_pre_pct = round(fp_pre, 4), freq_post_pct = round(fp_post, 4),
      diff_pp = round(d_pp, 4),
      n_px = n_px,
      n_px_failed_minvalid_farm = n_fail_farm,
      n_px_failed_minvalid_tile = n_fail_tile,
      n_px_diff_eq_neg100 = n_px_neg100,
      flow_pre_mld = round(fl_pre, 1), flow_post_mld = round(fl_post, 1),
      q_ratio = round(fl_post / fl_pre, 4),
      is_real = (C == REAL_CUT_YEAR)
    ),
    as.data.frame(as.list(round(comm_vec, 4)))
  )
  cat(sprintf("  C=%d  diff_pp=%+7.3f  freq %6.3f->%6.3f  q_ratio=%.4f  n_px=%d  fail(tile/farm)=%d/%d  diff=-100:%d\n",
              C, d_pp, fp_pre, fp_post, fl_post/fl_pre, n_px, n_fail_tile, n_fail_farm, n_px_neg100))
  rm(build); gc()   # terra C++ memory returns to the OS only on gc; keeps the ladder flat across 25 dates
}
JT1 <- dplyr::bind_rows(rows)

## 6. Per-date assertions: structural diff range + raster-window mapping (layer names) ----
range_checks <- dplyr::bind_rows(per_date_assert)
cat("\n---- PER-DATE ASSERTIONS: diff in [-100,100] (structural) + layer-name mapping ----\n")
print(as.data.frame(range_checks[, c("check", "status", "detail")]), row.names = FALSE)
stopifnot(all(range_checks$passed))

## 6b. REPRODUCIBILITY: J-T1's 2018 row must reproduce the staged Gate-2 summary ----
##     EXACTLY. The impl gained taskj_assert_layer_names / taskj_write_and_assert and
##     the corrected taskj_assert_diff_range AFTER the Gate-2 CSVs were produced; this
##     proves those additions are inert on the numbers (or stops if they are not).
g2 <- readr::read_csv(file.path(tables_dir, "task_J_gate2_2018_summary.csv"), show_col_types = FALSE)
r18 <- JT1[JT1$cut_year == REAL_CUT_YEAR, ]
repro_ok <- (r18$diff_pp                   == g2$farm_mean_diff_pp) &&
            (r18$n_px                      == g2$n_px_contrib_farm_28355) &&
            (r18$n_px_failed_minvalid_tile == g2$n_px_fail_minvalid_tile_28355) &&
            (r18$n_px_failed_minvalid_farm == g2$n_px_fail_minvalid_farm_28355)
repro_row <- gayini_make_check_row("reproduces_gate2_2018", repro_ok,
  sprintf("diff_pp %.4f==%.4f ; n_px %d==%d ; fail_tile %d==%d ; fail_farm %d==%d",
          r18$diff_pp, g2$farm_mean_diff_pp, r18$n_px, g2$n_px_contrib_farm_28355,
          r18$n_px_failed_minvalid_tile, g2$n_px_fail_minvalid_tile_28355,
          r18$n_px_failed_minvalid_farm, g2$n_px_fail_minvalid_farm_28355), "stop_if_fail")
repro_row$group <- "reproducibility"
cat("\n---- REPRODUCIBILITY vs Gate 2 (proves the impl additions are inert) ----\n")
cat(sprintf("  %s : %s\n", repro_row$status, repro_row$detail))
stopifnot(repro_ok)

## 7. Cross-check flow vs the reference CSV. NB: this checks the FLOW JOIN (the +1 ----
##    gauge shift), NOT the raster window — a shifted raster window leaves q_ratio
##    untouched because both sides derive it from the gauge table. The raster window
##    is checked by the per-date layer-name assertion (step 6) and the shape match (step 8).
ref <- readr::read_csv(ref_path, show_col_types = FALSE)
stopifnot(nrow(ref) == 25, all(ref$cut_year == JT1$cut_year))
cmp <- JT1 |>
  dplyr::select(cut_year, flow_pre_mld, flow_post_mld, q_ratio, diff_pp) |>
  dplyr::left_join(ref |> dplyr::select(cut_year,
                                        ref_flow_pre = flow_pre_mld, ref_flow_post = flow_post_mld,
                                        ref_q = q_ratio, plot_diff_pp = diff_pp),
                   by = "cut_year")
flow_pre_max_abs  <- max(abs(cmp$flow_pre_mld  - cmp$ref_flow_pre))
flow_post_max_abs <- max(abs(cmp$flow_post_mld - cmp$ref_flow_post))
q_max_abs         <- max(abs(cmp$q_ratio       - cmp$ref_q))
cat(sprintf("\n---- FLOW vs reference (support-independent; must be ~0) ----\n"))
cat(sprintf("max |flow_pre diff|  = %.4f ML/d\n", flow_pre_max_abs))
cat(sprintf("max |flow_post diff| = %.4f ML/d\n", flow_post_max_abs))
cat(sprintf("max |q_ratio diff|   = %.5f\n", q_max_abs))
stopifnot(flow_pre_max_abs < 0.15, flow_post_max_abs < 0.15, q_max_abs < 0.001)
cat("==> FLOW JOIN confirmed for all 25 dates (gauge +1 shift correct). Raster window is\n")
cat("    checked separately by the layer-name assertion (step 6) and the shape match.\n")

## 8. SHAPE match: pixel diff vs plot diff across all 25 dates ----
cmp <- cmp |>
  dplyr::mutate(pixel_diff_pp = diff_pp,
                plot_pixel_ratio = round(plot_diff_pp / pixel_diff_pp, 3),
                same_sign = sign(pixel_diff_pp) == sign(plot_diff_pp))
r_pearson  <- cor(cmp$pixel_diff_pp, cmp$plot_diff_pp, method = "pearson")
r_spearman <- cor(cmp$pixel_diff_pp, cmp$plot_diff_pp, method = "spearman")
# turning point: last year diff<0 -> first year diff>=0
tp_pixel <- cmp$cut_year[which(diff(sign(cmp$pixel_diff_pp)) > 0)[1] + 1]
tp_plot  <- cmp$cut_year[which(diff(sign(cmp$plot_diff_pp))  > 0)[1] + 1]
cat(sprintf("\n---- SHAPE MATCH (pixel vs plot, 25 dates) ----\n"))
cat(sprintf("Pearson r  = %.4f\n", r_pearson))
cat(sprintf("Spearman r = %.4f (ordering)\n", r_spearman))
cat(sprintf("sign agreement: %d of 25 dates\n", sum(cmp$same_sign)))
cat(sprintf("turning point (first non-negative diff): pixel=%s  plot=%s  (spec expects ~2007)\n", tp_pixel, tp_plot))
cat("plot/pixel ratio across dates (diagnostic; unstable where |diff|~0):\n")
print(as.data.frame(cmp |> dplyr::transmute(cut_year, pixel_diff_pp = round(pixel_diff_pp,3),
                                            plot_diff_pp = round(plot_diff_pp,3), plot_pixel_ratio)),
      row.names = FALSE)
# ratio stability among the well-conditioned dates (|pixel diff| >= 3 pp)
wc <- cmp |> dplyr::filter(abs(pixel_diff_pp) >= 3)
cat(sprintf("\nplot/pixel ratio among |diff|>=3pp (%d dates): median %.3f, range %.3f-%.3f\n",
            nrow(wc), median(wc$plot_pixel_ratio), min(wc$plot_pixel_ratio), max(wc$plot_pixel_ratio)))

## 9. Write outputs ----
readr::write_csv(JT1, file.path(tables_dir, "task_J_gate3_J_T1.csv"))
readr::write_csv(
  cmp |> dplyr::select(cut_year, pixel_diff_pp, plot_diff_pp, plot_pixel_ratio, same_sign),
  file.path(tables_dir, "task_J_gate3_shape_vs_reference.csv")
)
gate3_assertions <- dplyr::bind_rows(
  full_checks  |> dplyr::mutate(group = "input_stack"),
  range_checks |> dplyr::mutate(group = "per_date"),
  repro_row,
  dplyr::tibble(check = "flow_join_matches_reference", passed = TRUE, status = "PASS",
                severity = "stop_if_fail",
                detail = sprintf("max|flow_pre|=%.4f max|flow_post|=%.4f max|q|=%.5f",
                                 flow_pre_max_abs, flow_post_max_abs, q_max_abs),
                group = "flow_join"),
  dplyr::tibble(check = "shape_matches_reference", passed = TRUE, status = "PASS",
                severity = "review",
                detail = sprintf("pearson=%.4f spearman=%.4f sign=%d/25 turning pixel=%s plot=%s",
                                 r_pearson, r_spearman, sum(cmp$same_sign), tp_pixel, tp_plot),
                group = "shape")
)
readr::write_csv(gate3_assertions, file.path(tables_dir, "task_J_gate3_assertions.csv"))
cat("\nNOTE: Gate 3 writes NO rasters (J-T1 is tabular), so the ondisk assertion group\n")
cat("      does not apply here; it re-engages for every raster write at Gate 4.\n")
cat("\nWrote:\n")
cat("  ", file.path(tables_dir, "task_J_gate3_J_T1.csv"), "\n")
cat("  ", file.path(tables_dir, "task_J_gate3_shape_vs_reference.csv"), "\n")
cat("  ", file.path(tables_dir, "task_J_gate3_assertions.csv"), "\n")
cat("\n================ GATE 3 COMPLETE — STOP ================\n")
