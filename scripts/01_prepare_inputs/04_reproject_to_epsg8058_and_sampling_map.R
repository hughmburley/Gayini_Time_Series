# ------------------------------------------------------------------------------
# Script: scripts/01_prepare_inputs/04_reproject_to_epsg8058_and_sampling_map.R
# Purpose: Tier 1 · Task A. Reproject all vector layers (and reproject-on-read
#          the annual raster stack) to EPSG:8058 (GDA2020 / NSW Lambert),
#          run plot/community spatial QA, and build the F1 sampling-design map
#          together with its concept explainer.
# Workflow stage: 01_prepare_inputs
# Run mode: lightweight_review
# Heavy processing: no (vector reprojection + figures only)
# Key inputs:
#   - Input/shapefiles/{gayini_boundary, Gayini_Vegetation-classes-use,
#     gayini_hectare_plots, CA0561_ManagementZones}.shp
#   - Output/database/Gayini_Results.sqlite  (dim_plot)
#   - Output/rasters/inundation_annual_stack/annual_{wet,valid}_any_1988_2023.tif
# Key outputs:
#   - Output/spatial_8058/*_epsg8058.gpkg            (reprojected vector copies)
#   - Output/figures/F1_sampling_design_map_data.{png,pdf}
#   - Output/figures/F1_sampling_design_concept.{svg,pdf}
#   - Output/figures/figures_manifest.csv
#   - Output/diagnostics/plot_community_mismatch_report.csv
# Notes:
#   - Source files are opened read-only and NEVER mutated.
#   - Stops at the acceptance gate; commit is a separate, human-reviewed step.
# ------------------------------------------------------------------------------

####################################################################################################


## GAYINI REMOTE SENSING PROJECT — Tier 1 Task A


####################################################################################################


## 0. User settings ----


INSTALL_MISSING <- FALSE
TARGET_CRS      <- 8058L

root_dir <- getwd()


## 1. Source helpers and Tier 1 spatial functions ----


source(file.path(root_dir, "R", "gayini_helpers.R"))
source(file.path(root_dir, "R", "vector_prep_functions.R"))
source(file.path(root_dir, "R", "gayini_output_helpers.R"))
source(file.path(root_dir, "R", "gayini_spatial_8058_functions.R"))
source(file.path(root_dir, "R", "gayini_sampling_design_map.R"))

suppressPackageStartupMessages({
  library(sf)
  library(terra)
  library(dplyr)
  library(ggplot2)
})

sf::sf_use_s2(FALSE)


## 2. Snapshot source-file checksums (proof the originals are untouched) ----


source_shapefile_files <- list.files(
  file.path(root_dir, "Input", "shapefiles"),
  full.names = TRUE
)

checksum_before <- tools::md5sum(source_shapefile_files)


## 3. Reproject all vector layers to EPSG:8058 -> Output/spatial_8058/ ----


reproj <- gayini_reproject_vectors_8058(root = root_dir, target = TARGET_CRS)


## 4. Raster strategy: REPROJECT-ON-READ (documented decision) ----
##
## The 35-band wet/valid stack is NOT written to a reprojected copy. Instead it
## is projected on demand by to_analysis_crs(<SpatRaster>, method = "near").
## Rationale:
##   - The annual occurrence / wet-cell numbers are LOCKED in EPSG:28355 (Tier 0,
##     verified against the manifest). Reprojecting a categorical stack resamples
##     cells and would move those counts, breaking the spine view.
##   - Nothing in Task A (the sampling-design map) consumes the raster.
##   - Keeping the authoritative stack pristine and projecting on read preserves
##     both the numbers and the single source of truth. Extraction helpers in
##     later rungs call to_analysis_crs() at the point of use.
##   - Categorical layers MUST use nearest-neighbour (method = "near"), never
##     bilinear, so no fractional classes are invented.
## A one-band smoke test confirms the helper works and tags 8058:

wet_stack_path <- file.path(root_dir, "Output", "rasters",
                            "inundation_annual_stack", "annual_wet_any_1988_2023.tif")

raster_smoke_ok <- FALSE
if (file.exists(wet_stack_path)) {
  wet_band1     <- terra::rast(wet_stack_path)[[1]]
  wet_band1_8058 <- to_analysis_crs(wet_band1, target = TARGET_CRS, method = "near")
  raster_smoke_ok <- isTRUE(gayini_crs_epsg(wet_band1_8058) == TARGET_CRS)
  message("Raster reproject-on-read smoke test (band 1 -> 8058, nearest): ",
          if (raster_smoke_ok) "PASS" else "FAIL")
} else {
  warning("Annual wet stack not found; raster smoke test skipped.", call. = FALSE)
}


## 5. Spatial QA — centroids-in-boundary + plot/community intersection ----


dim_plot <- gayini_load_dim_plot(
  file.path(root_dir, "Output", "database", "Gayini_Results.sqlite")
)

qa <- gayini_plot_community_qa(
  plots_8058       = reproj$plots,
  communities_8058 = reproj$communities,
  boundary_8058    = reproj$boundary,
  dim_plot         = dim_plot
)

## LOG the mismatch report (never silently dropped).
plot_community_mismatch_report <- qa$mismatch_report

mismatch_path <- file.path(root_dir, "Output", "diagnostics",
                           "plot_community_mismatch_report.csv")
gayini_write_csv(plot_community_mismatch_report, mismatch_path)

message("Plot centroids inside boundary: ", qa$n_centroids_in_boundary, " / 66")
message("Plot footprints in assigned community: ", qa$n_footprint_in_assigned, " / 66")
message("Logged ", nrow(plot_community_mismatch_report),
        " plot/community QA flags to ", mismatch_path)


## 6. Community counts (must stay 22 / 19 / 16 / 9) ----


community_levels <- gayini_community_levels()

plot_counts_by_group <- qa$plots_qa |>
  sf::st_drop_geometry() |>
  dplyr::count(simplified_vegetation_group) |>
  { \(df) stats::setNames(df$n[match(community_levels, df$simplified_vegetation_group)],
                          community_levels) }()

print(plot_counts_by_group)


## 7. F1 figure pair — data map + concept explainer ----


f1_data    <- gayini_build_sampling_design_map(reproj, qa$plots_qa, root = root_dir)
f1_concept <- gayini_build_concept_figure(root = root_dir)


## 8. Figures manifest ({step}_{concept|data} convention) ----


veg_input   <- "Input/shapefiles/Gayini_Vegetation-classes-use.shp"
plots_input <- "Input/shapefiles/gayini_hectare_plots.shp"

figures_manifest <- dplyr::bind_rows(
  gayini_figure_manifest_row(
    step = "F1", kind = "concept", path = f1_concept$svg,
    inputs = "schematic (no data)", crs = "n/a", root = root_dir),
  gayini_figure_manifest_row(
    step = "F1", kind = "concept", path = f1_concept$pdf,
    inputs = "schematic (no data)", crs = "n/a", root = root_dir),
  gayini_figure_manifest_row(
    step = "F1", kind = "data", path = f1_data$png,
    inputs = paste(c("gayini_boundary", "Gayini_Vegetation-classes-use",
                     "gayini_hectare_plots", "CA0561_ManagementZones", "dim_plot"),
                   collapse = "; "),
    crs = "EPSG:8058", root = root_dir),
  gayini_figure_manifest_row(
    step = "F1", kind = "data", path = f1_data$pdf,
    inputs = paste(c("gayini_boundary", "Gayini_Vegetation-classes-use",
                     "gayini_hectare_plots", "CA0561_ManagementZones", "dim_plot"),
                   collapse = "; "),
    crs = "EPSG:8058", root = root_dir)
)

manifest_path <- file.path(root_dir, "Output", "figures", "figures_manifest.csv")
gayini_write_csv(figures_manifest, manifest_path)


## 9. Acceptance gate (must pass before commit) ----


## everything on NSW Lambert
reprojected_epsg <- vapply(reproj$paths, function(p) gayini_crs_epsg(p), integer(1))

## originals untouched
checksum_after <- tools::md5sum(source_shapefile_files)

## Riverine Chenopod restored -> four communities present in the legend
n_veg_classes_in_legend <- length(intersect(
  community_levels,
  as.character(unique(reproj$communities$simplified_vegetation_group))
))

stopifnot(
  all(reprojected_epsg == 8058L),
  identical(checksum_before, checksum_after),
  qa$n_centroids_in_boundary == 66L,
  n_veg_classes_in_legend == 4L,
  all(plot_counts_by_group == c(22, 19, 16, 9)),
  isTRUE(raster_smoke_ok) || !file.exists(wet_stack_path)
)

stopifnot(
  file.exists(file.path(root_dir, "Output", "figures", "F1_sampling_design_map_data.pdf")),
  file.exists(file.path(root_dir, "Output", "figures", "F1_sampling_design_concept.svg")),
  file.exists(file.path(root_dir, "Output", "figures", "figures_manifest.csv"))
)

## community/plot intersection mismatches are LOGGED, not silently dropped
stopifnot(exists("plot_community_mismatch_report"))


## 10. Final summary ----


message("\n==================== ACCEPTANCE GATE PASSED ====================")
message("Reprojected layers (EPSG): ",
        paste(names(reprojected_epsg), reprojected_epsg, sep = "=", collapse = ", "))
message("Source shapefiles unchanged: ", identical(checksum_before, checksum_after))
message("Plot centroids in boundary: ", qa$n_centroids_in_boundary, "/66")
message("Legend communities: ", n_veg_classes_in_legend, " (Riverine Chenopod restored)")
message("Community counts: ", paste(plot_counts_by_group, collapse = " / "), " (expected 22/19/16/9)")
message("F1 data map:    ", f1_data$png)
message("F1 concept:     ", f1_concept$svg)
message("Manifest:       ", manifest_path)
message("Mismatch report:", mismatch_path)
message("\nSTOP: review Output/figures/F1_sampling_design_map_data.pdf before committing.")


####################################################################################################
############################################ TBC ###################################################
####################################################################################################
