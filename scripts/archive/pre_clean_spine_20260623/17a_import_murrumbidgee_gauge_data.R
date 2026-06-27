## 17a_import_murrumbidgee_gauge_data.R
## Import clean Murrumbidgee gauge products into Gayini hydrology inputs.

root_dir <- Sys.getenv("GAYINI_ROOT", unset = getwd())
setwd(root_dir)

source_root <- Sys.getenv("MURRUMBIDGEE_GAUGE_ROOT", unset = "D:/Github_repos/Murrumbidgee_Gauge_Workflow")

required_packages <- c("dplyr", "readr", "stringr", "tibble")
missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]
if (length(missing_packages) > 0) {
  stop("Install missing packages before continuing: ", paste(missing_packages, collapse = ", "))
}

source(file.path(root_dir, "R/hydrology_import_functions.R"))

dir.create(file.path(root_dir, "Input/hydrology"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(root_dir, "data_intermediate/hydrology"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(root_dir, "data_processed/hydrology"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(root_dir, "Output/diagnostics/hydrology"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(root_dir, "Output/figures/hydrology"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(root_dir, "Output/logs"), recursive = TRUE, showWarnings = FALSE)

file_lookup <- source_file_lookup(source_root)
copied_files <- copy_hydrology_exports(file_lookup, root_dir)

required_imports <- c(
  "Input/hydrology/gayini_gauge_daily.csv",
  "Input/hydrology/gayini_gauge_monthly.csv",
  "Input/hydrology/gayini_gauge_water_year.csv"
)
missing_imports <- required_imports[!file.exists(file.path(root_dir, required_imports))]
if (length(missing_imports) > 0) {
  stop("Hydrology import missing required copied files: ", paste(missing_imports, collapse = ", "))
}

daily <- read_hydrology_csv(file.path(root_dir, "Input/hydrology/gayini_gauge_daily.csv")) |>
  dplyr::mutate(date = as.Date(.data$date)) |>
  add_gauge_roles()
monthly <- read_hydrology_csv(file.path(root_dir, "Input/hydrology/gayini_gauge_monthly.csv")) |>
  dplyr::mutate(month_start = as.Date(.data$month_start)) |>
  add_gauge_roles()
water_year <- read_hydrology_csv(file.path(root_dir, "Input/hydrology/gayini_gauge_water_year.csv")) |>
  add_gauge_roles()

metadata <- make_gauge_metadata(daily)
readr::write_csv(metadata, file.path(root_dir, "Input/hydrology/gauge_metadata.csv"))
readr::write_csv(gauge_role_lookup(), file.path(root_dir, "Output/diagnostics/hydrology/hydrology_gauge_role_lookup.csv"))

readr::write_csv(daily, file.path(root_dir, "data_intermediate/hydrology/gayini_gauge_daily_imported.csv"))
readr::write_csv(monthly, file.path(root_dir, "data_intermediate/hydrology/gayini_gauge_monthly_imported.csv"))
readr::write_csv(water_year, file.path(root_dir, "data_intermediate/hydrology/gayini_gauge_water_year_imported.csv"))

import_checks <- make_hydrology_import_checks(daily, monthly, water_year, copied_files)
readr::write_csv(copied_files, file.path(root_dir, "Output/diagnostics/hydrology/hydrology_imported_source_files.csv"))
readr::write_csv(import_checks, file.path(root_dir, "Output/diagnostics/hydrology/hydrology_import_checks.csv"))

if (any(import_checks$status == "fail")) {
  stop("Hydrology import checks failed. See Output/diagnostics/hydrology/hydrology_import_checks.csv")
}

writeLines(capture.output(sessionInfo()), file.path(root_dir, "Output/logs/17a_import_murrumbidgee_gauge_data_session_info.txt"))

message("Task 04b/17a hydrology import complete.")
message("Imported source set: ", paste(unique(copied_files$source_set[copied_files$copied]), collapse = "; "))
message("Daily rows: ", nrow(daily))
