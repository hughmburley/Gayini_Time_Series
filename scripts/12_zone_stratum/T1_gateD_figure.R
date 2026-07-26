#!/usr/bin/env Rscript
# T1 Gate D figure - matched grazed/ungrazed contrast, one panel per community,
# veg_p05_delta beside flood_freq_delta per band, cells < 3,000 px greyed+labelled.
# Written AND registered via gayini_write_and_register_figure().

suppressPackageStartupMessages({library(ggplot2)})
root <- normalizePath(".", winslash = "/")
source(file.path(root, "R/gayini_figure_register.R"))
fig_dir <- file.path(root, "Output/figures/diagnostics")

d <- utils::read.csv(file.path(root, "Output/tables/T1_gateD_contrast.csv"),
                     stringsAsFactors = FALSE)
d$community <- vapply(strsplit(d$community, " "), `[`, character(1), 1)   # short name
d$regime_band <- factor(d$regime_band, levels = c("low", "mid", "high"))

long <- rbind(
  data.frame(community = d$community, band = d$regime_band,
             metric = "veg_p05 delta (floor)", value = d$veg_p05_delta,
             flagged = d$min_cell_n == 1),
  data.frame(community = d$community, band = d$regime_band,
             metric = "flood_freq delta (wetness confound)", value = d$flood_freq_delta,
             flagged = d$min_cell_n == 1))
long$metric <- factor(long$metric,
                      levels = c("veg_p05 delta (floor)", "flood_freq delta (wetness confound)"))
lab <- d[d$min_cell_n == 1, ]

p <- ggplot(long, aes(band, value, fill = metric, alpha = flagged)) +
  geom_col(position = position_dodge(width = 0.8), width = 0.7) +
  geom_hline(yintercept = 0, colour = "grey40", linewidth = 0.3) +
  geom_text(data = lab, aes(x = regime_band, y = pmax(veg_p05_delta, flood_freq_delta) + 1.5),
            label = "n < 3,000 px", inherit.aes = FALSE, size = 2.7, colour = "grey30") +
  scale_fill_manual(values = c("veg_p05 delta (floor)" = "#238b45",
                               "flood_freq delta (wetness confound)" = "#2171b5"),
                    name = NULL) +
  scale_alpha_manual(values = c("FALSE" = 1, "TRUE" = 0.35), guide = "none") +
  facet_wrap(~community, nrow = 1) +
  labs(title = "T1 D · Matched grazed/ungrazed contrast within census stratum",
       subtitle = "ungrazed − grazed, pixel-weighted. Floor difference beside the wetness confound; greyed = cell < 3,000 px",
       x = "wetness band (within community)", y = "ungrazed − grazed (pp)",
       caption = paste("Support: pixel (aggregation_unit = zone_stratum). Nine non-treed strata.",
                       "Riverine: floor difference survives matching (small flood_freq delta);",
                       "Inland-high floor gap tracks a +11 pp wetness gap.")) +
  theme_minimal(base_size = 11) + theme(legend.position = "top")

gayini_write_and_register_figure(
  p, file.path(fig_dir, "T1_D_matched_contrast.png"),
  title = "T1 D matched contrast",
  caption = "Support: pixel. Ungrazed-minus-grazed veg_p05 delta beside flood_freq delta per stratum; cells < 3,000 px greyed.",
  support_level = "pixel", figure_level = "diagnostics", run_id = "T1_gateD",
  provenance_note = "Gate D matched contrast. Floor difference vs wetness confound, nine non-treed strata.",
  width = 11, height = 6)
cat("\n[done] T1_D_matched_contrast.png\n")
