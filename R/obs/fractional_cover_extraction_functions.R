## -----------------------------------------------------------------------------
## Gayini fractional-cover extraction functions
## -----------------------------------------------------------------------------


## These functions support the 04-series fractional / ground-cover scripts.


## The first scripts test fractional-cover extraction before scaling up.


## It should run on a small development subset of Landsat fractional-cover rasters
## and a small number of plots before we scale to all plots and all rasters.


## Files in R/ should define functions only. They should not run the workflow.


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


## Extraction-setting helpers ----


gayini_read_extraction_settings <- function(extraction_settings_path) {
  if (!file.exists(extraction_settings_path)) {
    warning(
      "Extraction settings file not found. Using script defaults: ",
      extraction_settings_path,
      call. = FALSE
    )

    return(tibble::tibble(setting_name = character(), setting_value = character()))
  }

  readr::read_csv(extraction_settings_path, show_col_types = FALSE)
}


gayini_get_extraction_setting <- function(extraction_settings,
                                          setting_name,
                                          default_value) {
  if (!all(c("setting_name", "setting_value") %in% names(extraction_settings))) {
    return(default_value)
  }

  setting_row <- extraction_settings |>
    dplyr::filter(.data$setting_name == .env$setting_name)

  if (nrow(setting_row) == 0) {
    return(default_value)
  }

  setting_value <- setting_row$setting_value[1]

  if (is.na(setting_value) || setting_value == "") {
    return(default_value)
  }

  setting_value
}


## Method-name helper ----


gayini_normalise_fc_summary_methods <- function(primary_method = "mean",
                                                secondary_method = "median") {
  ## exactextractr::exact_extract() uses "mean" and "median" for summaries
  ## that are weighted internally by polygon coverage fraction.

  ## Earlier planning documents used "weighted_mean" and "weighted_median" as
  ## plain-English labels. This helper maps those labels to exactextractr names.

  method_lookup <- c(
    weighted_mean   = "mean",
    weighted_median = "median",
    mean            = "mean",
    median          = "median"
  )

  primary_method_normalised <- unname(method_lookup[[primary_method]])
  secondary_method_normalised <- unname(method_lookup[[secondary_method]])

  if (is.null(primary_method_normalised)) {
    stop("Unsupported primary fractional-cover summary method: ", primary_method, call. = FALSE)
  }

  if (is.null(secondary_method_normalised)) {
    stop("Unsupported secondary fractional-cover summary method: ", secondary_method, call. = FALSE)
  }

  unique(c(primary_method_normalised, secondary_method_normalised, "count"))
}


## Fractional-cover band lookup ----


gayini_read_fractional_cover_band_lookup <- function(band_lookup_path,
                                                     n_bands = 3) {
  default_lookup <- tibble::tibble(
    band_number      = seq_len(n_bands),
    assumed_variable = paste0("band_", seq_len(n_bands)),
    confirmed        = FALSE,
    notes            = "Default placeholder. Confirm band meaning before interpretation."
  )

  if (!file.exists(band_lookup_path)) {
    warning(
      "Fractional-cover band lookup not found. Using placeholder band labels: ",
      band_lookup_path,
      call. = FALSE
    )

    return(default_lookup)
  }

  band_lookup <- readr::read_csv(band_lookup_path, show_col_types = FALSE)

  required_columns <- c("band_number", "assumed_variable", "confirmed")

  if (!all(required_columns %in% names(band_lookup))) {
    warning(
      "Fractional-cover band lookup is missing required columns. Using placeholder band labels.",
      call. = FALSE
    )

    return(default_lookup)
  }

  band_lookup |>
    dplyr::mutate(
      band_number      = as.integer(band_number),
      assumed_variable = as.character(assumed_variable),
      confirmed        = as.logical(confirmed)
    ) |>
    dplyr::filter(band_number %in% seq_len(n_bands)) |>
    dplyr::right_join(
      default_lookup |> dplyr::select(band_number),
      by = "band_number"
    ) |>
    dplyr::mutate(
      assumed_variable = dplyr::if_else(
        is.na(assumed_variable),
        paste0("band_", band_number),
        assumed_variable
      ),
      confirmed = dplyr::if_else(is.na(confirmed), FALSE, confirmed),
      notes     = dplyr::if_else(is.na(notes), "", as.character(notes))
    ) |>
    dplyr::arrange(band_number)
}


## Test-plot selector ----


gayini_select_fractional_cover_test_plots <- function(plots_sf,
                                                      preferred_plot_ids = c("GA_029"),
                                                      n_plots = 3) {
  gayini_check_required_columns(plots_sf, c("plot_id"), object_name = "plots_sf")

  plots_ordered <- plots_sf |>
    dplyr::arrange(plot_id)

  preferred_plots <- plots_ordered |>
    dplyr::filter(plot_id %in% preferred_plot_ids)

  if (nrow(preferred_plots) == 0 && length(preferred_plot_ids) > 0) {
    warning(
      "None of the preferred test plots were found: ",
      paste(preferred_plot_ids, collapse = ", "),
      call. = FALSE
    )
  }

  if ("treatment" %in% names(plots_ordered)) {
    representative_plots <- plots_ordered |>
      dplyr::filter(!plot_id %in% preferred_plots$plot_id) |>
      dplyr::group_by(.data$treatment) |>
      dplyr::slice(1) |>
      dplyr::ungroup()
  } else {
    representative_plots <- plots_ordered |>
      dplyr::filter(!plot_id %in% preferred_plots$plot_id)
  }

  selected_plots <- dplyr::bind_rows(preferred_plots, representative_plots) |>
    dplyr::distinct(plot_id, .keep_all = TRUE) |>
    dplyr::slice_head(n = n_plots)

  if (nrow(selected_plots) < n_plots) {
    extra_plots <- plots_ordered |>
      dplyr::filter(!plot_id %in% selected_plots$plot_id) |>
      dplyr::slice_head(n = n_plots - nrow(selected_plots))

    selected_plots <- dplyr::bind_rows(selected_plots, extra_plots) |>
      dplyr::distinct(plot_id, .keep_all = TRUE) |>
      dplyr::slice_head(n = n_plots)
  }

  selected_plots
}


## Plot buffer helper ----


gayini_apply_pixel_buffer <- function(plots_sf,
                                      raster,
                                      buffer_pixels = 0) {
  if (buffer_pixels == 0) {
    return(plots_sf)
  }

  if (sf::st_is_longlat(plots_sf)) {
    stop(
      "Pixel buffering is not allowed for longitude/latitude plot geometries. ",
      "Transform plots to a projected CRS first.",
      call. = FALSE
    )
  }

  raster_resolution <- terra::res(raster)
  buffer_distance   <- max(abs(raster_resolution), na.rm = TRUE) * buffer_pixels

  sf::st_buffer(plots_sf, dist = buffer_distance)
}


## Raster CRS helper ----


gayini_transform_plots_to_raster <- function(plots_sf, raster) {
  raster_crs <- terra::crs(raster)

  if (is.na(raster_crs) || raster_crs == "") {
    stop("Raster CRS is missing. Cannot safely extract by polygon.", call. = FALSE)
  }

  sf::st_transform(plots_sf, crs = raster_crs)
}


## Single-raster fractional-cover extraction ----


gayini_extract_fractional_cover_raster <- function(raster_row,
                                                   plots_sf,
                                                   band_lookup,
                                                   summary_methods = c("mean", "median", "count"),
                                                   buffer_pixels = 0,
                                                   value_scale_factor = 1,
                                                   extraction_scope = "development_smoke_test") {
  gayini_check_required_columns(
    raster_row,
    c(
      "file_path",
      "file_name",
      "product",
      "sensor",
      "date_start",
      "date_end",
      "water_year"
    ),
    object_name = "raster_row"
  )

  raster_path <- raster_row$file_path[1]

  if (!file.exists(raster_path)) {
    stop("Raster file not found: ", raster_path, call. = FALSE)
  }

  raster <- terra::rast(raster_path)

  plots_for_raster <- plots_sf |>
    gayini_transform_plots_to_raster(raster) |>
    gayini_apply_pixel_buffer(raster = raster, buffer_pixels = buffer_pixels)

  n_bands <- terra::nlyr(raster)

  band_lookup_for_raster <- band_lookup |>
    dplyr::filter(band_number %in% seq_len(n_bands))

  if (nrow(band_lookup_for_raster) < n_bands) {
    missing_bands <- setdiff(seq_len(n_bands), band_lookup_for_raster$band_number)

    band_lookup_for_raster <- dplyr::bind_rows(
      band_lookup_for_raster,
      tibble::tibble(
        band_number      = missing_bands,
        assumed_variable = paste0("band_", missing_bands),
        confirmed        = FALSE,
        notes            = "Placeholder band label created during extraction."
      )
    ) |>
      dplyr::arrange(band_number)
  }

  extraction_list <- vector("list", n_bands)

  for (band_index in seq_len(n_bands)) {
    raster_band <- raster[[band_index]]
    names(raster_band) <- "value"

    band_info <- band_lookup_for_raster |>
      dplyr::filter(band_number == band_index) |>
      dplyr::slice(1)

    extracted <- exactextractr::exact_extract(
      raster_band,
      plots_for_raster,
      fun        = summary_methods,
      append_cols = "plot_id",
      force_df   = TRUE,
      progress   = FALSE
    )

    extracted <- extracted |>
      dplyr::mutate(
        band_number            = band_index,
        band_label             = band_info$assumed_variable[1],
        band_confirmed         = band_info$confirmed[1],
        band_notes             = band_info$notes[1],
        mean_raw               = .data$mean,
        median_raw             = .data$median,
        valid_coverage_count   = .data$count,
        mean_value             = .data$mean * value_scale_factor,
        median_value           = .data$median * value_scale_factor,
        value_scale_factor     = value_scale_factor,
        buffer_pixels          = buffer_pixels,
        engine_used            = "exactextractr",
        extraction_scope       = extraction_scope,
        summary_method_primary = "mean",
        summary_method_secondary = "median"
      ) |>
      dplyr::select(
        plot_id,
        band_number,
        band_label,
        band_confirmed,
        band_notes,
        mean_raw,
        median_raw,
        mean_value,
        median_value,
        valid_coverage_count,
        value_scale_factor,
        buffer_pixels,
        engine_used,
        extraction_scope,
        summary_method_primary,
        summary_method_secondary
      )

    extraction_list[[band_index]] <- extracted
  }

  dplyr::bind_rows(extraction_list) |>
    dplyr::mutate(
      file_path      = raster_row$file_path[1],
      file_name      = raster_row$file_name[1],
      product        = raster_row$product[1],
      sensor         = raster_row$sensor[1],
      date_start     = as.Date(raster_row$date_start[1]),
      date_end       = as.Date(raster_row$date_end[1]),
      water_year     = raster_row$water_year[1],
      raster_n_bands = n_bands,
      raster_crs     = terra::crs(raster, describe = TRUE)$name[1],
      raster_res_x   = terra::res(raster)[1],
      raster_res_y   = terra::res(raster)[2]
    ) |>
    dplyr::select(
      plot_id,
      date_start,
      date_end,
      water_year,
      product,
      sensor,
      file_name,
      file_path,
      band_number,
      band_label,
      band_confirmed,
      band_notes,
      mean_raw,
      median_raw,
      mean_value,
      median_value,
      valid_coverage_count,
      value_scale_factor,
      buffer_pixels,
      engine_used,
      extraction_scope,
      summary_method_primary,
      summary_method_secondary,
      raster_n_bands,
      raster_crs,
      raster_res_x,
      raster_res_y
    )
}


## Multiple-raster fractional-cover extraction ----


gayini_extract_fractional_cover_subset <- function(raster_subset,
                                                   plots_sf,
                                                   band_lookup,
                                                   summary_methods = c("mean", "median", "count"),
                                                   buffer_pixels = 0,
                                                   value_scale_factor = 1,
                                                   extraction_scope = "development_smoke_test") {
  gayini_check_required_columns(
    raster_subset,
    c("file_path", "file_name", "product", "sensor", "date_start", "date_end", "water_year"),
    object_name = "raster_subset"
  )

  extraction_results <- vector("list", nrow(raster_subset))

  for (i in seq_len(nrow(raster_subset))) {
    message("Extracting fractional cover raster ", i, " of ", nrow(raster_subset), ": ", raster_subset$file_name[i])

    raster_row <- raster_subset[i, , drop = FALSE]

    extraction_results[[i]] <- gayini_extract_fractional_cover_raster(
      raster_row         = raster_row,
      plots_sf           = plots_sf,
      band_lookup        = band_lookup,
      summary_methods    = summary_methods,
      buffer_pixels      = buffer_pixels,
      value_scale_factor = value_scale_factor,
      extraction_scope   = extraction_scope
    )
  }

  dplyr::bind_rows(extraction_results)
}


## Safe diagnostic summary helpers ----


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


gayini_safe_sum <- function(x) {
  if (all(is.na(x))) {
    return(NA_real_)
  }

  sum(x, na.rm = TRUE)
}


## Band-sum diagnostics ----


gayini_make_fractional_cover_band_sum_checks <- function(extraction_results) {
  gayini_check_required_columns(
    extraction_results,
    c("plot_id", "date_start", "file_name", "band_number", "mean_value", "valid_coverage_count"),
    object_name = "extraction_results"
  )

  extraction_results |>
    dplyr::group_by(plot_id, date_start, date_end, water_year, file_name) |>
    dplyr::summarise(
      n_bands_extracted      = dplyr::n_distinct(band_number),
      n_bands_missing        = sum(is.na(mean_value)),
      all_bands_missing      = all(is.na(mean_value)),
      band_sum_mean_value    = gayini_safe_sum(mean_value),
      min_band_mean_value    = gayini_safe_min(mean_value),
      max_band_mean_value    = gayini_safe_max(mean_value),
      total_valid_count      = gayini_safe_sum(valid_coverage_count),
      .groups                = "drop"
    ) |>
    dplyr::mutate(
      band_sum_interpretation = dplyr::case_when(
        all_bands_missing                             ~ "all_bands_missing",
        is.na(band_sum_mean_value)                    ~ "missing",
        abs(band_sum_mean_value - 100) <= 15           ~ "looks_like_percent_scale",
        abs(band_sum_mean_value - 1) <= 0.15           ~ "looks_like_fraction_scale",
        TRUE                                          ~ "needs_review"
      )
    ) |>
    dplyr::arrange(plot_id, date_start)
}


## Smoke-test checks ----


gayini_check_fractional_cover_test_results <- function(extraction_results,
                                                       raster_subset,
                                                       plots_sf,
                                                       expected_bands_per_raster = 3) {
  expected_rows <- nrow(raster_subset) * nrow(plots_sf) * expected_bands_per_raster

  actual_rows <- nrow(extraction_results)

  dplyr::bind_rows(
    tibble::tibble(
      check_name  = "extraction_row_count",
      check_value = as.character(actual_rows),
      status      = ifelse(actual_rows == expected_rows, "pass", "warn"),
      notes       = paste0("Expected ", expected_rows, " rows from rasters x plots x bands. Warn may be acceptable if band counts vary.")
    ),

    tibble::tibble(
      check_name  = "unique_plots_extracted",
      check_value = as.character(dplyr::n_distinct(extraction_results$plot_id)),
      status      = ifelse(dplyr::n_distinct(extraction_results$plot_id) == nrow(plots_sf), "pass", "fail"),
      notes       = "All selected test plots should appear in the extraction output."
    ),

    tibble::tibble(
      check_name  = "unique_rasters_extracted",
      check_value = as.character(dplyr::n_distinct(extraction_results$file_path)),
      status      = ifelse(dplyr::n_distinct(extraction_results$file_path) == nrow(raster_subset), "pass", "fail"),
      notes       = "All selected fractional-cover rasters should appear in the extraction output."
    ),

    tibble::tibble(
      check_name  = "missing_mean_values",
      check_value = as.character(sum(is.na(extraction_results$mean_value))),
      status      = ifelse(any(is.na(extraction_results$mean_value)), "warn", "pass"),
      notes       = "Missing values may indicate NoData, CRS problems, or plots outside raster coverage."
    ),

    tibble::tibble(
      check_name  = "negative_mean_values",
      check_value = as.character(sum(extraction_results$mean_value < 0, na.rm = TRUE)),
      status      = ifelse(any(extraction_results$mean_value < 0, na.rm = TRUE), "warn", "pass"),
      notes       = "Fractional-cover values should not normally be negative."
    ),

    tibble::tibble(
      check_name  = "mean_values_over_255",
      check_value = as.character(sum(extraction_results$mean_value > 255, na.rm = TRUE)),
      status      = ifelse(any(extraction_results$mean_value > 255, na.rm = TRUE), "warn", "pass"),
      notes       = "Values above 255 are suspicious for uint8 fractional-cover rasters."
    ),

    tibble::tibble(
      check_name  = "zero_or_missing_valid_coverage_count",
      check_value = as.character(sum(is.na(extraction_results$valid_coverage_count) | extraction_results$valid_coverage_count <= 0)),
      status      = ifelse(any(is.na(extraction_results$valid_coverage_count) | extraction_results$valid_coverage_count <= 0), "warn", "pass"),
      notes       = "Each plot-raster-band combination should normally have positive coverage count."
    )
  )
}


## Valid-coverage status helpers ----


gayini_add_valid_coverage_status <- function(extraction_results,
                                             very_low_threshold = 1,
                                             adequate_threshold = 5) {
  gayini_check_required_columns(
    extraction_results,
    c("valid_coverage_count"),
    object_name = "extraction_results"
  )

  extraction_results |>
    dplyr::mutate(
      valid_coverage_status = dplyr::case_when(
        is.na(.data$valid_coverage_count) | .data$valid_coverage_count <= 0 ~ "no_valid_coverage",
        .data$valid_coverage_count > 0 & .data$valid_coverage_count < very_low_threshold ~ "very_low_coverage",
        .data$valid_coverage_count >= very_low_threshold & .data$valid_coverage_count < adequate_threshold ~ "low_coverage",
        .data$valid_coverage_count >= adequate_threshold ~ "adequate_coverage",
        TRUE ~ "needs_review"
      ),
      valid_coverage_status_note = dplyr::case_when(
        .data$valid_coverage_status == "no_valid_coverage" ~ "No valid raster coverage intersected this plot/band/date after NoData handling.",
        .data$valid_coverage_status == "very_low_coverage" ~ "Less than one effective raster cell contributed to the estimate; treat as very low confidence.",
        .data$valid_coverage_status == "low_coverage" ~ "Between one and five effective raster cells contributed; keep but flag for sensitivity review.",
        .data$valid_coverage_status == "adequate_coverage" ~ "At least five effective raster cells contributed; first-pass adequate coverage threshold met.",
        TRUE ~ "Coverage status requires review."
      )
    )
}


gayini_safe_mean <- function(x) {
  if (all(is.na(x))) {
    return(NA_real_)
  }

  mean(x, na.rm = TRUE)
}


gayini_safe_median <- function(x) {
  if (all(is.na(x))) {
    return(NA_real_)
  }

  stats::median(x, na.rm = TRUE)
}
