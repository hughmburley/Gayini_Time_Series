## 07h plot annual inundation panel pages ----

root_dir <- Sys.getenv("GAYINI_ROOT", "D:/Github_repos/Gayini")
SHOW_VALID_ANY_PANELS <- FALSE

required_packages <- c('sf', 'terra', 'dplyr', 'tidyr', 'readr', 'stringr', 'purrr', 'ggplot2')
missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]


if (length(missing_packages) > 0) {

  stop('Missing required packages: ', paste(missing_packages, collapse = ', '), call. = FALSE)

}

library(sf)
library(terra)
library(dplyr)
library(tidyr)
library(readr)
library(stringr)
library(purrr)
library(ggplot2)


source(file.path(root_dir, 'R', 'inundation_pre_post_plotting_functions.R'))


annual_dir <- file.path(root_dir, 'Output', 'rasters', 'inundation_pre_post', 'annual')

obs_density_path <- gayini_find_first_existing(c(
  file.path(root_dir, 'Output', 'diagnostics', '07e_pre_post_inundation_observation_density_by_year.csv')))

plots_path <- gayini_find_first_existing(c(
  file.path(root_dir, 'Input', 'shapefiles', 'gayini_hectare_plots.shp'),
  file.path(root_dir, 'data_intermediate', 'spatial', 'plots_clean.gpkg')))

boundary_path <- gayini_find_first_existing(c(
  file.path(root_dir, 'Input', 'shapefiles', 'gayini_boundary.shp'),
  file.path(root_dir, 'data_intermediate', 'spatial', 'boundary_clean.gpkg')
))
zones_path <- gayini_find_first_existing(c(
  file.path(root_dir, 'Input', 'shapefiles', 'CA0561_ManagementZones.shp')
))

fig_dir <- file.path(root_dir, 'Output', 'figures', '07h_annual_inundation_panels')
dir.create(fig_dir, recursive = TRUE, showWarnings = FALSE)

annual_files <- list.files(annual_dir, pattern = '^annual_inundated_any_.*\\.tif$', full.names = TRUE)
if (length(annual_files) == 0) stop('No annual_inundated_any rasters found in: ', annual_dir, call. = FALSE)

annual_tbl <- tibble::tibble(file_path = annual_files) |>
  dplyr::mutate(file_name = basename(.data$file_path)) |>
  tidyr::extract(.data$file_name, into = c('prefix', 'period', 'year'), regex = '^(annual_inundated_any)_(pre_conservation|post_conservation)__([0-9]{4})\\.tif$', remove = FALSE) |>
  dplyr::mutate(analysis_year = as.integer(.data$year), period_year = paste0(.data$period, '__', .data$analysis_year)) |>
  dplyr::arrange(.data$period, .data$analysis_year)

if (!is.na(obs_density_path)) {
  density_df <- readr::read_csv(obs_density_path, show_col_types = FALSE) |>
    dplyr::select(.data$period_year, .data$n_rasters_total, .data$observation_density_class)
  annual_tbl <- annual_tbl |>
    dplyr::left_join(density_df, by = 'period_year')
}

plots_sf <- gayini_read_optional_sf(plots_path)
boundary_sf <- gayini_read_optional_sf(boundary_path)
zones_sf <- gayini_read_optional_sf(zones_path)

make_one_period_panel <- function(period_value) {
  use_tbl <- annual_tbl |>
    dplyr::filter(.data$period == !!period_value)

  panel_df <- purrr::map_dfr(seq_len(nrow(use_tbl)), function(i) {
    r <- terra::rast(use_tbl$file_path[[i]])
    df <- gayini_raster_to_df(r, 'annual_inundated_any') |>
      dplyr::mutate(
        period_year = use_tbl$period_year[[i]],
        facet_label = paste0('WY', use_tbl$analysis_year[[i]], '\n',
                             'rasters = ', use_tbl$n_rasters_total[[i]] %||% NA, '\n',
                             use_tbl$observation_density_class[[i]] %||% 'density_unknown')
      )
    df
  })

  ref_r <- terra::rast(use_tbl$file_path[[1]])
  target_crs <- sf::st_crs(terra::crs(ref_r))
  boundary_r <- gayini_safe_sf_transform(boundary_sf, target_crs)
  plots_r <- gayini_safe_sf_transform(plots_sf, target_crs)
  zones_r <- gayini_safe_sf_transform(zones_sf, target_crs)

  p <- ggplot() +
    geom_raster(data = panel_df, aes(x = x, y = y, fill = factor(annual_inundated_any))) +
    scale_fill_manual(values = c('0' = '#f0e7d6', '1' = '#3182bd'),
                      na.value = 'grey92', name = 'Annual\ninundation', labels = c('0' = 'No', '1' = 'Yes')) +
    {if (!is.null(zones_r)) geom_sf(data = zones_r, fill = NA, colour = 'grey65', linewidth = 0.2)} +
    {if (!is.null(boundary_r)) geom_sf(data = boundary_r, fill = NA, colour = 'black', linewidth = 0.3)} +
    {if (!is.null(plots_r)) geom_sf(data = plots_r, fill = NA, colour = 'black', linewidth = 0.1)} +
    facet_wrap(~facet_label, ncol = 3) +
    coord_sf(expand = FALSE) +
    labs(
      title = paste0(ifelse(period_value == 'pre_conservation', 'Pre-conservation',
                            'Post-conservation'), ' annual inundation rasters'),
      subtitle = 'Annual inundated_any layers. Titles show water year and the number of contributing rasters.'
    ) +
    gayini_theme_map()

  out_path <- file.path(fig_dir, paste0('07h_annual_inundated_any_', period_value, '_panel.png'))
  ggplot2::ggsave(out_path, plot = p, width = 12, height = 8.5, dpi = 240)
}

make_one_period_panel('pre_conservation')
make_one_period_panel('post_conservation')

message('07h complete. Wrote outputs to: ', fig_dir)
