# SPAT-1 Stage A figures - the empirical variogram, and the directional one.
#
# Spec: docs/spatial/Gayini_CC_spec_SPAT1.md section 8.
#
# These are METHODS figures. They carry no result about cover or water; they show how far
# residual structure reaches, which is what every interval in the project has been
# asserting without measuring.
#
# EA: no internal identifiers on the face. EC: labels name the quantity, the population and
# the time step. Backgrounds set explicitly - theme_void is not used here, but the
# transparent-PNG defect applies to any ggsave and the four background elements are set
# anyway (I-60).

suppressPackageStartupMessages({library(ggplot2)})

root <- normalizePath(".", winslash = "/")
source(file.path(root, "R/gayini_figure_register.R"))
OUT <- file.path(root, "Output", "spatial")

emp <- utils::read.csv(file.path(OUT, "SPAT1_variogram_empirical.csv"))
mod <- utils::read.csv(file.path(OUT, "SPAT1_variogram_models.csv"))
stab <- utils::read.csv(file.path(OUT, "SPAT1_variogram_seed_stability.csv"))
en <- utils::read.csv(file.path(OUT, "SPAT1_effective_n.csv"))

INK <- "#26302E"; BODY <- "#5F6B67"; MUTED <- "#8A8378"
PAL <- c(aeolian = "#C79A3C", riverine = "#3FAE97", inland = "#2E6DB0")
LAY <- c(aeolian = "Aeolian Chenopod", riverine = "Riverine Chenopod",
         inland = "Inland Floodplain")
MAXLAG <- max(mod$max_lag_m)

base_theme <- function() {
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
          legend.position = "right")
}
wrap <- function(x, w) paste(strwrap(paste(x, collapse = " "), width = w), collapse = "\n")

# ---------------------------------------------------------------- figure 1: isotropic
iso <- emp[emp$direction == "isotropic", ]
iso$community_lab <- factor(LAY[iso$community], levels = unname(LAY))
im <- mod[mod$direction == "isotropic" & mod$model == "spherical", ]
med <- aggregate(cbind(nugget, psill, rng) ~ community, data = im, FUN = stats::median)
curve <- do.call(rbind, lapply(seq_len(nrow(med)), function(i) {
  h <- seq(0, MAXLAG, length.out = 250)
  p <- med[i, ]
  g <- ifelse(h >= p$rng, p$nugget + p$psill,
              p$nugget + p$psill * (1.5 * h / p$rng - 0.5 * (h / p$rng)^3))
  data.frame(community = p$community, lag_m = h, fitted = g)
}))
curve$community_lab <- factor(LAY[curve$community], levels = unname(LAY))
vl <- data.frame(community = med$community, rng = med$rng)
vl$community_lab <- factor(LAY[vl$community], levels = unname(LAY))

sub1 <- wrap(c(
  "Each point is the average squared difference between pairs of cells that far apart, halved - the standard measure of how quickly a pattern loses its resemblance to itself.",
  "The curve is a fitted spherical model; the vertical line is its range, the distance beyond which cells stop resembling one another at all.",
  "Ten independent subsamples of ten thousand cells were drawn per community and the fitted range varied by less than a factor of 1.5 across them."), 155)

foot1 <- wrap(c(
  sprintf("Residuals from a straight-line fit of cover against water at cell level, one fit per vegetation community, across the %s hectares of open country analysed on a %s hectare property.",
          format(round(en$analysed_ha[1]), big.mark = ","),
          format(round(en$property_ha[1]), big.mark = ",")),
  sprintf("Ranges: %s.",
          paste(sprintf("%s %s km", LAY[med$community], format(round(med$rng / 1000, 1), nsmall = 1)),
                collapse = "; ")),
  sprintf("Distances were binned to %s km, and no range is read beyond that: a model fitted past the measured distance is an extrapolation, not a measurement.",
          format(MAXLAG / 1000, big.mark = ",")),
  "The height at which each curve levels off is the total variability; the height it starts at is the part that is not spatial at all - measurement noise and variation between neighbouring cells.",
  "IN TWO OF THE THREE THE CURVE IS A POOR SUMMARY OF THE POINTS. Aeolian Chenopod and Riverine Chenopod both rise to a peak and fall again rather than levelling off, which means the leftovers carry a broad pattern of their own rather than simply fading with distance. Their fitted distances describe a shape the data does not have and should be read as indicative only; Inland Floodplain, which does level off, is the one to rely on.",
  "This figure carries no result about cover or water. It measures how far the leftovers of that relationship travel, which is what every interval in this project has assumed without checking.",
  "Cover and water are measured on a 25 m satellite grid across 1988-2022."), 205)

p1 <- ggplot(iso, aes(lag_m / 1000, semivariance)) +
  geom_point(aes(colour = community_lab), alpha = 0.10, size = 0.7) +
  geom_line(data = curve, aes(lag_m / 1000, fitted, colour = community_lab),
            linewidth = 0.9) +
  geom_vline(data = vl, aes(xintercept = rng / 1000, colour = community_lab),
             linetype = "dashed", linewidth = 0.5, show.legend = FALSE) +
  facet_wrap(~ community_lab, nrow = 1) +
  scale_colour_manual(values = setNames(unname(PAL[names(LAY)]), unname(LAY)),
                      guide = "none") +
  labs(title = "How far the pattern reaches",
       subtitle = sub1,
       x = "Distance between two places (km)",
       # shortened: the full statement ran into the subtitle. EC allows the axis to carry
       # the quantity while the subtitle carries the construction, which it does.
       y = "How different two places are (percentage points squared)",
       caption = foot1) +
  base_theme()

cap1 <- paste0(
  "Support: pixel. Empirical semivariogram of Stage 0 OLS residuals on ",
  "veg_p05_temporal_mean, per vegetation community, 988,829 non-treed census cells. ",
  "gamma(h) = 0.5 x mean (z_i - z_j)^2 over pairs in each lag bin; 10 subsamples of ",
  "10,000 cells per community, binned to ", format(MAXLAG / 1000), " km in 80 bins. ",
  "Spherical model fitted by least squares; the plotted curve uses the median of the ten ",
  "seeds. Fitted ranges: ",
  paste(sprintf("%s %.0f m", med$community, med$rng), collapse = "; "),
  ". Ten-seed stability: max/min ratio 1.09-1.47, all within the factor-of-two rule. ",
  "RULING EN: no range is used beyond the ", format(MAXLAG / 1000), " km maximum lag. ",
  "This is a methods figure and carries no result about cover or water. Scope: ",
  "treed_context_flag = 0 AND regime_band <> 'context', 1988-2022.")

r1 <- gayini_write_and_register_figure(
  plot = p1, path = file.path(OUT, "SPAT1_F1_variogram_by_community.png"),
  title = "Empirical semivariogram of cover-water residuals by vegetation community, with fitted spherical models",
  caption = cap1, support_level = "pixel", figure_level = "pixel",
  run_id = "SPAT1_20260810", domain = "zone_diagnostics", recommended_use = "review",
  provenance_note = paste(
    "SPAT-1 Stage A figure 1. Built from Output/spatial/SPAT1_variogram_empirical.csv and",
    "_models.csv. THE FIVE QUALIFIERS: support_level = pixel;",
    "scope_filter_sql = treed_context_flag = 0 AND regime_band <> 'context';",
    "pixel_area_ha = 0.062351428; denominator_ha = 61654.9 analysed of 85910.8 property",
    "(Ruling EQ); period_label = 1988-2022 (35 water years)."),
  width = 13.5, height = 7.2, dpi = 150)
cat(sprintf("  [registered] %s  %s\n", basename(r1$path), substr(r1$checksum_sha256, 1, 12)))

# ---------------------------------------------------------------- figure 2: directional
dr <- mod[mod$direction != "isotropic" & mod$model == "spherical", ]
dr$deg <- as.numeric(sub("deg", "", dr$direction))
dr$community_lab <- factor(LAY[dr$community], levels = unname(LAY))
dr$resolved <- as.logical(dr$range_resolved_within_max_lag)
dr$plot_rng <- ifelse(dr$resolved, dr$rng, MAXLAG)

sub2 <- wrap(c(
  "The same measurement taken separately along four compass directions. If the pattern reached equally far in every direction the four bars would match.",
  "They do not. This is a floodplain and water moves along paths, so the country is stretched along some directions and compressed across others.",
  "An open bar means the pattern had still not faded within the twenty kilometres measured, so no distance can be quoted for that direction."), 155)

foot2 <- wrap(c(
  "Zero degrees is east-west, ninety is north-south. Each bar is the distance beyond which leftover cover stops resembling itself along that direction.",
  "Aeolian Chenopod country is the most directional of the three, reaching several times further east-west than across it.",
  "In Inland Floodplain country the north-east direction did not fade within twenty kilometres at all: that bar is drawn open at the limit of measurement and no number is quoted for it, because a model fitted past the distance measured is an extrapolation rather than a result.",
  "An average taken across directions would hide this. It would understate how far the pattern reaches along the water and overstate it across, so the four are kept apart.",
  "No cause is attributed. A range is a distance over which leftovers resemble one another. It is not soil, not position and not management.",
  "Cover and water are measured on a 25 m satellite grid across 1988-2022."), 205)

p2 <- ggplot(dr, aes(factor(deg), plot_rng / 1000, fill = community_lab)) +
  geom_col(aes(alpha = resolved), width = 0.72, colour = "#6E756F", linewidth = 0.25) +
  facet_wrap(~ community_lab, nrow = 1) +
  scale_fill_manual(values = setNames(unname(PAL[names(LAY)]), unname(LAY)),
                    guide = "none") +
  scale_alpha_manual(values = c("TRUE" = 1, "FALSE" = 0.22), guide = "none") +
  geom_hline(yintercept = MAXLAG / 1000, linetype = "dotted", colour = INK,
             linewidth = 0.4) +
  labs(title = "The pattern is not the same length in every direction",
       subtitle = sub2,
       x = "Direction measured along (degrees, 0 = east-west)",
       y = "Distance beyond which leftover cover stops resembling itself (km)",
       caption = foot2) +
  base_theme()

cap2 <- paste0(
  "Support: pixel. Directional semivariograms of Stage 0 OLS residuals at 0, 45, 90 and ",
  "135 degrees, tolerance +/-22.5 degrees, one 10,000-cell subsample per direction per ",
  "community, binned to ", format(MAXLAG / 1000), " km. Spherical ranges, in metres: ",
  paste(sprintf("%s %s %s", dr$community, dr$direction,
                ifelse(dr$resolved, sprintf("%.0f", dr$rng), "UNRESOLVED")),
        collapse = "; "),
  ". RULING EN ENFORCED IN THE TABLE AND ON THE FACE: a fit running past the maximum lag ",
  "is not a measured range, is flagged in SPAT1_variogram_models.csv, is drawn open at ",
  "the measurement limit, and its number is not quoted. Anisotropy max/min by community: ",
  paste(sprintf("%s %.2f", unique(dr$community),
                tapply(dr$rng, dr$community, function(v) max(v) / min(v))[unique(dr$community)]),
        collapse = "; "),
  ". Not averaged away (spec 4.3). This is a methods figure and carries no result about ",
  "cover or water. Scope: treed_context_flag = 0 AND regime_band <> 'context', 1988-2022.")

r2 <- gayini_write_and_register_figure(
  plot = p2, path = file.path(OUT, "SPAT1_F2_directional_variogram.png"),
  title = "Directional semivariogram ranges of cover-water residuals, four directions by vegetation community",
  caption = cap2, support_level = "pixel", figure_level = "pixel",
  run_id = "SPAT1_20260810", domain = "zone_diagnostics", recommended_use = "review",
  provenance_note = paste(
    "SPAT-1 Stage A figure 2, section 4.3. Built from",
    "Output/spatial/SPAT1_variogram_models.csv (direction != isotropic). Unresolved",
    "directions are drawn at the measurement limit with no number quoted (Ruling EN).",
    "THE FIVE QUALIFIERS: support_level = pixel;",
    "scope_filter_sql = treed_context_flag = 0 AND regime_band <> 'context';",
    "pixel_area_ha = 0.062351428; denominator_ha = 61654.9 analysed of 85910.8 property;",
    "period_label = 1988-2022 (35 water years)."),
  width = 13.5, height = 7.2, dpi = 150)
cat(sprintf("  [registered] %s  %s\n", basename(r2$path), substr(r2$checksum_sha256, 1, 12)))
