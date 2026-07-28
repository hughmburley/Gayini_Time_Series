#!/usr/bin/env Rscript
# T12 · Gate C — diagnostics and falsification pack (spec v4, all seven items).
# STOP gate: produces figures + tables + the numbers a human needs to evaluate the
# §2.7 stopping rule. Does NOT classify (Gate D). Read-only against DEA rasters and
# the DB; writes figures to figures/diagnostics/ and tables to Output/tables/, all
# T12_DEA_-prefixed. Figure registration is a separate step (Python).
#
# Items: 1 persistence FRACTION (§2.9, full + pilot, §2.9.3 rule) · 2 farm CTV vs
# flood/veg · 3 zone correlations (both water-year alignments, §6) · 4 zone floor
# table · 5 suspect-year sensitivity · 6 four reference paddocks · 7 positive control
# (§2.10, on- vs off-property, one panel, hard scope stop).

suppressPackageStartupMessages({library(terra); library(sf); library(DBI); library(RSQLite); library(ggplot2)})
root <- "d:/Github_repos/Gayini"
db <- file.path(root, "Output/database/Gayini_Results.sqlite")
figdir <- file.path(root, "figures/diagnostics"); dir.create(figdir, showWarnings = FALSE, recursive = TRUE)
tabdir <- file.path(root, "Output/tables")
CAP <- "DEA Land Cover is a modelled national product, not a record of land use. Not independent of the Gayini census."
RUN <- "T12_gateC"

# ---- inputs ----------------------------------------------------------------
con <- dbConnect(SQLite(), db, flags = SQLITE_RO)
bpath <- dbGetQuery(con, "SELECT path FROM spatial_layer_asset WHERE spatial_layer_asset_id='spatial_007'")$path
zone_ctv <- dbGetQuery(con, "SELECT zone_fid, dea_calendar_year, dea_ctv_pct FROM fact_dea_landcover_zone_year")
farm_ctv <- dbGetQuery(con, "SELECT dea_calendar_year, dea_ctv_pct FROM fact_dea_landcover_farm_year ORDER BY dea_calendar_year")
fzva <- dbGetQuery(con, "SELECT zone_fid, water_year, veg_mean, flood_frac_pct, wet_pixels, valid_pixels, n_pixels_valid
                         FROM fact_zone_veg_annual WHERE series_variant='mean_of_seasons'")
dmz <- dbGetQuery(con, "SELECT zone_fid, zone_name FROM dim_management_zone")
dbDisconnect(con)

dir <- file.path(root, "Input/landsat_landcover/level3")
files <- sort(list.files(dir, pattern = "^LLC3_\\d{4}_MGA54\\.tif$", full.names = TRUE))
years <- as.integer(sub(".*LLC3_(\\d{4}).*", "\\1", basename(files)))
dea <- rast(files); names(dea) <- years
grid <- dea[[1]]
boundary <- project(vect(file.path(root, bpath)), "EPSG:7854")

# masks: on-property (centroid in boundary) and off-property control (>500 m outside)
propmask <- rasterize(boundary, grid, field = 1, touches = FALSE)
buf500   <- rasterize(buffer(boundary, 500), grid, field = 1, touches = FALSE)
vprop <- values(propmask)[, 1]; vbuf <- values(buf500)[, 1]
onprop <- which(!is.na(vprop))
control <- which(is.na(vbuf))           # outside property + 500 m ring
cat(sprintf("on-property pixels %d | off-property control pixels %d\n", length(onprop), length(control)))

# ---- per-pixel CTV counts (full 38y, 8y pilot, 13y non-suspect) -------------
pilot_years <- c(2013:2017, 2023:2025); ns_years <- 2013:2025
# §2.9: frac = CTV years / VALID years, NA-aware (off-property cells can be NA, so
# valid years != 38 there). Denominator is valid years per pixel, not a constant.
ctv_bin <- dea == 111; valid_bin <- !is.na(dea)
cf <- function(idx) {
  c <- values(sum(ctv_bin[[idx]], na.rm = TRUE))[, 1]
  v <- values(sum(valid_bin[[idx]], na.rm = TRUE))[, 1]
  ifelse(v > 0, c / v, NA_real_)
}
frac_full  <- cf(seq_along(years))
frac_pilot <- cf(match(pilot_years, years))
frac_ns    <- cf(match(ns_years, years))

# ---- §2.9.3 separated-mode rule --------------------------------------------
sep_mode <- function(fr, lab) {
  fr <- fr[is.finite(fr)]; n <- length(fr)
  # raw 20-bin histogram (spec) — reported for transparency, but prone to a
  # k/valid-years vs 0.05-bin granularity sawtooth on discrete fractions.
  br <- seq(0, 1, by = 0.05); h <- hist(fr, breaks = br, plot = FALSE); cnt <- h$counts
  # SMOOTHED DENSITY (spec §2.9.3 evaluates "the smoothed density") via Gaussian KDE,
  # which removes the discreteness artifact. Local minima with x in [0.30,0.70].
  d <- density(fr, from = 0, to = 1, n = 512, bw = 0.05)  # smooth at the spec's 0.05 scale
  imin <- which(diff(sign(diff(d$y))) == 2) + 1
  win <- imin[d$x[imin] >= 0.30 & d$x[imin] <= 0.70]
  has_min <- length(win) > 0
  cut <- if (has_min) d$x[win[which.min(d$y[win])]] else NA_real_
  mass_above <- if (has_min) mean(fr > cut) else NA_real_
  verdict <- has_min && !is.na(mass_above) && mass_above >= 0.01
  cat(sprintf("  [%s] n=%d | KDE local-min in [0.30,0.70]: %s @%.2f | mass above: %s | SEP MODE: %s\n",
              lab, n, has_min, ifelse(is.na(cut), 0, cut),
              ifelse(is.na(mass_above), "-", sprintf("%.3f%%", 100*mass_above)), verdict))
  cat("     raw bin%[0->1 by .05]:", paste(sprintf("%.2f", 100*cnt/n), collapse = " "), "\n")
  data.frame(window = lab, n = n, ever_ctv_pct = round(100*mean(fr > 0), 2),
             frac_ge0.50_pct = round(100*mean(fr >= 0.50), 3),
             frac_ge0.75_pct = round(100*mean(fr >= 0.75), 3), max_frac = round(max(fr), 3),
             kde_local_min = has_min, min_at = round(ifelse(is.na(cut), NA, cut), 2),
             mass_above_min_pct = ifelse(is.na(mass_above), NA, round(100*mass_above, 3)),
             separated_mode = verdict, stringsAsFactors = FALSE)
}
cat("=== ITEM 1 · §2.9.3 stopping-rule test (persistence FRACTION, on-property) ===\n")
s_full  <- sep_mode(frac_full[onprop],  "full_1988_2025")
s_pilot <- sep_mode(frac_pilot[onprop], "pilot_8yr")
s_ns    <- sep_mode(frac_ns[onprop],    "nonsuspect_2013_2025")
s_ctrl  <- sep_mode(frac_full[control], "control_full_1988_2025")
persist_summary <- rbind(s_full, s_pilot, s_ns, s_ctrl)
write.csv(persist_summary, file.path(tabdir, "T12_DEA_persistence_summary.csv"), row.names = FALSE)

# figures item 1 (two separate figures, never shared axes)
gg_persist <- function(fr, ttl, fn) {
  d <- data.frame(frac = fr)
  g <- ggplot(d, aes(frac)) +
    geom_histogram(breaks = seq(0, 1, 0.05), fill = "#7FB09A", colour = "white") +
    annotate("rect", xmin = 0.30, xmax = 0.70, ymin = 0, ymax = Inf, alpha = 0.08, fill = "#0E7A5F") +
    labs(title = ttl, x = "CTV persistence fraction (CTV years / valid years)",
         y = "pixels", caption = CAP) +
    theme_minimal(base_size = 11)
  ggsave(file.path(figdir, fn), g, width = 7, height = 4.2, dpi = 130); fn
}
f1a <- gg_persist(frac_full[onprop],  "DEA Land Cover (modelled) — CTV persistence, full record 1988–2025 (on-property)", "T12_DEA_persistence_fraction_full_1988_2025.png")
f1b <- gg_persist(frac_pilot[onprop], "DEA Land Cover (modelled) — CTV persistence, 8-year pilot subset (reconciliation only)", "T12_DEA_persistence_fraction_pilot_8yr.png")

# ---- ITEM 2 · farm CTV vs property flood & veg, 1988-2025 -------------------
prop_hydro <- do.call(rbind, lapply(split(fzva, fzva$water_year), function(d) data.frame(
  water_year = d$water_year[1],
  veg_mean = sum(d$veg_mean * d$n_pixels_valid) / sum(d$n_pixels_valid),
  flood_frac = 100 * sum(d$wet_pixels) / sum(d$valid_pixels))))
d2 <- merge(data.frame(year = farm_ctv$dea_calendar_year, ctv = farm_ctv$dea_ctv_pct),
            data.frame(year = prop_hydro$water_year, veg = prop_hydro$veg_mean, flood = prop_hydro$flood_frac),
            by = "year", all.x = TRUE)
write.csv(d2, file.path(tabdir, "T12_DEA_farm_ctv_vs_flood_veg.csv"), row.names = FALSE)
d2l <- rbind(data.frame(year = d2$year, value = d2$ctv,   series = "DEA CTV % (calendar yr)"),
             data.frame(year = d2$year, value = d2$flood, series = "flood_frac % (water yr)"),
             data.frame(year = d2$year, value = d2$veg,   series = "veg_mean (water yr)"))
g2 <- ggplot(d2l, aes(year, value, colour = series)) + geom_line(na.rm = TRUE) + geom_point(size = 0.8, na.rm = TRUE) +
  scale_colour_manual(values = c("DEA CTV % (calendar yr)" = "#B4632F", "flood_frac % (water yr)" = "#4D9FDC", "veg_mean (water yr)" = "#0E7A5F")) +
  labs(title = "DEA Land Cover (modelled) — farm CTV vs flood & veg, 1988–2025",
       x = NULL, y = "percent", colour = NULL, caption = CAP) + theme_minimal(base_size = 11) + theme(legend.position = "bottom")
ggsave(file.path(figdir, "T12_DEA_farm_ctv_vs_flood_veg_1988_2025.png"), g2, width = 8, height = 4.4, dpi = 130)

# adjacent-year swing factor (property CTV) — §2.7 input
swing <- function(v) { v <- v[v > 0]; max(mapply(function(a, b) max(a/b, b/a), v[-1], v[-length(v)])) }
sw_all <- swing(farm_ctv$dea_ctv_pct)
sw_ns  <- swing(farm_ctv$dea_ctv_pct[farm_ctv$dea_calendar_year %in% ns_years])
cat(sprintf("=== ITEM 2 · adjacent-year swing factor: all-years %.2fx | non-suspect %.2fx (>3x = §2.7 'swinging') ===\n", sw_all, sw_ns))

# ---- ITEM 3 · zone correlations, both water-year alignments (§6) ------------
zc <- merge(zone_ctv, dmz, by = "zone_fid")
corr_align <- function(offset) {
  z2 <- zone_ctv; z2$wy <- z2$dea_calendar_year - offset
  m <- merge(z2, fzva, by.x = c("zone_fid", "wy"), by.y = c("zone_fid", "water_year"))
  do.call(rbind, lapply(split(m, m$zone_fid), function(d) data.frame(
    zone_fid = d$zone_fid[1], n = nrow(d),
    corr_ctv_flood = if (nrow(d) > 2) cor(d$dea_ctv_pct, d$flood_frac_pct) else NA,
    corr_ctv_veg   = if (nrow(d) > 2) cor(d$dea_ctv_pct, d$veg_mean) else NA)))
}
cA <- corr_align(0); names(cA)[-1] <- paste0(names(cA)[-1], "_A")   # wy = cy
cB <- corr_align(1); names(cB)[-1] <- paste0(names(cB)[-1], "_B")   # wy = cy-1
corr_tab <- merge(merge(dmz, cA, by = "zone_fid"), cB, by = "zone_fid")
write.csv(corr_tab, file.path(tabdir, "T12_DEA_zone_correlations.csv"), row.names = FALSE)
cat(sprintf("=== ITEM 3 · zone CTV~flood corr (align A): median %.3f | zones |r|>=0.5: %d/64 | align B median %.3f ===\n",
            median(corr_tab$corr_ctv_flood_A, na.rm = TRUE), sum(abs(corr_tab$corr_ctv_flood_A) >= 0.5, na.rm = TRUE),
            median(corr_tab$corr_ctv_flood_B, na.rm = TRUE)))

# ---- ITEM 4 · zone floor table (mean CTV 2023-25), sorted ------------------
fl <- aggregate(dea_ctv_pct ~ zone_fid, data = subset(zone_ctv, dea_calendar_year %in% 2023:2025), FUN = mean)
names(fl)[2] <- "dea_ctv_floor"; fl <- merge(dmz, fl, by = "zone_fid"); fl <- fl[order(-fl$dea_ctv_floor), ]
write.csv(fl, file.path(tabdir, "T12_DEA_zone_floor_table.csv"), row.names = FALSE)
cat(sprintf("=== ITEM 4 · zone floor: unweighted mean %.2f%% | zones >5%%: %d/64 | range %.2f-%.2f (%s .. %s) ===\n",
            mean(fl$dea_ctv_floor), sum(fl$dea_ctv_floor > 5), min(fl$dea_ctv_floor), max(fl$dea_ctv_floor),
            fl$zone_name[which.min(fl$dea_ctv_floor)], fl$zone_name[which.max(fl$dea_ctv_floor)]))

# ---- ITEM 5 · suspect-year sensitivity (headlines all vs non-suspect) ------
sens <- data.frame(
  headline = c("ever-CTV %", "persistence frac >=0.75 %", "adjacent-year swing (x)", "separated mode?"),
  all_years = c(s_full$ever_ctv_pct, s_full$frac_ge0.75_pct, round(sw_all,2), s_full$separated_mode),
  nonsuspect_2013_2025 = c(s_ns$ever_ctv_pct, s_ns$frac_ge0.75_pct, round(sw_ns,2), s_ns$separated_mode),
  stringsAsFactors = FALSE)
write.csv(sens, file.path(tabdir, "T12_DEA_suspect_year_sensitivity.csv"), row.names = FALSE)
cat("=== ITEM 5 · suspect-year sensitivity ===\n"); print(sens, row.names = FALSE)

# ---- ITEM 6 · four reference paddocks, full record, 29ca broken out --------
ref <- subset(zc, zone_name %in% c("Bala 26ca","Bala 27ca","Bala 28ca","Bala 29ca"))
ref_w <- reshape(ref[, c("zone_name","dea_calendar_year","dea_ctv_pct")],
                 idvar = "dea_calendar_year", timevar = "zone_name", direction = "wide")
names(ref_w) <- sub("dea_ctv_pct.", "", names(ref_w)); ref_w <- ref_w[order(ref_w$dea_calendar_year), ]
write.csv(ref_w, file.path(tabdir, "T12_DEA_reference_paddocks.csv"), row.names = FALSE)
b29 <- subset(ref, zone_name == "Bala 29ca")
cat(sprintf("=== ITEM 6 · Bala 29ca CTV: 1988-1992 mean %.1f%% (SUSPECT, L5-TM) | 2013-2025 mean %.1f%% | 2023-25 floor %.1f%% ===\n",
            mean(b29$dea_ctv_pct[b29$dea_calendar_year %in% 1988:1992]),
            mean(b29$dea_ctv_pct[b29$dea_calendar_year %in% 2013:2025]),
            mean(b29$dea_ctv_pct[b29$dea_calendar_year %in% 2023:2025])))

# ---- ITEM 7 · positive control panel (on- vs off-property) -----------------
ctrl_df <- rbind(data.frame(frac = frac_full[onprop],  scope = "on_property"),
                 data.frame(frac = frac_full[control], scope = "off_property_control"))
ctrl_df <- ctrl_df[is.finite(ctrl_df$frac), ]
g7 <- ggplot(ctrl_df, aes(frac, y = after_stat(density), fill = scope)) +
  geom_histogram(breaks = seq(0, 1, 0.05), position = "identity", alpha = 0.55, colour = "white") +
  scale_fill_manual(values = c(on_property = "#7FB09A", off_property_control = "#B4632F")) +
  labs(title = "DEA Land Cover (modelled) — CTV persistence, on-property vs off-property control (§2.10)",
       subtitle = "Off-property = raster extent − property − 500 m buffer. Positive control only; never a Gayini denominator.",
       x = "CTV persistence fraction, 1988–2025", y = "density", fill = NULL, caption = CAP) +
  theme_minimal(base_size = 11) + theme(legend.position = "bottom")
ggsave(file.path(figdir, "T12_DEA_positive_control.png"), g7, width = 8, height = 4.6, dpi = 130)
# control & on-property CTV% per year, and their adjacent-year swing factors
ctrl_ctv_by_year <- sapply(seq_along(years), function(i) 100 * mean(values(dea[[i]])[control, 1] == 111, na.rm = TRUE))
onp_ctv_by_year  <- sapply(seq_along(years), function(i) 100 * mean(values(dea[[i]])[onprop,  1] == 111, na.rm = TRUE))
cat(sprintf("=== ITEM 7 · positive control: on-property ever-CTV %.1f%% vs control %.1f%% | persist>=0.75: on %.3f%% vs control %.3f%% | swing on %.2fx vs control %.2fx ===\n",
            100*mean(frac_full[onprop] > 0, na.rm = TRUE), 100*mean(frac_full[control] > 0, na.rm = TRUE),
            100*mean(frac_full[onprop] >= 0.75, na.rm = TRUE), 100*mean(frac_full[control] >= 0.75, na.rm = TRUE),
            swing(onp_ctv_by_year), swing(ctrl_ctv_by_year)))
write.csv(data.frame(year = years, onprop_ctv_pct = round(onp_ctv_by_year,3), control_ctv_pct = round(ctrl_ctv_by_year,3)),
          file.path(tabdir, "T12_DEA_positive_control_by_year.csv"), row.names = FALSE)

cat("\n[done] figures -> figures/diagnostics/T12_DEA_*.png ; tables -> Output/tables/T12_DEA_*.csv\n")
cat("FIGURES:", f1a, f1b, "T12_DEA_farm_ctv_vs_flood_veg_1988_2025.png", "T12_DEA_positive_control.png", sep = "\n  ")
