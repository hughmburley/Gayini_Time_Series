# ------------------------------------------------------------------------------
# Script: scripts/05_ground_cover/04_taskM_green_at_floor_area.R
# Purpose: Tier 2 · Task M · Gate C, Rule 8 — close the D8 paper trail.
#
#   The green-share-at-the-floor count and its hectare conversion were performed
#   interactively during the 2026-07-20 on-disk review and written to scratch
#   (Output/diagnostics/ondisk_review_20260720/refugia_area_check.csv). No script
#   in the repository reproduced them, so the number did not rebuild from git —
#   the break Gate A recorded as PARTIAL.
#
#   This script performs exactly that count and conversion, from the committed
#   substrate, and writes the result to Output/. It reports the number. It does
#   not name it, classify it, or interpret it.
#
#   green_at_floor() is NOT reimplemented here. The definition below is a verbatim
#   copy of the committed function in 03_h2_seasonal_gate_and_diagnostics.R, and
#   §2 asserts at run time that the copy is byte-identical to that source. If
#   either drifts, this script stops rather than silently computing a different
#   number.
#
# Workflow stage: 05_ground_cover · Tier 2 Task M, Gate C
# Run mode: analysis (read-only inputs) · no DB mutation · writes ONE new file
# Key inputs (all read-only):
#   - Output/rasters/fc_intermediate/fc_total_veg_3577_wy1988_2023.tif (140 lyr)
#   - Output/rasters/fc_intermediate/fc_pv_3577_wy1988_2023.tif        (140 lyr)
#   - Output/diagnostics/tier2H_h2_fc_water_year_pool.csv
#   - Output/spatial_8058/gayini_boundary_epsg8058.gpkg
#   - scripts/05_ground_cover/03_h2_seasonal_gate_and_diagnostics.R (function source)
# Key output:
#   - Output/tables/taskM_green_at_floor_area.csv
# ------------------------------------------------------------------------------

## 0. Constants ----

MIN_SEASONS   <- 50L          # as in script 03; the support rule green_at_floor() enforces
GREEN_CUT     <- 50           # the >50 threshold under audit — DO NOT ADJUST
PIXEL_AREA_HA <- 0.09         # 30 m native FC grid (EPSG:3577): 30^2 / 1e4

root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", getwd()), winslash = "/", mustWork = TRUE)
source(file.path(root_dir, "R", "gayini_helpers.R"))
source(file.path(root_dir, "R", "gayini_output_helpers.R"))
source(file.path(root_dir, "R", "vector_prep_functions.R"))

suppressPackageStartupMessages({
  library(sf); library(terra); library(dplyr)
})
sf::sf_use_s2(FALSE); terra::terraOptions(progress = 0)

rasters_dir     <- file.path(root_dir, "Output", "rasters")
diagnostics_dir <- file.path(root_dir, "Output", "diagnostics")
tables_dir      <- file.path(root_dir, "Output", "tables")
spatial_dir     <- file.path(root_dir, "Output", "spatial_8058")

SRC_SCRIPT <- file.path(root_dir, "scripts", "05_ground_cover",
                        "03_h2_seasonal_gate_and_diagnostics.R")
OWN_SCRIPT <- file.path(root_dir, "scripts", "05_ground_cover",
                        "04_taskM_green_at_floor_area.R")
OUT_CSV    <- file.path(tables_dir, "taskM_green_at_floor_area.csv")


## 1. green_at_floor() — VERBATIM COPY. Do not edit; §2 enforces this. ----
##
## Paired per-pixel: green fraction (%) in the season at the total-veg p05 order stat.
## Returns c(total_at_floor, pv_at_floor, green_frac_pct). Support rule enforced.
green_at_floor <- function(x) {
  n   <- length(x) / 2L
  tot <- x[seq_len(n)]; pv <- x[n + seq_len(n)]
  ok  <- !is.na(tot) & !is.na(pv)
  m   <- sum(ok)
  if (m < 50L) return(c(NA_real_, NA_real_, NA_real_))   # MIN_SEASONS
  tot <- tot[ok]; pv <- pv[ok]
  k   <- max(1L, ceiling(0.05 * m))                      # 5th-percentile ORDER statistic
  idx <- order(tot)[k]
  tf  <- tot[idx]; pf  <- pv[idx]
  c(tf, pf, if (tf > 0) 100 * pf / tf else NA_real_)
}


## 2. GUARD — the copy above must be byte-identical to the committed source ----
##
## Extract the function block from script 03 by marker (not by line number, which
## would rot) and compare it, whitespace-normalised, with the copy above.

extract_fn_block <- function(lines, marker) {
  ## Exact match on the trimmed line, so the marker string held in a variable
  ## further down this file is not mistaken for a second definition.
  i0 <- which(trimws(lines) == marker)
  if (length(i0) != 1L) stop("expected exactly one definition of ", marker)
  depth <- 0L; started <- FALSE
  for (i in seq(i0, length(lines))) {
    opens  <- lengths(regmatches(lines[i], gregexpr("\\{", lines[i])))
    closes <- lengths(regmatches(lines[i], gregexpr("\\}", lines[i])))
    depth  <- depth + opens - closes
    if (opens > 0L) started <- TRUE
    if (started && depth == 0L) return(lines[seq(i0, i)])
  }
  stop("unterminated function block for ", marker)
}

normalise <- function(x) {
  x <- sub("#.*$", "", x)                 # strip trailing comments
  x <- gsub("[[:space:]]+", " ", x)       # collapse whitespace
  x <- trimws(x)
  paste(x[nzchar(x)], collapse = "\n")
}

marker    <- "green_at_floor <- function(x) {"
src_block <- extract_fn_block(readLines(SRC_SCRIPT, warn = FALSE), marker)
own_block <- extract_fn_block(readLines(OWN_SCRIPT, warn = FALSE), marker)

if (!identical(normalise(src_block), normalise(own_block))) {
  cat("\n--- committed (03_h2_seasonal_gate_and_diagnostics.R) ---\n",
      normalise(src_block), "\n--- this script ---\n", normalise(own_block), "\n", sep = "")
  stop("green_at_floor() here is NOT verbatim against the committed source. ",
       "Refusing to compute a number under a drifted definition.")
}
message("[guard] green_at_floor() verified verbatim against ", basename(SRC_SCRIPT))
stopifnot(MIN_SEASONS == 50L, GREEN_CUT == 50, identical(PIXEL_AREA_HA, 0.09))


## 3. Substrate — the same two native-3577 FC stacks script 03 uses ----

tv_tif <- file.path(rasters_dir, "fc_intermediate", "fc_total_veg_3577_wy1988_2023.tif")
pv_tif <- file.path(rasters_dir, "fc_intermediate", "fc_pv_3577_wy1988_2023.tif")
stopifnot(file.exists(tv_tif), file.exists(pv_tif))

pool <- readr::read_csv(file.path(diagnostics_dir, "tier2H_h2_fc_water_year_pool.csv"),
                        show_col_types = FALSE)
pool <- pool[pool$retained, ]

tv_stack_full <- terra::rast(tv_tif)
pv_stack_full <- terra::rast(pv_tif)
names(tv_stack_full) <- paste0(pool$water_year, "_", pool$season)
names(pv_stack_full) <- names(tv_stack_full)
stopifnot(terra::nlyr(tv_stack_full) == 140L, terra::nlyr(pv_stack_full) == 140L)

boundary      <- gayini_read_vector(file.path(spatial_dir, "gayini_boundary_epsg8058.gpkg"),
                                    label = "boundary (8058)")
boundary_3577 <- sf::st_transform(boundary, 3577)
bv3577        <- terra::vect(boundary_3577)


## 4. The paired per-pixel apply — as in script 03 §3b ----

message("[compute] paired per-pixel apply over the farm (EPSG:3577); complete, not sampled ...")
tv_farm3577 <- terra::mask(terra::crop(tv_stack_full, bv3577), bv3577)
pv_farm3577 <- terra::mask(terra::crop(pv_stack_full, bv3577), bv3577)
floor_r <- terra::app(c(tv_farm3577, pv_farm3577), fun = green_at_floor)
names(floor_r) <- c("total_at_floor", "pv_at_floor", "green_frac_pct")


## 5. The count and the conversion — the step that was missing from git ----

gf      <- terra::values(floor_r)[, "green_frac_pct"]
gf      <- gf[!is.na(gf)]
n_valid <- length(gf)
n_gt    <- sum(gf > GREEN_CUT)

out <- tibble::tibble(
  quantity = c("n_valid_floor_px", "n_majority_green_px_gt50", "pct_of_valid",
               "area_ha_native_30m_3577", "implied_farm_ha_30m",
               "green_frac_pct_median", "green_frac_pct_mean"),
  value = c(n_valid, n_gt,
            round(100 * n_gt / n_valid, 3),
            round(n_gt * PIXEL_AREA_HA, 2),
            round(n_valid * PIXEL_AREA_HA, 2),
            round(stats::median(gf), 3), round(mean(gf), 3)),
  ## The definition travels with every value. A hectare figure from this table is
  ## not quotable without these columns.
  variable      = "green_frac_pct = 100 * PV / total_veg, read PAIRED in the season that sets each pixel's total-veg 5th-percentile order statistic",
  threshold     = "green_frac_pct > 50",
  mask          = "Gayini farm boundary, crop + mask on the native grid",
  support_rule  = "MIN_SEASONS: >= 50 valid paired seasons per pixel",
  grid_epsg     = 3577L,
  pixel_area_ha = PIXEL_AREA_HA,
  source_artefact = "scripts/05_ground_cover/04_taskM_green_at_floor_area.R from Output/rasters/fc_intermediate/fc_{total_veg,pv}_3577_wy1988_2023.tif",
  method_source = "green_at_floor() verbatim from scripts/05_ground_cover/03_h2_seasonal_gate_and_diagnostics.R",
  not_this      = "NOT veg_p05 >= 50 (total cover at the floor); a different variable"
)

print(as.data.frame(out[, c("quantity", "value")]), row.names = FALSE)
gayini_write_csv(out, OUT_CSV)


## 6. Reconciliation against the scratch artefact Gate A traced ----
##
## Reported as a comparison of two numbers. No verdict is drawn here.

ref_csv <- file.path(diagnostics_dir, "ondisk_review_20260720", "refugia_area_check.csv")
if (file.exists(ref_csv)) {
  ref <- readr::read_csv(ref_csv, show_col_types = FALSE)
  getv <- function(tbl, q) {
    v <- tbl$value[tbl$quantity == q]
    if (length(v) == 1L) as.numeric(v) else NA_real_
  }
  cmp <- tibble::tibble(
    quantity = c("n_valid_floor_px", "n_majority_green_px_gt50", "area_ha_native_30m_3577"),
    this_script = vapply(c("n_valid_floor_px", "n_majority_green_px_gt50",
                           "area_ha_native_30m_3577"), function(q) getv(out, q), numeric(1)),
    scratch_2026_07_20 = vapply(c("n_valid_floor_px", "n_majority_green_px_gt50",
                                  "area_ha_native_30m_3577"), function(q) getv(ref, q), numeric(1))
  )
  cmp$difference <- cmp$this_script - cmp$scratch_2026_07_20
  message("\n[reconcile] this script vs the 2026-07-20 scratch artefact:")
  print(as.data.frame(cmp), row.names = FALSE)
} else {
  message("[reconcile] scratch artefact not present; nothing to compare against.")
}

message("\nDone. Number reported, not interpreted.")
