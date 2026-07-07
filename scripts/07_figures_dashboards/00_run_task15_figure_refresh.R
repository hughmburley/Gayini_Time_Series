# ------------------------------------------------------------------------------
# Script: scripts/07_figures_dashboards/00_run_task15_figure_refresh.R
# Purpose: Run Task 15 figure, map and dashboard refresh for Adrian review.
# Workflow stage: 07_figures_dashboards
# Run mode: lightweight_review
# Heavy processing: no
# ------------------------------------------------------------------------------

root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", "D:/Github_repos/Gayini"), winslash = "/", mustWork = TRUE)
setwd(root_dir)

required_packages <- c(
  "dplyr",
  "tidyr",
  "readr",
  "stringr",
  "ggplot2",
  "sf",
  "terra",
  "patchwork",
  "scales",
  "magick",
  "ggrepel",
  "tibble"
)

missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_packages) > 0L) {
  stop("Missing required packages: ", paste(missing_packages, collapse = ", "), call. = FALSE)
}

library(dplyr)
library(tidyr)
library(readr)
library(stringr)
library(ggplot2)
library(sf)
library(terra)
library(patchwork)
library(scales)
library(tibble)

source(file.path(root_dir, "R", "gayini_output_helpers.R"))
source(file.path(root_dir, "R", "gayini_output_paths.R"))
source(file.path(root_dir, "R", "gayini_plotting_helpers.R"))
source(file.path(root_dir, "R", "gayini_figure_manifest.R"))
source(file.path(root_dir, "R", "gayini_plot_context_figures.R"))
source(file.path(root_dir, "R", "gayini_map_inundation_figures.R"))
source(file.path(root_dir, "R", "gayini_plot_hydrology_figures.R"))
source(file.path(root_dir, "R", "gayini_plot_ground_cover_figures.R"))
source(file.path(root_dir, "R", "gayini_dashboard_figures.R"))

figure_root <- file.path(root_dir, "Output", "figures", "review_refresh")
report_dir <- file.path(root_dir, "Output", "reports", "figure_refresh")

for (dir in c(
  file.path(figure_root, "context"),
  file.path(figure_root, "inundation"),
  file.path(figure_root, "hydrology"),
  file.path(figure_root, "ground_cover"),
  file.path(figure_root, "dashboards"),
  file.path(figure_root, "appendix"),
  report_dir
)) {
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
}

resolved <- gayini_resolve_task15_inputs(root_dir)
input_paths <- resolved$paths

path_check_path <- file.path(report_dir, "task15_path_resolution_checks.csv")
gayini_write_csv(resolved$checks, path_check_path)

context_result <- gayini_make_task15_context_figures(
  root_dir = root_dir,
  input_paths = input_paths,
  figure_dir = figure_root,
  report_dir = report_dir
)

map_result <- gayini_make_task15_inundation_maps(
  root_dir = root_dir,
  input_paths = input_paths,
  figure_dir = figure_root
)

hydrology_result <- gayini_make_task15_hydrology_overlap_figures(
  root_dir = root_dir,
  input_paths = input_paths,
  figure_dir = figure_root
)

ground_cover_result <- gayini_make_task15_ground_cover_figures(
  root_dir = root_dir,
  input_paths = input_paths,
  figure_dir = figure_root
)

dashboard_result <- gayini_make_task15_dashboard_figures(
  root_dir = root_dir,
  input_paths = input_paths,
  figure_dir = figure_root
)

manifest <- dplyr::bind_rows(
  context_result$manifest,
  map_result$manifest,
  hydrology_result$manifest,
  ground_cover_result$manifest,
  dashboard_result$manifest
) |>
  dplyr::arrange(.data$priority, .data$figure_id)

deck_metrics <- gayini_task15_metric_table(root_dir, input_paths)
metrics_path <- file.path(report_dir, "task15_deck_metric_recheck.csv")
gayini_write_csv(deck_metrics, metrics_path)

manifest_path <- file.path(report_dir, "Gayini_refreshed_figure_manifest.csv")
gayini_task15_write_manifest(manifest, manifest_path)

asset_register <- gayini_task15_deck_asset_register(manifest)
asset_register_path <- file.path(report_dir, "Gayini_deck_asset_register_refreshed.csv")
gayini_write_csv(asset_register, asset_register_path)

contact_sheet_path <- file.path(report_dir, "Gayini_refreshed_figure_contact_sheet.png")
gayini_task15_write_contact_sheet(
  manifest = manifest,
  root_dir = root_dir,
  output_path = contact_sheet_path,
  priority_filter = "P0"
)

session_info_path <- file.path(report_dir, "task15_session_info.txt")
writeLines(capture.output(sessionInfo()), session_info_path)
message("Wrote: ", session_info_path)

created_rows <- manifest |>
  dplyr::filter(.data$status %in% c("created", "updated"))
skipped_rows <- manifest |>
  dplyr::filter(!.data$status %in% c("created", "updated"))
diff_rows <- deck_metrics |>
  dplyr::filter(.data$status == "differs")
fallback_rows <- resolved$checks |>
  dplyr::filter(.data$status == "found_fallback")

replacement_lines <- c(
  "- Plot dataset and interpretation set: `Output/figures/review_refresh/context/P0_4_plot_context_vegetation_interpretation.png` and `Output/figures/review_refresh/context/P0_5_plot_context_grazing_counts.png`.",
  "- Flow data alongside mapped inundation: `Output/figures/review_refresh/hydrology/P0_7_RS_gauge_flow_overlap_timeseries.png`.",
  "- Whole-farm pre/post annual occurrence: `Output/figures/review_refresh/inundation/P0_1_annual_occurrence_pre_post_maps.png`.",
  "- Post-minus-pre annual occurrence change: `Output/figures/review_refresh/inundation/P0_2_annual_occurrence_change_map.png`.",
  "- MER annual maximum observed wet frequency: `Output/figures/review_refresh/inundation/P0_3a_MER_pre_post_annual_max_maps.png`.",
  "- MER post-minus-pre annual maximum observed wet change: `Output/figures/review_refresh/inundation/P0_3b_MER_annual_max_change_map.png`.",
  "- Ground-cover by vegetation group: `Output/figures/review_refresh/ground_cover/P0_8_ground_cover_change_by_vegetation_group.png`.",
  "- Ground-cover by grazing / no grazing: `Output/figures/review_refresh/ground_cover/P0_9_ground_cover_change_by_grazing.png`.",
  "- Dashboard slides: refreshed `P0_10_dashboard_*.png` files in `Output/figures/review_refresh/dashboards/`.",
  "- Candidate dashboard review set: `Output/figures/review_refresh/dashboards/P1_2_selected_dashboard_site_map.png`."
)

handoff_lines <- c(
  "# Task 15 Figure Refresh Handoff",
  "",
  paste0("Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
  "",
  "## Summary",
  "",
  "Refreshed the P0 figure, map and dashboard layer for Adrian review. Outputs are review-refresh assets only and do not replace the scientific narrative or create client-facing causal claims.",
  "",
  "## Files Generated",
  "",
  paste0("- `", created_rows$output_path, "`: ", created_rows$figure_title),
  "",
  "## Inputs Used",
  "",
  paste0("- `", resolved$checks$selected_path[!is.na(resolved$checks$selected_path)], "`"),
  "",
  "## Path Mismatches Fixed",
  "",
  if (nrow(fallback_rows) == 0L) {
    "- No fallback paths were required; preferred grouped outputs were found."
  } else {
    paste0("- `", fallback_rows$logical_input_name, "` used fallback `", fallback_rows$selected_path, "`.")
  },
  "",
  "## Deck Metric Recheck",
  "",
  paste0(
    "- ",
    deck_metrics$metric,
    ": refreshed=",
    round(deck_metrics$refreshed_value, 2),
    "; current deck=",
    deck_metrics$current_deck_value,
    "; status=",
    deck_metrics$status
  ),
  "",
  "## Figures Skipped Or Needing Review",
  "",
  if (nrow(skipped_rows) == 0L) {
    "- No requested P0 figures were skipped."
  } else {
    paste0("- `", skipped_rows$figure_id, "` ", skipped_rows$figure_title, ": ", skipped_rows$reason_if_skipped)
  },
  "",
  "## Recommended Deck Replacements",
  "",
  replacement_lines,
  "",
  "## Open Questions For Adrian",
  "",
  "- Confirm whether Maude should remain the local upstream dashboard gauge anchor or whether another gauge should be shown in dashboard exemplars.",
  "- Confirm how prominently MER should appear in the main review deck versus appendix material.",
  "- Confirm whether dashboard examples should remain the current review set or be trimmed before client-facing use.",
  "",
  "## Risks Before Client-Facing Use",
  "",
  "- These figures remain descriptive review assets, not treatment-effect evidence.",
  "- Annual occurrence maps show spatial exposure / occurrence only; they do not show depth, duration, hydroperiod, dry intervals, water quality or ecological outcome.",
  "- MER maps show annual maximum observed wet footprint context only; they are not hydroperiod, duration or depth.",
  "- Grazing categories are descriptive and may be confounded with vegetation group, hydrology, paddock context and site placement.",
  "",
  "## Reproducibility",
  "",
  paste0("- Top-level runner: `scripts/07_figures_dashboards/00_run_task15_figure_refresh.R`."),
  paste0("- Manifest: `", gayini_relative_path(root_dir, manifest_path), "`."),
  paste0("- Contact sheet: `", gayini_relative_path(root_dir, contact_sheet_path), "`."),
  paste0("- Path checks: `", gayini_relative_path(root_dir, path_check_path), "`."),
  paste0("- Session info: `", gayini_relative_path(root_dir, session_info_path), "`.")
)

handoff_path <- file.path(report_dir, "task15_figure_refresh_handoff.md")
writeLines(handoff_lines, handoff_path)
message("Wrote: ", handoff_path)

if (nrow(diff_rows) > 0L) {
  warning(
    "Some recomputed deck metrics differ from current deck values. See: ",
    metrics_path,
    call. = FALSE
  )
}

message("Task 15 figure refresh complete.")
message("Manifest: ", manifest_path)
message("Contact sheet: ", contact_sheet_path)
message("Handoff: ", handoff_path)
