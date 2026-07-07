## inundation_pre_post_raster_functions.R ----

## Helper functions for building pre-/post-conservation inundation-frequency
## rasters from the Gayini annual Landsat and daily NSW/Sentinel-style
## inundation products.


## Required-column check ----

gayini_check_required_columns <- function(x, required_columns, object_name = "object") {
  missing_columns <- setdiff(required_columns, names(x))

  if (length(missing_columns) > 0) {
    stop(
      object_name,
      " is missing required columns: ",
      paste(missing_columns, collapse = ", "),
      call. = FALSE
    )
  }

  invisible(TRUE)
}


## Filename / sensor helpers ----

gayini_has_cloud3 <- function(file_name) {
  stringr::str_detect(tolower(basename(file_name)), "cloud3")
}


gayini_has_ors2 <- function(file_name) {
  stringr::str_detect(tolower(basename(file_name)), "ors2")
}


gayini_make_water_year <- function(date, start_month = 7) {
  dplyr::if_else(
    lubridate::month(date) >= start_month,
    lubridate::year(date) + 1L,
    lubridate::year(date)
  )
}


gayini_standardise_combined_inundation_catalog <- function(raster_catalog,
                                                           root,
                                                           start_date = as.Date("2013-07-01"),
                                                           end_date = as.Date("2026-06-30"),
                                                           conservation_date = as.Date("2019-07-01"),
                                                           water_year_start_month = 7,
                                                           prefer_cloud3_duplicates = TRUE) {
  gayini_check_required_columns(
    raster_catalog,
    c("file_path", "file_name", "product", "sensor", "resolution_x", "date_start", "date_end"),
    object_name = "raster_catalog"
  )

  out <- raster_catalog |>
    dplyr::mutate(
      file_path = as.character(.data$file_path),
      file_name = basename(.data$file_name),
      product = as.character(.data$product),
      sensor = as.character(.data$sensor),
      date_start = as.Date(.data$date_start),
      date_end = as.Date(.data$date_end),
      date_midpoint = .data$date_start + floor(as.numeric(.data$date_end - .data$date_start) / 2),
      file_exists = file.exists(.data$file_path),
      has_cloud3_name = gayini_has_cloud3(.data$file_name),
      has_ors2_name = gayini_has_ors2(.data$file_name),
      sensor_clean = dplyr::case_when(
        .data$product == "sentinel2_inundation" & .data$sensor == "unknown" & .data$resolution_x <= 12 ~ "s2_inferred_10m",
        .data$product == "sentinel2_inundation" & .data$sensor == "unknown" ~ "unknown_daily",
        TRUE ~ .data$sensor
      ),
      analysis_year = gayini_make_water_year(.data$date_midpoint, start_month = water_year_start_month),
      analysis_year_start = as.Date(paste0(.data$analysis_year - 1L, "-", sprintf("%02d", water_year_start_month), "-01")),
      analysis_year_end = analysis_year_start + lubridate::years(1) - lubridate::days(1),
      period = dplyr::case_when(
        .data$analysis_year_end < conservation_date ~ "pre_conservation",
        .data$analysis_year_start >= conservation_date ~ "post_conservation",
        TRUE ~ "transition_year"
      ),
      period_year = paste(.data$period, .data$analysis_year, sep = "__")
    ) |>
    dplyr::filter(
      .data$product %in% c("landsat_inundation", "sentinel2_inundation"),
      !is.na(.data$date_midpoint),
      .data$date_midpoint >= start_date,
      .data$date_midpoint <= end_date,
      !is.na(.data$period),
      .data$period != "transition_year",
      .data$file_exists
    )

  ## Same-sensor same-day duplicates should not double-count a day.
  ## Keep separate sensors on the same day because they are independent source rasters.
  if (prefer_cloud3_duplicates) {
    out <- out |>
      dplyr::arrange(
        .data$product,
        .data$sensor_clean,
        .data$date_midpoint,
        dplyr::desc(.data$has_cloud3_name),
        dplyr::desc(.data$has_ors2_name),
        .data$file_name
      ) |>
      dplyr::group_by(.data$product, .data$sensor_clean, .data$date_midpoint) |>
      dplyr::slice(1) |>
      dplyr::ungroup()
  }

  out |>
    dplyr::arrange(.data$analysis_year, .data$date_midpoint, .data$product, .data$sensor_clean, .data$file_name)
}


gayini_standardise_landsat_background_inundation_catalog <- function(raster_catalog,
                                                                     root,
                                                                     period_key,
                                                                     start_date,
                                                                     end_date,
                                                                     water_year_start_month = 7,
                                                                     prefer_cloud3_duplicates = TRUE) {
  gayini_check_required_columns(
    raster_catalog,
    c("file_path", "file_name", "product", "sensor", "date_start", "date_end"),
    object_name = "raster_catalog"
  )

  out <- raster_catalog |>
    dplyr::mutate(
      file_path = as.character(.data$file_path),
      file_path = dplyr::if_else(
        grepl("^[A-Za-z]:[/\\\\]|^/", .data$file_path),
        .data$file_path,
        file.path(root, .data$file_path)
      ),
      file_name = basename(.data$file_name),
      product = as.character(.data$product),
      sensor = as.character(.data$sensor),
      date_start = as.Date(.data$date_start),
      date_end = as.Date(.data$date_end),
      date_midpoint = .data$date_start + floor(as.numeric(.data$date_end - .data$date_start) / 2),
      file_exists = file.exists(.data$file_path),
      has_cloud3_name = gayini_has_cloud3(.data$file_name),
      has_ors2_name = gayini_has_ors2(.data$file_name),
      sensor_clean = dplyr::if_else(
        is.na(.data$sensor) | .data$sensor == "",
        "landsat",
        .data$sensor
      ),
      analysis_year = gayini_make_water_year(.data$date_midpoint, start_month = water_year_start_month),
      analysis_year_start = as.Date(paste0(.data$analysis_year - 1L, "-", sprintf("%02d", water_year_start_month), "-01")),
      analysis_year_end = .data$analysis_year_start + lubridate::years(1) - lubridate::days(1),
      period = period_key,
      period_year = paste(.data$period, .data$analysis_year, sep = "__")
    ) |>
    dplyr::filter(
      .data$product == "landsat_inundation",
      !is.na(.data$date_midpoint),
      .data$date_midpoint >= start_date,
      .data$date_midpoint <= end_date
    )

  if (prefer_cloud3_duplicates && nrow(out) > 0) {
    out <- out |>
      dplyr::arrange(
        .data$product,
        .data$sensor_clean,
        .data$date_midpoint,
        dplyr::desc(.data$has_cloud3_name),
        dplyr::desc(.data$has_ors2_name),
        .data$file_name
      ) |>
      dplyr::group_by(.data$product, .data$sensor_clean, .data$date_midpoint) |>
      dplyr::slice(1) |>
      dplyr::ungroup()
  }

  out |>
    dplyr::arrange(.data$analysis_year, .data$date_midpoint, .data$product, .data$sensor_clean, .data$file_name)
}


## Observation-density summaries ----

gayini_summarise_inundation_observation_density <- function(inundation_catalog) {
  gayini_check_required_columns(
    inundation_catalog,
    c("period", "analysis_year", "analysis_year_start", "analysis_year_end", "period_year", "product", "sensor_clean", "date_midpoint", "file_name"),
    object_name = "inundation_catalog"
  )

  inundation_catalog |>
    dplyr::mutate(
      is_annual_landsat = .data$product == "landsat_inundation",
      is_daily_product = .data$product == "sentinel2_inundation",
      is_s2 = .data$sensor_clean %in% c("s2", "s2_inferred_10m"),
      is_l7 = .data$sensor_clean == "l7",
      is_l8 = .data$sensor_clean == "l8",
      is_unknown_daily = .data$sensor_clean %in% c("unknown", "unknown_daily"),
      has_cloud3_name = gayini_has_cloud3(.data$file_name)
    ) |>
    dplyr::group_by(
      .data$period,
      .data$analysis_year,
      .data$analysis_year_start,
      .data$analysis_year_end,
      .data$period_year
    ) |>
    dplyr::summarise(
      n_rasters_total = dplyr::n(),
      n_unique_dates = dplyr::n_distinct(.data$date_midpoint),
      n_landsat_annual_rasters = sum(.data$is_annual_landsat, na.rm = TRUE),
      n_daily_rasters = sum(.data$is_daily_product, na.rm = TRUE),
      n_s2_rasters = sum(.data$is_s2, na.rm = TRUE),
      n_l7_rasters = sum(.data$is_l7, na.rm = TRUE),
      n_l8_rasters = sum(.data$is_l8, na.rm = TRUE),
      n_unknown_daily_rasters = sum(.data$is_unknown_daily, na.rm = TRUE),
      n_cloud3_named_rasters = sum(.data$has_cloud3_name, na.rm = TRUE),
      first_observation_date = min(.data$date_midpoint, na.rm = TRUE),
      last_observation_date = max(.data$date_midpoint, na.rm = TRUE),
      products = paste(sort(unique(.data$product)), collapse = "; "),
      sensors = paste(sort(unique(.data$sensor_clean)), collapse = "; "),
      observation_density_class = dplyr::case_when(
        .data$n_rasters_total <= 1 ~ "single_raster",
        .data$n_rasters_total <= 3 ~ "very_low_density",
        .data$n_rasters_total <= 8 ~ "moderate_density",
        TRUE ~ "high_density"
      ),
      s2_available = .data$n_s2_rasters > 0,
      .groups = "drop"
    ) |>
    dplyr::arrange(.data$period, .data$analysis_year)
}


## Raster grid helpers ----

gayini_make_reference_grid <- function(inundation_catalog,
                                       boundary_sf,
                                       reference_preference = "landsat_inundation",
                                       boundary_buffer_m = 100) {
  reference_candidates <- inundation_catalog |>
    dplyr::filter(.data$product == reference_preference) |>
    dplyr::arrange(.data$date_start, .data$file_name)

  if (nrow(reference_candidates) == 0) {
    reference_candidates <- inundation_catalog |>
      dplyr::arrange(.data$date_start, .data$file_name)
  }

  if (nrow(reference_candidates) == 0) {
    stop("No inundation rasters available to create a reference grid.", call. = FALSE)
  }

  reference_path <- reference_candidates$file_path[[1]]
  reference <- terra::rast(reference_path)[[1]]

  boundary_for_reference <- boundary_sf |>
    sf::st_transform(terra::crs(reference)) |>
    sf::st_buffer(dist = boundary_buffer_m)

  boundary_vect <- terra::vect(boundary_for_reference)

  reference <- terra::crop(reference, boundary_vect, snap = "out")

  ## Keep a real study-area mask based on the Gayini boundary, not on
  ## the valid-data footprint of the first reference raster. This avoids
  ## the earlier all-NA problem and also avoids silently excluding pixels
  ## that are NA in the first raster but valid in later rasters.
  reference <- terra::setValues(reference, 1)
  reference <- terra::mask(reference, boundary_vect)
  reference <- terra::ifel(!is.na(reference), 1, NA)
  names(reference) <- "reference_grid"

  reference_cells <- as.numeric(terra::global(!is.na(reference), sum, na.rm = TRUE)[1, 1])

  if (is.na(reference_cells) || reference_cells == 0) {
    stop(
      "Reference grid has zero non-NA cells after crop/mask. Check boundary CRS and raster overlap.",
      call. = FALSE
    )
  }

  reference
}


gayini_align_to_reference <- function(raster_layer, reference_grid) {
  same_geometry <- terra::compareGeom(
    raster_layer,
    reference_grid,
    stopOnError = FALSE,
    crs = TRUE,
    ext = TRUE,
    rowcol = TRUE,
    res = TRUE
  )

  if (isTRUE(same_geometry)) {
    return(raster_layer)
  }

  terra::project(raster_layer, reference_grid, method = "near")
}


gayini_align_binary_to_reference <- function(binary_layer,
                                             reference_grid,
                                             preferred_method = "max") {
  ## For harmonising inundation sources, align binary wet/valid rasters
  ## after reclassification, rather than aligning raw categorical rasters.
  ## This is important for Sentinel/native 10 m products because nearest
  ## neighbour can miss small wet pixels when downsampling to the common grid.

  same_geometry <- terra::compareGeom(
    binary_layer,
    reference_grid,
    stopOnError = FALSE,
    crs = TRUE,
    ext = TRUE,
    rowcol = TRUE,
    res = TRUE
  )

  if (isTRUE(same_geometry)) {
    aligned <- binary_layer
  } else {
    ## Try a conservative any-positive aggregation/resampling first.
    ## Fall back to nearest neighbour if the installed terra version does
    ## not support the requested method for the specific geometry case.
    aligned <- try(
      terra::resample(binary_layer, reference_grid, method = preferred_method),
      silent = TRUE
    )

    if (inherits(aligned, "try-error")) {
      aligned <- terra::project(binary_layer, reference_grid, method = "near")
    }
  }

  aligned <- terra::mask(aligned, reference_grid)
  aligned <- terra::ifel(!is.na(aligned) & aligned > 0, 1, 0)
  aligned <- terra::mask(aligned, reference_grid)

  aligned
}


## Inundation reclassification helpers ----

gayini_make_binary_inundation_layers <- function(raster_layer,
                                                 product,
                                                 daily_wet_rule = c("strict_value_1", "include_ors_value_2"),
                                                 nodata_values = c(255, 65535, 127, -1)) {
  daily_wet_rule <- match.arg(daily_wet_rule)

  if (terra::nlyr(raster_layer) != 1) {
    raster_layer <- raster_layer[[1]]
  }

  if (product == "landsat_inundation") {
    # Confirmed value legend (NSW SEED metadata + Adrian's ruling, 2026-07-07):
    #   0 = not inundated     -> dry  (valid observation)
    #   1 = inundated         -> WET
    #   2 = off-river storage -> WET  (Adrian: "those pixels were wet just the same")
    #   3 = cloud shadow      -> MASK (failed observation: neither wet nor valid)
    # Explicit rule replacing the implicit `x > 0`, which silently counted value 3
    # (cloud shadow) as wet. wet = value IN (1,2); valid = value IN (0,1,2); value 3
    # is excluded from both. The vectorised %in% needs no branch on whether value 3
    # is present in a given raster. For the 35 canonical Landsat sources this is
    # identical to `x > 0` (they contain values {0,1,2} only), so the value-3 mask is
    # a no-op here -- but it is active for Sentinel-2 cloud shadow (Tier 3).
    landsat_valid_values <- c(0L, 1L, 2L)
    landsat_wet_values   <- c(1L, 2L)

    valid <- terra::app(
      raster_layer,
      fun = function(x) {
        as.integer(!is.na(x) & !(x %in% nodata_values) & x %in% landsat_valid_values)
      }
    )

    wet <- terra::app(
      raster_layer,
      fun = function(x) {
        as.integer(!is.na(x) & !(x %in% nodata_values) & x %in% landsat_wet_values)
      }
    )

  } else {
    valid_values <- c(0, 1, 2)

    wet_values <- if (daily_wet_rule == "include_ors_value_2") {
      c(1, 2)
    } else {
      c(1)
    }

    valid <- terra::app(
      raster_layer,
      fun = function(x) {
        as.integer(!is.na(x) & !(x %in% nodata_values) & x %in% valid_values)
      }
    )

    wet <- terra::app(
      raster_layer,
      fun = function(x) {
        as.integer(!is.na(x) & !(x %in% nodata_values) & x %in% wet_values)
      }
    )
  }

  names(valid) <- "valid_observation"
  names(wet) <- "wet_observation"

  list(wet = wet, valid = valid)
}


## Annual / period aggregation helpers ----

gayini_build_one_period_year_rasters <- function(period_year_catalog,
                                                 reference_grid,
                                                 daily_wet_rule = "strict_value_1",
                                                 nodata_values = c(255, 65535, 127, -1),
                                                 output_dir = NULL) {
  if (nrow(period_year_catalog) == 0) {
    stop("period_year_catalog has no rows.", call. = FALSE)
  }

  zero_template <- terra::ifel(!is.na(reference_grid), 0, NA)

  wet_sum <- zero_template
  valid_sum <- zero_template

  names(wet_sum) <- "wet_observation_count"
  names(valid_sum) <- "valid_observation_count"

  for (i in seq_len(nrow(period_year_catalog))) {
    raster_info <- period_year_catalog[i, , drop = FALSE]

    message(
      "  Adding ", i, " of ", nrow(period_year_catalog), ": ",
      raster_info$file_name[[1]]
    )

    r <- terra::rast(raster_info$file_path[[1]])[[1]]

    ## Reclassify at the source/native grid first, then align binary
    ## wet/valid layers to the common grid. This follows Adrian's logic:
    ## harmonise sensors onto one grid, but do not let a 10 m Sentinel
    ## pixel be lost by nearest-neighbour downsampling of raw classes.
    binary_native <- gayini_make_binary_inundation_layers(
      raster_layer = r,
      product = raster_info$product[[1]],
      daily_wet_rule = daily_wet_rule,
      nodata_values = nodata_values
    )

    wet_aligned <- gayini_align_binary_to_reference(
      binary_layer = binary_native$wet,
      reference_grid = reference_grid,
      preferred_method = "max"
    )

    valid_aligned <- gayini_align_binary_to_reference(
      binary_layer = binary_native$valid,
      reference_grid = reference_grid,
      preferred_method = "max"
    )

    wet_sum <- wet_sum + terra::ifel(is.na(wet_aligned), 0, wet_aligned)
    valid_sum <- valid_sum + terra::ifel(is.na(valid_aligned), 0, valid_aligned)
  }

  annual_wet_any <- terra::ifel(valid_sum > 0 & wet_sum > 0, 1, 0)
  annual_valid_any <- terra::ifel(valid_sum > 0, 1, NA)
  annual_wet_any <- terra::mask(annual_wet_any, annual_valid_any)

  names(annual_wet_any) <- "annual_inundated_any"
  names(annual_valid_any) <- "annual_valid_any"

  if (!is.null(output_dir)) {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

    period_year <- unique(period_year_catalog$period_year)
    if (length(period_year) != 1) {
      period_year <- period_year[[1]]
    }

    terra::writeRaster(
      annual_wet_any,
      filename = file.path(output_dir, paste0("annual_inundated_any_", period_year, ".tif")),
      overwrite = TRUE,
      gdal = c("COMPRESS=LZW")
    )

    terra::writeRaster(
      annual_valid_any,
      filename = file.path(output_dir, paste0("annual_valid_any_", period_year, ".tif")),
      overwrite = TRUE,
      gdal = c("COMPRESS=LZW")
    )
  }

  list(
    annual_wet_any = annual_wet_any,
    annual_valid_any = annual_valid_any,
    wet_observation_count = wet_sum,
    valid_observation_count = valid_sum
  )
}


gayini_build_period_frequency_rasters <- function(annual_outputs,
                                                  period_lookup,
                                                  period,
                                                  output_dir) {
  keep_names <- period_lookup |>
    dplyr::filter(.data$period == !!period) |>
    dplyr::pull(.data$period_year)

  keep_names <- keep_names[keep_names %in% names(annual_outputs)]

  if (length(keep_names) == 0) {
    stop("No annual outputs available for period: ", period, call. = FALSE)
  }

  wet_stack <- terra::rast(lapply(annual_outputs[keep_names], `[[`, "annual_wet_any"))
  valid_stack <- terra::rast(lapply(annual_outputs[keep_names], `[[`, "annual_valid_any"))

  wet_year_count <- terra::app(wet_stack, sum, na.rm = TRUE)
  valid_year_count <- terra::app(valid_stack, function(x) sum(!is.na(x)))

  valid_mask <- terra::ifel(valid_year_count > 0, 1, NA)

  inundation_frequency_pct <- 100 * wet_year_count / valid_year_count
  inundation_frequency_pct <- terra::mask(inundation_frequency_pct, valid_mask)

  wet_year_count <- terra::mask(wet_year_count, valid_mask)
  valid_year_count <- terra::mask(valid_year_count, valid_mask)

  names(wet_year_count) <- paste0(period, "_wet_year_count")
  names(valid_year_count) <- paste0(period, "_valid_year_count")
  names(inundation_frequency_pct) <- paste0(period, "_inundation_frequency_pct")

  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  terra::writeRaster(
    inundation_frequency_pct,
    filename = file.path(output_dir, paste0(period, "_inundation_frequency_pct.tif")),
    overwrite = TRUE,
    gdal = c("COMPRESS=LZW")
  )

  terra::writeRaster(
    wet_year_count,
    filename = file.path(output_dir, paste0(period, "_wet_year_count.tif")),
    overwrite = TRUE,
    gdal = c("COMPRESS=LZW")
  )

  terra::writeRaster(
    valid_year_count,
    filename = file.path(output_dir, paste0(period, "_valid_year_count.tif")),
    overwrite = TRUE,
    gdal = c("COMPRESS=LZW")
  )

  list(
    inundation_frequency_pct = inundation_frequency_pct,
    wet_year_count = wet_year_count,
    valid_year_count = valid_year_count
  )
}


## Plot extraction helpers ----

gayini_get_raster_crs_sf <- function(x) {
  crs_text <- terra::crs(x)

  if (is.na(crs_text) || crs_text == "") {
    stop("Raster has no CRS. Cannot transform plots for extraction.", call. = FALSE)
  }

  sf::st_crs(crs_text)
}


gayini_make_raster_extent_sfc <- function(x) {
  raster_crs <- gayini_get_raster_crs_sf(x)
  raster_ext <- terra::ext(x)

  sf::st_as_sfc(
    sf::st_bbox(
      c(
        xmin = terra::xmin(raster_ext),
        ymin = terra::ymin(raster_ext),
        xmax = terra::xmax(raster_ext),
        ymax = terra::ymax(raster_ext)
      ),
      crs = raster_crs
    )
  )
}


gayini_prepare_plots_for_raster <- function(plots_sf,
                                            reference_raster,
                                            buffer_pixels = 1) {
  raster_crs <- gayini_get_raster_crs_sf(reference_raster)
  raster_res <- terra::res(reference_raster)
  buffer_distance <- buffer_pixels * max(abs(raster_res))

  plots_for_raster <- plots_sf |>
    sf::st_make_valid() |>
    sf::st_transform(crs = raster_crs)

  if (any(sf::st_is_empty(plots_for_raster))) {
    stop(
      "Some plot geometries became empty after transforming to raster CRS.",
      call. = FALSE
    )
  }

  if (buffer_pixels > 0) {
    plots_for_raster <- sf::st_buffer(plots_for_raster, dist = buffer_distance)
  }

  list(
    plots_for_raster = plots_for_raster,
    buffer_distance = buffer_distance,
    raster_crs = raster_crs
  )
}



gayini_prepare_period_raster_stack <- function(period_rasters,
                                               context = "period_rasters") {
  if (inherits(period_rasters, "SpatRaster")) {
    raster_stack <- period_rasters
  } else if (is.character(period_rasters)) {
    if (!all(file.exists(period_rasters))) {
      missing <- period_rasters[!file.exists(period_rasters)]
      stop(
        context, " includes missing raster files: ",
        paste(missing, collapse = "; "),
        call. = FALSE
      )
    }

    raster_stack <- terra::rast(period_rasters)
  } else {
    raster_stack <- terra::rast(period_rasters)
  }

  if (!terra::hasValues(raster_stack)) {
    stop(
      context, " has geometry but no readable cell values. ",
      "This usually means the SpatRaster object was rebuilt from geometry only, ",
      "or the source files were not attached/readable. ",
      "Pass file paths to terra::rast(c(...)) or use an existing SpatRaster directly; ",
      "do not wrap an existing SpatRaster again with terra::rast().",
      call. = FALSE
    )
  }

  raster_stack
}

gayini_plot_raster_spatial_checks <- function(period_rasters,
                                              plots_sf,
                                              buffer_pixels = 1) {
  raster_stack <- gayini_prepare_period_raster_stack(
    period_rasters,
    context = "period_rasters passed to gayini_plot_raster_spatial_checks()"
  )

  reference_raster <- raster_stack[[1]]

  prepared <- gayini_prepare_plots_for_raster(
    plots_sf = plots_sf,
    reference_raster = reference_raster,
    buffer_pixels = buffer_pixels
  )

  plots_for_raster <- prepared$plots_for_raster
  raster_extent_sfc <- gayini_make_raster_extent_sfc(reference_raster)

  plot_intersects_extent <- lengths(sf::st_intersects(plots_for_raster, raster_extent_sfc)) > 0
  plot_bbox <- sf::st_bbox(plots_for_raster)
  raster_ext <- terra::ext(reference_raster)

  plot_centroids <- suppressWarnings(sf::st_centroid(plots_for_raster))
  centroid_values <- terra::extract(
    raster_stack,
    terra::vect(plot_centroids),
    ID = FALSE
  ) |>
    tibble::as_tibble()

  centroid_non_na <- centroid_values |>
    dplyr::summarise(
      dplyr::across(
        dplyr::everything(),
        ~sum(!is.na(.x)),
        .names = "{.col}"
      )
    ) |>
    tidyr::pivot_longer(
      cols = dplyr::everything(),
      names_to = "raster_layer",
      values_to = "centroid_non_na_plots"
    )

  spatial_summary <- tibble::tibble(
    check = c(
      "plots_total",
      "plots_intersect_raster_extent",
      "plots_not_intersecting_raster_extent",
      "buffer_pixels",
      "buffer_distance_m",
      "raster_xmin",
      "raster_xmax",
      "raster_ymin",
      "raster_ymax",
      "plot_bbox_xmin_raster_crs",
      "plot_bbox_xmax_raster_crs",
      "plot_bbox_ymin_raster_crs",
      "plot_bbox_ymax_raster_crs"
    ),
    value = c(
      as.character(nrow(plots_for_raster)),
      as.character(sum(plot_intersects_extent)),
      as.character(sum(!plot_intersects_extent)),
      as.character(buffer_pixels),
      as.character(prepared$buffer_distance),
      as.character(terra::xmin(raster_ext)),
      as.character(terra::xmax(raster_ext)),
      as.character(terra::ymin(raster_ext)),
      as.character(terra::ymax(raster_ext)),
      as.character(plot_bbox[["xmin"]]),
      as.character(plot_bbox[["xmax"]]),
      as.character(plot_bbox[["ymin"]]),
      as.character(plot_bbox[["ymax"]])
    )
  )

  list(
    spatial_summary = spatial_summary,
    centroid_non_na = centroid_non_na
  )
}


gayini_normalise_exactextractr_column_names <- function(extracted, expected_names, summary_method = "mean") {
  extracted <- tibble::as_tibble(extracted)

  if (ncol(extracted) == length(expected_names)) {
    names(extracted) <- expected_names
    return(extracted)
  }

  current_names <- names(extracted)

  stripped_names <- current_names |>
    stringr::str_remove(paste0("^", summary_method, "\\.")) |>
    stringr::str_remove(paste0("_", summary_method, "$")) |>
    stringr::str_remove(paste0("\\.", summary_method, "$"))

  names(extracted) <- stripped_names

  missing_expected <- setdiff(expected_names, names(extracted))

  if (length(missing_expected) > 0) {
    stop(
      "Could not recover expected exactextractr columns: ",
      paste(missing_expected, collapse = ", "),
      ". Extracted columns were: ",
      paste(current_names, collapse = ", "),
      call. = FALSE
    )
  }

  extracted |>
    dplyr::select(dplyr::all_of(expected_names))
}


gayini_extract_with_exactextractr <- function(raster_stack,
                                             plots_for_raster,
                                             expected_names,
                                             summary_method = "mean") {
  extracted_raw <- exactextractr::exact_extract(
    raster_stack,
    plots_for_raster,
    summary_method,
    progress = FALSE
  )

  gayini_normalise_exactextractr_column_names(
    extracted = extracted_raw,
    expected_names = expected_names,
    summary_method = summary_method
  )
}


gayini_extract_with_terra_fallback <- function(raster_stack,
                                               plots_for_raster,
                                               expected_names) {
  extracted_raw <- terra::extract(
    raster_stack,
    terra::vect(plots_for_raster),
    fun = mean,
    na.rm = TRUE,
    exact = TRUE,
    ID = FALSE
  ) |>
    tibble::as_tibble()

  if ("ID" %in% names(extracted_raw)) {
    extracted_raw <- dplyr::select(extracted_raw, - .data$ID)
  }

  missing_expected <- setdiff(expected_names, names(extracted_raw))

  if (length(missing_expected) > 0 && ncol(extracted_raw) == length(expected_names)) {
    names(extracted_raw) <- expected_names
    missing_expected <- setdiff(expected_names, names(extracted_raw))
  }

  if (length(missing_expected) > 0) {
    stop(
      "terra::extract fallback could not recover expected columns: ",
      paste(missing_expected, collapse = ", "),
      ". Extracted columns were: ",
      paste(names(extracted_raw), collapse = ", "),
      call. = FALSE
    )
  }

  extracted_raw |>
    dplyr::select(dplyr::all_of(expected_names))
}


gayini_count_non_na_rows <- function(x) {
  x <- tibble::as_tibble(x)
  sum(rowSums(!is.na(x)) > 0)
}


gayini_extract_period_rasters_to_plots <- function(period_rasters,
                                                   plots_sf,
                                                   buffer_pixels = 1,
                                                   summary_method = "mean",
                                                   allow_terra_fallback = TRUE,
                                                   stop_if_all_na = TRUE) {
  raster_stack <- gayini_prepare_period_raster_stack(
    period_rasters,
    context = "period_rasters passed to gayini_extract_period_rasters_to_plots()"
  )

  reference_raster <- raster_stack[[1]]

  prepared <- gayini_prepare_plots_for_raster(
    plots_sf = plots_sf,
    reference_raster = reference_raster,
    buffer_pixels = buffer_pixels
  )

  plots_for_raster <- prepared$plots_for_raster
  expected_names <- names(raster_stack)

  spatial_checks <- gayini_plot_raster_spatial_checks(
    period_rasters = raster_stack,
    plots_sf = plots_sf,
    buffer_pixels = buffer_pixels
  )

  n_centroid_non_na <- sum(spatial_checks$centroid_non_na$centroid_non_na_plots, na.rm = TRUE)

  extracted <- gayini_extract_with_exactextractr(
    raster_stack = raster_stack,
    plots_for_raster = plots_for_raster,
    expected_names = expected_names,
    summary_method = summary_method
  )

  extraction_method_used <- "exactextractr"
  n_exact_non_na_rows <- gayini_count_non_na_rows(extracted)

  if (n_exact_non_na_rows == 0 && n_centroid_non_na > 0 && isTRUE(allow_terra_fallback)) {
    warning(
      "exactextractr returned all NA, but centroid sampling found raster values. ",
      "Using terra::extract fallback for plot summaries.",
      call. = FALSE
    )

    extracted <- gayini_extract_with_terra_fallback(
      raster_stack = raster_stack,
      plots_for_raster = plots_for_raster,
      expected_names = expected_names
    )

    extraction_method_used <- "terra_exact_fallback"
  }

  n_final_non_na_rows <- gayini_count_non_na_rows(extracted)

  if (n_final_non_na_rows == 0 && isTRUE(stop_if_all_na)) {
    stop(
      "Plot extraction returned all NA values. ",
      "This usually means a plot/raster CRS or overlap problem. ",
      "Run gayini_plot_raster_spatial_checks() and inspect centroid_non_na.",
      call. = FALSE
    )
  }

  out <- sf::st_drop_geometry(plots_sf) |>
    dplyr::bind_cols(extracted) |>
    dplyr::mutate(
      buffer_pixels = buffer_pixels,
      buffer_distance_m = prepared$buffer_distance,
      extraction_engine = extraction_method_used,
      summary_method = summary_method,
      exactextractr_non_na_plot_rows = n_exact_non_na_rows,
      final_non_na_plot_rows = n_final_non_na_rows,
      centroid_non_na_values_total = n_centroid_non_na
    )

  out
}


## Raster value lookup / QA helpers ----

gayini_raster_value_summary <- function(x, raster_name) {
  value_freq <- terra::freq(x, digits = 12) |>
    tibble::as_tibble()

  if (!"value" %in% names(value_freq)) {
    names(value_freq)[1] <- "value"
  }

  if (!"count" %in% names(value_freq)) {
    names(value_freq)[2] <- "count"
  }

  value_freq |>
    dplyr::mutate(
      raster_name = raster_name,
      value = as.numeric(.data$value),
      count = as.numeric(.data$count)
    ) |>
    dplyr::select(.data$raster_name, .data$value, .data$count)
}


gayini_summarise_named_rasters <- function(named_rasters) {
  raster_stack <- gayini_prepare_period_raster_stack(
    named_rasters,
    context = "named_rasters passed to gayini_summarise_named_rasters()"
  )

  raster_names <- names(raster_stack)

  if (is.null(raster_names) || length(raster_names) != terra::nlyr(raster_stack)) {
    raster_names <- paste0("layer_", seq_len(terra::nlyr(raster_stack)))
  }

  purrr::map_dfr(
    seq_len(terra::nlyr(raster_stack)),
    function(i) {
      x <- raster_stack[[i]]
      nm <- raster_names[[i]]

      tibble::tibble(
        raster_name = nm,
        layer_index = i,
        non_na_cells = gayini_raster_non_na_count(x),
        min_value = gayini_raster_min(x),
        max_value = gayini_raster_max(x),
        mean_value = as.numeric(terra::global(x, mean, na.rm = TRUE)[1, 1])
      )
    }
  )
}


gayini_write_variable_lookup <- function(path) {
  lookup <- tibble::tribble(
    ~variable, ~type, ~expected_values, ~meaning, ~main_use,
    "annual_valid_any", "annual raster", "1 / NA", "Pixel had at least one valid/interpretable observation in that water year.", "Annual denominator mask; not a flood map.",
    "annual_inundated_any", "annual raster", "0 / 1 / NA", "Pixel was inundated at least once in that water year.", "Annual wet/not-wet occurrence layer.",
    "wet_year_count", "period raster", "0 to number of valid years", "Number of valid water years where annual_inundated_any = 1.", "Numerator for period frequency.",
    "valid_year_count", "period raster", "0 to number of years in period", "Number of water years with at least one valid/interpretable observation.", "Denominator for period frequency.",
    "pre_conservation_inundation_frequency_pct", "period raster", "0 to 100", "Percent of valid pre-conservation water years with at least one inundation event.", "Pre-conservation baseline.",
    "post_conservation_inundation_frequency_pct", "period raster", "0 to 100", "Percent of valid post-conservation water years with at least one inundation event.", "Post-conservation inundation frequency.",
    "post_minus_pre_inundation_frequency_pct_points", "period raster", "-100 to 100", "Post-conservation frequency minus pre-conservation frequency.", "Primary change surface."
  )

  readr::write_csv(lookup, path)

  invisible(lookup)
}



gayini_format_water_years_used <- function(period_year_lookup, period) {
  years <- period_year_lookup |>
    dplyr::filter(.data$period == !!period) |>
    dplyr::arrange(.data$analysis_year) |>
    dplyr::pull(.data$analysis_year) |>
    unique()

  if (length(years) == 0) {
    return(NA_character_)
  }

  paste(years, collapse = ";")
}


gayini_missing_target_years <- function(years_used, target_start_year, target_end_year) {
  target_years <- seq(target_start_year, target_end_year)
  missing_years <- setdiff(target_years, years_used)

  if (length(missing_years) == 0) {
    return(NA_character_)
  }

  paste(missing_years, collapse = ";")
}


gayini_classify_plot_inundation_change <- function(x) {
  dplyr::case_when(
    is.na(x) ~ "no_comparison",
    x >= 20 ~ "much_wetter_post",
    x >= 5 ~ "wetter_post",
    x <= -20 ~ "much_drier_post",
    x <= -5 ~ "drier_post",
    TRUE ~ "similar_frequency"
  )
}


gayini_add_period_metadata_to_plot_summary <- function(plot_summary,
                                                        period_year_lookup,
                                                        conservation_date,
                                                        pre_start_date,
                                                        post_end_date,
                                                        daily_wet_rule,
                                                        reference_product) {
  pre_years <- period_year_lookup |>
    dplyr::filter(.data$period == "pre_conservation") |>
    dplyr::arrange(.data$analysis_year) |>
    dplyr::pull(.data$analysis_year) |>
    unique()

  post_years <- period_year_lookup |>
    dplyr::filter(.data$period == "post_conservation") |>
    dplyr::arrange(.data$analysis_year) |>
    dplyr::pull(.data$analysis_year) |>
    unique()

  target_pre_start_year  <- lubridate::year(pre_start_date) + 1
  target_pre_end_year    <- lubridate::year(conservation_date)
  target_post_start_year <- lubridate::year(conservation_date) + 1
  target_post_end_year   <- lubridate::year(post_end_date)

  plot_summary |>
    dplyr::mutate(
      vegetation_adrian_group = dplyr::case_when(
        .data$vegetation %in% c("Inland Floodplain Shrublands", "Inland Floodplain Swamps") ~ "Inland Floodplain Shrublands / Swamps",
        TRUE ~ .data$vegetation
      ),
      inundation_change_class = gayini_classify_plot_inundation_change(
        .data$post_minus_pre_inundation_frequency_pct_points
      ),
      conservation_date = conservation_date,
      pre_start_date = pre_start_date,
      post_end_date = post_end_date,
      daily_wet_rule = daily_wet_rule,
      reference_product = reference_product,
      pre_water_years_used = ifelse(length(pre_years) > 0, paste(pre_years, collapse = ";"), NA_character_),
      post_water_years_used = ifelse(length(post_years) > 0, paste(post_years, collapse = ";"), NA_character_),
      n_pre_water_years_used = length(pre_years),
      n_post_water_years_used = length(post_years),
      target_pre_water_years = paste(seq(target_pre_start_year, target_pre_end_year), collapse = ";"),
      target_post_water_years = paste(seq(target_post_start_year, target_post_end_year), collapse = ";"),
      missing_target_pre_water_years = gayini_missing_target_years(pre_years, target_pre_start_year, target_pre_end_year),
      missing_target_post_water_years = gayini_missing_target_years(post_years, target_post_start_year, target_post_end_year)
    )
}

## Logical QA helpers ----

gayini_raster_min <- function(x) {
  as.numeric(terra::global(x, min, na.rm = TRUE)[1, 1])
}


gayini_raster_max <- function(x) {
  as.numeric(terra::global(x, max, na.rm = TRUE)[1, 1])
}


gayini_raster_sum <- function(x) {
  val <- as.numeric(terra::global(x, sum, na.rm = TRUE)[1, 1])
  ifelse(is.na(val), 0, val)
}


gayini_raster_non_na_count <- function(x) {
  val <- as.numeric(terra::global(!is.na(x), sum, na.rm = TRUE)[1, 1])
  ifelse(is.na(val), 0, val)
}


gayini_make_check_row <- function(check, passed, detail, severity = "review") {
  tibble::tibble(
    check = check,
    passed = isTRUE(passed),
    status = dplyr::if_else(isTRUE(passed), "PASS", "CHECK"),
    severity = severity,
    detail = as.character(detail)
  )
}


gayini_check_prepost_inundation_outputs <- function(inundation_catalog,
                                                     period_year_lookup,
                                                     observation_density = NULL,
                                                     pre_period,
                                                     post_period,
                                                     inundation_diff,
                                                     plot_summary,
                                                     plots_clean,
                                                     min_valid_years_pre = 2,
                                                     min_valid_years_post = 2) {

  pre_min  <- gayini_raster_min(pre_period$inundation_frequency_pct)
  pre_max  <- gayini_raster_max(pre_period$inundation_frequency_pct)
  post_min <- gayini_raster_min(post_period$inundation_frequency_pct)
  post_max <- gayini_raster_max(post_period$inundation_frequency_pct)
  diff_min <- gayini_raster_min(inundation_diff)
  diff_max <- gayini_raster_max(inundation_diff)

  pre_non_na  <- gayini_raster_non_na_count(pre_period$inundation_frequency_pct)
  post_non_na <- gayini_raster_non_na_count(post_period$inundation_frequency_pct)
  diff_non_na <- gayini_raster_non_na_count(inundation_diff)

  pre_wet_gt_valid <- gayini_raster_sum(
    terra::ifel(pre_period$wet_year_count > pre_period$valid_year_count, 1, 0)
  )

  post_wet_gt_valid <- gayini_raster_sum(
    terra::ifel(post_period$wet_year_count > post_period$valid_year_count, 1, 0)
  )

  pre_frequency_without_valid <- gayini_raster_sum(
    terra::ifel(!is.na(pre_period$inundation_frequency_pct) & pre_period$valid_year_count <= 0, 1, 0)
  )

  post_frequency_without_valid <- gayini_raster_sum(
    terra::ifel(!is.na(post_period$inundation_frequency_pct) & post_period$valid_year_count <= 0, 1, 0)
  )

  n_pre_years <- period_year_lookup |>
    dplyr::filter(.data$period == "pre_conservation") |>
    dplyr::distinct(.data$analysis_year) |>
    nrow()

  n_post_years <- period_year_lookup |>
    dplyr::filter(.data$period == "post_conservation") |>
    dplyr::distinct(.data$analysis_year) |>
    nrow()

  n_expected_plots <- nrow(plots_clean)
  n_plot_rows <- nrow(plot_summary)

  n_plot_no_comparison <- plot_summary |>
    dplyr::filter(is.na(.data$post_minus_pre_inundation_frequency_pct_points)) |>
    nrow()

  n_plot_low_pre_valid <- plot_summary |>
    dplyr::filter(.data$pre_conservation_valid_year_count < min_valid_years_pre | is.na(.data$pre_conservation_valid_year_count)) |>
    nrow()

  n_plot_low_post_valid <- plot_summary |>
    dplyr::filter(.data$post_conservation_valid_year_count < min_valid_years_post | is.na(.data$post_conservation_valid_year_count)) |>
    nrow()

  n_plot_pre_values <- sum(!is.na(plot_summary$pre_conservation_inundation_frequency_pct))
  n_plot_post_values <- sum(!is.na(plot_summary$post_conservation_inundation_frequency_pct))
  n_plot_diff_values <- sum(!is.na(plot_summary$post_minus_pre_inundation_frequency_pct_points))

  n_density_rows <- if (is.null(observation_density)) 0L else nrow(observation_density)

  n_single_raster_years <- if (is.null(observation_density)) {
    NA_integer_
  } else {
    observation_density |>
      dplyr::filter(.data$observation_density_class == "single_raster") |>
      nrow()
  }

  n_pre_single_raster_years <- if (is.null(observation_density)) {
    NA_integer_
  } else {
    observation_density |>
      dplyr::filter(.data$period == "pre_conservation", .data$observation_density_class == "single_raster") |>
      nrow()
  }

  n_post_single_raster_years <- if (is.null(observation_density)) {
    NA_integer_
  } else {
    observation_density |>
      dplyr::filter(.data$period == "post_conservation", .data$observation_density_class == "single_raster") |>
      nrow()
  }

  dplyr::bind_rows(
    gayini_make_check_row(
      "selected_rasters_exist",
      nrow(inundation_catalog) > 0 && all(inundation_catalog$file_exists),
      paste0(nrow(inundation_catalog), " selected rasters; all file_exists = ", all(inundation_catalog$file_exists)),
      severity = "stop_if_fail"
    ),

    gayini_make_check_row(
      "both_periods_present",
      all(c("pre_conservation", "post_conservation") %in% period_year_lookup$period),
      paste(unique(period_year_lookup$period), collapse = ", "),
      severity = "stop_if_fail"
    ),

    gayini_make_check_row(
      "enough_pre_water_years",
      n_pre_years >= min_valid_years_pre,
      paste0(n_pre_years, " pre-conservation water years"),
      severity = "review"
    ),

    gayini_make_check_row(
      "enough_post_water_years",
      n_post_years >= min_valid_years_post,
      paste0(n_post_years, " post-conservation water years"),
      severity = "review"
    ),

    gayini_make_check_row(
      "observation_density_summary_written",
      n_density_rows > 0,
      paste0(n_density_rows, " period-year rows in observation-density summary"),
      severity = "review"
    ),

    gayini_make_check_row(
      "single_raster_years_flagged",
      is.na(n_single_raster_years) || n_single_raster_years == 0,
      paste0(n_single_raster_years, " water years have only one selected raster; pre = ", n_pre_single_raster_years, "; post = ", n_post_single_raster_years),
      severity = "review"
    ),

    gayini_make_check_row(
      "pre_frequency_not_empty",
      pre_non_na > 0,
      paste0(pre_non_na, " non-NA cells"),
      severity = "stop_if_fail"
    ),

    gayini_make_check_row(
      "post_frequency_not_empty",
      post_non_na > 0,
      paste0(post_non_na, " non-NA cells"),
      severity = "stop_if_fail"
    ),

    gayini_make_check_row(
      "difference_not_empty",
      diff_non_na > 0,
      paste0(diff_non_na, " non-NA cells"),
      severity = "review"
    ),

    gayini_make_check_row(
      "pre_frequency_range",
      !is.na(pre_min) && pre_min >= 0 && pre_max <= 100,
      paste0("range = ", round(pre_min, 2), " to ", round(pre_max, 2)),
      severity = "stop_if_fail"
    ),

    gayini_make_check_row(
      "post_frequency_range",
      !is.na(post_min) && post_min >= 0 && post_max <= 100,
      paste0("range = ", round(post_min, 2), " to ", round(post_max, 2)),
      severity = "stop_if_fail"
    ),

    gayini_make_check_row(
      "difference_range",
      !is.na(diff_min) && diff_min >= -100 && diff_max <= 100,
      paste0("range = ", round(diff_min, 2), " to ", round(diff_max, 2)),
      severity = "stop_if_fail"
    ),

    gayini_make_check_row(
      "pre_wet_years_not_greater_than_valid_years",
      pre_wet_gt_valid == 0,
      paste0(pre_wet_gt_valid, " pixels where wet_year_count > valid_year_count"),
      severity = "stop_if_fail"
    ),

    gayini_make_check_row(
      "post_wet_years_not_greater_than_valid_years",
      post_wet_gt_valid == 0,
      paste0(post_wet_gt_valid, " pixels where wet_year_count > valid_year_count"),
      severity = "stop_if_fail"
    ),

    gayini_make_check_row(
      "pre_frequency_requires_valid_years",
      pre_frequency_without_valid == 0,
      paste0(pre_frequency_without_valid, " pixels have frequency but no valid pre years"),
      severity = "stop_if_fail"
    ),

    gayini_make_check_row(
      "post_frequency_requires_valid_years",
      post_frequency_without_valid == 0,
      paste0(post_frequency_without_valid, " pixels have frequency but no valid post years"),
      severity = "stop_if_fail"
    ),

    gayini_make_check_row(
      "plot_rows_match_clean_plots",
      n_plot_rows == n_expected_plots,
      paste0(n_plot_rows, " plot rows; expected ", n_expected_plots),
      severity = "stop_if_fail"
    ),

    gayini_make_check_row(
      "plot_pre_values_not_empty",
      n_plot_pre_values > 0,
      paste0(n_plot_pre_values, " plots have non-NA pre frequency values"),
      severity = "stop_if_fail"
    ),

    gayini_make_check_row(
      "plot_post_values_not_empty",
      n_plot_post_values > 0,
      paste0(n_plot_post_values, " plots have non-NA post frequency values"),
      severity = "stop_if_fail"
    ),

    gayini_make_check_row(
      "plot_diff_values_not_empty",
      n_plot_diff_values > 0,
      paste0(n_plot_diff_values, " plots have non-NA post-minus-pre values"),
      severity = "stop_if_fail"
    ),

    gayini_make_check_row(
      "plot_comparisons_available",
      n_plot_no_comparison < n_expected_plots,
      paste0(n_plot_no_comparison, " plots have no pre/post comparison"),
      severity = "stop_if_fail"
    ),

    gayini_make_check_row(
      "plot_pre_valid_years",
      n_plot_low_pre_valid == 0,
      paste0(n_plot_low_pre_valid, " plots have fewer than ", min_valid_years_pre, " valid pre years"),
      severity = "stop_if_fail"
    ),

    gayini_make_check_row(
      "plot_post_valid_years",
      n_plot_low_post_valid == 0,
      paste0(n_plot_low_post_valid, " plots have fewer than ", min_valid_years_post, " valid post years"),
      severity = "stop_if_fail"
    )
  )
}
