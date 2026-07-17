# ------------------------------------------------------------------------------
# Script: scripts/03_inundation_products/14_build_flood_zone_raster.R
# Purpose: Tier 2 · Task H · H6 — the ABSOLUTE flood-zone raster. Reclassify the
#          census (NN, 8058) between-year flood frequency into five fixed zones and
#          register it. Feeds the `flood_zone` column of the H4 census parquet
#          (data contract §3).
#
# WHY FIXED BREAKS, not quantiles — this is the whole point of the layer:
#   The within-community terciles are NOT comparable across communities (facts §9:
#   "Aeolian's wettest band is wetter than Inland's driest"; on a bivariate map
#   "darker = wetter" is true WITHIN a community and false ACROSS the map). Absolute
#   zones are comparable everywhere, and they are STABLE where quantiles are not
#   (facts §6: the Inland 1/3 break sits on a tie plateau with a 0.07 pp margin; a
#   0.019% change in the pixel set swings the low band by 14%).
#
#   Fixed breaks at 10 / 25 / 50% have ZERO pixels on them BY CONSTRUCTION: every
#   focus pixel has 35/35 valid years (facts §5), so freq takes exactly k/35, and
#   3.5/35, 8.75/35, 17.5/35 are not integers. That is a PROOF, not an observation —
#   so the open/closed convention at each break is immaterial. Asserted below anyway.
#
# Workflow stage: 03_inundation_products · Tier 2 Task H
# Run mode: analysis (raster) · additive · post-build DB touch (raster_asset, dim_metric)
# Key inputs:
#   - Output/rasters/inundation_annual_stack_8058/annual_{wet,valid}_any_1988_2023_8058.tif
#   - Output/rasters/veg_regime_class_8058.tif  (grid template + community/context)
# Key outputs:
#   - Output/rasters/flood_zone_8058.tif  (categorical 0-4, RAT + colour table)
#   - Output/diagnostics/tier2H_h6_flood_zone_crosstab.csv
#   - Output/diagnostics/tier2H_h6_qa.json
#   - raster_asset row `raster_flood_zone_8058`; dim_metric row `flood_zone`
# Notes:
#   - Post-build mutation (raster_asset/dim_metric) — re-run after any full rebuild.
#   - Originals untouched; the frequency surface is recomputed from the NN stack, so
#     this layer inherits H3.0's nearest-neighbour discipline (no bilinear smoothing).
# ------------------------------------------------------------------------------

## 0. Zone definition ----

ZONE_BREAKS <- c(0, 10, 25, 50)          # %, absolute; 1:10, 1:4, 1:2
ZONE_CODES  <- 0:4
ZONE_LABELS <- c("never", "rarely (<1:10)", "occasionally (1:10-1:4)",
                 "regularly (1:4-1:2)", "frequently (>1:2)")
ZONE_COLOURS <- c("#F2F2F2", "#FDE0A5", "#7FC7A4", "#2E6DB0", "#12304F")

## Expected cross-tab (% within community) — facts §9, measured independently.
EXPECTED <- tibble::tribble(
  ~community,                              ~never, ~rarely, ~occasionally, ~regularly, ~frequently,
  "Aeolian Chenopod Shrublands",             41.6,    36.7,          17.4,        3.6,         0.7,
  "Riverine Chenopod Shrublands",            14.0,    38.6,          28.7,       18.1,         0.7,
  "Inland Floodplain Shrublands / Swamps",    2.7,    15.2,          25.4,       46.6,        10.1,
  "Floodplain Woodland / Forest",             0.6,    17.1,          16.8,       44.4,        21.1
)
EXPECTED_FARM <- c(never = 7.4, rarely = 21.1, occasionally = 24.7,
                   regularly = 38.2, frequently = 8.6)
TOL_PP <- 0.2   # facts table is quoted to 1 dp


## 1. Sources ----

root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", getwd()), winslash = "/", mustWork = TRUE)
source(file.path(root_dir, "R", "gayini_helpers.R"))
source(file.path(root_dir, "R", "gayini_output_helpers.R"))
source(file.path(root_dir, "R", "gayini_output_paths.R"))
source(file.path(root_dir, "R", "gayini_gradient_helpers.R"))
source(file.path(root_dir, "R", "gayini_veg_regime_functions.R"))

suppressPackageStartupMessages({
  library(terra); library(dplyr); library(DBI); library(RSQLite)
})
terra::terraOptions(progress = 0)

rasters_dir     <- file.path(root_dir, "Output", "rasters")
diagnostics_dir <- file.path(root_dir, "Output", "diagnostics")
db_path         <- file.path(root_dir, "Output", "database", "Gayini_Results.sqlite")

class_tif <- file.path(rasters_dir, "veg_regime_class_8058.tif")
stack_dir <- file.path(rasters_dir, "inundation_annual_stack_8058")
for (p in c(class_tif, file.path(stack_dir, "annual_wet_any_1988_2023_8058.tif")))
  gayini_stop_if_missing(p, label = basename(p))

class_r <- terra::rast(class_tif)
wet <- terra::rast(file.path(stack_dir, "annual_wet_any_1988_2023_8058.tif"))
val <- terra::rast(file.path(stack_dir, "annual_valid_any_1988_2023_8058.tif"))


## 2. Census flood frequency on the canonical grid (NN lineage) ----

message("\n[H6] Recomputing census flood frequency from the NN 8058 stack ...")
wet_count <- terra::app(wet, "sum", na.rm = TRUE)
val_count <- terra::app(val, "sum", na.rm = TRUE)
val_count <- terra::ifel(val_count == 0, NA, val_count)
freq <- 100 * wet_count / val_count
names(freq) <- "flood_freq_pct"
stopifnot(isTRUE(terra::compareGeom(freq, class_r, lyrs = FALSE, crs = TRUE, ext = TRUE,
                                    rowcol = TRUE, res = TRUE, stopOnError = FALSE)))
message("  compareGeom(freq, veg_regime_class_8058) = TRUE")


## 3. THE PROOF — zero pixels sit on a break ----
##    Only meaningful over the census (focus pixels have 35/35 valid years).

message("\n================ H6 · break-collision proof ================")
cls_v <- terra::values(class_r)[, 1]
fq_v  <- terra::values(freq)[, 1]
in_census <- !is.na(cls_v) & !is.na(fq_v)
on_break <- vapply(ZONE_BREAKS[-1], function(b) sum(abs(fq_v[in_census] - b) < 1e-9), integer(1))
names(on_break) <- paste0(ZONE_BREAKS[-1], "%")
message("  census pixels landing exactly ON each break (must all be 0 — k/35 can never equal")
message("  3.5/35, 8.75/35 or 17.5/35, so this is a proof, not an observation):")
print(on_break)
stopifnot(all(on_break == 0L))
message("  ==> PROVEN: no pixel on a break, so the open/closed convention is immaterial.")


## 4. Reclassify to zones ----

zone <- terra::classify(
  freq,
  rcl = matrix(c(-Inf, 0,      0,      # never (freq == 0 exactly)
                 0,    10,     1,      # rarely
                 10,   25,     2,      # occasionally
                 25,   50,     3,      # regularly
                 50,   Inf,    4),     # frequently
               ncol = 3, byrow = TRUE),
  include.lowest = TRUE, right = TRUE)
names(zone) <- "flood_zone"
## Zones are only defined where the census is defined.
zone <- terra::mask(zone, class_r)

zv <- terra::values(zone)[, 1]
stopifnot(all(stats::na.omit(unique(zv)) %in% ZONE_CODES))

## Attach a RAT + colour table so the tif is self-describing.
present <- sort(unique(stats::na.omit(zv)))
levels(zone) <- data.frame(value = ZONE_CODES, flood_zone = ZONE_LABELS)[
  match(present, ZONE_CODES), ]
ct <- data.frame(value = present,
                 t(grDevices::col2rgb(ZONE_COLOURS[match(present, ZONE_CODES)], alpha = TRUE)))
names(ct) <- c("value", "red", "green", "blue", "alpha")
terra::coltab(zone) <- ct

zone_tif <- file.path(rasters_dir, "flood_zone_8058.tif")
terra::writeRaster(zone, zone_tif, overwrite = TRUE, datatype = "INT1U")
message("\n  wrote: ", zone_tif)


## 5. Cross-tab by community + reconcile to facts §9 ----

classes <- gayini_veg_regime_classes()
comm_of <- stats::setNames(classes$community, classes$code)
df <- tibble::tibble(zone = zv[in_census], code = cls_v[in_census]) |>
  dplyr::mutate(community = unname(comm_of[as.character(code)]))

crosstab <- df |>
  dplyr::count(community, zone) |>
  dplyr::group_by(community) |>
  dplyr::mutate(pct = 100 * n / sum(n)) |>
  dplyr::ungroup() |>
  dplyr::select(community, zone, n, pct) |>
  dplyr::mutate(zone_label = ZONE_LABELS[zone + 1L])

wide <- crosstab |>
  dplyr::select(community, zone, pct) |>
  tidyr::pivot_wider(names_from = zone, values_from = pct, values_fill = 0) |>
  dplyr::rename(never = `0`, rarely = `1`, occasionally = `2`,
                regularly = `3`, frequently = `4`)

farm <- df |> dplyr::count(zone) |> dplyr::mutate(pct = 100 * n / sum(n))
farm_v <- stats::setNames(round(farm$pct, 1), ZONE_LABELS[farm$zone + 1L])

message("\n================ H6 · flood-zone cross-tab (% within community) ================")
print(as.data.frame(wide |> dplyr::mutate(dplyr::across(where(is.numeric), ~ round(.x, 1)))),
      row.names = FALSE)
message("\n  farm-wide (mapped): ",
        paste(sprintf("%s %.1f", names(farm_v), farm_v), collapse = " · "))

## Reconciliation against the independently measured facts §9 table.
recon <- EXPECTED |>
  tidyr::pivot_longer(-community, names_to = "zone_name", values_to = "expected") |>
  dplyr::left_join(
    wide |> tidyr::pivot_longer(-community, names_to = "zone_name", values_to = "observed"),
    by = c("community", "zone_name")) |>
  dplyr::mutate(delta = round(observed - expected, 2))
message("\n  reconciliation vs facts §9 (delta = observed - expected, pp):")
print(as.data.frame(recon |> dplyr::mutate(observed = round(observed, 1))), row.names = FALSE)
max_abs <- max(abs(recon$delta), na.rm = TRUE)
message(sprintf("\n  max |delta| = %.2f pp  (tolerance %.2f)", max_abs, TOL_PP))
gayini_write_csv(crosstab, file.path(diagnostics_dir, "tier2H_h6_flood_zone_crosstab.csv"))
stopifnot(max_abs < TOL_PP)
message("  ==> RECONCILES to the independently measured table.")


## 6. Register (raster_asset + dim_metric) ----

sha256_of <- function(p) tryCatch(
  if (requireNamespace("digest", quietly = TRUE)) digest::digest(file = p, algo = "sha256")
  else NA_character_, error = function(e) NA_character_)

ex <- as.vector(terra::ext(zone)); rs <- terra::res(zone)
sem <- paste0("Absolute between-year flood-frequency zone on the canonical 8058 census grid. ",
              "0=never (freq==0) · 1=rarely (<10%) · 2=occasionally (10-25%) · ",
              "3=regularly (25-50%) · 4=frequently (>50%). Derived from the NN-reprojected ",
              "annual stack (no bilinear smoothing). FIXED breaks, deliberately not quantiles: ",
              "within-community terciles are not comparable across communities and are unstable ",
              "on tie plateaus, whereas 10/25/50% have zero pixels on them by construction ",
              "(freq = k/35). PIXEL support (24.97 m) - not comparable to plot-support figures.")
con <- dbConnect(SQLite(), db_path)
dbExecute(con, "DELETE FROM raster_asset WHERE raster_asset_id = ?",
          params = list("raster_flood_zone_8058"))
dbExecute(con,
  "INSERT INTO raster_asset
     (raster_asset_id, path, metric_id, water_year, period_label, crs, resolution_x,
      resolution_y, xmin, ymin, xmax, ymax, checksum_sha256, path_exists, qa_status,
      run_id, crs_epsg, product, legend_status, legend_semantics)
   VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
  params = list("raster_flood_zone_8058", gayini_relative_path(root_dir, zone_tif),
                "flood_zone", NA_character_, "WY1988-2023 across-series", "EPSG:8058",
                rs[1], rs[2], ex[1], ex[3], ex[2], ex[4], sha256_of(zone_tif), 1L,
                "REVIEW", "tier2H_h6", 8058L, "flood_zone_8058", "confirmed", sem))
cols <- dbGetQuery(con, "PRAGMA table_info(dim_metric)")$name
if (!"support" %in% cols) dbExecute(con, "ALTER TABLE dim_metric ADD COLUMN support TEXT")
dbExecute(con, "INSERT OR REPLACE INTO dim_metric
   (metric_id, metric_name, domain, units, scale, numerator, denominator,
    method_summary, safe_interpretation, caveat, support) VALUES (?,?,?,?,?,?,?,?,?,?,?)",
  params = list("flood_zone", "Absolute flood-frequency zone", "inundation", "class_code",
    "0-4", "between-year flood frequency", "pixel",
    paste("Fixed absolute breaks at 0 / 10 / 25 / 50% of between-year flood frequency",
          "(100 x wet-valid-years / valid-years) on the NN 8058 census grid."),
    paste("Comparable ACROSS communities, unlike the within-community terciles.",
          "Farm-wide (mapped): never 7.4 / rarely 21.1 / occasionally 24.7 /",
          "regularly 38.2 / frequently 8.6 %."),
    paste("PIXEL support (24.97 m). Zones are absolute, so a 'low' tercile in one",
          "community and another's are NOT the same zone - that is the point.",
          "Floodplain Woodland is the wettest unit on the property despite being context."),
    "pixel 24.97 m (EPSG:8058 census grid)"))
dbDisconnect(con)
message("\n  registered: raster_flood_zone_8058 + dim_metric flood_zone")


## 7. QA ----

qa <- list(
  step = "H6 absolute flood-zone raster",
  generated_by = "scripts/03_inundation_products/14_build_flood_zone_raster.R",
  breaks_pct = ZONE_BREAKS, zone_labels = ZONE_LABELS,
  break_collisions = as.list(on_break),
  proof = paste("freq = k/35 for every focus pixel (35/35 valid years), and 3.5/35,",
                "8.75/35, 17.5/35 are not integers -> no pixel can land on a break."),
  compareGeom_vs_veg_regime_class_8058 = TRUE,
  crosstab = lapply(seq_len(nrow(wide)), function(i) as.list(wide[i, ])),
  farm_wide_pct = as.list(farm_v),
  reconciliation_max_abs_delta_pp = max_abs, tolerance_pp = TOL_PP,
  output = "Output/rasters/flood_zone_8058.tif",
  registered = "raster_flood_zone_8058")
jsonlite::write_json(qa, file.path(diagnostics_dir, "tier2H_h6_qa.json"),
                     auto_unbox = TRUE, pretty = TRUE, digits = 6)

message("\n==================== H6 COMPLETE ====================")
message("flood_zone_8058.tif written, registered, and reconciled to facts §9 ",
        sprintf("(max |delta| = %.2f pp).", max_abs))
message("Feeds the `flood_zone` column of the H4 census parquet (data contract §3).")
