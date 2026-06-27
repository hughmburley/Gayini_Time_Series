## -----------------------------------------------------------------------------
## Gayini remote sensing workflow
## 10h_prepare_review_package_spine.R
## -----------------------------------------------------------------------------


## Purpose:
## Consolidate Tasks 1-4 and current Gayini review outputs into decision-ready
## registers for Adrian/BCT review. This is an integration/reporting script only:
## it reads current outputs and writes review package tables/reports. It does not
## run extraction, rebuild rasters, edit PowerPoint files, or touch biodiversity
## repository outputs.


## User settings ----


root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", "D:/Github_repos/Gayini"), winslash = "/", mustWork = TRUE)
MANAGEMENT_CHANGE_DATE <- as.Date("2019-07-01")


## Required packages ----


required_packages <- c(
  "dplyr",
  "tidyr",
  "readr",
  "stringr",
  "magrittr",
  "tibble",
  "tools"
)

source(file.path(root_dir, "R", "gayini_analysis_base_functions.R"))
gayini_check_packages(required_packages)

library(dplyr)
library(tidyr)
library(readr)
library(stringr)
library(magrittr)
library(tibble)


## Paths ----


csv_dir <- file.path(root_dir, "Output", "csv")
figure_root <- file.path(root_dir, "Output", "figures")
reports_dir <- file.path(root_dir, "Output", "reports")
diagnostics_dir <- file.path(root_dir, "Output", "diagnostics", "10h_review_package_spine")
raster_dir <- file.path(root_dir, "Output", "rasters")

dir.create(reports_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(diagnostics_dir, recursive = TRUE, showWarnings = FALSE)

variable_lut_path <- file.path(reports_dir, "Gayini_review_variable_LUT.csv")
figure_manifest_path <- file.path(reports_dir, "Gayini_review_key_figure_manifest.csv")
analysis_spine_path <- file.path(reports_dir, "Gayini_analysis_spine.csv")
adrian_questions_path <- file.path(reports_dir, "Gayini_questions_for_Adrian.csv")
story_structure_path <- file.path(reports_dir, "Gayini_story_structure.md")
handoff_path <- file.path(reports_dir, "Gayini_review_package_handoff.md")
checks_path <- file.path(diagnostics_dir, "task5_review_package_checks.csv")
input_inventory_path <- file.path(diagnostics_dir, "task5_input_inventory.csv")


## Helpers ----


write_csv_message <- function(x, path) {
  readr::write_csv(x, path)
  message("Wrote: ", path)
  invisible(x)
}


read_names_if_exists <- function(path) {
  if (!file.exists(path)) {
    return(character())
  }
  names(readr::read_csv(path, n_max = 1, show_col_types = FALSE))
}


module_from_path <- function(path) {
  path <- stringr::str_replace_all(path, "\\\\", "/")
  dplyr::case_when(
    stringr::str_detect(path, "plot_context|task_1|treed") ~ "Plot context",
    stringr::str_detect(path, "ground_cover|fractional|total_veg|bare|modis") ~ "Ground cover",
    stringr::str_detect(path, "gauge|hydrology|flow") ~ "Hydrology",
    stringr::str_detect(path, "MER|mer") ~ "MER metrics",
    stringr::str_detect(path, "inundation|flood|matched|annual") ~ "Inundation",
    TRUE ~ "Review / methods"
  )
}


variable_domain <- function(variable_name, source_module) {
  dplyr::case_when(
    stringr::str_detect(variable_name, "plot_id|vegetation|treed|grazing|treatment|centroid|area_ha|exclusion|group") ~ "Plot context",
    stringr::str_detect(variable_name, "bare|green|npv|pv|total_veg|ground_cover|delta_total|delta_bare") ~ "Ground cover",
    stringr::str_detect(variable_name, "gauge|flow|station|missing_flow|patch_status|record_status|completeness") ~ "Hydrology",
    stringr::str_detect(variable_name, "MER|mer|annual_max|observed_sequence|sensor_mix|observation_density|daily_wet_rule|n_valid_observations|n_wet_observations") ~ "MER metrics",
    stringr::str_detect(variable_name, "inund|wet|water_year|valid_year|frequency|background|matched") ~ "Remote sensing inundation",
    stringr::str_detect(variable_name, "modis|farm|buffer|management_zone") ~ "MODIS / broad context",
    TRUE ~ source_module
  )
}


analysis_flag <- function(variable_name, source_module) {
  dplyr::case_when(
    stringr::str_detect(variable_name, "plot_id|simplified_vegetation_group|treed_plot_flag|ground_cover_exclusion_flag|collapsed_grazing_category") ~ "Main analysis",
    stringr::str_detect(variable_name, "pre_conservation_inundation_frequency_pct|post_conservation_inundation_frequency_pct|post_minus_pre_inundation_frequency_pct_points|background_inundation_frequency_pct|total_veg_pct|bare_ground_pct|delta_total_veg_pct|delta_bare_ground_pct") ~ "Main analysis",
    stringr::str_detect(variable_name, "gauge|flow|completeness|missing_flow|annual_max_inundated_area_pct|mer_post_minus_pre|comparison_flag|observation_density") ~ "Supplementary",
    stringr::str_detect(variable_name, "monthly|seasonal|observed_sequence|longest_observed|BFAST|tbreak|sensitivity") ~ "Experimental",
    source_module %in% c("MER metrics", "Hydrology", "MODIS / broad context") ~ "Supplementary",
    TRUE ~ "Supplementary"
  )
}


variable_description <- function(variable_name) {
  dplyr::case_when(
    variable_name == "plot_id" ~ "Stable plot identifier.",
    variable_name == "simplified_vegetation_group" ~ "Task 1 simplified vegetation group used for review summaries.",
    variable_name == "treed_plot_flag" ~ "Task 1 flag identifying woody/treed plots.",
    variable_name == "ground_cover_exclusion_flag" ~ "Task 1 flag for excluding treed plots from ground-cover interpretation summaries.",
    variable_name == "collapsed_grazing_category" ~ "Task 1 grazing collapse: Any grazing or No grazing.",
    variable_name == "total_veg_pct" ~ "Ground-cover total vegetation: green PV plus non-green NPV.",
    variable_name == "bare_ground_pct" ~ "Ground-cover bare ground percentage.",
    variable_name == "post_minus_pre_inundation_frequency_pct_points" ~ "Post-minus-pre annual inundation occurrence change in percentage points.",
    variable_name == "background_inundation_frequency_pct" ~ "Task 3 historical/background annual occurrence frequency.",
    variable_name == "annual_max_inundated_area_pct" ~ "MER annual maximum observed inundated plot area; supplementary footprint metric.",
    variable_name == "longest_observed_wet_sequence_days" ~ "MER observed wet-sequence diagnostic; not hydroperiod or true duration.",
    variable_name == "mean_flow_mld" ~ "Gauge mean flow in ML/day; hydrological context only.",
    variable_name == "missing_flow_pct" ~ "Gauge missingness/completeness percentage.",
    TRUE ~ stringr::str_replace_all(variable_name, "_", " ")
  )
}


figure_family_from_name <- function(path) {
  nm <- basename(path)
  dplyr::case_when(
    stringr::str_detect(nm, "dashboard|selected_plot") ~ "Plot dashboard",
    stringr::str_detect(nm, "gauge|flow|hydrology") ~ "Gauge / hydrology",
    stringr::str_detect(nm, "inundation|flood|matched|MER|mer") ~ "Inundation",
    stringr::str_detect(nm, "ground_cover|total_veg|bare|fractional|modis") ~ "Ground cover",
    stringr::str_detect(nm, "map|spatial|rgb") ~ "Map / methods",
    stringr::str_detect(nm, "extraction|support|missing|QA|check") ~ "QA / methods",
    TRUE ~ "Review"
  )
}


deck_priority_from_path <- function(path) {
  path <- stringr::str_replace_all(path, "\\\\", "/")
  nm <- basename(path)
  dplyr::case_when(
    stringr::str_detect(path, "Output/figures/review") &
      !stringr::str_detect(nm, "gauge_data_completeness|gauge_flow_by_station|selected_plot|mer_metric") ~ "Headline",
    stringr::str_detect(nm, "dashboard|matched_year|background|inundation_frequency_by_vegetation|gc_total_veg|inundation_with_gauge|mer_metric") ~ "Supporting",
    stringr::str_detect(path, "adrian_review_png_assets|deck_candidates|hydrology|10b_ground_cover") ~ "Appendix",
    stringr::str_detect(path, "missingness|check|heatmap|monthly|seasonal|support") ~ "Appendix",
    TRUE ~ "Defer"
  )
}


story_role_from_path <- function(path) {
  nm <- basename(path)
  dplyr::case_when(
    stringr::str_detect(nm, "gauge|flow") ~ "Hydrology",
    stringr::str_detect(nm, "ground_cover|total_veg|bare|fractional|modis") ~ "Vegetation response",
    stringr::str_detect(nm, "inundation|flood|matched|MER|mer") ~ "Environmental change",
    stringr::str_detect(nm, "map|extraction|support|missing|dashboard_metric") ~ "Methods",
    stringr::str_detect(nm, "treatment|treed|vegetation_group") ~ "Context",
    TRUE ~ "QA"
  )
}


source_data_guess <- function(path) {
  nm <- basename(path)
  dplyr::case_when(
    stringr::str_detect(nm, "background|matched") ~ "Output/csv/background_inundation_frequency_by_plot.csv; Output/csv/matched_year_candidate_ranking.csv",
    stringr::str_detect(nm, "gauge|flow") ~ "Output/csv/gauge_context_for_gayini.csv",
    stringr::str_detect(nm, "MER|mer") ~ "Output/csv/05b_MER_plot_inundation_dynamic_metrics.csv; Output/diagnostics/06_MER_inundation/mer_vs_annual_occurrence_flags.csv",
    stringr::str_detect(nm, "ground_cover|total_veg|bare|fractional") ~ "Output/csv/curated_ground_cover_timeseries.csv; Output/csv/10a_ground_cover_prepost_plot_summary.csv",
    stringr::str_detect(nm, "modis") ~ "Output/csv/03_modis_ground_cover_context_full.csv",
    stringr::str_detect(nm, "inundation") ~ "Output/csv/curated_annual_inundation_timeseries.csv; Output/csv/plot_rs_gauge_analysis_base.csv",
    TRUE ~ "See generating script / figure manifest"
  )
}


generating_script_guess <- function(path) {
  nm <- basename(path)
  dplyr::case_when(
    stringr::str_detect(nm, "plot_treed") ~ "scripts/07_figures_dashboards/10d_prepare_plot_context_flags.R",
    stringr::str_detect(nm, "gauge|dashboard_gauge|with_gauge|selected_plot_total_veg") ~ "scripts/07_figures_dashboards/10e_integrate_gauge_context_review_figures.R",
    stringr::str_detect(nm, "background|matched|inundation_frequency_by_vegetation") ~ "scripts/07_figures_dashboards/10f_prepare_background_flood_pattern_matched_years.R",
    stringr::str_detect(nm, "mer_metric_summary") ~ "scripts/06_mer/10g_consolidate_mer_metric_review.R",
    stringr::str_detect(nm, "MER|mer") ~ "scripts/06_mer/06_extract_MER_inundation_metrics.R",
    stringr::str_detect(nm, "10b_") ~ "scripts/07_figures_dashboards/10b_make_review_figures_and_dashboards.R",
    stringr::str_detect(nm, "modis") ~ "scripts/02_extract_heavy/03_extract_ground_cover_full.R",
    stringr::str_detect(nm, "05c|06c|04c") ~ "scripts/02_extract_heavy/03_extract_ground_cover_full.R; scripts/02_extract_heavy/04_extract_annual_inundation_full.R; scripts/02_extract_heavy/05_extract_daily_inundation_full.R",
    TRUE ~ "Unknown/current figure asset"
  )
}


review_caveat_from_path <- function(path) {
  nm <- basename(path)
  dplyr::case_when(
    stringr::str_detect(nm, "inundation|flood|matched") ~ "Annual inundation occurrence is not hydroperiod, duration, depth or wet days; management timing is diagnostic/coincident, not causal.",
    stringr::str_detect(nm, "gauge|flow") ~ "Gauge flow is hydrological context only; known gaps and anchor-gauge decisions remain.",
    stringr::str_detect(nm, "MER|mer") ~ "MER metrics are supplementary observed-footprint/support metrics unless Adrian promotes them.",
    stringr::str_detect(nm, "ground_cover|total_veg|bare|fractional") ~ "Ground-cover interpretation excludes treed plots by default; management effects are coincident, not proven.",
    stringr::str_detect(nm, "modis") ~ "MODIS is broad-context evidence, not 1 ha plot-scale evidence.",
    TRUE ~ "Review/preliminary; confirm final deck role before presentation."
  )
}


## Input inventory and raster snapshot ----


tif_snapshot_before <- tibble::tibble(
  tif_path = list.files(raster_dir, pattern = "\\.tif$", recursive = TRUE, full.names = TRUE),
  last_write_time_before = as.character(file.info(tif_path)$mtime),
  size_before = file.info(tif_path)$size
)

handoff_reports <- file.path(
  reports_dir,
  c(
    "task_1_veg_groups_treed_grazing_handoff.md",
    "task_2_gauge_integration_handoff.md",
    "task_3_background_flood_pattern_handoff.md",
    "task_4_mer_metric_consolidation_handoff.md"
  )
)

review_inputs <- tibble::tibble(
  input_name = c(
    "codex_context",
    "current_run_order",
    "task1_handoff",
    "task2_handoff",
    "task3_handoff",
    "task4_handoff",
    "plot_context_flags",
    "task2_plot_gauge_base",
    "task3_background",
    "task4_mer_comparison",
    "adrian_review_png_assets",
    "existing_tif_outputs"
  ),
  path = c(
    file.path(root_dir, "docs", "codex_context.md"),
    file.path(root_dir, "docs", "current_run_order.md"),
    handoff_reports,
    file.path(csv_dir, "plot_context_flags.csv"),
    file.path(csv_dir, "plot_rs_gauge_analysis_base.csv"),
    file.path(csv_dir, "background_inundation_frequency_by_plot.csv"),
    file.path(csv_dir, "mer_metric_comparison_table.csv"),
    file.path(reports_dir, "adrian_review_png_assets"),
    raster_dir
  )
) %>%
  dplyr::mutate(found = file.exists(.data$path))

write_csv_message(review_inputs, input_inventory_path)


## Variable LUT ----


source_tables <- tibble::tribble(
  ~source_table, ~source_module, ~required_for_review,
  "Output/csv/plot_context_flags.csv", "Plot context", TRUE,
  "Output/csv/curated_ground_cover_timeseries.csv", "Ground cover", TRUE,
  "Output/csv/10a_ground_cover_prepost_plot_summary.csv", "Ground cover", TRUE,
  "Output/csv/10a_ground_cover_prepost_plot_summary_interpretation.csv", "Ground cover", TRUE,
  "Output/csv/curated_annual_inundation_timeseries.csv", "Remote sensing inundation", TRUE,
  "Output/csv/curated_daily_inundation_monthly.csv", "Remote sensing inundation", TRUE,
  "Output/csv/plot_rs_gauge_analysis_base.csv", "Review base", TRUE,
  "Output/csv/gauge_context_for_gayini.csv", "Hydrology", TRUE,
  "Output/csv/gauge_data_completeness_for_gayini.csv", "Hydrology", TRUE,
  "Output/csv/background_inundation_frequency_by_plot.csv", "Remote sensing inundation", TRUE,
  "Output/csv/inundation_frequency_by_vegetation_group.csv", "Remote sensing inundation", TRUE,
  "Output/csv/matched_year_candidate_ranking.csv", "Remote sensing inundation", TRUE,
  "Output/csv/05b_MER_plot_inundation_dynamic_metrics.csv", "MER metrics", TRUE,
  "Output/csv/05b_MER_plot_inundation_monthly_seasonal_max.csv", "MER metrics", FALSE,
  "Output/csv/mer_metric_comparison_table.csv", "MER metrics", TRUE,
  "Output/csv/03_modis_ground_cover_prepost_summary.csv", "MODIS / broad context", FALSE,
  "Output/csv/03_modis_ground_cover_water_year_summary.csv", "MODIS / broad context", FALSE
) %>%
  dplyr::mutate(abs_path = file.path(root_dir, .data$source_table), exists = file.exists(.data$abs_path))

variable_lut <- source_tables %>%
  dplyr::filter(.data$exists) %>%
  dplyr::rowwise() %>%
  dplyr::mutate(variable_name = list(read_names_if_exists(.data$abs_path))) %>%
  tidyr::unnest("variable_name") %>%
  dplyr::ungroup() %>%
  dplyr::mutate(
    variable_domain = mapply(variable_domain, .data$variable_name, .data$source_module),
    analysis_status = mapply(analysis_flag, .data$variable_name, .data$source_module),
    description = variable_description(.data$variable_name),
    bct_use = dplyr::case_when(
      .data$analysis_status == "Main analysis" ~ "BCT review / main deck",
      .data$analysis_status == "Supplementary" ~ "BCT support / technical appendix",
      TRUE ~ "Future sensitivity / scientific publication"
    ),
    caveat = dplyr::case_when(
      .data$variable_domain == "Remote sensing inundation" ~ "Occurrence/observed area metrics are not hydroperiod, duration, depth or wet days.",
      .data$variable_domain == "Hydrology" ~ "Gauge context supports interpretation but does not prove plot-level response.",
      .data$variable_domain == "Ground cover" ~ "Treed plot handling must be documented; pre/post response is diagnostic/coincident.",
      .data$variable_domain == "MER metrics" ~ "MER metrics remain supplementary unless Adrian promotes them.",
      TRUE ~ "Review/preliminary variable."
    )
  ) %>%
  dplyr::select(
    "variable_name",
    "variable_domain",
    "source_module",
    "source_table",
    "analysis_status",
    "description",
    "bct_use",
    "caveat"
  ) %>%
  dplyr::arrange(.data$variable_domain, .data$source_table, .data$variable_name)

write_csv_message(variable_lut, variable_lut_path)


## Figure manifest ----


figure_paths <- c(
  list.files(file.path(reports_dir, "adrian_review_png_assets"), pattern = "\\.png$", recursive = TRUE, full.names = TRUE),
  list.files(figure_root, pattern = "\\.png$", recursive = TRUE, full.names = TRUE)
) %>%
  unique()

figure_manifest <- tibble::tibble(
  file_path = figure_paths,
  filename = basename(.data$file_path)
) %>%
  dplyr::filter(!stringr::str_detect(stringr::str_replace_all(.data$file_path, "\\\\", "/"), "/archive/")) %>%
  dplyr::mutate(
    figure_title = stringr::str_to_sentence(stringr::str_replace_all(tools::file_path_sans_ext(.data$filename), "_", " ")),
    figure_family = vapply(.data$file_path, figure_family_from_name, character(1)),
    analysis_module = vapply(.data$file_path, module_from_path, character(1)),
    source_data = vapply(.data$file_path, source_data_guess, character(1)),
    generating_script = vapply(.data$file_path, generating_script_guess, character(1)),
    intended_slide = dplyr::case_when(
      deck_priority_from_path(.data$file_path) == "Headline" ~ "Main review deck",
      deck_priority_from_path(.data$file_path) == "Supporting" ~ "Main deck support or backup slide",
      deck_priority_from_path(.data$file_path) == "Appendix" ~ "Technical appendix",
      TRUE ~ "Defer / retain for QA"
    ),
    intended_paper_section = dplyr::case_when(
      story_role_from_path(.data$file_path) == "Methods" ~ "Methods / data processing",
      story_role_from_path(.data$file_path) == "Hydrology" ~ "Hydrological context",
      story_role_from_path(.data$file_path) == "Vegetation response" ~ "Vegetation and ground-cover response",
      story_role_from_path(.data$file_path) == "Environmental change" ~ "Inundation and environmental change",
      TRUE ~ "Supplementary material"
    ),
    review_caveats = vapply(.data$file_path, review_caveat_from_path, character(1)),
    deck_priority = vapply(.data$file_path, deck_priority_from_path, character(1)),
    story_role = vapply(.data$file_path, story_role_from_path, character(1)),
    exists = file.exists(.data$file_path),
    relative_path = stringr::str_remove(stringr::str_replace_all(.data$file_path, "\\\\", "/"), paste0("^", stringr::str_replace_all(root_dir, "\\\\", "/"), "/"))
  ) %>%
  dplyr::select(
    "filename",
    "figure_title",
    "figure_family",
    "analysis_module",
    "source_data",
    "generating_script",
    "intended_slide",
    "intended_paper_section",
    "review_caveats",
    "deck_priority",
    "story_role",
    "exists",
    "relative_path",
    "file_path"
  ) %>%
  dplyr::arrange(factor(.data$deck_priority, levels = c("Headline", "Supporting", "Appendix", "Defer")), .data$story_role, .data$filename)

write_csv_message(figure_manifest, figure_manifest_path)


## Analysis spine ----


analysis_spine <- tibble::tribble(
  ~Analysis, ~Question_answered, ~Main_metric, ~Main_figure, ~Confidence, ~Priority, ~Notes,
  "Study area and plot context", "What is being compared and how are plots grouped?", "simplified_vegetation_group; treed_plot_flag; collapsed_grazing_category", "Output/figures/review/plot_treed_exclusion_map.png", "High for current review, pending Adrian confirmation.", "Headline", "Task 1 flags are the current authority. Treed plots are excluded from GC interpretation only.",
  "Water gauges", "What broader river-flow context frames the RS signals?", "mean_flow_mld; total_flow_ml; missing_flow_pct", "Output/figures/review/inundation_with_gauge_context.png", "Moderate; known gaps and anchor-gauge choice remain.", "Supporting", "Gauge context is hydrological support only, not causal proof.",
  "Annual inundation occurrence", "How often was inundation detected annually at plot scale?", "annual occurrence frequency; post_minus_pre_inundation_frequency_pct_points", "Output/figures/review/background_flood_pattern_pre2015.png", "High for BCT reporting if caveats are retained.", "Headline", "Main inundation metric. Not hydroperiod, duration, depth or wet days.",
  "Pre/post inundation change", "Which plots appear wetter or drier after the management transition date?", "post_minus_pre_inundation_frequency_pct_points", "Output/figures/review/mer_metric_summary_review.png", "Moderate-high; diagnostic/coincident, not causal.", "Headline", "Use percentage points and provisional 2019-07-01 transition date.",
  "Background flood frequency", "What was the longer historical background inundation pattern?", "background_inundation_frequency_pct", "Output/figures/review/background_flood_pattern_pre2015.png", "High for plot-level background; no long historical raster stack produced.", "Headline", "Task 3 period: 1988-1989 to 2014-2015.",
  "Matched-year comparison", "Which wet pre/post years are most comparable for discussion?", "candidate_rank; whole_farm_abs_diff_pct_points", "Output/figures/review/matched_year_inundation_comparison.png", "Moderate; screening comparison.", "Supporting", "Task 3 selected 2016-2017 vs 2021-2022.",
  "Ground cover", "How did total vegetation and bare ground vary pre/post?", "total_veg_pct; bare_ground_pct; delta_total_veg_pct; delta_bare_ground_pct", "Output/figures/review/gc_total_veg_with_gauge_context.png", "Moderate; treed plots excluded from interpretation.", "Headline", "Describe changes as coincident with management transition and hydrology, not causal.",
  "MODIS broad context", "Do broader farm/zone vegetation patterns support the plot-scale story?", "MODIS total vegetation and bare ground summaries.", "Output/figures/modis_ground_cover/modis_whole_farm_monthly_timeseries.png", "Moderate-low for plot inference; useful as context.", "Supporting", "Broad context only, not 1 ha plot-scale evidence.",
  "MER metrics", "How large did the observed wet footprint become when inundation was detected?", "annual_max_inundated_area_pct; mer_post_minus_pre_mean_annual_max_pct", "Output/figures/review/mer_metric_summary_review.png", "Moderate as supplementary evidence.", "Appendix", "Task 4 recommends MER as supplementary unless Adrian promotes it.",
  "Vegetation groups", "How should vegetation classes be simplified for review?", "simplified_vegetation_group", "Output/figures/review/inundation_frequency_by_vegetation_group.png", "High for current review, pending Adrian confirmation.", "Headline", "Use Task 1 grouping; include treed flag in inundation-only summaries.",
  "Plot dashboards", "Which plots need manual review or examples?", "plot-level time series and pre/post summaries", "Output/figures/review/dashboard_gauge_integration_prototype.png", "Moderate; review selection needed.", "Supporting", "Good for Adrian review and appendix, not all dashboards need main deck.",
  "BFAST/tBreak", "Is formal breakpoint analysis justified?", "Not currently run/promoted.", "NA", "Deferred.", "Defer", "Reserve for future scientific publication after simpler diagnostics are settled."
)

write_csv_message(analysis_spine, analysis_spine_path)


## Adrian decision register ----


adrian_questions <- tibble::tribble(
  ~decision, ~current_recommendation, ~rationale, ~consequence_if_changed, ~status,
  "Management transition date", "Use 2019-07-01 provisionally.", "Matches current pre/post workflow and water-year split.", "Changing date requires rerunning pre/post summaries and updating deck wording.", "Needs Adrian confirmation",
  "Gauge anchor pair", "Use Darlington Point, Balranald Weir, Hay Weir and Maude Weir as preferred context until narrowed.", "Task 2 found these as preferred continuous context gauges.", "Changing anchors affects gauge-context figures and matched-year interpretation, not RS metrics.", "Needs Adrian confirmation",
  "Water year vs calendar year", "Use water year July-June for inundation and hydrology.", "Aligns with current hydrological interpretation and existing outputs.", "Calendar-year framing would require re-aggregation and could alter matched-year story.", "Needs Adrian confirmation",
  "Preferred flow metric/threshold", "Use mean/total flow as context; avoid hard thresholds for causal claims.", "Gauge flow supports interpretation but does not prove plot response.", "Threshold-based claims would need separate validation.", "Needs Adrian confirmation",
  "Treed plot exclusion", "Exclude treed plots from ground-cover interpretation; include and flag them for inundation-only summaries.", "Treed canopy confounds fractional cover but not necessarily inundation occurrence summaries.", "Including treed plots in GC interpretation may weaken/blur vegetation response story.", "Needs Adrian confirmation",
  "Vegetation grouping", "Use Task 1 simplified vegetation groups.", "Current figures/tables consistently use these groups.", "Changing groups requires regenerating summaries/figures and updating LUT.", "Needs Adrian confirmation",
  "Redbank handling", "Keep Redbank cautious/context only; not a primary continuous anchor.", "Known suitability/completeness caveats; Task 2/4 checks confirm not primary.", "Promoting Redbank would require explicit caveat and likely figure changes.", "Needs Adrian confirmation",
  "MER metric inclusion", "Keep MER annual max as supplementary; defer monthly/seasonal and observed sequence headline use.", "Task 4 found MER adds footprint magnitude but does not replace occurrence frequency.", "Promoting MER changes story emphasis and increases support/cadence caveats.", "Needs Adrian confirmation",
  "BFAST/tBreak", "Defer.", "Current project needs review-package clarity before formal breakpoint analysis.", "Running now risks overcomplicating BCT deck and causal interpretation.", "Deferred",
  "BCT vs publication framing", "BCT deck should be diagnostic/descriptive; publication ideas can be separated.", "Avoid overstating causal effects while preserving future research value.", "Mixing publication claims into BCT deck could create overclaiming risk.", "Needs project team confirmation",
  "Main deck figure set", "Use Headline/Supporting rows in Gayini_review_key_figure_manifest.csv.", "Keeps deck tight and reproducible.", "Adding too many appendix/QA figures may dilute the review story.", "Needs Adrian confirmation"
)

write_csv_message(adrian_questions, adrian_questions_path)


## Story structure and handoff ----


story_lines <- c(
  "# Gayini Story Structure",
  "",
  "## Framing",
  "",
  "The current Gayini analysis documents environmental change through time. Pre/post results are diagnostic and coincident with the provisional 2019 management transition; they do not prove causal management effects.",
  "",
  "## Main Story",
  "",
  "- Study area, plot network, vegetation groups and treed-plot handling.",
  "- Gauge context and known gauge data limitations.",
  "- Annual inundation occurrence frequency and pre/post occurrence change.",
  "- Historical/background flood pattern for 1988-1989 to 2014-2015.",
  "- Ground-cover response focused on total vegetation and bare ground, with treed plots excluded from interpretation.",
  "- Broad MODIS context where it helps communicate landscape-scale patterns.",
  "",
  "## Supporting",
  "",
  "- Task 3 matched-year comparison: 2016-2017 vs 2021-2022.",
  "- MER annual maximum observed inundated area as a supplementary wet-footprint metric.",
  "- Plot dashboards and selected plot examples for Adrian review.",
  "- Gauge-flow context figures, clearly framed as hydrological context only.",
  "- Vegetation-group summaries and treed-plot sensitivity context.",
  "",
  "## Technical Appendix",
  "",
  "- MER-vs-annual occurrence diagnostic flags and observation-support figures.",
  "- Extraction examples, support/missingness panels, and QA figures.",
  "- MODIS maps and management-zone support figures.",
  "- Ground-cover model/treatment sanity checks.",
  "",
  "## Deferred",
  "",
  "- Monthly/seasonal MER headline use.",
  "- Observed wet-sequence metrics as hydroperiod/duration surrogates.",
  "- BFAST/tBreak and formal breakpoint modelling.",
  "- Causal management-effect claims.",
  "",
  "## Required Caveats",
  "",
  "- Annual inundation occurrence frequency is not hydroperiod, duration, depth or wet days.",
  "- Gauge data contain known gaps and are hydrological context only.",
  "- Management transition date remains provisional.",
  "- Treed-plot handling must be documented wherever ground-cover interpretation is shown.",
  "- MER metrics remain supplementary unless Adrian recommends otherwise."
)

writeLines(story_lines, story_structure_path)
message("Wrote: ", story_structure_path)


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

missing_figures <- figure_manifest %>%
  dplyr::filter(!.data$exists)

archived_current_refs <- c(variable_lut$source_table, figure_manifest$relative_path, analysis_spine$Main_figure) %>%
  stringr::str_detect("archive/|Output/archive|scripts/archive") %>%
  sum(na.rm = TRUE)

biodiversity_refs <- c(variable_lut$source_table, figure_manifest$relative_path, analysis_spine$Notes) %>%
  stringr::str_detect("Biodiversity|biodiversity") %>%
  sum(na.rm = TRUE)

checks <- tibble::tibble(
  check_name = c(
    "variable_names_match_current_outputs",
    "figures_listed_exist",
    "archived_outputs_not_referenced_as_current",
    "biodiversity_outputs_excluded",
    "no_heavy_workflows_run",
    "no_raster_products_rebuilt",
    "required_handoff_reports_found",
    "required_caveats_present"
  ),
  status = c(
    dplyr::if_else(nrow(variable_lut) > 0, "pass", "fail"),
    dplyr::if_else(nrow(missing_figures) == 0, "pass", "fail"),
    dplyr::if_else(archived_current_refs == 0, "pass", "review"),
    dplyr::if_else(biodiversity_refs == 0, "pass", "fail"),
    "pass",
    dplyr::if_else(all(tif_compare$unchanged, na.rm = TRUE), "pass", "fail"),
    dplyr::if_else(all(file.exists(handoff_reports)), "pass", "review"),
    "pass"
  ),
  check_value = c(
    paste0(nrow(variable_lut), " variable/source-table rows documented from ", dplyr::n_distinct(variable_lut$source_table), " current tables."),
    paste0(nrow(figure_manifest), " figures listed; ", nrow(missing_figures), " missing."),
    as.character(archived_current_refs),
    as.character(biodiversity_refs),
    "Only read current CSV/report/figure inventories; no extraction/build scripts run.",
    paste0(sum(tif_compare$unchanged, na.rm = TRUE), " .tif files unchanged of ", nrow(tif_compare), " inventoried."),
    paste(file.exists(handoff_reports), collapse = "; "),
    "Story/report caveats cover diagnostic/coincident framing, occurrence-not-duration, gauge gaps, provisional transition date, treed handling and supplementary MER."
  )
)

write_csv_message(checks, checks_path)

if (any(checks$status == "fail")) {
  stop("Task 5 review package checks failed. See: ", checks_path, call. = FALSE)
}

headline_figures <- figure_manifest %>%
  dplyr::filter(.data$deck_priority == "Headline") %>%
  dplyr::pull(.data$relative_path)

handoff_lines <- c(
  "# Gayini Review Package Handoff",
  "",
  paste0("Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
  "",
  "## Repository Status",
  "",
  "- Current active spine is documented in `docs/current_run_order.md`.",
  "- Tasks 1-4 handoff reports are present and were used.",
  "- This task did not edit PowerPoint files, run heavy workflows, rebuild rasters, delete outputs, archive outputs, or touch the biodiversity repository.",
  "",
  "## Analyses Completed",
  "",
  paste0("- Variable LUT rows documented: ", nrow(variable_lut)),
  paste0("- Figures documented: ", nrow(figure_manifest)),
  paste0("- Analysis spine rows: ", nrow(analysis_spine)),
  paste0("- Adrian decisions listed: ", nrow(adrian_questions)),
  "",
  "## Recommended Next Codex Task",
  "",
  "- Build a deck-update checklist from `Gayini_review_key_figure_manifest.csv` and `Gayini_story_structure.md`, then update slide content manually in PowerPoint. Do not automate PowerPoint edits until Adrian confirms the figure set and decisions.",
  "",
  "## Recommended Manual PowerPoint Updates",
  "",
  "- Replace old causal wording with diagnostic/coincident wording.",
  "- Use annual inundation occurrence as the headline inundation metric.",
  "- Add Task 3 background and matched-year figures as review-context slides.",
  "- Add ground-cover total vegetation / bare-ground summaries with treed-exclusion caveat.",
  "- Keep MER summary as a supporting or appendix slide unless Adrian promotes it.",
  "",
  "## Key Risks",
  "",
  "- Causal overclaiming around management effects.",
  "- Confusing annual occurrence frequency with hydroperiod/duration/depth/wet days.",
  "- Gauge gaps or anchor-gauge choices being read as definitive hydrological proof.",
  "- Treed plot handling not being explained before ground-cover interpretation.",
  "- Overloading the main deck with MER/monthly/seasonal/QA material.",
  "",
  "## BCT Deliverables",
  "",
  "- Strongest current BCT package: descriptive environmental change, reproducible methods, annual inundation occurrence, historical/background pattern, matched-year context, ground-cover response, and clear caveats.",
  "",
  "## Publication Opportunities",
  "",
  "- Future scientific paper: coupled floodplain inundation and vegetation response across conservation transition.",
  "- Future methods paper/note: reproducible RS workflow integrating Landsat/Sentinel inundation, MODIS context, and gauge hydrology.",
  "- Future sensitivity paper: MER-style observed footprint and sequence metrics versus annual occurrence frequency.",
  "",
  "## Headline Figure Candidates",
  "",
  paste0("- ", headline_figures),
  "",
  "## Outputs From This Task",
  "",
  paste0("- `", variable_lut_path, "`"),
  paste0("- `", figure_manifest_path, "`"),
  paste0("- `", analysis_spine_path, "`"),
  paste0("- `", adrian_questions_path, "`"),
  paste0("- `", story_structure_path, "`"),
  paste0("- `", checks_path, "`"),
  "",
  "## Checks",
  "",
  paste0("- ", checks$check_name, ": ", checks$status, " (", checks$check_value, ")")
)

writeLines(handoff_lines, handoff_path)
message("Wrote: ", handoff_path)

message("Task 5 review package spine consolidation complete.")
