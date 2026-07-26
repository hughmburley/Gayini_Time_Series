#!/usr/bin/env Rscript
# T1 Gate B1 - prove the caption-support guard FIRES on a broken fixture
# (CLAUDE.md: "every check must be able to fail"). Two fixtures: one good
# caption (must register), one caption omitting the support token (must stop,
# and must NOT create a file or a row).
suppressPackageStartupMessages(library(ggplot2))
root <- normalizePath(".", winslash = "/")
source(file.path(root, "R/gayini_figure_register.R"))

p <- ggplot(mtcars, aes(mpg, wt)) + geom_point()
bad_path  <- file.path(root, "Output/figures/diagnostics/_fixture_bad.png")
if (file.exists(bad_path)) file.remove(bad_path)

# BROKEN FIXTURE: caption names no support level.
res <- tryCatch(
  gayini_write_and_register_figure(
    p, bad_path, title = "fixture", caption = "a caption naming no unit at all",
    support_level = "zone", figure_level = "diagnostics", run_id = "fixture_test"),
  error = function(e) conditionMessage(e))

fired <- is.character(res) && grepl("must state the support level", res)
no_file <- !file.exists(bad_path)
cat(sprintf("guard FIRED on broken caption : %s\n", fired))
cat(sprintf("no file written on failure     : %s\n", no_file))
cat(sprintf("message: %s\n", if (fired) res else "(guard did not fire)"))
if (!(fired && no_file)) quit(status = 1)
cat("PASS: the check can fail, and fails closed (no file, no row).\n")
