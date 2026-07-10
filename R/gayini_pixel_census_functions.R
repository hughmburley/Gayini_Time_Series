####################################################################################################


## GAYINI REMOTE SENSING PROJECT


## Tier 1 · Pixel census (Task 1) — how many farm pixels sit in each
## vegetation-community x wetness-band stratum, and what fraction we sample.
##
## The census classifies EVERY farm pixel (not just the plot neighbourhoods F5
## sampled) by:
##   1. community  — overlay the vegetation-community polygons on the 8058 grid;
##   2. wetness band — apply the community-relative tercile breaks (regime_band_
##      breaks.csv) to the background flood-frequency surface.
## A pixel counts only if it passes the valid-coverage mask (>= min_valid_years
## of valid annual observations) — the same, parameterised support test F5 uses.
##
## The 3 non-treed focus communities are banded low/mid/high (9 strata). The
## treed Woodland/Forest and the Other/minor units are single UNBANDED context
## rows (no tercile breaks are defined for them). Equal-allocation sampling
## over-represents small strata — the census is built to make that visible via
## points_per_1000ha.
##
## This is descriptive infrastructure + a stratification audit, NOT a trend or
## probability surface. Source rasters are read-only; only the derived continuous
## surface is reprojected. See [[gayini-tier1c-sampling-frame]].


####################################################################################################


## 1. Classify every farm pixel to (community x band) and tabulate ----
##
## freq_8058  : background flood-frequency surface (already >= min_valid_years
##              masked by gayini_background_flood_frequency at the SAME threshold,
##              so a non-NA freq pixel == a valid pixel).
## valid_8058 : per-pixel valid-year COUNT (nearest-neighbour), used only for the
##              masked-out reconciliation accounting.
## communities: sf of vegetation-community polygons (EPSG:8058), non-overlapping.
## breaks     : named list (per focus community) of c(min, q1, q2, max) edges.
## points     : the current stratified sample (sf) with community + regime_band.

gayini_pixel_census <- function(freq_8058,
                                 valid_8058,
                                 communities,
                                 breaks,
                                 focus_communities,
                                 points,
                                 min_valid_years,
                                 pixel_area_ha = NULL) {

  band_levels <- gayini_regime_band_levels()

  if (is.null(pixel_area_ha)) {
    pixel_area_ha <- prod(terra::res(freq_8058)) / 1e4
  }

  ## Community ordering: 3 focus (gradient order) first, then the treed context
  ## community, then any remaining (Other / minor units).
  all_present <- unique(as.character(communities$simplified_vegetation_group))
  treed_first <- intersect(GAYINI_CONTEXT_COMMUNITY, all_present)
  other_ctx   <- setdiff(all_present, c(focus_communities, treed_first))
  comm_order  <- c(focus_communities, treed_first, other_ctx)
  context_communities <- c(treed_first, other_ctx)

  ## Rasterize the community polygons onto the frequency grid (integer id per
  ## pixel). Polygons are a partition of the farm, so one id per farm pixel.
  comm_v <- terra::vect(communities)
  comm_v$.cid <- as.integer(factor(as.character(comm_v$simplified_vegetation_group),
                                   levels = comm_order))
  comm_r <- terra::rasterize(comm_v, freq_8058, field = ".cid")

  cid   <- terra::values(comm_r)[, 1]
  freq  <- terra::values(freq_8058)[, 1]
  valid <- terra::values(valid_8058)[, 1]

  in_farm    <- !is.na(cid)
  valid_pix  <- in_farm & !is.na(freq)                    # passes support mask
  masked_out <- in_farm & is.na(freq)                     # in a community, fails mask

  ## Sample-point tallies per (community x band).
  pts_tab <- table(factor(as.character(points$community), levels = comm_order),
                   factor(as.character(points$regime_band), levels = band_levels))

  n_sampled <- function(g, b) {
    if (g %in% rownames(pts_tab) && b %in% colnames(pts_tab)) as.integer(pts_tab[g, b]) else 0L
  }

  rows <- list()
  co   <- 0L

  ## --- Focus communities: low / mid / high ---
  for (g in focus_communities) {
    co  <- co + 1L
    gid <- match(g, comm_order)
    fg  <- freq[valid_pix & cid == gid]
    br  <- breaks[[g]]
    band <- gayini_assign_regime_band(fg, br)                 # low / mid / high
    band <- factor(band, levels = band_levels)
    ncell_band <- as.integer(table(band))

    band_lo <- c(low = br[1], mid = br[2], high = br[3])
    band_hi <- c(low = br[2], mid = br[3], high = br[4])

    for (bi in seq_along(band_levels)) {
      b  <- band_levels[bi]
      np <- ncell_band[bi]
      rows[[length(rows) + 1L]] <- tibble::tibble(
        community_order      = co,
        band_order           = bi,
        community            = g,
        regime_band          = b,
        treed_context_flag   = 0L,
        band_freq_lo_pct     = round(unname(band_lo[b]), 2),
        band_freq_hi_pct     = round(unname(band_hi[b]), 2),
        n_pixels             = as.integer(np),
        area_ha              = round(np * pixel_area_ha, 3),
        n_points_sampled     = n_sampled(g, b),
        valid_year_threshold = as.integer(min_valid_years)
      )
    }
  }

  ## --- Context communities: single unbanded row each ---
  for (g in context_communities) {
    co  <- co + 1L
    gid <- match(g, comm_order)
    np  <- sum(valid_pix & cid == gid)
    treed_flag <- as.integer(identical(g, GAYINI_CONTEXT_COMMUNITY))
    rows[[length(rows) + 1L]] <- tibble::tibble(
      community_order      = co,
      band_order           = 1L,
      community            = g,
      regime_band          = "context",
      treed_context_flag   = treed_flag,
      band_freq_lo_pct     = NA_real_,
      band_freq_hi_pct     = NA_real_,
      n_pixels             = as.integer(np),
      area_ha              = round(np * pixel_area_ha, 3),
      n_points_sampled     = n_sampled(g, "context"),  # 0 by design (unsampled)
      valid_year_threshold = as.integer(min_valid_years)
    )
  }

  census <- dplyr::bind_rows(rows)
  census$farm_area_ha <- round(sum(census$area_ha), 3)   # mapped, valid farm area

  ## Reconciliation accounting (returned for QA, not stored on every row).
  recon <- list(
    pixel_area_ha           = pixel_area_ha,
    n_valid_pixels          = as.integer(sum(valid_pix)),
    n_masked_out_pixels     = as.integer(sum(masked_out)),
    n_in_community_pixels   = as.integer(sum(in_farm)),
    classified_valid_area_ha = round(sum(valid_pix) * pixel_area_ha, 3),
    masked_out_area_ha       = round(sum(masked_out) * pixel_area_ha, 3),
    in_community_area_ha     = round(sum(in_farm) * pixel_area_ha, 3),
    community_order          = comm_order,
    context_communities      = context_communities
  )

  list(census = census, recon = recon)
}


## 2. Persist the census base table + build the census view ----
##
## Post-build DB mutation (mirrors 03_populate_raster_metadata.R): the Python
## builder unlinks + rebuilds and has no GDAL, so the census table + view must be
## (re)built here after any rebuild. Numbers live in census_stratum; the view
## derives pct_of_farm / sampling_fraction / points_per_1000ha so there is a
## single source of truth.

gayini_write_pixel_census_view <- function(db_path, census, metric_rows = NULL) {

  gayini_stop_if_missing(db_path, label = "results SQLite database")

  con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  DBI::dbExecute(con, "DROP VIEW IF EXISTS v_pixel_census_by_veg_regime")
  DBI::dbWriteTable(con, "census_stratum", as.data.frame(census), overwrite = TRUE)

  ## Safety-net metric definitions (canonical copies also live in the Python
  ## builder METRICS list). INSERT OR IGNORE keeps this idempotent + rebuild-safe.
  if (!is.null(metric_rows)) {
    DBI::dbExecute(con, "CREATE TABLE IF NOT EXISTS dim_metric (
        metric_id TEXT PRIMARY KEY, metric_name TEXT NOT NULL, domain TEXT NOT NULL,
        units TEXT, scale TEXT, numerator TEXT, denominator TEXT,
        method_summary TEXT, safe_interpretation TEXT, caveat TEXT)")
    DBI::dbExecute(con, "BEGIN")
    for (i in seq_len(nrow(metric_rows))) {
      DBI::dbExecute(con,
        "INSERT OR IGNORE INTO dim_metric VALUES (?,?,?,?,?,?,?,?,?,?)",
        params = unname(as.list(metric_rows[i, ])))
    }
    DBI::dbExecute(con, "COMMIT")
  }

  DBI::dbExecute(con,
    "CREATE VIEW v_pixel_census_by_veg_regime AS
     SELECT
       community,
       regime_band,
       treed_context_flag,
       band_freq_lo_pct,
       band_freq_hi_pct,
       n_pixels,
       area_ha,
       100.0 * area_ha / farm_area_ha                              AS pct_of_farm,
       n_points_sampled,
       CASE WHEN n_pixels > 0
            THEN CAST(n_points_sampled AS REAL) / n_pixels END     AS sampling_fraction,
       CASE WHEN area_ha > 0
            THEN 1000.0 * n_points_sampled / area_ha END           AS points_per_1000ha,
       valid_year_threshold
     FROM census_stratum
     ORDER BY community_order, band_order")

  out <- DBI::dbGetQuery(con, "SELECT * FROM v_pixel_census_by_veg_regime")
  tibble::as_tibble(out)
}


## 3. The census figure — available vs sampled per stratum ----
##
## Two panels sharing the stratum axis: pixel area per stratum (the "available"
## side) and sampling density (points per 1000 ha, the "sampled" side). Equal
## allocation makes the small strata spike on the density panel — the point of
## the slide. Context rows (treed / other) are shown greyed with 0 density.

gayini_build_pixel_census_figure <- function(census_view, out_dir,
                                             basename = "F5d_pixel_census_data") {

  band_levels <- gayini_regime_band_levels()
  pal <- gayini_gradient_palette()

  df <- census_view
  df$is_context <- df$treed_context_flag == 1L

  ## Stable stratum label + top-to-bottom order (focus low->high, then context).
  short <- gayini_gradient_short_labels()
  comm_short <- ifelse(df$community %in% names(short), short[df$community], df$community)
  band_lab <- ifelse(df$is_context, "context",
                     factor(df$regime_band, levels = band_levels))
  df$stratum <- paste0(comm_short, " · ", ifelse(df$is_context, "(context)", df$regime_band))
  df$stratum <- factor(df$stratum, levels = rev(unique(df$stratum)))
  df$fill <- ifelse(df$community %in% names(pal), pal[df$community], "#BDBDBD")

  long <- dplyr::bind_rows(
    transform(df, measure = "Available: pixel area (ha)",  value = area_ha),
    transform(df, measure = "Sampled: points per 1000 ha", value = points_per_1000ha)
  )
  long$measure <- factor(long$measure,
                         levels = c("Available: pixel area (ha)",
                                    "Sampled: points per 1000 ha"))
  long$value[is.na(long$value)] <- 0
  long$bar_alpha <- ifelse(long$is_context, 0.45, 1)
  long$lab <- ifelse(
    long$measure == "Available: pixel area (ha)",
    formatC(long$area_ha, format = "d", big.mark = ","),
    ifelse(long$n_points_sampled > 0,
           sprintf("%.1f", long$points_per_1000ha), "not sampled")
  )

  p <- ggplot2::ggplot(long, ggplot2::aes(x = value, y = stratum, fill = I(fill),
                                          alpha = I(bar_alpha))) +
    ggplot2::geom_col(width = 0.72) +
    ggplot2::geom_text(ggplot2::aes(label = lab), alpha = 1,
                       hjust = -0.08, size = 2.7, colour = "grey20") +
    ggplot2::facet_wrap(~measure, scales = "free_x") +
    ggplot2::scale_x_continuous(expand = ggplot2::expansion(mult = c(0, 0.22))) +
    ggplot2::labs(
      title    = "Pixel census: how much of the farm each stratum covers vs how densely we sample it",
      subtitle = "3 focus communities x wetness terciles (9 strata) + treed / other context rows. Equal allocation over-represents small strata.",
      x = NULL, y = NULL,
      caption  = "Available = valid (>= support threshold) farm pixels, EPSG:8058. Sampled = current stratified points per 1000 ha. Source: v_pixel_census_by_veg_regime."
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(
      panel.grid.major.y = ggplot2::element_blank(),
      panel.grid.minor   = ggplot2::element_blank(),
      strip.text         = ggplot2::element_text(face = "bold"),
      plot.title         = ggplot2::element_text(face = "bold", size = 12),
      plot.subtitle      = ggplot2::element_text(size = 9, colour = "grey30"),
      plot.caption       = ggplot2::element_text(size = 7, colour = "grey45", hjust = 0)
    )

  gayini_save_figure(p, out_dir, basename, kind = "data", width = 11, height = 6.2, dpi = 300)
}
