# ------------------------------------------------------------------------------
# Script: scripts/07_figures_dashboards/11_build_f5_legibility_views.R
# Purpose: Tier 1 · Tasks C2+C3. Presentation-only F5 figures for Adrian / Nari
#          Nari, under the standing rule ONE FIGURE = ONE FILE = ONE SLIDE:
#            F5_fullfarm_map      — the whole-farm surface + band-coloured points (map only);
#            F5_band_reference    — points-per-community x band matrix + tercile-break table;
#            F5b_community_facets  — one self-contained panel per focus community;
#            F5c_paddock_*         — 3-4 paddock zooms (chosen by density x spread, logged),
#                                    locator inset reserved clear of title/subtitle/caption.
#          Relative-band labelling throughout (within-community terciles overlap).
# Workflow stage: 07_figures_dashboards
# Run mode: lightweight_review (no sampling / no analysis)
# Heavy processing: no
# Key inputs (all existing F5 products / 8058 vectors):
#   - Output/spatial_8058/stratified_sample_points.gpkg
#   - Output/rasters/background_flood_frequency_8058.tif
#   - Output/diagnostics/regime_band_breaks.csv
#   - Output/spatial_8058/{gayini_boundary, vegetation_communities,
#     management_zones, gayini_hectare_plots}_epsg8058.gpkg
#   - Output/database/Gayini_Results.sqlite (dim_plot -> plot communities)
# Key outputs:
#   - Output/figures/F5_fullfarm_map_data.{png,pdf}
#   - Output/figures/F5_band_reference_data.{png,pdf}
#   - Output/figures/F5b_community_facets_data.{png,pdf}
#   - Output/figures/F5c_paddock_*_data.{png,pdf}
#   - Output/diagnostics/{f5c_paddock_choice_log, f5c_inset_overlap_check}.csv
#   - Output/review_bundles/tier1c3_f5_figures.zip
# Notes:
#   - Presentation only: does NOT re-sample, re-band, or alter the F5 data products.
#   - One figure = one file = one slide; insets never overlap title/caption.
#   - Bands are within-community relative BY DESIGN (Q1 to Adrian may switch to
#     absolute; if so it is a one-line change in F5 and these views inherit it).
#   - Stops at the acceptance gate; commit is a separate, human-reviewed step.
# ------------------------------------------------------------------------------

####################################################################################################


## GAYINI REMOTE SENSING PROJECT — Tier 1 Tasks C2+C3 (F5 presentation figures)


####################################################################################################


## 0. Settings ----


N_PADDOCK_ZOOMS <- 4L   # choose 3-4 paddocks; logged with rationale

root_dir <- getwd()


## 1. Sources ----


source(file.path(root_dir, "R", "gayini_helpers.R"))
source(file.path(root_dir, "R", "vector_prep_functions.R"))
source(file.path(root_dir, "R", "gayini_output_helpers.R"))
source(file.path(root_dir, "R", "gayini_gradient_helpers.R"))
source(file.path(root_dir, "R", "gayini_spatial_8058_functions.R"))
source(file.path(root_dir, "R", "gayini_sampling_design_map.R"))
source(file.path(root_dir, "R", "gayini_descriptive_figures.R"))
source(file.path(root_dir, "R", "gayini_stratified_sampling_functions.R"))
source(file.path(root_dir, "R", "gayini_stratified_sampling_figures.R"))
source(file.path(root_dir, "R", "gayini_f5_legibility_figures.R"))

suppressPackageStartupMessages({
  library(sf)
  library(terra)
  library(dplyr)
  library(ggplot2)
})

sf::sf_use_s2(FALSE)

figures_dir     <- file.path(root_dir, "Output", "figures")
diagnostics_dir <- file.path(root_dir, "Output", "diagnostics")


## 2. Load the finished F5 products ----


products <- gayini_load_f5_products(root_dir)
pts       <- products$pts
breaks_df <- products$breaks_df
focus     <- products$focus
band_levels <- gayini_regime_band_levels()

message("Loaded ", nrow(pts), " F5 sample points across ",
        dplyr::n_distinct(pts$community), " communities.")


## 3. F5 map -> TWO single-slide files (one figure = one file = one slide) ----
##
## Presentation only — reads the existing points/surface, reconstructs the
## per-stratum counts for the band-reference matrix (no re-sampling).
##   F5_fullfarm_map_data  — the whole-farm map only (no tables).
##   F5_band_reference_data — the points matrix + the tercile-break table.


plots_raw <- gayini_read_vector(
  file.path(root_dir, "Output", "spatial_8058", "gayini_hectare_plots_epsg8058.gpkg"),
  label = "hectare plots (8058)")
dim_plot  <- gayini_load_dim_plot(file.path(root_dir, "Output", "database", "Gayini_Results.sqlite"))
plots <- plots_raw |>
  dplyr::left_join(dim_plot[, c("plot_id", "simplified_vegetation_group")], by = "plot_id")

## Reconstruct the community x band draw counts for the band-reference matrix.
grid <- expand.grid(community = focus, regime_band = band_levels, stringsAsFactors = FALSE)
cnt  <- pts |> sf::st_drop_geometry() |>
  dplyr::count(community, regime_band, name = "n_drawn")
sample_summary <- dplyr::left_join(grid, cnt, by = c("community", "regime_band"))
sample_summary$n_drawn[is.na(sample_summary$n_drawn)] <- 0L
sample_summary$community   <- factor(sample_summary$community, levels = focus)
sample_summary$regime_band <- factor(sample_summary$regime_band, levels = band_levels)

## Retire the old composite file (superseded by the two single-slide files).
for (ext in c("png", "pdf", "svg")) {
  stale <- file.path(figures_dir, paste0("F5_stratified_sampling_map_data.", ext))
  if (file.exists(stale)) unlink(stale, force = TRUE)
}

f5_fullfarm <- gayini_build_f5_fullfarm_map(
  freq_8058         = products$freq,
  sample            = list(points = pts, summary = sample_summary),
  boundary          = products$boundary,
  communities       = products$communities,
  plots             = plots,
  focus_communities = focus,
  out_dir           = figures_dir
)
fullfarm_has_tables <- f5_fullfarm$has_tables   # FALSE by construction (map only)

f5_bandref <- gayini_build_f5_band_reference(
  sample_summary    = sample_summary,
  breaks_df         = breaks_df,
  focus_communities = focus,
  out_dir           = figures_dir
)


## 4. F5b — community-facet panels ----


f5b <- gayini_build_f5b_community_facets(products, out_dir = figures_dir)
n_facet_panels <- f5b$n_facet_panels


## 5. F5c — paddock zooms (chosen by density x spread, logged) ----


choice <- gayini_choose_paddocks(products, n_choose = N_PADDOCK_ZOOMS)

paddock_choice_log <- choice$chosen
choice_log_path <- file.path(diagnostics_dir, "f5c_paddock_choice_log.csv")
gayini_write_csv(choice$ranking, choice_log_path)   # full ranking (chosen flagged)

message("Paddock zooms chosen (score = n_points x n_comm x n_band):")
print(choice$chosen |> dplyr::select(rank, paddock, n_points, n_comm, n_band, score))

f5c <- gayini_build_f5c_paddock_zooms(products, choice, out_dir = figures_dir)
f5c_paths          <- f5c$paths
inset_overlap_check <- f5c$overlap_check

message("Inset-overlap check (all must clear title & caption):")
print(inset_overlap_check |> dplyr::select(paddock, clears_title, clears_caption, clear))


## 6. Register the new figures in the manifest ----


pts_input <- "stratified_sample_points.gpkg; background_flood_frequency_8058.tif; regime_band_breaks.csv"

f5_rows <- dplyr::bind_rows(
  gayini_manifest_row("F5",    "data", f5_fullfarm$png, paste0(pts_input, " [full-farm map]"), "EPSG:8058", root_dir),
  gayini_manifest_row("F5",    "data", f5_fullfarm$pdf, paste0(pts_input, " [full-farm map]"), "EPSG:8058", root_dir),
  gayini_manifest_row("F5ref", "data", f5_bandref$png,  paste0(pts_input, " [band reference]"), "n/a", root_dir),
  gayini_manifest_row("F5ref", "data", f5_bandref$pdf,  paste0(pts_input, " [band reference]"), "n/a", root_dir)
)

f5b_rows <- dplyr::bind_rows(
  gayini_manifest_row("F5b", "data", f5b$paths$png, pts_input, "EPSG:8058", root_dir),
  gayini_manifest_row("F5b", "data", f5b$paths$pdf, pts_input, "EPSG:8058", root_dir)
)

f5c_rows <- dplyr::bind_rows(lapply(names(f5c_paths), function(nm) {
  p <- f5c_paths[[nm]]
  dplyr::bind_rows(
    gayini_manifest_row("F5c", "data", p$png, paste0(pts_input, " [paddock: ", nm, "]"),
                        "EPSG:8058", root_dir),
    gayini_manifest_row("F5c", "data", p$pdf, paste0(pts_input, " [paddock: ", nm, "]"),
                        "EPSG:8058", root_dir)
  )
}))

new_rows <- dplyr::bind_rows(f5_rows, f5b_rows, f5c_rows)
manifest <- gayini_update_figures_manifest(new_rows, root = root_dir)


## 7. Acceptance gate (must pass before commit) ----


legend_label <- gayini_regime_band_legend_title()

stopifnot(
  # relative-band labelling present on band figures
  grepl("within-community|relative", legend_label, ignore.case = TRUE),
  # the farm map file is map-only (no tables composited in)
  fullfarm_has_tables == FALSE,
  # band reference is its own file
  file.exists(file.path(figures_dir, "F5_band_reference_data.pdf")),
  # community facets: 3 panels, each with its own tercile breaks annotated
  n_facet_panels == 3L,
  # paddock zooms: chosen paddocks logged with rationale
  nrow(paddock_choice_log) >= 3L,
  # no inset overlaps title/caption on any inset figure (checked + logged)
  all(inset_overlap_check$clear == TRUE),
  # the old composite file was retired (split into two single-slide files)
  !file.exists(file.path(figures_dir, "F5_stratified_sampling_map_data.pdf"))
)

## The single-slide files all exist.
stopifnot(
  file.exists(file.path(figures_dir, "F5_fullfarm_map_data.pdf")),
  file.exists(file.path(figures_dir, "F5_band_reference_data.pdf")),
  file.exists(file.path(figures_dir, "F5b_community_facets_data.pdf")),
  all(vapply(f5c_paths, function(p) file.exists(p$pdf), logical(1)))
)


## 8. Package for review (standing convention) ----


bundle_dir      <- file.path(root_dir, "Output", "review_bundles", "tier1c3_f5_figures")
bundle_fig_dir  <- file.path(bundle_dir, "figures")
bundle_diag_dir <- file.path(bundle_dir, "diagnostics")
unlink(bundle_dir, recursive = TRUE, force = TRUE)
dir.create(bundle_fig_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(bundle_diag_dir, recursive = TRUE, showWarnings = FALSE)

figure_files <- list.files(
  figures_dir,
  pattern = "^(F5_fullfarm_map_data|F5_band_reference_data|F5b_community_facets_data|F5c_paddock_.*)\\.(png|pdf)$",
  full.names = TRUE)
file.copy(figure_files, bundle_fig_dir, overwrite = TRUE)
file.copy(file.path(figures_dir, "figures_manifest.csv"), bundle_dir, overwrite = TRUE)
readr::write_csv(new_rows, file.path(bundle_dir, "manifest_rows_tier1c3.csv"))

## Log the inset-overlap check with the bundle.
overlap_log_path <- file.path(diagnostics_dir, "f5c_inset_overlap_check.csv")
gayini_write_csv(inset_overlap_check, overlap_log_path)

file.copy(c(choice_log_path, overlap_log_path,
            file.path(diagnostics_dir, "regime_band_breaks.csv")),
          bundle_diag_dir, overwrite = TRUE)

change_report_path <- file.path(root_dir, "docs", "change_reports", "tier1c3_f5_figures.md")
if (file.exists(change_report_path)) file.copy(change_report_path, bundle_dir, overwrite = TRUE)

bundle_zip <- file.path(root_dir, "Output", "review_bundles", "tier1c3_f5_figures.zip")
if (file.exists(bundle_zip)) unlink(bundle_zip, force = TRUE)
zip::zip(
  zipfile = bundle_zip,
  files   = list.files(bundle_dir, recursive = TRUE, full.names = FALSE),
  root    = bundle_dir
)
message("Wrote review bundle: ", bundle_zip)

stopifnot(file.exists(bundle_zip))


## 9. Summary ----


message("\n==================== ACCEPTANCE GATE PASSED ====================")
message("One figure = one file = one slide:")
message("  F5 full-farm map (map only):   ", f5_fullfarm$png)
message("  F5 band reference (matrix+table): ", f5_bandref$png)
message("  F5b community facets (", n_facet_panels, " panels): ", f5b$paths$png)
message("  F5c paddock zooms (", length(f5c_paths), "): ",
        paste(names(f5c_paths), collapse = ", "))
message("Old composite retired: F5_stratified_sampling_map_data.* removed")
message("Inset-overlap check: ", sum(inset_overlap_check$clear), "/",
        nrow(inset_overlap_check), " paddock insets clear of title & caption")
message("Review bundle: ", bundle_zip)
message("\nSTOP: review Output/review_bundles/tier1c3_f5_figures.zip before committing.")


####################################################################################################
############################################ TBC ###################################################
####################################################################################################
