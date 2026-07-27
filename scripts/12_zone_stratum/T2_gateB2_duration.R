#!/usr/bin/env Rscript
# T2 Gate B2 - per-pixel vegetation PERSISTENCE-DURATION surface.
# From the 35-layer PRIMARY annual total-veg stack (total_veg_annual_mean_8058),
# count the years each pixel exceeds each threshold t in {50,60,70,80}.
# DENOMINATOR: two are computed and BOTH stored, because the spec says count
# valid_years from `valid_any` (the INUNDATION stack) yet its own justification is
# about VEG validity. pct_above_* uses the veg-own valid-year count (correct for a
# veg measure); inund_valid_years is stored alongside so the choice is auditable and
# reversible. Flagged at the Gate D STOP. Raw values; 30 m native FC provenance noted.
# Distinct from T3's veg_p05 (level held 95% of time) - this is #years above a level.

suppressPackageStartupMessages({library(terra)})
root <- normalizePath(".", winslash = "/")
source(file.path(root, "R/gayini_params.R"))
source(file.path(root, "R/gayini_figure_register.R"))   # gayini_sha256_first50()

veg   <- rast("Output/rasters/veg_annual_8058/total_veg_annual_mean_8058.tif")
valid <- rast("Output/rasters/inundation_annual_stack_8058/annual_valid_any_1988_2023_8058.tif")

THR <- c(50, 60, 70, 80)
MIN_VVY <- 10L   # pct_above_* is NA below this many observed veg-years, so a pixel
                 # seen 1 year cannot read 100% beside one seen 30 of 35.
veg_valid_years   <- sum(!is.na(veg))                       # years veg observed
inund_valid_years <- sum(valid, na.rm = TRUE)               # years valid_any==1
inund_valid_years <- mask(inund_valid_years, veg_valid_years > 0, maskvalue = FALSE)
enough <- veg_valid_years >= MIN_VVY                        # min-n mask for ratios

bands <- list(veg_valid_years   = veg_valid_years,
              inund_valid_years = inund_valid_years)
for (t in THR) {
  n_above <- sum(veg > t, na.rm = TRUE)                     # years above t (raw count)
  n_above <- mask(n_above, veg_valid_years > 0, maskvalue = FALSE)
  pct     <- 100 * n_above / veg_valid_years
  pct     <- mask(pct, enough, maskvalue = FALSE)           # NA where veg_valid_years < MIN_VVY
  bands[[sprintf("n_above_%d", t)]]   <- n_above
  bands[[sprintf("pct_above_%d", t)]] <- pct
}
out <- rast(bands)
names(out) <- names(bands)

outdir <- file.path(root, "Output/rasters/veg_duration_8058")
dir.create(outdir, showWarnings = FALSE, recursive = TRUE)
outpath <- file.path(outdir, "veg_persistence_duration_8058.tif")
writeRaster(out, outpath, overwrite = TRUE, datatype = "FLT4S")

# quick stats for the change report
mm <- minmax(out)
cat("bands:", paste(names(out), collapse = ", "), "\n")
for (nm in names(out)) cat(sprintf("  %-18s [%.3f, %.3f]\n", nm, mm[1, nm], mm[2, nm]))

## ---- register in raster_asset (INSERT OR REPLACE, first-50-MB SHA-256) ----
e   <- as.vector(ext(out))
sha <- gayini_sha256_first50(outpath)
relpath <- sub(paste0(root, "/"), "", gsub("\\\\","/", normalizePath(outpath, winslash="/")), fixed = TRUE)
legend <- paste0(
  "T2 B2 per-pixel veg persistence-duration, 10 bands: veg_valid_years (years veg ",
  "observed), inund_valid_years (years valid_any==1; note valid_any is uniformly 35 so ",
  "it is NOT the denominator), n_above_{50,60,70,80} (years annual total-veg mean > t), ",
  "pct_above_{50,60,70,80} = 100*n_above / veg_valid_years, set NA where veg_valid_years ",
  "< 10 (min-n, so 1-of-1 cannot read 100%). Source total_veg_annual_mean_8058 (FC native ",
  "30 m -> bilinear 8058). Scope: all-pixel (no strata filter). Distinct from T3 veg_p05.")
con <- DBI::dbConnect(RSQLite::SQLite(), file.path(root, "Output/database/Gayini_Results.sqlite"))
DBI::dbExecute(con,
  "INSERT OR REPLACE INTO raster_asset
     (raster_asset_id, path, metric_id, water_year, period_label, crs,
      resolution_x, resolution_y, xmin, ymin, xmax, ymax, checksum_sha256,
      path_exists, qa_status, run_id, crs_epsg, product, legend_status,
      legend_semantics, superseded_flag, framing_label, provenance_note)
   VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,1,'REVIEW',?,8058,?,?,?,0,?,?)",
  params = list("raster_veg_persistence_duration_8058", relpath, "veg_persistence_duration",
                NA, "WY1988-2023", "EPSG:8058", res(out)[1], res(out)[2],
                e["xmin"], e["ymin"], e["xmax"], e["ymax"], sha,
                "T2_gateB2", "veg_persistence_duration_8058", "confirmed", legend,
                "census_8058", "Denominator veg_valid_years (veg-own); inund_valid_years stored for audit."))
DBI::dbDisconnect(con)
cat(sprintf("\nregistered raster_veg_persistence_duration_8058 (%s)\n", substr(sha,1,12)))
cat("DONE\n")
