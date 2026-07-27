#!/usr/bin/env Rscript
# T6 Gate B (part 1) - connected components of the unzoned area + plot evidence +
# confirmation that the 7 unplaced standard plots sit OUTSIDE the mapped census.
# Writes a registered component raster and a per-component table; assigns component_id
# to every unzoned in-scope pixel for the extraction step. Repo-relative inputs only.

suppressPackageStartupMessages({library(terra); library(sf); library(DBI); library(RSQLite)})
sf::sf_use_s2(FALSE)
root <- normalizePath(".", winslash = "/")
source(file.path(root, "R/gayini_params.R"))
source(file.path(root, "R/gayini_figure_register.R"))   # gayini_sha256_first50
tbl <- file.path(root, "Output/tables")
MIN_HA <- 100
PXHA <- GAYINI_PARAMS$PIXEL_AREA_HA

pts <- utils::read.csv(file.path(tbl, "T6_in_scope_points.csv"))
unz <- pts[is.na(pts$zone_fid), ]
tmpl <- rast("Output/rasters/veg_annual_8058/total_veg_annual_mean_8058.tif")[[1]]

# ---- component raster from unzoned in-scope pixels ----
r <- tmpl; values(r) <- NA
r[cellFromXY(r, as.matrix(unz[, c("x_8058", "y_8058")]))] <- 1L
comp <- patches(r, directions = 8, zeroAsNA = TRUE)
names(comp) <- "component_id"
ct <- as.data.frame(freq(comp)); ct$area_ha <- ct$count * PXHA
ct <- ct[order(-ct$area_ha), ]
ct$is_qualifying <- as.integer(ct$area_ha >= MIN_HA)

outdir <- file.path(root, "Output/rasters/unzoned_components_8058")
dir.create(outdir, showWarnings = FALSE, recursive = TRUE)
cpath <- file.path(outdir, "unzoned_components_8058.tif")
writeRaster(comp, cpath, overwrite = TRUE, datatype = "INT4S")

# ---- plots: assign each of the 15 standard-grazing plots to a component ----
con <- DBI::dbConnect(RSQLite::SQLite(), file.path(root, "Output/database/Gayini_Results.sqlite"))
pl <- DBI::dbGetQuery(con, "SELECT p.plot_id, p.plot_treatment, p.in_zone,
   d.centroid_x, d.centroid_y, d.management_zone_coverage_pct
   FROM plot_paddock p JOIN dim_plot d ON d.plot_id=p.plot_id")
psf <- sf::st_transform(sf::st_as_sf(pl, coords = c("centroid_x", "centroid_y"),
                        crs = GAYINI_PARAMS$CRS_PLOT_CENTROID), GAYINI_PARAMS$CRS_CANONICAL)
pl$component_id <- terra::extract(comp, terra::vect(psf))[, 2]
std <- pl[pl$plot_treatment == "Standard grazing", ]

npl <- as.data.frame(table(component_id = std$component_id[!is.na(std$component_id)]))
npl$component_id <- as.integer(as.character(npl$component_id))
ct <- merge(ct, data.frame(value = npl$component_id, n_plots = npl$Freq),
            by = "value", all.x = TRUE)
ct$n_plots[is.na(ct$n_plots)] <- 0L
ct$plot_confirmed <- as.integer(ct$n_plots > 0)
names(ct)[names(ct) == "value"] <- "component_id"
ct <- ct[order(-ct$area_ha), c("component_id", "count", "area_ha", "is_qualifying",
                               "n_plots", "plot_confirmed")]
utils::write.csv(ct, file.path(tbl, "T6_components.csv"), row.names = FALSE)

# ---- assign component_id to every unzoned pixel, write for the extraction ----
unz$component_id <- terra::extract(comp, as.matrix(unz[, c("x_8058", "y_8058")]))[, 1]
utils::write.csv(unz[, c("pixel_id", "component_id")],
                 file.path(tbl, "T6_unzoned_pixel_component.csv"), row.names = FALSE)

# ---- correction 4: confirm the 7 unplaced standard plots are OUTSIDE mapped census ----
cxy <- utils::read.csv(file.path(tbl, "T6_census_xy.csv"))
cmask <- tmpl; values(cmask) <- NA
cmask[cellFromXY(cmask, as.matrix(cxy[, c("x_8058", "y_8058")]))] <- 1L
std$in_mapped_census <- terra::extract(cmask, terra::vect(psf[psf$plot_treatment == "Standard grazing", ]))[, 2]
std$mgmt_cov0 <- std$management_zone_coverage_pct == 0
cat(sprintf("standard plots: %d; management_zone_coverage_pct==0: %d/15\n",
            nrow(std), sum(std$mgmt_cov0, na.rm = TRUE)))
cat(sprintf("standard plots INSIDE mapped census: %d; OUTSIDE: %d\n",
            sum(std$in_mapped_census == 1, na.rm = TRUE),
            sum(is.na(std$in_mapped_census))))
unplaced <- std$plot_id[is.na(std$component_id)]
outside  <- std$plot_id[is.na(std$in_mapped_census)]
cat("unplaced (no component):", paste(sort(unplaced), collapse = ", "), "\n")
cat("outside mapped census   :", paste(sort(outside), collapse = ", "), "\n")
cat("SAME SET?", identical(sort(unplaced), sort(outside)), "\n")

# ---- register the component raster ----
e <- as.vector(ext(comp)); sha <- gayini_sha256_first50(cpath)
rel <- sub(paste0(root, "/"), "", gsub("\\\\", "/", normalizePath(cpath, winslash = "/")), fixed = TRUE)
DBI::dbExecute(con,
  "INSERT OR REPLACE INTO raster_asset
     (raster_asset_id, path, metric_id, water_year, period_label, crs, resolution_x,
      resolution_y, xmin, ymin, xmax, ymax, checksum_sha256, path_exists, qa_status,
      run_id, crs_epsg, product, legend_status, legend_semantics, superseded_flag,
      framing_label, provenance_note)
   VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,1,'REVIEW',?,8058,?,?,?,0,?,?)",
  params = list("raster_unzoned_components_8058", rel, "unzoned_component_id", NA,
                "static", "EPSG:8058", res(comp)[1], res(comp)[2], e["xmin"], e["ymin"],
                e["xmax"], e["ymax"], sha, "T6_gateB", "unzoned_components_8058", "confirmed",
                sprintf("Connected components (8-conn) of unzoned in-scope census pixels; %d total, %d >= %d ha. component_id per pixel; NA outside unzoned area.",
                        nrow(ct), sum(ct$is_qualifying), MIN_HA),
                "census_8058",
                "T6 Gate B. Unzoned = inferred standard grazing; 8 of 15 standard plots fall here."))
DBI::dbDisconnect(con)
cat(sprintf("\nregistered raster_unzoned_components_8058 (%s)\n", substr(sha, 1, 12)))
cat(sprintf("components: %d total, %d qualifying (>=%d ha), %.1f ha in qualifying\n",
            nrow(ct), sum(ct$is_qualifying), MIN_HA, sum(ct$area_ha[ct$is_qualifying == 1])))
cat("DONE\n")
