####################################################################################################


## GAYINI REMOTE SENSING PROJECT


## Tier 1 spatial foundation: reproject-on-read helper, EPSG:8058 vector copies,
## vegetation-community simplification, and plot/community spatial QA.


## EPSG:8058 = GDA2020 / NSW Lambert. One projection for all of NSW, so the
## Gayini MGA zone 54 / 55 straddle is a non-issue. Source files are NEVER
## mutated; reprojected copies are written to Output/spatial_8058/.


####################################################################################################


GAYINI_ANALYSIS_EPSG <- 8058L


## Reproject-on-read helper ----
##
## Single entry point used by every figure/analysis function so that nothing
## downstream ever has to think about the source CRS. Works on:
##   - sf / sfc vector objects        -> sf::st_transform()
##   - terra SpatRaster objects       -> terra::project(), NEAREST by default
##     (the wet/valid layers are categorical; bilinear would invent classes)
##   - a file path (character)        -> read, then dispatch as above
##
## It only ever returns a reprojected in-memory object. It does not write, and
## it does not touch the source on disk.

to_analysis_crs <- function(x, target = GAYINI_ANALYSIS_EPSG, method = NULL) {

  target_crs <- if (is.numeric(target)) paste0("EPSG:", target) else target

  ## Resolve a file path to an in-memory object first.
  if (is.character(x)) {

    gayini_stop_if_missing(x, label = "layer to reproject")

    raster_ext <- grepl("\\.(tif|tiff|img|vrt|nc|grd)$", x, ignore.case = TRUE)

    x <- if (raster_ext) terra::rast(x) else sf::st_read(x, quiet = TRUE)

  }

  if (inherits(x, "SpatRaster")) {

    ## Categorical wet/valid layers -> nearest neighbour, never bilinear.
    resample_method <- if (is.null(method)) "near" else method

    return(terra::project(x, target_crs, method = resample_method))

  }

  if (inherits(x, c("sf", "sfc"))) {

    if (is.na(sf::st_crs(x))) {
      stop("Cannot reproject a layer with an undefined CRS.", call. = FALSE)
    }

    return(sf::st_transform(x, sf::st_crs(target_crs)))

  }

  stop(
    "to_analysis_crs() expects an sf/sfc object, a SpatRaster, or a file path; got: ",
    paste(class(x), collapse = ", "),
    call. = FALSE
  )

}


gayini_crs_epsg <- function(x) {

  if (is.character(x)) {
    x <- if (grepl("\\.(tif|tiff|img|vrt)$", x, ignore.case = TRUE)) terra::rast(x) else sf::st_read(x, quiet = TRUE)
  }

  if (inherits(x, "SpatRaster")) {
    code <- terra::crs(x, describe = TRUE)$code
    return(suppressWarnings(as.integer(code)))
  }

  suppressWarnings(as.integer(sf::st_crs(x)$epsg))

}


## Vegetation-community simplification ----
##
## The vegetation-classes shapefile carries a fine-grained `Vegetation` field
## (9 detailed types). The plot analysis groups these into FOUR communities,
## matching `simplified_vegetation_group` in dim_plot. This lookup is the single
## place the mapping lives. Detailed types with no plots (grasslands, sandhill /
## mulga woodlands) fall through to "Other / minor units", which is drawn as
## context but is NOT one of the four legend communities.

gayini_vegetation_group_lookup <- function() {

  tibble::tribble(
    ~detailed_vegetation,             ~simplified_vegetation_group,
    "Aeolian Chenopod Shrublands",    "Aeolian Chenopod Shrublands",
    "Inland Floodplain Shrublands",   "Inland Floodplain Shrublands / Swamps",
    "Inland Floodplain Swamps",       "Inland Floodplain Shrublands / Swamps",
    "Inland Floodplain Woodlands",    "Floodplain Woodland / Forest",
    "Inland Riverine Forests",        "Floodplain Woodland / Forest",
    "Riverine Chenopod Shrublands",   "Riverine Chenopod Shrublands"
  )

}


## Canonical order + counts of the four plot communities (mirrors the acceptance
## gate: c(22, 19, 16, 9)).
gayini_community_levels <- function() {
  c(
    "Inland Floodplain Shrublands / Swamps",
    "Riverine Chenopod Shrublands",
    "Aeolian Chenopod Shrublands",
    "Floodplain Woodland / Forest"
  )
}

GAYINI_OTHER_COMMUNITY <- "Other / minor units"


gayini_simplify_vegetation <- function(veg_sf, veg_field = "Vegetation") {

  if (!veg_field %in% names(veg_sf)) {
    veg_field <- gayini_find_field(veg_sf, c("Vegetation", "vegetation"), "vegetation class")
  }

  lookup <- gayini_vegetation_group_lookup()

  detailed <- as.character(veg_sf[[veg_field]])

  simplified <- lookup$simplified_vegetation_group[match(detailed, lookup$detailed_vegetation)]
  simplified[is.na(simplified)] <- GAYINI_OTHER_COMMUNITY

  veg_sf$detailed_vegetation          <- detailed
  veg_sf$simplified_vegetation_group  <- factor(
    simplified,
    levels = c(gayini_community_levels(), GAYINI_OTHER_COMMUNITY)
  )

  veg_sf

}


## Dissolve the (already-simplified) vegetation polygons to one multipolygon per
## simplified community. Used by both the map and the plot/community QA.
gayini_dissolve_communities <- function(veg_simplified) {

  veg_simplified |>
    dplyr::group_by(.data$simplified_vegetation_group) |>
    dplyr::summarise(.groups = "drop") |>
    sf::st_make_valid()

}


## Reproject all vector layers to EPSG:8058 and write new copies ----
##
## Reads the four source shapefiles, transforms each to 8058 via
## to_analysis_crs(), attaches the simplified community to the vegetation layer,
## and writes `_epsg8058.gpkg` copies to Output/spatial_8058/. Originals are
## opened read-only and never written back.

gayini_reproject_vectors_8058 <- function(root = getwd(), target = GAYINI_ANALYSIS_EPSG) {

  sf::sf_use_s2(FALSE)

  shp <- function(name) gayini_path("Input", "shapefiles", name, root = root)

  out_dir <- gayini_path("Output", "spatial_8058", root = root)
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

  ## --- read sources (read-only) ---
  boundary_raw   <- gayini_read_vector(shp("gayini_boundary.shp"), label = "Gayini boundary")
  veg_raw        <- gayini_read_vector(shp("Gayini_Vegetation-classes-use.shp"), label = "vegetation classes")
  plots_raw      <- gayini_read_vector(shp("gayini_hectare_plots.shp"), label = "hectare plots")
  management_raw <- gayini_read_vector(shp("CA0561_ManagementZones.shp"), label = "management zones")

  ## --- reproject to 8058 (true orientation preserved; nothing snapped) ---
  boundary_8058   <- to_analysis_crs(boundary_raw, target = target)
  veg_8058        <- gayini_simplify_vegetation(to_analysis_crs(veg_raw, target = target))
  plots_8058      <- to_analysis_crs(plots_raw, target = target)
  management_8058 <- to_analysis_crs(management_raw, target = target)

  ## Standardise the plot id field to plot_id (source field is "Gayini.Nam").
  plot_id_field <- gayini_find_field(plots_8058, c("Gayini Nam", "Gayini_Nam", "Gayini.Nam", "plot_id"), "plot ID")
  plots_8058$plot_id <- as.character(plots_8058[[plot_id_field]])

  ## Dissolved community layer (one feature per simplified community).
  communities_8058 <- gayini_dissolve_communities(veg_8058)

  ## --- write _epsg8058 copies ---
  paths <- list(
    boundary    = file.path(out_dir, "gayini_boundary_epsg8058.gpkg"),
    vegetation  = file.path(out_dir, "vegetation_classes_epsg8058.gpkg"),
    communities = file.path(out_dir, "vegetation_communities_epsg8058.gpkg"),
    plots       = file.path(out_dir, "gayini_hectare_plots_epsg8058.gpkg"),
    management  = file.path(out_dir, "management_zones_epsg8058.gpkg")
  )

  gayini_write_sf_output(boundary_8058,   paths$boundary)
  gayini_write_sf_output(veg_8058,        paths$vegetation)
  gayini_write_sf_output(communities_8058, paths$communities)
  gayini_write_sf_output(plots_8058,      paths$plots)
  gayini_write_sf_output(management_8058, paths$management)

  list(
    boundary    = boundary_8058,
    vegetation  = veg_8058,
    communities = communities_8058,
    plots       = plots_8058,
    management  = management_8058,
    paths       = paths
  )

}


## Load dim_plot (authoritative community assignment + flags) ----

gayini_load_dim_plot <- function(db_path) {

  gayini_stop_if_missing(db_path, label = "results SQLite database")

  con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  DBI::dbGetQuery(
    con,
    "SELECT plot_id, simplified_vegetation_group, treed_plot_flag,
            ground_cover_exclusion_flag, spatial_review_flag,
            centroid_x, centroid_y
       FROM dim_plot"
  ) |>
    tibble::as_tibble()

}


## Plot / community spatial QA ----
##
## Joins the reprojected plots to their authoritative dim_plot community, then:
##   1. counts plot centroids that fall inside the property boundary (target 66)
##   2. tests whether each plot footprint intersects its ASSIGNED community
##      polygon, and logs every mismatch (never silently dropped)
##   3. flags the six known spatial-review plots

gayini_plot_community_qa <- function(plots_8058,
                                     communities_8058,
                                     boundary_8058,
                                     dim_plot,
                                     review_ids = c("GA_006", "GA_007", "GA_016", "GA_022", "GA_029", "GA_066")) {

  ## Attach authoritative community + flags from dim_plot.
  plots <- plots_8058 |>
    dplyr::left_join(dim_plot, by = "plot_id")

  ## Plot representative points (point_on_surface stays inside the polygon even
  ## for the angled survey squares).
  plot_points <- sf::st_point_on_surface(sf::st_geometry(plots))

  ## --- centroid-in-boundary ---
  boundary_union <- sf::st_union(sf::st_geometry(boundary_8058))
  in_boundary    <- lengths(sf::st_intersects(plot_points, boundary_union)) > 0
  plots$centroid_in_boundary <- in_boundary

  ## --- footprint vs assigned community ---
  ## Pre-compute per-community geometry for lookup.
  community_geom <- stats::setNames(
    lapply(as.character(communities_8058$simplified_vegetation_group), function(g) {
      sf::st_geometry(communities_8058[communities_8058$simplified_vegetation_group == g, ])
    }),
    as.character(communities_8058$simplified_vegetation_group)
  )

  assigned <- as.character(plots$simplified_vegetation_group)

  intersects_assigned <- vapply(seq_len(nrow(plots)), function(i) {
    g <- assigned[i]
    if (is.na(g) || is.null(community_geom[[g]])) return(NA)
    length(sf::st_intersects(sf::st_geometry(plots)[i], community_geom[[g]])[[1]]) > 0
  }, logical(1))

  plots$footprint_in_assigned_community <- intersects_assigned
  plots$is_spatial_review_plot <- plots$plot_id %in% review_ids

  ## Mismatch report: any plot whose footprint does NOT sit in its assigned
  ## community, plus the six spatial-review plots (kept even if they intersect).
  mismatch_report <- plots |>
    sf::st_drop_geometry() |>
    dplyr::transmute(
      plot_id = .data$plot_id,
      simplified_vegetation_group = .data$simplified_vegetation_group,
      centroid_in_boundary = .data$centroid_in_boundary,
      footprint_in_assigned_community = .data$footprint_in_assigned_community,
      spatial_review_flag = .data$spatial_review_flag,
      is_spatial_review_plot = .data$is_spatial_review_plot,
      issue = dplyr::case_when(
        is.na(.data$footprint_in_assigned_community) ~ "no_assigned_community_polygon",
        !.data$footprint_in_assigned_community ~ "footprint_outside_assigned_community",
        !.data$centroid_in_boundary ~ "centroid_outside_boundary",
        .data$is_spatial_review_plot ~ "spatial_review_plot_ok",
        TRUE ~ "ok"
      )
    ) |>
    dplyr::filter(.data$issue != "ok") |>
    dplyr::arrange(.data$issue, .data$plot_id)

  list(
    plots_qa = plots,
    n_centroids_in_boundary = sum(in_boundary),
    n_footprint_in_assigned = sum(intersects_assigned, na.rm = TRUE),
    mismatch_report = mismatch_report
  )

}


## Figures manifest helper ({step}_{concept|data} convention) ----

gayini_figure_manifest_row <- function(step, kind, path, inputs, crs, root = getwd()) {
  tibble::tibble(
    step   = step,
    kind   = kind,
    path   = gayini_relative_path_safe(root, path),
    inputs = inputs,
    crs    = crs
  )
}


gayini_relative_path_safe <- function(root, path) {
  rel <- tryCatch(fs::path_rel(path, start = root), error = function(e) path)
  as.character(rel)
}
