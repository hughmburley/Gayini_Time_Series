# UNZONED v3 Arm A - the descriptive offsets and figures A1 and A2.
#
# Spec: docs/reference_update/Gayini_CC_spec_UNZONED_v3.md sections 3.3-3.5.
#
# ARM A IS DESCRIPTIVE (section 3.4). There is NO registered line on the temporal
# metric - PARTSCATTER's curves are display smoothers and no coefficient may be taken
# from one - so nothing here is a residual and nothing here is a test. The quantity
# reported is a DESCRIPTIVE OFFSET: the median vertical distance, in percentage points,
# from the zoned smoother's predicted value, with its sign and interquartile range.
#
# EXTRAPOLATION IS REFUSED, NOT SILENTLY PERFORMED. A patch whose water value falls
# outside the zoned parts' observed range for its community gets NO predicted value and
# is excluded from that community's offset, with the count reported. loess returns NA
# there and that NA is honoured rather than filled.
#
# Ruling EH plus section 3.1: a community is fitted only where it clears BOTH a
# ten-patch count and a central 10th-90th percentile water range. Read from the support
# table, never re-decided here.
#
# Ruling EJ: the opacity direction is asserted on the BUILT plot, three separate
# assertions, because a correlation, an endpoint and a mark-to-legend pairing are three
# different failures.
#
# NAMING (section 2): "unzoned standard-grazing country". Never a reference, a control,
# or unmanaged.

suppressPackageStartupMessages({library(ggplot2); library(DBI); library(RSQLite)})

root <- normalizePath(".", winslash = "/")
source(file.path(root, "R/gayini_figure_register.R"))
source(file.path(root, "R/gayini_gradient_helpers.R"))
source(file.path(root, "R/gayini_veg_regime_functions.R"))
source(file.path(root, "R/gayini_dash2_panels.R"))   # GAYINI_SEASONAL_BASIS_SENTENCE

OUTD <- file.path(root, "Output", "unzoned")
ZS  <- file.path(root, "Output/temporal/PARTSCATTER_scatter_input.csv")
ZSU <- file.path(root, "Output/temporal/PARTSCATTER_community_support.csv")
US  <- file.path(OUTD, "UNZONED_v3_armA_scatter_input.csv")
USU <- file.path(OUTD, "UNZONED_v3_armA_community_support.csv")
SEL <- file.path(OUTD, "UNZONED_v3_armA_selection_counts.csv")
stopifnot(file.exists(ZS), file.exists(ZSU), file.exists(US), file.exists(USU))

zd  <- utils::read.csv(ZS,  stringsAsFactors = FALSE)
zsu <- utils::read.csv(ZSU, stringsAsFactors = FALSE)
ud  <- utils::read.csv(US,  stringsAsFactors = FALSE)
usu <- utils::read.csv(USU, stringsAsFactors = FALSE)
sel <- utils::read.csv(SEL, stringsAsFactors = FALSE)
stopifnot(nrow(zd) == 100L, nrow(ud) == 39L)

INK <- "#26302E"; BODY <- "#5F6B67"; MUTED <- "#8A8378"
LAY <- c(aeolian = "Aeolian Chenopod", riverine = "Riverine Chenopod",
         inland = "Inland Floodplain")
ORD <- c("inland", "riverine", "aeolian")

cls <- gayini_veg_regime_classes()
mid <- cls[cls$band == "mid", c("community", "colour")]
PAL <- stats::setNames(mid$colour, mid$community)
COMM_OF <- stats::setNames(usu$community, usu$community_short)
PAL_SHORT <- stats::setNames(unname(PAL[COMM_OF[ORD]]), ORD)

wrap <- function(x, w) paste(strwrap(paste(x, collapse = " "), width = w), collapse = "\n")

# ---- section 3.4 · descriptive offsets against the zoned smoother --------------------
# Same loess settings ggplot draws with, so the offset is against the curve on the page.
fit_of <- function(cs) {
  k <- zd$community_short == cs
  stats::loess(veg_p05_temporal_mean ~ mean_share_cells_wet, data = zd[k, ],
               span = 0.75, degree = 2)
}
off_rows <- list()
ud$zoned_predicted <- NA_real_
for (cs in ORD) {
  ku <- ud$community_short == cs
  if (!any(ku)) next
  kz <- zd$community_short == cs
  m <- fit_of(cs)
  pr <- stats::predict(m, newdata = data.frame(mean_share_cells_wet =
                                                 ud$mean_share_cells_wet[ku]))
  ud$zoned_predicted[ku] <- pr
  d <- ud$veg_p05_temporal_mean[ku] - pr
  n_out <- sum(is.na(pr))
  d <- d[!is.na(d)]
  off_rows[[length(off_rows) + 1L]] <- data.frame(
    community = unname(LAY[cs]), community_short = cs,
    n_patches = sum(ku), n_outside_zoned_water_range = n_out,
    n_with_offset = length(d),
    zoned_water_min = min(zd$mean_share_cells_wet[kz]),
    zoned_water_max = max(zd$mean_share_cells_wet[kz]),
    unzoned_water_min = min(ud$mean_share_cells_wet[ku]),
    unzoned_water_max = max(ud$mean_share_cells_wet[ku]),
    median_offset_pp = if (length(d)) stats::median(d) else NA_real_,
    offset_q1_pp = if (length(d)) unname(stats::quantile(d, .25)) else NA_real_,
    offset_q3_pp = if (length(d)) unname(stats::quantile(d, .75)) else NA_real_)
}
off <- do.call(rbind, off_rows)
off$quantity <- "DESCRIPTIVE OFFSET - not a residual, not a test"
off$basis <- paste("vertical distance in pp from the zoned parts' display smoother for",
                   "the same vegetation community, at the patch's own water value")
off$extrapolation_rule <- paste("a patch outside the zoned parts' observed water range",
                                "for its community gets NO predicted value and is",
                                "excluded; loess returns NA there and the NA is honoured")
off$metric <- "veg_p05_temporal_mean"
off$support_level <- "pixel"
off$period_label <- "1988-2022 (35 water years)"
utils::write.csv(off, file.path(OUTD, "UNZONED_v3_armA_descriptive_offsets.csv"),
                 row.names = FALSE)
cat("\n== section 3.4 descriptive offsets ==\n")
print(off[, c("community_short", "n_patches", "n_outside_zoned_water_range",
              "n_with_offset", "unzoned_water_min", "unzoned_water_max",
              "zoned_water_min", "zoned_water_max", "median_offset_pp",
              "offset_q1_pp", "offset_q3_pp")], row.names = FALSE, digits = 4)

# ---- Ruling EJ · three assertions on the BUILT plot ----------------------------------
assert_alpha <- function(p, dat, tag) {
  pb <- ggplot2::ggplot_build(p)
  ly <- Filter(function(z) nrow(z) == nrow(dat) && "alpha" %in% names(z), pb$data)
  stopifnot(length(ly) >= 1L)
  al <- ly[[1]]$alpha
  rho <- stats::cor(al, dat$veg_p05_within_sd)
  cat(sprintf("  [EJ %s] rho %+.4f ; alpha %.3f-%.3f\n", tag, rho, min(al), max(al)))
  if (is.na(rho) || rho > -0.999)
    stop(sprintf("EJ %s: opacity not reversed against spread (rho %+.4f)", tag, rho))
  if (abs(min(al) - 0.45) > 0.005 || abs(max(al) - 1) > 0.005)
    stop(sprintf("EJ %s: ramp is not 1.0 down to 0.45 (%.3f-%.3f)", tag, min(al), max(al)))
  if (which.min(al) != which.max(dat$veg_p05_within_sd) ||
      which.max(al) != which.min(dat$veg_p05_within_sd))
    stop(sprintf("EJ %s: mark-to-value pairing is wrong", tag))
  invisible(TRUE)
}

ALPHA_TITLE <- paste("How well the point describes its cells",
                     "darker areas vary less from cell to cell", sep = "\n")
Y_LAB <- "5th-percentile ground cover, mean of cells (%)"
X_LAB <- "Share of the area's cells seen wet, mean over years (%)"

base_theme <- function() {
  theme_minimal(base_size = 12) +
    theme(panel.grid.minor = element_blank(),
          panel.grid.major = element_line(colour = "#EFEBE0", linewidth = 0.4),
          axis.text = element_text(colour = MUTED),
          axis.title = element_text(colour = BODY, size = 11),
          plot.title = element_text(colour = INK, face = "bold", size = 17),
          plot.subtitle = element_text(colour = BODY, size = 10.2, lineheight = 1.3),
          plot.caption = element_text(colour = MUTED, size = 7.4, hjust = 0,
                                      lineheight = 1.3),
          plot.title.position = "plot", plot.caption.position = "plot",
          plot.margin = margin(14, 18, 10, 14),
          legend.position = "right",
          legend.title = element_text(size = 9.5, colour = BODY),
          legend.text = element_text(size = 9, colour = BODY),
          legend.key.height = unit(0.95, "lines"))
}

# =====================================================================================
# FIGURE A1 · unzoned alone
# =====================================================================================
lab_u <- function(cs) {
  r <- usu[usu$community_short == cs, ]
  if (nrow(r) == 0) return(NA_character_)
  if (isTRUE(as.logical(r$r_printed_on_figure)))
    sprintf("%s — n %d · r %+.2f", LAY[cs], r$n_patches, r$r_across_patches)
  else if (!isTRUE(as.logical(r$passes_patch_count)))
    sprintf("%s — n %d · too few patches to fit", LAY[cs], r$n_patches)
  else
    sprintf("%s — n %d · range too narrow to fit", LAY[cs], r$n_patches)
}
present <- ORD[ORD %in% ud$community_short]
lev_u <- vapply(present, lab_u, character(1))
ud$community_lab <- factor(vapply(ud$community_short, lab_u, character(1)),
                           levels = unname(lev_u))
PAL_U <- stats::setNames(unname(PAL_SHORT[present]), unname(lev_u))

drawn_u <- usu$community_short[as.logical(usu$smoother_drawn)]
ud_fit <- ud[ud$community_short %in% drawn_u, ]
cat(sprintf("\n  A1 smoother drawn for: %s | no line: %s\n",
            paste(drawn_u, collapse = ", "),
            paste(setdiff(usu$community_short, drawn_u), collapse = ", ")))

inl_u <- usu[usu$community_short == "inland", ]
riv_u <- usu[usu$community_short == "riverine", ]
aeo_u <- usu[usu$community_short == "aeolian", ]

sub_a1 <- wrap(c(
  "Each point is one continuous tract of unzoned standard-grazing country, cut where it",
  "changes vegetation community and averaged over its own cells —",
  sprintf("%d tracts across %s hectares, sized by the number of cells each holds.",
          nrow(ud), format(round(sum(ud$area_ha)), big.mark = ",")),
  sprintf("Cover rises with water in Inland Floodplain country, across tracts ranging from %.0f%% to %.0f%% of cells wet.",
          inl_u$water_min_pct, inl_u$water_max_pct),
  sprintf("Riverine Chenopod carries %d tracts and Aeolian Chenopod %d — too few to fit a line to either.",
          riv_u$n_patches, aeo_u$n_patches)), 185)

foot_a1 <- wrap(c(
  "Every number on both axes comes from the satellite grid, with no field measurements mixed in.",
  "These are contiguous tracts of country that no management zone was ever drawn over, not management units:",
  "they are cut where the vegetation community changes, so each one is a single community throughout.",
  sprintf("This ground is grazed under set stocking. Of %s hectares carrying a community label, %s hectares sit in %d tracts",
          "12,048", format(round(sum(ud$area_ha)), big.mark = ","), nrow(ud)),
  sprintf("holding at least 500 cells — the same floor the paddock figure uses, so the two can be read side by side. Counting instead by whether a tract could be SEEN for at least 25 years gives %d tracts, and a bare 33-cell threshold gives %d.",
          sel$n_patches[sel$rule == "v2 rule: >=25 yrs of >=30 valid cells"],
          sel$n_patches[grepl("bare", sel$rule)]),
  GAYINI_SEASONAL_BASIS_SENTENCE,
  "The line is a display smoother — no slope is read from it and no significance test is computed.",
  "These tracts have no parent paddock, so nothing here can be said about areas sharing one. They are contiguous",
  "pieces of country and neighbours may share the same conditions, so the shaded band is display only and is, if",
  "anything, too narrow.",
  "r is the correlation across tracts within a vegetation community.",
  "Opacity carries how much cover varies between cells inside a tract. In a solid point the average describes",
  "nearly every cell; in a faint one it describes few of them well. Two tracts of very different size with the",
  "same internal spread are drawn equally solid, so the channel is not a measure of precision.",
  "This describes how places differ from one another over the record, not what more water would do to any one",
  "place."), 245)

pA1 <- ggplot(ud, aes(mean_share_cells_wet, veg_p05_temporal_mean)) +
  geom_smooth(data = ud_fit, aes(group = community_lab, colour = community_lab,
                                 fill = community_lab),
              method = "loess", formula = y ~ x, se = TRUE,
              alpha = 0.15, linewidth = 0.8, show.legend = FALSE) +
  scale_fill_manual(values = PAL_U, guide = "none") +
  geom_point(aes(colour = community_lab, size = n_cells, alpha = veg_p05_within_sd)) +
  scale_colour_manual(values = PAL_U, name = "Vegetation community",
                      guide = guide_legend(order = 1,
                                           override.aes = list(size = 4, alpha = 1))) +
  scale_size_continuous(range = c(1.8, 9), name = "Cells in the tract",
                        labels = function(x) format(x, big.mark = ","),
                        guide = guide_legend(order = 2,
                                             override.aes = list(alpha = 0.85))) +
  scale_alpha_continuous(range = c(1, 0.45), name = ALPHA_TITLE,
                         labels = function(x) sprintf("%.0f", x),
                         guide = guide_legend(order = 3,
                                              override.aes = list(size = 4,
                                                                  colour = INK))) +
  coord_cartesian(xlim = c(0, max(ud$mean_share_cells_wet) * 1.04)) +
  labs(title = "Wetter country holds more cover in its poorest seasons — off the map as well as on it",
       subtitle = sub_a1, x = X_LAB, y = Y_LAB, caption = foot_a1) +
  base_theme()

assert_alpha(pA1, ud, "A1")

capA1 <- paste0(
  "Support: pixel. ", nrow(ud), " unzoned patches, ",
  format(sum(ud$n_cells), big.mark = ","), " non-treed census cells, ",
  format(round(sum(ud$area_ha), 1), big.mark = ","), " ha of unzoned standard-grazing ",
  "country. UNIT: 8-connected component within one vegetation community, outside every ",
  "management zone (Gate 1), at or above the 500-cell PARTSCATTER floor. Y is ",
  "veg_p05_temporal_mean, SEASONAL basis; X is the share of the patch's cells seen wet, ",
  "MEAN OVER YEARS (Rulings AZ / CX), NOT a between-year flood frequency. Opacity is ",
  "veg_p05_within_sd, reversed (low spread more opaque), ramp 1.0-0.45, asserted on the ",
  "built plot under Ruling EJ; it is NOT a standard error and does not shrink with patch ",
  "size. One loess for Inland Floodplain only: Riverine (8) and Aeolian (2) fall below ",
  "the ten-patch rule of section 3.1, and Aeolian also fails Ruling EH's range test ",
  "(1.77 pp). No coefficient is taken from any smoother and no p-value is computed. ",
  "This is unzoned STANDARD-GRAZING country - set stocking, a designed treatment arm - ",
  "and is never described as a reference, a control or unmanaged. Scope: ",
  "treed_context_flag = 0 AND regime_band <> 'context' AND zone_fid IS NULL, 1988-2022.")

rA1 <- gayini_write_and_register_figure(
  plot = pA1,
  path = file.path(root, "Output/figures/unzoned/UNZONED_A1_unzoned_patches_temporal_p05_vs_water.png"),
  title = paste("Mean per-cell temporal 5th-percentile ground cover against wetness,",
                nrow(ud), "unzoned standard-grazing patches"),
  caption = capA1, support_level = "pixel", figure_level = "patch",
  run_id = "UNZONED_V3_20260810", domain = "zone_diagnostics",
  recommended_use = "review",
  provenance_note = paste(
    "UNZONED v3 Arm A, figure A1. Built by",
    "scripts/12_zone_stratum/UNZONED_v3_armA_prepare.py from the census parquet;",
    "no raster opened, no new metric computed. Gate 1 patch labelling rebuilt from",
    "census coordinates and verified against UNZONED_gate1_patch_inventory.csv:",
    "625 patches, every cell count and community exact. Water axis verified against",
    "UNZONED_gate1_patch_series.npy at 0.0000 pp. THE FIVE QUALIFIERS:",
    "support_level = pixel;",
    "scope_filter_sql = treed_context_flag = 0 AND regime_band <> 'context' AND",
    "zone_fid IS NULL AND n_cells >= 500;",
    "pixel_area_ha = 0.062351428 (derived from PIXEL_SIDE_M = 24.970268);",
    sprintf("denominator_ha = %.1f, the plotted patches' own cells;", sum(ud$area_ha)),
    "period_label = 1988-2022 (35 water years).",
    "Water surface: COUNTED-8058 (Ruling DM). Rulings AZ/CX x label, EC y label,",
    "EH and section 3.1 the smoothers, EJ the opacity direction."),
  width = 13.333, height = 7.5, dpi = 150)
cat(sprintf("  [registered] %s  %s\n", basename(rA1$path),
            substr(rA1$checksum_sha256, 1, 12)))

# =====================================================================================
# FIGURE A2 · zoned and unzoned together
# =====================================================================================
SET_Z <- "Paddock areas (zoned)"
SET_U <- "Unzoned standard-grazing tracts"

zc <- zd[, c("community_short", "mean_share_cells_wet", "veg_p05_temporal_mean",
             "n_cells", "veg_p05_within_sd")]
zc$set <- SET_Z
uc <- ud[, c("community_short", "mean_share_cells_wet", "veg_p05_temporal_mean",
             "n_cells", "veg_p05_within_sd")]
uc$set <- SET_U
both <- rbind(zc, uc)
both$set <- factor(both$set, levels = c(SET_Z, SET_U))
lab_c <- function(cs) sprintf("%s", LAY[cs])
both$community_lab <- factor(vapply(both$community_short, lab_c, character(1)),
                             levels = unname(LAY[ORD]))
PAL_B <- stats::setNames(unname(PAL_SHORT[ORD]), unname(LAY[ORD]))

# the smoothers are the ZONED ones, and only where PARTSCATTER draws them
drawn_z <- zsu$community_short[as.logical(zsu$smoother_drawn)]
zfit <- both[both$set == SET_Z & both$community_short %in% drawn_z, ]

sub_a2 <- wrap(c(
  sprintf("%d paddock areas and %d tracts of unzoned standard-grazing country on one pair of axes, each averaged over its own cells.",
          nrow(zd), nrow(ud)),
  "The lines are fitted to the paddock areas alone; the unzoned tracts are drawn over them and enter no line.",
  "Whether the unzoned country falls where the paddock relationship predicts is the question this figure is asked to answer."),
  185)

off_txt <- paste(vapply(seq_len(nrow(off)), function(i) {
  o <- off[i, ]
  if (is.na(o$median_offset_pp))
    sprintf("%s has no comparison: all %d of its tracts sit outside the wetness range the paddock areas cover",
            o$community, o$n_patches)
  else
    sprintf("%s sits %+.1f pp from the paddock line at the median (quartiles %+.1f to %+.1f, %d of %d tracts inside the paddock wetness range)",
            o$community, o$median_offset_pp, o$offset_q1_pp, o$offset_q3_pp,
            o$n_with_offset, o$n_patches)
}, character(1)), collapse = "; ")

foot_a2 <- wrap(c(
  "Every number on both axes comes from the satellite grid, with no field measurements mixed in.",
  "A circle is one paddock cut to a single vegetation community; a triangle is one contiguous tract of unzoned",
  "standard-grazing country, cut the same way. The two are built differently and are not pooled.",
  "THE LINES ARE FITTED TO THE PADDOCK AREAS ONLY. The unzoned tracts enter no line and no fit; they are drawn",
  "over the paddock relationship so it can be seen whether they fall where it predicts.",
  paste0("Where they fall, as a plain distance from the line rather than a test: ", off_txt, "."),
  "A tract wetter or drier than every paddock area of its community gets no comparison at all rather than a",
  "guess: the line is not extended past the country it was fitted on.",
  GAYINI_SEASONAL_BASIS_SENTENCE,
  "The lines are display smoothers — no slope is read from them and no significance test is computed.",
  "Opacity carries how much cover varies between cells inside an area. In a solid point the average describes",
  "nearly every cell; in a faint one it describes few of them well. Size and opacity are on the same scales for",
  "both sets of points.",
  "This ground is grazed under set stocking. Nothing here compares grazing regimes, and no cause is attributed:",
  "it describes how places differ from one another over the record, not what more water would do to any one place."),
  245)

pA2 <- ggplot(both, aes(mean_share_cells_wet, veg_p05_temporal_mean)) +
  geom_smooth(data = zfit, aes(group = community_lab, colour = community_lab,
                               fill = community_lab),
              method = "loess", formula = y ~ x, se = TRUE,
              alpha = 0.13, linewidth = 0.8, show.legend = FALSE) +
  scale_fill_manual(values = PAL_B, guide = "none") +
  geom_point(aes(colour = community_lab, size = n_cells, alpha = veg_p05_within_sd,
                 shape = set)) +
  scale_shape_manual(values = c(16, 17), name = "Unit",
                     guide = guide_legend(order = 1,
                                          override.aes = list(size = 4, alpha = 1,
                                                              colour = INK))) +
  scale_colour_manual(values = PAL_B, name = "Vegetation community",
                      guide = guide_legend(order = 2,
                                           override.aes = list(size = 4, alpha = 1))) +
  scale_size_continuous(range = c(1.8, 9), name = "Cells in the area",
                        labels = function(x) format(x, big.mark = ","),
                        guide = guide_legend(order = 3,
                                             override.aes = list(alpha = 0.85))) +
  scale_alpha_continuous(range = c(1, 0.45), name = ALPHA_TITLE,
                         labels = function(x) sprintf("%.0f", x),
                         guide = guide_legend(order = 4,
                                              override.aes = list(size = 4,
                                                                  colour = INK))) +
  coord_cartesian(xlim = c(0, max(both$mean_share_cells_wet) * 1.04)) +
  labs(title = "Does the paddock relationship hold on country that was never part of it?",
       subtitle = sub_a2, x = X_LAB, y = Y_LAB, caption = foot_a2) +
  base_theme()

assert_alpha(pA2, both, "A2")

capA2 <- paste0(
  "Support: pixel. ", nrow(zd), " zoned paddock x community parts and ", nrow(ud),
  " unzoned standard-grazing patches on one pair of axes, ",
  format(sum(both$n_cells), big.mark = ","), " non-treed census cells. THE TWO UNIT ",
  "CONSTRUCTIONS DIFFER and the sets are NOT pooled: a paddock x community part is a ",
  "management zone cut to one community; an unzoned patch is an 8-connected component ",
  "within one community outside every zone. Smoothers are fitted to the ZONED parts ",
  "only (Inland and Riverine, per Ruling EH); the unzoned points enter no smoother and ",
  "no fit. Y is veg_p05_temporal_mean, SEASONAL basis; X is the share of cells seen wet, ",
  "MEAN OVER YEARS (Rulings AZ / CX). Descriptive offsets against the zoned smoother, ",
  "NOT residuals and NOT a test, are in UNZONED_v3_armA_descriptive_offsets.csv; a patch ",
  "outside its community's zoned water range is excluded rather than extrapolated to. ",
  "Opacity reversed under Ruling EJ, asserted on the built plot; not a standard error. ",
  "Unzoned ground is STANDARD-GRAZING country - set stocking, a designed treatment arm - ",
  "never a reference, a control or unmanaged. No management claim is made. Scope: ",
  "treed_context_flag = 0 AND regime_band <> 'context', 1988-2022.")

rA2 <- gayini_write_and_register_figure(
  plot = pA2,
  path = file.path(root, "Output/figures/unzoned/UNZONED_A2_zoned_and_unzoned_temporal_p05_vs_water.png"),
  title = paste("Mean per-cell temporal 5th-percentile ground cover against wetness,",
                nrow(zd), "paddock areas and", nrow(ud), "unzoned patches"),
  caption = capA2, support_level = "pixel", figure_level = "mixed_unit",
  run_id = "UNZONED_V3_20260810", domain = "zone_diagnostics",
  recommended_use = "review",
  provenance_note = paste(
    "UNZONED v3 Arm A, figure A2. Zoned points from",
    "Output/temporal/PARTSCATTER_scatter_input.csv; unzoned from",
    "Output/unzoned/UNZONED_v3_armA_scatter_input.csv. Smoothers fitted to the ZONED",
    "parts only. The two unit constructions differ and are stated on the face; the sets",
    "are never pooled into one fit. THE FIVE QUALIFIERS:",
    "support_level = pixel;",
    "scope_filter_sql = treed_context_flag = 0 AND regime_band <> 'context', with",
    "zone_fid IS NOT NULL for the circles and zone_fid IS NULL AND n_cells >= 500 for",
    "the triangles;",
    "pixel_area_ha = 0.062351428 (derived from PIXEL_SIDE_M = 24.970268);",
    sprintf("denominator_ha = %.1f zoned plus %.1f unzoned;",
            sum(zd$n_cells) * 24.970268^2 / 1e4, sum(ud$area_ha)),
    "period_label = 1988-2022 (35 water years).",
    "Water surface: COUNTED-8058 (Ruling DM)."),
  width = 13.333, height = 7.5, dpi = 150)
cat(sprintf("  [registered] %s  %s\n", basename(rA2$path),
            substr(rA2$checksum_sha256, 1, 12)))
