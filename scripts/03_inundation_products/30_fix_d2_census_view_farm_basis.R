# ------------------------------------------------------------------------------
# Script: scripts/03_inundation_products/30_fix_d2_census_view_farm_basis.R
# Purpose: Tier 2 · Task H · Gate E (G6) — D2 fix, NON-DESTRUCTIVE. The census view
#          v_pixel_census_by_veg_regime derives pct_of_farm as 100*area_ha/farm_area_ha,
#          but census_stratum.farm_area_ha is a MISNOMER holding the MAPPED area
#          (67,349.332 ha), not the farm (85,910.8 ha) — so pct_of_farm was really
#          "% of mapped", overstating "% of farm" by 85,910.8/67,349.332 = x1.276.
#
#          Fix (additive; NEVER reset_file): add census_stratum.farm_area_total_ha =
#          85,910.8, then recreate ONLY the view with pct_of_farm on the true farm
#          denominator AND an explicit pct_of_mapped for the mapped basis (the S12
#          "66.44% of mapped" held trap). No table data is dropped; the builder
#          function (gayini_write_pixel_census_view) is updated to match for rebuilds.
#
# Workflow stage: 03_inundation_products · Tier 2 Task H, Gate E, G6 · post-build DB touch
# Run mode: DB mutation (ADD COLUMN + recreate view only) · idempotent · re-run after any rebuild
# Key inputs/outputs: Output/database/Gayini_Results.sqlite
# ------------------------------------------------------------------------------

FARM_AREA_TOTAL_HA <- 85910.8   # true farm (gayini_boundary -> 8058 area); facts §1

root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", getwd()), winslash = "/", mustWork = TRUE)
source(file.path(root_dir, "R", "gayini_helpers.R"))
suppressPackageStartupMessages({ library(DBI); library(RSQLite) })

db_path <- file.path(root_dir, "Output", "database", "Gayini_Results.sqlite")
gayini_stop_if_missing(db_path, label = "Gayini_Results.sqlite")

con <- dbConnect(SQLite(), db_path)
on.exit(dbDisconnect(con), add = TRUE)

## 1. Add the true-farm column (idempotent) and populate it.
cols <- dbListFields(con, "census_stratum")
if (!"farm_area_total_ha" %in% cols)
  dbExecute(con, "ALTER TABLE census_stratum ADD COLUMN farm_area_total_ha REAL")
dbExecute(con, "UPDATE census_stratum SET farm_area_total_ha = ?", params = list(FARM_AREA_TOTAL_HA))

## 2. Recreate ONLY the view (derived — safe to drop/recreate; no table data touched).
dbExecute(con, "DROP VIEW IF EXISTS v_pixel_census_by_veg_regime")
dbExecute(con,
  "CREATE VIEW v_pixel_census_by_veg_regime AS
   SELECT
     community, regime_band, treed_context_flag, band_freq_lo_pct, band_freq_hi_pct,
     n_pixels, area_ha,
     100.0 * area_ha / farm_area_total_ha                        AS pct_of_farm,
     100.0 * area_ha / farm_area_ha                              AS pct_of_mapped,
     n_points_sampled,
     CASE WHEN n_pixels > 0
          THEN CAST(n_points_sampled AS REAL) / n_pixels END     AS sampling_fraction,
     CASE WHEN area_ha > 0
          THEN 1000.0 * n_points_sampled / area_ha END           AS points_per_1000ha,
     valid_year_threshold
   FROM census_stratum
   ORDER BY community_order, band_order")

## 3. Verify against data: pct_of_farm now on the true denominator; mapped basis preserved.
chk <- dbGetQuery(con, "SELECT community, regime_band, area_ha, pct_of_farm, pct_of_mapped
                        FROM v_pixel_census_by_veg_regime WHERE regime_band='low'
                          AND community='Aeolian Chenopod Shrublands'")
inl <- dbGetQuery(con, "SELECT SUM(pct_of_farm) f, SUM(pct_of_mapped) m
                        FROM v_pixel_census_by_veg_regime WHERE community LIKE 'Inland%'")
message(sprintf("Aeolian low: pct_of_farm=%.4f%% (true, 85,910.8) · pct_of_mapped=%.4f%% (67,349.332)",
                chk$pct_of_farm, chk$pct_of_mapped))
message(sprintf("Inland total: pct_of_farm=%.2f%% (true) · pct_of_mapped=%.2f%% (mapped — the held trap)",
                inl$f, inl$m))
stopifnot(abs(chk$pct_of_mapped - 2.4798) < 0.01,        # mapped basis unchanged
          abs(chk$pct_of_farm - 1.9440) < 0.01,          # true-farm basis = mapped / 1.276
          abs(inl$m - 66.44) < 0.05)                     # S12 held trap preserved on mapped
message("\n==> D2 FIXED (non-destructive): pct_of_farm now divides by the true farm; pct_of_mapped added.")
message("    census_stratum.farm_area_ha remains the (misnamed) MAPPED value — renaming it is out of scope.")
