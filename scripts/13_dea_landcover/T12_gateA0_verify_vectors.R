#!/usr/bin/env Rscript
# T12 — Gate A0 vector verification + facts emitter.
# Reads the three standalone EPSG:8058 vector inputs (siblings of spatial_006 in
# Output/spatial_8058/), asserts CRS/feature-count/validity, reads each file's own
# field list (read_registered_layer's contract), and emits the facts CSV the
# Python registrar consumes. Read-only against the vectors; writes one CSV only.
# Spec docs/reference_update/T12_dea_landcover_l3_extraction.md v2, Gate A0.

suppressPackageStartupMessages({library(sf)})
root <- "d:/Github_repos/Gayini"
spec <- list(
  list(id = "spatial_007", alias = "gayini_boundary_8058",
       file = "Output/spatial_8058/gayini_boundary_epsg8058.gpkg", expect_n = 1),
  list(id = "spatial_008", alias = "gayini_hectare_plots_8058",
       file = "Output/spatial_8058/gayini_hectare_plots_epsg8058.gpkg", expect_n = 66),
  list(id = "spatial_009", alias = "vegetation_communities_8058",
       file = "Output/spatial_8058/vegetation_communities_epsg8058.gpkg", expect_n = 5)
)
rows <- lapply(spec, function(s) {
  x <- st_read(file.path(root, s$file), quiet = TRUE)
  fields <- names(st_drop_geometry(x))
  inv_before <- sum(!st_is_valid(x), na.rm = TRUE)
  data.frame(spatial_layer_asset_id = s$id, alias = s$alias, file = s$file,
    epsg = st_crs(x)$epsg, feature_count = nrow(x), expect_n = s$expect_n,
    geometry_type = toupper(paste(unique(as.character(st_geometry_type(x))), collapse = "/")),
    invalid_before = inv_before, field_list = paste(fields, collapse = ","),
    ok = (st_crs(x)$epsg == 8058 && nrow(x) == s$expect_n && inv_before == 0),
    stringsAsFactors = FALSE)
})
res <- do.call(rbind, rows)
print(res[, c("spatial_layer_asset_id", "epsg", "feature_count", "expect_n",
              "geometry_type", "invalid_before", "ok")], row.names = FALSE)
write.csv(res, file.path(root, "Output/tables/T12_gateA0_vector_facts.csv"), row.names = FALSE)
cat("\n[facts] -> Output/tables/T12_gateA0_vector_facts.csv | ALL OK:", all(res$ok), "\n")
