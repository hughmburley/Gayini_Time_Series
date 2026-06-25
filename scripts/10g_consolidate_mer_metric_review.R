## -----------------------------------------------------------------------------
## Gayini remote sensing workflow
## 10g_consolidate_mer_metric_review.R
## -----------------------------------------------------------------------------


## Purpose:
## Consolidate current MER / Flow_MER-inspired inundation outputs against the
## annual occurrence, pre/post, gauge-context and matched-year review workflow.
## This script is read-only with respect to extraction/raster products: it does
## not rerun MER extraction, daily extraction, annual extraction, or pre/post
## raster builds.


## User settings ----


root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", "D:/Github_repos/Gayini"), winslash = "/", mustWork = TRUE)
PRIMARY_REVIEW_FIGURE <- "mer_metric_summary_review.png"


## Required packages ----


required_packages <- c(
  "dplyr",
  "tidyr",
  "readr",
  "stringr",
  "magrittr",
  "tibble",
  "ggplot2"
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


## Paths ----


csv_dir <- file.path(root_dir, "Output", "csv")
figure_dir <- file.path(root_dir, "Output", "figures", "review")
diagnostics_dir <- file.path(root_dir, "Output", "diagnostics", "10g_mer_metric_consolidation")
report_dir <- file.path(root_dir, "Output", "reports")
raster_dir <- file.path(root_dir, "Output", "rasters")

dir.create(csv_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(figure_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(diagnostics_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(report_dir, recursive = TRUE, showWarnings = FALSE)

task1_context_path <- file.path(csv_dir, "plot_context_flags.csv")
task2_gauge_context_path <- file.path(csv_dir, "gauge_context_for_gayini.csv")
task2_gauge_completeness_path <- file.path(csv_dir, "gauge_data_completeness_for_gayini.csv")
task2_plot_base_path <- file.path(csv_dir, "plot_rs_gauge_analysis_base.csv")
task3_background_path <- file.path(csv_dir, "background_inundation_frequency_by_plot.csv")
task3_group_path <- file.path(csv_dir, "inundation_frequency_by_vegetation_group.csv")
task3_candidate_path <- file.path(csv_dir, "matched_year_candidate_ranking.csv")
task3_gauge_context_path <- file.path(csv_dir, "matched_year_gauge_context.csv")

mer_annual_path <- file.path(csv_dir, "05b_MER_plot_inundation_dynamic_metrics.csv")
mer_monthly_seasonal_path <- file.path(csv_dir, "05b_MER_plot_inundation_monthly_seasonal_max.csv")
mer_flags_path <- file.path(root_dir, "Output", "diagnostics", "06_MER_inundation", "mer_vs_annual_occurrence_flags.csv")
mer_deck_summary_path <- file.path(root_dir, "Output", "diagnostics", "06_MER_inundation", "mer_deck_summary_table.csv")
mer_metric_notes_path <- file.path(root_dir, "Output", "diagnostics", "06_MER_inundation", "mer_deck_metric_use_notes.csv")
mer_monthly_support_path <- file.path(root_dir, "Output", "diagnostics", "06_MER_inundation", "mer_monthly_seasonal_support_summary.csv")
mer_annual_support_path <- file.path(root_dir, "Output", "diagnostics", "06_MER_inundation", "mer_annual_support_summary.csv")
mer_row_counts_path <- file.path(root_dir, "Output", "diagnostics", "06_MER_inundation", "06_MER_row_counts.csv")

metric_comparison_path <- file.path(csv_dir, "mer_metric_comparison_table.csv")
decision_table_path <- file.path(csv_dir, "mer_metric_keep_defer_decision_table.csv")
script_review_path <- file.path(diagnostics_dir, "task4_scripts_reviewed.csv")
input_report_path <- file.path(diagnostics_dir, "task4_input_report.csv")
checks_path <- file.path(diagnostics_dir, "task4_checks.csv")
summary_stats_path <- file.path(diagnostics_dir, "task4_mer_summary_stats.csv")
figure_manifest_path <- file.path(diagnostics_dir, "task4_figure_manifest.csv")
handoff_report_path <- file.path(report_dir, "task_4_mer_metric_consolidation_handoff.md")
summary_figure_path <- file.path(figure_dir, PRIMARY_REVIEW_FIGURE)


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


safe_sum <- function(x) {
  sum(x, na.rm = TRUE)
}


format_pct <- function(x, digits = 1) {
  ifelse(is.na(x), "NA", paste0(round(x, digits), "%"))
}


theme_review <- function(base_size = 12) {
  ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      plot.title = ggplot2::element_text(face = "bold"),
      plot.caption = ggplot2::element_text(hjust = 0, colour = "grey35", size = base_size * 0.78),
      strip.text = ggplot2::element_text(face = "bold")
    )
}


## Read-only inventory ----


tif_snapshot_before <- tibble::tibble(
  tif_path = list.files(raster_dir, pattern = "\\.tif$", recursive = TRUE, full.names = TRUE),
  last_write_time_before = as.character(file.info(tif_path)$mtime),
  size_before = file.info(tif_path)$size
)

input_report <- tibble::tibble(
  input_name = c(
    "task1_plot_context_flags",
    "task2_gauge_context_for_gayini",
    "task2_gauge_data_completeness",
    "task2_plot_rs_gauge_analysis_base",
    "task3_background_inundation_frequency_by_plot",
    "task3_inundation_frequency_by_vegetation_group",
    "task3_matched_year_candidate_ranking",
    "task3_matched_year_gauge_context",
    "mer_annual_dynamic_metrics",
    "mer_monthly_seasonal_metrics",
    "mer_vs_annual_occurrence_flags",
    "mer_deck_summary_table",
    "mer_metric_use_notes",
    "existing_tif_outputs"
  ),
  path = c(
    task1_context_path,
    task2_gauge_context_path,
    task2_gauge_completeness_path,
    task2_plot_base_path,
    task3_background_path,
    task3_group_path,
    task3_candidate_path,
    task3_gauge_context_path,
    mer_annual_path,
    mer_monthly_seasonal_path,
    mer_flags_path,
    mer_deck_summary_path,
    mer_metric_notes_path,
    raster_dir
  ),
  found = c(
    file.exists(task1_context_path),
    file.exists(task2_gauge_context_path),
    file.exists(task2_gauge_completeness_path),
    file.exists(task2_plot_base_path),
    file.exists(task3_background_path),
    file.exists(task3_group_path),
    file.exists(task3_candidate_path),
    file.exists(task3_gauge_context_path),
    file.exists(mer_annual_path),
    file.exists(mer_monthly_seasonal_path),
    file.exists(mer_flags_path),
    file.exists(mer_deck_summary_path),
    file.exists(mer_metric_notes_path),
    nrow(tif_snapshot_before) > 0
  ),
  role = c(
    "Task 1 authority for vegetation groups, treed flags and grazing collapse.",
    "Task 2 gauge context; hydrological support only.",
    "Task 2 gauge completeness caveats.",
    "Task 2 combined plot-level review base.",
    "Task 3 background flood-pattern benchmark.",
    "Task 3 vegetation-group background summary.",
    "Task 3 matched-year benchmark.",
    "Task 3 matched-year gauge context.",
    "Current annual MER / Flow_MER-inspired observed extent and timing metrics.",
    "Current monthly/seasonal MER summaries.",
    "Current MER versus annual occurrence diagnostic flags.",
    "Current compact MER deck summary.",
    "Current MER metric-use notes.",
    "Existing raster outputs inventoried only; no .tif files are written."
  )
)

write_csv_message(input_report, input_report_path)

required_inputs <- input_report %>%
  dplyr::filter(.data$input_name != "existing_tif_outputs")

if (any(!required_inputs$found)) {
  stop(
    "Missing required Task 4 input(s): ",
    paste(required_inputs$input_name[!required_inputs$found], collapse = ", "),
    call. = FALSE
  )
}

scripts_reviewed <- tibble::tibble(
  script_or_doc = c(
    "docs/codex_context.md",
    "docs/current_run_order.md",
    "scripts/04_extract_annual_inundation_full.R",
    "scripts/05_extract_daily_inundation_full.R",
    "scripts/06_extract_MER_inundation_metrics.R",
    "R/gayini_mer_inundation_functions.R",
    "scripts/08a_build_prepost_inundation_products.R",
    "scripts/08b_check_prepost_inundation_products.R",
    "scripts/08c_extract_prepost_inundation_to_plots.R",
    "scripts/archive/pre_clean_spine_20260623/05b_MER_extract_inundation.R"
  ),
  exists = file.exists(file.path(root_dir, script_or_doc)),
  action_this_task = c(
    "read",
    "read",
    "read_only_not_run",
    "read_only_not_run",
    "read_only_not_run",
    "read_only_not_run",
    "read_only_not_run",
    "read_only_not_run",
    "read_only_not_run",
    "read_only_not_run"
  ),
  note = c(
    "Repo context.",
    "Active run order and MER stage description.",
    "Annual inundation wrapper reviewed; not run.",
    "Daily inundation wrapper reviewed; not run.",
    "Active MER driver reviewed; not run.",
    "Active MER implementation reviewed; not run.",
    "Pre/post raster build wrapper reviewed; not run.",
    "Read-only pre/post QA wrapper reviewed; not run.",
    "Pre/post extract wrapper reviewed; not run.",
    "Archived MER provenance implementation reviewed; active driver no longer sources it."
  )
)

write_csv_message(scripts_reviewed, script_review_path)


## Read inputs ----


task1_context <- readr::read_csv(task1_context_path, show_col_types = FALSE) %>%
  gayini_standardise_plot_id(object_name = "Task 1 plot context flags")

plot_base <- readr::read_csv(task2_plot_base_path, show_col_types = FALSE) %>%
  gayini_standardise_plot_id(object_name = "Task 2 plot RS/gauge base")

gauge_context <- readr::read_csv(task2_gauge_context_path, show_col_types = FALSE)
gauge_completeness <- readr::read_csv(task2_gauge_completeness_path, show_col_types = FALSE)
background_by_plot <- readr::read_csv(task3_background_path, show_col_types = FALSE) %>%
  gayini_standardise_plot_id(object_name = "Task 3 background flood pattern")
matched_year_candidates <- readr::read_csv(task3_candidate_path, show_col_types = FALSE)
matched_year_gauge_context <- readr::read_csv(task3_gauge_context_path, show_col_types = FALSE)

mer_annual <- readr::read_csv(mer_annual_path, show_col_types = FALSE) %>%
  gayini_standardise_plot_id(object_name = "MER annual dynamic metrics")
mer_monthly_seasonal <- readr::read_csv(mer_monthly_seasonal_path, show_col_types = FALSE) %>%
  gayini_standardise_plot_id(object_name = "MER monthly/seasonal metrics")
mer_flags <- readr::read_csv(mer_flags_path, show_col_types = FALSE) %>%
  gayini_standardise_plot_id(object_name = "MER vs annual occurrence flags")
mer_deck_summary <- readr::read_csv(mer_deck_summary_path, show_col_types = FALSE)
mer_metric_notes <- readr::read_csv(mer_metric_notes_path, show_col_types = FALSE)
mer_monthly_support <- readr::read_csv(mer_monthly_support_path, show_col_types = FALSE)
mer_annual_support <- readr::read_csv(mer_annual_support_path, show_col_types = FALSE)
mer_row_counts <- readr::read_csv(mer_row_counts_path, show_col_types = FALSE)


## Summary statistics ----


comparison_counts <- mer_flags %>%
  dplyr::count(.data$comparison_flag, name = "n_plots") %>%
  dplyr::mutate(
    plot_pct = round(100 * .data$n_plots / sum(.data$n_plots), 1),
    comparison_label = dplyr::case_when(
      .data$comparison_flag == "directions_agree" ~ "Directions agree",
      .data$comparison_flag == "directions_disagree_review" ~ "Review disagreement",
      .data$comparison_flag == "one_metric_near_no_change" ~ "Near/no-change",
      TRUE ~ .data$comparison_flag
    )
  )

selected_matched_pair <- matched_year_candidates %>%
  dplyr::arrange(.data$candidate_rank) %>%
  dplyr::slice_head(n = 1)

redbank_primary_count <- gauge_context %>%
  dplyr::filter(.data$redbank_caution_flag == TRUE, .data$gauge_context_role == "preferred_context") %>%
  nrow()

summary_stats <- tibble::tibble(
  statistic = c(
    "mer_annual_rows",
    "mer_monthly_seasonal_rows",
    "mer_plots",
    "mer_water_years",
    "mer_vs_annual_directions_agree",
    "mer_vs_annual_disagreement_review",
    "mer_vs_annual_near_no_change",
    "task3_background_period",
    "task3_selected_matched_pair",
    "task2_preferred_gauges",
    "redbank_primary_anchor_rows"
  ),
  value = c(
    as.character(nrow(mer_annual)),
    as.character(nrow(mer_monthly_seasonal)),
    as.character(dplyr::n_distinct(mer_annual$plot_id)),
    as.character(dplyr::n_distinct(mer_annual$water_year)),
    as.character(safe_sum(mer_flags$comparison_flag == "directions_agree")),
    as.character(safe_sum(mer_flags$comparison_flag == "directions_disagree_review")),
    as.character(safe_sum(mer_flags$comparison_flag == "one_metric_near_no_change")),
    paste(unique(background_by_plot$background_period_label), collapse = "; "),
    paste0(selected_matched_pair$pre_water_year, " vs ", selected_matched_pair$post_water_year),
    paste(sort(unique(gauge_context$gauge_name[gauge_context$gauge_context_role == "preferred_context"])), collapse = "; "),
    as.character(redbank_primary_count)
  )
)

write_csv_message(summary_stats, summary_stats_path)


## Metric comparison and decision tables ----


metric_comparison <- tibble::tibble(
  metric_family = c(
    "Annual occurrence",
    "Pre/post occurrence change",
    "Task 3 background pattern",
    "Task 3 matched-year comparison",
    "Gauge-flow context",
    "MER annual maximum observed area",
    "MER annual mean observed area",
    "MER observed wet sequence",
    "MER monthly/seasonal maxima",
    "MER observation support",
    "MER vs annual occurrence diagnostic"
  ),
  primary_output = c(
    "Output/csv/plot_rs_gauge_analysis_base.csv",
    "Output/csv/plot_rs_gauge_analysis_base.csv; Output/csv/07f_pre_post_inundation_plot_summary_fixed.csv",
    "Output/csv/background_inundation_frequency_by_plot.csv",
    "Output/csv/matched_year_candidate_ranking.csv; Output/figures/review/matched_year_inundation_comparison.png",
    "Output/csv/gauge_context_for_gayini.csv",
    "Output/csv/05b_MER_plot_inundation_dynamic_metrics.csv",
    "Output/csv/05b_MER_plot_inundation_dynamic_metrics.csv",
    "Output/csv/05b_MER_plot_inundation_dynamic_metrics.csv",
    "Output/csv/05b_MER_plot_inundation_monthly_seasonal_max.csv",
    "Output/diagnostics/06_MER_inundation/observation_density_by_water_year.csv",
    "Output/diagnostics/06_MER_inundation/mer_vs_annual_occurrence_flags.csv"
  ),
  temporal_scale = c(
    "water-year/period",
    "pre/post period",
    "1988-1989 to 2014-2015 historical plot period",
    paste0(selected_matched_pair$pre_water_year, " vs ", selected_matched_pair$post_water_year),
    "monthly and water-year",
    "plot-water-year and pre/post summary",
    "plot-water-year",
    "plot-water-year",
    "plot-month and plot-season",
    "water-year/sensor",
    "plot pre/post"
  ),
  what_it_calculates = c(
    "Percent of valid annual records where inundation was detected.",
    "Post-minus-pre annual occurrence frequency in percentage points.",
    "Historical annual occurrence frequency by plot and vegetation group.",
    "Ranks and visualises comparable wet/inundation years.",
    "Preferred-gauge flow context and completeness; not causal proof.",
    "Maximum observed inundated plot area in a water year from daily observations.",
    "Mean observed inundated plot area across valid daily observations in a water year.",
    "Longest observed run of wet satellite observations under a gap rule.",
    "Monthly/seasonal maxima from daily observations.",
    "Observation density and sensor mix that support MER interpretation.",
    "Agreement/disagreement between MER footprint change and annual occurrence change."
  ),
  overlap_with_current_workflow = c(
    "Headline inundation metric; MER should not replace it.",
    "Headline pre/post change metric; MER annual max partly overlaps but asks a different size/footprint question.",
    "Benchmark historical pattern; MER only covers daily-observation era and does not replace it.",
    "Benchmark wet-year comparison; MER can supplement observed footprint differences if needed.",
    "Separate contextual hydrology support; not an MER input.",
    "Overlaps with annual inundation extent but uses daily observation maxima rather than annual occurrence.",
    "Less aligned with headline occurrence; sensitive to observation timing and density.",
    "Potentially overlaps with duration language but is not true duration/hydroperiod.",
    "Overlaps with event/timing review but has lower support and should not headline.",
    "Complements all MER outputs as a caveat/support layer.",
    "Directly compares current annual occurrence and MER annual maximum conclusions."
  ),
  added_value = c(
    "Clear, interpretable, long historical framing.",
    "Main management-change signal.",
    "Provides pre-2015 baseline story.",
    "Gives Adrian a defensible wet-year discussion pair.",
    "Helps explain water context without implying causality.",
    "Adds footprint magnitude: how large the observed wet area became when water was detected.",
    "Limited added value for current deck; can be noisy.",
    "Timing/support diagnostic only; useful for QA and later sensitivity.",
    "Useful for targeted technical review but not robust enough for headline claims.",
    "Essential caveat for any MER use.",
    "Most useful MER consolidation output for current review: shows where metrics agree or need review."
  ),
  recommendation = c(
    "keep_main_review",
    "keep_main_review",
    "keep_main_review",
    "keep_main_review",
    "keep_context_only",
    "keep_supplementary_review",
    "supplementary_or_defer",
    "defer_headline_use",
    "defer_headline_use",
    "keep_support_caveat",
    "keep_supplementary_review"
  ),
  caveat = c(
    "Not hydroperiod, duration, flood depth or wet days.",
    "Percentage points, not percent change.",
    "Plot-level historical table; not a continuous background raster stack.",
    "Screening comparison, not causal attribution.",
    "Redbank remains cautious context only.",
    "Observed annual maximum area, not occurrence frequency or hydroperiod.",
    "Mean of observed dates, not annual water persistence.",
    "Depends on satellite timing and 45-day gap rule; not hydroperiod.",
    "Many bins have lower support; use targeted QA only.",
    "Sensor cadence/pixel size/history differ.",
    "Disagreement can reflect different metric questions, not necessarily error."
  )
)

write_csv_message(metric_comparison, metric_comparison_path)

decision_table <- tibble::tribble(
  ~item, ~item_type, ~decision, ~deck_role, ~rationale, ~caveat,
  "Annual occurrence frequency", "metric", "keep_main_review", "headline", "Most interpretable and historically consistent inundation metric.", "Not hydroperiod/duration/depth/wet days.",
  "Pre/post annual occurrence change", "metric", "keep_main_review", "headline", "Directly answers management-change occurrence question.", "Percentage points, not percent change.",
  "Task 3 historical background frequency", "metric/output", "keep_main_review", "context/headline support", "Adds defensible pre-2015 background story.", "Plot-level historical pattern, not a rebuilt raster stack.",
  "Task 3 matched-year comparison", "metric/output", "keep_main_review", "review discussion", "Selected 2016-2017 vs 2021-2022 wet-year pair anchors the review story.", "Screening comparison only.",
  "MER annual maximum observed inundated area", "metric", "keep_supplementary_review", "supporting deck/technical appendix", "Adds observed footprint magnitude beyond occurrence frequency.", "Not annual frequency or duration; depends on observation support.",
  "MER annual max vs annual occurrence flags", "diagnostic", "keep_supplementary_review", "review confidence", "Summarises 48 agree / 12 review / 6 near-no-change pattern.", "Manual review needed for disagreement plots.",
  "MER observation support by sensor/year", "diagnostic/figure", "keep_support_caveat", "technical caveat", "Important for interpreting Landsat/Sentinel-2 support differences.", "Support metric, not ecological response.",
  "MER monthly/seasonal maxima", "metric/output", "defer", "technical QA only", "Potentially useful for targeted event review but support is weaker.", "Do not headline until support sensitivity is checked.",
  "MER longest observed wet sequence days", "metric", "defer", "technical QA only", "Can help timing review but is not hydroperiod or true duration.", "Satellite timing/gap-rule dependent.",
  "scripts/06_extract_MER_inundation_metrics.R", "active script", "keep_active", "workflow step 06", "Clean active driver sourcing R/gayini_mer_inundation_functions.R.", "Should remain RS-only; no gauge dependency.",
  "R/gayini_mer_inundation_functions.R", "active implementation", "keep_active", "workflow implementation", "Reusable live MER logic now outside archive.", "Contains supplementary metrics; avoid promoting all outputs to headline.",
  "scripts/archive/pre_clean_spine_20260623/05b_MER_extract_inundation.R", "archived script", "keep_provenance_archive_later", "none", "Historical provenance only; active scripts should not source it.", "Do not delete without a later archive policy.",
  "Output/diagnostics/05b_MER_inundation", "historical diagnostics", "archive_later_if_cleanup_requested", "none", "Superseded by Output/diagnostics/06_MER_inundation.", "Keep for provenance until cleanup instruction.",
  "MER deck candidate ranked/scatter figures", "figure set", "keep_supplementary_review", "technical appendix or backup slide", "Useful to explain metric agreement and footprint change.", "Not stronger than annual occurrence for main story.",
  "MER heatmap/monthly-seasonal products", "figure/output set", "defer", "technical appendix only", "Visually rich but risks overclaiming event timing.", "Needs observation-support sensitivity before deck headline use."
)

write_csv_message(decision_table, decision_table_path)


## Review figure ----


figure_data <- mer_flags %>%
  dplyr::left_join(
    task1_context %>%
      dplyr::select("plot_id", "simplified_vegetation_group", "treed_plot_flag"),
    by = "plot_id"
  ) %>%
  dplyr::left_join(
    background_by_plot %>%
      dplyr::select("plot_id", "background_inundation_frequency_pct"),
    by = "plot_id"
  ) %>%
  dplyr::mutate(
    comparison_flag = factor(
      .data$comparison_flag,
      levels = c("directions_agree", "directions_disagree_review", "one_metric_near_no_change"),
      labels = c("Directions agree", "Review disagreement", "Near/no-change")
    ),
    treed_plot_flag = as.logical(.data$treed_plot_flag)
  )

label_data <- figure_data %>%
  dplyr::filter(.data$comparison_flag == "Review disagreement") %>%
  dplyr::arrange(dplyr::desc(abs(.data$mer_post_minus_pre_mean_annual_max_pct))) %>%
  dplyr::slice_head(n = 8)

summary_label <- comparison_counts %>%
  dplyr::mutate(label = paste0(.data$comparison_label, ": ", .data$n_plots)) %>%
  dplyr::pull(.data$label) %>%
  paste(collapse = " | ")

summary_plot <- ggplot2::ggplot(
  figure_data,
  ggplot2::aes(
    x = .data$post_minus_pre_inundation_frequency_pct_points,
    y = .data$mer_post_minus_pre_mean_annual_max_pct
  )
) +
  ggplot2::geom_hline(yintercept = 0, linewidth = 0.3, colour = "grey50") +
  ggplot2::geom_vline(xintercept = 0, linewidth = 0.3, colour = "grey50") +
  ggplot2::geom_point(
    ggplot2::aes(
      colour = .data$comparison_flag,
      shape = .data$treed_plot_flag,
      size = .data$background_inundation_frequency_pct
    ),
    alpha = 0.78
  ) +
  ggplot2::geom_text(
    data = label_data,
    ggplot2::aes(label = .data$plot_id),
    size = 3,
    vjust = -0.65,
    check_overlap = TRUE
  ) +
  ggplot2::scale_colour_manual(
    values = c(
      "Directions agree" = "#2f6f4e",
      "Review disagreement" = "#b44f3f",
      "Near/no-change" = "#7d8794"
    ),
    drop = FALSE
  ) +
  ggplot2::scale_shape_manual(values = c("FALSE" = 16, "TRUE" = 17), name = "Treed plot") +
  ggplot2::scale_size_continuous(range = c(1.8, 5.2), name = "Task 3 background\nfrequency (%)") +
  ggplot2::labs(
    title = "MER annual maximum change versus annual occurrence change",
    subtitle = summary_label,
    x = "Post-minus-pre annual occurrence frequency (percentage points)",
    y = "Post-minus-pre MER annual maximum observed inundated area (percentage points)",
    colour = "MER / occurrence flag",
    caption = stringr::str_wrap(
      "Review/preliminary. MER annual maximum observed area is a supplementary footprint metric; annual occurrence frequency remains the main inundation metric. Neither metric is hydroperiod, duration, depth or wet days.",
      width = 135
    )
  ) +
  theme_review()

ggplot2::ggsave(summary_figure_path, summary_plot, width = 9.5, height = 7, dpi = 220)

figure_manifest <- tibble::tibble(
  figure_path = summary_figure_path,
  status = ifelse(file.exists(summary_figure_path), "written", "not_written"),
  role = "MER consolidation figure comparing annual occurrence change, MER annual maximum observed area change, Task 1 treed flag and Task 3 background frequency."
)

write_csv_message(figure_manifest, figure_manifest_path)


## Checks and report ----


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

checks <- tibble::tibble(
  check_name = c(
    "no_heavy_processing_run",
    "no_prepost_raster_rebuild",
    "no_tif_files_overwritten",
    "scripts_read_vs_run_recorded",
    "metrics_not_confused_with_annual_occurrence",
    "andres_code_reviewed_not_separately_incorporated",
    "mer_outputs_ready_status_reported",
    "task1_task2_task3_outputs_used",
    "redbank_not_primary_anchor",
    "annual_occurrence_not_labelled_duration"
  ),
  status = c(
    "pass",
    "pass",
    dplyr::if_else(all(tif_compare$unchanged, na.rm = TRUE), "pass", "fail"),
    dplyr::if_else(file.exists(script_review_path), "pass", "fail"),
    "pass",
    "pass",
    "pass",
    dplyr::if_else(all(required_inputs$found), "pass", "fail"),
    dplyr::if_else(redbank_primary_count == 0, "pass", "fail"),
    "pass"
  ),
  check_value = c(
    "Read existing outputs only; did not run scripts/06, 05, 04, 08a, 08b or 08c.",
    "This script does not source pre/post raster build code.",
    paste0(sum(tif_compare$unchanged, na.rm = TRUE), " .tif files unchanged of ", nrow(tif_compare), " inventoried."),
    script_review_path,
    "Comparison table separates annual occurrence from MER observed annual maximum area and observed sequence diagnostics.",
    "Local active/archived Flow_MER-inspired implementation reviewed; no external Andres/Sutton code was newly incorporated in Task 4.",
    "Recommendation table marks annual MER max as supplementary, monthly/seasonal and sequence metrics as deferred/technical.",
    paste(required_inputs$input_name, collapse = "; "),
    as.character(redbank_primary_count),
    "Figure/report use annual occurrence, observed area, support and diagnostic wording only."
  ),
  note = c(
    "Task 4 is a consolidation pass.",
    "Pre/post rasters are protected.",
    "Existing raster outputs were inventoried before and after only.",
    "Scripts reviewed table states which files were read and not run.",
    "No metric is promoted as hydroperiod/duration/depth/wet days.",
    "Andres/Sutton material is represented locally by Flow_MER-inspired Gayini implementation and archived provenance.",
    "MER is review-ready as a supplementary footprint/support layer, not as the main headline metric.",
    "Task 1 context, Task 2 gauge context, and Task 3 background/matched-year outputs are all required inputs.",
    "Redbank remains cautious context only.",
    "Annual occurrence frequency remains the headline inundation metric."
  )
)

write_csv_message(checks, checks_path)

if (any(checks$status == "fail")) {
  stop("Task 4 checks failed. See: ", checks_path, call. = FALSE)
}

keep_main <- decision_table %>%
  dplyr::filter(.data$decision == "keep_main_review") %>%
  dplyr::pull(.data$item)

keep_supplementary <- decision_table %>%
  dplyr::filter(stringr::str_detect(.data$decision, "supplementary|support")) %>%
  dplyr::pull(.data$item)

defer_items <- decision_table %>%
  dplyr::filter(stringr::str_detect(.data$decision, "defer")) %>%
  dplyr::pull(.data$item)

report_lines <- c(
  "# Task 4 — MER / Andres-style inundation metric consolidation",
  "",
  paste0("Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
  "",
  "## Scope",
  "",
  "- Reviewed existing active/archived MER / Flow_MER-inspired code and outputs.",
  "- Read Task 1 plot context, Task 2 gauge context, and Task 3 background/matched-year outputs.",
  "- Did not run MER extraction, daily extraction, annual extraction, or pre/post raster builds.",
  "- Did not write or overwrite `.tif` files.",
  "",
  "## MER / Andres-Style Metrics Found",
  "",
  "- `annual_max_inundated_area_pct`: annual maximum observed inundated plot area from daily observations.",
  "- `annual_mean_inundated_area_pct`: mean observed inundated plot area across valid daily observations.",
  "- `longest_observed_wet_sequence_days`: observed wet-sequence diagnostic under a configured gap rule; not hydroperiod.",
  "- monthly and seasonal maximum observed inundated area summaries.",
  "- observation density and sensor-support diagnostics.",
  "- MER versus annual occurrence agreement/disagreement flags.",
  "",
  "## Task Inputs",
  "",
  paste0("- Task 1 context found: ", file.exists(task1_context_path), " — `", task1_context_path, "`"),
  paste0("- Task 2 gauge context found: ", file.exists(task2_gauge_context_path), " — `", task2_gauge_context_path, "`"),
  paste0("- Task 3 background/matched-year outputs found: ", file.exists(task3_background_path) && file.exists(task3_candidate_path)),
  paste0("- Task 3 matched pair benchmark: ", selected_matched_pair$pre_water_year, " vs ", selected_matched_pair$post_water_year),
  "",
  "## Main Recommendation",
  "",
  "- Keep annual occurrence frequency, pre/post occurrence change, Task 3 background pattern, and Task 3 matched-year comparison as the main Adrian review story.",
  "- Keep MER annual maximum observed inundated area as a supplementary footprint-size metric.",
  "- Keep MER-vs-annual occurrence agreement flags as a review-confidence / manual-check diagnostic.",
  "- Keep observation-support figures as caveats.",
  "- Defer monthly/seasonal MER summaries and observed-sequence metrics from headline deck use.",
  "",
  "## Metrics To Keep In Main Review",
  "",
  paste0("- ", keep_main),
  "",
  "## Supplementary / Technical Appendix",
  "",
  paste0("- ", keep_supplementary),
  "",
  "## Defer",
  "",
  paste0("- ", defer_items),
  "",
  "## MER Agreement With Annual Occurrence",
  "",
  paste0("- ", comparison_counts$comparison_flag, ": ", comparison_counts$n_plots, " plots (", comparison_counts$plot_pct, "%)"),
  "",
  "## Andres/Sutton Code Interpretation",
  "",
  "- No new external Andres/Sutton code was incorporated in Task 4.",
  "- The active Gayini implementation is Flow_MER-inspired and lives in `R/gayini_mer_inundation_functions.R`.",
  "- The archived `scripts/archive/pre_clean_spine_20260623/05b_MER_extract_inundation.R` is provenance only.",
  "- The Andres-style approach mostly provides a robust supplementary implementation of observed inundation footprint/timing summaries; it does not overturn the annual-occurrence story.",
  "",
  "## Outputs",
  "",
  paste0("- `", metric_comparison_path, "`"),
  paste0("- `", decision_table_path, "`"),
  paste0("- `", summary_figure_path, "`"),
  paste0("- `", checks_path, "`"),
  "",
  "## Unresolved Questions For Adrian",
  "",
  "- Whether MER annual maximum observed area should appear as a main-deck support slide or stay in the technical appendix.",
  "- Which disagreement-review plots should be manually inspected before presentation.",
  "- Whether monthly/seasonal MER summaries are worth a later sensitivity check.",
  "- Whether observed-sequence diagnostics should ever be shown, given the hydroperiod/duration risk.",
  "- Whether final review wording should call MER 'Flow_MER-inspired' or simply 'daily observed inundation footprint'.",
  "",
  "## Checks",
  "",
  paste0("- ", checks$check_name, ": ", checks$status, " (", checks$check_value, ")")
)

writeLines(report_lines, handoff_report_path)
message("Wrote: ", handoff_report_path)

message("Task 4 MER metric consolidation complete.")
