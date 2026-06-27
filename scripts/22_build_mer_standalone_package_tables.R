## -----------------------------------------------------------------------------
## Gayini remote sensing workflow
## 22_build_mer_standalone_package_tables.R
## -----------------------------------------------------------------------------

## Purpose:
## Build the lightweight tables, figure copies, and asset-pack updates needed for
## the standalone MER / Flow-MER-inspired communication package. This script reads
## existing curated MER and annual-occurrence outputs only. It does not run daily
## extraction, MER extraction, raster extraction, or raster rebuilding.


## Settings ----


root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", "D:/Github_repos/Gayini"), winslash = "/", mustWork = TRUE)
task_name <- "Codex Task 9 - Standalone MER analysis package"
task_date <- Sys.Date()


## Packages ----


required_packages <- c("dplyr", "readr", "stringr", "magrittr", "tibble")

source(file.path(root_dir, "R", "gayini_analysis_base_functions.R"))
source(file.path(root_dir, "R", "gayini_output_helpers.R"))
source(file.path(root_dir, "R", "gayini_mer_helpers.R"))
gayini_check_packages(required_packages)

library(dplyr)
library(readr)
library(stringr)
library(magrittr)
library(tibble)


## Paths ----


csv_dir <- file.path(root_dir, "Output", "csv")
mer_csv_dir <- file.path(csv_dir, "MER")
figure_dir <- file.path(root_dir, "Output", "figures", "review")
mer_figure_dir <- file.path(figure_dir, "MER")
report_dir <- file.path(root_dir, "Output", "reports")
mer_report_dir <- file.path(report_dir, "MER")
diagnostics_dir <- file.path(root_dir, "Output", "diagnostics", "22_mer_standalone_package")

gayini_ensure_dir(mer_csv_dir)
gayini_ensure_dir(mer_figure_dir)
gayini_ensure_dir(mer_report_dir)
gayini_ensure_dir(diagnostics_dir)

flags_path <- file.path(root_dir, "Output", "diagnostics", "06_MER_inundation", "mer_vs_annual_occurrence_flags.csv")
review_shortlist_path <- file.path(root_dir, "Output", "diagnostics", "06_MER_inundation", "mer_plot_review_shortlist.csv")
deck_summary_path <- file.path(root_dir, "Output", "diagnostics", "06_MER_inundation", "mer_deck_summary_table.csv")
metric_comparison_path <- file.path(csv_dir, "mer_metric_comparison_table.csv")
keep_defer_path <- file.path(csv_dir, "mer_metric_keep_defer_decision_table.csv")
mer_dynamic_path <- file.path(csv_dir, "05b_MER_plot_inundation_dynamic_metrics.csv")
mer_monthly_path <- file.path(csv_dir, "05b_MER_plot_inundation_monthly_seasonal_max.csv")
annual_occurrence_path <- file.path(csv_dir, "07f_pre_post_inundation_plot_summary_fixed.csv")
asset_register_path <- file.path(report_dir, "Gayini_ppt_asset_register.csv")

task8_mer_compare_path <- file.path(figure_dir, "mer_vs_annual_inundation_change_comparison.png")
task8_mer_change_path <- file.path(figure_dir, "mer_change_result_main_deck.png")
task4_mer_summary_path <- file.path(figure_dir, "mer_metric_summary_review.png")

required_inputs <- c(
  flags = flags_path,
  metric_comparison = metric_comparison_path,
  keep_defer = keep_defer_path,
  mer_dynamic = mer_dynamic_path,
  annual_occurrence = annual_occurrence_path,
  task8_mer_compare = task8_mer_compare_path,
  task8_mer_change = task8_mer_change_path
)

missing_inputs <- names(required_inputs)[!file.exists(required_inputs)]
if (length(missing_inputs) > 0L) {
  stop("Missing required Task 9 input(s): ", paste(missing_inputs, collapse = ", "), call. = FALSE)
}


## Helpers ----


normalise_path <- function(path) {
  normalizePath(path, winslash = "/", mustWork = FALSE)
}

copy_with_log <- function(source_path, destination_path, role) {
  gayini_ensure_dir(destination_path, path_is_file = TRUE)
  copied <- file.copy(source_path, destination_path, overwrite = TRUE)
  source_info <- file.info(source_path)
  tibble::tibble(
    source_path = normalise_path(source_path),
    destination_path = normalise_path(destination_path),
    role = role,
    source_exists = file.exists(source_path),
    copied = copied,
    destination_exists = file.exists(destination_path),
    size_bytes = ifelse(file.exists(source_path), source_info$size, NA_real_)
  )
}

make_output_row <- function(file_path, file_type, metric, recommended_use, deck_or_appendix, notes) {
  tibble::tibble(
    file_path = normalise_path(file_path),
    file_type = file_type,
    metric = metric,
    recommended_use = recommended_use,
    deck_or_appendix = deck_or_appendix,
    notes = notes
  )
}

make_asset_row <- function(asset_id, file_path, title, deck_priority, asset_status, notes) {
  info <- file.info(file_path)
  tibble::tibble(
    asset_id = asset_id,
    filename = basename(file_path),
    full_path = normalise_path(file_path),
    file_type = tools::file_ext(file_path),
    file_modified_date = if (file.exists(file_path)) format(info$mtime, "%Y-%m-%dT%H:%M:%S") else NA_character_,
    figure_or_table_title = title,
    analysis_module = "MER",
    story_role = "Supplementary inundation footprint context",
    recommended_slide = "Standalone MER review deck / optional main-deck support slide",
    deck_priority = deck_priority,
    asset_status = asset_status,
    supersedes = NA_character_,
    superseded_by = NA_character_,
    source_script = "scripts/22_build_mer_standalone_package_tables.R",
    source_data = "Existing MER and annual occurrence outputs",
    review_caveat = paste("Plot-based / plot-centroid MER comparison.", gayini_mer_caveat_text("comparison")),
    notes = paste(notes, "updated_by_task_9 = TRUE")
  )
}


## Read inputs ----


flags <- readr::read_csv(flags_path, show_col_types = FALSE) %>%
  gayini_standardise_plot_id(object_name = "MER vs annual occurrence flags")

review_shortlist <- if (file.exists(review_shortlist_path)) {
  readr::read_csv(review_shortlist_path, show_col_types = FALSE) %>%
    gayini_standardise_plot_id(object_name = "MER review shortlist")
} else {
  tibble::tibble()
}

deck_summary <- if (file.exists(deck_summary_path)) {
  readr::read_csv(deck_summary_path, show_col_types = FALSE)
} else {
  tibble::tibble()
}

metric_comparison <- readr::read_csv(metric_comparison_path, show_col_types = FALSE)
keep_defer <- readr::read_csv(keep_defer_path, show_col_types = FALSE)
mer_dynamic <- readr::read_csv(mer_dynamic_path, show_col_types = FALSE)
mer_monthly <- if (file.exists(mer_monthly_path)) readr::read_csv(mer_monthly_path, show_col_types = FALSE) else tibble::tibble()
annual_occurrence <- readr::read_csv(annual_occurrence_path, show_col_types = FALSE)


## Agreement summary outputs ----


agreement_summary <- flags %>%
  dplyr::count(.data$comparison_flag, name = "plot_count") %>%
  dplyr::mutate(
    agreement_category = dplyr::case_when(
      .data$comparison_flag == "directions_agree" ~ "Directions agree",
      .data$comparison_flag == "directions_disagree_review" ~ "Directions disagree / review",
      .data$comparison_flag == "one_metric_near_no_change" ~ "One metric near no change",
      TRUE ~ .data$comparison_flag
    ),
    interpretation = dplyr::case_when(
      .data$comparison_flag == "directions_agree" ~ "MER annual maximum observed area and annual occurrence change point in the same broad direction.",
      .data$comparison_flag == "directions_disagree_review" ~ "The two metrics point in different directions; this is a review flag, not automatically an error.",
      .data$comparison_flag == "one_metric_near_no_change" ~ "At least one metric is close to no change, so the comparison should not be over-interpreted.",
      TRUE ~ "Review category."
    ),
    recommended_review_action = dplyr::case_when(
      .data$comparison_flag == "directions_agree" ~ "Use as supporting confidence context if the plot is otherwise deck-relevant.",
      .data$comparison_flag == "directions_disagree_review" ~ "Inspect plot history, observation support and spatial context before deck use.",
      .data$comparison_flag == "one_metric_near_no_change" ~ "Keep as neutral/contextual unless Adrian needs a threshold example.",
      TRUE ~ "Review before use."
    ),
    notes = dplyr::case_when(
      .data$comparison_flag == "directions_agree" ~ "Agreement supports complementarity between metrics.",
      .data$comparison_flag == "directions_disagree_review" ~ "Disagreement may reflect metric definitions: frequency versus largest observed footprint.",
      .data$comparison_flag == "one_metric_near_no_change" ~ "Near-zero changes are sensitive to threshold and display choices.",
      TRUE ~ NA_character_
    )
  ) %>%
  dplyr::select("agreement_category", "plot_count", "interpretation", "recommended_review_action", "notes") %>%
  dplyr::arrange(match(.data$agreement_category, c("Directions agree", "Directions disagree / review", "One metric near no change")))

plot_review_flags <- flags %>%
  dplyr::transmute(
    plot_id = .data$plot_id,
    vegetation_group = dplyr::coalesce(
      if ("vegetation_adrian_group" %in% names(.)) .data$vegetation_adrian_group else NA_character_,
      if ("vegetation" %in% names(.)) .data$vegetation else NA_character_,
      NA_character_
    ),
    treed_plot_flag = NA,
    annual_occurrence_change = .data$post_minus_pre_inundation_frequency_pct_points,
    MER_metric_change = .data$mer_post_minus_pre_mean_annual_max_pct,
    agreement_category = dplyr::case_when(
      .data$comparison_flag == "directions_agree" ~ "Directions agree",
      .data$comparison_flag == "directions_disagree_review" ~ "Directions disagree / review",
      .data$comparison_flag == "one_metric_near_no_change" ~ "One metric near no change",
      TRUE ~ .data$comparison_flag
    ),
    review_flag = .data$comparison_flag == "directions_disagree_review",
    notes = dplyr::case_when(
      .data$comparison_flag == "directions_disagree_review" ~ "Review flag: annual occurrence frequency and MER annual maximum observed footprint answer different questions.",
      .data$comparison_flag == "one_metric_near_no_change" ~ "Near no change in at least one metric.",
      TRUE ~ "Directions agree."
    )
  )

gayini_write_csv(agreement_summary, file.path(mer_csv_dir, "mer_vs_annual_occurrence_agreement_summary.csv"))
gayini_write_csv(plot_review_flags, file.path(mer_csv_dir, "mer_vs_annual_occurrence_plot_review_flags.csv"))


## Metric and inventory tables ----


date_range_dynamic <- mer_dynamic %>%
  dplyr::summarise(
    first_water_year = min(.data$water_year, na.rm = TRUE),
    last_water_year = max(.data$water_year, na.rm = TRUE)
  )

metric_definitions <- tibble::tribble(
  ~metric_name, ~metric_family, ~calculation, ~units, ~interpretation, ~main_caveat, ~recommended_use, ~main_deck_appendix_defer,
  "Annual occurrence frequency", "Main annual occurrence workflow", "100 * wet valid water years / valid water years", "Percent", "How often inundation was detected in valid annual records.", "Not hydroperiod, duration, depth or wet days.", "Headline Gayini inundation-change metric.", "Main deck",
  "Post-minus-pre annual occurrence change", "Main annual occurrence workflow", "Post-conservation annual occurrence frequency minus pre-conservation annual occurrence frequency", "Percentage points", "Broad direction and magnitude of pre/post occurrence change.", "Percentage points, not percent change; not causal proof.", "Headline pre/post inundation-change metric.", "Main deck",
  "MER annual maximum observed inundated area", "MER / daily observed footprint", "Maximum plot area observed inundated within each water year from daily RS observations", "Percent plot area", "Largest observed wet footprint in a year.", "Not hydroperiod or duration; observation support varies by sensor/year.", "Supplementary event-footprint context.", "Supporting / appendix",
  "MER post-minus-pre mean annual max observed area", "MER / daily observed footprint", "Post mean annual maximum observed area minus pre mean annual maximum observed area", "Percentage points", "Whether largest observed wet footprint was larger or smaller post-management.", "Plot-based comparison; no true MER raster surface currently exists.", "One optional main-deck support slide; otherwise technical appendix.", "Supporting / appendix",
  "MER monthly/seasonal maxima", "MER / daily observed footprint", "Maximum observed inundated area within month or season bins", "Percent plot area", "Targeted timing diagnostics.", "Many bins have low observation support.", "QA / targeted review only.", "Defer",
  "Longest observed wet sequence", "MER sequence diagnostic", "Longest sequence of observed wet satellite dates under configured gap rule", "Days", "Timing/support diagnostic from observed image sequence.", "Not hydroperiod, duration or wet days.", "Technical appendix only if needed.", "Defer",
  "MER vs annual occurrence agreement flag", "Comparison diagnostic", "Compares direction of annual occurrence change with MER annual maximum observed area change", "Category", "Identifies agreement and plots for manual review.", "Disagreement is not automatically an error.", "Review confidence and triage.", "Supporting / appendix"
)

input_files <- tibble::tribble(
  ~file_path, ~file_type, ~role, ~date_range, ~spatial_unit, ~notes,
  flags_path, "CSV", "MER versus annual occurrence comparison flags", paste0(date_range_dynamic$first_water_year, " to ", date_range_dynamic$last_water_year), "plot", "Canonical agreement/disagreement source for Task 9.",
  mer_dynamic_path, "CSV", "Annual MER dynamic metrics", paste0(date_range_dynamic$first_water_year, " to ", date_range_dynamic$last_water_year), "plot-water-year", "Includes annual maximum observed inundated area and sequence support diagnostics.",
  mer_monthly_path, "CSV", "Monthly/seasonal MER summaries", paste0(date_range_dynamic$first_water_year, " to ", date_range_dynamic$last_water_year), "plot-period", "Retained as QA/targeted review due to low-support bins.",
  annual_occurrence_path, "CSV", "Current annual occurrence pre/post plot summary", "pre/post conservation", "plot", "Main annual occurrence comparison framework.",
  metric_comparison_path, "CSV", "Task 4 metric comparison table", "not temporal", "metric", "Documents overlap and added value.",
  keep_defer_path, "CSV", "Task 4 keep/defer decision table", "not temporal", "metric/output", "Preserves current recommendation.",
  task8_mer_compare_path, "PNG", "Task 8 MER versus annual occurrence plot-based comparison figure", "pre/post conservation", "plot centroid", "Primary main-deck MER comparison asset.",
  task8_mer_change_path, "PNG", "Task 8 MER annual maximum change plot-based figure", "pre/post conservation", "plot centroid", "Primary MER result asset."
) %>%
  dplyr::mutate(file_path = normalise_path(.data$file_path))

output_files <- dplyr::bind_rows(
  make_output_row(file.path(mer_csv_dir, "mer_vs_annual_occurrence_agreement_summary.csv"), "CSV", "MER vs annual occurrence agreement", "Summary table for deck/note/workbook.", "Main deck/supporting", "Generated by Task 9 from existing flags."),
  make_output_row(file.path(mer_csv_dir, "mer_vs_annual_occurrence_plot_review_flags.csv"), "CSV", "Plot-level MER review flags", "Manual review and appendix table.", "Appendix", "Generated by Task 9 from existing flags."),
  make_output_row(file.path(mer_csv_dir, "mer_metric_definitions.csv"), "CSV", "Metric definitions", "Shared source for documentation/workbook.", "Technical package", "Generated by Task 9."),
  make_output_row(file.path(mer_csv_dir, "mer_input_files_inventory.csv"), "CSV", "Input inventory", "Audit and documentation.", "Technical package", "Generated by Task 9."),
  make_output_row(file.path(mer_csv_dir, "mer_output_files_inventory.csv"), "CSV", "Output inventory", "Audit and documentation.", "Technical package", "Generated by Task 9."),
  make_output_row(file.path(mer_figure_dir, "mer_vs_annual_occurrence_main_deck_comparison.png"), "PNG", "MER vs annual occurrence comparison", "Primary MER comparison figure.", "Main deck/supporting", "Copied from Task 8 asset."),
  make_output_row(file.path(mer_figure_dir, "mer_metric_summary_main_deck.png"), "PNG", "MER metric summary", "Primary MER annual maximum observed area figure.", "Main deck/supporting", "Copied from Task 8 asset."),
  make_output_row(file.path(mer_report_dir, "Gayini_MER_analysis_review_deck.pptx"), "PPTX", "Standalone MER review deck", "Standalone communication package.", "Separate deck", "Created after this table script."),
  make_output_row(file.path(mer_report_dir, "Gayini_MER_methods_and_interpretation_note.docx"), "DOCX", "MER methods and interpretation note", "Technical documentation.", "Technical package", "Created after this table script."),
  make_output_row(file.path(mer_report_dir, "Gayini_MER_analysis_workbook.xlsx"), "XLSX", "MER reference workbook", "Data inventory and decision support.", "Technical package", "Created after this table script.")
)

recommended_figures <- tibble::tribble(
  ~figure_file, ~deck_role, ~slide_suggestion, ~status, ~caveat,
  file.path(mer_figure_dir, "mer_vs_annual_occurrence_main_deck_comparison.png"), "Primary MER comparison", "MER versus annual occurrence comparison", "Current canonical", "Plot-based / plot-centroid comparison.",
  file.path(mer_figure_dir, "mer_metric_summary_main_deck.png"), "MER annual max result", "MER-style annual maximum observed footprint", "Current canonical", "Supplementary; not hydroperiod or duration.",
  task4_mer_summary_path, "Technical appendix", "Metric keep/defer summary", ifelse(file.exists(task4_mer_summary_path), "Available", "Missing"), "Use as supporting summary, not main story.",
  file.path(root_dir, "Output", "figures", "06_MER_inundation", "deck_candidates", "05_observation_support_sensor_note.png"), "Technical appendix", "Observation support by sensor/year", "Available", "Support/caveat figure, not ecological response.",
  file.path(root_dir, "Output", "figures", "06_MER_inundation", "deck_candidates", "04_annual_max_heatmap_ordered_by_mer_change.png"), "Technical appendix", "Detailed annual maximum heatmap", "Available", "Dense; appendix only."
) %>%
  dplyr::mutate(figure_file = normalise_path(.data$figure_file))

adrian_questions <- tibble::tribble(
  ~question, ~current_recommendation, ~rationale, ~consequence,
  "Should this method be described as MER / Flow-MER-inspired inundation metrics, daily observed inundation footprint metrics, or another preferred label?", "Use daily observed inundation footprint metrics in main deck; MER / Flow-MER-inspired in technical material.", "Keeps main-deck language intuitive while preserving method provenance.", "Determines slide titles, figure captions and methods wording.",
  "Should MER appear in the main deck, appendix, or both?", "Use one MER comparison slide in the main deck only if space allows; keep detail in appendix.", "Annual occurrence remains the headline result.", "Controls deck length and emphasis.",
  "Are disagreement plots useful review flags?", "Yes, but as review flags only.", "Disagreement may reflect metric definitions rather than error.", "Determines whether plot-level review table is used with Adrian.",
  "Are annual maximum observed area metrics useful for Adrian's review?", "Yes as supplementary wet-footprint context.", "They add event-footprint size context beyond annual frequency.", "Could justify one support slide.",
  "Should monthly/seasonal or sequence metrics remain deferred?", "Yes for now.", "Support is weaker and wording risks hydroperiod confusion.", "Keeps technical appendix focused and cautious."
)

keep_defer_archive <- keep_defer %>%
  dplyr::transmute(
    output_or_metric = .data$item,
    decision = .data$decision,
    reason = .data$rationale,
    recommended_location = dplyr::case_when(
      .data$deck_role == "headline" ~ "Main Gayini deck",
      .data$deck_role %in% c("supporting", "appendix") ~ "Technical appendix / supporting material",
      .data$deck_role == "defer" ~ "Deferred",
      TRUE ~ .data$deck_role
    )
  )

gayini_write_csv(metric_definitions, file.path(mer_csv_dir, "mer_metric_definitions.csv"))
gayini_write_csv(input_files, file.path(mer_csv_dir, "mer_input_files_inventory.csv"))
gayini_write_csv(output_files, file.path(mer_csv_dir, "mer_output_files_inventory.csv"))
gayini_write_csv(recommended_figures, file.path(mer_csv_dir, "mer_recommended_figures.csv"))
gayini_write_csv(adrian_questions, file.path(mer_csv_dir, "mer_adrian_questions.csv"))
gayini_write_csv(keep_defer_archive, file.path(mer_csv_dir, "mer_keep_defer_archive_decisions.csv"))


## Figure copies ----


figure_copy_log <- dplyr::bind_rows(
  copy_with_log(
    task8_mer_compare_path,
    file.path(mer_figure_dir, "mer_vs_annual_occurrence_main_deck_comparison.png"),
    "primary_main_deck_mer_comparison"
  ),
  copy_with_log(
    task8_mer_change_path,
    file.path(mer_figure_dir, "mer_metric_summary_main_deck.png"),
    "primary_main_deck_mer_metric_summary"
  ),
  if (file.exists(task4_mer_summary_path)) {
    copy_with_log(
      task4_mer_summary_path,
      file.path(mer_figure_dir, "mer_metric_keep_defer_summary_review.png"),
      "supporting_mer_metric_keep_defer_summary"
    )
  } else {
    tibble::tibble()
  },
  if (file.exists(file.path(root_dir, "Output", "figures", "06_MER_inundation", "deck_candidates", "05_observation_support_sensor_note.png"))) {
    copy_with_log(
      file.path(root_dir, "Output", "figures", "06_MER_inundation", "deck_candidates", "05_observation_support_sensor_note.png"),
      file.path(mer_figure_dir, "mer_observation_support_sensor_note_appendix.png"),
      "appendix_observation_support"
    )
  } else {
    tibble::tibble()
  },
  if (file.exists(file.path(root_dir, "Output", "figures", "06_MER_inundation", "deck_candidates", "04_annual_max_heatmap_ordered_by_mer_change.png"))) {
    copy_with_log(
      file.path(root_dir, "Output", "figures", "06_MER_inundation", "deck_candidates", "04_annual_max_heatmap_ordered_by_mer_change.png"),
      file.path(mer_figure_dir, "mer_annual_max_heatmap_appendix.png"),
      "appendix_annual_max_heatmap"
    )
  } else {
    tibble::tibble()
  }
)

gayini_write_csv(figure_copy_log, file.path(diagnostics_dir, "task9_mer_figure_copy_log.csv"))


## Asset pack and register updates ----


asset_pack_candidates <- list.dirs(report_dir, recursive = FALSE, full.names = TRUE) %>%
  .[stringr::str_detect(basename(.), "^ppt_asset_pack_")]

asset_pack_dir <- if (length(asset_pack_candidates) > 0L) {
  asset_pack_candidates[order(asset_pack_candidates, decreasing = TRUE)][1]
} else {
  file.path(report_dir, paste0("ppt_asset_pack_", format(task_date, "%Y%m%d")))
}

main_destination_dir <- file.path(asset_pack_dir, "01_main_deck_figures")
support_destination_dir <- file.path(asset_pack_dir, "02_supporting_figures")
appendix_destination_dir <- file.path(asset_pack_dir, "03_appendix_figures")

asset_pack_copy_log <- dplyr::bind_rows(
  copy_with_log(file.path(mer_figure_dir, "mer_vs_annual_occurrence_main_deck_comparison.png"), file.path(main_destination_dir, "mer_vs_annual_occurrence_main_deck_comparison.png"), "asset_pack_main"),
  copy_with_log(file.path(mer_figure_dir, "mer_metric_summary_main_deck.png"), file.path(main_destination_dir, "mer_metric_summary_main_deck.png"), "asset_pack_main"),
  if (file.exists(file.path(mer_figure_dir, "mer_metric_keep_defer_summary_review.png"))) copy_with_log(file.path(mer_figure_dir, "mer_metric_keep_defer_summary_review.png"), file.path(support_destination_dir, "mer_metric_keep_defer_summary_review.png"), "asset_pack_supporting") else tibble::tibble(),
  if (file.exists(file.path(mer_figure_dir, "mer_observation_support_sensor_note_appendix.png"))) copy_with_log(file.path(mer_figure_dir, "mer_observation_support_sensor_note_appendix.png"), file.path(appendix_destination_dir, "mer_observation_support_sensor_note_appendix.png"), "asset_pack_appendix") else tibble::tibble(),
  if (file.exists(file.path(mer_figure_dir, "mer_annual_max_heatmap_appendix.png"))) copy_with_log(file.path(mer_figure_dir, "mer_annual_max_heatmap_appendix.png"), file.path(appendix_destination_dir, "mer_annual_max_heatmap_appendix.png"), "asset_pack_appendix") else tibble::tibble()
)

gayini_write_csv(asset_pack_copy_log, file.path(diagnostics_dir, "task9_mer_asset_pack_copy_log.csv"))

if (file.exists(asset_register_path)) {
  asset_register <- readr::read_csv(asset_register_path, show_col_types = FALSE) %>%
    dplyr::mutate(file_modified_date = as.character(.data$file_modified_date))

  if (!"updated_by_task_9" %in% names(asset_register)) {
    asset_register <- asset_register %>%
      dplyr::mutate(updated_by_task_9 = FALSE)
  } else {
    asset_register <- asset_register %>%
      dplyr::mutate(updated_by_task_9 = as.logical(.data$updated_by_task_9))
  }

  task9_asset_rows <- dplyr::bind_rows(
    make_asset_row("PPTTASK9_MER_001", file.path(mer_figure_dir, "mer_vs_annual_occurrence_main_deck_comparison.png"), "MER versus annual occurrence comparison", "Supporting", "Current canonical", "Primary Task 9 MER comparison asset copied from Task 8."),
    make_asset_row("PPTTASK9_MER_002", file.path(mer_figure_dir, "mer_metric_summary_main_deck.png"), "MER annual maximum observed footprint summary", "Supporting", "Current canonical", "Primary Task 9 MER metric asset copied from Task 8."),
    if (file.exists(file.path(mer_figure_dir, "mer_observation_support_sensor_note_appendix.png"))) make_asset_row("PPTTASK9_MER_003", file.path(mer_figure_dir, "mer_observation_support_sensor_note_appendix.png"), "MER observation support by sensor/year", "Appendix", "Appendix", "Observation support caveat figure.") else tibble::tibble(),
    if (file.exists(file.path(mer_figure_dir, "mer_annual_max_heatmap_appendix.png"))) make_asset_row("PPTTASK9_MER_004", file.path(mer_figure_dir, "mer_annual_max_heatmap_appendix.png"), "MER annual maximum heatmap", "Appendix", "Appendix", "Dense appendix-only MER figure.") else tibble::tibble()
  ) %>%
    dplyr::mutate(updated_by_task_9 = TRUE)

  updated_register <- asset_register %>%
    dplyr::filter(!.data$filename %in% task9_asset_rows$filename) %>%
    dplyr::bind_rows(task9_asset_rows) %>%
    dplyr::arrange(.data$analysis_module, .data$deck_priority, .data$filename)

  gayini_write_csv(updated_register, asset_register_path)
}


## Checks ----


mer_raster_files <- list.files(file.path(root_dir, "Output", "rasters"), pattern = "(?i)mer|flow", recursive = TRUE, full.names = TRUE)

checks <- tibble::tibble(
  check_name = c(
    "no_heavy_workflows_run",
    "no_raster_products_rebuilt",
    "task8_mer_assets_reused",
    "agreement_counts_supported",
    "true_mer_raster_surface_exists",
    "main_mer_figures_copied",
    "asset_pack_files_copied",
    "biodiversity_repo_excluded"
  ),
  status = c(
    "pass",
    "pass",
    "pass",
    dplyr::if_else(sum(agreement_summary$plot_count) == nrow(flags), "pass", "fail"),
    dplyr::if_else(length(mer_raster_files) > 0L, "review", "not_found"),
    dplyr::if_else(all(figure_copy_log$destination_exists), "pass", "fail"),
    dplyr::if_else(all(asset_pack_copy_log$destination_exists), "pass", "fail"),
    "pass"
  ),
  check_value = c(
    "This script only read existing CSVs/PNGs and copied outputs.",
    "This script never writes .tif files or calls raster scripts.",
    paste(basename(c(task8_mer_compare_path, task8_mer_change_path)), collapse = "; "),
    paste(agreement_summary$agreement_category, agreement_summary$plot_count, collapse = "; "),
    if (length(mer_raster_files) > 0L) paste(normalise_path(mer_raster_files), collapse = "; ") else "No MER/Flow raster files found under Output/rasters.",
    paste0(sum(figure_copy_log$destination_exists), " of ", nrow(figure_copy_log), " MER figure copies exist."),
    paste0(sum(asset_pack_copy_log$destination_exists), " of ", nrow(asset_pack_copy_log), " asset-pack copies exist."),
    "No biodiversity paths read or written."
  )
)

gayini_write_csv(checks, file.path(diagnostics_dir, "task9_mer_package_table_checks.csv"))

if (any(checks$status == "fail")) {
  stop("Task 9 MER package table checks failed. See diagnostics.", call. = FALSE)
}

message("Task 9 MER package tables and figure copies complete.")
message("MER CSV folder: ", mer_csv_dir)
message("MER figure folder: ", mer_figure_dir)
message("Asset pack updated: ", asset_pack_dir)
