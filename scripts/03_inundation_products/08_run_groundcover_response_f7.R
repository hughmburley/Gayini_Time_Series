# ------------------------------------------------------------------------------
# Script: scripts/03_inundation_products/08_run_groundcover_response_f7.R
# Purpose: Tier 1 · Task E (F7). THE GROUND-COVER RESPONSE TEST — the primary
#          analytical rung of the reshaped Phase D. F6 shut the gate (no stratum
#          trends; the system is flood-pulse driven). F7 asks the one live
#          question: within each vegetation x flood-regime stratum, does ground
#          cover RESPOND to the flood pulses?
#            (1) assign each non-treed plot its F5 stratum (extract the F5
#                background flood-frequency surface at the plot centroid; apply
#                the F5 tercile breaks — strata are the F5 strata BY CONSTRUCTION);
#            (2) same-year within-plot response (PRIMARY): per-plot r + OLS slope
#                of ground cover on the wet-extent intensity across valid years;
#                summarise to community and community x band with bootstrap CIs;
#            (3) monthly lag profile (SECONDARY): per plot x lag correlation of
#                monthly cover on monthly inundation intensity at t - lag, to a
#                per-community median at each lag (supersedes script 10);
#            (4) per-stratum verdict: responds / weak_or_none / mixed;
#          plus the F7 concept + four data figures and the review bundle.
# Workflow stage: 03_inundation_products
# Run mode: analysis (DB-first; one raster extraction for plot->band) · review outputs
# Heavy processing: light (57-point extraction + DB queries)
# Key inputs:
#   - Output/database/Gayini_Results.sqlite
#       v_plot_year_analysis_spine, stg_canonical_ground_cover_timeseries,
#       stg_canonical_daily_inundation_monthly, dim_plot
#   - Output/rasters/background_flood_frequency_8058.tif  (F5 surface)
#   - Output/diagnostics/regime_band_breaks.csv           (F5 tercile breaks)
# Key outputs:
#   - Output/csv/{f7_response_by_plot, f7_response_summary, f7_lag_profile}.csv
#   - Output/diagnostics/f7_plot_stratum.csv
#   - Output/figures/F7_concept.{svg,pdf}
#   - Output/figures/F7_{response_by_community,strata_panel,lag_profile,response_summary}_data.{png,pdf}
#   - Output/review_bundles/tier1e_f7_groundcover_response.zip
# Notes:
#   - F7 is DESCRIPTIVE support, not a trend / surface / driver analysis, and does
#     NOT reopen the gate. "Weak or no response" is a legitimate result.
#   - Metric discipline: the HEADLINE between-year flood frequency defines each
#     plot's stratum; the labelled SECONDARY wet-extent intensity CARRIES the
#     response. Never present the response axis as the headline.
#   - ONE vegetation scheme: the 4-class simplified_vegetation_group (join
#     dim_plot). period + vegetation_adrian_group are DROPPED.
#   - Mask + verdict thresholds are named constants in gayini_f7_thresholds(),
#     flagged for Adrian Q3; changing them changes VALUES, not logic.
#   - Stops at the acceptance gate; commit is a separate, human-reviewed step.
# ------------------------------------------------------------------------------

####################################################################################################


## GAYINI REMOTE SENSING PROJECT — Tier 1 Task E (F7)


####################################################################################################


## 1. Sources ----


root_dir <- getwd()

source(file.path(root_dir, "R", "gayini_helpers.R"))
source(file.path(root_dir, "R", "gayini_output_helpers.R"))
source(file.path(root_dir, "R", "gayini_gradient_helpers.R"))              # gradient vocab + manifest + DB loaders
source(file.path(root_dir, "R", "gayini_stratified_sampling_functions.R")) # regime band levels + band assignment
source(file.path(root_dir, "R", "gayini_descriptive_figures.R"))           # gayini_save_figure
source(file.path(root_dir, "R", "gayini_ground_cover_response_functions.R"))
source(file.path(root_dir, "R", "gayini_ground_cover_response_figures.R"))

suppressPackageStartupMessages({
  library(terra)
  library(dplyr)
  library(ggplot2)
})

figures_dir     <- file.path(root_dir, "Output", "figures")
diagnostics_dir <- file.path(root_dir, "Output", "diagnostics")
csv_dir         <- file.path(root_dir, "Output", "csv")
for (d in c(figures_dir, diagnostics_dir, csv_dir))
  dir.create(d, recursive = TRUE, showWarnings = FALSE)

thresholds        <- gayini_f7_thresholds()
focus_communities <- gayini_focus_levels()


## 2. Load the DB tables (DB-first) ----


con <- gayini_connect_results_db(root_dir)
spine        <- DBI::dbGetQuery(con, "SELECT * FROM v_plot_year_analysis_spine")        |> tibble::as_tibble()
gc_ts        <- DBI::dbGetQuery(con, "SELECT * FROM stg_canonical_ground_cover_timeseries") |> tibble::as_tibble()
daily_month  <- DBI::dbGetQuery(con, "SELECT * FROM stg_canonical_daily_inundation_monthly") |> tibble::as_tibble()
dim_plot     <- DBI::dbGetQuery(con, "SELECT * FROM dim_plot")                          |> tibble::as_tibble()
DBI::dbDisconnect(con)


## 3. Echo the mask + verdict thresholds (gate flag) ----


message("\nF7 thresholds (OUR defaults — flagged for Adrian Q3):")
for (nm in names(thresholds))
  message(sprintf("  %-20s = %s", nm, paste(thresholds[[nm]], collapse = ", ")))
f7_thresholds_logged <- TRUE


## 4. Assign each non-treed plot its F5 stratum ----


freq_raster_path <- file.path(root_dir, "Output", "rasters", "background_flood_frequency_8058.tif")
breaks_csv_path  <- file.path(root_dir, "Output", "diagnostics", "regime_band_breaks.csv")

plot_stratum <- gayini_f7_assign_plot_strata(dim_plot, freq_raster_path, breaks_csv_path,
                                             focus_communities = focus_communities)

message(sprintf("\nStratum assignment: %d non-treed plots banded low/mid/high (F5 surface + F5 breaks).",
                nrow(plot_stratum)))
print(table(community = plot_stratum$community, band = plot_stratum$regime_band))

gayini_write_csv(plot_stratum, file.path(diagnostics_dir, "f7_plot_stratum.csv"))


## 5. Same-year within-plot response (PRIMARY) ----


response_by_plot <- gayini_f7_same_year_response(spine, plot_stratum, thresholds = thresholds)

community_summary <- gayini_f7_summarise_response(response_by_plot, by = "community", thresholds = thresholds)
response_summary  <- gayini_f7_summarise_response(response_by_plot, by = "stratum",   thresholds = thresholds)

message("\nCommunity-level same-year response (median veg r, dry->wet):")
print(community_summary |> dplyr::select("community", "n_plots", "median_r_veg",
                                         "median_r_bare", "sign_frac_pos",
                                         "ci_lo_veg", "ci_hi_veg"))

message("\nPer-stratum verdicts:")
print(response_summary |> dplyr::select("community", "regime_band", "n_plots",
                                        "median_r_veg", "sign_frac_pos", "verdict"),
      n = nrow(response_summary))
message("\nVerdict tally:"); print(table(response_summary$verdict))

gayini_write_csv(response_by_plot, file.path(csv_dir, "f7_response_by_plot.csv"))
gayini_write_csv(response_summary, file.path(csv_dir, "f7_response_summary.csv"))


## 6. Monthly lag profile (SECONDARY) — supersedes script 10 ----


lag <- gayini_f7_monthly_lag_profile(gc_ts, daily_month, dim_plot, thresholds = thresholds)
lag_pairs   <- lag$lag_pairs
lag_profile <- lag$lag_profile
peak_lag    <- lag$peak_lag

message("\nMonthly lag profile (median cover~intensity r per community x lag):")
print(lag_profile |> dplyr::select("simplified_vegetation_group", "lag_months",
                                   "n_plots", "median_r"), n = nrow(lag_profile))
message("\nPeak lag per community:")
print(peak_lag)

gayini_write_csv(lag_profile, file.path(csv_dir, "f7_lag_profile.csv"))


## 7. F7 figure set (one figure = one file = one slide) ----


## Masked plot-year points (usable plots only) for the response-by-community spaghetti.
usable_plot_ids <- response_by_plot$plot_id[response_by_plot$usable]
plot_year_masked <- spine |>
  dplyr::filter(.data$treed_plot_flag == 0,
                .data$ground_cover_exclusion_flag == 0,
                .data$plot_id %in% usable_plot_ids,
                .data$annual_valid_coverage_pct >= thresholds$MIN_VALID_COVERAGE,
                !is.na(.data$mean_total_veg_pct), !is.na(.data$annual_occurrence_pct)) |>
  dplyr::transmute(plot_id,
                   community = factor(as.character(.data$simplified_vegetation_group),
                                      levels = focus_communities),
                   annual_occurrence_pct, total_veg_pct = .data$mean_total_veg_pct)

f7_concept  <- gayini_build_f7_concept(out_dir = figures_dir)
f7_by_comm  <- gayini_build_f7_response_by_community(plot_year_masked, community_summary, out_dir = figures_dir)
f7_strata   <- gayini_build_f7_strata_panel(response_by_plot, response_summary, out_dir = figures_dir,
                                            thresholds = thresholds)
f7_lag      <- gayini_build_f7_lag_profile(lag_profile, peak_lag, out_dir = figures_dir)
f7_summary  <- gayini_build_f7_response_summary(response_summary, peak_lag, out_dir = figures_dir)


## 8. Register in the figures manifest ----


spine_inputs <- "v_plot_year_analysis_spine (annual_occurrence_pct = SECONDARY wet-extent intensity)"
band_inputs  <- "dim_plot centroids -> background_flood_frequency_8058.tif + regime_band_breaks.csv (F5)"
lag_inputs   <- "stg_canonical_ground_cover_timeseries + stg_canonical_daily_inundation_monthly (4-class; period/adrian dropped)"

new_rows <- dplyr::bind_rows(
  gayini_manifest_row("F7", "concept", f7_concept$svg, "schematic (illustrative)", "n/a", root_dir),
  gayini_manifest_row("F7", "concept", f7_concept$pdf, "schematic (illustrative)", "n/a", root_dir),
  gayini_manifest_row("F7", "data",    f7_by_comm$png, paste(spine_inputs, band_inputs, sep = " + "), "EPSG:9473 pts -> 8058 extract", root_dir),
  gayini_manifest_row("F7", "data",    f7_by_comm$pdf, paste(spine_inputs, band_inputs, sep = " + "), "EPSG:9473 pts -> 8058 extract", root_dir),
  gayini_manifest_row("F7", "data",    f7_strata$png,  paste(spine_inputs, band_inputs, sep = " + "), "EPSG:9473 pts -> 8058 extract", root_dir),
  gayini_manifest_row("F7", "data",    f7_strata$pdf,  paste(spine_inputs, band_inputs, sep = " + "), "EPSG:9473 pts -> 8058 extract", root_dir),
  gayini_manifest_row("F7", "data",    f7_lag$png,     lag_inputs, "n/a", root_dir),
  gayini_manifest_row("F7", "data",    f7_lag$pdf,     lag_inputs, "n/a", root_dir),
  gayini_manifest_row("F7", "data",    f7_summary$png, "f7_response_summary.csv + f7_lag_profile.csv", "n/a", root_dir),
  gayini_manifest_row("F7", "data",    f7_summary$pdf, "f7_response_summary.csv + f7_lag_profile.csv", "n/a", root_dir)
)

manifest <- gayini_update_figures_manifest(new_rows, root = root_dir)


## 9. Acceptance gate (must pass before commit) ----


bundle_zip <- file.path(root_dir, "Output", "review_bundles", "tier1e_f7_groundcover_response.zip")

stopifnot(
  # --- one vegetation scheme, non-treed focus, no pre/post leakage ---
  all(as.character(response_by_plot$simplified_vegetation_group) %in% gayini_focus_levels()),
  !any(c("period", "vegetation_adrian_group") %in% names(lag_pairs)),
  # --- strata tied to F5 ---
  all(as.character(plot_stratum$regime_band) %in% c("low", "mid", "high")),
  nrow(plot_stratum) == 57,
  # --- same-year response computed and summarised ---
  all(!is.na(response_summary$median_r_veg)),
  all(as.character(response_summary$verdict) %in% c("responds", "weak_or_none", "mixed")),
  # confirmatory: community-level dry->wet strengthening recovered
  with(community_summary,
       median_r_veg[community == "Inland Floodplain Shrublands / Swamps"] >
       median_r_veg[community == "Aeolian Chenopod Shrublands"]),
  # --- lag profile computed at all lags, superseding script 10 ---
  all(c(0, 3, 6, 9, 12) %in% lag_profile$lag_months),
  # --- masks + thresholds auditable ---
  exists("f7_thresholds_logged"), isTRUE(f7_thresholds_logged),
  # --- figures one-per-file per convention ---
  file.exists(file.path(figures_dir, "F7_concept.svg")),
  file.exists(file.path(figures_dir, "F7_response_by_community_data.pdf")),
  file.exists(file.path(figures_dir, "F7_strata_panel_data.pdf")),
  file.exists(file.path(figures_dir, "F7_lag_profile_data.pdf")),
  file.exists(file.path(figures_dir, "F7_response_summary_data.pdf"))
)


## 10. Package for review (standing convention) ----


bundle_dir      <- file.path(root_dir, "Output", "review_bundles", "tier1e_f7_groundcover_response")
bundle_fig_dir  <- file.path(bundle_dir, "figures")
bundle_diag_dir <- file.path(bundle_dir, "diagnostics")
unlink(bundle_dir, recursive = TRUE, force = TRUE)
for (d in c(bundle_fig_dir, bundle_diag_dir))
  dir.create(d, recursive = TRUE, showWarnings = FALSE)

figure_files <- list.files(figures_dir, pattern = "^F7_.*\\.(png|pdf|svg)$", full.names = TRUE)
file.copy(figure_files, bundle_fig_dir, overwrite = TRUE)
file.copy(file.path(figures_dir, "figures_manifest.csv"), bundle_dir, overwrite = TRUE)
readr::write_csv(new_rows, file.path(bundle_dir, "manifest_rows_tier1e.csv"))

## Diagnostics + data products behind every figure.
file.copy(c(file.path(csv_dir, "f7_response_by_plot.csv"),
            file.path(csv_dir, "f7_response_summary.csv"),
            file.path(csv_dir, "f7_lag_profile.csv"),
            file.path(diagnostics_dir, "f7_plot_stratum.csv")),
          bundle_diag_dir, overwrite = TRUE)

change_report_path <- file.path(root_dir, "docs", "change_reports", "tier1e_f7_groundcover_response.md")
if (file.exists(change_report_path)) file.copy(change_report_path, bundle_dir, overwrite = TRUE)

if (file.exists(bundle_zip)) unlink(bundle_zip, force = TRUE)
zip::zip(
  zipfile = bundle_zip,
  files   = list.files(bundle_dir, recursive = TRUE, full.names = FALSE),
  root    = bundle_dir
)
message("Wrote review bundle: ", bundle_zip)

stopifnot(file.exists(bundle_zip))


## 11. Final summary ----


message("\n==================== ACCEPTANCE GATE PASSED ====================")
message("Non-treed plots banded:  ", nrow(plot_stratum), " (57 = 66 - 9 treed)")
message("Usable same-year plots:  ", sum(response_by_plot$usable))
message("Verdict tally:"); print(table(response_summary$verdict))
message("Response by plot:  ", file.path(csv_dir, "f7_response_by_plot.csv"))
message("Response summary:  ", file.path(csv_dir, "f7_response_summary.csv"))
message("Lag profile:       ", file.path(csv_dir, "f7_lag_profile.csv"))
message("F7 concept:        ", f7_concept$pdf)
message("F7 by community:   ", f7_by_comm$pdf)
message("F7 strata panel:   ", f7_strata$pdf)
message("F7 lag profile:    ", f7_lag$pdf)
message("F7 response table: ", f7_summary$pdf)
message("Review bundle:     ", bundle_zip)
message("\nSTOP: F7 is descriptive support — it does NOT build a surface, model ",
        "drivers, or reopen the gate.\nReview Output/review_bundles/",
        "tier1e_f7_groundcover_response.zip with Adrian before committing.")


####################################################################################################
############################################ TBC ###################################################
####################################################################################################
