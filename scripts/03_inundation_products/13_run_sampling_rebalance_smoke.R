# ------------------------------------------------------------------------------
# Script: scripts/03_inundation_products/13_run_sampling_rebalance_smoke.R
# Purpose: SMOKE test of the F5 rebalance mechanics (B1 per-stratum allocation +
#          B2 seeded Monte-Carlo loop) and the per-draw F6 wiring. Runs a SMALL
#          ~5-draw draw with a PLACEHOLDER allocation to validate mechanics only.
#
#          THIS IS NOT THE PRODUCTION RUN. The definitive 100-draw run + F6 re-run
#          is gated on the Wednesday Adrian sync (final per-stratum allocation,
#          Q1/Q3a). The allocation here is a throwaway placeholder driven through
#          the budget/min_n interface -- the numbers are NOT the production numbers.
#
#          Writes only under Output/diagnostics/sampling_rebalance_smoke/ (gitignored).
#          Does NOT touch the committed stratified_sample_points.gpkg or the DB.
# Run mode: smoke (small; a few minutes). Read-only w.r.t. committed artefacts.
# ------------------------------------------------------------------------------

## 0. Placeholder smoke parameters (NOT production) ----
SMOKE_SEEDS   <- 1:5          # 5 Monte-Carlo draws
SMOKE_BUDGET  <- 90L          # total points/draw (placeholder — real budget lands Wed)
SMOKE_MIN_N   <- 5L           # floor per stratum (placeholder)
NEIGHBOURHOOD_RADIUS <- 2000  # m   (Q1 default — flagged)
EXCLUSION_BUFFER     <- 100    # m
MIN_VALID_YEARS      <- 25     # yrs (Q3a default MIN_VALID_COVERAGE analogue — flagged)
TARGET_CRS           <- 8058L

## 1. Sources ----
root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", getwd()), winslash = "/", mustWork = TRUE)
source(file.path(root_dir, "R", "gayini_helpers.R"))
source(file.path(root_dir, "R", "vector_prep_functions.R"))
source(file.path(root_dir, "R", "gayini_output_helpers.R"))
source(file.path(root_dir, "R", "gayini_gradient_helpers.R"))
source(file.path(root_dir, "R", "gayini_spatial_8058_functions.R"))
source(file.path(root_dir, "R", "gayini_stratified_sampling_functions.R"))
source(file.path(root_dir, "R", "gayini_sampling_allocation.R"))
source(file.path(root_dir, "R", "gayini_monte_carlo_sampling.R"))
source(file.path(root_dir, "R", "gayini_trend_test_functions.R"))

suppressPackageStartupMessages({
  library(sf); library(terra); library(dplyr); library(DBI); library(RSQLite); library(tibble)
})
sf::sf_use_s2(FALSE)

spatial_dir <- file.path(root_dir, "Output", "spatial_8058")
db_path     <- file.path(root_dir, "Output", "database", "Gayini_Results.sqlite")
out_dir     <- file.path(root_dir, "Output", "diagnostics", "sampling_rebalance_smoke")

focus_communities <- gayini_focus_levels()
band_levels       <- gayini_regime_band_levels()

## 2. Inputs (mirrors F5 script 06) ----
communities <- gayini_read_vector(file.path(spatial_dir, "vegetation_communities_epsg8058.gpkg"),
                                  label = "communities (8058)")
plots_raw   <- gayini_read_vector(file.path(spatial_dir, "gayini_hectare_plots_epsg8058.gpkg"),
                                  label = "hectare plots (8058)")
dim_plot <- gayini_load_dim_plot(db_path)
plots <- plots_raw |>
  dplyr::left_join(dim_plot[, c("plot_id", "simplified_vegetation_group")], by = "plot_id")
stopifnot(all(!is.na(plots$simplified_vegetation_group)))

wet_path   <- file.path(root_dir, "Output", "rasters", "inundation_annual_stack", "annual_wet_any_1988_2023.tif")
valid_path <- file.path(root_dir, "Output", "rasters", "inundation_annual_stack", "annual_valid_any_1988_2023.tif")

surface    <- gayini_background_flood_frequency(wet_path, valid_path, min_valid_years = MIN_VALID_YEARS,
                                                target = TARGET_CRS, out_tif = NULL)
freq_8058  <- surface$freq_8058
valid_8058 <- surface$valid_8058
breaks     <- gayini_community_regime_bands(freq_8058, communities, focus_communities)

## 3. PLACEHOLDER allocation (proportional to census stratum size; NOT production) ----
con <- dbConnect(SQLite(), db_path)
census <- dbGetQuery(con, "SELECT community, regime_band, n_pixels
                             FROM census_stratum
                            WHERE regime_band IN ('low','mid','high')")
dbDisconnect(con)
sizes <- data.frame(community = census$community, regime_band = census$regime_band,
                    size = census$n_pixels, stringsAsFactors = FALSE)
allocation <- gayini_stratum_allocation(sizes, method = "proportional",
                                        budget = SMOKE_BUDGET, min_n = SMOKE_MIN_N)
message("\nPLACEHOLDER allocation (", allocation$basis[1], "):")
print(allocation[, c("community", "regime_band", "target_n")], row.names = FALSE)

## 4. Monte-Carlo draw (B2) ----
mc <- gayini_draw_monte_carlo(freq_8058, valid_8058, plots, communities, breaks,
                              focus_communities, NEIGHBOURHOOD_RADIUS, EXCLUSION_BUFFER,
                              MIN_VALID_YEARS, allocation = allocation,
                              seeds = SMOKE_SEEDS, out_dir = out_dir)

## 5. Per-draw F6 wiring — run F6 on the FIRST draw's points ----
thresholds <- gayini_trend_thresholds()
draw1 <- mc$points[mc$points$draw == 1, ]
verdicts <- gayini_f6_verdicts_for_points(draw1, wet_path, valid_path,
                                          focus_communities, band_levels, thresholds)
message("\nPer-draw F6 wiring (draw 1) — per-stratum verdicts:")
print(as.data.frame(verdicts[, intersect(c("stratum", "verdict"), names(verdicts))]), row.names = FALSE)

## 6. Smoke assertions ----
alloc_total <- sum(allocation$target_n)
ids <- mc$points$sample_point_id
per_draw <- mc$summary |>
  dplyr::group_by(draw) |>
  dplyr::summarise(drawn = sum(n_drawn), short = sum(shortfall), .groups = "drop")

checks <- c(
  five_draws                = length(unique(mc$summary$seed)) == length(SMOKE_SEEDS),
  allocation_sums_to_budget = alloc_total == SMOKE_BUDGET,
  every_stratum_ge_min_n    = all(allocation$target_n >= SMOKE_MIN_N),
  ids_globally_unique       = !any(duplicated(ids)),
  ids_seed_namespaced       = all(grepl("^SP_[0-9]+_[0-9]{4}$", ids)),
  each_draw_hits_target     = all(per_draw$drawn == alloc_total) && all(per_draw$short == 0L),
  f6_returns_9_strata       = nrow(verdicts) == 9L,
  f6_verdicts_valid         = all(verdicts$verdict %in% c("no_trend", "non_stationary", "directional_trend"))
)
message("\n== SMOKE CHECKS ==")
for (nm in names(checks)) message(sprintf("  %-26s %s", nm, if (checks[[nm]]) "PASS" else "FAIL"))
message(sprintf("\nWrote per-seed outputs to: %s", out_dir))
message("Placeholder allocation only — NO production run, committed sample + DB untouched.")

if (!all(unlist(checks))) quit(status = 1L, save = "no")
message("\nREBALANCE MECHANICS SMOKE: ALL CHECKS PASS")
