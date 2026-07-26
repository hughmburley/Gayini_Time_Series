#!/usr/bin/env Rscript
# T1 Gate B1 - the A0/A/B gate figures, each written AND registered in one call
# via gayini_write_and_register_figure() (first-50-MB SHA-256, INSERT OR REPLACE).
# Spec: docs/T1_zone_stratum_census_join.md v3, Gate figures.

suppressPackageStartupMessages({
  library(sf); library(terra); library(ggplot2); library(DBI); library(RSQLite)
})
root <- normalizePath(".", winslash = "/")
source(file.path(root, "R/gayini_figure_register.R"))

gpkg    <- file.path(root, "Output/spatial_8058/management_zones_epsg8058.gpkg")
gridref <- file.path(root, "Output/rasters/veg_regime_class_8058.tif")
fig_dir <- file.path(root, "Output/figures/diagnostics")
RUN_ID  <- "T1_gateB1"
SUPPORT <- "paddock"         # closed-vocab support ladder term; a management zone IS a paddock
LEVEL   <- "diagnostics"

## ---- data ------------------------------------------------------------------
z <- sf::st_read(gpkg, quiet = TRUE)
gc <- DBI::dbConnect(RSQLite::SQLite(), gpkg, flags = RSQLite::SQLITE_RO)
fidmap <- DBI::dbGetQuery(gc, "SELECT fid, ManagmentZ FROM management_zones_epsg8058")
DBI::dbDisconnect(gc)
z$fid <- as.integer(fidmap$fid[match(as.character(z$ManagmentZ), fidmap$ManagmentZ)])

areas <- read.csv(file.path(root, "Output/tables/T1_gateA_zone_areas.csv"))
ident <- read.csv(file.path(root, "Output/tables/T1_gateB_identity_assignment.csv"))
z <- merge(z, areas[, c("fid", "zone_name", "treatment", "area_ha_source",
                        "area_ha_computed", "area_ha_diff_pct")], by = "fid")

ev <- as.vector(terra::ext(terra::rast(gridref)))   # named: xmin xmax ymin ymax
ext_sfc <- sf::st_as_sfc(sf::st_bbox(c(xmin = ev[["xmin"]], ymin = ev[["ymin"]],
                                       xmax = ev[["xmax"]], ymax = ev[["ymax"]]),
                                     crs = sf::st_crs(z)))

## ---- F1: A0 zone layer over the census grid extent -------------------------
p1 <- ggplot() +
  geom_sf(data = ext_sfc, fill = NA, colour = "red", linewidth = 0.9) +
  geom_sf(data = z, fill = "#9ecae1", colour = "#08519c", linewidth = 0.2) +
  annotate("text", x = ev[["xmin"]], y = ev[["ymax"]],
           label = "red = census grid extent (veg_regime_class_8058)",
           hjust = 0, vjust = 1.4, size = 3, colour = "red") +
  labs(title = "T1 A0 · 8058 zone layer over the census grid extent",
       subtitle = "64 management zones (EPSG:8058) within the census grid; no offset",
       caption = "Support: paddock (management zone). Both layers EPSG:8058.") +
  theme_minimal(base_size = 11)
gayini_write_and_register_figure(
  p1, file.path(fig_dir, "T1_A0_zone_layer_extent.png"),
  title = "T1 A0 zone layer extent",
  caption = "Support: paddock (management zone). 8058 zone layer over the census grid extent; extents coincide.",
  support_level = SUPPORT, figure_level = LEVEL, run_id = RUN_ID,
  provenance_note = "Gate A0 check figure. spatial_006 vs veg_regime_class_8058 extent.",
  width = 9, height = 7)

## ---- F2: A named zone map, filled by treatment -----------------------------
p2 <- ggplot(z) +
  geom_sf(aes(fill = treatment), colour = "grey30", linewidth = 0.2) +
  geom_sf_text(aes(label = zone_name), size = 1.7, colour = "black") +
  scale_fill_manual(values = c("14-day grazing" = "#fdae6b", "No grazing" = "#31a354"),
                    name = "Treatment") +
  labs(title = "T1 A · Management zones, labelled with paddock names",
       subtitle = "Fill = grazing treatment (14-day grazing 60 · No grazing 4)",
       caption = "Support: paddock (management zone). Labels are ManagmentZ paddock names, not indices.") +
  theme_minimal(base_size = 11)
gayini_write_and_register_figure(
  p2, file.path(fig_dir, "T1_A_zone_map_named.png"),
  title = "T1 A zone map named",
  caption = "Support: paddock (management zone). All 64 zones filled by treatment, labelled with paddock names.",
  support_level = SUPPORT, figure_level = LEVEL, run_id = RUN_ID,
  provenance_note = "Gate A named-map check. ManagmentZ labels.",
  width = 11, height = 9)

## ---- F3: A identity margin - residual band + per-zone margins, twins marked -
ident$is_twin <- ident$off_identity == 1
long <- rbind(
  data.frame(fid = ident$zone_fid, metric = "assumed-partner residual (pp)",
             value = ident$residual_pp, is_twin = ident$is_twin),
  data.frame(fid = ident$zone_fid, metric = "per-zone area margin (pp)",
             value = ident$margin_pp, is_twin = ident$is_twin))
band <- data.frame(metric = "assumed-partner residual (pp)",
                   ymin = min(ident$residual_pp), ymax = max(ident$residual_pp))
twin_lab <- subset(long, is_twin)
p3 <- ggplot(long, aes(fid, value)) +
  geom_rect(data = band, inherit.aes = FALSE,
            aes(xmin = -Inf, xmax = Inf, ymin = ymin, ymax = ymax),
            fill = "#41ab5d", alpha = 0.18) +
  geom_hline(yintercept = 0, colour = "grey70", linewidth = 0.3) +
  geom_point(aes(colour = is_twin), size = 1.6) +
  geom_text(data = twin_lab, aes(label = paste0("fid ", fid)),
            vjust = -0.9, size = 2.8, colour = "#cb181d") +
  scale_colour_manual(values = c("FALSE" = "#08519c", "TRUE" = "#cb181d"),
                      labels = c("area-pinned (provenance+area)", "area-twin (provenance_only)"),
                      name = NULL) +
  facet_wrap(~metric, ncol = 1, scales = "free_y") +
  labs(title = "T1 A · Zone identity — residual band and per-zone margins",
       subtitle = sprintf("Residuals in a tight %.3f–%.3f pp band (green) — a scrambled permutation would be ragged; fid 9/21 are area-twins held by provenance",
                          min(ident$residual_pp), max(ident$residual_pp)),
       x = "zone fid", y = NULL,
       caption = "Support: paddock (management zone). Residual = |MODIS area − computed area| / MODIS area. Margin < 0 = a competitor fid is closer (area-twin).") +
  theme_minimal(base_size = 11) + theme(legend.position = "top")
gayini_write_and_register_figure(
  p3, file.path(fig_dir, "T1_A_identity_margin.png"),
  title = "T1 A identity margin",
  caption = "Support: paddock (management zone). Assumed-partner residual band and per-zone margins; fid 9/21 marked as area-twins.",
  support_level = SUPPORT, figure_level = LEVEL, run_id = RUN_ID,
  provenance_note = "Gate A identity check. Band tightness is the evidence; twins held by provenance.",
  width = 10, height = 8)

## ---- F4: B Area_MW vs area_ha_computed, 1:1 line ---------------------------
med_diff <- median(areas$area_ha_diff_pct)
p4 <- ggplot(areas, aes(area_ha_source, area_ha_computed)) +
  geom_abline(slope = 1, intercept = 0, colour = "grey50", linetype = 2) +
  geom_point(colour = "#08519c", size = 1.8, alpha = 0.8) +
  labs(title = "T1 B · Area_MW (source) vs area_ha_computed (8058 geometry)",
       subtitle = sprintf("Points sit just below 1:1 — computed is a systematic %.2f%% smaller (median); a projection offset, reported not corrected", med_diff),
       x = "Area_MW (ESRI, projection unstated) — ha",
       y = "area_ha_computed (EPSG:8058) — ha",
       caption = "Support: paddock (management zone). Both area columns retained in dim_management_zone with area_ha_diff_pct.") +
  coord_equal() + theme_minimal(base_size = 11)
gayini_write_and_register_figure(
  p4, file.path(fig_dir, "T1_B_area_source_vs_computed.png"),
  title = "T1 B area source vs computed",
  caption = "Support: paddock (management zone). Area_MW vs area_ha_computed, 1:1 line; systematic projection offset annotated.",
  support_level = SUPPORT, figure_level = LEVEL, run_id = RUN_ID,
  provenance_note = "Gate B area check. Source vs 8058-computed area.",
  width = 8, height = 8)

cat("\n[done] 4 gate figures written + registered ->", fig_dir, "\n")
