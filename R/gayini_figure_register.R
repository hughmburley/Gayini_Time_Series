# gayini_figure_register.R
# R owns BOTH halves of figure registration - write and register in one call,
# one transaction - so a figure can never land on disk unregistered (the failure
# mode that produced ~330 orphan figures when R wrote and Python registered later).
#
# Checksum convention is first-50-MB SHA-256, IDENTICAL to the Python
# sha256_first50() (50*1024*1024 bytes, verified byte-for-byte on the 8058 gpkg:
# e7a3b436...0c5225). NEVER digest::digest(file=...) whole-file - that is the old
# R registrars' convention and would be a third, incompatible one.

gayini_sha256_first50 <- function(path) {
  cap <- 50L * 1024L * 1024L
  con <- file(path, "rb")
  on.exit(close(con))
  raw_bytes <- readBin(con, what = "raw", n = cap)
  digest::digest(raw_bytes, algo = "sha256", serialize = FALSE)
}

# One call: ggsave -> first-50-MB SHA-256 -> INSERT OR REPLACE into figure_asset.
# Returns the row identity invisibly. `caption` MUST state the support level.
gayini_write_and_register_figure <- function(plot, path, title, caption,
                                             support_level, figure_level, run_id,
                                             db_path = file.path("Output", "database", "Gayini_Results.sqlite"),
                                             root = normalizePath(".", winslash = "/"),
                                             domain = "zone_diagnostics",
                                             recommended_use = "review",
                                             framing_label = "census_8058",
                                             provenance_note = NA_character_,
                                             width = 10, height = 7, dpi = 150) {
  # caption MUST name the support level (the token itself, not just the word
  # "support") - this is the check that keeps every figure's support explicit.
  if (!grepl(tolower(support_level), tolower(caption), fixed = TRUE))
    stop(sprintf("caption must state the support level '%s'; got: %s",
                 support_level, caption))
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  ggplot2::ggsave(path, plot, width = width, height = height, dpi = dpi)
  if (!file.exists(path)) stop("ggsave did not write ", path)

  checksum <- gayini_sha256_first50(path)
  abs_path  <- gsub("\\\\", "/", normalizePath(path, winslash = "/"))
  root_norm <- gsub("\\\\", "/", root)
  rel_path  <- sub(paste0(root_norm, "/"), "", abs_path, fixed = TRUE)
  slug <- gsub("[^A-Za-z0-9]+", "_", tools::file_path_sans_ext(basename(path)))
  fid  <- paste0("figure_", tolower(slug))

  con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  cols <- c("support_level", "figure_level")           # assert Gate B1 columns exist
  have <- DBI::dbGetQuery(con, "PRAGMA table_info(figure_asset)")$name
  if (!all(cols %in% have))
    stop("figure_asset is missing ", paste(setdiff(cols, have), collapse = ", "),
         " - run T1_gateB1_schema_migrations.py first.")

  DBI::dbBegin(con)
  tryCatch({
    DBI::dbExecute(con,
      "INSERT OR REPLACE INTO figure_asset
         (figure_asset_id, path, title, domain, metric_id, recommended_use,
          checksum_sha256, path_exists, qa_status, run_id, superseded_flag,
          framing_label, provenance_note, caption, support_level, figure_level)
       VALUES (?,?,?,?,NULL,?,?,1,'REVIEW',?,0,?,?,?,?,?)",
      params = list(fid, rel_path, title, domain, recommended_use, checksum,
                    run_id, framing_label, provenance_note, caption,
                    support_level, figure_level))
    DBI::dbCommit(con)
  }, error = function(e) { DBI::dbRollback(con); stop(e) })

  message(sprintf("registered %s -> %s (%s)", fid, rel_path, substr(checksum, 1, 12)))
  invisible(list(figure_asset_id = fid, path = rel_path, checksum_sha256 = checksum))
}
