## -----------------------------------------------------------------------------
## Gayini remote sensing workflow
## run_spine_smoke_test.R
## -----------------------------------------------------------------------------


## Purpose:
## Handoff smoke test for repository structure, helper loading and active script
## parsing. This script does not run heavy workflows, extraction or raster builds.


args <- commandArgs(trailingOnly = TRUE)
mode <- if (length(args) == 0L) "smoke" else args[[1]]
allowed_modes <- c("smoke", "lightweight_review", "full_rebuild")

if (!mode %in% allowed_modes) {
  stop("Unsupported mode: ", mode, ". Use one of: ", paste(allowed_modes, collapse = ", "), call. = FALSE)
}

if (mode == "full_rebuild" && Sys.getenv("GAYINI_CONFIRM_FULL_REBUILD") != "YES_I_UNDERSTAND") {
  stop(
    "full_rebuild mode is a placeholder and requires GAYINI_CONFIRM_FULL_REBUILD=YES_I_UNDERSTAND. ",
    "No heavy workflows were run.",
    call. = FALSE
  )
}

root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", getwd()), winslash = "/", mustWork = TRUE)
output_dir <- file.path(root_dir, "Output", "reports", "spine_smoke_test")

helper_paths <- c(
  file.path(root_dir, "R", "gayini_output_helpers.R"),
  file.path(root_dir, "R", "gayini_time_helpers.R"),
  file.path(root_dir, "R", "gayini_plotting_helpers.R"),
  file.path(root_dir, "R", "gayini_interpretation_filters.R"),
  file.path(root_dir, "R", "gayini_mer_helpers.R")
)

for (helper_path in helper_paths) {
  source(helper_path)
}

gayini_ensure_dir(output_dir)

results <- list()

add_result <- function(check_group,
                       check_name,
                       status,
                       path = NA_character_,
                       message = NA_character_,
                       severity = c("info", "warning", "fail")) {
  severity <- match.arg(severity)
  results[[length(results) + 1L]] <<- data.frame(
    check_group = check_group,
    check_name = check_name,
    status = status,
    path = path,
    message = message,
    severity = severity,
    stringsAsFactors = FALSE
  )
  invisible(NULL)
}

check_path_exists <- function(check_group,
                              check_name,
                              path,
                              severity_if_missing = "fail") {
  exists <- file.exists(path)
  add_result(
    check_group = check_group,
    check_name = check_name,
    status = if (exists) "pass" else "missing",
    path = path,
    message = if (exists) "Path exists." else "Path is missing.",
    severity = if (exists) "info" else severity_if_missing
  )
  exists
}

expected_dirs <- c(
  "R",
  "scripts",
  "scripts/00_setup",
  "scripts/01_prepare_inputs",
  "scripts/02_extract_heavy",
  "scripts/03_inundation_products",
  "scripts/04_gauges",
  "scripts/05_ground_cover",
  "scripts/06_mer",
  "scripts/07_figures_dashboards",
  "scripts/08_review_packages",
  "scripts/09_qa",
  "scripts/10_downstream_optional",
  "scripts/archive",
  "docs",
  "docs/run_order"
)

for (relative_path in expected_dirs) {
  check_path_exists("structure", paste0("folder_", relative_path), file.path(root_dir, relative_path), "fail")
}

expected_inputs <- c(
  "Input",
  "data_intermediate/spatial",
  "docs/run_order/README.md",
  "docs/scripts_manifest.csv"
)

for (relative_path in expected_inputs) {
  check_path_exists("inputs", paste0("input_", relative_path), file.path(root_dir, relative_path), "warning")
}

expected_outputs <- c(
  "Output/csv/plot_rs_analysis_base.csv",
  "Output/csv/10a_ground_cover_prepost_plot_summary.csv",
  "Output/csv/MER/mer_vs_annual_occurrence_raster_comparison_summary.csv",
  "Output/reports/Gayini_ppt_asset_register.csv"
)

for (relative_path in expected_outputs) {
  check_path_exists("outputs", paste0("output_", relative_path), file.path(root_dir, relative_path), "warning")
}

for (helper_path in helper_paths) {
  add_result(
    check_group = "helpers",
    check_name = paste0("source_", basename(helper_path)),
    status = "pass",
    path = helper_path,
    message = "Helper sourced cleanly.",
    severity = "info"
  )
}

active_script_files <- list.files(file.path(root_dir, "scripts"), pattern = "\\.(R|r|py|ps1)$", recursive = TRUE, full.names = TRUE)
active_script_files <- active_script_files[!grepl("/archive/", normalizePath(active_script_files, winslash = "/", mustWork = FALSE), fixed = TRUE)]

for (script_path in active_script_files[grepl("\\.(R|r)$", active_script_files)]) {
  parsed <- try(parse(file = script_path), silent = TRUE)
  add_result(
    check_group = "parse",
    check_name = paste0("parse_", basename(script_path)),
    status = if (inherits(parsed, "try-error")) "fail" else "pass",
    path = script_path,
    message = if (inherits(parsed, "try-error")) as.character(parsed) else "R script parsed cleanly.",
    severity = if (inherits(parsed, "try-error")) "fail" else "info"
  )
}

run_order_files <- c(
  "docs/run_order/01_full_rebuild_workflow.csv",
  "docs/run_order/02_lightweight_review_refresh.csv",
  "docs/run_order/03_mer_workflow.csv",
  "docs/run_order/04_qa_workflow.csv",
  "docs/run_order/05_downstream_optional.csv"
)

for (relative_path in run_order_files) {
  check_path_exists("run_order", paste0("run_order_", basename(relative_path)), file.path(root_dir, relative_path), "fail")
}

full_rebuild_path <- file.path(root_dir, "docs", "run_order", "01_full_rebuild_workflow.csv")
mer_workflow_path <- file.path(root_dir, "docs", "run_order", "03_mer_workflow.csv")

if (file.exists(full_rebuild_path)) {
  full_rebuild <- utils::read.csv(full_rebuild_path, stringsAsFactors = FALSE)
  heavy_rows <- full_rebuild[full_rebuild$heavy_or_light == "heavy", , drop = FALSE]
  bad_heavy <- heavy_rows[heavy_rows$run_by_default != "no" | heavy_rows$safe_for_new_user != "no", , drop = FALSE]
  add_result(
    "safety",
    "full_rebuild_heavy_steps_marked_safe",
    if (nrow(bad_heavy) == 0L) "pass" else "fail",
    full_rebuild_path,
    if (nrow(bad_heavy) == 0L) "Heavy full-rebuild steps are not marked safe/default." else "One or more heavy full-rebuild steps are marked safe/default.",
    if (nrow(bad_heavy) == 0L) "info" else "fail"
  )
}

if (file.exists(mer_workflow_path)) {
  mer_workflow <- utils::read.csv(mer_workflow_path, stringsAsFactors = FALSE)
  mer_build <- mer_workflow[grepl("annual_max_rasters", mer_workflow$script_path), , drop = FALSE]
  bad_mer_build <- mer_build[mer_build$heavy_or_light != "heavy" | mer_build$run_by_default != "no", , drop = FALSE]
  add_result(
    "safety",
    "mer_raster_production_marked_heavy",
    if (nrow(bad_mer_build) == 0L) "pass" else "fail",
    mer_workflow_path,
    if (nrow(bad_mer_build) == 0L) "MER raster production is marked heavy and not default." else "MER raster production is not clearly marked heavy/not default.",
    if (nrow(bad_mer_build) == 0L) "info" else "fail"
  )
}

if (mode == "lightweight_review") {
  add_result(
    "mode",
    "lightweight_review",
    "not_run",
    NA_character_,
    "Mode acknowledged. This smoke test still does not execute review scripts by default.",
    "warning"
  )
} else {
  add_result("mode", mode, "pass", NA_character_, "No workflow scripts executed.", "info")
}

result_df <- do.call(rbind, results)
results_path <- file.path(output_dir, "spine_smoke_test_results.csv")
report_path <- file.path(output_dir, "spine_smoke_test_report.md")

utils::write.csv(result_df, results_path, row.names = FALSE, na = "")

n_fail <- sum(result_df$severity == "fail")
n_warning <- sum(result_df$severity == "warning")

report_lines <- c(
  "# Gayini Spine Smoke Test",
  "",
  paste0("Mode: `", mode, "`"),
  paste0("Run time: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
  paste0("Root: `", root_dir, "`"),
  "",
  "## Summary",
  "",
  paste0("- Checks: ", nrow(result_df)),
  paste0("- Failures: ", n_fail),
  paste0("- Warnings: ", n_warning),
  "- Heavy workflows executed: no",
  "- Extraction executed: no",
  "- Raster builds executed: no",
  "",
  "## Outputs",
  "",
  paste0("- `", results_path, "`"),
  paste0("- `", report_path, "`")
)

writeLines(report_lines, report_path, useBytes = TRUE)

message("Smoke-test results: ", results_path)
message("Smoke-test report: ", report_path)

if (n_fail > 0L) {
  quit(status = 1L, save = "no")
}

invisible(result_df)
