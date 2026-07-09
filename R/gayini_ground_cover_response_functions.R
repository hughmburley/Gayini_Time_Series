####################################################################################################


## GAYINI REMOTE SENSING PROJECT


## Tier 1 · F7 — the ground-cover response test (the primary analytical rung of
## the reshaped Phase D).
##
## F6 shut the gate: no stratum shows a directional trend — the system is
## flood-pulse driven, not trending. F7 asks the one live question: within each
## vegetation x flood-regime stratum, does ground cover RESPOND to the flood
## pulses? This is descriptive support, not a trend / surface / driver analysis,
## and it does not reopen the gate. "Weak or no response" is a legitimate result.
##
## Two reads, simplest first, nothing hidden:
##   1. Same-year within-plot response (PRIMARY) — per plot, Pearson r + OLS slope
##      of ground cover on the wet-extent intensity across its valid years;
##      summarised to community and to community x regime band, with a plot-level
##      bootstrap CI on each stratum's median r.
##   2. Monthly lag profile (SECONDARY) — per plot x lag correlation of monthly
##      cover on monthly inundation intensity at t - lag, summarised to a
##      per-community median at each lag (supersedes script 10).
##
## METRIC DISCIPLINE (do not blur): the HEADLINE between-year flood frequency
## defines each plot's STRATUM (via the F5 surface + F5 tercile breaks); the
## labelled SECONDARY "wet-extent" intensity metric CARRIES the response. On the
## same-year read the intensity regressor is `annual_occurrence_pct` (spine); on
## the lag read it is `mean_daily_inundated_pct` (sub-annual). Never present the
## response axis as the headline.
##
## ONE VEGETATION SCHEME: the 4-class `simplified_vegetation_group` (join
## dim_plot). The sub-annual tables only carry the legacy 5-class
## `vegetation_adrian_group` and a `period` (pre/post) column — both are DROPPED.
## Focus is the three non-treed communities; treed / cover-excluded plots are out.
##
## Strata are the F5 strata BY CONSTRUCTION — each plot's band comes from the F5
## background flood-frequency surface + F5 tercile breaks, so F5 -> F6 -> F7 read
## as one family. Only this plot -> band assignment touches a raster; everything
## else is DB-first.


####################################################################################################


## 0. Tunable defaults — OUR decisions, FLAGGED for Adrian Q3 ----
##
## Named constants so masks + verdict logic are auditable and a reviewer can
## change VALUES without touching logic. Echoed to the run log (see the
## orchestrator's f7_thresholds_logged flag). Adrian's Q3(a) answer changes the
## valid-coverage value, not the logic.

gayini_f7_thresholds <- function() {
  list(
    MIN_VALID_COVERAGE   = 40,                  # Q3a: keep plot-years with annual_valid_coverage_pct >= this
    MIN_PLOT_VALID_YEARS = 4L,                  # a plot needs >= this many valid years for a same-year fit
    MIN_MONTH_OBS        = 3L,                  # keep months with n_daily_observations >= this
    MIN_LAG_PAIRS        = 6L,                  # require this many paired months per plot x lag
    MONTHLY_LAGS         = c(0L, 3L, 6L, 9L, 12L),  # cover at t vs inundation intensity at t - lag
    ANNUAL_LAGS          = c(0L, 1L),           # coarse annual cross-check
    R_RESPOND            = 0.20,                 # stratum median r must reach this to "respond"
    SIGN_FRAC            = 0.70,                 # ... and this fraction of plots must share the sign
    N_BOOT               = 2000L,               # bootstrap resamples for the stratum-median CI
    BOOT_CONF            = 0.95,                 # bootstrap CI confidence level
    SEED                 = 20260709L            # reproducibility (bootstrap CIs)
  )
}


## Response verdict vocabulary + palette (panel tint / table colour) ----

gayini_f7_verdict_levels <- function() c("responds", "weak_or_none", "mixed")

gayini_f7_verdict_labels <- function() {
  c(responds     = "Responds",
    weak_or_none = "Weak / no clear response",
    mixed        = "Mixed (sign-inconsistent)")
}

gayini_f7_verdict_palette <- function() {
  c(responds     = "#1A9850",   # green — cover tracks the pulses
    weak_or_none = "#9E9E9E",   # grey  — flat / inconclusive
    mixed        = "#F46D43")   # amber — plots disagree in sign
}

## Response variables: the headline cover response (total veg) + its mirror
## (bare ground, expected negative) + the mechanistic PV/NPV split.
gayini_f7_response_vars <- function() {
  c(veg  = "mean_total_veg_pct",
    bare = "mean_bare_ground_pct",
    pv   = "mean_pv_pct",
    npv  = "mean_npv_pct")
}


## Small date helpers (month flooring + calendar-safe month arithmetic) ----
## Re-implemented here so F7 is self-contained (the retired script 10 carried
## equivalents); no lubridate dependency.

gayini_f7_month_start <- function(date) {
  as.Date(sprintf("%s-01", format(as.Date(date), "%Y-%m")))
}

gayini_f7_add_months <- function(date, n_months) {
  date <- as.Date(date)
  mi <- as.integer(format(date, "%Y")) * 12L + as.integer(format(date, "%m")) - 1L + n_months
  as.Date(sprintf("%04d-%02d-01", mi %/% 12L, mi %% 12L + 1L))
}


## 1. Assign each non-treed plot its F5 stratum ----
##
## Extract the F5 background flood-frequency surface at each dim_plot centroid,
## then apply the per-community tercile breaks (regime_band_breaks.csv, the exact
## F5 breaks) to band it low / mid / high. The centroid layer is GDA2020 /
## Australian Albers (EPSG:9473, per the results-DB build); the vector is
## reprojected to the raster CRS — the surface is read-only and never resampled.
gayini_f7_assign_plot_strata <- function(dim_plot, freq_raster_path, breaks_csv_path,
                                         focus_communities = gayini_focus_levels(),
                                         centroid_crs = "EPSG:9473") {

  gayini_stop_if_missing(freq_raster_path, label = "F5 background flood-frequency surface")
  gayini_stop_if_missing(breaks_csv_path,  label = "F5 regime-band tercile breaks")

  nt <- dim_plot |>
    dplyr::filter(.data$treed_plot_flag == 0,
                  .data$ground_cover_exclusion_flag == 0,
                  as.character(.data$simplified_vegetation_group) %in% focus_communities)

  freq <- terra::rast(freq_raster_path)
  pv   <- terra::project(
    terra::vect(as.matrix(nt[, c("centroid_x", "centroid_y")]), type = "points", crs = centroid_crs),
    terra::crs(freq)
  )
  nt$background_flood_freq <- terra::extract(freq, pv, ID = FALSE)[, 1]

  breaks <- readr::read_csv(breaks_csv_path, show_col_types = FALSE)
  nt$regime_band <- vapply(seq_len(nrow(nt)), function(i) {
    b <- breaks[breaks$community == as.character(nt$simplified_vegetation_group[i]), ]
    if (nrow(b) != 1) stop("No F5 tercile breaks for community: ",
                           nt$simplified_vegetation_group[i], call. = FALSE)
    gayini_assign_regime_band(nt$background_flood_freq[i],
                              c(b$freq_min_pct, b$tercile_1_pct, b$tercile_2_pct, b$freq_max_pct))
  }, character(1))

  out <- tibble::tibble(
    plot_id               = nt$plot_id,
    community             = factor(as.character(nt$simplified_vegetation_group), levels = focus_communities),
    regime_band           = factor(nt$regime_band, levels = gayini_regime_band_levels()),
    background_flood_freq = nt$background_flood_freq
  ) |>
    dplyr::arrange(.data$community, .data$regime_band, .data$plot_id)

  if (any(is.na(out$regime_band)))
    stop("Some plots did not receive a regime band (NA extraction?).", call. = FALSE)

  out
}


## 2. Same-year within-plot response (PRIMARY) ----
##
## From the spine, non-treed, valid-coverage-masked: per plot, correlation +
## OLS slope of each ground-cover response variable on the wet-extent intensity
## (`annual_occurrence_pct`) across the plot's valid years. Plots with fewer than
## MIN_PLOT_VALID_YEARS valid years or zero intensity variance are dropped (and
## logged). Returns one row per plot with r/slope per response variable.
gayini_f7_same_year_response <- function(spine, plot_stratum,
                                         thresholds = gayini_f7_thresholds()) {

  resp_vars <- gayini_f7_response_vars()
  focus     <- gayini_focus_levels()

  d <- spine |>
    dplyr::filter(.data$treed_plot_flag == 0,
                  .data$ground_cover_exclusion_flag == 0,
                  as.character(.data$simplified_vegetation_group) %in% focus,
                  .data$annual_valid_coverage_pct >= thresholds$MIN_VALID_COVERAGE)

  fit_one <- function(df) {
    x <- df$annual_occurrence_pct
    n <- sum(!is.na(x))
    usable <- n >= thresholds$MIN_PLOT_VALID_YEARS && stats::var(x, na.rm = TRUE) > 0
    row <- tibble::tibble(n_valid_years = n, usable = usable)
    for (nm in names(resp_vars)) {
      y  <- df[[resp_vars[[nm]]]]
      ok <- !is.na(x) & !is.na(y)
      has_var <- sum(ok) >= thresholds$MIN_PLOT_VALID_YEARS &&
        stats::var(x[ok]) > 0 && stats::var(y[ok]) > 0
      row[[paste0("r_", nm)]]     <- if (usable && has_var) stats::cor(x[ok], y[ok]) else NA_real_
      row[[paste0("slope_", nm)]] <- if (usable && has_var)
        unname(stats::coef(stats::lm(y[ok] ~ x[ok]))[2]) else NA_real_
    }
    row
  }

  per_plot <- d |>
    dplyr::group_by(.data$plot_id) |>
    dplyr::group_modify(~ fit_one(.x)) |>
    dplyr::ungroup()

  ## Attach stratum (community x band). Plots absent from the spine mask keep the
  ## band from plot_stratum but carry no fit (usable = FALSE / NA r).
  response_by_plot <- plot_stratum |>
    dplyr::left_join(per_plot, by = "plot_id") |>
    dplyr::mutate(
      simplified_vegetation_group = .data$community,
      n_valid_years = dplyr::coalesce(.data$n_valid_years, 0L),
      usable        = dplyr::coalesce(.data$usable, FALSE)
    )

  dropped <- response_by_plot |> dplyr::filter(!.data$usable)
  if (nrow(dropped) > 0) {
    message(sprintf("Same-year response: %d of %d non-treed plots dropped (< %d valid years or zero variance):",
                    nrow(dropped), nrow(response_by_plot), thresholds$MIN_PLOT_VALID_YEARS))
    message(paste0("  ", paste(sprintf("%s (%s, %d yr)", dropped$plot_id,
                                       as.character(dropped$regime_band), dropped$n_valid_years),
                               collapse = "; ")))
  }

  response_by_plot
}


## Plot-level bootstrap CI on a stratum's median r. Resample plots (rows) with
## replacement N_BOOT times; take the median each time; percentile CI. Deterministic
## given the caller has set the seed. Returns c(lower, upper); NA if < 2 plots.
gayini_f7_boot_median_ci <- function(r, n_boot, conf = 0.95) {
  r <- r[!is.na(r)]
  if (length(r) < 2) return(c(lower = NA_real_, upper = NA_real_))
  meds <- replicate(n_boot, stats::median(sample(r, length(r), replace = TRUE)))
  q <- stats::quantile(meds, c((1 - conf) / 2, 1 - (1 - conf) / 2), names = FALSE, na.rm = TRUE)
  c(lower = q[1], upper = q[2])
}


## Per-group summary of the per-plot response distribution: median r (veg & bare),
## mean slope, sign-consistency fraction (share of plots with positive veg r), and
## the bootstrap CI on the median veg r. `by` selects the grouping ("community" or
## "stratum"). The response VERDICT is applied here for the stratum grouping.
gayini_f7_summarise_response <- function(response_by_plot, by = c("stratum", "community"),
                                         thresholds = gayini_f7_thresholds()) {
  by <- match.arg(by)
  group_cols <- if (by == "community") "community" else c("community", "regime_band")

  usable <- response_by_plot |> dplyr::filter(.data$usable)

  ## Deterministic bootstrap: fix the seed once, then walk groups in a fixed order.
  set.seed(thresholds$SEED)
  keyed <- usable |>
    dplyr::arrange(dplyr::across(dplyr::all_of(group_cols))) |>
    dplyr::group_by(dplyr::across(dplyr::all_of(group_cols)))

  summ <- keyed |>
    dplyr::summarise(
      n_plots        = dplyr::n(),
      median_r_veg   = stats::median(.data$r_veg,  na.rm = TRUE),
      median_r_bare  = stats::median(.data$r_bare, na.rm = TRUE),
      median_r_pv    = stats::median(.data$r_pv,   na.rm = TRUE),
      median_r_npv   = stats::median(.data$r_npv,  na.rm = TRUE),
      mean_slope_veg = mean(.data$slope_veg, na.rm = TRUE),
      sign_frac_pos  = mean(.data$r_veg > 0, na.rm = TRUE),
      .groups = "drop"
    )

  ## Bootstrap CI per group (re-walk in the same fixed order after the single seed).
  ci <- usable |>
    dplyr::arrange(dplyr::across(dplyr::all_of(group_cols))) |>
    dplyr::group_by(dplyr::across(dplyr::all_of(group_cols))) |>
    dplyr::group_modify(function(df, key) {
      b <- gayini_f7_boot_median_ci(df$r_veg, thresholds$N_BOOT, thresholds$BOOT_CONF)
      tibble::tibble(ci_lo_veg = b[["lower"]], ci_hi_veg = b[["upper"]])
    }) |>
    dplyr::ungroup()

  summ <- summ |> dplyr::left_join(ci, by = group_cols)

  ## Verdict (stratum grouping): responds / weak_or_none / mixed. Named-constant
  ## thresholds, mirroring the F6 verdict pattern; descriptive, not over-claimed.
  ##   responds     : median veg r >= R_RESPOND AND sign-consistent positive
  ##                  (>= SIGN_FRAC positive) AND bootstrap CI excludes 0 (lo > 0)
  ##   mixed        : plots disagree in sign (sign_frac strictly between the two cuts)
  ##   weak_or_none : otherwise (consistent but too small, or CI spans 0)
  verdict_of <- function(median_r, sign_frac, ci_lo) {
    if (!is.na(median_r) && !is.na(ci_lo) &&
        median_r >= thresholds$R_RESPOND && sign_frac >= thresholds$SIGN_FRAC && ci_lo > 0) {
      "responds"
    } else if (!is.na(sign_frac) &&
               sign_frac > (1 - thresholds$SIGN_FRAC) && sign_frac < thresholds$SIGN_FRAC) {
      "mixed"
    } else {
      "weak_or_none"
    }
  }
  summ$verdict <- factor(
    mapply(verdict_of, summ$median_r_veg, summ$sign_frac_pos, summ$ci_lo_veg),
    levels = gayini_f7_verdict_levels()
  )

  summ |>
    dplyr::arrange(dplyr::across(dplyr::all_of(group_cols)))
}


## 3. Monthly lag profile (SECONDARY) ----
##
## Join monthly ground cover (mean per plot-month from date_midpoint) to monthly
## inundation intensity at month t - lag, via dim_plot for the 4-class group.
## DROPS `period` and `vegetation_adrian_group`. Per plot x lag correlation
## (require MIN_LAG_PAIRS paired months); summarised to a per-community median at
## each lag; the community's peak lag is the lag maximising that median. This
## supersedes scripts/10_downstream_optional/01_lag_diagnostics_inundation_gc.R.
gayini_f7_monthly_lag_profile <- function(gc_timeseries, daily_monthly, dim_plot,
                                          thresholds = gayini_f7_thresholds()) {

  focus <- gayini_focus_levels()

  ## 4-class group + focus flags ONLY (drops the 5-class + period scaffolding).
  plot_group <- dim_plot |>
    dplyr::transmute(
      plot_id,
      simplified_vegetation_group = factor(as.character(.data$simplified_vegetation_group),
                                           levels = gayini_gradient_levels()),
      treed_plot_flag,
      ground_cover_exclusion_flag
    )

  ## Monthly ground cover: mean total-veg per plot-month.
  gc_month <- gc_timeseries |>
    dplyr::transmute(
      plot_id,
      month_start   = gayini_f7_month_start(.data$date_midpoint),
      total_veg_pct = as.numeric(.data$total_veg_pct)
    ) |>
    dplyr::group_by(.data$plot_id, .data$month_start) |>
    dplyr::summarise(total_veg_pct = mean(.data$total_veg_pct, na.rm = TRUE), .groups = "drop")

  ## Monthly inundation intensity, month-support masked.
  inun_month <- daily_monthly |>
    dplyr::transmute(
      plot_id,
      month_start              = as.Date(.data$month_start),
      mean_daily_inundated_pct = as.numeric(.data$mean_daily_inundated_pct),
      n_daily_observations     = as.integer(.data$n_daily_observations)
    ) |>
    dplyr::filter(.data$n_daily_observations >= thresholds$MIN_MONTH_OBS)

  ## Lag pairs: cover at month t vs inundation intensity at t - lag.
  lag_pairs <- dplyr::bind_rows(lapply(thresholds$MONTHLY_LAGS, function(L) {
    gc_month |>
      dplyr::mutate(lag_months = L,
                    inun_month_start = gayini_f7_add_months(.data$month_start, -L)) |>
      dplyr::inner_join(
        inun_month |> dplyr::select("plot_id",
                                    inun_month_start = "month_start",
                                    "mean_daily_inundated_pct"),
        by = c("plot_id", "inun_month_start")
      )
  })) |>
    dplyr::inner_join(plot_group, by = "plot_id") |>
    dplyr::filter(.data$treed_plot_flag == 0,
                  .data$ground_cover_exclusion_flag == 0,
                  as.character(.data$simplified_vegetation_group) %in% focus)

  ## Per plot x lag correlation (descriptive; require enough paired months).
  per_plot_lag <- lag_pairs |>
    dplyr::group_by(.data$plot_id, .data$simplified_vegetation_group, .data$lag_months) |>
    dplyr::summarise(
      n_pairs = sum(!is.na(.data$total_veg_pct) & !is.na(.data$mean_daily_inundated_pct)),
      r = if (n_pairs >= thresholds$MIN_LAG_PAIRS &&
              stats::sd(.data$total_veg_pct, na.rm = TRUE) > 0 &&
              stats::sd(.data$mean_daily_inundated_pct, na.rm = TRUE) > 0) {
        stats::cor(.data$total_veg_pct, .data$mean_daily_inundated_pct, use = "complete.obs")
      } else NA_real_,
      .groups = "drop"
    )

  ## Per-community median correlation at each lag — full community x lag grid so
  ## every lag appears even where a community is thin.
  grid <- tidyr::expand_grid(
    simplified_vegetation_group = factor(focus, levels = gayini_gradient_levels()),
    lag_months = thresholds$MONTHLY_LAGS
  )
  lag_profile <- grid |>
    dplyr::left_join(
      per_plot_lag |>
        dplyr::group_by(.data$simplified_vegetation_group, .data$lag_months) |>
        dplyr::summarise(
          n_plots    = sum(!is.na(.data$r)),
          median_r   = stats::median(.data$r, na.rm = TRUE),
          q25_r      = stats::quantile(.data$r, 0.25, na.rm = TRUE, names = FALSE),
          q75_r      = stats::quantile(.data$r, 0.75, na.rm = TRUE, names = FALSE),
          .groups = "drop"
        ),
      by = c("simplified_vegetation_group", "lag_months")
    ) |>
    dplyr::mutate(
      n_plots  = dplyr::coalesce(.data$n_plots, 0L),
      median_r = ifelse(is.nan(.data$median_r), NA_real_, .data$median_r)
    ) |>
    dplyr::arrange(.data$simplified_vegetation_group, .data$lag_months)

  ## Peak lag per community (lag maximising the community median r).
  peak_lag <- lag_profile |>
    dplyr::filter(!is.na(.data$median_r)) |>
    dplyr::group_by(.data$simplified_vegetation_group) |>
    dplyr::slice_max(.data$median_r, n = 1, with_ties = FALSE) |>
    dplyr::ungroup() |>
    dplyr::transmute(.data$simplified_vegetation_group,
                     peak_lag_months = .data$lag_months,
                     peak_median_r   = .data$median_r)

  list(lag_pairs = lag_pairs, per_plot_lag = per_plot_lag,
       lag_profile = lag_profile, peak_lag = peak_lag)
}
