# Adrian pack — T1 (conserved paddocks side by side), F3 (annual gap series), F5 (cover vs water).
#
# ASSEMBLY ONLY. Every value is read from a registered object or a committed T10/REG-1 output.
# Nothing is refitted here - the F5 expectation line comes from dim_headline_number, NOT from a
# regression run in this script. If a value does not reproduce, the script STOPS.
#
# Outputs: Output/tables/T1_conserved_paddock_comparison.csv
#          Output/figures/T1_conserved_paddock_comparison.png
#          Output/figures/F3_annual_gap_series.png
#          Output/figures/F5_cover_vs_water_64_paddocks.png
suppressPackageStartupMessages({library(ggplot2); library(dplyr); library(DBI); library(RSQLite)
                                library(patchwork)})
source("R/gayini_params.R")
source("R/gayini_figure_register.R")
source("R/gayini_assert_rendered.R")

RUN  <- "adrian_pack_20260731"
FIGD <- "Output/figures"; TABD <- "Output/tables"
DBP  <- "Output/database/Gayini_Results.sqlite"
con  <- DBI::dbConnect(RSQLite::SQLite(), DBP)
on.exit(DBI::dbDisconnect(con), add = TRUE)

REF  <- c("Bala 26ca", "Bala 27ca", "Bala 28ca", "Bala 29ca")
# deck palette: same semantic set ratified at T13 Gate D
PAL_STATE <- c("Recovering"="#2E7D32","Unremarkable"="#9E9E9E","Declining"="#B2182B",
               "Persistently poor"="#8D6E63")
COL_REF <- "#B2182B"; COL_GRAZED <- "#9E9E9E"; COL_LINE <- "#2E7D32"

## ============================================================ T1 — the four, side by side
res  <- DBI::dbGetQuery(con, "SELECT zone_fid,zone_name,mean_floor,mean_flood,residual,rank AS resid_rank
                              FROM v_zone_floor_flood_residual")
stopifnot(nrow(res) == 64)
# ranks computed by ORDERING registered values - no refit. Direction stated in the caption.
res$flood_rank <- rank(-res$mean_flood, ties.method = "min")   # 1 = wettest
res$floor_rank <- rank(-res$mean_floor, ties.method = "min")   # 1 = highest cover

tmp  <- read.csv("Output/tables/T10_gateC_temporal_table.csv", stringsAsFactors = FALSE)
comp <- DBI::dbGetQuery(con, "SELECT zone_fid,zone_name,community,share_a FROM v_zone_community_composition")
cls  <- DBI::dbGetQuery(con, "SELECT zone_fid,community,state_registered,assert_state
                              FROM fact_zone_community_part_classification")
plots <- DBI::dbGetQuery(con,
  "SELECT zone_name, COUNT(*) n FROM plot_paddock
   WHERE simplified_vegetation_group <> 'Floodplain Woodland / Forest' GROUP BY 1")

short <- function(x) c("Inland Floodplain Shrublands / Swamps"="Inland",
                       "Riverine Chenopod Shrublands"="Riverine",
                       "Aeolian Chenopod Shrublands"="Aeolian",
                       "Floodplain Woodland / Forest"="Woodland")[x]

rows <- lapply(REF, function(z) {
  fid <- res$zone_fid[res$zone_name == z]
  cp  <- comp %>% filter(zone_name == z, share_a >= 0.5) %>% arrange(desc(share_a))
  st  <- cls %>% filter(zone_fid == fid) %>% arrange(community)
  tr  <- tmp %>% filter(zone_name == z)
  r   <- res %>% filter(zone_name == z)
  data.frame(
    paddock = z,
    composition = paste(sprintf("%s %.0f%%", short(cp$community), cp$share_a), collapse = " / "),
    mean_flood_pct = r$mean_flood, flood_rank_of_64 = r$flood_rank,
    veg_p05_spatial = r$mean_floor, floor_rank_of_64 = r$floor_rank,
    cross_sectional_residual_pp = r$residual, residual_rank_of_64 = r$resid_rank,
    water_adjusted_floor_trend_pp_yr = tr$water_adjusted_floor_trend,
    adj_trend_rank_of_64 = tr$rank_by_adjusted,
    part_states = paste(sprintf("%s %s%s", short(st$community), st$state_registered,
                                ifelse(st$assert_state == 0, " (not asserted)", "")),
                        collapse = " · "),
    reportable_sites = ifelse(z %in% plots$zone_name, plots$n[match(z, plots$zone_name)], 0L),
    stringsAsFactors = FALSE)
})
T1 <- do.call(rbind, rows)

## --- acceptance: hit the expected values or STOP ---------------------------------------------
EXP <- data.frame(paddock = REF,
                  flood = c(45.3, 29.7, 43.3, 8.5), floor = c(68.8, 68.0, 68.1, 40.5),
                  resid = c(-8.70, -0.91, -8.31, -16.80),
                  adj   = c(-0.108, -0.337, 0.080, 0.556), sites = c(3, 0, 8, 10))
chk <- function(got, want, tol, nm) {
  d <- max(abs(got - want))
  cat(sprintf("  %-28s max |diff| = %.4f  (tol %.3f)  %s\n", nm, d, tol,
              if (d <= tol) "OK" else "*** DIFFER ***"))
  d <= tol
}
# The adjusted trend is REGISTERED at 4 dp and was stated at 3 dp, so the honest criterion is
# "does the registered value round to the stated one", not an epsilon. A tolerance of exactly
# 0.0005 sits ON the half-ulp and fails or passes on float representation alone - Bala 26ca's
# -0.1085 is exactly half-way. Expressing the real criterion removes the ambiguity.
chk_round <- function(got, want, d, nm) {
  agree <- round(got, d) == want
  cat(sprintf("  %-28s rounds to %d dp on %d of %d  %s\n", nm, d, sum(agree), length(agree),
              if (all(agree)) "OK" else "*** DIFFER ***"))
  all(agree)
}
cat("T1 acceptance against the expected values:\n")
ok <- c(chk(T1$mean_flood_pct, EXP$flood, 0.05, "mean annual flood %"),
        chk(T1$veg_p05_spatial, EXP$floor, 0.05, "veg_p05_spatial"),
        chk(T1$cross_sectional_residual_pp, EXP$resid, 0.005, "cross-sectional residual"),
        chk_round(T1$water_adjusted_floor_trend_pp_yr, EXP$adj, 3, "water-adjusted floor trend"),
        chk(T1$reportable_sites, EXP$sites, 0, "reportable sites"))
if (!all(ok)) stop("T1 values DIFFER from the expected set - STOP and report, do not adjust.")
write.csv(T1, file.path(TABD, "T1_conserved_paddock_comparison.csv"), row.names = FALSE)
cat(sprintf("wrote %s/T1_conserved_paddock_comparison.csv (%d rows, no summary row)\n", TABD, nrow(T1)))

## --- T1 figure: a rendered table, cells coloured by part state -------------------------------
# NB: `if`, NOT `ifelse`. ifelse() returns a value the length of its TEST - `sign` is length 1,
# so ifelse() silently collapsed this to one element which sprintf then recycled across all four
# paddocks. The first draft rendered "45.3" in every column while the CSV was correct, and the
# value-level acceptance checks could not see it because they test the data frame, not the ink.
fmt <- function(x, d = 1, sign = FALSE)
  if (sign) sprintf(paste0("%+.", d, "f"), x) else sprintf(paste0("%.", d, "f"), x)
cellcol <- function(state) unname(PAL_STATE[sub(" .*", "", state)])

# Rank direction lives in the ROW LABEL, on the figure, beside the numbers it governs - two
# rank conventions in one table is a real misread risk, and a single note at the foot of a
# caption does not reach a reader scanning the columns.
FIELDS <- c("Community composition",
            "Mean annual flood %\n(rank 1 = wettest)",
            "Cover floor veg_p05\n(rank 1 = highest cover)",
            "Residual vs expectation\n(rank 1 = largest shortfall)",
            "Water-adjusted trend\n(rank 1 = steepest decline)",
            "Part states", "Reportable sites")
val <- list(
  T1$composition,
  sprintf("%s   (rank %d of 64)", fmt(T1$mean_flood_pct), T1$flood_rank_of_64),
  sprintf("%s   (rank %d of 64)", fmt(T1$veg_p05_spatial), T1$floor_rank_of_64),
  sprintf("%s pp   (rank %d of 64)", fmt(T1$cross_sectional_residual_pp, 2, TRUE), T1$residual_rank_of_64),
  sprintf("%s pp/yr   (rank %d of 64)", fmt(T1$water_adjusted_floor_trend_pp_yr, 3, TRUE), T1$adj_trend_rank_of_64),
  gsub(" · ", "\n", T1$part_states),
  as.character(T1$reportable_sites))

# POST-RENDER ASSERTIONS (I-32) on the strings actually drawn, not on T1. The value checks above
# passed while the figure rendered "45.3" in all four columns; only a check on the ink sees that.
names(val) <- FIELDS
gayini_assert_rendered_table(val, "T1 table")
gayini_assert_rendered_values(val[[2]], T1$mean_flood_pct, 1, FALSE, "T1 flood %")
gayini_assert_rendered_values(val[[3]], T1$veg_p05_spatial, 1, FALSE, "T1 cover floor")
gayini_assert_rendered_values(val[[4]], T1$cross_sectional_residual_pp, 2, TRUE, "T1 residual")
gayini_assert_rendered_values(val[[5]], T1$water_adjusted_floor_trend_pp_yr, 3, TRUE, "T1 adj trend")
gayini_assert_rendered_values(val[[7]], T1$reportable_sites, 0, FALSE, "T1 sites")
# the ranks are drawn too, and are just as recyclable
for (j in seq_len(4)) {
  rk <- c(T1$flood_rank_of_64[j], T1$floor_rank_of_64[j],
          T1$residual_rank_of_64[j], T1$adj_trend_rank_of_64[j])
  for (k in seq_len(4))
    if (!grepl(sprintf("rank %d of 64", rk[k]), val[[k + 1]][j], fixed = TRUE))
      stop(sprintf("T1 rank not rendered for %s (row %d)", T1$paddock[j], k + 1))
}
cat("  post-render assertions: 7 rows vary; values and ranks match the source  OK\n")

grid <- do.call(rbind, lapply(seq_along(FIELDS), function(i)
  data.frame(row = i, col = seq_len(4), field = FIELDS[i], txt = val[[i]], stringsAsFactors = FALSE)))
grid$hl <- grid$field == "Part states"

t1fig <- ggplot(grid, aes(col, -row)) +
  geom_tile(aes(fill = hl), colour = "grey80", linewidth = 0.4, width = 1, height = 1) +
  scale_fill_manual(values = c(`FALSE` = "white", `TRUE` = "#F4F1EA"), guide = "none") +
  geom_text(aes(label = txt), size = 2.9, lineheight = 1.05) +
  annotate("text", x = seq_len(4), y = 0, label = REF, fontface = "bold", size = 3.6) +
  annotate("text", x = 0.42, y = -seq_along(FIELDS), label = FIELDS,
           hjust = 1, fontface = "bold", size = 3.0) +
  coord_cartesian(xlim = c(-1.15, 4.6), ylim = c(-length(FIELDS) - 0.6, 0.5), clip = "off") +
  labs(title = "The four conserved paddocks are not alike",
       subtitle = "Every value read from a registered object. No average across the four is shown - averaging them is the mistake this table exists to prevent.") +
  theme_void(base_size = 10) +
  theme(plot.title = element_text(face = "bold", size = 13),
        plot.subtitle = element_text(size = 8.5, colour = "grey30"),
        plot.margin = margin(10, 12, 10, 12))

cap_t1 <- paste0(
  "Support level: pixel (whole-paddock values over 1988-2022, non-treed ground). ",
  "The four paddocks managed without grazing, side by side. They differ on every measure: ",
  "Bala 29ca is the driest paddock on the property and has the second-lowest cover of 64, while ",
  "Bala 26ca and 28ca are among the wettest and sit near the top for cover. ",
  "'Residual vs expectation' is how far a paddock's cover sits above or below what its own water ",
  "would predict, from the 64-paddock line; rank 1 is the largest shortfall. ",
  "'Water-adjusted trend' is the change in cover once the paddock's own wetting or drying is ",
  "removed; rank 1 is the steepest decline, so a high rank means a rising trend. ",
  "Ranks for flood and cover are 1 = wettest and 1 = highest cover. ",
  "'Part states' splits each paddock by vegetation community, because a fence line does not follow ",
  "vegetation; 'not asserted' marks a part too close to a boundary to call. ",
  "Reportable sites are the non-treed monitoring plots inside the paddock. ",
  "Cover is how much and how green, not a condition score, and no cause is attributed.")

gayini_write_and_register_figure(
  plot = t1fig, path = file.path(FIGD, "T1_conserved_paddock_comparison.png"),
  title = "T1 - the four conserved paddocks side by side",
  caption = cap_t1, support_level = "pixel", figure_level = "headline", run_id = RUN,
  domain = "zone_diagnostics", framing_label = "census_8058",
  provenance_note = "v_zone_floor_flood_residual, v_zone_community_composition, fact_zone_community_part_classification, T10_gateC_temporal_table.csv, plot_paddock",
  width = 14, height = 7, dpi = 200)

## ============================================================ F3 — the annual gap series
G <- read.csv("Output/tables/T10_annual_gap_series.csv", stringsAsFactors = FALSE) %>%
  filter(series_variant == "mean_of_seasons")
S <- read.csv("Output/tables/T10_trend_statistics.csv", stringsAsFactors = FALSE) %>%
  filter(series_variant == "mean_of_seasons")
stopifnot(nrow(G) == 105, all(table(G$series) == 35))
expS <- c(A_all4 = 0.273, B_excl29ca = 0.057, C_29ca = 0.919)
expR <- c(A_all4 = 0.770, B_excl29ca = 0.222, C_29ca = 0.846)
for (s in names(expS)) {
  gs <- S$slope_pp_per_yr[S$series == s]; gr <- S$r[S$series == s]
  cat(sprintf("F3 %-11s slope %+.4f (expect %+.3f)  r %.4f (expect %.3f)  %s\n", s, gs, expS[[s]],
              gr, expR[[s]], if (abs(gs - expS[[s]]) <= 0.0005 && abs(gr - expR[[s]]) <= 0.0005) "OK" else "*** DIFFER ***"))
  if (abs(gs - expS[[s]]) > 0.0005 || abs(gr - expR[[s]]) > 0.0005)
    stop("F3 trend statistics DIFFER - STOP and report.")
}
LAB <- c(A_all4 = "All four conserved paddocks",
         B_excl29ca = "The three others (Bala 29ca removed)",
         C_29ca = "Bala 29ca on its own")
COLS <- c(A_all4 = "#4A4A4A", B_excl29ca = "#2E7D32", C_29ca = "#B2182B")
G$lab <- LAB[G$series]
ann <- data.frame(series = names(LAB), lab = unname(LAB),
                  slope = S$slope_pp_per_yr[match(names(LAB), S$series)],
                  r = S$r[match(names(LAB), S$series)])
ann$txt <- sprintf("%+.3f pp per year  (r %.2f)", ann$slope, ann$r)

f3 <- ggplot(G, aes(water_year, gap_pp, colour = series)) +
  geom_hline(yintercept = 0, colour = "grey55", linewidth = 0.4) +
  geom_line(linewidth = 0.45, alpha = 0.65) +
  geom_point(size = 1.2, alpha = 0.8) +
  geom_smooth(method = "lm", se = FALSE, linewidth = 1.0, formula = y ~ x) +
  # Labels go in the empty lower-right block (x > 2004, y < -38 holds no data), not beside the
  # lines - the first draft put them on top of the green line and the 2022 red points.
  geom_text(data = ann, aes(x = 2004, y = c(-41, -46, -51), label = paste0(lab, ":  ", txt),
                            colour = series),
            hjust = 0, size = 3.1, fontface = "bold", inherit.aes = FALSE, show.legend = FALSE) +
  scale_colour_manual(values = COLS, labels = LAB, name = NULL) +
  labs(title = "Is conserved country pulling away from grazed country?",
       subtitle = "The gap in cover floor between conserved and grazed paddocks, each water year. Above zero = conserved is higher.",
       x = "Water year", y = "Gap in cover floor (percentage points)") +
  theme_minimal(base_size = 10) +
  theme(legend.position = "bottom",
        plot.title = element_text(face = "bold", size = 13),
        plot.subtitle = element_text(size = 9, colour = "grey30"))

cap_f3 <- paste0(
  "Support level: zone (paddock), 35 water years, non-treed ground. ",
  "Each point is one year's difference between the conserved paddocks' cover floor and the grazed ",
  "median; the straight line is the fitted trend. ",
  "Taking all four conserved paddocks together, the gap closes over the record. But once Bala 29ca ",
  "is removed the line is nearly flat - the other three conserved paddocks show no trend towards or ",
  "away from grazed country at all. Bala 29ca on its own accounts for the entire movement, and it ",
  "starts from far below every other paddock. ",
  "No p-values are shown: 35 consecutive years are not independent observations, so a p-value would ",
  "overstate the certainty. The gap closing is not evidence that grazing exclusion worked - the ",
  "convergence runs from 1988, about thirty years before conservation management began.")

gayini_write_and_register_figure(
  plot = f3, path = file.path(FIGD, "F3_annual_gap_series.png"),
  title = "F3 - annual conserved-grazed gap, all four / excluding Bala 29ca / Bala 29ca alone",
  caption = cap_f3, support_level = "zone", figure_level = "headline", run_id = RUN,
  domain = "zone_diagnostics", framing_label = "census_8058",
  provenance_note = "Output/tables/T10_annual_gap_series.csv + T10_trend_statistics.csv (T10 Gate B)",
  width = 11, height = 7, dpi = 200)

## ============================================================ F5 — cover against water
hn <- DBI::dbGetQuery(con, "SELECT number_id,pinned_value FROM dim_headline_number
                            WHERE number_id IN ('floor_flood_intercept_64pdk','floor_flood_slope_64pdk',
                                                'floor_flood_residual_sd_64pdk','floor_flood_r_64pdk')")
P <- setNames(hn$pinned_value, hn$number_id)
INT <- P[["floor_flood_intercept_64pdk"]]; SLP <- P[["floor_flood_slope_64pdk"]]
SD  <- P[["floor_flood_residual_sd_64pdk"]]; RR <- P[["floor_flood_r_64pdk"]]
cat(sprintf("F5 line READ from dim_headline_number: intercept %.4f  slope %.3f  residual SD %.4f  r %.2f\n",
            INT, SLP, SD, RR))
# repinned at 6 dp 2026-07-31 (precision correction; the fitted value did not change).
# These guards caught this script still expecting the rounded pair - which is what they are for.
stopifnot(abs(INT - 52.652934) < 1e-6, abs(SLP - 0.547838) < 1e-6, abs(SD - 6.6208) < 1e-4)

res$is_ref <- res$zone_name %in% REF
for (z in c("Bala 29ca", "Dinan 10")) {
  r <- res[res$zone_name == z, ]
  cat(sprintf("F5 %-10s residual %+.2f rank %d of 64\n", z, r$residual, r$resid_rank))
}
stopifnot(res$resid_rank[res$zone_name == "Bala 29ca"] == 2,
          res$resid_rank[res$zone_name == "Dinan 10"] == 3)

# Bala 29ca (8.5, 40.5) and Dinan 10 (5.1, 40.4) sit almost on top of each other, so the two
# labels collided in the first draft. Explicit per-point offsets, one up-right and one down-right.
lab <- res %>% filter(zone_name %in% c("Bala 29ca", "Dinan 10")) %>%
  mutate(lx = c(16, 16)[match(zone_name, c("Bala 29ca", "Dinan 10"))],
         ly = c(47.5, 32.5)[match(zone_name, c("Bala 29ca", "Dinan 10"))],
         calltxt = sprintf("%s - %.1f pp below expectation (rank %d of 64)",
                           zone_name, abs(residual), resid_rank))
# POST-RENDER assertion on the callouts actually drawn (I-32)
gayini_assert_rendered_varies(lab$calltxt, "F5 callouts")
gayini_assert_rendered_values(lab$calltxt, abs(lab$residual), 1, FALSE, "F5 callout residual")
for (i in seq_len(nrow(lab)))
  if (!grepl(sprintf("rank %d of 64", lab$resid_rank[i]), lab$calltxt[i], fixed = TRUE))
    stop("F5 callout rank not rendered for ", lab$zone_name[i])
cat("F5 post-render assertions: callouts carry their residual and rank  OK
")
xr  <- range(res$mean_flood); band <- data.frame(x = seq(xr[1], xr[2], length.out = 100))
band$y <- INT + SLP * band$x; band$lo <- band$y - SD; band$hi <- band$y + SD

f5 <- ggplot(res, aes(mean_flood, mean_floor)) +
  geom_ribbon(data = band, aes(x = x, ymin = lo, ymax = hi), inherit.aes = FALSE,
              fill = "grey60", alpha = 0.22) +
  geom_line(data = band, aes(x, y), inherit.aes = FALSE, colour = COL_LINE, linewidth = 0.9) +
  geom_point(aes(fill = is_ref, size = is_ref), shape = 21, colour = "grey25", stroke = 0.35) +
  scale_fill_manual(values = c(`FALSE` = COL_GRAZED, `TRUE` = COL_REF),
                    labels = c("Grazed (60)", "Conserved (4)"), name = NULL) +
  scale_size_manual(values = c(`FALSE` = 2.3, `TRUE` = 3.6), guide = "none") +
  geom_segment(data = lab, aes(x = mean_flood, xend = lx - 0.6, y = mean_floor, yend = ly),
               colour = "grey45", linewidth = 0.3) +
  geom_text(data = lab, aes(x = lx, y = ly, label = calltxt),
            hjust = 0, size = 3.0, colour = "grey15") +
  labs(title = "Cover follows water, and the exceptions are the story",
       subtitle = sprintf("One point per paddock. Line = the registered expectation (%.1f + %.3f x flood %%). Shaded band = plus or minus one typical miss (%.1f pp).",
                          INT, SLP, SD),
       x = "Mean annual flood frequency (% of years wet)",
       y = "Cover floor, veg_p05_spatial (%)") +
  theme_minimal(base_size = 10) +
  theme(legend.position = "bottom", plot.title = element_text(face = "bold", size = 13),
        plot.subtitle = element_text(size = 8.5, colour = "grey30"))

cap_f5 <- paste0(
  "Support level: pixel (whole-paddock means over 1988-2022, non-treed ground), 64 paddocks. ",
  "How much cover a paddock holds in its poorest seasons is largely set by how often it floods - ",
  "wetter paddocks sit higher. The green line is the expectation registered for the property, and ",
  "the shaded band is one typical miss either side, so a point inside the band is behaving normally ",
  "for its water. Two paddocks sit far below: Bala 29ca and Dinan 10 hold about 15 to 17 points ",
  "less cover than their water predicts, the second and third largest shortfalls of 64. ",
  "The line is read from the registered numbers and is not refitted here. ",
  "This says nothing about cause - a paddock can sit low for reasons the satellite cannot see, ",
  "and cover is how much and how green, not a condition score.")

gayini_write_and_register_figure(
  plot = f5, path = file.path(FIGD, "F5_cover_vs_water_64_paddocks.png"),
  title = "F5 - paddock cover floor against flood frequency, 64 paddocks, registered expectation line",
  caption = cap_f5, support_level = "pixel", figure_level = "headline", run_id = RUN,
  domain = "zone_diagnostics", framing_label = "census_8058",
  provenance_note = "v_zone_floor_flood_residual; line + band from dim_headline_number (floor_flood_* pinned rows), NOT refitted",
  width = 11, height = 7.5, dpi = 200)

cat("\nAll three built. Assembly only - nothing refitted; every acceptance value reproduced.\n")
