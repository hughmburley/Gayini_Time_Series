#!/usr/bin/env Rscript
# T1 Gate B1 (read-only helper) - resolve each spatial_layer_asset row to its
# registered file and read the ACTUAL field names, in file order. Emits
# Output/tables/T1_gateB1_field_lists.csv for the Python migration to consume.
# read_registered_layer's contract is "compare the file's actual fields to the
# registered field_list", so field_list must be the registered file's own fields.

suppressPackageStartupMessages({library(sf); library(DBI); library(RSQLite)})

root <- normalizePath(".", winslash = "/")
db   <- file.path(root, "Output/database/Gayini_Results.sqlite")
zip  <- file.path(root, "Input/shapefiles.zip")
gpkg_companion <- file.path(root, "Output/database/Gayini_Results.gpkg")

con <- DBI::dbConnect(RSQLite::SQLite(), db, flags = RSQLite::SQLITE_RO)
sla <- DBI::dbGetQuery(con, "SELECT spatial_layer_asset_id, layer_name, path, source_crs FROM spatial_layer_asset ORDER BY spatial_layer_asset_id")
DBI::dbDisconnect(con)

# layer_name -> shapefile inside the zip (from R/vector_prep_functions.R paths)
shp_in_zip <- c(
  plots_source     = "shapefiles/gayini_hectare_plots.shp",
  gayini_boundary  = "shapefiles/gayini_boundary.shp",
  vegetation_units = "shapefiles/Gayini_Vegetation-classes-use.shp",
  management_zones = "shapefiles/CA0561_ManagementZones.shp"
)

read_fields <- function(dsn, layer = NULL) {
  tryCatch({
    x <- if (is.null(layer)) sf::st_read(dsn, quiet = TRUE) else sf::st_read(dsn, layer = layer, quiet = TRUE)
    nm <- names(sf::st_drop_geometry(x))
    list(fields = nm, ok = TRUE, msg = "")
  }, error = function(e) list(fields = character(0), ok = FALSE, msg = conditionMessage(e)))
}

out <- lapply(seq_len(nrow(sla)), function(k) {
  id <- sla$spatial_layer_asset_id[k]; ln <- sla$layer_name[k]
  if (id == "spatial_006") {
    dsn <- file.path(root, "Output/spatial_8058/management_zones_epsg8058.gpkg"); r <- read_fields(dsn)
    resolved <- "Output/spatial_8058/management_zones_epsg8058.gpkg"
  } else if (ln %in% names(shp_in_zip)) {
    inner <- shp_in_zip[[ln]]; dsn <- paste0("/vsizip/", zip, "/", inner); r <- read_fields(dsn)
    resolved <- paste0("Input/shapefiles.zip::", inner)
  } else if (id == "spatial_005") {
    # gauge db (sqlite); try the gauge_sites layer
    dsn <- sla$path[k]; r <- read_fields(dsn, layer = "gauge_sites"); resolved <- dsn
  } else { r <- list(fields = character(0), ok = FALSE, msg = "no resolver"); resolved <- sla$path[k] }
  data.frame(spatial_layer_asset_id = id, layer_name = ln,
             registered_path = sla$path[k], resolved_file = resolved,
             field_list = paste(r$fields, collapse = ","),
             n_fields = length(r$fields), readable = r$ok, note = r$msg,
             stringsAsFactors = FALSE)
})
res <- do.call(rbind, out)

# Extra: also read the lowercase 28355 map companion (Gayini_Results.gpkg:
# management_zones) so we can compare it against spatial_004's actual shapefile.
comp <- read_fields(gpkg_companion, layer = "management_zones")
cat("=== 28355 map companion Gayini_Results.gpkg:management_zones ===\n")
cat("  readable:", comp$ok, "| fields:", paste(comp$fields, collapse = ","), "\n\n")

write.csv(res, file.path(root, "Output/tables/T1_gateB1_field_lists.csv"), row.names = FALSE)
print(res[, c("spatial_layer_asset_id", "layer_name", "resolved_file", "field_list", "readable")],
      row.names = FALSE)
cat("\n[done] -> Output/tables/T1_gateB1_field_lists.csv\n")
