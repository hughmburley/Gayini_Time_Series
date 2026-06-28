# ------------------------------------------------------------------------------
# Script: scripts/04_gauges/01_import_murrumbidgee_gauge_context.R
# Purpose: Import optional Murrumbidgee gauge context.
# Workflow stage: 04_gauges
# Run mode: lightweight_review
# Heavy processing: no
# Key inputs:
#   - Packaged hydrology database or clean exports.
# Key outputs:
#   - Gauge context diagnostics and processed tables.
# Notes:
#   - Gauge context is supporting context only, not causal proof.
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Load configuration and execute workflow step
# ------------------------------------------------------------------------------

## Purpose:
## Optional Murrumbidgee gauge-context import for later RS review stages. This
## step is deliberately outside the MER metric calculation: MER remains
## remote-sensing derived.


root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", "D:/Github_repos/Gayini"), winslash = "/", mustWork = TRUE)
source_root <- Sys.getenv("MURRUMBIDGEE_GAUGE_ROOT", unset = "D:/Github_repos/Murrumbidgee_Gauge_Workflow")

required_packages <- c("dplyr", "readr", "tibble", "tidyr")
missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]
if (length(missing_packages) > 0) {
  stop("Install missing packages before continuing: ", paste(missing_packages, collapse = ", "))
}

source(file.path(root_dir, "R", "hydrology_import_functions.R"))

input_dir <- file.path(root_dir, "Input", "hydrology")
intermediate_dir <- file.path(root_dir, "data_intermediate", "hydrology")
processed_dir <- file.path(root_dir, "data_processed", "hydrology")
diagnostics_dir <- file.path(root_dir, "Output", "diagnostics", "hydrology")
log_dir <- file.path(root_dir, "Output", "logs")
db_export_dir <- file.path(processed_dir, "gauge_db_selected_tables")

dir.create(input_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(intermediate_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(processed_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(diagnostics_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(db_export_dir, recursive = TRUE, showWarnings = FALSE)

database_path <- find_gauge_context_database(root_dir)
selected_tables <- selected_gauge_database_tables()

coerce_station_id <- function(data) {
  if ("station_id" %in% names(data)) {
    data <- dplyr::mutate(data, station_id = as.character(.data$station_id))
  }
  data
}

site_lookup <- function(gauge_sites) {
  if (is.null(gauge_sites) || !"station_id" %in% names(gauge_sites)) {
    return(tibble::tibble(station_id = character(), station_name = character()))
  }

  station_name_col <- intersect(c("station_name", "site_name", "gauge_name", "name"), names(gauge_sites))
  out <- gauge_sites |>
    coerce_station_id() |>
    dplyr::distinct(.data$station_id, .keep_all = TRUE)

  if (length(station_name_col) == 0L) {
    out$station_name <- out$station_id
  } else {
    out$station_name <- as.character(out[[station_name_col[[1]]]])
  }

  out |>
    dplyr::select("station_id", "station_name")
}

standardise_db_daily <- function(daily_flow_wide, gauge_sites) {
  daily_flow_wide <- tibble::as_tibble(daily_flow_wide)
  date_col <- intersect(c("date", "Date", "day", "date_midpoint"), names(daily_flow_wide))
  if (length(date_col) == 0L) {
    stop("daily_flow_wide table must contain a date-like column.", call. = FALSE)
  }
  date_col <- date_col[[1]]

  if ("station_id" %in% names(daily_flow_wide)) {
    out <- daily_flow_wide |>
      coerce_station_id() |>
      dplyr::mutate(date = as.Date(.data[[date_col]]))
  } else {
    id_cols <- intersect(c(date_col, "source_system", "patch_status", "record_status"), names(daily_flow_wide))
    value_cols <- setdiff(names(daily_flow_wide), id_cols)
    out <- daily_flow_wide |>
      tidyr::pivot_longer(
        cols = dplyr::all_of(value_cols),
        names_to = "station_id",
        values_to = "flow_mld"
      ) |>
      dplyr::mutate(
        station_id = as.character(.data$station_id),
        date = as.Date(.data[[date_col]])
      )
  }

  if (!"flow_mld" %in% names(out)) {
    flow_col <- intersect(c("mean_flow_mld", "flow", "value"), names(out))
    if (length(flow_col) > 0L) out$flow_mld <- as.numeric(out[[flow_col[[1]]]])
  }
  if (!"flow_m3s" %in% names(out)) out$flow_m3s <- out$flow_mld / 86.4
  if (!"source_system" %in% names(out)) out$source_system <- "packaged_gauge_database"
  if (!"patch_status" %in% names(out)) out$patch_status <- "packaged_database"
  if (!"record_status" %in% names(out)) out$record_status <- "packaged_database"

  out |>
    dplyr::left_join(site_lookup(gauge_sites), by = "station_id") |>
    dplyr::mutate(station_name = dplyr::coalesce(.data$station_name, .data$station_id)) |>
    add_gauge_roles()
}

standardise_db_monthly <- function(monthly_flow, gauge_sites) {
  out <- tibble::as_tibble(monthly_flow) |>
    coerce_station_id()

  if (!"month_start" %in% names(out) && all(c("year", "month") %in% names(out))) {
    out$month_start <- as.Date(sprintf("%04d-%02d-01", as.integer(out$year), as.integer(out$month)))
  } else {
    out$month_start <- as.Date(out$month_start)
  }

  if (!"station_name" %in% names(out)) {
    out <- out |> dplyr::left_join(site_lookup(gauge_sites), by = "station_id")
  }
  if (!"station_name" %in% names(out)) out$station_name <- out$station_id
  if (!"record_status_summary" %in% names(out)) out$record_status_summary <- "packaged_database"
  if (!"patch_status_summary" %in% names(out)) out$patch_status_summary <- "packaged_database"
  if (!"drought_context_class" %in% names(out)) out$drought_context_class <- NA_character_

  out |> add_gauge_roles()
}

standardise_db_water_year <- function(water_year_flow, gauge_sites) {
  out <- tibble::as_tibble(water_year_flow) |>
    coerce_station_id()

  if (!"station_name" %in% names(out)) {
    out <- out |> dplyr::left_join(site_lookup(gauge_sites), by = "station_id")
  }
  if (!"station_name" %in% names(out)) out$station_name <- out$station_id
  if (!"record_status_summary" %in% names(out)) out$record_status_summary <- "packaged_database"
  if (!"patch_status_summary" %in% names(out)) out$patch_status_summary <- "packaged_database"
  if (!"drought_context_class" %in% names(out)) out$drought_context_class <- NA_character_

  out |> add_gauge_roles()
}

if (is.na(database_path)) {
  message("No packaged gauge database found; falling back to clean CSV exports from: ", source_root)
  source(file.path(root_dir, "scripts", "04_gauges", "internal", "01_import_murrumbidgee_gauge_data_impl.R"), chdir = FALSE)

  database_manifest <- tibble::tibble(
    import_mode = "clean_csv_fallback",
    database_path = NA_character_,
    table_name = selected_tables,
    table_available = FALSE,
    rows_read = NA_integer_,
    note = "No packaged gauge database found in Input/hydrology; imported clean CSV exports instead."
  )
} else {
  db_packages <- c("DBI", "RSQLite")
  missing_db_packages <- db_packages[
    !vapply(db_packages, requireNamespace, logical(1), quietly = TRUE)
  ]
  if (length(missing_db_packages) > 0) {
    stop("Install missing database packages before continuing: ", paste(missing_db_packages, collapse = ", "))
  }

  con <- DBI::dbConnect(RSQLite::SQLite(), database_path)
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  available_tables <- DBI::dbListTables(con)
  tables_to_read <- intersect(selected_tables, available_tables)
  missing_selected_tables <- setdiff(selected_tables, tables_to_read)

  if (!all(c("daily_flow_wide", "monthly_flow", "water_year_flow") %in% tables_to_read)) {
    stop(
      "Packaged gauge database is present but does not contain the required clean tables: daily_flow_wide, monthly_flow, water_year_flow.",
      call. = FALSE
    )
  }

  db_tables <- stats::setNames(
    lapply(tables_to_read, function(table_name) tibble::as_tibble(DBI::dbReadTable(con, table_name))),
    tables_to_read
  )

  export_manifest <- dplyr::bind_rows(lapply(names(db_tables), function(table_name) {
    export_path <- file.path(db_export_dir, paste0(table_name, ".csv"))
    readr::write_csv(db_tables[[table_name]], export_path)
    tibble::tibble(
      table_name = table_name,
      export_path = export_path,
      rows_read = nrow(db_tables[[table_name]])
    )
  }))

  daily <- standardise_db_daily(db_tables$daily_flow_wide, db_tables$gauge_sites)
  monthly <- standardise_db_monthly(db_tables$monthly_flow, db_tables$gauge_sites)
  water_year <- standardise_db_water_year(db_tables$water_year_flow, db_tables$gauge_sites)

  readr::write_csv(daily, file.path(input_dir, "gayini_gauge_daily.csv"))
  readr::write_csv(monthly, file.path(input_dir, "gayini_gauge_monthly.csv"))
  readr::write_csv(water_year, file.path(input_dir, "gayini_gauge_water_year.csv"))
  readr::write_csv(make_gauge_metadata(daily), file.path(input_dir, "gauge_metadata.csv"))
  readr::write_csv(gauge_role_lookup(), file.path(diagnostics_dir, "hydrology_gauge_role_lookup.csv"))

  readr::write_csv(daily, file.path(intermediate_dir, "gayini_gauge_daily_imported.csv"))
  readr::write_csv(monthly, file.path(intermediate_dir, "gayini_gauge_monthly_imported.csv"))
  readr::write_csv(water_year, file.path(intermediate_dir, "gayini_gauge_water_year_imported.csv"))

  copied_files <- tibble::tibble(
    product = c("daily", "monthly", "water_year"),
    source_path = database_path,
    import_path = file.path(input_dir, c("gayini_gauge_daily.csv", "gayini_gauge_monthly.csv", "gayini_gauge_water_year.csv")),
    source_exists = TRUE,
    copied = TRUE,
    source_set = "packaged_database"
  )
  import_checks <- make_hydrology_import_checks(daily, monthly, water_year, copied_files)
  readr::write_csv(copied_files, file.path(diagnostics_dir, "hydrology_imported_source_files.csv"))
  readr::write_csv(import_checks, file.path(diagnostics_dir, "hydrology_import_checks.csv"))

  database_manifest <- tibble::tibble(
    import_mode = "packaged_database",
    database_path = database_path,
    table_name = selected_tables,
    table_available = selected_tables %in% tables_to_read,
    rows_read = export_manifest$rows_read[match(selected_tables, export_manifest$table_name)],
    note = dplyr::if_else(
      selected_tables %in% missing_selected_tables,
      "Selected clean table was not present in the packaged database.",
      "Selected clean table read from packaged database."
    )
  )

  if (any(import_checks$status == "fail")) {
    stop("Hydrology import checks failed. See Output/diagnostics/hydrology/hydrology_import_checks.csv")
  }
}

readr::write_csv(database_manifest, file.path(diagnostics_dir, "gauge_database_import_manifest.csv"))
writeLines(capture.output(sessionInfo()), file.path(log_dir, "07_import_murrumbidgee_gauge_context_session_info.txt"))

message("Gauge context import complete. Mode: ", unique(database_manifest$import_mode)[[1]])
