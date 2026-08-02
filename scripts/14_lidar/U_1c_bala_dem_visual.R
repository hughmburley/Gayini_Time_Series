# Task U · §1c — visual inspection of the 2009 DEM at the four Bala reference paddocks.
#
# Design-seat Gate U2 response §1c. TIMEBOXED, PROSE-ONLY, NOT AN ANALYSIS.
#   no roughness metric · no derived surface · no numbers · nothing registered
#
# The question: does Bala 29ca carry engineered linear features - banks, levees,
# channels - on or near its boundary that its three neighbours do not? Banks are
# linear, sharp-edged and unmistakable at 50 cm. If it shows something, it comes back
# to the design seat as a candidate for a properly specified test. If it shows
# nothing, that is one line.
#
# Output goes to the SCRATCHPAD, not to Output/. Nothing here is a deliverable.

suppressPackageStartupMessages({library(terra); library(sf)})

DEM   <- "Output/rasters/task_U/taskU_bb0_dem_2009_8058_50cm.tif"
ZONES <- "Output/spatial_8058/management_zones_epsg8058.gpkg"
REF   <- c("Bala 26ca", "Bala 27ca", "Bala 28ca", "Bala 29ca")
SCRATCH <- file.path(Sys.getenv("TEMP"), "claude", "taskU_1c")
dir.create(SCRATCH, recursive = TRUE, showWarnings = FALSE)

z <- sf::st_read(ZONES, quiet = TRUE)
nm <- names(z)[grepl("^ManagmentZ$|zone_name|management_zone", names(z), ignore.case = TRUE)][1]
if (is.na(nm)) { print(names(z)); stop("cannot find the zone-name column") }
z$.__name <- as.character(z[[nm]])
ref <- z[z$.__name %in% REF, ]
if (nrow(ref) != 4) { print(sort(unique(z$.__name))); stop("expected 4 reference zones, got ", nrow(ref)) }
cat("reference zones found:", paste(sort(ref$.__name), collapse = ", "), "\n")

bb <- sf::st_bbox(ref)
pad <- 600                                   # metres of surrounding context
ext <- terra::ext(bb["xmin"] - pad, bb["xmax"] + pad, bb["ymin"] - pad, bb["ymax"] + pad)

r <- terra::rast(DEM)
cat("DEM:", terra::ncol(r), "x", terra::nrow(r), "@", terra::res(r)[1], "m\n")
cr <- terra::crop(r, ext)
# ~2 m for rendering - banks are metres wide, so 2 m still resolves them, and the
# full 50 cm crop would be ~1.5 Gpx.
fact <- max(1, round(2 / terra::res(r)[1]))
cr <- terra::aggregate(cr, fact = fact, fun = "mean", na.rm = TRUE)
cat("rendered at", terra::res(cr)[1], "m,", terra::ncol(cr), "x", terra::nrow(cr), "\n")

slope  <- terra::terrain(cr, "slope",  unit = "radians")
aspect <- terra::terrain(cr, "aspect", unit = "radians")
hs     <- terra::shade(slope, aspect, angle = 25, direction = 315)

zv <- terra::vect(sf::st_geometry(ref))

png(file.path(SCRATCH, "bala_2009_dem_hillshade.png"), width = 2000, height = 1500,
    res = 130)
par(mar = c(2, 2, 3, 4))
terra::plot(hs, col = grey(0:100 / 100), legend = FALSE,
            main = "2009 DEM (bb0, 50 cm -> 2 m) - hillshade, four Bala reference paddocks")
terra::plot(cr, col = terrain.colors(60, alpha = 0.42), add = TRUE)
terra::plot(zv, add = TRUE, border = "red", lwd = 2.2)
cent <- terra::centroids(zv)
text(terra::crds(cent), labels = ref$.__name, col = "red", font = 2, cex = 1.0)
dev.off()

# Second view: elevation stretched hard, which is what makes low banks legible.
qs <- terra::global(cr, fun = function(v) quantile(v, c(0.02, 0.98), na.rm = TRUE))
lo <- as.numeric(qs[1, 1]); hi <- as.numeric(qs[1, 2])
png(file.path(SCRATCH, "bala_2009_dem_stretch.png"), width = 2000, height = 1500,
    res = 130)
par(mar = c(2, 2, 3, 4))
terra::plot(terra::clamp(cr, lo, hi, values = TRUE),
            col = hcl.colors(80, "Terrain2"),
            main = sprintf("2009 DEM elevation, stretched %.2f-%.2f m AHD-like", lo, hi))
terra::plot(zv, add = TRUE, border = "red", lwd = 2.2)
text(terra::crds(cent), labels = ref$.__name, col = "black", font = 2, cex = 1.0)
dev.off()

cat("written:\n  ", file.path(SCRATCH, "bala_2009_dem_hillshade.png"),
    "\n  ", file.path(SCRATCH, "bala_2009_dem_stretch.png"), "\n")
