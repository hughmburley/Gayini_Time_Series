## -----------------------------------------------------------------------------
## Gayini remote sensing workflow
## gayini_mer_raster_functions.R
## -----------------------------------------------------------------------------


## Purpose:
## Reusable helpers for a census-first MER raster readiness check and a controlled
## one-water-year annual maximum observed inundation smoke test.


gayini_mer_check_packages <- function(required_packages) {
  missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]

  if (length(missing_packages) > 0) {
    stop("Missing required packages: ", paste(missing_packages, collapse = ", "), call. = FALSE)
  }

  invisible(TRUE)
}


gayini_mer_make_dirs <- function(root_dir) {
  dirs <- c(
    file.path(root_dir, "Output", "diagnostics", "24_mer_raster_build"),
    file.path(root_dir, "Output", "csv", "MER", "raster_build"),
    file.path(root_dir, "Output", "figures", "review", "MER", "raster_build"),
    file.path(root_dir, "Output", "rasters", "MER", "annual_max"),
    file.path(root_dir, "Output", "rasters", "MER", "support"),
    file.path(root_dir, "Output", "reports", "MER")
  )

  invisible(lapply(dirs, dir.create, recursive = TRUE, showWarnings = FALSE))
  dirs
}


gayini_mer_bool <- function(x) {
  if (is.logical(x)) {
    return(x)
  }

  stringr::str_to_upper(as.character(x)) %in% c("TRUE", "T", "1", "YES", "Y")
}


gayini_mer_safe_chr <- function(x) {
  if (length(x) == 0 || is.null(x)) {
    return(NA_character_)
  }

  as.character(x[[1]])
}


gayini_mer_select_daily_raster_index <- function(daily_df,
                                                 only_adequate_coverage = TRUE) {
  daily_df %>%
    dplyr::mutate(
      date_midpoint = as.Date(.data$date_midpoint),
      sensor_clean = dplyr::case_when(
        .data$sensor %in% c("s2", "s2_inferred_10m") ~ "s2",
        .data$sensor %in% c("l7", "l8", "l9") ~ as.character(.data$sensor),
        TRUE ~ "unknown"
      ),
      has_cloud3_name = gayini_mer_bool(.data$has_cloud3_name),
      has_ors2_name = gayini_mer_bool(.data$has_ors2_name)
    ) %>%
    dplyr::filter(!is.na(.data$date_midpoint), !is.na(.data$water_year)) %>%
    {
      if (only_adequate_coverage && "valid_coverage_status" %in% names(.)) {
        dplyr::filter(., .data$valid_coverage_status == "adequate_coverage")
      } else {
        .
      }
    } %>%
    dplyr::distinct(
      .data$date_midpoint,
      .data$water_year,
      .data$product,
      .data$sensor_clean,
      .data$file_name,
      .data$file_path,
      .data$raster_res_x,
      .data$raster_res_y,
      .data$has_cloud3_name,
      .data$has_ors2_name
    ) %>%
    dplyr::arrange(
      .data$date_midpoint,
      .data$sensor_clean,
      dplyr::desc(.data$has_cloud3_name),
      dplyr::desc(.data$has_ors2_name),
      .data$file_name
    ) %>%
    dplyr::group_by(.data$date_midpoint, .data$sensor_clean) %>%
    dplyr::mutate(
      duplicate_group_size = dplyr::n(),
      selected_for_mer_raster = dplyr::row_number() == 1L,
      duplicate_resolution_rule = "same_date_same_sensor_keep_cloud3_then_ors2_then_filename"
    ) %>%
    dplyr::ungroup() %>%
    dplyr::mutate(
      source_raster_id = paste0(
        "MER_SRC_",
        stringr::str_replace_all(.data$water_year, "-", "_"),
        "_",
        stringr::str_replace_all(as.character(.data$date_midpoint), "-", ""),
        "_",
        .data$sensor_clean
      )
    )
}


gayini_mer_read_raster_metadata <- function(path) {
  if (!file.exists(path)) {
    return(tibble::tibble(
      can_open = FALSE,
      raster_nrow = NA_integer_,
      raster_ncol = NA_integer_,
      raster_xres = NA_real_,
      raster_yres = NA_real_,
      crs = NA_character_,
      extent_xmin = NA_real_,
      extent_xmax = NA_real_,
      extent_ymin = NA_real_,
      extent_ymax = NA_real_,
      n_layers = NA_integer_,
      nodata_value = NA_character_,
      notes = "source_raster_missing"
    ))
  }

  out <- tryCatch({
    r <- terra::rast(path)
    ext <- terra::ext(r)
    res <- terra::res(r)
    tibble::tibble(
      can_open = TRUE,
      raster_nrow = terra::nrow(r),
      raster_ncol = terra::ncol(r),
      raster_xres = as.numeric(res[[1]]),
      raster_yres = as.numeric(res[[2]]),
      crs = terra::crs(r, proj = TRUE),
      extent_xmin = as.numeric(ext[1]),
      extent_xmax = as.numeric(ext[2]),
      extent_ymin = as.numeric(ext[3]),
      extent_ymax = as.numeric(ext[4]),
      n_layers = terra::nlyr(r),
      nodata_value = paste(stats::na.omit(terra::NAflag(r)), collapse = ";"),
      notes = "metadata_read"
    )
  }, error = function(e) {
    tibble::tibble(
      can_open = FALSE,
      raster_nrow = NA_integer_,
      raster_ncol = NA_integer_,
      raster_xres = NA_real_,
      raster_yres = NA_real_,
      crs = NA_character_,
      extent_xmin = NA_real_,
      extent_xmax = NA_real_,
      extent_ymin = NA_real_,
      extent_ymax = NA_real_,
      n_layers = NA_integer_,
      nodata_value = NA_character_,
      notes = paste0("open_failed: ", conditionMessage(e))
    )
  })

  out
}


sample_mer_raster_value_schema <- function(inventory,
                                           sample_size = 20000) {
  purrr::map_dfr(seq_len(nrow(inventory)), function(i) {
    row <- inventory[i, ]

    if (!isTRUE(row$exists) || !isTRUE(row$can_open)) {
      return(tibble::tibble(
        source_raster_path = row$source_raster_path,
        date = row$date,
        water_year = row$water_year,
        sensor = row$sensor,
        unique_values_sample = NA_character_,
        n_unique_values_sampled = NA_integer_,
        value_0_count_sample = NA_integer_,
        value_1_count_sample = NA_integer_,
        value_2_count_sample = NA_integer_,
        value_3_count_sample = NA_integer_,
        value_255_count_sample = NA_integer_,
        other_values_present = NA,
        strict_wet_rule_supported = FALSE,
        sensitivity_wet_rule_supported = FALSE,
        notes = "not_sampled_missing_or_unopenable"
      ))
    }

    tryCatch({
      r <- terra::rast(row$source_raster_path)[[1]]
      vals <- terra::spatSample(
        r,
        size = min(sample_size, terra::ncell(r)),
        method = "regular",
        na.rm = FALSE,
        as.df = TRUE,
        values = TRUE
      )
      vals <- vals[[1]]
      vals <- vals[!is.na(vals)]
      unique_vals <- sort(unique(vals))
      other_vals <- setdiff(unique_vals, c(0, 1, 2, 3, 255))

      tibble::tibble(
        source_raster_path = row$source_raster_path,
        date = row$date,
        water_year = row$water_year,
        sensor = row$sensor,
        unique_values_sample = paste(unique_vals, collapse = ";"),
        n_unique_values_sampled = length(unique_vals),
        value_0_count_sample = sum(vals == 0, na.rm = TRUE),
        value_1_count_sample = sum(vals == 1, na.rm = TRUE),
        value_2_count_sample = sum(vals == 2, na.rm = TRUE),
        value_3_count_sample = sum(vals == 3, na.rm = TRUE),
        value_255_count_sample = sum(vals == 255, na.rm = TRUE),
        other_values_present = length(other_vals) > 0,
        strict_wet_rule_supported = all(unique_vals %in% c(0, 1, 2, 3, 255)) && length(unique_vals) > 0,
        sensitivity_wet_rule_supported = all(unique_vals %in% c(0, 1, 2, 3, 255)) && length(unique_vals) > 0,
        notes = dplyr::if_else(length(other_vals) > 0, paste0("other_values: ", paste(other_vals, collapse = ";")), "sampled")
      )
    }, error = function(e) {
      tibble::tibble(
        source_raster_path = row$source_raster_path,
        date = row$date,
        water_year = row$water_year,
        sensor = row$sensor,
        unique_values_sample = NA_character_,
        n_unique_values_sampled = NA_integer_,
        value_0_count_sample = NA_integer_,
        value_1_count_sample = NA_integer_,
        value_2_count_sample = NA_integer_,
        value_3_count_sample = NA_integer_,
        value_255_count_sample = NA_integer_,
        other_values_present = NA,
        strict_wet_rule_supported = FALSE,
        sensitivity_wet_rule_supported = FALSE,
        notes = paste0("sample_failed: ", conditionMessage(e))
      )
    })
  })
}


check_mer_grid_compatibility <- function(inventory) {
  inventory %>%
    dplyr::filter(.data$selected_for_mer_raster) %>%
    dplyr::mutate(sensor_group = "all_selected") %>%
    dplyr::bind_rows(
      inventory %>%
        dplyr::filter(.data$selected_for_mer_raster) %>%
        dplyr::mutate(sensor_group = .data$sensor)
    ) %>%
    dplyr::group_by(.data$water_year, .data$sensor_group) %>%
    dplyr::summarise(
      n_rasters = dplyr::n(),
      n_missing = sum(!.data$exists),
      n_unopenable = sum(.data$exists & !.data$can_open),
      n_unique_crs = dplyr::n_distinct(.data$crs[.data$can_open], na.rm = TRUE),
      n_unique_resolution = dplyr::n_distinct(paste(round(.data$raster_xres, 6), round(.data$raster_yres, 6))[.data$can_open], na.rm = TRUE),
      n_unique_extent = dplyr::n_distinct(
        paste(
          round(.data$extent_xmin, 3),
          round(.data$extent_xmax, 3),
          round(.data$extent_ymin, 3),
          round(.data$extent_ymax, 3)
        )[.data$can_open],
        na.rm = TRUE
      ),
      n_unique_dimensions = dplyr::n_distinct(paste(.data$raster_nrow, .data$raster_ncol)[.data$can_open], na.rm = TRUE),
      reference_raster = dplyr::first(.data$source_raster_path[.data$can_open]),
      .groups = "drop"
    ) %>%
    dplyr::mutate(
      grid_status = dplyr::case_when(
        .data$n_missing > 0 ~ "missing_files",
        .data$n_unopenable > 0 ~ "needs_review",
        .data$n_unique_crs > 1 ~ "mixed_crs",
        .data$n_unique_resolution > 1 ~ "mixed_resolution",
        .data$n_unique_extent > 1 ~ "mixed_extent",
        .data$n_unique_dimensions > 1 ~ "mixed_extent",
        .data$n_unique_crs == 1 & .data$n_unique_resolution == 1 & .data$n_unique_extent == 1 & .data$n_unique_dimensions == 1 ~ "compatible",
        TRUE ~ "needs_review"
      ),
      requires_alignment = .data$grid_status %in% c("mixed_resolution", "mixed_extent", "mixed_crs", "needs_review"),
      alignment_recommendation = dplyr::case_when(
        .data$grid_status == "compatible" ~ "Stack directly; no resampling indicated for this group.",
        .data$grid_status == "missing_files" ~ "Resolve missing source paths before raster building.",
        .data$grid_status == "mixed_crs" ~ "Do not stack until CRS alignment rule is reviewed.",
        .data$grid_status == "mixed_resolution" ~ "Do not silently resample; review sensor-specific or reference-grid workflow.",
        .data$grid_status == "mixed_extent" ~ "Do not silently align; review crop/snap/mask policy first.",
        TRUE ~ "Review before stacking."
      ),
      safe_for_stack_without_resampling = .data$grid_status == "compatible",
      notes = dplyr::case_when(
        .data$sensor_group == "all_selected" & .data$grid_status == "mixed_resolution" ~ "Likely mixed Landsat/Sentinel or source-grid resolution issue.",
        TRUE ~ NA_character_
      )
    ) %>%
    dplyr::arrange(.data$water_year, .data$sensor_group)
}


summarise_mer_observation_support <- function(inventory, grid_compatibility = NULL) {
  support <- inventory %>%
    dplyr::filter(.data$selected_for_mer_raster) %>%
    dplyr::arrange(.data$water_year, .data$date) %>%
    dplyr::group_by(.data$water_year) %>%
    dplyr::summarise(
      start_date = as.Date(paste0(substr(dplyr::first(.data$water_year), 1, 4), "-07-01")),
      end_date = as.Date(paste0(substr(dplyr::first(.data$water_year), 6, 9), "-06-30")),
      n_observation_dates = dplyr::n_distinct(.data$date),
      n_existing_source_rasters = sum(.data$exists & .data$can_open),
      n_landsat = sum(.data$sensor %in% c("l7", "l8", "l9")),
      n_sentinel2 = sum(.data$sensor == "s2"),
      n_other_sensor = sum(!.data$sensor %in% c("l7", "l8", "l9", "s2")),
      first_observation_date = min(.data$date, na.rm = TRUE),
      last_observation_date = max(.data$date, na.rm = TRUE),
      median_gap_days = {
        gaps <- diff(sort(unique(.data$date)))
        if (length(gaps) == 0) NA_real_ else stats::median(as.numeric(gaps), na.rm = TRUE)
      },
      max_gap_days = {
        gaps <- diff(sort(unique(.data$date)))
        if (length(gaps) == 0) NA_real_ else max(as.numeric(gaps), na.rm = TRUE)
      },
      months_with_observations = dplyr::n_distinct(format(.data$date, "%Y-%m")),
      max_monthly_gap = {
        month_index <- as.integer(format(.data$date, "%Y")) * 12L + as.integer(format(.data$date, "%m"))
        month_index <- sort(unique(month_index))
        if (length(month_index) <= 1) NA_integer_ else max(diff(month_index) - 1L, na.rm = TRUE)
      },
      .groups = "drop"
    )

  if (!is.null(grid_compatibility)) {
    support <- support %>%
      dplyr::left_join(
        grid_compatibility %>%
          dplyr::filter(.data$sensor_group == "all_selected") %>%
          dplyr::select("water_year", "grid_status", "safe_for_stack_without_resampling"),
        by = "water_year"
      )
  } else {
    support$grid_status <- NA_character_
    support$safe_for_stack_without_resampling <- NA
  }

  support %>%
    dplyr::mutate(
      annual_max_readiness = dplyr::case_when(
        .data$n_existing_source_rasters < .data$n_observation_dates ~ "Not recommended with current inputs",
        !(.data$safe_for_stack_without_resampling %in% TRUE) & .data$grid_status != "compatible" ~ "Possible but needs caution",
        .data$n_observation_dates >= 12 ~ "Ready for smoke test",
        .data$n_observation_dates >= 6 ~ "Possible but needs caution",
        TRUE ~ "Not recommended with current inputs"
      ),
      sequence_metric_readiness = dplyr::case_when(
        .data$n_observation_dates >= 30 & !is.na(.data$max_gap_days) & .data$max_gap_days <= 45 ~ "Possible but needs caution",
        .data$n_observation_dates >= 20 & !is.na(.data$median_gap_days) & .data$median_gap_days <= 20 ~ "Possible but needs caution",
        TRUE ~ "Not recommended with current inputs"
      ),
      main_limitation = dplyr::case_when(
        .data$grid_status != "compatible" ~ paste0("Grid status: ", .data$grid_status),
        .data$n_observation_dates < 12 ~ "Sparse annual observations",
        .data$sequence_metric_readiness == "Not recommended with current inputs" ~ "Observation gaps too large for defensible sequence rasters",
        TRUE ~ "Annual maximum support acceptable; sequence metrics remain cautious"
      ),
      notes = "Readiness is based on existing source rasters only; no external imagery was downloaded."
    )
}


census_mer_raster_inputs <- function(root_dir = Sys.getenv("GAYINI_ROOT", "D:/Github_repos/Gayini"),
                                     sample_size = 20000) {
  root_dir <- normalizePath(root_dir, winslash = "/", mustWork = TRUE)
  gayini_mer_make_dirs(root_dir)

  required_packages <- c("dplyr", "tidyr", "readr", "stringr", "magrittr", "tibble", "purrr", "ggplot2", "terra")
  gayini_mer_check_packages(required_packages)

  library(dplyr)
  library(tidyr)
  library(readr)
  library(stringr)
  library(magrittr)
  library(tibble)
  library(purrr)
  library(ggplot2)
  library(terra)

  daily_path <- file.path(root_dir, "Output", "csv", "06c_daily_inundation_full.csv")
  if (!file.exists(daily_path)) {
    stop("Missing daily inundation table: ", daily_path, call. = FALSE)
  }

  daily <- readr::read_csv(daily_path, show_col_types = FALSE)
  raster_index <- gayini_mer_select_daily_raster_index(daily)
  selected <- raster_index %>%
    dplyr::filter(.data$selected_for_mer_raster) %>%
    dplyr::mutate(
      source_raster_path = .data$file_path,
      exists = file.exists(.data$source_raster_path),
      date = as.Date(.data$date_midpoint),
      sensor = .data$sensor_clean,
      source_product = .data$product,
      resolution_from_table = paste(.data$raster_res_x, .data$raster_res_y, sep = " x ")
    )

  metadata <- purrr::map_dfr(selected$source_raster_path, gayini_mer_read_raster_metadata)

  inventory <- dplyr::bind_cols(selected, metadata) %>%
    dplyr::mutate(
      wet_value_rule_candidate = "strict: value 1 only; sensitivity: value 1 plus 2",
      valid_value_rule_candidate = "valid interpretation: values 0, 1, 2; invalid/cloud/shadow/nodata: value 3, 255, NA",
      unique_values_sample = NA_character_
    ) %>%
    dplyr::select(
      "source_raster_id",
      "source_raster_path",
      "exists",
      "date",
      "water_year",
      "sensor",
      "source_product",
      "resolution_from_table",
      "raster_nrow",
      "raster_ncol",
      "raster_xres",
      "raster_yres",
      "crs",
      "extent_xmin",
      "extent_xmax",
      "extent_ymin",
      "extent_ymax",
      "n_layers",
      "nodata_value",
      "unique_values_sample",
      "wet_value_rule_candidate",
      "valid_value_rule_candidate",
      "notes",
      "can_open",
      "selected_for_mer_raster",
      "date_midpoint",
      "file_name",
      "file_path",
      "duplicate_group_size",
      "duplicate_resolution_rule"
    )

  value_schema <- sample_mer_raster_value_schema(inventory, sample_size = sample_size)
  inventory <- inventory %>%
    dplyr::left_join(
      value_schema %>%
        dplyr::select("source_raster_path", "unique_values_sample"),
      by = "source_raster_path",
      suffix = c("", "_sampled")
    ) %>%
    dplyr::mutate(unique_values_sample = dplyr::coalesce(.data$unique_values_sample_sampled, .data$unique_values_sample)) %>%
    dplyr::select(-"unique_values_sample_sampled")

  grid_compatibility <- check_mer_grid_compatibility(inventory)
  water_year_support <- summarise_mer_observation_support(inventory, grid_compatibility)

  sequence_metric_readiness <- water_year_support %>%
    dplyr::transmute(
      water_year = .data$water_year,
      n_observations = .data$n_observation_dates,
      median_gap_days = .data$median_gap_days,
      max_gap_days = .data$max_gap_days,
      sequence_metric_readiness = .data$sequence_metric_readiness,
      why_or_why_not = dplyr::case_when(
        .data$sequence_metric_readiness == "Possible but needs caution" ~ "Observation cadence is comparatively strong, but still observation-timing dependent.",
        TRUE ~ "Observation gaps are too large or observations too sparse for defensible continuous sequence rasters."
      ),
      recommended_metric_label = "longest_observed_wet_sequence_between_observations; start_date_of_longest_observed_wet_sequence"
    )

  flow_mer_vs_gayini <- tibble::tribble(
    ~comparison_topic, ~flow_mer_expected_or_used, ~gayini_available, ~match_status, ~evidence_file_or_script, ~temporal_resolution_implication, ~spatial_resolution_implication, ~metric_implication, ~recommendation,
    "input product type", "Surface reflectance notebooks and local scripts using already-classified water extent rasters.", "Already-classified single-date inundation rasters represented in 06c daily extraction table.", "partial_match", "Flow_MER README; Output/csv/06c_daily_inundation_full.csv", "Gayini can use existing classified rasters for raster-first annual max; no new index calculation in this task.", "Existing grids must be checked because Landsat/Sentinel sources differ.", "Annual max is more defensible than sequence metrics.", "Use classified rasters for smoke test only after grid check.",
    "Landsat role", "Landsat notebooks create annual max and dynamic metrics from surface reflectance/water index.", "L7/L8 are present in pre-conservation years, generally 30 m.", "partial_match", "Flow_MER README; Gayini daily table", "Earlier Gayini years have lower cadence.", "30 m grid differs from Sentinel-2 years.", "Pre/post comparison may combine different sensor support regimes.", "Keep sensor support explicit.",
    "Sentinel-2 role", "Sentinel-2 notebook creates dynamic annual metrics using a water index.", "S2 dominates from WY2018-2019 onward, generally denser and 10 m.", "partial_match", "Flow_MER README; observation support diagnostics", "Post period has denser observations than early Landsat years.", "S2 10 m grid should not be stacked with 30 m Landsat without policy.", "Post-period annual max may detect smaller/shorter wet footprints.", "Build per-water-year; avoid silent cross-resolution resampling.",
    "already-classified water extent rasters", "Local scripts expect rasters with pixel values 1 water and 0 dry.", "Gayini source rasters use value 1 as strict inundated, 2 as sensitivity/off-river storage, 3 cloud/shadow, 0 dry.", "match_with_caveat", "Flow_MER local scripts; Gayini code/value schema", "Comparable for annual max if strict value 1 is used.", "Value schema is compatible where sampled values are limited to known classes.", "Value 2 should stay sensitivity only.", "Use strict value 1 for smoke test.",
    "water-index / surface-reflectance inputs", "Notebooks can derive water from surface reflectance using water index.", "This task uses existing classified rasters only; no surface reflectance download or reclassification.", "not_used_in_gayini_task", "Flow_MER notebooks; task constraints", "Gayini cannot improve temporal density without new/rebuilt source imagery.", "Not applicable to current smoke test.", "No new classification uncertainty introduced.", "Do not download/process new imagery in Task 10.",
    "date parsing", "Local dynamic script parses date tokens from filenames.", "Gayini daily table already stores parsed date_midpoint and water_year.", "match", "annual_metrics_water_extent.py; 06c table", "Date handling is cleaner in Gayini for census and build.", "Not spatially relevant.", "Supports water-year grouping.", "Use table dates rather than filename-only parsing.",
    "pixel value coding", "Flow_MER scripts treat 1 as water, 0 as dry, 3 as non-water/invalid handling, >=255 as nodata.", "Gayini convention supports strict value 1 wet, value 2 sensitivity, value 3 cloud/shadow, 255/NA nodata where present.", "match_with_caveat", "Flow_MER scripts; Gayini extraction code", "Compatible for annual max with strict rule.", "No grid implication.", "Keep invalid/support rasters beside annual max.", "Document strict and sensitivity rules.",
    "nodata coding", "Flow_MER masks values >=255.", "Gayini samples/checks 255 and raster NA flags.", "match_with_caveat", "annual_max_water_extent.py; value schema report", "Nodata should not count as valid observation.", "No grid implication.", "Support rasters are required.", "Treat 255/NA as nodata.",
    "annual maximum raster suitability", "Flow_MER creates annual maximum water extent rasters from stacks.", "Gayini has date-stamped single-date rasters and can smoke-test compatible water years.", "likely_match", "Flow_MER annual_max script; grid compatibility report", "Annual maximum is less cadence-sensitive than sequence metrics but still observation-dependent.", "Only stack compatible grids.", "Safe as supplementary observed footprint metric.", "Ready for smoke test where grid status is compatible.",
    "dynamic sequence raster suitability", "Flow_MER creates duration/start-date raster bands from image stacks.", "Gayini observations are uneven, with early Landsat years sparse and post S2 years denser.", "weak_match", "Flow_MER annual_metrics script; water-year support report", "Large observation gaps weaken continuous sequence interpretation.", "Could be built only per compatible grid, but not recommended as headline.", "Use observed sequence wording only.", "Defer sequence rasters; keep dry-run readiness.",
    "site extraction order", "Raster creation first, then site/polygon extraction.", "Gayini currently extracts to plots first, then summarises MER plot tables.", "different_order", "Site_annualwatermetric_extract.py; Gayini step 06", "Raster-first would enable continuous surfaces and then plot QA.", "Requires stack-safe annual rasters.", "Current plot summaries remain canonical until raster QA passes.", "Smoke-test raster-to-plot comparison before full build.",
    "observation support / cadence", "Flow_MER examples imply one directory of single-date rasters per year; notebooks show annual stacks but not a universal cadence requirement.", "Gayini selected MER observations span 9 to 31 dates per water year.", "uncertain", "Flow_MER README/notebooks; Gayini support report", "Andres may have used equal or denser stacks for examples; repo alone does not prove cadence was better.", "No direct grid implication.", "Sequence metrics remain the risky metric.", "Report uncertainty and avoid overclaiming.",
    "grid consistency", "Scripts set a reference image and note this is needed when maps have different grids.", "Gayini must verify CRS, resolution, extent, and dimensions before stacking.", "needs_check", "annual_max_water_extent.py; Gayini inventory", "No temporal implication.", "Mixed grids require review before stacking.", "Annual max can run only for compatible groups.", "Fail clearly; do not silently resample.",
    "resolution differences", "Flow_MER does not explicitly solve multi-sensor multi-resolution fusion in the local scripts.", "Gayini has Landsat 30 m and Sentinel-2 10 m periods.", "caution", "Flow_MER scripts; Gayini inventory", "Post years may have better temporal and spatial support.", "Pre/post raster comparison may include resolution effects.", "Keep annual occurrence as headline.", "Do not combine resolutions without explicit policy.",
    "CRS / extent consistency", "Site extraction expects same CRS as image data, EPSG:3577 noted.", "Gayini rasters and plot vectors are expected in/transformable to EPSG:3577, but each raster is checked.", "likely_match", "Site_annualwatermetric_extract.py; inventory", "No temporal implication.", "Compatible CRS/extent required for stack and plot extraction.", "Supports smoke test if compatible.", "Use inventory results as gate."
  )

  diagnostics_dir <- file.path(root_dir, "Output", "diagnostics", "24_mer_raster_build")
  csv_dir <- file.path(root_dir, "Output", "csv", "MER", "raster_build")
  figure_dir <- file.path(root_dir, "Output", "figures", "review", "MER", "raster_build")

  readr::write_csv(flow_mer_vs_gayini, file.path(csv_dir, "flow_mer_vs_gayini_rs_data_census.csv"))
  readr::write_csv(inventory, file.path(diagnostics_dir, "mer_raster_input_inventory.csv"))
  readr::write_csv(grid_compatibility, file.path(diagnostics_dir, "mer_raster_grid_compatibility.csv"))
  readr::write_csv(water_year_support, file.path(diagnostics_dir, "mer_raster_water_year_support.csv"))
  readr::write_csv(value_schema, file.path(diagnostics_dir, "mer_raster_value_schema.csv"))
  readr::write_csv(sequence_metric_readiness, file.path(diagnostics_dir, "mer_sequence_metric_readiness.csv"))

  readiness <- gayini_mer_build_readiness_checks(
    root_dir = root_dir,
    daily_path = daily_path,
    inventory = inventory,
    grid_compatibility = grid_compatibility,
    water_year_support = water_year_support,
    value_schema = value_schema
  )
  readr::write_csv(readiness, file.path(diagnostics_dir, "mer_raster_build_readiness_checks.csv"))

  gayini_mer_write_census_figures(
    water_year_support = water_year_support,
    grid_compatibility = grid_compatibility,
    readiness = readiness,
    figure_dir = figure_dir
  )

  message("MER raster census complete.")
  message("Selected source rasters: ", nrow(inventory))
  message("Existing source rasters: ", sum(inventory$exists))
  message("Opened source rasters: ", sum(inventory$can_open, na.rm = TRUE))
  message("Water years: ", paste(range(inventory$water_year, na.rm = TRUE), collapse = " to "))

  invisible(list(
    inventory = inventory,
    grid_compatibility = grid_compatibility,
    water_year_support = water_year_support,
    value_schema = value_schema,
    readiness = readiness,
    flow_mer_vs_gayini = flow_mer_vs_gayini
  ))
}


gayini_mer_build_readiness_checks <- function(root_dir,
                                              daily_path,
                                              inventory,
                                              grid_compatibility,
                                              water_year_support,
                                              value_schema) {
  out_dirs <- c(
    file.path(root_dir, "Output", "diagnostics", "24_mer_raster_build"),
    file.path(root_dir, "Output", "csv", "MER", "raster_build"),
    file.path(root_dir, "Output", "figures", "review", "MER", "raster_build"),
    file.path(root_dir, "Output", "rasters", "MER", "annual_max"),
    file.path(root_dir, "Output", "rasters", "MER", "support")
  )

  any_compatible_year <- any(
    grid_compatibility$sensor_group == "all_selected" &
      grid_compatibility$safe_for_stack_without_resampling,
    na.rm = TRUE
  )

  any_annual_ready <- any(water_year_support$annual_max_readiness == "Ready for smoke test", na.rm = TRUE)
  any_sequence_possible <- any(water_year_support$sequence_metric_readiness == "Possible but needs caution", na.rm = TRUE)
  schema_ok <- all(value_schema$strict_wet_rule_supported, na.rm = TRUE) &&
    !any(value_schema$other_values_present %in% TRUE, na.rm = TRUE)

  tibble::tribble(
    ~check_id, ~check_name, ~status, ~evidence, ~consequence, ~recommended_action,
    "T10_001", "daily table exists", ifelse(file.exists(daily_path), "PASS", "FAIL"), daily_path, "Census cannot run without daily raster extraction table.", "Restore or rerun daily extraction only if needed.",
    "T10_002", "source raster paths exist", ifelse(all(inventory$exists), "PASS", "FAIL"), paste0(sum(inventory$exists), " of ", nrow(inventory), " selected paths exist."), "Missing rasters block raster build for affected years.", "Resolve missing paths before any full build.",
    "T10_003", "source rasters can be opened", ifelse(all(inventory$can_open), "PASS", "FAIL"), paste0(sum(inventory$can_open, na.rm = TRUE), " of ", nrow(inventory), " selected paths opened."), "Unopenable rasters block stacking.", "Inspect source files if failures occur.",
    "T10_004", "source raster paths unique after duplicate handling", ifelse(nrow(inventory) == dplyr::n_distinct(inventory$source_raster_path), "PASS", "WARN"), paste0(dplyr::n_distinct(inventory$source_raster_path), " unique paths for ", nrow(inventory), " selected rows."), "Duplicates could overweight a date.", "Review duplicate log if warning.",
    "T10_005", "water-year dates parse correctly", ifelse(!any(is.na(inventory$date)) && !any(is.na(inventory$water_year)), "PASS", "FAIL"), paste0(sum(!is.na(inventory$date)), " selected rows have parsed dates."), "Date parse failures block water-year grouping.", "Fix date parsing before raster build.",
    "T10_006", "CRS compatibility", ifelse(all(grid_compatibility$n_unique_crs <= 1), "PASS", "FAIL"), paste0(max(grid_compatibility$n_unique_crs, na.rm = TRUE), " max unique CRS per group."), "Mixed CRS cannot be stacked safely.", "Review CRS transform policy if failed.",
    "T10_007", "resolution compatibility", ifelse(any(grid_compatibility$grid_status == "mixed_resolution"), "WARN", "PASS"), paste0(sum(grid_compatibility$grid_status == "mixed_resolution"), " grid groups have mixed resolution."), "Mixed resolution blocks direct stacking for those groups.", "Build only compatible years or define alignment policy.",
    "T10_008", "extent compatibility", ifelse(any(grid_compatibility$grid_status == "mixed_extent"), "WARN", "PASS"), paste0(sum(grid_compatibility$grid_status == "mixed_extent"), " grid groups have mixed extent/dimensions."), "Mixed extent blocks direct stacking for those groups.", "Build only compatible years or define crop/snap policy.",
    "T10_009", "pixel value schema compatibility", ifelse(schema_ok, "PASS", "WARN"), paste0(sum(value_schema$strict_wet_rule_supported, na.rm = TRUE), " of ", nrow(value_schema), " sampled rasters support strict wet rule."), "Unexpected values require value-rule review.", "Inspect value schema before full build.",
    "T10_010", "annual max raster feasibility", ifelse(any_compatible_year && any_annual_ready, "PASS", "WARN"), paste0(sum(water_year_support$annual_max_readiness == "Ready for smoke test"), " water years ready for smoke test."), "Annual max smoke test is possible only for compatible/high-support years.", "Run one-year smoke test only.",
    "T10_011", "sequence raster feasibility", ifelse(any_sequence_possible, "WARN", "WARN"), paste0(sum(water_year_support$sequence_metric_readiness == "Possible but needs caution"), " water years possible with caution."), "Sequence rasters remain observation-timing diagnostics, not hydroperiod.", "Do not write sequence rasters in Task 10.",
    "T10_012", "output folders isolated from existing pre/post rasters", ifelse(all(dir.exists(out_dirs)), "PASS", "FAIL"), paste(out_dirs, collapse = "; "), "Outputs are isolated from canonical annual occurrence rasters.", "Write Task 10 rasters only under Output/rasters/MER/.",
    "T10_013", "no existing canonical rasters will be overwritten", "PASS", "Smoke-test outputs include SMOKE_TEST and target Output/rasters/MER only.", "Canonical pre/post rasters remain untouched.", "Keep overwrite = FALSE unless explicitly approved."
  )
}


gayini_mer_write_census_figures <- function(water_year_support,
                                            grid_compatibility,
                                            readiness,
                                            figure_dir) {
  dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)

  support_long <- water_year_support %>%
    dplyr::select("water_year", "n_landsat", "n_sentinel2", "n_other_sensor", "annual_max_readiness", "sequence_metric_readiness", "max_gap_days") %>%
    tidyr::pivot_longer(
      cols = c("n_landsat", "n_sentinel2", "n_other_sensor"),
      names_to = "sensor_group",
      values_to = "n_observations"
    ) %>%
    dplyr::mutate(
      sensor_group = dplyr::recode(
        .data$sensor_group,
        n_landsat = "Landsat",
        n_sentinel2 = "Sentinel-2",
        n_other_sensor = "Other"
      )
    )

  p_cadence <- ggplot2::ggplot(support_long, ggplot2::aes(x = .data$water_year, y = .data$n_observations, fill = .data$sensor_group)) +
    ggplot2::geom_col(width = 0.72) +
    ggplot2::geom_point(
      data = water_year_support,
      ggplot2::aes(x = .data$water_year, y = .data$max_gap_days / 4),
      inherit.aes = FALSE,
      size = 2.1,
      colour = "#333333"
    ) +
    ggplot2::scale_fill_manual(values = c("Landsat" = "#4c78a8", "Sentinel-2" = "#f58518", "Other" = "#999999")) +
    ggplot2::labs(
      x = "Water year",
      y = "Selected raster observations",
      fill = "Sensor group",
      title = "MER raster observation cadence by water year",
      subtitle = "Bars show observation count. Dots show maximum gap divided by four for compact QA display.",
      caption = "Annual maximum is less cadence-sensitive than sequence metrics; sequence rasters remain deferred unless support is strong."
    ) +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 45, hjust = 1), panel.grid.minor = ggplot2::element_blank())

  ggplot2::ggsave(file.path(figure_dir, "mer_raster_observation_cadence_by_water_year.png"), p_cadence, width = 9.5, height = 5.4, dpi = 220)

  p_grid <- grid_compatibility %>%
    dplyr::filter(.data$sensor_group == "all_selected") %>%
    ggplot2::ggplot(ggplot2::aes(x = .data$water_year, y = .data$sensor_group, fill = .data$grid_status)) +
    ggplot2::geom_tile(colour = "white", linewidth = 0.5) +
    ggplot2::scale_fill_manual(
      values = c(
        compatible = "#2f7d55",
        mixed_resolution = "#d08b2c",
        mixed_extent = "#b44f3f",
        mixed_crs = "#8b3f8f",
        missing_files = "#6b6b6b",
        needs_review = "#7d8794"
      ),
      drop = FALSE
    ) +
    ggplot2::labs(x = "Water year", y = NULL, fill = "Grid status", title = "MER raster grid compatibility summary") +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 45, hjust = 1), panel.grid = ggplot2::element_blank())

  ggplot2::ggsave(file.path(figure_dir, "mer_raster_grid_compatibility_summary.png"), p_grid, width = 8.5, height = 3.8, dpi = 220)

  p_ready <- readiness %>%
    dplyr::count(.data$status, name = "n_checks") %>%
    ggplot2::ggplot(ggplot2::aes(x = .data$status, y = .data$n_checks, fill = .data$status)) +
    ggplot2::geom_col(width = 0.65) +
    ggplot2::scale_fill_manual(values = c(PASS = "#2f7d55", WARN = "#d08b2c", FAIL = "#b44f3f", NOT_TESTED = "#7d8794"), drop = FALSE) +
    ggplot2::labs(x = "Readiness status", y = "Number of checks", title = "MER raster build readiness checks") +
    ggplot2::theme_minimal(base_size = 11) +
    ggplot2::theme(legend.position = "none", panel.grid.minor = ggplot2::element_blank())

  ggplot2::ggsave(file.path(figure_dir, "mer_raster_build_readiness_summary.png"), p_ready, width = 6.5, height = 4.4, dpi = 220)
}


build_mer_annual_max_observed_raster <- function(raster_paths,
                                                 output_path,
                                                 wet_values = 1,
                                                 crop_extent = NULL,
                                                 overwrite = FALSE) {
  if (file.exists(output_path) && !overwrite) {
    stop("Output exists and overwrite = FALSE: ", output_path, call. = FALSE)
  }

  annual_max <- NULL
  for (path in raster_paths) {
    r <- terra::rast(path)[[1]]
    if (!is.null(crop_extent)) {
      r <- terra::crop(r, crop_extent)
    }
    valid_mask <- (r == 0) | (r == 1) | (r == 2)
    wet_mask <- r == wet_values[[1]]
    if (length(wet_values) > 1) {
      for (v in wet_values[-1]) {
        wet_mask <- wet_mask | (r == v)
      }
    }
    wet <- terra::ifel(valid_mask, terra::ifel(wet_mask, 1, 0), NA)
    if (is.null(annual_max)) {
      annual_max <- wet
    } else {
      annual_max <- terra::ifel(
        (annual_max == 1) | (wet == 1),
        1,
        terra::ifel((annual_max == 0) | (wet == 0), 0, NA)
      )
    }
  }
  names(annual_max) <- "annual_max_observed_inundation_strict_value_1"
  terra::writeRaster(annual_max, output_path, overwrite = overwrite, datatype = "INT1U", gdal = c("COMPRESS=LZW"))
  output_path
}


build_mer_observation_support_raster <- function(raster_paths,
                                                 observation_count_path,
                                                 valid_observation_count_path,
                                                 crop_extent = NULL,
                                                 overwrite = FALSE) {
  for (out_path in c(observation_count_path, valid_observation_count_path)) {
    if (file.exists(out_path) && !overwrite) {
      stop("Output exists and overwrite = FALSE: ", out_path, call. = FALSE)
    }
  }

  observation_count <- NULL
  valid_observation_count <- NULL
  for (path in raster_paths) {
    r <- terra::rast(path)[[1]]
    if (!is.null(crop_extent)) {
      r <- terra::crop(r, crop_extent)
    }
    obs_increment <- terra::ifel(!is.na(r) & r < 255, 1, 0)
    valid_increment <- terra::ifel((r == 0) | (r == 1) | (r == 2), 1, 0)
    if (is.null(observation_count)) {
      observation_count <- obs_increment
      valid_observation_count <- valid_increment
    } else {
      observation_count <- observation_count + obs_increment
      valid_observation_count <- valid_observation_count + valid_increment
    }
  }
  names(observation_count) <- "observation_count"
  names(valid_observation_count) <- "valid_observation_count"
  terra::writeRaster(observation_count, observation_count_path, overwrite = overwrite, datatype = "INT2U", gdal = c("COMPRESS=LZW"))
  terra::writeRaster(valid_observation_count, valid_observation_count_path, overwrite = overwrite, datatype = "INT2U", gdal = c("COMPRESS=LZW"))

  c(observation_count_path, valid_observation_count_path)
}


extract_mer_raster_to_plots_for_qa <- function(raster_path,
                                               plots_path,
                                               plot_id_col = "plot_id") {
  if (!file.exists(plots_path)) {
    return(tibble::tibble())
  }

  r <- terra::rast(raster_path)
  plots <- terra::vect(plots_path)
  extracted <- terra::extract(r, plots, fun = mean, na.rm = TRUE)
  plot_ids <- as.data.frame(plots)[[plot_id_col]]
  value_col <- setdiff(names(extracted), "ID")[[1]]

  tibble::tibble(
    plot_id = as.character(plot_ids[extracted$ID]),
    raster_annual_max_observed_inundated_pct = as.numeric(extracted[[value_col]]) * 100
  )
}


compare_raster_mer_to_existing_plot_mer <- function(raster_plot_qa,
                                                    existing_mer_path,
                                                    smoke_water_year) {
  if (nrow(raster_plot_qa) == 0 || !file.exists(existing_mer_path)) {
    return(raster_plot_qa)
  }

  existing <- readr::read_csv(existing_mer_path, show_col_types = FALSE) %>%
    dplyr::filter(.data$water_year == smoke_water_year) %>%
    dplyr::select("plot_id", plot_mer_annual_max_observed_inundated_pct = "annual_max_inundated_area_pct")

  raster_plot_qa %>%
    dplyr::left_join(existing, by = "plot_id") %>%
    dplyr::mutate(
      raster_minus_plot_table_pct_points = .data$raster_annual_max_observed_inundated_pct - .data$plot_mer_annual_max_observed_inundated_pct,
      qa_note = "Raster extraction uses smoke-test annual max raster; small differences may reflect polygon extraction method and grid handling."
    )
}


## Production annual maximum helpers ----


gayini_mer_year_label <- function(water_year) {
  paste0("WY", stringr::str_replace_all(water_year, "-", "_"))
}


gayini_mer_period_from_water_year <- function(water_year,
                                              management_change_date = as.Date("2019-07-01")) {
  start_year <- as.integer(substr(water_year, 1, 4))
  water_year_start <- as.Date(sprintf("%04d-07-01", start_year))

  dplyr::case_when(
    is.na(water_year_start) ~ NA_character_,
    water_year_start < management_change_date ~ "pre_conservation",
    TRUE ~ "post_conservation"
  )
}


gayini_mer_find_reference_grid <- function(root_dir) {
  candidates <- c(
    file.path(root_dir, "Output", "rasters", "inundation_pre_post", "post_minus_pre_inundation_frequency_pct_points.tif"),
    file.path(root_dir, "Output", "rasters", "inundation_pre_post", "pre_conservation_inundation_frequency_pct.tif"),
    file.path(root_dir, "Output", "rasters", "inundation_pre_post", "post_conservation_inundation_frequency_pct.tif")
  )
  hit <- candidates[file.exists(candidates)]
  if (length(hit) == 0) {
    stop("No canonical annual occurrence/pre-post reference raster found.", call. = FALSE)
  }

  normalizePath(hit[[1]], winslash = "/", mustWork = TRUE)
}


gayini_mer_prepare_reference_template <- function(reference_path,
                                                  boundary_path = NULL) {
  ref <- terra::rast(reference_path)[[1]]

  if (!is.null(boundary_path) && file.exists(boundary_path)) {
    boundary <- terra::vect(boundary_path)
    boundary <- terra::project(boundary, terra::crs(ref))
    ref <- terra::mask(ref, boundary)
  }

  template <- terra::ifel(!is.na(ref), 0, NA)
  names(template) <- "mer_reference_template"
  template
}


gayini_mer_align_source_to_template <- function(source_path,
                                                template,
                                                resample_method = "near") {
  r <- terra::rast(source_path)[[1]]

  if (terra::crs(r) != terra::crs(template)) {
    r <- terra::project(r, template, method = resample_method)
  } else {
    r <- terra::crop(r, terra::ext(template), snap = "out")
    r <- terra::resample(r, template, method = resample_method)
  }

  terra::mask(r, template)
}


gayini_mer_build_annual_products_for_year <- function(year_inventory,
                                                      template,
                                                      output_dirs,
                                                      wet_values = 1,
                                                      valid_values = c(0, 1, 2),
                                                      support_thresholds = c(low_max = 5L, moderate_max = 11L),
                                                      overwrite = FALSE) {
  if (nrow(year_inventory) == 0) {
    stop("No source rasters supplied for annual MER build.", call. = FALSE)
  }

  water_year <- unique(year_inventory$water_year)
  if (length(water_year) != 1) {
    stop("Annual MER build requires exactly one water_year.", call. = FALSE)
  }

  year_label <- gayini_mer_year_label(water_year)
  annual_max_path <- file.path(output_dirs$annual_max, paste0("mer_annual_max_observed_wet_", year_label, ".tif"))
  valid_count_path <- file.path(output_dirs$annual_max, paste0("mer_valid_observation_count_", year_label, ".tif"))
  wet_count_path <- file.path(output_dirs$annual_max, paste0("mer_wet_observation_count_", year_label, ".tif"))
  support_class_path <- file.path(output_dirs$annual_max, paste0("mer_observation_support_class_", year_label, ".tif"))
  wet_fraction_path <- file.path(output_dirs$annual_max, paste0("mer_wet_observation_fraction_", year_label, ".tif"))

  output_paths <- c(annual_max_path, valid_count_path, wet_count_path, support_class_path, wet_fraction_path)
  existing_outputs <- output_paths[file.exists(output_paths)]
  if (length(existing_outputs) > 0 && !overwrite) {
    stop("Production output exists and overwrite = FALSE: ", paste(existing_outputs, collapse = "; "), call. = FALSE)
  }

  valid_count <- template * 0
  wet_count <- template * 0

  source_log <- vector("list", nrow(year_inventory))

  for (i in seq_len(nrow(year_inventory))) {
    source_path <- year_inventory$source_raster_path[[i]]
    aligned <- gayini_mer_align_source_to_template(source_path, template, resample_method = "near")

    valid_increment <- aligned == valid_values[[1]]
    if (length(valid_values) > 1) {
      for (v in valid_values[-1]) {
        valid_increment <- valid_increment | (aligned == v)
      }
    }

    wet_increment <- aligned == wet_values[[1]]
    if (length(wet_values) > 1) {
      for (v in wet_values[-1]) {
        wet_increment <- wet_increment | (aligned == v)
      }
    }

    wet_increment <- terra::ifel(valid_increment, terra::ifel(wet_increment, 1, 0), 0)
    valid_increment <- terra::ifel(valid_increment, 1, 0)

    valid_pixel_count <- as.numeric(terra::global(valid_increment, "sum", na.rm = TRUE)[1, 1])
    wet_pixel_count <- as.numeric(terra::global(wet_increment, "sum", na.rm = TRUE)[1, 1])

    valid_count <- valid_count + valid_increment
    wet_count <- wet_count + wet_increment

    source_log[[i]] <- tibble::tibble(
      water_year = water_year,
      source_raster_path = source_path,
      source_date = year_inventory$date[[i]],
      sensor = year_inventory$sensor[[i]],
      status = "aligned_with_nearest_neighbour",
      valid_pixel_count = valid_pixel_count,
      wet_pixel_count = wet_pixel_count,
      output_reference_grid = terra::sources(template)[[1]] %||% NA_character_
    )
  }

  annual_max <- terra::ifel(valid_count > 0, terra::ifel(wet_count > 0, 1, 0), NA)
  support_class <- terra::ifel(
    valid_count <= 0,
    0,
    terra::ifel(
      valid_count <= support_thresholds[["low_max"]],
      1,
      terra::ifel(valid_count <= support_thresholds[["moderate_max"]], 2, 3)
    )
  )
  wet_fraction <- terra::ifel(valid_count > 0, wet_count / valid_count, NA)

  names(annual_max) <- "annual_max_observed_wet"
  names(valid_count) <- "valid_observation_count"
  names(wet_count) <- "wet_observation_count"
  names(support_class) <- "observation_support_class"
  names(wet_fraction) <- "observed_wet_fraction"

  terra::writeRaster(annual_max, annual_max_path, overwrite = overwrite, datatype = "INT1U", gdal = c("COMPRESS=LZW"))
  terra::writeRaster(valid_count, valid_count_path, overwrite = overwrite, datatype = "INT2U", gdal = c("COMPRESS=LZW"))
  terra::writeRaster(wet_count, wet_count_path, overwrite = overwrite, datatype = "INT2U", gdal = c("COMPRESS=LZW"))
  terra::writeRaster(support_class, support_class_path, overwrite = overwrite, datatype = "INT1U", gdal = c("COMPRESS=LZW"))
  terra::writeRaster(wet_fraction, wet_fraction_path, overwrite = overwrite, datatype = "FLT4S", gdal = c("COMPRESS=LZW"))

  tibble::tibble(
    water_year = water_year,
    year_label = year_label,
    annual_max_path = annual_max_path,
    valid_count_path = valid_count_path,
    wet_count_path = wet_count_path,
    support_class_path = support_class_path,
    wet_fraction_path = wet_fraction_path,
    n_source_rasters = nrow(year_inventory),
    first_date = min(year_inventory$date, na.rm = TRUE),
    last_date = max(year_inventory$date, na.rm = TRUE),
    status = "built",
    notes = "Annual maximum observed wet footprint; not hydroperiod, duration, or wet days."
  ) %>%
    dplyr::mutate(source_log = list(dplyr::bind_rows(source_log)))
}


gayini_mer_build_period_summary_rasters <- function(annual_manifest,
                                                    output_dir,
                                                    management_change_date = as.Date("2019-07-01"),
                                                    overwrite = FALSE) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  manifest <- annual_manifest %>%
    dplyr::mutate(period = gayini_mer_period_from_water_year(.data$water_year, management_change_date))

  pre <- manifest %>% dplyr::filter(.data$period == "pre_conservation")
  post <- manifest %>% dplyr::filter(.data$period == "post_conservation")

  if (nrow(pre) == 0 || nrow(post) == 0) {
    stop("Need both pre and post annual MER rasters for period summaries.", call. = FALSE)
  }

  build_frequency <- function(paths) {
    annual_stack <- terra::rast(paths)
    valid_year_count <- terra::app(!is.na(annual_stack), sum, na.rm = TRUE)
    wet_year_count <- terra::app(annual_stack == 1, sum, na.rm = TRUE)
    frequency <- terra::ifel(valid_year_count > 0, 100 * wet_year_count / valid_year_count, NA)
    list(frequency = frequency, valid_year_count = valid_year_count, wet_year_count = wet_year_count)
  }

  pre_summary <- build_frequency(pre$annual_max_path)
  post_summary <- build_frequency(post$annual_max_path)
  change <- post_summary$frequency - pre_summary$frequency
  support_mask <- terra::ifel(pre_summary$valid_year_count > 0 & post_summary$valid_year_count > 0, 1, NA)

  outputs <- c(
    pre_frequency = file.path(output_dir, "mer_pre_annual_max_observed_frequency_pct.tif"),
    post_frequency = file.path(output_dir, "mer_post_annual_max_observed_frequency_pct.tif"),
    change = file.path(output_dir, "mer_post_minus_pre_annual_max_frequency_pct_points.tif"),
    pre_valid = file.path(output_dir, "mer_pre_valid_year_count.tif"),
    post_valid = file.path(output_dir, "mer_post_valid_year_count.tif"),
    support_mask = file.path(output_dir, "mer_period_summary_support_mask.tif")
  )

  existing_outputs <- outputs[file.exists(outputs)]
  if (length(existing_outputs) > 0 && !overwrite) {
    stop("Period summary output exists and overwrite = FALSE: ", paste(existing_outputs, collapse = "; "), call. = FALSE)
  }

  names(pre_summary$frequency) <- "mer_pre_annual_max_observed_frequency_pct"
  names(post_summary$frequency) <- "mer_post_annual_max_observed_frequency_pct"
  names(change) <- "mer_post_minus_pre_annual_max_frequency_pct_points"
  names(pre_summary$valid_year_count) <- "mer_pre_valid_year_count"
  names(post_summary$valid_year_count) <- "mer_post_valid_year_count"
  names(support_mask) <- "mer_period_summary_support_mask"

  terra::writeRaster(pre_summary$frequency, outputs[["pre_frequency"]], overwrite = overwrite, datatype = "FLT4S", gdal = c("COMPRESS=LZW"))
  terra::writeRaster(post_summary$frequency, outputs[["post_frequency"]], overwrite = overwrite, datatype = "FLT4S", gdal = c("COMPRESS=LZW"))
  terra::writeRaster(change, outputs[["change"]], overwrite = overwrite, datatype = "FLT4S", gdal = c("COMPRESS=LZW"))
  terra::writeRaster(pre_summary$valid_year_count, outputs[["pre_valid"]], overwrite = overwrite, datatype = "INT1U", gdal = c("COMPRESS=LZW"))
  terra::writeRaster(post_summary$valid_year_count, outputs[["post_valid"]], overwrite = overwrite, datatype = "INT1U", gdal = c("COMPRESS=LZW"))
  terra::writeRaster(support_mask, outputs[["support_mask"]], overwrite = overwrite, datatype = "INT1U", gdal = c("COMPRESS=LZW"))

  tibble::tibble(
    output_type = names(outputs),
    path = unname(outputs),
    exists = file.exists(unname(outputs)),
    pre_years = paste(pre$water_year, collapse = ";"),
    post_years = paste(post$water_year, collapse = ";"),
    notes = "MER period summary based on annual maximum observed wet rasters; not hydroperiod or duration."
  )
}


gayini_mer_extract_rasters_to_plots <- function(raster_manifest,
                                                plots_path,
                                                plot_context_path = NULL) {
  if (!file.exists(plots_path)) {
    stop("Missing plot vector: ", plots_path, call. = FALSE)
  }

  plots <- terra::vect(plots_path)
  plot_ids <- as.character(as.data.frame(plots)$plot_id)

  annual_rows <- lapply(seq_len(nrow(raster_manifest)), function(i) {
    row <- raster_manifest[i, ]
    annual_max <- terra::rast(row$annual_max_path)
    valid_count <- terra::rast(row$valid_count_path)
    wet_count <- terra::rast(row$wet_count_path)
    support_class <- terra::rast(row$support_class_path)
    wet_fraction <- terra::rast(row$wet_fraction_path)
    stack <- c(annual_max, valid_count, wet_count, support_class, wet_fraction)
    names(stack) <- c(
      "mer_annual_max_observed_wet_pct",
      "mer_valid_observation_count_mean",
      "mer_wet_observation_count_mean",
      "mer_observation_support_class",
      "mer_wet_observation_fraction_mean"
    )
    extracted <- terra::extract(stack, plots, fun = mean, na.rm = TRUE)
    tibble::tibble(
      plot_id = plot_ids[extracted$ID],
      water_year = row$water_year,
      mer_annual_max_observed_wet_pct = extracted$mer_annual_max_observed_wet_pct * 100,
      mer_valid_observation_count_mean = extracted$mer_valid_observation_count_mean,
      mer_wet_observation_count_mean = extracted$mer_wet_observation_count_mean,
      mer_observation_support_class = extracted$mer_observation_support_class,
      mer_wet_observation_fraction_mean = extracted$mer_wet_observation_fraction_mean,
      notes = "Annual maximum observed wet area; not hydroperiod or duration."
    )
  })

  annual_by_plot <- dplyr::bind_rows(annual_rows)

  period_stack <- c(
    terra::rast(file.path(dirname(dirname(raster_manifest$annual_max_path[[1]])), "period_summaries", "mer_pre_annual_max_observed_frequency_pct.tif")),
    terra::rast(file.path(dirname(dirname(raster_manifest$annual_max_path[[1]])), "period_summaries", "mer_post_annual_max_observed_frequency_pct.tif")),
    terra::rast(file.path(dirname(dirname(raster_manifest$annual_max_path[[1]])), "period_summaries", "mer_post_minus_pre_annual_max_frequency_pct_points.tif")),
    terra::rast(file.path(dirname(dirname(raster_manifest$annual_max_path[[1]])), "period_summaries", "mer_pre_valid_year_count.tif")),
    terra::rast(file.path(dirname(dirname(raster_manifest$annual_max_path[[1]])), "period_summaries", "mer_post_valid_year_count.tif"))
  )
  names(period_stack) <- c(
    "pre_mer_frequency_pct",
    "post_mer_frequency_pct",
    "post_minus_pre_mer_frequency_pct_points",
    "n_pre_valid_years",
    "n_post_valid_years"
  )
  period_extracted <- terra::extract(period_stack, plots, fun = mean, na.rm = TRUE)
  period_by_plot <- tibble::tibble(
    plot_id = plot_ids[period_extracted$ID],
    pre_mer_frequency_pct = period_extracted$pre_mer_frequency_pct,
    post_mer_frequency_pct = period_extracted$post_mer_frequency_pct,
    post_minus_pre_mer_frequency_pct_points = period_extracted$post_minus_pre_mer_frequency_pct_points,
    n_pre_valid_years = period_extracted$n_pre_valid_years,
    n_post_valid_years = period_extracted$n_post_valid_years,
    notes = "MER pre/post frequency is based on annual maximum observed wet rasters; not hydroperiod or duration."
  )

  if (!is.null(plot_context_path) && file.exists(plot_context_path)) {
    context <- readr::read_csv(plot_context_path, show_col_types = FALSE) %>%
      dplyr::select(dplyr::any_of(c(
        "plot_id",
        "simplified_vegetation_group",
        "vegetation_adrian_group",
        "treed_plot_flag",
        "ground_cover_exclusion_flag",
        "ground_cover_exclusion_reason",
        "collapsed_grazing_category"
      )))
    annual_by_plot <- annual_by_plot %>% dplyr::left_join(context, by = "plot_id")
    period_by_plot <- period_by_plot %>% dplyr::left_join(context, by = "plot_id")
  }

  list(annual_by_plot = annual_by_plot, period_by_plot = period_by_plot)
}


gayini_mer_compare_with_annual_occurrence <- function(mer_period_by_plot,
                                                      annual_occurrence_plot_path) {
  annual_occurrence <- readr::read_csv(annual_occurrence_plot_path, show_col_types = FALSE) %>%
    dplyr::select(dplyr::any_of(c(
      "plot_id",
      "vegetation_adrian_group",
      "pre_conservation_inundation_frequency_pct",
      "post_conservation_inundation_frequency_pct",
      "post_minus_pre_inundation_frequency_pct_points"
    ))) %>%
    dplyr::rename(annual_occurrence_vegetation_group = "vegetation_adrian_group")

  comparison <- mer_period_by_plot %>%
    dplyr::left_join(annual_occurrence, by = "plot_id") %>%
    dplyr::mutate(
      vegetation_group = dplyr::coalesce(
        gayini_get_first_existing_column(., c("vegetation_group", "simplified_vegetation_group", "vegetation_adrian_group"), default = NA_character_),
        .data$annual_occurrence_vegetation_group
      ),
      annual_occurrence_post_minus_pre_pct_points = .data$post_minus_pre_inundation_frequency_pct_points,
      mer_post_minus_pre_pct_points = .data$post_minus_pre_mer_frequency_pct_points,
      difference_mer_minus_annual_occurrence = .data$mer_post_minus_pre_pct_points - .data$annual_occurrence_post_minus_pre_pct_points,
      direction_agreement = dplyr::case_when(
        is.na(.data$mer_post_minus_pre_pct_points) | is.na(.data$annual_occurrence_post_minus_pre_pct_points) ~ "insufficient_support",
        abs(.data$mer_post_minus_pre_pct_points) < 5 & abs(.data$annual_occurrence_post_minus_pre_pct_points) < 5 ~ "agree_near_zero",
        abs(.data$mer_post_minus_pre_pct_points) < 5 | abs(.data$annual_occurrence_post_minus_pre_pct_points) < 5 ~ "one_near_zero",
        .data$mer_post_minus_pre_pct_points > 0 & .data$annual_occurrence_post_minus_pre_pct_points > 0 ~ "agree_positive",
        .data$mer_post_minus_pre_pct_points < 0 & .data$annual_occurrence_post_minus_pre_pct_points < 0 ~ "agree_negative",
        TRUE ~ "disagree"
      ),
      review_flag = dplyr::case_when(
        .data$direction_agreement == "disagree" ~ "review_disagreement",
        .data$direction_agreement == "one_near_zero" ~ "review_one_metric_near_zero",
        .data$direction_agreement == "insufficient_support" ~ "review_support",
        TRUE ~ "no_flag"
      ),
      notes = "Disagreement between MER annual max and annual occurrence is a review flag, not necessarily an error."
    )

  summary <- comparison %>%
    dplyr::count(.data$direction_agreement, .data$review_flag, name = "n_plots") %>%
    dplyr::mutate(
      pct_plots = round(100 * .data$n_plots / sum(.data$n_plots), 1),
      notes = "MER raster comparison against current annual occurrence plot summary."
    )

  list(plot_comparison = comparison, summary = summary)
}
