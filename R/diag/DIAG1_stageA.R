# DIAG1_stageA.R - between-unit diagnostics (spec section 2).
#
# Diagnoses the fit behind Figure 25 and the three residual maps: across-year mean
# floor against across-year mean wetness, 115 parts, pixel-weighted, clustered on the
# paddock, in each of three periods.
#
# ORDER MATTERS AND IS THE SPEC'S. Reproduce first (2.1) and halt if it fails, because
# everything after it would be diagnosing a different model. Then heteroscedasticity
# (2.3), influence (2.4), functional form (2.5), and the form sensitivity that must
# reach the article (2.6).
#
# This task registers nothing, proposes nothing, and refits nothing into production.

source(file.path("R", "diag", "DIAG1_common.R"))

dir.create(DIAG_FIG, recursive = TRUE, showWarnings = FALSE)

CSV <- file.path(DIAG_ANA, "DIAG1_between_parts.csv")
SHA <- gayini_sha256_first50_file(CSV)
D <- read.csv(CSV, stringsAsFactors = FALSE)

WEIGHTING <- "pixel-weighted by the part's cell count"
ESTIMAND <- "BETWEEN-UNIT (across parts)"
CLUSTER <- "zone_fid (paddock)"

per <- function(p) D[D$period == p, , drop = FALSE]
PERIODS <- c("whole_record", "cropping_era", "post_management")
PLABEL <- c(whole_record = "1988-2022", cropping_era = "1988-2013",
            post_management = "2018-2022")

dg_say("=== DIAG-1 Stage A - between-unit diagnostics ===")
dg_say("  source %s", basename(CSV))
dg_say("  sha256_first50 %s", SHA)

# ================================================================ 2.1 reproduce ====
# The halt condition. Refit in R through the shared gayini_fit() and check against the
# coefficients that shipped.

dg_say("")
dg_say("-- 2.1 reproduce before diagnosing (HALT CONDITION) --")

fit_period <- function(p, weighted = TRUE) {
  d <- per(p)
  gayini_fit(CSV, y = "floor_mean", x = "inund_mean",
             weights = if (weighted) "n_pixels_part" else NULL,
             cluster = NULL, n_boot = 0L,
             subset = D$period == p,
             label = sprintf("DIAG-1 2.1 %s %s", p, if (weighted) "weighted" else "unweighted"))
}

f_whole <- fit_period("whole_record")
f_whole_unw <- fit_period("whole_record", weighted = FALSE)
f_crop <- fit_period("cropping_era")
f_post <- fit_period("post_management")

dg_check("S2_whole_full115__slope", "whole-record slope, pixel-weighted",
         0.547274, f_whole$slope, 5e-6, halt = TRUE, note = "2.1")
dg_check("S2_whole_full115__intercept", "whole-record intercept, pixel-weighted",
         52.697196, f_whole$intercept, 5e-6, halt = TRUE, note = "2.1")
dg_check("S2_whole_record_common_unweighted__slope", "whole-record slope, unweighted",
         0.521378, f_whole_unw$slope, 5e-6, halt = TRUE, note = "2.1")
dg_check("S2_whole_record_common_unweighted__intercept", "whole-record intercept, unweighted",
         53.956357, f_whole_unw$intercept, 5e-6, halt = TRUE, note = "2.1")
dg_check("S2_cropping_era_common__slope", "cropping-era slope, pixel-weighted",
         0.592241, f_crop$slope, 5e-6, halt = TRUE, note = "2.1")
dg_check("S2_post_management_common__slope", "post-management slope, pixel-weighted",
         0.324225, f_post$slope, 5e-6, halt = TRUE, note = "2.1")

for (r in dg_checks$rows) with(r, dg_say("  %-46s target %11.6f  got %11.6f  %s",
                                         check, target, got, if (agrees) "AGREES" else "DIFFERS"))

# The published residuals themselves, not only the coefficients: a residual is what
# the maps print, so check the shipped column rather than trusting that it was made
# from the shipped coefficients.
for (p in PERIODS) {
  d <- per(p)
  f <- dg_wls(cbind(1, d$inund_mean), d$floor_mean, d$n_pixels_part)
  dg_check(sprintf("published_residual_max_abs_diff__%s", p),
           sprintf("largest |refit residual - published residual|, %s", p),
           0, max(abs(f$resid - d$published_residual)), 5e-5, halt = TRUE, note = "2.1")
  dg_say("  %-46s max |refit - published| = %.2e", sprintf("residuals %s", p),
         max(abs(f$resid - d$published_residual)))
}

# ---- show the check able to fail -------------------------------------------------
# Spec 2.1: "Perturb one weight in a scratch copy and confirm the assertion fires."
# A check that has never failed has not been tested; it has only been run. The failure
# text is captured and written out, because Ruling J's distinction is that a check
# that ERRORS is not a check that CATCHES - so the fixture must move the VALUE, and
# the recorded message must show the value it moved to.

dg_say("")
dg_say("-- 2.1 fixture: the reproduction check, shown able to fail --")
scratch <- file.path(tempdir(), "DIAG1_between_parts_PERTURBED.csv")
Dp <- D
i <- which(Dp$period == "whole_record" & Dp$paddock_name == "Bala 29ca" &
             Dp$community_short == "aeolian")
stopifnot(length(i) == 1L)
w_before <- Dp$n_pixels_part[i]
Dp$n_pixels_part[i] <- w_before * 2  # one weight, doubled - the data is untouched
write.csv(Dp, scratch, row.names = FALSE)

fixture <- tryCatch({
  fp <- gayini_fit(scratch, y = "floor_mean", x = "inund_mean", weights = "n_pixels_part",
                   cluster = NULL, n_boot = 0L, subset = Dp$period == "whole_record",
                   label = "fixture")
  dg_check("FIXTURE_perturbed_weight", "reproduction check against a doubled weight",
           0.547274, fp$slope, 5e-6, halt = TRUE, note = "2.1 fixture", fixture = TRUE)
  list(fired = FALSE, slope = fp$slope, msg = "NO ERROR - THE CHECK DID NOT FIRE")
}, error = function(e) {
  fp <- gayini_fit(scratch, y = "floor_mean", x = "inund_mean", weights = "n_pixels_part",
                   cluster = NULL, n_boot = 0L, subset = Dp$period == "whole_record")
  list(fired = TRUE, slope = fp$slope, msg = conditionMessage(e))
})
dg_checks$rows[[length(dg_checks$rows)]]$halt_condition <- FALSE  # the fixture is not a halt
dg_say("  weight on Bala 29ca / Aeolian: %d -> %d", w_before, w_before * 2L)
dg_say("  slope moves 0.547274 -> %.6f (%+.6f)", fixture$slope, fixture$slope - 0.547274)
dg_say("  check fired: %s", fixture$fired)
dg_say("  message: %s", gsub("\n", " | ", fixture$msg))
stopifnot(fixture$fired)
writeLines(c("DIAG-1 section 2.1 fixture - the reproduction check shown able to fail",
             "",
             sprintf("Perturbation: n_pixels_part on the Bala 29ca / Aeolian part, whole record, %d -> %d.",
                     w_before, w_before * 2L),
             "No y or x value was altered. Only one weight moved.",
             "",
             sprintf("Slope under the perturbation: %.6f (target 0.547274, moved %+.6f).",
                     fixture$slope, fixture$slope - 0.547274),
             sprintf("Tolerance: 5e-06. The move is %.0fx the tolerance.",
                     abs(fixture$slope - 0.547274) / 5e-6),
             "",
             "The check FIRED. Verbatim failure:",
             fixture$msg,
             "",
             paste("This is a value-level fixture, not a crash. The code path did not break;",
                   "it returned a WRONG NUMBER and the assertion rejected it. Ruling J: a check",
                   "that errors is not a check that catches.")),
           file.path(DIAG_OUT, "DIAG1_fixture_2_1.txt"))

# ============================================ 2.2 / 2.3 pointwise and local scale ====

dg_say("")
dg_say("-- 2.2 pointwise diagnostics, per period; 2.3 heteroscedasticity --")

pointwise <- list()
quart_rows <- list()

for (p in PERIODS) {
  d <- per(p)
  f <- dg_wls(cbind(1, d$inund_mean), d$floor_mean, d$n_pixels_part)
  del <- dg_deleted_residuals(DG_FORMS$linear, d$inund_mean, d$floor_mean,
                              d$n_pixels_part, d$zone_fid)

  # water quartiles, type-7 breaks on the period's own x, unweighted counts.
  # SAMPLE SD (n-1) within each bin: that divisor reproduces the four registered
  # values exactly, and the POPULATION SD reproduces their registered spread_min
  # exactly - so the registered spread on those four numbers is the divisor choice
  # and nothing else. Recorded here because it is the kind of thing that otherwise
  # gets rediscovered as a discrepancy.
  br <- stats::quantile(d$inund_mean, c(0, .25, .5, .75, 1))
  qtl <- cut(d$inund_mean, br, include.lowest = TRUE, labels = FALSE)
  sd_smp <- tapply(f$resid, qtl, stats::sd)
  sd_pop <- tapply(f$resid, qtl, function(v) sqrt(mean((v - mean(v))^2)))

  for (k in 1:4) quart_rows[[length(quart_rows) + 1L]] <- data.frame(
    scope = "all communities", period = p, water_quartile = k,
    n_parts = sum(qtl == k), x_lower = br[[k]], x_upper = br[[k + 1L]],
    residual_sd_sample = sd_smp[[k]], residual_sd_population = sd_pop[[k]],
    number_id = if (p == "whole_record") sprintf("cap_residual_sd_water_quartile_%d", k) else NA_character_,
    stringsAsFactors = FALSE)

  # the same split within each community, per 2.3
  for (cm in c("aeolian", "riverine", "inland")) {
    kk <- d$community_short == cm
    if (sum(kk) < 8) next
    brc <- stats::quantile(d$inund_mean[kk], c(0, .25, .5, .75, 1))
    qc <- cut(d$inund_mean[kk], brc, include.lowest = TRUE, labels = FALSE)
    sc <- tapply(f$resid[kk], qc, stats::sd)
    for (k in seq_along(sc)) quart_rows[[length(quart_rows) + 1L]] <- data.frame(
      scope = cm, period = p, water_quartile = as.integer(names(sc)[k]),
      n_parts = sum(qc == as.integer(names(sc)[k])),
      x_lower = brc[[k]], x_upper = brc[[k + 1L]],
      residual_sd_sample = sc[[k]], residual_sd_population = NA_real_,
      number_id = NA_character_, stringsAsFactors = FALSE)
  }

  local_sd <- as.numeric(sd_smp[qtl])
  pointwise[[p]] <- data.frame(
    part_id = d$part_id, zone_fid = d$zone_fid, paddock_name = d$paddock_name,
    community_short = d$community_short, conserved = d$conserved,
    n_pixels_part = d$n_pixels_part, period = p, period_label = PLABEL[[p]],
    x_inund_mean = d$inund_mean, y_floor_mean = d$floor_mean,
    fitted = f$fitted, residual = f$resid, published_residual = d$published_residual,
    hat_leverage = f$hat, std_residual = f$std_resid,
    sqrt_abs_std_residual = sqrt(abs(f$std_resid)),
    residual_obs_deleted = del$obs_deleted,
    residual_cluster_deleted = del$cluster_deleted,
    water_quartile = qtl, local_residual_sd = local_sd,
    residual_z_local = f$resid / local_sd,
    stringsAsFactors = FALSE)

  dg_say("  %-16s n=%3d  slope %.6f  R2 %.4f  resid SD %.3f  quartile SDs %s",
         p, nrow(d), f$coef[2], f$r2, f$resid_sd,
         paste(sprintf("%.3f", sd_smp), collapse = " "))
}

PW <- do.call(rbind, pointwise)
PW <- dg_stamp(PW, "pixel", "part (paddock x community)", NA, WEIGHTING, ESTIMAND, CLUSTER, SHA)
PW$period_label <- PLABEL[PW$period]
write.csv(PW, file.path(DIAG_OUT, "DIAG1_between_pointwise.csv"), row.names = FALSE, na = "")

QT <- do.call(rbind, quart_rows)
QT <- dg_stamp(QT, "pixel", "part (paddock x community)", NA, WEIGHTING, ESTIMAND, CLUSTER, SHA)
QT$period_label <- PLABEL[QT$period]
write.csv(QT, file.path(DIAG_OUT, "DIAG1_heteroscedasticity.csv"), row.names = FALSE, na = "")

# the four registered values
wr <- QT[QT$scope == "all communities" & QT$period == "whole_record", ]
for (k in 1:4)
  dg_check(sprintf("cap_residual_sd_water_quartile_%d", k),
           sprintf("registered residual SD, water quartile %d (cite the number_id)", k),
           c(12.8110, 8.4856, 6.3343, 3.8329)[k], wr$residual_sd_sample[k], 5e-4, note = "2.3")

wrp <- PW[PW$period == "whole_record", ]
dg_check("corr_abs_resid_x", "corr(|residual|, wetness), whole record",
         -0.506, stats::cor(abs(wrp$residual), wrp$x_inund_mean), 1e-3, note = "2.3")

# local-z: rank movement. Rank 1 = largest shortfall, so ranks ascend with residual.
lz <- wrp[, c("part_id", "zone_fid", "paddock_name", "community_short", "n_pixels_part",
              "x_inund_mean", "residual", "water_quartile", "local_residual_sd",
              "residual_z_local")]
lz$rank_pooled <- rank(lz$residual, ties.method = "first")
lz$rank_local <- rank(lz$residual_z_local, ties.method = "first")
lz$rank_movement <- lz$rank_local - lz$rank_pooled
lz <- lz[order(lz$rank_pooled), ]
for (nm in c("Mara 6", "Dinan 2")) {
  r <- lz[lz$paddock_name == nm & lz$community_short == "inland", ]
  if (nrow(r) == 1L) {
    dg_check(sprintf("rank_pooled__%s", gsub(" ", "_", nm)),
             sprintf("%s (Inland) pooled residual rank", nm),
             c("Mara 6" = 85, "Dinan 2" = 87)[[nm]], r$rank_pooled, 0, note = "2.3")
    dg_check(sprintf("rank_local__%s", gsub(" ", "_", nm)),
             sprintf("%s (Inland) local-z rank", nm),
             c("Mara 6" = 113, "Dinan 2" = 114)[[nm]], r$rank_local, 0, note = "2.3")
  }
}
lz <- dg_stamp(lz, "pixel", "part (paddock x community)", "1988-2022", WEIGHTING, ESTIMAND,
               CLUSTER, SHA)
lz$note <- paste("residual_z_local = residual / SD of the residuals in this part's water",
                 "quartile. ADDITIONAL COLUMN. It does not replace the published residual and",
                 "the shipped GeoPackage and CSV are not edited.")
write.csv(lz, file.path(DIAG_OUT, "DIAG1_local_z.csv"), row.names = FALSE, na = "")
mv <- lz[order(-abs(lz$rank_movement)), ]
dg_say("  local-z: largest rank movements  %s",
       paste(sprintf("%s/%s %+d", mv$paddock_name[1:4], mv$community_short[1:4],
                     mv$rank_movement[1:4]), collapse = "   "))

# ================================================================= 2.4 influence ====

dg_say("")
dg_say("-- 2.4 influence, at the cluster that matters --")

infl <- list()
for (p in PERIODS) {
  d <- per(p)
  base <- dg_wls(cbind(1, d$inund_mean), d$floor_mean, d$n_pixels_part)$coef[2]
  dr <- dg_drop_one_cluster(DG_FORMS$linear, d$inund_mean, d$floor_mean,
                            d$n_pixels_part, d$zone_fid)
  nm <- d$paddock_name[match(dr$cluster_value, d$zone_fid)]
  infl[[length(infl) + 1L]] <- data.frame(
    row_type = "drop_one_cluster", period = p, period_label = PLABEL[[p]],
    cluster_value = dr$cluster_value, paddock_name = nm, n_parts_dropped = dr$n_dropped,
    slope_all = base, slope_without = dr$slope_without,
    slope_delta = dr$slope_without - base,
    part_id = NA_character_, community_short = NA_character_,
    residual_in_sample = NA_real_, residual_cluster_deleted = NA_real_,
    hat_leverage = NA_real_, stringsAsFactors = FALSE)
  if (p == "whole_record") {
    dg_check("drop_one_min", "drop-one-paddock slope, minimum", 0.4692, min(dr$slope_without), 5e-4, note = "2.4")
    dg_check("drop_one_max", "drop-one-paddock slope, maximum", 0.5867, max(dr$slope_without), 5e-4, note = "2.4")
    b29 <- dr$slope_without[nm == "Bala 29ca"] - base
    dg_check("drop_one_bala29ca", "Bala 29ca's effect on the slope", -0.0781, b29, 5e-4, note = "2.4")
    o <- sort(dr$slope_without - base)
    dg_say("  drop-one range %.4f to %.4f against %.6f", min(dr$slope_without), max(dr$slope_without), base)
    dg_say("  Bala 29ca %+.4f;  next largest %+.4f (%s) - a factor of %.2f",
           o[1], o[2], nm[order(dr$slope_without - base)][2], o[1] / o[2])
  }
  pw <- pointwise[[p]]
  infl[[length(infl) + 1L]] <- data.frame(
    row_type = "part_leverage_and_deleted_residual", period = p, period_label = PLABEL[[p]],
    cluster_value = pw$zone_fid, paddock_name = pw$paddock_name, n_parts_dropped = NA_integer_,
    slope_all = base, slope_without = NA_real_, slope_delta = NA_real_,
    part_id = pw$part_id, community_short = pw$community_short,
    residual_in_sample = pw$residual, residual_cluster_deleted = pw$residual_cluster_deleted,
    hat_leverage = pw$hat_leverage, stringsAsFactors = FALSE)
}
IN <- do.call(rbind, infl)
IN <- dg_stamp(IN, "pixel", "part (paddock x community)", NA, WEIGHTING, ESTIMAND, CLUSTER, SHA)
IN$period_label <- PLABEL[IN$period]
IN$deletion_rule <- ifelse(IN$row_type == "drop_one_cluster",
                           "the whole paddock is removed and the slope refitted",
                           "residual_cluster_deleted = predicted from a fit with this part's WHOLE PADDOCK removed")
write.csv(IN, file.path(DIAG_OUT, "DIAG1_influence.csv"), row.names = FALSE, na = "")

b <- PW[PW$period == "whole_record" & PW$paddock_name == "Bala 29ca", ]
for (j in seq_len(nrow(b))) {
  tg <- c(aeolian = -27.29, riverine = -23.74, inland = 4.45)[[b$community_short[j]]]
  dg_check(sprintf("loo_bala29ca_%s", b$community_short[j]),
           sprintf("Bala 29ca / %s cluster-deleted residual", b$community_short[j]),
           tg, b$residual_cluster_deleted[j], 5e-3, note = "2.4")
  dg_say("  Bala 29ca %-9s in-sample %+7.2f -> cluster-deleted %+7.2f  (leverage %.3f)",
         b$community_short[j], b$residual[j], b$residual_cluster_deleted[j], b$hat_leverage[j])
}

# ============================================================ 2.5 / 2.6 the form ====

dg_say("")
dg_say("-- 2.5 functional form, leave-one-paddock-out; 2.6 sensitivity --")

form_rows <- list()
CV_TARGET <- c(sqrt_x = 8.481, quadratic = 8.553, linear = 8.572, log_x1 = 8.701, cubic = 8.805)

scopes <- c("pooled", "aeolian", "riverine", "inland")
for (p in PERIODS) {
  d <- per(p)
  for (sc in scopes) {
    k <- if (sc == "pooled") rep(TRUE, nrow(d)) else d$community_short == sc
    x <- d$inund_mean[k]; y <- d$floor_mean[k]; w <- d$n_pixels_part[k]; cl <- d$zone_fid[k]
    r2_lin <- dg_wls(DG_FORMS$linear(x), y, w)$r2
    for (fm in names(DG_FORMS)) {
      f <- dg_wls(DG_FORMS[[fm]](x), y, w)
      cv <- if (length(unique(cl)) > 2) dg_cluster_cv_rmse(DG_FORMS[[fm]], x, y, w, cl) else NA_real_
      form_rows[[length(form_rows) + 1L]] <- data.frame(
        row_type = "form_summary", period = p, period_label = PLABEL[[p]], scope = sc,
        form = fm, n = length(y), n_clusters = length(unique(cl)),
        x_min = min(x), x_max = max(x),
        cv_rmse_weighted_leave_one_paddock_out = cv,
        r2_in_sample = f$r2, delta_r2_vs_linear = f$r2 - r2_lin,
        resid_sd = f$resid_sd,
        term_1 = f$coef[1], term_2 = f$coef[2],
        term_3 = if (length(f$coef) > 2) f$coef[3] else NA_real_,
        term_4 = if (length(f$coef) > 3) f$coef[4] else NA_real_,
        part_id = NA_character_, community_of_part = NA_character_,
        residual = NA_real_, stringsAsFactors = FALSE)
      if (p == "whole_record" && sc == "pooled")
        dg_check(sprintf("cv_rmse_%s", fm), sprintf("leave-one-paddock-out CV weighted RMSE, %s", fm),
                 CV_TARGET[[fm]], cv, 5e-3, note = "2.5")
      if (p == "whole_record" && fm == "quadratic") {
        tg_x2 <- c(aeolian = 0.306, riverine = 0.047, inland = -0.0028, pooled = -0.0096)[[sc]]
        tg_dr <- c(aeolian = 0.106, riverine = 0.111, inland = 0.006, pooled = 0.026)[[sc]]
        dg_check(sprintf("quad_x2_%s", sc), sprintf("quadratic x-squared term, %s", sc),
                 tg_x2, f$coef[3], 5e-4, note = "2.5")
        dg_check(sprintf("quad_dr2_%s", sc), sprintf("delta R2 from quadratic, %s", sc),
                 tg_dr, f$r2 - r2_lin, 5e-4, note = "2.5")
      }
    }
  }
}

# 2.6: every part's residual under linear, quadratic and sqrt, all three periods
for (p in PERIODS) {
  d <- per(p)
  for (fm in c("linear", "quadratic", "sqrt_x")) {
    f <- dg_wls(DG_FORMS[[fm]](d$inund_mean), d$floor_mean, d$n_pixels_part)
    form_rows[[length(form_rows) + 1L]] <- data.frame(
      row_type = "part_residual", period = p, period_label = PLABEL[[p]], scope = "pooled",
      form = fm, n = nrow(d), n_clusters = length(unique(d$zone_fid)),
      x_min = NA_real_, x_max = NA_real_, cv_rmse_weighted_leave_one_paddock_out = NA_real_,
      r2_in_sample = f$r2, delta_r2_vs_linear = NA_real_, resid_sd = f$resid_sd,
      term_1 = NA_real_, term_2 = NA_real_, term_3 = NA_real_, term_4 = NA_real_,
      part_id = d$part_id, community_of_part = d$community_short,
      residual = f$resid, stringsAsFactors = FALSE)
  }
}
FC <- do.call(rbind, form_rows)
FC <- dg_stamp(FC, "pixel", "part (paddock x community)", NA, WEIGHTING, ESTIMAND, CLUSTER, SHA)
FC$period_label <- PLABEL[FC$period]
write.csv(FC, file.path(DIAG_OUT, "DIAG1_form_comparison.csv"), row.names = FALSE, na = "")

s <- FC[FC$row_type == "form_summary" & FC$period == "whole_record" & FC$scope == "pooled", ]
for (j in order(s$cv_rmse_weighted_leave_one_paddock_out))
  dg_say("  CV RMSE %-10s %.4f", s$form[j], s$cv_rmse_weighted_leave_one_paddock_out[j])

pr <- FC[FC$row_type == "part_residual" & FC$period == "whole_record", ]
wide <- reshape(pr[, c("part_id", "form", "residual")], idvar = "part_id",
                timevar = "form", direction = "wide")
sp <- stats::cor(wide$residual.linear, wide$residual.sqrt_x, method = "spearman")
dg_check("spearman_linear_sqrt", "Spearman between residual rankings, linear vs sqrt(x)",
         0.984, sp, 1e-3, note = "2.6")
dg_say("  Spearman linear vs sqrt(x) %.4f;  linear vs quadratic %.4f", sp,
       stats::cor(wide$residual.linear, wide$residual.quadratic, method = "spearman"))

b29 <- wide[wide$part_id %in% PW$part_id[PW$paddock_name == "Bala 29ca"], ]
b29$community <- PW$community_short[match(b29$part_id, PW$part_id)]
tgt <- list(aeolian = c(-24.85, -21.66, -21.53), riverine = c(-21.58, -19.83, -20.57),
            inland = c(5.87, 4.93, 4.74))
for (j in seq_len(nrow(b29))) {
  cm <- b29$community[j]
  got <- c(b29$residual.linear[j], b29$residual.quadratic[j], b29$residual.sqrt_x[j])
  for (m in 1:3)
    dg_check(sprintf("form_resid_bala29ca_%s_%s", cm, c("linear", "quadratic", "sqrt_x")[m]),
             sprintf("Bala 29ca / %s residual under %s", cm, c("linear", "quadratic", "sqrt_x")[m]),
             tgt[[cm]][m], got[m], 5e-3, note = "2.6")
  dg_say("  Bala 29ca %-9s linear %+7.2f  quadratic %+7.2f  sqrt %+7.2f  (spread %.2f pp)",
         cm, got[1], got[2], got[3], max(got) - min(got))
}
# the worst three, and whether they hold order across forms
w3 <- wide[order(wide$residual.linear)[1:3], ]
s3 <- wide[order(wide$residual.sqrt_x)[1:3], ]
dg_say("  worst three by linear: %s", paste(w3$part_id, collapse = ", "))
dg_say("  worst three by sqrt:   %s   identical and in order: %s",
       paste(s3$part_id, collapse = ", "), identical(w3$part_id, s3$part_id))
dg_check("worst_three_identical", "worst three parts identical and in order across linear and sqrt(x)",
         1, as.numeric(identical(w3$part_id, s3$part_id)), 0, note = "2.6")

# the community slopes referenced by 2.5's bootstrap reading
for (cm in c("aeolian", "riverine", "inland")) {
  d <- per("whole_record"); k <- d$community_short == cm
  f <- dg_wls(cbind(1, d$inund_mean[k]), d$floor_mean[k], d$n_pixels_part[k])
  dg_say("  observed between slope, %-9s %+.4f  (n=%d)", cm, f$coef[2], sum(k))
  if (cm == "aeolian")
    dg_check("aeolian_observed_slope", "Aeolian observed between-unit slope (FIG-2 panel B)",
             -0.309, f$coef[2], 1e-3, note = "2.5")
}

d <- dg_write_checks(file.path(DIAG_OUT, "DIAG1_reproduction_checks_stageA.csv"))
real <- d[!d$expected_to_disagree, ]
dg_say("")
dg_say("Stage A checks: %d of %d agree (plus %d fixture row(s) that correctly disagree)",
       sum(real$agrees), nrow(real), sum(d$expected_to_disagree))
if (any(!real$agrees)) {
  dg_say("DISAGREEMENTS:")
  for (j in which(!real$agrees))
    dg_say("  %-42s target %11.6f  got %11.6f", real$check[j], real$target[j], real$got[j])
}
