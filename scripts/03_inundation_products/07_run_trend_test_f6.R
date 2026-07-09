# ------------------------------------------------------------------------------
# Script: scripts/03_inundation_products/07_run_trend_test_f6.R
# Purpose: Tier 1 · Task D (F6). THE TREND TEST — the gate for Phase D.
#          For each vegetation x regime stratum from the F5 frame:
#          (1) extract each sample point's 35-year annual wet/valid series from
#              the categorical stack (points reprojected to the stack CRS; the
#              stack is read-only and NEVER resampled);
#          (2) aggregate to one annual flood-frequency series per stratum;
#          (3) fit three things and show them together — Theil-Sen + Mann-Kendall
#              (primary, robust), OLS (reference), LOESS (shape);
#          (4) run the episodic-robustness check (drop each stratum's two biggest
#              flood years and re-test);
#          (5) assign a per-stratum verdict: no_trend / directional_trend /
#              non_stationary (episodic);
#          plus the F6 concept + two data figures and the review bundle.
# Workflow stage: 03_inundation_products
# Run mode: analysis (point extraction + trend tests) · lightweight_review outputs
# Heavy processing: moderate (360 points x 35-band extraction)
# Key inputs:
#   - Output/spatial_8058/stratified_sample_points.gpkg  (360 pts, 9 strata; F5)
#   - Output/rasters/inundation_annual_stack/annual_{wet,valid}_any_1988_2023.tif
#     (EPSG:28355, 35 bands) — reproject POINTS to 28355; never resample the stack.
# Key outputs:
#   - Output/diagnostics/{f6_stratum_annual_series, f6_verdict_summary}.csv
#   - Output/figures/F6_concept.{svg,pdf}
#   - Output/figures/F6_strata_trends_data.{png,pdf}
#   - Output/figures/F6_verdict_summary_data.{png,pdf}
#   - Output/review_bundles/tier1d_trend_test.zip
# Notes:
#   - F6 produces VERDICTS + EVIDENCE. It does NOT build a surface and does NOT
#     auto-advance to Phase D; that is a human call (with Adrian) for strata that
#     earn a directional-trend verdict. "No trend" and "non-stationary" are
#     legitimate, reportable results.
#   - Verdict thresholds are named constants in gayini_trend_thresholds(),
#     flagged for Adrian/stats review; changing them changes VALUES, not logic.
#   - Trend tests (Mann-Kendall, Theil-Sen + CI) are base-R implementations so the
#     logic is auditable end-to-end; no new package dependency.
#   - Stops at the acceptance gate; commit is a separate, human-reviewed step.
# ------------------------------------------------------------------------------

####################################################################################################


## GAYINI REMOTE SENSING PROJECT — Tier 1 Task D (F6)


####################################################################################################


## 1. Sources ----


root_dir <- getwd()

source(file.path(root_dir, "R", "gayini_helpers.R"))
source(file.path(root_dir, "R", "vector_prep_functions.R"))        # gayini_read_vector
source(file.path(root_dir, "R", "gayini_output_helpers.R"))
source(file.path(root_dir, "R", "gayini_gradient_helpers.R"))       # gradient vocab + manifest helpers
source(file.path(root_dir, "R", "gayini_stratified_sampling_functions.R"))  # regime band levels
source(file.path(root_dir, "R", "gayini_descriptive_figures.R"))    # gayini_save_figure
source(file.path(root_dir, "R", "gayini_trend_test_functions.R"))
source(file.path(root_dir, "R", "gayini_trend_test_figures.R"))

suppressPackageStartupMessages({
  library(sf)
  library(terra)
  library(dplyr)
  library(ggplot2)
})

sf::sf_use_s2(FALSE)

figures_dir     <- file.path(root_dir, "Output", "figures")
diagnostics_dir <- file.path(root_dir, "Output", "diagnostics")
spatial_dir     <- file.path(root_dir, "Output", "spatial_8058")

focus_communities <- gayini_focus_levels()
band_levels       <- gayini_regime_band_levels()
thresholds        <- gayini_trend_thresholds()


## 2. Load the F5 sampling frame ----


points_path <- file.path(spatial_dir, "stratified_sample_points.gpkg")
pts <- gayini_read_vector(points_path, label = "stratified sample points (F5)")

pts$community   <- factor(as.character(pts$community),   levels = focus_communities)
pts$regime_band <- factor(as.character(pts$regime_band), levels = band_levels)
pts$stratum     <- paste(as.character(pts$community), as.character(pts$regime_band), sep = " | ")

stopifnot(all(!is.na(pts$community)), all(!is.na(pts$regime_band)))


## 3. Extract each point's 35-year annual wet/valid series ----


wet_path   <- file.path(root_dir, "Output", "rasters", "inundation_annual_stack",
                        "annual_wet_any_1988_2023.tif")
valid_path <- file.path(root_dir, "Output", "rasters", "inundation_annual_stack",
                        "annual_valid_any_1988_2023.tif")

extraction <- gayini_extract_point_series(pts, wet_path, valid_path)
pts_years  <- extraction$points   # carries per-point `valid_years` (from the stack)

message(sprintf("Extracted %d points x %d years. Per-point valid years: min %d, median %d, max %d.",
                nrow(pts_years), length(extraction$years),
                min(pts_years$valid_years), stats::median(pts_years$valid_years),
                max(pts_years$valid_years)))


## 4. Per stratum x year: annual flood-frequency series ----


series_long <- gayini_stratum_annual_series(extraction, pts_years$stratum)

## Attach community + regime_band to each stratum series (for facets / ordering).
stratum_meta <- pts_years |>
  sf::st_drop_geometry() |>
  dplyr::distinct(.data$stratum, .data$community, .data$regime_band) |>
  dplyr::arrange(.data$community, .data$regime_band)

series_long <- series_long |>
  dplyr::left_join(stratum_meta, by = "stratum")

## Diagnostics: the raw annual series (audit trail for every verdict).
series_csv <- file.path(diagnostics_dir, "f6_stratum_annual_series.csv")
gayini_write_csv(series_long |>
                   dplyr::select("community", "regime_band", "stratum",
                                 "year", "n_valid", "n_wet", "freq_pct"),
                 series_csv)

n_strata               <- length(unique(series_long$stratum))
strata_series_length   <- as.integer(table(series_long$stratum))


## 5. Run the three fits + episodic-robustness + verdict, per stratum ----


## Echo the verdict thresholds so the logic is auditable (gate flag).
message("\nVerdict thresholds (OUR defaults — flagged for Adrian/stats review):")
for (nm in names(thresholds)) message(sprintf("  %-22s = %s", nm, thresholds[[nm]]))
verdict_thresholds_logged <- TRUE

trend       <- gayini_run_trend_tests(series_long, stratum_meta, thresholds = thresholds)
verdict_tbl <- trend$verdict_tbl

message("\nPer-stratum verdicts:")
print(verdict_tbl |>
        dplyr::select("community", "regime_band", "theil_sen_slope", "mk_tau",
                      "mk_p", "ols_r2", "flood_drop_robust", "loess_monotonic",
                      "mk_p_drop2floods", "verdict"),
      n = nrow(verdict_tbl))

message("\nVerdict tally:")
print(table(verdict_tbl$verdict))

## Diagnostics: the verdict table (the headline deliverable).
verdict_csv <- file.path(diagnostics_dir, "f6_verdict_summary.csv")
gayini_write_csv(verdict_tbl, verdict_csv)


## 6. F6 figure trio (one figure = one file = one slide) ----


f6_concept <- gayini_build_f6_concept(out_dir = figures_dir)
f6_strata  <- gayini_build_f6_strata_trends(series_long, trend, out_dir = figures_dir)
f6_verdict <- gayini_build_f6_verdict_summary(trend, out_dir = figures_dir)


## 7. Register in the figures manifest ----


stack_inputs  <- "annual_{wet,valid}_any_1988_2023.tif (EPSG:28355 stack)"
series_inputs <- paste("stratified_sample_points.gpkg [series extracted from", stack_inputs, "]")

new_rows <- dplyr::bind_rows(
  gayini_manifest_row("F6", "concept", f6_concept$svg, "schematic (illustrative)", "n/a", root_dir),
  gayini_manifest_row("F6", "concept", f6_concept$pdf, "schematic (illustrative)", "n/a", root_dir),
  gayini_manifest_row("F6", "data",    f6_strata$png,  series_inputs, "EPSG:8058 pts -> 28355 extract", root_dir),
  gayini_manifest_row("F6", "data",    f6_strata$pdf,  series_inputs, "EPSG:8058 pts -> 28355 extract", root_dir),
  gayini_manifest_row("F6", "data",    f6_verdict$png, "f6_verdict_summary.csv", "n/a", root_dir),
  gayini_manifest_row("F6", "data",    f6_verdict$pdf, "f6_verdict_summary.csv", "n/a", root_dir)
)

manifest <- gayini_update_figures_manifest(new_rows, root = root_dir)


## 8. Acceptance gate (must pass before commit) ----


bundle_zip <- file.path(root_dir, "Output", "review_bundles", "tier1d_trend_test.zip")

stopifnot(
  # extraction
  all(pts_years$valid_years >= 25),
  n_strata == 9, all(strata_series_length == 35),
  # tests computed per stratum
  all(!is.na(verdict_tbl$theil_sen_slope)),
  all(!is.na(verdict_tbl$mk_p)),
  all(as.character(verdict_tbl$verdict) %in%
        c("no_trend", "directional_trend", "non_stationary")),
  # episodic-robustness actually run
  all(!is.na(verdict_tbl$mk_p_drop2floods)),
  # figures one-per-file per convention
  file.exists(file.path(figures_dir, "F6_strata_trends_data.pdf")),
  file.exists(file.path(figures_dir, "F6_verdict_summary_data.pdf")),
  file.exists(file.path(figures_dir, "F6_concept.pdf"))
)
# thresholds echoed to the log so the verdict logic is auditable
stopifnot(exists("verdict_thresholds_logged"), isTRUE(verdict_thresholds_logged))


## 9. Package for review (standing convention) ----


bundle_dir      <- file.path(root_dir, "Output", "review_bundles", "tier1d_trend_test")
bundle_fig_dir  <- file.path(bundle_dir, "figures")
bundle_diag_dir <- file.path(bundle_dir, "diagnostics")
unlink(bundle_dir, recursive = TRUE, force = TRUE)
for (d in c(bundle_fig_dir, bundle_diag_dir))
  dir.create(d, recursive = TRUE, showWarnings = FALSE)

## Figures (all formats) + manifest + this task's manifest rows.
figure_files <- list.files(figures_dir, pattern = "^F6_.*\\.(png|pdf|svg)$", full.names = TRUE)
file.copy(figure_files, bundle_fig_dir, overwrite = TRUE)
file.copy(file.path(figures_dir, "figures_manifest.csv"), bundle_dir, overwrite = TRUE)
readr::write_csv(new_rows, file.path(bundle_dir, "manifest_rows_tier1d.csv"))

## Diagnostics: the verdict table + the raw annual series behind it.
file.copy(c(verdict_csv, series_csv), bundle_diag_dir, overwrite = TRUE)

## A copy of the change report (report itself stays local / uncommitted).
change_report_path <- file.path(root_dir, "docs", "change_reports", "tier1d_trend_test.md")
if (file.exists(change_report_path)) file.copy(change_report_path, bundle_dir, overwrite = TRUE)

if (file.exists(bundle_zip)) unlink(bundle_zip, force = TRUE)
zip::zip(
  zipfile = bundle_zip,
  files   = list.files(bundle_dir, recursive = TRUE, full.names = FALSE),
  root    = bundle_dir
)
message("Wrote review bundle: ", bundle_zip)

stopifnot(file.exists(bundle_zip))


## 10. Final summary ----


message("\n==================== ACCEPTANCE GATE PASSED ====================")
message("Strata tested: ", n_strata, " (each a 35-year annual series)")
message("Verdict tally:")
print(table(verdict_tbl$verdict))
message("Verdict table:   ", verdict_csv)
message("Annual series:   ", series_csv)
message("F6 concept:      ", f6_concept$pdf)
message("F6 strata trends:", f6_strata$pdf)
message("F6 verdict table:", f6_verdict$pdf)
message("Review bundle:   ", bundle_zip)
message("\nSTOP: F6 produces verdicts + evidence, it does NOT build a surface or ",
        "advance to Phase D.\nReview Output/review_bundles/tier1d_trend_test.zip ",
        "(esp. F6_strata_trends_data.pdf + F6_verdict_summary_data.pdf) with Adrian ",
        "before committing.")


####################################################################################################
############################################ TBC ###################################################
####################################################################################################
