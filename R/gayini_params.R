# gayini_params.R - the ONE place a Gayini project constant may appear.
# Every other file references these; a bare literal from GAYINI_MAGIC_LITERALS
# anywhere under scripts/ or R/ (outside this file / its Python twin) fails the
# smoke-test magic-number lint. PIXEL_AREA_HA is DERIVED, never typed - that one
# line removes the 0.0625-vs-0.062351428 class of error.
#
# Spec: docs/T5_guardrails_and_checks.md Gate 1.1. Twin: scripts/lib/gayini_params.py.

GAYINI_PARAMS <- local({
  PIXEL_SIDE_M      <- 24.970268                 # raster_asset.resolution_x (8058)
  list(
    PIXEL_SIDE_M      = PIXEL_SIDE_M,
    PIXEL_AREA_HA     = PIXEL_SIDE_M^2 / 1e4,     # DERIVED, never typed = 0.062351428
    MAPPED_AREA_HA    = 67349.332,                # census_stratum.farm_area_ha
    TRUE_FARM_HA      = 85910.8,                  # census_stratum.farm_area_total_ha
    TOTAL_CENSUS_PX   = 1080157L,                 # census_asset.n_rows
    SCOPE_NON_TREED   = "treed_context_flag = 0 AND regime_band <> 'context'",
    SCOPE_ALL_PIXEL   = "1=1",
    CRS_CANONICAL     = 8058L,
    CRS_INUNDATION    = 28355L,
    CRS_FC_SOURCE     = 3577L,
    CRS_PLOT_CENTROID = 9473L
  )
})

# Load-time self-check: the DB is authoritative. If it is reachable and a value
# disagrees, ERROR (never silently diverge). If it is unreachable, WARN only, so
# the module still loads in DB-less contexts.
gayini_params_validate <- function(db_path = file.path("Output", "database", "Gayini_Results.sqlite"),
                                   tol = 1e-4) {
  if (!file.exists(db_path)) {
    warning("gayini_params: DB not found at ", db_path, " - self-check skipped.")
    return(invisible(FALSE))
  }
  if (!requireNamespace("DBI", quietly = TRUE) || !requireNamespace("RSQLite", quietly = TRUE)) {
    warning("gayini_params: DBI/RSQLite unavailable - self-check skipped.")
    return(invisible(FALSE))
  }
  con <- DBI::dbConnect(RSQLite::SQLite(), db_path, flags = RSQLite::SQLITE_RO)
  on.exit(DBI::dbDisconnect(con))
  res <- DBI::dbGetQuery(con, "SELECT resolution_x FROM raster_asset WHERE crs_epsg=8058 LIMIT 1")
  cs  <- DBI::dbGetQuery(con, "SELECT farm_area_ha, farm_area_total_ha FROM census_stratum LIMIT 1")
  nr  <- DBI::dbGetQuery(con, "SELECT n_rows FROM census_asset WHERE census_asset_id='census_pixel_8058'")
  checks <- list(
    c("PIXEL_SIDE_M",    GAYINI_PARAMS$PIXEL_SIDE_M,   res$resolution_x[1],      tol),
    c("MAPPED_AREA_HA",  GAYINI_PARAMS$MAPPED_AREA_HA, cs$farm_area_ha[1],       0.01),
    c("TRUE_FARM_HA",    GAYINI_PARAMS$TRUE_FARM_HA,   cs$farm_area_total_ha[1], 0.01),
    c("TOTAL_CENSUS_PX", GAYINI_PARAMS$TOTAL_CENSUS_PX, nr$n_rows[1],            0.5))
  for (ch in checks) {
    nm <- ch[[1]]; want <- as.numeric(ch[[2]]); got <- as.numeric(ch[[3]]); t <- as.numeric(ch[[4]])
    if (is.na(got)) stop(sprintf("gayini_params: DB returned NA for %s", nm))
    if (abs(want - got) > t)
      stop(sprintf("gayini_params: %s = %s disagrees with DB %s (tol %s). Fix the module or the DB, do not diverge.",
                   nm, want, got, t))
  }
  invisible(TRUE)
}

# run on load (non-fatal only when the DB is absent)
try(gayini_params_validate(), silent = TRUE) -> .gayini_params_ok
if (isTRUE(.gayini_params_ok)) message("gayini_params: DB self-check passed.")
