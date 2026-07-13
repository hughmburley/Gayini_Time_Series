# ------------------------------------------------------------------------------
# Script: scripts/03_inundation_products/09_build_pixel_census_view.R
# Purpose: Tier 1 · Task 1 (pixel census). Build the database view
#          v_pixel_census_by_veg_regime: for every vegetation-community x wetness
#          -band stratum, how many valid farm pixels exist, what area / share of
#          the farm that is, how many stratified points currently sample it, and
#          the sampling fraction + density. Makes equal-allocation over-sampling
#          of small strata visible (that is the point of the deck slide).
# Workflow stage: 03_inundation_products
# Run mode: analysis (real raster work) · post-build DB mutation
# Key inputs:
#   - Output/rasters/inundation_annual_stack/annual_{wet,valid}_any_1988_2023.tif (EPSG:28355)
#   - Output/spatial_8058/vegetation_communities_epsg8058.gpkg                     (EPSG:8058)
#   - Output/spatial_8058/gayini_boundary_epsg8058.gpkg                           (EPSG:8058)
#   - Output/spatial_8058/stratified_sample_points.gpkg  (current sample, F5)
#   - Output/diagnostics/regime_band_breaks.csv          (within-community terciles, F5)
#   - Output/database/Gayini_Results.sqlite
# Key outputs:
#   - DB: table census_stratum + view v_pixel_census_by_veg_regime (+ dim_metric rows)
#   - Output/diagnostics/pixel_census.csv
#   - Output/diagnostics/pixel_census_qa.json
#   - Output/figures/F5d_pixel_census_data.{png,pdf}  (registered in the manifest)
#   - Output/review_bundles/tier1_pixel_census.zip
# Notes:
#   - POST-BUILD DB MUTATION (like 03_populate_raster_metadata.R): the Python
#     builder unlinks + rebuilds the DB and has no GDAL, so this must be re-run
#     after any full rebuild. Order: builder -> 03_populate_raster_metadata.R ->
#     05_build_unified_annual_stack.R -> (this).
#   - Descriptive stratification audit, NOT a trend / probability surface. Source
#     rasters are read-only; only the derived continuous surface is reprojected.
#   - Stops at an acceptance gate; commit is a separate, human-reviewed step.
# ------------------------------------------------------------------------------

####################################################################################################


## GAYINI REMOTE SENSING PROJECT — Tier 1 · Pixel census (Task 1)


####################################################################################################


## 0. Tunable defaults ----

MIN_VALID_YEARS <- 25L        # valid-coverage mask: sample only pixels with >= 25/35 valid years
TARGET_CRS      <- 8058L


## 1. Sources ----

root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", getwd()), winslash = "/", mustWork = TRUE)

source(file.path(root_dir, "R", "gayini_helpers.R"))
source(file.path(root_dir, "R", "vector_prep_functions.R"))
source(file.path(root_dir, "R", "gayini_output_helpers.R"))
source(file.path(root_dir, "R", "gayini_gradient_helpers.R"))
source(file.path(root_dir, "R", "gayini_spatial_8058_functions.R"))
source(file.path(root_dir, "R", "gayini_descriptive_figures.R"))
source(file.path(root_dir, "R", "gayini_stratified_sampling_functions.R"))
source(file.path(root_dir, "R", "gayini_pixel_census_functions.R"))
source(file.path(root_dir, "R", "gayini_db_validation.R"))

suppressPackageStartupMessages({
  library(sf)
  library(terra)
  library(dplyr)
  library(ggplot2)
  library(DBI)
  library(RSQLite)
})

sf::sf_use_s2(FALSE)

figures_dir     <- file.path(root_dir, "Output", "figures")
diagnostics_dir <- file.path(root_dir, "Output", "diagnostics")
spatial_dir     <- file.path(root_dir, "Output", "spatial_8058")
db_path         <- file.path(root_dir, "Output", "database", "Gayini_Results.sqlite")

focus_communities <- gayini_focus_levels()


## 2. Load vectors + current sample ----

boundary    <- gayini_read_vector(file.path(spatial_dir, "gayini_boundary_epsg8058.gpkg"),
                                  label = "boundary (8058)")
communities <- gayini_read_vector(file.path(spatial_dir, "vegetation_communities_epsg8058.gpkg"),
                                  label = "communities (8058)")
points      <- gayini_read_vector(file.path(spatial_dir, "stratified_sample_points.gpkg"),
                                  label = "stratified sample points (8058)")


## 3. Background flood-frequency surface + valid-year support (28355 -> 8058) ----
##
## Recomputed here (not read from the saved tif) so the valid-coverage mask is
## PARAMETERISED by MIN_VALID_YEARS: freq is masked at exactly this threshold, so
## a non-NA freq pixel == a valid pixel. Reuses the F5 function verbatim.

wet_path   <- file.path(root_dir, "Output", "rasters", "inundation_annual_stack",
                        "annual_wet_any_1988_2023.tif")
valid_path <- file.path(root_dir, "Output", "rasters", "inundation_annual_stack",
                        "annual_valid_any_1988_2023.tif")

surface <- gayini_background_flood_frequency(
  wet_path        = wet_path,
  valid_path      = valid_path,
  min_valid_years = MIN_VALID_YEARS,
  target          = TARGET_CRS,
  out_tif         = NULL
)
freq_8058  <- surface$freq_8058
valid_8058 <- surface$valid_8058


## 4. Within-community band breaks — source of truth is regime_band_breaks.csv (F5) ----

regime_breaks_path <- file.path(diagnostics_dir, "regime_band_breaks.csv")
gayini_stop_if_missing(regime_breaks_path, label = "regime_band_breaks.csv")
band_breaks_tbl <- readr::read_csv(regime_breaks_path, show_col_types = FALSE)

breaks <- stats::setNames(lapply(focus_communities, function(g) {
  r <- band_breaks_tbl[band_breaks_tbl$community == g, ]
  if (nrow(r) != 1) stop("regime_band_breaks.csv missing a single row for: ", g, call. = FALSE)
  c(r$freq_min_pct, r$tercile_1_pct, r$tercile_2_pct, r$freq_max_pct)
}), focus_communities)


## 4b. Sampling allocation — source of truth for the gate counts (F5) ----
##
## The acceptance gate asserts against the ACTUAL per-stratum allocation the current
## sample targeted (sample_summary.csv `target_n`), NOT hardcoded 360/40/9. So a
## proportional rebalance (per-stratum N) re-runs F5 -> regenerates sample_summary ->
## the gate follows automatically, instead of failing on a stale magic number.

N_CONTEXT_STRATA <- 2L   # structural: Floodplain Woodland/Forest (treed) + Other/minor

sample_summary_path <- file.path(diagnostics_dir, "sample_summary.csv")
gayini_stop_if_missing(sample_summary_path, label = "sample_summary.csv")
allocation_tbl    <- readr::read_csv(sample_summary_path, show_col_types = FALSE)
if (!"target_n" %in% names(allocation_tbl)) {
  stop("sample_summary.csv is missing the `target_n` column (per-stratum allocation).", call. = FALSE)
}
allocation_total  <- sum(allocation_tbl$target_n)
n_focus_expected  <- nrow(allocation_tbl)                       # 9 focus strata (community x band)
n_strata_expected <- n_focus_expected + N_CONTEXT_STRATA        # + context rows -> 11 today


## 5. Classify every farm pixel + tabulate the census ----

res_census <- gayini_pixel_census(
  freq_8058         = freq_8058,
  valid_8058        = valid_8058,
  communities       = communities,
  breaks            = breaks,
  focus_communities = focus_communities,
  points            = points,
  min_valid_years   = MIN_VALID_YEARS
)
census <- res_census$census
recon  <- res_census$recon

message("\nCensus (per stratum):")
print(census[, c("community", "regime_band", "n_pixels", "area_ha", "n_points_sampled")],
      n = nrow(census))


## 6. dim_metric definitions for the census quantities ----
##    Canonical copies also added to the Python builder METRICS list; these are
##    the rebuild-safe safety net (INSERT OR IGNORE inside the writer).

metric_rows <- tibble::tribble(
  ~metric_id, ~metric_name, ~domain, ~units, ~scale, ~numerator, ~denominator, ~method_summary, ~safe_interpretation, ~caveat,
  "census_stratum_pixel_count", "Stratum valid pixel count", "sampling", "count", "count", "valid farm pixels", "stratum",
    "Count of valid (>= valid-year threshold) farm pixels per vegetation-community x wetness-band stratum.",
    "Denominator for the stratum sampling fraction.", "Depends on the parameterised valid-year coverage threshold.",
  "census_stratum_area_ha", "Stratum area", "sampling", "ha", "area", "valid pixel area", "stratum",
    "Area of valid farm pixels per stratum (pixel count x pixel area).",
    "Stratum size for allocation review.", "EPSG:8058 grid; ~0.0624 ha per 25 m pixel.",
  "census_stratum_sampling_fraction", "Stratum sampling fraction", "sampling", "fraction", "0-1", "sample points", "valid pixels",
    "Current stratified sample points divided by valid pixels in the stratum.",
    "Shows equal-allocation over/under-sampling across strata.", "Tiny by design; compare relative, not absolute.",
  "census_stratum_sampling_density_per_1000ha", "Stratum sampling density", "sampling", "points_per_1000ha", "density", "sample points x 1000", "stratum area (ha)",
    "Stratified sample points per 1000 ha within the stratum.",
    "Makes small-stratum oversampling visible (the sampling-density slide).", "Equal allocation inflates density in small strata by design."
)


## 7. Persist base table + build the view ----

census_view <- gayini_write_pixel_census_view(db_path, census, metric_rows = metric_rows)

## 09 is the LAST post-build mutation: assert the whole chain is intact (B4 guard).
local({
  con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
  on.exit(DBI::dbDisconnect(con))
  gayini_assert_post_build_objects(con)
})

census_csv_path <- file.path(diagnostics_dir, "pixel_census.csv")
gayini_write_csv(census_view, census_csv_path)


## 8. Figure — available vs sampled per stratum ----

fig <- gayini_build_pixel_census_figure(census_view, out_dir = figures_dir,
                                        basename = "F5d_pixel_census_data")


## 9. Register in the figures manifest ----

fig_inputs <- paste(
  "v_pixel_census_by_veg_regime (Gayini_Results.sqlite) [from",
  "vegetation_communities_epsg8058 x background flood frequency (annual_{wet,valid}_any_1988_2023.tif)",
  "+ regime_band_breaks.csv + stratified_sample_points.gpkg]"
)
new_rows <- dplyr::bind_rows(
  gayini_manifest_row("F5d", "data", fig$png, fig_inputs, "n/a", root_dir),
  gayini_manifest_row("F5d", "data", fig$pdf, fig_inputs, "n/a", root_dir)
)
manifest <- gayini_update_figures_manifest(new_rows, root = root_dir)


## 10. Reconciliation + QA ----

boundary_area_ha  <- as.numeric(sum(sf::st_area(boundary))) / 1e4
comm_union_area_ha <- as.numeric(sum(sf::st_area(
  sf::st_union(sf::st_geometry(communities))))) / 1e4

sum_stratum_area_ha <- sum(census_view$area_ha)
pct_sum             <- sum(census_view$pct_of_farm)
total_points        <- sum(census_view$n_points_sampled)

## Reconciliation: classified valid + masked-out should equal the mapped farm
## (community union), bar raster-vs-vector edge effects.
recon_diff_comm_ha  <- (recon$classified_valid_area_ha + recon$masked_out_area_ha) - comm_union_area_ha
recon_diff_comm_pct <- 100 * recon_diff_comm_ha / comm_union_area_ha
comm_vs_boundary_pct <- 100 * (comm_union_area_ha - boundary_area_ha) / boundary_area_ha

focus_rows   <- census_view[census_view$regime_band != "context", ]
context_rows <- census_view[census_view$regime_band == "context", ]

qa <- list(
  view_name            = "v_pixel_census_by_veg_regime",
  base_table           = "census_stratum",
  generated_by         = "scripts/03_inundation_products/09_build_pixel_census_view.R",
  crs_epsg             = gayini_crs_epsg(freq_8058),
  valid_year_threshold = MIN_VALID_YEARS,
  pixel_area_ha        = round(recon$pixel_area_ha, 6),
  n_strata_rows        = nrow(census_view),
  n_focus_strata       = nrow(focus_rows),
  n_context_rows       = nrow(census_view) - nrow(focus_rows),
  counts = list(
    n_valid_pixels        = recon$n_valid_pixels,
    n_masked_out_pixels   = recon$n_masked_out_pixels,
    n_in_community_pixels = recon$n_in_community_pixels
  ),
  area_reconciliation = list(
    farm_boundary_area_ha      = round(boundary_area_ha, 2),
    community_union_area_ha    = round(comm_union_area_ha, 2),
    classified_valid_area_ha   = recon$classified_valid_area_ha,
    masked_out_area_ha         = recon$masked_out_area_ha,
    sum_of_stratum_area_ha     = round(sum_stratum_area_ha, 2),
    classified_plus_masked_minus_community_ha  = round(recon_diff_comm_ha, 2),
    classified_plus_masked_minus_community_pct = round(recon_diff_comm_pct, 3),
    community_union_minus_boundary_pct         = round(comm_vs_boundary_pct, 3)
  ),
  null_checks = list(
    n_pixels_any_na          = as.integer(any(is.na(census_view$n_pixels))),
    n_pixels_any_negative    = as.integer(any(census_view$n_pixels < 0)),
    focus_band_breaks_all_present = as.integer(all(!is.na(focus_rows$band_freq_lo_pct) &
                                                    !is.na(focus_rows$band_freq_hi_pct))),
    context_band_breaks_all_null  = as.integer(all(is.na(
      census_view$band_freq_lo_pct[census_view$regime_band == "context"])))
  ),
  sampling = list(
    total_points_sampled       = as.integer(total_points),
    allocation_total           = as.integer(allocation_total),
    n_focus_expected           = as.integer(n_focus_expected),
    points_only_in_focus_strata = as.integer(sum(context_rows$n_points_sampled) == 0),
    pct_of_farm_sums_to_100    = round(pct_sum, 4)
  )
)

## Pass/fail rollup.
qa$checks <- list(
  crs_is_8058                = qa$crs_epsg == 8058L,
  strata_count_matches       = qa$n_strata_rows == n_strata_expected,
  focus_strata_matches       = qa$n_focus_strata == n_focus_expected,
  pct_sums_to_100            = abs(pct_sum - 100) < 1e-6,
  area_reconciles_1pct       = abs(recon_diff_comm_pct) < 1.0,
  no_null_pixel_counts       = qa$null_checks$n_pixels_any_na == 0L,
  focus_breaks_present       = qa$null_checks$focus_band_breaks_all_present == 1L,
  context_breaks_null        = qa$null_checks$context_band_breaks_all_null == 1L,
  total_points_matches_alloc = total_points == allocation_total,
  points_focus_only          = qa$sampling$points_only_in_focus_strata == 1L
)
qa$all_pass <- all(unlist(qa$checks))

qa_path <- file.path(diagnostics_dir, "pixel_census_qa.json")
jsonlite::write_json(qa, qa_path, auto_unbox = TRUE, pretty = TRUE, digits = 6)
message("Wrote: ", qa_path)

message("\nArea reconciliation:")
message(sprintf("  farm boundary          : %10.1f ha", boundary_area_ha))
message(sprintf("  community union (vector): %10.1f ha  (%.2f%% vs boundary)",
                comm_union_area_ha, comm_vs_boundary_pct))
message(sprintf("  classified valid pixels: %10.1f ha", recon$classified_valid_area_ha))
message(sprintf("  masked-out pixels      : %10.1f ha", recon$masked_out_area_ha))
message(sprintf("  classified+masked-union: %+10.1f ha  (%.3f%%)", recon_diff_comm_ha, recon_diff_comm_pct))


## 11. Acceptance gate ----

stopifnot(
  qa$checks$crs_is_8058,
  qa$checks$strata_count_matches,
  qa$checks$focus_strata_matches,
  qa$checks$pct_sums_to_100,
  qa$checks$area_reconciles_1pct,
  qa$checks$no_null_pixel_counts,
  qa$checks$focus_breaks_present,
  qa$checks$context_breaks_null,
  qa$checks$total_points_matches_alloc,
  qa$checks$points_focus_only
)


## 12. Package for review ----

bundle_dir      <- file.path(root_dir, "Output", "review_bundles", "tier1_pixel_census")
bundle_fig_dir  <- file.path(bundle_dir, "figures")
bundle_diag_dir <- file.path(bundle_dir, "diagnostics")
unlink(bundle_dir, recursive = TRUE, force = TRUE)
for (d in c(bundle_fig_dir, bundle_diag_dir)) dir.create(d, recursive = TRUE, showWarnings = FALSE)

file.copy(list.files(figures_dir, pattern = "^F5d_pixel_census_data\\.(png|pdf)$", full.names = TRUE),
          bundle_fig_dir, overwrite = TRUE)
file.copy(file.path(figures_dir, "figures_manifest.csv"), bundle_dir, overwrite = TRUE)
readr::write_csv(new_rows, file.path(bundle_dir, "manifest_rows_pixel_census.csv"))
file.copy(c(census_csv_path, qa_path, regime_breaks_path), bundle_diag_dir, overwrite = TRUE)

change_report_path <- file.path(root_dir, "docs", "change_reports", "tier1_pixel_census.md")
if (file.exists(change_report_path)) file.copy(change_report_path, bundle_dir, overwrite = TRUE)

bundle_zip <- file.path(root_dir, "Output", "review_bundles", "tier1_pixel_census.zip")
if (file.exists(bundle_zip)) unlink(bundle_zip, force = TRUE)
zip::zip(zipfile = bundle_zip,
         files   = list.files(bundle_dir, recursive = TRUE, full.names = FALSE),
         root    = bundle_dir)
message("Wrote review bundle: ", bundle_zip)


## 13. Final summary ----

message("\n==================== ACCEPTANCE GATE PASSED ====================")
message("View:  v_pixel_census_by_veg_regime  (base table census_stratum) in ", db_path)
message("CSV:   ", census_csv_path)
message("QA:    ", qa_path, "  (all_pass = ", qa$all_pass, ")")
message("Figure:", fig$png)
message("Bundle:", bundle_zip)
print(census_view, n = nrow(census_view))
message("\nSTOP: review Output/review_bundles/tier1_pixel_census.zip before committing.")


####################################################################################################
############################################ TBC ###################################################
####################################################################################################
