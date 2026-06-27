source(file.path("..", "..", "R", "gayini_time_helpers.R"))

test_that("management transition date is stable", {
  expect_equal(gayini_management_transition_date(), as.Date("2019-07-01"))
})

test_that("water year increments in July", {
  expect_equal(gayini_water_year(as.Date("2019-06-30")), 2019)
  expect_equal(gayini_water_year(as.Date("2019-07-01")), 2020)
})

test_that("pre/post period helper uses the management transition", {
  expect_equal(gayini_period_pre_post(date = as.Date("2019-06-30")), "pre_conservation")
  expect_equal(gayini_period_pre_post(date = as.Date("2019-07-01")), "post_conservation")
})
