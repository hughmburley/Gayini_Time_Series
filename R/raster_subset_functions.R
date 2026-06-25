## -----------------------------------------------------------------------------
## Gayini raster development-subset functions
## -----------------------------------------------------------------------------


## These functions support scripts/03_make_raster_dev_subset.R.


## The goal is to select a small, date-spread subset of rasters for extraction
## testing before running the full remote-sensing workflow.


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


## Date coercion helper ----


gayini_coerce_catalog_dates <- function(raster_catalog) {
  raster_catalog |>
    dplyr::mutate(
      date_start = as.Date(date_start),
      date_end   = as.Date(date_end)
    )
}


## Sensor-column helper ----


gayini_infer_sensor_from_catalog <- function(raster_catalog) {
  if ("sensor" %in% names(raster_catalog)) {
    return(raster_catalog)
  }

  message("Raster catalogue does not contain a sensor column. Inferring sensor from product and filename.")

  raster_catalog |>
    dplyr::mutate(
      sensor = dplyr::case_when(
        product == "modis_fractional_cover"   ~ "modis",
        product == "landsat_fractional_cover" ~ "landsat",
        product == "landsat_inundation"       ~ "landsat",
        product == "aerial_or_ads_imagery"    ~ "ads",
        product == "sentinel2_inundation" & stringr::str_detect(stringr::str_to_lower(file_name), "_s2_") ~ "s2",
        product == "sentinel2_inundation" & stringr::str_detect(stringr::str_to_lower(file_name), "_l8_") ~ "l8",
        product == "sentinel2_inundation" & stringr::str_detect(stringr::str_to_lower(file_name), "_l7_") ~ "l7",
        product == "sentinel2_inundation"     ~ "unknown",
        TRUE                                  ~ "unknown"
      )
    )
}


## Development-subset group helper ----


gayini_add_dev_subset_group <- function(raster_catalog, group_daily_inundation_by_sensor = TRUE) {
  gayini_check_required_columns(
    raster_catalog,
    c("product", "sensor", "file_name"),
    object_name = "raster_catalog"
  )

  if (isTRUE(group_daily_inundation_by_sensor)) {
    raster_catalog <- raster_catalog |>
      dplyr::mutate(
        dev_subset_group = dplyr::case_when(
          product == "sentinel2_inundation" ~ paste(product, sensor, sep = "__"),
          TRUE                              ~ product
        )
      )
  } else {
    raster_catalog <- raster_catalog |>
      dplyr::mutate(dev_subset_group = product)
  }

  raster_catalog
}


## Evenly spaced row selection ----


gayini_select_evenly_spaced_rows <- function(x, n = 10, date_column = "date_start") {
  if (nrow(x) == 0) {
    return(x)
  }

  if (!date_column %in% names(x)) {
    stop("Date column not found: ", date_column, call. = FALSE)
  }

  x_ordered <- x |>
    dplyr::arrange(.data[[date_column]], file_name)

  if (nrow(x_ordered) <= n) {
    return(
      x_ordered |>
        dplyr::mutate(dev_subset_selection_rank = dplyr::row_number())
    )
  }

  selected_rows <- unique(round(seq(1, nrow(x_ordered), length.out = n)))

  x_ordered |>
    dplyr::slice(selected_rows) |>
    dplyr::mutate(dev_subset_selection_rank = dplyr::row_number())
}


## Main development-subset selector ----


gayini_make_raster_dev_subset <- function(raster_catalog,
                                          include_products = c(
                                            "landsat_fractional_cover",
                                            "landsat_inundation",
                                            "sentinel2_inundation",
                                            "modis_fractional_cover",
                                            "aerial_or_ads_imagery"
                                          ),
                                          n_per_group = 10,
                                          group_daily_inundation_by_sensor = TRUE,
                                          include_ads = TRUE) {
  raster_catalog <- gayini_infer_sensor_from_catalog(raster_catalog)

  gayini_check_required_columns(
    raster_catalog,
    c(
      "file_path",
      "file_name",
      "product",
      "sensor",
      "read_status",
      "date_start",
      "date_end",
      "date_parse_status",
      "is_plot_scale_candidate"
    ),
    object_name = "raster_catalog"
  )

  raster_catalog <- raster_catalog |>
    gayini_coerce_catalog_dates() |>
    gayini_add_dev_subset_group(
      group_daily_inundation_by_sensor = group_daily_inundation_by_sensor
    )

  if (!isTRUE(include_ads)) {
    include_products <- setdiff(include_products, "aerial_or_ads_imagery")
  }

  candidate_catalog <- raster_catalog |>
    dplyr::filter(product %in% include_products) |>
    dplyr::filter(read_status == "ok") |>
    dplyr::filter(!is.na(date_start))

  dev_subset <- candidate_catalog |>
    dplyr::group_by(dev_subset_group) |>
    dplyr::group_modify(~ gayini_select_evenly_spaced_rows(.x, n = n_per_group)) |>
    dplyr::ungroup() |>
    dplyr::mutate(
      dev_subset_n_per_group_setting       = n_per_group,
      dev_subset_grouped_daily_by_sensor   = group_daily_inundation_by_sensor,
      dev_subset_created_at                = as.character(Sys.time())
    ) |>
    dplyr::arrange(product, sensor, date_start, file_name)

  dev_subset
}


## Development-subset summary ----


gayini_summarise_raster_dev_subset <- function(dev_subset) {
  gayini_check_required_columns(
    dev_subset,
    c(
      "product",
      "sensor",
      "dev_subset_group",
      "file_size_mb",
      "date_start",
      "date_end",
      "is_plot_scale_candidate"
    ),
    object_name = "dev_subset"
  )

  dev_subset |>
    dplyr::group_by(product, sensor, dev_subset_group) |>
    dplyr::summarise(
      n_files                 = dplyr::n(),
      first_date              = min(date_start, na.rm = TRUE),
      last_date               = max(date_end, na.rm = TRUE),
      total_size_mb           = round(sum(file_size_mb, na.rm = TRUE), 3),
      plot_scale_candidates   = sum(is_plot_scale_candidate, na.rm = TRUE),
      .groups                 = "drop"
    ) |>
    dplyr::arrange(product, sensor, dev_subset_group)
}


## Development-subset checks ----


gayini_check_raster_dev_subset <- function(dev_subset, n_per_group = 10) {
  gayini_check_required_columns(
    dev_subset,
    c(
      "file_path",
      "file_name",
      "product",
      "sensor",
      "read_status",
      "date_start",
      "date_parse_status",
      "dev_subset_group"
    ),
    object_name = "dev_subset"
  )

  dplyr::bind_rows(
    tibble::tibble(
      check_name  = "dev_subset_row_count",
      check_value = as.character(nrow(dev_subset)),
      status      = ifelse(nrow(dev_subset) > 0, "pass", "fail"),
      notes       = "Development subset should contain at least one raster."
    ),

    tibble::tibble(
      check_name  = "duplicated_file_paths",
      check_value = as.character(sum(duplicated(dev_subset$file_path))),
      status      = ifelse(any(duplicated(dev_subset$file_path)), "fail", "pass"),
      notes       = "Each raster file should appear only once in the development subset."
    ),

    tibble::tibble(
      check_name  = "read_failures",
      check_value = as.character(sum(dev_subset$read_status != "ok", na.rm = TRUE)),
      status      = ifelse(any(dev_subset$read_status != "ok", na.rm = TRUE), "fail", "pass"),
      notes       = "All development-subset rasters should have read_status == 'ok'."
    ),

    tibble::tibble(
      check_name  = "date_parse_failures",
      check_value = as.character(sum(is.na(dev_subset$date_start), na.rm = TRUE)),
      status      = ifelse(any(is.na(dev_subset$date_start)), "fail", "pass"),
      notes       = "All development-subset rasters should have a parsed start date."
    ),

    tibble::tibble(
      check_name  = "groups_above_requested_n",
      check_value = as.character(
        dev_subset |>
          dplyr::count(dev_subset_group) |>
          dplyr::filter(n > n_per_group) |>
          nrow()
      ),
      status      = ifelse(
        dev_subset |>
          dplyr::count(dev_subset_group) |>
          dplyr::filter(n > n_per_group) |>
          nrow() > 0,
        "fail",
        "pass"
      ),
      notes       = "No development-subset group should exceed the requested n_per_group."
    )
  )
}


## Extraction-decision table helper ----


gayini_make_extraction_decision_table <- function(edge_buffer_pixels = 0,
                                                  sensitivity_buffer_pixels = 1,
                                                  continuous_summary_method = "weighted_mean",
                                                  continuous_secondary_method = "weighted_median",
                                                  categorical_summary_method = "coverage_fraction",
                                                  categorical_secondary_method = "majority_class") {
  tibble::tribble(
    ~setting_name,                  ~setting_value,                  ~applies_to,                  ~decision_status,        ~notes,
    "edge_buffer_pixels",           as.character(edge_buffer_pixels), "all plot extractions",       "default_first_pass",    "Use fixed plot boundaries for the primary analysis. Do not enlarge plots in the main estimate.",
    "sensitivity_buffer_pixels",    as.character(sensitivity_buffer_pixels), "all plot extractions", "later_sensitivity_test", "A one-pixel buffer may be useful as a sensitivity/context check, but should not be the primary extraction unit.",
    "continuous_summary_method",    continuous_summary_method,       "fractional cover",           "default_first_pass",    "For proportional fractional-cover bands, use an area/coverage-weighted mean as the primary plot-level estimate.",
    "continuous_secondary_method",  continuous_secondary_method,     "fractional cover",           "qa_sensitivity_check",  "Use a weighted median as a robustness check where small plots or edge pixels may influence means.",
    "categorical_summary_method",   categorical_summary_method,      "inundation classes",         "default_first_pass",    "For categorical water classes, retain class-area proportions before deriving inundated_pct.",
    "categorical_secondary_method", categorical_secondary_method,    "inundation classes",         "qa_sensitivity_check",  "Majority class can be useful for QA but may hide partial inundation in small plots."
  )
}
