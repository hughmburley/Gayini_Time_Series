# PARTSCATTER - the part-grain companion to the TEMPORAL-1 paddock scatter.
#
# Spec: docs/reference_update/Gayini_CC_spec_PARTSCATTER_update.md.
# Amendments A1-A5, 9 August 2026: opacity channel, full-width caption, "vegetation
# community" written out, caption rewritten to article register, per-community r.
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
# alpha = veg_p05_within_sd (A1): the spread of the per-cell 5th percentile ACROSS THE
#     AREA'S OWN CELLS - the same cells y averages over. High spread = more opaque.
#     This runs AGAINST the convention that opacity reads as confidence, so the legend
#     title says so in words and the footnote says it again. It is not a standard error
#     and does not shrink with area size.
#
# r = correlation across AREAS within a community, computed on the data (A5). NOT taken
#     from the smoother. NO R2, pooled or per-community - that is PARTSCATTER-2.
#     Printed only where a line is drawn; see the prepare step for why.
#
# THE TWO-METRIC PROHIBITION IS ABSOLUTE ON THIS PAGE. veg_p05_spatial does not appear
# and the word "floor" does not appear (spec section 8).
#
# Ruling EH: a per-community smoother is fitted only where the community's central
# 10th-90th percentile of the water axis spans a usable range. The drawn/not-drawn
# decision is READ FROM PARTSCATTER_community_support.csv, never re-decided here.
#
# No p-values, no significance test.

suppressPackageStartupMessages({library(ggplot2); library(DBI); library(RSQLite)})

root <- normalizePath(".", winslash = "/")
source(file.path(root, "R/gayini_figure_register.R"))
source(file.path(root, "R/gayini_gradient_helpers.R"))
source(file.path(root, "R/gayini_veg_regime_functions.R"))
source(file.path(root, "R/gayini_dash2_panels.R"))   # GAYINI_SEASONAL_BASIS_SENTENCE

SRC   <- file.path(root, "Output/temporal/PARTSCATTER_scatter_input.csv")
SUPP  <- file.path(root, "Output/temporal/PARTSCATTER_community_support.csv")
CHAIN <- file.path(root, "Output/temporal/PARTSCATTER_reconciliation_chain.csv")
EXC   <- file.path(root, "Output/temporal/PARTSCATTER_excluded_communities.csv")
stopifnot(file.exists(SRC), file.exists(SUPP), file.exists(CHAIN), file.exists(EXC))

d     <- utils::read.csv(SRC, stringsAsFactors = FALSE)
supp  <- utils::read.csv(SUPP, stringsAsFactors = FALSE)
chain <- utils::read.csv(CHAIN, stringsAsFactors = FALSE)
exc   <- utils::read.csv(EXC, stringsAsFactors = FALSE)
stopifnot(nrow(d) == 100L, nrow(supp) == 3L)

# the 38 excluded areas are NOT all woodland - read the split, never assume it
n_treed <- sum(exc$n_parts[exc$community == "Floodplain Woodland / Forest"])
n_other <- sum(exc$n_parts[exc$community != "Floodplain Woodland / Forest"])
stopifnot(n_treed + n_other == chain$n_parts[1] - chain$n_parts[2])

# ---- colours: the community identity colours, from the canonical class table --------
cls  <- gayini_veg_regime_classes()
mid  <- cls[cls$band == "mid", c("community", "colour")]
PAL  <- stats::setNames(mid$colour, mid$community)

LAY <- c(aeolian  = "Aeolian Chenopod",
         riverine = "Riverine Chenopod",
         inland   = "Inland Floodplain")
COMM_OF <- stats::setNames(supp$community, supp$community_short)
row_of  <- function(s) supp[supp$community_short == s, ]

# ---- legend label: n always, r only where a line is drawn (A5) ----------------------
lab_of <- function(s) {
  r <- row_of(s)
  if (isTRUE(as.logical(r$r_printed_on_figure)))
    sprintf("%s — n %d · r %+.2f", LAY[s], r$n_parts, r$r_across_areas)
  else
    sprintf("%s — n %d · range too narrow to fit", LAY[s], r$n_parts)
}
d$community_lab <- vapply(d$community_short, lab_of, character(1))
lev <- vapply(c("inland", "riverine", "aeolian"), lab_of, character(1))
d$community_lab <- factor(d$community_lab, levels = unname(lev))
PAL_LAB <- stats::setNames(unname(PAL[COMM_OF[c("inland", "riverine", "aeolian")]]),
                           unname(lev))

# ---- which communities get a line: READ, not re-decided (Ruling EH) -----------------
drawn_short <- supp$community_short[as.logical(supp$smoother_drawn)]
d_fit <- d[d$community_short %in% drawn_short, ]
stopifnot(nrow(d_fit) > 0)
message(sprintf("  smoother drawn for: %s   | no line: %s",
                paste(drawn_short, collapse = ", "),
                paste(setdiff(supp$community_short, drawn_short), collapse = ", ")))

INK <- "#26302E"; BODY <- "#5F6B67"; MUTED <- "#8A8378"

aeo <- row_of("aeolian")
n_aeo_below <- sum(d$community_short == "aeolian" & d$mean_share_cells_wet < 7)
# the subtitle spells these as words; assert the data still says what the words say
stopifnot(n_aeo_below == 11L, aeo$n_parts == 12L)

# the wet end of the Inland line rests on ONE area - identified from the data
inl <- d[d$community_short == "inland", ]
wet_solo <- inl[inl$mean_share_cells_wet > 50, ]
stopifnot(nrow(wet_solo) == 1L)

wrap <- function(x, w) paste(strwrap(paste(x, collapse = " "), width = w), collapse = "\n")

# ---- A4: subtitle says what you are looking at --------------------------------------
sub_txt <- wrap(c(
  "Each point is one paddock cut to a single vegetation community —",
  sprintf("%d areas across %d paddocks, sized by the number of cells each holds.",
          nrow(d), length(unique(d$zone_fid))),
  sprintf("In Inland Floodplain country, cover rises across areas ranging from %.0f%% to %.0f%% of cells wet;",
          row_of("inland")$water_min_pct, row_of("inland")$water_max_pct),
  sprintf("in Riverine Chenopod, from %.0f%% to %.0f%%.",
          row_of("riverine")$water_min_pct, row_of("riverine")$water_max_pct),
  "Aeolian Chenopod areas are all dry — eleven of the twelve sit below 7% —",
  "so no line is fitted to them."), 185)

# ---- A4: footnote answers what a careful reader will ask, in order ------------------
foot <- wrap(c(
  "Every number on both axes comes from the satellite grid, with no field measurements mixed in.",
  # 1 - why 100
  sprintf("Of %d paddock × vegetation community areas, %d are woodland or forest and are set aside because ground cover",
          chain$n_parts[1], n_treed),
  sprintf("beneath a canopy does not mean what it means in the open; %d sit outside the three open communities; %d hold fewer",
          n_other, chain$n_parts[2] - chain$n_parts[3]),
  sprintf("than 500 cells (%.0f ha, %.1f%% of the open ground), too few for an average that stands beside one taken over thousands.",
          chain$area_ha[2] - chain$area_ha[3],
          100 * (chain$area_ha[2] - chain$area_ha[3]) / chain$area_ha[2]),
  "An earlier version at this grain counted 115 by keeping areas down to 33 cells.",
  # 2 - what cover means here
  GAYINI_SEASONAL_BASIS_SENTENCE,
  # 3 - what the lines are
  "The lines are display smoothers — no slope is read from them and no significance test is computed.",
  # 4 - where the shading widens
  sprintf("The Inland band opens above 50%% wet because a single area, %s at %.0f%%, carries that end of the range.",
          wet_solo$zone_name[1], wet_solo$mean_share_cells_wet[1]),
  # 5 - clustering, stated not hedged, and the clause that licenses r
  "Areas within one paddock are not independent, but no fitted line here holds two areas from the same paddock,",
  "so the bands are not understating clustering within a line.",
  "r is the correlation across areas within a vegetation community; each area in a fitted line comes from a",
  "different paddock, so these are independent units.",
  # 6 - the opacity channel (A6: direction reversed)
  "Opacity carries how much cover varies between cells inside an area. In a solid point the average describes",
  "nearly every cell; in a faint one it describes few of them well.",
  # 7 - what this does not say
  "This describes how places differ from one another over the record — not what more water would do to any one place."),
  245)

p <- ggplot(d, aes(mean_share_cells_wet, veg_p05_temporal_mean)) +
  # beneath the points, always. Band tinted to ITS OWN community - two grey bands
  # overlapping between 17% and 30% wet could not be attributed to their lines.
  geom_smooth(data = d_fit, aes(group = community_lab, colour = community_lab,
                                fill = community_lab),
              method = "loess", formula = y ~ x, se = TRUE,
              alpha = 0.15, linewidth = 0.8, show.legend = FALSE) +
  scale_fill_manual(values = PAL_LAB, guide = "none") +
  geom_point(aes(colour = community_lab, size = n_cells, alpha = veg_p05_within_sd)) +
  scale_colour_manual(values = PAL_LAB, name = "Vegetation community",
                      guide = guide_legend(order = 1,
                                           override.aes = list(size = 4, alpha = 1))) +
  scale_size_continuous(range = c(1.8, 9), name = "Cells in the area",
                        labels = function(x) format(x, big.mark = ","),
                        guide = guide_legend(order = 2,
                                             override.aes = list(alpha = 0.85))) +
  # A6 REVERSES A1's direction: LOW spread -> opaque, HIGH spread -> faint. `range` is
  # given high-to-low deliberately - rescale() maps the SMALLEST sd to range[1] - so
  # the least-varied areas are the solid ones. Asserted below, not assumed.
  #
  # Still floored at 0.45: this is a FOURTH channel on a figure already carrying colour,
  # size and position, and a near-transparent end would lose those areas altogether.
  #
  # The reversal puts the channel back in step with the convention that solid reads as
  # reliable, which is what A1 was fighting. That makes the figure easier to read and
  # the STANDARD-ERROR misreading EASIER TO MAKE, which is why the "not a standard
  # error, does not shrink with area size" note is strengthened rather than dropped.
  scale_alpha_continuous(range = c(1, 0.45),
                         name = paste("How well the point describes its cells",
                                      "darker areas vary less from cell to cell",
                                      sep = "\n"),
                         labels = function(x) sprintf("%.0f", x),
                         guide = guide_legend(order = 3,
                                              override.aes = list(size = 4,
                                                                  colour = INK))) +
  coord_cartesian(xlim = c(0, max(d$mean_share_cells_wet) * 1.04)) +
  labs(
    title = "Wetter country holds more cover in its poorest seasons",
    subtitle = sub_txt,
    x = "Share of the area's cells seen wet, mean over years (%)",   # Rulings AZ / CX
    y = "5th-percentile ground cover, mean of cells (%)",            # Ruling EC
    caption = foot) +
  theme_minimal(base_size = 12) +
  theme(panel.grid.minor = element_blank(),
        panel.grid.major = element_line(colour = "#EFEBE0", linewidth = 0.4),
        axis.text = element_text(colour = MUTED),
        axis.title = element_text(colour = BODY, size = 11),
        plot.title = element_text(colour = INK, face = "bold", size = 17),
        plot.subtitle = element_text(colour = BODY, size = 10.2, lineheight = 1.3),
        plot.caption = element_text(colour = MUTED, size = 7.4, hjust = 0,
                                    lineheight = 1.3),
        # A2: caption spans the whole plot, edge to edge, not the panel column
        plot.title.position = "plot", plot.caption.position = "plot",
        plot.margin = margin(14, 18, 10, 14),
        legend.position = "right", legend.title = element_text(size = 9.5, colour = BODY),
        legend.text = element_text(size = 9, colour = BODY),
        legend.key.height = unit(0.95, "lines"))

# ---- A6 direction check, and it must be able to FAIL --------------------------------
# Reads the alpha the BUILT plot actually assigned, not the comment above the scale.
# A reversed `range` argument is the kind of instruction that can silently fail to take
# effect while every other signal reports success (I-60).
pb  <- ggplot2::ggplot_build(p)
lyr <- Filter(function(z) nrow(z) == nrow(d) && "alpha" %in% names(z), pb$data)
stopifnot(length(lyr) >= 1L)
al  <- lyr[[1]]$alpha
rho <- stats::cor(al, d$veg_p05_within_sd)
cat(sprintf("  [A6] alpha vs within-area spread: rho %+.4f ; alpha %.3f-%.3f\n",
            rho, min(al), max(al)))
if (is.na(rho) || rho > -0.999)
  stop(sprintf("A6: opacity is NOT reversed against within-area spread (rho %+.4f)", rho))
if (abs(min(al) - 0.45) > 0.005 || abs(max(al) - 1) > 0.005)
  stop(sprintf("A6: ramp is not 1.0 down to 0.45 (got %.3f-%.3f)", min(al), max(al)))
# the least-varied area must be the solid one, and the most-varied the faintest
stopifnot(which.min(al) == which.max(d$veg_p05_within_sd),
          which.max(al) == which.min(d$veg_p05_within_sd))

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
  "OPACITY (A1, direction REVERSED under A6) is veg_p05_within_sd, the SPATIAL spread of ",
  "the per-cell percentile across the part's own cells, ramped 1.0 down to 0.45 with LOW ",
  "spread the MORE opaque: a solid point's mean describes nearly every one of its cells. ",
  "IT IS NOT A STANDARD ERROR AND DOES NOT SHRINK WITH PART SIZE, and the reversal makes ",
  "that misreading EASIER rather than harder, because solid now reads as reliable in the ",
  "conventional direction - a 588-cell part and a 32,399-cell part with the same internal ",
  "spread are drawn equally solid. Reconciliation chain: 156 ",
  "paddock x community areas -> 118 non-treed -> 100 at or above the 500-cell floor. ",
  "The client slide's 115 is this project's own PARTREG count at a 33-cell floor over ",
  "the SAME three non-treed communities, not eight. One loess per community under ",
  "Ruling EH, drawn only where the community's central 10th-90th percentile water range ",
  "spans at least 10 pp: Inland 29.05 and Riverine 22.94 yes, Aeolian 4.39 no. ",
  "r is computed ACROSS AREAS on the data, never taken from the smoother; no R2, pooled ",
  "or per-community. Inland r = ", sprintf("%+.3f", row_of("inland")$r_across_areas),
  ", Riverine r = ", sprintf("%+.3f", row_of("riverine")$r_across_areas),
  ", Aeolian r = ", sprintf("%+.3f", row_of("aeolian")$r_across_areas),
  " (retained here, NOT printed on the figure - noise across a 1-12% range, and beside ",
  "two positive values it would read as a negative response to water). Parts within a ",
  "paddock are not independent (L-01), but within each fitted line every part comes from ",
  "a distinct paddock. Scope: treed_context_flag = 0 AND regime_band <> 'context', ",
  "1988-2022.")

r <- gayini_write_and_register_figure(
  plot = p,
  path = file.path(root, "Output/figures/temporal/PARTSCATTER_part_temporal_p05_vs_water.png"),
  title = paste("Mean per-cell temporal 5th-percentile ground cover against wetness,",
                "100 paddock x community parts"),
  caption = caption, support_level = "pixel", figure_level = "part",
  run_id = "PARTSCATTER_20260809", domain = "client_deliverables",
  recommended_use = "client presentation",
  provenance_note = paste(
    "PARTSCATTER, amendments A1-A5. Regrouping of TEMPORAL-1 to paddock x community",
    "part grain; no raster opened and no new metric computed. Built by",
    "scripts/14_diag/PARTSCATTER_prepare.py from",
    "Output/census/gayini_pixel_census_8058.parquet joined to",
    "gayini_pixel_zone_assignment.parquet. THE FIVE QUALIFIERS, carried here because",
    "figure_asset has no columns for them (held under DJ):",
    "support_level = pixel;",
    "scope_filter_sql = treed_context_flag = 0 AND regime_band <> 'context' AND zone_fid",
    "IS NOT NULL AND n_cells >= 500;",
    "pixel_area_ha = 0.062351428 (derived from PIXEL_SIDE_M = 24.970268);",
    "denominator_ha = 49436.1 mapped, the plotted parts' own cells;",
    "period_label = 1988-2022 (35 water years).",
    "Water surface: COUNTED-8058 (Ruling DM - the census PARQUET, not the view).",
    "Rulings AZ/CX govern the x label; EC the y label; EH the per-community smoother;",
    "DA the community range wording."),
  width = 13.333, height = 7.5, dpi = 150)

cat(sprintf("  [registered] %s  %s\n", basename(r$path), substr(r$checksum_sha256, 1, 12)))
cat(sprintf("  x %.2f-%.2f ; y %.2f-%.2f ; within-area sd %.2f-%.2f ; parts %d ; cells %s\n",
            min(d$mean_share_cells_wet), max(d$mean_share_cells_wet),
            min(d$veg_p05_temporal_mean), max(d$veg_p05_temporal_mean),
            min(d$veg_p05_within_sd), max(d$veg_p05_within_sd),
            nrow(d), format(sum(d$n_cells), big.mark = ",")))
