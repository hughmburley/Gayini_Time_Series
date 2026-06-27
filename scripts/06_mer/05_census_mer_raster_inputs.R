## -----------------------------------------------------------------------------
## Gayini remote sensing workflow
## 05_census_mer_raster_inputs.R
## -----------------------------------------------------------------------------


## Purpose:
## Read-only census of source rasters available for a possible MER-style annual
## maximum observed inundation raster workflow.


root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", "D:/Github_repos/Gayini"), winslash = "/", mustWork = TRUE)

source(file.path(root_dir, "R", "gayini_analysis_base_functions.R"))
source(file.path(root_dir, "R", "gayini_mer_raster_functions.R"))

census <- census_mer_raster_inputs(root_dir = root_dir, sample_size = 20000)

message("Census outputs:")
message("- Output/diagnostics/24_mer_raster_build/mer_raster_input_inventory.csv")
message("- Output/diagnostics/24_mer_raster_build/mer_raster_grid_compatibility.csv")
message("- Output/diagnostics/24_mer_raster_build/mer_raster_water_year_support.csv")
message("- Output/diagnostics/24_mer_raster_build/mer_raster_value_schema.csv")
message("- Output/diagnostics/24_mer_raster_build/mer_raster_build_readiness_checks.csv")
message("- Output/csv/MER/raster_build/flow_mer_vs_gayini_rs_data_census.csv")
message("- Output/figures/review/MER/raster_build/")

