## Gayini fractional-cover extraction visual checks ----


## Purpose:
## This script is a diagnostic / visual QA script only.
## It is not part of the numbered main workflow.
## It creates PNG maps for irregular plot × raster cases so that we can check
## whether missing or low-coverage extraction results are consistent with
## source-raster NoData / footprint issues rather than processing errors.


## User settings ----


ROOT_DIR <- "D:/Github_repos/Gayini"


MAX_ALL_MISSING_CASES <- 12


MAX_LOW_COVERAGE_CASES <- 12


MAX_CLEAN_COMPARISON_CASES <- 6


LOW_COVERAGE_THRESHOLD_EFFECTIVE_CELLS <- 5


MAP_BUFFER_METRES_MINIMUM <- 120


PLOT_BUFFER_PIXELS_FOR_CONTEXT <- 1


SHOW_PLOT_BUFFER <- TRUE


RASTER_BANDS_TO_PLOT <- c(1, 2, 3)


## Package setup ----


required_packages <- c(
  "terra",
  "sf",
  "dplyr",
  "readr",
  "stringr",
  "purrr",
  "tibble"
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


## Root and path checks ----


if (!dir.exists(ROOT_DIR)) {
  ROOT_DIR <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
}


plots_path <- file.path(ROOT_DIR, "data_intermediate", "spatial", "plots_clean.gpkg")


raster_subset_path <- file.path(ROOT_DIR, "data_intermediate", "raster_catalog", "raster_dev_subset.csv")


fc_output_path <- file.path(ROOT_DIR, "Output", "csv", "04b_fractional_cover_all_dev_plots.csv")


figures_dir <- file.path(ROOT_DIR, "Output", "figures", "extraction_checks", "fractional_cover")


diagnostics_dir <- file.path(ROOT_DIR, "Output", "diagnostics", "extraction_checks")


dir.create(figures_dir, recursive = TRUE, showWarnings = FALSE)


dir.create(diagnostics_dir, recursive = TRUE, showWarnings = FALSE)


required_files <- c(plots_path, raster_subset_path, fc_output_path)


missing_files <- required_files[!file.exists(required_files)]


if (length(missing_files) > 0) {
  stop(
    "Missing required input files. Please check these paths: ",
    paste(missing_files, collapse = "; "),
    call. = FALSE
  )
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


gayini_safe_sum <- function(x) {
  if (all(is.na(x))) {
    return(NA_real_)
  }
  sum(x, na.rm = TRUE)
}


gayini_make_safe_file_label <- function(x) {
  x |>
    stringr::str_replace_all("[^A-Za-z0-9_]+", "_") |>
    stringr::str_replace_all("_+", "_") |>
    stringr::str_replace_all("^_|_$", "")
}


gayini_wrap_label <- function(x, width = 72) {
  if (is.na(x) || length(x) == 0) {
    return(NA_character_)
  }
  paste(strwrap(as.character(x), width = width), collapse = "\n")
}


gayini_make_panel_title <- function(panel_label, coverage_status) {
  paste0(panel_label, "\n", coverage_status)
}


gayini_make_case_title <- function(case_row, raster, raster_res) {
  valid_count <- case_row$total_valid_count

  if (is.na(valid_count)) {
    valid_count_label <- "NA"
  } else {
    valid_count_label <- format(round(valid_count, 3), nsmall = 3, trim = TRUE)
  }

  raster_crs_code <- terra::crs(raster, describe = TRUE)$code

  if (is.null(raster_crs_code) || is.na(raster_crs_code) || raster_crs_code == "") {
    raster_crs_code <- "CRS available, code not reported"
  }

  line_1 <- paste(
    "Plot", case_row$plot_id,
    "|", case_row$check_group,
    "|", case_row$coverage_status
  )

  line_2 <- paste(
    "Date", case_row$date_start, "to", case_row$date_end,
    "| valid effective cells", valid_count_label
  )

  line_3 <- paste(
    "Raster", case_row$file_name
  )

  line_4 <- paste(
    "Raster CRS", raster_crs_code,
    "| resolution", paste(round(abs(raster_res), 3), collapse = " × ")
  )

  c(
    gayini_wrap_label(line_1, width = 92),
    gayini_wrap_label(line_2, width = 92),
    gayini_wrap_label(line_3, width = 92),
    gayini_wrap_label(line_4, width = 92)
  )
}


gayini_get_raster_path_column <- function(raster_catalog) {
  gayini_first_existing_column(
    raster_catalog,
    c("file_path", "path", "full_path", "raster_path", "source_path"),
    "raster file path"
  )
}


gayini_make_case_table <- function(fc_output, low_coverage_threshold) {
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
      total_valid_count     = gayini_safe_sum(valid_coverage_count),
      min_valid_count       = ifelse(all(is.na(valid_coverage_count)), NA_real_, min(valid_coverage_count, na.rm = TRUE)),
      max_valid_count       = ifelse(all(is.na(valid_coverage_count)), NA_real_, max(valid_coverage_count, na.rm = TRUE)),
      treatment             = dplyr::first(treatment),
      vegetation            = dplyr::first(vegetation),
      .groups               = "drop"
    ) |>
    dplyr::mutate(
      coverage_status = dplyr::case_when(
        all_bands_missing ~ "all_bands_missing",
        is.na(total_valid_count) ~ "unknown_coverage",
        total_valid_count < low_coverage_threshold ~ "low_valid_coverage",
        TRUE ~ "adequate_valid_coverage"
      )
    )
}


gayini_select_check_cases <- function(case_table) {
  all_missing_cases <- case_table |>
    dplyr::filter(coverage_status == "all_bands_missing") |>
    dplyr::arrange(date_start, plot_id) |>
    dplyr::slice_head(n = MAX_ALL_MISSING_CASES) |>
    dplyr::mutate(check_group = "all_bands_missing")


  low_coverage_cases <- case_table |>
    dplyr::filter(coverage_status == "low_valid_coverage") |>
    dplyr::arrange(total_valid_count, date_start, plot_id) |>
    dplyr::slice_head(n = MAX_LOW_COVERAGE_CASES) |>
    dplyr::mutate(check_group = "low_valid_coverage")


  clean_cases <- case_table |>
    dplyr::filter(coverage_status == "adequate_valid_coverage") |>
    dplyr::arrange(date_start, plot_id) |>
    dplyr::slice_head(n = MAX_CLEAN_COMPARISON_CASES) |>
    dplyr::mutate(check_group = "clean_comparison")


  dplyr::bind_rows(all_missing_cases, low_coverage_cases, clean_cases) |>
    dplyr::distinct(plot_id, file_name, .keep_all = TRUE)
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
    raster                  = raster,
    plot_vect               = plot_vect,
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
    stringr::str_remove(case_row$file_name, "\\.[A-Za-z0-9]+$"),
    sep = "__"
  ) |>
    gayini_make_safe_file_label()


  output_png <- file.path(figures_dir, paste0(file_label, ".png"))


  png(filename = output_png, width = 2600, height = 2200, res = 220)


  old_par <- par(no.readonly = TRUE)


  on.exit({
    par(old_par)
    dev.off()
  }, add = TRUE)


  case_title <- gayini_make_case_title(
    case_row   = case_row,
    raster     = raster,
    raster_res = raster_res
  )


  par(
    mfrow    = c(2, 2),
    mar      = c(2.6, 2.6, 3.1, 4.8),
    oma      = c(0.4, 0.4, 8.4, 0.4),
    cex      = 0.78,
    cex.axis = 0.72,
    cex.main = 0.82,
    mgp      = c(1.7, 0.45, 0)
  )


  for (band_index in RASTER_BANDS_TO_PLOT) {
    if (band_index <= terra::nlyr(raster_crop)) {
      terra::plot(
        raster_crop[[band_index]],
        main = gayini_make_panel_title(
          paste0("Band ", band_index),
          case_row$coverage_status
        ),
        axes = TRUE,
        cex.main = 0.82,
        plg = list(cex = 0.72)
      )


      if (SHOW_PLOT_BUFFER && !is.null(plot_buffer)) {
        terra::plot(plot_buffer, add = TRUE, border = "grey30", lwd = 1, lty = 2)
      }


      terra::plot(plot_vect, add = TRUE, border = "red", lwd = 2)
    }
  }


  terra::plot(
    valid_mask,
    main = gayini_make_panel_title("Valid data mask", "Band 1"),
    axes = TRUE,
    cex.main = 0.82,
    plg = list(cex = 0.72)
  )


  if (SHOW_PLOT_BUFFER && !is.null(plot_buffer)) {
    terra::plot(plot_buffer, add = TRUE, border = "grey30", lwd = 1, lty = 2)
  }


  terra::plot(plot_vect, add = TRUE, border = "red", lwd = 2)


  mtext(case_title[1], side = 3, outer = TRUE, line = 6.2, cex = 0.88, font = 2)
  mtext(case_title[2], side = 3, outer = TRUE, line = 4.8, cex = 0.76)
  mtext(case_title[3], side = 3, outer = TRUE, line = 3.4, cex = 0.68)
  mtext(case_title[4], side = 3, outer = TRUE, line = 2.0, cex = 0.68)
  mtext("Red outline = 1 ha plot; grey dashed outline = one-pixel contextual buffer only", side = 1, outer = TRUE, line = -0.2, cex = 0.66)


  tibble::tibble(
    plot_id                 = case_row$plot_id,
    file_name               = case_row$file_name,
    date_start              = case_row$date_start,
    date_end                = case_row$date_end,
    check_group             = case_row$check_group,
    coverage_status         = case_row$coverage_status,
    total_valid_count       = case_row$total_valid_count,
    raster_path             = raster_path,
    output_png              = output_png,
    raster_crs              = terra::crs(raster),
    raster_res_x            = terra::res(raster)[1],
    raster_res_y            = terra::res(raster)[2],
    raster_band_count       = terra::nlyr(raster),
    plot_status             = "png_created"
  )
}


## Read inputs ----


plots_sf <- sf::st_read(plots_path, quiet = TRUE)


raster_subset <- readr::read_csv(raster_subset_path, show_col_types = FALSE)


fc_output <- readr::read_csv(fc_output_path, show_col_types = FALSE)


message("Clean plots available: ", nrow(plots_sf))


message("Development raster subset rows: ", nrow(raster_subset))


message("Fractional-cover extraction rows: ", nrow(fc_output))


## Prepare raster lookup ----


raster_path_col <- gayini_get_raster_path_column(raster_subset)


raster_lookup <- raster_subset |>
  dplyr::filter(product == "landsat_fractional_cover") |>
  dplyr::select(file_name, raster_path = dplyr::all_of(raster_path_col)) |>
  dplyr::distinct(file_name, .keep_all = TRUE)


raster_lookup <- stats::setNames(raster_lookup$raster_path, raster_lookup$file_name)


## Select cases for visual checking ----


case_table <- gayini_make_case_table(
  fc_output              = fc_output,
  low_coverage_threshold = LOW_COVERAGE_THRESHOLD_EFFECTIVE_CELLS
)


selected_cases <- gayini_select_check_cases(case_table)


case_table_path <- file.path(diagnostics_dir, "extraction_check_fractional_cover_case_table.csv")


selected_cases_path <- file.path(diagnostics_dir, "extraction_check_fractional_cover_selected_cases.csv")


readr::write_csv(case_table, case_table_path)


readr::write_csv(selected_cases, selected_cases_path)


message("Wrote: ", case_table_path)


message("Wrote: ", selected_cases_path)


message("Selected cases for PNG checks: ", nrow(selected_cases))


## Create PNG checks ----


plot_results <- purrr::map_dfr(
  seq_len(nrow(selected_cases)),
  function(i) {
    message("Creating extraction-check PNG ", i, " of ", nrow(selected_cases), ": ", selected_cases$plot_id[i], " | ", selected_cases$file_name[i])
    gayini_plot_single_case(
      case_row      = selected_cases[i, ],
      plots_sf      = plots_sf,
      raster_lookup = raster_lookup,
      figures_dir   = figures_dir
    )
  }
)


plot_results_path <- file.path(diagnostics_dir, "extraction_check_fractional_cover_png_index.csv")


readr::write_csv(plot_results, plot_results_path)


message("Wrote: ", plot_results_path)


message("Extraction-check PNG folder: ", figures_dir)


message("Fractional-cover extraction visual check complete.")
