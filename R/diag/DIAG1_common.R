# DIAG1_common.R - shared diagnostic machinery for DIAG-1 (7 August 2026).
#
# Ruling AS: estimation lives in R. R/gayini_fit.R is the shared SLOPE function and is
# used for the section 2.1 reproduction. This file adds what a diagnostics task needs
# and gayini_fit does not return: hat values, cluster-deleted residuals, design
# matrices for alternative functional forms, and cluster cross-validation.
#
# THE SAME THREE RULES APPLY AND ARE NOT RESTATED PER FUNCTION:
#   - summary() is never called on a model object. No p-value can print by accident.
#     Nothing here computes a standard error, a t statistic or a test of any kind.
#   - Every emitted row carries its estimator, its cluster and the input checksum.
#   - Nothing is registered and nothing touches the database.
#
# WEIGHTING. Every fit below is pixel-weighted by the unit's cell count, because the
# fit being diagnosed is. Unweighted variants are reported where the spec asks for
# them and are labelled; they are never silently substituted.

suppressPackageStartupMessages({
  library(digest)
})

source(file.path("R", "gayini_fit.R"))

DIAG_OUT <- file.path("Output", "diag")
DIAG_ANA <- file.path(DIAG_OUT, "analysis")
DIAG_FIG <- file.path(DIAG_OUT, "figures")

# ---------------------------------------------------------------- weighted OLS ----

#' Weighted least squares with the diagnostic quantities attached.
#'
#' Coefficients come from solve() on the weighted normal equations and are
#' cross-checked against lm() by the caller where a cross-check is meaningful.
#'
#' hat: for weighted OLS the projection is H = X (X'WX)^-1 X'W, so the leverage of
#' observation i is h_ii = w_i * x_i' (X'WX)^-1 x_i. A part with many cells therefore
#' carries more leverage than an otherwise identical part with few, which is the
#' behaviour we want to be able to SEE rather than assume.
dg_wls <- function(X, y, w) {
  X <- as.matrix(X)
  XtW <- t(X * w)
  A <- XtW %*% X
  b <- as.vector(solve(A, XtW %*% y))
  fitted <- as.vector(X %*% b)
  e <- y - fitted
  M <- solve(A)
  h <- as.vector(rowSums((X %*% M) * X) * w)
  n <- length(y); p <- ncol(X)
  s2 <- sum(w * e^2) / (n - p)
  ybar <- sum(w * y) / sum(w)
  list(coef = b, fitted = fitted, resid = e, hat = h,
       # standardised residual, weighted form; used for the panel only, never tested
       std_resid = e * sqrt(w) / sqrt(s2 * pmax(1 - h, .Machine$double.eps)),
       sigma = sqrt(s2),
       r2 = 1 - sum(w * e^2) / sum(w * (y - ybar)^2),
       resid_sd = sqrt(sum(w * e^2) / sum(w)),
       n = n, p = p)
}

#' The five functional forms compared in section 2.5, as design-matrix builders.
DG_FORMS <- list(
  linear    = function(x) cbind(1, x),
  quadratic = function(x) cbind(1, x, x^2),
  sqrt_x    = function(x) cbind(1, sqrt(x)),
  log_x1    = function(x) cbind(1, log(x + 1)),
  cubic     = function(x) cbind(1, x, x^2, x^3)
)

#' Leave-one-CLUSTER-out predictive error, weighted RMSE.
#'
#' Not in-sample R-squared, and not leave-one-OBSERVATION-out. Parts inside one
#' paddock share a fence, a management history and much of their water; deleting one
#' part while its siblings stay in the fit understates how much the model borrowed
#' from them. Deleting the paddock is the honest test.
dg_cluster_cv_rmse <- function(fx, x, y, w, cluster) {
  se <- 0; sw <- 0
  for (g in unique(cluster)) {
    k <- cluster != g
    b <- dg_wls(fx(x[k]), y[k], w[k])$coef
    pred <- as.vector(fx(x[!k]) %*% b)
    se <- se + sum(w[!k] * (y[!k] - pred)^2)
    sw <- sw + sum(w[!k])
  }
  sqrt(se / sw)
}

#' Cluster-deleted residuals: refit without each cluster, predict its members.
#'
#' This is the section 2.4 leave-one-out. The part-deleted version (e / (1 - h)) was
#' computed first and gives a DIFFERENT answer - for Bala 29ca's Inland part it moves
#' +5.87 to +6.01 where the cluster-deleted version moves it to +4.45 - because
#' deleting one part leaves its two siblings pulling the line. Both are returned so
#' the difference is visible rather than a choice made silently.
dg_deleted_residuals <- function(fx, x, y, w, cluster) {
  n <- length(y)
  out_cluster <- numeric(n)
  for (g in unique(cluster)) {
    k <- cluster != g
    b <- dg_wls(fx(x[k]), y[k], w[k])$coef
    out_cluster[!k] <- y[!k] - as.vector(fx(x[!k]) %*% b)
  }
  f <- dg_wls(fx(x), y, w)
  list(cluster_deleted = out_cluster,
       obs_deleted = f$resid / pmax(1 - f$hat, .Machine$double.eps),
       in_sample = f$resid)
}

#' Drop-one-cluster refits: the slope with each cluster held out.
dg_drop_one_cluster <- function(fx, x, y, w, cluster, term = 2L) {
  g <- unique(cluster)
  data.frame(
    cluster_value = g,
    slope_without = vapply(g, function(v) {
      k <- cluster != v
      dg_wls(fx(x[k]), y[k], w[k])$coef[term]
    }, numeric(1)),
    n_dropped = vapply(g, function(v) sum(cluster == v), integer(1)),
    stringsAsFactors = FALSE
  )
}

# ------------------------------------------------------- within (fixed effects) ----

#' Demean y and x within each unit, weighted - the within transform.
#'
#' Returned as columns rather than applied in place, so a caller can plot the raw and
#' the demeaned axes side by side without refitting.
dg_demean <- function(y, x, w, unit) {
  yd <- y; xd <- x
  for (i in split(seq_along(y), unit)) {
    sw <- sum(w[i])
    yd[i] <- y[i] - sum(w[i] * y[i]) / sw
    xd[i] <- x[i] - sum(w[i] * x[i]) / sw
  }
  list(y = yd, x = xd)
}

# ----------------------------------------------------------------- bookkeeping ----

#' The five provenance columns section 7 requires on every output, plus estimand.
dg_stamp <- function(df, support_level, unit, period_label, weighting, estimand,
                     cluster = NA_character_, source_sha = NA_character_) {
  df$support_level <- support_level
  df$unit <- unit
  df$period_label <- period_label
  df$weighting <- weighting
  df$estimand <- estimand
  df$cluster <- cluster
  df$source_sha256_first50 <- source_sha
  df$interval_status <- "diagnostic - NOT registered, and nothing here is proposed for registration"
  df
}

#' Accumulate reproduction checks. `halt` marks the section 2.1 conditions.
dg_checks <- new.env(parent = emptyenv())
dg_checks$rows <- list()

#' `fixture = TRUE` marks a row that is SUPPOSED to disagree: the deliberately broken
#' input proving the check can catch a wrong value. Without the flag it would be
#' counted as a failure and the "n of n agree" line would understate the run by one.
dg_check <- function(id, what, target, got, tol, halt = FALSE, note = "", fixture = FALSE) {
  agrees <- is.finite(got) && is.finite(target) && abs(got - target) <= tol
  dg_checks$rows[[length(dg_checks$rows) + 1L]] <- data.frame(
    check = id, what = what, section = note, target = target, got = got,
    tolerance = tol, agrees = agrees, halt_condition = halt,
    expected_to_disagree = fixture, stringsAsFactors = FALSE)
  if (halt && !agrees)
    stop(sprintf("DIAG-1 HALT (spec section 2.1): %s - target %.6f, got %.6f, tolerance %g.\n%s",
                 id, target, got, tol,
                 "Everything downstream would be diagnosing a different model. Run stopped."))
  invisible(agrees)
}

dg_write_checks <- function(path) {
  d <- do.call(rbind, dg_checks$rows)
  utils::write.csv(d, path, row.names = FALSE, na = "")
  d
}

dg_say <- function(...) cat(sprintf(...), "\n", sep = "")
