####################################################################################################


## GAYINI REMOTE SENSING PROJECT


## Run script 02: catalogue raster files before any extraction or change detection.


####################################################################################################


## 0. User settings ----


INSTALL_MISSING <- FALSE


root_dir <- getwd()


## 1. Source helper and raster catalogue functions ----


source(file.path(root_dir, "R", "gayini_helpers.R"))


source(file.path(root_dir, "R", "raster_catalog_functions.R"))


## 2. Check packages and folders ----


raster_packages <- gayini_required_packages("rasters")


gayini_check_packages(raster_packages, install_missing = INSTALL_MISSING)


gayini_make_dirs(root = root_dir)


terra::terraOptions(memfrac = 0.8, tempdir = tempdir())


## 3. Confirm the raw Input folder exists ----


input_dir <- file.path(root_dir, "Input")


gayini_stop_if_missing(input_dir, label = "Input directory")


## 4. Build the raster catalogue ----


raster_catalog <- gayini_catalog_rasters(root = root_dir)


catalog_summaries <- gayini_write_raster_catalog_outputs(raster_catalog, root = root_dir)


## 5. Run expected-output checks ----


catalog_path  <- file.path(root_dir, "data_intermediate", "raster_catalog", "raster_catalog.csv")


summary_path  <- file.path(root_dir, "Output", "csv", "raster_product_summary.csv")


warnings_path <- file.path(root_dir, "Output", "diagnostics", "raster_catalog_warnings.csv")


gayini_stop_if_missing(catalog_path, label = "raster catalogue")


gayini_stop_if_missing(summary_path, label = "raster product summary")


gayini_stop_if_missing(warnings_path, label = "raster catalogue warnings")


if (nrow(catalog_summaries$warnings) > 0) {
  warning("Raster catalogue warnings were created. Review: ", warnings_path, call. = FALSE)
}


if (!any(raster_catalog$product == "landsat_fractional_cover")) {
  warning("No Landsat fractional cover rasters were detected. Check folder names and file extensions.", call. = FALSE)
}


if (!any(raster_catalog$product == "landsat_inundation")) {
  warning("No Landsat inundation rasters were detected. Check folder names and file extensions.", call. = FALSE)
}


if (!any(raster_catalog$product == "sentinel2_inundation")) {
  warning("No Sentinel-2 inundation rasters were detected. Check folder names and file extensions.", call. = FALSE)
}


## 6. Final user-facing summary ----


message("Raster catalogue complete.")


message("Readable raster catalogue rows: ", nrow(raster_catalog))


message("Raster catalogue warnings: ", nrow(catalog_summaries$warnings))


message("Key output: ", catalog_path)


message("Summary output: ", summary_path)


message("Warnings output: ", warnings_path)


message("Do not run extraction until the catalogue and class legends have been checked.")
