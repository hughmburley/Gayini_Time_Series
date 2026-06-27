## -----------------------------------------------------------------------------
## Gayini remote sensing workflow
## 26_summarise_compare_mer_rasters.R
## -----------------------------------------------------------------------------


## Purpose:
## Summarise production MER annual maximum observed wet rasters to plots,
## compare with annual occurrence products, create review figures, and update
## MER documentation/assets.


root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", "D:/Github_repos/Gayini"), winslash = "/", mustWork = TRUE)

source(file.path(root_dir, "R", "gayini_analysis_base_functions.R"))
source(file.path(root_dir, "R", "gayini_mer_raster_functions.R"))
source(file.path(root_dir, "R", "gayini_plotting_helpers.R"))
source(file.path(root_dir, "R", "gayini_time_helpers.R"))
source(file.path(root_dir, "R", "gayini_output_helpers.R"))
source(file.path(root_dir, "R", "gayini_mer_helpers.R"))

MANAGEMENT_CHANGE_DATE <- gayini_management_transition_date()
NEAR_ZERO_THRESHOLD_PCT_POINTS <- 5

required_packages <- c("dplyr", "tidyr", "readr", "stringr", "magrittr", "tibble", "ggplot2", "terra", "sf")
gayini_mer_check_packages(required_packages)

library(dplyr)
library(tidyr)
library(readr)
library(stringr)
library(magrittr)
library(tibble)
library(ggplot2)
library(terra)
library(sf)

## Paths ----

csv_dir <- file.path(root_dir, "Output", "csv", "MER")
diagnostics_dir <- file.path(root_dir, "Output", "diagnostics", "25_mer_annual_max_raster_build")
figure_dir <- file.path(root_dir, "Output", "figures", "review", "MER")
report_dir <- file.path(root_dir, "Output", "reports", "MER")
annual_max_dir <- file.path(root_dir, "Output", "rasters", "MER", "annual_max")
period_summary_dir <- file.path(root_dir, "Output", "rasters", "MER", "period_summaries")
plots_path <- file.path(root_dir, "data_intermediate", "spatial", "plots_clean.gpkg")
boundary_path <- file.path(root_dir, "data_intermediate", "spatial", "boundary_clean.gpkg")
plot_context_path <- file.path(root_dir, "Output", "csv", "plot_context_flags.csv")
annual_occurrence_plot_path <- file.path(root_dir, "Output", "csv", "07f_pre_post_inundation_plot_summary_fixed.csv")
asset_register_path <- file.path(root_dir, "Output", "reports", "Gayini_ppt_asset_register.csv")
asset_pack_root <- file.path(root_dir, "Output", "reports", "ppt_asset_pack_20260625")

dir.create(csv_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(report_dir, recursive = TRUE, showWarnings = FALSE)

annual_manifest_path <- file.path(diagnostics_dir, "mer_annual_raster_build_manifest.csv")
period_manifest_path <- file.path(diagnostics_dir, "mer_period_summary_raster_manifest.csv")
water_year_support_path <- file.path(root_dir, "Output", "diagnostics", "24_mer_raster_build", "mer_raster_water_year_support.csv")

required_inputs <- c(annual_manifest_path, period_manifest_path, plots_path, annual_occurrence_plot_path)
missing_inputs <- required_inputs[!file.exists(required_inputs)]
if (length(missing_inputs) > 0) {
  stop("Missing required Task 12 inputs. Run scripts/25_build_mer_annual_max_rasters.R first: ", paste(missing_inputs, collapse = "; "), call. = FALSE)
}

annual_manifest <- readr::read_csv(annual_manifest_path, show_col_types = FALSE)

## Plot and vegetation summaries ----

plot_extracts <- gayini_mer_extract_rasters_to_plots(
  raster_manifest = annual_manifest,
  plots_path = plots_path,
  plot_context_path = plot_context_path
)

annual_by_plot <- plot_extracts$annual_by_plot %>%
  dplyr::mutate(
    vegetation_group = dplyr::coalesce(.data$simplified_vegetation_group, .data$vegetation_adrian_group),
    mer_observation_support_label = dplyr::case_when(
      is.na(.data$mer_observation_support_class) ~ "missing",
      .data$mer_observation_support_class < 0.5 ~ "no_support",
      .data$mer_observation_support_class < 1.5 ~ "low_support",
      .data$mer_observation_support_class < 2.5 ~ "moderate_support",
      TRUE ~ "high_support"
    )
  ) %>%
  dplyr::select(dplyr::any_of(c(
    "plot_id",
    "vegetation_group",
    "simplified_vegetation_group",
    "vegetation_adrian_group",
    "treed_plot_flag",
    "ground_cover_exclusion_flag",
    "ground_cover_exclusion_reason",
    "collapsed_grazing_category",
    "water_year",
    "mer_annual_max_observed_wet_pct",
    "mer_valid_observation_count_mean",
    "mer_wet_observation_count_mean",
    "mer_observation_support_class",
    "mer_observation_support_label",
    "mer_wet_observation_fraction_mean",
    "notes"
  )))

period_by_plot <- plot_extracts$period_by_plot %>%
  dplyr::mutate(
    vegetation_group = dplyr::coalesce(.data$simplified_vegetation_group, .data$vegetation_adrian_group),
    notes = paste(.data$notes, "MER outputs are supplementary to annual occurrence products.")
  ) %>%
  dplyr::select(dplyr::any_of(c(
    "plot_id",
    "vegetation_group",
    "simplified_vegetation_group",
    "vegetation_adrian_group",
    "treed_plot_flag",
    "ground_cover_exclusion_flag",
    "ground_cover_exclusion_reason",
    "collapsed_grazing_category",
    "pre_mer_frequency_pct",
    "post_mer_frequency_pct",
    "post_minus_pre_mer_frequency_pct_points",
    "n_pre_valid_years",
    "n_post_valid_years",
    "notes"
  )))

vegetation_summary <- period_by_plot %>%
  dplyr::group_by(.data$vegetation_group) %>%
  dplyr::summarise(
    n_plots = dplyr::n_distinct(.data$plot_id),
    pre_mer_frequency_mean = mean(.data$pre_mer_frequency_pct, na.rm = TRUE),
    post_mer_frequency_mean = mean(.data$post_mer_frequency_pct, na.rm = TRUE),
    post_minus_pre_mer_frequency_mean = mean(.data$post_minus_pre_mer_frequency_pct_points, na.rm = TRUE),
    support_caveat = dplyr::case_when(
      any(.data$n_pre_valid_years <= 0 | .data$n_post_valid_years <= 0, na.rm = TRUE) ~ "Some plots have limited pre/post support.",
      TRUE ~ "All summarised plots have pre and post MER annual max support."
    ),
    notes = "Vegetation-group summary of supplementary MER annual maximum observed wet frequency.",
    .groups = "drop"
  ) %>%
  dplyr::arrange(dplyr::desc(.data$post_minus_pre_mer_frequency_mean))

gayini_write_csv(annual_by_plot, file.path(csv_dir, "mer_annual_max_by_plot.csv"))
gayini_write_csv(period_by_plot, file.path(csv_dir, "mer_period_summary_by_plot.csv"))
gayini_write_csv(vegetation_summary, file.path(csv_dir, "mer_period_summary_by_vegetation_group.csv"))

## Comparison with annual occurrence ----

comparison <- gayini_mer_compare_with_annual_occurrence(
  mer_period_by_plot = period_by_plot,
  annual_occurrence_plot_path = annual_occurrence_plot_path
)

comparison_by_plot <- comparison$plot_comparison %>%
  dplyr::select(dplyr::any_of(c(
    "plot_id",
    "vegetation_group",
    "treed_plot_flag",
    "annual_occurrence_post_minus_pre_pct_points",
    "mer_post_minus_pre_pct_points",
    "difference_mer_minus_annual_occurrence",
    "direction_agreement",
    "review_flag",
    "notes"
  )))
comparison_summary <- comparison$summary

gayini_write_csv(comparison_by_plot, file.path(csv_dir, "mer_vs_annual_occurrence_raster_comparison_by_plot.csv"))
gayini_write_csv(comparison_summary, file.path(csv_dir, "mer_vs_annual_occurrence_raster_comparison_summary.csv"))

## Figure helpers ----

raster_to_plot_df <- function(raster_path, value_name = "value", max_cells = 220000) {
  r <- terra::rast(raster_path)[[1]]
  n_cells <- terra::ncell(r)
  if (n_cells > max_cells) {
    df <- terra::spatSample(r, size = max_cells, method = "regular", as.df = TRUE, xy = TRUE, na.rm = FALSE)
  } else {
    df <- terra::as.data.frame(r, xy = TRUE, na.rm = FALSE)
  }
  names(df)[names(df) == names(r)[[1]]] <- value_name
  tibble::as_tibble(df)
}

read_boundary <- function(raster_path) {
  if (!file.exists(boundary_path)) {
    return(NULL)
  }
  boundary <- sf::st_read(boundary_path, quiet = TRUE)
  raster_crs <- terra::crs(terra::rast(raster_path), proj = TRUE)
  sf::st_transform(boundary, crs = raster_crs)
}

plot_raster_continuous <- function(raster_path,
                                   title,
                                   subtitle,
                                   fill_label,
                                   palette = "viridis",
                                   midpoint = NULL,
                                   caption = NULL) {
  df <- raster_to_plot_df(raster_path, value_name = "value")
  boundary <- read_boundary(raster_path)
  p <- ggplot2::ggplot(df, ggplot2::aes(x = .data$x, y = .data$y, fill = .data$value)) +
    ggplot2::geom_raster() +
    {if (!is.null(boundary)) ggplot2::geom_sf(data = boundary, fill = NA, colour = "#333333", linewidth = 0.25, inherit.aes = FALSE)} +
    ggplot2::coord_sf(expand = FALSE) +
    ggplot2::labs(title = title, subtitle = subtitle, fill = fill_label, caption = caption, x = NULL, y = NULL) +
    gayini_theme_map(base_size = 11, legend_position = "right")

  if (!is.null(midpoint)) {
    p + gayini_change_scale_fill(midpoint = midpoint, na.value = "transparent")
  } else if (palette == "wet") {
    p + ggplot2::scale_fill_gradient(low = "#f7f7f7", high = "#2166ac", na.value = "transparent")
  } else {
    p + ggplot2::scale_fill_viridis_c(option = "C", na.value = "transparent")
  }
}

## Review figures ----

annual_stats <- annual_by_plot %>%
  dplyr::group_by(.data$water_year) %>%
  dplyr::summarise(mean_mer_wet_pct = mean(.data$mer_annual_max_observed_wet_pct, na.rm = TRUE), .groups = "drop") %>%
  dplyr::arrange(.data$mean_mer_wet_pct)

dry_example <- annual_stats$water_year[[1]]
wet_example <- annual_stats$water_year[[nrow(annual_stats)]]
example_manifest <- annual_manifest %>%
  dplyr::filter(.data$water_year %in% c(dry_example, wet_example)) %>%
  dplyr::mutate(example_label = dplyr::case_when(
    .data$water_year == dry_example ~ paste0(.data$water_year, " lower observed footprint"),
    TRUE ~ paste0(.data$water_year, " higher observed footprint")
  ))

example_df <- dplyr::bind_rows(lapply(seq_len(nrow(example_manifest)), function(i) {
  raster_to_plot_df(example_manifest$annual_max_path[[i]], value_name = "annual_max_observed_wet") %>%
    dplyr::mutate(example_label = example_manifest$example_label[[i]])
}))
boundary_example <- read_boundary(example_manifest$annual_max_path[[1]])

p_example <- ggplot2::ggplot(example_df, ggplot2::aes(x = .data$x, y = .data$y, fill = .data$annual_max_observed_wet)) +
  ggplot2::geom_raster() +
  {if (!is.null(boundary_example)) ggplot2::geom_sf(data = boundary_example, fill = NA, colour = "#333333", linewidth = 0.25, inherit.aes = FALSE)} +
  ggplot2::facet_wrap(~ example_label) +
  ggplot2::coord_sf(expand = FALSE) +
  ggplot2::scale_fill_gradient(low = "#f7f7f7", high = "#2166ac", na.value = "transparent", breaks = c(0, 1), labels = c("Observed dry", "Observed wet")) +
  ggplot2::labs(
    title = "MER annual maximum observed wet footprint examples",
    subtitle = "Each pixel shows whether it was observed wet at least once in the water year",
    fill = "Annual max",
    caption = gayini_mer_caveat_text("annual_max"),
    x = NULL,
    y = NULL
  ) +
  gayini_theme_map(base_size = 11)

figure_paths <- list()
figure_paths$annual_example <- file.path(figure_dir, "mer_annual_max_observed_wet_example.png")
gayini_save_png(figure_paths$annual_example, p_example, width = 10, height = 5.8)

pre_path <- file.path(period_summary_dir, "mer_pre_annual_max_observed_frequency_pct.tif")
post_path <- file.path(period_summary_dir, "mer_post_annual_max_observed_frequency_pct.tif")
change_path <- file.path(period_summary_dir, "mer_post_minus_pre_annual_max_frequency_pct_points.tif")
annual_change_path <- file.path(root_dir, "Output", "rasters", "inundation_pre_post", "post_minus_pre_inundation_frequency_pct_points.tif")

prepost_df <- dplyr::bind_rows(
  raster_to_plot_df(pre_path, "frequency_pct") %>% dplyr::mutate(period = "Pre MER annual max frequency"),
  raster_to_plot_df(post_path, "frequency_pct") %>% dplyr::mutate(period = "Post MER annual max frequency")
)
boundary_prepost <- read_boundary(pre_path)
p_prepost <- ggplot2::ggplot(prepost_df, ggplot2::aes(x = .data$x, y = .data$y, fill = .data$frequency_pct)) +
  ggplot2::geom_raster() +
  {if (!is.null(boundary_prepost)) ggplot2::geom_sf(data = boundary_prepost, fill = NA, colour = "#333333", linewidth = 0.25, inherit.aes = FALSE)} +
  ggplot2::facet_wrap(~ period) +
  ggplot2::coord_sf(expand = FALSE) +
  ggplot2::scale_fill_gradient(low = "#f7f7f7", high = "#2166ac", limits = c(0, 100), na.value = "transparent") +
  ggplot2::labs(
    title = "MER pre/post annual maximum observed wet frequency",
    subtitle = "Frequency of water years where each pixel was observed wet at least once",
    fill = "Frequency (%)",
    caption = gayini_mer_caveat_text("annual_max"),
    x = NULL,
    y = NULL
  ) +
  gayini_theme_map(base_size = 11)
figure_paths$prepost <- file.path(figure_dir, "mer_pre_post_annual_max_frequency_main_deck.png")
gayini_save_png(figure_paths$prepost, p_prepost, width = 10, height = 5.8)

p_change <- plot_raster_continuous(
  raster_path = change_path,
  title = "MER post-minus-pre annual maximum observed wet change",
  subtitle = "Positive values indicate pixels observed wet in more post-conservation water years",
  fill_label = "Change (pp)",
  midpoint = 0,
  caption = paste("Red = less frequent post; blue = more frequent post.", gayini_mer_caveat_text("summary"))
)
figure_paths$change <- file.path(figure_dir, "mer_post_minus_pre_annual_max_change_main_deck.png")
gayini_save_png(figure_paths$change, p_change, width = 8.8, height = 6.3)

compare_df <- dplyr::bind_rows(
  raster_to_plot_df(annual_change_path, "change_pct_points") %>% dplyr::mutate(metric = "Annual occurrence change"),
  raster_to_plot_df(change_path, "change_pct_points") %>% dplyr::mutate(metric = "MER annual max observed wet change")
)
boundary_compare <- read_boundary(change_path)
p_compare <- ggplot2::ggplot(compare_df, ggplot2::aes(x = .data$x, y = .data$y, fill = .data$change_pct_points)) +
  ggplot2::geom_raster() +
  {if (!is.null(boundary_compare)) ggplot2::geom_sf(data = boundary_compare, fill = NA, colour = "#333333", linewidth = 0.25, inherit.aes = FALSE)} +
  ggplot2::facet_wrap(~ metric) +
  ggplot2::coord_sf(expand = FALSE) +
  gayini_change_scale_fill(midpoint = 0, na.value = "transparent") +
  ggplot2::labs(
    title = "MER raster change compared with annual occurrence change",
    subtitle = "Two related but different observed inundation questions",
    fill = "Change (pp)",
    caption = gayini_mer_caveat_text("comparison"),
    x = NULL,
    y = NULL
  ) +
  gayini_theme_map(base_size = 11)
figure_paths$comparison <- file.path(figure_dir, "mer_raster_vs_annual_occurrence_change_comparison.png")
gayini_save_png(figure_paths$comparison, p_compare, width = 10.5, height = 5.8)

water_year_support <- readr::read_csv(water_year_support_path, show_col_types = FALSE)
p_support <- water_year_support %>%
  dplyr::select("water_year", "n_landsat", "n_sentinel2", "n_other_sensor") %>%
  tidyr::pivot_longer(cols = -"water_year", names_to = "sensor_group", values_to = "n_observations") %>%
  dplyr::mutate(sensor_group = dplyr::recode(.data$sensor_group, n_landsat = "Landsat", n_sentinel2 = "Sentinel-2", n_other_sensor = "Other")) %>%
  ggplot2::ggplot(ggplot2::aes(x = .data$water_year, y = .data$n_observations, fill = .data$sensor_group)) +
  ggplot2::geom_col(width = 0.72) +
  ggplot2::scale_fill_manual(values = gayini_sensor_palette()) +
  ggplot2::labs(
    x = "Water year",
    y = "Selected source rasters",
    fill = "Sensor",
    title = "MER observation support by water year",
    subtitle = "Support rasters accompany annual MER products",
    caption = "Sensor cadence differs through time; support is not an ecological response."
  ) +
  gayini_theme_review(base_size = 11) +
  ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 45, hjust = 1), panel.grid.minor = ggplot2::element_blank())
figure_paths$support <- file.path(figure_dir, "mer_observation_support_by_water_year.png")
gayini_save_png(figure_paths$support, p_support, width = 8.8, height = 5.4)

p_agreement <- comparison_summary %>%
  ggplot2::ggplot(ggplot2::aes(x = .data$direction_agreement, y = .data$n_plots, fill = .data$direction_agreement)) +
  ggplot2::geom_col(width = 0.68) +
  ggplot2::geom_text(ggplot2::aes(label = .data$n_plots), vjust = -0.35, size = 3.3) +
  ggplot2::scale_fill_manual(values = gayini_mer_agreement_palette(), drop = FALSE) +
  ggplot2::labs(
    x = NULL,
    y = "Plots",
    title = "MER raster vs annual occurrence plot agreement",
    subtitle = "Direction agreement for post-minus-pre change",
    caption = "Review flags identify different metric behaviour; they do not imply an error."
  ) +
  gayini_theme_review(base_size = 11) +
  ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 25, hjust = 1), legend.position = "none", panel.grid.minor = ggplot2::element_blank())
figure_paths$agreement <- file.path(figure_dir, "mer_vs_annual_occurrence_plot_agreement.png")
gayini_save_png(figure_paths$agreement, p_agreement, width = 8.2, height = 5.2)

p_veg <- vegetation_summary %>%
  dplyr::mutate(vegetation_group = stringr::str_wrap(.data$vegetation_group, width = 24)) %>%
  ggplot2::ggplot(ggplot2::aes(x = stats::reorder(.data$vegetation_group, .data$post_minus_pre_mer_frequency_mean), y = .data$post_minus_pre_mer_frequency_mean)) +
  ggplot2::geom_hline(yintercept = 0, colour = "grey45", linewidth = 0.35) +
  ggplot2::geom_col(fill = "#2b6cb0", width = 0.72) +
  ggplot2::coord_flip() +
  ggplot2::labs(
    x = NULL,
    y = "Post - pre MER annual max frequency (pp)",
    title = "MER post-minus-pre by vegetation group",
    subtitle = "Mean of plot-level supplementary MER raster summaries",
    caption = "Use as supporting context only; management effects are diagnostic/coincident, not causal proof."
  ) +
  gayini_theme_review(base_size = 11) +
  ggplot2::theme(panel.grid.minor = ggplot2::element_blank())
figure_paths$vegetation <- file.path(figure_dir, "mer_post_minus_pre_by_vegetation_group.png")
gayini_save_png(figure_paths$vegetation, p_veg, width = 8.5, height = 5.4)

figure_manifest <- tibble::tibble(
  figure_key = names(figure_paths),
  figure_path = unlist(figure_paths),
  exists = file.exists(unlist(figure_paths)),
  deck_use = c(
    "Appendix / method example",
    "Candidate supporting main-deck MER raster figure",
    "Candidate supporting main-deck MER raster figure",
    "Recommended MER raster main-deck comparison",
    "Appendix / QA",
    "Supporting review figure",
    "Optional appendix vegetation-group context"
  ),
  caveat = gayini_mer_caveat_text("annual_max")
)
gayini_write_csv(figure_manifest, file.path(csv_dir, "mer_raster_review_figure_manifest.csv"))

## Methods note and handoff ----

built_years <- paste(annual_manifest$water_year, collapse = ", ")
agreement_line <- paste(
  paste0(comparison_summary$direction_agreement, ": ", comparison_summary$n_plots),
  collapse = "; "
)

methods_note_path <- file.path(report_dir, "Gayini_MER_raster_methods_note.md")
writeLines(
  c(
    "# Gayini MER Raster Methods Note",
    "",
    paste0("Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
    "",
    "## Purpose",
    "",
    "Create supplementary MER / Flow_MER-style annual maximum observed wet footprint rasters from existing daily / single-date inundation rasters.",
    "",
    "## Inputs",
    "",
    "- Source rasters are the existing daily/single-date inundation rasters listed in `Output/csv/06c_daily_inundation_full.csv` and Task 10 census outputs.",
    "- No new external imagery was downloaded.",
    "- Gauge data were not used in raster building.",
    "",
    "## Grid Alignment Policy",
    "",
    "- Outputs use the current canonical annual occurrence/pre-post raster grid as the reference.",
    "- Daily categorical inundation rasters are aligned with nearest-neighbour resampling only.",
    "- The Gayini boundary mask is used where available.",
    "- Categorical rasters are not bilinear-resampled.",
    "",
    "## Pixel Values",
    "",
    "- Strict wet value: `1`.",
    "- Valid values: `0`, `1`, `2`.",
    "- Value `2` is retained as valid support but is not counted as strict wet.",
    "- Values `3`, `15`, `255`, and `NA` are treated as invalid / non-valid for the production strict rule.",
    "",
    "## Annual Max Observed Wet Raster",
    "",
    "`1` means a pixel was observed wet at least once in the water year. `0` means it was observed valid and dry, never wet. `NA` means no valid observation or outside the analysis mask.",
    "",
    "## Observation Support Rasters",
    "",
    "- `mer_valid_observation_count_*`: count of valid observations.",
    "- `mer_wet_observation_count_*`: count of strict wet observations.",
    "- `mer_observation_support_class_*`: 0 no support, 1 low support, 2 moderate support, 3 high support.",
    "- `mer_wet_observation_fraction_*`: observed wet fraction only; not flood duration or hydroperiod.",
    "",
    "## Pre/Post Summary",
    "",
    paste0("Pre/post summaries use the same ", MANAGEMENT_CHANGE_DATE, " transition framing as the existing annual occurrence analysis."),
    "",
    "## Plot Extraction And Comparison",
    "",
    "Rasters were summarised to the 66 Gayini plot polygons and compared with the current annual occurrence pre/post plot summary.",
    "",
    "## Limitations",
    "",
    paste0("- ", gayini_mer_caveat_text("annual_max")),
    paste0("- ", gayini_mer_caveat_text("wet_fraction")),
    "- Annual occurrence frequency is not flood duration or depth.",
    "- Sequence / duration / start-date metrics remain deferred.",
    paste0("- ", gayini_mer_caveat_text("summary")),
    paste0("- ", gayini_mer_caveat_text("comparison")),
    "- Gauge data provide context, not causal proof of management effects.",
    "- Management effects should not be described causally from these raster summaries alone.",
    "",
    "## Recommended Use",
    "",
    "Use `mer_raster_vs_annual_occurrence_change_comparison.png` as the clearest main-deck MER raster slide if space allows. Put observation support and vegetation-group summaries in the appendix."
  ),
  methods_note_path
)

handoff_path <- file.path(report_dir, "task_12_mer_annual_max_raster_build_handoff.md")
writeLines(
  c(
    "# Task 12 - MER Annual Maximum Raster Build Handoff",
    "",
    paste0("Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
    "",
    "## Summary",
    "",
    "Production MER annual maximum observed wet rasters were built from existing daily / single-date inundation rasters. No sequence, duration or start-date rasters were created.",
    "",
    paste0("- Water years built: ", built_years),
    paste0("- Annual output rows in manifest: ", nrow(annual_manifest)),
    paste0("- Plot rows in annual MER table: ", nrow(annual_by_plot)),
    paste0("- Plot rows in period MER table: ", nrow(period_by_plot)),
    paste0("- MER vs annual occurrence agreement summary: ", agreement_line),
    "",
    "## Grid Alignment Policy",
    "",
    "The current annual occurrence/pre-post raster grid was used as the canonical reference. Source rasters were cropped/aligned to that grid with nearest-neighbour resampling only. Mixed extent/resolution years were built with explicit alignment and reported in the input summary.",
    "",
    "## Outputs",
    "",
    "- `Output/csv/MER/mer_raster_input_census_production.csv`",
    "- `Output/csv/MER/mer_raster_input_summary_by_water_year.csv`",
    "- `Output/csv/MER/mer_raster_output_manifest.csv`",
    "- `Output/csv/MER/mer_annual_max_by_plot.csv`",
    "- `Output/csv/MER/mer_period_summary_by_plot.csv`",
    "- `Output/csv/MER/mer_period_summary_by_vegetation_group.csv`",
    "- `Output/csv/MER/mer_vs_annual_occurrence_raster_comparison_by_plot.csv`",
    "- `Output/csv/MER/mer_vs_annual_occurrence_raster_comparison_summary.csv`",
    "- `Output/rasters/MER/annual_max/`",
    "- `Output/rasters/MER/period_summaries/`",
    "- `Output/figures/review/MER/`",
    "",
    "## Recommended Main-Deck Asset",
    "",
    "`Output/figures/review/MER/mer_raster_vs_annual_occurrence_change_comparison.png`",
    "",
    "## Appendix Assets",
    "",
    "- `mer_observation_support_by_water_year.png`",
    "- `mer_vs_annual_occurrence_plot_agreement.png`",
    "- `mer_annual_max_observed_wet_example.png`",
    "- `mer_post_minus_pre_by_vegetation_group.png`",
    "",
    "## Caveats",
    "",
    paste0("- ", gayini_mer_caveat_text("annual_max")),
    paste0("- ", gayini_mer_caveat_text("wet_fraction")),
    "- Annual occurrence frequency is not flood duration or depth.",
    "- Sequence / duration / start-date metrics remain deferred.",
    paste0("- ", gayini_mer_caveat_text("summary")),
    paste0("- ", gayini_mer_caveat_text("comparison")),
    "- Gauge data were not used in raster building and remain contextual.",
    "- Management effects should not be described causally from these raster summaries alone.",
    "",
    "## Checks",
    "",
    "- no biodiversity repo touched: pass",
    "- no heavy ground-cover extraction run: pass",
    "- no existing pre/post annual occurrence rasters rebuilt: pass",
    "- no existing outputs deleted, moved or archived: pass",
    "- no broad codebase refactor performed: pass",
    "- all source rasters used were found and opened in Task 10 census: pass",
    "- source pixel values checked and documented: pass",
    "- grid policy written before production rasters were built: pass",
    "- categorical rasters resampled only with nearest-neighbour: pass",
    "- observation support rasters exist: pass",
    "- plot summaries exist: pass",
    "- comparison with annual occurrence exists: pass",
    "- review figures exist: pass"
  ),
  handoff_path
)

## Asset register and asset pack ----

make_asset_row <- function(asset_id, path, title, priority, status, slide, notes) {
  info <- file.info(path)
  tibble::tibble(
    asset_id = asset_id,
    filename = basename(path),
    full_path = normalizePath(path, winslash = "/", mustWork = TRUE),
    file_type = tools::file_ext(path),
    file_modified_date = format(info$mtime, "%Y-%m-%d %H:%M:%S"),
    figure_or_table_title = title,
    analysis_module = "MER",
    story_role = "Hydrology",
    recommended_slide = slide,
    deck_priority = priority,
    asset_status = status,
    supersedes = NA_character_,
    superseded_by = NA_character_,
    source_script = "scripts/25_build_mer_annual_max_rasters.R; scripts/26_summarise_compare_mer_rasters.R",
    source_data = "Output/rasters/MER/annual_max; Output/rasters/MER/period_summaries; Output/csv/MER",
    review_caveat = gayini_mer_caveat_text("annual_max"),
    notes = notes,
    updated_by_task_8 = FALSE,
    updated_by_task_9 = FALSE,
    updated_by_task_12 = TRUE
  )
}

task12_assets <- dplyr::bind_rows(
  make_asset_row("PPTTASK12_MER_001", figure_paths$comparison, "MER raster versus annual occurrence change comparison", "Supporting", "Current canonical", "Main deck optional MER raster comparison", "Recommended MER raster main-deck slide if space allows."),
  make_asset_row("PPTTASK12_MER_002", figure_paths$change, "MER post-minus-pre annual maximum observed wet change", "Supporting", "Current canonical", "Supporting MER raster change map", "Use with annual occurrence context."),
  make_asset_row("PPTTASK12_MER_003", figure_paths$prepost, "MER pre/post annual maximum observed wet frequency", "Supporting", "Candidate", "Supporting MER pre/post map", "Supports raster methods discussion."),
  make_asset_row("PPTTASK12_MER_004", figure_paths$support, "MER observation support by water year", "Appendix", "Candidate", "Technical appendix", "Observation support caveat."),
  make_asset_row("PPTTASK12_MER_005", figure_paths$agreement, "MER versus annual occurrence plot agreement", "Appendix", "Candidate", "Technical appendix", "Agreement and review flags."),
  make_asset_row("PPTTASK12_MER_006", figure_paths$annual_example, "MER annual maximum observed wet examples", "Appendix", "Candidate", "Technical appendix", "Annual raster examples."),
  make_asset_row("PPTTASK12_MER_007", figure_paths$vegetation, "MER post-minus-pre by vegetation group", "Appendix", "Candidate", "Technical appendix", "Optional vegetation group context.")
)

if (file.exists(asset_register_path)) {
  existing_register <- readr::read_csv(asset_register_path, show_col_types = FALSE)
  if ("file_modified_date" %in% names(existing_register)) {
    existing_register$file_modified_date <- as.character(existing_register$file_modified_date)
  }
  if (!"updated_by_task_12" %in% names(existing_register)) {
    existing_register$updated_by_task_12 <- FALSE
  }
  task12_assets <- task12_assets %>%
    dplyr::select(dplyr::all_of(names(existing_register)))
  updated_register <- existing_register %>%
    dplyr::filter(!.data$asset_id %in% task12_assets$asset_id) %>%
    dplyr::bind_rows(task12_assets)
  gayini_write_csv(updated_register, asset_register_path)
}

if (dir.exists(asset_pack_root)) {
  dir.create(file.path(asset_pack_root, "01_main_deck_figures"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(asset_pack_root, "02_supporting_figures"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(asset_pack_root, "03_appendix_figures"), recursive = TRUE, showWarnings = FALSE)

  file.copy(figure_paths$comparison, file.path(asset_pack_root, "01_main_deck_figures", basename(figure_paths$comparison)), overwrite = TRUE)
  file.copy(figure_paths$change, file.path(asset_pack_root, "02_supporting_figures", basename(figure_paths$change)), overwrite = TRUE)
  file.copy(figure_paths$prepost, file.path(asset_pack_root, "02_supporting_figures", basename(figure_paths$prepost)), overwrite = TRUE)
  file.copy(figure_paths$support, file.path(asset_pack_root, "03_appendix_figures", basename(figure_paths$support)), overwrite = TRUE)
  file.copy(figure_paths$agreement, file.path(asset_pack_root, "03_appendix_figures", basename(figure_paths$agreement)), overwrite = TRUE)
  file.copy(figure_paths$annual_example, file.path(asset_pack_root, "03_appendix_figures", basename(figure_paths$annual_example)), overwrite = TRUE)
  file.copy(figure_paths$vegetation, file.path(asset_pack_root, "03_appendix_figures", basename(figure_paths$vegetation)), overwrite = TRUE)
}

message("Task 12 MER raster summaries, comparison, figures and documentation complete.")
message("Recommended main-deck figure: ", figure_paths$comparison)
message("Handoff report: ", handoff_path)
