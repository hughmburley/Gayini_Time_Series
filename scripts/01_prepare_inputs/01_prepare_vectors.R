# ------------------------------------------------------------------------------
# Script: scripts/01_prepare_inputs/01_prepare_vectors.R
# Purpose: Prepare plot and boundary vector inputs.
# Workflow stage: 01_prepare_inputs
# Run mode: lightweight_review
# Heavy processing: no
# Key inputs:
#   - Input spatial source files.
# Key outputs:
#   - Clean vectors and vector diagnostics.
# Notes:
#   - Keep stable output filenames for downstream reports.
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Load configuration and execute workflow step
# ------------------------------------------------------------------------------
####################################################################################################


## GAYINI REMOTE SENSING PROJECT


## Run script 01: prepare vector data and create the plot master table.


####################################################################################################


## 0. User settings ----


INSTALL_MISSING <- TRUE
TARGET_CRS      <- 3577


root_dir       <- getwd()




## 1. Source helper and vector functions ----


source(file.path(root_dir, "R", "gayini_helpers.R"))
source(file.path(root_dir, "R", "vector_prep_functions.R"))




## 2. Check packages and folders ----


vector_packages <- gayini_required_packages("vectors")
gayini_check_packages(vector_packages, install_missing = INSTALL_MISSING)
gayini_make_dirs(root = root_dir)


sf::sf_use_s2(FALSE)




## 3. Confirm required input files are present ----


required_vector_files <- c(

  file.path(root_dir, "Input", "shapefiles", "gayini_hectare_plots.shp"),
  file.path(root_dir, "Input", "shapefiles", "gayini_boundary.shp"),
  file.path(root_dir, "Input", "shapefiles", "CA0561_ManagementZones.shp"),
  file.path(root_dir, "Input", "shapefiles", "Gayini_Vegetation-classes-use.shp")

)


for (path in required_vector_files) {

  gayini_stop_if_missing(path, label = "required vector file")

}


## 4. Prepare the core vector layers ----


vector_outputs <- gayini_prepare_core_vectors(root = root_dir, crs_target = TARGET_CRS)




## 5. Run expected-output checks ----


plot_master_path <- file.path(root_dir, "data_processed", "plot_master.csv")
plots_clean_path <- file.path(root_dir, "data_intermediate", "spatial", "plots_clean.gpkg")
modis_context_units_path <- file.path(root_dir, "data_intermediate", "spatial", "modis_context_units_clean.gpkg")
modis_context_summary_path <- file.path(root_dir, "Output", "csv", "modis_context_units_summary.csv")
modis_context_checks_path <- file.path(root_dir, "Output", "diagnostics", "modis_context_units_checks.csv")
gayini_stop_if_missing(plot_master_path, label = "plot master table")


gayini_stop_if_missing(plots_clean_path, label = "clean plot geopackage")
gayini_stop_if_missing(modis_context_units_path, label = "MODIS context unit geopackage")
gayini_stop_if_missing(modis_context_summary_path, label = "MODIS context unit summary")
gayini_stop_if_missing(modis_context_checks_path, label = "MODIS context unit checks")


if (nrow(vector_outputs$plots_clean) != 66) {

  warning("Expected 66 hectare plots, but found ", 
          nrow(vector_outputs$plots_clean), ". Check plot layer before continuing.")

}


if (any(vector_outputs$plots_clean$area_ha < 0.8 | vector_outputs$plots_clean$area_ha > 1.2)) {

  warning("Some plots are outside the expected 0.8 to 1.2 ha range. Check Output/diagnostics/vector_checks.csv.")

}




## 6. Final user-facing summary ----


message("Vector preparation complete.")
message("Key output: ", plot_master_path)
message("MODIS context units: ", modis_context_units_path)
message("Diagnostic plots are in: ", file.path(root_dir, "Output", "figures"))
message("Expected next step: run scripts/01_prepare_inputs/02_catalog_rasters.R")




####################################################################################################
############################################ TBC ###################################################
####################################################################################################
