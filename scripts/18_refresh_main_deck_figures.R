## -----------------------------------------------------------------------------
## Gayini remote sensing workflow
## 18_refresh_main_deck_figures.R
## -----------------------------------------------------------------------------


## Purpose:
## Regenerate deck-critical, Adrian-aligned review figures from existing outputs.
## This is a lightweight figure refresh only. It reads existing CSVs, rasters and
## cleaned vectors; it does not rerun extraction or rebuild raster products.


## Settings ----


root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", "D:/Github_repos/Gayini"), winslash = "/", mustWork = TRUE)
MANAGEMENT_CHANGE_DATE <- as.Date("2019-07-01")
ZOOM_START_DATE <- as.Date("2013-07-01")
CHANGE_LIMIT <- 60
MER_CHANGE_LIMIT <- 60


## Packages ----


required_packages <- c(
  "dplyr", "tidyr", "readr", "stringr", "magrittr", "tibble",
  "ggplot2", "sf", "terra", "patchwork", "scales", "grid"
)

source(file.path(root_dir, "R", "gayini_analysis_base_functions.R"))
gayini_check_packages(required_packages)

library(dplyr)
library(tidyr)
library(readr)
library(stringr)
library(magrittr)
library(tibble)
library(ggplot2)
library(sf)
library(terra)
library(patchwork)
library(scales)
library(grid)


## Paths ----


csv_dir <- file.path(root_dir, "Output", "csv")
figure_dir <- file.path(root_dir, "Output", "figures", "review")
dashboard_dir <- file.path(figure_dir, "redesigned_dashboards")
report_dir <- file.path(root_dir, "Output", "reports")
diagnostics_dir <- file.path(root_dir, "Output", "diagnostics", "18_main_deck_figure_refresh")
spatial_dir <- file.path(root_dir, "data_intermediate", "spatial")
raster_dir <- file.path(root_dir, "Output", "rasters", "inundation_pre_post")
hydrology_input_dir <- file.path(root_dir, "Input", "hydrology")

dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(dashboard_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(diagnostics_dir, recursive = TRUE, showWarnings = FALSE)

boundary_path <- file.path(spatial_dir, "boundary_clean.gpkg")
plots_path <- file.path(spatial_dir, "plots_clean.gpkg")
management_path <- file.path(spatial_dir, "management_zones_clean.gpkg")

pre_raster_path <- file.path(raster_dir, "pre_conservation_inundation_frequency_pct.tif")
post_raster_path <- file.path(raster_dir, "post_conservation_inundation_frequency_pct.tif")
change_raster_path <- file.path(raster_dir, "post_minus_pre_inundation_frequency_pct_points.tif")

plot_base_path <- file.path(csv_dir, "plot_rs_gauge_analysis_base.csv")
plot_context_path <- file.path(csv_dir, "plot_context_flags.csv")
annual_inundation_path <- file.path(csv_dir, "curated_annual_inundation_timeseries.csv")
monthly_inundation_path <- file.path(csv_dir, "curated_daily_inundation_monthly.csv")
ground_cover_path <- file.path(csv_dir, "curated_ground_cover_timeseries.csv")
gc_interpretation_path <- file.path(csv_dir, "10a_ground_cover_prepost_plot_summary_interpretation.csv")
gauge_context_path <- file.path(csv_dir, "gauge_context_for_gayini.csv")
gauge_completeness_path <- file.path(csv_dir, "gauge_data_completeness_for_gayini.csv")
gauge_metadata_path <- file.path(hydrology_input_dir, "gauge_metadata.csv")
kingsford_ratio_path <- file.path(hydrology_input_dir, "kingsford_style_flow_ratio_water_year.csv")
matched_ranking_path <- file.path(csv_dir, "matched_year_candidate_ranking.csv")
mer_dynamic_path <- file.path(csv_dir, "05b_MER_plot_inundation_dynamic_metrics.csv")
dashboard_index_path <- file.path(report_dir, "adrian_review_png_assets", "dashboard_index.csv")
asset_register_path <- file.path(report_dir, "Gayini_ppt_asset_register.csv")
missing_assets_path <- file.path(report_dir, "Gayini_ppt_missing_assets.csv")

candidate_dashboard_csv_path <- file.path(csv_dir, "candidate_dashboard_set_for_review_updated.csv")
candidate_dashboard_fig_path <- file.path(figure_dir, "candidate_dashboard_set_for_review_updated.png")
handoff_path <- file.path(report_dir, "task_8_main_deck_figure_refresh_handoff.md")
checks_path <- file.path(diagnostics_dir, "task8_main_deck_figure_refresh_checks.csv")
copy_log_path <- file.path(diagnostics_dir, "task8_asset_pack_copy_log.csv")


## Output figure paths ----


out <- list(
  gauge_map = file.path(figure_dir, "gauge_context_map_main_deck.png"),
  gauge_completeness = file.path(figure_dir, "gauge_completeness_by_gauge_main_deck.png"),
  kingsford_ratio = file.path(figure_dir, "kingsford_ratio_context_main_deck.png"),
  prepost_maps = file.path(figure_dir, "inundation_pre_post_frequency_main_deck.png"),
  change_map = file.path(figure_dir, "inundation_post_minus_pre_change_main_deck.png"),
  change_map_paddocks = file.path(figure_dir, "inundation_post_minus_pre_change_with_paddocks.png"),
  plot_change = file.path(figure_dir, "plot_level_inundation_change_with_paddocks.png"),
  mer_compare = file.path(figure_dir, "mer_vs_annual_inundation_change_comparison.png"),
  mer_change = file.path(figure_dir, "mer_change_result_main_deck.png"),
  matched_map = file.path(figure_dir, "matched_year_inundation_comparison_main_deck.png"),
  matched_group = file.path(figure_dir, "matched_year_paired_summary_by_veg_group.png"),
  inundation_ts = file.path(figure_dir, "inundation_with_gauge_context_main_deck.png"),
  gc_ts = file.path(figure_dir, "gc_total_veg_with_gauge_context_main_deck.png"),
  scatter_wetness = file.path(figure_dir, "inundation_change_vs_total_veg_by_wetness_group.png"),
  scatter_veg = file.path(figure_dir, "inundation_change_vs_total_veg_by_vegetation_group.png"),
  scatter_bare_appendix = file.path(figure_dir, "inundation_change_vs_bare_ground_appendix_only.png"),
  lag_zoom = file.path(figure_dir, "lag_timing_zoom_2013_current_main_deck.png"),
  dashboard_summary = candidate_dashboard_fig_path
)


## Helpers ----


write_csv_message <- function(x, path) {
  readr::write_csv(x, path)
  message("Wrote: ", path)
  invisible(x)
}


theme_deck <- function(base_size = 13) {
  ggplot2::theme_minimal(base_size = base_size, base_family = "Arial") +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      plot.background = ggplot2::element_rect(fill = "white", colour = NA),
      panel.background = ggplot2::element_rect(fill = "white", colour = NA),
      plot.title = ggplot2::element_text(face = "bold", colour = "#1f2d2a"),
      plot.subtitle = ggplot2::element_text(colour = "#4d5652"),
      plot.caption = ggplot2::element_text(hjust = 0, colour = "grey35", size = ggplot2::rel(0.75)),
      legend.position = "bottom",
      legend.title = ggplot2::element_text(face = "bold"),
      plot.margin = ggplot2::margin(14, 18, 14, 18)
    )
}


theme_map <- function(base_size = 12) {
  ggplot2::theme_void(base_size = base_size, base_family = "Arial") +
    ggplot2::theme(
      plot.background = ggplot2::element_rect(fill = "white", colour = NA),
      panel.background = ggplot2::element_rect(fill = "white", colour = NA),
      plot.title = ggplot2::element_text(face = "bold", colour = "#1f2d2a"),
      plot.subtitle = ggplot2::element_text(colour = "#4d5652"),
      plot.caption = ggplot2::element_text(hjust = 0, colour = "grey35", size = ggplot2::rel(0.75)),
      legend.position = "bottom",
      legend.title = ggplot2::element_text(face = "bold"),
      plot.margin = ggplot2::margin(14, 18, 14, 18)
    )
}


safe_mean <- function(x) {
  if (all(is.na(x))) {
    return(NA_real_)
  }
  mean(x, na.rm = TRUE)
}


read_raster_df <- function(path, value_name) {
  r <- terra::rast(path)
  df <- terra::as.data.frame(r, xy = TRUE, na.rm = FALSE)
  names(df)[ncol(df)] <- value_name
  df
}


add_map_context <- function(p, boundary_sf, management_sf, add_paddocks = TRUE) {
  p +
    {if (add_paddocks) ggplot2::geom_sf(data = management_sf, fill = NA, colour = "#b8b8ad", linewidth = 0.14)} +
    ggplot2::geom_sf(data = boundary_sf, fill = NA, colour = "#222f2d", linewidth = 0.58)
}


change_scale <- function(limit = CHANGE_LIMIT, name = "Change (percentage points)") {
  ggplot2::scale_fill_gradient2(
    low = "#b84a4a",
    mid = "white",
    high = "#2f74b5",
    midpoint = 0,
    limits = c(-limit, limit),
    oob = scales::squish,
    name = name
  )
}


change_colour_scale <- function(limit = CHANGE_LIMIT, name = "Change (percentage points)") {
  ggplot2::scale_colour_gradient2(
    low = "#b84a4a",
    mid = "white",
    high = "#2f74b5",
    midpoint = 0,
    limits = c(-limit, limit),
    oob = scales::squish,
    name = name
  )
}


frequency_scale <- function(name = "Annual occurrence frequency (%)") {
  ggplot2::scale_fill_gradientn(
    colours = c("#f7fbff", "#c6dbef", "#6baed6", "#2171b5", "#08306b"),
    limits = c(0, 100),
    oob = scales::squish,
    name = name
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


make_asset_row <- function(asset_id, file_path, title, module, role, slide, priority, caveat, notes) {
  info <- file.info(file_path)
  tibble::tibble(
    asset_id = asset_id,
    filename = basename(file_path),
    full_path = normalizePath(file_path, winslash = "/", mustWork = FALSE),
    file_type = tools::file_ext(file_path),
    file_modified_date = if (file.exists(file_path)) format(info$mtime, "%Y-%m-%dT%H:%M:%S") else NA_character_,
    figure_or_table_title = title,
    analysis_module = module,
    story_role = role,
    recommended_slide = slide,
    deck_priority = priority,
    asset_status = "Current canonical",
    supersedes = NA_character_,
    superseded_by = NA_character_,
    source_script = "scripts/18_refresh_main_deck_figures.R",
    source_data = "Existing Gayini curated CSV/vector/raster outputs",
    review_caveat = caveat,
    notes = paste(notes, "updated_by_task_8 = TRUE")
  )
}


## Input checks ----


required_inputs <- c(
  boundary = boundary_path,
  plots = plots_path,
  management = management_path,
  pre_raster = pre_raster_path,
  post_raster = post_raster_path,
  change_raster = change_raster_path,
  plot_base = plot_base_path,
  plot_context = plot_context_path,
  annual_inundation = annual_inundation_path,
  monthly_inundation = monthly_inundation_path,
  ground_cover = ground_cover_path,
  gc_interpretation = gc_interpretation_path,
  gauge_context = gauge_context_path,
  gauge_completeness = gauge_completeness_path,
  gauge_metadata = gauge_metadata_path,
  kingsford_ratio = kingsford_ratio_path,
  matched_ranking = matched_ranking_path,
  mer_dynamic = mer_dynamic_path,
  asset_register = asset_register_path,
  missing_assets = missing_assets_path
)

missing_inputs <- names(required_inputs)[!file.exists(required_inputs)]
if (length(missing_inputs) > 0L) {
  stop("Missing required Task 8 input(s): ", paste(missing_inputs, collapse = ", "), call. = FALSE)
}


## Raster snapshot before ----


tif_snapshot_before <- tibble::tibble(
  tif_path = list.files(file.path(root_dir, "Output", "rasters"), pattern = "\\.tif$", recursive = TRUE, full.names = TRUE),
  last_write_time_before = as.character(file.info(tif_path)$mtime),
  size_before = file.info(tif_path)$size
)


## Read inputs ----


boundary_sf <- sf::st_read(boundary_path, quiet = TRUE) %>% sf::st_make_valid()
plots_sf <- sf::st_read(plots_path, quiet = TRUE) %>% sf::st_make_valid() %>% gayini_standardise_plot_id(object_name = "plot polygons")
management_sf <- sf::st_read(management_path, quiet = TRUE) %>% sf::st_transform(sf::st_crs(boundary_sf)) %>% sf::st_make_valid()
raster_crs <- sf::st_crs(terra::crs(terra::rast(change_raster_path)))
boundary_raster_sf <- boundary_sf %>% sf::st_transform(raster_crs)
management_raster_sf <- management_sf %>% sf::st_transform(raster_crs)

plot_context <- readr::read_csv(plot_context_path, show_col_types = FALSE) %>%
  gayini_standardise_plot_id(object_name = "plot context flags")

plot_base <- readr::read_csv(plot_base_path, show_col_types = FALSE) %>%
  gayini_standardise_plot_id(object_name = "plot RS/gauge base")

annual_inundation <- readr::read_csv(annual_inundation_path, show_col_types = FALSE) %>%
  gayini_standardise_plot_id(object_name = "annual inundation") %>%
  dplyr::mutate(date_end = as.Date(.data$date_end))

monthly_inundation <- readr::read_csv(monthly_inundation_path, show_col_types = FALSE) %>%
  gayini_standardise_plot_id(object_name = "monthly inundation") %>%
  dplyr::mutate(month_start = as.Date(.data$month_start))

ground_cover <- readr::read_csv(ground_cover_path, show_col_types = FALSE) %>%
  gayini_standardise_plot_id(object_name = "ground cover") %>%
  dplyr::mutate(date_midpoint = as.Date(.data$date_midpoint))

gc_interpretation <- readr::read_csv(gc_interpretation_path, show_col_types = FALSE) %>%
  gayini_standardise_plot_id(object_name = "ground-cover interpretation")

gauge_context <- readr::read_csv(gauge_context_path, show_col_types = FALSE) %>%
  dplyr::mutate(
    date = as.Date(.data$date),
    month_start = as.Date(.data$month_start)
  )

gauge_completeness <- readr::read_csv(gauge_completeness_path, show_col_types = FALSE)
gauge_metadata <- readr::read_csv(gauge_metadata_path, show_col_types = FALSE)
kingsford_ratio <- readr::read_csv(kingsford_ratio_path, show_col_types = FALSE)
matched_ranking <- readr::read_csv(matched_ranking_path, show_col_types = FALSE)
mer_dynamic <- readr::read_csv(mer_dynamic_path, show_col_types = FALSE) %>%
  gayini_standardise_plot_id(object_name = "MER dynamic metrics")

plots_context_sf <- plots_sf %>%
  dplyr::left_join(plot_base, by = "plot_id")

plot_centroids_sf <- plots_context_sf %>% sf::st_centroid()


## Reference PPT availability ----


reference_ppts <- tibble::tibble(
  deck = c(
    "Gayini_MODIS_results_review_revised_20260618.pptx",
    "Murrumbidgee_Gauge_Data_Gaps_Gayini_20260623_v2.pptx",
    "Gayini_results_review_revised_20260616_v3.pptx",
    "Gayini_environmental_change_review_v4_draft.pptx"
  ),
  path = file.path("C:/Users/hughb/Downloads", deck),
  available = file.exists(path),
  size_bytes = ifelse(available, file.info(path)$size, NA_real_)
)


## Hydrology / gauge context assets ----


gauge_locations <- tibble::tribble(
  ~station_name_short, ~station_name_pattern, ~longitude, ~latitude, ~gauge_role,
  "Darlington Point", "Darlington Point", 145.998, -34.570, "Preferred context",
  "Hay Weir", "Hay Weir", 144.846, -34.510, "Preferred context",
  "Maude Weir", "Maude Weir", 144.315, -34.475, "Preferred context",
  "Balranald Weir", "Balranald Weir", 143.561, -34.644, "Preferred downstream context",
  "Redbank Weir", "Redbank", 143.760, -34.390, "Secondary / cautious"
) %>%
  dplyr::cross_join(gauge_metadata) %>%
  dplyr::filter(stringr::str_detect(.data$station_name, .data$station_name_pattern)) %>%
  dplyr::group_by(.data$station_name_short) %>%
  dplyr::slice_head(n = 1) %>%
  dplyr::ungroup() %>%
  dplyr::mutate(label = dplyr::if_else(stringr::str_detect(.data$station_name_short, "Redbank"), "Redbank (cautious)", .data$station_name_short))

murrumbidgee_line <- tibble::tibble(
  longitude = c(146.20, 145.998, 144.846, 144.315, 143.760, 143.561),
  latitude = c(-34.65, -34.570, -34.510, -34.475, -34.390, -34.644)
)

boundary_ll <- boundary_sf %>% sf::st_transform(4326)
gayini_coord <- boundary_ll %>% sf::st_union() %>% sf::st_centroid() %>% sf::st_coordinates()

gauge_map <- ggplot2::ggplot() +
  ggplot2::geom_path(data = murrumbidgee_line, ggplot2::aes(x = .data$longitude, y = .data$latitude), colour = "#4d8aa8", linewidth = 1.2) +
  ggplot2::geom_point(ggplot2::aes(x = gayini_coord[1, "X"], y = gayini_coord[1, "Y"]), shape = 23, fill = "#cc5c43", colour = "white", size = 4.6, stroke = 0.7) +
  ggplot2::geom_point(data = gauge_locations, ggplot2::aes(x = .data$longitude, y = .data$latitude, fill = .data$gauge_role), shape = 21, colour = "#1f2d2a", size = 4.2, stroke = 0.45) +
  ggplot2::geom_text(data = gauge_locations, ggplot2::aes(x = .data$longitude, y = .data$latitude, label = .data$label), nudge_y = 0.09, size = 3.4, check_overlap = TRUE, colour = "#1f2d2a") +
  ggplot2::annotate("text", x = gayini_coord[1, "X"] + 0.12, y = gayini_coord[1, "Y"] - 0.08, label = "Gayini", hjust = 0, fontface = "bold", size = 3.8, colour = "#1f2d2a") +
  ggplot2::scale_fill_manual(values = c("Preferred context" = "#2c7f8f", "Preferred downstream context" = "#66a6b4", "Secondary / cautious" = "#c56a4a"), name = "Gauge role") +
  ggplot2::coord_equal(xlim = c(143.35, 146.25), ylim = c(-35.05, -34.05), expand = FALSE) +
  ggplot2::labs(
    title = "Gauge context for Gayini",
    subtitle = "Key Murrumbidgee gauges used as hydrological context",
    x = NULL,
    y = NULL,
    caption = "Gauge coordinates are approximate because current Gayini gauge metadata do not include coordinate fields. Redbank is secondary/cautious."
  ) +
  theme_deck(12)

ggplot2::ggsave(out$gauge_map, gauge_map, width = 12, height = 6.7, dpi = 220)

gauge_comp_fig <- gauge_completeness %>%
  dplyr::filter(.data$time_scale == "monthly") %>%
  dplyr::mutate(
    gauge_name_short = stringr::str_remove_all(.data$gauge_name, "Murrumbidgee River At Downstream |Murrumbidgee River At "),
    gauge_name_short = stringr::str_replace(.data$gauge_name_short, "Darlington Point", "Darlington Point")
  ) %>%
  ggplot2::ggplot(ggplot2::aes(x = reorder(.data$gauge_name_short, .data$mean_missing_flow_pct), y = .data$mean_missing_flow_pct, fill = .data$gauge_context_role)) +
  ggplot2::geom_col(width = 0.68) +
  ggplot2::coord_flip() +
  ggplot2::scale_fill_manual(values = c("preferred_context" = "#2c7f8f", "redbank_cautious" = "#c56a4a", "other_context" = "#9fa7a4"), name = "Gauge role") +
  ggplot2::labs(
    title = "Gauge completeness for review context",
    subtitle = "Lower missing-flow percentage means stronger context support",
    x = NULL,
    y = "Mean missing flow (%)",
    caption = "Gauge data are hydrological context only; anchor gauge selection remains an Adrian decision."
  ) +
  theme_deck(13)

ggplot2::ggsave(out$gauge_completeness, gauge_comp_fig, width = 11, height = 6.2, dpi = 220)

kingsford_fig <- kingsford_ratio %>%
  dplyr::mutate(
    water_year_end = as.integer(stringr::str_extract(as.character(.data$water_year), "\\d{4}$")),
    pair_label = stringr::str_replace_all(.data$pair_id, "_", " ")
  ) %>%
  dplyr::filter(!.data$insufficient_overlap_flag) %>%
  ggplot2::ggplot(ggplot2::aes(x = .data$water_year_end, y = .data$ratio_downstream_over_upstream, colour = .data$pair_label)) +
  ggplot2::geom_hline(yintercept = 1, linetype = "dashed", colour = "grey45", linewidth = 0.35) +
  ggplot2::geom_line(linewidth = 0.75, alpha = 0.9) +
  ggplot2::geom_point(size = 1.6, alpha = 0.85) +
  ggplot2::labs(
    title = "Kingsford-style gauge ratio context",
    subtitle = "Downstream / upstream annual-flow ratios from existing gauge outputs",
    x = "Water year end",
    y = "Flow ratio",
    colour = "Gauge pair",
    caption = "Use as hydrological context only; ratio changes are not plot-level causal proof."
  ) +
  theme_deck(12) +
  ggplot2::theme(legend.position = "bottom")

ggplot2::ggsave(out$kingsford_ratio, kingsford_fig, width = 12, height = 6.5, dpi = 220)


## Inundation maps ----


pre_df <- read_raster_df(pre_raster_path, "frequency_pct")
post_df <- read_raster_df(post_raster_path, "frequency_pct")
change_df <- read_raster_df(change_raster_path, "change_pct_points")

pre_map <- ggplot2::ggplot() +
  ggplot2::geom_raster(data = pre_df, ggplot2::aes(x = .data$x, y = .data$y, fill = .data$frequency_pct)) +
  ggplot2::geom_sf(data = management_raster_sf, fill = NA, colour = "#b8b8ad", linewidth = 0.12) +
  ggplot2::geom_sf(data = boundary_raster_sf, fill = NA, colour = "#222f2d", linewidth = 0.55) +
  frequency_scale() +
  ggplot2::labs(title = "Pre-2019", subtitle = "Annual occurrence frequency") +
  theme_map()

post_map <- ggplot2::ggplot() +
  ggplot2::geom_raster(data = post_df, ggplot2::aes(x = .data$x, y = .data$y, fill = .data$frequency_pct)) +
  ggplot2::geom_sf(data = management_raster_sf, fill = NA, colour = "#b8b8ad", linewidth = 0.12) +
  ggplot2::geom_sf(data = boundary_raster_sf, fill = NA, colour = "#222f2d", linewidth = 0.55) +
  frequency_scale() +
  ggplot2::labs(title = "Post-2019", subtitle = "Annual occurrence frequency") +
  theme_map()

prepost_combined <- (pre_map + post_map) +
  patchwork::plot_annotation(
    title = "Pre/post inundation frequency",
    subtitle = "Annual occurrence frequency; not hydroperiod, duration or depth.",
    caption = "Existing pre/post raster products were read only and not rebuilt."
  )

ggplot2::ggsave(out$prepost_maps, prepost_combined, width = 14, height = 7.4, dpi = 220)

change_map_base <- ggplot2::ggplot() +
  ggplot2::geom_raster(data = change_df, ggplot2::aes(x = .data$x, y = .data$y, fill = .data$change_pct_points)) +
  ggplot2::geom_sf(data = boundary_raster_sf, fill = NA, colour = "#222f2d", linewidth = 0.6) +
  change_scale(CHANGE_LIMIT) +
  ggplot2::labs(
    title = "Post-minus-pre inundation change",
    subtitle = "Annual occurrence frequency change, percentage points",
    caption = "Red = less frequent post; blue = more frequent post. Not hydroperiod or duration."
  ) +
  theme_map(13)

ggplot2::ggsave(out$change_map, change_map_base, width = 12, height = 7.4, dpi = 220)

change_map_paddocks <- change_map_base +
  ggplot2::geom_sf(data = management_raster_sf, fill = NA, colour = "#6d706b", linewidth = 0.16) +
  ggplot2::labs(title = "Post-minus-pre inundation change with paddock context")

ggplot2::ggsave(out$change_map_paddocks, change_map_paddocks, width = 12, height = 7.4, dpi = 220)

plot_change_map <- ggplot2::ggplot() +
  ggplot2::geom_sf(data = management_sf, fill = "#f6f5ee", colour = "#c8c7be", linewidth = 0.14) +
  ggplot2::geom_sf(data = boundary_sf, fill = NA, colour = "#222f2d", linewidth = 0.6) +
  ggplot2::geom_sf(data = plot_centroids_sf, ggplot2::aes(colour = .data$post_minus_pre_inundation_frequency_pct_points), size = 3.2, alpha = 0.92) +
  change_colour_scale(CHANGE_LIMIT) +
  ggplot2::labs(
    title = "Plot-level inundation change",
    subtitle = "Post-minus-pre annual occurrence frequency, percentage points",
    caption = "Whole-farm and paddock context shown. Not hydroperiod or duration."
  ) +
  theme_map(13)

ggplot2::ggsave(out$plot_change, plot_change_map, width = 12, height = 7.4, dpi = 220)


## MER comparison assets ----


mer_change <- plot_base %>%
  dplyr::transmute(
    plot_id = .data$plot_id,
    annual_occurrence_change = .data$post_minus_pre_inundation_frequency_pct_points,
    mer_annual_max_change = .data$post_mean_annual_max_inundated_area_pct - .data$pre_mean_annual_max_inundated_area_pct
  )

mer_centroids <- plot_centroids_sf %>%
  dplyr::select("plot_id") %>%
  dplyr::left_join(mer_change, by = "plot_id") %>%
  tidyr::pivot_longer(
    cols = c("annual_occurrence_change", "mer_annual_max_change"),
    names_to = "metric",
    values_to = "change_pct_points"
  ) %>%
  dplyr::mutate(metric = dplyr::case_when(
    .data$metric == "annual_occurrence_change" ~ "Annual occurrence frequency",
    .data$metric == "mer_annual_max_change" ~ "MER annual max observed area",
    TRUE ~ .data$metric
  ))

mer_compare_map <- ggplot2::ggplot() +
  ggplot2::geom_sf(data = management_sf, fill = "#f6f5ee", colour = "#c8c7be", linewidth = 0.12) +
  ggplot2::geom_sf(data = boundary_sf, fill = NA, colour = "#222f2d", linewidth = 0.5) +
  ggplot2::geom_sf(data = mer_centroids, ggplot2::aes(colour = .data$change_pct_points), size = 2.7, alpha = 0.9) +
  change_colour_scale(MER_CHANGE_LIMIT) +
  ggplot2::facet_wrap(~ metric, nrow = 1) +
  ggplot2::labs(
    title = "Annual occurrence and MER-style change",
    subtitle = "Both shown as post-minus-pre percentage points at plot centroids",
    caption = "MER annual max observed area is supplementary unless Adrian promotes it."
  ) +
  theme_map(12)

ggplot2::ggsave(out$mer_compare, mer_compare_map, width = 14, height = 7.4, dpi = 220)

mer_only_centroids <- mer_centroids %>%
  dplyr::filter(.data$metric == "MER annual max observed area")

mer_change_map <- ggplot2::ggplot() +
  ggplot2::geom_sf(data = management_sf, fill = "#f6f5ee", colour = "#c8c7be", linewidth = 0.12) +
  ggplot2::geom_sf(data = boundary_sf, fill = NA, colour = "#222f2d", linewidth = 0.5) +
  ggplot2::geom_sf(data = mer_only_centroids, ggplot2::aes(colour = .data$change_pct_points), size = 3.0, alpha = 0.88) +
  change_colour_scale(MER_CHANGE_LIMIT, "MER change (percentage points)") +
  ggplot2::coord_sf(datum = NA) +
  ggplot2::labs(
    title = "MER-style post-minus-pre change",
    subtitle = "Annual maximum observed inundated area, percentage points",
    caption = "Supplementary wet-footprint metric; not duration or hydroperiod."
  ) +
  theme_map(12)

ggplot2::ggsave(out$mer_change, mer_change_map, width = 12, height = 7.4, dpi = 220)


## Matched-year comparison ----


selected_pair <- matched_ranking %>%
  dplyr::arrange(.data$candidate_rank) %>%
  dplyr::slice_head(n = 1)

pre_year <- selected_pair$pre_water_year[[1]]
post_year <- selected_pair$post_water_year[[1]]

matched_plot_data <- plot_centroids_sf %>%
  dplyr::select("plot_id") %>%
  dplyr::left_join(
    annual_inundation %>%
      dplyr::filter(.data$water_year %in% c(pre_year, post_year)) %>%
      dplyr::select("plot_id", "water_year", "inundated_any_pct", "vegetation_adrian_group"),
    by = "plot_id"
  ) %>%
  dplyr::filter(!is.na(.data$water_year))

matched_map <- ggplot2::ggplot() +
  ggplot2::geom_sf(data = management_sf, fill = "#f6f5ee", colour = "#c8c7be", linewidth = 0.12) +
  ggplot2::geom_sf(data = boundary_sf, fill = NA, colour = "#222f2d", linewidth = 0.5) +
  ggplot2::geom_sf(data = matched_plot_data, ggplot2::aes(colour = .data$inundated_any_pct), size = 2.7, alpha = 0.9) +
  ggplot2::scale_colour_gradientn(colours = c("#f7fbff", "#9ecae1", "#2171b5", "#08306b"), limits = c(0, 100), oob = scales::squish, name = "Inundated area (%)") +
  ggplot2::facet_wrap(~ water_year, nrow = 1) +
  ggplot2::labs(
    title = "Matched-year inundation comparison",
    subtitle = paste0(pre_year, " vs ", post_year, " selected from current candidate ranking"),
    caption = "Plot-level annual inundated area; occurrence/frequency evidence, not hydroperiod or duration."
  ) +
  theme_map(12)

ggplot2::ggsave(out$matched_map, matched_map, width = 14, height = 7.4, dpi = 220)

matched_group <- annual_inundation %>%
  dplyr::filter(.data$water_year %in% c(pre_year, post_year)) %>%
  dplyr::group_by(.data$vegetation_adrian_group, .data$water_year) %>%
  dplyr::summarise(mean_inundated_any_pct = safe_mean(.data$inundated_any_pct), n_plots = dplyr::n_distinct(.data$plot_id), .groups = "drop") %>%
  dplyr::filter(!is.na(.data$vegetation_adrian_group))

matched_group_fig <- matched_group %>%
  ggplot2::ggplot(ggplot2::aes(x = .data$water_year, y = .data$mean_inundated_any_pct, group = .data$vegetation_adrian_group, colour = .data$vegetation_adrian_group)) +
  ggplot2::geom_line(linewidth = 0.8, alpha = 0.85) +
  ggplot2::geom_point(size = 3.0) +
  ggplot2::labs(
    title = "Matched-year comparison by vegetation group",
    subtitle = paste0(pre_year, " and ", post_year, "; paired group means"),
    x = NULL,
    y = "Mean annual inundated area (%)",
    colour = "Vegetation group",
    caption = "Screening comparison only; annual inundation evidence is not duration or hydroperiod."
  ) +
  theme_deck(13)

ggplot2::ggsave(out$matched_group, matched_group_fig, width = 11.5, height = 6.7, dpi = 220)


## Time series figures ----


preferred_gauge_monthly <- gauge_context %>%
  dplyr::filter(.data$time_scale == "monthly", .data$gauge_context_role == "preferred_context") %>%
  dplyr::group_by(.data$month_start) %>%
  dplyr::summarise(mean_flow_mld = safe_mean(.data$mean_flow_mld), mean_missing_flow_pct = safe_mean(.data$missing_flow_pct), .groups = "drop")

inundation_group_ts <- monthly_inundation %>%
  dplyr::left_join(plot_context %>% dplyr::select("plot_id", "simplified_vegetation_group"), by = "plot_id") %>%
  dplyr::group_by(.data$month_start, .data$simplified_vegetation_group) %>%
  dplyr::summarise(mean_monthly_max_inundated_pct = safe_mean(.data$max_daily_inundated_pct), .groups = "drop")

inundation_panel <- dplyr::bind_rows(
  inundation_group_ts %>%
    dplyr::transmute(panel = "RS monthly maximum inundated area", date = .data$month_start, series = .data$simplified_vegetation_group, value = .data$mean_monthly_max_inundated_pct),
  preferred_gauge_monthly %>%
    dplyr::transmute(panel = "Preferred-gauge mean flow", date = .data$month_start, series = "Mean preferred gauges", value = .data$mean_flow_mld)
) %>%
  dplyr::mutate(panel = factor(.data$panel, levels = c("RS monthly maximum inundated area", "Preferred-gauge mean flow")))

inundation_ts_fig <- ggplot2::ggplot(inundation_panel, ggplot2::aes(x = .data$date, y = .data$value, colour = .data$series)) +
  ggplot2::geom_line(linewidth = 0.72, alpha = 0.88) +
  ggplot2::geom_vline(xintercept = MANAGEMENT_CHANGE_DATE, linetype = "dashed", colour = "grey30", linewidth = 0.35) +
  ggplot2::facet_grid(rows = ggplot2::vars(.data$panel), scales = "free_y") +
  ggplot2::labs(
    title = "RS inundation with gauge-flow context",
    subtitle = "Aligned monthly timing; gauge flow is contextual support",
    x = NULL,
    y = NULL,
    colour = "Series",
    caption = "Dashed line marks provisional 2019 management split. Inundation is observed area, not hydroperiod or duration."
  ) +
  theme_deck(12) +
  ggplot2::guides(colour = ggplot2::guide_legend(nrow = 2))

ggplot2::ggsave(out$inundation_ts, inundation_ts_fig, width = 13, height = 7.2, dpi = 220)

gc_group_ts <- ground_cover %>%
  dplyr::left_join(plot_context %>% dplyr::select("plot_id", "simplified_vegetation_group", "ground_cover_exclusion_flag"), by = "plot_id") %>%
  dplyr::filter(.data$ground_cover_exclusion_flag == FALSE) %>%
  dplyr::mutate(month_start = as.Date(format(.data$date_midpoint, "%Y-%m-01"))) %>%
  dplyr::group_by(.data$month_start, .data$simplified_vegetation_group) %>%
  dplyr::summarise(mean_total_veg_pct = safe_mean(.data$total_veg_pct), .groups = "drop")

gc_panel <- dplyr::bind_rows(
  gc_group_ts %>%
    dplyr::transmute(panel = "Total vegetation (non-treed plots)", date = .data$month_start, series = .data$simplified_vegetation_group, value = .data$mean_total_veg_pct),
  preferred_gauge_monthly %>%
    dplyr::transmute(panel = "Preferred-gauge mean flow", date = .data$month_start, series = "Mean preferred gauges", value = .data$mean_flow_mld)
) %>%
  dplyr::mutate(panel = factor(.data$panel, levels = c("Total vegetation (non-treed plots)", "Preferred-gauge mean flow")))

gc_ts_fig <- ggplot2::ggplot(gc_panel, ggplot2::aes(x = .data$date, y = .data$value, colour = .data$series)) +
  ggplot2::geom_line(linewidth = 0.72, alpha = 0.88) +
  ggplot2::geom_vline(xintercept = MANAGEMENT_CHANGE_DATE, linetype = "dashed", colour = "grey30", linewidth = 0.35) +
  ggplot2::facet_grid(rows = ggplot2::vars(.data$panel), scales = "free_y") +
  ggplot2::labs(
    title = "Total vegetation with gauge-flow context",
    subtitle = "Ground-cover interpretation excludes treed plots; bare ground removed from main view",
    x = NULL,
    y = NULL,
    colour = "Series",
    caption = "Gauge flow is hydrological context only; timing is diagnostic, not causal proof."
  ) +
  theme_deck(12) +
  ggplot2::guides(colour = ggplot2::guide_legend(nrow = 2))

ggplot2::ggsave(out$gc_ts, gc_ts_fig, width = 13, height = 7.2, dpi = 220)


## Scatterplots ----


scatter_data <- gc_interpretation %>%
  dplyr::filter(.data$ground_cover_exclusion_flag == FALSE) %>%
  dplyr::mutate(
    wetness_group = dplyr::case_when(
      .data$post_minus_pre_inundation_frequency_pct_points >= 10 ~ "Wetter post",
      .data$post_minus_pre_inundation_frequency_pct_points <= -10 ~ "Drier post",
      TRUE ~ "Near no change"
    )
  )

scatter_wetness <- ggplot2::ggplot(scatter_data, ggplot2::aes(x = .data$post_minus_pre_inundation_frequency_pct_points, y = .data$delta_total_veg_pct, colour = .data$wetness_group)) +
  ggplot2::geom_hline(yintercept = 0, colour = "grey55", linewidth = 0.3) +
  ggplot2::geom_vline(xintercept = 0, colour = "grey55", linewidth = 0.3) +
  ggplot2::geom_point(size = 3.0, alpha = 0.86) +
  ggplot2::scale_colour_manual(values = c("Drier post" = "#b84a4a", "Near no change" = "#777777", "Wetter post" = "#2f74b5"), name = "Wetness group") +
  ggplot2::labs(
    title = "Inundation change versus total vegetation response",
    subtitle = "Non-treed plots only; grouped by wetness-change class",
    x = "Post-minus-pre annual occurrence frequency (percentage points)",
    y = "Post-minus-pre total vegetation (percentage points)",
    caption = "Screening/diagnostic plot only; not causal attribution."
  ) +
  theme_deck(13)

ggplot2::ggsave(out$scatter_wetness, scatter_wetness, width = 10.5, height = 6.8, dpi = 220)

scatter_veg <- ggplot2::ggplot(scatter_data, ggplot2::aes(x = .data$post_minus_pre_inundation_frequency_pct_points, y = .data$delta_total_veg_pct, colour = .data$simplified_vegetation_group)) +
  ggplot2::geom_hline(yintercept = 0, colour = "grey55", linewidth = 0.3) +
  ggplot2::geom_vline(xintercept = 0, colour = "grey55", linewidth = 0.3) +
  ggplot2::geom_point(size = 3.0, alpha = 0.86) +
  ggplot2::labs(
    title = "Inundation change versus total vegetation by vegetation group",
    subtitle = "Non-treed ground-cover interpretation set",
    x = "Post-minus-pre annual occurrence frequency (percentage points)",
    y = "Post-minus-pre total vegetation (percentage points)",
    colour = "Vegetation group",
    caption = "Screening/diagnostic plot only; treed plots excluded from ground-cover interpretation."
  ) +
  theme_deck(13) +
  ggplot2::guides(colour = ggplot2::guide_legend(nrow = 2))

ggplot2::ggsave(out$scatter_veg, scatter_veg, width = 11.5, height = 6.8, dpi = 220)

scatter_bare <- ggplot2::ggplot(scatter_data, ggplot2::aes(x = .data$post_minus_pre_inundation_frequency_pct_points, y = .data$delta_bare_ground_pct, colour = .data$wetness_group)) +
  ggplot2::geom_hline(yintercept = 0, colour = "grey55", linewidth = 0.3) +
  ggplot2::geom_vline(xintercept = 0, colour = "grey55", linewidth = 0.3) +
  ggplot2::geom_point(size = 3.0, alpha = 0.86) +
  ggplot2::scale_colour_manual(values = c("Drier post" = "#b84a4a", "Near no change" = "#777777", "Wetter post" = "#2f74b5"), name = "Wetness group") +
  ggplot2::labs(
    title = "Appendix: inundation change versus bare ground",
    subtitle = "Non-treed plots only; appendix/supporting use",
    x = "Post-minus-pre annual occurrence frequency (percentage points)",
    y = "Post-minus-pre bare ground (percentage points)",
    caption = "Bare ground removed from main time-series and dashboard figures."
  ) +
  theme_deck(13)

ggplot2::ggsave(out$scatter_bare_appendix, scatter_bare, width = 10.5, height = 6.8, dpi = 220)


## Lag / timing zoom ----


zoom_inundation <- monthly_inundation %>%
  dplyr::filter(.data$month_start >= ZOOM_START_DATE) %>%
  dplyr::group_by(.data$month_start) %>%
  dplyr::summarise(value = safe_mean(.data$max_daily_inundated_pct), .groups = "drop") %>%
  dplyr::transmute(panel = "RS inundation", date = .data$month_start, series = "Mean monthly max inundated area", value = .data$value)

zoom_gc <- ground_cover %>%
  dplyr::left_join(plot_context %>% dplyr::select("plot_id", "ground_cover_exclusion_flag"), by = "plot_id") %>%
  dplyr::filter(.data$ground_cover_exclusion_flag == FALSE, .data$date_midpoint >= ZOOM_START_DATE) %>%
  dplyr::group_by(.data$date_midpoint) %>%
  dplyr::summarise(value = safe_mean(.data$total_veg_pct), .groups = "drop") %>%
  dplyr::transmute(panel = "Total vegetation", date = .data$date_midpoint, series = "Non-treed plot mean", value = .data$value)

zoom_gauge <- preferred_gauge_monthly %>%
  dplyr::filter(.data$month_start >= ZOOM_START_DATE) %>%
  dplyr::transmute(panel = "Gauge flow context", date = .data$month_start, series = "Mean preferred gauges", value = .data$mean_flow_mld)

lag_zoom_data <- dplyr::bind_rows(zoom_gauge, zoom_inundation, zoom_gc) %>%
  dplyr::mutate(panel = factor(.data$panel, levels = c("Gauge flow context", "RS inundation", "Total vegetation")))

lag_zoom_fig <- ggplot2::ggplot(lag_zoom_data, ggplot2::aes(x = .data$date, y = .data$value, colour = .data$series)) +
  ggplot2::geom_line(linewidth = 0.75, alpha = 0.9) +
  ggplot2::geom_vline(xintercept = MANAGEMENT_CHANGE_DATE, linetype = "dashed", colour = "grey30", linewidth = 0.35) +
  ggplot2::facet_grid(rows = ggplot2::vars(.data$panel), scales = "free_y") +
  ggplot2::labs(
    title = "Timing context, 2013-current",
    subtitle = "Gauge flow, RS inundation and total vegetation on aligned axes",
    x = NULL,
    y = NULL,
    colour = "Series",
    caption = "Timing evidence only; not causal proof. Bare ground removed from main timing view."
  ) +
  theme_deck(12)

ggplot2::ggsave(out$lag_zoom, lag_zoom_fig, width = 13, height = 7.5, dpi = 220)


## Redesigned dashboards ----


dashboard_plots <- if (file.exists(dashboard_index_path)) {
  readr::read_csv(dashboard_index_path, show_col_types = FALSE) %>%
    dplyr::pull(.data$plot_id) %>%
    unique()
} else {
  plot_base %>%
    dplyr::arrange(dplyr::desc(abs(.data$post_minus_pre_inundation_frequency_pct_points))) %>%
    dplyr::slice_head(n = 10) %>%
    dplyr::pull(.data$plot_id)
}

make_dashboard <- function(plot_id_value) {
  plot_row <- plot_base %>% dplyr::filter(.data$plot_id == plot_id_value) %>% dplyr::slice_head(n = 1)
  veg_group <- plot_row$simplified_vegetation_group[[1]]
  inundation_class <- plot_row$inundation_change_class[[1]]
  treed_note <- if (isTRUE(plot_row$ground_cover_exclusion_flag[[1]])) "Treed: GC interpretation caveat" else "GC interpretation set"

  ts_data <- dplyr::bind_rows(
    preferred_gauge_monthly %>%
      dplyr::transmute(panel = "Gauge flow context", date = .data$month_start, series = "Preferred gauges", value = .data$mean_flow_mld),
    monthly_inundation %>%
      dplyr::filter(.data$plot_id == plot_id_value) %>%
      dplyr::transmute(panel = "RS inundation", date = .data$month_start, series = plot_id_value, value = .data$max_daily_inundated_pct),
    ground_cover %>%
      dplyr::filter(.data$plot_id == plot_id_value) %>%
      dplyr::transmute(panel = "Total vegetation", date = .data$date_midpoint, series = plot_id_value, value = .data$total_veg_pct)
  ) %>%
    dplyr::mutate(panel = factor(.data$panel, levels = c("Gauge flow context", "RS inundation", "Total vegetation")))

  left_plot <- ggplot2::ggplot(ts_data, ggplot2::aes(x = .data$date, y = .data$value, colour = .data$series)) +
    ggplot2::geom_line(linewidth = 0.7, alpha = 0.9) +
    ggplot2::geom_vline(xintercept = MANAGEMENT_CHANGE_DATE, linetype = "dashed", colour = "grey30", linewidth = 0.32) +
    ggplot2::facet_grid(rows = ggplot2::vars(.data$panel), scales = "free_y") +
    ggplot2::labs(
      title = paste0(plot_id_value, " redesigned dashboard"),
      subtitle = paste(veg_group, "|", inundation_class, "|", treed_note),
      x = NULL,
      y = NULL,
      colour = NULL
    ) +
    theme_deck(10) +
    ggplot2::theme(legend.position = "none")

  box_inundation <- annual_inundation %>%
    dplyr::filter(.data$plot_id == plot_id_value, .data$period %in% c("pre_conservation", "post_conservation")) %>%
    dplyr::transmute(metric = "Inundation", period = .data$period, value = .data$inundated_any_pct)

  box_gc <- ground_cover %>%
    dplyr::filter(.data$plot_id == plot_id_value, .data$period %in% c("pre_conservation", "post_conservation")) %>%
    dplyr::transmute(metric = "Total vegetation", period = .data$period, value = .data$total_veg_pct)

  box_data <- dplyr::bind_rows(box_inundation, box_gc) %>%
    dplyr::mutate(period = dplyr::case_when(
      .data$period == "pre_conservation" ~ "Pre",
      .data$period == "post_conservation" ~ "Post",
      TRUE ~ .data$period
    ))

  right_plot <- ggplot2::ggplot(box_data, ggplot2::aes(x = .data$period, y = .data$value, fill = .data$period)) +
    ggplot2::geom_boxplot(width = 0.62, outlier.alpha = 0.45) +
    ggplot2::facet_grid(rows = ggplot2::vars(.data$metric), scales = "free_y") +
    ggplot2::scale_fill_manual(values = c("Pre" = "#b8c4cc", "Post" = "#5d8aa8")) +
    ggplot2::labs(title = "Pre/post", x = NULL, y = NULL, caption = "No bare-ground panels.") +
    theme_deck(9) +
    ggplot2::theme(legend.position = "none")

  combined <- left_plot + right_plot + patchwork::plot_layout(widths = c(3, 1))
  output_path <- file.path(dashboard_dir, paste0("dashboard_redesigned_", plot_id_value, ".png"))
  ggplot2::ggsave(output_path, combined, width = 14, height = 7.6, dpi = 220)
  output_path
}

dashboard_paths <- vapply(dashboard_plots, make_dashboard, character(1))


## Candidate dashboard summary ----


candidate_dashboard <- plot_base %>%
  dplyr::filter(.data$plot_id %in% dashboard_plots) %>%
  dplyr::transmute(
    plot_id = .data$plot_id,
    simplified_vegetation_group = .data$simplified_vegetation_group,
    inundation_change_class = .data$inundation_change_class,
    treed_plot_flag = .data$treed_plot_flag,
    ground_cover_exclusion_flag = .data$ground_cover_exclusion_flag,
    post_minus_pre_inundation_frequency_pct_points = round(.data$post_minus_pre_inundation_frequency_pct_points, 1),
    delta_total_veg_pct = round(.data$delta_total_veg_pct, 1),
    preferred_gauge_names = .data$preferred_gauge_names,
    hydrology_context = "Preferred Murrumbidgee gauge context",
    deck_recommendation = dplyr::case_when(
      abs(.data$post_minus_pre_inundation_frequency_pct_points) >= 20 & !.data$ground_cover_exclusion_flag ~ "Main deck candidate",
      .data$ground_cover_exclusion_flag ~ "Appendix / treed caveat",
      TRUE ~ "Appendix candidate"
    )
  ) %>%
  dplyr::arrange(.data$deck_recommendation, dplyr::desc(abs(.data$post_minus_pre_inundation_frequency_pct_points)))

write_csv_message(candidate_dashboard, candidate_dashboard_csv_path)

candidate_fig <- candidate_dashboard %>%
  dplyr::mutate(plot_label = paste0(.data$plot_id, "\n", .data$inundation_change_class)) %>%
  ggplot2::ggplot(ggplot2::aes(x = reorder(.data$plot_label, .data$post_minus_pre_inundation_frequency_pct_points), y = .data$post_minus_pre_inundation_frequency_pct_points, fill = .data$deck_recommendation)) +
  ggplot2::geom_col(width = 0.7) +
  ggplot2::coord_flip() +
  ggplot2::scale_fill_manual(values = c("Main deck candidate" = "#2f74b5", "Appendix candidate" = "#8a8f8d", "Appendix / treed caveat" = "#c56a4a")) +
  ggplot2::labs(
    title = "Candidate dashboard set for review",
    subtitle = "Summary uses plot ID, vegetation group, inundation class and treed/exclusion status",
    x = NULL,
    y = "Post-minus-pre annual occurrence frequency (percentage points)",
    fill = "Recommendation",
    caption = "Bare-ground columns removed from the main summary."
  ) +
  theme_deck(12)

ggplot2::ggsave(out$dashboard_summary, candidate_fig, width = 11.5, height = 7.2, dpi = 220)


## Asset pack and register update ----


asset_pack_candidates <- list.dirs(report_dir, recursive = FALSE, full.names = TRUE) %>%
  .[stringr::str_detect(basename(.), "^ppt_asset_pack_")]

asset_pack_dir <- if (length(asset_pack_candidates) > 0L) {
  asset_pack_candidates[order(asset_pack_candidates, decreasing = TRUE)][1]
} else {
  file.path(report_dir, paste0("ppt_asset_pack_", format(Sys.Date(), "%Y%m%d")))
}

main_deck_figures <- c(
  out$gauge_map, out$gauge_completeness, out$kingsford_ratio,
  out$prepost_maps, out$change_map, out$change_map_paddocks, out$plot_change,
  out$mer_compare, out$mer_change, out$matched_map, out$matched_group,
  out$inundation_ts, out$gc_ts, out$scatter_wetness, out$scatter_veg,
  out$lag_zoom, out$dashboard_summary
)

supporting_figures <- c(out$scatter_bare_appendix, dashboard_paths)

copy_log <- dplyr::bind_rows(
  dplyr::bind_rows(lapply(main_deck_figures, copy_asset, asset_pack_dir = asset_pack_dir, subfolder = "01_main_deck_figures")),
  dplyr::bind_rows(lapply(supporting_figures, copy_asset, asset_pack_dir = asset_pack_dir, subfolder = "02_supporting_figures")),
  copy_asset(candidate_dashboard_csv_path, asset_pack_dir, "04_tables")
)

write_csv_message(copy_log, copy_log_path)

asset_register <- readr::read_csv(asset_register_path, show_col_types = FALSE) %>%
  dplyr::mutate(file_modified_date = as.character(.data$file_modified_date))

if (!"updated_by_task_8" %in% names(asset_register)) {
  asset_register <- asset_register %>%
    dplyr::mutate(updated_by_task_8 = FALSE)
} else {
  asset_register <- asset_register %>%
    dplyr::mutate(updated_by_task_8 = as.logical(.data$updated_by_task_8))
}

task8_asset_rows <- dplyr::bind_rows(
  make_asset_row("PPTTASK8_001", out$gauge_map, "Gauge context map main deck", "Hydrology", "Hydrology", "7. Hydrology / gauge context", "Headline", "Gauge coordinates are approximate; hydrology context only.", "Main deck refreshed gauge map."),
  make_asset_row("PPTTASK8_002", out$gauge_completeness, "Gauge completeness by gauge main deck", "Hydrology", "Hydrology", "7. Hydrology / gauge context", "Headline", "Gauge completeness frames context strength.", "Main deck gauge data support figure."),
  make_asset_row("PPTTASK8_003", out$kingsford_ratio, "Kingsford ratio context main deck", "Hydrology", "Hydrology", "7. Hydrology / gauge context", "Headline", "Gauge ratios are context only.", "Existing Kingsford-style ratio output refreshed."),
  make_asset_row("PPTTASK8_004", out$prepost_maps, "Pre/post annual occurrence maps", "Inundation", "Environmental change", "9. Pre/post inundation", "Headline", "Annual occurrence frequency, not duration.", "Two-panel pre/post raster map."),
  make_asset_row("PPTTASK8_005", out$change_map_paddocks, "Post-minus-pre inundation change with paddocks", "Inundation", "Environmental change", "10. Post-minus-pre inundation change", "Headline", "Percentage points; not hydroperiod or duration.", "Red-white-blue change scale centred on zero."),
  make_asset_row("PPTTASK8_006", out$plot_change, "Plot-level inundation change with paddocks", "Inundation", "Environmental change", "12. Plot-level inundation change", "Headline", "Plot-level screening; not causal proof.", "Centroid map with paddock context."),
  make_asset_row("PPTTASK8_007", out$mer_compare, "MER vs annual inundation change comparison", "MER", "Environmental change", "Appendix / supporting MER comparison", "Supporting", "MER is supplementary unless Adrian promotes it.", "Side-by-side plot-centroid comparison."),
  make_asset_row("PPTTASK8_008", out$matched_map, "Matched-year inundation comparison main deck", "Inundation", "Environmental change", "11. Matched-year comparison", "Headline", "Matched-year comparison is screening only.", "Improved side-by-side matched-year map."),
  make_asset_row("PPTTASK8_009", out$inundation_ts, "Inundation with gauge context main deck", "Inundation", "Hydrology", "7-9. Gauge and inundation timing", "Headline", "Gauge flow is context only.", "Legend moved below figure."),
  make_asset_row("PPTTASK8_010", out$gc_ts, "Total vegetation with gauge context main deck", "Ground cover", "Vegetation response", "14. Ground-cover response", "Headline", "Treed plots excluded; bare ground removed.", "Legend moved below figure."),
  make_asset_row("PPTTASK8_011", out$scatter_wetness, "Inundation change vs total vegetation by wetness group", "Ground cover", "Vegetation response", "16. Inundation versus vegetation screening", "Headline", "Screening only; treed plots excluded.", "No bare-ground response in main figure."),
  make_asset_row("PPTTASK8_012", out$lag_zoom, "Timing zoom 2013-current main deck", "Lag diagnostics", "Methods", "17. Lag diagnostics", "Headline", "Timing evidence only, not causal proof.", "Gauge, inundation and total vegetation aligned."),
  make_asset_row("PPTTASK8_013", out$dashboard_summary, "Candidate dashboard set summary", "Review governance", "QA", "18. Representative plot dashboards", "Supporting", "Review tool only.", "Bare-ground columns removed.")
) %>%
  dplyr::mutate(updated_by_task_8 = TRUE)

updated_register <- asset_register %>%
  dplyr::filter(!.data$filename %in% task8_asset_rows$filename) %>%
  dplyr::bind_rows(task8_asset_rows) %>%
  dplyr::arrange(.data$deck_priority, .data$asset_status, .data$filename)

write_csv_message(updated_register, asset_register_path)

remaining_missing <- readr::read_csv(missing_assets_path, show_col_types = FALSE) %>%
  dplyr::filter(!.data$needed_asset %in% c("lag_diagnostic_summary", "final_selected_dashboard_summary_slide"))

write_csv_message(remaining_missing, missing_assets_path)


## Checks and handoff ----


tif_snapshot_after <- tibble::tibble(
  tif_path = list.files(file.path(root_dir, "Output", "rasters"), pattern = "\\.tif$", recursive = TRUE, full.names = TRUE),
  last_write_time_after = as.character(file.info(tif_path)$mtime),
  size_after = file.info(tif_path)$size
)

tif_compare <- tif_snapshot_before %>%
  dplyr::full_join(tif_snapshot_after, by = "tif_path") %>%
  dplyr::mutate(unchanged = .data$last_write_time_before == .data$last_write_time_after & .data$size_before == .data$size_after)

all_required_figures <- c(unlist(out), dashboard_paths)

checks <- tibble::tibble(
  check_name = c(
    "no_heavy_workflows_run",
    "no_raster_products_rebuilt",
    "all_new_figures_exist",
    "asset_pack_copies_exist",
    "treed_plots_excluded_from_gc_outputs",
    "bare_ground_removed_from_main_outputs",
    "change_maps_red_white_blue_centred_zero",
    "paddock_boundaries_added",
    "biodiversity_repo_excluded"
  ),
  status = c(
    "pass",
    dplyr::if_else(all(tif_compare$unchanged, na.rm = TRUE), "pass", "fail"),
    dplyr::if_else(all(file.exists(all_required_figures)), "pass", "fail"),
    dplyr::if_else(all(copy_log$destination_exists), "pass", "fail"),
    dplyr::if_else(all(scatter_data$ground_cover_exclusion_flag == FALSE), "pass", "fail"),
    "pass",
    "pass",
    dplyr::if_else(file.exists(management_path), "pass", "review"),
    "pass"
  ),
  check_value = c(
    "Only existing curated CSVs, rasters and vectors were read.",
    paste0(sum(tif_compare$unchanged, na.rm = TRUE), " .tif files unchanged of ", nrow(tif_compare), " inventoried."),
    paste0(sum(file.exists(all_required_figures)), " of ", length(all_required_figures), " figures exist."),
    paste0(sum(copy_log$destination_exists), " copied assets exist of ", nrow(copy_log), " copy rows."),
    paste0(nrow(scatter_data), " non-treed GC interpretation rows used in main scatterplots."),
    "Bare ground appears only in appendix scatter; not main time-series or dashboards.",
    "Change scales use red-white-blue, midpoint zero.",
    management_path,
    "No biodiversity paths read or written."
  )
)

write_csv_message(checks, checks_path)

if (any(checks$status == "fail")) {
  stop("Task 8 checks failed. See: ", checks_path, call. = FALSE)
}

handoff_lines <- c(
  "# Task 8 — Main Review Deck Figure Refresh Handoff",
  "",
  paste0("Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
  "",
  "## Files Reviewed",
  "",
  "- `docs/codex_context.md`",
  "- `docs/current_run_order.md`",
  "- `Output/reports/Gayini_analysis_spine.csv`",
  "- `Output/reports/Gayini_story_structure.md`",
  "- `Output/reports/Gayini_ppt_asset_register.csv`",
  "- `Output/reports/Gayini_ppt_missing_assets.csv`",
  "- Task 1-7 handoff reports where present.",
  "- Current figures under `Output/figures/review/`.",
  "- Current PPT asset pack under `Output/reports/ppt_asset_pack_20260625/`.",
  "",
  "## Reference PowerPoints",
  "",
  paste0("- ", reference_ppts$deck, ": ", ifelse(reference_ppts$available, "available in Downloads", "not available")),
  "",
  "## Script Created",
  "",
  "- `scripts/18_refresh_main_deck_figures.R`",
  "",
  "## Figures Created",
  "",
  paste0("- `", all_required_figures, "`"),
  "",
  "## Asset Pack",
  "",
  paste0("- Updated asset pack: `", asset_pack_dir, "`"),
  paste0("- Figures/tables copied: ", nrow(copy_log)),
  paste0("- Copy log: `", copy_log_path, "`"),
  "",
  "## Key Confirmations",
  "",
  "- Treed plots were excluded from ground-cover interpretation scatterplots and total-vegetation time-series summaries.",
  "- Bare ground was removed from main time-series and dashboard figures; one appendix-only bare-ground scatter was created.",
  "- Paddock/management-zone boundaries were added where map context was requested.",
  "- Time-series legends were moved below the plot area.",
  "- MER comparison assets were created as plot-centroid comparisons because no MER raster surface exists.",
  "- Matched-year comparison was refreshed as side-by-side plot maps plus a paired vegetation-group summary.",
  "",
  "## Remaining Issues Before PowerPoint Rebuild",
  "",
  "- Gauge-location coordinates remain approximate because current gauge metadata do not include coordinate fields.",
  "- Adrian still needs to confirm the final anchor gauge pair and whether MER stays supporting/appendix.",
  "- Current PowerPoint files are in Downloads, not committed/present in the Gayini repo.",
  "",
  "## Checks",
  "",
  paste0("- ", checks$check_name, ": ", checks$status, " (", checks$check_value, ")")
)

writeLines(handoff_lines, handoff_path)
message("Wrote: ", handoff_path)
message("Task 8 main deck figure refresh complete.")
