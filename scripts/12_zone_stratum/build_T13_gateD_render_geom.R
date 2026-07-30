# T13 Gate D (step 1b) — a RENDER-ONLY simplified copy of the part polygons.
#
# WHY: the exact polygons are dissolved from ~795,602 pixel squares, so their perimeters are
# pixel staircases carrying enormous vertex counts and many single-pixel holes. At any visible
# outline width they render as solid blobs rather than outlined areas - the first Gate D draft
# was unreadable for exactly this reason. They are also far too slow to intersect for hatching.
#
# THIS FILE IS FOR DRAWING ONLY. The analysis unit remains
# Output/spatial_8058/T13_part_polygons_epsg8058.gpkg, which is exact and untouched. Nothing
# is measured off the simplified copy - no area, no count, no number of any kind. The figure
# captions say the boundaries are generalised for display.
suppressPackageStartupMessages({library(sf); library(dplyr)})
source("R/gayini_params.R")

EXACT  <- "Output/spatial_8058/T13_part_polygons_epsg8058.gpkg"
RENDER <- "Output/spatial_8058/T13_part_polygons_render_only_epsg8058.gpkg"
side   <- GAYINI_PARAMS$PIXEL_SIDE_M

p <- sf::st_read(EXACT, quiet = TRUE)
stopifnot(sf::st_crs(p)$epsg == GAYINI_PARAMS$CRS_CANONICAL)

nv <- function(x) sum(sapply(sf::st_geometry(x), function(g) nrow(sf::st_coordinates(g))))
v0 <- nv(p)
cat(sprintf("exact polygons: %d parts, %s vertices\n", nrow(p), format(v0, big.mark = ",")))

t0 <- Sys.time()
# morphological close at one pixel: fills single-pixel holes and the staircase notches
g <- sf::st_buffer(sf::st_geometry(p), side * 0.5)
g <- sf::st_buffer(g, -side * 0.5)
cat(sprintf("  close done (%.0fs)\n", as.numeric(difftime(Sys.time(), t0, units = "secs"))))
g <- sf::st_simplify(g, dTolerance = side * 0.6, preserveTopology = TRUE)
cat(sprintf("  simplify done (%.0fs)\n", as.numeric(difftime(Sys.time(), t0, units = "secs"))))
g <- sf::st_make_valid(g)

r <- sf::st_sf(zone_fid = p$zone_fid, community = p$community,
               n_pixels = p$n_pixels, area_ha = p$area_ha, geometry = g)
r <- r[!sf::st_is_empty(r), ]

v1 <- nv(r)
cat(sprintf("render copy: %d parts, %s vertices (%.1f%% of exact)\n",
            nrow(r), format(v1, big.mark = ","), 100 * v1 / v0))

# --- checks: this is a DISPLAY object, so the check is that it is recognisably the same shape,
# --- not that it is identical. Area drift is reported, never used.
ae <- as.numeric(sf::st_area(p)) / 10000
ar <- as.numeric(sf::st_area(r)) / 10000
m  <- match(paste(r$zone_fid, r$community), paste(p$zone_fid, p$community))
rel <- abs(ar - ae[m]) / ae[m]
cat(sprintf("area drift from generalisation: median %.2f%%  max %.2f%%  (REPORTED, never used)\n",
            100 * median(rel), 100 * max(rel)))
for (i in order(-rel)[1:5])
  cat(sprintf("   worst: zone %3d  %-26s %7.1f ha exact  drift %5.2f%%\n",
              r$zone_fid[i], substr(r$community[i], 1, 24), ae[m][i], 100 * rel[i]))
stopifnot(nrow(r) == nrow(p))
# A display object may generalise, but not so far that it misrepresents a part's extent.
# At side*2 tolerance one part drifted 50% - that is a misleading map, not a simplified one.
stopifnot(max(rel) < 0.15)

sf::st_write(r, RENDER, layer = "T13_part_polygons_render_only", delete_dsn = TRUE, quiet = TRUE)
cat(sprintf("wrote %s\n", RENDER))
cat("RENDER ONLY - never an analysis input. No DB write.\n")
