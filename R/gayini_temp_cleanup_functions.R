# R/gayini_temp_cleanup_functions.R
#
# Purpose:
#   Small helper functions for keeping terra temporary raster files inside
#   the Gayini project folder and cleaning them after heavy raster scripts.
#
# Usage at the top of a heavy raster script:
#
#   source("R/gayini_temp_cleanup_functions.R")
#
#   terra_temp_dir <- gayini_setup_terra_temp(
#     temp_dir = file.path("data_intermediate", "terra_tmp", "07e_prepost_inundation")
#   )
#
#   on.exit(
#     gayini_cleanup_terra_temp(temp_dir = terra_temp_dir),
#     add = TRUE
#   )
#
# Optional explicit cleanup at the end of the script:
#
#   gayini_cleanup_terra_temp(temp_dir = terra_temp_dir)


# Setup terra temp directory ------------------------------------------------

gayini_setup_terra_temp <- function(
  temp_dir = file.path("data_intermediate", "terra_tmp"),
  memfrac = 0.7,
  todisk = TRUE,
  progress = 1
) {

  if (!requireNamespace("terra", quietly = TRUE)) {
    stop("Package 'terra' is required before calling gayini_setup_terra_temp().", call. = FALSE)
  }

  dir.create(temp_dir, recursive = TRUE, showWarnings = FALSE)

  terra::terraOptions(
    tempdir  = temp_dir,
    memfrac  = memfrac,
    todisk   = todisk,
    progress = progress
  )

  current_temp <- terra::terraOptions()$tempdir

  message("terra tempdir set to: ", current_temp)

  invisible(current_temp)
}


# Cleanup terra temp directory ---------------------------------------------

gayini_cleanup_terra_temp <- function(
  temp_dir = terra::terraOptions()$tempdir,
  remove_all_files = TRUE,
  quiet = FALSE
) {

  if (!requireNamespace("terra", quietly = TRUE)) {
    warning("Package 'terra' is not available; skipping terra temp cleanup.", call. = FALSE)
    return(invisible(FALSE))
  }

  if (!quiet) {
    message("Cleaning terra temporary files...")
  }

  try(
    terra::tmpFiles(remove = TRUE),
    silent = TRUE
  )

  if (!is.null(temp_dir) && dir.exists(temp_dir) && isTRUE(remove_all_files)) {

    temp_files <- list.files(
      temp_dir,
      recursive = TRUE,
      full.names = TRUE,
      all.files = TRUE,
      no.. = TRUE
    )

    if (length(temp_files) > 0) {
      unlink(temp_files, recursive = TRUE, force = TRUE)

      if (!quiet) {
        message("Removed ", length(temp_files), " files/folders from: ", temp_dir)
      }
    } else {
      if (!quiet) {
        message("No files found in terra tempdir: ", temp_dir)
      }
    }
  }

  invisible(TRUE)
}


# Optional diagnostic listing -----------------------------------------------

gayini_list_terra_temp_files <- function(
  temp_dir = terra::terraOptions()$tempdir
) {

  if (is.null(temp_dir) || !dir.exists(temp_dir)) {
    return(
      data.frame(
        path = character(),
        size_mb = numeric(),
        modified = as.POSIXct(character())
      )
    )
  }

  files <- list.files(
    temp_dir,
    recursive = TRUE,
    full.names = TRUE,
    all.files = TRUE,
    no.. = TRUE
  )

  if (length(files) == 0) {
    return(
      data.frame(
        path = character(),
        size_mb = numeric(),
        modified = as.POSIXct(character())
      )
    )
  }

  info <- file.info(files)

  data.frame(
    path = files,
    size_mb = round(info$size / 1024^2, 3),
    modified = info$mtime,
    stringsAsFactors = FALSE
  )
}
