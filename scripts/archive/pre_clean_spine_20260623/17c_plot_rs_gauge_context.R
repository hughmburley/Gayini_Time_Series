## 17c_plot_rs_gauge_context.R
## Review figures for Murrumbidgee gauge context in the Gayini workflow.

root_dir <- Sys.getenv("GAYINI_ROOT", unset = getwd())
setwd(root_dir)

required_packages <- c("dplyr", "ggplot2", "lubridate", "readr", "stringr", "tibble", "tidyr")
missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]
if (length(missing_packages) > 0) {
  stop("Install missing packages before continuing: ", paste(missing_packages, collapse = ", "))
}

source(file.path(root_dir, "R/hydrology_import_functions.R"))
source(file.path(root_dir, "R/rs_gauge_join_functions.R"))

dir.create(file.path(root_dir, "Output/figures/hydrology"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(root_dir, "Output/diagnostics/hydrology"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(root_dir, "Output/logs"), recursive = TRUE, showWarnings = FALSE)

gauge_monthly <- read_hydrology_csv(file.path(root_dir, "data_intermediate/hydrology/gauge_monthly_prepared.csv")) |>
  dplyr::mutate(month_start = as.Date(.data$month_start))
gauge_water_year <- read_hydrology_csv(file.path(root_dir, "data_intermediate/hydrology/gauge_water_year_prepared.csv"))
water_year_context <- readr::read_csv(file.path(root_dir, "data_processed/hydrology/plot_rs_gauge_water_year_context.csv"), show_col_types = FALSE, col_types = readr::cols(.default = readr::col_guess(), station_id = readr::col_character()))
monthly_context <- readr::read_csv(file.path(root_dir, "data_processed/hydrology/plot_rs_gauge_monthly_context.csv"), show_col_types = FALSE, col_types = readr::cols(.default = readr::col_guess(), station_id = readr::col_character())) |>
  dplyr::mutate(month_start = as.Date(.data$month_start))

primary_uses <- c("upstream_context_primary", "lower_murrumbidgee_context_primary", "local_upstream_primary", "downstream_context_flagged")

monthly_primary_plot <- gauge_monthly |>
  dplyr::filter(.data$recommended_use %in% primary_uses) |>
  dplyr::mutate(plot_mean_flow_mld = dplyr::if_else(.data$n_valid_flow_days > 0, .data$mean_flow_mld, NA_real_)) |>
  ggplot2::ggplot(ggplot2::aes(x = .data$month_start, y = .data$plot_mean_flow_mld)) +
  ggplot2::geom_vline(xintercept = as.Date("2019-07-01"), colour = "#525252", linetype = "dashed", linewidth = 0.35) +
  ggplot2::geom_line(colour = "#2166ac", linewidth = 0.35, na.rm = TRUE) +
  ggplot2::facet_wrap(~ station_name, scales = "free_y", ncol = 2) +
  ggplot2::labs(
    title = "Monthly flow context for primary Murrumbidgee gauges",
    subtitle = "Dashed line marks 2019-07-01 management-change reference; gaps remain unconnected",
    x = "Month",
    y = "Mean flow (ML/day)"
  ) +
  ggplot2::theme_minimal(base_size = 10)

water_year_primary_plot <- gauge_water_year |>
  dplyr::filter(.data$recommended_use %in% primary_uses) |>
  dplyr::mutate(plot_total_flow_ml = dplyr::if_else(.data$n_valid_flow_days > 0, .data$total_flow_ml, NA_real_)) |>
  ggplot2::ggplot(ggplot2::aes(x = .data$water_year_numeric, y = .data$plot_total_flow_ml)) +
  ggplot2::geom_vline(xintercept = 2020, colour = "#525252", linetype = "dashed", linewidth = 0.35) +
  ggplot2::geom_line(colour = "#2166ac", linewidth = 0.35, na.rm = TRUE) +
  ggplot2::geom_point(size = 0.8, colour = "#2166ac", na.rm = TRUE) +
  ggplot2::facet_wrap(~ station_name, scales = "free_y", ncol = 2) +
  ggplot2::labs(
    title = "Water-year flow context for primary Murrumbidgee gauges",
    subtitle = "Water year is July-June; 2020 is the first water year after 2019-07-01",
    x = "Water year ending",
    y = "Total flow (ML)"
  ) +
  ggplot2::theme_minimal(base_size = 10)

annual_inundation_summary <- water_year_context |>
  dplyr::filter(.data$recommended_use %in% primary_uses) |>
  dplyr::group_by(.data$station_id, .data$station_name, .data$recommended_use, .data$water_year, .data$water_year_numeric) |>
  dplyr::summarise(
    mean_annual_inundated_any_pct = mean(.data$annual_inundated_any_pct, na.rm = TRUE),
    mean_daily_max_inundated_pct = mean(.data$daily_max_inundated_pct, na.rm = TRUE),
    total_flow_ml = dplyr::first(.data$total_flow_ml),
    missing_flow_pct = dplyr::first(.data$missing_flow_pct),
    patch_status_summary = dplyr::first(.data$patch_status_summary),
    .groups = "drop"
  )

flow_vs_inundation_plot <- annual_inundation_summary |>
  ggplot2::ggplot(ggplot2::aes(x = .data$total_flow_ml, y = .data$mean_annual_inundated_any_pct, colour = .data$missing_flow_pct)) +
  ggplot2::geom_point(size = 1.7, alpha = 0.85, na.rm = TRUE) +
  ggplot2::facet_wrap(~ station_name, scales = "free_x", ncol = 2) +
  ggplot2::scale_colour_viridis_c(option = "C", direction = -1, na.value = "#bdbdbd") +
  ggplot2::labs(
    title = "Gauge water-year flow vs annual inundation frequency",
    x = "Gauge total flow (ML)",
    y = "Mean plot annual inundated-any (%)",
    colour = "Flow missing (%)"
  ) +
  ggplot2::theme_minimal(base_size = 10)

example_plots <- water_year_context |>
  dplyr::filter(.data$recommended_use == "local_upstream_primary", !is.na(.data$total_veg_pct)) |>
  dplyr::group_by(.data$plot_id) |>
  dplyr::summarise(total_veg_range = max(.data$total_veg_pct, na.rm = TRUE) - min(.data$total_veg_pct, na.rm = TRUE), .groups = "drop") |>
  dplyr::arrange(dplyr::desc(.data$total_veg_range)) |>
  dplyr::slice_head(n = 6) |>
  dplyr::pull(.data$plot_id)

flow_vs_veg_plot <- water_year_context |>
  dplyr::filter(.data$recommended_use == "local_upstream_primary", .data$plot_id %in% example_plots) |>
  ggplot2::ggplot(ggplot2::aes(x = .data$total_flow_ml, y = .data$total_veg_pct, colour = .data$water_year_numeric >= 2020)) +
  ggplot2::geom_point(size = 1.6, alpha = 0.85, na.rm = TRUE) +
  ggplot2::facet_wrap(~ plot_id, ncol = 3) +
  ggplot2::scale_colour_manual(values = c("FALSE" = "#2166ac", "TRUE" = "#b2182b"), labels = c("Pre", "Post")) +
  ggplot2::labs(
    title = "Example plot vegetation vs Maude water-year flow",
    subtitle = "Context only; do not infer causation without further analysis",
    x = "Maude total flow (ML)",
    y = "Total vegetation (%)",
    colour = "Period"
  ) +
  ggplot2::theme_minimal(base_size = 10) +
  ggplot2::theme(legend.position = "bottom")

missingness_plot <- gauge_monthly |>
  dplyr::mutate(gauge_group = dplyr::case_when(
    .data$recommended_use == "local_downstream_partial_record" ~ "Redbank partial record",
    .data$recommended_use == "upstream_support_recent" ~ "Carrathool support/recent",
    TRUE ~ "Primary review gauges"
  )) |>
  ggplot2::ggplot(ggplot2::aes(x = .data$month_start, y = .data$missing_flow_pct)) +
  ggplot2::geom_vline(xintercept = as.Date("2019-07-01"), colour = "#525252", linetype = "dashed", linewidth = 0.35) +
  ggplot2::geom_line(colour = "#b2182b", linewidth = 0.3, na.rm = TRUE) +
  ggplot2::facet_wrap(~ station_name, ncol = 2) +
  ggplot2::coord_cartesian(ylim = c(0, 100)) +
  ggplot2::labs(
    title = "Gauge missingness context for Gayini review",
    x = "Month",
    y = "Missing flow days (%)"
  ) +
  ggplot2::theme_minimal(base_size = 10)

ratio_path <- file.path(root_dir, "Input/hydrology/kingsford_style_flow_ratio_water_year.csv")
if (file.exists(ratio_path)) {
  ratios <- readr::read_csv(ratio_path, show_col_types = FALSE)
  ratio_plot <- ratios |>
    dplyr::mutate(plot_ratio = dplyr::if_else(.data$insufficient_overlap_flag, NA_real_, .data$ratio_downstream_over_upstream)) |>
    ggplot2::ggplot(ggplot2::aes(x = .data$water_year, y = .data$plot_ratio, colour = .data$pair_id)) +
    ggplot2::geom_vline(xintercept = 2020, colour = "#525252", linetype = "dashed", linewidth = 0.35) +
    ggplot2::geom_line(linewidth = 0.35, na.rm = TRUE) +
    ggplot2::geom_point(data = dplyr::filter(ratios, .data$insufficient_overlap_flag), ggplot2::aes(y = 0), shape = 4, alpha = 0.6) +
    ggplot2::labs(
      title = "Kingsford-style downstream/upstream flow ratios for review",
      subtitle = "X marks years with insufficient overlapping valid days",
      x = "Water year ending",
      y = "Downstream / upstream total flow ratio",
      colour = "Gauge pair"
    ) +
    ggplot2::theme_minimal(base_size = 10) +
    ggplot2::theme(legend.position = "bottom")
} else {
  ratio_plot <- ggplot2::ggplot() +
    ggplot2::annotate("text", x = 0, y = 0, label = "Kingsford-style ratio file not imported") +
    ggplot2::theme_void()
}

ggplot2::ggsave(file.path(root_dir, "Output/figures/hydrology/gauge_context_monthly_flow_primary_gauges.png"), monthly_primary_plot, width = 11, height = 7.5, dpi = 200)
ggplot2::ggsave(file.path(root_dir, "Output/figures/hydrology/gauge_context_water_year_flow_primary_gauges.png"), water_year_primary_plot, width = 11, height = 7.5, dpi = 200)
ggplot2::ggsave(file.path(root_dir, "Output/figures/hydrology/gauge_flow_vs_annual_inundation_frequency.png"), flow_vs_inundation_plot, width = 10, height = 7, dpi = 200)
ggplot2::ggsave(file.path(root_dir, "Output/figures/hydrology/gauge_flow_vs_total_vegetation_examples.png"), flow_vs_veg_plot, width = 10, height = 6, dpi = 200)
ggplot2::ggsave(file.path(root_dir, "Output/figures/hydrology/gauge_missingness_context.png"), missingness_plot, width = 11, height = 7.5, dpi = 200)
ggplot2::ggsave(file.path(root_dir, "Output/figures/hydrology/kingsford_style_flow_ratios_for_review.png"), ratio_plot, width = 10, height = 5.5, dpi = 200)

figure_manifest <- tibble::tibble(
  figure = c(
    "gauge_context_monthly_flow_primary_gauges.png",
    "gauge_context_water_year_flow_primary_gauges.png",
    "gauge_flow_vs_annual_inundation_frequency.png",
    "gauge_flow_vs_total_vegetation_examples.png",
    "gauge_missingness_context.png",
    "kingsford_style_flow_ratios_for_review.png"
  ),
  path = file.path(root_dir, "Output/figures/hydrology", figure)
)
readr::write_csv(figure_manifest, file.path(root_dir, "Output/diagnostics/hydrology/hydrology_figure_manifest.csv"))

writeLines(capture.output(sessionInfo()), file.path(root_dir, "Output/logs/17c_plot_rs_gauge_context_session_info.txt"))

message("Task 04b/17c hydrology figures complete.")
