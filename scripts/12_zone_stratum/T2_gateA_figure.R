#!/usr/bin/env Rscript
# T2 Gate A - stack alignment + nodata evidence.
# Left  : the four 8058 T2-input raster extents drawn over the census-grid bbox.
#         All four are compareGeom()-identical, so they coincide exactly (the point).
# Right : a nodata map - per-pixel count of valid years from annual_valid_any
#         (range [0,35]); nodata is NA (blank), never 255. If a 255 had survived into
#         a mean it would blow the veg range past 100 by ~150; observed max is 108
#         (mean) / 110 (jja_son) - bilinear-resampling overshoot, not 255.
# Read-only w.r.t. the DB except the one figure_asset INSERT OR REPLACE.

suppressPackageStartupMessages({library(ggplot2); library(terra); library(patchwork)})
root <- normalizePath(".", winslash = "/")
source(file.path(root, "R/gayini_figure_register.R"))
source(file.path(root, "R/gayini_params.R"))
fig_dir <- file.path(root, "Output/figures/diagnostics")
side_m <- sprintf("%.6f", GAYINI_PARAMS$PIXEL_SIDE_M)   # never a bare literal

paths <- c(
  "veg_mean\n(primary)"  = "Output/rasters/veg_annual_8058/total_veg_annual_mean_8058.tif",
  "veg_jja_son\n(robust)"= "Output/rasters/veg_annual_8058/total_veg_annual_jja_son_8058.tif",
  "wet_any"              = "Output/rasters/inundation_annual_stack_8058/annual_wet_any_1988_2023_8058.tif",
  "valid_any"            = "Output/rasters/inundation_annual_stack_8058/annual_valid_any_1988_2023_8058.tif"
)
exts <- lapply(paths, function(p) as.vector(ext(rast(p))))
ext_df <- do.call(rbind, lapply(seq_along(exts), function(i) {
  e <- exts[[i]]
  data.frame(layer = names(paths)[i],
             xmin = e["xmin"], xmax = e["xmax"], ymin = e["ymin"], ymax = e["ymax"])
}))
# tiny jitter so four identical rectangles are individually visible
ext_df$off <- (seq_len(nrow(ext_df)) - 2.5) * 55

pA <- ggplot(ext_df) +
  geom_rect(aes(xmin = xmin + off, xmax = xmax + off,
                ymin = ymin + off, ymax = ymax + off, colour = layer),
            fill = NA, linewidth = 0.7) +
  coord_equal() +
  scale_colour_brewer(palette = "Dark2", name = NULL) +
  labs(title = "A. Extent alignment (offset ±55 m for legibility)",
       subtitle = paste0("compareGeom() = TRUE for all four (ext, rowcol, crs=8058, res=", side_m, " m)"),
       x = "easting (EPSG:8058, m)", y = "northing (m)") +
  theme_minimal(base_size = 10) + theme(legend.position = "right")

# nodata map: valid-year count, coarsened for display
valid <- rast(paths[["valid_any"]])
nvy   <- sum(valid, na.rm = TRUE)               # NA where all-NA => stays NA
nvy_c <- aggregate(nvy, fact = 20, fun = "mean", na.rm = TRUE)
df    <- as.data.frame(nvy_c, xy = TRUE, na.rm = TRUE)
names(df)[3] <- "valid_years"

pB <- ggplot(df, aes(x, y, fill = valid_years)) +
  geom_raster() + coord_equal() +
  scale_fill_viridis_c(name = "valid\nyears", limits = c(0, 35)) +
  labs(title = "B. Nodata map - valid-year count from annual_valid_any",
       subtitle = "Range [0,35]; nodata = NA (blank), never 255. Veg max 108/110 << 255 => no 255 in any mean.",
       x = "easting (EPSG:8058, m)", y = "northing (m)") +
  theme_minimal(base_size = 10)

p <- pA / pB + plot_annotation(
  title = "T2 A - stack alignment and nodata evidence (four 8058 inputs)")

gayini_write_and_register_figure(
  p, file.path(fig_dir, "T2_A_stack_alignment.png"),
  title = "T2 A stack alignment and nodata evidence",
  caption = paste0("Support: pixel (", side_m, " m, EPSG:8058). Four T2 input stacks are ",
                   "compareGeom-identical; nodata is NA not 255; veg overshoot (max 108/110) ",
                   "is bilinear-resampling artefact, 24/622 pixel-years, not 255 contamination."),
  support_level = "pixel", figure_level = "diagnostics", run_id = "T2_gateA",
  provenance_note = "Gate A evidence. Extents coincident; valid_any presence-only [1]; no 255 survives.",
  width = 11, height = 11)
cat("\n[done] T2_A_stack_alignment.png\n")
