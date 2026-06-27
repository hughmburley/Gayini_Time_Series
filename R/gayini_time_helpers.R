## -----------------------------------------------------------------------------
## Gayini remote sensing workflow
## gayini_time_helpers.R
## -----------------------------------------------------------------------------


## Purpose:
## Shared date, water-year and management-transition helpers.


gayini_management_transition_date <- function() {
  as.Date("2019-07-01")
}


gayini_water_year <- function(date) {
  date <- as.Date(date)
  year <- as.integer(format(date, "%Y"))
  month <- as.integer(format(date, "%m"))
  year + ifelse(month >= 7L, 1L, 0L)
}


gayini_water_year_label <- function(date = NULL,
                                    water_year = NULL) {
  if (!is.null(water_year)) {
    end_year <- as.integer(water_year)
  } else {
    end_year <- gayini_water_year(date)
  }

  paste0(end_year - 1L, "-", end_year)
}


gayini_period_pre_post <- function(date = NULL,
                                   water_year = NULL,
                                   transition_date = gayini_management_transition_date()) {
  if (!is.null(water_year)) {
    start_year <- as.integer(substr(as.character(water_year), 1, 4))
    period_date <- as.Date(sprintf("%04d-07-01", start_year))
  } else {
    period_date <- as.Date(date)
  }

  dplyr::case_when(
    is.na(period_date) ~ NA_character_,
    period_date < transition_date ~ "pre_conservation",
    TRUE ~ "post_conservation"
  )
}
