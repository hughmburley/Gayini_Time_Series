# ------------------------------------------------------------------------------
# Script: scripts/01_prepare_inputs/05_populate_metric_support.R
# Purpose: Correction C10 (Tier 2 · Task H) — give dim_metric a SUPPORT dimension.
#          Between-year flood frequency is ONE metric measured on TWO supports, and
#          until now they were indistinguishable by name:
#            - PLOT support (~1 ha, any-pixel rule, 66 plots): Aeolian 9 / Riverine 22
#              / Inland 50 / Woodland 44  -- "how often does a 1-ha site see any water"
#            - PIXEL support (24.97 m census pixel): Aeolian 6.1 / Riverine 12.9 /
#              Inland 28.0                -- "how often is a 25 m pixel wet"
#          Both are correct and both are between-year. The 1.5-1.8x gap is
#          P(any of ~16 pixels) >> P(one pixel) -- NOT a within-year/between-year
#          confusion (the within-year annual_occurrence_pct means are 4.0/11.6/31.2,
#          a different metric again -- that is C8's name trap, this is a second and
#          distinct one).
#          Verified: annual_wet_any <=> occurrence_pct > 0 (1,590 dry plot-years all
#          occ = 0; 720 wet plot-years all occ > 0), i.e. the plot flag IS the
#          any-pixel rule.
# Workflow stage: 01_prepare_inputs
# Run mode: light (DB metadata only) · POST-BUILD DB MUTATION
# Key inputs:
#   - Output/database/Gayini_Results.sqlite (dim_metric)
# Key outputs:
#   - dim_metric.support populated; census between-year frequency metric registered
# Notes:
#   - POST-BUILD MUTATION. The Python builder unlinks + rebuilds the DB from its
#     METRICS list, which has no `support` column, so this must be re-run after any
#     full rebuild. Add to the post-build chain (see CLAUDE.md).
#   - ADDITIVE: adds a column + fills it, and adds one new metric row. It does NOT
#     rewrite or replace any existing metric definition. The plot-support numbers
#     (9/22/50/44) are CORRECT and are not touched -- they are merely labelled.
# ------------------------------------------------------------------------------

root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", getwd()), winslash = "/", mustWork = TRUE)

suppressPackageStartupMessages({
  library(DBI)
  library(RSQLite)
})

db_path <- file.path(root_dir, "Output", "database", "Gayini_Results.sqlite")
if (!file.exists(db_path)) stop("Results DB not found: ", db_path, call. = FALSE)

SUPPORT_PIXEL <- "pixel 24.97 m (EPSG:8058 census grid)"
SUPPORT_PLOT  <- "plot ~1 ha (any-pixel rule: wet if ANY of ~16 pixels is wet; 66 plots)"

con <- dbConnect(RSQLite::SQLite(), db_path)
on.exit(dbDisconnect(con), add = TRUE)

## 1. Add the support column if the schema predates it (additive) ----

cols <- dbGetQuery(con, "PRAGMA table_info(dim_metric)")$name
if (!"support" %in% cols) {
  dbExecute(con, "ALTER TABLE dim_metric ADD COLUMN support TEXT")
  message("  added column dim_metric.support")
} else {
  message("  dim_metric.support already present")
}

## 2. Label the existing metrics by support ----

n_pixel <- dbExecute(con,
  "UPDATE dim_metric SET support = ?
    WHERE metric_id LIKE 'census\\_%' ESCAPE '\\' OR metric_id = 'veg_regime_class'",
  params = list(SUPPORT_PIXEL))

## The plot-support family: the annual wet FLAG (this is the any-pixel rule, and it
## is what the 9/22/50/44 headline aggregates) and the within-year area metric.
n_plot <- dbExecute(con,
  "UPDATE dim_metric SET support = ?
    WHERE metric_id IN ('inundation_annual_wet_any', 'inundation_annual_occurrence_pct')",
  params = list(SUPPORT_PLOT))

message(sprintf("  labelled %d pixel-support and %d plot-support metric rows.", n_pixel, n_plot))

## 3. Register the census between-year flood frequency metric (new; pixel support) ----

census_metric <- list(
  "census_flood_frequency_pct",
  "Census between-year flood frequency (pixel support)",
  "inundation", "pct", "0-100",
  "wet-valid-years", "valid-years",
  paste("100 x wet-valid-years / valid-years computed over EVERY census pixel in a",
        "vegetation x wetness stratum, on the nearest-neighbour-reprojected EPSG:8058",
        "annual stack (Tier2H H3.0/H3.1). Strata are the F5 regime_band_breaks.csv",
        "edges (option 2, decouple)."),
  paste("How often a 24.97 m pixel is wet, between years. Community means:",
        "Aeolian 6.1 / Riverine 12.9 / Inland Floodplain 28.0."),
  paste("PIXEL SUPPORT (C10). NOT comparable to the plot-support headline",
        "(Aeolian 9 / Riverine 22 / Inland 50 / Woodland 44), which applies the",
        "any-pixel rule over ~16 pixels per 1-ha plot. Both are correct between-year",
        "measures of different things; never compare or substitute across supports."),
  SUPPORT_PIXEL
)
dbExecute(con, "INSERT OR REPLACE INTO dim_metric
  (metric_id, metric_name, domain, units, scale, numerator, denominator,
   method_summary, safe_interpretation, caveat, support)
  VALUES (?,?,?,?,?,?,?,?,?,?,?)", params = census_metric)
message("  registered metric: census_flood_frequency_pct (pixel support)")

## 4. Report ----

out <- dbGetQuery(con,
  "SELECT metric_id, support FROM dim_metric WHERE support IS NOT NULL ORDER BY support, metric_id")
message("\nMetrics now carrying an explicit support:")
print(out, row.names = FALSE)

n_unlabelled <- dbGetQuery(con, "SELECT COUNT(*) n FROM dim_metric WHERE support IS NULL")$n
message(sprintf(paste("\n%d dim_metric rows still have no support label (not all metrics",
                      "are support-bearing; label them as they become relevant)."),
                n_unlabelled))
message("\nC10 applied. Post-build mutation: re-run after any full DB rebuild.")
