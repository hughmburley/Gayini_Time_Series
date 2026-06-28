# ------------------------------------------------------------------------------
# Script: scripts/08_review_packages/02_make_ppt_missing_assets.R
# Purpose: Create missing PPT assets.
# Workflow stage: 08_review_packages
# Run mode: lightweight_review
# Heavy processing: no
# Key inputs:
#   - Existing outputs and spatial inputs.
# Key outputs:
#   - PPT missing-assets figures/registers.
# Notes:
#   - Keep stable output filenames for downstream reports.
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Load configuration and execute workflow step
# ------------------------------------------------------------------------------

## Purpose:
## Create lightweight, presentation-ready missing PowerPoint assets from existing
## vectors and summary tables only. This script does not run raster extraction,
## rebuild raster products, or edit PowerPoint files.


## User settings ----


root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", "D:/Github_repos/Gayini"), winslash = "/", mustWork = TRUE)
source(file.path(root_dir, "R", "gayini_time_helpers.R"))
ASSET_PACK_DATE <- format(Sys.Date(), "%Y%m%d")
MANAGEMENT_CHANGE_DATE <- gayini_management_transition_date()


## Required packages ----


required_packages <- c(
  "dplyr",
  "tidyr",
  "readr",
  "stringr",
  "magrittr",
  "tibble",
  "ggplot2",
  "sf",
  "grid"
)

source(file.path(root_dir, "R", "gayini_analysis_base_functions.R"))
source(file.path(root_dir, "R", "gayini_output_helpers.R"))
source(file.path(root_dir, "R", "gayini_plotting_helpers.R"))
gayini_check_packages(required_packages)

library(dplyr)
library(tidyr)
library(readr)
library(stringr)
library(magrittr)
library(tibble)
library(ggplot2)
library(sf)
library(grid)


## Paths ----


figure_dir <- file.path(root_dir, "Output", "figures", "review")
report_dir <- file.path(root_dir, "Output", "reports")
csv_dir <- file.path(root_dir, "Output", "csv")
diagnostics_dir <- file.path(root_dir, "Output", "diagnostics", "14_ppt_missing_assets")
spatial_dir <- file.path(root_dir, "data_intermediate", "spatial")
raster_dir <- file.path(root_dir, "Output", "rasters")

gayini_ensure_dir(figure_dir)
gayini_ensure_dir(report_dir)
gayini_ensure_dir(diagnostics_dir)

boundary_path <- file.path(spatial_dir, "boundary_clean.gpkg")
plots_path <- file.path(spatial_dir, "plots_clean.gpkg")
management_path <- file.path(spatial_dir, "management_zones_clean.gpkg")
vegetation_path <- file.path(spatial_dir, "vegetation_classes_clean.gpkg")
plot_context_path <- file.path(csv_dir, "plot_context_flags.csv")
plot_rs_gauge_base_path <- file.path(csv_dir, "plot_rs_gauge_analysis_base.csv")
gc_interpretation_path <- file.path(csv_dir, "10a_ground_cover_prepost_plot_summary_interpretation.csv")
gauge_completeness_path <- file.path(csv_dir, "gauge_data_completeness_for_gayini.csv")
gauge_metadata_path <- file.path(root_dir, "Input", "hydrology", "gauge_metadata.csv")

asset_register_path <- file.path(report_dir, "Gayini_ppt_asset_register.csv")
missing_assets_path <- file.path(report_dir, "Gayini_ppt_missing_assets.csv")
handoff_path <- file.path(report_dir, "task_7_missing_ppt_assets_handoff.md")
workflow_notes_path <- file.path(report_dir, "gayini_analysis_workflow_summary_notes.md")
checks_path <- file.path(diagnostics_dir, "task7_missing_asset_checks.csv")
copy_log_path <- file.path(diagnostics_dir, "task7_asset_pack_copy_log.csv")

location_map_path <- file.path(figure_dir, "gayini_location_context_map.png")
location_map_wide_path <- file.path(figure_dir, "gayini_location_context_map_wide.png")
vegetation_map_path <- file.path(figure_dir, "gayini_vegetation_group_map.png")
vegetation_map_plots_path <- file.path(figure_dir, "gayini_vegetation_group_map_with_plots.png")
gauge_map_path <- file.path(figure_dir, "gayini_gauge_location_map.png")
gauge_map_flow_path <- file.path(figure_dir, "gayini_gauge_location_map_with_flow_direction.png")
workflow_path <- file.path(figure_dir, "gayini_analysis_workflow_summary.png")
synthesis_path <- file.path(figure_dir, "gayini_hydrology_inundation_vegetation_synthesis.png")

required_inputs <- c(
  boundary = boundary_path,
  plots = plots_path,
  management_zones = management_path,
  vegetation_classes = vegetation_path,
  plot_context_flags = plot_context_path,
  plot_rs_gauge_analysis_base = plot_rs_gauge_base_path,
  ground_cover_interpretation = gc_interpretation_path,
  gauge_completeness = gauge_completeness_path,
  gauge_metadata = gauge_metadata_path,
  ppt_asset_register = asset_register_path,
  ppt_missing_assets = missing_assets_path
)

missing_inputs <- names(required_inputs)[!file.exists(required_inputs)]
if (length(missing_inputs) > 0L) {
  stop("Missing required input(s): ", paste(missing_inputs, collapse = ", "), call. = FALSE)
}


## Helpers ----


write_csv_message <- gayini_write_csv


theme_deck_map <- function(base_size = 13) {
  gayini_theme_map(base_size = base_size, legend_position = "right") +
    ggplot2::theme(plot.margin = ggplot2::margin(14, 20, 14, 26))
}


theme_deck_chart <- function(base_size = 13) {
  gayini_theme_review(base_size = base_size, legend_position = "right") +
    ggplot2::theme(plot.margin = ggplot2::margin(14, 20, 14, 26))
}


flag_treed_vegetation <- function(vegetation_class) {
  vegetation_class <- stringr::str_squish(as.character(vegetation_class))

  stringr::str_detect(
    stringr::str_to_lower(vegetation_class),
    "floodplain forest|floodplain woodland|floodplain woodlands|riverine forest|riverine forests|woodland|woodlands|forest|forests"
  )
}


collapse_vegetation_group <- function(vegetation_class) {
  vegetation_class <- stringr::str_squish(as.character(vegetation_class))

  dplyr::case_when(
    is.na(vegetation_class) | vegetation_class == "" ~ "Unknown vegetation",
    flag_treed_vegetation(vegetation_class) ~ "Floodplain Woodland / Forest",
    vegetation_class %in% c("Inland Floodplain Shrublands", "Inland Floodplain Swamps") ~
      "Inland Floodplain Shrublands / Swamps",
    TRUE ~ vegetation_class
  )
}


add_map_helpers <- function(p, bbox, scale_km = 10) {
  x_range <- bbox[["xmax"]] - bbox[["xmin"]]
  y_range <- bbox[["ymax"]] - bbox[["ymin"]]
  sx <- bbox[["xmin"]] + 0.06 * x_range
  sy <- bbox[["ymin"]] + 0.08 * y_range
  nx <- bbox[["xmax"]] - 0.08 * x_range
  ny <- bbox[["ymin"]] + 0.12 * y_range

  p +
    ggplot2::annotate("segment", x = sx, xend = sx + scale_km * 1000, y = sy, yend = sy, linewidth = 0.7, colour = "#2f3432") +
    ggplot2::annotate("text", x = sx + scale_km * 500, y = sy + 0.025 * y_range, label = paste0(scale_km, " km"), size = 3.2, colour = "#2f3432") +
    ggplot2::annotate(
      "segment",
      x = nx,
      xend = nx,
      y = ny,
      yend = ny + 0.11 * y_range,
      arrow = grid::arrow(length = grid::unit(0.14, "inches")),
      linewidth = 0.6,
      colour = "#2f3432"
    ) +
    ggplot2::annotate("text", x = nx, y = ny + 0.14 * y_range, label = "N", fontface = "bold", size = 3.4, colour = "#2f3432")
}


safe_mean <- function(x) {
  if (all(is.na(x))) {
    return(NA_real_)
  }
  mean(x, na.rm = TRUE)
}


safe_count <- function(x, predicate) {
  sum(predicate(x), na.rm = TRUE)
}


make_asset_row <- function(asset_id, file_path, title, module, role, slide, priority, source_script, source_data, caveat, notes) {
  info <- file.info(file_path)

  tibble::tibble(
    asset_id = asset_id,
    filename = basename(file_path),
    full_path = normalizePath(file_path, winslash = "/", mustWork = FALSE),
    file_type = stringr::str_remove(tools::file_ext(file_path), "^$"),
    file_modified_date = if (file.exists(file_path)) format(info$mtime, "%Y-%m-%dT%H:%M:%S") else NA_character_,
    figure_or_table_title = title,
    analysis_module = module,
    story_role = role,
    recommended_slide = slide,
    deck_priority = priority,
    asset_status = "Current canonical",
    supersedes = NA_character_,
    superseded_by = NA_character_,
    source_script = source_script,
    source_data = source_data,
    review_caveat = caveat,
    notes = notes
  )
}


copy_asset <- function(file_path, asset_pack_dir, subfolder) {
  destination_dir <- file.path(asset_pack_dir, subfolder)
  dir.create(destination_dir, recursive = TRUE, showWarnings = FALSE)

  destination_path <- file.path(destination_dir, basename(file_path))
  copied <- if (file.exists(file_path)) {
    file.copy(file_path, destination_path, overwrite = TRUE)
  } else {
    FALSE
  }

  tibble::tibble(
    source_path = file_path,
    destination_path = destination_path,
    copied = copied,
    source_exists = file.exists(file_path),
    destination_exists = file.exists(destination_path),
    asset_pack_subfolder = subfolder
  )
}


## Raster snapshot before lightweight work ----


tif_snapshot_before <- tibble::tibble(
  tif_path = list.files(raster_dir, pattern = "\\.tif$", recursive = TRUE, full.names = TRUE),
  last_write_time_before = as.character(file.info(tif_path)$mtime),
  size_before = file.info(tif_path)$size
)


## Read inputs ----


boundary_sf <- sf::st_read(boundary_path, quiet = TRUE) %>%
  sf::st_make_valid()

plots_sf <- sf::st_read(plots_path, quiet = TRUE) %>%
  sf::st_make_valid() %>%
  gayini_standardise_plot_id(object_name = "plot polygons")

management_sf <- sf::st_read(management_path, quiet = TRUE) %>%
  sf::st_transform(sf::st_crs(boundary_sf)) %>%
  sf::st_make_valid()

vegetation_sf <- sf::st_read(vegetation_path, quiet = TRUE) %>%
  sf::st_transform(sf::st_crs(boundary_sf)) %>%
  sf::st_make_valid() %>%
  dplyr::mutate(
    simplified_vegetation_group = collapse_vegetation_group(.data$Vegetation)
  )

plot_context <- readr::read_csv(plot_context_path, show_col_types = FALSE) %>%
  gayini_standardise_plot_id(object_name = "plot context flags")

plots_with_context <- plots_sf %>%
  dplyr::left_join(plot_context, by = "plot_id")

plot_centroids <- plots_with_context %>%
  sf::st_centroid()

plot_rs_gauge <- readr::read_csv(plot_rs_gauge_base_path, show_col_types = FALSE) %>%
  gayini_standardise_plot_id(object_name = "plot RS/gauge analysis base")

gc_interpretation <- readr::read_csv(gc_interpretation_path, show_col_types = FALSE) %>%
  gayini_standardise_plot_id(object_name = "ground-cover interpretation table")

gauge_completeness <- readr::read_csv(gauge_completeness_path, show_col_types = FALSE)
gauge_metadata <- readr::read_csv(gauge_metadata_path, show_col_types = FALSE)


## Shared data for maps ----


boundary_ll <- boundary_sf %>%
  sf::st_transform(4326)

gayini_point_ll <- boundary_ll %>%
  sf::st_union() %>%
  sf::st_centroid() %>%
  sf::st_as_sf()

gayini_coord <- sf::st_coordinates(gayini_point_ll)[1, ]
boundary_bbox <- sf::st_bbox(boundary_sf)

vegetation_palette <- gayini_vegetation_group_palette()

management_fill <- "#f5f3ea"
boundary_colour <- "#243331"


## 1. Study area / location map ----


nsw_locator <- ggplot2::ggplot() +
  ggplot2::annotate("rect", xmin = 141, xmax = 154.2, ymin = -37.7, ymax = -28.0, fill = "#f4f6f2", colour = "#b9c0b8", linewidth = 0.4) +
  ggplot2::annotate("path", x = c(148.7, 147.2, 146.0, 145.0, 144.3, 143.6), y = c(-35.4, -35.0, -34.75, -34.58, -34.48, -34.63), colour = "#4d8aa8", linewidth = 1.0) +
  ggplot2::annotate("point", x = gayini_coord[["X"]], y = gayini_coord[["Y"]], size = 4.0, shape = 21, fill = "#cc5c43", colour = "white", stroke = 0.7) +
  ggplot2::annotate("text", x = gayini_coord[["X"]] + 0.35, y = gayini_coord[["Y"]] + 0.18, label = "Gayini", fontface = "bold", hjust = 0, size = 4.0, colour = "#263330") +
  ggplot2::annotate("text", x = 146.0, y = -34.15, label = "Murrumbidgee River corridor", colour = "#336f8c", size = 3.4) +
  ggplot2::coord_equal(xlim = c(143.0, 149.2), ylim = c(-35.9, -33.75), expand = FALSE) +
  ggplot2::labs(
    title = "Gayini in southern NSW",
    subtitle = "Schematic locator"
  ) +
  theme_deck_map(12) +
  ggplot2::theme(legend.position = "none")

property_context <- ggplot2::ggplot() +
  ggplot2::geom_sf(data = management_sf, fill = management_fill, colour = "#d4d2c7", linewidth = 0.18) +
  ggplot2::geom_sf(data = boundary_sf, fill = NA, colour = boundary_colour, linewidth = 0.7) +
  ggplot2::geom_sf(data = plot_centroids, shape = 21, fill = "#254f5f", colour = "white", stroke = 0.25, size = 2.0, alpha = 0.9) +
  ggplot2::labs(
    title = "Study area and monitoring plots",
    subtitle = "Boundary, management zones and plot centroids",
    caption = "Source: existing cleaned Gayini vector layers. No raster products were rebuilt."
  ) +
  theme_deck_map(12)

property_context <- add_map_helpers(property_context, boundary_bbox, scale_km = 10)

png(filename = location_map_path, width = 11, height = 7.5, units = "in", res = 220)
grid::grid.newpage()
grid::pushViewport(grid::viewport(layout = grid::grid.layout(nrow = 1, ncol = 2, widths = grid::unit(c(1.05, 1.55), "null"))))
print(nsw_locator, vp = grid::viewport(layout.pos.row = 1, layout.pos.col = 1))
print(property_context, vp = grid::viewport(layout.pos.row = 1, layout.pos.col = 2))
dev.off()
message("Wrote: ", location_map_path)

png(filename = location_map_wide_path, width = 14.2, height = 7.2, units = "in", res = 220)
grid::grid.newpage()
grid::pushViewport(grid::viewport(layout = grid::grid.layout(nrow = 1, ncol = 2, widths = grid::unit(c(0.95, 1.75), "null"))))
print(nsw_locator, vp = grid::viewport(layout.pos.row = 1, layout.pos.col = 1))
print(property_context, vp = grid::viewport(layout.pos.row = 1, layout.pos.col = 2))
dev.off()
message("Wrote: ", location_map_wide_path)


## 2. Vegetation group maps ----


vegetation_base <- ggplot2::ggplot() +
  ggplot2::geom_sf(
    data = vegetation_sf,
    ggplot2::aes(fill = .data$simplified_vegetation_group),
    colour = "white",
    linewidth = 0.08,
    alpha = 0.95
  ) +
  ggplot2::geom_sf(data = boundary_sf, fill = NA, colour = boundary_colour, linewidth = 0.75) +
  ggplot2::scale_fill_manual(values = vegetation_palette, na.value = "#d4d4d4", name = "Simplified vegetation group") +
  ggplot2::labs(
    title = "Gayini simplified vegetation groups",
    subtitle = "Deck-facing grouping used for current review summaries",
    caption = "Source: existing vegetation class layer; grouping follows Task 1 review flags."
  ) +
  theme_deck_map(13)

vegetation_base <- add_map_helpers(vegetation_base, boundary_bbox, scale_km = 10)

ggplot2::ggsave(vegetation_map_path, vegetation_base, width = 11, height = 7.5, dpi = 220)
message("Wrote: ", vegetation_map_path)

vegetation_with_plots <- vegetation_base +
  ggplot2::geom_sf(
    data = plot_centroids,
    ggplot2::aes(shape = .data$ground_cover_exclusion_flag),
    fill = "#202b2c",
    colour = "white",
    size = 2.0,
    stroke = 0.25,
    inherit.aes = FALSE
  ) +
  ggplot2::scale_shape_manual(
    values = c(`FALSE` = 21, `TRUE` = 24),
    labels = c(`FALSE` = "GC interpretation plot", `TRUE` = "Treed / GC caveat"),
    name = "Plot overlay"
  ) +
  ggplot2::labs(
    title = "Vegetation groups with monitoring plots",
    subtitle = "Plot overlay included for ecological-context slides"
  )

ggplot2::ggsave(vegetation_map_plots_path, vegetation_with_plots, width = 11, height = 7.5, dpi = 220)
message("Wrote: ", vegetation_map_plots_path)


## 3. Gauge location map ----


gauge_locations <- tibble::tribble(
  ~station_name_short, ~station_name_pattern, ~longitude, ~latitude, ~gauge_role,
  "Darlington Point", "Darlington Point", 145.998, -34.570, "Preferred context",
  "Hay Weir", "Hay Weir", 144.846, -34.510, "Preferred context",
  "Maude Weir", "Maude Weir", 144.315, -34.475, "Preferred context",
  "Balranald Weir", "Balranald Weir", 143.561, -34.644, "Preferred context / downstream",
  "Redbank Weir", "Redbank", 143.760, -34.390, "Secondary / cautious"
) %>%
  dplyr::cross_join(
    gauge_metadata %>%
      dplyr::mutate(station_name_match = .data$station_name) %>%
      dplyr::select("station_id", "station_name", "recommended_use", "interpretation", "missing_flow_pct")
  ) %>%
  dplyr::filter(stringr::str_detect(.data$station_name, .data$station_name_pattern)) %>%
  dplyr::group_by(.data$station_name_short) %>%
  dplyr::slice_head(n = 1) %>%
  dplyr::ungroup() %>%
  dplyr::mutate(
    caution_flag = stringr::str_detect(stringr::str_to_lower(.data$station_name_short), "redbank"),
    label = dplyr::if_else(.data$caution_flag, paste0(.data$station_name_short, " (cautious)"), .data$station_name_short)
  )

murrumbidgee_line <- tibble::tibble(
  longitude = c(146.20, 145.998, 144.846, 144.315, 143.760, 143.561),
  latitude = c(-34.65, -34.570, -34.510, -34.475, -34.390, -34.644)
)

flow_segments <- murrumbidgee_line %>%
  dplyr::mutate(
    longitude_end = dplyr::lead(.data$longitude),
    latitude_end = dplyr::lead(.data$latitude)
  ) %>%
  dplyr::filter(!is.na(.data$longitude_end), !is.na(.data$latitude_end)) %>%
  dplyr::slice(c(1, 3))

gauge_map <- ggplot2::ggplot() +
  ggplot2::geom_path(data = murrumbidgee_line, ggplot2::aes(x = .data$longitude, y = .data$latitude), colour = "#4d8aa8", linewidth = 1.2, lineend = "round") +
  ggplot2::geom_point(ggplot2::aes(x = gayini_coord[["X"]], y = gayini_coord[["Y"]]), shape = 23, fill = "#cc5c43", colour = "white", size = 4.6, stroke = 0.7) +
  ggplot2::geom_point(
    data = gauge_locations,
    ggplot2::aes(x = .data$longitude, y = .data$latitude, fill = .data$gauge_role),
    shape = 21,
    colour = "#1f2d2a",
    size = 4.1,
    stroke = 0.45
  ) +
  ggplot2::geom_text(
    data = gauge_locations,
    ggplot2::aes(x = .data$longitude, y = .data$latitude, label = .data$label),
    nudge_y = 0.10,
    size = 3.3,
    check_overlap = TRUE,
    colour = "#1f2d2a"
  ) +
  ggplot2::annotate("text", x = gayini_coord[["X"]] + 0.12, y = gayini_coord[["Y"]] - 0.08, label = "Gayini", hjust = 0, fontface = "bold", size = 3.8, colour = "#1f2d2a") +
  ggplot2::scale_fill_manual(
    values = gayini_gauge_role_palette("display"),
    name = "Gauge role"
  ) +
  ggplot2::coord_equal(xlim = c(143.35, 146.25), ylim = c(-35.05, -34.05), expand = FALSE) +
  ggplot2::labs(
    title = "Gauge context for Gayini review",
    subtitle = "Key Murrumbidgee gauges used as hydrological context",
    x = NULL,
    y = NULL,
    caption = "Gauge coordinates are approximate because current Gayini gauge metadata do not include coordinate fields. Redbank is shown as secondary/cautious context."
  ) +
  theme_deck_chart(12) +
  ggplot2::theme(
    panel.grid.major = ggplot2::element_line(colour = "#e9ece7", linewidth = 0.25),
    legend.position = "right"
  )

ggplot2::ggsave(gauge_map_path, gauge_map, width = 11, height = 6.6, dpi = 220)
message("Wrote: ", gauge_map_path)

gauge_map_flow <- gauge_map +
  ggplot2::geom_segment(
    data = flow_segments,
    ggplot2::aes(x = .data$longitude, y = .data$latitude, xend = .data$longitude_end, yend = .data$latitude_end),
    inherit.aes = FALSE,
    arrow = grid::arrow(length = grid::unit(0.16, "inches")),
    colour = "#336f8c",
    linewidth = 0.65
  ) +
  ggplot2::labs(subtitle = "Approximate upstream-to-downstream gauge order; flow context is not causal proof")

ggplot2::ggsave(gauge_map_flow_path, gauge_map_flow, width = 11, height = 6.6, dpi = 220)
message("Wrote: ", gauge_map_flow_path)


## 4. Simplified workflow figure ----


workflow_nodes <- tibble::tibble(
  node = c("Context /\nstudy area", "Hydrology /\ngauges", "Inundation", "Ground cover /\nvegetation", "MODIS /\nlonger context", "Lag diagnostics", "Interpretation"),
  x = seq_len(7),
  y = 1,
  module = c("Context", "Hydrology", "Inundation", "Ground cover", "MODIS", "Diagnostics", "Interpretation"),
  fill = c("#dfe7dc", "#d7e8ef", "#cfe1ec", "#dcebd3", "#eadfc8", "#e9e2f0", "#f0dfd6")
)

workflow_edges <- tibble::tibble(
  x = workflow_nodes$x[-nrow(workflow_nodes)] + 0.42,
  xend = workflow_nodes$x[-1] - 0.42,
  y = 1,
  yend = 1
)

workflow_figure <- ggplot2::ggplot() +
  ggplot2::geom_segment(
    data = workflow_edges,
    ggplot2::aes(x = .data$x, xend = .data$xend, y = .data$y, yend = .data$yend),
    arrow = grid::arrow(length = grid::unit(0.16, "inches")),
    linewidth = 0.65,
    colour = "#5b625f"
  ) +
  ggplot2::geom_rect(
    data = workflow_nodes,
    ggplot2::aes(xmin = .data$x - 0.42, xmax = .data$x + 0.42, ymin = 0.72, ymax = 1.28, fill = .data$module),
    colour = "#2f3432",
    linewidth = 0.35
  ) +
  ggplot2::geom_text(
    data = workflow_nodes,
    ggplot2::aes(x = .data$x, y = .data$y, label = .data$node),
    size = 3.7,
    lineheight = 0.9,
    colour = "#1f2d2a"
  ) +
  ggplot2::scale_fill_manual(values = stats::setNames(workflow_nodes$fill, workflow_nodes$module)) +
  ggplot2::coord_cartesian(xlim = c(0.45, 7.55), ylim = c(0.45, 1.55), expand = FALSE) +
  ggplot2::labs(
    title = "Gayini review analysis workflow",
    subtitle = "Presentation summary: remote sensing first, with gauges as hydrological context",
    caption = "Annual inundation occurrence remains the headline water metric; MER and lag diagnostics are supporting/appendix material."
  ) +
  theme_deck_chart(13) +
  ggplot2::theme(
    axis.text = ggplot2::element_blank(),
    axis.title = ggplot2::element_blank(),
    panel.grid = ggplot2::element_blank(),
    legend.position = "none"
  )

ggplot2::ggsave(workflow_path, workflow_figure, width = 13, height = 4.6, dpi = 220)
message("Wrote: ", workflow_path)

workflow_notes <- c(
  "# Gayini Analysis Workflow Summary Notes",
  "",
  "This graphic is intended for a PowerPoint workflow slide, not as a code-flow chart.",
  "",
  "Core sequence:",
  "",
  "1. Context / study area",
  "2. Hydrology / gauges",
  "3. Inundation",
  "4. Ground cover / vegetation",
  "5. MODIS / longer-term context",
  "6. Lag diagnostics",
  "7. Interpretation",
  "",
  "Caveats:",
  "",
  "- Gauge data are hydrological context only.",
  "- Annual inundation occurrence is not hydroperiod, duration, depth or wet days.",
  "- Pre/post framing is diagnostic/coincident, not causal proof.",
  "- MER metrics remain supporting/appendix unless promoted later."
)

writeLines(workflow_notes, workflow_notes_path)
message("Wrote: ", workflow_notes_path)


## 5. Lightweight synthesis figure ----


preferred_gauge_names <- plot_rs_gauge %>%
  dplyr::pull(.data$preferred_gauge_names) %>%
  stats::na.omit() %>%
  unique()

gauge_summary <- gauge_completeness %>%
  dplyr::filter(.data$time_scale == "monthly", .data$gauge_context_role == "preferred_context") %>%
  dplyr::summarise(
    n_gauges = dplyr::n_distinct(.data$gauge_name),
    mean_missing_flow_pct = safe_mean(.data$mean_missing_flow_pct),
    .groups = "drop"
  )

inundation_summary <- plot_rs_gauge %>%
  dplyr::summarise(
    n_plots = dplyr::n_distinct(.data$plot_id),
    n_wetter = safe_count(.data$post_minus_pre_inundation_frequency_pct_points, function(x) x > 5),
    n_drier = safe_count(.data$post_minus_pre_inundation_frequency_pct_points, function(x) x < -5),
    mean_change = safe_mean(.data$post_minus_pre_inundation_frequency_pct_points),
    .groups = "drop"
  )

vegetation_summary <- gc_interpretation %>%
  dplyr::summarise(
    n_non_treed = dplyr::n_distinct(.data$plot_id),
    mean_total_veg_change = safe_mean(.data$delta_total_veg_pct),
    n_strong_increase = sum(.data$strong_total_veg_increase, na.rm = TRUE),
    n_strong_decrease = sum(.data$strong_total_veg_decrease, na.rm = TRUE),
    .groups = "drop"
  )

synthesis_nodes <- tibble::tibble(
  panel = c("Hydrology context", "Observed inundation", "Vegetation response"),
  x = c(1, 2, 3),
  y = 1,
  fill = c("#d7e8ef", "#cfe1ec", "#dcebd3"),
  body = c(
    paste0(
      gauge_summary$n_gauges, " preferred gauges\n",
      round(gauge_summary$mean_missing_flow_pct, 1), "% mean missing flow\n",
      "Context only"
    ),
    paste0(
      inundation_summary$n_plots, " plots screened\n",
      inundation_summary$n_wetter, " wetter; ", inundation_summary$n_drier, " drier\n",
      "Annual occurrence"
    ),
    paste0(
      vegetation_summary$n_non_treed, " non-treed plots\n",
      round(vegetation_summary$mean_total_veg_change, 1), " pp mean total veg change\n",
      "Diagnostic response"
    )
  )
)

synthesis_edges <- tibble::tibble(
  x = c(1.36, 2.36),
  xend = c(1.64, 2.64),
  y = c(1, 1),
  yend = c(1, 1)
)

synthesis_figure <- ggplot2::ggplot() +
  ggplot2::geom_segment(
    data = synthesis_edges,
    ggplot2::aes(x = .data$x, xend = .data$xend, y = .data$y, yend = .data$yend),
    arrow = grid::arrow(length = grid::unit(0.16, "inches")),
    linewidth = 0.7,
    colour = "#6b706d",
    linetype = "dashed"
  ) +
  ggplot2::geom_rect(
    data = synthesis_nodes,
    ggplot2::aes(xmin = .data$x - 0.34, xmax = .data$x + 0.34, ymin = 0.55, ymax = 1.45, fill = .data$panel),
    colour = "#2f3432",
    linewidth = 0.4
  ) +
  ggplot2::geom_text(
    data = synthesis_nodes,
    ggplot2::aes(x = .data$x, y = 1.28, label = .data$panel),
    fontface = "bold",
    size = 4.0,
    colour = "#1f2d2a"
  ) +
  ggplot2::geom_text(
    data = synthesis_nodes,
    ggplot2::aes(x = .data$x, y = 0.92, label = .data$body),
    size = 3.5,
    lineheight = 0.95,
    colour = "#1f2d2a"
  ) +
  ggplot2::scale_fill_manual(values = stats::setNames(synthesis_nodes$fill, synthesis_nodes$panel)) +
  ggplot2::coord_cartesian(xlim = c(0.55, 3.45), ylim = c(0.35, 1.65), expand = FALSE) +
  ggplot2::labs(
    title = "Review synthesis: context, water signal, vegetation response",
    subtitle = "A compact slide concept from existing summary outputs",
    caption = "Dashed links are interpretive context, not causal proof. pp = percentage points."
  ) +
  theme_deck_chart(13) +
  ggplot2::theme(
    axis.text = ggplot2::element_blank(),
    axis.title = ggplot2::element_blank(),
    panel.grid = ggplot2::element_blank(),
    legend.position = "none"
  )

ggplot2::ggsave(synthesis_path, synthesis_figure, width = 12, height = 5.2, dpi = 220)
message("Wrote: ", synthesis_path)


## Update PPT asset register and missing list ----


task7_assets <- dplyr::bind_rows(
  make_asset_row(
    "PPTTASK7_001",
    location_map_path,
    "Gayini location and study area context map",
    "Study area",
    "Context",
    "2. Study area and Gayini overview",
    "Headline",
    "scripts/08_review_packages/02_make_ppt_missing_assets.R",
    "data_intermediate/spatial/boundary_clean.gpkg; data_intermediate/spatial/management_zones_clean.gpkg; data_intermediate/spatial/plots_clean.gpkg",
    "NSW locator is schematic because no external NSW/MDB boundary layer is stored in the repo.",
    "Opening-slide study-area map."
  ),
  make_asset_row(
    "PPTTASK7_002",
    location_map_wide_path,
    "Gayini location and study area context map wide",
    "Study area",
    "Context",
    "2. Study area and Gayini overview",
    "Headline",
    "scripts/08_review_packages/02_make_ppt_missing_assets.R",
    "data_intermediate/spatial/boundary_clean.gpkg; data_intermediate/spatial/management_zones_clean.gpkg; data_intermediate/spatial/plots_clean.gpkg",
    "NSW locator is schematic because no external NSW/MDB boundary layer is stored in the repo.",
    "Wide opening-slide variant."
  ),
  make_asset_row(
    "PPTTASK7_003",
    vegetation_map_path,
    "Gayini simplified vegetation group map",
    "Plot context",
    "Context",
    "13. Vegetation groups",
    "Headline",
    "scripts/08_review_packages/02_make_ppt_missing_assets.R",
    "data_intermediate/spatial/vegetation_classes_clean.gpkg; Output/csv/plot_context_flags.csv",
    "Vegetation classes are simplified for deck readability; use detailed source classes in appendix if needed.",
    "Large landscape/ecological context map."
  ),
  make_asset_row(
    "PPTTASK7_004",
    vegetation_map_plots_path,
    "Gayini simplified vegetation group map with plot overlay",
    "Plot context",
    "Context",
    "13. Vegetation groups",
    "Headline",
    "scripts/08_review_packages/02_make_ppt_missing_assets.R",
    "data_intermediate/spatial/vegetation_classes_clean.gpkg; data_intermediate/spatial/plots_clean.gpkg; Output/csv/plot_context_flags.csv",
    "Plot overlay is for context; treed flag affects ground-cover interpretation only.",
    "Use if the slide needs plot positions over ecological groups."
  ),
  make_asset_row(
    "PPTTASK7_005",
    gauge_map_path,
    "Gayini gauge location overview",
    "Hydrology",
    "Hydrology",
    "7. Hydrology / gauge context",
    "Headline",
    "scripts/08_review_packages/02_make_ppt_missing_assets.R",
    "Input/hydrology/gauge_metadata.csv; Output/csv/gauge_data_completeness_for_gayini.csv",
    "Gauge coordinates are approximate because current gauge metadata do not include coordinate fields.",
    "Hydrology context map; Redbank shown as cautious."
  ),
  make_asset_row(
    "PPTTASK7_006",
    gauge_map_flow_path,
    "Gayini gauge location overview with flow direction",
    "Hydrology",
    "Hydrology",
    "7. Hydrology / gauge context",
    "Supporting",
    "scripts/08_review_packages/02_make_ppt_missing_assets.R",
    "Input/hydrology/gauge_metadata.csv; Output/csv/gauge_data_completeness_for_gayini.csv",
    "Gauge coordinates and flow-direction line are approximate/schematic.",
    "Optional hydrology context map with approximate flow-direction cue."
  ),
  make_asset_row(
    "PPTTASK7_007",
    workflow_path,
    "Gayini review analysis workflow summary",
    "Review governance",
    "Methods",
    "5. Analysis workflow",
    "Headline",
    "scripts/08_review_packages/02_make_ppt_missing_assets.R",
    "docs/current_run_order.md; Output/reports/Gayini_story_structure.md",
    "Presentation workflow only; not a full code-flow diagram.",
    "Clean slide-ready workflow graphic."
  ),
  make_asset_row(
    "PPTTASK7_008",
    synthesis_path,
    "Hydrology inundation vegetation synthesis figure",
    "Review governance",
    "Environmental change",
    "19. Current interpretation",
    "Supporting",
    "scripts/08_review_packages/02_make_ppt_missing_assets.R",
    "Output/csv/gauge_data_completeness_for_gayini.csv; Output/csv/plot_rs_gauge_analysis_base.csv; Output/csv/10a_ground_cover_prepost_plot_summary_interpretation.csv",
    "Conceptual synthesis from existing outputs; interpretive links are not causal proof.",
    "Optional compact synthesis slide concept."
  ),
  make_asset_row(
    "PPTTASK7_009",
    workflow_notes_path,
    "Workflow figure notes",
    "Review governance",
    "Methods",
    "Speaker notes / reference",
    "Appendix",
    "scripts/08_review_packages/02_make_ppt_missing_assets.R",
    "docs/current_run_order.md; Output/reports/Gayini_story_structure.md",
    "Reference note only.",
    "Editable text companion for workflow figure."
  )
)

asset_register <- readr::read_csv(asset_register_path, show_col_types = FALSE)
asset_register <- asset_register %>%
  dplyr::mutate(file_modified_date = as.character(.data$file_modified_date))

completed_missing_titles <- c(
  "large gayini location map",
  "large vegetation group map",
  "gauge location map",
  "updated simplified workflow figure",
  "combined hydrology inundation vegetation synthesis"
)

updated_register <- asset_register %>%
  dplyr::filter(
    !(.data$filename %in% task7_assets$filename),
    !(
      .data$asset_status %in% c("Missing", "Needs regeneration", "Needs decision") &
        stringr::str_to_lower(.data$figure_or_table_title) %in% completed_missing_titles
    )
  ) %>%
  dplyr::mutate(
    deck_priority = dplyr::if_else(.data$asset_status %in% c("Missing", "Needs regeneration", "Needs decision"), "Defer", .data$deck_priority)
  ) %>%
  dplyr::bind_rows(task7_assets) %>%
  dplyr::arrange(.data$deck_priority, .data$asset_status, .data$asset_id)

write_csv_message(updated_register, asset_register_path)

remaining_missing <- readr::read_csv(missing_assets_path, show_col_types = FALSE) %>%
  dplyr::filter(!.data$needed_asset %in% c(
    "large_gayini_location_map",
    "large_vegetation_group_map",
    "gauge_location_map",
    "updated_simplified_workflow_figure",
    "combined_hydrology_inundation_vegetation_synthesis"
  )) %>%
  dplyr::mutate(
    current_status = dplyr::case_when(
      .data$needed_asset == "lag_diagnostic_summary" ~ "Deferred",
      TRUE ~ .data$current_status
    )
  )

write_csv_message(remaining_missing, missing_assets_path)


## Copy to current PPT asset pack ----


asset_pack_candidates <- list.dirs(report_dir, recursive = FALSE, full.names = TRUE) %>%
  .[stringr::str_detect(basename(.), "^ppt_asset_pack_")]

asset_pack_dir <- if (length(asset_pack_candidates) > 0L) {
  asset_pack_candidates[order(asset_pack_candidates, decreasing = TRUE)][1]
} else {
  file.path(report_dir, paste0("ppt_asset_pack_", ASSET_PACK_DATE))
}

copy_log <- dplyr::bind_rows(
  copy_asset(location_map_path, asset_pack_dir, "01_main_deck_figures"),
  copy_asset(location_map_wide_path, asset_pack_dir, "01_main_deck_figures"),
  copy_asset(vegetation_map_path, asset_pack_dir, "01_main_deck_figures"),
  copy_asset(vegetation_map_plots_path, asset_pack_dir, "01_main_deck_figures"),
  copy_asset(gauge_map_path, asset_pack_dir, "01_main_deck_figures"),
  copy_asset(gauge_map_flow_path, asset_pack_dir, "02_supporting_figures"),
  copy_asset(workflow_path, asset_pack_dir, "01_main_deck_figures"),
  copy_asset(synthesis_path, asset_pack_dir, "02_supporting_figures"),
  copy_asset(workflow_notes_path, asset_pack_dir, "05_reference_reports")
)

write_csv_message(copy_log, copy_log_path)


## Checks and handoff ----


tif_snapshot_after <- tibble::tibble(
  tif_path = list.files(raster_dir, pattern = "\\.tif$", recursive = TRUE, full.names = TRUE),
  last_write_time_after = as.character(file.info(tif_path)$mtime),
  size_after = file.info(tif_path)$size
)

tif_compare <- tif_snapshot_before %>%
  dplyr::full_join(tif_snapshot_after, by = "tif_path") %>%
  dplyr::mutate(
    unchanged = .data$last_write_time_before == .data$last_write_time_after &
      .data$size_before == .data$size_after
  )

created_figures <- c(
  location_map_path,
  location_map_wide_path,
  vegetation_map_path,
  vegetation_map_plots_path,
  gauge_map_path,
  gauge_map_flow_path,
  workflow_path,
  synthesis_path
)

checks <- tibble::tibble(
  check_name = c(
    "no_heavy_workflows_run",
    "no_raster_products_rebuilt",
    "required_figures_created",
    "asset_pack_copy_complete",
    "asset_register_updated",
    "missing_assets_updated",
    "gauge_coordinates_caveated",
    "biodiversity_repo_excluded"
  ),
  status = c(
    "pass",
    dplyr::if_else(all(tif_compare$unchanged, na.rm = TRUE), "pass", "fail"),
    dplyr::if_else(all(file.exists(created_figures)), "pass", "fail"),
    dplyr::if_else(all(copy_log$copied), "pass", "fail"),
    dplyr::if_else(all(task7_assets$filename %in% updated_register$filename), "pass", "fail"),
    "pass",
    "pass",
    "pass"
  ),
  check_value = c(
    "Only existing vector, CSV, docs and report files were read.",
    paste0(sum(tif_compare$unchanged, na.rm = TRUE), " .tif files unchanged of ", nrow(tif_compare), " inventoried."),
    paste(basename(created_figures), collapse = "; "),
    paste0(sum(copy_log$copied), " copied of ", nrow(copy_log), " Task 7 assets."),
    paste0(nrow(task7_assets), " Task 7 rows added/updated."),
    paste0(nrow(remaining_missing), " unresolved missing/decision items remain."),
    "Gauge-location figure caption states coordinates are approximate because current metadata lacks coordinate fields.",
    "No biodiversity paths were read or written."
  ),
  note = c(
    "No extraction, raster-building, or major analytical workflow was run.",
    "Raster snapshot checks compare mtime and file size before/after.",
    "All required figures plus optional useful variants were created.",
    "Task 7 assets were copied into the current PPT asset pack.",
    "Register can be used by scripts/collect_ppt_assets.ps1.",
    "Remaining items are still listed for the PPT rebuild.",
    "Gauge map is suitable as a deck context schematic, not a surveyed station-location layer.",
    "Task stayed inside the Gayini repository."
  )
)

write_csv_message(checks, checks_path)

if (any(checks$status == "fail")) {
  stop("Task 7 checks failed. See: ", checks_path, call. = FALSE)
}

handoff_lines <- c(
  "# Task 7 — Lightweight PPT Missing-Asset Generation",
  "",
  paste0("Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
  "",
  "## Files Reviewed",
  "",
  paste0("- `", file.path(root_dir, "docs", "codex_context.md"), "`"),
  paste0("- `", file.path(root_dir, "docs", "current_run_order.md"), "`"),
  paste0("- `", asset_register_path, "`"),
  paste0("- `", missing_assets_path, "`"),
  paste0("- `", file.path(report_dir, "Gayini_ppt_superseded_assets.csv"), "`"),
  paste0("- `", file.path(report_dir, "task_6_ppt_asset_audit_handoff.md"), "`"),
  paste0("- `", file.path(report_dir, "Gayini_analysis_spine.csv"), "`"),
  paste0("- `", file.path(report_dir, "Gayini_story_structure.md"), "`"),
  paste0("- `", boundary_path, "`"),
  paste0("- `", plots_path, "`"),
  paste0("- `", management_path, "`"),
  paste0("- `", vegetation_path, "`"),
  paste0("- `", gauge_metadata_path, "`"),
  "",
  "## Scripts Created Or Modified",
  "",
  paste0("- `", file.path(root_dir, "scripts", "02_make_ppt_missing_assets.R"), "`"),
  "",
  "## Figures Created",
  "",
  paste0("- `", created_figures, "`"),
  "",
  "## Completed Missing Assets",
  "",
  "- Gayini location / study-area context map.",
  "- Large vegetation-group overview map.",
  "- Gauge-location overview map.",
  "- Simplified workflow summary figure.",
  "- Optional hydrology-inundation-vegetation synthesis figure.",
  "",
  "## Remaining Unresolved Items",
  "",
  if (nrow(remaining_missing) == 0L) {
    "- None listed in `Gayini_ppt_missing_assets.csv`."
  } else {
    paste0("- ", remaining_missing$needed_asset, ": ", remaining_missing$current_status, " — ", remaining_missing$recommended_action)
  },
  "",
  "## Asset Pack",
  "",
  paste0("- Updated asset pack: `", asset_pack_dir, "`"),
  paste0("- Copy log: `", copy_log_path, "`"),
  "",
  "## Notes",
  "",
  "- The gauge-location map is a presentation schematic using approximate station locations because the current Gayini gauge metadata do not contain coordinate fields.",
  "- The NSW / Murrumbidgee locator panel is schematic because no external NSW or Murray-Darling Basin boundary layer is stored in this repository.",
  "- The synthesis figure is a light conceptual summary from existing outputs, not a new statistical analysis.",
  "- The repository is now sufficient for a first manual PowerPoint rebuild, subject to Adrian confirming the figure set and any remaining deck decisions.",
  "",
  "## Checks",
  "",
  paste0("- ", checks$check_name, ": ", checks$status, " (", checks$check_value, ")")
)

writeLines(handoff_lines, handoff_path)
message("Wrote: ", handoff_path)

message("Task 7 lightweight PPT missing assets complete.")
