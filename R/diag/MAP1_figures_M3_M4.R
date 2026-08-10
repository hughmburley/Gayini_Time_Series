# MAP-1 figures M3 and M4 - the two axes, on the ground.
#
# Spec: docs/reference_update/Gayini_CC_spec_MAP1.md sections 5 and 6.
# Run AFTER MAP1_figures.R, which builds M1 and M2 and defines the shared conventions.
#
# NO COMMUNITY COLOUR APPEARS ON EITHER OF THESE MAPS, so Ruling CQ's collision condition
# does not arise: a blue water ramp cannot be confused with Inland Floodplain's blue on a
# page where community is not encoded at all. Grey continues to mean "not analysed", as it
# does on M1 and M2, and the two ramps are deliberately different families so a reader
# moving between M3 and M4 cannot mistake one for the other.
#
# EXCLUDED UNITS KEEP M1's TREATMENT. Not analysed is not the same as zero, and a
# continuous ramp that swallowed the excluded areas at its low end would say it was.

suppressPackageStartupMessages({library(ggplot2); library(sf)})

root <- normalizePath(".", winslash = "/")
source(file.path(root, "R/gayini_figure_register.R"))

MAPS <- file.path(root, "Output", "maps")
parts <- sf::st_read(file.path(MAPS, "MAP1_paddock_community_areas_epsg8058.gpkg"),
                     quiet = TRUE)
tracts <- sf::st_read(file.path(root, "Output/unzoned/UNZONED_patches_epsg8058.gpkg"),
                      quiet = TRUE)
bnd <- sf::st_read(file.path(root, "Output/spatial_8058/gayini_boundary_epsg8058.gpkg"),
                   quiet = TRUE)
stopifnot(nrow(parts) == 156L, nrow(tracts) == 625L)

INK <- "#26302E"; BODY <- "#5F6B67"; MUTED <- "#8A8378"
GREY_NA <- "#7C837E"
# The low end of each ramp is TINTED, not near-white. A ramp that starts at white makes
# the driest country indistinguishable from the background, so "almost never wet" reads
# as "no data" - the opposite of what the grey class is there to say.
WATER_RAMP <- c("#D6E4EE", "#9CC2DA", "#3E7FB0", "#123F6B")
COVER_RAMP <- c("#F0E4CB", "#DDBE86", "#A87C3C", "#5C3D14")
UNIT_EDGE <- "#AEB6B0"   # every analysed unit gets an edge, so a pale fill still reads

analysed <- parts[!parts$inclusion_class %in% c("woodland", "other"), ]
notan <- parts[parts$inclusion_class %in% c("woodland", "other"), ]
stopifnot(nrow(analysed) == 118L, nrow(notan) == 38L)

sz_alpha <- function(n) ifelse(n >= 500, 1, 0.42)
analysed$a <- sz_alpha(analysed$n_cells)
tracts$a <- sz_alpha(tracts$n_cells)

bb <- sf::st_bbox(parts)
bar_m <- 10000
x0 <- bb[["xmax"]] - 0.24 * (bb[["xmax"]] - bb[["xmin"]])
y0 <- bb[["ymin"]] + 0.055 * (bb[["ymax"]] - bb[["ymin"]])
nx <- bb[["xmax"]] - 0.035 * (bb[["xmax"]] - bb[["xmin"]])
ny <- bb[["ymax"]] - 0.14 * (bb[["ymax"]] - bb[["ymin"]])
arrow_h <- 0.085 * (bb[["ymax"]] - bb[["ymin"]])

deco <- function(p) {
  p +
    annotate("segment", x = x0, xend = x0 + bar_m, y = y0, yend = y0, colour = INK,
             linewidth = 1.1) +
    annotate("segment", x = x0, xend = x0, y = y0 - 400, yend = y0 + 400, colour = INK,
             linewidth = 0.7) +
    annotate("segment", x = x0 + bar_m, xend = x0 + bar_m, y = y0 - 400, yend = y0 + 400,
             colour = INK, linewidth = 0.7) +
    annotate("text", x = x0 + bar_m / 2, y = y0 + 1300, label = "10 km", colour = INK,
             size = 3.1) +
    annotate("segment", x = nx, xend = nx, y = ny, yend = ny + arrow_h, colour = INK,
             linewidth = 0.9,
             arrow = grid::arrow(length = unit(0.18, "cm"), type = "closed")) +
    annotate("text", x = nx, y = ny + arrow_h + 1400, label = "N", colour = INK,
             size = 3.6, fontface = "bold")
}

map_theme <- function() {
  theme_void(base_size = 12) +
    theme(plot.background = element_rect(fill = "white", colour = NA),
          panel.background = element_rect(fill = "white", colour = NA),
          legend.background = element_rect(fill = "white", colour = NA),
          legend.key = element_rect(fill = "white", colour = NA),
          plot.title = element_text(colour = INK, face = "bold", size = 17,
                                    margin = margin(b = 4)),
          plot.subtitle = element_text(colour = BODY, size = 10.2, lineheight = 1.3,
                                       margin = margin(b = 8)),
          plot.caption = element_text(colour = MUTED, size = 7.4, hjust = 0,
                                      lineheight = 1.3, margin = margin(t = 8)),
          plot.title.position = "plot", plot.caption.position = "plot",
          plot.margin = margin(14, 18, 10, 14),
          legend.position = "right",
          legend.title = element_text(size = 9.5, colour = BODY),
          legend.text = element_text(size = 9, colour = BODY))
}

wrap <- function(x, w) paste(strwrap(paste(x, collapse = " "), width = w), collapse = "\n")
W <- 14; H <- 9.2

build <- function(value_col, ramp, legend_title, title, subtitle, footnote, path,
                  reg_title, reg_caption, prov) {
  a <- analysed; a$v <- a[[value_col]]
  t <- tracts;   t$v <- t[[value_col]]
  rng <- range(c(a$v, t$v), na.rm = TRUE)
  p <- ggplot() +
    geom_sf(data = notan, fill = GREY_NA, colour = NA, alpha = 0.55) +
    geom_sf(data = t, aes(fill = v, alpha = I(a)), colour = UNIT_EDGE,
            linewidth = 0.07) +
    geom_sf(data = a, aes(fill = v, alpha = I(a)), colour = UNIT_EDGE,
            linewidth = 0.12) +
    geom_sf(data = bnd, fill = NA, colour = INK, linewidth = 0.7) +
    scale_fill_gradientn(colours = ramp, limits = rng, name = legend_title,
                         guide = guide_colourbar(barheight = unit(3.4, "cm"),
                                                 barwidth = unit(0.42, "cm"),
                                                 order = 1)) +
    coord_sf(expand = FALSE) +
    labs(title = title, subtitle = subtitle, caption = footnote) +
    map_theme()
  p <- deco(p)
  r <- gayini_write_and_register_figure(
    plot = p, path = path, title = reg_title, caption = reg_caption,
    support_level = "pixel", figure_level = "mixed_unit", run_id = "MAP1_20260810",
    domain = "client_deliverables", recommended_use = "client report",
    provenance_note = prov, width = W, height = H, dpi = 150)
  cat(sprintf("  [registered] %s  %s   value range %.1f-%.1f\n", basename(r$path),
              substr(r$checksum_sha256, 1, 12), rng[1], rng[2]))
  invisible(r)
}

# ======================================================================================
# M3 - the water axis on the ground
# ======================================================================================
sub3 <- wrap(c(
  "The x-axis of every cover-and-water figure, drawn where it comes from. Each area is filled by its own value,",
  "on one scale for the paddock areas and the unzoned tracts alike.",
  "It reads as a coarsened flood map, and it should: this is that pattern averaged up to the unit the analysis works on."),
  150)

foot3 <- wrap(c(
  "Fill is the share of each area's own census cells seen under water, averaged over the water years 1988-2022.",
  "It is a within-year extent averaged over the record - how much of an area goes under in a typical year - and NOT how often the ground floods, which is a different quantity with no time axis.",
  "Faint areas hold fewer than 500 cells. Grey areas carry tree canopy or sit outside the three open vegetation communities and are not analysed at all: grey is not a low value, and this ramp does not reach it.",
  "Comparing this map with the figures shows how much of the fine-grained water pattern survives being averaged to the analysis unit, and how much does not.",
  "White inside the boundary carries no vegetation-community mapping at all - 18,663 hectares, 22% of the property - and enters no analysis anywhere in this project. It is not a low value either.",
  "Measured on a 25 m satellite grid; the shapes are the union of each area's own cells."),
  220)

cap3 <- paste0(
  "Support: pixel. 118 non-treed paddock x community areas and 625 unzoned tracts on one ",
  "continuous scale; 38 not-analysed areas in grey. Fill is the share of the area's cells ",
  "seen wet, mean over years (%), Rulings AZ / CX - a within-year extent averaged over ",
  "the record, NEVER a between-year flood frequency. Transparency is the 500-cell size ",
  "threshold. No new metric is computed and no raster is built: every value is the same ",
  "column that supplies the x-axis of the cover-and-water figures. No community colour ",
  "appears, so no ramp colour can be confused with a community identity. Scope: ",
  "1988-2022.")

build("mean_share_cells_wet", WATER_RAMP,
      "Share of the area's cells\nseen wet, mean over\nyears (%)",
      "Where the water axis comes from", sub3, foot3,
      file.path(MAPS, "MAP1_M3_water_axis_on_the_ground.png"),
      "Share of cells seen wet, mean over years, by paddock x community area and unzoned tract",
      cap3,
      paste("MAP-1 figure M3. Values from the same columns behind the cover-and-water",
            "scatters. Geometry from MAP1_paddock_community_areas_epsg8058.gpkg and",
            "UNZONED_patches_epsg8058.gpkg. THE FIVE QUALIFIERS: support_level = pixel;",
            "scope_filter_sql = treed_context_flag = 0 AND regime_band <> 'context' for",
            "the ramp, the remaining 38 areas drawn grey as not-analysed;",
            "pixel_area_ha = 0.062351428; denominator_ha = 49606.9 zoned non-treed plus",
            "12048.1 unzoned; period_label = 1988-2022 (35 water years)."))

# ======================================================================================
# M4 - the cover axis · CONDITIONAL on its caption fitting legibly
# ======================================================================================
# The pre-registered rule: if the burden sentence cannot be fitted legibly on the face,
# M4 is not produced. TESTED, not assumed - the footnote is built first and measured.
foot4 <- wrap(c(
  "Fill is the 5th-percentile ground cover of each area, averaged over its own cells: what the poorest seasons leave on the ground, place by place.",
  "THE CLIENT'S OBJECTION TO THE EARLIER RESIDUAL MAPS DOES NOT APPLY HERE, and the reason is the difference between the two measures. Those maps coloured large areas using a value calculated from the barest ground inside them. This one does not: the percentile is worked out for every cell across its own 35-year history, and the area's colour is the average of all of them, so every cell contributes and no subset of ground is selected.",
  "THIS IS GROUND COVER MEASURED BY SATELLITE, NOT ECOLOGICAL CONDITION. It cannot separate a change in land use from a change in condition, and a darker area is not a better one.",
  "It describes how places differ from one another over the record - not what more water would do to any one place.",
  "Faint areas hold fewer than 500 cells. Grey areas carry tree canopy or sit outside the three open vegetation communities: beneath a canopy the satellite's ground-cover number does not mean what it means in the open, so they are not analysed and the ramp does not reach them.",
  "White inside the boundary carries no vegetation-community mapping at all - 18,663 hectares, 22% of the property - and enters no analysis anywhere in this project. It is not a low value either.",
  "Measured on a 25 m satellite grid across 1988-2022."),
  220)

n_lines <- length(strsplit(foot4, "\n")[[1]])
LINE_BUDGET <- 12   # at 7.4 pt with 1.3 line height on a 9.2 in canvas
cat(sprintf("\n[M4 gate] burden footnote is %d lines against a budget of %d\n",
            n_lines, LINE_BUDGET))
if (n_lines > LINE_BUDGET) {
  cat("[M4 gate] NOT PRODUCED - the burden sentence does not fit legibly on the face.\n")
} else {
  cat("[M4 gate] PRODUCED - the burden fits; M4 is built.\n")
  sub4 <- wrap(c(
    "The y-axis of every cover-and-water figure, drawn where it comes from. Each area is filled by its own value,",
    "on one scale for the paddock areas and the unzoned tracts alike.",
    "Read it as a map of how much cover the poorest seasons leave, not as a map of how good the country is."), 150)
  cap4 <- paste0(
    "Support: pixel. 118 non-treed paddock x community areas and 625 unzoned tracts on ",
    "one continuous scale; 38 not-analysed areas in grey. Fill is the mean over an area's ",
    "cells of each cell's temporal 5th percentile of total vegetation cover, SEASONAL ",
    "basis - the same quantity that supplies the y-axis of the cover-and-water figures, ",
    "and a DISTINCT METRIC from the spatial floor, which is never co-plotted with it. ",
    "The face carries the answer to the client's standing objection to the residual maps: ",
    "that objection was correct about the spatial floor and does not apply to this ",
    "metric, because the percentile is computed per cell and averaged, so no subset of ",
    "ground is selected. The face also carries the condition caveat in full. ",
    "Transparency is the 500-cell size threshold. No new metric is computed. Scope: ",
    "treed_context_flag = 0 AND regime_band <> 'context', 1988-2022.")
  build("veg_p05_temporal_mean", COVER_RAMP,
        "5th-percentile ground\ncover, mean of cells (%)",
        "Where the cover axis comes from", sub4, foot4,
        file.path(MAPS, "MAP1_M4_cover_axis_on_the_ground.png"),
        "Mean per-cell temporal 5th-percentile ground cover, by paddock x community area and unzoned tract",
        cap4,
        paste("MAP-1 figure M4, produced because the section 6 burden sentence fits",
              "legibly on the face. Values from the same column behind the",
              "cover-and-water scatters' y-axis. THE FIVE QUALIFIERS:",
              "support_level = pixel;",
              "scope_filter_sql = treed_context_flag = 0 AND regime_band <> 'context';",
              "pixel_area_ha = 0.062351428; denominator_ha = 49606.9 zoned non-treed plus",
              "12048.1 unzoned; period_label = 1988-2022 (35 water years)."))
}
