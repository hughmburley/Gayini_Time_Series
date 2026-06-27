####################################################################################################


## GAYINI REMOTE SENSING PROJECT


## Run script 00: set up folders, package checks, and template lookup files.


####################################################################################################


## 0. User settings ----


INSTALL_MISSING <- FALSE
UPDATE_EXISTING_LEGENDS <- TRUE


root_dir <- getwd()


## 1. Source helper functions ----


source(file.path(root_dir, "R", "gayini_helpers.R"))




## 2. Check packages needed for setup ----


setup_packages <- gayini_required_packages("setup")
gayini_check_packages(setup_packages, install_missing = INSTALL_MISSING)




## 3. Create the project folder scaffold ----


created_dirs <- gayini_make_dirs(root = root_dir)


dir.create(file.path(root_dir, "config", "class_legends"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(root_dir, "Output", "archive", "config"), recursive = TRUE, showWarnings = FALSE)


message("Folder setup complete.")
message("New folders created: ", length(created_dirs))




## 4. Create / update template lookup files ----


## Fractional cover / ground-cover band legend ----
##
## Authoritative mapping for the TERN/JRSRP Seasonal Ground Cover Landsat product:
##   band 1 = bare ground fraction (%)
##   band 2 = green vegetation fraction (%)
##   band 3 = non-green vegetation fraction (%)
##   NoData = 255
##
## This replaces the provisional older project mapping. If an existing legend
## file uses the old mapping, it is archived and replaced when
## UPDATE_EXISTING_LEGENDS is TRUE.


fractional_cover_template <- tibble::tibble(

  band_number = c(1L, 2L, 3L),
  assumed_variable = c("bare_ground", "green_vegetation", "non_green_vegetation"),
  display_label = c("Bare ground", "Green / PV", "Non-green / NPV"),
  units = c("percent", "percent", "percent"),
  nodata_value = c(255L, 255L, 255L),
  source = c("TERN/JRSRP seasonal ground cover metadata", "TERN/JRSRP seasonal ground cover metadata", "TERN/JRSRP seasonal ground cover metadata"),
  confirmed = c(TRUE, TRUE, TRUE),
  notes = c(
    "Band 1 is bare ground fraction in percent.",
    "Band 2 is green vegetation fraction in percent.",
    "Band 3 is non-green vegetation fraction in percent."
  )

)


fractional_cover_path <- file.path(root_dir, "config", "class_legends", "fractional_cover_bands.csv")


write_fractional_cover_legend <- FALSE


if (!file.exists(fractional_cover_path)) {

  write_fractional_cover_legend <- TRUE

} else {

  existing_fractional_cover <- readr::read_csv(fractional_cover_path, show_col_types = FALSE)

  existing_band_1 <- as.character(
    existing_fractional_cover$assumed_variable[existing_fractional_cover$band_number == 1]
  )

  legend_outdated <- length(existing_band_1) == 0 || !identical(existing_band_1[[1]], "bare_ground")

  if (legend_outdated && UPDATE_EXISTING_LEGENDS) {

    archive_path <- file.path(
      root_dir,
      "Output",
      "archive",
      "config",
      paste0("fractional_cover_bands_PRE_TERN_UPDATE_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".csv")
    )

    file.copy(fractional_cover_path, archive_path, overwrite = TRUE)
    message("Archived old fractional-cover band legend to: ", archive_path)

    write_fractional_cover_legend <- TRUE

  }

}


if (write_fractional_cover_legend) {

  readr::write_csv(fractional_cover_template, fractional_cover_path)
  message("Wrote TERN/JRSRP fractional-cover band legend: ", fractional_cover_path)

} else {

  message("Fractional-cover band legend already matches TERN/JRSRP mapping: ", fractional_cover_path)

}


## Inundation class legend ----


inundation_template <- tibble::tibble(

  product = c(
    "landsat_inundation",
    "landsat_inundation",
    "landsat_inundation",
    "daily_inundation",
    "daily_inundation",
    "daily_inundation",
    "daily_inundation"
  ),

  class_value = c(0, 1, 2, 0, 1, 2, 3),

  assumed_meaning = c(
    "not_inundated_or_background",
    "inundated_or_wet_count",
    "inundated_or_wet_count_uncertain",
    "not_inundated",
    "inundated",
    "ors_or_mixed_water_uncertain",
    "cloud_shadow_or_invalid"
  ),

  primary_valid_rule = c(TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE),
  primary_wet_rule = c(FALSE, TRUE, TRUE, FALSE, TRUE, FALSE, FALSE),
  sensitivity_wet_rule_include_value_2 = c(FALSE, TRUE, TRUE, FALSE, TRUE, TRUE, FALSE),

  confirmed = c(FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE),

  notes = c(
    "Annual Landsat/NSW class 0 currently treated as dry/background.",
    "Annual Landsat/NSW values > 0 currently treated as annual wet occurrence.",
    "Confirm whether value 2 means inundated/mixed/ORS before final interpretation.",
    "Daily value 0 is valid dry under the current conservative rule.",
    "Daily value 1 is the primary wet class.",
    "Daily value 2 is kept valid but dry in strict_value_1; include in sensitivity if Adrian confirms.",
    "Daily value 3 is treated as cloud/shadow or invalid, not dry."
  )

)


inundation_path <- file.path(root_dir, "config", "class_legends", "inundation_classes.csv")


if (!file.exists(inundation_path)) {

  readr::write_csv(inundation_template, inundation_path)
  message("Wrote inundation class legend template: ", inundation_path)

}


## Land-use table ----


landuse_template <- tibble::tibble(

  plot_id = character(),
  landuse_past = character(),
  landuse_present = character(),
  image_date_past = as.Date(character()),
  image_date_present = as.Date(character()),
  classification_confidence = character(),
  analyst = character(),
  qa_status = character(),
  evidence_notes = character()

)


landuse_path <- file.path(root_dir, "data_processed", "plot_landuse_classification.csv")


if (!file.exists(landuse_path)) {

  readr::write_csv(landuse_template, landuse_path)

}


## 5. Write a setup log for this run ----


setup_log <- c(

  paste("Run date:", Sys.time()),
  paste("Project root:", root_dir),
  paste("New folders created:", length(created_dirs)),
  paste("Fractional cover band legend:", fractional_cover_path),
  paste("Inundation class template:", inundation_path),
  paste("Land-use classification template:", landuse_path),
  paste("UPDATE_EXISTING_LEGENDS:", UPDATE_EXISTING_LEGENDS)

)


gayini_write_lines(
  setup_log,
  file.path(root_dir, "Output", "logs", paste0("setup_log_", gayini_timestamp(), ".txt"))
)




## 6. Final user-facing checks ----


message("Expected next step: run scripts/01_prepare_inputs/01_prepare_vectors.R")
message("Before running 01_prepare_vectors.R, make sure the shapefiles are under Input/shapefiles/.")




####################################################################################################
############################################ TBC ###################################################
####################################################################################################
