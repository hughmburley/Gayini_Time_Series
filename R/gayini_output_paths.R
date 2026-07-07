## -----------------------------------------------------------------------------
## Gayini remote sensing workflow
## gayini_output_paths.R
## -----------------------------------------------------------------------------

## Purpose:
## Robust output path resolution for review-refresh scripts.


gayini_path_is_absolute <- function(path) {
  grepl("^[A-Za-z]:[/\\\\]", path) || grepl("^/", path) || grepl("^\\\\\\\\", path)
}


gayini_as_project_path <- function(root_dir, path) {
  if (is.na(path) || !nzchar(path)) {
    return(NA_character_)
  }

  if (gayini_path_is_absolute(path)) {
    return(normalizePath(path, winslash = "/", mustWork = FALSE))
  }

  normalizePath(file.path(root_dir, path), winslash = "/", mustWork = FALSE)
}


gayini_relative_path <- function(root_dir, path) {
  if (length(path) > 1L) {
    return(vapply(path, function(one_path) gayini_relative_path(root_dir, one_path), character(1)))
  }

  if (is.na(path) || !nzchar(path)) {
    return(NA_character_)
  }

  root_norm <- normalizePath(root_dir, winslash = "/", mustWork = TRUE)
  path_norm <- normalizePath(path, winslash = "/", mustWork = FALSE)

  if (startsWith(path_norm, paste0(root_norm, "/"))) {
    return(substring(path_norm, nchar(root_norm) + 2L))
  }

  path_norm
}


gayini_find_output <- function(root_dir,
                               candidates,
                               logical_name = "output",
                               required = TRUE) {
  candidate_paths <- vapply(
    candidates,
    function(path) gayini_as_project_path(root_dir, path),
    character(1)
  )

  exists_vec <- file.exists(candidate_paths)
  selected <- candidate_paths[exists_vec][1]

  if (length(selected) == 0L || is.na(selected)) {
    if (isTRUE(required)) {
      stop(
        "Missing expected output for ", logical_name, ". Tried: ",
        paste(candidate_paths, collapse = "; "),
        call. = FALSE
      )
    }
    return(NA_character_)
  }

  selected
}


gayini_task15_describe_path <- function(path, type = c("csv", "raster", "spatial", "file")) {
  type <- match.arg(type)

  if (is.na(path) || !file.exists(path)) {
    return(list(row_count = NA_integer_, dimensions = NA_character_))
  }

  if (type == "csv") {
    n_rows <- nrow(readr::read_csv(path, show_col_types = FALSE, progress = FALSE))
    return(list(row_count = n_rows, dimensions = NA_character_))
  }

  if (type == "raster") {
    raster <- terra::rast(path)
    dims <- paste0(
      terra::nrow(raster), " rows x ",
      terra::ncol(raster), " cols x ",
      terra::nlyr(raster), " layer(s)"
    )
    return(list(row_count = NA_integer_, dimensions = dims))
  }

  if (type == "spatial") {
    layer <- sf::st_read(path, quiet = TRUE)
    return(list(row_count = nrow(layer), dimensions = paste0(sf::st_geometry_type(layer)[1], " layer")))
  }

  info <- file.info(path)
  list(row_count = NA_integer_, dimensions = paste0(info$size, " bytes"))
}


gayini_resolve_output_specs <- function(root_dir,
                                        specs) {
  resolved_paths <- list()
  check_rows <- vector("list", length(specs))

  for (i in seq_along(specs)) {
    spec <- specs[[i]]
    logical_name <- spec$logical_name
    candidates <- spec$candidates
    required <- isTRUE(spec$required)
    type <- spec$type %||% "file"

    candidate_paths <- vapply(
      candidates,
      function(path) gayini_as_project_path(root_dir, path),
      character(1)
    )
    exists_vec <- file.exists(candidate_paths)
    selected <- candidate_paths[exists_vec][1]

    if (length(selected) == 0L || is.na(selected)) {
      selected <- NA_character_
      status <- if (required) "missing_required" else "missing_optional"
      detail <- "No candidate path exists."
      desc <- list(row_count = NA_integer_, dimensions = NA_character_)
    } else {
      selected <- unname(selected)
      status <- if (which(exists_vec)[1] == 1L) "found_preferred" else "found_fallback"
      detail <- if (status == "found_fallback") {
        "Preferred grouped path was unavailable; fallback candidate was used."
      } else {
        "Preferred candidate used."
      }
      desc <- gayini_task15_describe_path(selected, type = type)
    }

    resolved_paths[[logical_name]] <- selected
    check_rows[[i]] <- tibble::tibble(
      logical_input_name = logical_name,
      candidate_paths_tried = paste(gayini_relative_path(root_dir, candidate_paths), collapse = "; "),
      selected_path = gayini_relative_path(root_dir, selected),
      status = status,
      required = required,
      row_count = desc$row_count,
      raster_or_layer_dimensions = desc$dimensions,
      notes = detail
    )
  }

  list(
    paths = unlist(resolved_paths, use.names = TRUE),
    checks = dplyr::bind_rows(check_rows)
  )
}


gayini_task15_input_specs <- function() {
  list(
    list(
      logical_name = "plot_base_csv",
      type = "csv",
      required = TRUE,
      candidates = c(
        "Output/csv/canonical/plot_rs_gauge_analysis_base.csv",
        "Output/csv/plot_rs_gauge_analysis_base.csv",
        "Output/csv/plot_rs_analysis_base.csv"
      )
    ),
    list(
      logical_name = "plot_context_flags_csv",
      type = "csv",
      required = TRUE,
      candidates = c(
        "Output/csv/ground_cover/plot_context_flags.csv",
        "Output/csv/plot_context_flags.csv"
      )
    ),
    list(
      logical_name = "ground_cover_interpretation_csv",
      type = "csv",
      required = TRUE,
      candidates = c(
        "Output/csv/ground_cover/10a_ground_cover_prepost_plot_summary_interpretation.csv",
        "Output/csv/10a_ground_cover_prepost_plot_summary_interpretation.csv"
      )
    ),
    list(
      logical_name = "ground_cover_all_csv",
      type = "csv",
      required = FALSE,
      candidates = c(
        "Output/csv/ground_cover/10a_ground_cover_prepost_plot_summary.csv",
        "Output/csv/10a_ground_cover_prepost_plot_summary.csv"
      )
    ),
    list(
      logical_name = "annual_timeseries_csv",
      type = "csv",
      required = FALSE,
      candidates = c(
        "Output/csv/canonical/curated_annual_inundation_timeseries.csv",
        "Output/csv/curated_annual_inundation_timeseries.csv"
      )
    ),
    list(
      logical_name = "daily_monthly_csv",
      type = "csv",
      required = FALSE,
      candidates = c(
        "Output/csv/canonical/curated_daily_inundation_monthly.csv",
        "Output/csv/curated_daily_inundation_monthly.csv"
      )
    ),
    list(
      logical_name = "water_year_context_csv",
      type = "csv",
      required = TRUE,
      candidates = c(
        "data_processed/hydrology/plot_rs_gauge_water_year_context.csv",
        "Output/csv/hydrology/plot_rs_gauge_water_year_context.csv"
      )
    ),
    list(
      logical_name = "plot_spatial_gpkg",
      type = "spatial",
      required = TRUE,
      candidates = c("data_intermediate/spatial/plots_clean.gpkg")
    ),
    list(
      logical_name = "boundary_gpkg",
      type = "spatial",
      required = TRUE,
      candidates = c("data_intermediate/spatial/boundary_clean.gpkg")
    ),
    list(
      logical_name = "annual_pre_raster",
      type = "raster",
      required = TRUE,
      candidates = c("Output/rasters/inundation_pre_post/pre_conservation_inundation_frequency_pct.tif")
    ),
    list(
      logical_name = "annual_post_raster",
      type = "raster",
      required = TRUE,
      candidates = c("Output/rasters/inundation_pre_post/post_conservation_inundation_frequency_pct.tif")
    ),
    list(
      logical_name = "annual_change_raster",
      type = "raster",
      required = TRUE,
      candidates = c("Output/rasters/inundation_pre_post/post_minus_pre_inundation_frequency_pct_points.tif")
    ),
    list(
      logical_name = "mer_pre_raster",
      type = "raster",
      required = FALSE,
      candidates = c("Output/rasters/MER/period_summaries/mer_pre_annual_max_observed_frequency_pct.tif")
    ),
    list(
      logical_name = "mer_post_raster",
      type = "raster",
      required = FALSE,
      candidates = c("Output/rasters/MER/period_summaries/mer_post_annual_max_observed_frequency_pct.tif")
    ),
    list(
      logical_name = "mer_change_raster",
      type = "raster",
      required = FALSE,
      candidates = c("Output/rasters/MER/period_summaries/mer_post_minus_pre_annual_max_frequency_pct_points.tif")
    ),
    list(
      logical_name = "mer_period_summary_csv",
      type = "csv",
      required = FALSE,
      candidates = c("Output/csv/MER/mer_period_summary_by_plot.csv")
    ),
    list(
      logical_name = "mer_comparison_csv",
      type = "csv",
      required = FALSE,
      candidates = c("Output/csv/MER/mer_vs_annual_occurrence_raster_comparison_by_plot.csv")
    ),
    list(
      logical_name = "dashboard_candidates_csv",
      type = "csv",
      required = FALSE,
      candidates = c("Output/csv/review_deck/candidate_dashboard_set_for_review_updated.csv")
    )
  )
}


gayini_resolve_task15_inputs <- function(root_dir) {
  gayini_resolve_output_specs(root_dir, gayini_task15_input_specs())
}


gayini_column <- function(df, candidates, default = NA_character_) {
  for (candidate in candidates) {
    if (candidate %in% names(df)) {
      return(df[[candidate]])
    }
  }

  rep(default, nrow(df))
}


`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}
