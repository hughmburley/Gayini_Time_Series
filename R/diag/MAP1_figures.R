# MAP-1 - where the scatterplot points are.
#
# Spec: docs/reference_update/Gayini_CC_spec_MAP1.md.
#
# These maps answer "what is a point and where does it sit". THEY CARRY NO NEW RESULT.
# Every value drawn is a column already behind an existing figure; no metric is computed
# and no raster is built.
#
# GEOMETRY. The 156 paddock x community areas are NOT in Gayini_Results.gpkg, which holds
# management_zones (64) and vegetation_units (20). They are derived from the census cells
# by MAP1_build_part_polygons.py - the same cells the scatters aggregate - so the shapes
# on the map ARE the analysis units rather than a second vector definition of them. The
# unzoned tracts come from UNZONED v3's own geopackage (section 2's fork did not fire).
#
# NO LOCATOR INSET, and that is an override - see the run report. Section 7 asks for one,
# and the four locator paths in this codebase all exist to place a SUB-UNIT inside the
# property. These maps ARE the whole property, so such an inset would locate the property
# inside itself. A regional inset would need boundary data the project does not hold. The
# property boundary is the frame instead. No locator path was parameterised.
#
# Naming: "unzoned standard-grazing country". Never unmanaged, ungrazed, control or
# reference. Place names follow existing report-stream usage; no new naming is introduced
# and no location is labelled that the report stream does not already label.

suppressPackageStartupMessages({library(ggplot2); library(sf); library(DBI)
                                library(RSQLite)})

root <- normalizePath(".", winslash = "/")
source(file.path(root, "R/gayini_figure_register.R"))

MAPS <- file.path(root, "Output", "maps")
PARTS <- file.path(MAPS, "MAP1_paddock_community_areas_epsg8058.gpkg")
TRACTS <- file.path(root, "Output/unzoned/UNZONED_patches_epsg8058.gpkg")
BND <- file.path(root, "Output/spatial_8058/gayini_boundary_epsg8058.gpkg")
stopifnot(file.exists(PARTS), file.exists(TRACTS), file.exists(BND))

parts <- sf::st_read(PARTS, quiet = TRUE)
tracts <- sf::st_read(TRACTS, quiet = TRUE)
bnd <- sf::st_read(BND, quiet = TRUE)
stopifnot(nrow(parts) == 156L, sf::st_crs(parts)$epsg == 8058,
          sf::st_crs(tracts)$epsg == 8058, sf::st_crs(bnd)$epsg == 8058)

INK <- "#26302E"; BODY <- "#5F6B67"; MUTED <- "#8A8378"
PAL <- c("Inland Floodplain" = "#2E6DB0", "Riverine Chenopod" = "#3FAE97",
         "Aeolian Chenopod" = "#C79A3C",
         "Not analysed — tree canopy or minor unit" = "#7C837E")
LAY <- c(inland = "Inland Floodplain", riverine = "Riverine Chenopod",
         aeolian = "Aeolian Chenopod")
NOT_ANALYSED <- "Not analysed — tree canopy or minor unit"

comm_lab <- function(short, cls) {
  ifelse(cls %in% c("woodland", "other"), NOT_ANALYSED, LAY[short])
}
parts$fill_lab <- factor(comm_lab(parts$community_short, parts$inclusion_class),
                         levels = names(PAL))
# alpha encodes SIZE, applied honestly to all 156 - eight of the not-analysed areas are
# also under the floor, and lightening them too is what the column actually says.
SZ <- c("500 cells or more" = 1, "Under 500 cells" = 0.30)
parts$size_lab <- factor(ifelse(parts$n_cells >= 500, "500 cells or more",
                                "Under 500 cells"), levels = names(SZ))

tracts$fill_lab <- factor(LAY[tracts$community_short], levels = names(PAL))
tr_plot <- tracts[!is.na(tracts$meets_500_cells) & tracts$meets_500_cells == 1, ]
tr_rest <- tracts[is.na(tracts$meets_500_cells) | tracts$meets_500_cells == 0, ]

# ---- the numbers the captions state, all read from the data --------------------------
# THE WHITE INSIDE THE BOUNDARY IS TWO DIFFERENT THINGS and a reader cannot tell them
# apart by looking. Measured here rather than described: the property is 85,911 ha, the
# vegetation census maps 67,349 of them, and the remainder carries no community label and
# enters no analysis anywhere in this project. That is the mapped-vs-true-farm
# denominator, and on a map it is 22% of the page.
bnd_ha <- as.numeric(sum(sf::st_area(bnd))) / 1e4
unmapped_ha <- bnd_ha - sum(parts$area_ha) - sum(tracts$area_ha)
cat(sprintf("[numbers] property %.0f ha; zoned %.0f; unzoned %.0f; UNMAPPED %.0f (%.0f%%)\n",
            bnd_ha, sum(parts$area_ha), sum(tracts$area_ha), unmapped_ha,
            100 * unmapped_ha / bnd_ha))

cls_ha <- tapply(parts$area_ha, parts$inclusion_class, sum)
cls_n <- table(parts$inclusion_class)
open_ha <- sum(parts$area_ha[!parts$inclusion_class %in% c("woodland", "other")])
tr_all_ha <- sum(tracts$area_ha)
tr_plot_ha <- sum(tr_plot$area_ha)
sup <- tracts[!is.na(tracts$meets_support_rule) & tracts$meets_support_rule == 1, ]
sup_drop <- sup[sup$n_cells < 500, ]
cat(sprintf("\n[numbers] plotted %d (%.0f ha) | woodland %d (%.0f) | other %d (%.0f) | under-floor %d (%.0f, %.1f%% of open %.0f)\n",
            cls_n[["plotted"]], cls_ha[["plotted"]], cls_n[["woodland"]], cls_ha[["woodland"]],
            cls_n[["other"]], cls_ha[["other"]], cls_n[["under_floor"]], cls_ha[["under_floor"]],
            100 * cls_ha[["under_floor"]] / open_ha, open_ha))
cat(sprintf("[numbers] tracts: all %d (%.0f ha); plotted %d (%.0f ha); supported %d; supported dropping %d (%.0f ha); all-minus-plotted %.0f ha\n",
            nrow(tracts), tr_all_ha, nrow(tr_plot), tr_plot_ha, nrow(sup),
            nrow(sup_drop), sum(sup_drop$area_ha), tr_all_ha - tr_plot_ha))

# ---- scale bar and north arrow, built from the extent --------------------------------
bb <- sf::st_bbox(parts)
bar_m <- 10000
# bottom-RIGHT: the bottom-left corner is filled with polygons and the bar sat on top of
# them, unreadable. The bottom-right corner of the extent is empty country.
x0 <- bb[["xmax"]] - 0.24 * (bb[["xmax"]] - bb[["xmin"]])
y0 <- bb[["ymin"]] + 0.055 * (bb[["ymax"]] - bb[["ymin"]])
nx <- bb[["xmax"]] - 0.035 * (bb[["xmax"]] - bb[["xmin"]])
ny <- bb[["ymax"]] - 0.14 * (bb[["ymax"]] - bb[["ymin"]])
arrow_h <- 0.085 * (bb[["ymax"]] - bb[["ymin"]])

deco <- function(p) {
  p +
    annotate("segment", x = x0, xend = x0 + bar_m, y = y0, yend = y0,
             colour = INK, linewidth = 1.1) +
    annotate("segment", x = x0, xend = x0, y = y0 - 400, yend = y0 + 400,
             colour = INK, linewidth = 0.7) +
    annotate("segment", x = x0 + bar_m, xend = x0 + bar_m, y = y0 - 400,
             yend = y0 + 400, colour = INK, linewidth = 0.7) +
    annotate("text", x = x0 + bar_m / 2, y = y0 + 1300, label = "10 km",
             colour = INK, size = 3.1) +
    annotate("segment", x = nx, xend = nx, y = ny, yend = ny + arrow_h,
             colour = INK, linewidth = 0.9,
             arrow = grid::arrow(length = unit(0.18, "cm"), type = "closed")) +
    annotate("text", x = nx, y = ny + arrow_h + 1400, label = "N", colour = INK,
             size = 3.6, fontface = "bold")
}

map_theme <- function() {
  theme_void(base_size = 12) +
    # theme_void() leaves the background UNSET, and ggsave then writes a PNG with a
    # transparent background. Dropped into a slide or a document that renders as black
    # or shows whatever is behind it. A client-facing map states its own background.
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
          legend.text = element_text(size = 9, colour = BODY),
          legend.key.height = unit(1.0, "lines"))
}

wrap <- function(x, w) paste(strwrap(paste(x, collapse = " "), width = w), collapse = "\n")

W <- 14; H <- 9.2

# ======================================================================================
# M1 - the units, and what was left out
# ======================================================================================
sub1 <- wrap(c(
  "Every one of the 156 areas the cover-and-water figures are built from, drawn where it is.",
  "Each shape is one paddock cut to a single vegetation community, and each is one point on those figures.",
  "Thin lines separate neighbouring areas: this is a map of units, not a map of vegetation."), 150)

foot1 <- wrap(c(
  sprintf("Of the %d areas, %d are plotted on the cover-and-water figures.", nrow(parts), cls_n[["plotted"]]),
  sprintf("%d carry tree canopy and are not analysed, because beneath a canopy the satellite's ground-cover number does not mean what it means in the open; %d more sit outside the three open vegetation communities.",
          cls_n[["woodland"]], cls_n[["other"]]),
  sprintf("The %d faint areas hold fewer than 500 cells - too few for an average that stands beside one taken over thousands.",
          cls_n[["under_floor"]]),
  sprintf("THEY ARE A LARGE SHARE OF THE UNITS AND A TINY SHARE OF THE GROUND: %d of %d areas, but %s hectares, %.1f%% of the open country.",
          cls_n[["under_floor"]], nrow(parts), format(round(cls_ha[["under_floor"]]), big.mark = ","),
          100 * cls_ha[["under_floor"]] / open_ha),
  sprintf("Areas by class: %s ha plotted, %s ha tree canopy, %s ha minor units, %s ha too small.",
          format(round(cls_ha[["plotted"]]), big.mark = ","),
          format(round(cls_ha[["woodland"]]), big.mark = ","),
          format(round(cls_ha[["other"]]), big.mark = ","),
          format(round(cls_ha[["under_floor"]]), big.mark = ",")),
  "None of the 156 is left off this map: what is excluded from the figures is drawn and named rather than quietly omitted.",
  sprintf("The white inside the property boundary is TWO different things and they should not be read as one: %s hectares of unzoned standard-grazing country, which the second map draws, and %s hectares - %.0f%% of the property - that carries no vegetation-community mapping at all and enters no analysis anywhere in this project.",
          format(round(sum(tracts$area_ha)), big.mark = ","),
          format(round(unmapped_ha), big.mark = ","), 100 * unmapped_ha / bnd_ha),
  "Cover and water are measured on a 25 m satellite grid across 1988-2022; the shapes are the union of each area's own cells."),
  220)

p1 <- ggplot() +
  geom_sf(data = parts, aes(fill = fill_lab, alpha = size_lab),
          colour = "#FBFAF6", linewidth = 0.14) +
  geom_sf(data = bnd, fill = NA, colour = INK, linewidth = 0.7) +
  scale_fill_manual(values = PAL, name = "Vegetation community", drop = FALSE,
                    guide = guide_legend(order = 1, override.aes = list(alpha = 1))) +
  scale_alpha_manual(values = SZ, name = "Size of the area",
                     guide = guide_legend(order = 2,
                                          override.aes = list(fill = "#2E6DB0"))) +
  coord_sf(expand = FALSE) +
  labs(title = "The 156 areas behind the cover-and-water figures",
       subtitle = sub1, caption = foot1) +
  map_theme()
p1 <- deco(p1)

cap1 <- paste0(
  "Support: pixel. 156 paddock x community areas, 885,292 census cells, 55,199 ha. ",
  "Geometry is the union of each area's own census cells - the same cells the scatters ",
  "aggregate - polygonised on the EPSG:8058 grid and verified to close against the cell ",
  "counts to 0.005 ha. Inclusion classes verified against the census before rendering ",
  "(design-seat amendment, 10 Aug): 100 plotted / 34 woodland or forest / 4 outside the ",
  "three open communities / 18 under the 500-cell floor, summing to 156. Fill is ",
  "vegetation community; transparency is the 500-cell size threshold applied to all 156, ",
  "so eight not-analysed areas are also lightened. No new metric is computed and no ",
  "raster is built. Scope: all census cells inside a management zone, 1988-2022.")

r1 <- gayini_write_and_register_figure(
  plot = p1, path = file.path(MAPS, "MAP1_M1_units_and_exclusions.png"),
  title = "The 156 paddock x community areas, by vegetation community and inclusion class",
  caption = cap1, support_level = "pixel", figure_level = "unit",
  run_id = "MAP1_20260810", domain = "client_deliverables",
  recommended_use = "client report",
  provenance_note = paste(
    "MAP-1 figure M1. Geometry from",
    "Output/maps/MAP1_paddock_community_areas_epsg8058.gpkg, derived from the census",
    "parquet by scripts/12_zone_stratum/MAP1_build_part_polygons.py. The 156 areas are",
    "NOT in Gayini_Results.gpkg as spec section 2 states; that file holds",
    "management_zones (64) and vegetation_units (20). THE FIVE QUALIFIERS:",
    "support_level = pixel; scope_filter_sql = zone_fid IS NOT NULL;",
    "pixel_area_ha = 0.062351428 (derived from PIXEL_SIDE_M = 24.970268);",
    "denominator_ha = 55199.2; period_label = 1988-2022 (35 water years).",
    "No locator inset: the four locator paths place a sub-unit inside the property and",
    "this map IS the property. Rulings EA and EC observed."),
  width = W, height = H, dpi = 150)
cat(sprintf("  [registered] %s  %s\n", basename(r1$path), substr(r1$checksum_sha256, 1, 12)))

# ======================================================================================
# M2 - the paddock system against the country outside it
# ======================================================================================
sub2 <- wrap(c(
  "The managed paddocks tile the country in blocks cut by fences. The unzoned standard-grazing country is what is left:",
  "interstitial, irregular, and wherever no management zone was ever drawn.",
  "They are different geometries covering the same country, which is why the unzoned tracts are a genuine held-out sample",
  "rather than a re-slicing of the same ground."), 150)

foot2 <- wrap(c(
  sprintf("Solid fills with a thin light edge are the %d paddock areas plotted on the cover-and-water figures. Heavy dark outlines are the %d unzoned tracts plotted alongside them.",
          cls_n[["plotted"]], nrow(tr_plot)),
  "Colour carries vegetation community on both, exactly as it does on every scatter; the outline, not the hue, is what tells the two apart.",
  sprintf("The palest shapes are the rest of the unzoned country. THE COUNT AND THE AREA PULL IN OPPOSITE DIRECTIONS AND BOTH ARE TRUE: of the %d tracts that can be seen for long enough to measure, %d fall under the 500-cell floor, and they carry %s of %s hectares.",
          nrow(sup), nrow(sup_drop), format(round(sum(sup_drop$area_ha)), big.mark = ","),
          format(round(sum(sup$area_ha)), big.mark = ",")),
  sprintf("Counting instead against every hectare of unzoned country, the %d plotted tracts hold %s of %s hectares, so %s hectares are not plotted.",
          nrow(tr_plot), format(round(tr_plot_ha), big.mark = ","),
          format(round(tr_all_ha), big.mark = ","),
          format(round(tr_all_ha - tr_plot_ha), big.mark = ",")),
  "The pale grey is tree-canopy and minor-unit country, analysed on neither side and shown here so the property reads whole.",
  sprintf("White is neither: %s hectares - %.0f%% of the property - carry no vegetation-community mapping and enter no analysis anywhere in this project.",
          format(round(unmapped_ha), big.mark = ","), 100 * unmapped_ha / bnd_ha),
  "This is unzoned STANDARD-GRAZING country - set stocking, a designed treatment arm. It is not unmanaged, not ungrazed, not a control and not a reference.",
  "All fifteen standard-grazing monitoring plots sit on this ground, which is why that arm had never been reported above plot scale: it had no paddock to belong to.",
  "Cover and water are measured on a 25 m satellite grid across 1988-2022."), 220)

p2 <- ggplot() +
  # the not-analysed country, as CONTEXT. Without it the map has large white voids that a
  # reader cannot identify, and the legend carries a swatch with no data behind it.
  geom_sf(data = parts[parts$inclusion_class %in% c("woodland", "other"), ],
          aes(fill = fill_lab), colour = NA, alpha = 0.30) +
  geom_sf(data = tr_rest, aes(fill = fill_lab), colour = NA, alpha = 0.22) +
  geom_sf(data = parts[parts$inclusion_class == "plotted", ], aes(fill = fill_lab),
          colour = "#FBFAF6", linewidth = 0.14, alpha = 0.95) +
  geom_sf(data = tr_plot, aes(fill = fill_lab), colour = INK, linewidth = 0.42,
          alpha = 0.95) +
  geom_sf(data = bnd, fill = NA, colour = INK, linewidth = 0.7) +
  scale_fill_manual(values = PAL, name = "Vegetation community", drop = FALSE,
                    guide = guide_legend(order = 1)) +
  coord_sf(expand = FALSE) +
  labs(title = "The paddock system, and the country outside it",
       subtitle = sub2, caption = foot2) +
  map_theme()
p2 <- deco(p2)

cap2 <- paste0(
  "Support: pixel. ", cls_n[["plotted"]], " plotted paddock x community areas (",
  format(round(cls_ha[["plotted"]]), big.mark = ","), " ha) and ", nrow(tr_plot),
  " plotted unzoned standard-grazing tracts (", format(round(tr_plot_ha), big.mark = ","),
  " ha), with the remaining unzoned country drawn faintly (", nrow(tr_rest), " tracts, ",
  format(round(tr_all_ha - tr_plot_ha), big.mark = ","), " ha). TWO TRUE COUNTS, stated ",
  "on the face because they pull opposite ways: 54 of the 93 supported tracts fall under ",
  "the 500-cell floor carrying 474 ha, while against all 12,048 ha of unzoned ground the ",
  "unplotted remainder is 570 ha. The two differ because the second includes tracts that ",
  "were never supported. Hue carries vegetation community on both sets; the outline ",
  "treatment, never the hue, distinguishes zoned from unzoned. The two unit ",
  "constructions differ and the sets are never pooled into one fit. Unzoned ground is ",
  "STANDARD-GRAZING country - set stocking, a designed treatment arm - never a ",
  "reference, a control or unmanaged. Scope: 1988-2022.")

r2 <- gayini_write_and_register_figure(
  plot = p2, path = file.path(MAPS, "MAP1_M2_paddock_system_and_unzoned.png"),
  title = "The paddock system against the unzoned standard-grazing country",
  caption = cap2, support_level = "pixel", figure_level = "mixed_unit",
  run_id = "MAP1_20260810", domain = "client_deliverables",
  recommended_use = "client report",
  provenance_note = paste(
    "MAP-1 figure M2. Zoned geometry from",
    "Output/maps/MAP1_paddock_community_areas_epsg8058.gpkg; unzoned tracts from",
    "Output/unzoned/UNZONED_patches_epsg8058.gpkg (section 2's fork did NOT fire - the",
    "geopackage was already written by UNZONED v3 section 6, 625 polygons closing to",
    "12,048.1 ha). THE FIVE QUALIFIERS: support_level = pixel;",
    "scope_filter_sql = treed_context_flag = 0 AND regime_band <> 'context', with",
    "zone_fid IS NOT NULL AND n_cells >= 500 for the paddock areas and zone_fid IS NULL",
    "for the tracts; pixel_area_ha = 0.062351428; denominator_ha = 49436.1 zoned plus",
    "11478.3 unzoned; period_label = 1988-2022 (35 water years)."),
  width = W, height = H, dpi = 150)
cat(sprintf("  [registered] %s  %s\n", basename(r2$path), substr(r2$checksum_sha256, 1, 12)))
