# ------------------------------------------------------------------------------
# R/gayini_db_validation.R
# DB-connected validation for the Gayini results database.
#
#   gayini_assert_post_build_objects(con)  -- B4 guard: hard-stops if a full
#       rebuild wiped the post-build mutations (raster_asset metadata, the unified
#       annual stack registration, census_stratum / v_pixel_census_by_veg_regime,
#       the modelling spine). The Python builder unlinks + rebuilds without GDAL,
#       so these are re-applied AFTER the build (order: builder -> 05 -> 03 -> 09).
#       A DB that fails this guard has NOT had its post-build steps re-run.
#
#   gayini_validate_spine(con)             -- returns a check data.frame for the
#       modelling spine: shape (2310 = 66 x 35), the 4-class grouping, absence of
#       the retired period / vegetation_adrian_group / drier_post columns, and that
#       the headline flood-frequency gradient reproduces (9 / 22 / 50 / 44).
#
# Both take an open DBI connection. Pure DBI/base R -- no rasters, no terra.
# ------------------------------------------------------------------------------

gayini_db_object_exists <- function(con, name) {
  n <- DBI::dbGetQuery(
    con,
    "SELECT COUNT(*) AS n FROM sqlite_master WHERE name = ? AND type IN ('table','view')",
    params = list(name)
  )$n
  n > 0L
}

# ---- B4 guard ----------------------------------------------------------------

gayini_assert_post_build_objects <- function(con,
                                             spine_rows       = 2310L,
                                             n_focus_strata   = 9L,
                                             n_context_strata = 2L,
                                             stack_asset_ids  = c("stack_annual_wet_any_1988_2023",
                                                                  "stack_annual_valid_any_1988_2023")) {
  fail <- character(0)
  add  <- function(msg) fail[[length(fail) + 1L]] <<- msg

  ## 1. raster_asset populated
  if (!gayini_db_object_exists(con, "raster_asset")) {
    add("raster_asset table is missing.")
  } else {
    if (DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM raster_asset")$n == 0L) {
      add("raster_asset has 0 rows (03_populate_raster_metadata.R not run).")
    }
    ## 2. unified annual stack registered, with CRS populated
    has_crs_col <- "crs_epsg" %in% DBI::dbGetQuery(con, "PRAGMA table_info(raster_asset)")$name
    for (aid in stack_asset_ids) {
      q <- DBI::dbGetQuery(con,
        "SELECT COUNT(*) AS n, SUM(CASE WHEN crs_epsg IS NOT NULL THEN 1 ELSE 0 END) AS n_crs
           FROM raster_asset WHERE raster_asset_id = ?", params = list(aid))
      if (q$n == 0L) {
        add(sprintf("annual-stack asset '%s' not registered (05_build_unified_annual_stack.R not run).", aid))
      } else if (has_crs_col && (is.na(q$n_crs) || q$n_crs == 0L)) {
        add(sprintf("annual-stack asset '%s' has NULL crs_epsg (03_populate_raster_metadata.R not run).", aid))
      }
    }
  }

  ## 3. census_stratum table with the expected row count
  if (!gayini_db_object_exists(con, "census_stratum")) {
    add("census_stratum table is missing (09_build_pixel_census_view.R not run).")
  } else {
    n <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM census_stratum")$n
    if (n != n_focus_strata + n_context_strata) {
      add(sprintf("census_stratum has %d rows; expected %d (%d focus + %d context).",
                  n, n_focus_strata + n_context_strata, n_focus_strata, n_context_strata))
    }
  }

  ## 4. pixel-census view
  if (!gayini_db_object_exists(con, "v_pixel_census_by_veg_regime")) {
    add("v_pixel_census_by_veg_regime view is missing (09_build_pixel_census_view.R not run).")
  }

  ## 5. modelling spine (lives in the builder, should always be present)
  if (!gayini_db_object_exists(con, "v_plot_year_analysis_spine")) {
    add("v_plot_year_analysis_spine view is missing (DB build failed).")
  } else {
    n <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM v_plot_year_analysis_spine")$n
    if (n != spine_rows) add(sprintf("v_plot_year_analysis_spine has %d rows; expected %d.", n, spine_rows))
  }

  if (length(fail) > 0L) {
    stop("Post-build DB guard FAILED -- the rebuild's post-build mutations are missing or stale:\n",
         paste0("  - ", fail, collapse = "\n"),
         "\nRe-run, in order: builder -> 05_build_unified_annual_stack.R -> ",
         "03_populate_raster_metadata.R -> 09_build_pixel_census_view.R",
         call. = FALSE)
  }
  message("Post-build DB guard: PASS (raster_asset + annual stack + census + spine present).")
  invisible(TRUE)
}

# ---- spine data validation ---------------------------------------------------

gayini_validate_spine <- function(con,
                                  spine_rows = 2310L,
                                  n_plots    = 66L,
                                  n_years    = 35L) {
  rows <- list()
  add  <- function(check, ok, detail) {
    rows[[length(rows) + 1L]] <<- data.frame(
      check = check, status = if (isTRUE(ok)) "pass" else "fail",
      detail = detail, stringsAsFactors = FALSE)
  }

  spine_cols <- DBI::dbGetQuery(con, "PRAGMA table_info(v_plot_year_analysis_spine)")$name

  n <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM v_plot_year_analysis_spine")$n
  add("spine_row_count", n == spine_rows, sprintf("%d rows (expect %d)", n, spine_rows))

  py <- DBI::dbGetQuery(con,
    "SELECT COUNT(DISTINCT plot_id) AS p, COUNT(DISTINCT water_year) AS y FROM v_plot_year_analysis_spine")
  add("spine_plots_x_years", py$p == n_plots && py$y == n_years,
      sprintf("%d plots x %d water years (expect %d x %d)", py$p, py$y, n_plots, n_years))

  grp <- sort(DBI::dbGetQuery(con,
    "SELECT DISTINCT simplified_vegetation_group AS g FROM v_plot_year_analysis_spine")$g)
  expect_grp <- sort(c("Aeolian Chenopod Shrublands", "Riverine Chenopod Shrublands",
                       "Inland Floodplain Shrublands / Swamps", "Floodplain Woodland / Forest"))
  add("four_class_grouping", identical(grp, expect_grp),
      sprintf("groups: %s", paste(grp, collapse = " | ")))

  leak <- intersect(c("period", "vegetation_adrian_group", "drier_post"), spine_cols)
  add("no_retired_column_leakage", length(leak) == 0L,
      if (length(leak)) paste("LEAKED:", paste(leak, collapse = ", ")) else "no period/adrian/drier_post columns")

  hl <- DBI::dbGetQuery(con,
    "SELECT simplified_vegetation_group AS g,
            100.0 * SUM(annual_wet_any) / SUM(annual_valid_any) AS freq
       FROM v_plot_year_analysis_spine
      WHERE annual_valid_any IS NOT NULL
      GROUP BY simplified_vegetation_group")
  target <- c("Aeolian Chenopod Shrublands" = 9,  "Riverine Chenopod Shrublands" = 22,
              "Inland Floodplain Shrublands / Swamps" = 50, "Floodplain Woodland / Forest" = 44)
  got  <- setNames(hl$freq, hl$g)[names(target)]
  ok   <- all(abs(got - target) < 1.0)
  add("headline_gradient", ok,
      sprintf("Aeolian %.1f / Riverine %.1f / Inland %.1f / Woodland %.1f (expect ~9/22/50/44)",
              got[[1]], got[[2]], got[[3]], got[[4]]))

  do.call(rbind, rows)
}
