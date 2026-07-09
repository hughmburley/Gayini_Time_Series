####################################################################################################


## GAYINI REMOTE SENSING PROJECT


## Tier 1 · F5 — the stratified sampling frame.
##
## Builds, in order:
##   1. a STATIC background flood-frequency surface (the headline between-year
##      metric, spatially: 100 x sum(wet_any) / sum(valid_any) across 35 years),
##      computed in native EPSG:28355 then reprojected (continuous -> bilinear)
##      to EPSG:8058. This is a stratification SUBSTRATE + descriptive map, NOT
##      the F8/F9 trend or probability surface.
##   2. within-community regime bands (terciles of the surface) for the three
##      non-treed focus communities.
##   3. a plot-neighbourhood sampling frame (2 km around plots, clipped to the
##      plot's own community, footprint + buffer excluded) intersected with the
##      regime bands.
##   4. a stratified random sample of points per community x regime band.
##
## Never mutates a source raster: the 35-band wet/valid stack is read-only and
## the categorical bands are NEVER resampled. Only the derived CONTINUOUS
## frequency surface is reprojected (bilinear); the derived valid-year COUNT is
## reprojected with nearest neighbour so the >= MIN_VALID_YEARS support test
## stays exact.


####################################################################################################


## Regime-band vocabulary + palette ----

## Warm ramp: reads clearly as points drawn on the blue flood-frequency surface.
gayini_regime_band_levels <- function() c("low", "mid", "high")

gayini_regime_band_palette <- function() {
  c(low = "#FEE08B", mid = "#F46D43", high = "#7F0000")
}

## Sequential blue ramp for the background flood-frequency surface (0 -> 100%).
gayini_flood_frequency_ramp <- function() {
  c("#F7FBFF", "#DEEBF7", "#C6DBEF", "#9ECAE1", "#6BAED6",
    "#4292C6", "#2171B5", "#08519C", "#08306B")
}


## 1. Background flood-frequency surface ----
##
## freq = 100 * sum(wet_any) / sum(valid_any) per pixel, across the 35 years,
## in native EPSG:28355. Support mask keeps only pixels with
## >= min_valid_years of valid observations. The continuous surface is then
## reprojected to `target` with BILINEAR; the valid-year count is reprojected
## with NEAREST (kept as an exact integer support layer for later point tests).

gayini_background_flood_frequency <- function(wet_path,
                                              valid_path,
                                              min_valid_years,
                                              target  = 8058L,
                                              out_tif = NULL) {

  gayini_stop_if_missing(wet_path,   label = "annual wet stack")
  gayini_stop_if_missing(valid_path, label = "annual valid stack")

  wet <- terra::rast(wet_path)
  val <- terra::rast(valid_path)

  if (terra::nlyr(wet) != terra::nlyr(val)) {
    stop("wet and valid stacks have different band counts: ",
         terra::nlyr(wet), " vs ", terra::nlyr(val), call. = FALSE)
  }
  n_years <- terra::nlyr(wet)

  ## Per-pixel counts across the 35 bands (NA years skipped). wet is a subset of
  ## valid by the Tier-0 wet-rule, so freq is bounded to [0, 100].
  wet_count   <- terra::app(wet, fun = "sum", na.rm = TRUE)
  valid_count <- terra::app(val, fun = "sum", na.rm = TRUE)

  ## Cells never validly observed -> NA (so they never enter the denominator or
  ## the support/retention accounting).
  valid_count <- terra::ifel(valid_count == 0, NA, valid_count)
  names(valid_count) <- "valid_years"

  freq <- 100 * wet_count / valid_count
  names(freq) <- "background_flood_freq"

  ## Support mask: only pixels with >= min_valid_years of valid years.
  freq_supported <- terra::ifel(valid_count >= min_valid_years, freq, NA)

  n_observed  <- as.numeric(terra::global(valid_count, "notNA")[[1]])
  n_supported <- as.numeric(terra::global(valid_count >= min_valid_years, "sum", na.rm = TRUE)[[1]])
  pct_retained <- 100 * n_supported / n_observed

  ## Reproject: continuous surface -> bilinear; integer support count -> nearest.
  tcrs <- if (is.numeric(target)) paste0("EPSG:", target) else target
  freq_8058  <- terra::project(freq_supported, tcrs, method = "bilinear")
  valid_8058 <- terra::project(valid_count,    tcrs, method = "near")
  names(freq_8058)  <- "background_flood_freq"
  names(valid_8058) <- "valid_years"

  if (!is.null(out_tif)) {
    dir.create(dirname(out_tif), recursive = TRUE, showWarnings = FALSE)
    terra::writeRaster(freq_8058, out_tif, overwrite = TRUE)
    message("Wrote: ", out_tif)
  }

  list(
    freq_28355   = freq_supported,
    freq_8058    = freq_8058,
    valid_8058   = valid_8058,
    n_years      = n_years,
    n_observed   = n_observed,
    n_supported  = n_supported,
    pct_retained = pct_retained
  )
}


## 2. Within-community regime bands (terciles) ----
##
## For each focus community, mask the frequency surface to the community polygon
## and compute within-community terciles. Returns, per community, the four break
## edges c(min, q1/3, q2/3, max) that define the low / mid / high bands. "wet" is
## therefore RELATIVE to each community's own range: Aeolian's "high" sits far
## below Inland Floodplain's "high", and that contrast is the point.

gayini_community_regime_bands <- function(freq_8058,
                                          communities,
                                          focus_communities) {

  breaks <- list()
  for (g in focus_communities) {
    poly <- communities[as.character(communities$simplified_vegetation_group) == g, ]
    if (nrow(poly) == 0) {
      stop("Community polygon not found for: ", g, call. = FALSE)
    }
    v <- terra::vect(sf::st_geometry(poly))
    r <- terra::mask(terra::crop(freq_8058, v), v)
    vals <- terra::values(r)
    vals <- vals[!is.na(vals)]
    if (length(vals) < 3) {
      stop("Too few supported pixels to form terciles in community: ", g, call. = FALSE)
    }
    qs <- stats::quantile(vals, probs = c(1 / 3, 2 / 3), names = FALSE, type = 7)
    breaks[[g]] <- c(min(vals), qs[1], qs[2], max(vals))
  }
  breaks
}


## Classify a vector of frequency values into low/mid/high given a community's
## break edges c(min, q1, q2, max).
gayini_assign_regime_band <- function(freq_values, breaks_g) {
  idx <- findInterval(freq_values, c(breaks_g[2], breaks_g[3]))  # 0 / 1 / 2
  gayini_regime_band_levels()[pmin(idx + 1L, 3L)]
}


## 3. Candidate pixels within a sampling neighbourhood ----
##
## Returns an sf of pixel-centre points inside `nbhd_sf` AND strictly within
## `comm_poly_sf`, carrying background_flood_freq + valid_years, filtered to
## pixels with >= min_valid_years of support.

gayini_candidate_pixels <- function(freq_8058,
                                     valid_8058,
                                     nbhd_sf,
                                     comm_poly_sf,
                                     min_valid_years,
                                     exclusion_zone = NULL) {

  empty <- sf::st_sf(
    background_flood_freq = numeric(0),
    valid_years           = numeric(0),
    geometry              = sf::st_sfc(crs = sf::st_crs(freq_8058))
  )

  if (length(nbhd_sf) == 0 || all(sf::st_is_empty(nbhd_sf))) return(empty)

  v  <- terra::vect(sf::st_sf(geometry = sf::st_geometry(nbhd_sf)))
  fr <- terra::mask(terra::crop(freq_8058, v), v)
  names(fr) <- "background_flood_freq"

  pts <- terra::as.points(fr, values = TRUE, na.rm = TRUE)
  if (nrow(pts) == 0) return(empty)

  sfp <- sf::st_as_sf(pts)

  ## Exact support at each candidate pixel (nearest-neighbour count surface).
  vy <- terra::extract(valid_8058, terra::vect(sfp))[["valid_years"]]
  sfp$valid_years <- vy
  sfp <- sfp[!is.na(vy) & vy >= min_valid_years, ]
  if (nrow(sfp) == 0) return(empty)

  ## Strictly inside the community polygon (guarantees the acceptance-gate
  ## st_within test, even for edge pixels).
  within <- lengths(sf::st_within(sfp, sf::st_union(comm_poly_sf))) > 0
  sfp <- sfp[within, , drop = FALSE]
  if (nrow(sfp) == 0) return(sfp)

  ## Drop pixel centres that fall strictly inside the exclusion zone (footprint +
  ## buffer). terra::mask keeps cells that merely OVERLAP the neighbourhood, so a
  ## cell centre a few metres inside the exclusion hole can survive; this
  ## vector-level test enforces dist_to_plot_m >= exclusion_buffer exactly.
  if (!is.null(exclusion_zone)) {
    outside_excl <- lengths(sf::st_within(sfp, sf::st_union(exclusion_zone))) == 0
    sfp <- sfp[outside_excl, , drop = FALSE]
  }
  sfp
}


## 4. Draw the stratified sample ----
##
## For each focus community: build the plot-neighbourhood (2 km buffers, clipped
## to the community, footprint + exclusion buffer removed), collect candidate
## pixels, band them by the community's terciles, and draw N_PER_STRATUM random
## pixels per band. Documented fallback: if the neighbourhood is too sparse to
## fill even one stratum, fall back to community-wide sampling (still excluding
## plot footprints) and LOG that the fallback triggered.

gayini_draw_stratified_sample <- function(freq_8058,
                                           valid_8058,
                                           plots,                 # sf, with plot_id + simplified_vegetation_group
                                           communities,
                                           breaks,
                                           focus_communities,
                                           neighbourhood_radius,
                                           exclusion_buffer,
                                           n_per_stratum,
                                           min_valid_years,
                                           seed) {

  set.seed(seed)
  band_levels <- gayini_regime_band_levels()

  ## All-plot exclusion zone: every plot footprint + exclusion buffer. Subtracted
  ## from every community's neighbourhood, so a drawn point is >= exclusion_buffer
  ## from EVERY plot footprint, not just its own community's plots.
  excl <- sf::st_union(sf::st_buffer(sf::st_geometry(plots), exclusion_buffer))

  point_list   <- list()
  summary_list <- list()

  for (g in focus_communities) {

    comm_poly <- sf::st_union(sf::st_geometry(
      communities[as.character(communities$simplified_vegetation_group) == g, ]
    ))
    g_plots <- plots[as.character(plots$simplified_vegetation_group) == g, ]

    ## Plot-neighbourhood = union(2 km buffers) ∩ community − exclusion.
    nbhd <- sf::st_union(sf::st_buffer(sf::st_geometry(g_plots), neighbourhood_radius))
    nbhd <- suppressWarnings(sf::st_intersection(nbhd, comm_poly))
    nbhd <- suppressWarnings(sf::st_difference(nbhd, excl))

    cand <- gayini_candidate_pixels(freq_8058, valid_8058, nbhd, comm_poly,
                                    min_valid_years, exclusion_zone = excl)

    ## Documented fallback: neighbourhood cannot fill even one stratum.
    fallback <- FALSE
    if (nrow(cand) < n_per_stratum) {
      fallback <- TRUE
      message("  [fallback] ", g, ": plot-neighbourhood too sparse (",
              nrow(cand), " candidate pixels < N_PER_STRATUM = ", n_per_stratum,
              ") -> community-wide stratified sampling (footprints still excluded).")
      nbhd_cw <- suppressWarnings(sf::st_difference(comm_poly, excl))
      cand <- gayini_candidate_pixels(freq_8058, valid_8058, nbhd_cw, comm_poly,
                                      min_valid_years, exclusion_zone = excl)
    }

    br <- breaks[[g]]
    if (nrow(cand) > 0) {
      cand$regime_band <- gayini_assign_regime_band(cand$background_flood_freq, br)
      cand$community   <- g
    }

    ## One row per band (all three ALWAYS present because terciles are defined on
    ## the community-wide distribution). Empty strata are logged, not dropped.
    for (b in band_levels) {
      pool  <- if (nrow(cand) > 0) cand[cand$regime_band == b, , drop = FALSE] else cand
      n_cand <- nrow(pool)

      if (n_cand >= n_per_stratum) {
        idx <- sample.int(n_cand, n_per_stratum)
      } else {
        idx <- seq_len(n_cand)   # take all available; shortfall logged below
      }
      drawn   <- pool[idx, , drop = FALSE]
      n_drawn <- nrow(drawn)

      band_lo <- if (identical(b, "low")) br[1] else if (identical(b, "mid")) br[2] else br[3]
      band_hi <- if (identical(b, "low")) br[2] else if (identical(b, "mid")) br[3] else br[4]

      summary_list[[length(summary_list) + 1L]] <- tibble::tibble(
        community          = g,
        regime_band        = factor(b, levels = band_levels),
        band_freq_lo_pct   = round(band_lo, 2),
        band_freq_hi_pct   = round(band_hi, 2),
        n_candidate_pixels = n_cand,
        n_drawn            = n_drawn,
        target_n           = n_per_stratum,
        shortfall          = max(n_per_stratum - n_drawn, 0L),
        empty_stratum      = n_cand == 0L,
        fallback_triggered = fallback
      )

      if (n_drawn > 0) point_list[[length(point_list) + 1L]] <- drawn
    }
  }

  sample_summary <- dplyr::bind_rows(summary_list)

  pts <- do.call(rbind, point_list)
  pts <- sf::st_sf(pts)

  ## Nearest plot (anchor) + distance to it.
  nn <- sf::st_nearest_feature(pts, plots)
  d  <- sf::st_distance(pts, plots[nn, ], by_element = TRUE)
  pts$nearest_plot_id  <- plots$plot_id[nn]
  pts$dist_to_plot_m   <- as.numeric(d)
  pts$community        <- factor(pts$community, levels = focus_communities)
  pts$regime_band      <- factor(pts$regime_band, levels = band_levels)

  ## Stable, self-describing point id + tidy column order.
  pts$sample_point_id <- sprintf("SP_%04d", seq_len(nrow(pts)))
  pts <- pts[, c("sample_point_id", "community", "regime_band",
                 "background_flood_freq", "valid_years",
                 "nearest_plot_id", "dist_to_plot_m", "geometry")]

  list(points = pts, summary = sample_summary)
}
