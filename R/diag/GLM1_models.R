# GLM1_models.R - does a bounded-response model do better? (spec GLM-1 + P5)
#
# PRE-REGISTERED. P1-P5 were fixed in Output/glm/GLM1_prereg.md and committed BEFORE
# this file ran, in a commit containing no model output. Nothing below renegotiates them.
#
# P5, AND IT LIMITS EVERYTHING ELSE. The quasi-binomial and beta models ASSUME the
# ceiling that DIAG-1 section 8.6 named as the alternative explanation for the
# saturation. Fitting the bound does not test the bound. No result here is evidence that
# the flattening is ecological rather than geometric, and none is reported as such.
#
# Ruling AS: all estimation in R. No p-values: summary() is never called on a model
# object, and nothing computes a standard error, a t statistic or a test.
#
# M2 IS HAND-IMPLEMENTED. betareg, glmmTMB, mvabund and ecostats are all absent from
# this machine and could not be installed. Beta regression is therefore fitted by
# maximum likelihood directly - the mean-precision parameterisation with a logit link on
# the mean - and its convergence is checked from several starting values rather than
# trusted. M4 (mvabund PIT-trap) is NOT ATTEMPTED, which the spec explicitly permits.

source(file.path("R", "diag", "DIAG1_common.R"))

GLM_OUT <- file.path("Output", "glm")
GLM_FIG <- file.path(GLM_OUT, "figures")
dir.create(GLM_FIG, recursive = TRUE, showWarnings = FALSE)

CSV_B <- file.path(DIAG_ANA, "DIAG1_between_parts.csv")
CSV_P <- file.path(DIAG_ANA, "DIAG1_part_year.csv")
CSV_Q <- file.path(DIAG_ANA, "DIAG1_patch_year.csv")
SHA_B <- gayini_sha256_first50_file(CSV_B)

B <- read.csv(CSV_B, stringsAsFactors = FALSE)
B <- B[B$period == "whole_record", ]
P <- read.csv(CSV_P, stringsAsFactors = FALSE)
Q <- read.csv(CSV_Q, stringsAsFactors = FALSE)
Q$n_pixels_part <- Q$n_cells

dg_say("=== GLM-1 - does a bounded-response model do better? ===")
dg_say("  prereg: Output/glm/GLM1_prereg.md, committed before this ran")
dg_say("  betareg / glmmTMB / mvabund / ecostats: ABSENT. M2 hand-fitted, M4 not attempted.")

# ============================================================ M0 - reproduce or halt ====
f0 <- dg_wls(cbind(1, B$inund_mean), B$floor_mean, B$n_pixels_part)
dg_check("M0_slope", "M0 linear slope (halt condition)", 0.547274, f0$coef[2], 5e-6,
         halt = TRUE, note = "2")
dg_check("M0_intercept", "M0 linear intercept (halt condition)", 52.697196, f0$coef[1], 5e-6,
         halt = TRUE, note = "2")
dg_say("")
dg_say("-- M0 reproduces: slope %.6f  intercept %.6f --", f0$coef[2], f0$coef[1])

# ------------------------------------------------------------------ shared helpers ----
WQ <- function(x) cut(x, stats::quantile(x, c(0, .25, .5, .75, 1)), include.lowest = TRUE,
                      labels = FALSE)

#' Pearson-residual SD by water quartile, and the max/min ratio. P1's statistic.
pearson_ratio <- function(pres, x) {
  s <- tapply(pres, WQ(x), stats::sd)
  list(sd = as.numeric(s), ratio = max(s) / min(s))
}

#' Beta log-likelihood, mean-precision parameterisation, logit link on the mean.
#' Weights enter as a multiplier on each observation's contribution - a PRECISION
#' weight, exactly as in M1, and not a trial count.
.beta_nll <- function(par, X, y, w) {
  k <- ncol(X)
  mu <- 1 / (1 + exp(-as.vector(X %*% par[1:k])))
  phi <- exp(par[k + 1])
  mu <- pmin(pmax(mu, 1e-10), 1 - 1e-10)
  a <- mu * phi; b <- (1 - mu) * phi
  -sum(w * (lgamma(phi) - lgamma(a) - lgamma(b) +
              (a - 1) * log(y) + (b - 1) * log1p(-y)))
}

#' Fit beta regression by ML. Convergence is CHECKED from several starts, not assumed:
#' a hand-rolled optimiser that silently lands in a local optimum would be undetectable.
fit_beta <- function(X, y, w, n_start = 4L) {
  k <- ncol(X)
  best <- NULL; vals <- numeric(0)
  for (s in seq_len(n_start)) {
    set.seed(20260808L + s)
    init <- c(if (s == 1L) c(stats::qlogis(mean(y)), rep(0, k - 1)) else stats::rnorm(k, 0, 0.5),
              log(10) + if (s == 1L) 0 else stats::rnorm(1, 0, 0.5))
    o <- try(stats::optim(init, .beta_nll, X = X, y = y, w = w, method = "BFGS",
                          control = list(maxit = 2000, reltol = 1e-12)), silent = TRUE)
    if (inherits(o, "try-error")) next
    vals <- c(vals, o$value)
    if (is.null(best) || o$value < best$value) best <- o
  }
  stopifnot(!is.null(best), best$convergence == 0)
  list(coef = best$par[1:k], log_phi = best$par[k + 1],
       nll = best$value, n_starts_converged = length(vals),
       start_spread = if (length(vals) > 1) max(vals) - min(vals) else 0)
}

link_mu <- function(X, b) 1 / (1 + exp(-as.vector(X %*% b)))

# ======================================================= BETWEEN-UNIT: M0, M1, M2 ====
xB <- B$inund_mean; yB <- B$floor_mean / 100; wB <- B$n_pixels_part; clB <- B$zone_fid
XB <- cbind(1, xB)

dg_say("")
dg_say("-- between-unit, 115 parts --")
dg_say("  response on (0,1): min %.4f  max %.4f", min(yB), max(yB))
n0 <- sum(yB <= 0); n1 <- sum(yB >= 1)
dg_say("  exact 0 or 1 values: %d and %d  -> %s", n0, n1,
       if (n0 + n1 == 0) "NO boundary adjustment needed, and none applied" else "ADJUSTMENT REQUIRED")
dg_check("M2_boundary_values", "exact 0 or 100 values requiring a beta adjustment",
         0, n0 + n1, 0, note = "2 M2")

m1B <- stats::glm(yB ~ xB, family = stats::quasibinomial(link = "logit"), weights = wB)
b1B <- stats::coef(m1B)
mu1B <- link_mu(XB, b1B)
m2B <- fit_beta(XB, yB, wB)
mu2B <- link_mu(XB, m2B$coef)
dg_say("  M1 quasi-binomial  logit coefs %+.5f %+.5f", b1B[1], b1B[2])
dg_say("  M2 beta ML         logit coefs %+.5f %+.5f   phi %.2f  (%d starts, nll spread %.2e)",
       m2B$coef[1], m2B$coef[2], exp(m2B$log_phi), m2B$n_starts_converged, m2B$start_spread)

# ---- leave-one-paddock-out CV, on the RESPONSE scale ------------------------------
cv_between <- function(kind) {
  se <- 0; sw <- 0
  for (g in unique(clB)) {
    k <- clB != g
    pr <- switch(
      kind,
      linear = as.vector(cbind(1, xB[!k]) %*% dg_wls(cbind(1, xB[k]), yB[k] * 100, wB[k])$coef),
      sqrt_x = as.vector(cbind(1, sqrt(xB[!k])) %*% dg_wls(cbind(1, sqrt(xB[k])), yB[k] * 100, wB[k])$coef),
      quasibinomial = 100 * link_mu(cbind(1, xB[!k]), stats::coef(stats::glm(
        yB[k] ~ xB[k], family = stats::quasibinomial(link = "logit"), weights = wB[k]))),
      beta = 100 * link_mu(cbind(1, xB[!k]), fit_beta(cbind(1, xB[k]), yB[k], wB[k], 2L)$coef))
    se <- se + sum(wB[!k] * (yB[!k] * 100 - pr)^2); sw <- sw + sum(wB[!k])
  }
  sqrt(se / sw)
}
CVB <- vapply(c("linear", "sqrt_x", "quasibinomial", "beta"), cv_between, numeric(1))
dg_say("  LOPO CV RMSE (response scale, pp): %s",
       paste(sprintf("%s %.4f", names(CVB), CVB), collapse = "   "))

# =============================================== WITHIN-UNIT: the primary interest ====
within_set <- function(d, unit, tag) {
  x <- d$inund_pct; y <- d$veg_p05_spatial / 100; w <- d$n_pixels_part
  u <- factor(d[[unit]])
  X <- stats::model.matrix(~ u + x)
  dg_say("")
  dg_say("-- within-unit: %s (n=%d, %d units) --", tag, nrow(d), nlevels(u))
  n0 <- sum(y <= 0); n1 <- sum(y >= 1)
  dg_say("  exact 0 or 1: %d and %d -> %s", n0, n1,
         if (n0 + n1 == 0) "no adjustment applied" else "ADJUSTMENT REQUIRED")

  m1 <- stats::glm(y ~ u + x, family = stats::quasibinomial(link = "logit"), weights = w)
  b1 <- stats::coef(m1); mu1 <- stats::fitted(m1)
  m2 <- fit_beta(X, y, w, 3L); mu2 <- link_mu(X, m2$coef)
  # M3: GAM shape check, k = 4, unit fixed effects retained
  m3 <- mgcv::gam(y ~ u + s(x, k = 4), family = stats::quasibinomial(link = "logit"),
                  weights = w, method = "REML")
  mu3 <- stats::fitted(m3)

  # within slope from the incumbent linear model, for the P4 comparison
  dm <- function(v) { o <- v; for (i in split(seq_along(v), u))
    o[i] <- v[i] - sum(w[i] * v[i]) / sum(w[i]); o }
  f0w <- dg_wls(cbind(dm(x)), dm(y * 100), w)
  res0 <- f0w$resid

  pr1 <- (y - mu1) / sqrt(mu1 * (1 - mu1) / w)
  pr2 <- (y - mu2) / sqrt(mu2 * (1 - mu2) / w)
  list(tag = tag, n = nrow(d), n_units = nlevels(u), x = x, y = y, w = w, u = u,
       b1_slope = unname(b1["x"]), b2_slope = unname(m2$coef[ncol(X)]),
       mu1 = mu1, mu2 = mu2, mu3 = mu3, res0 = res0, m2 = m2, m3 = m3,
       lin_slope = f0w$coef[1],
       p1_lin = pearson_ratio(res0, x), p1_m1 = pearson_ratio(pr1, x),
       p1_m2 = pearson_ratio(pr2, x),
       n_out_lin = sum(dm(y * 100) + 0 * y < -1e9),  # placeholder, filled below
       stringsAsFactors = FALSE)
}

EP <- within_set(P, "part_id", "115 parts, 4,025 part-years")
dg_say("  M1 within logit slope %+.6f   M2 beta within logit slope %+.6f",
       EP$b1_slope, EP$b2_slope)
dg_say("  Pearson-residual SD ratio across water quartiles:")
dg_say("    linear (incumbent) %.3f   M1 %.3f   M2 %.3f",
       EP$p1_lin$ratio, EP$p1_m1$ratio, EP$p1_m2$ratio)

EQ <- within_set(Q, "patch_id", "93 unzoned patches, 3,253 patch-years")
dg_say("  M1 within logit slope %+.6f   M2 beta within logit slope %+.6f",
       EQ$b1_slope, EQ$b2_slope)
dg_say("    linear %.3f   M1 %.3f   M2 %.3f",
       EQ$p1_lin$ratio, EQ$p1_m1$ratio, EQ$p1_m2$ratio)

saveRDS(list(B = B, EP = EP, EQ = EQ, CVB = CVB, f0 = f0, b1B = b1B, m2B = m2B,
             mu1B = mu1B, mu2B = mu2B, XB = XB, xB = xB, yB = yB, wB = wB, clB = clB,
             SHA_B = SHA_B),
        file.path(GLM_OUT, "GLM1_state.rds"))
dg_say("")
dg_say("[state saved] GLM1_state.rds")
