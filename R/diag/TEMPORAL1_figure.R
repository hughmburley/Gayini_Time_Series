# TEMPORAL-1 completion - output 2, the paddock scatter.
#
# y = veg_p05_temporal_mean: the mean over a paddock's cells of EACH CELL'S TEMPORAL 5th
#     percentile of total vegetation cover. SEASONAL BASIS (Ruling CT) - 140 seasonal
#     composites, MIN_SEASONS = 50 - and every caption says so.
#
# x = the PUBLISHED value the client has already seen, mean_flood from
#     v_zone_floor_flood_residual. Ruling AZ established what that quantity is: the share
#     of the paddock's cells seen wet, MEAN OVER YEARS. It is NOT a between-year flood
#     frequency and is not labelled as one here, whatever the spec calls it.
#
# THE TWO-METRIC PROHIBITION IS ABSOLUTE ON THIS PAGE. veg_p05_spatial does not appear.
# The word "floor" does not appear. The two sit side by side ONLY in
# TEMPORAL1_reconciliation.csv, which is a table.
#
# No p-values. The trend is a display smoother and no coefficient is taken from it; any
# estimate would go through R/gayini_fit.R, and none is needed for this deliverable.

suppressPackageStartupMessages({library(ggplot2); library(DBI); library(RSQLite)})

root <- normalizePath(".", winslash = "/")
source(file.path(root, "R/gayini_figure_register.R"))
source(file.path(root, "R/gayini_gradient_helpers.R"))
source(file.path(root, "R/gayini_veg_regime_functions.R"))

SRC <- file.path(root, "Output/temporal/TEMPORAL1_scatter_input.csv")
stopifnot(file.exists(SRC))
d <- utils::read.csv(SRC, stringsAsFactors = FALSE)
stopifnot(nrow(d) == 64L)

PAL <- c(aeolian = "#C79A3B", riverine = "#3B8A8F", inland = "#2165AC")
LAY <- c(aeolian = "Aeolian Chenopod", riverine = "Riverine Chenopod",
         inland = "Inland Floodplain")
d$community_lab <- LAY[d$dominant_community_short]

INK <- "#26302E"; BODY <- "#5F6B67"; MUTED <- "#8A8378"

p <- ggplot(d, aes(mean_flood, veg_p05_temporal_mean)) +
  # display smoother only - no coefficient is read off it and none is reported.
  # gayini_veg_response_trend() was considered and NOT reused: it is a binned
  # conditional mean built for the 2,306-point plot-year cloud and at n = 64 its bins
  # would carry a handful of paddocks each.
  geom_smooth(method = "loess", formula = y ~ x, se = TRUE, colour = "grey35",
              fill = "grey85", linewidth = 0.7, alpha = 0.5) +
  geom_point(aes(colour = community_lab, size = n_cells), alpha = 0.85) +
  scale_colour_manual(values = setNames(unname(PAL[names(LAY)]), unname(LAY)),
                      name = "Dominant community") +
  scale_size_continuous(range = c(1.6, 7), name = "Cells in paddock",
                        labels = function(x) format(x, big.mark = ",")) +
  scale_y_continuous(limits = NULL) +
  coord_cartesian(xlim = c(0, max(d$mean_flood) * 1.04)) +
  labs(
    title = "Wetter paddocks hold more cover in their poorest seasons",
    subtitle = paste0(
      "64 paddocks. Each point is one paddock's average, over its own cells, of that ",
      "cell's 5th-percentile total ground cover across 140 seasonal composites.\n",
      "55 of the 64 are Inland Floodplain-dominant, so this is mostly a relationship ",
      "WITHIN Inland country - it does not order the three communities against each other."),
    x = "Share of the paddock's cells seen wet, mean over years (%)",
    y = "Mean per-cell 5th-percentile ground cover (%)",
    caption = paste(
      "Support: pixel throughout - both axes describe census cells, and no site or plot",
      "measurement appears, so the two supports are never mixed (C10).")) +
  theme_minimal(base_size = 11) +
  theme(panel.grid.minor = element_blank(),
        panel.grid.major = element_line(colour = "#EFEBE0", linewidth = 0.4),
        axis.text = element_text(colour = MUTED), axis.title = element_text(colour = BODY),
        plot.title = element_text(colour = INK, face = "bold", size = 13),
        plot.subtitle = element_text(colour = BODY, size = 9.5, lineheight = 1.25),
        plot.caption = element_text(colour = MUTED, size = 7.6, hjust = 0),
        plot.title.position = "plot", plot.caption.position = "plot",
        legend.position = "right")

caption <- paste0(
  "Support: pixel. 64 paddocks, ", format(sum(d$n_cells), big.mark = ","),
  " non-treed census cells. Y is veg_p05_temporal_mean: the unweighted mean, over a ",
  "paddock's own cells, of each cell's TEMPORAL 5th percentile of total vegetation cover. ",
  "SEASONAL BASIS - the percentile is taken over the 140 seasonal composites (4 per water ",
  "year x 35 water years) with MIN_SEASONS = 50, which is NOT the annual-basis series the ",
  "regression uses. X is the published paddock value: the share of the paddock's cells seen ",
  "wet, mean over years (%), not a between-year flood frequency. This is a DISTINCT METRIC ",
  "from veg_p05_spatial and the two are never co-plotted; they appear side by side only in ",
  "Output/temporal/TEMPORAL1_reconciliation.csv. Points are sized by cell count and coloured ",
  "by the paddock's dominant community, whose share is recorded per paddock - a paddock is ",
  "not an ecological unit (L-01). Trend line is a display smoother; no coefficient is taken ",
  "from it and no p-value is computed. ",
  "READ THE COMMUNITY COLOURS BEFORE THE SLOPE (Ruling DN): 55 of the 64 paddocks are ",
  "Inland Floodplain-dominant, so this trend is predominantly a WITHIN-INLAND relationship ",
  "and must not be read as ordering the three communities against one another. The upper ",
  "end of the smoother's interval is carried by a SINGLE paddock at 58.9% wet - Bala 22 - ",
  "which is why the band widens there. Scope: ",
  "treed_context_flag = 0 AND regime_band <> 'context', 1988-2022.")

r <- gayini_write_and_register_figure(
  plot = p,
  path = file.path(root, "Output/figures/temporal/TEMPORAL1_paddock_temporal_p05_vs_water.png"),
  title = "Mean per-cell temporal 5th-percentile ground cover against paddock wetness, 64 paddocks",
  caption = caption, support_level = "pixel", figure_level = "unit",
  run_id = "TEMPORAL1_20260808", domain = "client_deliverables",
  recommended_use = "client report",
  provenance_note = paste(
    "TEMPORAL-1 completion. Assembled from Output/census/gayini_pixel_census_8058.parquet",
    "(per-cell temporal percentiles) joined to gayini_pixel_zone_assignment.parquet, with x",
    "from v_zone_floor_flood_residual.mean_flood. No raster opened; no new pipeline built.",
    "Ruling CT: seasonal basis, annual-basis build deferred. Ruling AZ governs the x label."),
  width = 10, height = 6.6, dpi = 150)

cat(sprintf("  [registered] %s  %s\n", basename(r$path), substr(r$checksum_sha256, 1, 12)))
cat(sprintf("  x range %.2f - %.2f ; y range %.2f - %.2f ; cells %s\n",
            min(d$mean_flood), max(d$mean_flood), min(d$veg_p05_temporal_mean),
            max(d$veg_p05_temporal_mean), format(sum(d$n_cells), big.mark = ",")))
