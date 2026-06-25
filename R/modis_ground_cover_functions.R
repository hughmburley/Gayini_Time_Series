## -----------------------------------------------------------------------------
## Gayini MODIS fractional-cover context functions
## -----------------------------------------------------------------------------


## Files in R/ define functions only. The Step 03 run script calls the top-level
## gayini_run_modis_ground_cover_context() function when RUN_MODIS_GC is TRUE.


## Catalogue helpers ----


gayini_infer_modis_fractional_cover_product <- function(file_path, file_name) {

  file_path_lower <- tolower(file_path)
  file_name_lower <- tolower(file_name)

  dplyr::case_when(
    grepl("modis_fractional_cover", file_path_lower) ~ "modis_fractional_cover",
    grepl("^fc\\.v[0-9]+\\.mcd43a4\\.a[0-9]{4}\\.[0-9]{2}\\.aust\\.[0-9]{3}\\.tif$", file_name_lower) ~ "modis_fractional_cover",
    TRUE ~ NA_character_
  )

}


gayini_standardise_modis_catalog <- function(raster_catalog,
                                             target_product = "modis_fractional_cover") {

  gayini_check_required_columns(
    raster_catalog,
    c("file_path", "file_name"),
    object_name = "raster_catalog"
  )

  output_catalog <- raster_catalog

  inferred_product <- gayini_infer_modis_fractional_cover_product(
    file_path = output_catalog$file_path,
    file_name = output_catalog$file_name
  )

  if (!"product" %in% names(output_catalog)) {
    output_catalog$product <- inferred_product
  } else {
    output_catalog$product <- dplyr::if_else(
      is.na(output_catalog$product) | output_catalog$product == "",
      inferred_product,
      as.character(output_catalog$product)
    )
  }

  if (!"read_status" %in% names(output_catalog)) {
    output_catalog$read_status <- "ok"
  }

  if (!"modis_version" %in% names(output_catalog)) {
    output_catalog$modis_version <- gayini_parse_modis_version(output_catalog$file_name)
  } else {
    output_catalog$modis_version <- dplyr::if_else(
      is.na(output_catalog$modis_version) | output_catalog$modis_version == "",
      gayini_parse_modis_version(output_catalog$file_name),
      as.character(output_catalog$modis_version)
    )
  }

  output_catalog |>
    dplyr::filter(.data$product == target_product, .data$read_status == "ok") |>
    dplyr::mutate(
      sensor = "modis",
      date_start = as.Date(.data$date_start),
      date_end = dplyr::if_else(is.na(as.Date(.data$date_end)), .data$date_start, as.Date(.data$date_end)),
      year = lubridate::year(.data$date_start),
      month = lubridate::month(.data$date_start),
      water_year = vapply(.data$date_start, gayini_make_water_year, character(1)),
      year_month = ifelse(is.na(.data$date_start), NA_character_, format(.data$date_start, "%Y-%m")),
      modis_version_rank = dplyr::case_when(
        .data$modis_version == "061" ~ 2L,
        .data$modis_version == "006" ~ 1L,
        TRUE ~ 0L
      )
    ) |>
    dplyr::group_by(.data$year_month) |>
    dplyr::mutate(duplicate_year_month = !is.na(.data$year_month) & dplyr::n() > 1) |>
    dplyr::ungroup() |>
    dplyr::arrange(.data$date_start, dplyr::desc(.data$modis_version_rank), .data$file_name) |>
    dplyr::distinct(.data$date_start, .keep_all = TRUE)

}


gayini_get_modis_catalog <- function(raster_catalog,
                                     run_mode = c("full", "test"),
                                     test_n = 3) {

  run_mode <- match.arg(run_mode)

  modis_catalog <- gayini_standardise_modis_catalog(raster_catalog)

  if (nrow(modis_catalog) == 0) {
    stop("No MODIS fractional-cover rows were found in the raster catalogue.", call. = FALSE)
  }

  bad_dates <- modis_catalog %>%
    dplyr::filter(is.na(.data$date_start))

  if (nrow(bad_dates) > 0) {
    stop("MODIS catalogue contains date parsing failures. Review modis_fractional_cover_catalog_checks.csv.", call. = FALSE)
  }

  bad_layers <- modis_catalog %>%
    dplyr::filter(!is.na(.data$n_layers), .data$n_layers != 3)

  if (nrow(bad_layers) > 0) {
    stop("MODIS catalogue contains rasters with n_layers != 3. Review catalogue diagnostics.", call. = FALSE)
  }

  if (run_mode == "test") {
    modis_catalog <- modis_catalog %>%
      dplyr::slice_head(n = test_n)
  }

  modis_catalog

}


## Band legend helpers ----


gayini_default_modis_band_lookup <- function() {

  tibble::tibble(
    band_number = 1:3,
    raw_name = c("bare_raw", "pv_raw", "npv_raw"),
    pct_name = c("bare_pct", "pv_pct", "npv_pct"),
    display_label = c("Bare soil", "Photosynthetic vegetation", "Non-photosynthetic vegetation"),
    units = "percent",
    nodata_value = 255,
    source = "Input/modis_fractional_cover/README.txt",
    confirmed = TRUE,
    notes = "Local MODIS README says three-band FC rasters use RGB order for Bare soil, PV and NPV."
  )

}


gayini_read_modis_band_lookup <- function(root = getwd()) {

  lookup_path <- gayini_path("config", "class_legends", "modis_fractional_cover_bands.csv", root = root)

  if (!file.exists(lookup_path)) {
    lookup <- gayini_default_modis_band_lookup()
    gayini_write_csv(lookup, lookup_path)
    return(lookup)
  }

  lookup <- readr::read_csv(lookup_path, show_col_types = FALSE)

  required_columns <- c("band_number", "raw_name", "pct_name", "display_label", "confirmed")

  if (!all(required_columns %in% names(lookup))) {
    warning(
      "MODIS fractional-cover band lookup is missing required columns. Using default bare/PV/NPV lookup.",
      call. = FALSE
    )

    return(gayini_default_modis_band_lookup())
  }

  lookup |>
    dplyr::mutate(
      band_number = as.integer(.data$band_number),
      raw_name = as.character(.data$raw_name),
      pct_name = as.character(.data$pct_name),
      confirmed = as.logical(.data$confirmed)
    ) |>
    dplyr::arrange(.data$band_number)

}


## Cache and cleaning helpers ----


gayini_make_modis_cache_path <- function(raster_row, cache_dir) {

  file.path(cache_dir, paste0(tools::file_path_sans_ext(raster_row$file_name[1]), "_gayini_aoi.tif"))

}


gayini_make_modis_aoi_cache_file <- function(source_file, cache_dir) {

  file.path(cache_dir, paste0(tools::file_path_sans_ext(basename(source_file)), "_gayini_aoi.tif"))

}


gayini_validate_modis_source_raster <- function(raster_path) {

  result <- tryCatch({
    raster <- terra::rast(raster_path)
    values <- terra::global(raster, fun = range, na.rm = TRUE)

    tibble::tibble(
      file_path = normalizePath(raster_path, winslash = "/", mustWork = FALSE),
      exists = file.exists(raster_path),
      file_size_mb = round(file.info(raster_path)$size / 1024^2, 3),
      n_layers = terra::nlyr(raster),
      n_cells = terra::ncell(raster),
      min_band1 = values[1, 1],
      max_band1 = values[1, 2],
      min_band2 = values[2, 1],
      max_band2 = values[2, 2],
      min_band3 = values[3, 1],
      max_band3 = values[3, 2],
      status = ifelse(terra::nlyr(raster) == 3, "pass", "fail"),
      issues = ifelse(terra::nlyr(raster) == 3, "none", "n_layers_not_3")
    )
  }, error = function(e) {
    tibble::tibble(
      file_path = normalizePath(raster_path, winslash = "/", mustWork = FALSE),
      exists = file.exists(raster_path),
      file_size_mb = ifelse(file.exists(raster_path), round(file.info(raster_path)$size / 1024^2, 3), NA_real_),
      n_layers = NA_integer_,
      n_cells = NA_real_,
      min_band1 = NA_real_,
      max_band1 = NA_real_,
      min_band2 = NA_real_,
      max_band2 = NA_real_,
      min_band3 = NA_real_,
      max_band3 = NA_real_,
      status = "fail",
      issues = paste("read_failed:", conditionMessage(e))
    )
  })

  result

}


gayini_validate_modis_aoi_cache <- function(cache_file) {

  result <- tryCatch({
    if (!file.exists(cache_file) || file.info(cache_file)$size <= 0) {
      stop("cache missing or empty", call. = FALSE)
    }

    raster <- terra::rast(cache_file)
    values <- terra::global(raster, fun = range, na.rm = TRUE)
    n_layers <- terra::nlyr(raster)
    n_cells <- terra::ncell(raster)
    valid <- n_layers == 3 && n_cells > 0

    tibble::tibble(
      cache_file = normalizePath(cache_file, winslash = "/", mustWork = FALSE),
      exists = TRUE,
      file_size_mb = round(file.info(cache_file)$size / 1024^2, 3),
      n_layers = n_layers,
      n_cells = n_cells,
      min_band1 = ifelse(n_layers >= 1, values[1, 1], NA_real_),
      max_band1 = ifelse(n_layers >= 1, values[1, 2], NA_real_),
      min_band2 = ifelse(n_layers >= 2, values[2, 1], NA_real_),
      max_band2 = ifelse(n_layers >= 2, values[2, 2], NA_real_),
      min_band3 = ifelse(n_layers >= 3, values[3, 1], NA_real_),
      max_band3 = ifelse(n_layers >= 3, values[3, 2], NA_real_),
      status = ifelse(valid, "pass", "fail"),
      issues = ifelse(valid, "none", "cache_invalid_shape")
    )
  }, error = function(e) {
    tibble::tibble(
      cache_file = normalizePath(cache_file, winslash = "/", mustWork = FALSE),
      exists = file.exists(cache_file),
      file_size_mb = ifelse(file.exists(cache_file), round(file.info(cache_file)$size / 1024^2, 3), NA_real_),
      n_layers = NA_integer_,
      n_cells = NA_real_,
      min_band1 = NA_real_,
      max_band1 = NA_real_,
      min_band2 = NA_real_,
      max_band2 = NA_real_,
      min_band3 = NA_real_,
      max_band3 = NA_real_,
      status = "fail",
      issues = paste("cache_read_failed:", conditionMessage(e))
    )
  })

  result

}


gayini_crop_modis_to_aoi <- function(raster_row,
                                     context_units,
                                     cache_dir,
                                     overwrite_cache = FALSE) {

  dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)

  raster_path <- raster_row$file_path[1]
  cache_path <- gayini_make_modis_cache_path(raster_row, cache_dir)

  if (file.exists(cache_path) && !isTRUE(overwrite_cache)) {
    cache_validation <- gayini_validate_modis_aoi_cache(cache_path)

    if (identical(cache_validation$status[1], "pass")) {
      return(tibble::tibble(
        file_path = raster_path,
        file_name = raster_row$file_name[1],
        date_start = as.Date(raster_row$date_start[1]),
        modis_version = raster_row$modis_version[1],
        cache_path = cache_path,
        cache_status = "pass",
        cache_action = "skipped_existing_valid",
        cache_file_size_mb = round(file.info(cache_path)$size / 1024^2, 3)
      ))
    }

    cache_action <- "rebuilt"
  } else if (file.exists(cache_path) && isTRUE(overwrite_cache)) {
    cache_action <- "rebuilt"
  } else {
    cache_action <- "created"
  }

  raster <- terra::rast(raster_path)

  if (terra::nlyr(raster) != 3) {
    stop("MODIS raster does not have 3 layers: ", raster_path, call. = FALSE)
  }

  context_for_raster <- context_units |>
    sf::st_transform(terra::crs(raster))

  aoi <- context_for_raster |>
    sf::st_union() |>
    sf::st_as_sf()

  aoi_vect <- terra::vect(aoi)

  raster_aoi <- raster |>
    terra::crop(aoi_vect) |>
    terra::mask(aoi_vect)

  if (terra::ncell(raster_aoi) == 0) {
    stop("MODIS AOI crop has zero cells for: ", raster_path, call. = FALSE)
  }

  names(raster_aoi) <- c("bare_raw", "pv_raw", "npv_raw")

  terra::writeRaster(
    raster_aoi,
    cache_path,
    overwrite = TRUE,
    datatype = "INT1U",
    NAflag = 255,
    gdal = c("COMPRESS=LZW", "TILED=YES")
  )

  cache_validation <- gayini_validate_modis_aoi_cache(cache_path)

  tibble::tibble(
    file_path = raster_path,
    file_name = raster_row$file_name[1],
    date_start = as.Date(raster_row$date_start[1]),
    modis_version = raster_row$modis_version[1],
    cache_path = cache_path,
    cache_status = cache_validation$status[1],
    cache_action = cache_action,
    cache_file_size_mb = round(file.info(cache_path)$size / 1024^2, 3)
  )

}


gayini_clean_modis_fractional_cover_values <- function(raster) {

  if (terra::nlyr(raster) != 3) {
    stop("MODIS fractional-cover raster must have exactly 3 layers.", call. = FALSE)
  }

  names(raster) <- c("bare_raw", "pv_raw", "npv_raw")

  cleaned <- terra::ifel(raster == 255 | raster > 100, NA, raster)
  names(cleaned) <- c("bare_pct", "pv_pct", "npv_pct")

  total_veg <- cleaned[["pv_pct"]] + cleaned[["npv_pct"]]
  names(total_veg) <- "total_veg_pct"

  c(cleaned, total_veg)

}


gayini_modis_valid_cell_count <- function(cleaned_raster) {

  valid_raster <- terra::ifel(
    is.na(cleaned_raster[["bare_pct"]]) |
      is.na(cleaned_raster[["pv_pct"]]) |
      is.na(cleaned_raster[["npv_pct"]]),
    NA,
    1
  )

  as.numeric(terra::global(valid_raster, "sum", na.rm = TRUE)[1, 1])

}


## exactextractr helpers ----


gayini_exact_weighted_mean <- function(values, coverage_fraction, weights) {

  area_weights <- coverage_fraction * weights
  valid <- !is.na(values) & !is.na(area_weights) & area_weights > 0

  if (!any(valid)) {
    return(NA_real_)
  }

  sum(values[valid] * area_weights[valid]) / sum(area_weights[valid])

}


gayini_exact_valid_support <- function(values, coverage_fraction, weights) {

  area_weights <- coverage_fraction * weights
  valid <- !is.na(values) & !is.na(area_weights) & area_weights > 0

  if (!any(valid)) {
    return(0)
  }

  sum(area_weights[valid], na.rm = TRUE)

}


gayini_extract_modis_metric <- function(raster_layer,
                                        context_units,
                                        cell_area_ha,
                                        metric_name) {

  extracted <- exactextractr::exact_extract(
    raster_layer,
    context_units,
    fun = function(values, coverage_fraction, weights) {
      gayini_exact_weighted_mean(values, coverage_fraction, weights)
    },
    weights = cell_area_ha,
    append_cols = c("unit_id", "unit_type", "area_ha", "effective_modis_pixel_estimate"),
    force_df = TRUE,
    progress = FALSE
  )

  if ("result" %in% names(extracted) && !metric_name %in% names(extracted)) {
    names(extracted)[names(extracted) == "result"] <- metric_name
  }

  extracted

}


gayini_extract_modis_area_metric <- function(raster_layer,
                                             context_units,
                                             cell_area_ha,
                                             metric_name) {

  extracted <- exactextractr::exact_extract(
    raster_layer,
    context_units,
    fun = gayini_exact_valid_support,
    weights = cell_area_ha,
    append_cols = c("unit_id", "unit_type", "area_ha", "effective_modis_pixel_estimate"),
    force_df = TRUE,
    progress = FALSE
  )

  if ("result" %in% names(extracted) && !metric_name %in% names(extracted)) {
    names(extracted)[names(extracted) == "result"] <- metric_name
  }

  extracted

}


gayini_extract_modis_valid_support <- function(valid_raster,
                                               context_units,
                                               cell_area_ha) {

  total_raster <- valid_raster
  terra::values(total_raster) <- 1

  valid_area <- gayini_extract_modis_area_metric(
    raster_layer = valid_raster,
    context_units = context_units,
    cell_area_ha = cell_area_ha,
    metric_name = "valid_area_ha"
  )

  total_area <- gayini_extract_modis_area_metric(
    raster_layer = total_raster,
    context_units = context_units,
    cell_area_ha = cell_area_ha,
    metric_name = "total_area_ha"
  ) |>
    dplyr::select(dplyr::all_of(c("unit_id", "total_area_ha")))

  valid_area |>
    dplyr::left_join(total_area, by = "unit_id")

}


## Extraction helpers ----


gayini_extract_modis_context_raster <- function(raster_row,
                                                context_units,
                                                cache_dir,
                                                overwrite_cache = FALSE) {

  cache_info <- gayini_crop_modis_to_aoi(
    raster_row = raster_row,
    context_units = context_units,
    cache_dir = cache_dir,
    overwrite_cache = overwrite_cache
  )

  cached_raster <- terra::rast(cache_info$cache_path[1])
  cleaned_raster <- gayini_clean_modis_fractional_cover_values(cached_raster)

  if (gayini_modis_valid_cell_count(cleaned_raster) <= 0) {
    stop("Cached MODIS AOI raster has no valid cells: ", cache_info$cache_path[1], call. = FALSE)
  }

  context_for_raster <- context_units |>
    sf::st_transform(terra::crs(cleaned_raster))

  cell_area_ha <- terra::cellSize(cleaned_raster[[1]], unit = "ha", mask = FALSE)

  bare <- gayini_extract_modis_metric(
    raster_layer = cleaned_raster[["bare_pct"]],
    context_units = context_for_raster,
    cell_area_ha = cell_area_ha,
    metric_name = "bare_pct"
  )

  pv <- gayini_extract_modis_metric(
    raster_layer = cleaned_raster[["pv_pct"]],
    context_units = context_for_raster,
    cell_area_ha = cell_area_ha,
    metric_name = "pv_pct"
  ) |>
    dplyr::select(dplyr::all_of(c("unit_id", "pv_pct")))

  npv <- gayini_extract_modis_metric(
    raster_layer = cleaned_raster[["npv_pct"]],
    context_units = context_for_raster,
    cell_area_ha = cell_area_ha,
    metric_name = "npv_pct"
  ) |>
    dplyr::select(dplyr::all_of(c("unit_id", "npv_pct")))

  total_veg <- gayini_extract_modis_metric(
    raster_layer = cleaned_raster[["total_veg_pct"]],
    context_units = context_for_raster,
    cell_area_ha = cell_area_ha,
    metric_name = "total_veg_pct"
  ) |>
    dplyr::select(dplyr::all_of(c("unit_id", "total_veg_pct")))

  valid_raster <- terra::ifel(
    is.na(cleaned_raster[["bare_pct"]]) |
      is.na(cleaned_raster[["pv_pct"]]) |
      is.na(cleaned_raster[["npv_pct"]]),
    NA,
    1
  )

  valid_support <- gayini_extract_modis_valid_support(
    valid_raster = valid_raster,
    context_units = context_for_raster,
    cell_area_ha = cell_area_ha
  ) |>
    dplyr::select(dplyr::all_of(c("unit_id", "valid_area_ha", "total_area_ha")))

  bare |>
    dplyr::left_join(pv, by = "unit_id") |>
    dplyr::left_join(npv, by = "unit_id") |>
    dplyr::left_join(total_veg, by = "unit_id") |>
    dplyr::left_join(valid_support, by = "unit_id") |>
    dplyr::mutate(
      date_start = as.Date(raster_row$date_start[1]),
      year = lubridate::year(.data$date_start),
      month = lubridate::month(.data$date_start),
      water_year = gayini_make_water_year(.data$date_start[1]),
      modis_version = raster_row$modis_version[1],
      valid_area_pct = dplyr::if_else(
        .data$total_area_ha > 0,
        100 * .data$valid_area_ha / .data$total_area_ha,
        NA_real_
      ),
      effective_modis_pixels = .data$valid_area_ha / 25,
      cache_file = cache_info$cache_path[1],
      cache_status = cache_info$cache_status[1],
      cache_action = cache_info$cache_action[1],
      source_file = raster_row$file_path[1]
    ) |>
    dplyr::select(
      unit_id,
      unit_type,
      date_start,
      year,
      month,
      water_year,
      modis_version,
      bare_pct,
      pv_pct,
      npv_pct,
      total_veg_pct,
      valid_area_pct,
      effective_modis_pixels,
      area_ha,
      effective_modis_pixel_estimate,
      valid_area_ha,
      total_area_ha,
      cache_file,
      cache_status,
      cache_action,
      source_file
    )

}


gayini_extract_modis_context_collection <- function(modis_catalog,
                                                    context_units,
                                                    cache_dir,
                                                    overwrite_cache = FALSE,
                                                    test_n = Inf) {

  if (is.finite(test_n)) {
    modis_catalog <- modis_catalog |>
      dplyr::slice_head(n = test_n)
  }

  if (nrow(modis_catalog) == 0) {
    stop("No MODIS files are available for extraction after catalogue standardisation.", call. = FALSE)
  }

  extraction_results <- vector("list", nrow(modis_catalog))

  for (i in seq_len(nrow(modis_catalog))) {
    message("Extracting MODIS context raster ", i, " of ", nrow(modis_catalog), ": ", modis_catalog$file_name[i])

    extraction_results[[i]] <- gayini_extract_modis_context_raster(
      raster_row = modis_catalog[i, , drop = FALSE],
      context_units = context_units,
      cache_dir = cache_dir,
      overwrite_cache = overwrite_cache
    )
  }

  dplyr::bind_rows(extraction_results)

}


## Diagnostics ----


gayini_make_modis_band_sum_checks <- function(modis_results) {

  gayini_check_required_columns(
    modis_results,
    c("unit_id", "date_start", "bare_pct", "pv_pct", "npv_pct", "total_veg_pct"),
    object_name = "modis_results"
  )

  modis_results |>
    dplyr::mutate(
      band_sum_pct = .data$bare_pct + .data$pv_pct + .data$npv_pct,
      band_sum_interpretation = dplyr::case_when(
        is.na(.data$band_sum_pct) ~ "missing",
        abs(.data$band_sum_pct - 100) <= 15 ~ "looks_like_percent_scale",
        .data$band_sum_pct < 0 | .data$band_sum_pct > 130 ~ "needs_review",
        TRUE ~ "moderate_departure_from_100"
      )
    ) |>
    dplyr::select(
      unit_id,
      unit_type,
      date_start,
      modis_version,
      bare_pct,
      pv_pct,
      npv_pct,
      total_veg_pct,
      band_sum_pct,
      band_sum_interpretation,
      valid_area_pct,
      effective_modis_pixels,
      source_file
    ) |>
    dplyr::arrange(.data$unit_id, .data$date_start)

}


gayini_make_modis_context_checks <- function(modis_results,
                                             modis_catalog,
                                             context_units,
                                             low_effective_pixel_threshold = 5) {

  pct_columns <- c("bare_pct", "pv_pct", "npv_pct", "total_veg_pct")

  duplicate_count <- modis_results |>
    dplyr::count(.data$unit_id, .data$date_start) |>
    dplyr::filter(.data$n > 1) |>
    nrow()

  out_of_range_count <- modis_results |>
    dplyr::select(dplyr::all_of(pct_columns)) |>
    tidyr::pivot_longer(dplyr::everything()) |>
    dplyr::filter(!is.na(.data$value), .data$value < 0 | .data$value > 100) |>
    nrow()

  low_effective_pixels <- sum(
    modis_results$effective_modis_pixels < low_effective_pixel_threshold,
    na.rm = TRUE
  )

  cache_missing_or_empty <- sum(
    !file.exists(modis_results$cache_file) |
      file.info(modis_results$cache_file)$size <= 0,
    na.rm = TRUE
  )

  dplyr::bind_rows(
    tibble::tibble(
      check_name = "modis_files_extracted",
      check_value = as.character(dplyr::n_distinct(modis_results$source_file)),
      status = ifelse(dplyr::n_distinct(modis_results$source_file) == nrow(modis_catalog), "pass", "fail"),
      notes = "All selected MODIS catalogue rows should be represented in the extraction output."
    ),
    tibble::tibble(
      check_name = "context_units_extracted",
      check_value = as.character(dplyr::n_distinct(modis_results$unit_id)),
      status = ifelse(dplyr::n_distinct(modis_results$unit_id) == nrow(context_units), "pass", "fail"),
      notes = "All MODIS context units should be represented for each selected raster."
    ),
    tibble::tibble(
      check_name = "duplicate_unit_date_rows",
      check_value = as.character(duplicate_count),
      status = ifelse(duplicate_count == 0, "pass", "fail"),
      notes = "Final MODIS context table should have one row per unit_id/date_start."
    ),
    tibble::tibble(
      check_name = "pct_values_outside_0_100",
      check_value = as.character(out_of_range_count),
      status = ifelse(out_of_range_count == 0, "pass", "fail"),
      notes = "Final percent fields should stay within 0-100 after invalid values are removed."
    ),
    tibble::tibble(
      check_name = "low_effective_modis_pixels",
      check_value = as.character(low_effective_pixels),
      status = ifelse(low_effective_pixels == 0, "pass", "warn"),
      notes = paste0("Rows below ", low_effective_pixel_threshold, " effective 500 m pixels should be interpreted cautiously.")
    ),
    tibble::tibble(
      check_name = "cache_files_missing_or_empty",
      check_value = as.character(cache_missing_or_empty),
      status = ifelse(cache_missing_or_empty == 0, "pass", "fail"),
      notes = "Every selected raster should have a non-empty cached AOI raster."
    ),
    tibble::tibble(
      check_name = "missing_valid_area_pct",
      check_value = as.character(sum(is.na(modis_results$valid_area_pct))),
      status = ifelse(any(is.na(modis_results$valid_area_pct)), "warn", "pass"),
      notes = "Missing valid_area_pct can indicate no valid cells or geometry/raster overlap problems."
    )
  )

}


gayini_add_modis_season_and_support <- function(modis_context_full) {

  modis_context_full %>%
    dplyr::mutate(
      season = dplyr::case_when(
        .data$month %in% c(12, 1, 2) ~ "summer",
        .data$month %in% c(3, 4, 5) ~ "autumn",
        .data$month %in% c(6, 7, 8) ~ "winter",
        .data$month %in% c(9, 10, 11) ~ "spring",
        TRUE ~ NA_character_
      ),
      support_class = dplyr::case_when(
        .data$effective_modis_pixels < 1 ~ "very_low_support",
        .data$effective_modis_pixels < 3 ~ "low_support",
        .data$effective_modis_pixels < 10 ~ "moderate_support",
        TRUE ~ "strong_support"
      )
    )

}


gayini_build_modis_monthly_timeseries <- function(modis_context_full) {

  modis_context_full %>%
    gayini_add_modis_season_and_support() %>%
    dplyr::arrange(.data$unit_type, .data$unit_id, .data$date_start)

}


gayini_summarise_modis_period <- function(data, grouping_columns) {

  if (nrow(data) == 0) {
    empty <- data[0, grouping_columns, drop = FALSE]
    empty$n_months <- integer(0)
    empty$bare_pct <- numeric(0)
    empty$pv_pct <- numeric(0)
    empty$npv_pct <- numeric(0)
    empty$total_veg_pct <- numeric(0)
    empty$valid_area_pct <- numeric(0)
    empty$valid_area_ha <- numeric(0)
    empty$total_area_ha <- numeric(0)
    empty$effective_modis_pixels <- numeric(0)
    empty$min_effective_modis_pixels <- numeric(0)
    empty$support_class <- character(0)
    return(tibble::as_tibble(empty))
  }

  data %>%
    dplyr::group_by(dplyr::across(dplyr::all_of(grouping_columns))) %>%
    dplyr::summarise(
      n_months = dplyr::n(),
      bare_pct = mean(.data$bare_pct, na.rm = TRUE),
      pv_pct = mean(.data$pv_pct, na.rm = TRUE),
      npv_pct = mean(.data$npv_pct, na.rm = TRUE),
      total_veg_pct = mean(.data$total_veg_pct, na.rm = TRUE),
      valid_area_pct = mean(.data$valid_area_pct, na.rm = TRUE),
      valid_area_ha = mean(.data$valid_area_ha, na.rm = TRUE),
      total_area_ha = mean(.data$total_area_ha, na.rm = TRUE),
      effective_modis_pixels = mean(.data$effective_modis_pixels, na.rm = TRUE),
      min_effective_modis_pixels = min(.data$effective_modis_pixels, na.rm = TRUE),
      support_class = dplyr::case_when(
        min_effective_modis_pixels < 1 ~ "very_low_support",
        min_effective_modis_pixels < 3 ~ "low_support",
        min_effective_modis_pixels < 10 ~ "moderate_support",
        TRUE ~ "strong_support"
      ),
      .groups = "drop"
    )

}


gayini_build_modis_seasonal_summary <- function(modis_monthly) {

  gayini_summarise_modis_period(
    modis_monthly,
    c("unit_id", "unit_type", "year", "season", "water_year")
  )

}


gayini_build_modis_water_year_summary <- function(modis_monthly) {

  gayini_summarise_modis_period(
    modis_monthly,
    c("unit_id", "unit_type", "water_year")
  )

}


gayini_build_modis_prepost_summary <- function(modis_monthly,
                                               pre_start_date = as.Date("2013-07-01"),
                                               conservation_date = as.Date("2019-07-01"),
                                               post_end_date = as.Date("2026-06-30")) {

  period_data <- modis_monthly %>%
    dplyr::mutate(
      period = dplyr::case_when(
        .data$date_start >= pre_start_date & .data$date_start < conservation_date ~ "pre_conservation",
        .data$date_start >= conservation_date & .data$date_start <= post_end_date ~ "post_conservation",
        TRUE ~ "outside_prepost_window"
      )
    ) %>%
    dplyr::filter(.data$period != "outside_prepost_window")

  period_summary <- gayini_summarise_modis_period(
    period_data,
    c("unit_id", "unit_type", "period")
  )

  period_wide <- period_summary %>%
    dplyr::select(dplyr::all_of(c(
      "unit_id",
      "unit_type",
      "period",
      "bare_pct",
      "pv_pct",
      "npv_pct",
      "total_veg_pct",
      "valid_area_pct",
      "effective_modis_pixels",
      "support_class"
    ))) %>%
    tidyr::pivot_wider(
      names_from = "period",
      values_from = c(
        "bare_pct",
        "pv_pct",
        "npv_pct",
        "total_veg_pct",
        "valid_area_pct",
        "effective_modis_pixels",
        "support_class"
      )
    )

  expected_prepost_columns <- c(
    "bare_pct_pre_conservation",
    "bare_pct_post_conservation",
    "pv_pct_pre_conservation",
    "pv_pct_post_conservation",
    "npv_pct_pre_conservation",
    "npv_pct_post_conservation",
    "total_veg_pct_pre_conservation",
    "total_veg_pct_post_conservation",
    "valid_area_pct_pre_conservation",
    "valid_area_pct_post_conservation",
    "effective_modis_pixels_pre_conservation",
    "effective_modis_pixels_post_conservation",
    "support_class_pre_conservation",
    "support_class_post_conservation"
  )

  for (column_name in expected_prepost_columns) {
    if (!column_name %in% names(period_wide)) {
      period_wide[[column_name]] <- NA
    }
  }

  period_wide %>%
    dplyr::mutate(
      bare_pct_post_minus_pre_points = .data$bare_pct_post_conservation - .data$bare_pct_pre_conservation,
      total_veg_pct_post_minus_pre_points = .data$total_veg_pct_post_conservation - .data$total_veg_pct_pre_conservation
    )

}


gayini_build_modis_management_zone_summary <- function(modis_monthly) {

  modis_monthly %>%
    dplyr::filter(.data$unit_type == "management_zone") %>%
    dplyr::group_by(.data$unit_id, .data$unit_type) %>%
    dplyr::summarise(
      n_months = dplyr::n(),
      mean_bare_pct = mean(.data$bare_pct, na.rm = TRUE),
      mean_total_veg_pct = mean(.data$total_veg_pct, na.rm = TRUE),
      mean_valid_area_pct = mean(.data$valid_area_pct, na.rm = TRUE),
      mean_effective_modis_pixels = mean(.data$effective_modis_pixels, na.rm = TRUE),
      min_effective_modis_pixels = min(.data$effective_modis_pixels, na.rm = TRUE),
      support_class = dplyr::case_when(
        min_effective_modis_pixels < 1 ~ "very_low_support",
        min_effective_modis_pixels < 3 ~ "low_support",
        min_effective_modis_pixels < 10 ~ "moderate_support",
        TRUE ~ "strong_support"
      ),
      interpretation_flag = dplyr::if_else(
        .data$support_class %in% c("very_low_support", "low_support"),
        "exploratory_low_modis_support",
        "exploratory_support_ok"
      ),
      .groups = "drop"
    ) %>%
    dplyr::arrange(.data$min_effective_modis_pixels, .data$unit_id)

}


gayini_make_modis_cache_checks <- function(modis_results,
                                           modis_catalog,
                                           cache_dir) {

  result_cache <- modis_results %>%
    dplyr::distinct(.data$source_file, .data$cache_file, .data$cache_status, .data$cache_action)

  modis_catalog %>%
    dplyr::mutate(
      source_file = .data$file_path,
      cache_file = gayini_make_modis_aoi_cache_file(.data$file_path, cache_dir)
    ) %>%
    dplyr::select(dplyr::all_of(c("source_file", "file_name", "date_start", "modis_version", "cache_file"))) %>%
    dplyr::left_join(result_cache, by = c("source_file", "cache_file")) %>%
    dplyr::rowwise() %>%
    dplyr::mutate(cache_validation = list(gayini_validate_modis_aoi_cache(.data$cache_file))) %>%
    dplyr::ungroup() %>%
    tidyr::unnest_wider("cache_validation", names_sep = "_") %>%
    dplyr::transmute(
      source_file = .data$source_file,
      cache_file = .data$cache_file,
      date_start = as.Date(.data$date_start),
      modis_version = .data$modis_version,
      status = .data$cache_validation_status,
      exists = .data$cache_validation_exists,
      file_size_mb = .data$cache_validation_file_size_mb,
      n_layers = .data$cache_validation_n_layers,
      n_cells = .data$cache_validation_n_cells,
      min_band1 = .data$cache_validation_min_band1,
      max_band1 = .data$cache_validation_max_band1,
      min_band2 = .data$cache_validation_min_band2,
      max_band2 = .data$cache_validation_max_band2,
      min_band3 = .data$cache_validation_min_band3,
      max_band3 = .data$cache_validation_max_band3,
      action_taken = dplyr::if_else(is.na(.data$cache_action), "not_processed", .data$cache_action),
      issues = .data$cache_validation_issues
    ) %>%
    dplyr::arrange(.data$date_start, .data$modis_version)

}


gayini_make_modis_effective_pixel_support <- function(modis_monthly) {

  modis_monthly %>%
    dplyr::group_by(.data$unit_id, .data$unit_type) %>%
    dplyr::summarise(
      n_months = dplyr::n(),
      min_effective_modis_pixels = min(.data$effective_modis_pixels, na.rm = TRUE),
      median_effective_modis_pixels = stats::median(.data$effective_modis_pixels, na.rm = TRUE),
      max_effective_modis_pixels = max(.data$effective_modis_pixels, na.rm = TRUE),
      support_class = dplyr::case_when(
        min_effective_modis_pixels < 1 ~ "very_low_support",
        min_effective_modis_pixels < 3 ~ "low_support",
        min_effective_modis_pixels < 10 ~ "moderate_support",
        TRUE ~ "strong_support"
      ),
      .groups = "drop"
    ) %>%
    dplyr::arrange(.data$min_effective_modis_pixels, .data$unit_id)

}


## Map and figure helpers ----


gayini_modis_cache_path_from_catalog <- function(modis_catalog, cache_dir) {

  gayini_make_modis_aoi_cache_file(modis_catalog$file_path, cache_dir)

}


gayini_select_modis_map_dates <- function(modis_catalog) {

  targets <- as.Date(c(
    min(modis_catalog$date_start, na.rm = TRUE),
    "2010-01-01",
    "2015-01-01",
    "2019-07-01",
    "2022-01-01",
    max(modis_catalog$date_start, na.rm = TRUE)
  ))

  selected <- lapply(targets, function(target_date) {
    modis_catalog[which.min(abs(as.numeric(modis_catalog$date_start - target_date))), , drop = FALSE]
  })

  dplyr::bind_rows(selected) %>%
    dplyr::distinct(.data$date_start, .keep_all = TRUE) %>%
    dplyr::arrange(.data$date_start)

}


gayini_clean_cached_modis_raster <- function(cache_file) {

  gayini_clean_modis_fractional_cover_values(terra::rast(cache_file))

}


gayini_save_modis_single_band_map <- function(raster_layer,
                                              out_file,
                                              title,
                                              legend_label = "Percent") {

  dir.create(dirname(out_file), recursive = TRUE, showWarnings = FALSE)

  grDevices::png(out_file, width = 1800, height = 1400, res = 180)
  terra::plot(
    raster_layer,
    col = grDevices::hcl.colors(40, "YlGnBu", rev = FALSE),
    main = title,
    plg = list(title = legend_label)
  )
  grDevices::dev.off()

  out_file

}


gayini_plot_modis_scale_context_map <- function(root,
                                                representative_cache_file,
                                                out_dir) {

  out_file <- file.path(out_dir, "modis_scale_context_map.png")
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

  raster <- terra::rast(representative_cache_file)[[1]]
  names(raster) <- "modis_pixel"
  raster_df <- terra::as.data.frame(raster, xy = TRUE, na.rm = FALSE)
  raster_res <- terra::res(raster)

  boundary_path <- gayini_path("data_intermediate", "spatial", "boundary_clean.gpkg", root = root)
  plots_path <- gayini_path("data_intermediate", "spatial", "plots_clean.gpkg", root = root)
  management_path <- gayini_path("data_intermediate", "spatial", "management_zones_clean.gpkg", root = root)

  boundary <- sf::st_read(boundary_path, quiet = TRUE) %>% sf::st_transform(terra::crs(raster))
  plots <- sf::st_read(plots_path, quiet = TRUE) %>% sf::st_transform(terra::crs(raster))
  management <- sf::st_read(management_path, quiet = TRUE) %>% sf::st_transform(terra::crs(raster))

  scale_plot <- ggplot2::ggplot() +
    ggplot2::geom_tile(
      data = raster_df,
      ggplot2::aes(x = .data$x, y = .data$y),
      width = raster_res[1],
      height = raster_res[2],
      fill = "grey80",
      colour = "grey55",
      alpha = 0.45,
      linewidth = 0.15
    ) +
    ggplot2::geom_sf(data = management, fill = NA, colour = "grey35", linewidth = 0.2) +
    ggplot2::geom_sf(data = plots, fill = NA, colour = "#7B1FA2", linewidth = 0.25) +
    ggplot2::geom_sf(data = boundary, fill = NA, colour = "black", linewidth = 0.8) +
    ggplot2::coord_sf(expand = FALSE) +
    ggplot2::labs(
      title = "MODIS context scale at Gayini",
      subtitle = "MODIS fractional cover is used as farm, buffer and management-zone context only; purple outlines show 1 ha plots for scale.",
      x = NULL,
      y = NULL
    ) +
    ggplot2::theme_minimal(base_family = "Arial")

  ggplot2::ggsave(out_file, scale_plot, width = 9, height = 7, dpi = 300)

  out_file

}


gayini_mean_cached_modis_layer <- function(modis_catalog,
                                           cache_dir,
                                           layer_name,
                                           start_date,
                                           end_date) {

  period_catalog <- modis_catalog %>%
    dplyr::filter(.data$date_start >= start_date, .data$date_start <= end_date) %>%
    dplyr::mutate(cache_file = gayini_modis_cache_path_from_catalog(., cache_dir)) %>%
    dplyr::filter(file.exists(.data$cache_file))

  if (nrow(period_catalog) == 0) {
    return(NULL)
  }

  sum_raster <- NULL
  count_raster <- NULL

  for (cache_file in period_catalog$cache_file) {
    layer <- gayini_clean_cached_modis_raster(cache_file)[[layer_name]]
    valid <- terra::ifel(is.na(layer), 0, 1)
    layer_zeroed <- terra::ifel(is.na(layer), 0, layer)

    if (is.null(sum_raster)) {
      sum_raster <- layer_zeroed
      count_raster <- valid
    } else {
      sum_raster <- sum_raster + layer_zeroed
      count_raster <- count_raster + valid
    }
  }

  mean_raster <- sum_raster / count_raster
  mean_raster <- terra::ifel(count_raster == 0, NA, mean_raster)
  names(mean_raster) <- layer_name
  mean_raster

}


gayini_plot_modis_map_set <- function(modis_catalog,
                                      root,
                                      cache_dir,
                                      out_dir = gayini_path("Output", "maps", "modis_ground_cover", root = root),
                                      pre_start_date = as.Date("2013-07-01"),
                                      conservation_date = as.Date("2019-07-01"),
                                      post_end_date = as.Date("2026-06-30")) {

  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

  selected_catalog <- gayini_select_modis_map_dates(modis_catalog) %>%
    dplyr::mutate(cache_file = gayini_modis_cache_path_from_catalog(., cache_dir)) %>%
    dplyr::filter(file.exists(.data$cache_file))

  map_paths <- character(0)

  if (nrow(selected_catalog) > 0) {
    map_paths <- c(
      map_paths,
      gayini_plot_modis_scale_context_map(
        root = root,
        representative_cache_file = selected_catalog$cache_file[1],
        out_dir = out_dir
      )
    )
  }

  for (i in seq_len(nrow(selected_catalog))) {
    row <- selected_catalog[i, , drop = FALSE]
    date_label <- format(row$date_start[1], "%Y_%m")
    raster <- terra::rast(row$cache_file[1])
    names(raster) <- c("bare_raw", "pv_raw", "npv_raw")

    rgb_file <- file.path(out_dir, paste0("modis_rgb_", date_label, ".png"))
    grDevices::png(rgb_file, width = 1800, height = 1400, res = 180)
    terra::plotRGB(
      raster,
      r = 1,
      g = 2,
      b = 3,
      scale = 100,
      stretch = "lin",
      main = paste0("MODIS RGB fractional cover: ", format(row$date_start[1], "%Y-%m"), " (R=bare, G=PV, B=NPV)")
    )
    grDevices::dev.off()
    map_paths <- c(map_paths, rgb_file)

    cleaned <- gayini_clean_modis_fractional_cover_values(raster)

    for (layer_name in c("bare_pct", "pv_pct", "npv_pct", "total_veg_pct")) {
      map_paths <- c(
        map_paths,
        gayini_save_modis_single_band_map(
          raster_layer = cleaned[[layer_name]],
          out_file = file.path(out_dir, paste0("modis_", layer_name, "_", date_label, ".png")),
          title = paste0("MODIS ", layer_name, ": ", format(row$date_start[1], "%Y-%m")),
          legend_label = "Percent"
        )
      )
    }
  }

  pre_total <- gayini_mean_cached_modis_layer(modis_catalog, cache_dir, "total_veg_pct", pre_start_date, conservation_date - 1)
  post_total <- gayini_mean_cached_modis_layer(modis_catalog, cache_dir, "total_veg_pct", conservation_date, post_end_date)
  pre_bare <- gayini_mean_cached_modis_layer(modis_catalog, cache_dir, "bare_pct", pre_start_date, conservation_date - 1)
  post_bare <- gayini_mean_cached_modis_layer(modis_catalog, cache_dir, "bare_pct", conservation_date, post_end_date)

  if (!is.null(pre_total)) {
    map_paths <- c(map_paths, gayini_save_modis_single_band_map(pre_total, file.path(out_dir, "modis_pre_mean_total_veg_pct.png"), "MODIS pre-conservation mean total vegetation", "Percent"))
  }
  if (!is.null(post_total)) {
    map_paths <- c(map_paths, gayini_save_modis_single_band_map(post_total, file.path(out_dir, "modis_post_mean_total_veg_pct.png"), "MODIS post-conservation mean total vegetation", "Percent"))
  }
  if (!is.null(pre_total) && !is.null(post_total)) {
    diff_total <- post_total - pre_total
    names(diff_total) <- "post_minus_pre_total_veg_pct_points"
    map_paths <- c(map_paths, gayini_save_modis_single_band_map(diff_total, file.path(out_dir, "modis_post_minus_pre_total_veg_pct_points.png"), "MODIS post minus pre total vegetation", "Percentage points"))
  }
  if (!is.null(pre_bare)) {
    map_paths <- c(map_paths, gayini_save_modis_single_band_map(pre_bare, file.path(out_dir, "modis_pre_mean_bare_pct.png"), "MODIS pre-conservation mean bare ground", "Percent"))
  }
  if (!is.null(post_bare)) {
    map_paths <- c(map_paths, gayini_save_modis_single_band_map(post_bare, file.path(out_dir, "modis_post_mean_bare_pct.png"), "MODIS post-conservation mean bare ground", "Percent"))
  }
  if (!is.null(pre_bare) && !is.null(post_bare)) {
    diff_bare <- post_bare - pre_bare
    names(diff_bare) <- "post_minus_pre_bare_pct_points"
    map_paths <- c(map_paths, gayini_save_modis_single_band_map(diff_bare, file.path(out_dir, "modis_post_minus_pre_bare_pct_points.png"), "MODIS post minus pre bare ground", "Percentage points"))
  }

  tibble::tibble(output_type = "map", path = map_paths)

}


gayini_plot_modis_timeseries_set <- function(modis_monthly,
                                             water_year_summary,
                                             prepost_summary,
                                             management_zone_summary,
                                             out_dir) {

  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

  figure_paths <- character(0)
  farm_buffer_types <- c("farm", "farm_buffer_5km", "farm_buffer_10km")

  farm_long <- modis_monthly %>%
    dplyr::filter(.data$unit_type == "farm") %>%
    dplyr::select(dplyr::all_of(c("date_start", "bare_pct", "pv_pct", "npv_pct", "total_veg_pct"))) %>%
    tidyr::pivot_longer(cols = -date_start, names_to = "metric", values_to = "pct")

  p <- ggplot2::ggplot(farm_long, ggplot2::aes(x = .data$date_start, y = .data$pct, colour = .data$metric)) +
    ggplot2::geom_vline(xintercept = as.Date("2019-07-01"), linetype = "dashed", colour = "grey35") +
    ggplot2::geom_line(linewidth = 0.35, na.rm = TRUE) +
    ggplot2::labs(title = "MODIS whole-farm monthly fractional cover", subtitle = "Values are monthly broad-scale fractional-cover summaries.", x = NULL, y = "Percent", colour = NULL) +
    ggplot2::theme_minimal(base_family = "Arial")
  path <- file.path(out_dir, "modis_whole_farm_monthly_timeseries.png")
  ggplot2::ggsave(path, p, width = 11, height = 6, dpi = 300)
  figure_paths <- c(figure_paths, path)

  for (metric in c("total_veg_pct", "bare_pct")) {
    metric_data <- modis_monthly %>%
      dplyr::filter(.data$unit_type %in% farm_buffer_types)

    p <- ggplot2::ggplot(metric_data, ggplot2::aes(x = .data$date_start, y = .data[[metric]], colour = .data$unit_type)) +
      ggplot2::geom_vline(xintercept = as.Date("2019-07-01"), linetype = "dashed", colour = "grey35") +
      ggplot2::geom_line(linewidth = 0.35, na.rm = TRUE) +
      ggplot2::labs(title = paste("MODIS farm vs buffer", gsub("_", " ", metric)), subtitle = "MODIS fractional cover is used as farm, buffer and management-zone context only.", x = NULL, y = "Percent", colour = NULL) +
      ggplot2::theme_minimal(base_family = "Arial")

    file_stub <- ifelse(metric == "total_veg_pct", "modis_farm_vs_buffer_total_veg_timeseries.png", "modis_farm_vs_buffer_bare_ground_timeseries.png")
    path <- file.path(out_dir, file_stub)
    ggplot2::ggsave(path, p, width = 11, height = 6, dpi = 300)
    figure_paths <- c(figure_paths, path)
  }

  for (metric in c("total_veg_pct", "bare_pct")) {
    summary_data <- water_year_summary %>%
      dplyr::filter(.data$unit_type %in% farm_buffer_types)

    p <- ggplot2::ggplot(summary_data, ggplot2::aes(x = .data$water_year, y = .data[[metric]], fill = .data$unit_type)) +
      ggplot2::geom_col(position = "dodge") +
      ggplot2::coord_cartesian(ylim = c(0, NA)) +
      ggplot2::labs(title = paste("MODIS water-year", gsub("_", " ", metric)), x = "Water year", y = "Mean percent", fill = NULL) +
      ggplot2::theme_minimal(base_family = "Arial") +
      ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 45, hjust = 1))

    file_stub <- ifelse(metric == "total_veg_pct", "modis_water_year_total_veg_summary.png", "modis_water_year_bare_ground_summary.png")
    path <- file.path(out_dir, file_stub)
    ggplot2::ggsave(path, p, width = 12, height = 6.5, dpi = 300)
    figure_paths <- c(figure_paths, path)
  }

  p <- ggplot2::ggplot(management_zone_summary, ggplot2::aes(x = stats::reorder(.data$unit_id, .data$min_effective_modis_pixels), y = .data$min_effective_modis_pixels, fill = .data$support_class)) +
    ggplot2::geom_col() +
    ggplot2::coord_flip() +
    ggplot2::labs(title = "MODIS management-zone pixel support", subtitle = "Management-zone results are exploratory and should be interpreted with MODIS pixel-support flags.", x = NULL, y = "Minimum effective MODIS pixels", fill = NULL) +
    ggplot2::theme_minimal(base_family = "Arial")
  path <- file.path(out_dir, "modis_management_zone_support.png")
  ggplot2::ggsave(path, p, width = 9, height = 12, dpi = 300)
  figure_paths <- c(figure_paths, path)

  selected_zones <- management_zone_summary %>%
    dplyr::filter(.data$support_class == "strong_support") %>%
    dplyr::arrange(dplyr::desc(.data$mean_effective_modis_pixels)) %>%
    dplyr::slice_head(n = 8) %>%
    dplyr::pull(.data$unit_id)

  zone_data <- modis_monthly %>%
    dplyr::filter(.data$unit_id %in% selected_zones)

  if (nrow(zone_data) > 0) {
    p <- ggplot2::ggplot(zone_data, ggplot2::aes(x = .data$date_start, y = .data$total_veg_pct, colour = .data$unit_id)) +
      ggplot2::geom_vline(xintercept = as.Date("2019-07-01"), linetype = "dashed", colour = "grey35") +
      ggplot2::geom_line(linewidth = 0.35, na.rm = TRUE) +
      ggplot2::labs(title = "Selected high-support MODIS management zones", subtitle = "Exploratory context only; Landsat remains the core plot-scale ground-cover product.", x = NULL, y = "Total vegetation (%)", colour = NULL) +
      ggplot2::theme_minimal(base_family = "Arial")
    path <- file.path(out_dir, "modis_selected_management_zone_timeseries.png")
    ggplot2::ggsave(path, p, width = 11, height = 6, dpi = 300)
    figure_paths <- c(figure_paths, path)
  }

  prepost_plot_data <- prepost_summary %>%
    dplyr::filter(.data$unit_type %in% farm_buffer_types) %>%
    dplyr::select(dplyr::all_of(c("unit_id", "unit_type", "bare_pct_pre_conservation", "bare_pct_post_conservation", "total_veg_pct_pre_conservation", "total_veg_pct_post_conservation"))) %>%
    tidyr::pivot_longer(cols = -c(unit_id, unit_type), names_to = "metric_period", values_to = "pct") %>%
    dplyr::mutate(
      metric = dplyr::if_else(grepl("^bare", .data$metric_period), "bare_pct", "total_veg_pct"),
      period = dplyr::if_else(grepl("pre_conservation", .data$metric_period), "pre_conservation", "post_conservation")
    )

  if (nrow(prepost_plot_data) > 0 && any(!is.na(prepost_plot_data$pct))) {
    p <- ggplot2::ggplot(prepost_plot_data, ggplot2::aes(x = .data$unit_type, y = .data$pct, fill = .data$period)) +
      ggplot2::geom_col(position = "dodge") +
      ggplot2::facet_wrap(~ metric) +
      ggplot2::labs(title = "MODIS pre/post context summary", subtitle = "Post-minus-pre values are percentage points.", x = NULL, y = "Mean percent", fill = NULL) +
      ggplot2::theme_minimal(base_family = "Arial")
    path <- file.path(out_dir, "modis_period_summary_prepost.png")
    ggplot2::ggsave(path, p, width = 10, height = 6, dpi = 300)
    figure_paths <- c(figure_paths, path)
  }

  tibble::tibble(output_type = "figure", path = figure_paths)

}


gayini_make_modis_results_ppt <- function(root,
                                          output_path = gayini_path("Output", "reports", "Gayini_MODIS_results_review.pptx", root = root),
                                          fallback_outline_path = gayini_path("Output", "reports", "Gayini_MODIS_results_review_slide_outline.md", root = root),
                                          modis_summary = NULL,
                                          map_paths = character(),
                                          figure_paths = character()) {

  dir.create(dirname(fallback_outline_path), recursive = TRUE, showWarnings = FALSE)

  outline <- c(
    "# Gayini MODIS results review",
    "",
    "## Slide 1. Title",
    "Gayini MODIS ground-cover context — review draft.",
    "",
    "## Slide 2. What MODIS adds",
    "MODIS fractional cover is used as farm, buffer and management-zone context only. MODIS is not interpreted at the 1 ha plot scale.",
    "",
    "## Slide 3. Data and processing",
    paste0("MODIS files processed: ", ifelse(is.null(modis_summary), "see diagnostics", modis_summary$n_modis_rasters)),
    paste0("Context units: ", ifelse(is.null(modis_summary), "see diagnostics", modis_summary$n_context_units)),
    "",
    "## Slide 4. Scale context",
    "Use Output/figures/maps/modis_ground_cover/modis_scale_context_map.png.",
    "",
    "## Slide 5. Representative MODIS maps",
    "Use selected RGB and single-band maps from Output/figures/maps/modis_ground_cover/.",
    "",
    "## Slide 6. Whole-farm time series",
    "Use Output/figures/modis_ground_cover/modis_whole_farm_monthly_timeseries.png.",
    "",
    "## Slide 7. Farm vs buffer context",
    "Use total vegetation and bare ground farm-vs-buffer figures.",
    "",
    "## Slide 8. Water-year and pre/post context",
    "Use water-year summaries and modis_period_summary_prepost.png.",
    "",
    "## Slide 9. Management-zone exploratory results",
    "Use support ranking and selected strong-support zone examples. Management-zone results are exploratory and should be interpreted with MODIS pixel-support flags.",
    "",
    "## Slide 10. Interpretation and next decisions",
    "MODIS supports landscape context. Landsat remains the core plot-scale ground-cover product. Decide which MODIS figures should go into the main August deck."
  )

  writeLines(outline, fallback_outline_path, useBytes = TRUE)

  tibble::tibble(
    ppt_path = ifelse(file.exists(output_path), output_path, NA_character_),
    fallback_outline_path = fallback_outline_path,
    status = ifelse(file.exists(output_path), "ppt_exists", "fallback_outline_written"),
    notes = "PPTX is generated outside R with the presentation artifact tool when available; this outline is the workflow fallback."
  )

}


## Phase 3 communication refinement helpers ----


gayini_phase3_paths <- function(root = getwd()) {

  list(
    monthly_path = gayini_path("data_processed", "modis_ground_cover_context_timeseries.csv", root = root),
    context_full_path = gayini_path("Output", "csv", "03_modis_ground_cover_context_full.csv", root = root),
    map_dir = gayini_path("Output", "figures", "maps", "modis_ground_cover", root = root),
    figure_dir = gayini_path("Output", "figures", "modis_ground_cover", root = root),
    diagnostics_dir = gayini_path("Output", "diagnostics", "modis_ground_cover", root = root),
    boundary_path = gayini_path("data_intermediate", "spatial", "boundary_clean.gpkg", root = root),
    management_path = gayini_path("data_intermediate", "spatial", "management_zones_clean.gpkg", root = root),
    plots_path = gayini_path("data_intermediate", "spatial", "plots_clean.gpkg", root = root)
  )

}


gayini_read_modis_phase3_inputs <- function(root = getwd()) {

  paths <- gayini_phase3_paths(root)
  gayini_stop_if_missing(paths$monthly_path, "MODIS monthly timeseries")
  gayini_stop_if_missing(paths$boundary_path, "clean Gayini boundary")
  gayini_stop_if_missing(paths$management_path, "clean management zones")

  monthly <- readr::read_csv(paths$monthly_path, show_col_types = FALSE) %>%
    dplyr::mutate(
      date_start = as.Date(.data$date_start),
      year = as.integer(.data$year),
      month = as.integer(.data$month)
    )

  list(
    monthly = monthly,
    boundary = sf::st_read(paths$boundary_path, quiet = TRUE),
    management = sf::st_read(paths$management_path, quiet = TRUE),
    plots = if (file.exists(paths$plots_path)) sf::st_read(paths$plots_path, quiet = TRUE) else NULL,
    paths = paths
  )

}


gayini_select_modis_representative_months <- function(modis_monthly,
                                                      conservation_date = as.Date("2019-07-01")) {

  farm <- modis_monthly %>%
    dplyr::filter(.data$unit_id == "gayini_farm") %>%
    dplyr::arrange(.data$date_start)

  select_one <- function(data, label, reason) {
    data %>%
      dplyr::slice(1) %>%
      dplyr::transmute(
        selection_label = label,
        date_start = .data$date_start,
        bare_pct = .data$bare_pct,
        pv_pct = .data$pv_pct,
        npv_pct = .data$npv_pct,
        total_veg_pct = .data$total_veg_pct,
        cache_file = .data$cache_file,
        selection_reason = reason
      )
  }

  dplyr::bind_rows(
    select_one(farm %>% dplyr::arrange(.data$total_veg_pct), "lowest_total_vegetation", "Whole-farm month with lowest total vegetation."),
    select_one(farm %>% dplyr::arrange(dplyr::desc(.data$total_veg_pct)), "highest_total_vegetation", "Whole-farm month with highest total vegetation."),
    select_one(farm %>% dplyr::arrange(dplyr::desc(.data$bare_pct)), "highest_bare_ground", "Whole-farm month with highest bare ground."),
    select_one(farm %>% dplyr::arrange(.data$bare_pct), "lowest_bare_ground", "Whole-farm month with lowest bare ground."),
    select_one(farm %>% dplyr::filter(.data$date_start < conservation_date) %>% dplyr::arrange(abs(as.numeric(.data$date_start - conservation_date))), "pre_boundary_month", "Pre-2019 month closest to management-change boundary."),
    select_one(farm %>% dplyr::filter(.data$date_start >= conservation_date) %>% dplyr::arrange(dplyr::desc(.data$total_veg_pct)), "post_wet_green_month", "Post-2019 wet/green month with high total vegetation.")
  ) %>%
    dplyr::distinct(.data$selection_label, .keep_all = TRUE)

}


gayini_get_modis_overlay_layers <- function(raster, boundary, management, plots = NULL) {

  raster_crs <- terra::crs(raster)

  list(
    boundary = sf::st_transform(boundary, raster_crs),
    management = sf::st_transform(management, raster_crs),
    plots = if (!is.null(plots)) sf::st_transform(plots, raster_crs) else NULL
  )

}


gayini_add_modis_overlays_base <- function(layers,
                                           include_plots = FALSE,
                                           management_col = "grey70",
                                           boundary_col = "grey10") {

  plot(sf::st_geometry(layers$management), add = TRUE, border = management_col, lwd = 0.45)

  if (isTRUE(include_plots) && !is.null(layers$plots)) {
    plot(sf::st_geometry(layers$plots), add = TRUE, border = "#7B1FA2", lwd = 0.45)
  }

  plot(sf::st_geometry(layers$boundary), add = TRUE, border = boundary_col, lwd = 2)

}


gayini_plot_refined_modis_single_map <- function(raster_layer,
                                                 out_file,
                                                 title,
                                                 subtitle = "MODIS context only",
                                                 legend_label = "Percent cover",
                                                 zlim = NULL,
                                                 palette = grDevices::hcl.colors(50, "YlGnBu", rev = FALSE),
                                                 boundary,
                                                 management,
                                                 diverging = FALSE) {

  dir.create(dirname(out_file), recursive = TRUE, showWarnings = FALSE)
  layers <- gayini_get_modis_overlay_layers(raster_layer, boundary, management)

  grDevices::png(out_file, width = 1800, height = 1400, res = 180)

  if (isTRUE(diverging)) {
    terra::plot(
      raster_layer,
      col = palette,
      range = zlim,
      plg = list(title = legend_label),
      main = paste0(title, "\n", subtitle)
    )
  } else {
    terra::plot(
      raster_layer,
      col = palette,
      range = zlim,
      plg = list(title = legend_label),
      main = paste0(title, "\n", subtitle)
    )
  }

  gayini_add_modis_overlays_base(layers)
  grDevices::dev.off()

  out_file

}


gayini_plot_refined_modis_rgb_map <- function(cache_file,
                                              out_file,
                                              title,
                                              boundary,
                                              management) {

  dir.create(dirname(out_file), recursive = TRUE, showWarnings = FALSE)
  raster <- terra::rast(cache_file)
  names(raster) <- c("bare_raw", "pv_raw", "npv_raw")
  layers <- gayini_get_modis_overlay_layers(raster, boundary, management)

  grDevices::png(out_file, width = 1800, height = 1400, res = 180)
  old_par <- graphics::par(no.readonly = TRUE)
  graphics::par(mar = c(1, 1, 6, 1))
  terra::plotRGB(
    raster,
    r = 1,
    g = 2,
    b = 3,
    scale = 100,
    stretch = "lin",
    main = NULL
  )
  graphics::mtext(title, side = 3, line = 4.1, cex = 1.1, font = 2)
  graphics::mtext("MODIS context only; RGB = bare ground / PV / NPV", side = 3, line = 2.6, cex = 0.95, font = 2)
  gayini_add_modis_overlays_base(layers)
  graphics::par(old_par)
  grDevices::dev.off()

  out_file

}


gayini_plot_refined_modis_scale_context_map <- function(root,
                                                        representative_cache_file,
                                                        boundary,
                                                        management,
                                                        plots,
                                                        out_file) {

  raster <- terra::rast(representative_cache_file)[[1]]
  raster_res <- terra::res(raster)
  raster_df <- terra::as.data.frame(raster, xy = TRUE, na.rm = FALSE)

  boundary_r <- sf::st_transform(boundary, terra::crs(raster))
  management_r <- sf::st_transform(management, terra::crs(raster))
  plots_r <- sf::st_transform(plots, terra::crs(raster))

  scale_plot <- ggplot2::ggplot() +
    ggplot2::geom_tile(
      data = raster_df,
      ggplot2::aes(x = .data$x, y = .data$y),
      width = raster_res[1],
      height = raster_res[2],
      fill = "grey82",
      colour = "grey55",
      alpha = 0.45,
      linewidth = 0.15
    ) +
    ggplot2::geom_sf(data = management_r, fill = NA, colour = "grey70", linewidth = 0.25) +
    ggplot2::geom_sf(data = plots_r, fill = NA, colour = "#7B1FA2", linewidth = 0.25) +
    ggplot2::geom_sf(data = boundary_r, fill = NA, colour = "grey10", linewidth = 0.9) +
    ggplot2::coord_sf(expand = FALSE) +
    ggplot2::labs(
      title = "MODIS scale context at Gayini",
      subtitle = "MODIS context only; purple outlines show 1 ha plots only to communicate scale mismatch.",
      x = NULL,
      y = NULL
    ) +
    ggplot2::theme_minimal(base_family = "Arial") +
    ggplot2::theme(
      plot.title = ggplot2::element_text(face = "bold"),
      plot.subtitle = ggplot2::element_text(colour = "grey30")
    )

  ggplot2::ggsave(out_file, scale_plot, width = 9, height = 7, dpi = 300)

  out_file

}


gayini_mean_cached_modis_layer_from_cache_catalog <- function(cache_catalog,
                                                             layer_name,
                                                             start_date,
                                                             end_date) {

  period_catalog <- cache_catalog %>%
    dplyr::filter(.data$date_start >= start_date, .data$date_start <= end_date) %>%
    dplyr::filter(file.exists(.data$cache_file))

  if (nrow(period_catalog) == 0) {
    return(NULL)
  }

  sum_raster <- NULL
  count_raster <- NULL

  for (cache_file in period_catalog$cache_file) {
    layer <- gayini_clean_cached_modis_raster(cache_file)[[layer_name]]
    valid <- terra::ifel(is.na(layer), 0, 1)
    layer_zeroed <- terra::ifel(is.na(layer), 0, layer)

    if (is.null(sum_raster)) {
      sum_raster <- layer_zeroed
      count_raster <- valid
    } else {
      sum_raster <- sum_raster + layer_zeroed
      count_raster <- count_raster + valid
    }
  }

  mean_raster <- sum_raster / count_raster
  mean_raster <- terra::ifel(count_raster == 0, NA, mean_raster)
  names(mean_raster) <- layer_name
  mean_raster

}


gayini_write_modis_phase3_refined_maps <- function(root = getwd(),
                                                   inputs,
                                                   representative_months,
                                                   pre_start_date = as.Date("2013-07-01"),
                                                   conservation_date = as.Date("2019-07-01"),
                                                   post_end_date = as.Date("2026-06-30")) {

  paths <- inputs$paths
  dir.create(paths$map_dir, recursive = TRUE, showWarnings = FALSE)

  monthly <- inputs$monthly
  cache_catalog <- monthly %>%
    dplyr::distinct(.data$date_start, .data$cache_file) %>%
    dplyr::arrange(.data$date_start)

  pre_total <- gayini_mean_cached_modis_layer_from_cache_catalog(cache_catalog, "total_veg_pct", pre_start_date, conservation_date - 1)
  post_total <- gayini_mean_cached_modis_layer_from_cache_catalog(cache_catalog, "total_veg_pct", conservation_date, post_end_date)
  pre_bare <- gayini_mean_cached_modis_layer_from_cache_catalog(cache_catalog, "bare_pct", pre_start_date, conservation_date - 1)
  post_bare <- gayini_mean_cached_modis_layer_from_cache_catalog(cache_catalog, "bare_pct", conservation_date, post_end_date)

  total_range <- range(c(terra::values(pre_total), terra::values(post_total)), na.rm = TRUE)
  bare_range <- range(c(terra::values(pre_bare), terra::values(post_bare)), na.rm = TRUE)
  total_diff <- post_total - pre_total
  bare_diff <- post_bare - pre_bare
  diff_range <- max(abs(c(terra::values(total_diff), terra::values(bare_diff))), na.rm = TRUE)
  diff_range <- max(diff_range, 1)

  dry_row <- representative_months %>%
    dplyr::filter(.data$selection_label == "highest_bare_ground") %>%
    dplyr::slice(1)
  wet_row <- representative_months %>%
    dplyr::filter(.data$selection_label == "highest_total_vegetation") %>%
    dplyr::slice(1)

  map_paths <- c(
    gayini_plot_refined_modis_scale_context_map(
      root = root,
      representative_cache_file = dry_row$cache_file[1],
      boundary = inputs$boundary,
      management = inputs$management,
      plots = inputs$plots,
      out_file = file.path(paths$map_dir, "modis_scale_context_map_refined.png")
    ),
    gayini_plot_refined_modis_rgb_map(
      cache_file = dry_row$cache_file[1],
      out_file = file.path(paths$map_dir, "modis_rgb_representative_dry_month.png"),
      title = paste0("Representative dry MODIS month: ", dry_row$date_start[1]),
      boundary = inputs$boundary,
      management = inputs$management
    ),
    gayini_plot_refined_modis_rgb_map(
      cache_file = wet_row$cache_file[1],
      out_file = file.path(paths$map_dir, "modis_rgb_representative_wet_month.png"),
      title = paste0("Representative wet/green MODIS month: ", wet_row$date_start[1]),
      boundary = inputs$boundary,
      management = inputs$management
    ),
    gayini_plot_refined_modis_single_map(pre_total, file.path(paths$map_dir, "modis_pre_mean_total_veg_pct_refined.png"), "Pre-conservation mean total vegetation", "MODIS context only; percent cover", "Percent cover", total_range, boundary = inputs$boundary, management = inputs$management),
    gayini_plot_refined_modis_single_map(post_total, file.path(paths$map_dir, "modis_post_mean_total_veg_pct_refined.png"), "Post-conservation mean total vegetation", "MODIS context only; percent cover", "Percent cover", total_range, boundary = inputs$boundary, management = inputs$management),
    gayini_plot_refined_modis_single_map(total_diff, file.path(paths$map_dir, "modis_post_minus_pre_total_veg_pct_points_refined.png"), "Post minus pre total vegetation", "MODIS context only; percentage points", "Percentage points", c(-diff_range, diff_range), grDevices::hcl.colors(51, "Blue-Red 3"), inputs$boundary, inputs$management, TRUE),
    gayini_plot_refined_modis_single_map(pre_bare, file.path(paths$map_dir, "modis_pre_mean_bare_pct_refined.png"), "Pre-conservation mean bare ground", "MODIS context only; percent cover", "Percent cover", bare_range, boundary = inputs$boundary, management = inputs$management),
    gayini_plot_refined_modis_single_map(post_bare, file.path(paths$map_dir, "modis_post_mean_bare_pct_refined.png"), "Post-conservation mean bare ground", "MODIS context only; percent cover", "Percent cover", bare_range, boundary = inputs$boundary, management = inputs$management),
    gayini_plot_refined_modis_single_map(bare_diff, file.path(paths$map_dir, "modis_post_minus_pre_bare_pct_points_refined.png"), "Post minus pre bare ground", "MODIS context only; percentage points", "Percentage points", c(-diff_range, diff_range), grDevices::hcl.colors(51, "Blue-Red 3"), inputs$boundary, inputs$management, TRUE)
  )

  tibble::tibble(asset_type = "map", path = map_paths)

}


gayini_make_modis_monthly_anomalies <- function(monthly) {

  climatology <- monthly %>%
    dplyr::filter(.data$unit_id %in% c("gayini_farm", "gayini_buffer_5km", "gayini_buffer_10km")) %>%
    dplyr::group_by(.data$unit_id, .data$month) %>%
    dplyr::summarise(
      bare_climatology = mean(.data$bare_pct, na.rm = TRUE),
      total_veg_climatology = mean(.data$total_veg_pct, na.rm = TRUE),
      .groups = "drop"
    )

  monthly %>%
    dplyr::filter(.data$unit_id %in% c("gayini_farm", "gayini_buffer_5km", "gayini_buffer_10km")) %>%
    dplyr::left_join(climatology, by = c("unit_id", "month")) %>%
    dplyr::mutate(
      bare_anomaly_points = .data$bare_pct - .data$bare_climatology,
      total_veg_anomaly_points = .data$total_veg_pct - .data$total_veg_climatology
    )

}


gayini_write_modis_phase3_refined_timeseries <- function(inputs,
                                                         conservation_date = as.Date("2019-07-01")) {

  paths <- inputs$paths
  dir.create(paths$figure_dir, recursive = TRUE, showWarnings = FALSE)

  monthly <- inputs$monthly
  farm <- monthly %>% dplyr::filter(.data$unit_id == "gayini_farm")

  water_year_farm <- farm %>%
    dplyr::group_by(.data$water_year) %>%
    dplyr::summarise(
      total_veg_pct = mean(.data$total_veg_pct, na.rm = TRUE),
      bare_pct = mean(.data$bare_pct, na.rm = TRUE),
      water_year_start = as.Date(paste0(substr(.data$water_year[1], 1, 4), "-07-01")),
      .groups = "drop"
    ) %>%
    tidyr::pivot_longer(c("total_veg_pct", "bare_pct"), names_to = "metric", values_to = "pct")

  water_year_end_date <- max(water_year_farm$water_year_start, na.rm = TRUE)
  monthly_end_date <- max(monthly$date_start, na.rm = TRUE)

  p1 <- ggplot2::ggplot(water_year_farm, ggplot2::aes(x = .data$water_year_start, y = .data$pct, colour = .data$metric)) +
    ggplot2::annotate("rect", xmin = conservation_date, xmax = water_year_end_date, ymin = -Inf, ymax = Inf, fill = "grey85", alpha = 0.35) +
    ggplot2::geom_line(linewidth = 0.8, na.rm = TRUE) +
    ggplot2::geom_point(size = 1.7, na.rm = TRUE) +
    ggplot2::annotate("segment", x = conservation_date, xend = conservation_date, y = -Inf, yend = Inf, linetype = "dashed") +
    ggplot2::scale_colour_manual(values = c(bare_pct = "#A4513F", total_veg_pct = "#2E6B4E"), labels = c(bare_pct = "Bare ground", total_veg_pct = "Total vegetation")) +
    ggplot2::labs(
      title = "MODIS whole-farm water-year context",
      subtitle = "MODIS context only; July-June means, percent cover.",
      x = NULL,
      y = "Percent cover",
      colour = NULL
    ) +
    ggplot2::theme_minimal(base_family = "Arial")
  p1_path <- file.path(paths$figure_dir, "modis_whole_farm_total_veg_bare_water_year_refined.png")
  ggplot2::ggsave(p1_path, p1, width = 10, height = 6, dpi = 300)

  anomalies <- gayini_make_modis_monthly_anomalies(monthly)
  farm_anomaly <- anomalies %>%
    dplyr::filter(.data$unit_id == "gayini_farm") %>%
    dplyr::select("date_start", "total_veg_anomaly_points", "bare_anomaly_points") %>%
    tidyr::pivot_longer(c("total_veg_anomaly_points", "bare_anomaly_points"), names_to = "metric", values_to = "anomaly_points")

  p2 <- ggplot2::ggplot(farm_anomaly, ggplot2::aes(x = .data$date_start, y = .data$anomaly_points, colour = .data$metric)) +
    ggplot2::annotate("rect", xmin = conservation_date, xmax = monthly_end_date, ymin = -Inf, ymax = Inf, fill = "grey85", alpha = 0.35) +
    ggplot2::geom_hline(yintercept = 0, linewidth = 0.3) +
    ggplot2::geom_line(linewidth = 0.45, na.rm = TRUE) +
    ggplot2::annotate("segment", x = conservation_date, xend = conservation_date, y = -Inf, yend = Inf, linetype = "dashed") +
    ggplot2::scale_colour_manual(values = c(bare_anomaly_points = "#A4513F", total_veg_anomaly_points = "#2E6B4E"), labels = c(bare_anomaly_points = "Bare ground anomaly", total_veg_anomaly_points = "Total vegetation anomaly")) +
    ggplot2::labs(
      title = "MODIS whole-farm monthly anomaly",
      subtitle = "MODIS context only; anomaly is relative to each calendar month's long-term mean.",
      x = NULL,
      y = "Percentage-point anomaly",
      colour = NULL
    ) +
    ggplot2::theme_minimal(base_family = "Arial")
  p2_path <- file.path(paths$figure_dir, "modis_whole_farm_monthly_anomaly_refined.png")
  ggplot2::ggsave(p2_path, p2, width = 11, height = 6, dpi = 300)

  farm_anom <- anomalies %>%
    dplyr::filter(.data$unit_id == "gayini_farm") %>%
    dplyr::select("date_start", farm_total_veg_anomaly = "total_veg_anomaly_points", farm_bare_anomaly = "bare_anomaly_points")

  buffer_anom <- anomalies %>%
    dplyr::filter(.data$unit_id %in% c("gayini_buffer_5km", "gayini_buffer_10km")) %>%
    dplyr::select("date_start", "unit_id", "total_veg_anomaly_points", "bare_anomaly_points") %>%
    dplyr::left_join(farm_anom, by = "date_start") %>%
    dplyr::mutate(
      farm_minus_buffer_total_veg_anomaly = .data$farm_total_veg_anomaly - .data$total_veg_anomaly_points,
      farm_minus_buffer_bare_anomaly = .data$farm_bare_anomaly - .data$bare_anomaly_points,
      buffer_label = dplyr::recode(
        .data$unit_id,
        gayini_buffer_5km = "5 km buffer",
        gayini_buffer_10km = "10 km buffer"
      )
    )

  p3 <- ggplot2::ggplot(buffer_anom, ggplot2::aes(x = .data$date_start, y = .data$farm_minus_buffer_total_veg_anomaly, colour = .data$buffer_label)) +
    ggplot2::annotate("rect", xmin = conservation_date, xmax = monthly_end_date, ymin = -Inf, ymax = Inf, fill = "grey85", alpha = 0.35) +
    ggplot2::geom_hline(yintercept = 0, linewidth = 0.3) +
    ggplot2::geom_line(linewidth = 0.45, na.rm = TRUE) +
    ggplot2::annotate("segment", x = conservation_date, xend = conservation_date, y = -Inf, yend = Inf, linetype = "dashed") +
    ggplot2::labs(
      title = "MODIS farm-minus-buffer total vegetation anomaly",
      subtitle = "MODIS context only; positive values mean farm anomaly exceeds buffer anomaly.",
      x = NULL,
      y = "Percentage-point anomaly difference",
      colour = NULL
    ) +
    ggplot2::theme_minimal(base_family = "Arial")
  p3_path <- file.path(paths$figure_dir, "modis_farm_minus_buffer_total_veg_anomaly.png")
  ggplot2::ggsave(p3_path, p3, width = 11, height = 6, dpi = 300)

  p4 <- ggplot2::ggplot(buffer_anom, ggplot2::aes(x = .data$date_start, y = .data$farm_minus_buffer_bare_anomaly, colour = .data$buffer_label)) +
    ggplot2::annotate("rect", xmin = conservation_date, xmax = monthly_end_date, ymin = -Inf, ymax = Inf, fill = "grey85", alpha = 0.35) +
    ggplot2::geom_hline(yintercept = 0, linewidth = 0.3) +
    ggplot2::geom_line(linewidth = 0.45, na.rm = TRUE) +
    ggplot2::annotate("segment", x = conservation_date, xend = conservation_date, y = -Inf, yend = Inf, linetype = "dashed") +
    ggplot2::labs(
      title = "MODIS farm-minus-buffer bare-ground anomaly",
      subtitle = "MODIS context only; positive values mean farm bare anomaly exceeds buffer anomaly.",
      x = NULL,
      y = "Percentage-point anomaly difference",
      colour = NULL
    ) +
    ggplot2::theme_minimal(base_family = "Arial")
  p4_path <- file.path(paths$figure_dir, "modis_farm_minus_buffer_bare_anomaly.png")
  ggplot2::ggsave(p4_path, p4, width = 11, height = 6, dpi = 300)

  tibble::tibble(
    asset_type = "figure",
    path = c(p1_path, p2_path, p3_path, p4_path)
  )

}


gayini_write_modis_phase3_management_assets <- function(inputs,
                                                        conservation_date = as.Date("2019-07-01")) {

  paths <- inputs$paths
  monthly <- inputs$monthly

  prepost <- gayini_build_modis_prepost_summary(monthly)

  zone_support <- monthly %>%
    dplyr::filter(.data$unit_type == "management_zone") %>%
    dplyr::group_by(.data$unit_id) %>%
    dplyr::summarise(
      mean_effective_modis_pixels = mean(.data$effective_modis_pixels, na.rm = TRUE),
      min_effective_modis_pixels = min(.data$effective_modis_pixels, na.rm = TRUE),
      support_class = dplyr::case_when(
        min_effective_modis_pixels < 1 ~ "very_low_support",
        min_effective_modis_pixels < 3 ~ "low_support",
        min_effective_modis_pixels < 10 ~ "moderate_support",
        TRUE ~ "strong_support"
      ),
      .groups = "drop"
    )

  zone_change <- prepost %>%
    dplyr::filter(.data$unit_type == "management_zone") %>%
    dplyr::select("unit_id", "total_veg_pct_post_minus_pre_points", "bare_pct_post_minus_pre_points")

  selected_zones <- zone_support %>%
    dplyr::left_join(zone_change, by = "unit_id") %>%
    dplyr::mutate(
      abs_total_veg_change = abs(.data$total_veg_pct_post_minus_pre_points),
      abs_bare_change = abs(.data$bare_pct_post_minus_pre_points),
      selected_reason = dplyr::case_when(
        dplyr::row_number(dplyr::desc(.data$mean_effective_modis_pixels)) <= 10 ~ "top_effective_pixel_support",
        .data$support_class == "strong_support" & .data$abs_total_veg_change >= stats::quantile(.data$abs_total_veg_change, 0.9, na.rm = TRUE) ~ "strong_support_high_total_veg_change",
        .data$support_class == "strong_support" & .data$abs_bare_change >= stats::quantile(.data$abs_bare_change, 0.9, na.rm = TRUE) ~ "strong_support_high_bare_change",
        TRUE ~ NA_character_
      )
    ) %>%
    dplyr::filter(!is.na(.data$selected_reason)) %>%
    dplyr::arrange(dplyr::desc(.data$mean_effective_modis_pixels)) %>%
    dplyr::slice_head(n = 12) %>%
    dplyr::mutate(
      zone_label = sub("^management_zone_", "Zone ", .data$unit_id),
      support_label = dplyr::recode(
        .data$support_class,
        very_low_support = "Very low support",
        low_support = "Low support",
        moderate_support = "Moderate support",
        strong_support = "Strong support"
      )
    )

  register_path <- file.path(paths$diagnostics_dir, "modis_selected_management_zone_register.csv")
  gayini_write_csv(selected_zones, register_path)

  p1 <- ggplot2::ggplot(selected_zones, ggplot2::aes(x = stats::reorder(.data$zone_label, .data$mean_effective_modis_pixels), y = .data$mean_effective_modis_pixels, fill = .data$support_label)) +
    ggplot2::geom_col() +
    ggplot2::geom_text(ggplot2::aes(label = .data$support_label), hjust = -0.05, size = 3) +
    ggplot2::coord_flip(clip = "off") +
    ggplot2::labs(
      title = "Selected MODIS management-zone support",
      subtitle = "MODIS context only; selected zones have the strongest support and/or strong pre/post change.",
      x = NULL,
      y = "Mean effective MODIS pixels",
      fill = "Support class"
    ) +
    ggplot2::scale_fill_manual(
      values = c("Low support" = "#F8766D", "Moderate support" = "#00BA38", "Strong support" = "#619CFF"),
      drop = FALSE
    ) +
    ggplot2::theme_minimal(base_family = "Arial") +
    ggplot2::theme(plot.margin = ggplot2::margin(8, 60, 8, 8))
  support_path <- file.path(paths$figure_dir, "modis_management_zone_support_simplified.png")
  ggplot2::ggsave(support_path, p1, width = 10, height = 6, dpi = 300)

  zone_ts <- monthly %>%
    dplyr::filter(.data$unit_id %in% selected_zones$unit_id)

  monthly_end_date <- max(monthly$date_start, na.rm = TRUE)

  p2 <- ggplot2::ggplot(zone_ts, ggplot2::aes(x = .data$date_start, y = .data$total_veg_pct, colour = .data$unit_id)) +
    ggplot2::annotate("rect", xmin = conservation_date, xmax = monthly_end_date, ymin = -Inf, ymax = Inf, fill = "grey85", alpha = 0.35) +
    ggplot2::geom_line(linewidth = 0.35, na.rm = TRUE) +
    ggplot2::annotate("segment", x = conservation_date, xend = conservation_date, y = -Inf, yend = Inf, linetype = "dashed") +
    ggplot2::labs(
      title = "Selected MODIS management-zone total vegetation",
      subtitle = "MODIS context only; management-zone results are exploratory and support-flagged.",
      x = NULL,
      y = "Total vegetation (%)",
      colour = NULL
    ) +
    ggplot2::theme_minimal(base_family = "Arial")
  ts_path <- file.path(paths$figure_dir, "modis_selected_management_zone_timeseries_refined.png")
  ggplot2::ggsave(ts_path, p2, width = 11, height = 6, dpi = 300)

  tibble::tibble(
    asset_type = "figure",
    path = c(support_path, ts_path)
  )

}


gayini_write_modis_phase3_asset_manifest <- function(asset_rows, diagnostics_dir) {

  manifest_path <- file.path(diagnostics_dir, "modis_phase3_asset_manifest.csv")

  lookup <- tibble::tribble(
    ~path_stub, ~figure_title, ~recommended_slide, ~main_deck_candidate, ~notes,
    "modis_scale_context_map_refined.png", "MODIS scale context at Gayini", "Scale caveat / methods", TRUE, "Use to keep MODIS interpretation at context scale.",
    "modis_whole_farm_total_veg_bare_water_year_refined.png", "Whole-farm MODIS water-year context", "Landscape context before Landsat/hydrology results", TRUE, "Simple annual context figure.",
    "modis_farm_minus_buffer_total_veg_anomaly.png", "Farm-minus-buffer total vegetation anomaly", "Does Gayini track regional context?", TRUE, "Directly links farm to regional buffer context.",
    "modis_post_minus_pre_total_veg_pct_points_refined.png", "Post minus pre total vegetation", "Pre/post landscape context", TRUE, "Percentage-point map; context only.",
    "modis_post_minus_pre_bare_pct_points_refined.png", "Post minus pre bare ground", "Pre/post bare-ground context", TRUE, "Percentage-point map; context only.",
    "modis_rgb_representative_dry_month.png", "Representative dry MODIS RGB month", "MODIS companion deck map examples", FALSE, "Data-driven dry month selection.",
    "modis_rgb_representative_wet_month.png", "Representative wet MODIS RGB month", "MODIS companion deck map examples", FALSE, "Data-driven wet/green month selection.",
    "modis_whole_farm_monthly_anomaly_refined.png", "Whole-farm monthly MODIS anomaly", "MODIS companion time-series detail", FALSE, "Monthly anomaly relative to climatology.",
    "modis_farm_minus_buffer_bare_anomaly.png", "Farm-minus-buffer bare-ground anomaly", "MODIS companion buffer context", FALSE, "Useful companion to total vegetation anomaly.",
    "modis_management_zone_support_simplified.png", "Selected management-zone support", "Management-zone caution slide", FALSE, "Use to explain support flags.",
    "modis_selected_management_zone_timeseries_refined.png", "Selected management-zone time series", "Exploratory management-zone context", FALSE, "Do not overinterpret low-support zones."
  )

  manifest <- asset_rows %>%
    dplyr::mutate(path_stub = basename(.data$path)) %>%
    dplyr::left_join(lookup, by = "path_stub") %>%
    dplyr::mutate(
      figure_title = dplyr::if_else(is.na(.data$figure_title), tools::file_path_sans_ext(.data$path_stub), .data$figure_title),
      recommended_slide = dplyr::if_else(is.na(.data$recommended_slide), "MODIS companion deck", .data$recommended_slide),
      main_deck_candidate = dplyr::if_else(is.na(.data$main_deck_candidate), FALSE, .data$main_deck_candidate),
      notes = dplyr::if_else(is.na(.data$notes), "Refined MODIS context asset.", .data$notes)
    ) %>%
    dplyr::select("asset_type", "path", "figure_title", "recommended_slide", "main_deck_candidate", "notes") %>%
    dplyr::arrange(dplyr::desc(.data$main_deck_candidate), .data$asset_type, .data$figure_title)

  gayini_write_csv(manifest, manifest_path)

  manifest

}


gayini_run_modis_phase3_asset_refinement <- function(root = getwd()) {

  inputs <- gayini_read_modis_phase3_inputs(root)
  paths <- inputs$paths
  dir.create(paths$diagnostics_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(paths$map_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(paths$figure_dir, recursive = TRUE, showWarnings = FALSE)

  representative_months <- gayini_select_modis_representative_months(inputs$monthly)
  rep_path <- file.path(paths$diagnostics_dir, "modis_representative_month_selection.csv")
  gayini_write_csv(
    representative_months %>%
      dplyr::select("selection_label", "date_start", "bare_pct", "pv_pct", "npv_pct", "total_veg_pct", "selection_reason"),
    rep_path
  )

  map_assets <- gayini_write_modis_phase3_refined_maps(
    root = root,
    inputs = inputs,
    representative_months = representative_months
  )

  timeseries_assets <- gayini_write_modis_phase3_refined_timeseries(inputs)
  management_assets <- gayini_write_modis_phase3_management_assets(inputs)

  asset_manifest <- gayini_write_modis_phase3_asset_manifest(
    dplyr::bind_rows(map_assets, timeseries_assets, management_assets),
    diagnostics_dir = paths$diagnostics_dir
  )

  qa_checks <- tibble::tibble(
    check_name = c(
      "pct_values_outside_0_100",
      "representative_months_written",
      "asset_manifest_rows",
      "main_deck_candidate_count"
    ),
    check_value = c(
      as.character(sum(inputs$monthly$bare_pct < 0 | inputs$monthly$bare_pct > 100 | inputs$monthly$total_veg_pct < 0 | inputs$monthly$total_veg_pct > 100, na.rm = TRUE)),
      as.character(nrow(representative_months)),
      as.character(nrow(asset_manifest)),
      as.character(sum(asset_manifest$main_deck_candidate))
    ),
    status = c(
      ifelse(any(inputs$monthly$bare_pct < 0 | inputs$monthly$bare_pct > 100 | inputs$monthly$total_veg_pct < 0 | inputs$monthly$total_veg_pct > 100, na.rm = TRUE), "fail", "pass"),
      ifelse(nrow(representative_months) >= 6, "pass", "warn"),
      ifelse(nrow(asset_manifest) > 0, "pass", "fail"),
      ifelse(sum(asset_manifest$main_deck_candidate) >= 3 & sum(asset_manifest$main_deck_candidate) <= 5, "pass", "warn")
    ),
    notes = c(
      "Final plotted percent-cover source values should stay within 0-100.",
      "Representative month selections are data-driven from whole-farm monthly values.",
      "Every refined asset should be recorded in the asset manifest.",
      "Main deck should use only the best 3-5 MODIS assets."
    )
  )

  qa_path <- file.path(paths$diagnostics_dir, "modis_phase3_qa_checks.csv")
  gayini_write_csv(qa_checks, qa_path)

  message("MODIS Phase 3 refinement complete.")
  message("Representative month CSV: ", rep_path)
  message("Asset manifest rows: ", nrow(asset_manifest))
  message("Main deck candidates: ", sum(asset_manifest$main_deck_candidate))

  invisible(list(
    representative_months = representative_months,
    asset_manifest = asset_manifest,
    qa_checks = qa_checks
  ))

}


## Top-level workflow ----


gayini_run_modis_ground_cover_context <- function(root = getwd(),
                                                  crop_to_aoi = TRUE,
                                                  overwrite_cache = FALSE,
                                                  run_mode = c("full", "test"),
                                                  test_n = 3,
                                                  write_maps = TRUE,
                                                  write_figures = TRUE,
                                                  write_ppt = TRUE) {

  run_mode <- match.arg(run_mode)

  raster_catalog_path <- gayini_path("data_intermediate", "raster_catalog", "raster_catalog.csv", root = root)
  context_units_path <- gayini_path("data_intermediate", "spatial", "modis_context_units_clean.gpkg", root = root)
  cache_dir <- gayini_path("data_intermediate", "extraction_cache", "modis_aoi", root = root)

  full_output_path <- gayini_path("Output", "csv", "03_modis_ground_cover_context_full.csv", root = root)
  processed_output_path <- gayini_path("data_processed", "modis_ground_cover_context_timeseries.csv", root = root)
  checks_path <- gayini_path("Output", "diagnostics", "03_modis_ground_cover_context_checks.csv", root = root)
  band_sum_checks_path <- gayini_path("Output", "diagnostics", "03_modis_ground_cover_band_sum_checks.csv", root = root)
  effective_pixel_support_path <- gayini_path("Output", "diagnostics", "03_modis_ground_cover_effective_pixel_support.csv", root = root)
  cache_checks_path <- gayini_path("Output", "diagnostics", "03_modis_ground_cover_cache_checks.csv", root = root)
  monthly_summary_path <- gayini_path("Output", "csv", "03_modis_ground_cover_monthly_farm_buffer_summary.csv", root = root)
  water_year_summary_path <- gayini_path("Output", "csv", "03_modis_ground_cover_water_year_summary.csv", root = root)
  seasonal_summary_path <- gayini_path("Output", "csv", "03_modis_ground_cover_seasonal_summary.csv", root = root)
  prepost_summary_path <- gayini_path("Output", "csv", "03_modis_ground_cover_prepost_summary.csv", root = root)
  management_zone_summary_path <- gayini_path("Output", "csv", "03_modis_ground_cover_management_zone_summary.csv", root = root)
  map_paths_path <- gayini_path("Output", "diagnostics", "03_modis_ground_cover_map_paths.csv", root = root)
  figure_paths_path <- gayini_path("Output", "diagnostics", "03_modis_ground_cover_figure_paths.csv", root = root)
  run_log_path <- gayini_path("Output", "logs", paste0("03_modis_ground_cover_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".txt"), root = root)

  gayini_stop_if_missing(raster_catalog_path, label = "raster catalogue")
  gayini_stop_if_missing(context_units_path, label = "MODIS context unit file")

  invisible(gayini_read_modis_band_lookup(root = root))

  raster_catalog <- readr::read_csv(raster_catalog_path, show_col_types = FALSE)
  context_units <- sf::st_read(context_units_path, quiet = TRUE)

  modis_catalog <- gayini_get_modis_catalog(
    raster_catalog = raster_catalog,
    run_mode = run_mode,
    test_n = test_n
  )

  if (nrow(modis_catalog) == 0) {
    stop("No MODIS fractional-cover files were detected and RUN_MODIS_GC is TRUE.", call. = FALSE)
  }

  if (any(is.na(modis_catalog$date_start))) {
    stop("At least one MODIS file has a date parsing failure. Review raster catalogue diagnostics.", call. = FALSE)
  }

  if ("n_layers" %in% names(modis_catalog) && any(modis_catalog$n_layers != 3, na.rm = TRUE)) {
    stop("At least one MODIS file does not have 3 layers. Review MODIS catalogue diagnostics.", call. = FALSE)
  }

  if (!isTRUE(crop_to_aoi)) {
    warning("crop_to_aoi = FALSE is not recommended for Australia-wide MODIS inputs; continuing with AOI cache anyway.", call. = FALSE)
  }

  modis_results <- gayini_extract_modis_context_collection(
    modis_catalog = modis_catalog,
    context_units = context_units,
    cache_dir = cache_dir,
    overwrite_cache = overwrite_cache,
    test_n = Inf
  )

  modis_monthly <- gayini_build_modis_monthly_timeseries(modis_results)
  monthly_farm_buffer <- modis_monthly %>%
    dplyr::filter(.data$unit_type %in% c("farm", "farm_buffer_5km", "farm_buffer_10km"))
  seasonal_summary <- gayini_build_modis_seasonal_summary(modis_monthly)
  water_year_summary <- gayini_build_modis_water_year_summary(modis_monthly)
  prepost_summary <- gayini_build_modis_prepost_summary(modis_monthly)
  management_zone_summary <- gayini_build_modis_management_zone_summary(modis_monthly)
  effective_pixel_support <- gayini_make_modis_effective_pixel_support(modis_monthly)
  cache_checks <- gayini_make_modis_cache_checks(
    modis_results = modis_results,
    modis_catalog = modis_catalog,
    cache_dir = cache_dir
  )
  band_sum_checks <- gayini_make_modis_band_sum_checks(modis_results)
  context_checks <- gayini_make_modis_context_checks(
    modis_results = modis_results,
    modis_catalog = modis_catalog,
    context_units = context_units
  )

  expected_rows <- nrow(modis_catalog) * nrow(context_units)

  context_checks <- dplyr::bind_rows(
    context_checks,
    tibble::tibble(
      check_name = "expected_row_count",
      check_value = paste0(nrow(modis_results), " / ", expected_rows),
      status = ifelse(nrow(modis_results) == expected_rows, "pass", "fail"),
      notes = "Expected rows are n selected MODIS rasters x n MODIS context units."
    ),
    tibble::tibble(
      check_name = "one_ha_plot_units_absent",
      check_value = as.character(sum(modis_results$unit_type %in% c("plot", "hectare_plot", "one_ha_plot"))),
      status = ifelse(any(modis_results$unit_type %in% c("plot", "hectare_plot", "one_ha_plot")), "fail", "pass"),
      notes = "MODIS must not be interpreted at the 1 ha plot scale."
    )
  )

  gayini_write_csv(modis_results, full_output_path)
  gayini_write_csv(modis_monthly, processed_output_path)
  gayini_write_csv(context_checks, checks_path)
  gayini_write_csv(band_sum_checks, band_sum_checks_path)
  gayini_write_csv(effective_pixel_support, effective_pixel_support_path)
  gayini_write_csv(cache_checks, cache_checks_path)
  gayini_write_csv(monthly_farm_buffer, monthly_summary_path)
  gayini_write_csv(water_year_summary, water_year_summary_path)
  gayini_write_csv(seasonal_summary, seasonal_summary_path)
  gayini_write_csv(prepost_summary, prepost_summary_path)
  gayini_write_csv(management_zone_summary, management_zone_summary_path)

  map_paths <- tibble::tibble(output_type = character(), path = character())
  figure_paths <- tibble::tibble(output_type = character(), path = character())

  if (isTRUE(write_maps)) {
    map_paths <- gayini_plot_modis_map_set(
      modis_catalog = modis_catalog,
      root = root,
      cache_dir = cache_dir
    )
    gayini_write_csv(map_paths, map_paths_path)
  }

  if (isTRUE(write_figures)) {
    figure_paths <- gayini_plot_modis_timeseries_set(
      modis_monthly = modis_monthly,
      water_year_summary = water_year_summary,
      prepost_summary = prepost_summary,
      management_zone_summary = management_zone_summary,
      out_dir = gayini_path("Output", "figures", "modis_ground_cover", root = root)
    )
    gayini_write_csv(figure_paths, figure_paths_path)
  }

  modis_run_summary <- tibble::tibble(
    modis_run_mode = run_mode,
    n_modis_rasters = nrow(modis_catalog),
    n_context_units = nrow(context_units),
    expected_rows = expected_rows,
    extraction_rows = nrow(modis_results),
    cache_created_count = sum(cache_checks$action_taken == "created", na.rm = TRUE),
    cache_skipped_existing_valid_count = sum(cache_checks$action_taken == "skipped_existing_valid", na.rm = TRUE),
    cache_rebuilt_count = sum(cache_checks$action_taken == "rebuilt", na.rm = TRUE),
    cache_failed_count = sum(cache_checks$status == "fail", na.rm = TRUE),
    maps_written = nrow(map_paths),
    figures_written = nrow(figure_paths)
  )

  ppt_info <- tibble::tibble(
    ppt_path = NA_character_,
    fallback_outline_path = NA_character_,
    status = "not_requested",
    notes = NA_character_
  )

  if (isTRUE(write_ppt)) {
    ppt_info <- gayini_make_modis_results_ppt(
      root = root,
      modis_summary = modis_run_summary,
      map_paths = map_paths$path,
      figure_paths = figure_paths$path
    )
  }

  run_log <- c(
    "Gayini MODIS ground-cover Phase 2 run",
    paste("Run time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
    paste("MODIS run mode:", run_mode),
    paste("MODIS source raster count:", nrow(modis_catalog)),
    paste("Context unit count:", nrow(context_units)),
    paste("Expected rows:", expected_rows),
    paste("Extraction rows:", nrow(modis_results)),
    paste("Cache created:", modis_run_summary$cache_created_count),
    paste("Cache skipped existing valid:", modis_run_summary$cache_skipped_existing_valid_count),
    paste("Cache rebuilt:", modis_run_summary$cache_rebuilt_count),
    paste("Cache failed:", modis_run_summary$cache_failed_count),
    paste("Maps written:", nrow(map_paths)),
    paste("Figures written:", nrow(figure_paths)),
    paste("PPT status:", ppt_info$status[1]),
    paste("PPT path:", ppt_info$ppt_path[1]),
    paste("Fallback outline path:", ppt_info$fallback_outline_path[1])
  )
  gayini_write_lines(run_log, run_log_path)

  failed_checks <- context_checks |>
    dplyr::filter(.data$status == "fail")

  warning_checks <- context_checks |>
    dplyr::filter(.data$status == "warn")

  if (nrow(warning_checks) > 0) {
    warning(
      "MODIS context extraction warnings were created. Review: ",
      checks_path,
      call. = FALSE
    )
  }

  if (nrow(failed_checks) > 0) {
    stop(
      "MODIS context extraction checks failed. Review: ",
      checks_path,
      call. = FALSE
    )
  }

  message("MODIS ground-cover context extraction complete.")
  message("MODIS run mode: ", run_mode)
  message("MODIS source raster count: ", nrow(modis_catalog))
  message("AOI cache created/skipped/rebuilt/failed: ",
          modis_run_summary$cache_created_count, "/",
          modis_run_summary$cache_skipped_existing_valid_count, "/",
          modis_run_summary$cache_rebuilt_count, "/",
          modis_run_summary$cache_failed_count)
  message("Context unit count: ", nrow(context_units))
  message("Rows written: ", nrow(modis_results))
  message("Expected rows: ", expected_rows)
  message("Maps written: ", nrow(map_paths))
  message("Figures written: ", nrow(figure_paths))
  message("PPT/fallback status: ", ppt_info$status[1])
  message("Primary output: ", full_output_path)
  message("Processed output: ", processed_output_path)
  message("Run log: ", run_log_path)

  invisible(list(
    results = modis_results,
    monthly = modis_monthly,
    seasonal_summary = seasonal_summary,
    water_year_summary = water_year_summary,
    prepost_summary = prepost_summary,
    management_zone_summary = management_zone_summary,
    checks = context_checks,
    band_sum_checks = band_sum_checks,
    cache_checks = cache_checks,
    map_paths = map_paths,
    figure_paths = figure_paths,
    ppt_info = ppt_info,
    run_summary = modis_run_summary
  ))

}
