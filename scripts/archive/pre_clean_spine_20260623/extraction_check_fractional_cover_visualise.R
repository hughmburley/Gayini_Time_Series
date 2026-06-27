## Gayini fractional-cover extraction visual checks ----


## Purpose:
## This script is a diagnostic / visual QA script only.
## It is not part of the numbered main workflow.
## It creates PNG maps for selected plot × raster cases so that we can check
## whether missing or low-coverage extraction results are consistent with
## source-raster NoData / footprint issues rather than processing errors.
##
## This version is designed for the full 04c fractional-cover output.
## It samples a broader cross-section across the full time series, including:
##   A) all-bands-missing cases spread through time
##   B) very-low and low valid-coverage cases
##   C) band-sum anomalies, if any
##   D) rasters with high missingness across plots
##   E) clean early / middle / late comparison cases


## User settings ----


ROOT_DIR <- "D:/Github_repos/Gayini"


## Input filenames to discover recursively ----


## The script now searches under ROOT_DIR recursively, so outputs can live in
## standard project subfolders such as Output/csv, data_processed, or nested
## folders created after unzipping an archive.


FC_OUTPUT_FILE_NAMES <- c(
  "04c_fractional_cover_full.csv",
  "plot_fractional_cover_timeseries.csv",
  "04b_fractional_cover_all_dev_plots.csv"
)


RASTER_CATALOG_FILE_NAMES <- c(
  "raster_catalog.csv",
  "raster_dev_subset.csv"
)


PLOTS_FILE_NAMES <- c(
  "plots_clean.gpkg"
)


## Preferred path fragments are used only for tie-breaking when duplicate
## filenames exist under ROOT_DIR.


FC_OUTPUT_PREFERRED_PATH_PARTS <- c(
  "Output/csv",
  "data_processed"
)


RASTER_CATALOG_PREFERRED_PATH_PARTS <- c(
  "data_intermediate/raster_catalog"
)


PLOTS_PREFERRED_PATH_PARTS <- c(
  "data_intermediate/spatial"
)


FIGURES_DIR <- file.path(
  ROOT_DIR,
  "Output",
  "figures",
  "extraction_checks",
  "fractional_cover_full_timeseries"
)


DIAGNOSTICS_DIR <- file.path(
  ROOT_DIR,
  "Output",
  "diagnostics",
  "extraction_checks"
)


## Case selection limits. These are deliberately small enough to review manually.


MAX_ALL_MISSING_CASES <- 18


MAX_LOW_COVERAGE_CASES <- 18


MAX_BAND_SUM_ANOMALY_CASES <- 12


MAX_HIGH_MISSING_RASTER_CASES <- 12


MAX_CLEAN_COMPARISON_CASES <- 12


## Coverage thresholds are effective raster-cell counts per plot/date/band.
## For a 1 ha plot and 30 m Landsat pixels, typical valid coverage is ~11 cells.


VERY_LOW_COVERAGE_THRESHOLD_EFFECTIVE_CELLS <- 1


LOW_COVERAGE_THRESHOLD_EFFECTIVE_CELLS <- 5


BAND_SUM_LOW_THRESHOLD <- 90


BAND_SUM_HIGH_THRESHOLD <- 110


MAP_BUFFER_METRES_MINIMUM <- 120


PLOT_BUFFER_PIXELS_FOR_CONTEXT <- 1


SHOW_PLOT_BUFFER <- TRUE


RASTER_BANDS_TO_PLOT <- c(1, 2, 3)


PNG_WIDTH <- 2800


PNG_HEIGHT <- 2400


PNG_RES <- 240


## Package setup ----


required_packages <- c(
  "terra",
  "sf",
  "dplyr",
  "readr",
  "stringr",
  "purrr",
  "tibble",
  "lubridate"
)


missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]


if (length(missing_packages) > 0) {
  stop(
    "Missing required packages: ",
    paste(missing_packages, collapse = ", "),
    call. = FALSE
  )
}


message("All required packages are available.")


## Root and recursive path checks ----


if (!dir.exists(ROOT_DIR)) {
  ROOT_DIR <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
}


dir.create(FIGURES_DIR, recursive = TRUE, showWarnings = FALSE)


dir.create(DIAGNOSTICS_DIR, recursive = TRUE, showWarnings = FALSE)


gayini_normalise_path_for_matching <- function(x) {
  x |>
    normalizePath(winslash = "/", mustWork = FALSE) |>
    stringr::str_replace_all("\\\\", "/")
}


gayini_find_nested_file <- function(root_dir, file_names, label, preferred_path_parts = character()) {
  root_dir <- gayini_normalise_path_for_matching(root_dir)

  candidate_files <- list.files(
    path       = root_dir,
    recursive  = TRUE,
    full.names  = TRUE,
    no..        = TRUE
  )

  candidate_files <- gayini_normalise_path_for_matching(candidate_files)

  matched_files <- candidate_files[
    tolower(basename(candidate_files)) %in% tolower(file_names)
  ]

  if (length(matched_files) == 0) {
    stop(
      "Could not find ", label, " under: ", root_dir, ". ",
      "Searched recursively for filenames: ",
      paste(file_names, collapse = ", "),
      call. = FALSE
    )
  }

  match_table <- tibble::tibble(
    path      = matched_files,
    file_name = basename(matched_files),
    file_rank = match(tolower(basename(matched_files)), tolower(file_names))
  )

  if (length(preferred_path_parts) > 0) {
    preferred_path_parts <- stringr::str_replace_all(preferred_path_parts, "\\\\", "/")

    match_table <- match_table |>
      dplyr::rowwise() |>
      dplyr::mutate(
        preferred_score = sum(stringr::str_detect(path, stringr::fixed(preferred_path_parts)))
      ) |>
      dplyr::ungroup()
  } else {
    match_table$preferred_score <- 0
  }

  match_table <- match_table |>
    dplyr::arrange(file_rank, dplyr::desc(preferred_score), path)

  if (nrow(match_table) > 1) {
    message(
      "Found ", nrow(match_table), " possible files for ", label,
      ". Using: ", match_table$path[1]
    )
  }

  match_table$path[1]
}


gayini_try_find_nested_file <- function(root_dir, file_names, label, preferred_path_parts = character()) {
  tryCatch(
    gayini_find_nested_file(
      root_dir              = root_dir,
      file_names            = file_names,
      label                 = label,
      preferred_path_parts  = preferred_path_parts
    ),
    error = function(e) {
      message("Optional file not found: ", label)
      NA_character_
    }
  )
}


PLOTS_PATH <- gayini_find_nested_file(
  root_dir             = ROOT_DIR,
  file_names           = PLOTS_FILE_NAMES,
  label                = "clean plot GeoPackage",
  preferred_path_parts = PLOTS_PREFERRED_PATH_PARTS
)


fc_output_path <- gayini_find_nested_file(
  root_dir             = ROOT_DIR,
  file_names           = FC_OUTPUT_FILE_NAMES,
  label                = "fractional-cover extraction output",
  preferred_path_parts = FC_OUTPUT_PREFERRED_PATH_PARTS
)


raster_catalog_path <- gayini_try_find_nested_file(
  root_dir             = ROOT_DIR,
  file_names           = RASTER_CATALOG_FILE_NAMES,
  label                = "raster catalogue",
  preferred_path_parts = RASTER_CATALOG_PREFERRED_PATH_PARTS
)


message("Using clean plots: ", PLOTS_PATH)


message("Using fractional-cover output: ", fc_output_path)


if (!is.na(raster_catalog_path)) {
  message("Using raster catalogue: ", raster_catalog_path)
} else {
  message("Raster catalogue not found. The script will try to use file_path values from the extraction output.")
}


## Helper functions ----


gayini_first_existing_column <- function(data, candidate_names, label) {
  matched_name <- candidate_names[candidate_names %in% names(data)][1]
  if (is.na(matched_name)) {
    stop(
      "Could not find required column for ", label, ". Candidate names were: ",
      paste(candidate_names, collapse = ", "),
      call. = FALSE
    )
  }
  matched_name
}


gayini_optional_column <- function(data, candidate_names) {
  matched_name <- candidate_names[candidate_names %in% names(data)][1]
  if (is.na(matched_name)) {
    return(NA_character_)
  }
  matched_name
}


gayini_safe_sum <- function(x) {
  if (all(is.na(x))) {
    return(NA_real_)
  }
  sum(x, na.rm = TRUE)
}


gayini_safe_min <- function(x) {
  if (all(is.na(x))) {
    return(NA_real_)
  }
  min(x, na.rm = TRUE)
}


gayini_safe_max <- function(x) {
  if (all(is.na(x))) {
    return(NA_real_)
  }
  max(x, na.rm = TRUE)
}


gayini_make_safe_file_label <- function(x) {
  x |>
    stringr::str_replace_all("[^A-Za-z0-9_]+", "_") |>
    stringr::str_replace_all("_+", "_") |>
    stringr::str_replace_all("^_|_$", "")
}


gayini_get_raster_path_column <- function(raster_catalog) {
  gayini_first_existing_column(
    raster_catalog,
    c("file_path", "path", "full_path", "raster_path", "source_path"),
    "raster file path"
  )
}


gayini_standardise_date_columns <- function(data) {
  if ("date_start" %in% names(data)) {
    data$date_start <- as.Date(data$date_start)
  }

  if ("date_end" %in% names(data)) {
    data$date_end <- as.Date(data$date_end)
  }

  data
}


gayini_add_valid_coverage_status <- function(data) {
  data |>
    dplyr::mutate(
      coverage_status = dplyr::case_when(
        all_bands_missing ~ "all_bands_missing",
        is.na(min_valid_count) ~ "unknown_coverage",
        min_valid_count <= 0 ~ "no_valid_coverage",
        min_valid_count < VERY_LOW_COVERAGE_THRESHOLD_EFFECTIVE_CELLS ~ "very_low_valid_coverage",
        min_valid_count < LOW_COVERAGE_THRESHOLD_EFFECTIVE_CELLS ~ "low_valid_coverage",
        TRUE ~ "adequate_valid_coverage"
      )
    )
}


gayini_make_case_table <- function(fc_output) {
  fc_output |>
    dplyr::group_by(
      plot_id,
      date_start,
      date_end,
      water_year,
      file_name
    ) |>
    dplyr::summarise(
      n_rows                = dplyr::n(),
      n_bands               = dplyr::n_distinct(band_number),
      n_missing_mean_values = sum(is.na(mean_value)),
      all_bands_missing     = all(is.na(mean_value)),
      band_sum_mean_value   = gayini_safe_sum(mean_value),
      min_band_mean_value   = gayini_safe_min(mean_value),
      max_band_mean_value   = gayini_safe_max(mean_value),
      min_valid_count       = gayini_safe_min(valid_coverage_count),
      max_valid_count       = gayini_safe_max(valid_coverage_count),
      mean_valid_count      = ifelse(all(is.na(valid_coverage_count)), NA_real_, mean(valid_coverage_count, na.rm = TRUE)),
      treatment             = dplyr::first(treatment),
      vegetation            = dplyr::first(vegetation),
      .groups               = "drop"
    ) |>
    gayini_add_valid_coverage_status() |>
    dplyr::mutate(
      band_sum_status = dplyr::case_when(
        all_bands_missing ~ "all_bands_missing",
        is.na(band_sum_mean_value) ~ "unknown_band_sum",
        band_sum_mean_value < BAND_SUM_LOW_THRESHOLD ~ "band_sum_low",
        band_sum_mean_value > BAND_SUM_HIGH_THRESHOLD ~ "band_sum_high",
        TRUE ~ "band_sum_ok"
      )
    )
}


gayini_slice_spread_through_time <- function(data, n) {
  if (nrow(data) <= n) {
    return(data)
  }

  data <- data |>
    dplyr::arrange(date_start, plot_id, file_name)

  selected_index <- unique(round(seq(1, nrow(data), length.out = n)))

  data |>
    dplyr::slice(selected_index)
}


gayini_select_high_missing_raster_cases <- function(case_table, n) {
  high_missing_rasters <- case_table |>
    dplyr::group_by(file_name, date_start, date_end, water_year) |>
    dplyr::summarise(
      all_missing_plot_count = sum(all_bands_missing, na.rm = TRUE),
      low_coverage_plot_count = sum(coverage_status %in% c("very_low_valid_coverage", "low_valid_coverage"), na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::filter(all_missing_plot_count > 0 | low_coverage_plot_count > 0) |>
    dplyr::arrange(dplyr::desc(all_missing_plot_count), dplyr::desc(low_coverage_plot_count), date_start) |>
    dplyr::slice_head(n = n)

  if (nrow(high_missing_rasters) == 0) {
    return(case_table[0, ] |>
             dplyr::mutate(check_group = character()))
  }

  case_table |>
    dplyr::semi_join(high_missing_rasters, by = c("file_name", "date_start", "date_end", "water_year")) |>
    dplyr::arrange(file_name, dplyr::desc(all_bands_missing), min_valid_count, plot_id) |>
    dplyr::group_by(file_name, date_start, date_end, water_year) |>
    dplyr::slice_head(n = 1) |>
    dplyr::ungroup() |>
    dplyr::mutate(check_group = "high_missing_raster_example")
}


gayini_select_check_cases <- function(case_table) {
  all_missing_cases <- case_table |>
    dplyr::filter(coverage_status == "all_bands_missing") |>
    gayini_slice_spread_through_time(MAX_ALL_MISSING_CASES) |>
    dplyr::mutate(check_group = "all_bands_missing")

  low_coverage_cases <- case_table |>
    dplyr::filter(coverage_status %in% c("very_low_valid_coverage", "low_valid_coverage")) |>
    dplyr::arrange(min_valid_count, date_start, plot_id) |>
    dplyr::slice_head(n = MAX_LOW_COVERAGE_CASES) |>
    dplyr::mutate(check_group = "low_valid_coverage")

  band_sum_anomaly_cases <- case_table |>
    dplyr::filter(band_sum_status %in% c("band_sum_low", "band_sum_high")) |>
    dplyr::arrange(dplyr::desc(abs(band_sum_mean_value - 100)), date_start, plot_id) |>
    dplyr::slice_head(n = MAX_BAND_SUM_ANOMALY_CASES) |>
    dplyr::mutate(check_group = "band_sum_anomaly")

  high_missing_raster_cases <- gayini_select_high_missing_raster_cases(
    case_table = case_table,
    n          = MAX_HIGH_MISSING_RASTER_CASES
  )

  clean_cases <- case_table |>
    dplyr::filter(
      coverage_status == "adequate_valid_coverage",
      band_sum_status == "band_sum_ok"
    ) |>
    gayini_slice_spread_through_time(MAX_CLEAN_COMPARISON_CASES) |>
    dplyr::mutate(check_group = "clean_time_series_comparison")

  dplyr::bind_rows(
    all_missing_cases,
    low_coverage_cases,
    band_sum_anomaly_cases,
    high_missing_raster_cases,
    clean_cases
  ) |>
    dplyr::arrange(check_group, date_start, plot_id) |>
    dplyr::distinct(check_group, plot_id, file_name, .keep_all = TRUE)
}


gayini_make_plot_buffer <- function(plot_vect, raster_res, buffer_pixels) {
  if (buffer_pixels <= 0) {
    return(NULL)
  }

  buffer_distance <- max(abs(raster_res), na.rm = TRUE) * buffer_pixels

  terra::buffer(plot_vect, width = buffer_distance)
}


gayini_crop_raster_for_plot <- function(raster, plot_vect, map_buffer_metres_minimum) {
  raster_res <- terra::res(raster)

  map_buffer <- max(map_buffer_metres_minimum, max(abs(raster_res), na.rm = TRUE) * 4)

  plot_extent <- terra::ext(plot_vect)

  plot_extent <- terra::ext(
    plot_extent$xmin - map_buffer,
    plot_extent$xmax + map_buffer,
    plot_extent$ymin - map_buffer,
    plot_extent$ymax + map_buffer
  )

  terra::crop(raster, plot_extent)
}


gayini_make_valid_mask <- function(raster_band) {
  valid_mask <- !is.na(raster_band)
  names(valid_mask) <- "valid_data_mask"
  valid_mask
}


gayini_get_raster_crs_label <- function(raster) {
  crs_description <- tryCatch(
    terra::crs(raster, describe = TRUE),
    error = function(e) NULL
  )

  if (is.null(crs_description) || is.null(crs_description$code) || is.na(crs_description$code)) {
    return("CRS code unavailable")
  }

  paste0(crs_description$authority, ":", crs_description$code)
}


gayini_wrap_label <- function(x, width = 105) {
  stringr::str_wrap(as.character(x), width = width)
}


gayini_plot_single_case <- function(case_row, plots_sf, raster_lookup, figures_dir) {
  raster_path <- raster_lookup[[case_row$file_name]]

  if (is.null(raster_path) || is.na(raster_path) || !file.exists(raster_path)) {
    warning("Raster path not found for: ", case_row$file_name, call. = FALSE)
    return(tibble::tibble(
      plot_id       = case_row$plot_id,
      file_name     = case_row$file_name,
      output_png    = NA_character_,
      plot_status   = "raster_path_missing"
    ))
  }

  raster <- terra::rast(raster_path)

  plot_sf <- plots_sf |>
    dplyr::filter(plot_id == case_row$plot_id)

  if (nrow(plot_sf) != 1) {
    warning("Expected one plot for ", case_row$plot_id, ", found ", nrow(plot_sf), call. = FALSE)
    return(tibble::tibble(
      plot_id       = case_row$plot_id,
      file_name     = case_row$file_name,
      output_png    = NA_character_,
      plot_status   = "plot_lookup_failed"
    ))
  }

  plot_sf_raster_crs <- sf::st_transform(plot_sf, sf::st_crs(terra::crs(raster)))

  plot_vect <- terra::vect(plot_sf_raster_crs)

  raster_crop <- gayini_crop_raster_for_plot(
    raster                    = raster,
    plot_vect                 = plot_vect,
    map_buffer_metres_minimum = MAP_BUFFER_METRES_MINIMUM
  )

  raster_res <- terra::res(raster_crop)

  plot_buffer <- gayini_make_plot_buffer(
    plot_vect     = plot_vect,
    raster_res    = raster_res,
    buffer_pixels = PLOT_BUFFER_PIXELS_FOR_CONTEXT
  )

  valid_mask <- gayini_make_valid_mask(raster_crop[[1]])

  file_label <- paste(
    case_row$check_group,
    case_row$plot_id,
    format(as.Date(case_row$date_start), "%Y%m%d"),
    stringr::str_remove(case_row$file_name, "\\.[A-Za-z0-9]+$"),
    sep = "__"
  ) |>
    gayini_make_safe_file_label()

  output_png <- file.path(figures_dir, paste0(file_label, ".png"))

  png(filename = output_png, width = PNG_WIDTH, height = PNG_HEIGHT, res = PNG_RES)

  old_par <- par(no.readonly = TRUE)

  on.exit({
    par(old_par)
    dev.off()
  }, add = TRUE)

  par(
    mfrow = c(2, 2),
    mar   = c(3.1, 3.0, 2.7, 4.6),
    oma   = c(4.3, 0, 7.4, 0)
  )

  for (band_index in RASTER_BANDS_TO_PLOT) {
    if (band_index <= terra::nlyr(raster_crop)) {
      terra::plot(
        raster_crop[[band_index]],
        main = paste0("Band ", band_index),
        axes = TRUE,
        cex.main = 0.82,
        cex.axis = 0.72,
        cex.lab  = 0.72
      )

      if (SHOW_PLOT_BUFFER && !is.null(plot_buffer)) {
        terra::plot(plot_buffer, add = TRUE, border = "grey30", lwd = 1, lty = 2)
      }

      terra::plot(plot_vect, add = TRUE, border = "red", lwd = 2)
    }
  }

  terra::plot(
    valid_mask,
    main = "Valid data mask | Band 1",
    axes = TRUE,
    cex.main = 0.82,
    cex.axis = 0.72,
    cex.lab  = 0.72
  )

  if (SHOW_PLOT_BUFFER && !is.null(plot_buffer)) {
    terra::plot(plot_buffer, add = TRUE, border = "grey30", lwd = 1, lty = 2)
  }

  terra::plot(plot_vect, add = TRUE, border = "red", lwd = 2)

  raster_crs_label <- gayini_get_raster_crs_label(raster)

  title_line_1 <- paste0(
    "Check: ", case_row$check_group,
    " | Plot: ", case_row$plot_id,
    " | Status: ", case_row$coverage_status
  )

  title_line_2 <- paste0(
    "Date: ", case_row$date_start,
    " to ", case_row$date_end,
    " | Min effective cells: ", round(case_row$min_valid_count, 3),
    " | Band sum: ", round(case_row$band_sum_mean_value, 2)
  )

  title_line_3 <- paste0("File: ", gayini_wrap_label(case_row$file_name, width = 120))

  title_line_4 <- paste0(
    "Raster: ", raster_crs_label,
    " | Resolution: ", paste(round(terra::res(raster), 3), collapse = " × ")
  )

  mtext(title_line_1, side = 3, outer = TRUE, line = 5.5, cex = 0.78, font = 2)
  mtext(title_line_2, side = 3, outer = TRUE, line = 4.4, cex = 0.68)
  mtext(title_line_3, side = 3, outer = TRUE, line = 3.2, cex = 0.58)
  mtext(title_line_4, side = 3, outer = TRUE, line = 1.9, cex = 0.58)

  mtext(
    "Red outline = 1 ha plot. Grey dashed outline = one-pixel contextual buffer for visual QA only; extraction is not buffered.",
    side = 1,
    outer = TRUE,
    line = 2.4,
    cex = 0.56
  )

  tibble::tibble(
    plot_id             = case_row$plot_id,
    file_name           = case_row$file_name,
    date_start          = case_row$date_start,
    date_end            = case_row$date_end,
    check_group         = case_row$check_group,
    coverage_status     = case_row$coverage_status,
    band_sum_status     = case_row$band_sum_status,
    band_sum_mean_value = case_row$band_sum_mean_value,
    min_valid_count     = case_row$min_valid_count,
    raster_path         = raster_path,
    output_png          = output_png,
    raster_crs          = terra::crs(raster),
    raster_res_x        = terra::res(raster)[1],
    raster_res_y        = terra::res(raster)[2],
    raster_band_count   = terra::nlyr(raster),
    plot_status         = "png_created"
  )
}


## Read inputs ----


plots_sf <- sf::st_read(PLOTS_PATH, quiet = TRUE)


if (!is.na(raster_catalog_path)) {
  raster_catalog <- readr::read_csv(raster_catalog_path, show_col_types = FALSE)
} else {
  raster_catalog <- tibble::tibble()
}


fc_output <- readr::read_csv(fc_output_path, show_col_types = FALSE) |>
  gayini_standardise_date_columns()


message("Clean plots available: ", nrow(plots_sf))


message("Raster catalogue rows: ", nrow(raster_catalog))


message("Fractional-cover extraction rows: ", nrow(fc_output))


## Prepare raster lookup ----


fc_file_path_col <- gayini_optional_column(
  fc_output,
  c("file_path", "path", "full_path", "raster_path", "source_path")
)


fc_file_name_col <- gayini_optional_column(
  fc_output,
  c("file_name", "filename", "basename")
)


if (!is.na(fc_file_path_col) && !is.na(fc_file_name_col)) {
  raster_lookup_table <- fc_output |>
    dplyr::select(
      file_name   = dplyr::all_of(fc_file_name_col),
      raster_path = dplyr::all_of(fc_file_path_col)
    ) |>
    dplyr::filter(!is.na(raster_path)) |>
    dplyr::distinct(file_name, .keep_all = TRUE)

  message("Prepared raster lookup from extraction output file_path column.")
} else if (nrow(raster_catalog) > 0) {
  raster_path_col <- gayini_get_raster_path_column(raster_catalog)

  file_name_col <- gayini_first_existing_column(
    raster_catalog,
    c("file_name", "filename", "basename"),
    "raster file name"
  )

  product_col <- gayini_optional_column(raster_catalog, c("product", "product_type", "data_product"))

  if (!is.na(product_col)) {
    raster_lookup_table <- raster_catalog |>
      dplyr::filter(.data[[product_col]] == "landsat_fractional_cover")
  } else {
    raster_lookup_table <- raster_catalog |>
      dplyr::filter(stringr::str_detect(.data[[file_name_col]], "lztmre|fractional|cover"))
  }

  raster_lookup_table <- raster_lookup_table |>
    dplyr::select(
      file_name   = dplyr::all_of(file_name_col),
      raster_path = dplyr::all_of(raster_path_col)
    ) |>
    dplyr::distinct(file_name, .keep_all = TRUE)

  message("Prepared raster lookup from raster catalogue.")
} else {
  stop(
    "Could not prepare raster lookup. Need either file_path in the extraction output or a raster catalogue.",
    call. = FALSE
  )
}


raster_lookup <- stats::setNames(raster_lookup_table$raster_path, raster_lookup_table$file_name)


message("Fractional-cover rasters available for visual lookup: ", length(raster_lookup))


## Select cases for visual checking ----


case_table <- gayini_make_case_table(fc_output)


selected_cases <- gayini_select_check_cases(case_table)


case_table_path <- file.path(DIAGNOSTICS_DIR, "extraction_check_fractional_cover_full_case_table.csv")


selected_cases_path <- file.path(DIAGNOSTICS_DIR, "extraction_check_fractional_cover_full_selected_cases.csv")


summary_path <- file.path(DIAGNOSTICS_DIR, "extraction_check_fractional_cover_full_selection_summary.csv")


selection_summary <- selected_cases |>
  dplyr::count(check_group, coverage_status, band_sum_status, name = "n_cases") |>
  dplyr::arrange(check_group, coverage_status, band_sum_status)


readr::write_csv(case_table, case_table_path)


readr::write_csv(selected_cases, selected_cases_path)


readr::write_csv(selection_summary, summary_path)


message("Wrote: ", case_table_path)


message("Wrote: ", selected_cases_path)


message("Wrote: ", summary_path)


message("Selected cases for PNG checks: ", nrow(selected_cases))


## Create PNG checks ----


plot_results <- purrr::map_dfr(
  seq_len(nrow(selected_cases)),
  function(i) {
    message(
      "Creating extraction-check PNG ", i, " of ", nrow(selected_cases), ": ",
      selected_cases$check_group[i], " | ",
      selected_cases$plot_id[i], " | ",
      selected_cases$file_name[i]
    )

    gayini_plot_single_case(
      case_row      = selected_cases[i, ],
      plots_sf      = plots_sf,
      raster_lookup = raster_lookup,
      figures_dir   = FIGURES_DIR
    )
  }
)


plot_results_path <- file.path(DIAGNOSTICS_DIR, "extraction_check_fractional_cover_full_png_index.csv")


readr::write_csv(plot_results, plot_results_path)


message("Wrote: ", plot_results_path)


message("Extraction-check PNG folder: ", FIGURES_DIR)


message("Fractional-cover full time-series extraction visual check complete.")
