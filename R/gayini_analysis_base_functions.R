## -----------------------------------------------------------------------------
## Gayini remote sensing workflow
## gayini_analysis_base_functions.R
## -----------------------------------------------------------------------------


## Purpose:
## Shared helpers for the curated remote-sensing analysis-base tables.
## These helpers deliberately use magrittr %>% pipes, matching project style.


`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0 || all(is.na(x))) y else x
}


gayini_check_packages <- function(required_packages) {
  missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]

  if (length(missing_packages) > 0) {
    stop(
      "Missing required packages: ",
      paste(missing_packages, collapse = ", "),
      call. = FALSE
    )
  }

  invisible(TRUE)
}


gayini_find_first_existing <- function(paths) {
  existing <- paths[file.exists(paths)]

  if (length(existing) == 0) {
    return(NA_character_)
  }

  normalizePath(existing[[1]], winslash = "/", mustWork = TRUE)
}


gayini_get_first_existing_column <- function(df, candidates, default = NA) {
  hit <- candidates[candidates %in% names(df)]

  if (length(hit) > 0) {
    return(df[[hit[[1]]]])
  }

  if (length(default) == 1) {
    return(rep(default, nrow(df)))
  }

  default
}


gayini_require_columns <- function(df, required_cols, object_name = "object") {
  missing_cols <- setdiff(required_cols, names(df))

  if (length(missing_cols) > 0) {
    stop(
      object_name, " is missing required column(s): ",
      paste(missing_cols, collapse = ", "),
      call. = FALSE
    )
  }

  invisible(TRUE)
}


gayini_find_plot_id_column <- function(x) {
  nms <- names(x)

  candidates <- c(
    "plot_id",
    "Plot_ID",
    "PLOT_ID",
    "plotid",
    "PlotID",
    "Plot_Id",
    "Gayini Nam",
    "Gayini.Nam",
    "Gayini_Nam",
    "GayiniNam",
    "Gayini Na",
    "Gayini_Na",
    "Gayini.Na",
    "Gayini"
  )

  hit <- candidates[candidates %in% nms]

  if (length(hit) > 0) {
    return(hit[[1]])
  }

  for (nm in nms) {
    vals <- as.character(x[[nm]])
    vals <- vals[!is.na(vals)]

    if (length(vals) > 0 && any(grepl("^GA_[0-9]{3}$", vals))) {
      return(nm)
    }
  }

  NA_character_
}


gayini_standardise_plot_id <- function(x, object_name = "object") {
  id_col <- gayini_find_plot_id_column(x)

  if (is.na(id_col)) {
    stop(
      "Could not find a plot ID column in ", object_name,
      ". Available columns: ", paste(names(x), collapse = ", "),
      call. = FALSE
    )
  }

  x$plot_id <- stringr::str_trim(as.character(x[[id_col]]))

  message("Using plot ID column in ", object_name, ": ", id_col)

  x
}


gayini_date_year <- function(x) {
  as.integer(format(as.Date(x), "%Y"))
}


gayini_date_month <- function(x) {
  as.integer(format(as.Date(x), "%m"))
}


gayini_assign_water_year <- function(date, water_year_start_month = 7) {
  date <- as.Date(date)
  date_year <- gayini_date_year(date)
  date_month <- gayini_date_month(date)
  start_year <- ifelse(date_month >= water_year_start_month, date_year, date_year - 1L)
  end_year <- start_year + 1L

  dplyr::if_else(
    is.na(date),
    NA_character_,
    paste0(start_year, "-", end_year)
  )
}


gayini_assign_period <- function(date,
                                 management_change_date,
                                 pre_start_date,
                                 post_end_date) {
  date <- as.Date(date)

  dplyr::case_when(
    is.na(date) ~ NA_character_,
    date >= pre_start_date & date < management_change_date ~ "pre_conservation",
    date >= management_change_date & date <= post_end_date ~ "post_conservation",
    TRUE ~ "outside_analysis_window"
  )
}


gayini_recode_vegetation_groups <- function(df) {
  existing_group <- if ("vegetation_adrian_group" %in% names(df)) {
    as.character(df$vegetation_adrian_group)
  } else {
    rep(NA_character_, nrow(df))
  }

  vegetation <- if ("vegetation" %in% names(df)) {
    as.character(df$vegetation)
  } else {
    rep(NA_character_, nrow(df))
  }

  df %>%
    dplyr::mutate(
      vegetation_adrian_group_raw = dplyr::case_when(
        !is.na(existing_group) & stringr::str_trim(existing_group) != "" ~ stringr::str_trim(existing_group),
        !is.na(vegetation) & stringr::str_trim(vegetation) != "" ~ stringr::str_trim(vegetation),
        TRUE ~ NA_character_
      ),
      vegetation_adrian_group = dplyr::case_when(
        .data$vegetation_adrian_group_raw %in% c(
          "Inland Floodplain Shrublands",
          "Inland Floodplain Swamps",
          "Inland Floodplain Shrublands / Swamps"
        ) ~ "Inland Floodplain Shrublands / Swamps",
        TRUE ~ .data$vegetation_adrian_group_raw
      )
    ) %>%
    dplyr::select(-"vegetation_adrian_group_raw")
}


gayini_ground_cover_band_lookup <- function() {
  tibble::tibble(
    band_number = c(1L, 2L, 3L),
    cover_key = c("bare_ground_pct", "green_pv_pct", "non_green_npv_pct"),
    cover_class = c("Bare ground", "Green / PV", "Non-green / NPV"),
    units = "percent",
    nodata_value = 255L,
    source = "TERN/JRSRP seasonal ground-cover band definitions",
    definition = c(
      "Bare ground percentage from band 1.",
      "Green / photosynthetic vegetation percentage from band 2.",
      "Non-green / non-photosynthetic vegetation percentage from band 3."
    )
  )
}


gayini_recode_ground_cover_bands <- function(df,
                                             value_column_candidates = c("mean_value", "median_value", "cover_value")) {
  value <- as.numeric(gayini_get_first_existing_column(df, value_column_candidates, default = NA_real_))

  band_number <- if ("band_number" %in% names(df)) {
    suppressWarnings(as.integer(df$band_number))
  } else {
    rep(NA_integer_, nrow(df))
  }

  band_label <- if ("band_label" %in% names(df)) {
    stringr::str_to_lower(as.character(df$band_label))
  } else {
    rep(NA_character_, nrow(df))
  }

  df %>%
    dplyr::mutate(
      band_number = band_number,
      ground_cover_pct = dplyr::if_else(value == 255, NA_real_, value),
      ground_cover_pct = pmax(pmin(.data$ground_cover_pct, 100), 0),
      cover_key = dplyr::case_when(
        !is.na(.data$band_number) & .data$band_number == 1L ~ "bare_ground_pct",
        !is.na(.data$band_number) & .data$band_number == 2L ~ "green_pv_pct",
        !is.na(.data$band_number) & .data$band_number == 3L ~ "non_green_npv_pct",
        is.na(.data$band_number) & stringr::str_detect(band_label, "bare") ~ "bare_ground_pct",
        is.na(.data$band_number) & stringr::str_detect(band_label, "non|npv") ~ "non_green_npv_pct",
        is.na(.data$band_number) & stringr::str_detect(band_label, "green|pv") ~ "green_pv_pct",
        TRUE ~ NA_character_
      ),
      cover_class = dplyr::case_when(
        .data$cover_key == "bare_ground_pct" ~ "Bare ground",
        .data$cover_key == "green_pv_pct" ~ "Green / PV",
        .data$cover_key == "non_green_npv_pct" ~ "Non-green / NPV",
        TRUE ~ "cover_unknown"
      ),
      tern_band_mapping_note = "TERN/JRSRP mapping: band 1 bare, band 2 green/PV, band 3 non-green/NPV; 255 NoData."
    )
}


gayini_add_total_vegetation <- function(df) {
  for (nm in c("bare_ground_pct", "green_pv_pct", "non_green_npv_pct")) {
    if (!nm %in% names(df)) {
      df[[nm]] <- NA_real_
    }
  }

  df %>%
    dplyr::mutate(
      total_veg_pct = dplyr::if_else(
        is.na(.data$green_pv_pct) & is.na(.data$non_green_npv_pct),
        NA_real_,
        dplyr::coalesce(.data$green_pv_pct, 0) + dplyr::coalesce(.data$non_green_npv_pct, 0)
      )
    )
}


gayini_add_gap_segments <- function(df,
                                    date_col = "date_midpoint",
                                    group_cols = c("plot_id"),
                                    gap_days_for_new_segment = 550) {
  df %>%
    dplyr::arrange(dplyr::across(dplyr::all_of(group_cols)), .data[[date_col]]) %>%
    dplyr::group_by(dplyr::across(dplyr::all_of(group_cols))) %>%
    dplyr::mutate(
      gap_days = as.numeric(.data[[date_col]] - dplyr::lag(.data[[date_col]])),
      segment_id = cumsum(dplyr::coalesce(.data$gap_days > gap_days_for_new_segment, FALSE))
    ) %>%
    dplyr::ungroup()
}


gayini_check_duplicate_keys <- function(df,
                                        key_cols,
                                        dataset_name,
                                        stop_on_duplicates = FALSE) {
  gayini_require_columns(df, key_cols, dataset_name)

  duplicate_keys <- df %>%
    dplyr::count(dplyr::across(dplyr::all_of(key_cols)), name = "n_rows") %>%
    dplyr::filter(.data$n_rows > 1)

  duplicate_summary <- tibble::tibble(
    dataset = dataset_name,
    key_cols = paste(key_cols, collapse = ";"),
    n_rows = nrow(df),
    n_duplicate_keys = nrow(duplicate_keys),
    n_duplicate_rows = sum(duplicate_keys$n_rows),
    status = dplyr::if_else(nrow(duplicate_keys) == 0, "ok", "duplicates_found")
  )

  attr(duplicate_summary, "duplicate_keys") <- duplicate_keys

  if (stop_on_duplicates && nrow(duplicate_keys) > 0) {
    stop(
      dataset_name, " has duplicated key records for: ",
      paste(key_cols, collapse = ", "),
      call. = FALSE
    )
  }

  duplicate_summary
}


gayini_make_row_count_diagnostics <- function(tables, paths = list()) {
  table_names <- names(tables)

  dplyr::bind_rows(lapply(table_names, function(nm) {
    x <- tables[[nm]]
    path <- paths[[nm]] %||% NA_character_

    tibble::tibble(
      dataset = nm,
      path = path,
      n_rows = nrow(x),
      n_cols = ncol(x)
    )
  }))
}


gayini_write_row_count_diagnostics <- function(tables, paths, output_path) {
  out <- gayini_make_row_count_diagnostics(tables = tables, paths = paths)
  readr::write_csv(out, output_path)
  message("Wrote: ", output_path)
  invisible(out)
}


gayini_variable_lut <- function() {
  tibble::tribble(
    ~variable_name, ~label, ~units, ~definition, ~caution,
    "plot_id", "Plot ID", NA_character_, "Standard Gayini plot identifier.", NA_character_,
    "water_year", "Water year", NA_character_, "July-June water year, labelled as start_year-end_year.", NA_character_,
    "period", "Analysis period", NA_character_, "Pre/post period assigned from configurable management-change and analysis-window dates.", NA_character_,
    "bare_ground_pct", "Bare ground", "percent", "TERN/JRSRP band 1.", "Ground-cover estimates may be uncertain in treed or woody plots.",
    "green_pv_pct", "Green / PV", "percent", "TERN/JRSRP band 2, photosynthetic vegetation.", "Ground-cover estimates may be uncertain in treed or woody plots.",
    "non_green_npv_pct", "Non-green / NPV", "percent", "TERN/JRSRP band 3, non-photosynthetic vegetation.", "Ground-cover estimates may be uncertain in treed or woody plots.",
    "total_veg_pct", "Total vegetation", "percent", "green_pv_pct + non_green_npv_pct.", "Total vegetation does not separate trees from ground-layer vegetation.",
    "pre_conservation_inundation_frequency_pct", "Pre-conservation inundation frequency", "percent", "Annual inundation occurrence frequency during the pre-conservation period.", "Annual occurrence frequency, not hydroperiod, depth, duration, or wet days.",
    "post_conservation_inundation_frequency_pct", "Post-conservation inundation frequency", "percent", "Annual inundation occurrence frequency during the post-conservation period.", "Annual occurrence frequency, not hydroperiod, depth, duration, or wet days.",
    "post_minus_pre_inundation_frequency_pct_points", "Post minus pre inundation frequency", "percentage points", "Post-conservation frequency minus pre-conservation frequency.", "Difference is percentage points, not percent change.",
    "daily_inundated_pct", "Daily inundated area", "percent", "Percentage of interpreted daily raster area mapped as strict value 1 inundated.", "Sensor density differs among years; Sentinel-rich years may detect short-lived water more readily.",
    "annual_valid_any", "Annual valid coverage flag", NA_character_, "Valid coverage indicator; it does not mean flooding occurred.", "annual_valid_any = 1 means valid coverage, not flooding.",
    "annual_max_inundated_area_pct", "Annual maximum inundated plot area", "percent", "Maximum daily strict value-1 inundated area percentage observed for a plot in a water year.", "Annual maximum extent is observation-density dependent and is not duration.",
    "annual_max_inundated_area_pct_value_1_plus_2", "Annual maximum inundated plot area sensitivity", "percent", "Maximum daily area percentage observed for a plot in a water year using value 1 plus value 2 as wet.", "Sensitivity only; keep separate from the primary strict value-1 metric.",
    "monthly_max_inundated_pct", "Monthly maximum inundated plot area", "percent", "Maximum daily strict value-1 inundated area percentage observed for a plot in a calendar month.", "Use with observation-density support.",
    "seasonal_max_inundated_pct", "Seasonal maximum inundated plot area", "percent", "Maximum daily strict value-1 inundated area percentage observed for a plot in a meteorological season.", "Use with observation-density support.",
    "longest_observed_wet_sequence_days", "Longest observed wet sequence", "days", "Longest run of wet observations where gaps between wet observations do not exceed the configured gap rule.", "Observed sequence only; not hydroperiod or proof of continuous inundation.",
    "start_day_of_longest_observed_wet_sequence", "Start day of longest observed wet sequence", "day of water year", "Day number from water-year start for the longest observed wet sequence.", "Depends on satellite observation timing.",
    "n_valid_observations", "Valid daily observations", "count", "Number of selected daily observations available after same-date duplicate handling.", "Observation density affects detectability of short wet events.",
    "n_wet_observations", "Wet daily observations", "count", "Number of selected daily observations with strict value-1 inundated area greater than the wet threshold.", "Count of observed wet detections, not number of wet days.",
    "observation_density_class", "Observation density class", NA_character_, "Simple support class based on number of selected daily observations.", "Use as interpretation support, not as an ecological response metric."
  )
}
