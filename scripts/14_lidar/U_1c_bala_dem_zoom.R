# Task U · §1c (continued) — zoom on Bala 29ca against a comparison paddock.
# TIMEBOXED, PROSE-ONLY, NOT AN ANALYSIS. Scratchpad output; nothing registered.
#
# The wide view showed a property-wide rectilinear grid of linear features. The
# question this zoom answers: is 29ca distinctively ENCLOSED - ringed by banks that
# would isolate it hydrologically - or is it inside the same grid as everywhere else?

suppressPackageStartupMessages({library(terra); library(sf)})

DEM   <- "Output/rasters/task_U/taskU_bb0_dem_2009_8058_50cm.tif"
ZONES <- "Output/spatial_8058/management_zones_epsg8058.gpkg"
SCRATCH <- file.path(Sys.getenv("TEMP"), "claude", "taskU_1c")
dir.create(SCRATCH, recursive = TRUE, showWarnings = FALSE)

z  <- sf::st_read(ZONES, quiet = TRUE)
nm <- names(z)[grepl("^ManagmentZ$", names(z))][1]
z$.__name <- as.character(z[[nm]])
r  <- terra::rast(DEM)

for (target in c("Bala 29ca", "Bala 28ca")) {
  g   <- z[z$.__name == target, ]
  bb  <- sf::st_bbox(g); pad <- 300
  ext <- terra::ext(bb["xmin"] - pad, bb["xmax"] + pad, bb["ymin"] - pad, bb["ymax"] + pad)
  cr  <- terra::crop(r, ext)
  fact <- max(1, round(1 / terra::res(r)[1]))          # ~1 m
  if (fact > 1) cr <- terra::aggregate(cr, fact = fact, fun = "mean", na.rm = TRUE)

  # Local de-trend so the REGIONAL slope stops dominating and metre-scale banks
  # become legible. Display only - no number is taken from it.
  # A w=151 focal MEDIAN was tried first and blew the �1c timebox (50 min CPU on one
  # paddock). A boxcar MEAN via aggregate/disagg is visually equivalent here and runs
  # in seconds; the timebox is a real constraint and this is how it was met.
  coarse <- terra::aggregate(cr, fact = 75, fun = "mean", na.rm = TRUE)
  bg  <- terra::resample(coarse, cr, method = "bilinear")
  det <- cr - bg

  slope  <- terra::terrain(cr, "slope",  unit = "radians")
  aspect <- terra::terrain(cr, "aspect", unit = "radians")
  hs     <- terra::shade(slope, aspect, angle = 20, direction = 315)

  zv <- terra::vect(sf::st_geometry(g))
  nb <- z[sf::st_intersects(z, sf::st_as_sfc(sf::st_bbox(ext, crs = sf::st_crs(z))),
                            sparse = FALSE)[, 1], ]

  slug <- gsub("[^A-Za-z0-9]+", "_", tolower(target))
  png(file.path(SCRATCH, sprintf("zoom_%s.png", slug)), width = 1900, height = 1500,
      res = 130)
  par(mfrow = c(1, 2), mar = c(2, 2, 3, 1))
  terra::plot(hs, col = grey(0:100 / 100), legend = FALSE,
              main = sprintf("%s - hillshade (2009 bb0, 1 m)", target))
  terra::plot(terra::vect(sf::st_geometry(nb)), add = TRUE, border = "grey40", lwd = 0.8)
  terra::plot(zv, add = TRUE, border = "red", lwd = 2.4)
  terra::plot(terra::clamp(det, -0.45, 0.45, values = TRUE),
              col = hcl.colors(60, "Blue-Red 3"),
              main = sprintf("%s - local relief, +/- 0.45 m (display only)", target))
  terra::plot(terra::vect(sf::st_geometry(nb)), add = TRUE, border = "grey30", lwd = 0.8)
  terra::plot(zv, add = TRUE, border = "black", lwd = 2.4)
  dev.off()
  cat("written:", file.path(SCRATCH, sprintf("zoom_%s.png", slug)), "\n")
}
