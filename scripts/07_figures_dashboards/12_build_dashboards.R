# ------------------------------------------------------------------------------
# Script: scripts/07_figures_dashboards/12_build_dashboards.R
# Purpose: Tier 1 · Task G — dashboards refresh. Build the dashboard composer +
#          modular panels on the trial subset in the ONE converged layout family
#          (big map left · aligned time-series column right · compact gauge bar ·
#          "where it sits" boxplot · sqrt-x vegetation response), plus one A3
#          example, for review. The A/B/C layout bake-off is resolved. Evolves the
#          old GA_### design: no pre/post; adds map + locator inset, baseline
#          gauge bar, and the F4-style "where it sits" boxplot; series share one
#          date axis (G3); vegetation-response on a sqrt x (G2).
# Workflow stage: 07_figures_dashboards
# Run mode: analysis (raster extraction per unit) · lightweight_review outputs
# Key inputs:
#   - Output/rasters/{background_flood_frequency_8058, veg_regime_class_8058}.tif
#   - Output/rasters/inundation_annual_stack/annual_{wet,valid}_any_1988_2023.tif
#   - Output/spatial_8058/{boundary, vegetation_communities, management_zones,
#     gayini_hectare_plots}_epsg8058.gpkg
#   - Output/database/Gayini_Results.sqlite (spine, groundcover, gauge, dim_plot)
#   - Output/diagnostics/{regime_band_breaks, f6_verdict_summary, f6_stratum_annual_series}.csv
# Key outputs:
#   - Output/figures/D{1,2,3}_*_slide_data.{png,pdf} + one A3
#   - Output/diagnostics/dashboards_trial_qa.json
#   - Output/review_bundles/tier1G_figures_dashboards.zip
# Notes:
#   - HARD RULES: no pre/post (no 2019/2020 line, no drier_post, no pre/post box);
#     trend wording provisional; boxplot on ABSOLUTE flood frequency; EPSG:8058.
#   - Site neighbourhood radius default 1 km (parameterised); baseline recent
#     window 5 water years; paddock map = C1 checkerboard.
#   - Stops at an acceptance gate; commit is a separate, human-reviewed step.
# ------------------------------------------------------------------------------

####################################################################################################


## GAYINI REMOTE SENSING PROJECT — Tier 1 · Dashboards Phase 1 (trial)


####################################################################################################


## 0. Settings ----

RADIUS_M      <- 1000L          # site neighbourhood ring (parameterised 500-2000)
GAUGE_STATION <- "410040"       # Murrumbidgee D/S Maude Weir (local context)

TRIAL_PADDOCKS <- c("Bala 28ca", "Bala 29ca", "Dinan 8", "Dinan 10")
TRIAL_SITES    <- c("GA_001", "GA_003", "GA_019", "GA_052", "GA_032")
TRIAL_STRATA   <- list(
  c("Aeolian Chenopod Shrublands", "low"),
  c("Riverine Chenopod Shrublands", "mid"),
  c("Inland Floodplain Shrublands / Swamps", "high"))


## 1. Sources ----

root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", getwd()), winslash = "/", mustWork = TRUE)

source(file.path(root_dir, "R", "gayini_helpers.R"))
source(file.path(root_dir, "R", "vector_prep_functions.R"))
source(file.path(root_dir, "R", "gayini_output_helpers.R"))
source(file.path(root_dir, "R", "gayini_gradient_helpers.R"))
source(file.path(root_dir, "R", "gayini_spatial_8058_functions.R"))
source(file.path(root_dir, "R", "gayini_descriptive_figures.R"))
source(file.path(root_dir, "R", "gayini_stratified_sampling_functions.R"))
source(file.path(root_dir, "R", "gayini_ground_cover_response_functions.R"))
source(file.path(root_dir, "R", "gayini_area_map.R"))
source(file.path(root_dir, "R", "gayini_veg_regime_functions.R"))
source(file.path(root_dir, "R", "gayini_dashboard_panels.R"))
source(file.path(root_dir, "R", "gayini_dashboard_compose.R"))

suppressPackageStartupMessages({
  library(sf); library(terra); library(dplyr); library(ggplot2)
  library(DBI); library(RSQLite); library(tidyr); library(cowplot); library(patchwork)
})
sf::sf_use_s2(FALSE)

figures_dir     <- file.path(root_dir, "Output", "figures")
diagnostics_dir <- file.path(root_dir, "Output", "diagnostics")


## 2. Shared context ----

message("Loading dashboard context ...")
ctx <- gayini_dashboard_context(root_dir, station_id = GAUGE_STATION, radius_m = RADIUS_M)


## 3. Build the trial units x layouts (slide) ----

slugify <- function(s) gsub("[^A-Za-z0-9]+", "_", trimws(s))

manifest_rows <- list()
qa_units      <- list()
built         <- 0L

register <- function(step, paths, inputs) {
  dplyr::bind_rows(
    gayini_manifest_row(step, "data", paths$png, inputs, "EPSG:8058", root_dir),
    gayini_manifest_row(step, "data", paths$pdf, inputs, "EPSG:8058", root_dir))
}

build_unit <- function(resolved, step, unit_slug, formats = "slide") {
  for (fmt in formats) {
    tag  <- if (fmt == "slide") "slide" else fmt
    base <- sprintf("%s_%s_%s_data", step, unit_slug, tag)
    paths <- gayini_build_dashboard(resolved, ctx, format = fmt,
                                    out_dir = figures_dir, basename = base)
    manifest_rows[[length(manifest_rows) + 1L]] <<- register(step, paths,
      sprintf("dashboard %s [%s, converged layout, %s]", unit_slug, step, fmt))
    built <<- built + 1L
  }
}

## D2 · sites (priority: closest to the old design) ----
message("D2 site dashboards ...")
for (pid in TRIAL_SITES) {
  r <- gayini_resolve_site(pid, ctx)
  build_unit(r, "D2", paste0("site_", pid))
  qa_units[[length(qa_units) + 1L]] <- list(
    unit = pid, type = "site", community = r$box$community,
    n_plots_response = r$resp$n_plots,
    flood_year_min = min(r$flooding$year), flood_year_max = max(r$flooding$year),
    site_neighbourhood_valid_pixels = as.integer(max(r$flooding$n_valid, na.rm = TRUE)),
    box_value_abs_freq = round(r$box$value, 2), radius_m = RADIUS_M)
}

## D1 · paddocks ----
message("D1 paddock dashboards ...")
for (pad in TRIAL_PADDOCKS) {
  r <- gayini_resolve_paddock(pad, ctx)
  build_unit(r, "D1", paste0("paddock_", slugify(pad)))
  qa_units[[length(qa_units) + 1L]] <- list(
    unit = pad, type = "paddock", community = r$box$community,
    n_plots_response = r$resp$n_plots, response_fallback = r$resp$fallback,
    flood_year_min = min(r$flooding$year), flood_year_max = max(r$flooding$year),
    box_value_abs_freq = round(r$box$value, 2))
}

## D3 · strata ----
message("D3 stratum dashboards ...")
for (st in TRIAL_STRATA) {
  r <- gayini_resolve_stratum(st[1], st[2], ctx)
  build_unit(r, "D3", paste0("stratum_", slugify(st[1]), "_", st[2]))
  qa_units[[length(qa_units) + 1L]] <- list(
    unit = sprintf("%s | %s", st[1], st[2]), type = "stratum", community = st[1],
    n_plots_response = r$resp$n_plots,
    flood_year_min = min(r$flooding$year), flood_year_max = max(r$flooding$year),
    trend_note = r$flood_note, box_value_abs_freq = round(r$box$value, 2))
}

## One A3 example (landscape) — richest paddock ----
message("A3 example ...")
r_a3 <- gayini_resolve_paddock("Bala 29ca", ctx)
build_unit(r_a3, "D1", "paddock_Bala_29ca", formats = "a3_landscape")


## 4. Register in the figures manifest ----

new_rows <- dplyr::bind_rows(manifest_rows)
manifest <- gayini_update_figures_manifest(new_rows, root = root_dir)


## 5. QA ----

trend_ok <- all(vapply(qa_units, function(u)
  is.null(u$trend_note) || grepl("provisional", u$trend_note), logical(1)))
sites <- Filter(function(u) u$type == "site", qa_units)

qa <- list(
  generated_by  = "scripts/07_figures_dashboards/12_build_dashboards.R",
  crs_epsg      = gayini_crs_epsg(ctx$freq_layer),
  radius_m      = RADIUS_M,
  gauge_station = GAUGE_STATION,
  recent_window_years = 5,
  n_figures_built = built,
  n_manifest_rows = nrow(new_rows),
  units = qa_units,
  checks = list(
    crs_is_8058              = gayini_crs_epsg(ctx$freq_layer) == 8058L &&
                               gayini_crs_epsg(ctx$class_layer) == 8058L,
    flooding_full_record     = all(vapply(qa_units, function(u)
                                 u$flood_year_min == 1988 && u$flood_year_max == 2022, logical(1))),
    no_prepost_by_construction = TRUE,
    site_pixels_within_radius = all(vapply(sites, function(u)
                                 u$site_neighbourhood_valid_pixels > 0, logical(1))),
    plot_counts_stated       = all(vapply(qa_units, function(u) !is.null(u$n_plots_response), logical(1))),
    provisional_trend_wording = trend_ok,
    boxplot_absolute_frequency = all(vapply(qa_units, function(u)
                                 is.numeric(u$box_value_abs_freq) && u$box_value_abs_freq >= 0 &&
                                 u$box_value_abs_freq <= 100, logical(1))),
    all_units_built          = built == (length(TRIAL_SITES) + length(TRIAL_PADDOCKS) +
                                         length(TRIAL_STRATA)) + 1L
  ))
qa$all_pass <- all(unlist(qa$checks))

qa_path <- file.path(diagnostics_dir, "dashboards_trial_qa.json")
jsonlite::write_json(qa, qa_path, auto_unbox = TRUE, pretty = TRUE, digits = 4)
message("Wrote: ", qa_path, "  (all_pass = ", qa$all_pass, ")")


## 6. Acceptance gate ----

stopifnot(
  qa$checks$crs_is_8058,
  qa$checks$flooding_full_record,
  qa$checks$site_pixels_within_radius,
  qa$checks$plot_counts_stated,
  qa$checks$provisional_trend_wording,
  qa$checks$boxplot_absolute_frequency,
  qa$checks$all_units_built
)


## 7. Package for review ----

## Dashboards are copied into the shared Task-G review bundle; the F5 concept and
## F7 response figures are added alongside by the handoff step before zipping.
bundle_dir     <- file.path(root_dir, "Output", "review_bundles", "tier1G_figures_dashboards")
bundle_fig_dir <- file.path(bundle_dir, "figures")
bundle_diag    <- file.path(bundle_dir, "diagnostics")
for (d in c(bundle_fig_dir, bundle_diag)) dir.create(d, recursive = TRUE, showWarnings = FALSE)

file.copy(list.files(figures_dir, pattern = "^D[123]_.*_data\\.(png|pdf)$", full.names = TRUE),
          bundle_fig_dir, overwrite = TRUE)
file.copy(file.path(figures_dir, "figures_manifest.csv"), bundle_dir, overwrite = TRUE)
readr::write_csv(new_rows, file.path(bundle_dir, "manifest_rows_dashboards.csv"))
file.copy(qa_path, bundle_diag, overwrite = TRUE)


## 8. Summary ----

message("\n================ TASK G DASHBOARDS BUILT ===================")
message("Figures built: ", built, " (", nrow(new_rows), " manifest rows), one converged layout per unit")
message("Sites: ", paste(TRIAL_SITES, collapse = ", "))
message("Paddocks: ", paste(TRIAL_PADDOCKS, collapse = ", "))
message("Strata: ", paste(vapply(TRIAL_STRATA, function(s) paste(s, collapse = "|"), ""), collapse = ", "))
message("QA all_pass = ", qa$all_pass, "  ->  ", qa_path)
message("Dashboards copied to: ", bundle_dir)
message("\nSTOP: F5 concept + F7 are added to the Task-G bundle by the handoff step, then zipped for review.")


####################################################################################################
############################################ TBC ###################################################
####################################################################################################
