## -----------------------------------------------------------------------------
## Gayini remote sensing workflow
## gayini_mer_helpers.R
## -----------------------------------------------------------------------------


## Purpose:
## Shared MER terminology, caveats and output-family labels.


gayini_mer_metric_labels <- function() {
  c(
    annual_max_observed_wet = "MER annual maximum observed wet extent",
    observed_wet_fraction = "MER observed wet fraction",
    annual_occurrence = "Annual occurrence frequency",
    post_minus_pre = "Post-minus-pre change",
    observation_support = "Observation support"
  )
}


gayini_mer_caveat_text <- function(caveat = c("annual_max", "wet_fraction", "comparison", "summary")) {
  caveat <- match.arg(caveat)
  switch(
    caveat,
    annual_max = "MER annual maximum observed wet extent is supplementary and is not hydroperiod, duration, depth or causal proof.",
    wet_fraction = "MER observed wet fraction is an observed satellite-footprint metric, not flood duration or hydroperiod.",
    comparison = "Disagreement between MER and annual occurrence is a review flag, not necessarily an error; neither metric is hydroperiod or depth.",
    summary = "MER outputs are supplementary to the current Gayini annual occurrence / pre-post framework unless promoted later."
  )
}


gayini_mer_output_family <- function(path) {
  dplyr::case_when(
    stringr::str_detect(path, "annual_max") ~ "MER raster annual maximum",
    stringr::str_detect(path, "period_summaries") ~ "MER raster pre/post summary",
    stringr::str_detect(path, "by_plot|comparison") ~ "MER plot/table comparison",
    stringr::str_detect(path, "figures|png") ~ "MER review figure",
    TRUE ~ "MER supporting output"
  )
}
