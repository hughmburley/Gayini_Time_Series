library(dplyr)
library(stringr)

source(file.path("..", "..", "R", "gayini_mer_helpers.R"))

test_that("MER labels include core supplementary metrics", {
  labels <- gayini_mer_metric_labels()

  expect_true("annual_max_observed_wet" %in% names(labels))
  expect_true("observed_wet_fraction" %in% names(labels))
  expect_match(labels[["annual_occurrence"]], "Annual occurrence")
})

test_that("MER caveats preserve hydroperiod caution", {
  expect_match(gayini_mer_caveat_text("annual_max"), "not hydroperiod")
  expect_match(gayini_mer_caveat_text("wet_fraction"), "not flood duration")
})

test_that("MER output family labels common output paths", {
  expect_equal(gayini_mer_output_family("Output/csv/MER/mer_annual_max_by_plot.csv"), "MER raster annual maximum")
  expect_equal(gayini_mer_output_family("Output/figures/review/MER/example.png"), "MER review figure")
})
