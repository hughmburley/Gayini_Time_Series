## -----------------------------------------------------------------------------
## utility_cleanup_empty_folders_20260623.R
## -----------------------------------------------------------------------------
## Dry-run helper for empty folders identified by the 2026-06-23 folder audit.
## Set dry_run <- FALSE only after reviewing docs/folder_structure_audit_20260623.md.

root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", "D:/Github_repos/Gayini"), winslash = "/", mustWork = TRUE)
dry_run <- TRUE

empty_dirs <- c(
  "data_intermediate/terra_tmp/07e_prepost_inundation",
  "data_intermediate/terra_tmp",
  "Output/figures/review/plot_dashboards/panels_if_no_patchwork",
  "Output/figures/review/plot_dashboards",
  "Output/figures/review",
  "Output/maps/review/combo_rasters",
  "Output/maps/review"
)

for (rel_dir in empty_dirs) {
  target <- file.path(root_dir, rel_dir)
  if (!dir.exists(target)) {
    message("SKIP missing: ", rel_dir)
    next
  }

  contents <- list.files(target, all.files = TRUE, no.. = TRUE)
  if (length(contents) > 0L) {
    message("SKIP not empty: ", rel_dir)
    next
  }

  if (isTRUE(dry_run)) {
    message("DRY RUN would delete empty folder: ", rel_dir)
  } else {
    unlink(target, recursive = FALSE, force = FALSE)
    message("Deleted empty folder: ", rel_dir)
  }
}
