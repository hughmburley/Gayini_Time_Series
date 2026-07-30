# T13 Gate D (step 1) — build paddock-PART polygons.
#
# A "part" is (zone_fid x community). No such layer exists: spatial_006 holds the 64 paddock
# polygons and spatial_009 holds 5 community polygons. Intersecting those two would produce a
# DIFFERENT partition from the one every T13 number was computed on, because the analysis
# communities come from the CENSUS PIXEL assignment (veg_regime_class_8058), not from the
# vegetation shapefile. That is the wrong-layer family of error this project has hit before.
#
# So the polygons are DISSOLVED FROM THE CENSUS PIXELS THEMSELVES - the same 795,602 in-scope
# zoned centroids in Output/tables/T2_in_scope_points.csv that Gate A extracted flood from and
# Gate B computed the measures on. Each centroid becomes its pixel square (PIXEL_SIDE_M from
# gayini_params, never a literal), then squares are unioned per part. The polygon is therefore
# the analysis unit by construction, not an approximation of it.
#
# Writes Output/spatial_8058/T13_part_polygons_epsg8058.gpkg. No DB write here.
suppressPackageStartupMessages({library(sf); library(dplyr)})
source("R/gayini_params.R")

ROOT <- normalizePath(".", winslash = "/")
PTS  <- file.path(ROOT, "Output/tables/T2_in_scope_points.csv")
OUTD <- file.path(ROOT, "Output/spatial_8058")
OUTG <- file.path(OUTD, "T13_part_polygons_epsg8058.gpkg")
dir.create(OUTD, recursive = TRUE, showWarnings = FALSE)

side <- GAYINI_PARAMS$PIXEL_SIDE_M  # from gayini_params - NOT typed
half <- side / 2
cat(sprintf("pixel side %.6f m (half %.6f) from gayini_params\n", side, half))

p <- read.csv(PTS, stringsAsFactors = FALSE)
cat(sprintf("in-scope centroids: %s\n", format(nrow(p), big.mark = ",")))
stopifnot(all(c("x_8058", "y_8058", "zone_fid", "community") %in% names(p)))

# --- one square polygon per pixel, dissolved per part -------------------------------------
# Built as a single sfc of boxes then unioned by group. st_union on ~800k boxes is too slow,
# so squares are snapped to the grid and merged as a raster-style polygonisation: adjacent
# equal-valued cells dissolve because their shared edges cancel under st_union of a buffer-0
# grouping. Practical route: group -> st_as_sfc of boxes -> st_union per group.
mk_part <- function(df) {
  bx <- lapply(seq_len(nrow(df)), function(i)
    sf::st_polygon(list(matrix(c(
      df$x_8058[i]-half, df$y_8058[i]-half,
      df$x_8058[i]+half, df$y_8058[i]-half,
      df$x_8058[i]+half, df$y_8058[i]+half,
      df$x_8058[i]-half, df$y_8058[i]+half,
      df$x_8058[i]-half, df$y_8058[i]-half), ncol = 2, byrow = TRUE))))
  sf::st_union(sf::st_sfc(bx, crs = 8058))
}

keys <- p |> distinct(zone_fid, community) |> arrange(zone_fid, community)
cat(sprintf("parts to build: %d\n", nrow(keys)))

geoms <- vector("list", nrow(keys)); npx <- integer(nrow(keys))
t0 <- Sys.time()
for (i in seq_len(nrow(keys))) {
  d <- p[p$zone_fid == keys$zone_fid[i] & p$community == keys$community[i], ]
  npx[i]   <- nrow(d)
  geoms[[i]] <- mk_part(d)
  if (i %% 20 == 0) cat(sprintf("  %3d/%d  (%.0fs)\n", i, nrow(keys),
                                as.numeric(difftime(Sys.time(), t0, units = "secs"))))
}

parts <- sf::st_sf(
  zone_fid  = keys$zone_fid,
  community = keys$community,
  n_pixels  = npx,
  area_ha   = npx * GAYINI_PARAMS$PIXEL_AREA_HA,  # DERIVED constant, never typed
  geometry  = do.call(c, geoms)
)
parts <- sf::st_make_valid(parts)

# --- checks that can fail ------------------------------------------------------------------
cat("\n=== CHECKS ===\n")
cat(sprintf("parts built: %d (expect 118 zone x community combinations)\n", nrow(parts)))
stopifnot(nrow(parts) == 118L)
stopifnot(sf::st_crs(parts)$epsg == GAYINI_PARAMS$CRS_CANONICAL)
cat(sprintf("total pixels in polygons: %s (expect 795,602)\n", format(sum(parts$n_pixels), big.mark = ",")))
stopifnot(sum(parts$n_pixels) == nrow(p))

# geometric area must reconcile with pixel-count area: dissolving squares cannot change area
ga <- as.numeric(sf::st_area(parts)) / 10000
rel <- max(abs(ga - parts$area_ha) / parts$area_ha)
cat(sprintf("max relative |geometric area - pixel-count area|: %.3e (tolerance 1e-6)\n", rel))
stopifnot(rel < 1e-6)

# parts within a paddock must not overlap - every pixel belongs to exactly one community
ov <- sf::st_overlaps(parts, parts, sparse = FALSE)
diag(ov) <- FALSE
cat(sprintf("overlapping part pairs: %d (expect 0)\n", sum(ov) / 2))
if (sum(ov) > 0) {
  w <- which(ov, arr.ind = TRUE)
  for (r in seq_len(min(5, nrow(w)))) cat(sprintf("   OVERLAP %s|%s vs %s|%s\n",
    parts$zone_fid[w[r,1]], substr(parts$community[w[r,1]],1,10),
    parts$zone_fid[w[r,2]], substr(parts$community[w[r,2]],1,10)))
}
stopifnot(sum(ov) == 0)

sf::st_write(parts, OUTG, layer = "T13_part_polygons", delete_dsn = TRUE, quiet = TRUE)
cat(sprintf("\nwrote %s (%d features, EPSG:8058)\n", OUTG, nrow(parts)))
cat("No DB write in this step; registration is Gate E.\n")
