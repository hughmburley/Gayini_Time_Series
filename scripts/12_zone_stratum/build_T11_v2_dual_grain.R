# T11 v2 — Gate A (dual-grain 2x2) and Gate B (paddock-grain residual panel).
#
# ASSEMBLY ONLY. Paddock values from fact_zone_veg_annual; part values from
# fact_zone_community_veg_annual joined to fact_zone_community_flood_annual (T13 Gate A).
# The Gate B expectation line is READ from dim_headline_number - never refitted here.
#
# FOOTPRINT NOTE. The paddock column is drawn on the paddock footprint DISSOLVED FROM THE PART
# POLYGONS, not on the raw management-zone polygons. The zone polygon covers treed ground and
# context band that the paddock mean is NOT computed on; colouring it whole would state a
# non-treed value over ground excluded from it. Dissolving the parts gives both columns the
# SAME footprint, so the columns differ only in partition - which is the entire comparison.
suppressPackageStartupMessages({library(sf); library(ggplot2); library(dplyr); library(DBI)
                                library(RSQLite); library(patchwork)})
source("R/gayini_params.R")
source("R/gayini_figure_register.R")
source("R/gayini_assert_rendered.R")

RUN  <- "T11_v2_20260731"
FIGD <- "Output/figures"
DBP  <- "Output/database/Gayini_Results.sqlite"
con  <- DBI::dbConnect(RSQLite::SQLite(), DBP); on.exit(DBI::dbDisconnect(con), add = TRUE)
REF  <- c("Bala 26ca", "Bala 27ca", "Bala 28ca", "Bala 29ca")

# ---- derived sequential ramps (recorded, as the T13 state palette was) -----------------------
# No sequential deck ramp is committed. These are built from the committed semantic hues:
#   floor -> the committed total_veg green #2E7D32 ; flood -> the committed flood blue #2171B5.
# Blue for water is consistent with every other map in this project (which is exactly why blue
# was REFUSED for "recovering" at T13 Gate D - same reasoning, opposite conclusion).
# Hue separation is deliberate and load-bearing: the argument is that the two ROWS look alike,
# so a reader must never need the legend to know which row they are in.
RAMP_FLOOR <- c("#F2F7F0", "#C9E0C0", "#8CC183", "#4E9C55", "#2E7D32", "#14401A")
RAMP_FLOOD <- c("#EFF4FA", "#C3D9EE", "#7FB0DA", "#3E86C4", "#2171B5", "#08306B")
NOT_ASSESSED <- "Not assessed (treed / outside census)"
BELOW_SUPPORT <- "Part below support rule (3 of 118)"
COL_NA <- "#E5E0D6"; COL_SUB <- "#BFB6A6"

## ---------------------------------------------------------------- data
pad <- DBI::dbGetQuery(con, "
  SELECT zone_fid, AVG(veg_p05_spatial) AS floor, AVG(flood_frac_pct) AS flood
  FROM fact_zone_veg_annual WHERE series_variant='mean_of_seasons' GROUP BY zone_fid")
stopifnot(nrow(pad) == 64)

pv <- DBI::dbGetQuery(con, "
  SELECT zone_fid, community, COUNT(*) n, AVG(veg_p05_spatial) AS floor
  FROM fact_zone_community_veg_annual
  WHERE series_variant='mean_of_seasons' AND n_pixels_valid>=30 AND veg_p05_spatial IS NOT NULL
  GROUP BY zone_fid, community")
pf <- DBI::dbGetQuery(con, "
  SELECT zone_fid, community, AVG(flood_frac_pct) AS flood
  FROM fact_zone_community_flood_annual WHERE flood_frac_pct IS NOT NULL
  GROUP BY zone_fid, community")
part <- pv %>% filter(n >= 25) %>% left_join(pf, by = c("zone_fid", "community"))
cat(sprintf("parts meeting the support rule: %d of %d in the flood table\n",
            nrow(part), nrow(pf)))
stopifnot(nrow(part) == 115)

name <- DBI::dbGetQuery(con, "SELECT zone_fid, zone_name FROM dim_management_zone")

## ---------------------------------------------------------------- geometry
pg <- sf::st_read("Output/spatial_8058/T13_part_polygons_render_only_epsg8058.gpkg", quiet = TRUE)
stopifnot(sf::st_crs(pg)$epsg == GAYINI_PARAMS$CRS_CANONICAL, nrow(pg) == 118)
pg <- pg %>% left_join(name, by = "zone_fid")

# paddock footprint = the parts of that paddock, dissolved. Same country as the right column.
foot <- pg %>% group_by(zone_fid) %>% summarise(.groups = "drop") %>%
  left_join(name, by = "zone_fid") %>% left_join(pad, by = "zone_fid")
stopifnot(nrow(foot) == 64)

pgv <- pg %>% left_join(part, by = c("zone_fid", "community"))
sub <- pgv %>% filter(is.na(floor))          # the 3 sub-support fragments
cat(sprintf("sub-support fragments drawn in their own fill: %d\n", nrow(sub)))
stopifnot(nrow(sub) == 3)
pgv_ok <- pgv %>% filter(!is.na(floor))

# The not-assessed base must be the FULL management zones, not the footprint: `foot` is the union
# of the parts, so nothing pale could ever show under it and the subtitle promised a fill the
# figure did not contain. Drawing the zones underneath makes the excluded ground visible - which
# is also what lets a reader see that the paddock column is NOT drawn over its treed ground.
zones <- sf::st_read("Output/spatial_8058/management_zones_epsg8058.gpkg", quiet = TRUE)
zones <- sf::st_transform(zones, GAYINI_PARAMS$CRS_CANONICAL)
refpoly <- foot %>% filter(zone_name %in% REF)

## ---------------------------------------------------------------- shared scales per ROW
lim_floor <- range(c(foot$floor, pgv_ok$floor)); lim_flood <- range(c(foot$flood, pgv_ok$flood))
brk <- function(l) pretty(l, 5)
cat(sprintf("floor scale limits %.1f - %.1f  breaks %s\n", lim_floor[1], lim_floor[2],
            paste(brk(lim_floor), collapse = ", ")))
cat(sprintf("flood scale limits %.1f - %.1f  breaks %s\n", lim_flood[1], lim_flood[2],
            paste(brk(lim_flood), collapse = ", ")))

## ---------------------------------------------------------------- decorations
bb <- sf::st_bbox(pg); xr <- as.numeric(bb["xmax"] - bb["xmin"]); yr <- as.numeric(bb["ymax"] - bb["ymin"])
sb <- 5000
sx <- as.numeric(bb["xmin"]) + 0.63 * xr; sy <- as.numeric(bb["ymin"]) + 0.05 * yr
nx <- as.numeric(bb["xmax"]) - 0.05 * xr
deco <- function(g) g +
  annotate("rect", xmin = sx, xmax = sx + sb/2, ymin = sy, ymax = sy + 0.014*yr,
           fill = "grey15", colour = "grey15") +
  annotate("rect", xmin = sx + sb/2, xmax = sx + sb, ymin = sy, ymax = sy + 0.014*yr,
           fill = "white", colour = "grey15") +
  annotate("text", x = sx + sb/2, y = sy + 0.045*yr, label = "5 km", size = 2.4) +
  annotate("segment", x = nx, xend = nx, y = sy, yend = sy + 0.085*yr,
           arrow = arrow(length = unit(0.14, "cm"), type = "closed"),
           colour = "grey15", linewidth = 0.45) +
  annotate("text", x = nx, y = sy + 0.115*yr, label = "N", size = 2.7, fontface = "bold")

panel <- function(dat, var, ramp, lims, title, showleg, legname, subpoly = NULL, labels = NULL) {
  g <- ggplot() +
    geom_sf(data = zones, fill = COL_NA, colour = "grey78", linewidth = 0.12)
  if (!is.null(subpoly) && nrow(subpoly) > 0)
    g <- g + geom_sf(data = subpoly, fill = COL_SUB, colour = "grey55", linewidth = 0.1)
  g <- g +
    geom_sf(data = dat, aes(fill = .data[[var]]), colour = "grey45", linewidth = 0.07) +
    geom_sf(data = refpoly, fill = NA, colour = "#1A1A1A", linewidth = 0.5, linetype = "22") +
    scale_fill_gradientn(colours = ramp, limits = lims, breaks = brk(lims), name = legname,
                         guide = guide_colourbar(barheight = unit(2.4, "cm"), barwidth = unit(0.35, "cm")))
  if (!is.null(labels))
    g <- g + geom_text(data = labels, aes(x, y, label = lab), size = 2.5,
                       fontface = "bold", colour = "grey10")
  g + labs(title = title) + theme_void(base_size = 9) +
    theme(legend.position = if (showleg) "right" else "none",
          plot.title = element_text(face = "bold", size = 10))
}

# labels for the part-grain floor panel
lc <- pgv_ok %>% filter(zone_name %in% c("Bala 29ca", "Dinan 1")) %>%
  group_by(zone_name) %>% summarise(.groups = "drop")
lxy <- sf::st_coordinates(sf::st_centroid(sf::st_geometry(lc)))
labdf <- data.frame(x = lxy[,1], y = lxy[,2] - 0.075 * yr, lab = lc$zone_name)

p11 <- deco(panel(foot,    "floor", RAMP_FLOOR, lim_floor, "Cover floor — paddock grain (64)",  FALSE, NULL))
p12 <- deco(panel(pgv_ok,  "floor", RAMP_FLOOR, lim_floor, "Cover floor — part grain (115)",    TRUE,
                  "veg_p05\n(%)", sub, labdf))
p21 <- deco(panel(foot,    "flood", RAMP_FLOOD, lim_flood, "Flood frequency — paddock grain (64)", FALSE, NULL))
p22 <- deco(panel(pgv_ok,  "flood", RAMP_FLOOD, lim_flood, "Flood frequency — part grain (115)",   TRUE,
                  "flood\n(% yrs)", sub))

key <- data.frame(x = c(1, 2), y = c(1, 1),
                  lab = c(NOT_ASSESSED, BELOW_SUPPORT), f = c(COL_NA, COL_SUB))
keyplot <- ggplot(key, aes(x, y)) +
  geom_tile(fill = key$f, colour = "grey55", width = 0.10, height = 0.5) +
  geom_text(aes(x = x + 0.075, label = lab), hjust = 0, size = 2.8) +
  coord_cartesian(xlim = c(0.85, 3.6), ylim = c(0.5, 1.5)) +
  theme_void()

SUP <- paste0("Right column: 115 of 118 parts carry a value. The 3 sub-support fragments (fewer ",
              "than 25 years of >=30 valid pixels) are drawn in their own grey — a blank there ",
              "would mean 'no data' and 'no cover' at once. Pale fill = not assessed (treed or ",
              "outside the mapped census). Both columns share one footprint.")
fig1 <- (p11 | p12) / (p21 | p22) / keyplot + patchwork::plot_layout(heights = c(1, 1, 0.09)) +
  patchwork::plot_annotation(
    title = "The same country, two ways of looking at it",
    subtitle = paste0("Rows share a colour scale; columns share a footprint. Dashed outline = the four conserved paddocks.\n", SUP),
    theme = theme(plot.title = element_text(face = "bold", size = 14),
                  plot.subtitle = element_text(size = 7.8, colour = "grey30", lineheight = 1.15)))

## ---- the spread number, verified not asserted -------------------------------------------------
spr <- part %>% group_by(zone_fid) %>% filter(n() > 1) %>%
  summarise(spread = max(floor) - min(floor), .groups = "drop")
med_spr <- median(spr$spread); max_spr <- max(spr$spread)
cat(sprintf("within-paddock spread: %d multi-part paddocks, median %.1f pp, max %.1f pp\n",
            nrow(spr), med_spr, max_spr))
stopifnot(nrow(spr) == 37, abs(med_spr - 12.8) < 0.05, abs(max_spr - 40.2) < 0.05)
d1 <- part %>% filter(zone_fid == name$zone_fid[name$zone_name == "Dinan 1"]) %>% arrange(desc(floor))
d1p <- pad$floor[pad$zone_fid == name$zone_fid[name$zone_name == "Dinan 1"]]

cap1 <- paste0(
  "Support level: pixel (35-year means, non-treed ground). The same two measurements, drawn twice. ",
  "The left column shows each paddock as a single value; the right column breaks each paddock into ",
  "its vegetation communities. Top row is how much cover the poorest patches carry; bottom row is ",
  "how often the ground floods. The two rows look alike, which is the point — water organises cover ",
  "more strongly than any management boundary does. The two columns do not, which is the second ",
  sprintf("point: a paddock average hides a median of %.1f percentage points of difference between the ", med_spr),
  sprintf("parts of the same paddock, and up to %.1f. Dinan 1 reads %.1f as a paddock; its three parts read ", max_spr, d1p),
  paste(sprintf("%.0f", d1$floor), collapse = ", "), ". ",
  "Each row shares one colour scale, so the two grains are directly comparable; the scales differ ",
  "between rows (green = cover, blue = water) so the row is never in doubt. ",
  "Both columns are drawn on the same footprint — the paddock outline is its in-scope ground ",
  "dissolved from the parts, not the whole management zone, because the paddock value is not ",
  "computed on treed or context ground. ",
  "Cover is how much and how green, not a condition score, and no cause is attributed.")

gayini_assert_caption_number(cap1, med_spr, 1, "T11 F1 caption: median spread")
gayini_assert_caption_number(cap1, max_spr, 1, "T11 F1 caption: max spread")
gayini_assert_caption_number(cap1, d1p, 1, "T11 F1 caption: Dinan 1 paddock mean")
cat("caption-number assertions (median, max, Dinan 1 paddock mean): OK\n")

gayini_write_and_register_figure(
  plot = fig1, path = file.path(FIGD, "M5_dual_grain_floor_and_flood.png"),
  title = "T11 v2 - cover floor and flood frequency at paddock and part grain",
  caption = cap1, support_level = "pixel", figure_level = "headline", run_id = RUN,
  domain = "zone_diagnostics", framing_label = "census_8058",
  provenance_note = "fact_zone_veg_annual; fact_zone_community_veg_annual + fact_zone_community_flood_annual; T13 part polygons (render-only)",
  width = 15, height = 11, dpi = 200)

## ---------------------------------------------------------------- Gate B: residual panel
hn <- DBI::dbGetQuery(con, "SELECT number_id,pinned_value FROM dim_headline_number
                            WHERE number_id LIKE 'floor_flood_%'")
P <- setNames(hn$pinned_value, hn$number_id)
INT <- P[["floor_flood_intercept_64pdk"]]; SLP <- P[["floor_flood_slope_64pdk"]]
SD  <- P[["floor_flood_residual_sd_64pdk"]]
cat(sprintf("Gate B line READ from dim_headline_number: intercept %.4f slope %.3f SD %.4f\n", INT, SLP, SD))
stopifnot(abs(INT - 52.6529) < 1e-4, abs(SLP - 0.548) < 1e-4, abs(SD - 6.6208) < 1e-4)

# The spec's formula from the PINNED constants and the registered view disagree by up to 0.0135,
# and neither is wrong. dim_headline_number pins ROUNDED constants (0.548 / 52.6529); the view
# was built from the fit's full precision (implied 0.547823 / 52.653223, recovered by solving
# predicted_floor on mean_flood). Recomputing from the pinned constants therefore cannot land on
# the view exactly. Budget: slope rounding x max flood + intercept rounding + the view's own 2 dp.
reg <- DBI::dbGetQuery(con, "SELECT zone_name, residual, rank FROM v_zone_floor_flood_residual")
foot$resid_pinned <- foot$floor - (INT + SLP * foot$flood)
chk <- foot %>% sf::st_drop_geometry() %>% left_join(reg, by = "zone_name")
budget <- 0.000177 * max(foot$flood) + 0.000323 + 0.005
gap <- max(abs(chk$resid_pinned - chk$residual))
cat(sprintf("residual from PINNED constants vs registered view: max |diff| %.5f (rounding budget %.5f)\n",
            gap, budget))
stopifnot(gap < budget)

# DRAWN VALUE = the registered view. Both routes satisfy "do not refit", but a client deliverable
# must not disagree with the registry by 0.01, and the labels the spec asks for (-16.80, -15.06)
# are the registered values. The pinned-constant computation above is retained as the check.
foot <- foot %>% left_join(reg %>% select(zone_name, resid = residual), by = "zone_name")
stopifnot(!any(is.na(foot$resid)))

lb <- foot %>% filter(zone_name %in% c("Bala 29ca", "Dinan 10"))
lbxy <- sf::st_coordinates(sf::st_centroid(sf::st_geometry(lb)))
lbdf <- data.frame(x = lbxy[,1], y = lbxy[,2] - 0.05 * yr,
                   lab = sprintf("%s  %+.1f pp", lb$zone_name, lb$resid))
gayini_assert_rendered_varies(lbdf$lab, "Gate B labels")
gayini_assert_rendered_values(lbdf$lab, lb$resid, 1, TRUE, "Gate B residual labels")

rlim <- max(abs(foot$resid))
fig2 <- deco(
  ggplot() +
    geom_sf(data = foot, aes(fill = resid), colour = "grey45", linewidth = 0.1) +
    geom_sf(data = refpoly, fill = NA, colour = "#1A1A1A", linewidth = 0.5, linetype = "22") +
    geom_text(data = lbdf, aes(x, y, label = lab), size = 2.9, fontface = "bold", colour = "grey10") +
    scale_fill_gradientn(
      colours = c("#8C3A2B", "#B2182B", "#E8A798", "#F5F0EC", "#A8C6E0", "#2171B5", "#0B3D73"),
      limits = c(-rlim, rlim), breaks = c(-2*SD, -SD, 0, SD, 2*SD),
      labels = sprintf("%+.1f", c(-2*SD, -SD, 0, SD, 2*SD)),
      name = "Cover above (blue)\nor below (red)\nexpectation (pp)",
      guide = guide_colourbar(barheight = unit(4.2, "cm"), barwidth = unit(0.4, "cm"))) +
    labs(title = "Which paddocks hold more or less cover than their water predicts",
         subtitle = sprintf("Residual from the registered expectation line (%.1f + %.3f x flood %%), read from dim_headline_number and not refitted.\nTicks are at one and two typical misses (1 SD = %.2f pp). Dashed outline = the four conserved paddocks.",
                            INT, SLP, SD)) +
    theme_void(base_size = 10) +
    theme(legend.position = "right", plot.title = element_text(face = "bold", size = 13),
          plot.subtitle = element_text(size = 8, colour = "grey30", lineheight = 1.15),
          plot.background = element_rect(fill = "white", colour = NA)))

cap2 <- paste0(
  "Support level: pixel (35-year means, non-treed ground), 64 paddocks. ",
  "How much cover each paddock carries against how much its water supply predicts. Blue is more ",
  "than expected, red is less; the scale is centred on zero and ticked at one and two typical ",
  sprintf("misses (1 SD = %.2f pp). ", SD),
  "Bala 29ca sits further below expectation than any paddock except Dinan 10 — which is grazed, ",
  "and almost exactly as dry. That pair is the reason dryness, not management, is the first ",
  "explanation to reach for. ",
  "There is deliberately NO part-grain version of this map: the expectation line is fitted across ",
  "the 64 paddocks and no part-grain fit has been registered. T13's level_z is a different ",
  "quantity — how far a part sits from its own community's median, not from a water expectation — ",
  "and the two must not be shown as versions of the same thing. ",
  "The line is read from the registered numbers, not refitted here. No cause is attributed.")

# the two labelled residuals must equal the registered values the spec names
stopifnot(abs(lb$resid[lb$zone_name == "Bala 29ca"] - (-16.80)) < 0.005,
          abs(lb$resid[lb$zone_name == "Dinan 10"] - (-15.06)) < 0.005)

gayini_assert_caption_number(cap2, SD, 2, "T11 F2 caption: residual SD")

gayini_write_and_register_figure(
  plot = fig2, path = file.path(FIGD, "M5b_paddock_residual_from_expectation.png"),
  title = "T11 v2 - paddock residual from the registered cover-water expectation line",
  caption = cap2, support_level = "pixel", figure_level = "headline", run_id = RUN,
  domain = "zone_diagnostics", framing_label = "census_8058",
  provenance_note = "v_zone_floor_flood_residual for cross-check; line from dim_headline_number floor_flood_* pinned rows, NOT refitted",
  width = 11, height = 8, dpi = 200)

cat("\nT11 v2 Gate A and Gate B built. Assembly only; nothing refitted.\n")
