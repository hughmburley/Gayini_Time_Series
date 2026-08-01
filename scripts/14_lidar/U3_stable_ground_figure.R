# Task U · Gate U3 — the sensor step-change evidence figure.
#
# Spec: docs/LiDAR/TaskU_lidar_structural_lens_v1.2.md, Gate U3 (items 4 and 6).
#
# Two panels, because the verdict rests on two questions:
#   A  How does the observed whole-of-property FPC change compare with what stable
#      ground shows when nothing changed? (item 4 — the floor)
#   B  Does the FPC offset scale with the bb5 return-density difference? (U3.6)
#
# Reads only the CSVs written by U3_sensor_step_change.py. No number is computed
# here. R owns write AND register in one transaction.

suppressPackageStartupMessages({
  library(ggplot2); library(dplyr); library(patchwork)
  library(DBI); library(RSQLite); library(digest)
})
source("R/gayini_figure_register.R")

RUN <- "taskU_gateU3"
SG  <- "Output/tables/taskU_gateU3_stable_ground.csv"
BK  <- "Output/tables/taskU_gateU3_u36_blocks.csv"
DS  <- "Output/tables/taskU_gateU3_density_scaling.csv"
OUT <- "Output/figures/task_U/U3_sensor_step_change.png"
stopifnot(file.exists(SG), file.exists(BK), file.exists(DS))

sg <- read.csv(SG, stringsAsFactors = FALSE)
bk <- read.csv(BK, stringsAsFactors = FALSE)
ds <- read.csv(DS, stringsAsFactors = FALSE)

LAB <- c(S1_bare_stable                     = "S1 bare stable\n(Landsat-defined)",
         S2_treed_stable                    = "S2 treed stable\n(class 40, off cuts)",
         ALL_on_property_both_valid         = "OBSERVED\nwhole property",
         ALL_on_property_woody_either_epoch = "OBSERVED\nFPC > 0 either epoch")
PAL <- c(S1_bare_stable                     = "#8D6E63",   # committed bare brown
         S2_treed_stable                    = "#2E7D32",   # committed veg green
         ALL_on_property_both_valid         = "#B2182B",   # committed "drier" red
         ALL_on_property_woody_either_epoch = "#2166AC")   # committed wet blue

# ---- Panel A: the floor against the observed change -----------------------------
blk <- sg %>%
  filter(product == "bbh_fpc", grepl("^block_", grain), epoch == "2021-2009") %>%
  mutate(set = factor(stable_set, levels = rev(names(LAB))))
pxl <- sg %>%
  filter(product == "bbh_fpc", grain == "pixel_10m", epoch == "2021-2009") %>%
  mutate(set = factor(stable_set, levels = rev(names(LAB))))

pa <- ggplot(blk, aes(y = set, colour = stable_set)) +
  geom_vline(xintercept = 0, colour = "grey55", linewidth = 0.4) +
  geom_linerange(aes(xmin = p05, xmax = p95), linewidth = 1.5, alpha = 0.35) +
  geom_linerange(data = pxl, aes(xmin = p05, xmax = p95),
                 linewidth = 0.5, linetype = "dotted") +
  # hollow = pixel-grain median (every set has one); filled = block-grain median
  # (only the sets with block statistics). Without the hollow point the woody-subset
  # row would show a spread with no centre.
  geom_point(data = pxl, aes(x = median), size = 2.5, shape = 21, fill = "white",
             stroke = 0.9) +
  geom_point(aes(x = median), size = 3.1) +
  scale_y_discrete(labels = LAB) +
  scale_colour_manual(values = PAL, guide = "none") +
  labs(subtitle = paste0(
         "A · Observed change against what stable ground shows\n",
         "Thick bar = 5th-95th percentile of 500 m BLOCK-mean differences; ",
         "dotted = the same at pixel grain; dot = median."),
       x = "FPC difference, 2021 - 2009 (percentage points)", y = NULL) +
  theme_minimal(base_size = 10) +
  theme(plot.subtitle = element_text(size = 8.6, colour = "grey20", lineheight = 1.15),
        axis.text.y = element_text(size = 8, lineheight = 0.92),
        panel.grid.major.y = element_blank())

# ---- Panel B: U3.6 density scaling ----------------------------------------------
fits <- ds %>% transmute(stable_set, slope = slope_fpc_pp_per_density,
                         intercept = intercept_fpc_pp, r2 = r_squared,
                         n = n_blocks)
ann <- fits %>% mutate(lab = sprintf("slope %.4f  ·  R² %.4f  ·  n %d blocks",
                                     slope, r2, n))

pb <- ggplot(bk, aes(density_diff, fpc_diff, colour = stable_set)) +
  geom_hline(yintercept = 0, colour = "grey55", linewidth = 0.4) +
  geom_point(size = 1.25, alpha = 0.55) +
  geom_abline(data = fits, aes(slope = slope, intercept = intercept),
              colour = "grey25", linewidth = 0.6, linetype = "dashed") +
  geom_text(data = ann, aes(x = -Inf, y = Inf, label = lab), inherit.aes = FALSE,
            hjust = -0.05, vjust = 1.6, size = 2.9, colour = "grey20") +
  facet_wrap(~ stable_set, scales = "free", ncol = 2,
             labeller = as_labeller(gsub("\n", " ", LAB))) +
  scale_colour_manual(values = PAL, guide = "none") +
  labs(subtitle = paste0(
         "B · U3.6 — does the FPC offset scale with the return-density difference?\n",
         "One point per 500 m block of stable ground. Dashed line is the OLS fit."),
       x = "bb5 first-return density difference, 2021 - 2009 (returns per m²)",
       y = "FPC difference (pp)") +
  theme_minimal(base_size = 10) +
  theme(plot.subtitle = element_text(size = 8.6, colour = "grey20", lineheight = 1.15),
        strip.text = element_text(size = 8.2))

p <- (pa / pb) + plot_layout(heights = c(1, 1.45)) +
  plot_annotation(
    title = "Task U Gate U3 — sensor step-change test, Leica ALS-50 (2009) to ALS-80 (2021)",
    subtitle = paste("Stable ground is defined from LANDSAT and the vegetation class map,",
                     "NOT from the LiDAR under test - defining it on\npersistently-zero FPC",
                     "would force the difference to zero by construction."),
    theme = theme(plot.title = element_text(face = "bold", size = 11.5),
                  plot.subtitle = element_text(size = 8.4, colour = "grey25",
                                               lineheight = 1.1)))

cap <- paste(
  "Pixel support throughout; block statistics are means over 500 m blocks of pixel values.",
  "FPC is LiDAR bbh (projected foliage cover, effectively woody) and is NOT comparable to",
  "Landsat total_veg - the two are never differenced or shared on an axis.",
  "Denominator: Task U both-valid, 85,882.6 ha on-property.",
  "S1 = flood_zone in {0,1} and census total_veg p50 < 30%; S2 = veg_regime_class 40 at",
  "least 250 m from any 2018 bank cut. Neither definition uses a LiDAR value.",
  "Source Output/tables/taskU_gateU3_{stable_ground,u36_blocks,density_scaling}.csv.")

gayini_write_and_register_figure(
  plot = p, path = OUT,
  title = "Task U Gate U3 - sensor step-change test on stable ground",
  caption = cap, support_level = "pixel", figure_level = "diagnostic", run_id = RUN,
  domain = "zone_diagnostics", framing_label = "census_8058",
  provenance_note = paste(
    "Task U Gate U3 items 4 and 6. Spec docs/LiDAR/TaskU_lidar_structural_lens_v1.2.md.",
    "The verdict itself is a design-seat decision; this figure is its evidence.",
    "A density-derived correction is never applied silently."),
  width = 10.5, height = 9.5, dpi = 200)
