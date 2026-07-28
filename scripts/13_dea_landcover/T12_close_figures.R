#!/usr/bin/env Rscript
# T12 close-out figures: (1) sensor-era on/off CTV gap (methods slide),
# (2) persistence map, (3) class snapshots 1990/2005/2016/2024 (official QML palette).
# Maps observe the off-property disclosure constraint: landscape scale, NO cadastral
# boundaries, NO holdings named (no vector overlays at all).

suppressPackageStartupMessages({library(terra); library(ggplot2)})
root <- "d:/Github_repos/Gayini"
figdir <- file.path(root, "figures/diagnostics")
tabdir <- file.path(root, "Output/tables")
CAP <- "DEA Land Cover is a modelled national product, not a record of land use. Not independent of the Gayini census."

dir <- file.path(root, "Input/landsat_landcover/level3")
files <- sort(list.files(dir, pattern = "^LLC3_\\d{4}_MGA54\\.tif$", full.names = TRUE))
years <- as.integer(sub(".*LLC3_(\\d{4}).*", "\\1", basename(files)))
dea <- rast(files); names(dea) <- years

# ---- (1) sensor-era gap (off - on), the methods-slide figure -----------------
d <- read.csv(file.path(tabdir, "T12_DEA_positive_control_by_year.csv"))
eras <- list("L5-only\n1988-99" = 1988:1999, "L5+L7\n2000-02" = 2000:2002,
             "L5deg+L7\n2003-10" = 2003:2010, "L7-only\n2011-12" = 2011:2012,
             "L8+L7\n2013-21" = 2013:2021, "L8+L9\n2022-25" = 2022:2025)
g <- do.call(rbind, lapply(names(eras), function(e) {
  s <- d[d$year %in% eras[[e]], ]
  data.frame(era = e, on = mean(s$onprop_ctv_pct), off = mean(s$control_ctv_pct),
             gap_off_minus_on = mean(s$control_ctv_pct) - mean(s$onprop_ctv_pct))
}))
g$era <- factor(g$era, levels = names(eras))
write.csv(g, file.path(tabdir, "T12_DEA_sensor_era_gap.csv"), row.names = FALSE)
print(g)
gg <- ggplot(g, aes(era, gap_off_minus_on, fill = gap_off_minus_on > 5)) +
  geom_col(width = 0.65) + geom_hline(yintercept = 0, colour = "#3A3A3A") +
  geom_text(aes(label = sprintf("%+.1f", gap_off_minus_on)), vjust = ifelse(g$gap_off_minus_on >= 0, -0.4, 1.2), size = 3.4) +
  scale_fill_manual(values = c(`FALSE` = "#B7B7A6", `TRUE` = "#0E7A5F"), guide = "none") +
  labs(title = "DEA Land Cover (modelled) — CTV separates cultivated from uncultivated only where observation density is adequate",
       subtitle = "Off-property (irrigation country) minus on-property (Gayini) mean CTV %, by Landsat sensor era. Distinguishable only in the last era.",
       x = NULL, y = "off - on CTV (pp)", caption = CAP) +
  theme_minimal(base_size = 11) + theme(plot.title = element_text(size = 10.5))
ggsave(file.path(figdir, "T12_DEA_sensor_era_gap.png"), gg, width = 8.5, height = 4.6, dpi = 130)

# ---- per-pixel CTV persistence fraction raster ------------------------------
ctv_cnt <- sum(dea == 111, na.rm = TRUE)
val_cnt <- sum(!is.na(dea), na.rm = TRUE)
frac <- ctv_cnt / val_cnt
frac[val_cnt == 0] <- NA

# ---- (2) persistence map (landscape; no cadastral, no holdings) -------------
png(file.path(figdir, "T12_DEA_persistence_map.png"), width = 1100, height = 900, res = 130)
ramp <- colorRampPalette(c("#F1EDE2", "#7FB09A", "#0E7A5F"))(100)
plot(frac, col = ramp, range = c(0, 1), axes = FALSE, mar = c(2, 2, 4, 4),
     main = "DEA Land Cover (modelled) — CTV persistence fraction 1988-2025 (landscape; no cadastre)")
mtext(CAP, side = 1, line = 0.5, cex = 0.6)
mtext("Off-property context shown at landscape scale; no property/paddock boundaries drawn, no holdings named.",
      side = 3, line = 0.1, cex = 0.7)
dev.off()

# ---- (3) class snapshots 1990/2005/2016/2024, official QML palette -----------
pal <- data.frame(value = c(111, 112, 124, 215, 216, 220, 255),
                  col = c("#acbc2d", "#0e7912", "#1ebf79", "#da5c69", "#f3ab69", "#4d9fdc", "#ffffff"))
snap_years <- c(1990, 2005, 2016, 2024)
png(file.path(figdir, "T12_DEA_class_snapshots.png"), width = 1200, height = 1000, res = 125)
par(mfrow = c(2, 2), mar = c(1.5, 1.5, 2.5, 1))
for (y in snap_years) {
  r <- dea[[match(y, years)]]
  present <- sort(unique(values(r, mat = FALSE)))
  present <- present[!is.na(present)]
  ct <- pal[pal$value %in% present, ]
  coltab(r) <- data.frame(value = ct$value, col = ct$col)
  plot(r, col = ct$col, axes = FALSE, legend = FALSE, main = paste0("DEA Level 3 — ", y))
}
mtext("DEA Land Cover Level 3 (modelled) — CTV #acbc2d, NTV #0e7912, NS #f3ab69, Water #4d9fdc | landscape, no cadastre",
      side = 1, outer = TRUE, line = -1.2, cex = 0.68)
dev.off()

cat("\n[done] figures: T12_DEA_sensor_era_gap.png, T12_DEA_persistence_map.png, T12_DEA_class_snapshots.png\n")
