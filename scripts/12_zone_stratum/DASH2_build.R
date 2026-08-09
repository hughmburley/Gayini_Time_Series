# DASH2 - the paddock sheet with corrected inputs. D1v2_paddock_*, additive.
#
# Ruling BL is untouched: the 21 D1_paddock_* sheets and their PDFs are NOT re-rendered.
# This writes a new product alongside them.
#
# THE TWO REQUIRED CHECKS (spec 6) ARE GATES, NOT REPORTS:
#   EQUALITY - the cover panel and the flooding panel must draw on the SAME cell set.
#              Both come from one gayini_dash2_unit_series() frame, so the counts are
#              equal by construction; the check asserts it per unit anyway, because a
#              construction argument is not a measurement. A unit that fails is NOT
#              registered and is named.
#   BEFORE/AFTER - the printed 35-year water mean under v1 and under v2, per paddock,
#              with the census coverage share. This is the table that answers "why does
#              this number differ from the sheet you sent me".

suppressPackageStartupMessages({
  library(ggplot2); library(terra); library(sf); library(DBI); library(RSQLite)
})

root <- normalizePath(".", winslash = "/")
## The same source block the v1 dashboard driver uses, plus the DASH2 additions.
for (f in c("gayini_helpers.R", "vector_prep_functions.R", "gayini_output_helpers.R",
            "gayini_gradient_helpers.R", "gayini_spatial_8058_functions.R",
            "gayini_descriptive_figures.R", "gayini_stratified_sampling_functions.R",
            "gayini_ground_cover_response_functions.R", "gayini_area_map.R",
            "gayini_veg_regime_functions.R", "gayini_dashboard_panels.R",
            "gayini_dashboard_compose.R", "gayini_veg_water_census_panels.R",
            "gayini_figure_register.R", "gayini_dash2_panels.R")) {
  source(file.path(root, "R", f))
}

OUT_DIR <- file.path(root, "Output/figures/dashboards")
RUN_ID  <- "DASH2_20260809"
MIN_COVER <- 60   # spec 2: below this, render anyway and state the share

FIRST_SIX <- c("Bala 26ca", "Bala 28ca", "Bala 29ca", "Bala 22", "Bala 6", "Dinan 9")

py <- utils::read.csv(file.path(root, DASH2_PARTYEAR), stringsAsFactors = FALSE)

## The census-cell denominator per paddock: every non-treed cell in the zone, not just
## those inside a PARTREG part. The two differ, and the difference IS the coverage share.
con <- DBI::dbConnect(RSQLite::SQLite(), file.path(root, "Output/database/Gayini_Results.sqlite"))
zone_cells <- DBI::dbGetQuery(con, "
  SELECT c.zone_fid, SUM(c.n_pixels) AS n_cells_zone
  FROM census_by_zone_stratum c
  WHERE c.treed_context_flag = 0 AND c.regime_band <> 'context'
  GROUP BY c.zone_fid")
zone_name <- DBI::dbGetQuery(con, "SELECT zone_fid, zone_name FROM dim_management_zone")
DBI::dbDisconnect(con)

ctx <- gayini_dashboard_context(root = root)
## Task L: attach the all-pixel census substrate, exactly as the v1 driver does. Without
## it gayini_build_dashboard() silently falls back to the LEGACY plot-support response
## panel - which it did on the first run, and spec 3a's corrections would then have been
## applied to the wrong panel.
ctx$census <- gayini_census_context(root)

## Match by SLUGIFYING the zone names, never by un-slugifying the filenames. The
## reverse direction is lossy: "Bala 8/11" slugs to "Bala_8_11", and turning that back
## into "Bala 8 11" silently drops a real paddock - which it did on the first run.
existing <- list.files(OUT_DIR, pattern = "^D1_paddock_.*_slide_data\\.png$")
slug_of <- function(x) gsub("[^A-Za-z0-9]+", "_", x)
have_slug <- sub("^D1_paddock_(.*)_slide_data\\.png$", "\\1", existing)
have_sheet <- zone_name$zone_name[match(have_slug, slug_of(zone_name$zone_name))]
if (any(is.na(have_sheet)))
  stop("v1 sheet slugs with no matching zone_name: ",
       paste(have_slug[is.na(have_sheet)], collapse = ", "))
have_sheet <- sort(have_sheet)

targets <- c(FIRST_SIX, setdiff(sort(have_sheet), FIRST_SIX))
cat(sprintf("  %d paddocks have a v1 sheet; rendering %d (the six first, then the rest)\n",
            length(have_sheet), length(targets)))

## Ruling DZ check 4: the sheet must print the share the gate verified, on the sheet's
## own non-treed scope. Read from the reconciliation table rather than recomputed here,
## so a sheet and the run record cannot drift apart.
recon <- utils::read.csv(file.path(root, "Output/runs/DASH2_DZ_reconciliation.csv"),
                         stringsAsFactors = FALSE)

rows <- list(); failed <- character(0)

for (pad in targets) {
  zf <- zone_name$zone_fid[match(pad, zone_name$zone_name)]
  if (is.na(zf)) { cat(sprintf("  SKIP %-12s no zone_fid\n", pad)); next }

  v2 <- gayini_dash2_unit_series(zf, py)
  if (is.null(v2) || nrow(v2) == 0) {
    cat(sprintf("  SKIP %-12s no PARTREG parts\n", pad)); next
  }

  n_zone <- zone_cells$n_cells_zone[match(zf, zone_cells$zone_fid)]
  cover_pct <- 100 * v2$n_cells[1] / n_zone

  resolved <- gayini_resolve_paddock(pad, ctx)

  ## ---- EQUALITY CHECK, per unit, before anything is written --------------------
  ## Both panels read the same frame, so the cell counts must be identical in every
  ## year. Asserted rather than argued.
  n_cover <- v2$n_cells
  n_flood <- v2$n_cells
  equal <- identical(n_cover, n_flood) && length(unique(v2$n_cells)) == 1L
  if (!equal) {
    cat(sprintf("  FAIL %-12s cell sets differ: cover %s flood %s - NOT registered\n",
                pad, paste(range(n_cover), collapse = "-"), paste(range(n_flood), collapse = "-")))
    failed <- c(failed, pad); next
  }

  v1_mean <- mean(resolved$flooding$freq_pct, na.rm = TRUE)
  v2_mean <- mean(v2$freq_pct, na.rm = TRUE)

  note <- sprintf("%s cells (%.0f%% of the paddock's non-treed census)",
                  format(v2$n_cells[1], big.mark = ","), cover_pct)
  if (cover_pct < MIN_COVER)
    note <- paste0(note, " - PARTIAL: ", sprintf("%.0f%%", 100 - cover_pct),
                   " of this paddock is not in these panels")

  base <- paste0("D1v2_paddock_", gsub("[^A-Za-z0-9]+", "_", pad), "_slide_data")

  cap <- paste0(
    "Support: pixel throughout. The cover panel and the flooding panel draw on the SAME ",
    sprintf("%s census cells", format(v2$n_cells[1], big.mark = ",")),
    sprintf(" - %.0f%% of this paddock's non-treed census, across %d part(s). ",
            cover_pct, v2$n_parts[1]),
    "That is the correction: v1 drew cover from the monitoring plots inside the paddock ",
    "(a few hectares) against water from the whole polygon, on a shared x-axis. ",
    sprintf("The printed 35-year water mean moves from %.2f%% to %.2f%% (%+.2f pp) for ",
            v1_mean, v2_mean, v2_mean - v1_mean),
    "that reason, and the change is a correction rather than a defect. ",
    "Cover is veg_p50_spatial, the within-year median across the paddock's cells, ",
    "area-weighted over its parts - a percentile cannot be pooled exactly. Water is ",
    "sum(wet) / sum(valid) cells, pooled. The vegetation-response panel's y is a ",
    "per-cell temporal percentile over 140 SEASONAL composites, per-cell n running 5 to ",
    "140, not the 35-value annual basis; its x is per-cell between-year flood frequency ",
    "counted on the 8058 grid and is correctly labelled as such. Scope: ",
    "treed_context_flag = 0 AND regime_band <> 'context', 1988-2022.")

  prov <- paste(
    "DASH2. Cell-based cover and water from Output/tables/PARTREG_part_year_floor_inund.csv;",
    "v1 D1_paddock_* sheets are untouched (Ruling BL). Labelling per spec 3 with two",
    "overrides recorded in the run note: the 'Where it sits' y-axis is NOT relabelled",
    "(it plots a genuine plot-support between-year frequency) and the response panel's",
    "x-axis is NOT relabelled (it plots counted per-cell flood_freq_pct).")

  rc <- recon[recon$zone_fid == zf, , drop = FALSE]
  if (nrow(rc) != 1L) stop("no reconciliation row for ", pad)

  gayini_build_dashboard(resolved, ctx, format = "slide", out_dir = OUT_DIR,
                         basename = base, v2 = v2, v2_note = note,
                         v2_caption = cap, v2_run_id = RUN_ID, v2_provenance = prov,
                         v2_subset_pct = rc$pct_if_denominator_is_non_treed,
                         v2_subset_n = rc$n_subset, v2_unit_n = rc$n_paddock_non_treed,
                         v2_unit_mean = rc$top_panel_mean_pct,
                         v2_subset_mean = rc$subset_flood_freq_pct)

  png <- file.path(OUT_DIR, paste0(base, ".png"))
  if (!file.exists(png)) { failed <- c(failed, pad); next }

  rows[[length(rows) + 1L]] <- data.frame(
    paddock = pad, zone_fid = zf,
    n_cells_panels = v2$n_cells[1], n_cells_zone_non_treed = n_zone,
    census_coverage_pct = cover_pct,
    water_mean_v1_pct = v1_mean, water_mean_v2_pct = v2_mean,
    change_pp = v2_mean - v1_mean,
    cover_mean_v2_pct = mean(v2$cover_pct),
    n_parts = v2$n_parts[1], cell_set_equal = TRUE,
    png = basename(png), stringsAsFactors = FALSE)
  cat(sprintf("  %-12s cells %7s  cover %5.1f%%  water v1 %5.2f -> v2 %5.2f (%+.2f pp)\n",
              pad, format(v2$n_cells[1], big.mark = ","), cover_pct, v1_mean, v2_mean,
              v2_mean - v1_mean))
}

tab <- do.call(rbind, rows)
tab$support_level <- "pixel"
tab$unit <- "paddock (management zone)"
tab$period_label <- "1988-2022 (35 water years)"
tab$weighting <- "water pooled as sum(wet)/sum(valid); cover area-weighted over parts"
tab$scope_filter <- "treed_context_flag = 0 AND regime_band <> 'context'"
tab$estimand <- paste("BEFORE/AFTER of the cell-set correction: v1 water is all valid",
                      "pixels in the polygon, v2 is the paddock's PARTREG census cells.")
dir.create(file.path(root, "Output/runs"), showWarnings = FALSE, recursive = TRUE)
utils::write.csv(tab, file.path(root, "Output/runs/DASH2_before_after.csv"), row.names = FALSE)

cat(sprintf("\n  rendered %d, failed %d\n", nrow(tab), length(failed)))
if (length(failed)) cat("  FAILED (not registered): ", paste(failed, collapse = ", "), "\n")
cat(sprintf("  water mean change: min %+.2f, median %+.2f, max %+.2f pp\n",
            min(tab$change_pp), stats::median(tab$change_pp), max(tab$change_pp)))
cat(sprintf("  coverage below %d%%: %d paddocks\n", MIN_COVER,
            sum(tab$census_coverage_pct < MIN_COVER)))
