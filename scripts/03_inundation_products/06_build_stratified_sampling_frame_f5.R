# ------------------------------------------------------------------------------
# Script: scripts/03_inundation_products/06_build_stratified_sampling_frame_f5.R
# Purpose: Tier 1 · Task C (F5). Build the stratified sampling FRAME:
#          (1) a static background flood-frequency surface (the headline
#              between-year metric, spatially) computed in EPSG:28355 and
#              reprojected (continuous -> bilinear) to EPSG:8058;
#          (2) within-community regime bands (terciles) for the 3 focus
#              communities;
#          (3) a plot-neighbourhood sampling frame (footprints excluded);
#          (4) a stratified random sample of points per community x regime band;
#          plus the F5 concept + data figure pair and the review bundle.
# Workflow stage: 03_inundation_products
# Run mode: analysis (real raster work) · lightweight_review outputs
# Heavy processing: moderate (35-band stack -> one summed surface)
# Key inputs:
#   - Output/rasters/inundation_annual_stack/annual_{wet,valid}_any_1988_2023.tif  (EPSG:28355)
#   - Output/spatial_8058/{gayini_boundary, vegetation_communities,
#     gayini_hectare_plots}_epsg8058.gpkg                                          (EPSG:8058, Task A)
#   - Output/database/Gayini_Results.sqlite  (dim_plot -> authoritative community)
# Key outputs:
#   - Output/rasters/background_flood_frequency_8058.tif
#   - Output/spatial_8058/stratified_sample_points.gpkg
#   - Output/diagnostics/{sample_summary, regime_band_breaks}.csv
#   - Output/figures/F5_stratified_sampling_{concept.svg/pdf, map_data.png/pdf}
#   - Output/review_bundles/tier1c_stratified_sampling.zip
# Notes:
#   - This is a STRATIFICATION SUBSTRATE + descriptive map, NOT the F6 trend or
#     F8/F9 probability surface. No trend is run here.
#   - Categorical wet/valid bands are NEVER resampled; only the derived
#     continuous surface is reprojected (bilinear). Source rasters are read-only.
#   - Stops at the acceptance gate; commit is a separate, human-reviewed step.
# ------------------------------------------------------------------------------

####################################################################################################


## GAYINI REMOTE SENSING PROJECT — Tier 1 Task C (F5)


####################################################################################################


## 0. Tunable defaults — OUR decisions, FLAGGED for Adrian Q1 ----
##
## These are the design defaults. Adrian's Q1 answer changes these VALUES; the
## logic downstream is unchanged either way.

NEIGHBOURHOOD_RADIUS <- 2000    # m   · sample within 2 km of a monitoring plot
EXCLUSION_BUFFER     <- 100     # m   · drop the plot footprint + 100 m around it
N_PER_STRATUM        <- 40      # pts · per community x regime band (where present)
MIN_VALID_YEARS      <- 25      # yrs · sample only pixels with >= 25 / 35 valid years
SEED                 <- 20260709
TARGET_CRS           <- 8058L

## Focus = the 3 non-treed communities only (Woodland / Forest excluded).
## Regime bands = within-community TERCILES of background flood frequency.


## 1. Sources ----


root_dir <- getwd()

source(file.path(root_dir, "R", "gayini_helpers.R"))
source(file.path(root_dir, "R", "vector_prep_functions.R"))       # gayini_read_vector
source(file.path(root_dir, "R", "gayini_output_helpers.R"))
source(file.path(root_dir, "R", "gayini_gradient_helpers.R"))
source(file.path(root_dir, "R", "gayini_spatial_8058_functions.R"))
source(file.path(root_dir, "R", "gayini_sampling_design_map.R"))   # scalebar / north arrow
source(file.path(root_dir, "R", "gayini_descriptive_figures.R"))   # gayini_save_figure
source(file.path(root_dir, "R", "gayini_stratified_sampling_functions.R"))
source(file.path(root_dir, "R", "gayini_stratified_sampling_figures.R"))

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

focus_communities <- gayini_focus_levels()   # 3 non-treed, gradient order
band_levels       <- gayini_regime_band_levels()


## 2. Load reprojected vectors (Task A) + authoritative plot communities ----


boundary    <- gayini_read_vector(file.path(spatial_dir, "gayini_boundary_epsg8058.gpkg"),
                                  label = "boundary (8058)")
communities <- gayini_read_vector(file.path(spatial_dir, "vegetation_communities_epsg8058.gpkg"),
                                  label = "communities (8058)")
plots_raw   <- gayini_read_vector(file.path(spatial_dir, "gayini_hectare_plots_epsg8058.gpkg"),
                                  label = "hectare plots (8058)")

dim_plot <- gayini_load_dim_plot(
  file.path(root_dir, "Output", "database", "Gayini_Results.sqlite")
)

## Authoritative community assignment comes from dim_plot (not the shapefile).
plots <- plots_raw |>
  dplyr::left_join(dim_plot[, c("plot_id", "simplified_vegetation_group")], by = "plot_id")

stopifnot(all(!is.na(plots$simplified_vegetation_group)))


## 3. Background flood-frequency surface (28355 -> 8058) ----


wet_path   <- file.path(root_dir, "Output", "rasters", "inundation_annual_stack",
                        "annual_wet_any_1988_2023.tif")
valid_path <- file.path(root_dir, "Output", "rasters", "inundation_annual_stack",
                        "annual_valid_any_1988_2023.tif")

freq_out <- file.path(root_dir, "Output", "rasters", "background_flood_frequency_8058.tif")

surface <- gayini_background_flood_frequency(
  wet_path        = wet_path,
  valid_path      = valid_path,
  min_valid_years = MIN_VALID_YEARS,
  target          = TARGET_CRS,
  out_tif         = freq_out
)

freq_8058  <- surface$freq_8058
valid_8058 <- surface$valid_8058

message(sprintf("Background surface: %d/%d years · support >= %d valid years retained %.1f%% of observed pixels (%d of %d).",
                surface$n_years, surface$n_years, MIN_VALID_YEARS,
                surface$pct_retained, surface$n_supported, surface$n_observed))


## 4. Within-community regime bands (terciles) — LOG the breakpoints ----


breaks <- gayini_community_regime_bands(freq_8058, communities, focus_communities)

regime_band_breaks <- dplyr::bind_rows(lapply(focus_communities, function(g) {
  b <- breaks[[g]]
  tibble::tibble(
    community      = g,
    freq_min_pct   = round(b[1], 2),
    tercile_1_pct  = round(b[2], 2),   # low | mid boundary
    tercile_2_pct  = round(b[3], 2),   # mid | high boundary
    freq_max_pct   = round(b[4], 2)
  )
}))

regime_breaks_path <- file.path(diagnostics_dir, "regime_band_breaks.csv")
gayini_write_csv(regime_band_breaks, regime_breaks_path)

message("Within-community tercile breakpoints (flood frequency %):")
print(regime_band_breaks)


## 5. Draw the stratified sample ----


sample <- gayini_draw_stratified_sample(
  freq_8058            = freq_8058,
  valid_8058           = valid_8058,
  plots                = plots,
  communities          = communities,
  breaks               = breaks,
  focus_communities    = focus_communities,
  neighbourhood_radius = NEIGHBOURHOOD_RADIUS,
  exclusion_buffer     = EXCLUSION_BUFFER,
  n_per_stratum        = N_PER_STRATUM,
  min_valid_years      = MIN_VALID_YEARS,
  seed                 = SEED
)

pts            <- sample$points
sample_summary <- sample$summary

n_strata_present <- length(focus_communities) * length(band_levels)

message("\nSample summary (points per community x regime band):")
print(sample_summary, n = nrow(sample_summary))
if (any(sample_summary$empty_stratum))
  message("  NB ", sum(sample_summary$empty_stratum), " empty stratum/strata logged (0 candidate pixels).")
if (any(sample_summary$fallback_triggered))
  message("  NB community-wide fallback triggered for: ",
          paste(unique(sample_summary$community[sample_summary$fallback_triggered]), collapse = ", "))


## 6. Write the sampling-frame outputs ----


points_path <- file.path(spatial_dir, "stratified_sample_points.gpkg")
if (file.exists(points_path)) unlink(points_path, force = TRUE)
sf::st_write(pts, points_path, quiet = TRUE)
message("Wrote: ", points_path)

summary_path <- file.path(diagnostics_dir, "sample_summary.csv")
gayini_write_csv(sample_summary, summary_path)


## 7. F5 figure pair ----


f5_concept <- gayini_build_f5_concept(out_dir = figures_dir)
f5_data    <- gayini_build_f5_data(
  freq_8058         = freq_8058,
  sample            = sample,
  boundary          = boundary,
  communities       = communities,
  plots             = plots,
  focus_communities = focus_communities,
  out_dir           = figures_dir
)


## 8. Register in the figures manifest ----


stack_inputs <- "annual_{wet,valid}_any_1988_2023.tif (EPSG:28355 stack)"
frame_inputs <- paste(
  "background_flood_frequency_8058.tif; vegetation_communities_epsg8058;",
  "gayini_hectare_plots_epsg8058; dim_plot"
)

new_rows <- dplyr::bind_rows(
  gayini_manifest_row("F5", "concept", f5_concept$svg, "schematic (no data)", "n/a", root_dir),
  gayini_manifest_row("F5", "concept", f5_concept$pdf, "schematic (no data)", "n/a", root_dir),
  gayini_manifest_row("F5", "data",    f5_data$png, paste0(frame_inputs, " [from ", stack_inputs, "]"),
                      "EPSG:8058", root_dir),
  gayini_manifest_row("F5", "data",    f5_data$pdf, paste0(frame_inputs, " [from ", stack_inputs, "]"),
                      "EPSG:8058", root_dir)
)

manifest <- gayini_update_figures_manifest(new_rows, root = root_dir)


## 9. Acceptance gate (must pass before commit) ----


freq_min <- as.numeric(terra::global(freq_8058, "min", na.rm = TRUE)[[1]])
freq_max <- as.numeric(terra::global(freq_8058, "max", na.rm = TRUE)[[1]])

## Per-point "own community" polygon (for the strict within test).
comm_union <- stats::setNames(
  lapply(focus_communities, function(g)
    sf::st_union(sf::st_geometry(
      communities[as.character(communities$simplified_vegetation_group) == g, ]))),
  focus_communities
)
own_geoms     <- do.call(c, comm_union[as.character(pts$community)])
own_community <- sf::st_sf(community = as.character(pts$community), geometry = own_geoms)

bundle_zip <- file.path(root_dir, "Output", "review_bundles", "tier1c_stratified_sampling.zip")

stopifnot(
  # background frequency surface
  freq_min >= 0,
  freq_max <= 100,
  gayini_crs_epsg(freq_8058) == 8058L,
  # sample points sane
  all(as.character(pts$community) %in% focus_communities),   # 3 non-treed only
  all(pts$valid_years >= MIN_VALID_YEARS),
  all(pts$dist_to_plot_m >= EXCLUSION_BUFFER),                # outside footprint buffer
  all(diag(sf::st_within(pts, own_community, sparse = FALSE))),  # each point in its community
  # every non-empty stratum drawn; empties logged, not silent
  nrow(sample_summary) == n_strata_present
)


## 10. Package for review (standing convention) ----


bundle_dir      <- file.path(root_dir, "Output", "review_bundles", "tier1c_stratified_sampling")
bundle_fig_dir  <- file.path(bundle_dir, "figures")
bundle_diag_dir <- file.path(bundle_dir, "diagnostics")
bundle_spat_dir <- file.path(bundle_dir, "spatial")
unlink(bundle_dir, recursive = TRUE, force = TRUE)
for (d in c(bundle_fig_dir, bundle_diag_dir, bundle_spat_dir))
  dir.create(d, recursive = TRUE, showWarnings = FALSE)

## Figures (both formats) + manifest + this task's manifest rows.
figure_files <- list.files(figures_dir, pattern = "^F5_.*\\.(png|pdf|svg)$", full.names = TRUE)
file.copy(figure_files, bundle_fig_dir, overwrite = TRUE)
file.copy(file.path(figures_dir, "figures_manifest.csv"), bundle_dir, overwrite = TRUE)
readr::write_csv(new_rows, file.path(bundle_dir, "manifest_rows_tier1c.csv"))

## Diagnostics (sample summary + tercile breakpoints) + the frame outputs.
file.copy(c(summary_path, regime_breaks_path), bundle_diag_dir, overwrite = TRUE)
file.copy(points_path, bundle_spat_dir, overwrite = TRUE)
file.copy(freq_out,    bundle_spat_dir, overwrite = TRUE)

## A copy of the change report (report itself stays local / uncommitted).
change_report_path <- file.path(root_dir, "docs", "change_reports", "tier1c_stratified_sampling.md")
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
message("Background flood-frequency surface: ", freq_out)
message(sprintf("  range %.1f–%.1f%% · support >= %d yrs retained %.1f%% of observed pixels",
                freq_min, freq_max, MIN_VALID_YEARS, surface$pct_retained))
message("Regime-band breakpoints (per community): ", regime_breaks_path)
message("Stratified sample points: ", nrow(pts), " -> ", points_path)
message("Sample summary: ", summary_path)
message("Points per community x band:")
print(sample_summary |>
        dplyr::select(community, regime_band, n_candidate_pixels, n_drawn, fallback_triggered),
      n = nrow(sample_summary))
message("F5 concept: ", f5_concept$svg)
message("F5 data:    ", f5_data$png)
message("Review bundle: ", bundle_zip)
message("\nSTOP: review Output/review_bundles/tier1c_stratified_sampling.zip",
        " (esp. F5_stratified_sampling_map_data.pdf) before committing.")


####################################################################################################
############################################ TBC ###################################################
####################################################################################################
