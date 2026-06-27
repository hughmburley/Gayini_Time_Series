####################################################################
## Gayini LOOC-B GeoJSON input preparation
##
## Purpose:
##   Create LOOC-B-compatible GeoJSON inputs for Gayini:
##
##   INPUT/Gayini/Gayini_polygon.json
##   INPUT/Gayini/Gayini_planning_areas.json
##
## Expected source inputs:
##   1. Full Gayini property / analysis boundary
##   2. Grazing-exclusion / restoration planning area
##
## Notes:
##   - Output GeoJSONs are WGS84 / EPSG:4326, longitude-latitude.
##   - The script dissolves each source layer to one feature by default.
##   - This matches the existing LOOC-B INPUT examples.
####################################################################


required_packages <- c(
  "sf",
  "dplyr",
  "readr",
  "stringr",
  "purrr",
  "janitor",
  "jsonlite",
  "units"
)


missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]


if (length(missing_packages) > 0) {
  stop(
    "Install missing packages before continuing: ",
    paste(missing_packages, collapse = ", ")
  )
}


####################################################################
## Config
####################################################################


config_path <- "config/gayini_loocb_geojson_config_template.csv"


if (file.exists(config_path)) {

  config_tbl <- readr::read_csv(config_path, show_col_types = FALSE)

  cfg <- stats::setNames(config_tbl$value, config_tbl$setting)

} else {

  cfg <- c(
    farm_name             = "Gayini",
    boundary_path         = "data/source/gayini_boundary.shp",
    planning_area_path    = "data/source/gayini_grazing_exclusion.shp",
    output_root           = "INPUT",
    location              = "Murrumbidgee / Gayini",
    state                 = "NSW",
    livestock             = "Grazing",
    management            = "Conservation / grazing management",
    polygon_description   = "Property boundary",
    polygon_notes         = "Prepared for Gayini LOOC-B adaptation; confirm final boundary before API run.",
    dissolve_boundary     = "TRUE",
    dissolve_planning_area = "TRUE",
    simplify_tolerance_m  = "0"
  )
}


farm_name <- cfg[["farm_name"]]


farm_slug <- farm_name %>%
  stringr::str_replace_all("[^A-Za-z0-9]+", "_") %>%
  stringr::str_replace_all("^_|_$", "")


out_dir <- file.path(cfg[["output_root"]], farm_slug)


dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

dir.create("OUTPUT/diagnostics", recursive = TRUE, showWarnings = FALSE)


boundary_out <- file.path(out_dir, paste0(farm_slug, "_polygon.json"))


planning_out <- file.path(out_dir, paste0(farm_slug, "_planning_areas.json"))


####################################################################
## Helper functions
####################################################################


as_logical_config <- function(x) {

  tolower(as.character(x)) %in% c("true", "t", "1", "yes", "y")
}


read_clean_polygon <- function(path,
                               dissolve = TRUE,
                               simplify_tolerance_m = 0) {

  if (!file.exists(path)) {
    stop("Source vector file not found: ", path)
  }

  x <- sf::st_read(path, quiet = TRUE) %>%
    janitor::clean_names() %>%
    sf::st_zm(drop = TRUE, what = "ZM") %>%
    sf::st_make_valid()

  if (is.na(sf::st_crs(x))) {
    stop("Source layer has no CRS. Set the CRS before running: ", path)
  }

  x_3577 <- x %>%
    sf::st_transform(3577)

  if (simplify_tolerance_m > 0) {
    x_3577 <- x_3577 %>%
      sf::st_simplify(dTolerance = simplify_tolerance_m, preserveTopology = TRUE) %>%
      sf::st_make_valid()
  }

  if (isTRUE(dissolve)) {
    x_3577 <- x_3577 %>%
      dplyr::summarise(geometry = sf::st_union(geometry), .groups = "drop") %>%
      sf::st_make_valid()
  }

  x_3577 <- x_3577 %>%
    sf::st_collection_extract("POLYGON", warn = FALSE) %>%
    sf::st_make_valid()

  area_ha <- x_3577 %>%
    sf::st_area() %>%
    units::set_units("ha") %>%
    as.numeric() %>%
    sum(na.rm = TRUE)

  x_4326 <- x_3577 %>%
    sf::st_transform(4326)

  attr(x_4326, "area_ha") <- area_ha

  x_4326
}


make_boundary_feature <- function(x,
                                  farm_name,
                                  cfg) {

  area_ha <- attr(x, "area_ha")

  geom <- sf::st_geometry(x)

  sf::st_sf(
    fid        = 1L,
    PROPERTY   = farm_name,
    PROP_CODE  = farm_name,
    location   = cfg[["location"]],
    state      = cfg[["state"]],
    DESCRIPT   = cfg[["polygon_description"]],
    LIVESTOCK  = cfg[["livestock"]],
    MANAGEMENT = cfg[["management"]],
    notes      = cfg[["polygon_notes"]],
    Area_ha    = round(area_ha),
    geometry   = geom,
    crs        = 4326
  )
}


make_planning_feature <- function(x,
                                  farm_name) {

  sf::st_sf(
    PROPERTY = farm_name,
    geometry = sf::st_geometry(x),
    crs      = 4326
  )
}


write_loocb_geojson <- function(x,
                                out_path) {

  if (file.exists(out_path)) {
    file.remove(out_path)
  }

  sf::st_write(
    x,
    out_path,
    driver     = "GeoJSON",
    delete_dsn = TRUE,
    quiet      = TRUE
  )

  txt <- readLines(out_path, warn = FALSE)

  if (!jsonlite::validate(paste(txt, collapse = "\n"))) {
    stop("Invalid JSON written: ", out_path)
  }

  invisible(out_path)
}


validate_pair <- function(boundary_sf,
                          planning_sf,
                          boundary_path,
                          planning_path) {

  boundary_3577 <- boundary_sf %>%
    sf::st_transform(3577)

  planning_3577 <- planning_sf %>%
    sf::st_transform(3577)

  boundary_area_ha <- boundary_3577 %>%
    sf::st_area() %>%
    units::set_units("ha") %>%
    as.numeric() %>%
    sum(na.rm = TRUE)

  planning_area_ha <- planning_3577 %>%
    sf::st_area() %>%
    units::set_units("ha") %>%
    as.numeric() %>%
    sum(na.rm = TRUE)

  overlap_area_ha <- suppressWarnings(
    sf::st_intersection(
      sf::st_make_valid(planning_3577),
      sf::st_make_valid(boundary_3577)
    )
  ) %>%
    sf::st_area() %>%
    units::set_units("ha") %>%
    as.numeric() %>%
    sum(na.rm = TRUE)

  planning_inside_pct <- ifelse(
    planning_area_ha > 0,
    100 * overlap_area_ha / planning_area_ha,
    NA_real_
  )

  dplyr::tibble(
    file = c(boundary_path, planning_path),
    role = c("property_boundary", "planning_area"),
    feature_count = c(nrow(boundary_sf), nrow(planning_sf)),
    geometry_type = c(
      paste(unique(as.character(sf::st_geometry_type(boundary_sf))), collapse = "; "),
      paste(unique(as.character(sf::st_geometry_type(planning_sf))), collapse = "; ")
    ),
    area_ha = c(boundary_area_ha, planning_area_ha),
    json_valid = c(
      jsonlite::validate(paste(readLines(boundary_path, warn = FALSE), collapse = "\n")),
      jsonlite::validate(paste(readLines(planning_path, warn = FALSE), collapse = "\n"))
    ),
    planning_area_inside_boundary_pct = c(NA_real_, planning_inside_pct)
  )
}


####################################################################
## Build outputs
####################################################################


boundary_clean <- read_clean_polygon(
  path                 = cfg[["boundary_path"]],
  dissolve             = as_logical_config(cfg[["dissolve_boundary"]]),
  simplify_tolerance_m = as.numeric(cfg[["simplify_tolerance_m"]])
)


planning_clean <- read_clean_polygon(
  path                 = cfg[["planning_area_path"]],
  dissolve             = as_logical_config(cfg[["dissolve_planning_area"]]),
  simplify_tolerance_m = as.numeric(cfg[["simplify_tolerance_m"]])
)


boundary_feature <- make_boundary_feature(
  x         = boundary_clean,
  farm_name = farm_name,
  cfg       = cfg
)


planning_feature <- make_planning_feature(
  x         = planning_clean,
  farm_name = farm_name
)


write_loocb_geojson(boundary_feature, boundary_out)


write_loocb_geojson(planning_feature, planning_out)


validation <- validate_pair(
  boundary_sf   = boundary_feature,
  planning_sf   = planning_feature,
  boundary_path = boundary_out,
  planning_path = planning_out
)


readr::write_csv(
  validation,
  "OUTPUT/diagnostics/gayini_loocb_geojson_validation.csv"
)


message("Wrote: ", boundary_out)
message("Wrote: ", planning_out)
message("Wrote: OUTPUT/diagnostics/gayini_loocb_geojson_validation.csv")


if (validation$planning_area_inside_boundary_pct[validation$role == "planning_area"] < 99.9) {
  warning("Planning area may not be fully inside the Gayini boundary. Check diagnostics before API use.")
}
