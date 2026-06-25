####################################################################################################


## GAYINI REMOTE SENSING PROJECT


## Major vector preparation functions.


####################################################################################################


## Vector reading and standardisation ----


gayini_read_vector <- function(path, label = basename(path)) {

  gayini_stop_if_missing(path, label = label)

  message("Reading vector layer: ", label)

  x <- sf::st_read(path, quiet = TRUE)

  if (nrow(x) == 0) {
    stop("Vector layer has zero features: ", path, call. = FALSE)
  }

  if (any(!sf::st_is_valid(x))) {
    message("Repairing invalid geometries in: ", label)
    x <- sf::st_make_valid(x)
  }

  x

}


gayini_transform_vector <- function(x, crs_target = 3577, label = "vector layer") {

  if (is.na(sf::st_crs(x))) {
    stop("CRS is missing for ", label, ". Please define the CRS before continuing.", call. = FALSE)
  }

  sf::st_transform(x, crs_target)

}


## Plot layer preparation ----


gayini_prepare_plot_layer <- function(plots_raw, crs_target = 3577) {

  ## Find the required fields in the raw hectare-plot layer.
  plot_id_field    <- gayini_find_field(plots_raw, c("Gayini Nam", "Gayini_Nam", "Gayini.Nam", "plot_id", "plot"), "plot ID")
  vegetation_field <- gayini_find_field(plots_raw, c("Vegetation", "vegetation"), "vegetation")
  treatment_field  <- gayini_find_field(plots_raw, c("Treatment", "treatment"), "treatment")

  ## Create a working copy.
  plots <- plots_raw

  ## Add standardised analysis fields.
  plots$plot_id    <- as.character(plots[[plot_id_field]])
  plots$vegetation <- as.character(plots[[vegetation_field]])
  plots$treatment  <- as.character(plots[[treatment_field]])

  ## Remove the original source fields if they would collide with the new standard fields.
  fields_to_drop <- unique(c(plot_id_field, vegetation_field, treatment_field))
  fields_to_drop <- fields_to_drop[!fields_to_drop %in% c("plot_id", "vegetation", "treatment")]

  plots <- plots |>
    dplyr::select(-dplyr::any_of(fields_to_drop))

  ## Make sure plot IDs are complete and unique before continuing.
  gayini_assert_unique(plots$plot_id, "plot_id")

  ## Transform the plot layer to the target projected CRS.
  plots <- gayini_transform_vector(plots, crs_target = crs_target, label = "Gayini hectare plots")

  ## Calculate plot area in hectares.
  plots$area_ha <- as.numeric(sf::st_area(plots)) / 10000

  ## Calculate representative plot coordinates for tables and diagnostics.
  centroid_xy <- sf::st_coordinates(sf::st_point_on_surface(sf::st_geometry(plots)))

  plots$centroid_x <- centroid_xy[, 1]
  plots$centroid_y <- centroid_xy[, 2]

  ## Check that there are no duplicated field names after normalising case.
  duplicated_lower_names <- names(plots)[duplicated(tolower(names(plots)))]

  if (length(duplicated_lower_names) > 0) {
    stop(
      "Duplicate field names remain after case-normalisation: ",
      paste(duplicated_lower_names, collapse = ", "),
      call. = FALSE
    )
  }

  plots

}


gayini_make_plot_master <- function(plots_clean) {

  plots_clean |>
    sf::st_drop_geometry() |>
    dplyr::select(plot_id, vegetation, treatment, area_ha, centroid_x, centroid_y, dplyr::everything()) |>
    dplyr::distinct(plot_id, .keep_all = TRUE)

}


## Plot area diagnostics ----


gayini_make_plot_area_flags <- function(plot_master, min_area_ha = 0.8, max_area_ha = 1.2) {

  plot_master |>
    dplyr::filter(area_ha < min_area_ha | area_ha > max_area_ha) |>
    dplyr::arrange(area_ha)

}


## Vector summary and diagnostics ----


gayini_vector_summary <- function(named_layers) {

  summaries <- lapply(names(named_layers), function(layer_name) {

    x <- named_layers[[layer_name]]

    tibble::tibble(
      layer          = layer_name,
      feature_count  = nrow(x),
      geometry_type  = paste(unique(as.character(sf::st_geometry_type(x))), collapse = "; "),
      crs_epsg       = sf::st_crs(x)$epsg,
      column_count   = length(names(x)),
      columns        = paste(names(sf::st_drop_geometry(x)), collapse = "; ")
    )

  })

  dplyr::bind_rows(summaries)

}


gayini_plot_summary_tables <- function(plots_clean) {

  treatment_summary <- plots_clean |>
    sf::st_drop_geometry() |>
    dplyr::count(treatment, name = "plot_count") |>
    dplyr::arrange(dplyr::desc(plot_count))

  vegetation_summary <- plots_clean |>
    sf::st_drop_geometry() |>
    dplyr::count(vegetation, name = "plot_count") |>
    dplyr::arrange(dplyr::desc(plot_count))

  vegetation_treatment_summary <- plots_clean |>
    sf::st_drop_geometry() |>
    dplyr::count(vegetation, treatment, name = "plot_count") |>
    dplyr::arrange(vegetation, treatment)

  list(
    treatment_summary            = treatment_summary,
    vegetation_summary           = vegetation_summary,
    vegetation_treatment_summary = vegetation_treatment_summary
  )

}


gayini_make_vector_checks <- function(plots_clean) {

  tibble::tibble(
    check = c(
      "plot_count",
      "unique_plot_ids",
      "mean_plot_area_ha",
      "min_plot_area_ha",
      "max_plot_area_ha"
    ),
    value = c(
      nrow(plots_clean),
      length(unique(plots_clean$plot_id)),
      mean(plots_clean$area_ha),
      min(plots_clean$area_ha),
      max(plots_clean$area_ha)
    )
  )

}


## Vector diagnostic plots ----


gayini_write_vector_qc_plots <- function(plots_clean, out_dir) {

  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

  treatment_plot <- ggplot2::ggplot(sf::st_drop_geometry(plots_clean), ggplot2::aes(x = treatment)) +
    ggplot2::geom_bar() +
    ggplot2::coord_flip() +
    ggplot2::labs(title = "Gayini plots by treatment", x = "Treatment", y = "Plot count") +
    ggplot2::theme_minimal()

  treatment_path <- file.path(out_dir, "plots_by_treatment.png")

  ggplot2::ggsave(treatment_path, treatment_plot, width = 8, height = 5, dpi = 300)

  plot_map <- ggplot2::ggplot(plots_clean) +
    ggplot2::geom_sf(ggplot2::aes(fill = treatment), colour = "grey30", linewidth = 0.1) +
    ggplot2::labs(title = "Gayini hectare plots by treatment", fill = "Treatment") +
    ggplot2::theme_minimal()

  map_path <- file.path(out_dir, "plots_map_by_treatment.png")

  ggplot2::ggsave(map_path, plot_map, width = 8, height = 7, dpi = 300)

  plot_map_zoomed <- ggplot2::ggplot() +
    ggplot2::geom_sf(data = plots_clean, ggplot2::aes(fill = treatment), colour = "grey30", linewidth = 0.1) +
    ggplot2::coord_sf() +
    ggplot2::labs(title = "Gayini hectare plots by treatment", fill = "Treatment") +
    ggplot2::theme_minimal()

  zoomed_map_path <- file.path(out_dir, "plots_map_by_treatment_zoomed.png")

  ggplot2::ggsave(zoomed_map_path, plot_map_zoomed, width = 9, height = 7, dpi = 300)

  tibble::tibble(
    check = c("treatment_bar_plot", "treatment_map", "treatment_map_zoomed"),
    path  = c(treatment_path, map_path, zoomed_map_path)
  )

}


## Spatial output writing ----


gayini_write_sf_output <- function(x, path) {

  output_dir <- dirname(path)

  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  }

  if (file.exists(path)) {
    unlink(path, force = TRUE)
  }

  sf::st_write(x, path, quiet = TRUE)

  if (!file.exists(path)) {
    stop("Spatial output was not created: ", path, call. = FALSE)
  }

invisible(path)

}


## MODIS context-unit preparation ----


gayini_first_existing_vector_field <- function(x, candidate_fields) {

  clean_names <- janitor::make_clean_names(names(sf::st_drop_geometry(x)))
  clean_candidates <- janitor::make_clean_names(candidate_fields)
  field_index <- which(clean_names %in% clean_candidates)

  if (length(field_index) == 0) {
    return(NA_character_)
  }

  names(sf::st_drop_geometry(x))[field_index[1]]

}


gayini_clean_polygon_layer <- function(x) {

  x <- sf::st_make_valid(x)

  suppressWarnings({
    x <- sf::st_collection_extract(x, "POLYGON")
  })

  x[!sf::st_is_empty(x), ]

}


gayini_make_single_context_unit <- function(geometry, unit_id, unit_type, source_name) {

  sf::st_sf(
    unit_id     = unit_id,
    unit_type   = unit_type,
    source_name = source_name,
    geometry    = geometry
  )

}


gayini_make_context_id_suffix <- function(x) {

  suffix <- janitor::make_clean_names(as.character(x))
  suffix <- sub("^x([0-9])", "\\1", suffix)
  suffix

}


gayini_make_modis_context_units <- function(boundary_clean,
                                            management_clean = NULL,
                                            paddocks_clean = NULL,
                                            crs_target = 3577,
                                            include_paddocks = TRUE) {

  boundary_clean <- gayini_clean_polygon_layer(boundary_clean)
  boundary_union <- sf::st_union(sf::st_geometry(boundary_clean))

  farm_unit <- gayini_make_single_context_unit(
    geometry    = sf::st_sfc(boundary_union, crs = sf::st_crs(boundary_clean)),
    unit_id     = "gayini_farm",
    unit_type   = "farm",
    source_name = "Gayini farm boundary"
  )

  buffer_5km <- gayini_make_single_context_unit(
    geometry    = sf::st_sfc(sf::st_buffer(boundary_union, dist = 5000), crs = sf::st_crs(boundary_clean)),
    unit_id     = "gayini_buffer_5km",
    unit_type   = "farm_buffer_5km",
    source_name = "Gayini farm boundary plus 5 km buffer"
  )

  buffer_10km <- gayini_make_single_context_unit(
    geometry    = sf::st_sfc(sf::st_buffer(boundary_union, dist = 10000), crs = sf::st_crs(boundary_clean)),
    unit_id     = "gayini_buffer_10km",
    unit_type   = "farm_buffer_10km",
    source_name = "Gayini farm boundary plus 10 km buffer"
  )

  context_units <- list(farm_unit, buffer_5km, buffer_10km)

  if (!is.null(management_clean) && nrow(management_clean) > 0) {
    management_clean <- gayini_clean_polygon_layer(management_clean)

    management_intersection <- suppressWarnings(
      sf::st_intersection(management_clean, farm_unit |> sf::st_geometry())
    )

    if (nrow(management_intersection) > 0) {
      management_id_field <- gayini_first_existing_vector_field(
        management_intersection,
        c("management_zone", "management", "zone", "zone_id", "name", "id")
      )

      if (is.na(management_id_field)) {
        management_source_name <- as.character(seq_len(nrow(management_intersection)))
      } else {
        management_source_name <- as.character(management_intersection[[management_id_field]])
        management_source_name[is.na(management_source_name) | management_source_name == ""] <-
          as.character(which(is.na(management_source_name) | management_source_name == ""))
      }

      management_units <- sf::st_sf(
        unit_id = paste0("management_zone_", gayini_make_context_id_suffix(management_source_name)),
        unit_type = "management_zone",
        source_name = management_source_name,
        geometry = sf::st_geometry(management_intersection)
      ) |>
        dplyr::mutate(unit_id = make.unique(.data$unit_id, sep = "_"))

      context_units <- c(context_units, list(management_units))
    }
  }

  if (isTRUE(include_paddocks) && !is.null(paddocks_clean) && nrow(paddocks_clean) > 0) {
    paddocks_clean <- gayini_clean_polygon_layer(paddocks_clean)

    paddock_intersection <- suppressWarnings(
      sf::st_intersection(paddocks_clean, farm_unit |> sf::st_geometry())
    )

    if (nrow(paddock_intersection) > 0) {
      paddock_id_field <- gayini_first_existing_vector_field(
        paddock_intersection,
        c("paddock", "paddock_id", "name", "id")
      )

      if (is.na(paddock_id_field)) {
        paddock_source_name <- as.character(seq_len(nrow(paddock_intersection)))
      } else {
        paddock_source_name <- as.character(paddock_intersection[[paddock_id_field]])
        paddock_source_name[is.na(paddock_source_name) | paddock_source_name == ""] <-
          as.character(which(is.na(paddock_source_name) | paddock_source_name == ""))
      }

      paddock_units <- sf::st_sf(
        unit_id = paste0("paddock_", gayini_make_context_id_suffix(paddock_source_name)),
        unit_type = "paddock",
        source_name = paddock_source_name,
        geometry = sf::st_geometry(paddock_intersection)
      ) |>
        dplyr::mutate(unit_id = make.unique(.data$unit_id, sep = "_"))

      context_units <- c(context_units, list(paddock_units))
    }
  }

  output_units <- dplyr::bind_rows(context_units) |>
    gayini_clean_polygon_layer() |>
    sf::st_transform(crs_target)

  output_units$area_ha <- as.numeric(sf::st_area(output_units)) / 10000
  output_units$effective_modis_pixel_estimate <- output_units$area_ha / 25

  output_units |>
    dplyr::select(
      unit_id,
      unit_type,
      source_name,
      area_ha,
      effective_modis_pixel_estimate,
      geometry
    ) |>
    dplyr::arrange(.data$unit_type, .data$unit_id)

}


gayini_make_modis_context_unit_checks <- function(modis_context_units,
                                                  low_pixel_threshold = 5) {

  dplyr::bind_rows(
    tibble::tibble(
      check_name  = "context_unit_count",
      check_value = as.character(nrow(modis_context_units)),
      status      = ifelse(nrow(modis_context_units) > 0, "pass", "fail"),
      notes       = "MODIS context units should include farm, 5 km buffer, 10 km buffer and any clean larger units."
    ),
    tibble::tibble(
      check_name  = "unique_unit_ids",
      check_value = as.character(dplyr::n_distinct(modis_context_units$unit_id)),
      status      = ifelse(dplyr::n_distinct(modis_context_units$unit_id) == nrow(modis_context_units), "pass", "fail"),
      notes       = "Each MODIS context unit must have a unique unit_id."
    ),
    tibble::tibble(
      check_name  = "invalid_geometries",
      check_value = as.character(sum(!sf::st_is_valid(modis_context_units))),
      status      = ifelse(any(!sf::st_is_valid(modis_context_units)), "fail", "pass"),
      notes       = "Invalid context-unit geometries should be repaired before extraction."
    ),
    tibble::tibble(
      check_name  = "low_effective_modis_pixel_estimate",
      check_value = as.character(sum(modis_context_units$effective_modis_pixel_estimate < low_pixel_threshold, na.rm = TRUE)),
      status      = ifelse(any(modis_context_units$effective_modis_pixel_estimate < low_pixel_threshold, na.rm = TRUE), "warn", "pass"),
      notes       = paste0("Units below ", low_pixel_threshold, " approximate 500 m MODIS pixels are exploratory context only.")
    ),
    tibble::tibble(
      check_name  = "one_ha_plots_excluded",
      check_value = as.character(sum(modis_context_units$unit_type %in% c("plot", "hectare_plot", "one_ha_plot"))),
      status      = ifelse(any(modis_context_units$unit_type %in% c("plot", "hectare_plot", "one_ha_plot")), "fail", "pass"),
      notes       = "1 ha plots must not be used as MODIS extraction units."
    )
  )

}


gayini_find_optional_paddock_path <- function(root = getwd()) {

  shapefile_dir <- gayini_path("Input", "shapefiles", root = root)

  if (!dir.exists(shapefile_dir)) {
    return(NA_character_)
  }

  paddock_paths <- list.files(
    shapefile_dir,
    pattern = "paddock.*\\.shp$|pdk.*\\.shp$",
    full.names = TRUE,
    ignore.case = TRUE
  )

  if (length(paddock_paths) == 0) {
    return(NA_character_)
  }

  paddock_paths[1]

}


## Main vector preparation workflow ----


gayini_prepare_core_vectors <- function(root = getwd(), crs_target = 3577) {

  paths <- list(
    plots              = gayini_path("Input", "shapefiles", "gayini_hectare_plots.shp", root = root),
    boundary           = gayini_path("Input", "shapefiles", "gayini_boundary.shp", root = root),
    management_zones   = gayini_path("Input", "shapefiles", "CA0561_ManagementZones.shp", root = root),
    vegetation_classes = gayini_path("Input", "shapefiles", "Gayini_Vegetation-classes-use.shp", root = root)
  )

  spatial_dir     <- gayini_path("data_intermediate", "spatial", root = root)
  csv_dir         <- gayini_path("Output", "csv", root = root)
  diagnostics_dir <- gayini_path("Output", "diagnostics", root = root)
  figures_dir     <- gayini_path("Output", "figures", root = root)

  dir.create(spatial_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(csv_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(diagnostics_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(figures_dir, recursive = TRUE, showWarnings = FALSE)

  plots_raw      <- gayini_read_vector(paths$plots, label = "hectare plots")
  boundary_raw   <- gayini_read_vector(paths$boundary, label = "Gayini boundary")
  management_raw <- gayini_read_vector(paths$management_zones, label = "management zones")
  vegetation_raw <- gayini_read_vector(paths$vegetation_classes, label = "vegetation classes")
  paddock_path   <- gayini_find_optional_paddock_path(root = root)
  paddocks_raw   <- if (!is.na(paddock_path)) gayini_read_vector(paddock_path, label = "optional paddock layer") else NULL

  plots_clean      <- gayini_prepare_plot_layer(plots_raw, crs_target = crs_target)
  boundary_clean   <- gayini_transform_vector(boundary_raw, crs_target = crs_target, label = "Gayini boundary")
  management_clean <- gayini_transform_vector(management_raw, crs_target = crs_target, label = "management zones")
  vegetation_clean <- gayini_transform_vector(vegetation_raw, crs_target = crs_target, label = "vegetation classes")
  paddocks_clean   <- if (!is.null(paddocks_raw)) gayini_transform_vector(paddocks_raw, crs_target = crs_target, label = "optional paddock layer") else NULL
  modis_context_units <- gayini_make_modis_context_units(
    boundary_clean    = boundary_clean,
    management_clean  = management_clean,
    paddocks_clean    = paddocks_clean,
    crs_target        = crs_target,
    include_paddocks  = TRUE
  )

  plot_master    <- gayini_make_plot_master(plots_clean)
  vector_summary <- gayini_vector_summary(list(
    plots_clean      = plots_clean,
    boundary_clean   = boundary_clean,
    management_clean = management_clean,
    vegetation_clean = vegetation_clean,
    modis_context_units = modis_context_units
  ))

  plot_summaries <- gayini_plot_summary_tables(plots_clean)
  checks         <- gayini_make_vector_checks(plots_clean)
  modis_context_checks <- gayini_make_modis_context_unit_checks(modis_context_units)
  modis_context_summary <- modis_context_units |>
    sf::st_drop_geometry() |>
    dplyr::arrange(.data$unit_type, .data$unit_id)
  plot_area_flags <- gayini_make_plot_area_flags(plot_master)

  gayini_write_sf_output(plots_clean, file.path(spatial_dir, "plots_clean.gpkg"))
  gayini_write_sf_output(boundary_clean, file.path(spatial_dir, "boundary_clean.gpkg"))
  gayini_write_sf_output(management_clean, file.path(spatial_dir, "management_zones_clean.gpkg"))
  gayini_write_sf_output(vegetation_clean, file.path(spatial_dir, "vegetation_classes_clean.gpkg"))
  gayini_write_sf_output(modis_context_units, file.path(spatial_dir, "modis_context_units_clean.gpkg"))

  gayini_write_csv(plot_master, gayini_path("data_processed", "plot_master.csv", root = root))
  gayini_write_csv(vector_summary, file.path(diagnostics_dir, "vector_layer_summary.csv"))
  gayini_write_csv(checks, file.path(diagnostics_dir, "vector_checks.csv"))
  gayini_write_csv(modis_context_checks, file.path(diagnostics_dir, "modis_context_units_checks.csv"))
  gayini_write_csv(plot_area_flags, file.path(diagnostics_dir, "plot_area_flags.csv"))

  gayini_write_csv(plot_summaries$treatment_summary, file.path(csv_dir, "plot_count_by_treatment.csv"))
  gayini_write_csv(plot_summaries$vegetation_summary, file.path(csv_dir, "plot_count_by_vegetation.csv"))
  gayini_write_csv(plot_summaries$vegetation_treatment_summary, file.path(csv_dir, "plot_count_by_vegetation_and_treatment.csv"))
  gayini_write_csv(modis_context_summary, file.path(csv_dir, "modis_context_units_summary.csv"))

  qc_plot_paths <- gayini_write_vector_qc_plots(plots_clean, figures_dir)

  gayini_write_csv(qc_plot_paths, file.path(diagnostics_dir, "vector_qc_plot_paths.csv"))

  if (nrow(plot_area_flags) > 0) {
    warning("Some plots have unusual areas. Check Output/diagnostics/plot_area_flags.csv", call. = FALSE)
  }

  list(
    plots_clean       = plots_clean,
    boundary_clean    = boundary_clean,
    management_clean  = management_clean,
    vegetation_clean  = vegetation_clean,
    modis_context_units = modis_context_units,
    modis_context_checks = modis_context_checks,
    plot_master       = plot_master,
    plot_area_flags   = plot_area_flags,
    checks            = checks,
    vector_summary    = vector_summary,
    qc_plot_paths     = qc_plot_paths
  )

}



####################################################################################################
############################################ TBC ###################################################
####################################################################################################
