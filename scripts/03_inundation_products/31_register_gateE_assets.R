# ------------------------------------------------------------------------------
# Script: scripts/03_inundation_products/31_register_gateE_assets.R
# Purpose: Tier 2 · Task H · Gate E (G7) — NON-DESTRUCTIVE registration of the Gate
#          E products in the results DB. Additive only: idempotent delete-by-id +
#          insert, with Gate-E-specific ids that never collide with the existing
#          figure_NNNNN / raster rows. NEVER reset_file (that destroys the 12 Task H
#          census rows). Registers:
#            - the Gate E figures        -> figure_asset  (starts closing D4)
#            - the response r-raster +
#              the two annual veg stacks -> raster_asset
#            - the G1b response tables   -> report_asset
#          Reports before/after counts.
#
# Workflow stage: 03_inundation_products · Tier 2 Task H, Gate E, G7 · post-build DB touch
# Run mode: DB mutation (INSERT/REPLACE by id only) · idempotent · re-run after any rebuild
# Key inputs/outputs: Output/database/Gayini_Results.sqlite ; Output/figures, rasters, diagnostics
# ------------------------------------------------------------------------------

RUN_ID <- "gateE_20260721"

root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", getwd()), winslash = "/", mustWork = TRUE)
source(file.path(root_dir, "R", "gayini_helpers.R"))
source(file.path(root_dir, "R", "gayini_output_paths.R"))
suppressPackageStartupMessages({ library(DBI); library(RSQLite); library(terra) })
terra::terraOptions(progress = 0)

db_path  <- file.path(root_dir, "Output", "database", "Gayini_Results.sqlite")
fig_dir  <- file.path(root_dir, "Output", "figures")
ras_dir  <- file.path(root_dir, "Output", "rasters", "veg_annual_8058")
diag_dir <- file.path(root_dir, "Output", "diagnostics")
gayini_stop_if_missing(db_path, label = "Gayini_Results.sqlite")

sha256_of <- function(path) tryCatch(
  if (requireNamespace("digest", quietly = TRUE)) digest::digest(file = path, algo = "sha256") else NA_character_,
  error = function(e) NA_character_)
relp <- function(p) gayini_relative_path(root_dir, p)

## ---- asset specs --------------------------------------------------------------

figures <- tibble::tribble(
  ~id,                         ~file,                                 ~title,                                                    ~use,
  "figure_gateE_s12",          "S12_stratum_coverage.png",            "S12 stratum coverage (all-pixel, mapped basis)",          "deck_or_report",
  "figure_gateE_s21",          "S21_flood_trend_census.png",          "S21 flood-trend census (9 no-trend / 0 / 0)",             "deck_or_report",
  "figure_gateE_s24",          "S24_response_singles.png",            "S24 veg x wetness response, per community",                "deck_or_report",
  "figure_gateE_s25",          "S25_lag_profile.png",                 "S25 cover response lag (PLOT support)",                    "deck_or_report",
  "figure_gateE_s26",          "S26_response_matrix.png",             "S26 veg x wetness response matrix (3x3)",                  "deck_or_report",
  "figure_gateE_figA",         "FigA_floor_gradient_density.png",     "Fig A veg floor vs flood freq density + GAM (appendix)",   "appendix_or_methods",
  "figure_gateE_vw_gam_p05",   "S_veg_water_gam_p05.png",             "Veg-water GAM cloud (floor p05), by community",            "deck_or_report",
  "figure_gateE_vw_gam_p50",   "S_veg_water_gam_p50.png",             "Veg-water GAM cloud (typical p50), by community",          "deck_or_report",
  "figure_gateE_vw_qb_p05",    "S_veg_water_qband_p05.png",           "Veg-water quantile bands (floor p05), by community",       "deck_or_report",
  "figure_gateE_vw_qb_p50",    "S_veg_water_qband_p50.png",           "Veg-water quantile bands (typical p50), by community",     "deck_or_report",
  "figure_gateE_vw_fan",       "S_veg_water_percentile_fan.png",      "Veg-water percentile fan (signal is in the floor)",        "deck_or_report")

rasters <- tibble::tribble(
  ~id,                               ~file,                                          ~metric,                    ~product,               ~sem,
  "raster_veg_wet_response_r_8058",  "census_veg_wet_response_r_meanseason_8058.tif", "veg_wet_response_r",       "veg_wet_response_8058", "Per-pixel same-year Pearson r of annual total-veg (mean-of-seasons) vs annual binary wet/dry state, 1988-2023, over focus census pixels. G1b. Pixel support; not independent n.",
  "raster_total_veg_annual_mean_8058","total_veg_annual_mean_8058.tif",              "total_veg_annual_mean",    "total_veg_annual_8058", "35-layer annual total-veg (mean of available seasons per water year), bilinear to the 8058 census grid. G1a base series.",
  "raster_total_veg_annual_jjason_8058","total_veg_annual_jja_son_8058.tif",         "total_veg_annual_jja_son", "total_veg_annual_8058", "35-layer annual total-veg (JJA/SON growing-season mean per water year), bilinear to the 8058 census grid. G1a robustness cross-check.")

reports <- tibble::tribble(
  ~id,                          ~file,                                                        ~title,                                        ~type,
  "report_gateE_resp_stratum",  "tier2H_g1b_census_veg_wet_response_by_stratum.csv",          "G1b census veg x wet response by stratum",    "census_response_table",
  "report_gateE_resp_community","tier2H_g1b_census_veg_wet_response_by_community.csv",         "G1b census veg x wet response by community",  "census_response_table")

## ---- register ----------------------------------------------------------------

con <- dbConnect(SQLite(), db_path)
on.exit(dbDisconnect(con), add = TRUE)
cnt <- function(t) dbGetQuery(con, sprintf("SELECT COUNT(*) n FROM %s", t))$n
before <- c(figure_asset = cnt("figure_asset"), raster_asset = cnt("raster_asset"), report_asset = cnt("report_asset"))

## figures
for (i in seq_len(nrow(figures))) {
  f <- figures[i, ]; path <- file.path(fig_dir, f$file)
  gayini_stop_if_missing(path, label = f$file)
  dbExecute(con, "DELETE FROM figure_asset WHERE figure_asset_id = ?", params = list(f$id))
  dbExecute(con,
    "INSERT INTO figure_asset (figure_asset_id, path, title, domain, metric_id, recommended_use,
                               checksum_sha256, path_exists, qa_status, run_id)
     VALUES (?,?,?,?,?,?,?,?,?,?)",
    params = list(f$id, relp(path), f$title, "tier2H_gateE", NA_character_, f$use,
                  sha256_of(path), 1L, "REVIEW", RUN_ID))
}

## rasters
for (i in seq_len(nrow(rasters))) {
  r <- rasters[i, ]; path <- file.path(ras_dir, r$file)
  gayini_stop_if_missing(path, label = r$file)
  rr <- terra::rast(path); ex <- as.vector(terra::ext(rr)); rs <- terra::res(rr)
  dbExecute(con, "DELETE FROM raster_asset WHERE raster_asset_id = ?", params = list(r$id))
  dbExecute(con,
    "INSERT INTO raster_asset (raster_asset_id, path, metric_id, water_year, period_label, crs,
        resolution_x, resolution_y, xmin, ymin, xmax, ymax, checksum_sha256, path_exists, qa_status,
        run_id, crs_epsg, product, legend_status, legend_semantics)
     VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
    params = list(r$id, relp(path), r$metric, NA_character_, "WY1988-2023", "EPSG:8058",
                  rs[1], rs[2], ex[1], ex[3], ex[2], ex[4], sha256_of(path), 1L, "REVIEW",
                  RUN_ID, 8058L, r$product, "confirmed", r$sem))
}

## reports (tables)
for (i in seq_len(nrow(reports))) {
  rp <- reports[i, ]; path <- file.path(diag_dir, rp$file)
  gayini_stop_if_missing(path, label = rp$file)
  dbExecute(con, "DELETE FROM report_asset WHERE report_asset_id = ?", params = list(rp$id))
  dbExecute(con,
    "INSERT INTO report_asset (report_asset_id, path, title, report_type, checksum_sha256,
                               path_exists, qa_status, run_id)
     VALUES (?,?,?,?,?,?,?,?)",
    params = list(rp$id, relp(path), rp$title, rp$type, sha256_of(path), 1L, "REVIEW", RUN_ID))
}

after <- c(figure_asset = cnt("figure_asset"), raster_asset = cnt("raster_asset"), report_asset = cnt("report_asset"))

## ---- report ------------------------------------------------------------------

message("\n================ G7 · registration (additive, non-destructive) ================")
for (t in names(before))
  message(sprintf("  %-13s : %d -> %d  (+%d)", t, before[[t]], after[[t]], after[[t]] - before[[t]]))
message(sprintf("  registered: %d figures · %d rasters · %d tables, run_id='%s'",
                nrow(figures), nrow(rasters), nrow(reports), RUN_ID))
## Confirm path_exists holds for every new row.
bad <- dbGetQuery(con, sprintf(
  "SELECT 'figure' k, figure_asset_id id FROM figure_asset WHERE run_id='%s' AND path_exists<>1
   UNION ALL SELECT 'raster', raster_asset_id FROM raster_asset WHERE run_id='%s' AND path_exists<>1
   UNION ALL SELECT 'report', report_asset_id FROM report_asset WHERE run_id='%s' AND path_exists<>1",
  RUN_ID, RUN_ID, RUN_ID))
stopifnot(nrow(bad) == 0)
message("  all new rows path_exists = 1. Existing rows untouched (D4 stale figure rows left as-is).")
message("\n==================== G7 COMPLETE ====================")
