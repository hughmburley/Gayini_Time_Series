#!/usr/bin/env Rscript
# T1 Gate C - assign every census pixel to a management zone by point-in-polygon.
# Adapts scripts/03_inundation_products/10_build_veg_regime_checkerboard.R:198-200
# (sf::st_intersects(point_centroids, management), first match) from 66 plot
# centroids to the 1.08M census pixels. Both inputs EPSG:8058 - NO reprojection.
# Reads points from a duckdb-exported CSV (R here has no arrow); writes the
# assignment (pixel_id, zone_fid) to CSV for the Python sidecar/aggregate step.

suppressPackageStartupMessages({library(sf); library(DBI); library(RSQLite)})
root <- normalizePath(".", winslash = "/")
gpkg <- file.path(root, "Output/spatial_8058/management_zones_epsg8058.gpkg")
pts_csv <- file.path(root, "Output/census/_tmp/points.csv")
out_csv <- file.path(root, "Output/census/_tmp/assignment.csv")

t0 <- Sys.time()
management <- sf::st_read(gpkg, quiet = TRUE)
if (sf::st_crs(management)$epsg != 8058L) stop("zone layer is not EPSG:8058 - STOP")
gc_ <- DBI::dbConnect(RSQLite::SQLite(), gpkg, flags = RSQLite::SQLITE_RO)
fidmap <- DBI::dbGetQuery(gc_, "SELECT fid, ManagmentZ FROM management_zones_epsg8058")
DBI::dbDisconnect(gc_)
management$fid <- as.integer(fidmap$fid[match(as.character(management$ManagmentZ), fidmap$ManagmentZ)])

pts <- utils::read.csv(pts_csv, colClasses = c("integer", "numeric", "numeric"))
message(sprintf("read %d points", nrow(pts)))

psf <- sf::st_as_sf(pts, coords = c("x_8058", "y_8058"), crs = 8058, remove = FALSE)
# reused pattern: st_intersects(points, management), first containing zone
hits <- sf::st_intersects(psf, management)
zone_row <- vapply(hits, function(z) if (length(z)) z[[1]] else NA_integer_, integer(1))
zone_fid <- management$fid[zone_row]     # NA -> unzoned

assignment <- data.frame(pixel_id = pts$pixel_id, zone_fid = zone_fid)
n_unzoned <- sum(is.na(zone_fid))
message(sprintf("zoned=%d  unzoned(zone_fid=NA)=%d  total=%d  (%.1fs)",
                sum(!is.na(zone_fid)), n_unzoned, nrow(assignment),
                as.numeric(difftime(Sys.time(), t0, units = "secs"))))
stopifnot(nrow(assignment) == nrow(pts))
utils::write.csv(assignment, out_csv, row.names = FALSE, na = "")
message("wrote ", out_csv)
