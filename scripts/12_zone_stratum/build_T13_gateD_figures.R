# T13 Gate D (step 2) — the map, the scatter companion, and the sensitivity small multiples.
#
# Rulings applied: five fill classes (Ruling 4's low-and-falling split rendered distinctly);
# hatching for the marginal set; heavier outline on the 3-part core; NO state asserted for
# Bala 29ca Inland; threshold lines + shaded marginal band on the scatter; the community-SD
# scale line ON THE MAP, not only in methods.
#
# MARGINAL BAND (see the Gate D report §2 for the flagged discrepancy): a part is hatched if it
# is within BAND of an ACTUAL cut, OR it changes state under the robustness run. The active cuts
# are level_z = -1.0, trend_z = -1.0, trend_z = +1.0. There is NO level_z = +1.0 cut in the §5
# rule, so distance to it is not a distance to anything.
#
# ggpattern and ggspatial are not installed; hatching, north arrow and scale bar are drawn
# from geometry rather than adding a dependency 11 days from the deadline.
suppressPackageStartupMessages({library(sf); library(ggplot2); library(dplyr); library(patchwork); library(DBI); library(RSQLite)})
source("R/gayini_params.R")
source("R/gayini_figure_register.R")
source("R/gayini_assert_rendered.R")

RUN   <- "T13_gateD_20260730"
BAND  <- 0.15                      # ruling: band width fixed at 0.15
CUT   <- 1.00
FIGD  <- "Output/figures"   # one canonical location for client-deliverable items
PARTS <- "Output/spatial_8058/T13_part_polygons_render_only_epsg8058.gpkg"
NOT_ASSERTED <- list(zone = "Bala 29ca", comm_prefix = "Inland")

# ---- deck palette --------------------------------------------------------------------------
# No committed STATE palette exists (the audited deck palette is per-COMMUNITY:
# docs/change_reports/tier2H_gateE_palette_audit.md). These hues are taken from the committed
# semantic set in R/gayini_dashboard_panels.R / gayini_dashboard_figures.R so the map reads with
# the rest of the deck: veg-green = gaining, neutral grey = unremarkable, the committed "drier"
# red = declining, bare-brown = low. Deliberately NOT viridis (spec §6). Flagged for ratification.
PAL <- c(
  "Recovering"                  = "#2E7D32",  # committed total_veg green
  "Unremarkable"                = "#9E9E9E",  # committed neutral grey
  "Declining"                   = "#B2182B",  # committed "drier" red
  "Persistently poor - flat"    = "#8D6E63",  # committed bare brown
  "Persistently poor - falling" = "#4A2C22",  # DERIVED darker bare - the only non-committed hue
  "State not asserted"          = "#FFFFFF",
  # out-of-scope ground: treed country, the context band, unzoned gaps. NOT white - white is
  # reserved for the single deliberate abstention, and the two must not read as one thing.
  "Not assessed (treed / outside census)" = "#E5E0D6"
)
NOT_ASSESSED <- "Not assessed (treed / outside census)"
LAB_ORDER <- names(PAL)

# ---- data ------------------------------------------------------------------------------------
cls <- read.csv("Output/tables/T13_gateC_classification.csv", stringsAsFactors = FALSE,
                check.names = FALSE)
rob <- read.csv("Output/tables/T13_gateC_robustness.csv", stringsAsFactors = FALSE)
# RENDER-ONLY geometry (build_T13_gateD_render_geom.R). The exact analysis polygons are
# pixel staircases: at any visible outline width they fill solid, and they are far too slow to
# intersect for hatching. Nothing is MEASURED off this copy - every number comes from the CSVs.
parts <- sf::st_read(PARTS, quiet = TRUE)
stopifnot(sf::st_crs(parts)$epsg == GAYINI_PARAMS$CRS_CANONICAL)

zones <- sf::st_read("Output/spatial_8058/management_zones_epsg8058.gpkg", quiet = TRUE)
zones <- sf::st_transform(zones, GAYINI_PARAMS$CRS_CANONICAL)
REF_ZONES <- c("Bala 26ca", "Bala 27ca", "Bala 28ca", "Bala 29ca")

# distance to the nearest ACTIVE cut (no phantom level_z = +1.0 boundary)
dist_to_cut <- function(lz, tz) pmin(abs(lz + CUT), abs(tz + CUT), abs(tz - CUT))

cls$dist_cut <- dist_to_cut(cls$level_z, cls$trend_z)
movers <- rob %>% filter(changed == 1) %>% transmute(zone_fid, community, is_mover = TRUE)
cls <- cls %>% left_join(movers, by = c("zone_fid", "community")) %>%
  mutate(is_mover = !is.na(is_mover),
         marginal = dist_cut <= BAND | is_mover)

# five fill classes: the pre-registered four, with Persistently poor split per Ruling 4
cls$fill_class <- dplyr::case_when(
  cls$state_registered == "Persistently poor" & cls$pp_split == "low and falling" ~ "Persistently poor - falling",
  cls$state_registered == "Persistently poor"                                    ~ "Persistently poor - flat",
  TRUE                                                                           ~ cls$state_registered)

# State is not asserted where a part is BOTH inside the marginal band AND changes state under
# the robustness run. A CRITERION read from the DB (assert_state), not a named part - naming one
# part was the ad-hoc-threshold problem this task exists to avoid, appearing in a ruling rather
# than in a cut. Nothing is reclassified: state_registered and the registered counts are
# untouched; this governs only what the MAP asserts.
asrt <- DBI::dbGetQuery(DBI::dbConnect(RSQLite::SQLite(),
          "Output/database/Gayini_Results.sqlite"),
          "SELECT zone_fid, community, assert_state FROM fact_zone_community_part_classification")
cls <- cls %>% left_join(asrt, by = c("zone_fid", "community"))
stopifnot(!any(is.na(cls$assert_state)))
na_idx <- cls$assert_state == 0
cat(sprintf("state NOT asserted (in band AND a robustness mover): %d of %d\n",
            sum(na_idx), nrow(cls)))
stopifnot(sum(na_idx) == 9)
cls$fill_class[na_idx] <- "State not asserted"

# the 3-part core: recovering at EVERY swept cut
cutcols <- grep("^state_cut_", names(cls), value = TRUE)
cls$core <- apply(cls[, cutcols], 1, function(v) all(v == "Recovering"))
cat(sprintf("core (recovering at every cut): %d\n", sum(cls$core)))
cat(sprintf("marginal (within %.2f of a real cut OR a robustness mover): %d of %d\n",
            BAND, sum(cls$marginal), nrow(cls)))

pg <- parts %>% inner_join(cls, by = c("zone_fid", "community"))
stopifnot(nrow(pg) == 115)   # 118 polygons, 115 supported parts
pg$fill_class <- factor(pg$fill_class, levels = LAB_ORDER)

# ---- hatching, built from geometry (no ggpattern) --------------------------------------------
hatch_lines <- function(poly_sf, spacing = 420, angle = 45) {
  if (nrow(poly_sf) == 0) return(NULL)
  bb <- sf::st_bbox(poly_sf)
  d  <- max(bb["xmax"] - bb["xmin"], bb["ymax"] - bb["ymin"]) * 1.5
  cx <- mean(c(bb["xmax"], bb["xmin"])); cy <- mean(c(bb["ymax"], bb["ymin"]))
  offs <- seq(-d, d, by = spacing)
  ls <- lapply(offs, function(o) sf::st_linestring(matrix(c(-d, o, d, o), ncol = 2, byrow = TRUE)))
  g  <- sf::st_sfc(ls, crs = sf::st_crs(poly_sf))
  th <- angle * pi / 180
  rot <- matrix(c(cos(th), sin(th), -sin(th), cos(th)), 2, 2)
  g <- (g * rot) + c(cx, cy)
  sf::st_crs(g) <- sf::st_crs(poly_sf)
  suppressWarnings(sf::st_intersection(sf::st_make_valid(g), sf::st_union(poly_sf)))
}
hatch <- hatch_lines(pg[pg$marginal, ])

# ---- north arrow + scale bar, drawn (no ggspatial) -------------------------------------------
bb <- sf::st_bbox(pg)
xr <- as.numeric(bb["xmax"] - bb["xmin"]); yr <- as.numeric(bb["ymax"] - bb["ymin"])
sb_len <- 5000                                            # 5 km, CRS is metres
# Placed bottom-RIGHT: the property runs SW-NE, so the bottom-left corner of the bbox is
# occupied by the Mara/Bala 29ca cluster. The first draft put the bar there and it sat on top
# of the data - insets never overlap the map (standing convention).
sb_x0 <- as.numeric(bb["xmin"]) + 0.63 * xr
sb_y0 <- as.numeric(bb["ymin"]) + 0.045 * yr
na_x  <- as.numeric(bb["xmax"]) - 0.045 * xr
na_y0 <- as.numeric(bb["ymin"]) + 0.045 * yr

deco <- function(g) {
  g +
    annotate("rect", xmin = sb_x0, xmax = sb_x0 + sb_len/2, ymin = sb_y0,
             ymax = sb_y0 + 0.012*yr, fill = "grey15", colour = "grey15") +
    annotate("rect", xmin = sb_x0 + sb_len/2, xmax = sb_x0 + sb_len, ymin = sb_y0,
             ymax = sb_y0 + 0.012*yr, fill = "white", colour = "grey15") +
    annotate("text", x = sb_x0, y = sb_y0 + 0.030*yr, label = "0", size = 2.6, hjust = 0.5) +
    annotate("text", x = sb_x0 + sb_len, y = sb_y0 + 0.030*yr, label = "5 km",
             size = 2.6, hjust = 0.5) +
    annotate("segment", x = na_x, xend = na_x, y = na_y0, yend = na_y0 + 0.075*yr,
             arrow = arrow(length = unit(0.16, "cm"), type = "closed"),
             colour = "grey15", linewidth = 0.5) +
    annotate("text", x = na_x, y = na_y0 + 0.095*yr, label = "N", size = 3, fontface = "bold")
}

base_map <- function(dat, fillvar, title, hatch_layer = NULL, show_core = TRUE) {
  # WHITE MEANT TWO THINGS in the first draft: the single deliberate abstention
  # (Bala 29ca Inland) and every out-of-scope hole - treed country, the context band, the
  # unzoned gaps, which are most of the white on the map. One appearance, two meanings; the
  # same class of error as the two floors. Out-of-scope now carries its own neutral fill and
  # its own legend entry, and is drawn via aes() so it enters the manual scale.
  g <- ggplot() +
    geom_sf(data = zones, aes(fill = NOT_ASSESSED), colour = "grey72", linewidth = 0.15) +
    geom_sf(data = dat, aes(fill = .data[[fillvar]]), colour = "grey40", linewidth = 0.08)
  if (!is.null(hatch_layer) && length(hatch_layer) > 0)
    g <- g + geom_sf(data = hatch_layer, colour = "grey15", linewidth = 0.16, alpha = 0.9)
  g <- g +
    geom_sf(data = zones[zones$ManagmentZ %in% REF_ZONES, ], fill = NA,
            colour = "#1A1A1A", linewidth = 0.45, linetype = "22")
  if (any(dat[[fillvar]] == "State not asserted", na.rm = TRUE))
    g <- g + geom_sf(data = dat[dat[[fillvar]] == "State not asserted", ], fill = NA,
                     colour = "#6A6A6A", linewidth = 0.45)
  if (show_core && any(dat$core))
    g <- g + geom_sf(data = dat[dat$core, ], fill = NA, colour = "black", linewidth = 0.5)
  g +
    scale_fill_manual(values = PAL, drop = FALSE, name = NULL) +
    labs(title = title) +
    theme_void(base_size = 10) +
    theme(legend.position = "right", plot.title = element_text(face = "bold", size = 11))
}

# ---------------------------------------------------------------- FIGURE 1: map + scatter
lab_z <- zones %>% mutate(ctr = sf::st_centroid(sf::st_geometry(.)))
lab_xy <- sf::st_coordinates(lab_z$ctr)
lab_df <- data.frame(x = lab_xy[,1], y = lab_xy[,2], nm = zones$ManagmentZ)

m1 <- deco(base_map(pg, "fill_class", "Paddock parts by state, pre-registered cut ±1.0  -  8 parts meet the recovering criterion, 5 asserted", hatch)) +
  geom_text(data = lab_df, aes(x, y, label = nm), size = 1.45, colour = "grey20")

marg_rect <- function() {
  list(
    annotate("rect", xmin = -Inf, xmax = Inf, ymin = -CUT-BAND, ymax = -CUT+BAND,
             fill = "grey55", alpha = 0.20),
    annotate("rect", xmin = -Inf, xmax = Inf, ymin = CUT-BAND, ymax = CUT+BAND,
             fill = "grey55", alpha = 0.20),
    annotate("rect", xmin = -CUT-BAND, xmax = -CUT+BAND, ymin = -Inf, ymax = Inf,
             fill = "grey55", alpha = 0.20))
}
s1 <- ggplot(pg, aes(level_z, trend_z)) +
  marg_rect() +
  geom_vline(xintercept = -CUT, linetype = "22", colour = "grey20") +
  geom_hline(yintercept = c(-CUT, CUT), linetype = "22", colour = "grey20") +
  geom_point(aes(fill = fill_class), shape = 21, size = 2.6, colour = "grey25", stroke = 0.3) +
  geom_point(data = pg[pg$core, ], shape = 21, size = 4.2, fill = NA, colour = "black", stroke = 0.9) +
  scale_fill_manual(values = PAL, drop = FALSE, guide = "none") +
  labs(x = "level_z  (community-scaled cover level)",
       y = "trend_z  (community-scaled water-adjusted trend)",
       title = "The continuous measures underneath",
       subtitle = "Shaded = the ±0.15 marginal band. Lines = the pre-registered cut.") +
  theme_minimal(base_size = 10) +
  theme(plot.title = element_text(face = "bold", size = 11),
        plot.subtitle = element_text(size = 8, colour = "grey30"))

cap1 <- paste0(
  "Support level: pixel (paddock part = management zone x vegetation community, dissolved from ",
  "24.970268 m census pixels; 115 parts). States are a LABELLING of two continuous measures, not ",
  "categories in the data. Pre-registered cut ±1.0 on both z-scores, fixed before any result ",
  "was seen; across the 0.50-1.50 sweep the recovering set runs 3 to 15 parts and is strictly ",
  "nested - the cut changes how many, not which. Z-scores are scaled to each community's own ",
  "spread, so a z of -1.0 is about 12 pp of ground in Aeolian or Riverine but only about 6 pp in ",
  "Inland. Hatching marks a part that is EITHER within 0.15 of a cut OR changes state when the ",
  "two wettest years are dropped - not all hatched parts are near a boundary. Heavy outline = ",
  "recovering at every swept cut. Dashed paddock outline = the four reference paddocks. ",
  "State is not asserted for the 9 parts that are BOTH within 0.15 of a cut AND change state ",
  "under the robustness run - a criterion, not a chosen part; nothing is reclassified and the ",
  "registered counts are unchanged. Those parts are drawn white. ",
  "changes state under the robustness run. Eight parts meet the recovering criterion. Five of ",
  "those survive dropping the two wettest years; three do not and are shown as unclassified. The ",
  "three that recover at every swept cut are among the five. White is a deliberate abstention and ",
  "is NOT the same as the pale out-of-scope fill, which marks treed country and ground outside ",
  "the mapped census. Geography, stated not explained: declining parts are overwhelmingly eastern (12 of 16 ",
  "in the Bala group), while both recovering and persistently-poor parts are south-western and the ",
  "centre is almost entirely unremarkable; why is not known and nothing here attributes a cause. ",
  "Cover is how much and how green, not a condition score.")

# POST-RENDER assertion (I-32) on the community-SD numbers QUOTED IN THE CAPTION. The caption
# tells the reader a z of -1.0 is "about 12 pp" in Aeolian/Riverine and "about 6 pp" in Inland;
# those are roundings of live SDs and must be checked against them, not trusted as prose.
gb <- read.csv("Output/tables/T13_gateB_part_measures.csv", stringsAsFactors = FALSE)
sd_by <- sapply(split(gb$level_dev, gb$community), sd)
sd_hi <- max(sd_by[grep("^(Aeolian|Riverine)", names(sd_by))])
sd_lo <- sd_by[grep("^Inland", names(sd_by))]
cat(sprintf("caption-number check: SD(level_dev) high %.2f -> '%d pp', Inland %.2f -> '%d pp'
",
            sd_hi, round(sd_hi), sd_lo, round(sd_lo)))
gayini_assert_caption_number(cap1, round(sd_hi), 0, "T13 D1 caption: Aeolian/Riverine pp")
gayini_assert_caption_number(cap1, round(sd_lo), 0, "T13 D1 caption: Inland pp")

fig1 <- m1 + s1 + patchwork::plot_layout(widths = c(1.7, 1))
gayini_write_and_register_figure(
  plot = fig1, path = file.path(FIGD, "T13_D1_part_state_map_and_scatter.png"),
  title = "T13 Gate D - paddock parts by state, pre-registered cut +/-1.0, with the continuous measures",
  caption = cap1, support_level = "pixel", figure_level = "diagnostic", run_id = RUN,
  domain = "zone_diagnostics", framing_label = "census_8058",
  provenance_note = "Output/tables/T13_gateC_classification.csv; polygons dissolved from T2_in_scope_points.csv",
  width = 17, height = 8.5, dpi = 200)

# ---------------------------------------------------------------- FIGURE 2: sensitivity small multiples
na_idx_pg <- pg$assert_state == 0
# All three panels the SAME SIZE and in one row - an unequal grid makes the eye read the
# largest panel as the important one, which defeats a sensitivity comparison.
panel <- function(cc) {
  col <- sprintf("state_cut_%.2f", cc)
  d <- pg
  d$fc <- dplyr::case_when(
    d[[col]] == "Persistently poor" & d$trend_z <= -cc ~ "Persistently poor - falling",
    d[[col]] == "Persistently poor"                    ~ "Persistently poor - flat",
    TRUE                                               ~ d[[col]])
  d$fc[na_idx_pg] <- "State not asserted"   # same assert_state criterion, from the DB
  d$fc <- factor(d$fc, levels = LAB_ORDER)
  nrec <- sum(d[[col]] == "Recovering"); nass <- sum(d[[col]] == "Recovering" & d$assert_state == 1)
  ttl <- sprintf("Cut ±%.2f  -  %d meet criterion, %d asserted", cc, nrec, nass)
  if (abs(cc - CUT) < 1e-9) ttl <- sprintf("REGISTERED cut ±%.2f  -  %d meet criterion, %d asserted", cc, nrec, nass)
  base_map(d, "fc", ttl, NULL, show_core = FALSE)
}
fig2 <- (panel(0.75) | panel(CUT) | panel(1.25)) +
  patchwork::plot_layout(guides = "collect") &
  theme(legend.position = "bottom", legend.text = element_text(size = 8))

cap2 <- paste0(
  "Support level: pixel (paddock part, 115 parts). Sensitivity of the state map to the cut: ",
  "±0.75 and ±1.25 against the registered ±1.0. The recovering set is strictly ",
  "nested across the full 0.50-1.50 sweep - parts enter and leave as the cut moves but are never ",
  "swapped, so the cut governs how many parts are called recovering, not which. Same palette and ",
  "same five classes as the registered map; core outline and hatching omitted so the cut effect ",
  "is the only thing varying. The pale fill is ground not assessed (treed or outside the mapped ",
  "census); white is the single deliberate abstention at Bala 29ca Inland. Z-scores are community-scaled: a z of -1.0 is about 12 pp of ground ",
  "in Aeolian or Riverine and about 6 pp in Inland.")

gayini_write_and_register_figure(
  plot = fig2, path = file.path(FIGD, "T13_D2_part_state_map_sensitivity.png"),
  title = "T13 Gate D - state map at the 0.75 and 1.25 cuts (sensitivity small multiples)",
  caption = cap2, support_level = "pixel", figure_level = "diagnostic", run_id = RUN,
  domain = "zone_diagnostics", framing_label = "census_8058",
  provenance_note = "Output/tables/T13_gateC_classification.csv sweep columns",
  width = 18, height = 7.5, dpi = 200)

cat("\nGate D figures written and registered.\n")
