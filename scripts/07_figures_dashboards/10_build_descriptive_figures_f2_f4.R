# ------------------------------------------------------------------------------
# Script: scripts/07_figures_dashboards/10_build_descriptive_figures_f2_f4.R
# Purpose: Tier 1 · Task B. Build the descriptive figure pairs F2-F4 on the
#          three-class flooding gradient (database-only; no CRS/raster/reproject).
# Workflow stage: 07_figures_dashboards
# Run mode: lightweight_review
# Heavy processing: no
# Key inputs (all from Output/database/Gayini_Results.sqlite):
#   - v_plot_year_analysis_spine
#   - v_plot_timeseries_inundation_annual
#   - dim_plot
# Key outputs:
#   - Output/figures/F2_*  F3_*  F4_*  ({concept .svg/.pdf}, {data .png/.pdf})
#   - Output/figures/figures_manifest.csv          (F2-F4 rows merged in)
#   - Output/diagnostics/community_occurrence_summary.csv
#   - Output/review_bundles/tier1b_descriptive_figures/  + .zip
# Notes:
#   - Runs independently of Task A. Stops at the acceptance gate; commit is a
#     separate, human-reviewed step.
# ------------------------------------------------------------------------------

####################################################################################################


## GAYINI REMOTE SENSING PROJECT — Tier 1 Task B (F2-F4)


####################################################################################################


## 0. Settings + sources ----


root_dir <- getwd()

source(file.path(root_dir, "R", "gayini_helpers.R"))
source(file.path(root_dir, "R", "gayini_output_helpers.R"))
source(file.path(root_dir, "R", "gayini_gradient_helpers.R"))
source(file.path(root_dir, "R", "gayini_descriptive_figures.R"))

suppressPackageStartupMessages({
  library(DBI)
  library(RSQLite)
  library(dplyr)
  library(ggplot2)
})

figures_dir <- file.path(root_dir, "Output", "figures")


## 1. Load the spine + inundation series ----


spine         <- gayini_load_spine(root_dir)
inundation_ts <- gayini_load_inundation_timeseries(root_dir)

message("Loaded spine: ", nrow(spine), " rows, ",
        dplyr::n_distinct(spine$plot_id), " plots, ",
        length(unique(spine$water_year)), " water years.")


## 2. Community summary — HEADLINE flood frequency + SECONDARY wet extent ----


## Per-plot between-year flood frequency (headline) carries the secondary
## within-year wet-extent coverage alongside it.
plot_frequency <- gayini_plot_between_year_frequency(spine) |>
  gayini_apply_gradient_order()

community_summary <- plot_frequency |>
  dplyr::group_by(simplified_vegetation_group, is_focus_community) |>
  dplyr::summarise(
    n_plots = dplyr::n(),
    headline_flood_frequency_pct   = round(mean(flood_frequency_pct), 2),      # % of years wet
    median_flood_frequency_pct     = round(stats::median(flood_frequency_pct), 2),
    secondary_wet_extent_coverage_pct = round(mean(wet_extent_coverage_pct), 2), # within-year coverage
    .groups = "drop"
  ) |>
  dplyr::arrange(simplified_vegetation_group)

diagnostics_dir <- file.path(root_dir, "Output", "diagnostics")
community_summary_path <- file.path(diagnostics_dir, "community_occurrence_summary.csv")
gayini_write_csv(community_summary, community_summary_path)
print(community_summary)


## 3. Build the three figure pairs ----


f2_concept <- gayini_build_f2_concept(inundation_ts, out_dir = figures_dir)
f2_data    <- gayini_build_f2_data(spine, out_dir = figures_dir)

f3_concept <- gayini_build_f3_concept(out_dir = figures_dir)
f3_data    <- gayini_build_f3_data(spine, out_dir = figures_dir)
f3_data_cov <- gayini_build_f3_data_coverage_secondary(spine, out_dir = figures_dir)  # secondary metric

f4_concept <- gayini_build_f4_concept(out_dir = figures_dir)
f4_data    <- gayini_build_f4_data(spine, out_dir = figures_dir)


## 4. Register all six figures in the manifest ----


spine_inputs <- "v_plot_year_analysis_spine (Gayini_Results.sqlite)"
ts_inputs    <- "v_plot_timeseries_inundation_annual (Gayini_Results.sqlite)"

new_rows <- dplyr::bind_rows(
  gayini_manifest_row("F2", "concept", f2_concept$svg, ts_inputs, "n/a", root_dir),
  gayini_manifest_row("F2", "concept", f2_concept$pdf, ts_inputs, "n/a", root_dir),
  gayini_manifest_row("F2", "data",    f2_data$png,    spine_inputs, "n/a", root_dir),
  gayini_manifest_row("F2", "data",    f2_data$pdf,    spine_inputs, "n/a", root_dir),
  gayini_manifest_row("F3", "concept", f3_concept$svg, "schematic (no data)", "n/a", root_dir),
  gayini_manifest_row("F3", "concept", f3_concept$pdf, "schematic (no data)", "n/a", root_dir),
  gayini_manifest_row("F3", "data",    f3_data$png,    spine_inputs, "n/a", root_dir),
  gayini_manifest_row("F3", "data",    f3_data$pdf,    spine_inputs, "n/a", root_dir),
  gayini_manifest_row("F3", "data-secondary", f3_data_cov$png, paste0(spine_inputs, " [wet-extent coverage]"), "n/a", root_dir),
  gayini_manifest_row("F3", "data-secondary", f3_data_cov$pdf, paste0(spine_inputs, " [wet-extent coverage]"), "n/a", root_dir),
  gayini_manifest_row("F4", "concept", f4_concept$svg, "schematic (no data)", "n/a", root_dir),
  gayini_manifest_row("F4", "concept", f4_concept$pdf, "schematic (no data)", "n/a", root_dir),
  gayini_manifest_row("F4", "data",    f4_data$png,    spine_inputs, "n/a", root_dir),
  gayini_manifest_row("F4", "data",    f4_data$pdf,    spine_inputs, "n/a", root_dir)
)

manifest <- gayini_update_figures_manifest(new_rows, root = root_dir)


## 5. Acceptance gate (must pass before commit) ----


stopifnot(
  nrow(spine) == 2310, dplyr::n_distinct(spine$plot_id) == 66,
  length(unique(spine$water_year)) == 35,
  all(spine$annual_occurrence_pct >= 0 & spine$annual_occurrence_pct <= 100)
)

## F4 gradient sanity — HEADLINE between-year flood frequency recovers the
## dry->wet order (Aeolian ~9%, Riverine ~22%, Inland Floodplain ~50%).
m <- tapply(plot_frequency$flood_frequency_pct,
            plot_frequency$simplified_vegetation_group, mean)
stopifnot(
  round(m["Aeolian Chenopod Shrublands"])            <= 12,
  round(m["Riverine Chenopod Shrublands"])  |> dplyr::between(18, 26),
  round(m["Inland Floodplain Shrublands / Swamps"])  >= 45,
  ## strict dry->wet ordering of the three focus communities
  m["Aeolian Chenopod Shrublands"] < m["Riverine Chenopod Shrublands"],
  m["Riverine Chenopod Shrublands"] < m["Inland Floodplain Shrublands / Swamps"]
)

## figure pairs + manifest exist under the {step}_{concept|data} convention
for (f in c("F2", "F3", "F4")) stopifnot(
  any(grepl(paste0(f, ".*concept"), manifest$path)),
  any(grepl(paste0(f, ".*data"),    manifest$path))
)


## 6. Package for review (standing convention) ----


bundle_dir <- file.path(root_dir, "Output", "review_bundles", "tier1b_descriptive_figures")
bundle_fig_dir  <- file.path(bundle_dir, "figures")
bundle_diag_dir <- file.path(bundle_dir, "diagnostics")
unlink(bundle_dir, recursive = TRUE, force = TRUE)
dir.create(bundle_fig_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(bundle_diag_dir, recursive = TRUE, showWarnings = FALSE)

## Copy the six figure pairs (all formats) + the manifest.
figure_files <- list.files(figures_dir, pattern = "^F[234]_.*\\.(png|pdf|svg)$", full.names = TRUE)
file.copy(figure_files, bundle_fig_dir, overwrite = TRUE)
file.copy(file.path(figures_dir, "figures_manifest.csv"), bundle_dir, overwrite = TRUE)

## Manifest rows for THIS task (F2-F4 only).
readr::write_csv(new_rows, file.path(bundle_dir, "manifest_rows_tier1b.csv"))

## Diagnostics + a copy of the change report (report itself stays local/uncommitted).
file.copy(community_summary_path, bundle_diag_dir, overwrite = TRUE)
change_report_path <- file.path(root_dir, "docs", "change_reports", "tier1b_descriptive_figures.md")
if (file.exists(change_report_path)) {
  file.copy(change_report_path, bundle_dir, overwrite = TRUE)
}

## Zip the bundle.
bundle_zip <- file.path(root_dir, "Output", "review_bundles", "tier1b_descriptive_figures.zip")
if (file.exists(bundle_zip)) unlink(bundle_zip, force = TRUE)
zip::zip(
  zipfile = bundle_zip,
  files = list.files(bundle_dir, recursive = TRUE, full.names = FALSE),
  root = bundle_dir
)
message("Wrote review bundle: ", bundle_zip)

stopifnot(file.exists(bundle_zip))


## 7. Summary ----


message("\n==================== ACCEPTANCE GATE PASSED ====================")
message("Spine: ", nrow(spine), " rows · ", dplyr::n_distinct(spine$plot_id),
        " plots · ", length(unique(spine$water_year)), " water years")
message("Headline flood frequency by community (% of years wet): ",
        paste(names(m), round(m, 1), sep = "=", collapse = "  "))
message("Figures: 6 pairs + 1 secondary (F3 wet-extent coverage) registered in ",
        file.path("Output", "figures", "figures_manifest.csv"))
message("Review bundle: ", bundle_zip)
message("\nSTOP: review Output/review_bundles/tier1b_descriptive_figures.zip before committing.")


####################################################################################################
############################################ TBC ###################################################
####################################################################################################
