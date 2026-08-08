# Ruling BE - is the fourth AY/AZ instance a LABEL defect or a VALUE defect?
#
# BL holds the 81 PNGs and 81 PDFs unrendered before 10 August UNLESS BE returns a value
# defect. So this is the check that decides whether a re-render is owed, and it is the
# only thing standing between "warn and leave" and a rebuild.
#
# THE PREDICTION BEING TESTED, stated so it can fail: the flooding panel and the
# vegetation-response marker differ ONLY IN SCOPE - what ground each describes - and no
# value in either is wrong.
#
# Reported per Bala 26ca / 28ca / 29ca:
#   1. the flooding panel's per-year sum of valid pixels, and the mean of its 35 values
#   2. the pixel set behind the vegetation-response marker, and its n
#   3. the unit's share on the community the panel shows
#
# Read-only. Registers nothing, renders nothing, changes no producer.

suppressPackageStartupMessages({
  library(terra); library(sf); library(DBI); library(RSQLite)
})

root <- normalizePath(".", winslash = "/")
UNITS <- c("Bala 26ca", "Bala 28ca", "Bala 29ca")

wet   <- terra::rast(file.path(root, "Output/rasters/inundation_annual_stack/annual_wet_any_1988_2023.tif"))
valid <- terra::rast(file.path(root, "Output/rasters/inundation_annual_stack/annual_valid_any_1988_2023.tif"))
mz    <- sf::st_read(file.path(root, "Output/spatial_8058/management_zones_epsg8058.gpkg"),
                     quiet = TRUE)

nm <- grep("zone_name|ManagmentZ|management_zone", names(mz), value = TRUE)[1]
cat(sprintf("  management zones: %d, name field '%s'\n", nrow(mz), nm))

con <- DBI::dbConnect(RSQLite::SQLite(), file.path(root, "Output/database/Gayini_Results.sqlite"))
on.exit(DBI::dbDisconnect(con), add = TRUE)

spine <- DBI::dbGetQuery(con, "SELECT * FROM v_plot_year_analysis_spine")
dplot <- DBI::dbGetQuery(con, "SELECT plot_id, simplified_vegetation_group, centroid_x, centroid_y FROM dim_plot")
# census part-level pixel counts, for the community share the panel implies
# Non-treed is treed_context_flag = 0 AND regime_band <> 'context'. The flag ALONE
# admits Other / minor units and gives ten strata, not nine. n_pixels_all keeps the
# whole unit including woodland, so the share can be reported against both denominators
# rather than leaving the reader to guess which one a bare percentage used.
cen <- DBI::dbGetQuery(con, "
  SELECT d.zone_name, c.community,
         SUM(CASE WHEN c.treed_context_flag = 0 AND c.regime_band <> 'context'
                  THEN c.n_pixels ELSE 0 END) AS n_pixels,
         SUM(c.n_pixels) AS n_pixels_all
  FROM census_by_zone_stratum c JOIN dim_management_zone d ON d.zone_fid = c.zone_fid
  GROUP BY d.zone_name, c.community")

# dim_plot centroids are EPSG:9473, NOT 8058 - reproject before any spatial join
plots <- sf::st_as_sf(dplot[!is.na(dplot$centroid_x), ],
                      coords = c("centroid_x", "centroid_y"), crs = 9473)
plots <- sf::st_transform(plots, sf::st_crs(mz))

rows <- list()
for (u in UNITS) {
  g <- mz[mz[[nm]] == u, ]
  if (nrow(g) == 0) { cat(sprintf("  %-10s NOT FOUND in the zone layer\n", u)); next }

  # (1) exactly what gayini_unit_flood_series does, reproduced rather than trusted
  v  <- terra::vect(sf::st_transform(sf::st_geometry(g), terra::crs(wet)))
  w  <- as.numeric(terra::extract(wet,   v, fun = sum, na.rm = TRUE, ID = FALSE)[1, ])
  vv <- as.numeric(terra::extract(valid, v, fun = sum, na.rm = TRUE, ID = FALSE)[1, ])
  yr <- as.integer(substr(names(wet), 1, 4))
  freq <- ifelse(vv > 0, 100 * w / vv, NA_real_)

  # (2) the vegetation-response marker: which plots, and how many
  hit <- sf::st_intersects(sf::st_geometry(plots), sf::st_geometry(g), sparse = FALSE)[, 1]
  pid <- plots$plot_id[hit]
  comm_of_plots <- plots$simplified_vegetation_group[hit]
  sub <- spine[spine$plot_id %in% pid, ]

  # (3) the community the panel shows, and the unit's share on it.
  #
  # THE RULE MATTERS AND THE FIRST PASS GOT IT WRONG. The dashboard does NOT show the
  # modal community of the unit's plots; gayini_resolve_paddock() takes the
  # AREA-DOMINANT focus community from gayini_paddock_community_shares() and then
  # gayini_unit_response() keeps only the plots that fall in THAT community. For Bala
  # 29ca the two rules disagree - plot-modal is Aeolian, area-dominant is Inland - so
  # using the plot-modal rule answers a question the panel never asked.
  cc <- cen[cen$zone_name == u, ]
  cc <- cc[order(-cc$n_pixels), ]
  shown <- if (nrow(cc)) cc$community[1] else NA_character_       # area-dominant
  shown_plot_modal <- if (length(pid))
    names(sort(table(comm_of_plots), decreasing = TRUE))[1] else NA_character_
  n_all <- sum(cc$n_pixels_all); n_nt <- sum(cc$n_pixels)
  share <- if (!is.na(shown)) 100 * cc$n_pixels[cc$community == shown] / n_nt else NA_real_
  share_of_all <- if (!is.na(shown)) 100 * cc$n_pixels[cc$community == shown] / n_all else NA_real_
  # the plots the marker actually draws: in the unit AND in the shown community
  pid_shown <- pid[comm_of_plots == shown]

  cat(sprintf("\n-- %s --\n", u))
  cat(sprintf("  FLOODING PANEL (pixel support, whole polygon, native 28355)\n"))
  cat(sprintf("    valid pixels per year: min %.0f  median %.0f  max %.0f\n",
              min(vv), stats::median(vv), max(vv)))
  cat(sprintf("    mean of the 35 valid-pixel counts   : %.1f\n", mean(vv)))
  cat(sprintf("    constant across years?              : %s\n",
              if (length(unique(vv)) == 1) "YES - identical in all 35" else
                sprintf("no - %d distinct values", length(unique(vv)))))
  cat(sprintf("    mean of the 35 freq_pct values      : %.2f %%\n", mean(freq, na.rm = TRUE)))
  cat(sprintf("    long-run 100*sum(wet)/sum(valid)    : %.2f %%\n", 100 * sum(w) / sum(vv)))
  cat(sprintf("  VEGETATION-RESPONSE MARKER (plot support)\n"))
  cat(sprintf("    pixel set behind it                 : NONE - it is built on PLOTS\n"))
  cat(sprintf("    n plots in unit                     : %d  (%s)\n", length(pid),
              if (length(pid)) paste(pid, collapse = ", ") else "none"))
  cat(sprintf("    n plot-years on the marker          : %d\n", nrow(sub)))
  cat(sprintf("  COMMUNITY SHOWN (area-dominant - the rule the dashboard uses)\n"))
  cat(sprintf("    shown community                     : %s\n",
              if (is.na(shown)) "n/a" else shown))
  cat(sprintf("    plot-modal community (NOT the rule) : %s%s\n",
              if (is.na(shown_plot_modal)) "n/a" else shown_plot_modal,
              if (!is.na(shown) && !is.na(shown_plot_modal) && shown != shown_plot_modal)
                "   <- DISAGREES with the shown community" else ""))
  cat(sprintf("    unit's non-treed census pixels      : %s\n",
              paste(sprintf("%s %s", substr(cc$community, 1, 8),
                            format(cc$n_pixels, big.mark = ",")), collapse = " | ")))
  cat(sprintf("    share on the shown community        : %.1f%% of non-treed cells;  %.1f%% of ALL cells\n",
              share, share_of_all))
  cat(sprintf("    plots the marker actually draws     : %d of the %d in the unit\n",
              length(pid_shown), length(pid)))

  rows[[length(rows) + 1L]] <- data.frame(
    unit = u,
    valid_px_mean_of_35 = mean(vv), valid_px_min = min(vv), valid_px_max = max(vv),
    valid_px_constant = length(unique(vv)) == 1,
    mean_of_annual_freq_pct = mean(freq, na.rm = TRUE),
    long_run_freq_pct = 100 * sum(w) / sum(vv),
    marker_pixel_set = "none - plot support",
    marker_n_plots_in_unit = length(pid),
    marker_n_plots_drawn = length(pid_shown), marker_n_plot_years = nrow(sub),
    community_shown_rule = "area-dominant focus community (gayini_paddock_community_shares)",
    community_shown = shown, community_plot_modal = shown_plot_modal,
    share_on_shown_pct_of_non_treed = share,
    share_on_shown_pct_of_all = share_of_all,
    stringsAsFactors = FALSE)
}

out <- do.call(rbind, rows)
dir.create(file.path(root, "Output/diag"), showWarnings = FALSE, recursive = TRUE)
out$support_level <- "MIXED - flooding panel pixel, response marker plot"
out$unit_col <- "paddock (management zone)"
out$period_label <- "1988-2022 (35 water years)"
out$weighting <- "unweighted"
out$estimand <- "SCOPE DIAGNOSTIC under Ruling BE - not an estimate of any relationship"
utils::write.csv(out, file.path(root, "Output/diag/BE_dashboard_scope_check.csv"),
                 row.names = FALSE)
cat("\n[wrote] Output/diag/BE_dashboard_scope_check.csv\n")
