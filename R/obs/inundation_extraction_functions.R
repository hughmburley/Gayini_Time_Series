## -----------------------------------------------------------------------------
## Gayini inundation extraction functions
## -----------------------------------------------------------------------------


## These functions support the 05-series and 06-series inundation scripts.


## Inundation rasters are coded rasters, not continuous surfaces.


## For Landsat annual inundation, Adrian's working description is that pixel
## values are ordinal / whole-number counts of inundation observations within a
## water year. The primary plot metric is therefore the area percentage of the
## plot with count > 0, while preserving count-specific area percentages.


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


## Catalogue standardisation helpers ----


gayini_first_existing_column <- function(x, candidate_columns) {
  existing_columns <- candidate_columns[candidate_columns %in% names(x)]

  if (length(existing_columns) == 0) {
    return(NA_character_)
  }

  existing_columns[[1]]
}


gayini_infer_inundation_product <- function(file_path, file_name) {
  file_path_lower <- tolower(file_path)
  file_name_lower <- tolower(file_name)

  dplyr::case_when(
    grepl("landsat_inundation", file_path_lower) ~ "landsat_inundation",
    grepl("sentinel2_inundation", file_path_lower) ~ "daily_inundation",
    grepl("^lo_[0-9]{8}", file_name_lower) ~ "daily_inundation",
    grepl("^lo_[0-9]{4}_[0-9]{4}", file_name_lower) ~ "landsat_inundation",
    TRUE ~ NA_character_
  )
}


gayini_infer_inundation_sensor <- function(file_path, file_name, product = NA_character_) {
  file_path_lower <- tolower(file_path)
  file_name_lower <- tolower(file_name)
  combined_text   <- paste(file_path_lower, file_name_lower)

  dplyr::case_when(
    grepl("_s2_|sentinel", combined_text) ~ "s2",
    grepl("_l9_|landsat[_ -]?9|\\bl9\\b", combined_text) ~ "l9",
    grepl("_l8_|landsat[_ -]?8|\\bl8\\b", combined_text) ~ "l8",
    grepl("_l7_|landsat[_ -]?7|\\bl7\\b", combined_text) ~ "l7",
    grepl("_l5_|landsat[_ -]?5|\\bl5\\b", combined_text) ~ "l5",
    product == "landsat_inundation" ~ "landsat_annual",
    product == "daily_inundation" ~ "unknown",
    TRUE ~ NA_character_
  )
}


gayini_standardise_inundation_catalog <- function(raster_catalog) {
  gayini_check_required_columns(
    raster_catalog,
    c("file_path", "file_name"),
    object_name = "raster_catalog"
  )

  output_catalog <- raster_catalog

  product_source_column <- gayini_first_existing_column(
    output_catalog,
    c("product", "raster_product", "product_type", "dataset")
  )

  if (is.na(product_source_column)) {
    output_catalog$product <- NA_character_
  } else {
    output_catalog$product <- as.character(output_catalog[[product_source_column]])
  }

  output_catalog$product <- dplyr::if_else(
    is.na(output_catalog$product) | output_catalog$product == "",
    gayini_infer_inundation_product(output_catalog$file_path, output_catalog$file_name),
    output_catalog$product
  )

  output_catalog$product <- dplyr::case_when(
    output_catalog$product == "sentinel2_inundation" ~ "daily_inundation",
    TRUE ~ output_catalog$product
  )

  sensor_source_column <- gayini_first_existing_column(
    output_catalog,
    c("sensor", "platform", "satellite")
  )

  if (is.na(sensor_source_column)) {
    output_catalog$sensor <- NA_character_
  } else {
    output_catalog$sensor <- as.character(output_catalog[[sensor_source_column]])
  }

  output_catalog$sensor <- dplyr::if_else(
    is.na(output_catalog$sensor) | output_catalog$sensor == "",
    gayini_infer_inundation_sensor(
      file_path = output_catalog$file_path,
      file_name = output_catalog$file_name,
      product = output_catalog$product
    ),
    output_catalog$sensor
  )

  output_catalog
}


## Plot-selection helpers ----


gayini_select_spread_plots <- function(plots_sf,
                                       n_plots = 10,
                                       include_plot_ids = c("GA_029")) {
  gayini_check_required_columns(
    plots_sf,
    c("plot_id"),
    object_name = "plots_sf"
  )

  if (nrow(plots_sf) <= n_plots) {
    return(plots_sf |> dplyr::arrange(.data$plot_id))
  }

  representative_points <- sf::st_point_on_surface(sf::st_geometry(plots_sf))
  representative_xy     <- sf::st_coordinates(representative_points)

  plot_index <- tibble::tibble(
    row_id  = seq_len(nrow(plots_sf)),
    plot_id = plots_sf$plot_id,
    x       = representative_xy[, 1],
    y       = representative_xy[, 2]
  )

  included_rows <- plot_index |>
    dplyr::filter(.data$plot_id %in% include_plot_ids) |>
    dplyr::pull(.data$row_id)

  if (length(included_rows) == 0) {
    included_rows <- plot_index$row_id[[1]]
  }

  selected_rows <- unique(included_rows)

  scaled_xy       <- scale(plot_index[, c("x", "y")])
  distance_matrix <- as.matrix(stats::dist(scaled_xy))

  while (length(selected_rows) < n_plots) {
    candidate_rows <- setdiff(plot_index$row_id, selected_rows)

    min_distance_to_selected <- vapply(
      candidate_rows,
      function(candidate_row) {
        min(distance_matrix[candidate_row, selected_rows], na.rm = TRUE)
      },
      numeric(1)
    )

    next_row      <- candidate_rows[which.max(min_distance_to_selected)]
    selected_rows <- c(selected_rows, next_row)
  }

  plots_sf[selected_rows, ] |>
    dplyr::arrange(.data$plot_id)
}


## Count and coverage helpers ----


gayini_make_inundation_count_columns <- function(count_values) {
  paste0("count_", count_values, "_area_pct")
}


gayini_count_fraction_summary <- function(values,
                                          coverage_fraction,
                                          count_values = 0:3,
                                          nodata_values = c(255)) {
  values            <- as.numeric(values)
  coverage_fraction <- as.numeric(coverage_fraction)

  valid_index <- !is.na(values) &
    !values %in% nodata_values &
    !is.na(coverage_fraction) &
    coverage_fraction > 0

  valid_values <- values[valid_index]
  valid_cov    <- coverage_fraction[valid_index]
  output_names <- gayini_make_inundation_count_columns(count_values)

  if (length(valid_values) == 0 || sum(valid_cov) <= 0) {
    output <- rep(NA_real_, length(output_names))
    names(output) <- output_names

    return(c(
      valid_coverage_count  = 0,
      output,
      other_count_area_pct  = NA_real_,
      inundated_any_pct     = NA_real_,
      mean_inundation_count = NA_real_,
      max_inundation_count  = NA_real_,
      majority_count        = NA_real_,
      n_valid_counts        = 0,
      min_count             = NA_real_,
      max_count             = NA_real_
    ))
  }

  total_cov <- sum(valid_cov)

  count_pct <- vapply(
    count_values,
    function(count_value) {
      100 * sum(valid_cov[valid_values == count_value]) / total_cov
    },
    numeric(1)
  )

  names(count_pct) <- output_names

  tabulated_counts <- sort(unique(valid_values))
  count_weights    <- vapply(
    tabulated_counts,
    function(count_value) {
      sum(valid_cov[valid_values == count_value])
    },
    numeric(1)
  )

  majority_count        <- tabulated_counts[which.max(count_weights)]
  other_count_area_pct  <- 100 * sum(valid_cov[!valid_values %in% count_values]) / total_cov
  inundated_any_pct     <- 100 * sum(valid_cov[valid_values > 0]) / total_cov
  mean_inundation_count <- stats::weighted.mean(valid_values, valid_cov)
  max_inundation_count  <- max(valid_values)

  c(
    valid_coverage_count  = total_cov,
    count_pct,
    other_count_area_pct  = other_count_area_pct,
    inundated_any_pct     = inundated_any_pct,
    mean_inundation_count = mean_inundation_count,
    max_inundation_count  = max_inundation_count,
    majority_count        = majority_count,
    n_valid_counts        = length(tabulated_counts),
    min_count             = min(valid_values),
    max_count             = max(valid_values)
  )
}


gayini_make_inundation_coverage_status <- function(valid_coverage_count,
                                                   expected_coverage_count,
                                                   very_low_pct = 25,
                                                   adequate_pct = 75) {
  valid_coverage_pct <- 100 * valid_coverage_count / expected_coverage_count

  dplyr::case_when(
    is.na(valid_coverage_count) | valid_coverage_count <= 0 ~ "no_valid_coverage",
    is.na(expected_coverage_count) | expected_coverage_count <= 0 ~ "coverage_unknown",
    valid_coverage_pct < very_low_pct ~ "very_low_coverage",
    valid_coverage_pct < adequate_pct ~ "low_coverage",
    TRUE ~ "adequate_coverage"
  )
}


gayini_extract_one_plot_landsat_inundation <- function(raster_layer,
                                                       plot_sf,
                                                       count_values = 0:3,
                                                       nodata_values = c(255)) {
  plot_extract <- exactextractr::exact_extract(
    raster_layer,
    plot_sf,
    progress = FALSE
  )[[1]]

  if (is.null(plot_extract) || nrow(plot_extract) == 0) {
    return(gayini_count_fraction_summary(
      values = numeric(0),
      coverage_fraction = numeric(0),
      count_values = count_values,
      nodata_values = nodata_values
    ))
  }

  if (!"coverage_fraction" %in% names(plot_extract)) {
    stop("exactextractr output is missing coverage_fraction.", call. = FALSE)
  }

  value_column <- setdiff(names(plot_extract), "coverage_fraction")[[1]]

  gayini_count_fraction_summary(
    values = plot_extract[[value_column]],
    coverage_fraction = plot_extract$coverage_fraction,
    count_values = count_values,
    nodata_values = nodata_values
  )
}


## Raster extraction ----


gayini_extract_landsat_inundation_raster <- function(raster_info,
                                                     plots_sf,
                                                     count_values = 0:3,
                                                     nodata_values = c(255),
                                                     buffer_pixels = 0,
                                                     extraction_scope = "development_smoke_test",
                                                     legend_status = "unconfirmed",
                                                     very_low_pct = 25,
                                                     adequate_pct = 75) {
  gayini_check_required_columns(
    raster_info,
    c("file_path", "file_name", "product", "sensor"),
    object_name = "raster_info"
  )

  gayini_check_required_columns(
    plots_sf,
    c("plot_id", "area_ha"),
    object_name = "plots_sf"
  )

  raster_path <- raster_info$file_path[[1]]

  if (!file.exists(raster_path)) {
    stop("Raster file does not exist: ", raster_path, call. = FALSE)
  }

  raster_layer <- terra::rast(raster_path)

  if (terra::nlyr(raster_layer) != 1) {
    stop(
      "Expected one inundation raster band, but found ",
      terra::nlyr(raster_layer),
      " in: ",
      raster_info$file_name[[1]],
      call. = FALSE
    )
  }

  names(raster_layer) <- "inundation_count"

  raster_crs   <- terra::crs(raster_layer)
  raster_res   <- terra::res(raster_layer)
  cell_area_m2 <- abs(raster_res[[1]] * raster_res[[2]])

  plots_for_raster <- sf::st_transform(plots_sf, crs = raster_crs)

  if (buffer_pixels > 0) {
    buffer_distance  <- buffer_pixels * max(abs(raster_res))
    plots_for_raster <- sf::st_buffer(plots_for_raster, dist = buffer_distance)
  }

  extracted_list <- lapply(
    seq_len(nrow(plots_for_raster)),
    function(i) {
      summary_vector <- gayini_extract_one_plot_landsat_inundation(
        raster_layer = raster_layer,
        plot_sf = plots_for_raster[i, ],
        count_values = count_values,
        nodata_values = nodata_values
      )

      tibble::as_tibble_row(as.list(summary_vector), .name_repair = "unique")
    }
  )

  extracted <- dplyr::bind_rows(extracted_list)

  expected_coverage_count <- (plots_sf$area_ha * 10000) / cell_area_m2

  extracted <- extracted |>
    dplyr::mutate(
      plot_id                 = plots_sf$plot_id,
      plot_area_ha            = plots_sf$area_ha,
      expected_coverage_count = expected_coverage_count,
      valid_coverage_pct      = 100 * .data$valid_coverage_count / .data$expected_coverage_count,
      valid_coverage_status   = gayini_make_inundation_coverage_status(
        valid_coverage_count = .data$valid_coverage_count,
        expected_coverage_count = .data$expected_coverage_count,
        very_low_pct = very_low_pct,
        adequate_pct = adequate_pct
      )
    ) |>
    dplyr::mutate(
      product           = raster_info$product[[1]],
      sensor            = raster_info$sensor[[1]],
      date_start        = raster_info$date_start[[1]],
      date_end          = raster_info$date_end[[1]],
      water_year        = raster_info$water_year[[1]],
      file_name         = raster_info$file_name[[1]],
      file_path         = raster_info$file_path[[1]],
      raster_crs        = raster_crs,
      raster_res_x      = raster_res[[1]],
      raster_res_y      = raster_res[[2]],
      buffer_pixels     = buffer_pixels,
      engine_used       = "exactextractr",
      summary_method    = "area_fraction_by_count",
      primary_metric    = "inundated_any_pct",
      secondary_method  = "majority_count_diagnostic",
      legend_status     = legend_status,
      extraction_scope  = extraction_scope,
      value_semantics   = "annual_inundation_count"
    ) |>
    dplyr::select(
      plot_id,
      plot_area_ha,
      product,
      sensor,
      date_start,
      date_end,
      water_year,
      file_name,
      count_0_area_pct,
      count_1_area_pct,
      count_2_area_pct,
      count_3_area_pct,
      other_count_area_pct,
      inundated_any_pct,
      mean_inundation_count,
      max_inundation_count,
      majority_count,
      n_valid_counts,
      min_count,
      max_count,
      valid_coverage_count,
      expected_coverage_count,
      valid_coverage_pct,
      valid_coverage_status,
      buffer_pixels,
      engine_used,
      summary_method,
      primary_metric,
      secondary_method,
      legend_status,
      value_semantics,
      extraction_scope,
      raster_crs,
      raster_res_x,
      raster_res_y,
      file_path
    )

  extracted
}


gayini_extract_landsat_inundation_collection <- function(raster_catalog,
                                                         plots_sf,
                                                         count_values = 0:3,
                                                         nodata_values = c(255),
                                                         buffer_pixels = 0,
                                                         extraction_scope = "development_smoke_test",
                                                         legend_status = "unconfirmed",
                                                         very_low_pct = 25,
                                                         adequate_pct = 75) {
  output_list <- vector("list", nrow(raster_catalog))

  for (i in seq_len(nrow(raster_catalog))) {
    message(
      "Extracting Landsat annual inundation raster ",
      i,
      " of ",
      nrow(raster_catalog),
      ": ",
      raster_catalog$file_name[[i]]
    )

    output_list[[i]] <- gayini_extract_landsat_inundation_raster(
      raster_info = raster_catalog[i, , drop = FALSE],
      plots_sf = plots_sf,
      count_values = count_values,
      nodata_values = nodata_values,
      buffer_pixels = buffer_pixels,
      extraction_scope = extraction_scope,
      legend_status = legend_status,
      very_low_pct = very_low_pct,
      adequate_pct = adequate_pct
    )
  }

  dplyr::bind_rows(output_list)
}


## Diagnostics ----


gayini_make_landsat_inundation_checks <- function(extraction_output,
                                                  expected_rows,
                                                  expected_count_columns = paste0("count_", 0:3, "_area_pct")) {
  count_column_check <- all(expected_count_columns %in% names(extraction_output))

  unexpected_count_rows <- extraction_output |>
    dplyr::filter(!is.na(.data$other_count_area_pct), .data$other_count_area_pct > 0)

  no_valid_rows <- extraction_output |>
    dplyr::filter(.data$valid_coverage_status == "no_valid_coverage")

  low_coverage_rows <- extraction_output |>
    dplyr::filter(.data$valid_coverage_status %in% c("very_low_coverage", "low_coverage"))

  inundated_any_problem_rows <- extraction_output |>
    dplyr::filter(!is.na(.data$inundated_any_pct), (.data$inundated_any_pct < 0 | .data$inundated_any_pct > 100))

  tibble::tibble(
    check_name = c(
      "expected_rows",
      "actual_rows",
      "row_count_matches",
      "count_columns_present",
      "no_valid_coverage_rows",
      "low_or_very_low_coverage_rows",
      "unexpected_count_rows",
      "inundated_any_pct_out_of_range_rows",
      "legend_confirmed"
    ),
    check_value = c(
      expected_rows,
      nrow(extraction_output),
      nrow(extraction_output) == expected_rows,
      count_column_check,
      nrow(no_valid_rows),
      nrow(low_coverage_rows),
      nrow(unexpected_count_rows),
      nrow(inundated_any_problem_rows),
      "FALSE"
    )
  )
}


gayini_make_landsat_inundation_count_summary <- function(extraction_output) {
  extraction_output |>
    dplyr::summarise(
      rows                         = dplyr::n(),
      mean_count_0_area_pct        = mean(.data$count_0_area_pct, na.rm = TRUE),
      mean_count_1_area_pct        = mean(.data$count_1_area_pct, na.rm = TRUE),
      mean_count_2_area_pct        = mean(.data$count_2_area_pct, na.rm = TRUE),
      mean_count_3_area_pct        = mean(.data$count_3_area_pct, na.rm = TRUE),
      mean_other_count_area_pct    = mean(.data$other_count_area_pct, na.rm = TRUE),
      mean_inundated_any_pct       = mean(.data$inundated_any_pct, na.rm = TRUE),
      mean_inundation_count        = mean(.data$mean_inundation_count, na.rm = TRUE),
      no_valid_coverage_rows       = sum(.data$valid_coverage_status == "no_valid_coverage", na.rm = TRUE),
      low_coverage_rows            = sum(.data$valid_coverage_status %in% c("very_low_coverage", "low_coverage"), na.rm = TRUE),
      .by = c("product", "sensor", "file_name", "date_start", "date_end", "water_year")
    ) |>
    dplyr::arrange(.data$date_start, .data$file_name)
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


gayini_make_inundation_coverage_summary <- function(extraction_output) {
  extraction_output |>
    dplyr::summarise(
      rows                      = dplyr::n(),
      median_valid_coverage_pct = median(.data$valid_coverage_pct, na.rm = TRUE),
      min_valid_coverage_pct    = gayini_safe_min(.data$valid_coverage_pct),
      max_valid_coverage_pct    = gayini_safe_max(.data$valid_coverage_pct),
      .by = c("plot_id", "valid_coverage_status")
    ) |>
    dplyr::arrange(.data$plot_id, .data$valid_coverage_status)
}
