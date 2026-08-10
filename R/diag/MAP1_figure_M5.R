# MAP-1 figure M5 - the unzoned standard-grazing country on its own terms.
#
# Spec: design-seat addition, 10 August 2026.
#
# M2 shows these tracts as a residual against a paddock system that dominates the page.
# The unzoned arm now carries its own result - 39 tracts, Inland r +0.719, landing 0.30 pp
# from the paddock line - and that evidence had no map. Here the paddock areas drop to a
# faint context outline and the tracts carry the page.
#
# THE FOUR CLASSES RESOLVE D2 PERMANENTLY. A count and an area with different denominators
# in one sentence is what caused it; four rows each carrying its own count AND its own
# area cannot. The whole never-supported tail is under 100 hectares across 532 tracts -
# the answer to anyone who assumes a 500-cell floor discarded most of this country.
#
# RULING C10. The fifteen standard-grazing monitoring plots are marked as LOCATIONS and
# are never given a value. This is a pixel-support map; the plots are plot support. They
# are here because this is the only map in the project where they have somewhere to sit,
# and because they are the join between this analysis and every plot-support result.
#
# Naming, fixed: unzoned standard-grazing country. Never unmanaged, ungrazed, control or
# reference.

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
plots <- sf::st_read(file.path(root,
                               "Output/spatial_8058/gayini_hectare_plots_epsg8058.gpkg"),
                     quiet = TRUE)
overlay <- utils::read.csv(file.path(root, "Output/tables/UNZONED_gate1_plot_overlay.csv"),
                           stringsAsFactors = FALSE)
stopifnot(nrow(tracts) == 625L, nrow(parts) == 156L, nrow(plots) == 66L)

INK <- "#26302E"; BODY <- "#5F6B67"; MUTED <- "#8A8378"
PAL <- c("Inland Floodplain" = "#2E6DB0", "Riverine Chenopod" = "#3FAE97",
         "Aeolian Chenopod" = "#C79A3C")
LAY <- c(inland = "Inland Floodplain", riverine = "Riverine Chenopod",
         aeolian = "Aeolian Chenopod")

# ---- the four classes, VERIFIED against the geopackage before drawing -----------------
sup <- ifelse(is.na(tracts$meets_support_rule), 0L, as.integer(tracts$meets_support_rule))
tracts$cls <- ifelse(sup == 1 & tracts$n_cells >= 500, "plotted",
                     ifelse(sup == 1, "under_floor", "never"))
CLS <- c(plotted = "Plotted in the figures — 500 cells or more",
         under_floor = "Measurable, but under the 500-cell floor",
         never = "Too rarely visible to measure at all")
tracts$cls_lab <- factor(CLS[tracts$cls], levels = unname(CLS))
tracts$comm_lab <- factor(LAY[tracts$community_short], levels = names(PAL))

agg <- aggregate(cbind(n = rep(1, nrow(tracts)), ha = tracts$area_ha),
                 by = list(cls = tracts$cls), FUN = sum)
row.names(agg) <- agg$cls
SPEC <- list(plotted = c(39, 11478.3), under_floor = c(54, 474.4), never = c(532, 95.4))
cat("\n[verify] the four classes against the geopackage\n")
ok <- TRUE
for (k in names(SPEC)) {
  n <- agg[k, "n"]; ha <- agg[k, "ha"]
  hit <- n == SPEC[[k]][1] && abs(ha - SPEC[[k]][2]) < 0.15
  ok <- ok && hit
  cat(sprintf("    %-14s n=%4d (design seat %4.0f)  %9.1f ha (%9.1f)  %s\n",
              k, n, SPEC[[k]][1], ha, SPEC[[k]][2], if (hit) "OK" else "REPORT BOTH"))
}
cat(sprintf("    %-14s n=%4d              %9.1f ha\n", "TOTAL", sum(agg$n), sum(agg$ha)))
if (!ok) cat("  NOTE: a class differs from the design-seat arithmetic; both are reported.\n")

# ---- the fifteen standard-grazing plots, as LOCATIONS only ---------------------------
sg_ids <- overlay$plot_id[grepl("tandard", overlay$treatment) &
                            overlay$on_unzoned_ground == 1]
sg <- plots[plots$plot_id %in% sg_ids, ]
stopifnot(nrow(sg) == 15L)
sg_pt <- sf::st_centroid(sf::st_geometry(sg))
cat(sprintf("  [plots] %d standard-grazing monitoring plots, marked as locations only\n",
            nrow(sg)))

bnd_ha <- as.numeric(sum(sf::st_area(bnd))) / 1e4
unmapped_ha <- bnd_ha - sum(parts$area_ha) - sum(tracts$area_ha)

bb <- sf::st_bbox(parts)
bar_m <- 10000
x0 <- bb[["xmax"]] - 0.24 * (bb[["xmax"]] - bb[["xmin"]])
y0 <- bb[["ymin"]] + 0.055 * (bb[["ymax"]] - bb[["ymin"]])
nx <- bb[["xmax"]] - 0.035 * (bb[["xmax"]] - bb[["xmin"]])
ny <- bb[["ymax"]] - 0.14 * (bb[["ymax"]] - bb[["ymin"]])
arrow_h <- 0.085 * (bb[["ymax"]] - bb[["ymin"]])

wrap <- function(x, w) paste(strwrap(paste(x, collapse = " "), width = w), collapse = "\n")

sub5 <- wrap(c(
  "The country no management zone was ever drawn over, drawn on its own terms rather than as what is left after the paddocks.",
  "It is interstitial by construction - it fills the gaps between fenced blocks, so it is irregular where the paddock system is rectangular.",
  "That is exactly why it is a genuine held-out sample: it is different geometry over the same country, not a re-slicing of the same units."),
  150)

foot5 <- wrap(c(
  sprintf("Every tract is drawn. Solid: the %d plotted on the cover-and-water figures, %s hectares. Mid: %d more that can be measured but hold fewer than 500 cells, %s hectares. Faintest: %d tracts too rarely visible to measure at all, %s hectares between them.",
          agg["plotted", "n"], format(round(agg["plotted", "ha"]), big.mark = ","),
          agg["under_floor", "n"], format(round(agg["under_floor", "ha"]), big.mark = ","),
          agg["never", "n"], format(round(agg["never", "ha"], 1), big.mark = ",")),
  sprintf("THE COUNT AND THE AREA SAY OPPOSITE THINGS AND BOTH ARE TRUE: %d of the %d tracts are not plotted, and they carry %s of %s hectares.",
          agg["under_floor", "n"] + agg["never", "n"], sum(agg$n),
          format(round(agg["under_floor", "ha"] + agg["never", "ha"]), big.mark = ","),
          format(round(sum(agg$ha)), big.mark = ",")),
  "This is the shape of the country, not a shortcoming of the threshold: a few large tracts and a long tail of slivers. The 500-cell floor removes most of the tracts and almost none of the ground.",
  "Black circles mark the fifteen standard-grazing monitoring plots. They are shown as PLACES ONLY and carry no value on this map: they are measured on the ground at one-hectare scale, while everything coloured here is measured from satellite on a 25 m grid, and the two scales are never mixed.",
  "All fifteen sit on this country, which is why the standard-grazing arm had never been reported above plot scale - it had no paddock to belong to.",
  "Grey outlines are the paddock areas, drawn for context only.",
  sprintf("White inside the boundary carries no vegetation-community mapping at all - %s hectares, %.0f%% of the property - and enters no analysis anywhere in this project.",
          format(round(unmapped_ha), big.mark = ","), 100 * unmapped_ha / bnd_ha),
  "This is unzoned STANDARD-GRAZING country - set stocking, a designed treatment arm. It is not unmanaged, not ungrazed, not a control and not a reference. Measured across 1988-2022."),
  220)

ALPHA <- c(1, 0.55, 0.30)
names(ALPHA) <- unname(CLS)

p5 <- ggplot() +
  geom_sf(data = parts, fill = NA, colour = "#C7CCC8", linewidth = 0.18) +
  geom_sf(data = tracts, aes(fill = comm_lab, alpha = cls_lab),
          colour = "#8E948F", linewidth = 0.08) +
  geom_sf(data = bnd, fill = NA, colour = INK, linewidth = 0.7) +
  geom_sf(data = sg_pt, shape = 21, fill = INK, colour = "white", stroke = 0.7,
          size = 2.4) +
  scale_fill_manual(values = PAL, name = "Vegetation community",
                    guide = guide_legend(order = 1,
                                         override.aes = list(alpha = 1))) +
  scale_alpha_manual(values = ALPHA, name = "How much of it can be measured",
                     guide = guide_legend(order = 2,
                                          override.aes = list(fill = "#2E6DB0"))) +
  coord_sf(expand = FALSE) +
  labs(title = "The unzoned standard-grazing country, on its own terms",
       subtitle = sub5, caption = foot5) +
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
        legend.text = element_text(size = 9, colour = BODY)) +
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

cap5 <- paste0(
  "Support: pixel, for everything coloured. 625 unzoned standard-grazing tracts, ",
  format(round(sum(agg$ha), 1), big.mark = ","), " ha, in four classes each carrying its ",
  "own count AND its own area: ", agg["plotted", "n"], " plotted (",
  format(round(agg["plotted", "ha"], 1), big.mark = ","), " ha), ",
  agg["under_floor", "n"], " supported but under the 500-cell floor (",
  round(agg["under_floor", "ha"], 1), " ha), ", agg["never", "n"], " never supported (",
  round(agg["never", "ha"], 1), " ha). The design-seat arithmetic gave 95.4 ha for the ",
  "never-supported tail; the geopackage gives ", round(agg["never", "ha"], 1),
  " ha, a rounding difference, and both are reported. RULING C10: the fifteen ",
  "standard-grazing monitoring plots are marked as LOCATIONS ONLY and are never given a ",
  "value - they are plot support (~1 ha) on a pixel-support map and the two are never ",
  "mixed. Paddock areas are context outline only. Unzoned ground is STANDARD-GRAZING ",
  "country - set stocking, a designed treatment arm - never a reference, a control or ",
  "unmanaged. No new metric is computed and no raster is built. Scope: ",
  "treed_context_flag = 0 AND regime_band <> 'context' AND zone_fid IS NULL, 1988-2022.")

r5 <- gayini_write_and_register_figure(
  plot = p5, path = file.path(MAPS, "MAP1_M5_unzoned_country_on_its_own_terms.png"),
  title = "The unzoned standard-grazing country by measurability class, with the standard-grazing monitoring plots",
  caption = cap5, support_level = "pixel", figure_level = "patch",
  run_id = "MAP1_20260810", domain = "client_deliverables",
  recommended_use = "client report",
  provenance_note = paste(
    "MAP-1 figure M5. Tract geometry and attributes from",
    "Output/unzoned/UNZONED_patches_epsg8058.gpkg; paddock context from",
    "Output/maps/MAP1_paddock_community_areas_epsg8058.gpkg; plot locations from",
    "Output/spatial_8058/gayini_hectare_plots_epsg8058.gpkg, selected by",
    "UNZONED_gate1_plot_overlay.csv. Class counts and areas verified against the",
    "geopackage before rendering. THE FIVE QUALIFIERS: support_level = pixel;",
    "scope_filter_sql = treed_context_flag = 0 AND regime_band <> 'context' AND zone_fid",
    "IS NULL; pixel_area_ha = 0.062351428 (derived from PIXEL_SIDE_M = 24.970268);",
    "denominator_ha = 12048.1; period_label = 1988-2022 (35 water years).",
    "Plot markers are plot support and carry no value (C10)."),
  width = 14, height = 9.2, dpi = 150)
cat(sprintf("  [registered] %s  %s\n", basename(r5$path), substr(r5$checksum_sha256, 1, 12)))
