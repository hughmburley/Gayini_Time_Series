## -----------------------------------------------------------------------------
## Gayini remote sensing workflow
## gayini_plotting_helpers.R
## -----------------------------------------------------------------------------


## Purpose:
## Shared plotting helpers for lightweight review, deck and QA outputs.


gayini_theme_review <- function(base_size = 13,
                                base_family = "Arial",
                                legend_position = "bottom") {
  ggplot2::theme_minimal(base_size = base_size, base_family = base_family) +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      plot.background = ggplot2::element_rect(fill = "white", colour = NA),
      panel.background = ggplot2::element_rect(fill = "white", colour = NA),
      plot.title = ggplot2::element_text(face = "bold", colour = "#1f2d2a"),
      plot.subtitle = ggplot2::element_text(colour = "#4d5652"),
      plot.caption = ggplot2::element_text(hjust = 0, colour = "grey35", size = ggplot2::rel(0.75)),
      legend.position = legend_position,
      legend.title = ggplot2::element_text(face = "bold"),
      plot.margin = ggplot2::margin(14, 18, 14, 18)
    )
}


gayini_theme_map <- function(base_size = 12,
                             base_family = "Arial",
                             legend_position = "bottom") {
  ggplot2::theme_void(base_size = base_size, base_family = base_family) +
    ggplot2::theme(
      plot.background = ggplot2::element_rect(fill = "white", colour = NA),
      panel.background = ggplot2::element_rect(fill = "white", colour = NA),
      plot.title = ggplot2::element_text(face = "bold", colour = "#1f2d2a"),
      plot.subtitle = ggplot2::element_text(colour = "#4d5652"),
      plot.caption = ggplot2::element_text(hjust = 0, colour = "grey35", size = ggplot2::rel(0.75)),
      legend.position = legend_position,
      legend.title = ggplot2::element_text(face = "bold"),
      plot.margin = ggplot2::margin(14, 18, 14, 18)
    )
}


gayini_slide_size <- function(size = c("wide", "standard", "panel")) {
  size <- match.arg(size)
  switch(
    size,
    wide = c(width = 13, height = 7.2),
    standard = c(width = 10.5, height = 5.8),
    panel = c(width = 8.8, height = 5.4)
  )
}


gayini_change_palette <- function() {
  c(
    negative = "#b84a4a",
    neutral = "white",
    positive = "#2f74b5"
  )
}


gayini_gauge_role_palette <- function(style = c("display", "analysis")) {
  style <- match.arg(style)

  switch(
    style,
    display = c(
      "Preferred context" = "#2c7f8f",
      "Preferred context / downstream" = "#66a6b4",
      "Preferred downstream context" = "#66a6b4",
      "Secondary / cautious" = "#c56a4a"
    ),
    analysis = c(
      preferred_context = "#2c7f8f",
      redbank_cautious = "#c56a4a",
      other_context = "#9fa7a4"
    )
  )
}


gayini_wetness_group_palette <- function() {
  c(
    "Drier post" = "#b84a4a",
    "Near no change" = "#777777",
    "Wetter post" = "#2f74b5"
  )
}


gayini_deck_candidate_palette <- function() {
  c(
    "Main deck candidate" = "#2f74b5",
    "Appendix candidate" = "#8a8f8d",
    "Appendix / treed caveat" = "#c56a4a"
  )
}


gayini_sensor_palette <- function() {
  c(
    "Landsat" = "#4c78a8",
    "Sentinel-2" = "#f58518",
    "Other" = "#999999"
  )
}


gayini_mer_agreement_palette <- function() {
  c(
    agree_positive = "#2f6f4e",
    agree_negative = "#6b8fb5",
    agree_near_zero = "#8a8a8a",
    one_near_zero = "#d08b2c",
    disagree = "#b44f3f",
    insufficient_support = "#555555"
  )
}


gayini_vegetation_group_palette <- function() {
  c(
    "Aeolian Chenopod Shrublands" = "#d9a441",
    "Floodplain Woodland / Forest" = "#4f7f5d",
    "Inland Floodplain Shrublands / Swamps" = "#5a9fb1",
    "Unknown vegetation" = "#bdbdbd"
  )
}


gayini_change_scale_fill <- function(limit = NULL,
                                     name = "Change (percentage points)",
                                     midpoint = 0,
                                     na.value = "transparent") {
  palette <- gayini_change_palette()
  limits <- if (is.null(limit)) NULL else c(-limit, limit)

  ggplot2::scale_fill_gradient2(
    low = palette[["negative"]],
    mid = palette[["neutral"]],
    high = palette[["positive"]],
    midpoint = midpoint,
    limits = limits,
    oob = scales::squish,
    na.value = na.value,
    name = name
  )
}


gayini_change_scale_colour <- function(limit = NULL,
                                       name = "Change (percentage points)",
                                       midpoint = 0,
                                       na.value = "transparent") {
  palette <- gayini_change_palette()
  limits <- if (is.null(limit)) NULL else c(-limit, limit)

  ggplot2::scale_colour_gradient2(
    low = palette[["negative"]],
    mid = palette[["neutral"]],
    high = palette[["positive"]],
    midpoint = midpoint,
    limits = limits,
    oob = scales::squish,
    na.value = na.value,
    name = name
  )
}


gayini_save_png <- function(filename,
                            plot,
                            width,
                            height,
                            dpi = 220,
                            ...) {
  dir.create(dirname(filename), recursive = TRUE, showWarnings = FALSE)
  ggplot2::ggsave(filename = filename, plot = plot, width = width, height = height, dpi = dpi, ...)
  invisible(filename)
}
