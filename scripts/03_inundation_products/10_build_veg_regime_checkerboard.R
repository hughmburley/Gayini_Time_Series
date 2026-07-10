# ------------------------------------------------------------------------------
# Script: scripts/03_inundation_products/10_build_veg_regime_checkerboard.R
# Purpose: Tier 1 · Task C1 (checkerboard). Build the per-pixel vegetation x
#          wetness class raster veg_regime_class_8058.tif and the bivariate
#          "checkerboard" maps: a whole-farm map + one map per major paddock,
#          all via the reusable gayini_plot_area_map() (heavy outline / light
#          neighbours / locator inset) with the fixed 3x3 bivariate legend.
# Workflow stage: 03_inundation_products (raster) + figures
# Run mode: analysis (real raster work) · post-build DB touch (dim_metric)
# Key inputs:
#   - Output/rasters/inundation_annual_stack/annual_{wet,valid}_any_1988_2023.tif (EPSG:28355)
#   - Output/spatial_8058/{vegetation_communities, gayini_boundary,
#     management_zones, gayini_hectare_plots}_epsg8058.gpkg                       (EPSG:8058)
#   - Output/diagnostics/regime_band_breaks.csv    (within-community terciles, F5)
#   - Output/database/Gayini_Results.sqlite        (v_pixel_census_by_veg_regime, for QA)
# Key outputs:
#   - Output/rasters/veg_regime_class_8058.tif   (categorical, RAT + colour table)
#   - Output/figures/C1_veg_regime_bivariate_farm_data.{png,pdf}
#   - Output/figures/C1_veg_regime_paddock_<slug>_data.{png,pdf}  (major paddocks)
#   - Output/diagnostics/veg_regime_class_qa.json  (class areas reconcile to census)
#   - Output/review_bundles/tier1_veg_regime_checkerboard.zip
#   - dim_metric row veg_regime_class (also canonical in the Python builder METRICS)
# Notes:
#   - Same 25/35 support threshold + same regime_band_breaks.csv terciles as
#     v_pixel_census_by_veg_regime, so per-class pixel counts reconcile EXACTLY.
#   - Descriptive checkerboard, NOT a trend / probability surface. Sources are
#     read-only; only the derived continuous surface is reprojected.
#   - Stops at an acceptance gate; commit is a separate, human-reviewed step.
# ------------------------------------------------------------------------------

####################################################################################################


## GAYINI REMOTE SENSING PROJECT — Tier 1 · Task C1 (vegetation x wetness checkerboard)


####################################################################################################


## 0. Tunable defaults ----

MIN_VALID_YEARS <- 25L
TARGET_CRS      <- 8058L
PAD_BUFFER      <- 400          # m · view padding around a paddock
NAMED_PADDOCKS  <- c("Bala 28ca", "Bala 29ca", "Dinan 8", "Dinan 10")


## 1. Sources ----

root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", getwd()), winslash = "/", mustWork = TRUE)

source(file.path(root_dir, "R", "gayini_helpers.R"))
source(file.path(root_dir, "R", "vector_prep_functions.R"))
source(file.path(root_dir, "R", "gayini_output_helpers.R"))
source(file.path(root_dir, "R", "gayini_gradient_helpers.R"))
source(file.path(root_dir, "R", "gayini_spatial_8058_functions.R"))
source(file.path(root_dir, "R", "gayini_descriptive_figures.R"))
source(file.path(root_dir, "R", "gayini_stratified_sampling_functions.R"))
source(file.path(root_dir, "R", "gayini_area_map.R"))
source(file.path(root_dir, "R", "gayini_veg_regime_functions.R"))

suppressPackageStartupMessages({
  library(sf)
  library(terra)
  library(dplyr)
  library(ggplot2)
  library(DBI)
  library(RSQLite)
})

sf::sf_use_s2(FALSE)

figures_dir     <- file.path(root_dir, "Output", "figures")
diagnostics_dir <- file.path(root_dir, "Output", "diagnostics")
rasters_dir     <- file.path(root_dir, "Output", "rasters")
spatial_dir     <- file.path(root_dir, "Output", "spatial_8058")
db_path         <- file.path(root_dir, "Output", "database", "Gayini_Results.sqlite")

focus_communities <- gayini_focus_levels()


## 2. Load vectors ----

boundary    <- gayini_read_vector(file.path(spatial_dir, "gayini_boundary_epsg8058.gpkg"),
                                  label = "boundary (8058)")
communities <- gayini_read_vector(file.path(spatial_dir, "vegetation_communities_epsg8058.gpkg"),
                                  label = "communities (8058)")
management  <- gayini_read_vector(file.path(spatial_dir, "management_zones_epsg8058.gpkg"),
                                  label = "management zones (8058)")
plots       <- gayini_read_vector(file.path(spatial_dir, "gayini_hectare_plots_epsg8058.gpkg"),
                                  label = "hectare plots (8058)")

zone_field <- gayini_find_field(management, c("ManagmentZ", "ManagementZ", "Zone", "Paddock"),
                                "management zone name")


## 3. Background flood-frequency surface (parameterised support mask) ----

wet_path   <- file.path(rasters_dir, "inundation_annual_stack", "annual_wet_any_1988_2023.tif")
valid_path <- file.path(rasters_dir, "inundation_annual_stack", "annual_valid_any_1988_2023.tif")

surface <- gayini_background_flood_frequency(
  wet_path = wet_path, valid_path = valid_path,
  min_valid_years = MIN_VALID_YEARS, target = TARGET_CRS, out_tif = NULL)
freq_8058 <- surface$freq_8058


## 4. Band breaks — source of truth is regime_band_breaks.csv (F5) ----

regime_breaks_path <- file.path(diagnostics_dir, "regime_band_breaks.csv")
gayini_stop_if_missing(regime_breaks_path, label = "regime_band_breaks.csv")
band_breaks_tbl <- readr::read_csv(regime_breaks_path, show_col_types = FALSE)

breaks <- stats::setNames(lapply(focus_communities, function(g) {
  r <- band_breaks_tbl[band_breaks_tbl$community == g, ]
  c(r$freq_min_pct, r$tercile_1_pct, r$tercile_2_pct, r$freq_max_pct)
}), focus_communities)


## 5. Build + write the per-pixel class raster ----

class_r <- gayini_build_veg_regime_class(freq_8058, communities, breaks, focus_communities)

class_tif <- file.path(rasters_dir, "veg_regime_class_8058.tif")
terra::writeRaster(class_r, class_tif, overwrite = TRUE, datatype = "INT1U")
message("Wrote: ", class_tif)

classes <- gayini_veg_regime_classes()
legend  <- gayini_bivariate_legend(classes)


## 6. Reconcile class areas to v_pixel_census_by_veg_regime ----

class_counts <- gayini_veg_regime_class_counts(class_r, classes)

con <- dbConnect(SQLite(), db_path)
census <- dbGetQuery(con,
  "SELECT community, regime_band AS band, n_pixels AS census_pixels
     FROM v_pixel_census_by_veg_regime")
dbDisconnect(con)

recon <- class_counts |>
  dplyr::rename(class_pixels = n_pixels) |>
  dplyr::left_join(census, by = c("community", "band")) |>
  dplyr::mutate(diff = class_pixels - census_pixels)

message("\nClass-area reconciliation to v_pixel_census_by_veg_regime:")
print(recon)

max_abs_diff <- max(abs(recon$diff), na.rm = TRUE)


## 7. dim_metric row (canonical copy in the Python builder METRICS) ----

metric_row <- list(
  "veg_regime_class", "Vegetation x wetness regime class", "landcover", "class_code",
  "categorical", "community x wetness tercile", "pixel",
  paste("Per-pixel bivariate class: vegetation community x within-community flood-frequency",
        "tercile (9 focus classes + treed context + other/minor), at the 25/35 valid-year",
        "support threshold with regime_band_breaks.csv terciles."),
  "Descriptive checkerboard for paddock context; class areas reconcile to v_pixel_census_by_veg_regime.",
  "Within-community relative bands; woodland/forest is context only; not a trend or probability surface.")

con <- dbConnect(SQLite(), db_path)
dbExecute(con, "CREATE TABLE IF NOT EXISTS dim_metric (
    metric_id TEXT PRIMARY KEY, metric_name TEXT NOT NULL, domain TEXT NOT NULL,
    units TEXT, scale TEXT, numerator TEXT, denominator TEXT,
    method_summary TEXT, safe_interpretation TEXT, caveat TEXT)")
dbExecute(con, "INSERT OR IGNORE INTO dim_metric VALUES (?,?,?,?,?,?,?,?,?,?)",
          params = metric_row)
dbDisconnect(con)


## 8. Whole-farm bivariate map ----

farm_caption <- "Per-pixel community x wetness tercile · farm outline heavy · paddocks light · EPSG:8058"

farm <- gayini_plot_area_map(
  area        = boundary,
  fill_layer  = class_r,
  fill_spec   = list(kind = "discrete", classes = classes, max_cells = 4e5),
  boundary    = boundary,
  neighbours  = management,
  outline     = boundary,
  pad_buffer  = 200,
  title       = "C1 · Vegetation x wetness checkerboard — whole farm",
  subtitle    = "Community = hue · wetness band (within community) = light -> dark · woodland grey = context",
  caption     = farm_caption,
  inset       = FALSE,
  legend_grob = legend,
  out_dir     = figures_dir,
  basename    = "C1_veg_regime_bivariate_farm_data",
  width = 12, height = 8)


## 9. Major-paddock set: paddocks with a hectare plot, unioned with the 4 named ----

pc  <- suppressWarnings(sf::st_centroid(sf::st_geometry(plots)))
pin <- sf::st_intersects(pc, management)
plot_zone_rows <- sort(unique(unlist(lapply(pin, function(z) if (length(z)) z[[1]] else NULL))))

zone_names   <- as.character(sf::st_drop_geometry(management)[[zone_field]])
named_rows   <- which(zone_names %in% NAMED_PADDOCKS)
paddock_rows <- sort(unique(c(plot_zone_rows, named_rows)))

message(sprintf("\nMajor paddocks: %d (with a hectare plot) + named -> %d unique maps.",
                length(plot_zone_rows), length(paddock_rows)))

slugify <- function(s) gsub("[^A-Za-z0-9]+", "_", trimws(s))

paddock_paths   <- list()
overlap_rows    <- list()
for (zr in paddock_rows) {
  pad      <- management[zr, ]
  pad_name <- zone_names[zr]
  slug     <- slugify(pad_name)

  z        <- sf::st_bbox(sf::st_buffer(sf::st_geometry(pad), PAD_BUFFER))
  clip_sfc <- sf::st_as_sfc(sf::st_bbox(
    terra::ext(z["xmin"], z["xmax"], z["ymin"], z["ymax"]), crs = sf::st_crs(management)))
  nbrs     <- suppressWarnings(management[
    sf::st_intersects(management, clip_sfc, sparse = FALSE)[, 1], ])

  n_plot <- sum(vapply(pin, function(zz) length(zz) && zz[[1]] == zr, logical(1)))

  res <- gayini_plot_area_map(
    area        = pad,
    fill_layer  = class_r,
    fill_spec   = list(kind = "discrete", classes = classes),
    boundary    = boundary,
    management  = management,
    neighbours  = nbrs,
    outline     = pad,
    pad_buffer  = PAD_BUFFER,
    title       = paste0("C1 · Checkerboard — ", pad_name),
    subtitle    = sprintf("%d monitoring plot%s · community x wetness class per pixel · bands within-community (relative)",
                          n_plot, ifelse(n_plot == 1, "", "s")),
    caption     = "Community = hue · wetness = light -> dark · paddock outline heavy · neighbours light",
    inset       = TRUE,
    legend_grob = legend,
    out_dir     = figures_dir,
    basename    = paste0("C1_veg_regime_paddock_", slug, "_data"),
    width = 11, height = 7)

  overlap_rows[[length(overlap_rows) + 1L]] <- dplyr::mutate(res$overlap, paddock = pad_name, .before = 1)
  paddock_paths[[pad_name]] <- res$paths
}
overlap_check <- dplyr::bind_rows(overlap_rows)


## 10. Register figures in the manifest ----

class_input <- "veg_regime_class_8058.tif [community x wetness tercile from background flood frequency + regime_band_breaks.csv]"

farm_rows <- dplyr::bind_rows(
  gayini_manifest_row("C1", "data", farm$paths$png, paste0(class_input, " [whole farm]"), "EPSG:8058", root_dir),
  gayini_manifest_row("C1", "data", farm$paths$pdf, paste0(class_input, " [whole farm]"), "EPSG:8058", root_dir)
)
paddock_manifest_rows <- dplyr::bind_rows(lapply(names(paddock_paths), function(nm) {
  p <- paddock_paths[[nm]]
  dplyr::bind_rows(
    gayini_manifest_row("C1", "data", p$png, paste0(class_input, " [paddock: ", nm, "]"), "EPSG:8058", root_dir),
    gayini_manifest_row("C1", "data", p$pdf, paste0(class_input, " [paddock: ", nm, "]"), "EPSG:8058", root_dir)
  )
}))
new_rows <- dplyr::bind_rows(farm_rows, paddock_manifest_rows)
manifest <- gayini_update_figures_manifest(new_rows, root = root_dir)


## 11. QA ----

r_epsg   <- gayini_crs_epsg(class_r)
present  <- sort(unique(stats::na.omit(terra::values(class_r)[, 1])))
pal_ok   <- all(present %in% classes$code)
woodland_context_only <- all(class_counts$band[class_counts$code == 40L] == "context")

qa <- list(
  raster                 = "Output/rasters/veg_regime_class_8058.tif",
  generated_by           = "scripts/03_inundation_products/10_build_veg_regime_checkerboard.R",
  crs_epsg               = r_epsg,
  valid_year_threshold   = MIN_VALID_YEARS,
  pixel_area_ha          = round(prod(terra::res(class_r)) / 1e4, 6),
  n_classes_present      = length(present),
  class_codes_present    = as.integer(present),
  reconciliation = list(
    max_abs_pixel_diff_vs_census = as.numeric(max_abs_diff),
    total_class_pixels           = as.integer(sum(class_counts$n_pixels)),
    total_census_pixels          = as.integer(sum(recon$census_pixels, na.rm = TRUE)),
    per_class = lapply(seq_len(nrow(recon)), function(i) list(
      community = recon$community[i], band = recon$band[i],
      class_pixels = as.integer(recon$class_pixels[i]),
      census_pixels = as.integer(recon$census_pixels[i]),
      diff = as.integer(recon$diff[i])))
  ),
  figures = list(
    whole_farm      = "C1_veg_regime_bivariate_farm_data",
    n_paddock_maps  = length(paddock_paths),
    paddocks        = names(paddock_paths)
  ),
  checks = list(
    crs_is_8058               = r_epsg == 8058L,
    palette_matches_scheme    = pal_ok,
    class_areas_reconcile      = max_abs_diff == 0,
    woodland_context_only     = woodland_context_only,
    all_paddock_insets_clear   = all(overlap_check$clear),
    farm_map_no_inset          = farm$overlap$inset_drawn == FALSE
  )
)
qa$all_pass <- all(unlist(qa$checks))

qa_path <- file.path(diagnostics_dir, "veg_regime_class_qa.json")
jsonlite::write_json(qa, qa_path, auto_unbox = TRUE, pretty = TRUE, digits = 6)
message("Wrote: ", qa_path, "  (all_pass = ", qa$all_pass, ")")

overlap_log <- file.path(diagnostics_dir, "c1_inset_overlap_check.csv")
gayini_write_csv(overlap_check, overlap_log)


## 12. Acceptance gate ----

stopifnot(
  qa$checks$crs_is_8058,
  qa$checks$palette_matches_scheme,
  qa$checks$class_areas_reconcile,
  qa$checks$woodland_context_only,
  qa$checks$all_paddock_insets_clear,
  qa$checks$farm_map_no_inset,
  file.exists(class_tif),
  file.exists(file.path(figures_dir, "C1_veg_regime_bivariate_farm_data.pdf"))
)


## 13. Package for review ----

bundle_dir      <- file.path(root_dir, "Output", "review_bundles", "tier1_veg_regime_checkerboard")
bundle_fig_dir  <- file.path(bundle_dir, "figures")
bundle_diag_dir <- file.path(bundle_dir, "diagnostics")
unlink(bundle_dir, recursive = TRUE, force = TRUE)
for (d in c(bundle_fig_dir, bundle_diag_dir)) dir.create(d, recursive = TRUE, showWarnings = FALSE)

file.copy(list.files(figures_dir, pattern = "^C1_veg_regime_.*\\.(png|pdf)$", full.names = TRUE),
          bundle_fig_dir, overwrite = TRUE)
file.copy(file.path(figures_dir, "figures_manifest.csv"), bundle_dir, overwrite = TRUE)
readr::write_csv(new_rows, file.path(bundle_dir, "manifest_rows_c1.csv"))
file.copy(c(qa_path, overlap_log, regime_breaks_path), bundle_diag_dir, overwrite = TRUE)

change_report_path <- file.path(root_dir, "docs", "change_reports", "tier1_veg_regime_checkerboard.md")
if (file.exists(change_report_path)) file.copy(change_report_path, bundle_dir, overwrite = TRUE)

bundle_zip <- file.path(root_dir, "Output", "review_bundles", "tier1_veg_regime_checkerboard.zip")
if (file.exists(bundle_zip)) unlink(bundle_zip, force = TRUE)
zip::zip(zipfile = bundle_zip,
         files   = list.files(bundle_dir, recursive = TRUE, full.names = FALSE),
         root    = bundle_dir)
message("Wrote review bundle: ", bundle_zip)


## 14. Summary ----

message("\n==================== ACCEPTANCE GATE PASSED ====================")
message("Class raster: ", class_tif, "  (", length(present), " classes present)")
message("Whole-farm map: ", farm$paths$png)
message("Paddock maps (", length(paddock_paths), "): ", paste(names(paddock_paths), collapse = ", "))
message("Class areas reconcile to census: max abs pixel diff = ", max_abs_diff)
message("QA: ", qa_path, "  (all_pass = ", qa$all_pass, ")")
message("Bundle: ", bundle_zip)
message("\nSTOP: review Output/review_bundles/tier1_veg_regime_checkerboard.zip before committing.")


####################################################################################################
############################################ TBC ###################################################
####################################################################################################
