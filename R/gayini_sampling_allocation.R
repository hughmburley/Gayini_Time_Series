# ------------------------------------------------------------------------------
# R/gayini_sampling_allocation.R
# Per-stratum draw-size allocation (community x regime_band -> target_n).
#
# Single source of truth for BOTH the F5 draw (gayini_draw_stratified_sample) and
# the census acceptance gate. The numbers are DERIVED from a documented budget /
# floor / cap, never hardcoded, so the Wednesday allocation decision (Q1/Q3a) is a
# PARAMETER change (method / budget / min_n), not a code edit.
#
#   method = "equal"        -> n_equal for every stratum (the current design).
#   method = "proportional" -> min_n to every stratum, then the remaining budget
#                              split in proportion to `size` (largest-remainder,
#                              integer), optionally capped at max_n.
#
# `sizes` is a data.frame with columns: community, regime_band, size  (size = a
# positive per-stratum measure -- e.g. census n_pixels, area_ha, or the near-plot
# candidate pool; WHICH basis is the Q1 near-plot-vs-community-wide choice).
# ------------------------------------------------------------------------------

gayini_stratum_allocation <- function(sizes,
                                      method  = c("equal", "proportional"),
                                      n_equal = 40L,
                                      budget  = NULL,
                                      min_n   = NULL,
                                      max_n   = NULL) {
  method <- match.arg(method)
  stopifnot(all(c("community", "regime_band", "size") %in% names(sizes)), nrow(sizes) >= 1L)

  out <- data.frame(
    community   = as.character(sizes$community),
    regime_band = as.character(sizes$regime_band),
    size        = as.numeric(sizes$size),
    stringsAsFactors = FALSE
  )
  k <- nrow(out)

  if (method == "equal") {
    out$target_n <- as.integer(rep(n_equal, k))
    out$basis    <- sprintf("equal(n=%d)", as.integer(n_equal))
    out$cap_binds <- rep(FALSE, k)
    return(out)
  }

  ## proportional
  if (is.null(budget)) stop("proportional allocation needs a `budget` (total points).", call. = FALSE)
  fl <- if (is.null(min_n)) 0L else as.integer(min_n)
  if (fl * k > budget) {
    stop(sprintf("min_n %d x %d strata (%d) exceeds budget %d.", fl, k, fl * k, budget), call. = FALSE)
  }
  if (any(out$size <= 0)) stop("all `size` values must be > 0 for proportional allocation.", call. = FALSE)

  remaining <- budget - fl * k
  w         <- out$size / sum(out$size)
  raw       <- remaining * w
  base      <- floor(raw)
  leftover  <- remaining - sum(base)
  ## largest-remainder: the `leftover` strata with the biggest fractional parts get +1
  add <- integer(k)
  if (leftover > 0L) add[order(raw - base, decreasing = TRUE)[seq_len(leftover)]] <- 1L
  target <- fl + as.integer(base) + add

  capped <- rep(FALSE, k)
  if (!is.null(max_n)) {
    over <- target > max_n
    capped <- over
    target[over] <- as.integer(max_n)   # capped points are NOT redistributed here (flagged)
  }

  out$target_n  <- as.integer(target)
  out$basis     <- sprintf("proportional(budget=%d, min_n=%d, max_n=%s)",
                           budget, fl, if (is.null(max_n)) "none" else as.character(max_n))
  out$cap_binds <- capped
  out
}
