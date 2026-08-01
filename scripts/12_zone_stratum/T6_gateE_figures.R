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
source(file.path(root, "R/gayini_assert_rendered.R"))   # QA-2a guard (I-32)
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
# ---- REM-1: the deficit labels are the PIN 1 aggregation, NOT the retired ALL rollup ----
# PIN 1 (T8 Gate B) retired regime_band='ALL' for the deficit statistic: pooling the wetness bands
# reintroduces the drier-skew confound T6 is designed to remove, and roughly DOUBLES the Aeolian and
# Riverine deficits (Aeolian not_grazed -19.65 under ALL vs -10.46 pinned). The labels are now the
# AREA-WEIGHTED band mean over low/mid/high, weighted by non-treed stratum area - the same method
# that produced every pinned value in dim_headline_number. NOTE the equal-weighted band mean is a
# DIFFERENT number again (-11.17 on Aeolian) and is recorded only as the spread endpoint.
# n_units is still read from the ALL row: it is a COUNT of units, not a deficit statistic.
bnd <- DBI::dbGetQuery(con, "SELECT community, treatment_arm, regime_band,
    floor_deficit_pp, mean_deficit_pp FROM fact_three_arm_gap_decomposition
  WHERE window='all' AND regime_band IN ('low','mid','high')")
ar <- DBI::dbGetQuery(con, "SELECT community, regime_band, SUM(area_ha) AS area_ha
  FROM census_by_zone_stratum WHERE treed_context_flag=0
    AND regime_band IN ('low','mid','high') GROUP BY community, regime_band")
nun <- DBI::dbGetQuery(con, "SELECT community, treatment_arm, n_units
  FROM fact_three_arm_gap_decomposition WHERE regime_band='ALL' AND window='all'")
pins <- DBI::dbGetQuery(con, "SELECT number_id, pinned_value FROM dim_headline_number
  WHERE number_id LIKE 'ref_grazed_floor_%' OR number_id LIKE 'ref_grazed_mean_cover_%'
     OR number_id LIKE 'three_arm_floor_deficit_unzoned_%'
     OR number_id LIKE 'three_arm_mean_deficit_unzoned_%'")
DBI::dbDisconnect(con)

bnd <- merge(bnd, ar, by = c("community", "regime_band"))
wavg <- function(df, col) do.call(rbind, lapply(
  split(df, list(df$community, df$treatment_arm), drop = TRUE), function(g)
    data.frame(community = g$community[1], treatment_arm = g$treatment_arm[1],
               v = sum(g[[col]] * g$area_ha) / sum(g$area_ha))))
dfl <- wavg(bnd, "floor_deficit_pp"); names(dfl)[3] <- "floor_deficit_pp"
dmn <- wavg(bnd, "mean_deficit_pp");  names(dmn)[3] <- "mean_deficit_pp"
dec <- merge(merge(dfl, dmn, by = c("community", "treatment_arm")), nun,
             by = c("community", "treatment_arm"))

# ---- assert against dim_headline_number: drift FAILS the render, it does not warn ----
SHORTC <- c("Aeolian Chenopod Shrublands" = "aeolian",
            "Riverine Chenopod Shrublands" = "riverine",
            "Inland Floodplain Shrublands / Swamps" = "inland")
ASSERT <- list(
  floor_deficit_pp = list(not_grazed = "ref_grazed_floor_%s",
                          unzoned_inferred_standard = "three_arm_floor_deficit_unzoned_inferred_%s",
                          unzoned_plot_confirmed = "three_arm_floor_deficit_unzoned_plot_%s"),
  mean_deficit_pp  = list(not_grazed = "ref_grazed_mean_cover_%s",
                          unzoned_inferred_standard = "three_arm_mean_deficit_unzoned_inferred_%s",
                          unzoned_plot_confirmed = "three_arm_mean_deficit_unzoned_plot_%s"))
for (qcol in names(ASSERT)) {
  for (armk in names(ASSERT[[qcol]])) for (cm in names(SHORTC)) {  # armk NOT arm - `arm` is the traj df
    nid  <- sprintf(ASSERT[[qcol]][[armk]], SHORTC[[cm]])
    want <- pins$pinned_value[pins$number_id == nid]
    got  <- dec[[qcol]][dec$community == cm & dec$treatment_arm == armk]
    if (length(want) != 1 || length(got) != 1 || abs(round(got, 2) - want) >= 0.005)
      stop(sprintf("REM-1 assert FAILED: %s / %s / %s drawn %.4f vs pinned %s (%s)",
                   qcol, armk, cm, if (length(got) == 1) got else NA_real_,
                   if (length(want) == 1) format(want) else "MISSING", nid))
  }
  cat(sprintf("[assert] all 9 %s labels reproduce dim_headline_number pinned values\n", qcol))
}

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
  lab$def <- lab[[defcol]]
  # ---- REM-1: the panel carries TWO quantities and must say so ON THE FIGURE ----
  # Pack figures travel WITHOUT their captions - Adrian lifts these into his own slides - so a
  # contents-document caption cannot carry this. The gap the eye sees between the arm line and the
  # grey median is the RAW difference; the label's deficit is that gap ADJUSTED for water
  # (within-stratum, area-weighted band mean, PIN 1). On Aeolian these are -30.9 and -10.5: most
  # of the visible gap is water, not grazing. raw_gap is the mean per-year vertical distance
  # between the two drawn lines - i.e. exactly what the reader integrates by eye. It is a
  # DESCRIPTION of what is already plotted, not a new quantity, so it needs no pin.
  raw <- do.call(rbind, lapply(split(a, list(a$comm, a$treatment_arm), drop = TRUE), function(g) {
    m <- merge(g[, c("comm", "water_year", "y")], gb[, c("comm", "water_year", "md")],
               by = c("comm", "water_year"))
    data.frame(comm = g$comm[1], treatment_arm = g$treatment_arm[1],
               raw_gap = mean(m$y - m$md, na.rm = TRUE))
  }))
  lab <- merge(lab, raw, by = c("comm", "treatment_arm"))
  lab$arm_lab <- factor(ARMS[lab$treatment_arm], levels = ARMS)
  lab$txt <- sprintf("%+.1f pp adj. for water\n(raw gap %+.1f)   n=%d",
                     lab$def, lab$raw_gap, lab$n_units)
  # QA-2a: assert the strings ACTUALLY DRAWN carry BOTH source values (catches the ifelse/
  # recycling class of defect that no data-level check can see).
  gayini_assert_rendered_values(lab$txt, lab$def, digits = 1, signed = TRUE,
                                label = paste("T6 panel labels adj", defcol))
  gayini_assert_rendered_values(lab$txt, lab$raw_gap, digits = 1, signed = TRUE,
                                label = paste("T6 panel labels raw", defcol))
  gayini_assert_rendered_varies(lab$txt, paste("T6 panel labels", defcol))
  lab$aeolian_flag <- ifelse(lab$comm == "Aeolian" & lab$treatment_arm == "not_grazed",
                             "\n(n=1: Bala 29ca)", "")
  # Subtitle numbers are COMPUTED from the same object the labels use - never typed. A hardcoded
  # subtitle silently disagrees with the panel the moment the aggregation changes.
  aeo <- lab[lab$comm == "Aeolian" & lab$treatment_arm == "not_grazed", ]
  sub <- paste0(
    "Grey = 14-day IQR band + median (fixed comparator). Blue = flood years. Line coloured by arm.\n",
    "TWO QUANTITIES, and they differ: the gap you SEE between the line and the grey median is the RAW ",
    "difference. The label is that gap ADJUSTED for water\n(within-stratum, area-weighted over the three ",
    sprintf("wetness bands). Most of the raw gap is water, not grazing - on Aeolian, raw %+.1f pp becomes %+.1f pp adjusted.",
            aeo$raw_gap, aeo$def))
  gayini_assert_caption_number(sub, aeo$raw_gap, 1, paste("T6 subtitle raw gap", defcol))
  gayini_assert_caption_number(sub, aeo$def, 1, paste("T6 subtitle adjusted", defcol))
  ggplot() +
    geom_rect(data = flood, aes(xmin = water_year - .5, xmax = water_year + .5,
              ymin = -Inf, ymax = Inf), fill = "#c6dbef", alpha = .45) +
    geom_ribbon(data = gb, aes(water_year, ymin = lo, ymax = hi), fill = "grey75", alpha = .55) +
    geom_line(data = gb, aes(water_year, md), colour = "grey35", linewidth = .5) +
    geom_line(data = a, aes(water_year, y, colour = arm_lab), linewidth = .9) +
    # y = 1 with the axis floored at 0: the label sits in reserved white space BELOW all data
    # (series minimum is ~15), so it can never overlap a line.
    geom_text(data = lab, aes(x = 1988, y = 1, label = paste0(txt, aeolian_flag)),
              hjust = 0, vjust = 0, size = 2.5, colour = "grey20") +
    facet_grid(arm_lab ~ comm, switch = "y") +
    scale_colour_manual(values = acols, guide = "none") +
    coord_cartesian(ylim = c(0, 100)) +
    labs(title = ttl, x = "water year", y = ylab, subtitle = sub,
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
  support_level = "pixel", figure_level = "deliverable", run_id = "rem1_rerender_20260801",
  provenance_note = "Inferred arm; two readings (intensity-noise vs less-grazed) in caption.",
  width = 13, height = 9)

p_mean <- make_grid("veg_mean", "mean_deficit_pp", "veg_mean (%)",
  "T6 B - Three-arm MEAN-cover trajectories vs the 14-day comparator (by community)")
gayini_write_and_register_figure(p_mean,
  file.path(fig_dir, "T6_B_three_arm_mean.png"),
  title = "T6 B three-arm mean-cover grid",
  caption = paste("Support: pixel. Three-arm veg_mean trajectories vs the 14-day IQR",
    "comparator; the mean-vs-floor contrast (arms match on mean, differ on floor)."),
  support_level = "pixel", figure_level = "deliverable", run_id = "rem1_rerender_20260801",
  provenance_note = "Mean-cover companion to T6_A.", width = 13, height = 9)

# ---- deck cut: 4 panels (not_grazed & unzoned) x (Aeolian & Riverine) ----
dk <- arm[arm$comm %in% c("Aeolian", "Riverine") &
          arm$treatment_arm %in% c("not_grazed", "unzoned_inferred_standard"), ]
dk$y <- dk$veg_p05_spatial
gbd <- band(grz, "veg_p05_spatial"); gbd <- gbd[gbd$comm %in% c("Aeolian", "Riverine"), ]
fld <- flood[flood$comm %in% c("Aeolian", "Riverine"), ]
ld <- dec[dec$comm %in% c("Aeolian", "Riverine") &
          dec$treatment_arm %in% c("not_grazed", "unzoned_inferred_standard"), ]
# REM-1: deck cut carries the same two quantities as the grid (see make_grid comment).
ldraw <- do.call(rbind, lapply(split(dk, list(dk$comm, dk$treatment_arm), drop = TRUE), function(g) {
  m <- merge(g[, c("comm", "water_year", "y")], gbd[, c("comm", "water_year", "md")],
             by = c("comm", "water_year"))
  data.frame(comm = g$comm[1], treatment_arm = g$treatment_arm[1],
             raw_gap = mean(m$y - m$md, na.rm = TRUE))
}))
ld <- merge(ld, ldraw, by = c("comm", "treatment_arm"))
ld$arm_lab <- ARMS[ld$treatment_arm]
ld$txt <- sprintf("%+.1f pp adj. for water (raw gap %+.1f)  n=%d%s",
                  ld$floor_deficit_pp, ld$raw_gap, ld$n_units,
                  ifelse(ld$comm == "Aeolian" & ld$treatment_arm == "not_grazed", " [n=1: Bala 29ca]", ""))
gayini_assert_rendered_values(ld$txt, ld$floor_deficit_pp, digits = 1, signed = TRUE,
                              label = "T6 deck-cut labels adj")
gayini_assert_rendered_values(ld$txt, ld$raw_gap, digits = 1, signed = TRUE,
                              label = "T6 deck-cut labels raw")
gayini_assert_rendered_varies(ld$txt, "T6 deck-cut labels")
# Deck subtitle numbers COMPUTED, never typed (same rule as the grid).
daeo <- ld[ld$comm == "Aeolian" & ld$treatment_arm == "not_grazed", ]
deck_sub <- paste0(
  "TWO QUANTITIES, and they differ: the gap you SEE between the line and the grey median is the RAW difference.\n",
  "The label is that gap ADJUSTED for water (within-stratum, area-weighted over three wetness bands). Most of the\n",
  sprintf("raw gap is water, not grazing - on Aeolian, raw %+.1f pp becomes %+.1f pp adjusted.",
          daeo$raw_gap, daeo$floor_deficit_pp))
gayini_assert_caption_number(deck_sub, daeo$raw_gap, 1, "T6 deck subtitle raw gap")
gayini_assert_caption_number(deck_sub, daeo$floor_deficit_pp, 1, "T6 deck subtitle adjusted")
p_deck <- ggplot() +
  geom_rect(data = fld, aes(xmin = water_year - .5, xmax = water_year + .5, ymin = -Inf, ymax = Inf),
            fill = "#c6dbef", alpha = .45) +
  geom_ribbon(data = gbd, aes(water_year, ymin = lo, ymax = hi), fill = "grey75", alpha = .55) +
  geom_line(data = gbd, aes(water_year, md), colour = "grey35", linewidth = .5) +
  geom_line(data = dk, aes(water_year, y, colour = arm_lab), linewidth = 1) +
  geom_text(data = ld, aes(1988, 1, label = txt), hjust = 0, vjust = 0, size = 2.9, colour = "grey20") +
  facet_grid(arm_lab ~ comm) + scale_colour_manual(values = acols, guide = "none") +
  coord_cartesian(ylim = c(0, 100)) +
  labs(title = "T6 A (deck) - Floor vs the 14-day comparator: reference below, inferred-standard above",
       x = "water year", y = "veg_p05_spatial (%)",
       subtitle = deck_sub,
       caption = paste("Support: pixel. Grey = 14-day IQR + median; blue = flood years. Inferred-standard arm sits ABOVE 14-day -",
         "inconsistent with heavier grazing; may mean the unzoned land is LESS grazed. Arm inferred (8/15 plots). not_grazed Aeolian n=1.")) +
  theme_minimal(base_size = 11) + theme(plot.caption = element_text(hjust = 0, size = 8))
gayini_write_and_register_figure(p_deck,
  file.path(fig_dir, "T6_A_three_arm_deck.png"),
  title = "T6 A three-arm deck cut",
  caption = paste("Support: pixel. Four-panel deck cut: not_grazed and unzoned arms x",
    "Aeolian and Riverine; inferred-standard arm above the 14-day floor."),
  support_level = "pixel", figure_level = "deliverable", run_id = "rem1_rerender_20260801",
  provenance_note = "Deck cut of T6_A; two readings in the full figure/change report.",
  width = 11, height = 7)
cat("[done] T6 Gate E figures\n")
