## Daily inundation extraction functions ----

## These functions support extraction of the NSW inland floodplain wetland
## daily inundation rasters. The expected legend, based on SEED/Data.NSW
## metadata, is:
## 0 = not inundated
## 1 = inundated
## 2 = off-river storage with water
## 3 = cloud shadow
## The legend should still be confirmed with Adrian before final interpretation.


## Date helpers ----

gayini_get_water_year <- function(date) {
  date <- as.Date(date)
  year <- as.integer(format(date, "%Y"))
  month <- as.integer(format(date, "%m"))
  start_year <- ifelse(month >= 7, year, year - 1)
  end_year <- start_year + 1
  paste0(start_year, "-", end_year)
}


gayini_parse_daily_inundation_date <- function(file_name) {
  file_name <- basename(file_name)
  date_token <- stringr::str_extract(file_name, "(?<![0-9])[0-9]{8}(?![0-9])")
  as.Date(date_token, format = "%Y%m%d")
}


## Sensor helpers ----

gayini_parse_daily_inundation_sensor <- function(file_name, file_path = NA_character_, res_x = NA_real_) {
  file_name_lower <- tolower(basename(file_name))
  file_path_lower <- tolower(file_path)
  has_s2 <- stringr::str_detect(file_name_lower, "(^|_)s2(_|$)")
  has_l7 <- stringr::str_detect(file_name_lower, "(^|_)l7(_|$)")
  has_l8 <- stringr::str_detect(file_name_lower, "(^|_)l8(_|$)")

  if (has_s2) {
    return(tibble::tibble(sensor = "s2", sensor_evidence = "filename_token"))
  }

  if (has_l7) {
    return(tibble::tibble(sensor = "l7", sensor_evidence = "filename_token"))
  }

  if (has_l8) {
    return(tibble::tibble(sensor = "l8", sensor_evidence = "filename_token"))
  }

  if (!is.na(res_x) && res_x <= 12) {
    return(tibble::tibble(sensor = "s2_inferred_10m", sensor_evidence = "missing_token_resolution_10m"))
  }

  if (stringr::str_detect(file_path_lower, "sentinel|sentinel2")) {
    return(tibble::tibble(sensor = "s2_inferred_folder", sensor_evidence = "missing_token_sentinel_folder"))
  }

  tibble::tibble(sensor = "unknown", sensor_evidence = "missing_token")
}


gayini_drop_existing_daily_derived_fields <- function(catalog) {
  derived_patterns <- c(
    "^sensor(\\.\\.\\.[0-9]+)?$",
    "^sensor_evidence(\\.\\.\\.[0-9]+)?$",
    "^file_name_lower$",
    "^file_path_lower$",
    "^date_start$",
    "^date_end$",
    "^date_midpoint$",
    "^water_year$",
    "^product$",
    "^has_cloud3_name$",
    "^has_ors2_name$",
    "^is_daily_name$",
    "^is_daily_path$",
    "^is_daily_file$"
  )

  derived_regex <- paste(derived_patterns, collapse = "|")

  drop_names <- names(catalog)[stringr::str_detect(names(catalog), derived_regex)]

  catalog |>
    dplyr::select(-dplyr::any_of(drop_names))
}


gayini_add_daily_sensor_fields <- function(catalog) {
  catalog <- catalog |>
    dplyr::select(-dplyr::matches("^sensor(\\.\\.\\.[0-9]+)?$")) |>
    dplyr::select(-dplyr::matches("^sensor_evidence(\\.\\.\\.[0-9]+)?$"))

  sensor_rows <- purrr::pmap_dfr(
    list(catalog$file_name, catalog$file_path, catalog$res_x),
    gayini_parse_daily_inundation_sensor
  )

  dplyr::bind_cols(catalog, sensor_rows)
}


## Catalogue helpers ----

gayini_choose_first_existing_path <- function(paths) {
  paths <- paths[!is.na(paths)]
  paths <- paths[file.exists(paths)]

  if (length(paths) == 0) {
    return(NA_character_)
  }

  paths[[1]]
}


gayini_find_project_file <- function(root, file_name, prefer_patterns = character()) {
  all_matches <- list.files(
    path       = root,
    pattern    = paste0("^", stringr::fixed(file_name), "$"),
    recursive  = TRUE,
    full.names = TRUE,
    ignore.case = FALSE
  )

  if (length(all_matches) == 0) {
    return(NA_character_)
  }

  if (length(prefer_patterns) > 0) {
    for (pattern in prefer_patterns) {
      preferred <- all_matches[stringr::str_detect(normalizePath(all_matches, winslash = "/", mustWork = FALSE), pattern)]
      if (length(preferred) > 0) {
        return(preferred[[1]])
      }
    }
  }

  all_matches[[1]]
}


gayini_read_raster_resolution_safe <- function(file_path) {
  out <- tibble::tibble(res_x = NA_real_, res_y = NA_real_)

  if (is.na(file_path) || !file.exists(file_path)) {
    return(out)
  }

  raster_obj <- try(terra::rast(file_path), silent = TRUE)

  if (inherits(raster_obj, "try-error")) {
    return(out)
  }

  raster_res <- terra::res(raster_obj)

  tibble::tibble(
    res_x = as.numeric(raster_res[[1]]),
    res_y = as.numeric(raster_res[[2]])
  )
}


gayini_standardise_daily_inundation_catalog <- function(raster_catalog, root) {
  catalog <- raster_catalog |>
    gayini_drop_existing_daily_derived_fields()

  if (!"file_name" %in% names(catalog)) {
    if ("filename" %in% names(catalog)) {
      catalog <- dplyr::rename(catalog, file_name = .data$filename)
    } else if ("name" %in% names(catalog)) {
      catalog <- dplyr::rename(catalog, file_name = .data$name)
    } else {
      stop("Raster catalogue must contain file_name, filename, or name.", call. = FALSE)
    }
  }

  if (!"file_path" %in% names(catalog)) {
    if ("path" %in% names(catalog)) {
      catalog <- dplyr::rename(catalog, file_path = .data$path)
    } else {
      catalog$file_path <- purrr::map_chr(
        catalog$file_name,
        ~ gayini_find_project_file(
          root            = root,
          file_name       = .x,
          prefer_patterns = c("sentinel2_inundation", "daily_inundation")
        )
      )
    }
  }

  catalog <- catalog |>
    dplyr::mutate(
      file_name       = basename(.data$file_name),
      file_path       = as.character(.data$file_path),
      file_name_lower = tolower(.data$file_name),
      file_path_lower = tolower(.data$file_path),
      date_start      = gayini_parse_daily_inundation_date(.data$file_name),
      date_end        = .data$date_start,
      date_midpoint   = .data$date_start,
      water_year      = gayini_get_water_year(.data$date_start),
      product         = "daily_inundation",
      has_cloud3_name = stringr::str_detect(.data$file_name_lower, "cloud3"),
      has_ors2_name   = stringr::str_detect(.data$file_name_lower, "ors2"),
      is_daily_name   = !is.na(.data$date_start),
      is_daily_path   = stringr::str_detect(.data$file_path_lower, "sentinel2_inundation|daily_inundation"),
      is_daily_file   = .data$is_daily_name & .data$is_daily_path
    ) |>
    dplyr::filter(.data$is_daily_file)

  if (!"res_x" %in% names(catalog) || !"res_y" %in% names(catalog)) {
    resolution_rows <- purrr::map_dfr(catalog$file_path, gayini_read_raster_resolution_safe)

    catalog <- catalog |>
      dplyr::select(-dplyr::any_of(c("res_x", "res_y"))) |>
      dplyr::bind_cols(resolution_rows)
  }

  catalog <- gayini_add_daily_sensor_fields(catalog)

  catalog |>
    dplyr::arrange(.data$date_start, .data$sensor, .data$file_name)
}


## Development subset helpers ----

gayini_select_spread_plots <- function(plots_sf, n_plots = 10, include_plot_id = "GA_029") {
  plot_centres <- suppressWarnings(sf::st_point_on_surface(plots_sf))
  xy <- sf::st_coordinates(plot_centres)

  ranked <- plots_sf |>
    dplyr::mutate(
      centre_x = xy[, 1],
      centre_y = xy[, 2],
      spread_rank = dplyr::ntile(dplyr::min_rank(.data$centre_x + .data$centre_y), n_plots)
    ) |>
    dplyr::arrange(.data$spread_rank, .data$centre_x, .data$centre_y)

  selected_ids <- ranked |>
    sf::st_drop_geometry() |>
    dplyr::group_by(.data$spread_rank) |>
    dplyr::slice(1) |>
    dplyr::ungroup() |>
    dplyr::pull(.data$plot_id) |>
    unique()

  if (!is.na(include_plot_id) && include_plot_id %in% plots_sf$plot_id && !(include_plot_id %in% selected_ids)) {
    selected_ids <- c(selected_ids[-length(selected_ids)], include_plot_id)
  }

  plots_sf |>
    dplyr::filter(.data$plot_id %in% selected_ids) |>
    dplyr::arrange(.data$plot_id)
}


gayini_select_daily_inundation_dev_rasters <- function(catalog, target_n = 12) {
  if (nrow(catalog) <= target_n) {
    return(catalog)
  }

  sensor_targets <- tibble::tibble(
    sensor_pattern = c("l7", "l8", "s2", "s2_inferred"),
    target_n       = c(2L, 2L, 4L, 4L)
  )

  selected <- purrr::pmap_dfr(
    sensor_targets,
    function(sensor_pattern, target_n) {
      sensor_rows <- catalog |>
        dplyr::filter(stringr::str_detect(.data$sensor, sensor_pattern)) |>
        dplyr::arrange(.data$date_start)

      if (nrow(sensor_rows) == 0) {
        return(sensor_rows)
      }

      take_n <- min(target_n, nrow(sensor_rows))
      indices <- unique(round(seq(1, nrow(sensor_rows), length.out = take_n)))

      sensor_rows[indices, , drop = FALSE]
    }
  )

  if (nrow(selected) < target_n) {
    remaining <- catalog |>
      dplyr::anti_join(selected |> dplyr::select(.data$file_path), by = "file_path") |>
      dplyr::arrange(.data$date_start)

    needed <- target_n - nrow(selected)
    extra_indices <- unique(round(seq(1, nrow(remaining), length.out = min(needed, nrow(remaining)))))

    selected <- dplyr::bind_rows(selected, remaining[extra_indices, , drop = FALSE])
  }

  selected |>
    dplyr::distinct(.data$file_path, .keep_all = TRUE) |>
    dplyr::arrange(.data$date_start, .data$sensor, .data$file_name)
}


## Extraction helpers ----

gayini_summarise_daily_inundation_values <- function(values, coverage_fraction, explicit_nodata_values = c(255, 65535, 127, -1)) {
  if (length(values) == 0 || length(coverage_fraction) == 0) {
    return(c(
      raster_coverage_count = 0,
      value_0_not_inundated_pct = NA_real_,
      value_1_inundated_pct = NA_real_,
      value_2_ors_water_pct = NA_real_,
      value_3_cloud_shadow_pct = NA_real_,
      other_value_area_pct = NA_real_,
      explicit_nodata_area_pct = NA_real_,
      valid_interpretation_pct = NA_real_,
      daily_inundated_pct = NA_real_,
      majority_value = NA_real_,
      observed_min_value = NA_real_,
      observed_max_value = NA_real_
    ))
  }

  values <- as.numeric(values)
  coverage_fraction <- as.numeric(coverage_fraction)
  total_coverage <- sum(coverage_fraction, na.rm = TRUE)

  if (is.na(total_coverage) || total_coverage <= 0) {
    return(c(
      raster_coverage_count = 0,
      value_0_not_inundated_pct = NA_real_,
      value_1_inundated_pct = NA_real_,
      value_2_ors_water_pct = NA_real_,
      value_3_cloud_shadow_pct = NA_real_,
      other_value_area_pct = NA_real_,
      explicit_nodata_area_pct = NA_real_,
      valid_interpretation_pct = NA_real_,
      daily_inundated_pct = NA_real_,
      majority_value = NA_real_,
      observed_min_value = NA_real_,
      observed_max_value = NA_real_
    ))
  }

  is_explicit_nodata <- is.na(values) | values %in% explicit_nodata_values
  is_other_value <- !is_explicit_nodata & !(values %in% c(0, 1, 2, 3))

  pct_value <- function(target_value) {
    100 * sum(coverage_fraction[!is_explicit_nodata & values == target_value], na.rm = TRUE) / total_coverage
  }

  value_0_pct <- pct_value(0)
  value_1_pct <- pct_value(1)
  value_2_pct <- pct_value(2)
  value_3_pct <- pct_value(3)
  other_pct <- 100 * sum(coverage_fraction[is_other_value], na.rm = TRUE) / total_coverage
  explicit_nodata_pct <- 100 * sum(coverage_fraction[is_explicit_nodata], na.rm = TRUE) / total_coverage
  valid_interpretation_pct <- value_0_pct + value_1_pct + value_2_pct

  value_table <- c(
    `0` = value_0_pct,
    `1` = value_1_pct,
    `2` = value_2_pct,
    `3` = value_3_pct
  )

  majority_value <- as.numeric(names(value_table)[which.max(value_table)])

  observed_values <- values[!is_explicit_nodata]

  c(
    raster_coverage_count = total_coverage,
    value_0_not_inundated_pct = value_0_pct,
    value_1_inundated_pct = value_1_pct,
    value_2_ors_water_pct = value_2_pct,
    value_3_cloud_shadow_pct = value_3_pct,
    other_value_area_pct = other_pct,
    explicit_nodata_area_pct = explicit_nodata_pct,
    valid_interpretation_pct = valid_interpretation_pct,
    daily_inundated_pct = value_1_pct,
    majority_value = majority_value,
    observed_min_value = ifelse(length(observed_values) == 0, NA_real_, min(observed_values, na.rm = TRUE)),
    observed_max_value = ifelse(length(observed_values) == 0, NA_real_, max(observed_values, na.rm = TRUE))
  )
}


gayini_assign_daily_coverage_status <- function(valid_interpretation_pct) {
  dplyr::case_when(
    is.na(valid_interpretation_pct) ~ "no_raster_coverage",
    valid_interpretation_pct >= 75 ~ "adequate_coverage",
    valid_interpretation_pct >= 50 ~ "low_coverage",
    valid_interpretation_pct >= 25 ~ "very_low_coverage",
    TRUE ~ "no_valid_interpretation_coverage"
  )
}


gayini_daily_summary_columns <- function() {
  c(
    "raster_coverage_count",
    "value_0_not_inundated_pct",
    "value_1_inundated_pct",
    "value_2_ors_water_pct",
    "value_3_cloud_shadow_pct",
    "other_value_area_pct",
    "explicit_nodata_area_pct",
    "valid_interpretation_pct",
    "daily_inundated_pct",
    "majority_value",
    "observed_min_value",
    "observed_max_value"
  )
}


gayini_normalise_daily_summary_output <- function(summary_values) {
  expected_cols <- gayini_daily_summary_columns()

  if (is.list(summary_values) && !inherits(summary_values, "data.frame") && length(summary_values) == 1) {
    summary_values <- summary_values[[1]]
  }

  if (is.matrix(summary_values)) {

    summary_matrix <- summary_values

    if (ncol(summary_matrix) == 1 && !is.null(rownames(summary_matrix)) && all(expected_cols %in% rownames(summary_matrix))) {
      summary_values <- as.list(as.numeric(summary_matrix[expected_cols, 1]))
      names(summary_values) <- expected_cols
      summary_tbl <- tibble::as_tibble(summary_values)
      return(summary_tbl)
    }

    if (nrow(summary_matrix) == 1 && !is.null(colnames(summary_matrix)) && all(expected_cols %in% colnames(summary_matrix))) {
      summary_tbl <- tibble::as_tibble(as.data.frame(summary_matrix), .name_repair = "minimal")
      return(summary_tbl)
    }

    summary_tbl <- tibble::as_tibble(as.data.frame(summary_matrix), .name_repair = "minimal")

  } else if (is.atomic(summary_values) && !is.null(names(summary_values))) {

    summary_tbl <- tibble::as_tibble(as.data.frame(as.list(summary_values)), .name_repair = "minimal")

  } else {

    summary_tbl <- tibble::as_tibble(as.data.frame(summary_values), .name_repair = "minimal")

  }

  if (!"valid_interpretation_pct" %in% names(summary_tbl) && ncol(summary_tbl) == length(expected_cols)) {
    names(summary_tbl) <- expected_cols
  }

  missing_cols <- setdiff(expected_cols, names(summary_tbl))

  if (length(missing_cols) > 0) {
    stop(
      "Daily inundation summary output is missing expected columns: ",
      paste(missing_cols, collapse = ", "),
      ". Existing columns are: ",
      paste(names(summary_tbl), collapse = ", "),
      call. = FALSE
    )
  }

  summary_tbl |>
    dplyr::select(dplyr::all_of(expected_cols))
}


gayini_extract_daily_inundation_raster <- function(raster_row, plots_sf, explicit_nodata_values = c(255, 65535, 127, -1)) {
  raster_path <- raster_row$file_path[[1]]

  if (is.na(raster_path) || !file.exists(raster_path)) {
    stop("Raster file does not exist: ", raster_path, call. = FALSE)
  }

  raster_obj <- terra::rast(raster_path)
  raster_res <- terra::res(raster_obj)
  raster_crs <- terra::crs(raster_obj)

  plots_raster_crs <- sf::st_transform(plots_sf, raster_crs)

  plot_rows <- purrr::map_dfr(
    seq_len(nrow(plots_raster_crs)),
    function(i) {
      one_plot <- plots_raster_crs[i, ]

      summary_values <- exactextractr::exact_extract(
        raster_obj,
        one_plot,
        fun = function(values, coverage_fraction) {
          gayini_summarise_daily_inundation_values(
            values                 = values,
            coverage_fraction      = coverage_fraction,
            explicit_nodata_values = explicit_nodata_values
          )
        }
      )

      summary_values <- gayini_normalise_daily_summary_output(summary_values)

      summary_values |>
        dplyr::mutate(plot_id = one_plot$plot_id[[1]], .before = 1)
    }
  )

  plot_rows |>
    dplyr::mutate(
      file_name = raster_row$file_name[[1]],
      file_path = raster_row$file_path[[1]],
      product = "daily_inundation",
      sensor = raster_row$sensor[[1]],
      sensor_evidence = raster_row$sensor_evidence[[1]],
      date_start = raster_row$date_start[[1]],
      date_end = raster_row$date_end[[1]],
      date_midpoint = raster_row$date_midpoint[[1]],
      water_year = raster_row$water_year[[1]],
      has_cloud3_name = raster_row$has_cloud3_name[[1]],
      has_ors2_name = raster_row$has_ors2_name[[1]],
      raster_res_x = as.numeric(raster_res[[1]]),
      raster_res_y = as.numeric(raster_res[[2]]),
      valid_coverage_status = gayini_assign_daily_coverage_status(.data$valid_interpretation_pct),
      wet_value_assumption = "value_1_only",
      daily_inundated_definition = "daily_inundated_pct = value_1_inundated_pct",
      value_2_handling = "off_river_storage_water_kept_separate",
      value_3_handling = "cloud_shadow_excluded_from_daily_inundated_pct",
      legend_status = "likely_seed_metadata_unconfirmed_by_adrian"
    ) |>
    dplyr::select(
      .data$plot_id,
      .data$date_start,
      .data$date_end,
      .data$date_midpoint,
      .data$water_year,
      .data$product,
      .data$sensor,
      .data$sensor_evidence,
      .data$file_name,
      .data$file_path,
      .data$raster_res_x,
      .data$raster_res_y,
      .data$has_cloud3_name,
      .data$has_ors2_name,
      .data$value_0_not_inundated_pct,
      .data$value_1_inundated_pct,
      .data$value_2_ors_water_pct,
      .data$value_3_cloud_shadow_pct,
      .data$other_value_area_pct,
      .data$explicit_nodata_area_pct,
      .data$valid_interpretation_pct,
      .data$daily_inundated_pct,
      .data$majority_value,
      .data$observed_min_value,
      .data$observed_max_value,
      .data$valid_coverage_status,
      .data$raster_coverage_count,
      .data$wet_value_assumption,
      .data$daily_inundated_definition,
      .data$value_2_handling,
      .data$value_3_handling,
      .data$legend_status
    )
}


gayini_extract_daily_inundation_collection <- function(raster_catalog, plots_sf, explicit_nodata_values = c(255, 65535, 127, -1)) {
  purrr::map_dfr(
    seq_len(nrow(raster_catalog)),
    function(i) {
      message("Extracting daily inundation raster ", i, " of ", nrow(raster_catalog), ": ", raster_catalog$file_name[[i]])

      extraction_start_time <- Sys.time()

      raster_output <- gayini_extract_daily_inundation_raster(
        raster_row             = raster_catalog[i, ],
        plots_sf               = plots_sf,
        explicit_nodata_values = explicit_nodata_values
      )

      extraction_elapsed_seconds <- as.numeric(
        difftime(Sys.time(), extraction_start_time, units = "secs")
      )

      raster_output |>
        dplyr::mutate(
          extraction_elapsed_seconds = .env$extraction_elapsed_seconds
        )
    }
  )
}


## Check helpers ----

gayini_make_daily_inundation_checks <- function(extraction, expected_rows) {
  value_sum <- extraction |>
    dplyr::mutate(
      value_area_sum = .data$value_0_not_inundated_pct +
        .data$value_1_inundated_pct +
        .data$value_2_ors_water_pct +
        .data$value_3_cloud_shadow_pct +
        .data$other_value_area_pct +
        .data$explicit_nodata_area_pct
    )

  tibble::tibble(
    check = c(
      "rows_expected",
      "rows_actual",
      "row_count_matches",
      "unique_plots",
      "unique_rasters",
      "no_raster_coverage_rows",
      "low_or_worse_coverage_rows",
      "unexpected_value_rows",
      "daily_inundated_out_of_range_rows",
      "value_area_sum_min",
      "value_area_sum_max",
      "legend_confirmed"
    ),
    value = c(
      expected_rows,
      nrow(extraction),
      nrow(extraction) == expected_rows,
      dplyr::n_distinct(extraction$plot_id),
      dplyr::n_distinct(extraction$file_name),
      sum(extraction$valid_coverage_status == "no_raster_coverage", na.rm = TRUE),
      sum(!extraction$valid_coverage_status %in% c("adequate_coverage"), na.rm = TRUE),
      sum(extraction$other_value_area_pct > 0, na.rm = TRUE),
      sum(extraction$daily_inundated_pct < 0 | extraction$daily_inundated_pct > 100, na.rm = TRUE),
      round(min(value_sum$value_area_sum, na.rm = TRUE), 6),
      round(max(value_sum$value_area_sum, na.rm = TRUE), 6),
      FALSE
    )
  )
}
