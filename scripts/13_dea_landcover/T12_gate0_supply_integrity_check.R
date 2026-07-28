#!/usr/bin/env Rscript
# T12 — Gate 0 resampling-integrity re-check on the newly supplied 1988-1999 files.
# Spec docs/reference_update/T12_dea_landcover_l3_extraction.md v2, Gate 0 item 3.
# HARD STOP if any distinct value is outside {111,112,124,215,216,220,255} — that
# would mean interpolated resampling and the series must be rebuilt from source.
# Also confirms grid/CRS/dtype uniformity and compareGeom against the existing series.

suppressMessages({library(terra)})
dir <- "d:/Github_repos/Gayini/Input/landsat_landcover/level3"
new_years <- 1988:1999
new_files <- file.path(dir, sprintf("LLC3_%d_MGA54.tif", new_years))
ref <- rast(file.path(dir, "LLC3_2000_MGA54.tif"))   # existing series reference grid
expected <- c(111, 112, 124, 215, 216, 220, 255)

all_vals <- integer(0); rows <- list()
for (f in new_files) {
  r <- rast(f); yr <- sub(".*LLC3_(\\d{4})_MGA54.*", "\\1", basename(f))
  vals <- sort(freq(r, bylayer = FALSE)[, "value"])
  all_vals <- sort(unique(c(all_vals, vals)))
  rows[[yr]] <- data.frame(year = yr, epsg = crs(r, describe = TRUE)$code,
    nx = ncol(r), ny = nrow(r), resx = res(r)[1], resy = res(r)[2],
    dtype = datatype(r), compareGeom_vs_existing = compareGeom(r, ref, stopOnError = FALSE),
    vals = paste(vals, collapse = "|"),
    unexpected = paste(setdiff(vals, expected), collapse = "|"), stringsAsFactors = FALSE)
}
tab <- do.call(rbind, rows)
print(tab[, c("year", "epsg", "nx", "ny", "resx", "resy", "dtype",
              "compareGeom_vs_existing", "vals", "unexpected")], row.names = FALSE)

cat("\n=== VERDICT (new files only) ===\n")
cat("global distinct 1988-1999:", paste(all_vals, collapse = ", "), "\n")
cat("subset of expected:", all(all_vals %in% expected),
    "| unexpected:", paste(setdiff(all_vals, expected), collapse = ", "), "\n")
cat("all 7854 / 2189x1545 / 30m / INT1U / compareGeom==existing:",
    all(tab$epsg == "7854" & tab$nx == 2189 & tab$ny == 1545 &
        tab$resx == 30 & tab$dtype == "INT1U" & tab$compareGeom_vs_existing), "\n")

allf <- list.files(dir, pattern = "^LLC3_\\d{4}_MGA54\\.tif$")
yrs <- sort(as.integer(sub(".*LLC3_(\\d{4}).*", "\\1", allf)))
cat("\nfull folder:", length(allf), "files, years", min(yrs), "-", max(yrs),
    "| contiguous 1988-2025:", identical(yrs, 1988:2025),
    "| missing:", paste(setdiff(1988:2025, yrs), collapse = ", "), "\n")
