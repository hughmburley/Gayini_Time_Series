####################################################################################################


## GAYINI REMOTE SENSING PROJECT


## Minor helper functions used by run scripts and analysis functions.


####################################################################################################


## Package helpers ----


gayini_required_packages <- function(stage = c("setup", "vectors", "rasters", "all")) {


  stage <- match.arg(stage)


  packages <- switch(stage,


    setup = c("fs", "readr", "tibble"),


    vectors = c("sf", "dplyr", "readr", "tibble", "janitor", "ggplot2", "fs"),


    rasters = c("terra", "dplyr", "readr", "tibble", "stringr", "purrr", "lubridate", "fs"),


    all = c("sf", "terra", "exactextractr", "dplyr", "tidyr", "readr", "tibble", "stringr", "purrr", "lubridate", "magrittr", "janitor", "ggplot2", "fs", "bfast", "zoo")


  )


  unique(packages)


}


gayini_check_packages <- function(packages, install_missing = FALSE) {


  missing_packages <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]


  if (length(missing_packages) == 0) {


    message("All required packages are available.")


    return(invisible(TRUE))


  }


  if (isTRUE(install_missing)) {


    message("Installing missing packages: ", paste(missing_packages, collapse = ", "))


    utils::install.packages(missing_packages)


    return(invisible(TRUE))


  }


  stop(


    "Missing required packages: ",


    paste(missing_packages, collapse = ", "),


    "\nInstall them manually or set INSTALL_MISSING <- TRUE in the run script.",


    call. = FALSE


  )


}


## Path and folder helpers ----


gayini_path <- function(..., root = getwd()) {


  file.path(root, ...)


}


gayini_standard_dirs <- function() {


  c(


    "config",


    "config/class_legends",


    "docs",


    "Input",


    "Input/ads",


    "Input/landsat_fractionalcover3",


    "Input/landsat_inundation",


    "Input/modis_fractional_cover",


    "Input/sentinel2_inundation",


    "Input/shapefiles",


    "R",


    "scripts",


    "data_intermediate",


    "data_intermediate/spatial",


    "data_intermediate/raster_catalog",


    "data_intermediate/extraction_cache",


    "data_processed",


    "Output",


    "Output/csv",


    "Output/figures",


    "Output/figures/maps",


    "Output/reports",


    "Output/logs",


    "Output/diagnostics"


  )


}


gayini_make_dirs <- function(root = getwd(), dirs = gayini_standard_dirs()) {


  created <- character(0)


  for (dir in dirs) {


    target <- gayini_path(dir, root = root)


    if (!dir.exists(target)) {


      dir.create(target, recursive = TRUE, showWarnings = FALSE)


      created <- c(created, target)


    }


  }


  invisible(created)


}


gayini_stop_if_missing <- function(path, label = "path") {


  if (!file.exists(path)) {


    stop("Missing ", label, ": ", path, call. = FALSE)


  }


  invisible(TRUE)


}


gayini_write_csv <- function(x, path) {


  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)


  readr::write_csv(x, path)


  message("Wrote: ", path)


  invisible(path)


}


gayini_write_lines <- function(lines, path, append = FALSE) {


  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)


  writeLines(lines, con = path, useBytes = TRUE)


  message("Wrote: ", path)


  invisible(path)


}


gayini_timestamp <- function() {


  format(Sys.time(), "%Y%m%d_%H%M%S")


}


## Field helpers ----


gayini_find_field <- function(data, candidates, label) {


  clean_names <- janitor::make_clean_names(names(data))


  candidate_names <- janitor::make_clean_names(candidates)


  direct_match <- which(clean_names %in% candidate_names)


  if (length(direct_match) > 0) {


    return(names(data)[direct_match[1]])


  }


  stop(


    "Could not find required field for ", label, ". Looked for: ",


    paste(candidates, collapse = ", "),


    ". Available fields are: ",


    paste(names(data), collapse = ", "),


    call. = FALSE


  )


}


gayini_assert_unique <- function(x, label) {


  missing_count <- sum(is.na(x) | x == "")


  duplicate_count <- sum(duplicated(x[!(is.na(x) | x == "")]))


  if (missing_count > 0) {


    stop(label, " contains ", missing_count, " missing values.", call. = FALSE)


  }


  if (duplicate_count > 0) {


    stop(label, " contains ", duplicate_count, " duplicated values.", call. = FALSE)


  }


  invisible(TRUE)


}
