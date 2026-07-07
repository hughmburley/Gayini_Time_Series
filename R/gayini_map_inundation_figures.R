## -----------------------------------------------------------------------------
## Gayini remote sensing workflow
## gayini_map_inundation_figures.R
## -----------------------------------------------------------------------------

## Purpose:
## Task 15 annual occurrence and MER map refresh with white no-data backgrounds.


gayini_task15_raster_df <- function(path) {
  raster <- terra::rast(path)
  df <- terra::as.data.frame(raster, xy = TRUE, na.rm = TRUE)
  names(df)[3] <- "value"
  df
}


gayini_task15_map_boundary <- function(boundary_path, raster_path) {
  raster <- terra::rast(raster_path)
  sf::st_read(boundary_path, quiet = TRUE) |>
    sf::st_transform(terra::crs(raster, proj = TRUE))
}


gayini_task15_frequency_map <- function(pre_path,
                                        post_path,
                                        boundary_path,
                                        title,
                                        subtitle,
                                        legend_title = "Frequency (%)",
                                        caption) {
  boundary <- gayini_task15_map_boundary(boundary_path, pre_path)
  pre_df <- gayini_task15_raster_df(pre_path) |>
    dplyr::mutate(period = "Pre-2019")
  post_df <- gayini_task15_raster_df(post_path) |>
    dplyr::mutate(period = "Post-2019")
  map_df <- dplyr::bind_rows(pre_df, post_df) |>
    dplyr::mutate(period = factor(.data$period, levels = c("Pre-2019", "Post-2019")))

  ggplot2::ggplot(map_df, ggplot2::aes(x = .data$x, y = .data$y, fill = .data$value)) +
    ggplot2::geom_raster() +
    ggplot2::geom_sf(data = boundary, inherit.aes = FALSE, fill = NA, colour = "#222222", linewidth = 0.45) +
    ggplot2::facet_wrap(~ period, nrow = 1) +
    ggplot2::coord_sf(expand = FALSE) +
    ggplot2::scale_fill_gradientn(
      colours = c("#f7fbff", "#deebf7", "#9ecae1", "#4292c6", "#08519c"),
      limits = c(0, 100),
      oob = scales::squish,
      na.value = "white",
      name = legend_title
    ) +
    ggplot2::labs(title = title, subtitle = subtitle, x = NULL, y = NULL, caption = caption) +
    gayini_theme_map(base_size = 12, legend_position = "bottom") +
    ggplot2::theme(strip.text = ggplot2::element_text(face = "bold"))
}


gayini_task15_change_map <- function(change_path,
                                     boundary_path,
                                     title,
                                     subtitle,
                                     legend_title = "Change (percentage points)",
                                     caption) {
  boundary <- gayini_task15_map_boundary(boundary_path, change_path)
  change_df <- gayini_task15_raster_df(change_path)
  values <- change_df$value[is.finite(change_df$value)]
  limit <- if (length(values) == 0L) 100 else ceiling(max(abs(values), na.rm = TRUE) / 5) * 5
  limit <- max(limit, 5)

  ggplot2::ggplot(change_df, ggplot2::aes(x = .data$x, y = .data$y, fill = .data$value)) +
    ggplot2::geom_raster() +
    ggplot2::geom_sf(data = boundary, inherit.aes = FALSE, fill = NA, colour = "#222222", linewidth = 0.45) +
    ggplot2::coord_sf(expand = FALSE) +
    gayini_change_scale_fill(limit = limit, name = legend_title, na.value = "white") +
    ggplot2::labs(title = title, subtitle = subtitle, x = NULL, y = NULL, caption = caption) +
    gayini_theme_map(base_size = 12, legend_position = "bottom")
}


gayini_make_task15_inundation_maps <- function(root_dir,
                                               input_paths,
                                               figure_dir) {
  source_script <- "R/gayini_map_inundation_figures.R"
  manifest <- list()

  annual_sources <- paste(
    gayini_relative_path(root_dir, input_paths[["annual_pre_raster"]]),
    gayini_relative_path(root_dir, input_paths[["annual_post_raster"]]),
    gayini_relative_path(root_dir, input_paths[["annual_change_raster"]]),
    gayini_relative_path(root_dir, input_paths[["boundary_gpkg"]]),
    sep = "; "
  )

  if (any(is.na(input_paths[c("annual_pre_raster", "annual_post_raster", "boundary_gpkg")]))) {
    manifest[[length(manifest) + 1L]] <- gayini_task15_skip_row(
      root_dir,
      "P0.1",
      "P0",
      "Annual occurrence pre/post maps",
      source_script,
      annual_sources,
      "Annual inundation",
      "Annual occurrence period rasters or boundary layer were not found.",
      "Annual occurrence is spatial exposure / occurrence, not depth, duration, hydroperiod, dry intervals, water quality or ecological outcome."
    )
  } else {
    annual_prepost <- gayini_task15_frequency_map(
      pre_path = input_paths[["annual_pre_raster"]],
      post_path = input_paths[["annual_post_raster"]],
      boundary_path = input_paths[["boundary_gpkg"]],
      title = "Annual inundation occurrence frequency",
      subtitle = "Percent of valid water years with at least one detected inundation event.",
      legend_title = "Annual occurrence (%)",
      caption = "White cells are no-data / outside valid support. Annual occurrence is not depth, duration or hydroperiod."
    )
    annual_prepost_path <- file.path(figure_dir, "inundation", "P0_1_annual_occurrence_pre_post_maps.png")
    gayini_save_review_figure(annual_prepost_path, annual_prepost)

    manifest[[length(manifest) + 1L]] <- gayini_task15_manifest_row(
      root_dir,
      "P0.1",
      "P0",
      "Annual occurrence pre/post maps with white background",
      annual_prepost_path,
      source_script,
      annual_sources,
      "Annual inundation",
      status = "created",
      caption_suggestion = "Pre- and post-2019 annual occurrence frequency, computed as 100 x wet valid water years / valid water years.",
      caveat_text = "Annual occurrence is spatial exposure / occurrence, not depth, duration, hydroperiod, dry intervals, water quality or ecological outcome.",
      qa_status = "pass",
      qa_notes = "Raster NA cells are filtered and plotted on a white panel/background."
    )
  }

  if (any(is.na(input_paths[c("annual_change_raster", "boundary_gpkg")]))) {
    manifest[[length(manifest) + 1L]] <- gayini_task15_skip_row(
      root_dir,
      "P0.2",
      "P0",
      "Post-minus-pre annual occurrence change map",
      source_script,
      annual_sources,
      "Annual inundation",
      "Annual occurrence change raster or boundary layer was not found.",
      "Change is reported in percentage points and is not causal proof."
    )
  } else {
    annual_change <- gayini_task15_change_map(
      change_path = input_paths[["annual_change_raster"]],
      boundary_path = input_paths[["boundary_gpkg"]],
      title = "Post-minus-pre annual occurrence change",
      subtitle = "Post-2019 annual occurrence frequency minus pre-2019 annual occurrence frequency.",
      legend_title = "Change (percentage points)",
      caption = "Centred diverging scale. Positive values indicate greater mapped annual occurrence post-2019."
    )
    annual_change_path <- file.path(figure_dir, "inundation", "P0_2_annual_occurrence_change_map.png")
    gayini_save_review_figure(annual_change_path, annual_change)

    manifest[[length(manifest) + 1L]] <- gayini_task15_manifest_row(
      root_dir,
      "P0.2",
      "P0",
      "Post-minus-pre annual occurrence change map with white background",
      annual_change_path,
      source_script,
      annual_sources,
      "Annual inundation",
      status = "created",
      caption_suggestion = "Post-minus-pre annual occurrence frequency change in percentage points.",
      caveat_text = "Change is descriptive spatial exposure / occurrence, not a causal treatment effect or hydroperiod metric.",
      qa_status = "pass",
      qa_notes = "White map background and centred diverging percentage-point scale used."
    )
  }

  mer_sources <- paste(
    gayini_relative_path(root_dir, input_paths[["mer_pre_raster"]]),
    gayini_relative_path(root_dir, input_paths[["mer_post_raster"]]),
    gayini_relative_path(root_dir, input_paths[["mer_change_raster"]]),
    gayini_relative_path(root_dir, input_paths[["boundary_gpkg"]]),
    sep = "; "
  )

  if (any(is.na(input_paths[c("mer_pre_raster", "mer_post_raster", "boundary_gpkg")]))) {
    manifest[[length(manifest) + 1L]] <- gayini_task15_skip_row(
      root_dir,
      "P0.3a",
      "P0",
      "MER pre/post annual maximum observed wet maps",
      source_script,
      mer_sources,
      "MER",
      "MER period summary rasters or boundary layer were not found.",
      "MER annual maximum observed wet extent is supplementary and is not hydroperiod, duration, depth or causal proof."
    )
  } else {
    mer_prepost <- gayini_task15_frequency_map(
      pre_path = input_paths[["mer_pre_raster"]],
      post_path = input_paths[["mer_post_raster"]],
      boundary_path = input_paths[["boundary_gpkg"]],
      title = "MER annual maximum observed wet frequency",
      subtitle = "Percent of valid years with observed annual maximum wet support.",
      legend_title = "MER frequency (%)",
      caption = "MER is supplementary event-footprint context. It is not hydroperiod, duration or depth."
    )
    mer_prepost_path <- file.path(figure_dir, "inundation", "P0_3a_MER_pre_post_annual_max_maps.png")
    gayini_save_review_figure(mer_prepost_path, mer_prepost)

    manifest[[length(manifest) + 1L]] <- gayini_task15_manifest_row(
      root_dir,
      "P0.3a",
      "P0",
      "MER pre/post annual maximum observed wet maps with white background",
      mer_prepost_path,
      source_script,
      mer_sources,
      "MER",
      status = "created",
      caption_suggestion = "MER annual maximum observed wet frequency, shown as supplementary event-footprint context.",
      caveat_text = "MER annual maximum observed wet extent is supplementary and is not hydroperiod, duration, depth or causal proof.",
      qa_status = "pass",
      qa_notes = "Raster NA cells are filtered and plotted on a white panel/background."
    )
  }

  if (any(is.na(input_paths[c("mer_change_raster", "boundary_gpkg")]))) {
    manifest[[length(manifest) + 1L]] <- gayini_task15_skip_row(
      root_dir,
      "P0.3b",
      "P0",
      "MER annual maximum observed wet change map",
      source_script,
      mer_sources,
      "MER",
      "MER change raster or boundary layer was not found.",
      "MER annual maximum observed wet extent is supplementary and is not hydroperiod, duration, depth or causal proof."
    )
  } else {
    mer_change <- gayini_task15_change_map(
      change_path = input_paths[["mer_change_raster"]],
      boundary_path = input_paths[["boundary_gpkg"]],
      title = "MER post-minus-pre annual maximum observed wet change",
      subtitle = "Post-2019 MER annual maximum observed wet frequency minus pre-2019 frequency.",
      legend_title = "Change (percentage points)",
      caption = "MER change is supplementary context and is not a duration, depth or hydroperiod result."
    )
    mer_change_path <- file.path(figure_dir, "inundation", "P0_3b_MER_annual_max_change_map.png")
    gayini_save_review_figure(mer_change_path, mer_change)

    manifest[[length(manifest) + 1L]] <- gayini_task15_manifest_row(
      root_dir,
      "P0.3b",
      "P0",
      "MER annual maximum observed wet change map with white background",
      mer_change_path,
      source_script,
      mer_sources,
      "MER",
      status = "created",
      caption_suggestion = "Post-minus-pre MER annual maximum observed wet change in percentage points.",
      caveat_text = "MER annual maximum observed wet extent is supplementary and is not hydroperiod, duration, depth or causal proof.",
      qa_status = "pass",
      qa_notes = "White map background and centred diverging percentage-point scale used."
    )
  }

  list(manifest = dplyr::bind_rows(manifest))
}
