# ------------------------------------------------------------------------------
# R/gayini_monte_carlo_sampling.R
# Monte-Carlo wrapper around gayini_draw_stratified_sample (B2) + the per-draw F6
# wiring helper. Each draw uses its own seed and its own point-id namespace
# (SP_<seed>_0001) so draws never collide; outputs fan out per seed.
#
# NOT a production runner. The production 100-draw run + F6 re-run is gated on the
# Wednesday Adrian sync (final allocation). This module only provides the mechanics.
# ------------------------------------------------------------------------------

# ---- B2: seeded Monte-Carlo draw loop ----------------------------------------

gayini_draw_monte_carlo <- function(freq_8058, valid_8058, plots, communities, breaks,
                                    focus_communities, neighbourhood_radius, exclusion_buffer,
                                    min_valid_years, allocation, seeds,
                                    out_dir = NULL) {
  if (is.null(allocation)) stop("gayini_draw_monte_carlo requires an `allocation` lookup.", call. = FALSE)
  if (!is.null(out_dir)) dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

  points_list  <- list()
  summary_list <- list()

  for (i in seq_along(seeds)) {
    s <- seeds[[i]]
    id_prefix <- sprintf("SP_%s", s)                 # -> SP_<seed>_0001
    message(sprintf("[MC] draw %d/%d  seed=%s  prefix=%s", i, length(seeds), s, id_prefix))

    res <- gayini_draw_stratified_sample(
      freq_8058 = freq_8058, valid_8058 = valid_8058, plots = plots,
      communities = communities, breaks = breaks, focus_communities = focus_communities,
      neighbourhood_radius = neighbourhood_radius, exclusion_buffer = exclusion_buffer,
      n_per_stratum = NA_integer_,                   # unused when allocation is supplied
      min_valid_years = min_valid_years, seed = s,
      allocation = allocation, id_prefix = id_prefix)

    res$points$draw  <- i;  res$points$seed  <- s
    res$summary$draw <- i;  res$summary$seed <- s

    if (!is.null(out_dir)) {
      gpkg <- file.path(out_dir, sprintf("mc_sample_points_seed%s.gpkg", s))
      suppressWarnings(sf::st_write(res$points, gpkg, delete_dsn = TRUE, quiet = TRUE))
      utils::write.csv(res$summary, file.path(out_dir, sprintf("mc_sample_summary_seed%s.csv", s)),
                       row.names = FALSE)
    }
    points_list[[i]]  <- res$points
    summary_list[[i]] <- res$summary
  }

  list(points  = do.call(rbind, points_list),
       summary = dplyr::bind_rows(summary_list),
       seeds   = seeds)
}

# ---- per-draw F6 wiring -------------------------------------------------------
# Reuses the F6 pipeline (gayini_extract_point_series -> gayini_stratum_annual_series
# -> gayini_run_trend_tests) exactly as scripts/03_inundation_products/07 does, so a
# single MC draw's points flow straight into the per-stratum trend test. Requires
# R/gayini_trend_test_functions.R sourced by the caller.

gayini_f6_verdicts_for_points <- function(pts, wet_path, valid_path,
                                          focus_communities, band_levels, thresholds) {
  pts$community   <- factor(as.character(pts$community),   levels = focus_communities)
  pts$regime_band <- factor(as.character(pts$regime_band), levels = band_levels)
  pts$stratum     <- paste(as.character(pts$community), as.character(pts$regime_band), sep = " | ")
  stopifnot(all(!is.na(pts$community)), all(!is.na(pts$regime_band)))

  extraction <- gayini_extract_point_series(pts, wet_path, valid_path)
  pts_years  <- extraction$points
  series_long <- gayini_stratum_annual_series(extraction, pts_years$stratum)

  stratum_meta <- pts_years |>
    sf::st_drop_geometry() |>
    dplyr::distinct(.data$stratum, .data$community, .data$regime_band) |>
    dplyr::arrange(.data$community, .data$regime_band)

  series_long <- dplyr::left_join(series_long, stratum_meta, by = "stratum")
  trend <- gayini_run_trend_tests(series_long, stratum_meta, thresholds = thresholds)
  trend$verdict_tbl
}
