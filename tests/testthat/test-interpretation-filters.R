library(dplyr)
library(magrittr)
library(stringr)

source(file.path("..", "..", "R", "gayini_interpretation_filters.R"))

test_that("treed plot exclusion drops flagged rows only", {
  x <- data.frame(
    plot_id = c("A", "B", "C"),
    ground_cover_exclusion_flag = c(FALSE, TRUE, NA),
    stringsAsFactors = FALSE
  )

  out <- gayini_exclude_treed_plots(x)

  expect_equal(out$plot_id, c("A", "C"))
})

test_that("main ground-cover metric selection is conservative", {
  x <- data.frame(
    metric = c("total_veg_pct", "bare_ground_pct", "delta_total_veg_pct"),
    value = c(1, 2, 3),
    stringsAsFactors = FALSE
  )

  out <- gayini_select_main_gc_metric(x, metric_col = "metric")

  expect_equal(out$metric, c("total_veg_pct", "delta_total_veg_pct"))
})

test_that("vegetation labels are standardised without changing unknown labels", {
  x <- data.frame(
    simplified_vegetation_group = c("River red gum woodland", "chenopod open", "Other"),
    stringsAsFactors = FALSE
  )

  out <- gayini_standardise_veg_group_labels(x)

  expect_equal(
    out$simplified_vegetation_group,
    c("Floodplain Woodland / Forest", "Open Grassland / Chenopod", "Other")
  )
})
