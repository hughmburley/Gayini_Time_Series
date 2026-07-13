## -----------------------------------------------------------------------------
## run_db_validation.R
## Companion to run_spine_smoke_test.R. That test checks repo STRUCTURE only; this
## one connects to the results DB and validates its DATA/state:
##   1. the post-build guard (B4) -- did a rebuild wipe the post-build mutations?
##   2. the modelling-spine data validation (shape, 4-class, no leakage, headline).
##
## Run AFTER any full DB rebuild (builder -> 05 -> 03 -> 09) to confirm the chain
## completed. Read-only, no rasters. Exits status 1 if any check fails.
##
## Run:  Rscript run_db_validation.R
## -----------------------------------------------------------------------------

suppressPackageStartupMessages({library(DBI); library(RSQLite)})

root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", getwd()), winslash = "/", mustWork = TRUE)
source(file.path(root_dir, "R", "gayini_db_validation.R"))

db_path    <- file.path(root_dir, "Output", "database", "Gayini_Results.sqlite")
output_dir <- file.path(root_dir, "Output", "reports", "db_validation")
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
if (!file.exists(db_path)) stop("Database not found: ", db_path, call. = FALSE)

con <- dbConnect(SQLite(), db_path); on.exit(dbDisconnect(con))

## 1. Post-build guard -- gayini_assert_post_build_objects() stop()s on failure.
guard_ok  <- TRUE
guard_msg <- "PASS"
guard <- tryCatch(gayini_assert_post_build_objects(con),
                  error = function(e) { guard_ok <<- FALSE; guard_msg <<- conditionMessage(e); NULL })

## 2. Spine data validation.
spine <- gayini_validate_spine(con)
cat("\n== Spine data validation ==\n")
print(spine, row.names = FALSE)

results_path <- file.path(output_dir, "db_validation_results.csv")
utils::write.csv(
  rbind(data.frame(check = "post_build_guard",
                   status = if (guard_ok) "pass" else "fail",
                   detail = guard_msg, stringsAsFactors = FALSE),
        spine),
  results_path, row.names = FALSE)
message("Wrote: ", results_path)

n_fail <- sum(spine$status == "fail") + as.integer(!guard_ok)
if (n_fail > 0L) {
  message("DB validation FAILED: ", n_fail, " check(s).")
  quit(status = 1L, save = "no")
}
message("DB validation: PASS (guard + ", nrow(spine), " spine checks).")
invisible(NULL)
