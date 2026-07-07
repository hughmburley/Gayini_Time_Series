# ------------------------------------------------------------------------------
# Script: scripts/01_prepare_inputs/03_populate_raster_metadata.R
# Purpose: Tier 0 sub-step 0.2 -- resolve raster CRS / legend metadata debt.
#          (1) Read CRS + extent for every raster_asset with terra and write
#              crs_epsg + crs + xmin/ymin/xmax/ymax + resolution back to the DB.
#          (2) Classify the null-metric_id assets via gayini_infer_metric_id().
#          (3) Emit a legend-confirmation sheet for Adrian grouped by product
#              family, recording the assumed value semantics for each.
# Workflow stage: 01_prepare_inputs
# Run mode: light-moderate (reads raster headers only)
# Key inputs:
#   - Output/database/Gayini_Results.sqlite  (raster_asset)
#   - data_intermediate/raster_catalog/raster_catalog.csv (needs_legend_check)
# Key outputs:
#   - raster_asset: crs_epsg/crs/extent/resolution populated, metric_id filled
#   - Output/reports/legend_confirmation_for_adrian.md
# Notes:
#   - Post-build DB mutation. The Python builder unlinks + rebuilds the DB and
#     cannot read CRS (no GDAL/proj at build time), so this step must be re-run
#     after any full rebuild. See docs/tier0_annual_stack_task.md sub-step 0.2.
# ------------------------------------------------------------------------------

root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", "D:/Github_repos/Gayini"), winslash = "/", mustWork = TRUE)

suppressMessages({
  library(terra)
  library(dplyr)
  library(readr)
  library(DBI)
  library(RSQLite)
})

source(file.path(root_dir, "R", "raster_catalog_functions.R"))
source(file.path(root_dir, "R", "gayini_output_paths.R"))

TARGET_EPSG <- 28355L
DB_PATH     <- file.path(root_dir, "Output", "database", "Gayini_Results.sqlite")
CATALOG_CSV <- file.path(root_dir, "data_intermediate", "raster_catalog", "raster_catalog.csv")
LEGEND_MD   <- file.path(root_dir, "Output", "reports", "legend_confirmation_for_adrian.md")

dir.create(dirname(LEGEND_MD), recursive = TRUE, showWarnings = FALSE)

# Resolve an asset's CRS to an EPSG code. Untagged sources that carry a GDA94
# MGA zone-55 Transverse Mercator WKT resolve to 28355 (the project CRS); this
# mirrors the assign-not-reproject decision made in Tier 0.1.
resolve_epsg <- function(r) {
  code <- terra::crs(r, describe = TRUE)$code
  if (!is.na(code) && nzchar(code)) return(as.integer(code))
  wkt <- terra::crs(r)
  is_mga55 <- grepl("Transverse Mercator", wkt, fixed = TRUE) &&
    grepl('"Longitude of natural origin",147', wkt, fixed = TRUE) &&
    grepl('"False easting",500000', wkt, fixed = TRUE) &&
    grepl('"Scale factor at natural origin",0.9996', wkt, fixed = TRUE)
  if (is_mga55) return(TARGET_EPSG)
  NA_integer_
}

# ------------------------------------------------------------------------------
# 1. Populate CRS + extent + resolution for every raster_asset.
# ------------------------------------------------------------------------------
message("[0.2] Reading raster_asset ...")
con <- dbConnect(RSQLite::SQLite(), DB_PATH)

# Add crs_epsg column if the schema predates it.
cols <- dbGetQuery(con, "PRAGMA table_info(raster_asset)")$name
if (!"crs_epsg" %in% cols) {
  dbExecute(con, "ALTER TABLE raster_asset ADD COLUMN crs_epsg INTEGER")
  message("  added column raster_asset.crs_epsg")
}

ra <- dbReadTable(con, "raster_asset")
message(sprintf("  %d assets; %d null metric_id, %d null crs_epsg at start.",
                nrow(ra), sum(is.na(ra$metric_id)), sum(is.na(ra$crs_epsg))))

abspath <- ifelse(grepl("^[A-Za-z]:", ra$path), ra$path, file.path(root_dir, ra$path))
missing <- !file.exists(abspath)
if (any(missing)) {
  stop("raster_asset references files not on disk; cannot populate CRS for:\n  ",
       paste(ra$path[missing], collapse = "\n  "), call. = FALSE)
}

n_meta <- 0L
for (i in seq_len(nrow(ra))) {
  r    <- terra::rast(abspath[i])
  epsg <- resolve_epsg(r)
  if (is.na(epsg)) {
    warning("Could not resolve EPSG for ", ra$path[i], call. = FALSE)
    next
  }
  e   <- as.vector(terra::ext(r))
  res <- terra::res(r)
  dbExecute(con,
    "UPDATE raster_asset
        SET crs_epsg = ?, crs = ?, resolution_x = ?, resolution_y = ?,
            xmin = ?, ymin = ?, xmax = ?, ymax = ?
      WHERE raster_asset_id = ?",
    params = list(epsg, paste0("EPSG:", epsg), res[1], res[2],
                  e[1], e[3], e[2], e[4], ra$raster_asset_id[i]))
  n_meta <- n_meta + 1L
}
message(sprintf("  populated CRS/extent/resolution for %d assets.", n_meta))

# ------------------------------------------------------------------------------
# 2. Classify null-metric_id assets via the extended filename parser.
# ------------------------------------------------------------------------------
message("[0.2] Classifying null metric_id ...")
null_metric <- ra$raster_asset_id[is.na(ra$metric_id)]
n_class <- 0L; n_unresolved <- 0L
for (id in null_metric) {
  p  <- ra$path[ra$raster_asset_id == id]
  mid <- gayini_infer_metric_id(p)
  if (is.na(mid)) { n_unresolved <- n_unresolved + 1L; next }
  dbExecute(con, "UPDATE raster_asset SET metric_id = ? WHERE raster_asset_id = ?",
            params = list(mid, id))
  n_class <- n_class + 1L
}
message(sprintf("  classified %d assets; %d still unresolved.", n_class, n_unresolved))

ra2 <- dbReadTable(con, "raster_asset")
message(sprintf("  metric_id coverage now %.1f%% (%d/%d).",
                100 * mean(!is.na(ra2$metric_id)), sum(!is.na(ra2$metric_id)), nrow(ra2)))
dbDisconnect(con)

# ------------------------------------------------------------------------------
# 3. Legend confirmation sheet, grouped by flagged product family.
# ------------------------------------------------------------------------------
message("[0.2] Writing legend confirmation sheet ...")
catalog <- suppressWarnings(readr::read_csv(CATALOG_CSV, show_col_types = FALSE, progress = FALSE))
flagged <- catalog %>%
  dplyr::filter(.data$needs_legend_check %in% c(TRUE, "TRUE")) %>%
  dplyr::group_by(product) %>%
  dplyr::summarise(n_assets = dplyr::n(), .groups = "drop") %>%
  dplyr::arrange(dplyr::desc(n_assets))

# Assumed value semantics per family (confirmation, not fact -- all "assumed").
family_notes <- list(
  landsat_inundation = list(
    assumption = "Integer inundation count {0,1,2}; **count > 0 = wet** (values 1 and 2 both treated as wet), 0 = dry. No NA / no-data cells observed in the 35 canonical rasters. Semantics recorded as `annual_inundation_count`, `legend_status = unconfirmed`.",
    status     = "assumed",
    question   = "Is `count > 0 = wet` correct, or should only `== 1` count as wet? What does value **2** represent (e.g. higher-confidence or multiple within-year detections)? (This directly sets the Tier 0.1 wet rule.)"
  ),
  sentinel2_inundation = list(
    assumption = "Assumed to share the Landsat inundation count legend (count > 0 = wet). Not independently confirmed against the Sentinel-2 processing.",
    status     = "assumed",
    question   = "Do the Sentinel-2 inundation rasters use the same value legend and wet rule as Landsat, or a different scale / no-data code?"
  ),
  landsat_fractional_cover = list(
    assumption = "Assumed multi-band fractional cover: PV / NPV / bare-soil as percentages (0-100), with 255 as no-data. Band order not confirmed.",
    status     = "assumed",
    question   = "Confirm band order (PV/NPV/BS), the value scaling (0-100 vs 0-255) and the no-data code for the Landsat fractional-cover rasters."
  )
)

lines <- c(
  "# Raster legend confirmation for Adrian",
  "",
  paste0("_Generated by `scripts/01_prepare_inputs/03_populate_raster_metadata.R` (Tier 0 sub-step 0.2)._"),
  "",
  paste0("Of ", nrow(catalog), " catalogued raster assets, **",
         sum(catalog$needs_legend_check %in% c(TRUE, "TRUE")),
         "** are flagged `needs_legend_check`. They fall into the product families below.",
         " Each row states the **current working assumption** the analysis uses today and the",
         " specific question that needs your confirmation. All assumptions are currently",
         " **unconfirmed** -- confirming or correcting them stops the assumption propagating",
         " silently into interpretation."),
  "",
  "| Product family | Assets flagged | Current working assumption | Source | Question for Adrian |",
  "|---|---:|---|---|---|"
)
for (i in seq_len(nrow(flagged))) {
  fam <- flagged$product[i]
  note <- family_notes[[fam]]
  if (is.null(note)) {
    note <- list(assumption = "No documented assumption yet.", status = "assumed",
                 question = "Please confirm the value legend / no-data code for this product family.")
  }
  lines <- c(lines, sprintf("| `%s` | %d | %s | %s | %s |",
                            fam, flagged$n_assets[i],
                            gsub("\n", " ", note$assumption), note$status, note$question))
}
lines <- c(lines, "",
  "## Notes",
  "",
  paste0("- The Tier 0.1 unified annual stack builds on the **landsat_inundation** row above: ",
         "it treats `count > 0` as wet, so a change to that rule (e.g. excluding value 2) would ",
         "change every downstream wet/occurrence product. Flagged here rather than changed silently."),
  paste0("- CRS/extent metadata for all raster_asset rows was populated in this step ",
         "(all resolve to EPSG:", TARGET_EPSG, "; untagged Transverse-Mercator sources are ",
         "GDA94 / MGA zone 55 and were assigned the code rather than reprojected)."),
  ""
)
writeLines(lines, LEGEND_MD)
message("  wrote ", gayini_relative_path(root_dir, LEGEND_MD))
message("[0.2] Done.")
