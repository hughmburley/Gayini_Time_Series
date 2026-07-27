#!/usr/bin/env Rscript
# T2 G - plot -> paddock coverage map (deliverable). The map IS the unzoned /
# Standard-grazing test. Shows the 66 plot centroids over the management zones
# (binary treatment: grazed = 14-day / not grazed = No grazing) with the unzoned
# area (property minus zones) underneath, so three findings read at a glance:
#   1. the 15 Standard-grazing plots sit in the unzoned area (no Standard zone exists)
#   2. Bala 29ca holds 13 of 24 not-grazed reference plots
#   3. the 3 stray 14-day plots (GA_018/024/045) and how close they are to a zone edge

suppressPackageStartupMessages({library(sf); library(ggplot2); library(DBI); library(RSQLite)})
sf::sf_use_s2(FALSE)
root <- normalizePath(".", winslash = "/")
source(file.path(root, "R/gayini_figure_register.R"))
source(file.path(root, "R/gayini_params.R"))
sp <- file.path(root, "Output/spatial_8058")

con <- DBI::dbConnect(RSQLite::SQLite(), file.path(root, "Output/database/Gayini_Results.sqlite"))
pj <- DBI::dbGetQuery(con, "SELECT * FROM plot_paddock")
dp <- DBI::dbGetQuery(con, "SELECT plot_id, centroid_x, centroid_y FROM dim_plot")
DBI::dbDisconnect(con)

zones <- sf::st_read(file.path(sp, "management_zones_epsg8058.gpkg"), quiet = TRUE)
bound <- sf::st_read(file.path(sp, "gayini_boundary_epsg8058.gpkg"), quiet = TRUE)
zones$treat_bin <- ifelse(zones$Treatment == "No grazing", "not grazed", "grazed (14-day)")
unzoned <- suppressWarnings(sf::st_difference(sf::st_union(bound), sf::st_union(zones)))

pts <- merge(dp, pj, by = "plot_id")
pts <- sf::st_transform(
  sf::st_as_sf(pts, coords = c("centroid_x", "centroid_y"),
               crs = GAYINI_PARAMS$CRS_PLOT_CENTROID), GAYINI_PARAMS$CRS_CANONICAL)
pts$category <- with(pts, ifelse(
  in_zone == 1 & grazing_excluded == 1, "not grazed (reference, zoned)",
  ifelse(in_zone == 1, "grazed 14-day (zoned)",
  ifelse(plot_treatment == "Standard grazing", "Standard grazing (unzoned)",
         "stray 14-day (unzoned)"))))
pts$category <- factor(pts$category, levels = c(
  "not grazed (reference, zoned)", "grazed 14-day (zoned)",
  "Standard grazing (unzoned)", "stray 14-day (unzoned)"))

# finding 3: distance of the 3 stray 14-day plots to the nearest zone edge
stray <- pts[pts$category == "stray 14-day (unzoned)", ]
d_edge <- as.numeric(sf::st_distance(stray, sf::st_union(sf::st_boundary(zones))))
stray_tbl <- data.frame(plot_id = stray$plot_id, dist_to_zone_edge_m = round(d_edge, 0))
# label position for Bala 29ca (finding 2)
b29 <- zones[zones$ManagmentZ == "Bala 29ca", ]
b29c <- sf::st_coordinates(sf::st_point_on_surface(sf::st_geometry(b29)))

cols <- c("not grazed (reference, zoned)" = "#238b45",
          "grazed 14-day (zoned)"         = "#f0a860",
          "Standard grazing (unzoned)"    = "#B2182B",
          "stray 14-day (unzoned)"        = "#6a51a3")

p <- ggplot() +
  geom_sf(data = unzoned, fill = "grey88", colour = NA) +
  geom_sf(data = zones, aes(fill = treat_bin), colour = "white", linewidth = 0.15) +
  geom_sf(data = bound, fill = NA, colour = "grey30", linewidth = 0.4) +
  scale_fill_manual(values = c("grazed (14-day)" = "#fee0b6", "not grazed" = "#c7e9c0"),
                    name = "zone treatment") +
  geom_sf(data = pts, aes(colour = category), size = 1.9) +
  geom_sf(data = stray, colour = "black", shape = 1, size = 3.4, stroke = 0.7) +
  geom_sf_text(data = stray, aes(label = plot_id), size = 2.6, nudge_y = 1200, colour = "grey15") +
  annotate("text", x = b29c[1], y = b29c[2], label = "Bala 29ca\n13 of 24\nreference plots",
           size = 2.9, fontface = "bold", colour = "#00441b") +
  scale_colour_manual(values = cols, name = "plot") +
  labs(title = "T2 G - Plot-to-paddock coverage: where the 66 plots fall vs the zone layer",
       subtitle = paste("48 of 66 plots zoned; 18 unzoned = 15 Standard-grazing (no Standard",
                        "zone exists) + 3 stray 14-day. Grey = property area with no management zone."),
       caption = paste0(
         "Support: plot. Binary treatment: grazed = 14-day rotational; Standard-grazing paddocks are absent\n",
         "from the zone layer (15 red plots, in grey unzoned area). Not grazed = the 4 reference paddocks;\n",
         "Bala 29ca alone holds 13 of 24. Stray 14-day plots (open circles) are near-boundary edge cases: ",
         paste(sprintf("%s %dm", stray_tbl$plot_id, stray_tbl$dist_to_zone_edge_m), collapse = ", "),
         "\nfrom the nearest zone edge. Centroids EPSG:8058."),
       x = NULL, y = NULL) +
  theme_minimal(base_size = 11) +
  theme(plot.caption = element_text(hjust = 0, size = 8), legend.position = "right")

gayini_write_and_register_figure(
  p, file.path(root, "Output/figures/diagnostics/T2_G_plot_paddock_coverage.png"),
  title = "T2 G plot-to-paddock coverage",
  caption = paste("Support: plot. 66 plot centroids over the management zones with the",
                  "unzoned area underneath; 15 Standard-grazing plots unzoned, Bala 29ca",
                  "holds 13 of 24 reference plots, 3 stray 14-day plots flagged."),
  support_level = "plot", figure_level = "deliverable", run_id = "T2_gateG",
  provenance_note = "plot_paddock coverage; binary treatment; Standard-grazing absent from zone layer.",
  width = 12, height = 8)
cat("stray 14-day distance to nearest zone edge (m):\n"); print(stray_tbl)
cat("[done] T2_G_plot_paddock_coverage.png\n")
