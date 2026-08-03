# T3 Gates C, D and E - persistence polygons (GeoPackage), the README, and the
# three remaining gate figures.
#
# Spec: docs/T3_always_green_threshold.md v3.  Decisions: T3 Gate D, 3 Aug 2026.
#
# NO HEADLINE THRESHOLD. Every figure and layer here carries the operational cut as
# an operational cut. Gate B1 measured a smooth decline with no knee, so refugial
# extent is a continuum; t = 75 / 79 / 82 are a stated sensitivity analysis, not a
# boundary. A result that holds at only one of them is measuring the cut.

suppressPackageStartupMessages({
  library(terra); library(sf); library(ggplot2); library(dplyr)
  library(scales); library(DBI); library(RSQLite)
})
source("R/gayini_figure_register.R")

RAS_DIR <- file.path("Output", "rasters", "persistence_8058")
FIG_DIR <- file.path("Output", "figures", "diagnostics")
GPKG    <- file.path(RAS_DIR, "T3_persistence_polygons_8058.gpkg")
DB      <- file.path("Output", "database", "Gayini_Results.sqlite")
RUN_ID  <- "T3_gateE"
CAVEAT  <- paste("FC is natively 30 m (EPSG:3577), bilinear-resampled once onto the 24.97 m",
                 "EPSG:8058 census grid - polygon edges are finer than the source supports.")
NOBREAK <- paste("NO HEADLINE THRESHOLD. Gate B1 measured a smooth area-threshold decline with",
                 "no knee (8.0%/pp at 75 rising monotonically to 69.0%/pp at 84), so refugial",
                 "extent is a CONTINUUM and every cut here is a chosen operational input for the",
                 "LiDAR overlay, not a measured boundary.")

bounds <- st_read("Output/spatial_8058/gayini_boundary_epsg8058.gpkg", quiet = TRUE)
zones  <- st_read("Output/spatial_8058/management_zones_epsg8058.gpkg", quiet = TRUE)
comp   <- read.csv("Output/tables/T3_persistence_vs_hydrology.csv")

con <- dbConnect(SQLite(), DB, flags = SQLITE_RO)
ref_fids <- dbGetQuery(con, "SELECT zone_fid FROM dim_management_zone WHERE reference_set_member=1")$zone_fid
sweep <- dbGetQuery(con, "SELECT * FROM v_always_green_sweep WHERE metric='total_cover_floor' AND scope='non_treed'")
dbDisconnect(con)
zcol  <- grep("fid|OBJECTID_1", names(zones), value = TRUE)[1]
ref_z <- zones[zones[[zcol]] %in% ref_fids, ]
cat("reference zones matched in the 8058 layer:", nrow(ref_z), "of 4 (key:", zcol, ")\n")

SURF <- list(list("total_cover_floor", 75, "primary"),
             list("total_cover_floor", 79, "sensitivity_max_components"),
             list("total_cover_floor", 82, "sensitivity_lower_bound"),
             list("green_share_floor", 50, "primary_majority_green"))

## ---------------------------------------------------------------- 1. GeoPackage
## 🔴 POLYGONISE BY COMPONENT ID, NEVER BY RE-SPLITTING THE BOOLEAN.
## The components are labelled with 8-connectivity (queen). Polygonising a boolean
## and casting MULTIPOLYGON -> POLYGON splits at every diagonal pinch point, i.e.
## silently reverts to ROOK - which turned 40 green-share components into 26 polygons
## and dropped 219 ha when the sub-parts fell back under the 5 ha filter. Dissolving
## by the component-id raster keeps the GeoPackage identical to the boolean surface
## and to T3_persistence_vs_hydrology.csv. Adrian overlays the GeoPackage, so a
## vector/raster disagreement here would be an error he inherits, not one we keep.
if (file.exists(GPKG)) file.remove(GPKG)
for (s in SURF) {
  metric <- s[[1]]; thr <- s[[2]]; role <- s[[3]]
  lr <- rast(file.path(RAS_DIR, sprintf("persistence_%s_ge%d_components_8058.tif", metric, thr)))
  names(lr) <- "component_id"
  pc <- as.polygons(lr, dissolve = TRUE) |> st_as_sf()
  pc <- pc[pc$component_id > 0, ]                       # 0 is nodata, not a component
  pc$area_ha <- as.numeric(st_area(pc)) / 1e4
  pc$metric <- metric; pc$threshold <- thr; pc$threshold_role <- role
  pc$in_reference_paddock <- lengths(st_intersects(pc, st_union(ref_z))) > 0
  pc <- pc[, c("component_id", "metric", "threshold", "threshold_role",
               "area_ha", "in_reference_paddock")]
  lyr <- sprintf("persistence_%s_ge%d", metric, thr)
  st_write(pc, GPKG, layer = lyr, quiet = TRUE, append = FALSE)
  # the vector must reconcile with the component table, or the package is wrong
  ref <- comp[comp$metric == metric & comp$threshold == thr, ]
  cat(sprintf("  gpkg %-38s %3d features %9.2f ha | table %3d %9.2f ha | %s\n",
              lyr, nrow(pc), sum(pc$area_ha), nrow(ref), sum(ref$area_ha),
              if (nrow(pc) == nrow(ref) &&
                  abs(sum(pc$area_ha) - sum(ref$area_ha)) < 0.01) "RECONCILES" else "!! MISMATCH"))
}
st_write(bounds, GPKG, layer = "gayini_boundary", quiet = TRUE, append = FALSE)
st_write(ref_z,  GPKG, layer = "reference_paddocks", quiet = TRUE, append = FALSE)
cat("wrote", GPKG, "\n  layers:", paste(st_layers(GPKG)$name, collapse = ", "), "\n")

## ---------------------------------------------------------------- 2. README
readme <- c(
  "# T3 persistence package - for the LiDAR overlay",
  "", "Generated 3 August 2026 - T3 Gate E. Spec docs/T3_always_green_threshold.md v3.",
  "", "## Read this first: there is no headline threshold",
  "", "Gate B1 swept the total-cover floor from 40 to 90 and found **no natural break**.",
  "Elasticity is 5-9% of area lost per +1 pp from t=40 to 75, then accelerates",
  "monotonically (13.5% at 78, 22.5% at 80, 40.4% at 82, 69.0% at 84) with no knee and",
  "no plateau. Refugial extent on this property is a **continuum**, so any single area",
  "figure is a chosen cut, not a measured boundary.",
  "", "The overlay therefore ships at **three thresholds**: t = 75 (primary, the most",
  "stable point in the usable window), 79 (most components, on the wetness plateau) and",
  "82 (lower bound). **If your result holds at all three it is threshold-independent.**",
  "**If it holds at only one, the overlay is measuring the cut, not the country.**",
  "", "## CRS", "", "Everything is **EPSG:8058** (GDA2020 / NSW Lambert), 24.970268 m grid,",
  "2422 x 4037 cells, origin (5.264715, 0.749231).",
  "", "## The two metrics are different variables - never merge them", "",
  "| | total-cover floor | green-share floor |", "|---|---|---|",
  "| Definition | `veg_p05 >= t`: across-series 5th percentile of TOTAL veg (green PV + non-green NPV) per pixel over 140 seasonal composites WY1988-2023 | `100 * PV / total_veg >= t`, read PAIRED in the season that sets each pixel's total-veg 5th-percentile order statistic |",
  "| Question | how much cover survives the worst seasons | when cover is at its worst, is what remains still alive |",
  "| Thresholds shipped | 75, 79, 82 | 50 (majority green, by definition of majority) |",
  "| Measured on | the 8058 census grid | the **native 30 m EPSG:3577** grid |",
  "", "**The green-share MEASURED area is 6,457.95 ha** (71,755 px x 0.09 ha at native",
  "30 m EPSG:3577, `green_frac_pct > 50`). The 8058 surface in this package is a bilinear",
  "reprojection thresholded on the 8058 grid - a different operation - and its area",
  "(3,744.20 ha over the raster extent, 3,363.36 ha over the census footprint) is **not**",
  "the measured area. Do not quote it as one. The older **4,474.03 ha** figure is the",
  "native pixel *count* multiplied by the 8058 pixel area; it is an arithmetic conversion",
  "of a count and is not what a correct reprojection produces either.",
  "", "## Pixel constant", "",
  "`PIXEL_AREA_HA = 0.062351428` ha, DERIVED as `24.970268^2 / 1e4`. Never 0.0625 - the",
  "25 m nominal inflates every area by 0.238%.",
  "", "## Contents", "",
  "- `persistence_{metric}_ge{t}_8058.tif` - boolean surfaces, 1 = persistent, 0 = not,",
  "  255 = nodata. **Components smaller than 5 ha are already removed.**",
  "- `T3_persistence_polygons_8058.gpkg` - one layer per metric/threshold, one polygon",
  "  per component >= 5 ha, plus `gayini_boundary` and `reference_paddocks`.",
  "- `../../tables/T3_persistence_vs_hydrology.csv` - per component: area, mean and",
  "  median flood frequency, % inside a reference paddock, scope filter, pixel constant.",
  "", "## Scope", "",
  "**non_treed**: `treed_context_flag = 0 AND regime_band <> 'context'` - 9 strata,",
  "988,829 px with finite p05. Treed Floodplain Woodland is context and is excluded from",
  "reporting entirely. Connectivity is 8 (queen); queen vs rook changes component counts",
  "by at most 2 at every candidate cut.",
  "", "## Distance to channel: ABSENT", "",
  "**No channel or watercourse layer is registered** in `spatial_layer_asset` (9 rows) or",
  "present anywhere under `Input/`. `dist_to_nearest_channel_m` is therefore NULL in the",
  "component table. The only hydrological geometry available is `irrigation_bank_cuts`",
  "(1,158 points), which is Task J **irrigation infrastructure, not natural channel** -",
  "substituting it would be a category error. Mean flood frequency is used as the",
  "available proxy, and it is a proxy, not a channel test.",
  "", "## Caveat that travels with every polygon", "",
  "FC is natively 30 m and these products are reported on the 24.97 m census grid.",
  "**Polygon edges are finer than the source supports.** Do not over-interpret them.")
writeLines(readme, file.path(RAS_DIR, "README.md"))
cat("wrote", file.path(RAS_DIR, "README.md"), "\n")

## ---------------------------------------------------------------- 3. Figure C
tc75 <- rast(file.path(RAS_DIR, "persistence_total_cover_floor_ge75_8058.tif"))
gs50 <- rast(file.path(RAS_DIR, "persistence_green_share_floor_ge50_8058.tif"))
both <- c(tc75, gs50); names(both) <- c("tc", "gs")
comb <- terra::app(both, function(x) ifelse(is.na(x[1]) | is.na(x[2]), NA,
                                            x[1] + 2 * x[2]))
agg <- terra::aggregate(comb, fact = 3, fun = "modal", na.rm = TRUE)
d <- as.data.frame(agg, xy = TRUE, na.rm = TRUE); names(d)[3] <- "cls"
d <- d[d$cls > 0, ]
d$lab <- factor(d$cls, levels = c(1, 2, 3),
                labels = c("total-cover floor only (veg_p05 >= 75)",
                           "green-share floor only (>= 50% green)",
                           "BOTH"))
p_c <- ggplot() +
  geom_sf(data = bounds, fill = "grey97", colour = "grey55", linewidth = 0.45) +
  geom_sf(data = zones, fill = NA, colour = "grey78", linewidth = 0.22) +
  geom_raster(data = d, aes(x, y, fill = lab)) +
  geom_sf(data = ref_z, fill = NA, colour = "#b03a2e", linewidth = 0.75) +
  scale_fill_manual(values = c("#2874a6", "#48a860", "#f0c419"), name = NULL, drop = FALSE) +
  coord_sf(crs = st_crs(8058), datum = st_crs(8058)) +
  guides(fill = guide_legend(nrow = 3)) +
  labs(title = "T3 Gate C - the two persistence surfaces: total-cover floor >= 75 and green-share floor >= 50",
       subtitle = paste("Thresholds are OPERATIONAL cuts, not measured boundaries - Gate B1 found no natural break.",
                        "Red outlines are the four\nreference paddocks (Bala 26/27/28/29ca).",
                        "Grey outlines are management zones. NO CHANNEL LAYER IS REGISTERED, so none is drawn."),
       x = "Easting EPSG:8058 (m)", y = "Northing EPSG:8058 (m)",
       caption = paste("Support: pixel. Components < 5 ha removed. non_treed scope (9 strata).",
                       "Displayed at 3x modal aggregation.\n", CAVEAT)) +
  theme_minimal(base_size = 11) +
  theme(plot.title = element_text(face = "bold", size = 11.2),
        plot.subtitle = element_text(size = 9, colour = "grey25", lineheight = 1.15),
        plot.caption = element_text(size = 8, colour = "grey35", hjust = 0, lineheight = 1.2),
        legend.position = "bottom", panel.grid = element_blank(),
        panel.background = element_rect(fill = "white", colour = NA))

gayini_write_and_register_figure(
  plot = p_c, path = file.path(FIG_DIR, "T3_C_persistence_map.png"),
  title = "T3 Gate C - both persistence surfaces over the property",
  caption = paste0("Support: pixel. ", NOBREAK, " Total-cover floor = census veg_p05 >= 75 ",
    "(across-series 5th percentile of total veg, green PV + non-green NPV, over 140 seasonal ",
    "composites WY1988-2023). Green-share floor = 100 * PV / total_veg >= 50 read paired at each ",
    "pixel's total-veg p05 season - a DIFFERENT VARIABLE, measured on the native 30 m EPSG:3577 ",
    "grid where its area is 6,457.95 ha; the 8058 rendering here is a reprojection, not a ",
    "re-measurement. Scope non_treed (treed_context_flag = 0 AND regime_band <> 'context'), ",
    "components < 5 ha removed, 8-connectivity. Reference paddocks (red) are the four ",
    "grazing_excluded = 1 zones; L-01 applies - the management zone is not an ecological unit and ",
    "no number may be attributed to a fence line without decomposing by community first. ",
    "NO CHANNEL LAYER IS REGISTERED anywhere in the project, so no channel overlay is drawn and ",
    "distance-to-channel is absent from the component table. CAVEAT: ", CAVEAT),
  support_level = "pixel", figure_level = "diagnostic", run_id = "T3_gateC",
  width = 12, height = 8, dpi = 150,
  provenance_note = "T3 Gate C. Spec v3. Thresholds are operational, not headline.")

## ---------------------------------------------------------------- 4. Figure D
p05 <- rast("Output/rasters/veg_percentiles_8058/total_veg_p05_8058.tif")
cls <- rast("Output/rasters/veg_regime_class_8058.tif")
levels(cls) <- NULL; coltab(cls) <- NULL
nt  <- cls %in% c(11, 12, 13, 21, 22, 23, 31, 32, 33)
p05nt <- terra::mask(p05, nt, maskvalues = c(0, NA), updatevalue = NA)
sm <- lapply(c(70, 75, 80, 85), function(t) {
  a <- terra::aggregate(p05nt >= t, fact = 4, fun = "mean", na.rm = TRUE)
  df <- as.data.frame(a, xy = TRUE, na.rm = TRUE); names(df)[3] <- "frac"
  df$t <- t; df[df$frac > 0, ]
})
smd <- bind_rows(sm)
lab <- sweep %>% filter(threshold %in% c(70, 75, 80, 85)) %>%
  transmute(t = threshold, lab = sprintf("t = %d\n%s ha\n%d components >= 5 ha\n%.0f%%/pp elasticity",
                                         threshold, comma(round(area_ha)), n_components_ge_5ha,
                                         c(8.7, 8.0, 22.5, 79.8)[match(threshold, c(70, 75, 80, 85))]))
smd$facet <- factor(smd$t, levels = c(70, 75, 80, 85),
                    labels = lab$lab[match(c(70, 75, 80, 85), lab$t)])

p_d <- ggplot(smd) +
  geom_sf(data = bounds, fill = "grey96", colour = "grey60", linewidth = 0.3) +
  geom_raster(aes(x, y, fill = frac)) +
  facet_wrap(~facet, ncol = 2) +
  scale_fill_gradient(low = "#cfe3f2", high = "#12456e", name = "fraction of\ncell above t",
                      limits = c(0, 1)) +
  coord_sf(crs = st_crs(8058), datum = st_crs(8058)) +
  labs(title = "T3 Gate D - what the threshold choice buys, and what it costs",
       subtitle = paste("From 8,300 ha in 75 components at t=75 to 106 ha in ONE component at t=85.",
                        "There is no natural break anywhere\nin this range - the surface simply thins.",
                        "t=85 cannot test an overlay against anything."),
       x = NULL, y = NULL,
       caption = paste("Support: pixel. non_treed scope. Displayed at 4x mean aggregation, so a",
                       "cell shows the FRACTION of its 4x4 block above t.\nAreas and component counts",
                       "are from v_always_green_sweep, not from this render.", CAVEAT)) +
  theme_minimal(base_size = 10) +
  theme(plot.title = element_text(face = "bold", size = 12),
        plot.subtitle = element_text(size = 9, colour = "grey25", lineheight = 1.15),
        plot.caption = element_text(size = 7.8, colour = "grey35", hjust = 0, lineheight = 1.2),
        strip.text = element_text(size = 8.2, lineheight = 1.1),
        axis.text = element_blank(), panel.grid = element_blank())

gayini_write_and_register_figure(
  plot = p_d, path = file.path(FIG_DIR, "T3_D_threshold_sensitivity.png"),
  title = "T3 Gate D - total-cover floor small multiples at 70 / 75 / 80 / 85",
  caption = paste0("Support: pixel. ", NOBREAK, " Small multiples of the total-cover floor ",
    "(census veg_p05 >= t) at t = 70 / 75 / 80 / 85, non_treed scope. Areas and component counts ",
    "in the panel labels come from v_always_green_sweep, not from this render, which is ",
    "4x mean-aggregated for display so each displayed cell shows the fraction of its block above ",
    "t. The progression is 12,640.75 ha / 125 components at 70, 8,300.41 / 75 at 75, ",
    "4,179.29 / 82 at 80, and 106.12 ha in ONE component at 85. No natural break exists anywhere ",
    "in this range; the decline is smooth and the surface simply thins, which is why no headline ",
    "threshold is set. CAVEAT: ", CAVEAT),
  support_level = "pixel", figure_level = "diagnostic", run_id = "T3_gateD",
  width = 11, height = 8.4, dpi = 150,
  provenance_note = "T3 Gate D. Spec v3. Evidence for the no-single-threshold decision.")

## ---------------------------------------------------------------- 5. Figure E
comp$lab <- factor(paste0(ifelse(comp$metric == "total_cover_floor", "total-cover >= ",
                                 "green-share >= "), comp$threshold),
                   levels = c("total-cover >= 75", "total-cover >= 79",
                              "total-cover >= 82", "green-share >= 50"))
BASE <- 23.32
p_e <- ggplot(comp, aes(area_ha, flood_freq_mean)) +
  annotate("rect", xmin = 4, xmax = Inf, ymin = -Inf, ymax = BASE,
           fill = "#f7d9d5", alpha = 0.45) +
  geom_hline(yintercept = BASE, linetype = "22", colour = "#7b241c", linewidth = 0.55) +
  annotate("text", x = 5.2, y = BASE - 2.6, hjust = 0, size = 3, colour = "#7b241c",
           label = "non_treed baseline 23.32% - components below this line would be DRIER than average ground") +
  geom_point(aes(colour = lab, shape = in_reference_paddock == 1), size = 2.1, alpha = 0.85) +
  scale_x_log10(labels = label_comma(accuracy = 1)) +
  scale_colour_manual(values = c("#2874a6", "#1f4e79", "#7d3c98", "#48a860"), name = NULL) +
  scale_shape_manual(values = c(16, 17), name = NULL,
                     labels = c("outside reference paddocks", "inside a reference paddock")) +
  guides(colour = guide_legend(nrow = 2), shape = guide_legend(nrow = 2)) +
  labs(title = "T3 Gate E - persistent components sit on wet ground, and it holds at every threshold",
       subtitle = paste("Area-weighted mean flood frequency is 48.5% at t=75, 50.1% at 79 and 46.3% at 82,",
                        "against a non_treed baseline of 23.3%\n- roughly 2x, and stable across the cuts.",
                        "Green-share components are wetter still at 57.0%. 12 of 257 components DO fall",
                        "below the\nbaseline, but they hold 144.6 ha of 14,844.7 (0.97%); at t=79 and t=82",
                        "none do."),
       x = "component area (ha, log scale)", y = "mean between-year flood frequency (%), pixel support",
       caption = paste("This is the channel expectation tested with a PROXY, not with channels:",
                       "no channel layer is registered anywhere in the project.\nTriangles mark components",
                       ">50% inside a reference paddock - all four are Bala, so treatment is perfectly",
                       "nested within block\nand L-01 applies. Do not read the enrichment as a management effect.")) +
  theme_minimal(base_size = 11) +
  theme(plot.title = element_text(face = "bold", size = 11.6),
        plot.subtitle = element_text(size = 9, colour = "grey25", lineheight = 1.15),
        plot.caption = element_text(size = 8, colour = "grey35", hjust = 0, lineheight = 1.2),
        legend.position = "bottom", legend.box = "vertical", legend.spacing.y = unit(0, "cm"),
        panel.grid.minor = element_blank())

gayini_write_and_register_figure(
  plot = p_e, path = file.path(FIG_DIR, "T3_E_components_vs_floodfreq.png"),
  title = "T3 Gate E - component area vs mean flood frequency, reference paddocks marked",
  caption = paste0("Support: pixel. ", NOBREAK, " Each point is one connected component >= 5 ha ",
    "(8-connectivity) from Output/tables/T3_persistence_vs_hydrology.csv, 257 components across ",
    "four surfaces. FINDING: persistent ground is roughly twice as flood-exposed as non-treed ",
    "ground generally, and the result is THRESHOLD-INDEPENDENT - area-weighted mean flood ",
    "frequency is 48.49% at t=75, 50.13% at t=79 and 46.31% at t=82 against a non_treed baseline ",
    "of 23.32%. Green-share components are wetter still (57.00%). THE EXCEPTIONS, stated rather ",
    "than rounded away: 12 of the 257 components DO fall below the baseline - 5 total-cover ",
    "components at t=75 (minimum 13.32%) and 7 green-share components (minimum 6.94%) - but they ",
    "are all small and together hold 144.59 ha of 14,844.69 ha, 0.97% of the persistent area. At ",
    "t=79 and t=82 none fall below. The below-baseline green-share patches are the 'green but dry' ",
    "cases and are not explained here. IMPORTANT: this tests the channel expectation with a ",
    "PROXY. No channel or watercourse layer is registered in spatial_layer_asset or present under ",
    "Input/; the only hydrological geometry is irrigation_bank_cuts, which is Task J irrigation ",
    "infrastructure and not natural channel, so distance-to-channel is NULL in the component ",
    "table. Triangles mark components more than 50% inside a reference paddock; all four ",
    "reference zones are Bala, so treatment is perfectly nested within block, and L-01 applies - ",
    "the enrichment must NOT be read as a management effect. CAVEAT: ", CAVEAT),
  support_level = "pixel", figure_level = "diagnostic", run_id = RUN_ID,
  width = 11, height = 7.6, dpi = 150,
  provenance_note = "T3 Gate E point 3. Spec v3. Channel layer absent; flood frequency is the proxy.")

cat("\nGates C/D/E vectors and figures complete\n")
