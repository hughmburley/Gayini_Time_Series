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


## Plot layer preparation ----


gayini_prepare_plot_layer <- function(plots_raw, crs_target = 3577) {
  
  
  ## Find the required fields in the raw hectare-plot layer.
  plot_id_field <- gayini_find_field(plots_raw, c("Gayini Nam", "Gayini_Nam", "Gayini.Nam", "plot_id", "plot"), "plot ID")
  vegetation_field <- gayini_find_field(plots_raw, c("Vegetation", "vegetation"), "vegetation")
  treatment_field <- gayini_find_field(plots_raw, c("Treatment", "treatment"), "treatment")
  
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
    
    stop("Duplicate field names remain after case-normalisation: ",
      
      paste(duplicated_lower_names, collapse = ", "), call. = FALSEzzz
      
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


## Create plot area diagnostic flags ----


plot_area_flags <- plot_master |>
  
  
  dplyr::filter(area_ha < 0.8 | area_ha > 1.2) |>
  dplyr::arrange(area_ha)

readr::write_csv(
  
  plot_area_flags,
  file.path(output_diagnostics_dir, "plot_area_flags.csv")
  
)


if (nrow(plot_area_flags) > 0) {
  
  warning("Some plots have unusual areas. Check Output/diagnostics/plot_area_flags.csv",
    
    call. = FALSE)
  
}



## Create zoomed plot map diagnostic ----


plot_map_zoomed <- ggplot2::ggplot() +
  
  ggplot2::geom_sf(
    
    data = plots_clean,
    ggplot2::aes(fill = treatment),
    colour = "grey30",
    linewidth = 0.1) +
  
  ggplot2::coord_sf() +
  ggplot2::labs(
    
    title = "Gayini hectare plots by treatment",
    fill = "Treatment") +
  
  ggplot2::theme_minimal()

ggplot2::ggsave(
  filename = file.path(output_figures_dir, "plots_map_by_treatment_zoomed.png"),
  plot = plot_map_zoomed,
  width = 9,
  height = 7,
  dpi = 300
  
)



## Vector summary and diagnostics ----


gayini_vector_summary <- function(named_layers) {

  summaries <- lapply(names(named_layers), function(layer_name) {

    x <- named_layers[[layer_name]]
    
    tibble::tibble(
      
      layer = layer_name,
      feature_count = nrow(x),
      geometry_type = paste(unique(as.character(sf::st_geometry_type(x))), collapse = "; "),

      crs_epsg = sf::st_crs(x)$epsg,
      column_count = length(names(x)),
      columns = paste(names(sf::st_drop_geometry(x)), collapse = "; ")
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
    treatment_summary = treatment_summary,
    vegetation_summary = vegetation_summary,
    vegetation_treatment_summary = vegetation_treatment_summary
  )

}


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

    ggplot2::geom_sf(ggplot2::aes(fill = treatment), linewidth = 0.1) +
    ggplot2::labs(title = "Gayini hectare plots by treatment", fill = "Treatment") +
    ggplot2::theme_minimal()

  map_path <- file.path(out_dir, "plots_map_by_treatment.png")

  ggplot2::ggsave(map_path, plot_map, width = 8, height = 7, dpi = 300)
  tibble::tibble(check = c("treatment_bar_plot", "treatment_map"), path = c(treatment_path, map_path))

}


## Main vector preparation workflow ----


gayini_prepare_core_vectors <- function(root = getwd(), crs_target = 3577) {

  paths <- list(

    plots = gayini_path("Input", "shapefiles", "gayini_hectare_plots.shp", root = root),
    boundary = gayini_path("Input", "shapefiles", "gayini_boundary.shp", root = root),
    management_zones = gayini_path("Input", "shapefiles", "CA0561_ManagementZones.shp", root = root),
    vegetation_classes = gayini_path("Input", "shapefiles", "Gayini_Vegetation-classes-use.shp", root = root)

  )

  plots_raw   <- gayini_read_vector(paths$plots, label = "hectare plots")
  boundary_raw <- gayini_read_vector(paths$boundary, label = "Gayini boundary")
  management_raw <- gayini_read_vector(paths$management_zones, label = "management zones")
  vegetation_raw <- gayini_read_vector(paths$vegetation_classes, label = "vegetation classes")

  plots_clean    <- gayini_prepare_plot_layer(plots_raw, crs_target = crs_target)
  boundary_clean <- gayini_transform_vector(boundary_raw, crs_target = crs_target, label = "Gayini boundary")


  management_clean <- gayini_transform_vector(management_raw, crs_target = crs_target, label = "management zones")
  vegetation_clean <- gayini_transform_vector(vegetation_raw, crs_target = crs_target, label = "vegetation classes")
  plot_master <- gayini_make_plot_master(plots_clean)
  
  vector_summary <- gayini_vector_summary(list(

    plots_clean = plots_clean,
    boundary_clean = boundary_clean,
    management_clean = management_clean,
    vegetation_clean = vegetation_clean

  ))

  plot_summaries <- gayini_plot_summary_tables(plots_clean)
  spatial_dir <- gayini_path("data_intermediate", "spatial", root = root)
  csv_dir <- gayini_path("Output", "csv", root = root)
  diagnostics_dir <- gayini_path("Output", "diagnostics", root = root)
  figures_dir <- gayini_path("Output", "figures", root = root)

  sf::st_write(plots_clean, file.path(spatial_dir, "plots_clean.gpkg"), delete_dsn = TRUE, quiet = TRUE)
  sf::st_write(boundary_clean, file.path(spatial_dir, "boundary_clean.gpkg"), delete_dsn = TRUE, quiet = TRUE)


  sf::st_write(management_clean, file.path(spatial_dir, "management_zones_clean.gpkg"), delete_dsn = TRUE, quiet = TRUE)
  sf::st_write(vegetation_clean, file.path(spatial_dir, "vegetation_classes_clean.gpkg"), delete_dsn = TRUE, quiet = TRUE)

  gayini_write_csv(plot_master, gayini_path("data_processed", "plot_master.csv", root = root))
  gayini_write_csv(vector_summary, file.path(diagnostics_dir, "vector_layer_summary.csv"))

  gayini_write_csv(plot_summaries$treatment_summary, file.path(csv_dir, "plot_count_by_treatment.csv"))
  gayini_write_csv(plot_summaries$vegetation_summary, file.path(csv_dir, "plot_count_by_vegetation.csv"))

  gayini_write_csv(plot_summaries$vegetation_treatment_summary, file.path(csv_dir, "plot_count_by_vegetation_and_treatment.csv"))
  qc_plot_paths <- gayini_write_vector_qc_plots(plots_clean, figures_dir)

  gayini_write_csv(qc_plot_paths, file.path(diagnostics_dir, "vector_qc_plot_paths.csv"))

  checks <- tibble::tibble(

    check = c("plot_count", "unique_plot_ids", "mean_plot_area_ha", "min_plot_area_ha", "max_plot_area_ha"),
    value = c(nrow(plots_clean), length(unique(plots_clean$plot_id)), mean(plots_clean$area_ha), min(plots_clean$area_ha), max(plots_clean$area_ha))

  )

  gayini_write_csv(checks, file.path(diagnostics_dir, "vector_checks.csv"))

  list(
    plots_clean = plots_clean,
    boundary_clean = boundary_clean,
    management_clean = management_clean,
    vegetation_clean = vegetation_clean,
    plot_master = plot_master,
    checks = checks
  )

}




####################################################################################################
############################################ TBC ###################################################
####################################################################################################
