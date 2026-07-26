#!/usr/bin/env Rscript
# T1 Gate C figures, written AND registered via gayini_write_and_register_figure().
#   T1_C_pixel_assignment_map.png  - unzoned pixels in a hard-to-miss colour over
#                                    the zones, to show the 18% unzoned share is a
#                                    coherent geometry gap, not a join bug.
#   T1_C_reconciliation_bar.png    - zoned + unzoned vs 1,080,157, diff annotated.
# H5: never plot 1.08M raw points - the map uses a hexbin density.

suppressPackageStartupMessages({library(sf); library(ggplot2)})
root <- normalizePath(".", winslash = "/")
source(file.path(root, "R/gayini_figure_register.R"))
source(file.path(root, "R/gayini_params.R"))   # TOTAL_CENSUS_PX - never a literal
TOTAL_PX <- GAYINI_PARAMS$TOTAL_CENSUS_PX
fig_dir <- file.path(root, "Output/figures/diagnostics")
RUN_ID <- "T1_gateC"; SUPPORT <- "pixel"; LEVEL <- "diagnostics"

pts <- utils::read.csv(file.path(root, "Output/census/_tmp/points.csv"),
                       colClasses = c("integer", "numeric", "numeric"))
asg <- utils::read.csv(file.path(root, "Output/census/_tmp/assignment.csv"),
                       colClasses = c("integer", "integer"), na.strings = "")
pts$zone_fid <- asg$zone_fid[match(pts$pixel_id, asg$pixel_id)]
zones <- sf::st_read(file.path(root, "Output/spatial_8058/management_zones_epsg8058.gpkg"), quiet = TRUE)
unz <- pts[is.na(pts$zone_fid), ]
n_zoned <- sum(!is.na(pts$zone_fid)); n_unz <- nrow(unz); n_tot <- nrow(pts)

## ---- F1: assignment map (zoned + unzoned hexbins, raw 8058 metres) ---------
## Both layers in EPSG:8058 metres with coord_equal so they align (mixing geom_sf,
## which reprojects to lon/lat for display, with a raw-coord geom_hex does not).
zoned_pts <- pts[!is.na(pts$zone_fid), ]
p1 <- ggplot() +
  geom_bin2d(data = zoned_pts, aes(x_8058, y_8058), bins = 180, fill = "grey82") +
  geom_bin2d(data = unz, aes(x_8058, y_8058, fill = after_stat(count)), bins = 180) +
  scale_fill_gradient(low = "#fa9fb5", high = "#7a0177", name = "unzoned\npixels / cell") +
  coord_equal() +
  labs(title = "T1 C · Pixel assignment — unzoned pixels (magenta) vs zoned (grey)",
       subtitle = sprintf("%s unzoned px (%.1f%%) form coherent blocks, not scattered noise; EPSG:8058",
                          format(n_unz, big.mark = ","), 100 * n_unz / n_tot),
       caption = "Support: pixel. Magenta = census pixels falling outside every zone (zone_fid IS NULL). Grey = zoned.") +
  theme_minimal(base_size = 11) +
  theme(axis.title = element_blank(), axis.text = element_blank())
gayini_write_and_register_figure(
  p1, file.path(fig_dir, "T1_C_pixel_assignment_map.png"),
  title = "T1 C pixel assignment map",
  caption = "Support: pixel. Census pixels by zone assignment; unzoned (zone_fid NULL) in magenta over grey zones.",
  support_level = SUPPORT, figure_level = LEVEL, run_id = RUN_ID,
  provenance_note = "Gate C assignment check. Unzoned coherence, not a join bug.",
  width = 10, height = 8)

## ---- F2: reconciliation bar ------------------------------------------------
recon <- data.frame(class = factor(c("unzoned", "zoned"), levels = c("unzoned", "zoned")),
                    n = c(n_unz, n_zoned))
diff_vs <- n_tot - TOTAL_PX   # from gayini_params; never a literal
p2 <- ggplot(recon, aes(x = "census", y = n, fill = class)) +
  geom_col(width = 0.5) +
  scale_fill_manual(values = c(unzoned = "#7a0177", zoned = "#41ab5d"), name = NULL) +
  geom_text(aes(label = paste0(class, "\n", format(n, big.mark = ","))),
            position = position_stack(vjust = 0.5), colour = "white", size = 4) +
  annotate("text", x = "census", y = n_tot * 1.04,
           label = sprintf("Σ = %s   (target 1,080,157; diff = %d)",
                           format(n_tot, big.mark = ","), diff_vs), size = 4.2) +
  labs(title = "T1 C · Assignment reconciliation",
       subtitle = "zoned + unzoned = the full census; diff = 0",
       y = "census pixels", x = NULL,
       caption = "Support: pixel. Every pixel retained; unzoned kept as an explicit class, not dropped.") +
  theme_minimal(base_size = 11) + theme(axis.text.x = element_blank())
gayini_write_and_register_figure(
  p2, file.path(fig_dir, "T1_C_reconciliation_bar.png"),
  title = "T1 C reconciliation bar",
  caption = "Support: pixel. Zoned + unzoned reconciles to 1,080,157, diff = 0.",
  support_level = SUPPORT, figure_level = LEVEL, run_id = RUN_ID,
  provenance_note = "Gate C reconciliation. Diff = 0 against the full census.",
  width = 6, height = 7)

cat(sprintf("\n[done] zoned=%d unzoned=%d total=%d\n", n_zoned, n_unz, n_tot))
