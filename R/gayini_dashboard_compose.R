####################################################################################################


## GAYINI REMOTE SENSING PROJECT


## Tier 1 · Dashboards — shared CONTEXT, unit RESOLVERS, and the LAYOUT composer.
##
## gayini_dashboard_context()  loads every shared input once.
## gayini_resolve_{site,paddock,stratum}()  turn a unit id into panel-ready data.
## gayini_build_dashboard()  builds the 6-7 panels and arranges layout A/B/C in a
##   slide or A3 format, then saves. One composer, modular panels — not forked.
##
## No pre/post anywhere; trend wording provisional; boxplot on absolute frequency.


####################################################################################################


## Format presets ----

gayini_dashboard_formats <- function() list(
  slide         = list(width = 13.33, height = 7.5,  base_size = 9),
  a3_landscape  = list(width = 16.54, height = 11.69, base_size = 12),
  a3_portrait   = list(width = 11.69, height = 16.54, base_size = 12)
)


## 1. Shared context ----

gayini_dashboard_context <- function(root = getwd(),
                                     station_id = "410040",
                                     radius_m   = 1000) {

  spatial_dir <- file.path(root, "Output", "spatial_8058")
  db_path     <- file.path(root, "Output", "database", "Gayini_Results.sqlite")
  focus       <- gayini_focus_levels()

  ## Vectors (8058).
  boundary    <- gayini_read_vector(file.path(spatial_dir, "gayini_boundary_epsg8058.gpkg"), label = "boundary")
  communities <- gayini_read_vector(file.path(spatial_dir, "vegetation_communities_epsg8058.gpkg"), label = "communities")
  management  <- gayini_read_vector(file.path(spatial_dir, "management_zones_epsg8058.gpkg"), label = "management")
  plots       <- gayini_read_vector(file.path(spatial_dir, "gayini_hectare_plots_epsg8058.gpkg"), label = "plots")
  zone_field  <- gayini_find_field(management, c("ManagmentZ", "ManagementZ", "Zone", "Paddock"), "zone name")

  ## Rasters.
  freq_layer  <- terra::rast(file.path(root, "Output", "rasters", "background_flood_frequency_8058.tif"))
  class_layer <- terra::rast(file.path(root, "Output", "rasters", "veg_regime_class_8058.tif"))
  wet_stack   <- terra::rast(file.path(root, "Output", "rasters", "inundation_annual_stack", "annual_wet_any_1988_2023.tif"))
  valid_stack <- terra::rast(file.path(root, "Output", "rasters", "inundation_annual_stack", "annual_valid_any_1988_2023.tif"))

  ## DB pulls.
  con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  spine   <- tibble::as_tibble(DBI::dbGetQuery(con, "SELECT * FROM v_plot_year_analysis_spine"))
  gc_all  <- tibble::as_tibble(DBI::dbGetQuery(con,
               "SELECT plot_id, date_midpoint, total_veg_pct, bare_ground_pct FROM v_plot_timeseries_groundcover"))
  dim_plot <- tibble::as_tibble(DBI::dbGetQuery(con,
               "SELECT plot_id, simplified_vegetation_group, treed_plot_flag, ground_cover_exclusion_flag, centroid_x, centroid_y FROM dim_plot"))
  gauge   <- tibble::as_tibble(DBI::dbGetQuery(con, sprintf(
               "SELECT water_year, mean_value_numeric AS flow_mld, gauge_name FROM v_gauge_context_by_water_year WHERE station_id='%s' AND variable_code='mean_flow_mld'", station_id)))

  ## F4 per-plot ABSOLUTE flood frequency, gradient-ordered (for where-it-sits).
  freq_by_plot <- gayini_plot_between_year_frequency(spine) |> gayini_apply_gradient_order()

  ## F7 masked plot-years (usable scatter data: x = wet-extent intensity, y = total veg).
  thr <- gayini_f7_thresholds()
  pym <- spine |>
    dplyr::filter(treed_plot_flag == 0, ground_cover_exclusion_flag == 0,
                  simplified_vegetation_group %in% focus,
                  annual_valid_coverage_pct >= thr$MIN_VALID_COVERAGE,
                  !is.na(annual_occurrence_pct), !is.na(mean_total_veg_pct)) |>
    dplyr::transmute(plot_id,
                     community = simplified_vegetation_group,
                     annual_occurrence_pct,
                     total_veg_pct = mean_total_veg_pct)

  ## Plot centroids (dim_plot centroids are EPSG:9473) -> 8058 sf.
  centroids_8058 <- sf::st_transform(
    sf::st_as_sf(dim_plot, coords = c("centroid_x", "centroid_y"), crs = 9473), 8058)

  ## Plot -> stratum (community x regime band) via F7 assignment.
  plot_stratum <- gayini_f7_assign_plot_strata(
    dim_plot,
    freq_raster_path = file.path(root, "Output", "rasters", "background_flood_frequency_8058.tif"),
    breaks_csv_path  = file.path(root, "Output", "diagnostics", "regime_band_breaks.csv"))

  ## F6 verdicts + pre-computed per-stratum annual flooding series.
  f6_verdict <- readr::read_csv(file.path(root, "Output", "diagnostics", "f6_verdict_summary.csv"),
                                show_col_types = FALSE)
  f6_series  <- readr::read_csv(file.path(root, "Output", "diagnostics", "f6_stratum_annual_series.csv"),
                                show_col_types = FALSE)

  classes <- gayini_veg_regime_classes()

  list(
    root = root, focus = focus, boundary = boundary, communities = communities,
    management = management, plots = plots, zone_field = zone_field,
    freq_layer = freq_layer, class_layer = class_layer,
    wet_stack = wet_stack, valid_stack = valid_stack,
    freq_ramp = gayini_flood_frequency_ramp(),
    classes = classes, class_legend = gayini_bivariate_legend_mini(classes), show_class_legend = TRUE,
    spine = spine, gc_all = gc_all, dim_plot = dim_plot, gauge = gauge,
    gauge_label = if (nrow(gauge)) gauge$gauge_name[1] else station_id,
    freq_by_plot = freq_by_plot, pym = pym,
    centroids_8058 = centroids_8058, plot_stratum = plot_stratum,
    f6_verdict = f6_verdict, f6_series = f6_series,
    radius_m = radius_m, station_id = station_id
  )
}


## Helpers ----

## Per-year between-year flood frequency (wet / valid) for a polygon, from the
## native 28355 categorical stack (never resampled). Returns year, freq_pct, n_valid.
gayini_unit_flood_series <- function(geom_8058, ctx) {
  v  <- terra::vect(sf::st_transform(sf::st_geometry(geom_8058), terra::crs(ctx$wet_stack)))
  w  <- as.numeric(terra::extract(ctx$wet_stack,   v, fun = sum, na.rm = TRUE, ID = FALSE)[1, ])
  vv <- as.numeric(terra::extract(ctx$valid_stack, v, fun = sum, na.rm = TRUE, ID = FALSE)[1, ])
  yr <- as.integer(substr(names(ctx$wet_stack), 1, 4))
  data.frame(year = yr, freq_pct = ifelse(vv > 0, 100 * w / vv, NA_real_), n_valid = vv)
}

## Long-run absolute flood frequency (%) for a polygon = 100 * Σwet / Σvalid.
gayini_unit_flood_frequency <- function(geom_8058, ctx) {
  v  <- terra::vect(sf::st_transform(sf::st_geometry(geom_8058), terra::crs(ctx$wet_stack)))
  w  <- sum(as.numeric(terra::extract(ctx$wet_stack,   v, fun = sum, na.rm = TRUE, ID = FALSE)[1, ]), na.rm = TRUE)
  vv <- sum(as.numeric(terra::extract(ctx$valid_stack, v, fun = sum, na.rm = TRUE, ID = FALSE)[1, ]), na.rm = TRUE)
  if (vv > 0) 100 * w / vv else NA_real_
}

## Dominant focus community of a polygon (area-weighted over the veg map).
gayini_dominant_community <- function(geom_8058, ctx) {
  inter <- suppressWarnings(sf::st_intersection(ctx$communities, sf::st_geometry(geom_8058)))
  if (nrow(inter) == 0) return(ctx$focus[1])
  inter$a <- as.numeric(sf::st_area(inter))
  agg <- stats::aggregate(a ~ simplified_vegetation_group, data = sf::st_drop_geometry(inter), FUN = sum)
  agg <- agg[agg$simplified_vegetation_group %in% ctx$focus, , drop = FALSE]
  if (nrow(agg) == 0) return(ctx$focus[1])
  as.character(agg$simplified_vegetation_group[which.max(agg$a)])
}

## Aggregate ground-cover series (mean over plot_ids) -> date, total_veg_pct, bare_ground_pct.
gayini_unit_gc_series <- function(plot_ids, ctx) {
  d <- ctx$gc_all[ctx$gc_all$plot_id %in% plot_ids, ]
  if (nrow(d) == 0) return(NULL)
  d |>
    dplyr::group_by(date_midpoint) |>
    dplyr::summarise(total_veg_pct = mean(total_veg_pct, na.rm = TRUE),
                     bare_ground_pct = mean(bare_ground_pct, na.rm = TRUE), .groups = "drop") |>
    dplyr::mutate(date = as.Date(date_midpoint)) |>
    dplyr::arrange(date)
}

## Response bundle for a set of unit plot_ids within a community.
gayini_unit_response <- function(unit_plot_ids, community, ctx) {
  comm_pts <- ctx$pym[ctx$pym$community == community, ]
  sub_pts  <- ctx$pym[ctx$pym$plot_id %in% unit_plot_ids & ctx$pym$community == community, ]
  n_plots  <- dplyr::n_distinct(sub_pts$plot_id)
  list(subset = sub_pts, community = comm_pts, n_plots = n_plots,
       community_name = community,
       colour = unname(gayini_gradient_palette()[community]),
       fallback = n_plots == 0, small_n = n_plots > 0 && n_plots < 5)
}

## Plots whose centroid falls inside a paddock polygon.
gayini_plots_in_paddock <- function(paddock_geom, ctx) {
  hit <- sf::st_intersects(sf::st_centroid(sf::st_geometry(ctx$plots)),
                           sf::st_geometry(paddock_geom), sparse = FALSE)[, 1]
  as.character(ctx$plots$plot_id[hit])
}


## 2. Unit resolvers ----

gayini_resolve_site <- function(plot_id, ctx) {
  di <- ctx$dim_plot[ctx$dim_plot$plot_id == plot_id, ]
  community <- di$simplified_vegetation_group[1]
  centroid  <- ctx$centroids_8058[ctx$centroids_8058$plot_id == plot_id, ]
  ring      <- sf::st_sf(geometry = sf::st_buffer(sf::st_geometry(centroid), ctx$radius_m))
  footprint <- ctx$plots[ctx$plots$plot_id == plot_id, ]
  nbrs      <- suppressWarnings(ctx$management[
    sf::st_intersects(ctx$management, ring, sparse = FALSE)[, 1], ])

  flooding <- gayini_unit_flood_series(ring, ctx)
  gc       <- gayini_unit_gc_series(plot_id, ctx)
  resp     <- gayini_unit_response(plot_id, community, ctx)
  box_val  <- ctx$freq_by_plot$flood_frequency_pct[ctx$freq_by_plot$plot_id == plot_id]
  gaugeflow <- data.frame(year = as.integer(substr(ctx$gauge$water_year, 1, 4)),
                          flow_mld = ctx$gauge$flow_mld)

  spec <- list(type = "site", ring = ring, footprint = footprint, neighbours = nbrs,
               radius_label = sprintf("%.1f km", ctx$radius_m / 1000), pad_buffer = 150)
  list(spec = spec, is_site = TRUE,
       title = sprintf("Site dashboard - %s", plot_id),
       subtitle = sprintf("%s | %s neighbourhood | community: %s",
                          plot_id, spec$radius_label, community),
       flooding = flooding, flood_note = "site neighbourhood", gc = gc, gc_note = "plot",
       resp = resp, box = list(value = box_val, community = community),
       gaugeflow = gaugeflow)
}

gayini_resolve_paddock <- function(pad_name, ctx) {
  geom <- ctx$management[as.character(sf::st_drop_geometry(ctx$management)[[ctx$zone_field]]) == pad_name, ]
  community <- gayini_dominant_community(geom, ctx)
  plot_ids  <- gayini_plots_in_paddock(geom, ctx)
  z    <- sf::st_bbox(sf::st_buffer(sf::st_geometry(geom), 300))
  nbrs <- suppressWarnings(ctx$management[sf::st_intersects(
    ctx$management, sf::st_as_sfc(z), sparse = FALSE)[, 1], ])

  flooding <- gayini_unit_flood_series(geom, ctx)
  gc_ids   <- if (length(plot_ids)) plot_ids else ctx$dim_plot$plot_id[ctx$dim_plot$simplified_vegetation_group == community]
  gc       <- gayini_unit_gc_series(gc_ids, ctx)
  resp     <- gayini_unit_response(plot_ids, community, ctx)
  box_val  <- gayini_unit_flood_frequency(geom, ctx)

  spec <- list(type = "paddock", geom = geom, neighbours = nbrs, pad_buffer = 300)
  list(spec = spec, is_site = FALSE,
       title = sprintf("Paddock dashboard - %s", pad_name),
       subtitle = sprintf("%s | %d monitoring plot%s | dominant community: %s",
                          pad_name, length(plot_ids), ifelse(length(plot_ids) == 1, "", "s"), community),
       flooding = flooding, flood_note = "paddock valid pixels",
       gc = gc, gc_note = if (length(plot_ids)) sprintf("mean of %d plot(s)", length(plot_ids)) else "community context (no plots in paddock)",
       resp = resp, box = list(value = box_val, community = community))
}

gayini_resolve_stratum <- function(community, band, ctx) {
  label <- sprintf("%s | %s", community, band)
  cls   <- ctx$classes[ctx$classes$community == community & ctx$classes$band == band, ]
  target_code <- cls$code[1]

  ps <- ctx$plot_stratum
  plot_ids <- as.character(ps$plot_id[as.character(ps$community) == community &
                                        as.character(ps$regime_band) == band])
  ser <- ctx$f6_series[ctx$f6_series$community == community & ctx$f6_series$regime_band == band, ]
  flooding <- data.frame(year = ser$year, freq_pct = ser$freq_pct, n_valid = ser$n_valid)

  ver <- ctx$f6_verdict$verdict[ctx$f6_verdict$community == community &
                                  ctx$f6_verdict$regime_band == band]
  trend_note <- switch(if (length(ver)) ver[1] else "",
    no_trend       = "No trend detected so far (provisional)",
    non_stationary = "Episodic / non-stationary (provisional)",
    "Trend inconclusive (provisional)")

  gc   <- gayini_unit_gc_series(plot_ids, ctx)
  resp <- gayini_unit_response(plot_ids, community, ctx)
  box_val <- mean(ser$freq_pct, na.rm = TRUE)

  spec <- list(type = "stratum", target_code = target_code, label = label,
               community = community, band = band)
  list(spec = spec, is_site = FALSE,
       title = sprintf("Stratum dashboard - %s", label),
       subtitle = sprintf("%s | %d plot%s | %s",
                          label, length(plot_ids), ifelse(length(plot_ids) == 1, "", "s"), trend_note),
       flooding = flooding, flood_note = trend_note,
       gc = gc, gc_note = sprintf("%d stratum plot(s)", length(plot_ids)),
       resp = resp, box = list(value = box_val, community = community))
}


## 3. Build + compose one dashboard ----
##
## ONE converged layout family (the A/B/C bake-off is resolved): a big map on the
## LEFT, an aligned time-series column on the RIGHT (shared date axis, G3), a
## compact horizontal baseline-gauge bar, the "where it sits" boxplot, and the
## sqrt-x vegetation-response panel (G2). Per unit type:
##   site    : map (ring + footprint + locator inset) top-left, boxplot under it;
##             right = gauge-flow -> flooding -> total veg -> response; gauge bar.
##   paddock : checkerboard map + locator inset + legend strip (left, full height);
##             right = flooding -> total veg -> response; gauge bar; boxplot.
##   stratum : whole-farm map, class highlighted, ENLARGED (left, full height);
##             right = flooding -> total veg (green only) -> response; gauge bar; box.

gayini_build_dashboard <- function(resolved, ctx, format = "slide", out_dir, basename) {
  fmt <- gayini_dashboard_formats()[[format]]
  bs  <- fmt$base_size
  typ <- resolved$spec$type

  ## Guard: total-veg / gc may be empty for context-only units.
  gc <- resolved$gc
  if (is.null(gc) || nrow(gc) == 0)
    gc <- data.frame(date = as.Date(NA), total_veg_pct = NA_real_, bare_ground_pct = NA_real_)

  ## ---- Shared date axis for the aligned time-series column (G3) ----
  ## Union of all time inputs so limits + breaks are identical across panels.
  dts <- gayini_year_to_date(resolved$flooding$year)
  if (any(!is.na(gc$date))) dts <- c(dts, gc$date)
  if (resolved$is_site)     dts <- c(dts, gayini_year_to_date(resolved$gaugeflow$year))
  date_lim <- range(dts, na.rm = TRUE)
  yr0 <- as.integer(format(date_lim[1], "%Y")); yr1 <- as.integer(format(date_lim[2], "%Y"))
  date_breaks <- gayini_year_to_date(seq(ceiling(yr0 / 5) * 5, floor(yr1 / 5) * 5, by = 5))

  ## ---- Panels ----
  green_only <- identical(typ, "stratum")   # stratum drops bare ground (G4)
  p_map   <- gayini_panel_map(resolved$spec, ctx, base_size = bs - 1)
  p_flow  <- if (resolved$is_site)
    gayini_panel_gauge_flow(resolved$gaugeflow, ctx$gauge_label, bs,
                            date_lim = date_lim, date_breaks = date_breaks) else NULL
  p_flood <- gayini_panel_annual_flooding(resolved$flooding, bs, resolved$flood_note,
                                          date_lim = date_lim, date_breaks = date_breaks)
  p_veg   <- gayini_panel_total_veg(gc, bs, resolved$gc_note,
                                    date_lim = date_lim, date_breaks = date_breaks,
                                    green_only = green_only)
  p_resp  <- gayini_panel_veg_response(resolved$resp, bs)
  p_base  <- gayini_panel_baseline_gauge(resolved$flooding, base_size = bs, compact = TRUE)
  p_box   <- gayini_panel_where_it_sits(ctx$freq_by_plot, resolved$box$value, resolved$box$community, bs)

  ## Only the LAST date panel (total veg) keeps its x-axis; strip it from the
  ## upper date panels so the shared year axis reads once but gridlines align.
  strip_x <- ggplot2::theme(axis.text.x = ggplot2::element_blank(),
                            axis.ticks.x = ggplot2::element_blank(),
                            axis.title.x = ggplot2::element_blank())
  if (!is.null(p_flow)) p_flow <- p_flow + strip_x
  p_flood <- p_flood + strip_x

  ## ---- Aligned series column (patchwork aligns panel widths / left edges) ----
  series_panels <- c(if (resolved$is_site) list(p_flow) else NULL,
                     list(p_flood, p_veg, p_resp))
  series <- patchwork::wrap_plots(series_panels, ncol = 1)

  header <- cowplot::ggdraw() +
    cowplot::draw_label(resolved$title, fontface = "bold", size = bs + 5, x = 0.01, hjust = 0, y = 0.68) +
    cowplot::draw_label(resolved$subtitle, size = bs - 1, colour = "grey35", x = 0.01, hjust = 0, y = 0.24)

  ## ---- Converged layout ----
  if (typ == "site") {
    ## map top-left, boxplot bottom-left (under map); series + gauge bar on right.
    left  <- cowplot::plot_grid(p_map, p_box, ncol = 1, rel_heights = c(1, 0.85))
    right <- cowplot::plot_grid(series, p_base, ncol = 1, rel_heights = c(1, 0.17))
    body  <- cowplot::plot_grid(left, right, ncol = 2, rel_widths = c(1, 1.05))
  } else {
    ## paddock / stratum: map fills the left column; right = series, gauge bar, box.
    map_w <- if (typ == "stratum") 1.25 else 1.05
    right <- cowplot::plot_grid(series, p_base, p_box, ncol = 1, rel_heights = c(1, 0.16, 0.62))
    body  <- cowplot::plot_grid(p_map, right, ncol = 2, rel_widths = c(map_w, 1))
  }

  composed <- cowplot::plot_grid(header, body, ncol = 1, rel_heights = c(0.07, 1))

  gayini_save_figure(composed, out_dir, basename, kind = "data",
                     width = fmt$width, height = fmt$height)
}
