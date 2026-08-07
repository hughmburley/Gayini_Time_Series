# gayini_fit.R - the one shared estimator, Ruling AS (7 August 2026).
#
# All statistical estimation lives in R from here. Python retains the spatial
# machinery and writes a checksummed analysis CSV at the boundary; this function
# reads that CSV and returns ONE TIDY ROW. It is not a package.
#
# THREE RULES BAKED IN:
#
#   1. NO P-VALUES, ANYWHERE. summary(lm) prints them by default, so summary() is
#      never called on a model object in this file. Coefficients come from coef();
#      r, residual SD and R-squared are computed explicitly from the fitted values.
#
#   2. EVERY ROW CARRIES ITS ESTIMATOR. `estimator` and `cluster` are columns, not
#      documentation. A within slope and a between slope are different quantities
#      answering different questions and must never be readable as two estimates of
#      one number.
#
#   3. R-SIDE INTERVALS ARE STABILITY CHECKS AND ARE NEVER REGISTERED. Registered
#      values stand. Nothing here writes to the database.
#
#   4. EVERY INTERVAL IS CONDITIONAL ON THE INPUTS BEING CORRECT (Ruling AW). Both
#      source products are modelled - fractional cover and the open-water
#      classification - and carry their own validation error, which nothing in this
#      project propagates. Every row therefore ships an interval_conditionality
#      column, so the qualifier travels with the number rather than living only in
#      the metadata records.
#
# The input CSV's first-50-MB SHA-256 is recorded on every row, so a result can
# always be traced to the bytes it was fitted on.

suppressPackageStartupMessages({
  library(digest)
})

gayini_sha256_first50_file <- function(path) {
  cap <- 50 * 1024 * 1024
  n <- min(file.info(path)$size, cap)
  con <- file(path, "rb"); on.exit(close(con))
  digest(readBin(con, "raw", n = n), algo = "sha256", serialize = FALSE)
}

# weighted OLS, computed rather than summarised
.wls <- function(x, y, w) {
  sw <- sum(w)
  mx <- sum(w * x) / sw
  my <- sum(w * y) / sw
  sxx <- sum(w * (x - mx)^2)
  sxy <- sum(w * (x - mx) * (y - my))
  syy <- sum(w * (y - my)^2)
  slope <- sxy / sxx
  inter <- my - slope * mx
  e <- y - (inter + slope * x)
  list(slope = slope, intercept = inter,
       r = if (sxx * syy > 0) sxy / sqrt(sxx * syy) else NA_real_,
       resid_sd = sqrt(sum(w * e^2) / sw),
       r2 = if (syy > 0) 1 - sum(w * e^2) / syy else NA_real_)
}

# within (fixed-effects) transform: subtract each unit's weighted mean from both axes
.demean <- function(d, y, x, unit, w) {
  s <- split(seq_len(nrow(d)), d[[unit]])
  for (i in s) {
    sw <- sum(d[[w]][i])
    d[[y]][i] <- d[[y]][i] - sum(d[[w]][i] * d[[y]][i]) / sw
    d[[x]][i] <- d[[x]][i] - sum(d[[w]][i] * d[[x]][i]) / sw
  }
  d
}

#' Fit one slope and return a tidy row.
#'
#' @param csv_path   analysis CSV written at the Python boundary
#' @param y,x        column names
#' @param weights    column name, or NULL for unweighted
#' @param cluster    column name to resample for the bootstrap, or NULL
#' @param unit       column identifying the panel unit; required when demean = TRUE
#' @param demean     TRUE for the WITHIN estimator (unit fixed effects)
#' @param subset     optional logical vector over the rows of the CSV
#' @param n_boot     bootstrap draws; 0 to skip
#' @param estimator  free-text label carried onto the row
gayini_fit <- function(csv_path, y, x, weights = NULL, cluster = NULL,
                       unit = NULL, demean = FALSE, subset = NULL,
                       n_boot = 2000L, seed = 20260807L,
                       estimator = if (demean) "within (unit fixed effects)" else "between (across units)",
                       label = NA_character_) {
  d <- utils::read.csv(csv_path, stringsAsFactors = FALSE)
  if (!is.null(subset)) d <- d[subset, , drop = FALSE]
  d <- d[stats::complete.cases(d[, c(y, x)]), , drop = FALSE]
  w <- if (is.null(weights)) rep(1, nrow(d)) else d[[weights]]
  d$.w <- w

  if (demean) {
    stopifnot(!is.null(unit))
    d <- .demean(d, y, x, unit, ".w")
  }
  f <- .wls(d[[x]], d[[y]], d$.w)

  # cross-check the hand-computed slope against lm(); coef() only, never summary()
  chk <- stats::coef(stats::lm(stats::as.formula(sprintf("%s ~ %s", y, x)),
                               data = d, weights = d$.w))[[2]]
  if (!isTRUE(all.equal(unname(chk), unname(f$slope), tolerance = 1e-9)))
    stop(sprintf("gayini_fit: hand-computed slope %.10f != lm() %.10f", f$slope, chk))

  qs <- c(NA_real_, NA_real_, NA_real_); nb <- 0L
  if (n_boot > 0 && !is.null(cluster)) {
    set.seed(seed)
    cl <- split(seq_len(nrow(d)), d[[cluster]])
    keys <- names(cl)
    out <- numeric(0)
    for (b in seq_len(n_boot)) {
      idx <- unlist(cl[sample(keys, length(keys), replace = TRUE)], use.names = FALSE)
      dd <- d[idx, , drop = FALSE]
      if (length(unique(dd[[x]])) < 3) next
      out <- c(out, .wls(dd[[x]], dd[[y]], dd$.w)$slope)
    }
    qs <- unname(stats::quantile(out, c(0.025, 0.5, 0.975)))
    nb <- length(out)
  }

  data.frame(
    label = label, estimator = estimator,
    y_variable = y, x_variable = x,
    weighting = if (is.null(weights)) "unweighted" else paste0("weighted by ", weights),
    cluster = if (is.null(cluster)) "none" else cluster,
    n_obs = nrow(d), n_units = if (is.null(unit)) NA_integer_ else length(unique(d[[unit]])),
    slope = f$slope, intercept = if (demean) NA_real_ else f$intercept,
    r = f$r, resid_sd = f$resid_sd, r2 = f$r2,
    boot_p2_5 = qs[1], boot_p50 = qs[2], boot_p97_5 = qs[3], boot_draws = nb,
    source_csv = basename(csv_path),
    source_sha256_first50 = gayini_sha256_first50_file(csv_path),
    interval_status = "R-side stability check - NOT registered",
    interval_conditionality = paste(
      "CONDITIONAL ON THE INPUTS BEING CORRECT (Ruling AW, 7 Aug 2026). This interval carries",
      "sampling variation only. It does NOT include the ingested products' own classification and",
      "calibration error - fractional cover and the open-water classification are modelled products",
      "with published validation error that nothing in this project propagates."),
    stringsAsFactors = FALSE)
}
