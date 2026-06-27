## Gayini review extraction-method map assets ----
##
## Purpose:
## Create slide-ready PNG examples showing how plot-level ground-cover and
## inundation raster summaries are derived from actual georeferenced rasters.
##
## This is a targeted figure-generation script only. It does not run extraction,
## raster builds, BFAST/tbreak, archiving, or any presentation-deck workflow.


## Settings ----


ROOT_DIR <- "D:/Github_repos/Gayini"

OUTPUT_DIR <- file.path(
  ROOT_DIR,
  "Output",
  "reports",
  "adrian_review_png_assets"
)

PLOTS_PATH <- file.path(
  ROOT_DIR,
  "data_intermediate",
  "spatial",
  "plots_clean.gpkg"
)

GROUND_COVER_INPUT <- file.path(
  ROOT_DIR,
  "Output",
  "csv",
  "04c_fractional_cover_full.csv"
)

INUNDATION_INPUT <- file.path(
  ROOT_DIR,
  "Output",
  "csv",
  "curated_annual_inundation_timeseries.csv"
)

MAP_BUFFER_METRES_MINIMUM <- 120
PLOT_BUFFER_PIXELS_FOR_CONTEXT <- 1
GROUND_COVER_BANDS_TO_PLOT <- c(1, 2, 3)
INUNDATION_NODATA_VALUES <- c(255)

PANEL_WIDTH_PX <- 5200
PANEL_HEIGHT_PX <- 5600
INDIVIDUAL_WIDTH_PX <- 3000
INDIVIDUAL_HEIGHT_PX <- 2450
PNG_RES <- 240


## Package setup ----


required_packages <- c(
  "dplyr",
  "magrittr",
  "readr",
  "sf",
  "stringr",
  "terra",
  "tibble"
)

missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]

if (length(missing_packages) > 0) {
  stop(
    "Missing required packages: ",
    paste(missing_packages, collapse = ", "),
    call. = FALSE
  )
}

invisible(lapply(required_packages, require, character.only = TRUE))

if (!dir.exists(ROOT_DIR)) {
  ROOT_DIR <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)
}

dir.create(OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)


## Helpers ----


gayini_check_file <- function(path, label) {
  if (!file.exists(path)) {
    stop(label, " not found: ", path, call. = FALSE)
  }

  invisible(path)
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


gayini_fmt_number <- function(x, digits = 2, missing = "NA") {
  if (length(x) == 0) {
    return(character())
  }

  output <- format(round(x, digits), nsmall = digits, trim = TRUE)
  output[is.na(x)] <- missing
  output
}


gayini_display_path <- function(path) {
  normalizePath(path, winslash = "/", mustWork = FALSE)
}


gayini_make_plot_buffer <- function(plot_vect, raster_res, buffer_pixels) {
  if (buffer_pixels <= 0) {
    return(NULL)
  }

  buffer_distance <- max(abs(raster_res), na.rm = TRUE) * buffer_pixels

  terra::buffer(plot_vect, width = buffer_distance)
}


gayini_crop_raster_for_plot <- function(raster, plot_vect) {
  raster_res <- terra::res(raster)
  map_buffer <- max(
    MAP_BUFFER_METRES_MINIMUM,
    max(abs(raster_res), na.rm = TRUE) * 4
  )

  plot_extent <- terra::ext(plot_vect)

  plot_extent <- terra::ext(
    plot_extent$xmin - map_buffer,
    plot_extent$xmax + map_buffer,
    plot_extent$ymin - map_buffer,
    plot_extent$ymax + map_buffer
  )

  terra::crop(raster, plot_extent)
}


gayini_get_plot_vect <- function(plots_sf, raster, plot_id) {
  plot_sf <- plots_sf %>%
    dplyr::filter(.data$plot_id == .env$plot_id)

  if (nrow(plot_sf) != 1) {
    stop(
      "Expected one plot polygon for ",
      plot_id,
      "; found ",
      nrow(plot_sf),
      call. = FALSE
    )
  }

  plot_sf %>%
    sf::st_transform(crs = terra::crs(raster)) %>%
    terra::vect()
}


gayini_panel_has_values <- function(raster_layer) {
  values <- terra::values(raster_layer, mat = FALSE)

  length(values) > 0 && !all(is.na(values))
}


gayini_plot_blank_extent <- function(raster_layer, main, note = "No raster values in crop") {
  raster_extent <- terra::ext(raster_layer)

  plot(
    NA,
    xlim = c(raster_extent$xmin, raster_extent$xmax),
    ylim = c(raster_extent$ymin, raster_extent$ymax),
    xlab = "",
    ylab = "",
    main = main,
    axes = TRUE
  )
  box()
  text(
    x = mean(c(raster_extent$xmin, raster_extent$xmax)),
    y = mean(c(raster_extent$ymin, raster_extent$ymax)),
    labels = note,
    cex = 0.72,
    col = "grey35"
  )
}


gayini_add_overlays <- function(plot_vect, plot_buffer) {
  if (!is.null(plot_buffer)) {
    terra::plot(plot_buffer, add = TRUE, border = "grey35", lwd = 1.1, lty = 2)
  }

  terra::plot(plot_vect, add = TRUE, border = "red", lwd = 2.2)
}


gayini_plot_raster_panel <- function(raster_layer,
                                     main,
                                     plot_vect,
                                     plot_buffer,
                                     col = NULL,
                                     value_labels = NULL,
                                     legend = TRUE) {
  if (!gayini_panel_has_values(raster_layer)) {
    gayini_plot_blank_extent(raster_layer, main)
    gayini_add_overlays(plot_vect, plot_buffer)
    return(invisible(NULL))
  }

  plot_args <- list(
    x = raster_layer,
    main = main,
    axes = TRUE,
    cex.main = 0.82,
    cex.axis = 0.70,
    cex.lab = 0.70,
    legend = legend,
    colNA = "white"
  )

  if (!is.null(col)) {
    plot_args$col <- col
  }

  if (!is.null(value_labels)) {
    plot_args$type <- "classes"
    plot_args$levels <- value_labels
  }

  do.call(terra::plot, plot_args)
  gayini_add_overlays(plot_vect, plot_buffer)

  invisible(NULL)
}


gayini_make_valid_mask <- function(raster_layer) {
  valid_mask <- !is.na(raster_layer)
  names(valid_mask) <- "valid_data_mask"
  valid_mask
}


gayini_clean_inundation_raster <- function(raster_layer) {
  clean_raster <- terra::ifel(
    raster_layer %in% INUNDATION_NODATA_VALUES,
    NA,
    raster_layer
  )

  names(clean_raster) <- "inundation_count"
  clean_raster
}


gayini_make_wet_mask <- function(clean_raster) {
  wet_mask <- terra::ifel(
    is.na(clean_raster),
    NA,
    terra::ifel(clean_raster > 0, 1, 0)
  )

  names(wet_mask) <- "wet_mask_count_gt_0"
  wet_mask
}


gayini_make_raster_context <- function(plots_sf, raster_path, plot_id) {
  raster <- terra::rast(raster_path)
  plot_vect <- gayini_get_plot_vect(plots_sf, raster, plot_id)
  raster_crop <- gayini_crop_raster_for_plot(raster, plot_vect)
  plot_buffer <- gayini_make_plot_buffer(
    plot_vect = plot_vect,
    raster_res = terra::res(raster_crop),
    buffer_pixels = PLOT_BUFFER_PIXELS_FOR_CONTEXT
  )

  list(
    raster = raster,
    raster_crop = raster_crop,
    plot_vect = plot_vect,
    plot_buffer = plot_buffer
  )
}


gayini_open_png <- function(output_path, width, height) {
  grDevices::png(
    filename = output_path,
    width = width,
    height = height,
    res = PNG_RES
  )
}


gayini_write_text_panel <- function(title, lines) {
  plot.new()
  text(
    x = 0.02,
    y = 0.95,
    labels = title,
    adj = c(0, 1),
    font = 2,
    cex = 0.86
  )

  wrapped_lines <- lines %>%
    stringr::str_wrap(width = 46)

  text(
    x = 0.02,
    y = 0.82,
    labels = paste(wrapped_lines, collapse = "\n\n"),
    adj = c(0, 1),
    cex = 0.64,
    col = "grey20"
  )
}


## Input checks ----


gayini_check_file(PLOTS_PATH, "Clean plot GeoPackage")
gayini_check_file(GROUND_COVER_INPUT, "Ground-cover extraction CSV")
gayini_check_file(INUNDATION_INPUT, "Curated annual inundation CSV")

plots_sf <- sf::st_read(PLOTS_PATH, quiet = TRUE)

ground_cover <- readr::read_csv(GROUND_COVER_INPUT, show_col_types = FALSE) %>%
  dplyr::mutate(
    date_start = as.Date(.data$date_start),
    date_end = as.Date(.data$date_end)
  )

annual_inundation <- readr::read_csv(INUNDATION_INPUT, show_col_types = FALSE) %>%
  dplyr::mutate(
    date_start = as.Date(.data$date_start),
    date_end = as.Date(.data$date_end)
  )


## Ground-cover example selection ----


gc_requested_examples <- tibble::tribble(
  ~example_id, ~individual_file, ~case_label, ~status_class, ~plot_id, ~date_start, ~file_name, ~reason_selected,
  "gc_01_full_support", "gc_example_01_full_support.png", "A. Adequate valid coverage / clean support", "adequate_valid_coverage", "GA_066", as.Date("2025-12-01"), "lztmre_nsw_m202512202602_dp1a2_subset.tif", "Clean late-series example with all three bands supported by about 10.7 effective 30 m cells.",
  "gc_02_partial_support", "gc_example_02_partial_support.png", "B. Partial support / edge-touching support", "partial_valid_coverage", "GA_008", as.Date("2001-09-01"), "lztmre_nsw_m200109200111_dp1a2_subset.tif", "Low-coverage edge case with only about one effective raster cell contributing to each band.",
  "gc_03_low_support", "gc_example_03_low_support.png", "C. Very low valid coverage / mostly gap", "very_low_valid_coverage", "GA_020", as.Date("2011-03-01"), "lztmre_nsw_m201103201105_dp1a2_subset.tif", "Very low valid overlap; values exist in the scene but barely intersect the 1 ha plot.",
  "gc_04_all_missing", "gc_example_04_all_missing.png", "D. All bands missing / no usable support", "all_bands_missing", "GA_001", as.Date("2012-09-01"), "lztmre_nsw_m201209201211_dp1a2_subset.tif", "No valid overlapping cells for the plot in any of the three ground-cover bands."
)


gc_case_table <- ground_cover %>%
  dplyr::group_by(
    .data$plot_id,
    .data$date_start,
    .data$date_end,
    .data$file_name,
    .data$file_path
  ) %>%
  dplyr::summarise(
    n_bands = dplyr::n_distinct(.data$band_number),
    n_missing_bands = sum(is.na(.data$mean_value)),
    all_bands_missing = all(is.na(.data$mean_value)),
    min_effective_cells = gayini_safe_min(.data$valid_coverage_count),
    max_effective_cells = gayini_safe_max(.data$valid_coverage_count),
    band_sum_mean_value = gayini_safe_sum(.data$mean_value),
    source_valid_coverage_status = paste(unique(.data$valid_coverage_status), collapse = "; "),
    extraction_buffer_pixels = dplyr::first(.data$buffer_pixels),
    extracted_metric_name = "mean_value_by_band_from_valid_overlapping_cells",
    .groups = "drop"
  )

gc_examples <- gc_requested_examples %>%
  dplyr::left_join(
    gc_case_table,
    by = c("plot_id", "date_start", "file_name")
  ) %>%
  dplyr::mutate(
    support_class = dplyr::case_when(
      .data$status_class == "adequate_valid_coverage" ~ "adequate",
      .data$status_class == "partial_valid_coverage" ~ "low",
      .data$status_class == "very_low_valid_coverage" ~ "very_low",
      .data$status_class == "all_bands_missing" ~ "none",
      TRUE ~ "review"
    ),
    extracted_metric_value = paste0(
      "min_effective_cells=",
      gayini_fmt_number(.data$min_effective_cells, 3),
      "; band_sum_mean_value=",
      gayini_fmt_number(.data$band_sum_mean_value, 2)
    ),
    raster_file = basename(.data$file_path),
    notes = paste0(
      "Ground-cover extraction uses the 1 ha plot polygon with buffer_pixels = ",
      .data$extraction_buffer_pixels,
      ". Grey buffer is visual QA context only."
    ),
    output_png = file.path(OUTPUT_DIR, .data$individual_file)
  )

if (any(is.na(gc_examples$file_path))) {
  missing_gc <- gc_examples %>%
    dplyr::filter(is.na(.data$file_path)) %>%
    dplyr::select(.data$example_id, .data$plot_id, .data$date_start, .data$file_name)

  stop(
    "Missing selected ground-cover example rows:\n",
    paste(utils::capture.output(print(missing_gc)), collapse = "\n"),
    call. = FALSE
  )
}

if (any(!file.exists(gc_examples$file_path))) {
  missing_files <- gc_examples %>%
    dplyr::filter(!file.exists(.data$file_path)) %>%
    dplyr::pull(.data$file_path)

  stop(
    "Selected ground-cover raster files are missing: ",
    paste(missing_files, collapse = "; "),
    call. = FALSE
  )
}


## Annual inundation example selection ----


inundation_requested_examples <- tibble::tribble(
  ~example_id, ~individual_file, ~case_label, ~status_class, ~plot_id, ~file_name, ~reason_selected,
  "inundation_01_clear_wet", "inundation_example_01_clear_wet.png", "A. Clear inundated / strong wet support", "clear_wet_adequate_support", "GA_001", "lo_1988_1989.img", "All valid plot support is inundated at least once in the annual count raster.",
  "inundation_02_clear_dry", "inundation_example_02_clear_dry.png", "B. Clear dry / valid support", "clear_dry_adequate_support", "GA_031", "lo_1994_1995.img", "Valid plot support with no inundated-count cells in the annual raster.",
  "inundation_03_partial_edge", "inundation_example_03_partial_edge.png", "C. Partial / edge-touching / mixed wet support", "partial_edge_adequate_support", "GA_020", "lo_1999_2000.img", "Small wet fraction shows how count > 0 area contributes to inundated_any_pct.",
  "inundation_04_low_support_or_gap", "inundation_example_04_low_support_or_gap.png", "D. Mixed support example; no poor-support annual case available", "mixed_support_no_poor_gap_available", "GA_057", "lo_1992_1993.img", "Annual curated outputs did not contain a low-confidence coverage case, so this mixed wet/dry adequate-support example is used instead."
)

inundation_examples <- inundation_requested_examples %>%
  dplyr::left_join(
    annual_inundation,
    by = c("plot_id", "file_name")
  ) %>%
  dplyr::mutate(
    support_class = .data$valid_coverage_status,
    extracted_metric_name = "inundated_any_pct",
    extracted_metric_value = as.character(round(.data$inundated_any_pct, 3)),
    raster_file = basename(.data$file_path),
    notes = paste0(
      "NoData value 255 is invalid; inundated_any_pct is based on valid area where count > 0. ",
      "Valid coverage status from workflow: ",
      .data$valid_coverage_status,
      "."
    ),
    output_png = file.path(OUTPUT_DIR, .data$individual_file)
  )

if (any(is.na(inundation_examples$file_path))) {
  missing_inundation <- inundation_examples %>%
    dplyr::filter(is.na(.data$file_path)) %>%
    dplyr::select(.data$example_id, .data$plot_id, .data$file_name)

  stop(
    "Missing selected inundation example rows:\n",
    paste(utils::capture.output(print(missing_inundation)), collapse = "\n"),
    call. = FALSE
  )
}

if (any(!file.exists(inundation_examples$file_path))) {
  missing_files <- inundation_examples %>%
    dplyr::filter(!file.exists(.data$file_path)) %>%
    dplyr::pull(.data$file_path)

  stop(
    "Selected inundation raster files are missing: ",
    paste(missing_files, collapse = "; "),
    call. = FALSE
  )
}


## Rendering helpers ----


gayini_render_ground_cover_example <- function(example_row, output_path) {
  context <- gayini_make_raster_context(
    plots_sf = plots_sf,
    raster_path = example_row$file_path,
    plot_id = example_row$plot_id
  )

  valid_mask <- gayini_make_valid_mask(context$raster_crop[[1]])

  gayini_open_png(output_path, INDIVIDUAL_WIDTH_PX, INDIVIDUAL_HEIGHT_PX)

  old_par <- par(no.readonly = TRUE)
  on.exit({
    par(old_par)
    grDevices::dev.off()
  }, add = TRUE)

  par(mfrow = c(2, 2), mar = c(3.1, 3.0, 2.7, 4.8), oma = c(4.1, 0, 7.7, 0))

  for (band_index in GROUND_COVER_BANDS_TO_PLOT) {
    gayini_plot_raster_panel(
      raster_layer = context$raster_crop[[band_index]],
      main = paste0("Band ", band_index),
      plot_vect = context$plot_vect,
      plot_buffer = context$plot_buffer
    )
  }

  gayini_plot_raster_panel(
    raster_layer = valid_mask,
    main = "Valid data mask | Band 1",
    plot_vect = context$plot_vect,
    plot_buffer = context$plot_buffer,
    col = c("grey90", "#277DA1")
  )

  mtext(
    paste0(
      example_row$case_label,
      " | Plot: ",
      example_row$plot_id,
      " | Status: ",
      example_row$status_class
    ),
    side = 3,
    outer = TRUE,
    line = 5.8,
    cex = 0.76,
    font = 2
  )
  mtext(
    paste0(
      "Date: ",
      example_row$date_start,
      " to ",
      example_row$date_end,
      " | Min effective cells: ",
      gayini_fmt_number(example_row$min_effective_cells, 3),
      " | Band sum: ",
      gayini_fmt_number(example_row$band_sum_mean_value, 2)
    ),
    side = 3,
    outer = TRUE,
    line = 4.6,
    cex = 0.62
  )
  mtext(
    paste0("File: ", example_row$file_name),
    side = 3,
    outer = TRUE,
    line = 3.4,
    cex = 0.56
  )
  mtext(
    stringr::str_wrap(example_row$reason_selected, width = 120),
    side = 3,
    outer = TRUE,
    line = 2.1,
    cex = 0.52
  )
  mtext(
    "Red outline = 1 ha plot. Grey dashed outline = one-pixel contextual QA buffer only; extraction itself is not buffered.",
    side = 1,
    outer = TRUE,
    line = 2.3,
    cex = 0.54
  )

  invisible(output_path)
}


gayini_render_inundation_example <- function(example_row, output_path) {
  context <- gayini_make_raster_context(
    plots_sf = plots_sf,
    raster_path = example_row$file_path,
    plot_id = example_row$plot_id
  )

  count_clean <- gayini_clean_inundation_raster(context$raster_crop[[1]])
  wet_mask <- gayini_make_wet_mask(count_clean)
  valid_mask <- gayini_make_valid_mask(count_clean)

  gayini_open_png(output_path, INDIVIDUAL_WIDTH_PX, INDIVIDUAL_HEIGHT_PX)

  old_par <- par(no.readonly = TRUE)
  on.exit({
    par(old_par)
    grDevices::dev.off()
  }, add = TRUE)

  par(mfrow = c(2, 2), mar = c(3.1, 3.0, 2.7, 4.8), oma = c(4.1, 0, 7.7, 0))

  gayini_plot_raster_panel(
    raster_layer = count_clean,
    main = "Annual inundation count | 255 treated as invalid",
    plot_vect = context$plot_vect,
    plot_buffer = context$plot_buffer
  )
  gayini_plot_raster_panel(
    raster_layer = wet_mask,
    main = "Inundated basis | count > 0",
    plot_vect = context$plot_vect,
    plot_buffer = context$plot_buffer,
    col = c("grey90", "#2C7FB8")
  )
  gayini_plot_raster_panel(
    raster_layer = valid_mask,
    main = "Valid interpretation mask",
    plot_vect = context$plot_vect,
    plot_buffer = context$plot_buffer,
    col = c("grey90", "#31A354")
  )
  gayini_write_text_panel(
    title = "Extracted summary",
    lines = c(
      paste0("Metric: inundated_any_pct = ", gayini_fmt_number(example_row$inundated_any_pct, 2), "%"),
      paste0("Valid coverage: ", gayini_fmt_number(example_row$valid_coverage_pct, 1), "% (", example_row$valid_coverage_status, ")"),
      paste0("Mean count: ", gayini_fmt_number(example_row$mean_inundation_count, 2), "; max count: ", gayini_fmt_number(example_row$max_inundation_count, 0)),
      "Workflow basis: 100 x valid area with count > 0 / total valid area."
    )
  )

  mtext(
    paste0(
      example_row$case_label,
      " | Plot: ",
      example_row$plot_id,
      " | Status: ",
      example_row$status_class
    ),
    side = 3,
    outer = TRUE,
    line = 5.8,
    cex = 0.76,
    font = 2
  )
  mtext(
    paste0(
      "Date: ",
      example_row$date_start,
      " to ",
      example_row$date_end,
      " | Inundated any: ",
      gayini_fmt_number(example_row$inundated_any_pct, 2),
      "% | Valid coverage: ",
      gayini_fmt_number(example_row$valid_coverage_pct, 1),
      "%"
    ),
    side = 3,
    outer = TRUE,
    line = 4.6,
    cex = 0.62
  )
  mtext(
    paste0("File: ", example_row$file_name),
    side = 3,
    outer = TRUE,
    line = 3.4,
    cex = 0.56
  )
  mtext(
    stringr::str_wrap(example_row$reason_selected, width = 120),
    side = 3,
    outer = TRUE,
    line = 2.1,
    cex = 0.52
  )
  mtext(
    "Red outline = 1 ha plot. Grey dashed outline = one-pixel contextual QA buffer only; extraction itself is not buffered.",
    side = 1,
    outer = TRUE,
    line = 2.3,
    cex = 0.54
  )

  invisible(output_path)
}


gayini_render_ground_cover_panel <- function(examples, output_path) {
  gayini_open_png(output_path, PANEL_WIDTH_PX, PANEL_HEIGHT_PX)

  old_par <- par(no.readonly = TRUE)
  on.exit({
    par(old_par)
    grDevices::dev.off()
  }, add = TRUE)

  layout(matrix(seq_len(16), nrow = 4, byrow = TRUE))
  par(mar = c(2.6, 2.8, 2.7, 4.3), oma = c(4.8, 0.4, 7.7, 0.4))

  for (i in seq_len(nrow(examples))) {
    example_row <- examples[i, ]
    context <- gayini_make_raster_context(
      plots_sf = plots_sf,
      raster_path = example_row$file_path,
      plot_id = example_row$plot_id
    )
    valid_mask <- gayini_make_valid_mask(context$raster_crop[[1]])

    for (band_index in GROUND_COVER_BANDS_TO_PLOT) {
      panel_title <- if (band_index == 1) {
        paste0(
          LETTERS[i],
          ". ",
          example_row$plot_id,
          " | ",
          example_row$status_class,
          "\nBand ",
          band_index,
          " | cells ",
          gayini_fmt_number(example_row$min_effective_cells, 2)
        )
      } else {
        paste0("Band ", band_index)
      }

      gayini_plot_raster_panel(
        raster_layer = context$raster_crop[[band_index]],
        main = panel_title,
        plot_vect = context$plot_vect,
        plot_buffer = context$plot_buffer
      )
    }

    gayini_plot_raster_panel(
      raster_layer = valid_mask,
      main = "Valid data mask | Band 1",
      plot_vect = context$plot_vect,
      plot_buffer = context$plot_buffer,
      col = c("grey90", "#277DA1")
    )
  }

  mtext(
    "Ground-cover raster extraction examples: valid overlapping cells within the 1 ha plot",
    side = 3,
    outer = TRUE,
    line = 5.9,
    cex = 0.90,
    font = 2
  )
  mtext(
    "Each row is one actual plot x raster case. Bands 1-3 are bare ground, green/PV, and non-green/NPV; summaries use valid overlapping cells only.",
    side = 3,
    outer = TRUE,
    line = 4.4,
    cex = 0.62
  )
  mtext(
    "Rows: A adequate support; B low/edge support; C very low support; D no valid support.",
    side = 3,
    outer = TRUE,
    line = 3.2,
    cex = 0.56
  )
  mtext(
    "Red outline = 1 ha plot. Grey dashed outline = one-pixel contextual QA buffer only; extraction itself is not buffered.",
    side = 1,
    outer = TRUE,
    line = 2.7,
    cex = 0.56
  )

  invisible(output_path)
}


gayini_render_inundation_panel <- function(examples, output_path) {
  gayini_open_png(output_path, PANEL_WIDTH_PX, PANEL_HEIGHT_PX)

  old_par <- par(no.readonly = TRUE)
  on.exit({
    par(old_par)
    grDevices::dev.off()
  }, add = TRUE)

  layout(matrix(seq_len(16), nrow = 4, byrow = TRUE))
  par(mar = c(2.6, 2.8, 2.7, 4.3), oma = c(4.8, 0.4, 7.7, 0.4))

  for (i in seq_len(nrow(examples))) {
    example_row <- examples[i, ]
    context <- gayini_make_raster_context(
      plots_sf = plots_sf,
      raster_path = example_row$file_path,
      plot_id = example_row$plot_id
    )

    count_clean <- gayini_clean_inundation_raster(context$raster_crop[[1]])
    wet_mask <- gayini_make_wet_mask(count_clean)
    valid_mask <- gayini_make_valid_mask(count_clean)

    gayini_plot_raster_panel(
      raster_layer = count_clean,
      main = paste0(
        LETTERS[i],
        ". ",
        example_row$plot_id,
        " | ",
        example_row$status_class,
        "\nAnnual count"
      ),
      plot_vect = context$plot_vect,
      plot_buffer = context$plot_buffer
    )
    gayini_plot_raster_panel(
      raster_layer = wet_mask,
      main = "Wet basis | count > 0",
      plot_vect = context$plot_vect,
      plot_buffer = context$plot_buffer,
      col = c("grey90", "#2C7FB8")
    )
    gayini_plot_raster_panel(
      raster_layer = valid_mask,
      main = "Valid mask | 255 invalid",
      plot_vect = context$plot_vect,
      plot_buffer = context$plot_buffer,
      col = c("grey90", "#31A354")
    )
    gayini_write_text_panel(
      title = "Workflow summary",
      lines = c(
        paste0("File: ", example_row$file_name),
        paste0("Date: ", example_row$date_start, " to ", example_row$date_end),
        paste0("Inundated any: ", gayini_fmt_number(example_row$inundated_any_pct, 2), "%"),
        paste0("Valid coverage: ", gayini_fmt_number(example_row$valid_coverage_pct, 1), "%")
      )
    )
  }

  mtext(
    "Annual inundation extraction examples: count rasters, wet basis, and valid support",
    side = 3,
    outer = TRUE,
    line = 5.9,
    cex = 0.90,
    font = 2
  )
  mtext(
    "The workflow treats NoData/255 as invalid and computes inundated_any_pct as valid area with count > 0 divided by total valid area.",
    side = 3,
    outer = TRUE,
    line = 4.4,
    cex = 0.62
  )
  mtext(
    "No poor-support annual example was present in the curated annual outputs; row D is an adequate-coverage mixed wet/dry example.",
    side = 3,
    outer = TRUE,
    line = 3.2,
    cex = 0.56
  )
  mtext(
    "Red outline = 1 ha plot. Grey dashed outline = one-pixel contextual QA buffer only; extraction itself is not buffered.",
    side = 1,
    outer = TRUE,
    line = 2.7,
    cex = 0.56
  )

  invisible(output_path)
}


## Render PNG assets ----


message("Writing individual ground-cover example PNGs.")

for (i in seq_len(nrow(gc_examples))) {
  gayini_render_ground_cover_example(
    example_row = gc_examples[i, ],
    output_path = gc_examples$output_png[i]
  )
}

gc_panel_path <- file.path(OUTPUT_DIR, "gc_extraction_examples_panel.png")
gayini_render_ground_cover_panel(gc_examples, gc_panel_path)

message("Writing individual inundation example PNGs.")

for (i in seq_len(nrow(inundation_examples))) {
  gayini_render_inundation_example(
    example_row = inundation_examples[i, ],
    output_path = inundation_examples$output_png[i]
  )
}

inundation_panel_path <- file.path(OUTPUT_DIR, "inundation_extraction_examples_panel.png")
gayini_render_inundation_panel(inundation_examples, inundation_panel_path)


## Manifests and handoff ----


gc_manifest <- gc_examples %>%
  dplyr::transmute(
    figure_name = "gc_extraction_examples_panel.png",
    example_id = .data$example_id,
    domain = "ground_cover",
    plot_id = .data$plot_id,
    raster_file = .data$raster_file,
    raster_path = gayini_display_path(.data$file_path),
    date_start = .data$date_start,
    date_end = .data$date_end,
    status_class = .data$status_class,
    support_class = .data$support_class,
    reason_selected = .data$reason_selected,
    extracted_metric_name = .data$extracted_metric_name,
    extracted_metric_value = .data$extracted_metric_value,
    individual_png = basename(.data$output_png),
    notes = .data$notes
  )

inundation_manifest <- inundation_examples %>%
  dplyr::transmute(
    figure_name = "inundation_extraction_examples_panel.png",
    example_id = .data$example_id,
    domain = "inundation",
    plot_id = .data$plot_id,
    raster_file = .data$raster_file,
    raster_path = gayini_display_path(.data$file_path),
    date_start = .data$date_start,
    date_end = .data$date_end,
    status_class = .data$status_class,
    support_class = .data$support_class,
    reason_selected = .data$reason_selected,
    extracted_metric_name = .data$extracted_metric_name,
    extracted_metric_value = .data$extracted_metric_value,
    individual_png = basename(.data$output_png),
    notes = .data$notes
  )

gc_manifest_path <- file.path(OUTPUT_DIR, "gc_extraction_examples_manifest.csv")
inundation_manifest_path <- file.path(OUTPUT_DIR, "inundation_extraction_examples_manifest.csv")

readr::write_csv(gc_manifest, gc_manifest_path)
readr::write_csv(inundation_manifest, inundation_manifest_path)

created_pngs <- c(
  gc_panel_path,
  gc_examples$output_png,
  inundation_panel_path,
  inundation_examples$output_png
)

handoff_path <- file.path(OUTPUT_DIR, "codex_handoff_report.md")

handoff_lines <- c(
  "# Extraction-method PNG asset handoff",
  "",
  paste0("Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
  "",
  "## Created",
  "",
  paste0("- `", basename(gc_panel_path), "`"),
  paste0("- `", basename(inundation_panel_path), "`"),
  paste0("- `", basename(gc_manifest_path), "`"),
  paste0("- `", basename(inundation_manifest_path), "`"),
  "- Optional individual example PNGs for each selected ground-cover and inundation case.",
  "",
  "## Ground-cover examples",
  "",
  paste0(
    "- ",
    gc_manifest$example_id,
    ": ",
    gc_manifest$plot_id,
    ", ",
    gc_manifest$date_start,
    ", ",
    gc_manifest$status_class,
    " (",
    gc_manifest$reason_selected,
    ")"
  ),
  "",
  "## Inundation examples",
  "",
  paste0(
    "- ",
    inundation_manifest$example_id,
    ": ",
    inundation_manifest$plot_id,
    ", ",
    inundation_manifest$date_start,
    ", ",
    inundation_manifest$status_class,
    " (",
    inundation_manifest$reason_selected,
    ")"
  ),
  "",
  "## Method fidelity",
  "",
  "- Ground-cover panels use actual source fractional-cover rasters and the actual 1 ha plot polygons.",
  "- The red outline is the extraction polygon. The grey dashed outline is a one-pixel visual QA context buffer only.",
  "- Ground-cover extraction is unbuffered and uses valid overlapping cells only.",
  "- Annual inundation panels use actual source count rasters. NoData/255 is treated as invalid.",
  "- `inundated_any_pct` is shown as valid area with count > 0 divided by total valid area.",
  "",
  "## Reuse/regeneration",
  "",
  "- Existing archived QA PNGs were used as visual references only.",
  "- The PNGs listed above were regenerated from source rasters and current plot polygons for this task.",
  "",
  "## Scripts run",
  "",
  "- `Rscript --vanilla scripts/15_make_review_extraction_method_maps.R`",
  "",
  "## Confirmations",
  "",
  "- No PPTX files were created or modified.",
  "- No full extraction workflow was run.",
  "- No raster-build workflow was run.",
  "- No BFAST/tbreak workflow was run.",
  "- No files were archived, moved, or deleted.",
  "",
  "## Limitations and caveats",
  "",
  "- The curated annual inundation outputs did not include a low-confidence or poor-support annual example. The fourth inundation row is therefore a mixed wet/dry adequate-support case rather than an invented gap case.",
  "- The panels are methodological illustrations for internal review, not new analysis outputs.",
  "- White raster areas in source panels indicate no plotted raster value in the cropped context, while mask panels show valid/interpretable support explicitly.",
  "",
  "## Examples considered but not used",
  "",
  "- `GA_001` 1994-09-01 ground-cover all-missing case was considered, but the 2012-09-01 case was more visually informative because nearby valid cells are visible outside the plot.",
  "- Other very-low ground-cover cases such as `GA_049` 2011-09-01 were considered; `GA_020` 2011-03-01 was selected for a clearer mostly-gap relationship.",
  "- True annual inundation poor-support/gap examples were sought in the curated annual table but were not available."
)

writeLines(handoff_lines, handoff_path)

message("Wrote PNG assets:")
message(paste(gayini_display_path(created_pngs), collapse = "\n"))
message("Wrote manifests and handoff:")
message(gayini_display_path(gc_manifest_path))
message(gayini_display_path(inundation_manifest_path))
message(gayini_display_path(handoff_path))
message("Extraction-method review PNG asset generation complete.")
