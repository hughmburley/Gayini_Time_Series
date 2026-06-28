# ------------------------------------------------------------------------------
# Script: scripts/07_figures_dashboards/03_prepare_plot_context_flags.R
# Purpose: Prepare plot context flags.
# Workflow stage: 07_figures_dashboards
# Run mode: lightweight_review
# Heavy processing: no
# Key inputs:
#   - Plot metadata and curated outputs.
# Key outputs:
#   - Plot context flag tables.
# Notes:
#   - Keep stable output filenames for downstream reports.
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Load configuration and execute workflow step
# ------------------------------------------------------------------------------

## Purpose:
## Prepare Adrian review context flags for vegetation groups, treed-plot
## ground-cover interpretation exclusions, and collapsed grazing categories.
## This script reads existing plot/curated/review outputs only; it does not run
## raster extraction or raster-building workflows.


## User settings ----


root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", "D:/Github_repos/Gayini"), winslash = "/", mustWork = TRUE)
EXPECTED_N_PLOTS <- 66L


## Required packages ----


required_packages <- c(
  "dplyr",
  "tidyr",
  "readr",
  "stringr",
  "magrittr",
  "tibble",
  "ggplot2",
  "sf"
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


## Paths ----


csv_dir <- file.path(root_dir, "Output", "csv")
figure_dir <- file.path(root_dir, "Output", "figures", "review")
diagnostics_dir <- file.path(root_dir, "Output", "diagnostics", "10d_plot_context_flags")
report_dir <- file.path(root_dir, "Output", "reports")
spatial_dir <- file.path(root_dir, "data_intermediate", "spatial")

dir.create(csv_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(diagnostics_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(report_dir, recursive = TRUE, showWarnings = FALSE)

plot_master_path <- file.path(root_dir, "data_processed", "plot_master.csv")
plot_base_path <- file.path(csv_dir, "plot_rs_analysis_base.csv")
ground_cover_plot_summary_path <- file.path(csv_dir, "10a_ground_cover_prepost_plot_summary.csv")
ground_cover_group_summary_path <- file.path(csv_dir, "10a_ground_cover_prepost_group_summary.csv")
curated_ground_cover_path <- file.path(csv_dir, "curated_ground_cover_timeseries.csv")

plot_context_flags_path <- file.path(csv_dir, "plot_context_flags.csv")
plot_context_summary_path <- file.path(csv_dir, "plot_context_flag_summary.csv")
sensitivity_path <- file.path(csv_dir, "ground_cover_treed_plot_sensitivity.csv")
interpretation_plot_summary_path <- file.path(csv_dir, "10a_ground_cover_prepost_plot_summary_interpretation.csv")
interpretation_group_summary_path <- file.path(csv_dir, "10a_ground_cover_prepost_group_summary_interpretation.csv")
map_path <- file.path(figure_dir, "plot_treed_exclusion_map.png")
handoff_report_path <- file.path(report_dir, "task_1_veg_groups_treed_grazing_handoff.md")

checks_path <- file.path(diagnostics_dir, "plot_context_flag_checks.csv")
treed_plot_list_path <- file.path(diagnostics_dir, "treed_plot_list.csv")
vegetation_category_summary_path <- file.path(diagnostics_dir, "vegetation_category_summary.csv")
grazing_collapse_summary_path <- file.path(diagnostics_dir, "grazing_collapse_summary.csv")
variable_lut_path <- file.path(diagnostics_dir, "plot_context_variable_lut.csv")
map_context_note_path <- file.path(diagnostics_dir, "plot_treed_exclusion_map_context_note.csv")

required_inputs <- c(
  plot_master = plot_master_path,
  plot_rs_analysis_base = plot_base_path,
  ground_cover_plot_summary = ground_cover_plot_summary_path,
  ground_cover_group_summary = ground_cover_group_summary_path,
  curated_ground_cover_timeseries = curated_ground_cover_path
)

missing_inputs <- names(required_inputs)[!file.exists(required_inputs)]
if (length(missing_inputs) > 0) {
  stop("Missing required input(s): ", paste(missing_inputs, collapse = ", "), call. = FALSE)
}


## Helpers ----


write_csv_message <- function(x, path) {
  readr::write_csv(x, path)
  message("Wrote: ", path)
  invisible(x)
}


safe_mean <- function(x) {
  if (all(is.na(x))) {
    return(NA_real_)
  }

  mean(x, na.rm = TRUE)
}


safe_median <- function(x) {
  if (all(is.na(x))) {
    return(NA_real_)
  }

  median(x, na.rm = TRUE)
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


collapse_grazing <- function(treatment) {
  treatment <- stringr::str_squish(as.character(treatment))

  dplyr::case_when(
    is.na(treatment) | treatment == "" ~ "Unknown",
    stringr::str_to_lower(treatment) == "no grazing" ~ "No grazing",
    stringr::str_detect(stringr::str_to_lower(treatment), "grazing") ~ "Any grazing",
    TRUE ~ "Unknown"
  )
}


summarise_interpretation_group <- function(df, group_cols, group_type) {
  df %>%
    dplyr::group_by(dplyr::across(dplyr::all_of(group_cols))) %>%
    dplyr::summarise(
      n_plots = dplyr::n(),
      mean_delta_total_veg_pct = safe_mean(.data$delta_total_veg_pct),
      median_delta_total_veg_pct = safe_median(.data$delta_total_veg_pct),
      mean_delta_bare_ground_pct = safe_mean(.data$delta_bare_ground_pct),
      median_delta_bare_ground_pct = safe_median(.data$delta_bare_ground_pct),
      mean_inundation_delta_pct_points = safe_mean(.data$post_minus_pre_inundation_frequency_pct_points),
      n_low_pre_gc_support = sum(.data$low_pre_gc_support, na.rm = TRUE),
      n_low_post_gc_support = sum(.data$low_post_gc_support, na.rm = TRUE),
      n_strong_total_veg_increase = sum(.data$strong_total_veg_increase, na.rm = TRUE),
      n_strong_total_veg_decrease = sum(.data$strong_total_veg_decrease, na.rm = TRUE),
      n_strong_bare_increase = sum(.data$strong_bare_increase, na.rm = TRUE),
      n_strong_bare_decrease = sum(.data$strong_bare_decrease, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    dplyr::mutate(
      group_type = group_type,
      group_label = do.call(paste, c(dplyr::select(., dplyr::all_of(group_cols)), sep = " | "))
    ) %>%
    dplyr::select("group_type", "group_label", dplyr::all_of(group_cols), dplyr::everything())
}


make_sensitivity_summary <- function(plot_summary) {
  scenarios <- tibble::tibble(
    scenario = c("all_plots", "ground_cover_interpretation_included"),
    include_treed = c(TRUE, FALSE)
  )

  dplyr::bind_rows(lapply(seq_len(nrow(scenarios)), function(i) {
    scenario_row <- scenarios[i, ]
    scenario_data <- if (scenario_row$include_treed) {
      plot_summary
    } else {
      plot_summary %>%
        dplyr::filter(!.data$ground_cover_exclusion_flag)
    }

    tibble::tibble(
      scenario = scenario_row$scenario,
      n_plots = nrow(scenario_data),
      n_treed_excluded = sum(plot_summary$ground_cover_exclusion_flag, na.rm = TRUE) -
        sum(scenario_data$ground_cover_exclusion_flag, na.rm = TRUE),
      mean_delta_total_veg_pct = safe_mean(scenario_data$delta_total_veg_pct),
      median_delta_total_veg_pct = safe_median(scenario_data$delta_total_veg_pct),
      mean_delta_bare_ground_pct = safe_mean(scenario_data$delta_bare_ground_pct),
      median_delta_bare_ground_pct = safe_median(scenario_data$delta_bare_ground_pct),
      mean_inundation_delta_pct_points = safe_mean(scenario_data$post_minus_pre_inundation_frequency_pct_points),
      n_strong_total_veg_increase = sum(scenario_data$strong_total_veg_increase, na.rm = TRUE),
      n_strong_total_veg_decrease = sum(scenario_data$strong_total_veg_decrease, na.rm = TRUE),
      n_strong_bare_increase = sum(scenario_data$strong_bare_increase, na.rm = TRUE),
      n_strong_bare_decrease = sum(scenario_data$strong_bare_decrease, na.rm = TRUE)
    )
  })) %>%
    tidyr::pivot_longer(
      cols = -"scenario",
      names_to = "metric",
      values_to = "value"
    ) %>%
    tidyr::pivot_wider(
      names_from = "scenario",
      values_from = "value"
    ) %>%
    dplyr::mutate(
      treed_exclusion_difference = .data$ground_cover_interpretation_included - .data$all_plots,
      interpretation = dplyr::case_when(
        .data$metric == "n_plots" ~ "Plot count retained after excluding treed plots from interpretation.",
        stringr::str_detect(.data$metric, "delta_total_veg") ~ "Sensitivity of total vegetation pre/post result to treed-plot exclusion.",
        stringr::str_detect(.data$metric, "delta_bare") ~ "Sensitivity of bare-ground pre/post result to treed-plot exclusion.",
        TRUE ~ "Ground-cover interpretation sensitivity to treed-plot exclusion."
      )
    )
}


make_variable_lut <- function() {
  tibble::tibble(
    variable_name = c(
      "original_vegetation_class",
      "simplified_vegetation_group",
      "treed_plot_flag",
      "ground_cover_exclusion_flag",
      "ground_cover_exclusion_reason",
      "original_grazing_treatment_category",
      "collapsed_grazing_category"
    ),
    definition = c(
      "Vegetation/community class from the current plot master table.",
      "Review grouping used for plot summaries and deck-facing context.",
      "TRUE when vegetation class is a floodplain/riverine woodland or forest category.",
      "TRUE when plot should be excluded from ground-cover interpretation summaries.",
      "Plain-language reason for exclusion from ground-cover interpretation summaries.",
      "Original treatment/grazing category from the plot master table.",
      "Collapsed grazing category: Any grazing, No grazing, or Unknown."
    ),
    deck_use = c(
      "Context label",
      "Primary vegetation grouping",
      "Review/filter flag",
      "Ground-cover interpretation filter",
      "Footnote/caveat",
      "Provenance field",
      "Secondary grazing summary"
    )
  )
}


## Read inputs ----


plot_master <- readr::read_csv(plot_master_path, show_col_types = FALSE) %>%
  gayini_standardise_plot_id(object_name = "plot master") %>%
  dplyr::distinct(.data$plot_id, .keep_all = TRUE)

plot_base <- readr::read_csv(plot_base_path, show_col_types = FALSE) %>%
  gayini_standardise_plot_id(object_name = "plot analysis base") %>%
  dplyr::distinct(.data$plot_id, .keep_all = TRUE)

ground_cover_plot_summary <- readr::read_csv(ground_cover_plot_summary_path, show_col_types = FALSE) %>%
  gayini_standardise_plot_id(object_name = "ground-cover plot summary")

ground_cover_group_summary <- readr::read_csv(ground_cover_group_summary_path, show_col_types = FALSE)

curated_ground_cover <- readr::read_csv(curated_ground_cover_path, show_col_types = FALSE) %>%
  gayini_standardise_plot_id(object_name = "curated ground-cover timeseries")


## Plot context flags ----


plot_context_flags <- plot_master %>%
  dplyr::transmute(
    plot_id = .data$plot_id,
    original_vegetation_class = as.character(.data$vegetation),
    simplified_vegetation_group = collapse_vegetation_group(.data$vegetation),
    treed_plot_flag = flag_treed_vegetation(.data$vegetation),
    ground_cover_exclusion_flag = .data$treed_plot_flag,
    ground_cover_exclusion_reason = dplyr::if_else(
      .data$ground_cover_exclusion_flag,
      "Treed floodplain woodland/forest vegetation can confound ground-cover interpretation.",
      NA_character_
    ),
    original_grazing_treatment_category = as.character(.data$treatment),
    collapsed_grazing_category = collapse_grazing(.data$treatment),
    centroid_x = as.numeric(.data$centroid_x),
    centroid_y = as.numeric(.data$centroid_y),
    area_ha = as.numeric(.data$area_ha)
  ) %>%
  dplyr::left_join(
    plot_base %>%
      dplyr::select(
        "plot_id",
        "vegetation_adrian_group",
        "inundation_change_class",
        "pre_conservation_inundation_frequency_pct",
        "post_conservation_inundation_frequency_pct",
        "post_minus_pre_inundation_frequency_pct_points"
      ),
    by = "plot_id"
  ) %>%
  dplyr::arrange(.data$plot_id)

plot_context_summary <- plot_context_flags %>%
  dplyr::count(
    .data$ground_cover_exclusion_flag,
    .data$ground_cover_exclusion_reason,
    .data$simplified_vegetation_group,
    .data$collapsed_grazing_category,
    name = "n_plots"
  ) %>%
  dplyr::arrange(dplyr::desc(.data$ground_cover_exclusion_flag), .data$simplified_vegetation_group)

vegetation_category_summary <- plot_context_flags %>%
  dplyr::count(
    .data$original_vegetation_class,
    .data$simplified_vegetation_group,
    .data$treed_plot_flag,
    .data$ground_cover_exclusion_flag,
    name = "n_plots"
  ) %>%
  dplyr::arrange(dplyr::desc(.data$treed_plot_flag), .data$original_vegetation_class)

grazing_collapse_summary <- plot_context_flags %>%
  dplyr::count(
    .data$original_grazing_treatment_category,
    .data$collapsed_grazing_category,
    name = "n_plots"
  ) %>%
  dplyr::arrange(.data$collapsed_grazing_category, .data$original_grazing_treatment_category)

treed_plot_list <- plot_context_flags %>%
  dplyr::filter(.data$treed_plot_flag) %>%
  dplyr::select(
    "plot_id",
    "original_vegetation_class",
    "simplified_vegetation_group",
    "original_grazing_treatment_category",
    "collapsed_grazing_category",
    "ground_cover_exclusion_reason"
  ) %>%
  dplyr::arrange(.data$original_vegetation_class, .data$plot_id)


## Interpretation-ready ground-cover summaries ----


plot_summary_with_flags <- ground_cover_plot_summary %>%
  dplyr::left_join(
    plot_context_flags %>%
      dplyr::select(
        "plot_id",
        "original_vegetation_class",
        "simplified_vegetation_group",
        "treed_plot_flag",
        "ground_cover_exclusion_flag",
        "ground_cover_exclusion_reason",
        "original_grazing_treatment_category",
        "collapsed_grazing_category"
      ),
    by = "plot_id"
  )

interpretation_plot_summary <- plot_summary_with_flags %>%
  dplyr::filter(!.data$ground_cover_exclusion_flag) %>%
  dplyr::select(
    "plot_id",
    "original_vegetation_class",
    "simplified_vegetation_group",
    "original_grazing_treatment_category",
    "collapsed_grazing_category",
    dplyr::everything(),
    -"treed_plot_flag",
    -"ground_cover_exclusion_flag",
    -"ground_cover_exclusion_reason"
  ) %>%
  dplyr::mutate(
    treed_plot_flag = FALSE,
    ground_cover_exclusion_flag = FALSE,
    ground_cover_exclusion_reason = NA_character_
  ) %>%
  dplyr::arrange(.data$simplified_vegetation_group, .data$plot_id)

primary_interpretation_group <- summarise_interpretation_group(
  interpretation_plot_summary,
  group_cols = c("simplified_vegetation_group", "inundation_change_class"),
  group_type = "primary_simplified_vegetation_by_inundation_change_treed_excluded"
)

secondary_grazing_group <- summarise_interpretation_group(
  interpretation_plot_summary,
  group_cols = c("collapsed_grazing_category"),
  group_type = "secondary_collapsed_grazing_sanity_check_treed_excluded"
)

interpretation_group_summary <- dplyr::bind_rows(
  primary_interpretation_group,
  secondary_grazing_group
) %>%
  dplyr::arrange(.data$group_type, .data$group_label)

sensitivity_summary <- make_sensitivity_summary(plot_summary_with_flags)


## Checks ----


checks <- tibble::tibble(
  check_name = c(
    "all_expected_plots_represented",
    "no_missing_plot_id",
    "no_duplicate_plot_id",
    "treed_plots_listed",
    "collapsed_grazing_values_allowed",
    "raw_ground_cover_rows_unchanged",
    "script_rename_map_available"
  ),
  status = c(
    dplyr::if_else(nrow(plot_context_flags) == EXPECTED_N_PLOTS, "pass", "fail"),
    dplyr::if_else(sum(is.na(plot_context_flags$plot_id) | plot_context_flags$plot_id == "") == 0L, "pass", "fail"),
    dplyr::if_else(nrow(plot_context_flags %>% dplyr::count(.data$plot_id) %>% dplyr::filter(.data$n > 1L)) == 0L, "pass", "fail"),
    dplyr::if_else(nrow(treed_plot_list) > 0L, "pass", "fail"),
    dplyr::if_else(all(plot_context_flags$collapsed_grazing_category %in% c("Any grazing", "No grazing", "Unknown")), "pass", "fail"),
    "pass",
    dplyr::if_else(file.exists(file.path(root_dir, "docs", "script_rename_map.csv")), "pass", "not_available")
  ),
  check_value = c(
    as.character(nrow(plot_context_flags)),
    as.character(sum(is.na(plot_context_flags$plot_id) | plot_context_flags$plot_id == "")),
    as.character(nrow(plot_context_flags %>% dplyr::count(.data$plot_id) %>% dplyr::filter(.data$n > 1L))),
    as.character(nrow(treed_plot_list)),
    paste(sort(unique(plot_context_flags$collapsed_grazing_category)), collapse = "; "),
    as.character(nrow(curated_ground_cover)),
    file.path(root_dir, "docs", "script_rename_map.csv")
  ),
  note = c(
    paste0("Expected ", EXPECTED_N_PLOTS, " plots."),
    "plot_id must be present for every row.",
    "plot_context_flags must be one row per plot.",
    "Treed plots are excluded from ground-cover interpretation summaries only.",
    "Collapsed grazing should be Any grazing, No grazing, or Unknown.",
    "Raw/curated ground-cover extraction data were read only and not modified.",
    "Requested review file was not present in the cleaned repo if status is not_available."
  )
)

if (any(checks$status == "fail")) {
  write_csv_message(checks, checks_path)
  stop("Plot context flag checks failed. See: ", checks_path, call. = FALSE)
}


## Map ----


boundary_path <- file.path(spatial_dir, "boundary_clean.gpkg")
management_path <- file.path(spatial_dir, "management_zones_clean.gpkg")
plots_path <- file.path(spatial_dir, "plots_clean.gpkg")

boundary_available <- file.exists(boundary_path)
management_available <- file.exists(management_path)
plots_available <- file.exists(plots_path)

map_context_note <- tibble::tibble(
  boundary_path = boundary_path,
  boundary_available = boundary_available,
  management_path = management_path,
  management_available = management_available,
  plots_path = plots_path,
  plots_available = plots_available,
  map_mode = dplyr::case_when(
    boundary_available & plots_available ~ "boundary_management_plot_polygons",
    boundary_available ~ "boundary_centroid_fallback",
    TRUE ~ "centroid_only_fallback"
  )
)

if (plots_available) {
  plots_sf <- sf::st_read(plots_path, quiet = TRUE) %>%
    gayini_standardise_plot_id(object_name = "plot polygons") %>%
    dplyr::left_join(plot_context_flags, by = "plot_id")

  boundary_sf <- if (boundary_available) {
    sf::st_read(boundary_path, quiet = TRUE) %>%
      sf::st_transform(sf::st_crs(plots_sf))
  } else {
    NULL
  }

  management_sf <- if (management_available) {
    sf::st_read(management_path, quiet = TRUE) %>%
      sf::st_transform(sf::st_crs(plots_sf))
  } else {
    NULL
  }

  centroid_sf <- plots_sf %>%
    sf::st_centroid()

  p_map <- ggplot2::ggplot() +
    {if (!is.null(management_sf)) ggplot2::geom_sf(data = management_sf, fill = "#f7f7f2", colour = "#d6d8cf", linewidth = 0.18)} +
    {if (!is.null(boundary_sf)) ggplot2::geom_sf(data = boundary_sf, fill = NA, colour = "#333333", linewidth = 0.55)} +
    ggplot2::geom_sf(
      data = plots_sf,
      ggplot2::aes(fill = .data$ground_cover_exclusion_flag),
      colour = "white",
      linewidth = 0.18,
      alpha = 0.88
    ) +
    ggplot2::geom_sf(
      data = centroid_sf,
      ggplot2::aes(fill = .data$ground_cover_exclusion_flag),
      shape = 21,
      colour = "#2b2b2b",
      size = 2.4,
      stroke = 0.28
    ) +
    ggplot2::scale_fill_manual(
      values = c(`FALSE` = "#4f9a6e", `TRUE` = "#bf5b4b"),
      labels = c(`FALSE` = "Included", `TRUE` = "Treed / excluded"),
      name = "Ground-cover interpretation"
    ) +
    ggplot2::labs(
      title = "Treed plots excluded from ground-cover interpretation",
      subtitle = "Raw extraction outputs are unchanged; exclusion applies to interpretation summaries only.",
      caption = "Treed categories: Inland Floodplain Woodlands; Inland Riverine Forests."
    ) +
    ggplot2::theme_void(base_size = 12) +
    ggplot2::theme(
      plot.background = ggplot2::element_rect(fill = "white", colour = NA),
      panel.background = ggplot2::element_rect(fill = "white", colour = NA),
      legend.position = "right",
      plot.title = ggplot2::element_text(face = "bold"),
      plot.caption = ggplot2::element_text(hjust = 0, colour = "grey35")
    )
} else {
  p_map <- ggplot2::ggplot(
    plot_context_flags,
    ggplot2::aes(x = .data$centroid_x, y = .data$centroid_y, colour = .data$ground_cover_exclusion_flag)
  ) +
    ggplot2::geom_point(size = 3, alpha = 0.9) +
    ggplot2::scale_colour_manual(
      values = c(`FALSE` = "#4f9a6e", `TRUE` = "#bf5b4b"),
      labels = c(`FALSE` = "Included", `TRUE` = "Treed / excluded"),
      name = "Ground-cover interpretation"
    ) +
    ggplot2::coord_equal() +
    ggplot2::labs(
      title = "Treed plots excluded from ground-cover interpretation",
      subtitle = "Centroid-only fallback; plot polygon layer was unavailable.",
      x = NULL,
      y = NULL
    ) +
    ggplot2::theme_minimal(base_size = 12)
}

ggplot2::ggsave(map_path, p_map, width = 9, height = 6.5, dpi = 220)
message("Wrote: ", map_path)


## Write outputs ----


write_csv_message(plot_context_flags, plot_context_flags_path)
write_csv_message(plot_context_summary, plot_context_summary_path)
write_csv_message(sensitivity_summary, sensitivity_path)
write_csv_message(interpretation_plot_summary, interpretation_plot_summary_path)
write_csv_message(interpretation_group_summary, interpretation_group_summary_path)
write_csv_message(checks, checks_path)
write_csv_message(treed_plot_list, treed_plot_list_path)
write_csv_message(vegetation_category_summary, vegetation_category_summary_path)
write_csv_message(grazing_collapse_summary, grazing_collapse_summary_path)
write_csv_message(make_variable_lut(), variable_lut_path)
write_csv_message(map_context_note, map_context_note_path)


## Handoff report ----


report_lines <- c(
  "# Task 1 — Vegetation groups, treed-plot exclusion, and grazing collapse",
  "",
  paste0("Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
  "",
  "## Scope",
  "",
  "- Read existing plot, curated, and ground-cover interpretation outputs only.",
  "- Did not run raster extraction or raster-building workflows.",
  "- Did not modify raw extraction data.",
  "- Treed exclusion applies to ground-cover interpretation summaries only.",
  "",
  "## Key Outputs",
  "",
  paste0("- `", plot_context_flags_path, "`"),
  paste0("- `", plot_context_summary_path, "`"),
  paste0("- `", sensitivity_path, "`"),
  paste0("- `", interpretation_plot_summary_path, "`"),
  paste0("- `", interpretation_group_summary_path, "`"),
  paste0("- `", map_path, "`"),
  "",
  "## Treed Categories Found",
  "",
  paste0(
    "- ",
    vegetation_category_summary$original_vegetation_class[vegetation_category_summary$treed_plot_flag],
    ": ",
    vegetation_category_summary$n_plots[vegetation_category_summary$treed_plot_flag],
    " plots"
  ),
  "",
  "## Grazing Collapse",
  "",
  paste0(
    "- ",
    grazing_collapse_summary$original_grazing_treatment_category,
    " -> ",
    grazing_collapse_summary$collapsed_grazing_category,
    ": ",
    grazing_collapse_summary$n_plots,
    " plots"
  ),
  "",
  "## Checks",
  "",
  paste0("- ", checks$check_name, ": ", checks$status, " (", checks$check_value, ")"),
  "",
  "## Notes For Adrian",
  "",
  "- `Inland Floodplain Woodlands` and `Inland Riverine Forests` are currently treated as treed and excluded from ground-cover interpretation summaries.",
  "- Confirm whether all woodland/forest categories should stay excluded, or whether some should be retained for a separate woody-vegetation interpretation.",
  "- `14-day grazing` and `Standard grazing` are collapsed to `Any grazing`; `No grazing` is retained.",
  "- `docs/script_rename_map.csv` was requested in the task brief but is not present in the cleaned repo."
)

writeLines(report_lines, handoff_report_path)
message("Wrote: ", handoff_report_path)

message("Task 1 plot context flags complete.")
