# ------------------------------------------------------------------------------
# Script: scripts/07_figures_dashboards/taskM_gateD_M2_method.R
# Purpose: Tier 2 · Task M · Gate D §D.4 — the all-pixel method explainer the
#          deck lacks. Schematic, NOT a chart of results. Every number on it is
#          read live from the DB (census_stratum) or is a §1 established fact;
#          the script hardcodes no result value.
#
# Run mode: figure build (read-only DB) · writes ONE new PNG
# Output: Output/figures/M2_all_pixel_method.png
# ------------------------------------------------------------------------------

root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", getwd()), winslash = "/", mustWork = TRUE)
source(file.path(root_dir, "R", "gayini_output_helpers.R"))
suppressPackageStartupMessages({ library(DBI); library(RSQLite) })

DB      <- file.path(root_dir, "Output", "database", "Gayini_Results.sqlite")
OUT_PNG <- file.path(root_dir, "Output", "figures", "M2_all_pixel_method.png")

# Design tokens
CREAM  <- "#F8F7F2"; PETROL <- "#0F3947"; INK <- "#26302E"; MUTED <- "#8A8378"
RUST   <- "#9C5B2E"; GOLD <- "#C79A3B"
TINT   <- list(Aeolian = c("#F3EBDA", "#C79A3B", "#8A5F1E"),
               Riverine = c("#E4EFEC", "#3B8A8F", "#2A6560"),
               Inland = c("#EEF5FD", "#2165AC", "#1B4E86"),
               Context = c("#ECEBE6", "#7C837E", "#565B57"))

## --- numbers, read live (no hardcoded results) ---
con <- DBI::dbConnect(RSQLite::SQLite(), DB)
strata <- DBI::dbGetQuery(con, "SELECT community, regime_band, treed_context_flag,
                                       n_pixels, area_ha, farm_area_total_ha
                                FROM census_stratum ORDER BY community_order, band_order")
n_plots <- DBI::dbGetQuery(con, "SELECT COUNT(*) n FROM dim_plot")$n
DBI::dbDisconnect(con)

n_pixels  <- sum(strata$n_pixels)
n_strata  <- nrow(strata)
mapped_ha <- sum(strata$area_ha)
farm_ha   <- strata$farm_area_total_ha[1]
pct_map   <- 100 * mapped_ha / farm_ha
fmt <- function(x) formatC(x, format = "d", big.mark = ",")
fmt1 <- function(x) formatC(x, format = "f", digits = 1, big.mark = ",")
stopifnot(n_pixels == 1080157L, n_strata == 11L, n_plots == 66L)

focus_comm <- c("Aeolian Chenopod Shrublands", "Riverine Chenopod Shrublands",
                "Inland Floodplain Shrublands / Swamps")
short <- c("Aeolian", "Riverine", "Inland")
bands <- c("low", "mid", "high")

## --- draw ---
ragg::agg_png(OUT_PNG, width = 2400, height = 1500, units = "px", res = 200,
              background = CREAM)
on.exit(grDevices::dev.off(), add = TRUE)
par(bg = CREAM, mar = c(0, 0, 0, 0))
plot.new(); plot.window(xlim = c(0, 100), ylim = c(0, 100), asp = NA)

text(3, 96, "How the analysis works: every pixel, not a sample", adj = 0,
     col = PETROL, cex = 1.7, font = 2)
text(3, 91.4, "A whole-farm census replaces the 66 monitoring plots as the unit of analysis.",
     adj = 0, col = MUTED, cex = 1.05)

## ---- Band 1: the shift, 66 plots -> 1,080,157 pixels ----
text(3, 85, "1 · From 66 sites to every pixel", adj = 0, col = RUST, cex = 1.05, font = 2)
## left: 66 plot squares in a cluster
px0 <- 4; py0 <- 74; cellw <- 1.5
for (i in 0:65) {
  cx <- px0 + (i %% 11) * cellw
  cy <- py0 - (i %/% 11) * cellw
  rect(cx, cy, cx + cellw * 0.7, cy + cellw * 0.7, col = GOLD, border = NA)
}
text(px0, 77.4, paste0(n_plots, " one-hectare plots"), adj = 0, col = INK,
     cex = 1.0, font = 2)
text(px0, 63.6, "anchors, sampled", adj = 0, col = MUTED, cex = 0.9)

## arrow
arrows(23, 71, 32, 71, length = 0.16, lwd = 3, col = PETROL)

## right: dense pixel block
bx0 <- 34; by0 <- 74; bw <- 0.62
ramp <- colorRampPalette(c("#D9F0A3", "#238443"))(40)
set_shade <- function(i) ramp[(i * 7) %% 40 + 1]
k <- 0
for (r in 0:14) for (c in 0:39) {
  rect(bx0 + c * bw, by0 - r * bw, bx0 + (c + 1) * bw - 0.06,
       by0 - (r + 1) * bw + 0.06, col = set_shade(k <- k + 1), border = NA)
}
text(bx0, 77.4, paste0(fmt(n_pixels), " census pixels"), adj = 0, col = INK,
     cex = 1.0, font = 2)
text(bx0, 62.5, "24.97 m · EPSG:8058 · one flood-frequency & cover value each",
     adj = 0, col = MUTED, cex = 0.9)

## mapped-area strip
mb_x0 <- 66; mb_x1 <- 97; mb_y <- 71; mb_h <- 3.2
rect(mb_x0, mb_y, mb_x1, mb_y + mb_h, col = "#E7E4DA", border = NA)
rect(mb_x0, mb_y, mb_x0 + (mb_x1 - mb_x0) * pct_map / 100, mb_y + mb_h,
     col = GOLD, border = NA)
rect(mb_x0, mb_y, mb_x1, mb_y + mb_h, border = PETROL, lwd = 1.1)
text(mb_x0, mb_y + mb_h + 2.0, "Mapped extent", adj = 0, col = INK, cex = 0.95, font = 2)
text(mb_x0, mb_y - 2.2,
     paste0(fmt1(mapped_ha), " ha mapped of the ", fmt1(farm_ha), " ha farm (",
            formatC(pct_map, format = "f", digits = 1), "%)"),
     adj = 0, col = MUTED, cex = 0.9)

## ---- Band 2: the 11 strata ----
text(3, 57, paste0("2 · ", n_strata, " strata: 3 communities × 3 wetness bands, + 2 context"),
     adj = 0, col = RUST, cex = 1.05, font = 2)

gx0 <- 16; gy0 <- 51; gw <- 12; gh <- 6.2; gpad <- 1.2
## column headers (bands)
for (j in seq_along(bands))
  text(gx0 + (j - 0.5) * (gw + gpad), gy0 + 2.4, toupper(bands[j]),
       col = MUTED, cex = 0.85, font = 2)
for (i in seq_along(focus_comm)) {
  key <- short[i]
  shades <- colorRampPalette(TINT[[key]])(3)
  ry <- gy0 - (i - 1) * (gh + gpad)
  text(gx0 - 1.5, ry - gh / 2, key, adj = 1, col = TINT[[key]][3], cex = 1.0, font = 2)
  for (j in seq_along(bands)) {
    row <- strata[strata$community == focus_comm[i] & strata$regime_band == bands[j], ]
    cx <- gx0 + (j - 1) * (gw + gpad)
    rect(cx, ry - gh, cx + gw, ry, col = shades[j], border = "#FFFFFF", lwd = 1.4)
    dark <- j >= 2
    text(cx + gw / 2, ry - gh / 2 + 0.9, paste0(fmt(row$n_pixels), " px"),
         col = if (dark) "#FFFFFF" else INK, cex = 0.92, font = 2)
    text(cx + gw / 2, ry - gh / 2 - 1.4, paste0(fmt1(row$area_ha), " ha"),
         col = if (dark) "#FFFFFF" else MUTED, cex = 0.82)
  }
}
## two context strata to the right — taller tiles, three non-overlapping text lines
ctx <- strata[strata$treed_context_flag == 1 |
              strata$community == "Other / minor units", ]
cx0 <- gx0 + 3 * (gw + gpad) + 3; ctw <- gw + 5
cth <- 9.0; ctgap <- 3.0
labs <- c("Floodplain Woodland / Forest", "Other / minor units")
for (i in seq_len(nrow(ctx))) {
  ry <- gy0 - (i - 1) * (cth + ctgap)
  rect(cx0, ry - cth, cx0 + ctw, ry, col = TINT$Context[1],
       border = TINT$Context[3], lwd = 1.4, lty = 2)
  text(cx0 + ctw / 2, ry - 2.0, labs[i], col = TINT$Context[3], cex = 0.76, font = 2)
  text(cx0 + ctw / 2, ry - 4.9, paste0(fmt(ctx$n_pixels[i]), " px"),
       col = INK, cex = 0.95, font = 2)
  text(cx0 + ctw / 2, ry - 7.3, "context — treed / minor, set aside",
       col = MUTED, cex = 0.64)
}

## ---- Band 3: the honest caveat ----
box_y1 <- 12.5; box_y0 <- 3.4
rect(3, box_y0, 97, box_y1, col = "#EDEAE0", border = GOLD, lwd = 1.2)
text(5, box_y1 - 2.1, "What the census does and does not buy", adj = 0,
     col = PETROL, cex = 1.0, font = 2)
text(5, box_y1 - 4.6,
     "Removes SAMPLING uncertainty — no draw, no rebalance, every pixel measured.",
     adj = 0, col = "#2E6B2E", cex = 0.92)
text(5, box_y1 - 6.7,
     paste0("Does NOT make the pixels independent observations — ",
            "~1M pixels are spatially and temporally autocorrelated."),
     adj = 0, col = "#9A6B5A", cex = 0.92)

## verbatim footer (spec §D.4)
text(50, 1.4,
     paste0("The census removes sampling uncertainty only. ~1M pixels are NOT independent n ",
            "(spatial and temporal autocorrelation). Landsat fractional cover measures COVER, ",
            "not condition."),
     col = MUTED, cex = 0.72)

message("[M2] wrote ", OUT_PNG, "  (plots=", n_plots, " pixels=", fmt(n_pixels),
        " strata=", n_strata, " mapped%=", formatC(pct_map, format = "f", digits = 1), ")")
