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
DBI::dbDisconnect(con)

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

make_panel <- function(yv, ylab, title, sub) {
  gb <- band(grz, yv)
  ggplot() +
    geom_rect(data = fl, aes(xmin = water_year - 0.5, xmax = water_year + 0.5,
                             ymin = -Inf, ymax = Inf), fill = "#c6dbef", alpha = 0.5) +
    geom_ribbon(data = gb, aes(water_year, ymin = lo, ymax = hi),
                fill = "grey70", alpha = 0.5) +
    geom_line(data = gb, aes(water_year, md), colour = "grey35", linewidth = 0.6) +
    geom_line(data = ref, aes(water_year, .data[[yv]], colour = paddock), linewidth = 0.9) +
    geom_point(data = ref, aes(water_year, .data[[yv]], colour = paddock), size = 0.9) +
    facet_wrap(~comm, nrow = 1) +
    scale_colour_brewer(palette = "Set1", name = "Reference\n(No grazing)") +
    labs(title = title, subtitle = sub, x = "water year", y = ylab,
         caption = paste0(
           "Support: pixel (aggregation_unit = zone_community_year, min ", MIN_PX,
           " px/cell). Reference = ", length(unique(ref$zone_fid)),
           " No-grazing paddocks (Bala 26-29ca), shown individually; grey = 60 grazed",
           " zones (IQR band + median). Blue = top-tercile flood years per community.\n",
           "veg_p05_spatial is a WITHIN-year SPATIAL percentile, NOT the census temporal",
           " veg_p05. Cropping history unavailable (RESERVED cols NULL) => this is",
           " conserved-vs-grazed, NOT conserved-vs-formerly-cropped.")) +
    theme_minimal(base_size = 11) +
    theme(legend.position = "right", plot.caption = element_text(hjust = 0, size = 8))
}

p1 <- make_panel("veg_p05_spatial", "veg_p05_spatial (%)",
  "T2 E - Paddock vegetation-floor trajectories, 1988-2023 (reference vs grazed)",
  "Floor (p05) of within-year cover; the band where the flood signal lives.")
p2 <- make_panel("veg_mean", "veg_mean (%)",
  "T2 E - Paddock mean-cover trajectories, 1988-2023 (reference vs grazed)",
  "Mean cover (secondary panel; shows why the floor, not the mean, was chosen).")

gayini_write_and_register_figure(
  p1, file.path(fig_dir, "T2_E_paddock_trajectories.png"),
  title = "T2 E paddock floor trajectories",
  caption = paste("Support: pixel. veg_p05_spatial trajectories, reference paddocks",
                  "individually vs grazed IQR band, faceted by community, flood years shaded."),
  support_level = "pixel", figure_level = "deliverable", run_id = "T2_gateE",
  provenance_note = "zone_community_year grain; mean_of_seasons; conserved-vs-grazed only.",
  width = 14, height = 6)
gayini_write_and_register_figure(
  p2, file.path(fig_dir, "T2_E_paddock_trajectories_mean.png"),
  title = "T2 E paddock mean-cover trajectories",
  caption = paste("Support: pixel. veg_mean secondary variant of the floor panel;",
                  "reference paddocks individually vs grazed band, faceted by community."),
  support_level = "pixel", figure_level = "deliverable", run_id = "T2_gateE",
  provenance_note = "Secondary to T2_E floor panel.", width = 14, height = 6)

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
