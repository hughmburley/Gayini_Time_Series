# ------------------------------------------------------------------------------
# Script: scripts/03_inundation_products/12_run_census_trend_test.R
# Purpose: Tier 2 · Task H · Track A · H3.1 + H3.2 + H3.3 — the all-pixel (census)
#          flood-frequency result.
#            H3.1  census veg x wetness matrix: annual flood frequency per class
#                  using EVERY pixel, per year, on the NN 8058 stack, partitioned
#                  by the F5 regime_band_breaks.csv edges (option 2, decouple).
#            H3.2  F6 re-run on the census: the same robust trend test (Theil-Sen
#                  + Mann-Kendall, LOESS shape, drop-two-floods) across the NINE
#                  strata, compared verdict-for-verdict against the shut gate
#                  (8 no-trend / 1 non-stationary / 0 directional).
#            H3.3  per-year cut (GATED — only runs if H3.2 reproduces 8/1/0).
# Workflow stage: 03_inundation_products · Tier 2 Task H, Track A
# Run mode: analysis (raster zonal stats + trend tests) · additive, read-only
# Key inputs:
#   - Output/rasters/veg_regime_class_8058.tif                    (strata partition, canonical)
#   - Output/rasters/inundation_annual_stack_8058/annual_{wet,valid}_any_1988_2023_8058.tif (NN, H3.0)
#   - Output/diagnostics/f6_verdict_summary.csv                   (F5-sample F6 verdicts, for comparison)
# Key outputs (additive; Output/ gitignored):
#   - Output/diagnostics/tier2H_h31_census_stratum_annual_series.csv
#   - Output/diagnostics/tier2H_h31_census_matrix.csv
#   - Output/diagnostics/tier2H_h32_census_f6_verdicts.csv
#   - Output/diagnostics/tier2H_h32_f6_verdict_delta_vs_sample.csv
#   - Output/diagnostics/tier2H_h33_per_year_cut.csv  (only if 8/1/0 reproduces)
#   - Output/diagnostics/tier2H_trackA_qa.json
# Notes:
#   - OPTION 2 (decouple): band definitions = the F5 regime_band_breaks.csv edges,
#     materialised in veg_regime_class_8058.tif (bilinear-defined, canonical). ALL
#     flood-frequency arithmetic is on the NN 8058 stack. This keeps the nine strata
#     IDENTICAL to the shut gate so F6 is a like-for-like comparison; NN quantile
#     bands are not reproducible (v3 spec 3.7). Aeolian's low/mid edge is a smoothing
#     artefact and is labelled as such.
#   - H3.2 acceptance: verdict tally MUST reproduce 8/1/0. A census adds ZERO temporal
#     power; divergence is a bug, not a finding. On divergence the script STOPS before
#     H3.3 and reports.
#   - Headline metric: 100 x wet-valid-years / valid-years. Wet-rule already applied
#     upstream in the annual stack (gayini_inundation_wet_rule.R).
#   - Read-only: no raster or DB mutation. Nothing existing is overwritten.
# ------------------------------------------------------------------------------

## 0. Constants ----

MIN_VALID_YEARS  <- 25L
FOCUS_CODES      <- c(11L, 12L, 13L, 21L, 22L, 23L, 31L, 32L, 33L)

## RATIFIED census expectation (Hugh, 15 Jul 2026). The F5-SAMPLE gate was
## 8 no-trend / 1 non-stationary / 0 directional; the census returns 9/0/0 because
## Riverine low's non-stationary flag was a small-sample artefact, not a signal:
## 1,000 random 40-point draws from this same census stratum return p < 0.05 in
## 541 (a 54% false-positive rate against a nominal 5%); median 29/35 zero-years
## per draw (the F5 sample's 28 is a TYPICAL draw, not an unlucky one); mean tau
## across draws +0.258 vs census +0.126 -- sparsity biases tau upward. At ~0.04
## expected wet points/year in the early period, 40 points report zero regardless
## of the truth.
##
## Why a verdict change is legitimate here (the earlier "divergence = bug" stop
## rule was wrong and is corrected): "a census adds zero temporal power" is true
## but does NOT imply the verdict cannot change. A trend test operates on the
## VALUES of the 35 annual observations, and the census removes measurement error
## WITHIN each year. Where the sample is systematically distorted -- as it is for a
## sparse, zero-inflated stratum -- the census CORRECTS rather than hardens.
EXPECTED_TALLY   <- c(no_trend = 9L, non_stationary = 0L, directional_trend = 0L)

## The single ratified verdict change vs the F5-sample gate. Any OTHER stratum
## moving is still a red flag and stops the run.
EXPECTED_CHANGED <- "Riverine Chenopod Shrublands | low"


## 1. Sources ----

root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", getwd()), winslash = "/", mustWork = TRUE)

source(file.path(root_dir, "R", "gayini_helpers.R"))
source(file.path(root_dir, "R", "gayini_output_helpers.R"))
source(file.path(root_dir, "R", "gayini_output_paths.R"))
source(file.path(root_dir, "R", "gayini_gradient_helpers.R"))
source(file.path(root_dir, "R", "gayini_stratified_sampling_functions.R"))  # focus levels / band levels
source(file.path(root_dir, "R", "gayini_veg_regime_functions.R"))           # class-code -> community x band
source(file.path(root_dir, "R", "gayini_trend_test_functions.R"))           # THE trend test (reused verbatim)

suppressPackageStartupMessages({
  library(terra)
  library(dplyr)
})

diagnostics_dir <- file.path(root_dir, "Output", "diagnostics")
rasters_dir     <- file.path(root_dir, "Output", "rasters")

class_tif <- file.path(rasters_dir, "veg_regime_class_8058.tif")
stack_dir <- file.path(rasters_dir, "inundation_annual_stack_8058")
wet_tif   <- file.path(stack_dir, "annual_wet_any_1988_2023_8058.tif")
val_tif   <- file.path(stack_dir, "annual_valid_any_1988_2023_8058.tif")
for (p in c(class_tif, wet_tif, val_tif)) gayini_stop_if_missing(p, label = basename(p))

focus_communities <- gayini_focus_levels()
band_levels       <- gayini_regime_band_levels()
classes           <- gayini_veg_regime_classes()


## 2. Load + grid discipline ----

message("\n[Track A] Loading NN 8058 stack + canonical strata partition ...")
class_r <- terra::rast(class_tif)
wet     <- terra::rast(wet_tif)
val     <- terra::rast(val_tif)

stopifnot(terra::nlyr(wet) == terra::nlyr(val))
n_years <- terra::nlyr(wet)
years   <- gayini_stack_water_years(names(wet))

## Strata raster and stack MUST share the exact grid (option 2 zonal join).
geom_ok <- terra::compareGeom(wet, class_r, lyrs = FALSE, crs = TRUE, ext = TRUE,
                              rowcol = TRUE, res = TRUE, stopOnError = FALSE) &&
           terra::compareGeom(val, class_r, lyrs = FALSE, crs = TRUE, ext = TRUE,
                              rowcol = TRUE, res = TRUE, stopOnError = FALSE)
stopifnot(isTRUE(geom_ok), n_years == 35L)
message(sprintf("  compareGeom(stack, veg_regime_class_8058) = TRUE · %d years (%d-%d)",
                n_years, min(years), max(years)))


## 3. Zonal sums on the NN stack, by canonical class ----
##    valid_8058 is presence-only {1,NA}: sum = count of valid pixels that year.
##    wet_8058 is {0,1,NA}: sum = count of wet pixels that year. na.rm drops masked.

zone <- class_r
levels(zone)     <- NULL       # numeric class codes, not RAT labels
terra::coltab(zone) <- NULL

message("[Track A] Zonal sums (every pixel) ...")
wet_z <- terra::zonal(wet, zone, fun = "sum", na.rm = TRUE)
val_z <- terra::zonal(val, zone, fun = "sum", na.rm = TRUE)
zcol  <- names(zone)                       # "veg_regime_class"
stopifnot(identical(wet_z[[zcol]], val_z[[zcol]]))


## 4. Build the per-stratum annual series (focus strata; F6 input format) ----

class_lut <- classes |>
  dplyr::transmute(code, community, regime_band = band,
                   stratum = paste(community, band, sep = " | "))

build_series <- function(codes) {
  dplyr::bind_rows(lapply(codes, function(cc) {
    wr <- as.numeric(wet_z[wet_z[[zcol]] == cc, -1, drop = TRUE])
    vr <- as.numeric(val_z[val_z[[zcol]] == cc, -1, drop = TRUE])
    meta <- class_lut[class_lut$code == cc, ]
    tibble::tibble(
      stratum     = meta$stratum, community = meta$community,
      regime_band = meta$regime_band, year = years,
      n_valid = as.integer(vr), n_wet = as.integer(wr),
      freq_pct = ifelse(vr > 0, 100 * wr / vr, NA_real_)
    )
  }))
}
series_long <- build_series(FOCUS_CODES)
series_long$community   <- factor(series_long$community,   levels = focus_communities)
series_long$regime_band <- factor(series_long$regime_band, levels = band_levels)

series_csv <- file.path(diagnostics_dir, "tier2H_h31_census_stratum_annual_series.csv")
gayini_write_csv(series_long, series_csv)


## 5. H3.1 — census veg x wetness matrix (headline per class + per community) ----

headline <- function(nw, nv) ifelse(sum(nv) > 0, 100 * sum(nw) / sum(nv), NA_real_)

matrix_stratum <- series_long |>
  dplyr::group_by(community, regime_band, stratum) |>
  dplyr::summarise(n_pixels_yr_valid = sum(n_valid), n_pixels_yr_wet = sum(n_wet),
                   flood_freq_pct = headline(n_wet, n_valid),
                   mean_annual_valid_px = round(mean(n_valid)), .groups = "drop") |>
  dplyr::arrange(community, regime_band)

matrix_community <- series_long |>
  dplyr::group_by(community) |>
  dplyr::summarise(flood_freq_pct = headline(n_wet, n_valid), .groups = "drop")

message("\n================ H3.1 · CENSUS veg x wetness matrix (headline 100 x wet/valid) ================")
message("Per community (sanity vs CLAUDE.md: Aeolian ~9 · Riverine ~22 · Inland ~50):")
print(as.data.frame(matrix_community), row.names = FALSE)
message("\nPer stratum (community x wetness band):")
print(as.data.frame(matrix_stratum[, c("community","regime_band","flood_freq_pct","mean_annual_valid_px")]),
      row.names = FALSE)
gayini_write_csv(matrix_stratum, file.path(diagnostics_dir, "tier2H_h31_census_matrix.csv"))

## MIN_VALID_YEARS sensitivity line (v3 3.5, verbatim).
message("\nMIN_VALID_YEARS sensitivity: the threshold is non-binding; at 25/35 it removes ",
        "0.025% of observed pixels (2,418 of 9,756,630); valid_count ranges 22-35, so any ",
        "threshold <= 22 is inert.")


## 6. H3.2 — F6 on the census (nine strata) ----

stratum_meta <- series_long |>
  dplyr::distinct(stratum, community, regime_band) |>
  dplyr::arrange(community, regime_band)

thresholds <- gayini_trend_thresholds()
message("\n================ H3.2 · F6 census trend test (nine strata) ================")
trend       <- gayini_run_trend_tests(series_long, stratum_meta, thresholds = thresholds)
verdict_tbl <- trend$verdict_tbl

## Aeolian low vacuity: its NN series is (near) flat-zero because bilinear called
## those pixels driest; a flat/near-flat series cannot trend (v3 3.7.3).
ael_low <- series_long[series_long$stratum == "Aeolian Chenopod Shrublands | low", ]
ael_low_max <- max(ael_low$freq_pct, na.rm = TRUE)
ael_low_mean <- mean(ael_low$freq_pct, na.rm = TRUE)

print(as.data.frame(verdict_tbl[, c("community","regime_band","theil_sen_slope","mk_tau",
                                    "mk_p","flood_drop_robust","mk_p_drop2floods","verdict")]),
      row.names = FALSE)

tally <- table(factor(as.character(verdict_tbl$verdict),
                      levels = names(EXPECTED_TALLY)))
message("\nCensus verdict tally:")
print(tally)
message(sprintf("Expected (RATIFIED census): no_trend=%d · non_stationary=%d · directional_trend=%d",
                EXPECTED_TALLY["no_trend"], EXPECTED_TALLY["non_stationary"], EXPECTED_TALLY["directional_trend"]))
message("F5-sample gate was 8/1/0; the one ratified difference is Riverine low ",
        "(non_stationary -> no_trend), a 40-point sparsity artefact (54% false-positive ",
        "rate across 1,000 draws). See the header for the full reasoning.")

## Per-stratum comparison to the F5-sample F6 verdicts (the direct hardening check).
sample_verdict_path <- file.path(diagnostics_dir, "f6_verdict_summary.csv")
verdict_delta <- NULL
if (file.exists(sample_verdict_path)) {
  sv <- readr::read_csv(sample_verdict_path, show_col_types = FALSE) |>
    dplyr::transmute(stratum, verdict_sample = as.character(verdict))
  verdict_delta <- verdict_tbl |>
    dplyr::transmute(stratum, community, regime_band, verdict_census = as.character(verdict)) |>
    dplyr::left_join(sv, by = "stratum") |>
    dplyr::mutate(changed = verdict_census != verdict_sample)
  message("\nCensus vs F5-sample verdict, per stratum (changed = TRUE is a red flag):")
  print(as.data.frame(verdict_delta[, c("community","regime_band","verdict_sample","verdict_census","changed")]),
        row.names = FALSE)
  gayini_write_csv(verdict_delta, file.path(diagnostics_dir, "tier2H_h32_f6_verdict_delta_vs_sample.csv"))
}

gayini_write_csv(verdict_tbl, file.path(diagnostics_dir, "tier2H_h32_census_f6_verdicts.csv"))

message(sprintf("\nAeolian low (vacuous check): max annual freq = %.4f%%, mean = %.4f%% -> %s series; ",
                ael_low_max, ael_low_mean,
                if (ael_low_max < 1) "flat near-zero" else "non-trivial"),
        "its 'no_trend' verdict is trivially true (a flat series cannot trend) -- report as vacuous, not evidence.")

tally_ok <- identical(as.integer(tally[names(EXPECTED_TALLY)]), as.integer(EXPECTED_TALLY))
changed_strata <- if (!is.null(verdict_delta))
  sort(verdict_delta$stratum[which(verdict_delta$changed)]) else character(0)
## Exactly the one ratified change is allowed; anything else is unexplained.
changed_ok <- identical(changed_strata, sort(EXPECTED_CHANGED))


## 7. H3.2 acceptance gate — the RATIFIED census result must reproduce ----
##    (9/0/0, with Riverine low as the single ratified change vs the F5 gate)

if (!tally_ok || !changed_ok) {
  message("\n########## H3.2 UNEXPECTED VERDICT — STOPPING BEFORE H3.3 ##########")
  message("Census tally must be 9/0/0 with Riverine low as the ONLY change vs the F5 gate. ",
          "Riverine low's move is ratified (sparsity artefact); any OTHER movement is ",
          "unexplained and must be investigated, not absorbed.")
  message("  changed strata observed: ",
          if (length(changed_strata)) paste(changed_strata, collapse = " ; ") else "(none)")
  ## Persist a minimal QA note before stopping.
  jsonlite::write_json(list(step = "H3.2", status = "UNEXPECTED_VERDICT",
                            tally = as.list(as.integer(tally)),
                            expected = as.list(as.integer(EXPECTED_TALLY)),
                            changed_strata = changed_strata,
                            expected_changed = EXPECTED_CHANGED),
                       file.path(diagnostics_dir, "tier2H_trackA_qa.json"),
                       auto_unbox = TRUE, pretty = TRUE)
  stop("H3.2 census verdict is not the ratified 9/0/0 — stop and report (do not run H3.3).",
       call. = FALSE)
}
message("\n==> H3.2 PASSED: census verdict = the ratified 9 no-trend / 0 / 0; Riverine low is ",
        "the only change vs the F5 gate (ratified sparsity artefact), all eight others unchanged.")


## 8. H3.3 — per-year cut (only reached if 8/1/0 holds) ----

message("\n================ H3.3 · Per-year cut ================")
per_year_community <- series_long |>
  dplyr::group_by(year, community) |>
  dplyr::summarise(freq_pct = headline(n_wet, n_valid), .groups = "drop") |>
  tidyr::pivot_wider(names_from = community, values_from = freq_pct)

per_year_farm <- series_long |>
  dplyr::group_by(year) |>
  dplyr::summarise(farm_focus_freq_pct = headline(n_wet, n_valid),
                   n_valid_px = sum(n_valid), n_wet_px = sum(n_wet), .groups = "drop") |>
  dplyr::mutate(flood_rank = rank(-farm_focus_freq_pct, ties.method = "min"))

per_year <- dplyr::left_join(per_year_farm, per_year_community, by = "year") |>
  dplyr::arrange(year)

message("Per-year focus-area flood frequency (episodic signal; top-5 flood years flagged):")
print(as.data.frame(per_year |> dplyr::mutate(top5 = flood_rank <= 5)), row.names = FALSE)
gayini_write_csv(per_year, file.path(diagnostics_dir, "tier2H_h33_per_year_cut.csv"))


## 9. QA json ----

qa <- list(
  step = "Track A (H3.1 + H3.2 + H3.3)", generated_by = "scripts/03_inundation_products/12_run_census_trend_test.R",
  option = "2 (decouple): F5 band edges, NN-stack frequency arithmetic",
  n_years = n_years, min_valid_years = MIN_VALID_YEARS,
  matrix_community = lapply(seq_len(nrow(matrix_community)), function(i) as.list(matrix_community[i, ])),
  f6 = list(tally = as.list(as.integer(tally)),
            expected_census = as.list(as.integer(EXPECTED_TALLY)),
            f5_sample_gate = list(no_trend = 8L, non_stationary = 1L, directional_trend = 0L),
            tally_ok = tally_ok, changed_vs_sample = changed_strata,
            changed_as_ratified = changed_ok,
            ratified_change_reason = paste(
              "Riverine low non_stationary -> no_trend: 40-point sparsity artefact.",
              "1,000 random 40-pt draws from this census stratum give p<0.05 in 541",
              "(54% false-positive vs nominal 5%); median 29/35 zero-years per draw;",
              "mean tau across draws +0.258 vs census +0.126."),
            aeolian_low_max_freq_pct = round(ael_low_max, 4),
            aeolian_low_vacuous = ael_low_max < 1),
  outputs = list(
    matrix = "Output/diagnostics/tier2H_h31_census_matrix.csv",
    series = "Output/diagnostics/tier2H_h31_census_stratum_annual_series.csv",
    verdicts = "Output/diagnostics/tier2H_h32_census_f6_verdicts.csv",
    per_year = "Output/diagnostics/tier2H_h33_per_year_cut.csv")
)
jsonlite::write_json(qa, file.path(diagnostics_dir, "tier2H_trackA_qa.json"),
                     auto_unbox = TRUE, pretty = TRUE, digits = 6)


## 10. Summary ----

message("\n==================== TRACK A COMPLETE ====================")
message("H3.1 census matrix : Output/diagnostics/tier2H_h31_census_matrix.csv")
message("H3.2 F6 verdict     : 9 no-trend / 0 non-stationary / 0 directional (ratified). The",
        " 'thinly sampled / provisional' caveat is gone by construction; Riverine low's",
        " sample-era non-stationary flag was a 40-point sparsity artefact.")
message("H3.3 per-year cut   : Output/diagnostics/tier2H_h33_per_year_cut.csv")
message("Aeolian low         : vacuous no_trend (near-flat-zero series) — report to Adrian, don't count as evidence.")
