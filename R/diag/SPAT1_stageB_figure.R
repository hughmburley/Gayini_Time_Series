# SPAT-1 Stage B figure - the two ladders, per Ruling EU.
#
# An OLS ladder alone cannot separate a scale effect from aggregation-induced curvature
# bias, so both ladders are drawn on one pair of axes and the reader can see which is
# which. Straight-line slope in solid, the GAM's average marginal effect dashed.

suppressPackageStartupMessages({library(ggplot2)})

root <- normalizePath(".", winslash = "/")
source(file.path(root, "R/gayini_figure_register.R"))
OUT <- file.path(root, "Output", "spatial")

ols <- utils::read.csv(file.path(OUT, "SPAT1_ladder_slopes.csv"), stringsAsFactors = FALSE)
gam <- utils::read.csv(file.path(OUT, "SPAT1_ladder_gam.csv"), stringsAsFactors = FALSE)
cnt <- utils::read.csv(file.path(OUT, "SPAT1_ladder_counts.csv"), stringsAsFactors = FALSE)
lev <- utils::read.csv(file.path(OUT, "SPAT1_ladder_levels.csv"), stringsAsFactors = FALSE)

INK <- "#26302E"; BODY <- "#5F6B67"; MUTED <- "#8A8378"
PAL <- c(aeolian = "#C79A3C", riverine = "#3FAE97", inland = "#2E6DB0")
LAY <- c(aeolian = "Aeolian Chenopod", riverine = "Riverine Chenopod",
         inland = "Inland Floodplain")

o <- ols[ols$subset == "all", c("block_m", "community", "slope", "ci_lo", "ci_hi", "n_units")]
o$kind <- "Straight-line slope"
names(o)[names(o) == "slope"] <- "value"
g <- gam[, c("block_m", "community", "ame", "n_units")]
g$kind <- "Curved fit, average slope"
names(g)[names(g) == "ame"] <- "value"
g$ci_lo <- NA_real_; g$ci_hi <- NA_real_
d <- rbind(o[, c("block_m", "community", "value", "ci_lo", "ci_hi", "n_units", "kind")],
           g[, c("block_m", "community", "value", "ci_lo", "ci_hi", "n_units", "kind")])
d$community_lab <- factor(LAY[d$community], levels = unname(LAY))

cnt$fitted <- as.logical(cnt$fitted)      # read.csv gives "True"/"False" from pandas
unfit <- cnt[!cnt$fitted, ]
stopifnot(nrow(unfit) == 2L)
wrap <- function(x, w) paste(strwrap(paste(x, collapse = " "), width = w), collapse = "\n")

sub <- wrap(c(
  "The same relationship measured on square blocks of growing size, from single satellite cells up to four kilometres across.",
  "A regular grid changes the size of the unit while holding constant how it was drawn, which is the only way to separate the two.",
  "Both a straight line and a curved fit are shown at every rung, because a straight line fitted to a curved relationship steepens as blocks grow whether or not anything real changes with scale."),
  158)

foot <- wrap(c(
  sprintf("Blocks are nested: each larger one is an exact union of the smaller. A unit is one block cut to a single vegetation community, kept where it holds at least 500 cells. The %s m and %s m rungs cannot reach that floor - a %s m block holds at most %d cells - so they are counted and not fitted, and the ladder begins at 1 km.",
          format(unfit$block_m[1]), format(unfit$block_m[2]), format(unfit$block_m[2]),
          max(unfit$max_cells_a_block_can_hold)),
  "In Inland Floodplain country both lines are flat: the relationship is the same on a four-kilometre block as on a single cell, which is a stronger statement than holding across the three unit types the project happened to build.",
  "In Riverine Chenopod the straight-line slope is flat while the curved fit's average slope falls, so the slope survives aggregation but the shape it approximates does not.",
  "In Aeolian Chenopod both fall and cross zero by four kilometres. Both moving together means this is not an artefact of forcing a straight line through a curve.",
  "Intervals are a spatial block bootstrap on 8 km blocks, larger than the distance over which the leftovers stay similar. They are not built from the number of blocks, which would assume the blocks are independent of one another.",
  "Cover and water are measured on a 25 m satellite grid across 1988-2022."), 210)

p <- ggplot(d, aes(block_m, value, colour = community_lab, linetype = kind,
                   shape = kind)) +
  geom_hline(yintercept = 0, colour = "#C9CFCB", linewidth = 0.5) +
  geom_errorbar(aes(ymin = ci_lo, ymax = ci_hi), width = 0.06, linewidth = 0.4,
                alpha = 0.55, na.rm = TRUE, show.legend = FALSE) +
  geom_line(linewidth = 0.8) +
  geom_point(size = 2.6, fill = "white", stroke = 0.8) +
  facet_wrap(~ community_lab, nrow = 1) +
  scale_x_log10(breaks = c(25, 100, 250, 1000, 2000, 4000),
                labels = c("cell", "100 m", "250 m", "1 km", "2 km", "4 km")) +
  scale_colour_manual(values = setNames(unname(PAL[names(LAY)]), unname(LAY)),
                      guide = "none") +
  scale_linetype_manual(values = c("Straight-line slope" = "solid",
                                   "Curved fit, average slope" = "22"), name = NULL) +
  scale_shape_manual(values = c("Straight-line slope" = 21,
                                "Curved fit, average slope" = 24), name = NULL) +
  labs(title = "Does the relationship change with the size of the unit?",
       subtitle = sub,
       x = "Size of the block the relationship is measured on",
       y = "Change in cover per point of water",
       caption = foot) +
  theme_minimal(base_size = 12) +
  theme(plot.background = element_rect(fill = "white", colour = NA),
        panel.background = element_rect(fill = "white", colour = NA),
        legend.background = element_rect(fill = "white", colour = NA),
        legend.key = element_rect(fill = "white", colour = NA),
        panel.grid.minor = element_blank(),
        panel.grid.major = element_line(colour = "#EFEBE0", linewidth = 0.4),
        strip.text = element_text(colour = INK, face = "bold", size = 10.5),
        axis.text = element_text(colour = MUTED),
        axis.title = element_text(colour = BODY, size = 11),
        plot.title = element_text(colour = INK, face = "bold", size = 16),
        plot.subtitle = element_text(colour = BODY, size = 10, lineheight = 1.3),
        plot.caption = element_text(colour = MUTED, size = 7.4, hjust = 0,
                                    lineheight = 1.3),
        plot.title.position = "plot", plot.caption.position = "plot",
        legend.position = "top")

cap <- paste0(
  "Support: pixel, aggregated to block x vegetation community. Nested square blocks on ",
  "EPSG:8058 anchored to one origin, 250 m to 4 km, plus the pixel census as rung 0. ",
  "Support rule 500 cells at every rung; the 250 m and 500 m rungs cannot physically ",
  "reach it (100 and 400 cells maximum) and are counted, not fitted (6.1). Units after ",
  "the floor: 746 at 1 km, 323 at 2 km, 129 at 4 km. SOLID is the OLS slope; DASHED is ",
  "the GAM's average marginal effect, the mean of dy/dx over each rung's own x, which is ",
  "what an OLS slope estimates when the relationship is straight. RULING EU: an OLS ",
  "ladder alone cannot separate a scale effect from aggregation-induced curvature bias, ",
  "so both are drawn. Inland both flat (spreads 0.09 / 0.12) - scale-invariant. Riverine ",
  "OLS flat at 0.05 while the GAM moves 0.34. Aeolian both move together, 0.46 / 0.35, ",
  "crossing zero by 4 km - not curvature. Intervals are an 8 km spatial block bootstrap, ",
  "2,000 draws, NOT the block count and NOT the Clifford-Richardson n_eff, which is ",
  "derived for a mean. Metric veg_p05_temporal_mean throughout; veg_p05_spatial does not ",
  "appear in this task. Scope: treed_context_flag = 0 AND regime_band <> 'context', ",
  "1988-2022.")

r <- gayini_write_and_register_figure(
  plot = p, path = file.path(OUT, "SPAT1_F3_scale_ladder.png"),
  title = "Slope against unit size on a regular nested grid, straight-line and curved fits, by vegetation community",
  caption = cap, support_level = "pixel", figure_level = "block",
  run_id = "SPAT1_20260810", domain = "zone_diagnostics", recommended_use = "review",
  provenance_note = paste(
    "SPAT-1 Stage B figure. Built from Output/spatial/SPAT1_ladder_slopes.csv and",
    "SPAT1_ladder_gam.csv. THE FIVE QUALIFIERS: support_level = pixel aggregated to",
    "block x vegetation community;",
    "scope_filter_sql = treed_context_flag = 0 AND regime_band <> 'context' AND",
    "n_cells >= 500 per block x community;",
    "pixel_area_ha = 0.062351428; denominator_ha = 61654.9 analysed of 85910.8 property",
    "(Ruling EQ); period_label = 1988-2022 (35 water years)."),
  width = 13.5, height = 7.6, dpi = 150)
cat(sprintf("  [registered] %s  %s\n", basename(r$path), substr(r$checksum_sha256, 1, 12)))

cat("\n[6.2 level] mean cover per rung, the UNZONED 1.1 test\n")
for (cs in c("aeolian", "riverine", "inland")) {
  k <- lev[lev$community == cs, ]; k <- k[order(k$block_m), ]
  dec <- log10(max(k$block_m) / min(k$block_m))
  chg <- k$mean_level[nrow(k)] - k$mean_level[1]
  cat(sprintf("  %-9s %s   change %+.2f pp over %.2f decades = %+.2f pp/decade\n", cs,
              paste(sprintf("%s:%.1f", sub(" .*", "", k$rung), k$mean_level),
                    collapse = "  "), chg, dec, chg / dec))
}
