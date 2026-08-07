# DIAG1_stageE.R - diagnose the WITHIN-unit fits (spec section 5), and section 6.
#
# Everything in DIAG-1 v1 aimed at the between-unit fit. The within fits have had no
# diagnostics at all and are now the project's central result: 115 of 115 positive,
# replicating 91 of 91 out of sample. This gives them the treatment section 2 gives
# the between fit.
#
# TWO SETS, ONE CODE PATH. The diagnostic functions take (x, y, weights, cluster) and
# do not care which set they are given. Section 6: the unzoned patches HAVE NO PADDOCK,
# and no paddock cluster is substituted for one - the outputs say so in a column.
#
# FUNCTIONAL FORM, THE ONE TRAP HERE. For a within estimator the transform is applied
# to RAW water and then demeaned within the unit: y = f(x) + unit + e. Transforming the
# already-demeaned water would take sqrt() and log() of negative numbers. The
# distinction is not cosmetic - it is the difference between a fit and an error.

source(file.path("R", "diag", "DIAG1_common.R"))

WEIGHTING <- "pixel-weighted by the unit's cell count"

dg_say("=== DIAG-1 Stage E - the within-unit fits ===")

dm <- function(v, unit, w) {
  o <- v
  for (i in split(seq_along(v), unit)) o[i] <- v[i] - sum(w[i] * v[i]) / sum(w[i])
  o
}

WITHIN_FORMS <- list(
  linear    = function(x) cbind(x),
  quadratic = function(x) cbind(x, x^2),
  sqrt_x    = function(x) cbind(sqrt(x)),
  log_x1    = function(x) cbind(log(x + 1)),
  cubic     = function(x) cbind(x, x^2, x^3)
)

#' One set's within diagnostics. `cluster_note` is printed onto every row.
stage_e <- function(tag, d, y, x, unit, w, cluster, cluster_note, target_slope,
                    sha, n_boot = 2000L) {
  Y <- d[[y]]; X <- d[[x]]; W <- d[[w]]; U <- d[[unit]]; CL <- d[[cluster]]
  yd <- dm(Y, U, W); xd <- dm(X, U, W)
  f <- dg_wls(cbind(xd), yd, W)           # no intercept: demeaning removed it
  slope <- f$coef[1]
  dg_say("")
  dg_say("-- %s: n=%d, %d units, %d clusters (%s) --", tag, nrow(d),
         length(unique(U)), length(unique(CL)), cluster)
  dg_say("  pooled within slope %.6f   (target %.4f)   R2 %.4f   resid SD %.3f",
         slope, target_slope, f$r2, f$resid_sd)
  dg_check(sprintf("%s__within_slope", tag), sprintf("%s pooled within slope", tag),
           target_slope, slope, 1e-3, note = "5")

  rows <- list()
  pointwise <- data.frame(
    set = tag, unit_id = U, cluster_id = CL,
    community_short = if ("community_short" %in% names(d)) d$community_short else NA_character_,
    water_year = d$water_year, weight = W,
    y_raw = Y, x_raw = X, y_demeaned = yd, x_demeaned = xd,
    fitted = f$fitted, residual = f$resid, abs_residual = abs(f$resid),
    stringsAsFactors = FALSE)
  pointwise <- dg_stamp(pointwise, "pixel", tag, "1988-2022", WEIGHTING,
                        "WITHIN-UNIT (unit fixed effects) - never a version of the between-unit slope",
                        cluster, sha)
  pointwise$cluster_note <- cluster_note

  # ---- influence at the cluster -------------------------------------------------
  ks <- unique(CL)
  # each refit demeans on the SUBSET's own unit means, never on demeaned values
  # carried in from the full sample - carrying them in would leak the dropped cluster
  sl <- vapply(ks, function(g) {
    k <- CL != g
    dg_wls(cbind(dm(X[k], U[k], W[k])), dm(Y[k], U[k], W[k]), W[k])$coef[1]
  }, numeric(1))
  dg_say("  drop-one-%s range %.4f to %.4f against %.4f  (widest mover %+.4f, %s)",
         cluster, min(sl), max(sl), slope, (sl - slope)[which.max(abs(sl - slope))],
         ks[which.max(abs(sl - slope))])
  rows[[length(rows) + 1L]] <- data.frame(
    set = tag, row_type = "drop_one_cluster", scope = as.character(ks), form = "linear",
    n = vapply(ks, function(g) sum(CL == g), integer(1)),
    value = sl, reference = slope, delta = sl - slope,
    detail = sprintf("slope with %s %s removed", cluster, ks), stringsAsFactors = FALSE)

  # ---- functional form: does the within response saturate? ----------------------
  cv_within <- function(fx) {
    se <- 0; sw <- 0
    for (g in ks) {
      k <- CL != g
      b <- dg_wls(apply(fx(X[k]), 2, dm, unit = U[k], w = W[k]), dm(Y[k], U[k], W[k]), W[k])$coef
      Xo <- apply(fx(X[!k]), 2, dm, unit = U[!k], w = W[!k])
      pred <- as.vector(as.matrix(Xo) %*% b)
      se <- se + sum(W[!k] * (dm(Y[!k], U[!k], W[!k]) - pred)^2); sw <- sw + sum(W[!k])
    }
    sqrt(se / sw)
  }
  r2_lin <- f$r2
  for (fm in names(WITHIN_FORMS)) {
    Xf <- apply(WITHIN_FORMS[[fm]](X), 2, dm, unit = U, w = W)
    ff <- dg_wls(Xf, dm(Y, U, W), W)
    cvr <- cv_within(WITHIN_FORMS[[fm]])
    rows[[length(rows) + 1L]] <- data.frame(
      set = tag, row_type = "form_summary", scope = "pooled", form = fm,
      n = nrow(d), value = cvr, reference = r2_lin, delta = ff$r2 - r2_lin,
      detail = sprintf("leave-one-%s-out CV weighted RMSE %.4f; in-sample R2 %.4f; terms %s",
                       cluster, cvr, ff$r2, paste(sprintf("%+.5f", ff$coef), collapse = " ")),
      stringsAsFactors = FALSE)
    dg_say("  form %-10s CV RMSE %.4f   R2 %.4f (%+.4f)   terms %s", fm, cvr, ff$r2,
           ff$r2 - r2_lin, paste(sprintf("%+.5f", ff$coef), collapse = " "))
  }

  # ---- heteroscedasticity in the within residuals -------------------------------
  br <- stats::quantile(xd, c(0, .25, .5, .75, 1))
  q <- cut(xd, br, include.lowest = TRUE, labels = FALSE)
  sdq <- tapply(f$resid, q, stats::sd)
  dg_say("  residual SD by demeaned-water quartile: %s", paste(sprintf("%.2f", sdq), collapse = " "))
  for (k in 1:4) rows[[length(rows) + 1L]] <- data.frame(
    set = tag, row_type = "heteroscedasticity_by_demeaned_water", scope = paste("quartile", k),
    form = "linear", n = sum(q == k), value = sdq[[k]], reference = f$resid_sd,
    delta = sdq[[k]] - f$resid_sd,
    detail = sprintf("demeaned water %.2f to %.2f pp", br[[k]], br[[k + 1L]]),
    stringsAsFactors = FALSE)
  if (!all(is.na(pointwise$community_short))) {
    for (cm in sort(unique(pointwise$community_short))) {
      k <- pointwise$community_short == cm
      fc <- dg_wls(cbind(dm(X[k], U[k], W[k])), dm(Y[k], U[k], W[k]), W[k])
      rows[[length(rows) + 1L]] <- data.frame(
        set = tag, row_type = "within_by_community", scope = cm, form = "linear",
        n = sum(k), value = fc$coef[1], reference = slope, delta = fc$coef[1] - slope,
        detail = sprintf("residual SD %.3f; R2 %.4f", fc$resid_sd, fc$r2),
        stringsAsFactors = FALSE)
      dg_say("  %-9s within slope %+.4f  resid SD %.3f  R2 %.4f", cm, fc$coef[1],
             fc$resid_sd, fc$r2)
    }
  }

  # ---- what the interval does and does not absorb -------------------------------
  # Section 5 asks us to state that the within intervals ignore serial correlation.
  # CHECKED RATHER THAN ASSERTED: three resampling schemes, same estimator, same data.
  # If the block scheme is already much wider than the iid scheme, the published
  # interval is not ignoring serial correlation and the sentence needs qualifying.
  boot_width <- function(scheme) {
    set.seed(20260807L)
    if (scheme == "iid_part_years") {
      # rows resampled independently: the panel structure is deliberately destroyed,
      # so this is what an interval that IGNORES serial dependence looks like
      acc <- vapply(seq_len(n_boot), function(b) {
        i <- sample.int(nrow(d), nrow(d), replace = TRUE)
        dg_wls(cbind(dm(X[i], U[i], W[i])), dm(Y[i], U[i], W[i]), W[i])$coef[1]
      }, numeric(1))
    } else {
      cl <- split(seq_len(nrow(d)), d[[scheme]]); keys <- names(cl)
      acc <- vapply(seq_len(n_boot), function(b) {
        pick <- sample(keys, length(keys), replace = TRUE)
        i <- unlist(cl[pick], use.names = FALSE)
        un <- paste(U[i], rep(seq_along(pick), lengths(cl[pick])), sep = "#")
        dg_wls(cbind(dm(X[i], un, W[i])), dm(Y[i], un, W[i]), W[i])$coef[1]
      }, numeric(1))
    }
    unname(stats::quantile(acc, c(0.025, 0.5, 0.975)))
  }
  schemes <- c("iid_part_years", unit, if (cluster != unit) cluster)
  for (s in schemes) {
    qv <- boot_width(s)
    rows[[length(rows) + 1L]] <- data.frame(
      set = tag, row_type = "bootstrap_scheme", scope = s, form = "linear", n = n_boot,
      value = qv[3] - qv[1], reference = slope, delta = qv[2] - slope,
      detail = sprintf("2.5th %.4f, 50th %.4f, 97.5th %.4f; width %.4f", qv[1], qv[2], qv[3], qv[3] - qv[1]),
      stringsAsFactors = FALSE)
    dg_say("  bootstrap %-14s [%.4f, %.4f]  width %.4f", s, qv[1], qv[3], qv[3] - qv[1])
  }

  R <- do.call(rbind, rows)
  R$cluster_note <- cluster_note
  R <- dg_stamp(R, "pixel", tag, "1988-2022", WEIGHTING,
                "WITHIN-UNIT (unit fixed effects) - never a version of the between-unit slope",
                cluster, sha)
  list(rows = R, pointwise = pointwise, slope = slope)
}

# ------------------------------------------------------------------- the parts ----
CSV_P <- file.path(DIAG_ANA, "DIAG1_part_year.csv")
SHA_P <- gayini_sha256_first50_file(CSV_P)
DP <- read.csv(CSV_P, stringsAsFactors = FALSE)
DP <- DP[order(DP$part_id, DP$water_year), ]
EP <- stage_e("part-year (115 parts in 64 paddocks)", DP, "veg_p05_spatial", "inund_pct",
              "part_id", "n_pixels_part", "zone_fid", "clustered on the PADDOCK (zone_fid)",
              0.161271, SHA_P)

# ------------------------------------------------------- the unzoned patches ----
CSV_Q <- file.path(DIAG_ANA, "DIAG1_patch_year.csv")
SHA_Q <- gayini_sha256_first50_file(CSV_Q)
DQ <- read.csv(CSV_Q, stringsAsFactors = FALSE)
DQ <- DQ[order(DQ$patch_id, DQ$water_year), ]
DQ$n_pixels_part <- DQ$n_cells
EQ <- stage_e("patch-year (93 unzoned patches)", DQ, "veg_p05_spatial", "inund_pct",
              "patch_id", "n_pixels_part", "patch_id",
              paste("NO PADDOCK EXISTS. Unzoned patches are not nested in management",
                    "zones; the cluster is the patch itself and no paddock cluster is",
                    "substituted (spec section 6)."),
              0.210573, SHA_Q)

WD <- rbind(EP$rows, EQ$rows)
write.csv(WD, file.path(DIAG_OUT, "DIAG1_within_diagnostics.csv"), row.names = FALSE, na = "")
PWW <- rbind(EP$pointwise, EQ$pointwise)
write.csv(PWW, file.path(DIAG_OUT, "DIAG1_within_pointwise.csv"), row.names = FALSE, na = "")

# ------------------------------------------------------------- section 6 note ----
dg_say("")
dg_say("-- 6 UNZONED between-unit half --")
dg_say("  NOT APPLICABLE. Amendment A1 ran; A2 did not. There is no unzoned")
dg_say("  between-unit fit and no unzoned residual, so section 2's diagnostics have")
dg_say("  nothing to run on for that half. The within half is covered above.")
write.csv(data.frame(
  question = "Stage A (between-unit) diagnostics over the UNZONED set",
  status = "NOT APPLICABLE",
  reason = paste("UNZONED amendment A1 ran and A2 did not. A1 produced within-patch",
                 "replication only. There is no unzoned between-unit fit and no unzoned",
                 "residual, so there is no fitted line to diagnose, no leverage to compute",
                 "and no residual to standardise. This is an absence of an input, not a",
                 "diagnostic that was skipped."),
  covered_instead = "Stage E's within diagnostics, run over all 3,253 patch-years, clustered on patch_id",
  cluster_substitution = "NONE. No paddock cluster was substituted for the missing one.",
  stringsAsFactors = FALSE),
  file.path(DIAG_OUT, "DIAG1_unzoned_between_not_applicable.csv"), row.names = FALSE)

d <- dg_write_checks(file.path(DIAG_OUT, "DIAG1_reproduction_checks_stageE.csv"))
real <- d[!d$expected_to_disagree, ]
dg_say("")
dg_say("Stage E checks: %d of %d agree", sum(real$agrees), nrow(real))
if (any(!real$agrees)) for (j in which(!real$agrees))
  dg_say("  DIFFERS %-38s target %9.6f  got %9.6f", real$check[j], real$target[j], real$got[j])
