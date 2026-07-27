#!/usr/bin/env Rscript
# plot_paddock - join the 66 monitoring plots (anchors) to the T1 management zones
# (paddocks), so the plot-support world connects to the zone x stratum substrate.
# Plot centroids are EPSG:9473 (dim_plot.centroid_x/y) - reproject to 8058 before the
# containment join, same zone layer T1 used (management_zones_epsg8058, fid + ManagmentZ).
# No design decision: point-in-polygon containment, mirroring T1's pixel->zone assignment.
# Additive: new table plot_paddock + view v_plot_paddock; CREATE IF NOT EXISTS + upsert.

suppressPackageStartupMessages({library(sf); library(DBI); library(RSQLite)})
sf::sf_use_s2(FALSE)
root <- normalizePath(".", winslash = "/")
source(file.path(root, "R/gayini_params.R"))
DB <- file.path(root, "Output/database/Gayini_Results.sqlite")
GPKG <- file.path(root, "Output/spatial_8058/management_zones_epsg8058.gpkg")

con <- DBI::dbConnect(RSQLite::SQLite(), DB)
plots <- DBI::dbGetQuery(con,
  "SELECT plot_id, centroid_x, centroid_y, simplified_vegetation_group,
          plot_attr_treatment FROM dim_plot")
zdim <- DBI::dbGetQuery(con,
  "SELECT zone_fid, zone_name, grazing_treatment, grazing_excluded FROM dim_management_zone")

pts <- sf::st_as_sf(plots, coords = c("centroid_x", "centroid_y"),
                    crs = GAYINI_PARAMS$CRS_PLOT_CENTROID, remove = FALSE)
pts8058 <- sf::st_transform(pts, GAYINI_PARAMS$CRS_CANONICAL)

zones <- sf::st_read(GPKG, quiet = TRUE)
if (sf::st_crs(zones)$epsg != GAYINI_PARAMS$CRS_CANONICAL)
  stop("zone layer is not EPSG:8058 - STOP")

hit <- sf::st_within(pts8058, zones)                 # containment, T1-consistent
zone_row <- vapply(hit, function(x) if (length(x)) x[1] else NA_integer_, integer(1))
# the gpkg has no `fid` attribute column; match by zone name (ManagmentZ) to
# dim_management_zone, which yields T1's zone_fid consistently.
zone_name_hit <- zones$ManagmentZ[zone_row]          # NA where centroid outside all zones

out <- data.frame(
  plot_id = plots$plot_id,
  zone_name = zone_name_hit,
  in_zone = as.integer(!is.na(zone_name_hit)),
  plot_treatment = plots$plot_attr_treatment,
  simplified_vegetation_group = plots$simplified_vegetation_group,
  stringsAsFactors = FALSE)
out <- merge(out, zdim, by = "zone_name", all.x = TRUE)
out$support_level <- "plot"
out$aggregation_unit <- "plot"
# treatment agreement: plot's own treatment vs the zone's (a data flag, not a fix)
out$treatment_match <- as.integer(!is.na(out$grazing_treatment) &
                                  out$plot_treatment == out$grazing_treatment)
out <- out[order(out$plot_id),
           c("plot_id","zone_fid","zone_name","grazing_treatment","grazing_excluded",
             "in_zone","plot_treatment","treatment_match","simplified_vegetation_group",
             "support_level","aggregation_unit")]

DBI::dbExecute(con, "CREATE TABLE IF NOT EXISTS plot_paddock (
  plot_id TEXT PRIMARY KEY, zone_fid INTEGER, zone_name TEXT, grazing_treatment TEXT,
  grazing_excluded INTEGER, in_zone INTEGER, plot_treatment TEXT, treatment_match INTEGER,
  simplified_vegetation_group TEXT, support_level TEXT, aggregation_unit TEXT)")
for (i in seq_len(nrow(out))) {
  r <- out[i, ]
  DBI::dbExecute(con,
    "INSERT OR REPLACE INTO plot_paddock
       (plot_id, zone_fid, zone_name, grazing_treatment, grazing_excluded, in_zone,
        plot_treatment, treatment_match, simplified_vegetation_group, support_level,
        aggregation_unit) VALUES (?,?,?,?,?,?,?,?,?,?,?)",
    params = list(r$plot_id, r$zone_fid, r$zone_name, r$grazing_treatment,
                  r$grazing_excluded, r$in_zone, r$plot_treatment, r$treatment_match,
                  r$simplified_vegetation_group, r$support_level, r$aggregation_unit))
}
DBI::dbExecute(con, "DROP VIEW IF EXISTS v_plot_paddock")
DBI::dbExecute(con, "CREATE VIEW v_plot_paddock AS SELECT * FROM plot_paddock")
DBI::dbDisconnect(con)

cat(sprintf("plots joined: %d | in a zone: %d | unzoned: %d\n",
            nrow(out), sum(out$in_zone), sum(out$in_zone == 0)))
cat(sprintf("plots in a No-grazing (reference) paddock: %d\n",
            sum(out$grazing_excluded == 1, na.rm = TRUE)))
cat(sprintf("treatment mismatches (plot vs zone, data flag): %d\n",
            sum(out$in_zone == 1 & out$treatment_match == 0, na.rm = TRUE)))
if (any(out$in_zone == 0)) cat("unzoned plots:", paste(out$plot_id[out$in_zone==0], collapse=", "), "\n")
cat("DONE\n")
