####################################################################################################


## GAYINI REMOTE SENSING PROJECT


## Tier 1 · F6 — the trend test.
##
## For each vegetation x regime stratum from the F5 frame, extract the 35-year
## annual wet/valid series at the stratum's sample points, aggregate to a single
## annual flood-frequency series (100 x wet / valid across the stratum's points),
## and ask the first real question of the ladder: does flood frequency actually
## MOVE over time — and if it moves, is that a stable directional trend or just
## the climate-driven wet/dry cycling?
##
## Three fits, shown together because they DISAGREE when the signal is episodic:
##   1. Theil-Sen slope + Mann-Kendall tau/p  — robust, non-parametric. PRIMARY.
##   2. OLS linear slope + R^2                 — reference; low R^2 exposes weakness.
##   3. LOESS smoother                         — reveals non-monotonic shape.
##
## Plus an episodic-robustness check: re-test with each stratum's two largest
## flood years dropped. If significance evaporates, the movement is carried by a
## few wet years — climate, not a stable trend.
##
## The trend tests (Mann-Kendall, Theil-Sen slope + confidence interval) are
## implemented here in base R rather than pulled from a package: it keeps the
## verdict logic auditable end-to-end ("nothing hidden") and adds no dependency.
## Never mutates a source raster: the 35-band categorical wet/valid stack is
## read-only and is NEVER resampled — only the sample POINTS are reprojected to
## the stack's CRS for exact per-cell extraction.


####################################################################################################


## 0. Verdict thresholds — OUR defaults, FLAGGED for Adrian / stats review ----
##
## Named constants so the verdict logic is auditable and a reviewer can change
## VALUES without touching logic. Echoed to the run log (see the orchestrator's
## verdict_thresholds_logged flag).

gayini_trend_thresholds <- function() {
  list(
    MK_P_ALPHA            = 0.10,   # Mann-Kendall two-sided significance cut
    N_LARGEST_FLOODS_DROP = 2L,     # episodic-robustness: drop this many biggest flood years
    TS_CI_CONF            = 0.90,   # Theil-Sen confidence level (= 1 - MK_P_ALPHA)
    LOESS_SPAN            = 0.75,   # LOESS smoother span (stats::loess default)
    LOESS_DEGREE          = 2L,     # LOESS local polynomial degree (stats::loess default)
    LOESS_MONOTONIC_FRAC  = 0.15,   # counter-directional LOESS movement must be < this fraction
                                    #   of the dominant movement to count as "monotonic"
    MIN_POINT_VALID_YEARS = 25L     # a sample point must have >= this many valid years to be used
  )
}


## Verdict vocabulary + palette (panel tint / table colour) ----

gayini_trend_verdict_levels <- function() {
  c("no_trend", "directional_trend", "non_stationary")
}

gayini_trend_verdict_labels <- function() {
  c(no_trend          = "No trend",
    directional_trend = "Directional trend",
    non_stationary    = "Non-stationary (episodic)")
}

gayini_trend_verdict_palette <- function() {
  c(no_trend          = "#9E9E9E",   # grey  — flat / inconclusive
    directional_trend = "#1A9850",   # green — a real, stable move
    non_stationary    = "#F46D43")   # amber — real movement, but cycle-driven
}


## 1. Extraction — 35-year wet/valid series at the sample points ----
##
## Water-year start (1988..2022) parsed from the stack layer names ("1988-1989").
gayini_stack_water_years <- function(layer_names) {
  as.integer(substr(as.character(layer_names), 1, 4))
}

## Reproject the POINTS to the stack's CRS (vector reprojection; the categorical
## stack is never touched) and extract the exact per-cell wet/valid value at each
## point for all 35 years. Returns:
##   points   : the input sf, in its original CRS, with a `valid_years` count of
##              valid observations across the record (for the acceptance gate);
##   years    : integer vector of water-year starts (length 35);
##   wet      : n_points x 35 integer matrix (1 wet, 0 dry, NA no obs);
##   valid    : n_points x 35 integer matrix (1 valid obs, NA/0 otherwise).
gayini_extract_point_series <- function(points, wet_path, valid_path) {

  gayini_stop_if_missing(wet_path,   label = "annual wet stack")
  gayini_stop_if_missing(valid_path, label = "annual valid stack")

  wet <- terra::rast(wet_path)
  val <- terra::rast(valid_path)
  if (terra::nlyr(wet) != terra::nlyr(val)) {
    stop("wet and valid stacks have different band counts: ",
         terra::nlyr(wet), " vs ", terra::nlyr(val), call. = FALSE)
  }
  years <- gayini_stack_water_years(names(wet))

  ## Vector reprojection to the stack CRS; the raster stack stays read-only and
  ## is NEVER resampled. Point extraction returns the value of the cell each
  ## point falls in — exact, not interpolated.
  pv <- terra::project(terra::vect(points), terra::crs(wet))

  wet_m <- as.matrix(terra::extract(wet, pv, ID = FALSE))
  val_m <- as.matrix(terra::extract(val, pv, ID = FALSE))
  storage.mode(wet_m) <- "double"
  storage.mode(val_m) <- "double"
  colnames(wet_m) <- colnames(val_m) <- as.character(years)

  ## A point-year counts as a valid observation only where valid == 1.
  is_valid <- (!is.na(val_m)) & (val_m == 1)
  points$valid_years <- as.integer(rowSums(is_valid))

  list(points = points, years = years, wet = wet_m, valid = val_m)
}


## Per stratum x year: flood frequency = 100 x wet / valid across the stratum's
## points, keeping only valid point-years. Returns a long tibble
## (stratum, community, regime_band, year, freq_pct, n_valid, n_wet).
gayini_stratum_annual_series <- function(extraction, stratum_key) {

  years <- extraction$years
  wet   <- extraction$wet
  val   <- extraction$valid
  key   <- as.character(stratum_key)

  series_rows <- lapply(sort(unique(key)), function(k) {
    rows <- which(key == k)
    is_valid <- (!is.na(val[rows, , drop = FALSE])) & (val[rows, , drop = FALSE] == 1)
    is_wet   <- is_valid & (!is.na(wet[rows, , drop = FALSE])) & (wet[rows, , drop = FALSE] == 1)
    n_valid  <- colSums(is_valid)
    n_wet    <- colSums(is_wet)
    tibble::tibble(
      stratum  = k,
      year     = years,
      n_valid  = as.integer(n_valid),
      n_wet    = as.integer(n_wet),
      freq_pct = ifelse(n_valid > 0, 100 * n_wet / n_valid, NA_real_)
    )
  })
  dplyr::bind_rows(series_rows)
}


## 2. Mann-Kendall trend test (base R, with tie correction) ----
##
## S = sum_{i<j} sign(y_j - y_i); variance uses the standard tie correction; the
## p-value is the continuity-corrected normal approximation (exact enough at
## n = 35). tau is tau-b (x = years carries no ties, so only y-ties enter).
gayini_mann_kendall <- function(y) {
  y <- as.numeric(y)
  n <- length(y)
  if (n < 3L) stop("Mann-Kendall needs >= 3 observations.", call. = FALSE)

  S <- 0
  for (k in seq_len(n - 1L)) S <- S + sum(sign(y[(k + 1L):n] - y[k]))

  ties     <- as.numeric(table(y))
  tie_term <- sum(ties * (ties - 1) * (2 * ties + 5))
  var_S    <- (n * (n - 1) * (2 * n + 5) - tie_term) / 18

  n0  <- n * (n - 1) / 2
  n1  <- sum(ties * (ties - 1) / 2)            # tied pairs in y
  tau <- if ((n0 - n1) > 0) S / sqrt((n0 - n1) * n0) else NA_real_

  z <- if (var_S <= 0) 0
       else if (S > 0)  (S - 1) / sqrt(var_S)
       else if (S < 0)  (S + 1) / sqrt(var_S)
       else 0
  p <- 2 * stats::pnorm(-abs(z))

  list(S = S, var_S = var_S, tau = tau, z = z, p = p, n = n)
}


## 3. Theil-Sen slope + confidence interval (Sen 1968, base R) ----
##
## slope = median of pairwise slopes (y_j - y_i)/(x_j - x_i); the CI uses the
## Mann-Kendall variance to pick rank order statistics of the sorted slopes
## (Gilbert 1987). `ci_spans_zero` is one of the two no-trend triggers.
gayini_theil_sen <- function(x, y, conf = 0.90, var_S = NULL) {
  x <- as.numeric(x); y <- as.numeric(y)
  n <- length(y)
  if (n < 3L) stop("Theil-Sen needs >= 3 observations.", call. = FALSE)

  ij <- utils::combn(n, 2)
  dx <- x[ij[2, ]] - x[ij[1, ]]
  dy <- y[ij[2, ]] - y[ij[1, ]]
  slopes <- (dy / dx)[dx != 0 & is.finite(dy / dx)]
  slope     <- stats::median(slopes)
  intercept <- stats::median(y - slope * x)

  if (is.null(var_S)) var_S <- gayini_mann_kendall(y)$var_S
  N <- length(slopes)
  C <- stats::qnorm(1 - (1 - conf) / 2) * sqrt(var_S)
  ss <- sort(slopes)
  rank_lo <- max(1L, min(N, round((N - C) / 2)))
  rank_up <- max(1L, min(N, round((N + C) / 2) + 1L))
  lower <- ss[rank_lo]
  upper <- ss[rank_up]

  list(slope = slope, intercept = intercept, lower = lower, upper = upper,
       ci_spans_zero = (lower <= 0 && upper >= 0), n_slopes = N)
}


## 4. OLS linear fit — reference only ----
gayini_ols_fit <- function(x, y) {
  fit <- stats::lm(y ~ x)
  sm  <- summary(fit)
  list(
    slope     = unname(stats::coef(fit)[2]),
    intercept = unname(stats::coef(fit)[1]),
    r2        = sm$r.squared,
    p         = if (nrow(sm$coefficients) >= 2) sm$coefficients[2, 4] else NA_real_
  )
}


## 5. LOESS smoother + monotonicity of its shape ----
##
## Fit a LOESS smoother and predict on a dense year grid. The curve is called
## "monotonic" if the counter-directional movement is a small fraction
## (LOESS_MONOTONIC_FRAC) of the dominant movement; otherwise "non-monotonic"
## (rise-then-fall, steps, cycles). `direction` is increasing/decreasing when
## monotonic, else "non_monotonic".
gayini_loess_shape <- function(x, y, span = 0.75, degree = 2L, monotonic_frac = 0.15) {
  x <- as.numeric(x); y <- as.numeric(y)
  fit  <- stats::loess(y ~ x, span = span, degree = degree)
  xg   <- seq(min(x), max(x), length.out = 100)
  pred <- as.numeric(stats::predict(fit, newdata = data.frame(x = xg)))

  d      <- diff(pred)
  up     <- sum(d[d > 0])
  down   <- -sum(d[d < 0])
  primary <- max(up, down)
  counter <- min(up, down)
  monotonic <- primary == 0 || (counter <= monotonic_frac * primary)
  direction <- if (!monotonic) "non_monotonic"
               else if (up >= down) "increasing" else "decreasing"

  list(pred_x = xg, pred_y = pred, direction = direction, monotonic = monotonic,
       net_change = pred[length(pred)] - pred[1])
}


## 6. Per-stratum verdict — assemble the three fits + episodic-robustness ----
##
## `series` is one stratum's annual tibble (year, freq_pct, n_valid). Returns a
## one-row verdict tibble plus the fitted objects the data figure draws.
gayini_stratum_trend_verdict <- function(series, thresholds = gayini_trend_thresholds()) {

  s <- series[!is.na(series$freq_pct), ]
  s <- s[order(s$year), ]
  x <- s$year; y <- s$freq_pct

  ## Full-series fits.
  mk  <- gayini_mann_kendall(y)
  ts  <- gayini_theil_sen(x, y, conf = thresholds$TS_CI_CONF, var_S = mk$var_S)
  ols <- gayini_ols_fit(x, y)
  lo  <- gayini_loess_shape(x, y, span = thresholds$LOESS_SPAN,
                            degree = thresholds$LOESS_DEGREE,
                            monotonic_frac = thresholds$LOESS_MONOTONIC_FRAC)

  ## Episodic-robustness: drop the two largest flood years and re-test.
  n_drop      <- thresholds$N_LARGEST_FLOODS_DROP
  drop_idx    <- order(y, decreasing = TRUE)[seq_len(min(n_drop, length(y)))]
  dropped_years <- sort(x[drop_idx])
  keep        <- setdiff(seq_along(y), drop_idx)
  mk_drop     <- gayini_mann_kendall(y[keep])
  ts_drop     <- gayini_theil_sen(x[keep], y[keep], conf = thresholds$TS_CI_CONF,
                                  var_S = mk_drop$var_S)

  alpha <- thresholds$MK_P_ALPHA
  sig_full  <- mk$p < alpha
  ## Flood-drop arbiter (reported as its own column): does the Mann-Kendall signal
  ## SURVIVE dropping the two biggest flood years? This is the principled episodic
  ## test — a movement carried by a handful of wet years evaporates here. Kept
  ## PURE (just the drop-2 significance) so it is not conflated with the separate
  ## slope-degeneracy check below.
  flood_drop_robust <- mk_drop$p < alpha

  ## LOESS agrees with the trend direction (only meaningful if monotonic + a
  ## non-degenerate slope; a degenerate slope of 0 fails both branches).
  loess_dir_matches <- lo$monotonic &&
    ((lo$direction == "increasing" && ts$slope > 0) ||
     (lo$direction == "decreasing" && ts$slope < 0))

  ## Verdict — Mann-Kendall (primary) decides whether there is DETECTABLE movement;
  ## the flood-drop check, the slope, and the LOESS shape then decide whether that
  ## movement is DIRECTIONAL or merely NON-STATIONARY. Theil-Sen CI-spanning-0 is
  ## NOT an independent no-trend gate (the spec's contradictory clause): the
  ## series are zero-inflated, so the median pairwise slope can be a degenerate 0
  ## while MK legitimately detects late-clustered floods. CI-spans-0 therefore
  ## discriminates directional-vs-episodic, it does not override MK.
  ##   - MK not significant                                   -> no_trend
  ##   - MK significant AND flood-drop-robust AND slope non-
  ##     degenerate (CI excludes 0) AND LOESS monotonic same
  ##     direction                                            -> directional_trend
  ##   - MK significant otherwise (signal collapses when the two
  ##     biggest floods are dropped, OR slope degenerate, OR
  ##     shape non-monotonic)                                 -> non_stationary
  verdict <- if (!sig_full) {
    "no_trend"
  } else if (flood_drop_robust && !ts$ci_spans_zero && loess_dir_matches) {
    "directional_trend"
  } else {
    "non_stationary"
  }

  row <- tibble::tibble(
    stratum            = s$stratum[1],
    n_years            = length(y),
    theil_sen_slope    = ts$slope,
    theil_sen_lo       = ts$lower,
    theil_sen_hi       = ts$upper,
    ci_spans_zero      = ts$ci_spans_zero,
    mk_tau             = mk$tau,
    mk_p               = mk$p,
    ols_slope          = ols$slope,
    ols_r2             = ols$r2,
    loess_direction    = lo$direction,
    loess_monotonic    = lo$monotonic,
    mk_p_drop2floods   = mk_drop$p,
    theil_sen_slope_drop2 = ts_drop$slope,
    flood_drop_robust  = flood_drop_robust,
    dropped_flood_years = paste(dropped_years, collapse = " & "),
    verdict            = factor(verdict, levels = gayini_trend_verdict_levels())
  )

  list(
    row           = row,
    fit           = list(ts = ts, ols = ols, loess = lo),
    dropped_years = dropped_years,
    series        = s
  )
}


## 7. Run the trend test across all strata ----
##
## `series_long` is the stacked per-stratum annual tibble from
## gayini_stratum_annual_series(); `stratum_meta` maps stratum key ->
## community + regime_band (for ordering / figure facets). Returns the verdict
## table and a named list of per-stratum fit objects.
gayini_run_trend_tests <- function(series_long, stratum_meta,
                                    thresholds = gayini_trend_thresholds()) {

  keys <- stratum_meta$stratum
  fits <- list()
  rows <- list()
  for (k in keys) {
    ser <- series_long[series_long$stratum == k, ]
    res <- gayini_stratum_trend_verdict(ser, thresholds = thresholds)
    fits[[k]] <- res
    rows[[k]] <- res$row
  }

  verdict_tbl <- dplyr::bind_rows(rows) |>
    dplyr::left_join(stratum_meta, by = "stratum") |>
    dplyr::relocate("community", "regime_band", .after = "stratum")

  list(verdict_tbl = verdict_tbl, fits = fits, thresholds = thresholds)
}
