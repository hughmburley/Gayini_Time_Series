# DIAG1_stageC.R - the annual series (spec section 4).
#
# WITHIN-1 already built most of this and reproduced 17 of 17 targets in R. The spec is
# explicit: do not re-derive those; READ them and CITE them. This script reads
# WITHIN1_reproduction_checks.csv and WITHIN1_fits.csv and carries their values
# forward. What it adds is what remains:
#
#   4.1  the distributed lag fitted properly, as the specification that REPLACES the
#        AR(1) error model rather than sitting beside it (Ruling AT)
#   4.2  is the across-year mean a fair summary of a part's own series?
#   4.3  lag 2 - where does the response stop?
#
# No management claim and no period comparison. This is an assumptions audit.

source(file.path("R", "diag", "DIAG1_common.R"))

CSV <- file.path(DIAG_ANA, "DIAG1_part_year.csv")
SHA <- gayini_sha256_first50_file(CSV)
D <- read.csv(CSV, stringsAsFactors = FALSE)
D <- D[order(D$part_id, D$water_year), ]

WEIGHTING <- "pixel-weighted by the part's cell count"
ESTIMAND <- "WITHIN-UNIT (part fixed effects; how a part's own floor moves with its own wetness)"

dg_say("=== DIAG-1 Stage C - the annual series ===")
dg_say("  source %s  %d part-years, %d parts, %d paddocks",
       basename(CSV), nrow(D), length(unique(D$part_id)), length(unique(D$zone_fid)))

# ============================================== carried from WITHIN-1, not refitted ====

W1C <- read.csv(file.path("Output", "tables", "WITHIN1_reproduction_checks.csv"),
                stringsAsFactors = FALSE)
W1F <- read.csv(file.path("Output", "tables", "WITHIN1_fits.csv"), stringsAsFactors = FALSE)
stopifnot(all(W1C$agrees))
dg_say("")
dg_say("-- carried from WITHIN-1 (%d of %d reproduced there; NOT recomputed here) --",
       sum(W1C$agrees), nrow(W1C))
carried <- W1C[W1C$check %in% c("ac1_floor", "ac1_resid_median", "ac1_water", "n_eff",
                                "lag_same_year", "lag_prev_year", "pooled_within_slope",
                                "med_aeolian", "med_riverine", "med_inland"), ]
for (j in seq_len(nrow(carried)))
  dg_say("  %-42s %.4f", carried$what[j], carried$got[j])

CARRIED <- data.frame(
  row_type = "carried_from_WITHIN1", quantity = carried$what, value = carried$got,
  lag = NA_integer_, scope = "as recorded by WITHIN-1", n_obs = NA_integer_,
  n_units = NA_integer_,
  source = "Output/tables/WITHIN1_reproduction_checks.csv via scripts/12_zone_stratum/WITHIN1_reproduce.R",
  stringsAsFactors = FALSE)

# ================================================== 4.1 / 4.3 the distributed lag ====
# Ruling AT established that the persistence in the cover series is a lagged ecological
# response and not error correlation. The AR(1) model ABSORBS that persistence into the
# error term; the distributed lag PUTS IT IN THE SPECIFICATION, where it can be read.
# The two are alternatives, and this is the one that answers the question.

lagmat <- function(d, max_lag) {
  s <- split(seq_len(nrow(d)), d$part_id)
  keep <- logical(nrow(d))
  L <- matrix(NA_real_, nrow(d), max_lag + 1L)
  for (i in s) {
    yr <- d$water_year[i]
    stopifnot(!is.unsorted(yr))
    for (k in 0:max_lag) {
      m <- match(yr - k, yr)
      L[i, k + 1L] <- d$inund_pct[i][m]
    }
    keep[i] <- stats::complete.cases(L[i, , drop = FALSE])
  }
  list(L = L, keep = keep)
}

#' Within (part fixed effects) fit of y on several lagged x columns, pixel-weighted,
#' with a clustered bootstrap on the paddock. Every column is demeaned within the part.
within_lag_fit <- function(d, L, scope, n_boot = 2000L, seed = 20260807L) {
  w <- d$n_pixels_part
  dm <- function(v, unit, w) { o <- v; for (i in split(seq_along(v), unit))
    o[i] <- v[i] - sum(w[i] * v[i]) / sum(w[i]); o }
  yd <- dm(d$veg_p05_spatial, d$part_id, w)
  Xd <- apply(L, 2, dm, unit = d$part_id, w = w)
  f <- dg_wls(cbind(1, Xd), yd, w)
  co <- f$coef[-1]

  boot_sum <- rep(NA_real_, 3)
  if (n_boot > 0) {
    set.seed(seed)
    cl <- split(seq_len(nrow(d)), d$zone_fid); keys <- names(cl)
    acc <- numeric(0)
    for (b in seq_len(n_boot)) {
      pick <- sample(keys, length(keys), replace = TRUE)
      idx <- unlist(cl[pick], use.names = FALSE)
      # Resampling paddocks DUPLICATES parts. The fixed effect must be re-formed on the
      # draw's own unit labels: if two copies of one part shared a single mean, the
      # within transform would remove variation the draw is supposed to contain.
      un <- paste(d$part_id[idx], rep(seq_along(pick), lengths(cl[pick])), sep = "#")
      dd <- d[idx, ]; ww <- dd$n_pixels_part
      yb <- dm(dd$veg_p05_spatial, un, ww)
      Xb <- apply(L[idx, , drop = FALSE], 2, dm, unit = un, w = ww)
      acc <- c(acc, sum(dg_wls(cbind(1, Xb), yb, ww)$coef[-1]))
    }
    boot_sum <- unname(stats::quantile(acc, c(0.025, 0.5, 0.975)))
  }

  data.frame(
    row_type = "distributed_lag", scope = scope, max_lag = ncol(L) - 1L,
    n_obs = nrow(d), n_units = length(unique(d$part_id)),
    n_clusters = length(unique(d$zone_fid)),
    lag0 = co[1], lag1 = if (length(co) > 1) co[2] else NA_real_,
    lag2 = if (length(co) > 2) co[3] else NA_real_,
    long_run_sum = sum(co), r2 = f$r2, resid_sd = f$resid_sd,
    boot_sum_p2_5 = boot_sum[1], boot_sum_p50 = boot_sum[2], boot_sum_p97_5 = boot_sum[3],
    stringsAsFactors = FALSE)
}

dg_say("")
dg_say("-- 4.1 / 4.3 the distributed lag, within parts, pixel-weighted --")

lag_rows <- list()
for (ml in 1:2) {
  lm_ <- lagmat(D, ml)
  for (sc in c("pooled", "aeolian", "riverine", "inland")) {
    k <- lm_$keep & (if (sc == "pooled") TRUE else D$community_short == sc)
    r <- within_lag_fit(D[k, ], lm_$L[k, , drop = FALSE], sc,
                        n_boot = if (sc == "pooled") 2000L else 500L)
    lag_rows[[length(lag_rows) + 1L]] <- r
    dg_say("  max lag %d  %-9s n=%4d  lag0 %+.4f  lag1 %+.4f  lag2 %s  long-run %+.4f",
           ml, sc, r$n_obs, r$lag0, r$lag1,
           if (is.na(r$lag2)) "     -" else sprintf("%+.4f", r$lag2), r$long_run_sum)
  }
}
LG <- do.call(rbind, lag_rows)
p1 <- LG[LG$max_lag == 1 & LG$scope == "pooled", ]
dg_check("lag_same_year", "same-year within slope with lagged water added", 0.1379, p1$lag0, 2e-3, note = "4.1")
dg_check("lag_prev_year", "previous-year within slope", 0.1178, p1$lag1, 2e-3, note = "4.1")
dg_check("long_run_sum", "long-run sum of the distributed lag", 0.2557, p1$long_run_sum, 2e-3, note = "4.1")

# where does the response stop? the lag-2 term against the lag-1 term
p2 <- LG[LG$max_lag == 2 & LG$scope == "pooled", ]
dg_say("  lag 2 pooled: lag0 %+.4f  lag1 %+.4f  lag2 %+.4f   long-run %+.4f",
       p2$lag0, p2$lag1, p2$lag2, p2$long_run_sum)
dg_say("  lag2 is %.0f%% of lag1 and %.0f%% of lag0",
       100 * p2$lag2 / p2$lag1, 100 * p2$lag2 / p2$lag0)

LG <- dg_stamp(LG, "pixel", "part-year", "1988-2022", WEIGHTING, ESTIMAND,
               "zone_fid (paddock), for the bootstrap", SHA)
LG$interval_conditionality <- paste(
  "CONDITIONAL ON THE INPUTS BEING CORRECT (Ruling AW). Sampling variation only; the",
  "fractional-cover and open-water products' own validation error is not propagated.")
LG$interval_status <- "R-side stability check - NOT registered, and not proposed for registration"
write.csv(LG, file.path(DIAG_OUT, "DIAG1_lag_fits.csv"), row.names = FALSE, na = "")

# ============================================ 4.2 is the mean a fair summary? ====
# The between-unit fit uses each part's MEAN. A part whose mean misrepresents its own
# 35 values is a part whose POSITION ON FIGURE 25 is misleading - not a part with a
# wrong number, which is why this belongs in an assumptions audit rather than a QA log.

dg_say("")
dg_say("-- 4.2 skew of each part's own series, and mean against median --")

sk <- function(v) { n <- length(v); m <- mean(v); s <- sqrt(sum((v - m)^2) / n)
  if (s == 0) return(NA_real_); sum((v - m)^3) / (n * s^3) }

s <- split(seq_len(nrow(D)), D$part_id)
SER <- do.call(rbind, lapply(names(s), function(pid) {
  i <- s[[pid]]; v <- D$veg_p05_spatial[i]; x <- D$inund_pct[i]
  data.frame(part_id = pid, zone_fid = D$zone_fid[i][1], zone_name = D$zone_name[i][1],
             community_short = D$community_short[i][1], n_pixels_part = D$n_pixels_part[i][1],
             n_years = length(v),
             floor_mean = mean(v), floor_median = stats::median(v),
             floor_mean_minus_median = mean(v) - stats::median(v),
             floor_skew_g1 = sk(v), floor_sd = stats::sd(v),
             floor_min = min(v), floor_max = max(v),
             water_mean = mean(x), water_median = stats::median(x), water_skew_g1 = sk(x),
             stringsAsFactors = FALSE)
}))
SER$abs_mean_minus_median <- abs(SER$floor_mean_minus_median)
SER <- SER[order(-SER$abs_mean_minus_median), ]
dg_say("  |mean - median| over 115 parts: median %.2f pp, 90th pct %.2f pp, max %.2f pp",
       stats::median(SER$abs_mean_minus_median),
       stats::quantile(SER$abs_mean_minus_median, 0.9), max(SER$abs_mean_minus_median))
dg_say("  skew: %d of 115 parts |g1| > 1;  %d parts left-skewed (g1 < -0.5)",
       sum(abs(SER$floor_skew_g1) > 1), sum(SER$floor_skew_g1 < -0.5))
dg_say("  largest divergences:")
for (j in 1:6) dg_say("    %-14s %-9s mean %5.2f  median %5.2f  %+5.2f pp  skew %+5.2f",
                      SER$zone_name[j], SER$community_short[j], SER$floor_mean[j],
                      SER$floor_median[j], SER$floor_mean_minus_median[j], SER$floor_skew_g1[j])

# does a part whose mean misrepresents its series move on Figure 25? Compare the
# between-unit residual computed from the mean with one computed from the median.
BP <- read.csv(file.path(DIAG_ANA, "DIAG1_between_parts.csv"), stringsAsFactors = FALSE)
BP <- BP[BP$period == "whole_record", ]
m <- match(BP$part_id, SER$part_id)
f <- dg_wls(cbind(1, BP$inund_mean), BP$floor_mean, BP$n_pixels_part)
f_med <- dg_wls(cbind(1, SER$water_median[m]), SER$floor_median[m], BP$n_pixels_part)
# Swapping both axes at once conflates two changes, so decompose: which axis moves it?
f_ymed <- dg_wls(cbind(1, BP$inund_mean), SER$floor_median[m], BP$n_pixels_part)
f_xmed <- dg_wls(cbind(1, SER$water_median[m]), BP$floor_mean, BP$n_pixels_part)
SER$between_residual_from_mean <- NA_real_; SER$between_residual_from_median <- NA_real_
SER$between_residual_from_mean[m] <- f$resid
SER$between_residual_from_median[m] <- f_med$resid
SER$residual_shift_median_vs_mean <- SER$between_residual_from_median - SER$between_residual_from_mean
dg_say("  slope, both axes on means            %.4f   (the published fit)", f$coef[2])
dg_say("  slope, median FLOOR on mean water    %.4f   (%+.4f)", f_ymed$coef[2], f_ymed$coef[2] - f$coef[2])
dg_say("  slope, mean floor on MEDIAN water    %.4f   (%+.4f)", f_xmed$coef[2], f_xmed$coef[2] - f$coef[2])
dg_say("  slope, both axes on medians          %.4f   (%+.4f)", f_med$coef[2], f_med$coef[2] - f$coef[2])
dg_say("  residual rank Spearman, mean vs median fit %.4f", stats::cor(f$resid, f_med$resid, method = "spearman"))
SUMM <- data.frame(
  variant = c("both axes mean (published)", "median floor, mean water",
              "mean floor, median water", "both axes median"),
  slope = c(f$coef[2], f_ymed$coef[2], f_xmed$coef[2], f_med$coef[2]),
  intercept = c(f$coef[1], f_ymed$coef[1], f_xmed$coef[1], f_med$coef[1]),
  r2 = c(f$r2, f_ymed$r2, f_xmed$r2, f_med$r2),
  resid_sd = c(f$resid_sd, f_ymed$resid_sd, f_xmed$resid_sd, f_med$resid_sd),
  spearman_resid_vs_published = c(1, stats::cor(f$resid, f_ymed$resid, method = "spearman"),
                                  stats::cor(f$resid, f_xmed$resid, method = "spearman"),
                                  stats::cor(f$resid, f_med$resid, method = "spearman")),
  stringsAsFactors = FALSE)
SUMM <- dg_stamp(SUMM, "pixel", "part (paddock x community)", "1988-2022", WEIGHTING,
                 "BETWEEN-UNIT sensitivity to the central-tendency summary - DIAGNOSTIC ONLY, replaces no published number",
                 "zone_fid (paddock)", SHA)
write.csv(SUMM, file.path(DIAG_OUT, "DIAG1_mean_vs_median_summary.csv"), row.names = FALSE, na = "")

SER <- dg_stamp(SER, "pixel", "part (35 annual values per part)", "1988-2022", WEIGHTING,
                "SERIES SUMMARY - describes each part's own annual series; not an estimate of anything across parts",
                "zone_fid (paddock)", SHA)
write.csv(SER, file.path(DIAG_OUT, "DIAG1_part_series_summary.csv"), row.names = FALSE, na = "")

CARRIED <- dg_stamp(CARRIED, "pixel", "part-year", "1988-2022", WEIGHTING, ESTIMAND,
                    "zone_fid (paddock)", SHA)
write.csv(CARRIED, file.path(DIAG_OUT, "DIAG1_carried_from_WITHIN1.csv"), row.names = FALSE, na = "")

d <- dg_write_checks(file.path(DIAG_OUT, "DIAG1_reproduction_checks_stageC.csv"))
real <- d[!d$expected_to_disagree, ]
dg_say("")
dg_say("Stage C checks: %d of %d agree", sum(real$agrees), nrow(real))
if (any(!real$agrees)) for (j in which(!real$agrees))
  dg_say("  DIFFERS %-38s target %9.6f  got %9.6f", real$check[j], real$target[j], real$got[j])
