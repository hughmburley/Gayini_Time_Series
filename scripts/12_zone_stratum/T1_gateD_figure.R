#!/usr/bin/env Rscript
# T1 Gate D figure - the grazed/ungrazed floor contrast and its ROBUSTNESS.
# Shows veg_p05_delta three ways per stratum so the apparent effect's collapse is
# visible: (1) all-zones pixel-weighted (confounded: 4 Bala-ungrazed vs 60 grazed
# incl. Mara/Dinan), (2) Bala-only pixel-weighted (block-controlled), (3) Bala
# zone-support (n = zones, the honest denominator). flood_freq_delta and
# n_ungrazed_zones annotated. Written+registered via write_and_register_figure().

suppressPackageStartupMessages({library(ggplot2)})
root <- normalizePath(".", winslash = "/")
source(file.path(root, "R/gayini_figure_register.R"))
fig_dir <- file.path(root, "Output/figures/diagnostics")

d <- utils::read.csv(file.path(root, "Output/tables/T1_gateD_contrast.csv"), stringsAsFactors = FALSE)
r <- utils::read.csv(file.path(root, "Output/tables/T1_gateD_robustness.csv"), stringsAsFactors = FALSE)
m <- merge(d, r, by = c("community", "regime_band"))
m$comm <- vapply(strsplit(m$community, " "), `[`, character(1), 1)
m$band <- factor(m$regime_band, levels = c("low", "mid", "high"))

long <- rbind(
  data.frame(comm = m$comm, band = m$band, method = "1 all-zones px-weighted (confounded)",
             value = m$veg_p05_delta),
  data.frame(comm = m$comm, band = m$band, method = "2 Bala-only px-weighted (block-controlled)",
             value = m$veg_p05_delta_bala_pxwtd),
  data.frame(comm = m$comm, band = m$band, method = "3 Bala zone-support (n = zones)",
             value = m$veg_p05_delta_zonesupport))
long$method <- factor(long$method, levels = unique(long$method))

p <- ggplot(long, aes(band, value, fill = method)) +
  geom_col(position = position_dodge(width = 0.85), width = 0.8) +
  geom_hline(yintercept = 0, colour = "grey40", linewidth = 0.3) +
  geom_point(data = m, aes(band, flood_freq_delta), inherit.aes = FALSE,
             shape = 4, size = 2.4, stroke = 1, colour = "#2171b5") +
  geom_text(data = m, aes(band, y = -8, label = paste0("nU=", n_ungrazed_zones)),
            inherit.aes = FALSE, size = 2.6, colour = "grey30") +
  scale_fill_manual(values = c("#bdbdbd", "#74c476", "#238b45"), name = NULL) +
  facet_wrap(~comm, nrow = 1) +
  labs(title = "T1 D · Grazed/ungrazed floor contrast collapses under block control and zone support",
       subtitle = "veg_p05 delta (ungrazed − grazed), pp. Blue ✕ = flood_freq delta. All 4 ungrazed zones are Bala paddocks.",
       x = "wetness band (within community)", y = "veg_p05 delta (pp)",
       caption = paste("Support: pixel (aggregation_unit = zone_stratum). nU = ungrazed zones (n).",
                       "Riverine +7.5..+8.3 (grey) falls to +3.6/+0.1/-2.1 at zone support (dark);",
                       "the pixel-weighted effect is one paddock (Bala 29ca), not grazing.")) +
  theme_minimal(base_size = 11) + theme(legend.position = "top")

gayini_write_and_register_figure(
  p, file.path(fig_dir, "T1_D_matched_contrast.png"),
  title = "T1 D matched contrast and robustness",
  caption = paste("Support: pixel. veg_p05 delta three ways (all-zones px, Bala-only px,",
                  "Bala zone-support) per stratum; the Riverine signal collapses at zone support."),
  support_level = "pixel", figure_level = "diagnostics", run_id = "T1_gateD",
  provenance_note = "Gate D robustness. All ungrazed zones are Bala; effect is one paddock, not grazing.",
  width = 12, height = 6)
cat("\n[done] T1_D_matched_contrast.png\n")
