# ------------------------------------------------------------------------------
# Script: scripts/07_figures_dashboards/taskM_gateD_M1_percentile_maps.R
# Purpose: Tier 2 · Task M · Gate D §D.1 — the two-panel veg-percentile map
#          (p05 the floor, p50 the typical), one shared 0-100 cover scale.
#
#   NO p50 - p05 difference panel (spec §11). Percentiles are plotted as
#   measured and are never differenced.
#
# Run mode: figure build (read-only inputs) · writes ONE new PNG
# Source rasters resolved from raster_asset (not hardcoded).
# Output: Output/figures/M1_veg_percentile_maps_p05_p50.png
# ------------------------------------------------------------------------------

root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", getwd()), winslash = "/", mustWork = TRUE)
source(file.path(root_dir, "R", "gayini_output_helpers.R"))
suppressPackageStartupMessages({ library(terra); library(sf); library(DBI); library(RSQLite) })
terra::terraOptions(progress = 0)

DB       <- file.path(root_dir, "Output", "database", "Gayini_Results.sqlite")
SPATIAL  <- file.path(root_dir, "Output", "spatial_8058")
OUT_PNG  <- file.path(root_dir, "Output", "figures", "M1_veg_percentile_maps_p05_p50.png")

# Design system tokens (docs/Gayini_presentation_design_system.md)
CREAM    <- "#F8F7F2"
PETROL   <- "#0F3947"
INK      <- "#26302E"
MUTED    <- "#8A8378"
# Sequential single-family cover ramp (YlGn-like) — NOT the community categorical palette.
RAMP     <- colorRampPalette(c("#FFFFE5", "#F7FCB9", "#D9F0A3", "#ADDD8E",
                               "#78C679", "#41AB5D", "#238443", "#005A32"))(256)
NA_COL   <- "#E7E4DA"   # data-absent inside frame

## --- resolve source paths from raster_asset (spec: do not hardcode) ---
con <- DBI::dbConnect(RSQLite::SQLite(), DB)
q <- "SELECT raster_asset_id, path FROM raster_asset WHERE raster_asset_id IN
        ('raster_vegpct_p05','raster_vegpct_p50')"
paths <- DBI::dbGetQuery(con, q); DBI::dbDisconnect(con)
get_path <- function(id) file.path(root_dir, paths$path[paths$raster_asset_id == id])
p05_tif <- get_path("raster_vegpct_p05"); p50_tif <- get_path("raster_vegpct_p50")
stopifnot(file.exists(p05_tif), file.exists(p50_tif))

boundary <- sf::st_read(file.path(SPATIAL, "gayini_boundary_epsg8058.gpkg"), quiet = TRUE)
zones    <- sf::st_read(file.path(SPATIAL, "management_zones_epsg8058.gpkg"), quiet = TRUE)
bv <- terra::vect(boundary); zv <- terra::vect(zones)

## Crop + mask both to the property boundary (frame as in H6_flood_zone_data.png).
prep <- function(tif) {
  r <- terra::rast(tif)
  terra::mask(terra::crop(r, bv), bv)
}
p05 <- prep(p05_tif); p50 <- prep(p50_tif)
message("[M1] p05 range ", paste(round(terra::minmax(p05)[, 1], 2), collapse = "-"),
        " · p50 range ", paste(round(terra::minmax(p50)[, 1], 2), collapse = "-"))

## --- draw ---
ragg::agg_png(OUT_PNG, width = 2400, height = 1350, units = "px", res = 200, background = CREAM)
on.exit(grDevices::dev.off(), add = TRUE)

layout(matrix(c(1, 2, 3, 3), nrow = 2, byrow = TRUE), heights = c(1, 0.20))
par(bg = CREAM, oma = c(2.4, 0, 3.4, 0))

draw_panel <- function(r, title) {
  par(mar = c(0.5, 0.5, 2.2, 0.5), bg = CREAM)
  terra::plot(r, col = RAMP, range = c(0, 100), colNA = NA,
              legend = FALSE, axes = FALSE, mar = NA, main = "")
  terra::polys(bv, border = PETROL, lwd = 2.4)
  terra::polys(zv, border = "#FFFFFF", lwd = 0.9)
  terra::polys(bv, border = PETROL, lwd = 2.4)
  title(main = title, col.main = PETROL, font.main = 2, cex.main = 1.25, line = 0.6)
}

draw_panel(p05, "5th-percentile total cover (the floor)")
draw_panel(p50, "50th-percentile total cover (typical)")

## Shared horizontal legend, fixed 0-100, one for both panels.
par(mar = c(2.6, 6, 1.0, 6), bg = CREAM)
plot.new(); plot.window(xlim = c(0, 100), ylim = c(0, 1))
xs <- seq(0, 100, length.out = length(RAMP) + 1)
rect(xs[-length(xs)], 0.45, xs[-1], 1.0, col = RAMP, border = NA)
rect(0, 0.45, 100, 1.0, border = PETROL, lwd = 1.2)
ticks <- seq(0, 100, 20)
segments(ticks, 0.45, ticks, 0.34, col = PETROL)
text(ticks, 0.10, labels = ticks, col = INK, cex = 0.95)
text(50, 1.9, "Total vegetation cover (%) — one shared scale, fixed 0–100",
     col = INK, cex = 1.0, xpd = NA, font = 2)

## Overall title, subtitle, footer in the outer margin.
mtext("Where the vegetation floor sits, and where it typically sits",
      side = 3, outer = TRUE, line = 1.3, col = PETROL, font = 2, cex = 1.5)
mtext(paste0("All-pixel census, EPSG:8058, 24.97 m. Across-series percentiles, ",
             "1988–2023, one value per pixel."),
      side = 3, outer = TRUE, line = -0.2, col = MUTED, cex = 0.95)
mtext(paste0("Landsat fractional cover measures COVER, not ecological condition. ",
             "Percentiles are plotted as measured and are never differenced."),
      side = 1, outer = TRUE, line = -0.4, col = MUTED, cex = 0.9)

message("[M1] wrote ", OUT_PNG)
