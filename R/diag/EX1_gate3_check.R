# EXEMPLAR-1 Gate 3 - check the design-seat findings in section 1 of the spec.
#
# THESE ARE PREDICTIONS, NOT FACTS. The spec says so: "CC's independently computed
# values take precedence wherever they disagree." So every one is written down as a
# target with a tolerance and the run reports agreement or divergence; nothing is tuned
# to match.
#
# Ruling AS: all estimation here. The parquet was prepared in Python and this file does
# every mean, bin and correlation.
#
# WHAT THIS IS NOT. These are the SEASONAL-basis temporal percentiles - 140 composites,
# MIN_SEASONS = 50 - not the annual-basis series the regression uses. TEMPORAL-1 is
# building the matched annual version and this does not duplicate it. The design-seat
# values were computed on these same shared rasters, so this is a like-for-like check.

source(file.path("R", "diag", "DIAG1_common.R"))


PQ <- file.path(DIAG_ANA, "EX1_gate3_census_cells.csv.gz")
stopifnot(file.exists(PQ))
d <- utils::read.csv(PQ, stringsAsFactors = FALSE)
stopifnot(nrow(d) == 988831L)

dg_say("=== EXEMPLAR-1 Gate 3 - the design-seat findings, checked ===")
dg_say("  %s cells, seasonal-basis temporal percentiles (140 composites, MIN_SEASONS = 50)",
       format(nrow(d), big.mark = ","))

ok <- stats::complete.cases(d[, c("flood_freq_pct", "temporal_p05", "temporal_p50")])
dg_say("  usable cells %s (dropped %d with no percentile - Ruling BT)",
       format(sum(ok), big.mark = ","), sum(!ok))
d <- d[ok, ]

# ---------------------------------------------------- whole-census correlations ----
r05 <- stats::cor(d$temporal_p05, d$flood_freq_pct)
r50 <- stats::cor(d$temporal_p50, d$flood_freq_pct)
dg_say("")
dg_say("-- whole-census correlations --")
dg_check("r_floor_vs_water", "r, per-cell temporal p05 against flood frequency",
         0.676, r05, 5e-3, note = "1")
dg_check("r_median_vs_water", "r, per-cell temporal p50 against flood frequency",
         0.566, r50, 5e-3, note = "1")
dg_say("  r(p05, flood freq) %.4f   target 0.676", r05)
dg_say("  r(p50, flood freq) %.4f   target 0.566", r50)

# ------------------------------------------------------- by community and bin ----
# Two binnings are computed because the spec does not state which produces its
# endpoints, and the choice changes them. Fixed 10-point bins are reported as the
# primary; deciles are reported beside them so the reading does not rest on one rule.
d$bin_fixed <- cut(d$flood_freq_pct, breaks = seq(0, 100, 10), include.lowest = TRUE,
                   right = FALSE)
d$bin_decile <- dplyr_ntile <- as.integer(cut(
  d$flood_freq_pct,
  breaks = stats::quantile(d$flood_freq_pct, probs = seq(0, 1, 0.1)),
  include.lowest = TRUE, labels = FALSE))

summ <- function(g, bincol) {
  s <- split(g, g[[bincol]])
  do.call(rbind, lapply(names(s), function(k) {
    x <- s[[k]]
    if (nrow(x) == 0) return(NULL)
    data.frame(community = x$community[1], bin = k, n_cells = nrow(x),
               flood_freq_mean = mean(x$flood_freq_pct),
               mean_p05 = mean(x$temporal_p05), mean_p50 = mean(x$temporal_p50),
               gap_p50_minus_p05 = mean(x$temporal_p50) - mean(x$temporal_p05),
               stringsAsFactors = FALSE)
  }))
}

rows <- list()
for (cm in sort(unique(d$community))) {
  g <- d[d$community == cm, ]
  for (b in c("bin_fixed", "bin_decile")) {
    s <- summ(g, b)
    if (is.null(s)) next
    s$binning <- if (b == "bin_fixed") "fixed 10-point bins" else "deciles of flood frequency"
    rows[[length(rows) + 1L]] <- s
  }
}
TB <- do.call(rbind, rows)

dg_say("")
dg_say("-- mean per-cell percentiles by community, fixed 10-point bins --")
for (cm in sort(unique(TB$community))) {
  s <- TB[TB$community == cm & TB$binning == "fixed 10-point bins", ]
  s <- s[order(s$flood_freq_mean), ]
  dg_say("  %s  (%d bins, %s cells)", cm, nrow(s),
         format(sum(s$n_cells), big.mark = ","))
  dg_say("    p05  %s", paste(sprintf("%.1f", s$mean_p05), collapse = " "))
  dg_say("    p50  %s", paste(sprintf("%.1f", s$mean_p50), collapse = " "))
  dg_say("    gap  %s", paste(sprintf("%.1f", s$gap_p50_minus_p05), collapse = " "))
  dg_say("    n    %s", paste(format(s$n_cells, big.mark = ","), collapse = " "))
  mono <- all(diff(s$mean_p05) > 0)
  dg_say("    p05 monotone rising across bins: %s", mono)
}

# ------------------------------------------------ the specific stated endpoints ----
# The spec does not state which binning produced its endpoints, and the choice moves
# them by several points. BOTH are checked against the same targets rather than one
# being picked to look better - a target that only agrees under a rule chosen after
# seeing the answer has not been reproduced.
for (bn in c("fixed 10-point bins", "deciles of flood frequency")) {
  tag <- if (bn == "fixed 10-point bins") "fixed" else "decile"
  inl <- TB[TB$community == "Inland Floodplain Shrublands / Swamps" & TB$binning == bn, ]
  inl <- inl[order(inl$flood_freq_mean), ]
  L <- nrow(inl)
  dg_check(sprintf("inland_p05_dry__%s", tag), "Inland mean p05, driest bin",
           37.9, inl$mean_p05[1], 0.5, note = "1")
  dg_check(sprintf("inland_p05_wet__%s", tag), "Inland mean p05, wettest bin",
           77.1, inl$mean_p05[L], 0.5, note = "1")
  dg_check(sprintf("inland_p50_dry__%s", tag), "Inland mean p50, driest bin",
           74.3, inl$mean_p50[1], 0.5, note = "1")
  dg_check(sprintf("inland_p50_wet__%s", tag), "Inland mean p50, wettest bin",
           88.7, inl$mean_p50[L], 0.5, note = "1")
  dg_check(sprintf("inland_gap_dry__%s", tag), "Inland gap, driest bin",
           36.4, inl$gap_p50_minus_p05[1], 0.5, note = "1")
  dg_check(sprintf("inland_gap_wet__%s", tag), "Inland gap, wettest bin",
           11.3, inl$gap_p50_minus_p05[L], 0.5, note = "1")
  dg_say("  Inland under %-26s p05 %.1f -> %.1f   p50 %.1f -> %.1f   gap %.1f -> %.1f",
         bn, inl$mean_p05[1], inl$mean_p05[L], inl$mean_p50[1], inl$mean_p50[L],
         inl$gap_p50_minus_p05[1], inl$gap_p50_minus_p05[L])
}
dg_say("  design-seat prediction              p05 37.9 -> 77.1   p50 74.3 -> 88.7   gap 36.4 -> 11.3")

# The DIRECTION and MAGNITUDE of the finding, which is what the client's step 3 rests
# on, and which does not depend on the binning rule at all.
for (bn in c("fixed 10-point bins", "deciles of flood frequency")) {
  inl <- TB[TB$community == "Inland Floodplain Shrublands / Swamps" & TB$binning == bn, ]
  inl <- inl[order(inl$flood_freq_mean), ]
  L <- nrow(inl)
  tag <- if (bn == "fixed 10-point bins") "fixed" else "decile"
  dg_check(sprintf("inland_p05_rises_more_than_p50__%s", tag),
           "Inland: the floor rises further than the median (the published finding)",
           1, as.numeric((inl$mean_p05[L] - inl$mean_p05[1]) >
                           (inl$mean_p50[L] - inl$mean_p50[1])), 0, note = "1")
  dg_check(sprintf("inland_gap_narrows__%s", tag),
           "Inland: the median-minus-floor gap narrows with water",
           1, as.numeric(inl$gap_p50_minus_p05[L] < inl$gap_p50_minus_p05[1]), 0,
           note = "1")
}

aeo <- TB[TB$community == "Aeolian Chenopod Shrublands" &
            TB$binning == "fixed 10-point bins", ]
aeo <- aeo[order(aeo$flood_freq_mean), ]
peak <- aeo$flood_freq_mean[which.max(aeo$mean_p05)]
n_above50 <- sum(d$flood_freq_pct > 50 & d$community == "Aeolian Chenopod Shrublands")
dg_say("")
dg_say("-- Aeolian, the non-monotone claim --")
dg_say("  p05 peaks in the bin centred at %.1f%% flood frequency (claim: about 35%%)", peak)
dg_say("  p05 monotone rising: %s", all(diff(aeo$mean_p05) > 0))
dg_check("aeolian_cells_above_50", "Aeolian cells above 50% flood frequency",
         511, n_above50, 0, note = "1")
dg_say("  Aeolian cells above 50%% flood frequency: %d   target 511", n_above50)

TB <- dg_stamp(TB, "pixel", "census cell (24.970268 m)", "1988-2022",
               "unweighted mean over cells",
               "PER-CELL TEMPORAL percentile means by community and flood-frequency bin - seasonal basis (140 composites), NOT the annual series the regression uses",
               "none", gayini_sha256_first50_file(PQ))
write.csv(TB, file.path(DIAG_OUT, "EX1_gate3_community_by_floodbin.csv"),
          row.names = FALSE, na = "")

d2 <- dg_write_checks(file.path(DIAG_OUT, "EX1_gate3_checks.csv"))
real <- d2[!d2$expected_to_disagree, ]
dg_say("")
dg_say("Gate 3 checks: %d of %d agree", sum(real$agrees), nrow(real))
for (j in which(!real$agrees))
  dg_say("  DIFFERS  %-28s target %9.4f  got %9.4f", real$check[j], real$target[j],
         real$got[j])
dg_say("[wrote] EX1_gate3_community_by_floodbin.csv (%d rows)", nrow(TB))
