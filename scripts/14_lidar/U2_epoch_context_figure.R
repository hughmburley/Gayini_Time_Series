# Task U · Gate U2 — the 35-year record with both LiDAR epochs marked.
#
# Spec: docs/LiDAR/TaskU_lidar_structural_lens_v1.2.md, Gate U2.
#
# R owns write AND register in one transaction (gayini_write_and_register_figure),
# so the figure cannot land on disk unregistered. Reads only the tidy CSV emitted by
# scripts/14_lidar/U2_epoch_context.py — no number is computed here.
#
# WHY THE EPOCHS ARE SHOWN AS BANDS, NOT LINES: the project water year starts in July
# and Gate U0.6 established that flight months are unrecoverable from the delivery.
# A calendar-2009 capture therefore falls in WY2008 if flown Jan–Jun and WY2009 if
# flown Jul–Dec, and likewise at 2021. Drawing a single line would invent a fact the
# delivery does not carry.

suppressPackageStartupMessages({
  library(ggplot2); library(dplyr); library(DBI); library(RSQLite); library(digest)
})
source("R/gayini_figure_register.R")

RUN <- "taskU_gateU2"
SER <- "Output/tables/taskU_gateU2_series_35yr.csv"
OUT <- "Output/figures/task_U/U2_epoch_context_35yr.png"

stopifnot(file.exists(SER))
ser <- read.csv(SER, stringsAsFactors = FALSE, check.names = FALSE)

# Candidate water-year windows, one per capture. Must match EPOCH_CANDIDATES in the
# Python producer.
bands <- data.frame(capture = c(2009L, 2021L), lo = c(2008L, 2020L), hi = c(2009L, 2021L))
bands$label <- sprintf("%d LiDAR\nWY%d or WY%d", bands$capture, bands$lo, bands$hi)

PANEL <- c(cover = "Total vegetation cover (%)\nwithin-zone spatial, pixel-weighted",
           flood = "Annual wet fraction (%)\nper community",
           flow  = "Gauge 410040 mean flow\n(ML/day)")
ser$panel_lab <- factor(PANEL[ser$panel], levels = unname(PANEL))

# Canonical C1 checkerboard community hues (deck palette, dry -> wet), plus the
# committed total_veg green and neutral grey. Deliberately NOT viridis.
PAL <- c("veg_p05_spatial"                       = "#2E7D32",
         "veg_median"                            = "#9E9E9E",
         "Aeolian Chenopod Shrublands"           = "#C2A25A",
         "Riverine Chenopod Shrublands"          = "#5AB4AC",
         "Inland Floodplain Shrublands / Swamps" = "#2166AC",
         # Flow gets the darkest blue of the committed sequential ramp, NOT the Inland
         # community hue. They sit in different facets but share one legend, and two
         # unrelated series in the same colour is a legibility defect either way.
         "gauge 410040"                          = "#08306B")

lab_pos <- ser %>% group_by(panel_lab) %>% summarise(y = max(value), .groups = "drop") %>%
  filter(panel_lab == levels(ser$panel_lab)[1])

p <- ggplot(ser, aes(water_year, value, colour = series)) +
  geom_rect(data = bands, inherit.aes = FALSE,
            aes(xmin = lo - 0.5, xmax = hi + 0.5, ymin = -Inf, ymax = Inf),
            fill = "grey20", alpha = 0.10) +
  geom_vline(data = bands, inherit.aes = FALSE, aes(xintercept = lo),
             linetype = "dotted", linewidth = 0.35, colour = "grey30") +
  geom_vline(data = bands, inherit.aes = FALSE, aes(xintercept = hi),
             linetype = "dotted", linewidth = 0.35, colour = "grey30") +
  geom_line(linewidth = 0.75) +
  geom_point(size = 1.15) +
  geom_text(data = merge(bands, lab_pos), inherit.aes = FALSE,
            aes(x = (lo + hi) / 2, y = y, label = label),
            vjust = 1.02, size = 2.9, fontface = "bold", colour = "#B2182B",
            lineheight = 0.95) +
  facet_wrap(~ panel_lab, ncol = 1, scales = "free_y", strip.position = "left") +
  scale_colour_manual(values = PAL, name = NULL) +
  scale_x_continuous(breaks = seq(1990, 2020, 5), minor_breaks = seq(1988, 2022, 1)) +
  labs(
    title = "Where the two LiDAR epochs sit in the 35-year Landsat record, Gayini 1988-2022",
    subtitle = paste("Shaded bands are the CANDIDATE water years for each capture -",
                     "flight months are unrecoverable from the delivery (Gate U0.6),",
                     "\nand the water year starts in July, so each capture year spans two."),
    x = "Water year (WY N = Jul N - Jun N+1)", y = NULL) +
  theme_minimal(base_size = 10) +
  theme(strip.placement = "outside",
        strip.text.y.left = element_text(angle = 90, size = 8.2, lineheight = 0.95),
        legend.position = "bottom", legend.text = element_text(size = 7.6),
        legend.key.width = unit(14, "pt"),
        panel.grid.minor = element_line(linewidth = 0.15),
        plot.title = element_text(face = "bold", size = 11.5),
        plot.subtitle = element_text(size = 8.2, colour = "grey25", lineheight = 1.1))

cap <- paste(
  "Pixel support.",
  "veg_p05_spatial is the WITHIN-ZONE, WITHIN-YEAR spatial 5th percentile,",
  "pixel-weighted across zones (aggregation order: within-zone percentile first) -",
  "it is NOT the census temporal veg_p05, which is a different object.",
  "series_variant = mean_of_seasons. Flood is the per-community annual wet fraction at",
  "pixel support and is never comparable with the plot-support figures.",
  "Each LiDAR capture is drawn as a two-water-year band because flight months are",
  "unrecoverable (Gate U0.6). Denominator: the Landsat census, 67,349.3 ha mapped.",
  "Source Output/tables/taskU_gateU2_series_35yr.csv and taskU_gateU2_epoch_context.csv.")

gayini_write_and_register_figure(
  plot = p, path = OUT,
  title = "Task U Gate U2 - LiDAR epochs in the 35-year Landsat record",
  caption = cap, support_level = "pixel", figure_level = "diagnostic", run_id = RUN,
  domain = "zone_diagnostics", framing_label = "census_8058",
  provenance_note = paste(
    "Task U Gate U2. Spec docs/LiDAR/TaskU_lidar_structural_lens_v1.2.md.",
    "Conditions every later change interpretation (trap T-3).",
    "2009 reads low on every farm and community metric under BOTH candidate water",
    "years; 2021 reads typical-to-high under both. The DIRECTION is robust to the",
    "flight-month ambiguity; the MAGNITUDE is not - farm veg_p05_spatial at the 2009",
    "capture is 30.87 (WY2008) or 51.71 (WY2009), a 20.8 pp spread."),
  width = 10.5, height = 9.0, dpi = 200)
