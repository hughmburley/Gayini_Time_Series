## -----------------------------------------------------------------------------
## Gayini remote sensing workflow
## gayini_output_helpers.R
## -----------------------------------------------------------------------------


## Purpose:
## Lightweight output, manifest and register helpers.


gayini_ensure_dir <- function(path,
                              path_is_file = FALSE) {
  target_dir <- if (path_is_file) dirname(path) else path
  dir.create(target_dir, recursive = TRUE, showWarnings = FALSE)
  invisible(target_dir)
}


gayini_write_csv <- function(x,
                             path,
                             message_prefix = "Wrote") {
  gayini_ensure_dir(path, path_is_file = TRUE)
  readr::write_csv(x, path)
  message(message_prefix, ": ", path)
  invisible(x)
}


gayini_file_exists_check <- function(path,
                                     label = basename(path),
                                     required = TRUE) {
  tibble::tibble(
    label = label,
    path = path,
    required = required,
    exists = file.exists(path),
    status = dplyr::case_when(
      required & file.exists(path) ~ "pass",
      required & !file.exists(path) ~ "fail",
      !required & file.exists(path) ~ "available",
      TRUE ~ "missing_optional"
    )
  )
}


gayini_output_manifest_row <- function(path,
                                       output_type,
                                       role,
                                       source_script,
                                       notes = NA_character_) {
  info <- file.info(path)
  tibble::tibble(
    output_path = path,
    output_type = output_type,
    role = role,
    source_script = source_script,
    exists = file.exists(path),
    size_bytes = if (file.exists(path)) info$size else NA_real_,
    file_modified_date = if (file.exists(path)) format(info$mtime, "%Y-%m-%dT%H:%M:%S") else NA_character_,
    notes = notes
  )
}
