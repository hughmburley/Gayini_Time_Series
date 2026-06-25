####################################################################################################


## GAYINI REMOTE SENSING PROJECT


## Major raster catalogue functions.


####################################################################################################


## Product classification ----


gayini_classify_raster_product <- function(path) {

  path_lower <- tolower(normalizePath(path, winslash = "/", mustWork = FALSE))

  if (grepl("landsat_fractionalcover3", path_lower)) {
    return("landsat_fractional_cover")
  }

  if (grepl("landsat_inundation", path_lower)) {
    return("landsat_inundation")
  }

  if (grepl("sentinel2_inundation", path_lower)) {
    return("sentinel2_inundation")
  }

  if (grepl("modis_fractional_cover", path_lower)) {
    return("modis_fractional_cover")
  }

  if (grepl("/ads/", path_lower) || grepl("\\\\ads\\\\", path_lower)) {
    return("aerial_or_ads_imagery")
  }

  "unknown"

}


## Junk file screening ----


gayini_is_junk_raster_path <- function(path) {

  file_name_lower <- tolower(basename(path))

  grepl("desktop\\.ini", file_name_lower) |
    grepl("_na_", file_name_lower) |
    grepl("^thumbs\\.db", file_name_lower)

}


## Date helpers ----


gayini_make_water_year <- function(date_value) {

  if (is.na(date_value)) {
    return(NA_character_)
  }

  year_value  <- lubridate::year(date_value)
  month_value <- lubridate::month(date_value)

  if (month_value >= 7) {
    return(paste0(year_value, "-", year_value + 1))
  }

  paste0(year_value - 1, "-", year_value)

}


gayini_safe_ymd <- function(date_text) {

  if (is.na(date_text) || !grepl("^[0-9]{8}$", date_text)) {
    return(as.Date(NA))
  }

  date_value <- suppressWarnings(as.Date(date_text, format = "%Y%m%d"))

  if (is.na(date_value)) {
    return(as.Date(NA))
  }

  date_value

}


## Date parsing ----


gayini_parse_raster_dates <- function(path) {

  filename       <- basename(path)
  filename_lower <- tolower(filename)
  product        <- gayini_classify_raster_product(path)

  date_start  <- as.Date(NA)
  date_end    <- as.Date(NA)
  water_year  <- NA_character_
  season      <- NA_character_
  parse_status <- "not_parsed"

  if (product == "sentinel2_inundation") {

    match <- stringr::str_match(filename_lower, "lo_([0-9]{8})_s2")

    if (!is.na(match[1, 1])) {
      date_start  <- gayini_safe_ymd(match[1, 2])
      date_end    <- date_start
      water_year  <- gayini_make_water_year(date_start)
      parse_status <- ifelse(is.na(date_start), "date_invalid_sentinel2_daily", "parsed_sentinel2_daily")
    }

  }

  if (product == "landsat_inundation") {

    match <- stringr::str_match(filename_lower, "lo_([0-9]{4})_([0-9]{4})")

    if (!is.na(match[1, 1])) {
      water_year  <- paste0(match[1, 2], "-", match[1, 3])
      date_start  <- as.Date(paste0(match[1, 2], "-07-01"))
      date_end    <- as.Date(paste0(match[1, 3], "-06-30"))
      parse_status <- "parsed_landsat_water_year"
    }

  }

  if (product == "landsat_fractional_cover") {

    match <- stringr::str_match(filename_lower, "m([0-9]{4})([0-9]{2})([0-9]{4})([0-9]{2})")

    if (!is.na(match[1, 1])) {
      start_year  <- as.integer(match[1, 2])
      start_month <- as.integer(match[1, 3])
      end_year    <- as.integer(match[1, 4])
      end_month   <- as.integer(match[1, 5])

      date_start  <- as.Date(sprintf("%04d-%02d-01", start_year, start_month))
      date_end    <- as.Date(sprintf("%04d-%02d-01", end_year, end_month))
      season      <- paste0(sprintf("%04d-%02d", start_year, start_month), "_to_", sprintf("%04d-%02d", end_year, end_month))
      water_year  <- gayini_make_water_year(date_start)
      parse_status <- "parsed_landsat_fractional_cover_period"
    }

  }

  if (product == "modis_fractional_cover") {

    match <- stringr::str_match(filename_lower, "a([0-9]{4})\\.([0-9]{2})")

    if (!is.na(match[1, 1])) {
      date_start  <- as.Date(paste0(match[1, 2], "-", match[1, 3], "-01"))
      date_end    <- date_start
      water_year  <- gayini_make_water_year(date_start)
      parse_status <- "parsed_modis_monthly"
    }

  }

  if (product == "aerial_or_ads_imagery") {

    match <- stringr::str_match(filename_lower, "([0-9]{8})")

    if (!is.na(match[1, 1])) {
      date_start  <- gayini_safe_ymd(match[1, 2])
      date_end    <- date_start
      water_year  <- gayini_make_water_year(date_start)
      parse_status <- ifelse(is.na(date_start), "date_invalid_ads_imagery", "parsed_ads_imagery_daily")
    }

  }

  tibble::tibble(
    product           = product,
    date_start        = date_start,
    date_end          = date_end,
    water_year        = water_year,
    season            = season,
    date_parse_status = parse_status
  )

}


## Raster metadata ----


gayini_catalog_one_raster <- function(path) {

  date_info <- gayini_parse_raster_dates(path)

  result <- tryCatch({

    r <- terra::rast(path)

    crs_description <- terra::crs(r, describe = TRUE)

    tibble::tibble(
      file_path     = normalizePath(path, winslash = "/", mustWork = FALSE),
      file_name     = basename(path),
      extension     = tools::file_ext(path),
      file_size_mb  = round(file.info(path)$size / 1024^2, 3),
      product       = date_info$product,
      n_layers      = terra::nlyr(r),
      n_rows        = terra::nrow(r),
      n_cols        = terra::ncol(r),
      resolution_x  = terra::xres(r),
      resolution_y  = terra::yres(r),
      crs_name      = crs_description$name,
      crs_epsg      = crs_description$code,
      data_type     = paste(unique(terra::datatype(r)), collapse = "; "),
      nodata_value  = paste(unique(terra::NAflag(r)), collapse = "; "),
      xmin          = terra::ext(r)$xmin,
      xmax          = terra::ext(r)$xmax,
      ymin          = terra::ext(r)$ymin,
      ymax          = terra::ext(r)$ymax,
      read_status   = "ok"
    )

  }, error = function(e) {

    tibble::tibble(
      file_path     = normalizePath(path, winslash = "/", mustWork = FALSE),
      file_name     = basename(path),
      extension     = tools::file_ext(path),
      file_size_mb  = round(file.info(path)$size / 1024^2, 3),
      product       = date_info$product,
      n_layers      = NA_integer_,
      n_rows        = NA_integer_,
      n_cols        = NA_integer_,
      resolution_x  = NA_real_,
      resolution_y  = NA_real_,
      crs_name      = NA_character_,
      crs_epsg      = NA_character_,
      data_type     = NA_character_,
      nodata_value  = NA_character_,
      xmin          = NA_real_,
      xmax          = NA_real_,
      ymin          = NA_real_,
      ymax          = NA_real_,
      read_status   = paste("failed:", conditionMessage(e))
    )

  })

  dplyr::bind_cols(result, dplyr::select(date_info, -product))

}


gayini_catalog_rasters <- function(root = getwd()) {

  input_dir <- gayini_path("Input", root = root)

  gayini_stop_if_missing(input_dir, label = "Input directory")

  raster_files_raw <- list.files(
    input_dir,
    pattern     = "\\.(tif|tiff|img|jp2)$",
    recursive   = TRUE,
    full.names  = TRUE,
    ignore.case = TRUE
  )

  if (length(raster_files_raw) == 0) {
    stop("No raster files found under: ", input_dir, call. = FALSE)
  }

  junk_files   <- raster_files_raw[gayini_is_junk_raster_path(raster_files_raw)]
  raster_files <- raster_files_raw[!gayini_is_junk_raster_path(raster_files_raw)]

  if (length(junk_files) > 0) {
    message("Ignored junk/system raster-like files: ", length(junk_files))
  }

  if (length(raster_files) == 0) {
    stop("Only junk/system raster-like files were found under: ", input_dir, call. = FALSE)
  }

  message("Raster files found: ", length(raster_files))

  catalog <- dplyr::bind_rows(lapply(raster_files, gayini_catalog_one_raster))

  catalog <- catalog |>
    dplyr::mutate(
      needs_date_check      = date_parse_status == "not_parsed",
      needs_legend_check    = product %in% c("landsat_inundation", "sentinel2_inundation", "landsat_fractional_cover"),
      is_plot_scale_candidate = product %in% c("landsat_fractional_cover", "landsat_inundation", "sentinel2_inundation")
    ) |>
    dplyr::arrange(product, date_start, file_name)

  catalog

}


gayini_make_raster_catalog_summaries <- function(catalog) {

  product_summary <- catalog |>
    dplyr::group_by(product) |>
    dplyr::summarise(
      file_count          = dplyr::n(),
      total_size_gb       = round(sum(file_size_mb, na.rm = TRUE) / 1024, 3),
      date_parse_failures = sum(needs_date_check, na.rm = TRUE),
      read_failures       = sum(read_status != "ok", na.rm = TRUE),
      .groups             = "drop"
    ) |>
    dplyr::arrange(dplyr::desc(file_count))

  warnings <- catalog |>
    dplyr::filter(read_status != "ok" | needs_date_check | is.na(crs_name) | product == "unknown") |>
    dplyr::select(file_name, product, read_status, date_parse_status, crs_name, file_path)

  list(product_summary = product_summary, warnings = warnings)

}


gayini_write_raster_catalog_outputs <- function(catalog, root = getwd()) {

  summaries <- gayini_make_raster_catalog_summaries(catalog)

  catalog_dir     <- gayini_path("data_intermediate", "raster_catalog", root = root)
  diagnostics_dir <- gayini_path("Output", "diagnostics", root = root)
  csv_dir         <- gayini_path("Output", "csv", root = root)

  gayini_write_csv(catalog, file.path(catalog_dir, "raster_catalog.csv"))
  gayini_write_csv(summaries$product_summary, file.path(csv_dir, "raster_product_summary.csv"))
  gayini_write_csv(summaries$warnings, file.path(diagnostics_dir, "raster_catalog_warnings.csv"))

  invisible(summaries)

}
