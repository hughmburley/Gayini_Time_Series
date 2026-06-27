####################################################################################################


## GAYINI REMOTE SENSING PROJECT


## 07a_make_ground_cover_cover_class_timeseries.R


####################################################################################################


## Purpose ----


## Create Adrian-review ground-cover time-series figures from the completed 04c
## Landsat fractional-cover extraction.


## The existing 04c figure combines cover classes. This script splits the output
## into one PNG per cover class:
##
##   1. Green / PV
##   2. Non-green / NPV
##   3. Bare ground
##
## Each figure shows treatment means through time, with one colour per treatment.


## This script does not rerun extraction.


## Setup ----


default_root <- "D:/Github_repos/Gayini"


helper_path <- file.path(default_root, "R", "gayini_review_figure_functions.R")


if (!file.exists(helper_path)) {
  helper_path <- file.path(getwd(), "R", "gayini_review_figure_functions.R")
}


if (!file.exists(helper_path)) {
  stop(
    "Could not find R/gayini_review_figure_functions.R. Copy the supplied R/ helper file into the project root first.",
    call. = FALSE
  )
}


source(helper_path)


root_dir <- gayini_review_find_root(default_root = default_root)


required_packages <- c(
  "dplyr",
  "readr",
  "ggplot2",
  "stringr",
  "tibble"
)


gayini_review_check_packages(required_packages)


library(dplyr)
library(readr)
library(ggplot2)
library(stringr)
library(tibble)


## User settings ----


## Use adequate-coverage rows only for the main Adrian review figures. Raw rows
## remain preserved in 04c_fractional_cover_full.csv.

USE_ADEQUATE_COVERAGE_ONLY <- TRUE


## Add points as well as lines. Points help show irregular/missing observation
## timing, especially in the early time series.

ADD_POINTS <- TRUE


## Output image size. These are intended to be readable when dropped into PPT.

FIGURE_WIDTH  <- 13
FIGURE_HEIGHT <- 7.5
FIGURE_DPI    <- 300
BASE_SIZE     <- 15


## Paths ----


input_path <- file.path(
  root_dir,
  "Output",
  "csv",
  "04c_fractional_cover_full.csv"
)


output_dir <- file.path(
  root_dir,
  "Output",
  "figures",
  "review",
  "ground_cover_timeseries"
)


csv_dir <- file.path(
  root_dir,
  "Output",
  "csv",
  "review"
)


gayini_review_make_dir(output_dir)
gayini_review_make_dir(csv_dir)


summary_output_path <- file.path(
  csv_dir,
  "07a_ground_cover_cover_class_treatment_timeseries.csv"
)


## Read data ----


gayini_review_required_file(input_path)


fc <- readr::read_csv(input_path, show_col_types = FALSE)


required_columns <- c(
  "plot_id",
  "date_midpoint",
  "treatment",
  "band_label",
  "mean_value",
  "valid_coverage_status"
)


missing_columns <- setdiff(required_columns, names(fc))


if (length(missing_columns) > 0) {
  stop(
    "04c fractional-cover table is missing required columns: ",
    paste(missing_columns, collapse = ", "),
    call. = FALSE
  )
}


## Prepare summary data ----


fc_plot <- fc |>
  dplyr::mutate(
    date_plot        = as.Date(.data$date_midpoint),
    cover_class      = gayini_review_cover_label(.data$band_label),
    cover_file_label = gayini_review_cover_file_label(.data$band_label),
    coverage_group   = dplyr::if_else(
      .data$valid_coverage_status == "adequate_coverage",
      "adequate coverage",
      "lower / no valid coverage"
    )
  )


if (isTRUE(USE_ADEQUATE_COVERAGE_ONLY)) {
  fc_plot <- fc_plot |>
    dplyr::filter(.data$valid_coverage_status == "adequate_coverage")
}


timeseries_summary <- fc_plot |>
  dplyr::group_by(
    .data$cover_class,
    .data$cover_file_label,
    .data$band_label,
    .data$treatment,
    .data$date_plot
  ) |>
  dplyr::summarise(
    mean_cover_pct   = gayini_review_safe_mean(.data$mean_value),
    median_cover_pct = gayini_review_safe_median(.data$mean_value),
    n_rows           = dplyr::n(),
    n_plots          = dplyr::n_distinct(.data$plot_id[!is.na(.data$mean_value)]),
    .groups          = "drop"
  ) |>
  dplyr::arrange(.data$cover_class, .data$treatment, .data$date_plot)


readr::write_csv(timeseries_summary, summary_output_path)


message("Wrote: ", summary_output_path)


## Make one figure per cover class ----


coverage_subtitle <- if (isTRUE(USE_ADEQUATE_COVERAGE_ONLY)) {
  "Treatment mean across 1 ha plots; adequate-coverage rows only; cover-class labels remain provisional."
} else {
  "Treatment mean across 1 ha plots; all rows retained; cover-class labels remain provisional."
}


cover_classes <- timeseries_summary |>
  dplyr::distinct(.data$cover_class, .data$cover_file_label, .data$band_label) |>
  dplyr::arrange(.data$band_label)


for (i in seq_len(nrow(cover_classes))) {

  this_cover <- cover_classes$cover_class[[i]]
  this_file  <- cover_classes$cover_file_label[[i]]

  plot_data <- timeseries_summary |>
    dplyr::filter(.data$cover_class == this_cover)

  p <- ggplot2::ggplot(
    plot_data,
    ggplot2::aes(
      x      = .data$date_plot,
      y      = .data$mean_cover_pct,
      group  = .data$treatment,
      colour = .data$treatment
    )
  ) +
    ggplot2::geom_line(linewidth = 0.75, na.rm = TRUE)

  if (isTRUE(ADD_POINTS)) {
    p <- p + ggplot2::geom_point(size = 1.4, alpha = 0.85, na.rm = TRUE)
  }

  p <- p +
    ggplot2::labs(
      title    = paste0("Landsat ground cover: ", this_cover),
      subtitle = coverage_subtitle,
      x        = "Raster midpoint date",
      y        = "Mean cover across plots (%)",
      colour   = "Treatment"
    ) +
    ggplot2::scale_x_date(date_breaks = "5 years", date_labels = "%Y") +
    ggplot2::coord_cartesian(ylim = c(0, 100)) +
    gayini_review_theme(base_size = BASE_SIZE) +
    ggplot2::theme(
      axis.text.x = ggplot2::element_text(angle = 45, hjust = 1),
      legend.position = "bottom"
    )

  output_path <- file.path(
    output_dir,
    paste0("07a_ground_cover_timeseries_", this_file, "_by_treatment.png")
  )

  gayini_review_save_png(
    plot   = p,
    path   = output_path,
    width  = FIGURE_WIDTH,
    height = FIGURE_HEIGHT,
    dpi    = FIGURE_DPI
  )
}


## Finish ----


message("07a ground-cover treatment × cover-class figures complete.")
message("Figure folder: ", output_dir)
