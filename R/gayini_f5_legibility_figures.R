####################################################################################################


## GAYINI REMOTE SENSING PROJECT


## Tier 1 · Task C2 — F5 legibility views (PRESENTATION ONLY).
##
## Reads the finished F5 data products (stratified_sample_points.gpkg,
## background_flood_frequency_8058.tif, regime_band_breaks.csv) and the 8058
## community / management-zone vectors, and produces views that make the
## within-community (RELATIVE) regime banding legible and can't be misread:
##   F5b — community-facet panels (one self-contained panel per focus community).
##   F5c — 3-4 paddock zoom maps, chosen by point density x community/band spread.
##
## Adds NO new sampling or analysis; it re-renders the existing result. Depends on
## gayini_stratified_sampling_functions.R (palette/ramp), gayini_stratified_sampling_figures.R
## (raster_to_df, tercile table, relative legend title) and gayini_sampling_design_map.R
## (scale bar / north arrow).


####################################################################################################


## Load the finished F5 products + supporting vectors ----

gayini_load_f5_products <- function(root = getwd()) {

  spatial_dir <- file.path(root, "Output", "spatial_8058")
  focus       <- gayini_focus_levels()

  pts <- gayini_read_vector(file.path(spatial_dir, "stratified_sample_points.gpkg"),
                            label = "F5 sample points")
  pts$community   <- factor(as.character(pts$community), levels = focus)
  pts$regime_band <- factor(as.character(pts$regime_band), levels = gayini_regime_band_levels())

  freq <- terra::rast(file.path(root, "Output", "rasters", "background_flood_frequency_8058.tif"))
  names(freq) <- "background_flood_freq"

  breaks_df <- readr::read_csv(
    file.path(root, "Output", "diagnostics", "regime_band_breaks.csv"),
    show_col_types = FALSE
  )

  boundary    <- gayini_read_vector(file.path(spatial_dir, "gayini_boundary_epsg8058.gpkg"),
                                    label = "boundary (8058)")
  communities <- gayini_read_vector(file.path(spatial_dir, "vegetation_communities_epsg8058.gpkg"),
                                    label = "communities (8058)")
  management  <- gayini_read_vector(file.path(spatial_dir, "management_zones_epsg8058.gpkg"),
                                    label = "management zones (8058)")

  list(pts = pts, freq = freq, breaks_df = breaks_df, boundary = boundary,
       communities = communities, management = management, focus = focus)
}


## Shared band-colour legend (extracted once, placed beneath facet rows) ----

gayini_regime_band_legend <- function() {
  band_pal <- gayini_regime_band_palette()
  ref <- ggplot2::ggplot(
    data.frame(x = 1, y = 1, band = factor(gayini_regime_band_levels(),
                                           levels = gayini_regime_band_levels())),
    ggplot2::aes(x, y, colour = band)) +
    ggplot2::geom_point(size = 2.5) +
    ggplot2::scale_colour_manual(values = band_pal,
                                 name = gayini_regime_band_legend_title()) +
    ggplot2::theme_minimal(base_size = 10) +
    ggplot2::theme(legend.position = "bottom", legend.direction = "horizontal")
  cowplot::get_legend(ref)
}


## F5b — community-facet panels ----
##
## One self-contained panel per focus community: the surface clipped to that
## community, its points coloured by band, and its OWN tercile breakpoints
## annotated on the panel. Because each panel is a single community, the bands
## cannot be read across communities.

gayini_build_f5b_community_facets <- function(products, out_dir) {

  band_pal  <- gayini_regime_band_palette()
  freq_ramp <- gayini_flood_frequency_ramp()

  pts         <- products$pts
  freq        <- products$freq
  communities <- products$communities
  breaks_df   <- products$breaks_df
  focus       <- products$focus

  panels <- lapply(focus, function(g) {

    poly  <- communities[as.character(communities$simplified_vegetation_group) == g, ]
    g_pts <- pts[as.character(pts$community) == g, ]
    v     <- terra::vect(sf::st_geometry(poly))
    fr    <- terra::mask(terra::crop(freq, v), v)
    df    <- gayini_raster_to_df(fr, max_cells = 1.5e5)
    z     <- sf::st_bbox(poly)

    br <- breaks_df[breaks_df$community == g, ]
    annot <- sprintf(
      "Terciles (this community): low %.1f–%.1f · mid %.1f–%.1f · high %.1f–%.1f  (%% flood freq.)",
      br$freq_min_pct, br$tercile_1_pct, br$tercile_1_pct, br$tercile_2_pct,
      br$tercile_2_pct, br$freq_max_pct)

    ggplot2::ggplot() +
      ggplot2::geom_raster(data = df, ggplot2::aes(x = x, y = y, fill = freq)) +
      ggplot2::scale_fill_gradientn(colours = freq_ramp, limits = c(0, 100),
                                    name = "flood freq. (%)",
                                    guide = ggplot2::guide_colourbar(barwidth = 0.6, barheight = 4)) +
      ggplot2::geom_sf(data = poly, fill = NA, colour = "grey30", linewidth = 0.35) +
      ggplot2::geom_sf(data = g_pts, ggplot2::aes(colour = regime_band), size = 0.9) +
      ggplot2::scale_colour_manual(values = band_pal, guide = "none") +
      ggplot2::coord_sf(xlim = c(z["xmin"], z["xmax"]), ylim = c(z["ymin"], z["ymax"]),
                        expand = FALSE) +
      ggplot2::labs(title = g, subtitle = annot) +
      ggplot2::theme_minimal(base_size = 9) +
      ggplot2::theme(
        plot.title    = ggplot2::element_text(face = "bold", size = 10),
        plot.subtitle = ggplot2::element_text(size = 6.6, colour = "grey30"),
        axis.title    = ggplot2::element_blank(),
        axis.text     = ggplot2::element_text(size = 5, colour = "grey55"),
        panel.grid    = ggplot2::element_line(colour = "grey94", linewidth = 0.15),
        legend.position = "right"
      )
  })

  n_facet_panels <- length(panels)
  facet_row <- cowplot::plot_grid(plotlist = panels, ncol = 3)
  legend    <- gayini_regime_band_legend()

  title <- cowplot::ggdraw() +
    cowplot::draw_label(
      "F5b · Regime bands by community — each panel self-contained (bands are within-community, relative)",
      fontface = "bold", size = 12, x = 0.01, hjust = 0)

  full <- cowplot::plot_grid(
    title, facet_row, legend,
    ncol = 1, rel_heights = c(0.08, 1, 0.08)
  )

  paths <- gayini_save_figure(full, out_dir, "F5b_community_facets_data",
                              kind = "data", width = 13, height = 4.6)

  list(paths = paths, n_facet_panels = n_facet_panels)
}


## Paddock selection — point density x community/band spread ----
##
## Score = n_points x n_communities x n_bands: rewards paddocks that are both
## point-dense and span the gradient. Returns the full ranking (logged) plus the
## chosen top `n_choose`.

gayini_choose_paddocks <- function(products, n_choose = 4, zone_field = "ManagmentZ") {

  pts        <- products$pts
  management <- products$management

  if (!zone_field %in% names(management)) {
    zone_field <- gayini_find_field(management, c("ManagmentZ", "ManagementZ", "Zone", "Paddock"),
                                    "management zone name")
  }

  within_idx <- sf::st_within(pts, management)
  zone_row   <- vapply(within_idx, function(z) if (length(z)) z[[1]] else NA_integer_, integer(1))

  tab <- tibble::tibble(
    zone_row    = zone_row,
    community   = as.character(pts$community),
    regime_band = as.character(pts$regime_band)
  ) |>
    dplyr::filter(!is.na(zone_row)) |>
    dplyr::group_by(zone_row) |>
    dplyr::summarise(
      n_points = dplyr::n(),
      n_comm   = dplyr::n_distinct(community),
      n_band   = dplyr::n_distinct(regime_band),
      .groups  = "drop"
    ) |>
    dplyr::mutate(
      paddock = as.character(sf::st_drop_geometry(management)[[zone_field]])[zone_row],
      score   = n_points * n_comm * n_band
    ) |>
    dplyr::arrange(dplyr::desc(score), dplyr::desc(n_points))

  tab$rank   <- seq_len(nrow(tab))
  tab$chosen <- tab$rank <= n_choose

  list(ranking = tab, chosen = tab[tab$chosen, , drop = FALSE], zone_field = zone_field)
}


## F5c — paddock zoom maps ----
##
## One zoomed map per chosen paddock: the surface + points by band + paddock
## outline (thick), neighbouring paddocks light, with a property-scale locator
## inset. Reusable seed for the future Nari Nari paddock-review panels.

gayini_build_f5c_paddock_zooms <- function(products, choice, out_dir, pad_buffer = 400) {

  band_pal  <- gayini_regime_band_palette()
  freq_ramp <- gayini_flood_frequency_ramp()

  pts        <- products$pts
  freq       <- products$freq
  boundary   <- products$boundary
  management <- products$management
  zone_field <- choice$zone_field
  chosen     <- choice$chosen

  slugify <- function(s) gsub("[^A-Za-z0-9]+", "_", trimws(s))

  paths <- list()
  for (i in seq_len(nrow(chosen))) {

    zr      <- chosen$zone_row[i]
    pad     <- management[zr, ]
    pad_name <- as.character(sf::st_drop_geometry(pad)[[zone_field]])
    slug    <- slugify(pad_name)

    pad_pts  <- pts[lengths(sf::st_within(pts, pad)) > 0, ]

    z    <- sf::st_bbox(sf::st_buffer(sf::st_geometry(pad), pad_buffer))
    clip <- terra::ext(z["xmin"], z["xmax"], z["ymin"], z["ymax"])
    fr   <- terra::crop(freq, clip)
    df   <- gayini_raster_to_df(fr, max_cells = 1.5e5)

    ## Neighbouring paddocks that fall in view (drawn light for context).
    nbrs <- suppressWarnings(management[sf::st_intersects(
      management, sf::st_as_sfc(sf::st_bbox(clip, crs = sf::st_crs(management))), sparse = FALSE)[, 1], ])

    n_comm <- dplyr::n_distinct(as.character(pad_pts$community))
    n_band <- dplyr::n_distinct(as.character(pad_pts$regime_band))

    main <- ggplot2::ggplot() +
      ggplot2::geom_raster(data = df, ggplot2::aes(x = x, y = y, fill = freq)) +
      ggplot2::scale_fill_gradientn(colours = freq_ramp, limits = c(0, 100),
                                    name = "Background\nflood freq. (%)") +
      ggplot2::geom_sf(data = nbrs, fill = NA, colour = "grey70", linewidth = 0.2) +
      ggplot2::geom_sf(data = pad, fill = NA, colour = "grey10", linewidth = 0.9) +
      ggplot2::geom_sf(data = pad_pts, ggplot2::aes(colour = regime_band), size = 1.8) +
      ggplot2::scale_colour_manual(values = band_pal,
                                   name = gayini_regime_band_legend_title(),
                                   guide = ggplot2::guide_legend(override.aes = list(size = 2.5))) +
      ggplot2::coord_sf(xlim = c(z["xmin"], z["xmax"]), ylim = c(z["ymin"], z["ymax"]),
                        expand = FALSE) +
      ggplot2::labs(
        title    = paste0("F5c · Paddock zoom — ", pad_name),
        subtitle = sprintf("%d sample points · %d communit%s · %d regime band%s · bands are within-community (relative)",
                           nrow(pad_pts), n_comm, ifelse(n_comm == 1, "y", "ies"),
                           n_band, ifelse(n_band == 1, "", "s")),
        caption  = "Surface = background flood frequency · paddock outline heavy · neighbouring paddocks light"
      ) +
      ggplot2::theme_minimal(base_size = 10) +
      ggplot2::theme(
        plot.title    = ggplot2::element_text(face = "bold", size = 11),
        plot.subtitle = ggplot2::element_text(size = 8, colour = "grey30"),
        panel.grid    = ggplot2::element_line(colour = "grey93", linewidth = 0.2),
        legend.position = "right"
      )

    ## Locator inset: property boundary + all paddocks, this one highlighted.
    locator <- ggplot2::ggplot() +
      ggplot2::geom_sf(data = management, fill = NA, colour = "grey80", linewidth = 0.15) +
      ggplot2::geom_sf(data = boundary, fill = NA, colour = "grey40", linewidth = 0.4) +
      ggplot2::geom_sf(data = pad, fill = "#D7301F", colour = "#D7301F", alpha = 0.7) +
      ggplot2::coord_sf(expand = FALSE) +
      ggplot2::theme_void() +
      ggplot2::theme(panel.background = ggplot2::element_rect(fill = "white", colour = "grey60",
                                                             linewidth = 0.4))

    composed <- cowplot::ggdraw(main) +
      cowplot::draw_plot(locator, x = 0.03, y = 0.60, width = 0.30, height = 0.34)

    p <- gayini_save_figure(composed, out_dir, paste0("F5c_paddock_", slug, "_data"),
                            kind = "data", width = 9, height = 7)
    paths[[pad_name]] <- p
  }

  paths
}
