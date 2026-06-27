####################################################################
## Validate Gayini LOOC-B GeoJSON input files
####################################################################


required_packages <- c("sf", "dplyr", "readr", "jsonlite", "units")


missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]


if (length(missing_packages) > 0) {
  stop(
    "Install missing packages before continuing: ",
    paste(missing_packages, collapse = ", ")
  )
}


input_dir <- "INPUT/Gayini"


dir.create("OUTPUT/diagnostics", recursive = TRUE, showWarnings = FALSE)


json_files <- list.files(
  input_dir,
  pattern    = "\\.json$",
  full.names = TRUE
)


if (length(json_files) == 0) {
  stop("No GeoJSON files found in ", input_dir)
}


check_geojson <- function(path) {

  txt <- paste(readLines(path, warn = FALSE), collapse = "\n")

  json_ok <- jsonlite::validate(txt)

  if (!json_ok) {
    return(
      dplyr::tibble(
        file = path,
        json_valid = FALSE,
        readable_by_sf = FALSE,
        feature_count = NA_integer_,
        geometry_type = NA_character_,
        crs = NA_character_,
        area_ha = NA_real_,
        bbox_xmin = NA_real_,
        bbox_ymin = NA_real_,
        bbox_xmax = NA_real_,
        bbox_ymax = NA_real_
      )
    )
  }

  x <- sf::st_read(path, quiet = TRUE) %>%
    sf::st_zm(drop = TRUE, what = "ZM") %>%
    sf::st_make_valid()

  x_3577 <- x %>%
    sf::st_transform(3577)

  area_ha <- x_3577 %>%
    sf::st_area() %>%
    units::set_units("ha") %>%
    as.numeric() %>%
    sum(na.rm = TRUE)

  bbox <- sf::st_bbox(x)

  dplyr::tibble(
    file = path,
    json_valid = TRUE,
    readable_by_sf = TRUE,
    feature_count = nrow(x),
    geometry_type = paste(unique(as.character(sf::st_geometry_type(x))), collapse = "; "),
    crs = as.character(sf::st_crs(x)$epsg),
    area_ha = area_ha,
    bbox_xmin = as.numeric(bbox[["xmin"]]),
    bbox_ymin = as.numeric(bbox[["ymin"]]),
    bbox_xmax = as.numeric(bbox[["xmax"]]),
    bbox_ymax = as.numeric(bbox[["ymax"]])
  )
}


validation <- purrr::map_dfr(json_files, check_geojson)


readr::write_csv(
  validation,
  "OUTPUT/diagnostics/gayini_loocb_geojson_validation_standalone.csv"
)


print(validation)


if (any(!validation$json_valid | !validation$readable_by_sf)) {
  stop("One or more GeoJSON files failed validation.")
}


if (any(validation$feature_count != 1, na.rm = TRUE)) {
  warning("One or more GeoJSONs has more than one feature. LOOC-B examples usually use one dissolved feature.")
}


message("Validation report written to OUTPUT/diagnostics/gayini_loocb_geojson_validation_standalone.csv")
