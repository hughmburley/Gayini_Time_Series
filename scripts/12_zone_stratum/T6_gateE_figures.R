#!/usr/bin/env Rscript
# T6 Gate E - three-arm trajectory grid. Arms x community; ONE arm line per panel over
# the 14-day IQR band + median (the fixed comparator, repeated in every panel); flood
# years shaded; per-panel deficit vs 14-day (within-stratum controlled) and n units.
# Two readings carried in the caption: (a) intensity does not register (noise), or
# (b) the unzoned land is LESS grazed, not more (inference inverted) - the monotonic
# ordering and the plot-confirmed subset being highest favour (b). NOT presenting (a)
# as the finding. Aeolian not_grazed is n=1 (Bala 29ca) - flagged.

suppressPackageStartupMessages({library(ggplot2); library(DBI); library(RSQLite)})
root <- normalizePath(".", winslash = "/")
source(file.path(root, "R/gayini_figure_register.R"))
fig_dir <- file.path(root, "Output/figures/diagnostics")
con <- DBI::dbConnect(RSQLite::SQLite(), file.path(root, "Output/database/Gayini_Results.sqlite"))

# arm trajectories (community-level, band=ALL, mean_of_seasons)
arm <- DBI::dbGetQuery(con, "SELECT treatment_arm, community, water_year, veg_p05_spatial, veg_mean
  FROM fact_three_arm_stratum_veg_annual WHERE regime_band='ALL' AND series_variant='mean_of_seasons'")
# 14-day IQR band from the grazed zones (T2 table), per community per year
grz <- DBI::dbGetQuery(con, "SELECT f.community, f.water_year, f.veg_p05_spatial, f.veg_mean
  FROM fact_zone_community_veg_annual f JOIN dim_management_zone d ON d.zone_fid=f.zone_fid
  WHERE d.grazing_excluded=0 AND f.series_variant='mean_of_seasons' AND f.below_min_support=0")
flood <- DBI::dbGetQuery(con, "SELECT community, water_year FROM fact_community_year_flood WHERE flood_class='flood'")
dec <- DBI::dbGetQuery(con, "SELECT community, treatment_arm, floor_deficit_pp, mean_deficit_pp, n_units
  FROM fact_three_arm_gap_decomposition WHERE regime_band='ALL' AND window='all'")
DBI::dbDisconnect(con)

short <- function(x) vapply(strsplit(x, " "), `[`, character(1), 1)
arm$comm <- short(arm$community); grz$comm <- short(grz$community)
flood$comm <- short(flood$community); dec$comm <- short(dec$community)

ARMS <- c(not_grazed = "not grazed (reference)",
          unzoned_inferred_standard = "unzoned mapped (inferred standard)",
          unzoned_plot_confirmed = "unzoned, plot-confirmed (8/15)")
arm <- arm[arm$treatment_arm %in% names(ARMS), ]
arm$arm_lab <- factor(ARMS[arm$treatment_arm], levels = ARMS)   # row order: ref, unzoned, pc
dec$arm_lab <- ARMS[dec$treatment_arm]

band <- function(df, yv) do.call(rbind, lapply(
  split(df, list(df$comm, df$water_year), drop = TRUE), function(g) data.frame(
    comm = g$comm[1], water_year = g$water_year[1],
    lo = stats::quantile(g[[yv]], .25, names = FALSE, na.rm = TRUE),
    md = stats::median(g[[yv]], na.rm = TRUE),
    hi = stats::quantile(g[[yv]], .75, names = FALSE, na.rm = TRUE))))

acols <- c("not grazed (reference)" = "#238b45",
           "unzoned mapped (inferred standard)" = "#B2182B",
           "unzoned, plot-confirmed (8/15)" = "#6a51a3")

make_grid <- function(yv, defcol, ylab, ttl) {
  gb <- band(grz, yv)
  a <- arm; a$y <- a[[yv]]
  lab <- dec[dec$treatment_arm %in% names(ARMS), ]   # exclude 14-day (the comparator)
  lab$arm_lab <- factor(ARMS[lab$treatment_arm], levels = ARMS)
  lab$def <- lab[[defcol]]
  lab$txt <- sprintf("%+.1f pp vs 14-day\nn=%d", lab$def, lab$n_units)
  lab$aeolian_flag <- ifelse(lab$comm == "Aeolian" & lab$treatment_arm == "not_grazed",
                             "\n(n=1: Bala 29ca)", "")
  ggplot() +
    geom_rect(data = flood, aes(xmin = water_year - .5, xmax = water_year + .5,
              ymin = -Inf, ymax = Inf), fill = "#c6dbef", alpha = .45) +
    geom_ribbon(data = gb, aes(water_year, ymin = lo, ymax = hi), fill = "grey75", alpha = .55) +
    geom_line(data = gb, aes(water_year, md), colour = "grey35", linewidth = .5) +
    geom_line(data = a, aes(water_year, y, colour = arm_lab), linewidth = .9) +
    geom_text(data = lab, aes(x = 1988, y = 12, label = paste0(txt, aeolian_flag)),
              hjust = 0, vjust = 0, size = 2.5, colour = "grey20") +
    facet_grid(arm_lab ~ comm, switch = "y") +
    scale_colour_manual(values = acols, guide = "none") +
    coord_cartesian(ylim = c(10, 100)) +
    labs(title = ttl, x = "water year", y = ylab,
      subtitle = paste("Grey = 14-day IQR band + median (fixed comparator). Blue = flood years.",
                       "Line coloured by arm. Deficit is within-stratum (wetness controlled)."),
      caption = paste0(
        "Support: pixel (aggregation_unit = arm_community_band_window). The inferred-standard arm sits AT OR ABOVE the 14-day\n",
        "floor within stratum (above in 6 of 9 strata; plot-confirmed above in 8 of 9), inconsistent with heavier grazing degrading\n",
        "the floor. Two readings: (a) grazing intensity does not register (ordering is noise); (b) the unzoned land is LESS grazed,\n",
        "not more - 'unzoned' = outside the rotational system (remote/unwatered/unfenced) - making the ordering a real gradient with\n",
        "the inference inverted. The monotonic ordering and the plot-confirmed subset being highest favour (b). Arm is INFERRED:\n",
        "'unzoned mapped area (8 of 15 standard-grazing plots)'. not_grazed n=1-4 (Aeolian n=1); unzoned n=3-17 - the better-replicated arm.")) +
    theme_minimal(base_size = 10) +
    theme(plot.caption = element_text(hjust = 0, size = 7),
          strip.text.y.left = element_text(angle = 0), strip.placement = "outside")
}

p_grid <- make_grid("veg_p05_spatial", "floor_deficit_pp", "veg_p05_spatial (%)",
  "T6 A - Three-arm vegetation-FLOOR trajectories vs the 14-day comparator (by community)")
gayini_write_and_register_figure(p_grid,
  file.path(fig_dir, "T6_A_three_arm_grid.png"),
  title = "T6 A three-arm floor grid",
  caption = paste("Support: pixel. Three-arm veg_p05_spatial trajectories vs the 14-day",
    "IQR comparator, faceted arm x community; inferred-standard arm at/above 14-day floor."),
  support_level = "pixel", figure_level = "deliverable", run_id = "T6_gateE",
  provenance_note = "Inferred arm; two readings (intensity-noise vs less-grazed) in caption.",
  width = 13, height = 9)

p_mean <- make_grid("veg_mean", "mean_deficit_pp", "veg_mean (%)",
  "T6 B - Three-arm MEAN-cover trajectories vs the 14-day comparator (by community)")
gayini_write_and_register_figure(p_mean,
  file.path(fig_dir, "T6_B_three_arm_mean.png"),
  title = "T6 B three-arm mean-cover grid",
  caption = paste("Support: pixel. Three-arm veg_mean trajectories vs the 14-day IQR",
    "comparator; the mean-vs-floor contrast (arms match on mean, differ on floor)."),
  support_level = "pixel", figure_level = "deliverable", run_id = "T6_gateE",
  provenance_note = "Mean-cover companion to T6_A.", width = 13, height = 9)

# ---- deck cut: 4 panels (not_grazed & unzoned) x (Aeolian & Riverine) ----
dk <- arm[arm$comm %in% c("Aeolian", "Riverine") &
          arm$treatment_arm %in% c("not_grazed", "unzoned_inferred_standard"), ]
dk$y <- dk$veg_p05_spatial
gbd <- band(grz, "veg_p05_spatial"); gbd <- gbd[gbd$comm %in% c("Aeolian", "Riverine"), ]
fld <- flood[flood$comm %in% c("Aeolian", "Riverine"), ]
ld <- dec[dec$comm %in% c("Aeolian", "Riverine") &
          dec$treatment_arm %in% c("not_grazed", "unzoned_inferred_standard"), ]
ld$txt <- sprintf("%+.1f pp vs 14-day (n=%d)%s", ld$floor_deficit_pp, ld$n_units,
                  ifelse(ld$comm == "Aeolian" & ld$treatment_arm == "not_grazed", " [n=1: Bala 29ca]", ""))
p_deck <- ggplot() +
  geom_rect(data = fld, aes(xmin = water_year - .5, xmax = water_year + .5, ymin = -Inf, ymax = Inf),
            fill = "#c6dbef", alpha = .45) +
  geom_ribbon(data = gbd, aes(water_year, ymin = lo, ymax = hi), fill = "grey75", alpha = .55) +
  geom_line(data = gbd, aes(water_year, md), colour = "grey35", linewidth = .5) +
  geom_line(data = dk, aes(water_year, y, colour = arm_lab), linewidth = 1) +
  geom_text(data = ld, aes(1988, 14, label = txt), hjust = 0, size = 2.9, colour = "grey20") +
  facet_grid(arm_lab ~ comm) + scale_colour_manual(values = acols, guide = "none") +
  coord_cartesian(ylim = c(10, 100)) +
  labs(title = "T6 A (deck) - Floor vs the 14-day comparator: reference below, inferred-standard above",
       x = "water year", y = "veg_p05_spatial (%)",
       caption = paste("Support: pixel. Grey = 14-day IQR + median; blue = flood years. Inferred-standard arm sits ABOVE 14-day -",
         "inconsistent with heavier grazing; may mean the unzoned land is LESS grazed. Arm inferred (8/15 plots). not_grazed Aeolian n=1.")) +
  theme_minimal(base_size = 11) + theme(plot.caption = element_text(hjust = 0, size = 8))
gayini_write_and_register_figure(p_deck,
  file.path(fig_dir, "T6_A_three_arm_deck.png"),
  title = "T6 A three-arm deck cut",
  caption = paste("Support: pixel. Four-panel deck cut: not_grazed and unzoned arms x",
    "Aeolian and Riverine; inferred-standard arm above the 14-day floor."),
  support_level = "pixel", figure_level = "deliverable", run_id = "T6_gateE",
  provenance_note = "Deck cut of T6_A; two readings in the full figure/change report.",
  width = 11, height = 7)
cat("[done] T6 Gate E figures\n")
