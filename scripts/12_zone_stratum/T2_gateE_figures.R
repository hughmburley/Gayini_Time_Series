#!/usr/bin/env Rscript
# T2 Gate E - the paddock trajectory panel (THE deliverable) + the veg_mean
# secondary + the B2 duration map. Built from the zone x community x year grain
# (fact_zone_community_veg_annual, mean_of_seasons) so a reference paddock that spans
# several communities appears in each community facet it occupies - a single dominant-
# community label would hide that (e.g. Bala 29ca p05 29/67/35 across its communities).
# Reference paddocks (No grazing, fids 1-4) individually; grazed as IQR band + median;
# flood years shaded (community top-tercile flood_frac); faceted by community.
# Reports gap narrow/widen/hold - NO distance-to-reference or convergence statistic.
# veg_p05_spatial is a WITHIN-year SPATIAL percentile, NOT the census temporal veg_p05.

suppressPackageStartupMessages({library(ggplot2); library(terra); library(DBI); library(RSQLite)})
root <- normalizePath(".", winslash = "/")
source(file.path(root, "R/gayini_figure_register.R"))
fig_dir <- file.path(root, "Output/figures/diagnostics")
MIN_PX <- 30L   # figure cell support floor; below this a zone-community-year is dropped

con <- DBI::dbConnect(RSQLite::SQLite(), file.path(root, "Output/database/Gayini_Results.sqlite"))
d <- DBI::dbGetQuery(con, "
  SELECT f.zone_fid, d.zone_name, d.grazing_excluded, f.community, f.water_year,
         f.n_pixels_valid, f.veg_mean, f.veg_p05_spatial
  FROM fact_zone_community_veg_annual f
  JOIN dim_management_zone d ON d.zone_fid = f.zone_fid
  WHERE f.series_variant = 'mean_of_seasons'")
flood <- utils::read.csv(file.path(root, "Output/tables/T2_community_year_flood.csv"))
# Ruling AC 2: each conserved line is a paddock-COMMUNITY part, and the parts differ
# enormously in how much of their paddock they represent. Bala 26ca's Riverine part is
# 1.9% of that paddock and currently draws at the same weight as a third of another.
# Computed here, never typed - the share is printed at the direct label.
shr <- DBI::dbGetQuery(con, "
  SELECT d.zone_name, c.community, SUM(c.n_pixels) AS npx
  FROM census_by_zone_stratum c
  JOIN dim_management_zone d ON d.zone_fid = c.zone_fid
  WHERE d.grazing_excluded = 1 AND c.treed_context_flag = 0
  GROUP BY d.zone_name, c.community")
DBI::dbDisconnect(con)

shr$share_pct <- 100 * shr$npx / ave(shr$npx, shr$zone_name, FUN = sum)
shr$comm <- vapply(strsplit(shr$community, " "), `[`, character(1), 1)

d <- d[d$n_pixels_valid >= MIN_PX, ]
d$comm <- vapply(strsplit(d$community, " "), `[`, character(1), 1)   # short facet label
flood$comm <- vapply(strsplit(flood$community, " "), `[`, character(1), 1)

# flood-year shading: per community, top-tercile flood_frac years
thr <- tapply(flood$flood_frac_pct, flood$comm, function(x) stats::quantile(x, 2/3, names = FALSE))
flood$is_flood <- flood$flood_frac_pct >= thr[flood$comm]
fl <- flood[flood$is_flood, c("comm", "water_year")]

ref <- d[d$grazing_excluded == 1, ]
ref$paddock <- ref$zone_name
grz <- d[d$grazing_excluded == 0, ]

band <- function(df, yv) {
  do.call(rbind, lapply(split(df, list(df$comm, df$water_year), drop = TRUE), function(g) {
    data.frame(comm = g$comm[1], water_year = g$water_year[1],
               lo = stats::quantile(g[[yv]], .25, names = FALSE),
               md = stats::median(g[[yv]]),
               hi = stats::quantile(g[[yv]], .75, names = FALSE))
  }))
}

## ---- Ruling AC 1.3: Bala 29ca is drawn as the outlier it is ----
## The three that behave as a group share ONE colour and are deliberately not separable
## from one another - that is the finding. Bala 29ca is the only distinguishable line.
GROUP_COL <- "#7C837E"; OUTLIER_COL <- "#0F3947"
MIN_LAB_GAP <- 5.5   # y-units between stacked direct labels; Inland needs all four
PADS  <- c("Bala 26ca", "Bala 27ca", "Bala 28ca", "Bala 29ca")
PAL   <- stats::setNames(c(rep(GROUP_COL, 3), OUTLIER_COL), PADS)
LWD   <- stats::setNames(c(rep(0.5, 3), 1.1), PADS)

make_panel <- function(yv, ylab, title, sub) {
  gb <- band(grz, yv)
  # direct labels at the right-hand end of each line; the legend is deleted
  ends <- do.call(rbind, lapply(split(ref, list(ref$paddock, ref$comm), drop = TRUE), function(g) {
    g <- g[!is.na(g[[yv]]), ]
    if (!nrow(g)) return(NULL)
    g <- g[which.max(g$water_year), ]
    s <- shr$share_pct[shr$zone_name == g$paddock[1] & shr$comm == g$comm[1]]
    data.frame(comm = g$comm[1], paddock = g$paddock[1], water_year = g$water_year[1],
               y = g[[yv]][1],
               lab = if (length(s) == 1)
                       sprintf("%s (%.1f%% of paddock)", g$paddock[1], s)
                     else g$paddock[1])
  }))
  # De-collide the direct labels vertically. In Inland all four parts finish within a
  # few points of one another, so the un-nudged labels overprint and none is readable.
  # Push apart from the top down, preserving order; the leader is the line's own colour.
  ends <- do.call(rbind, lapply(split(ends, ends$comm), function(g) {
    g <- g[order(-g$y), ]
    g$y_lab <- g$y
    if (nrow(g) > 1) for (i in 2:nrow(g))
      g$y_lab[i] <- min(g$y_lab[i], g$y_lab[i - 1] - MIN_LAB_GAP)
    g
  }))
  # n grazed parts contributing to the comparator band, per community
  npart <- do.call(rbind, lapply(sort(unique(grz$comm)), function(cm)
    data.frame(comm = cm,
               lab = sprintf("n = %d grazed parts",
                             length(unique(grz$zone_fid[grz$comm == cm]))))))
  ylo <- 0; yhi <- max(c(ref[[yv]], gb$hi), na.rm = TRUE) * 1.06
  cnm <- data.frame(comm = sort(unique(ref$comm)))
  ggplot() +
    geom_rect(data = fl, aes(xmin = water_year - 0.5, xmax = water_year + 0.5,
                             ymin = -Inf, ymax = Inf), fill = "#c6dbef", alpha = 0.5) +
    geom_ribbon(data = gb, aes(water_year, ymin = lo, ymax = hi),
                fill = "grey70", alpha = 0.5) +
    geom_line(data = gb, aes(water_year, md), colour = "grey35", linewidth = 0.6) +
    geom_line(data = ref, aes(water_year, .data[[yv]],
                              colour = paddock, linewidth = paddock)) +
    geom_segment(data = ends, aes(x = water_year, xend = water_year + 0.9,
                                  y = y, yend = y_lab, colour = paddock),
                 linewidth = 0.25, alpha = 0.8) +
    geom_text(data = ends, aes(water_year + 1.2, y_lab, label = lab, colour = paddock),
              hjust = 0, vjust = 0.5, size = 2.7) +
    # community name inside the panel, top left; the facet strip is dropped
    geom_text(data = cnm, aes(x = min(ref$water_year), y = yhi, label = comm),
              hjust = 0, vjust = 1, size = 3.6, fontface = "bold", colour = "grey15") +
    geom_text(data = npart, aes(x = min(ref$water_year), y = ylo, label = lab),
              hjust = 0, vjust = -0.2, size = 2.6, colour = "grey40") +
    facet_wrap(~comm, ncol = 1) +
    scale_colour_manual(values = PAL, guide = "none") +
    scale_linewidth_manual(values = LWD, guide = "none") +
    scale_x_continuous(expand = expansion(mult = c(0.02, 0.26)),
                       breaks = seq(1990, 2020, 10)) +
    coord_cartesian(ylim = c(ylo, yhi)) +
    labs(title = title, subtitle = sub, x = "water year", y = ylab) +
    theme_minimal(base_size = 11) +
    theme(legend.position = "none", strip.text = element_blank(),
          panel.grid.minor = element_blank(),
          plot.title = element_text(face = "bold", size = 13),
          plot.subtitle = element_text(colour = "grey30", size = 9.5))
}

p1 <- make_panel("veg_p05_spatial", "Cover in the poorest patches (%)",
  "Does conserved country hold more cover in its poorest patches than grazed country?",
  "One community per row, common vertical scale. Grey band = middle half of grazed parts, with the median through it.")
p2 <- make_panel("veg_mean", "Average cover (%)",
  "The same comparison, on average cover instead of the poorest patches",
  "One community per row, common vertical scale. Grey band = middle half of grazed parts, with the median through it.")

gayini_write_and_register_figure(
  p1, file.path(fig_dir, "T2_E_paddock_trajectories.png"),
  title = "Does conserved country hold more cover in its poorest patches than grazed country?",
  caption = paste("Support: pixel. Cover in the poorest patches, conserved paddock-community",
                  "parts against the grazed middle-half band, one community per row,",
                  "flood years shaded; Bala 29ca drawn as the outlier."),
  support_level = "pixel", figure_level = "deliverable", run_id = "T2_gateE",
  provenance_note = "zone_community_year grain; mean_of_seasons; conserved-vs-grazed only.",
  width = 8, height = 10.5, dpi = 150)
gayini_write_and_register_figure(
  p2, file.path(fig_dir, "T2_E_paddock_trajectories_mean.png"),
  title = "The same comparison, on average cover instead of the poorest patches",
  caption = paste("Support: pixel. Average cover companion to the poorest-patches panel;",
                  "conserved parts against the grazed middle-half band, one community per row."),
  support_level = "pixel", figure_level = "deliverable", run_id = "T2_gateE",
  provenance_note = "Secondary to the poorest-patches panel.",
  width = 8, height = 10.5, dpi = 150)

## ---- gap report (descriptive; NOT a convergence statistic) ----
gap_tbl <- do.call(rbind, lapply(sort(unique(d$comm)), function(cm) {
  r <- ref[ref$comm == cm, ]; g <- grz[grz$comm == cm, ]
  yr_gap <- sapply(sort(unique(r$water_year)), function(y) {
    mean(r$veg_p05_spatial[r$water_year == y]) -
      stats::median(g$veg_p05_spatial[g$water_year == y]) })
  yrs <- sort(unique(r$water_year))
  early <- mean(yr_gap[yrs <= 1997]); late <- mean(yr_gap[yrs >= 2013])
  # narrows/widens is about the MAGNITUDE of separation, not the signed gap; the
  # sign matters too (reference sits BELOW grazed where gap < 0 - the I-02 case).
  dsep <- abs(late) - abs(early)
  dir <- if (abs(dsep) < 2) "HOLDS" else if (dsep < 0) "NARROWS" else "WIDENS"
  data.frame(community = cm, gap_early_8897 = round(early, 1),
             gap_late_1322 = round(late, 1), sep_change = round(dsep, 1),
             ref_vs_grazed = ifelse(early < 0, "ref BELOW grazed", "ref ABOVE grazed"),
             direction = dir)
}))
utils::write.csv(gap_tbl, file.path(root, "Output/tables/T2_E_gap_report.csv"), row.names = FALSE)
cat("gap (reference mean p05 - grazed median p05), early 1988-97 vs late 2013-22:\n")
print(gap_tbl)

## ---- B2 duration map (pct_above_70) ----
dur <- rast("Output/rasters/veg_duration_8058/veg_persistence_duration_8058.tif")[["pct_above_70"]]
dfr <- as.data.frame(aggregate(dur, 12, "mean", na.rm = TRUE), xy = TRUE, na.rm = TRUE)
names(dfr)[3] <- "pct_above_70"
pmap <- ggplot(dfr, aes(x, y, fill = pct_above_70)) + geom_raster() + coord_equal() +
  scale_fill_viridis_c(name = "% years\ntotal-veg > 70", limits = c(0, 100)) +
  labs(title = "T2 B2 - vegetation persistence: % of observed years total-veg mean > 70%",
       subtitle = "'Greenest for longest'. Denominator = veg_valid_years (NA where < 10). All-pixel.",
       x = "easting (EPSG:8058, m)", y = "northing (m)",
       caption = "Support: pixel. Distinct from T3 veg_p05 (level held 95% of time).") +
  theme_minimal(base_size = 11) + theme(plot.caption = element_text(hjust = 0, size = 8))
gayini_write_and_register_figure(
  pmap, file.path(fig_dir, "T2_B2_duration_map.png"),
  title = "T2 B2 veg persistence duration map",
  caption = paste("Support: pixel. Percent of observed years total-veg mean exceeds 70%;",
                  "veg_valid_years denominator, min-n 10."),
  support_level = "pixel", figure_level = "deliverable", run_id = "T2_gateB2",
  provenance_note = "pct_above_70 band of veg_persistence_duration_8058.", width = 11, height = 7)
cat("\n[done] T2 Gate E figures\n")
