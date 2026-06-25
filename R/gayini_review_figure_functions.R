####################################################################################################


## GAYINI REMOTE SENSING PROJECT


## Shared helper functions for post-extraction review figures.


####################################################################################################


## Package helpers ----


gayini_review_check_packages <- function(packages) {

  missing_packages <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]

  if (length(missing_packages) > 0) {
    stop(
      "Missing required packages: ",
      paste(missing_packages, collapse = ", "),
      call. = FALSE
    )
  }

  message("All required packages are available.")

  invisible(TRUE)
}


## Path helpers ----


gayini_review_find_root <- function(default_root = "D:/Github_repos/Gayini") {

  if (dir.exists(default_root)) {
    return(normalizePath(default_root, winslash = "/", mustWork = TRUE))
  }

  current_dir <- normalizePath(getwd(), winslash = "/", mustWork = TRUE)

  if (dir.exists(file.path(current_dir, "Output")) && dir.exists(file.path(current_dir, "data_processed"))) {
    return(current_dir)
  }

  stop(
    "Could not find the Gayini project root. Either run from the project root or update default_root.",
    call. = FALSE
  )
}


gayini_review_make_dir <- function(path) {

  dir.create(path, recursive = TRUE, showWarnings = FALSE)

  invisible(path)
}


gayini_review_required_file <- function(path) {

  if (!file.exists(path)) {
    stop("Missing required file: ", path, call. = FALSE)
  }

  path
}


gayini_review_clean_filename <- function(x) {

  x <- tolower(x)
  x <- gsub("[^a-z0-9]+", "_", x)
  x <- gsub("^_+|_+$", "", x)

  x
}


## Numeric helpers ----


gayini_review_safe_mean <- function(x) {

  if (all(is.na(x))) {
    return(NA_real_)
  }

  mean(x, na.rm = TRUE)
}


gayini_review_safe_median <- function(x) {

  if (all(is.na(x))) {
    return(NA_real_)
  }

  stats::median(x, na.rm = TRUE)
}


gayini_review_safe_max <- function(x) {

  if (all(is.na(x))) {
    return(NA_real_)
  }

  max(x, na.rm = TRUE)
}


gayini_review_safe_min <- function(x) {

  if (all(is.na(x))) {
    return(NA_real_)
  }

  min(x, na.rm = TRUE)
}


gayini_review_rescale_0_100 <- function(x) {

  if (all(is.na(x))) {
    return(rep(NA_real_, length(x)))
  }

  rng <- range(x, na.rm = TRUE)

  if (isTRUE(all.equal(rng[1], rng[2]))) {
    return(rep(50, length(x)))
  }

  100 * (x - rng[1]) / (rng[2] - rng[1])
}


## Label helpers ----


gayini_review_plot_id_number <- function(plot_id) {

  suppressWarnings(as.integer(gsub("[^0-9]", "", plot_id)))
}


gayini_review_order_plot_ids <- function(plot_ids) {

  plot_ids[order(gayini_review_plot_id_number(plot_ids), plot_ids)]
}


gayini_review_label_every_nth <- function(values, n = 5) {

  labels <- rep("", length(values))
  keep <- seq(1, length(values), by = n)
  labels[keep] <- values[keep]

  labels
}


gayini_review_cover_label <- function(band_label) {

  dplyr::case_when(
    band_label == "green_or_pv"      ~ "Green / PV",
    band_label == "non_green_or_npv" ~ "Non-green / NPV",
    band_label == "bare_ground"      ~ "Bare ground",
    TRUE                             ~ band_label
  )
}


gayini_review_cover_file_label <- function(band_label) {

  dplyr::case_when(
    band_label == "green_or_pv"      ~ "green_pv",
    band_label == "non_green_or_npv" ~ "non_green_npv",
    band_label == "bare_ground"      ~ "bare_ground",
    TRUE                             ~ gayini_review_clean_filename(band_label)
  )
}


## Plot helpers ----


gayini_review_theme <- function(base_size = 14) {

  ggplot2::theme_bw(base_size = base_size) +
    ggplot2::theme(
      plot.title      = ggplot2::element_text(size = base_size + 3, face = "bold"),
      plot.subtitle   = ggplot2::element_text(size = base_size - 1),
      axis.title      = ggplot2::element_text(size = base_size),
      axis.text       = ggplot2::element_text(size = base_size - 2),
      strip.text      = ggplot2::element_text(size = base_size, face = "bold"),
      legend.title    = ggplot2::element_text(size = base_size - 1),
      legend.text     = ggplot2::element_text(size = base_size - 2),
      legend.position = "bottom"
    )
}


gayini_review_save_png <- function(plot, path, width = 12, height = 7, dpi = 300) {

  gayini_review_make_dir(dirname(path))

  ggplot2::ggsave(
    filename = path,
    plot     = plot,
    width    = width,
    height   = height,
    dpi      = dpi
  )

  message("Wrote: ", path)

  invisible(path)
}


## Spatial helpers ----


gayini_review_make_plot_zones <- function(plots_sf, n_zones = 3) {

  if (!requireNamespace("sf", quietly = TRUE)) {
    stop("Package sf is required for spatial zone creation.", call. = FALSE)
  }

  stopifnot(n_zones == 3)

  centroids <- sf::st_coordinates(sf::st_centroid(sf::st_geometry(plots_sf)))

  plots_sf$review_centroid_x <- centroids[, 1]
  plots_sf$review_centroid_y <- centroids[, 2]

  y_breaks <- stats::quantile(
    plots_sf$review_centroid_y,
    probs = c(0, 1 / 3, 2 / 3, 1),
    na.rm = TRUE,
    type = 7
  )

  if (length(unique(y_breaks)) < 4) {
    x_breaks <- stats::quantile(
      plots_sf$review_centroid_x,
      probs = c(0, 1 / 3, 2 / 3, 1),
      na.rm = TRUE,
      type = 7
    )

    plots_sf$review_zone <- cut(
      plots_sf$review_centroid_x,
      breaks = unique(x_breaks),
      include.lowest = TRUE,
      labels = c("West zone", "Central zone", "East zone")[seq_len(length(unique(x_breaks)) - 1)]
    )

    return(plots_sf)
  }

  plots_sf$review_zone <- cut(
    plots_sf$review_centroid_y,
    breaks = y_breaks,
    include.lowest = TRUE,
    labels = c("South zone", "Central zone", "North zone")
  )

  plots_sf
}


gayini_review_expanded_bbox <- function(sf_object, expand_fraction = 0.12) {

  bbox <- sf::st_bbox(sf_object)

  x_pad <- as.numeric(bbox["xmax"] - bbox["xmin"]) * expand_fraction
  y_pad <- as.numeric(bbox["ymax"] - bbox["ymin"]) * expand_fraction

  list(
    xlim = c(as.numeric(bbox["xmin"]) - x_pad, as.numeric(bbox["xmax"]) + x_pad),
    ylim = c(as.numeric(bbox["ymin"]) - y_pad, as.numeric(bbox["ymax"]) + y_pad)
  )
}


## Text helpers ----


gayini_review_collapse_notes <- function(notes) {

  notes <- notes[!is.na(notes) & nzchar(notes)]

  if (length(notes) == 0) {
    return("No major flags from first-pass summaries.")
  }

  paste(unique(notes), collapse = "; ")
}

