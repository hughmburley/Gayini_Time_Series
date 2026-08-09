# PARTSCATTER - the part-grain companion to the TEMPORAL-1 paddock scatter.
#
# Spec: docs/reference_update/Gayini_CC_spec_PARTSCATTER_update.md.
#
# y = veg_p05_temporal_mean: the mean over a PART's own cells of EACH CELL'S TEMPORAL
#     5th percentile of total vegetation cover. SEASONAL basis - identical definition
#     to the paddock figure, so the two are the same quantity at two grains.
#
# x = the share of the PART's cells seen wet, MEAN OVER YEARS (Rulings AZ / CX). Never
#     a between-year flood frequency and not labelled as one. Verified in
#     PARTSCATTER_prepare.py to reproduce the published paddock mean_flood at paddock
#     grain (max 0.005 pp over 64) and PARTREG's independent part-year series at part
#     grain (max 0.000012 pp over 100).
#
# THE TWO-METRIC PROHIBITION IS ABSOLUTE ON THIS PAGE. veg_p05_spatial does not appear
# and the word "floor" does not appear (spec section 8).
#
# ONE SMOOTHER PER COMMUNITY, and only where the community's own water range supports
# one. The drawn/not-drawn decision is READ FROM PARTSCATTER_community_support.csv - it
# is taken in the prepare step against a stated threshold, never re-decided here.
#
# No p-values. The trend is a display smoother and no coefficient is taken from it.

suppressPackageStartupMessages({library(ggplot2); library(DBI); library(RSQLite)})

root <- normalizePath(".", winslash = "/")
source(file.path(root, "R/gayini_figure_register.R"))
source(file.path(root, "R/gayini_gradient_helpers.R"))
source(file.path(root, "R/gayini_veg_regime_functions.R"))
source(file.path(root, "R/gayini_dash2_panels.R"))   # GAYINI_SEASONAL_BASIS_SENTENCE

SRC  <- file.path(root, "Output/temporal/PARTSCATTER_scatter_input.csv")
SUPP <- file.path(root, "Output/temporal/PARTSCATTER_community_support.csv")
CHAIN <- file.path(root, "Output/temporal/PARTSCATTER_reconciliation_chain.csv")
EXC  <- file.path(root, "Output/temporal/PARTSCATTER_excluded_communities.csv")
stopifnot(file.exists(SRC), file.exists(SUPP), file.exists(CHAIN), file.exists(EXC))

d     <- utils::read.csv(SRC, stringsAsFactors = FALSE)
supp  <- utils::read.csv(SUPP, stringsAsFactors = FALSE)
chain <- utils::read.csv(CHAIN, stringsAsFactors = FALSE)
exc   <- utils::read.csv(EXC, stringsAsFactors = FALSE)
stopifnot(nrow(d) == 100L, nrow(supp) == 3L)

# the 38 excluded areas are NOT all woodland - read the split, never assume it
n_treed <- sum(exc$n_parts[exc$community == "Floodplain Woodland / Forest"])
n_minor <- sum(exc$n_parts[exc$community != "Floodplain Woodland / Forest"])
stopifnot(n_treed + n_minor == chain$n_parts[1] - chain$n_parts[2])

# ---- colours: the community identity colours, from the canonical class table --------
# Mid band per focus community, so the scatter's colours are the same identities the
# Council sees on the community maps rather than a second palette for one figure.
cls  <- gayini_veg_regime_classes()
mid  <- cls[cls$band == "mid", c("community", "colour")]
PAL  <- stats::setNames(mid$colour, mid$community)

LAY <- c(aeolian  = "Aeolian Chenopod",
         riverine = "Riverine Chenopod",
         inland   = "Inland Floodplain")
COMM_OF <- stats::setNames(supp$community, supp$community_short)

# legend label carries each community's n, so the counts are on the face not in a table
n_by <- stats::setNames(supp$n_parts, supp$community_short)
lab_of <- function(s) sprintf("%s  (%d)", LAY[s], n_by[s])
d$community_lab <- lab_of(d$community_short)
lev <- unname(lab_of(c("inland", "riverine", "aeolian")))
d$community_lab <- factor(d$community_lab, levels = lev)
PAL_LAB <- stats::setNames(unname(PAL[COMM_OF[c("inland", "riverine", "aeolian")]]), lev)

# ---- which communities get a line: READ, not re-decided -----------------------------
drawn_short <- supp$community_short[as.logical(supp$smoother_drawn)]
d_fit <- d[d$community_short %in% drawn_short, ]
stopifnot(nrow(d_fit) > 0)
message(sprintf("  smoother drawn for: %s   | no line: %s",
                paste(drawn_short, collapse = ", "),
                paste(setdiff(supp$community_short, drawn_short), collapse = ", ")))

INK <- "#26302E"; BODY <- "#5F6B67"; MUTED <- "#8A8378"

# range sentence per community, in that community's OWN supported range (Ruling DA).
rng <- function(s) {
  r <- supp[supp$community_short == s, ]
  sprintf("%s from %.0f%% to %.0f%% of its cells wet", LAY[s], r$water_min_pct,
          r$water_max_pct)
}
aeo <- supp[supp$community_short == "aeolian", ]
n_aeo_below <- sum(d$community_short == "aeolian" & d$mean_share_cells_wet < 7)

# the wet end of the Inland line rests on ONE area - the same disclosure the paddock
# figure carries. Identified from the data, not typed.
inl <- d[d$community_short == "inland", ]
wet_solo <- inl[inl$mean_share_cells_wet > 50, ]

# subtitle is WRAPPED. Unwrapped, its second line ran off the right edge of the canvas.
sub_txt <- paste(strwrap(paste0(
  "Each point is one paddock x community area - a single paddock cut to one plant ",
  "community - averaged over its own cells. 100 areas, sized by how many cells each ",
  "holds. Cover rises with water in ", rng("inland"), ", and in ", rng("riverine"),
  ". Aeolian Chenopod areas sit across too narrow a range of wetness to show a pattern, ",
  "so no line is fitted to them."), width = 150), collapse = "\n")

p <- ggplot(d, aes(mean_share_cells_wet, veg_p05_temporal_mean)) +
  # beneath the points, always: a line over the markers obscures them however pale.
  # The band is tinted to ITS OWN community - two grey bands overlapping between 17%
  # and 30% wet could not be attributed to their lines.
  geom_smooth(data = d_fit, aes(group = community_lab, colour = community_lab,
                                fill = community_lab),
              method = "loess", formula = y ~ x, se = TRUE,
              alpha = 0.15, linewidth = 0.8, show.legend = FALSE) +
  scale_fill_manual(values = PAL_LAB, guide = "none") +
  geom_point(aes(colour = community_lab, size = n_cells), alpha = 0.85) +
  scale_colour_manual(values = PAL_LAB, name = "Plant community",
                      guide = guide_legend(order = 1,
                                           override.aes = list(size = 4, alpha = 1))) +
  scale_size_continuous(range = c(1.8, 9), name = "Cells in the area",
                        labels = function(x) format(x, big.mark = ","),
                        guide = guide_legend(order = 2)) +
  coord_cartesian(xlim = c(0, max(d$mean_share_cells_wet) * 1.04)) +
  labs(
    title = "Wetter country holds more cover in its poorest seasons",
    subtitle = sub_txt,
    x = "Share of the area's cells seen wet, mean over years (%)",       # Rulings AZ / CX
    y = "5th-percentile ground cover, mean of cells (%)",                # Ruling EC
    caption = paste(strwrap(paste(
      "Support: pixel throughout - both axes describe census cells, and no site or plot",
      "measurement appears, so the two supports are never mixed.",
      sprintf("Of the %d paddock x community areas inside the %d paddocks, %d are woodland or forest",
              chain$n_parts[1], length(unique(d$zone_fid)), n_treed),
      "country, set aside because ground cover under a canopy does not mean what it means in the open,",
      sprintf("and %d are minor units outside the three open communities. That leaves the three shown here,", n_minor),
      "not the full community list.",
      sprintf("A further %d areas hold fewer than 500 cells (%.0f ha, %.1f%% of the open ground) and are dropped,",
              chain$n_parts[2] - chain$n_parts[3],
              chain$area_ha[2] - chain$area_ha[3],
              100 * (chain$area_ha[2] - chain$area_ha[3]) / chain$area_ha[2]),
      "because an average over a few hundred cells does not stand beside one taken over thousands.",
      sprintf("An earlier series at this same grain counted 115 areas over the same three communities; it kept areas down to %d cells.",
              33L),
      sprintf("Aeolian Chenopod spans %.0f%% to %.0f%%, and %d of its %d areas lie below 7%%, too narrow a range to fit a line across.",
              aeo$water_min_pct, aeo$water_max_pct, n_aeo_below, aeo$n_parts),
      GAYINI_SEASONAL_BASIS_SENTENCE,
      sprintf("The Inland band widens above 50%% wet because a single area carries that end of it - %s, at %.0f%%.",
              wet_solo$zone_name[1], wet_solo$mean_share_cells_wet[1]),
      "Areas within one paddock are not independent, so a shaded band is display only and understates",
      "that clustering; no fitted line here holds two areas from the same paddock. Lines are display",
      "smoothers - no slope is read off them and no p-value is computed. No cause is attributed: this",
      "describes how places differ from one another over the record, not what more water would do to",
      "any one place."), width = 168), collapse = "\n")) +
  theme_minimal(base_size = 12) +
  theme(panel.grid.minor = element_blank(),
        panel.grid.major = element_line(colour = "#EFEBE0", linewidth = 0.4),
        axis.text = element_text(colour = MUTED),
        axis.title = element_text(colour = BODY, size = 11),
        plot.title = element_text(colour = INK, face = "bold", size = 17),
        plot.subtitle = element_text(colour = BODY, size = 10.2, lineheight = 1.3),
        plot.caption = element_text(colour = MUTED, size = 7.4, hjust = 0, lineheight = 1.25),
        plot.title.position = "plot", plot.caption.position = "plot",
        plot.margin = margin(14, 18, 10, 14),
        legend.position = "right", legend.title = element_text(size = 9.5, colour = BODY),
        legend.text = element_text(size = 9, colour = BODY))

caption <- paste0(
  "Support: pixel. ", nrow(d), " paddock x community parts in ",
  length(unique(d$zone_fid)), " management zones, ", format(sum(d$n_cells), big.mark = ","),
  " non-treed census cells. Y is veg_p05_temporal_mean: the unweighted mean, over a ",
  "PART's own cells, of each cell's TEMPORAL 5th percentile of total vegetation cover, ",
  "SEASONAL BASIS (140 seasonal composites, MIN_SEASONS = 50) - the same quantity the ",
  "TEMPORAL-1 paddock figure carries, regrouped to part grain. X is the share of the ",
  "PART's cells seen wet, MEAN OVER YEARS (%), Rulings AZ / CX - NOT a between-year ",
  "flood frequency; computed as the mean over the part's cells of the census parquet's ",
  "COUNTED per-cell flood_freq_pct, which is exactly equal because valid_years = 35 on ",
  "every cell, and verified against the published paddock mean_flood (max 0.005 pp over ",
  "64 paddocks) and against PARTREG's inund_pct series (max 0.000012 pp over 100 parts). ",
  "This is a DISTINCT METRIC from veg_p05_spatial and the two are never co-plotted. ",
  "Reconciliation chain: 156 paddock x community areas -> 118 non-treed -> 100 at or ",
  "above the 500-cell floor. The client slide's 115 is this project's own PARTREG count ",
  "at a 33-cell floor over the SAME three non-treed communities, not eight. One loess ",
  "per community, drawn only where the community's central 10th-90th percentile water ",
  "range spans at least 10 pp: Inland and Riverine yes, Aeolian no (4.4 pp). No ",
  "coefficient is taken from any smoother and no p-value is computed. Parts within a ",
  "paddock are not independent (L-01), so bands are display only; within each fitted ",
  "line, however, every part comes from a distinct paddock. Scope: ",
  "treed_context_flag = 0 AND regime_band <> 'context', 1988-2022.")

r <- gayini_write_and_register_figure(
  plot = p,
  path = file.path(root, "Output/figures/temporal/PARTSCATTER_part_temporal_p05_vs_water.png"),
  title = paste("Mean per-cell temporal 5th-percentile ground cover against wetness,",
                "100 paddock x community parts"),
  caption = caption, support_level = "pixel", figure_level = "part",
  run_id = "PARTSCATTER_20260809", domain = "client_deliverables",
  recommended_use = "client presentation",
  provenance_note = paste(
    "PARTSCATTER. Regrouping of TEMPORAL-1 to paddock x community part grain; no raster",
    "opened and no new metric computed. Built by scripts/14_diag/PARTSCATTER_prepare.py",
    "from Output/census/gayini_pixel_census_8058.parquet joined to",
    "gayini_pixel_zone_assignment.parquet. THE FIVE QUALIFIERS, carried here because",
    "figure_asset has no columns for them:",
    "support_level = pixel;",
    "scope_filter_sql = treed_context_flag = 0 AND regime_band <> 'context' AND zone_fid",
    "IS NOT NULL AND n_cells >= 500;",
    "pixel_area_ha = 0.062351428 (derived from PIXEL_SIDE_M = 24.970268);",
    "denominator_ha = 49436.1 mapped, the plotted parts' own cells;",
    "period_label = 1988-2022 (35 water years).",
    "Water surface: COUNTED-8058 (Ruling DM - the census PARQUET, not the view).",
    "Rulings AZ/CX govern the x label; EC the y label; DA the community range wording."),
  width = 13.333, height = 7.5, dpi = 150)

cat(sprintf("  [registered] %s  %s\n", basename(r$path), substr(r$checksum_sha256, 1, 12)))
cat(sprintf("  x range %.2f - %.2f ; y range %.2f - %.2f ; parts %d ; cells %s\n",
            min(d$mean_share_cells_wet), max(d$mean_share_cells_wet),
            min(d$veg_p05_temporal_mean), max(d$veg_p05_temporal_mean),
            nrow(d), format(sum(d$n_cells), big.mark = ",")))
