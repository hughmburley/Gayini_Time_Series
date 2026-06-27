## -----------------------------------------------------------------------------
## Gayini remote sensing workflow
## 07i_make_step7_figure_luts.R
## -----------------------------------------------------------------------------


## Purpose:
## Create Step 7 lookup tables for variables, figure captions, and plot-review flags.
## These tables keep long explanations out of the plots while preserving clear
## definitions for Adrian's review.


## User settings ----

root_dir <- normalizePath("D:/Github_repos/Gayini", winslash = "/", mustWork = TRUE)


## Required packages ----

required_packages <- c(
  "dplyr",
  "tidyr",
  "readr",
  "stringr",
  "tibble",
  "magrittr"
)

source(file.path(root_dir, "R", "step7_figure_helpers.R"))
gayini_check_packages(required_packages)

library(dplyr)
library(tidyr)
library(readr)
library(stringr)
library(tibble)
library(magrittr)


## Output folders ----

lut_dir <- file.path(root_dir, "Output", "diagnostics", "step7_figure_luts")
dir.create(lut_dir, recursive = TRUE, showWarnings = FALSE)


## Output paths ----

variable_lut_path <- file.path(lut_dir, "07i_step7_variable_lut.csv")
figure_caption_path <- file.path(lut_dir, "07i_step7_figure_caption_register.csv")
plot_review_lut_path <- file.path(lut_dir, "07i_plot_review_lut.csv")
change_class_lut_path <- file.path(lut_dir, "07i_change_class_lut.csv")


## Read plot summary if available ----

plot_summary <- gayini_read_step7_plot_summary(root_dir) %>%
  gayini_make_period_plot_data()


## Variable LUT ----

variable_lut <- tibble::tribble(
  ~variable, ~unit_or_values, ~definition, ~main_use, ~caption_caveat,
  "annual_valid_any", "1 / NA", "Pixel had at least one valid/interpretable observation in the water year.", "Denominator mask for valid annual observations.", "White/1 means valid coverage, not flooding.",
  "annual_inundated_any", "0 / 1 / NA", "Pixel was inundated at least once in the water year.", "Annual wet/not-wet occurrence layer.", "Does not estimate duration, depth, or hydroperiod.",
  "pre_conservation_inundation_frequency_pct", "percent", "Percent of valid pre-conservation water years where inundation occurred at least once.", "Recent pre-conservation baseline.", "Frequency is annual occurrence frequency.",
  "post_conservation_inundation_frequency_pct", "percent", "Percent of valid post-conservation water years where inundation occurred at least once.", "Post-conservation annual occurrence frequency.", "Current run may not include WY2026 if no data are present.",
  "post_minus_pre_inundation_frequency_pct_points", "percentage points", "Post-conservation frequency minus pre-conservation frequency.", "Primary plot/raster change variable.", "A value of +20 means +20 percentage points, not +20 percent.",
  "pre_conservation_valid_year_count", "years", "Number of valid pre-conservation water years in the denominator.", "QA / denominator check.", "Low denominator values need review.",
  "post_conservation_valid_year_count", "years", "Number of valid post-conservation water years in the denominator.", "QA / denominator check.", "Low denominator values need review.",
  "inundation_change_class", "text class", "Qualitative class from post-minus-pre thresholds.", "Adrian-facing plot screening.", "Thresholds are configurable and should be checked with Adrian."
)

readr::write_csv(variable_lut, variable_lut_path)
message("Wrote: ", variable_lut_path)


## Change-class LUT ----

change_class_lut <- tibble::tribble(
  ~change_class, ~rule, ~meaning, ~review_priority,
  "much_wetter_post", ">= +20 percentage points", "Strong increase in annual inundation occurrence frequency.", "High",
  "wetter_post", "+5 to < +20 percentage points", "Moderate increase in annual inundation occurrence frequency.", "Medium",
  "similar_frequency", "> -5 and < +5 percentage points", "No obvious shift at current threshold.", "Standard",
  "drier_post", "<= -5 to > -20 percentage points", "Moderate decrease in annual inundation occurrence frequency.", "Medium-high",
  "much_drier_post", "<= -20 percentage points", "Strong decrease in annual inundation occurrence frequency.", "High",
  "no_comparison", "NA difference", "Missing pre or post denominator.", "High"
)

readr::write_csv(change_class_lut, change_class_lut_path)
message("Wrote: ", change_class_lut_path)


## Figure caption register ----

figure_caption_register <- tibble::tribble(
  ~figure_file, ~figure_group, ~intended_use, ~draft_caption, ~variables_used, ~caveats,
  "07g_all_plots_prepost_change_dot_map.png", "07g", "Adrian-facing", "Plot-level change in annual inundation occurrence frequency. Points show 1 ha plots; colour shows post-conservation minus pre-conservation frequency in percentage points.", "post_minus_pre_inundation_frequency_pct_points", "Positive values indicate more frequently inundated post-conservation; this is occurrence frequency, not hydroperiod.",
  "07g_full_farm_pre_post_frequency_panel_v2.png", "07g", "Adrian-facing", "Full-farm pre- and post-conservation annual inundation occurrence frequency rasters. Pre is shown before post.", "pre_conservation_inundation_frequency_pct; post_conservation_inundation_frequency_pct", "Frequency is calculated across valid water years only.",
  "07g_full_farm_difference_panel_v2.png", "07g", "Adrian-facing", "Post-minus-pre difference raster for annual inundation occurrence frequency.", "post_minus_pre_inundation_frequency_pct_points", "Display colour scale may be clipped/squished for readability; raw raster values are unchanged.",
  "07g_plot_prepost_metric_matrix.png", "07g", "Adrian-facing / QA", "Plot-level matrix showing pre frequency, post frequency, post-minus-pre difference and valid-year counts for each 1 ha plot.", "pre/post/difference/valid years", "Use the variable LUT for units and definitions.",
  "07h_annual_inundated_any_pre_panel_v2.png", "07h", "Adrian-facing / context", "Annual pre-conservation wet/not-wet inundation occurrence rasters by water year.", "annual_inundated_any", "Annual wet means inundated at least once in that water year.",
  "07h_annual_inundated_any_post_panel_v2.png", "07h", "Adrian-facing / context", "Annual post-conservation wet/not-wet inundation occurrence rasters by water year.", "annual_inundated_any", "Annual wet means inundated at least once in that water year.",
  "07h_annual_wet_area_percent_timeseries.png", "07h", "Adrian-facing / context", "Farm-wide annual wet-area percentage calculated from annual inundated_any rasters.", "annual_inundated_any", "This is the percentage of valid raster cells marked wet for the water year.",
  "07k_gc_bare_median_iqr_no_treatment.png", "07k", "Adrian-facing / context", "Median and interquartile range of bare-ground cover across all suitable plots, without treatment grouping.", "bare ground cover", "Cover labels follow current fractional-cover band definitions and remain provisional if legends change."
)

readr::write_csv(figure_caption_register, figure_caption_path)
message("Wrote: ", figure_caption_path)


## Plot review LUT ----

has_pre_valid_years <- "pre_conservation_valid_year_count" %in% names(plot_summary)
has_post_valid_years <- "post_conservation_valid_year_count" %in% names(plot_summary)

plot_review_lut <- plot_summary %>%
  dplyr::mutate(
    low_valid_years_flag = dplyr::case_when(
      has_pre_valid_years & .data$pre_conservation_valid_year_count < max(.data$pre_conservation_valid_year_count, na.rm = TRUE) ~ TRUE,
      has_post_valid_years & .data$post_conservation_valid_year_count < max(.data$post_conservation_valid_year_count, na.rm = TRUE) ~ TRUE,
      TRUE ~ FALSE
    ),
    review_note = dplyr::case_when(
      .data$strong_increase_flag ~ "Strong post-conservation increase; inspect as potential hydrological response.",
      .data$strong_decrease_flag ~ "Strong post-conservation decrease; inspect as potential anomaly or local dry shift.",
      .data$low_inundation_flag ~ "Rarely inundated in both periods; likely dry/edge plot or classification issue.",
      .data$low_valid_years_flag ~ "Lower valid-year support; interpret cautiously.",
      TRUE ~ "Standard review."
    )
  ) %>%
  dplyr::select(
    "plot_id",
    dplyr::any_of(c("vegetation", "vegetation_adrian_group", "treatment", "area_ha")),
    "pre_conservation_inundation_frequency_pct",
    "post_conservation_inundation_frequency_pct",
    "post_minus_pre_inundation_frequency_pct_points",
    dplyr::any_of(c("pre_conservation_valid_year_count", "post_conservation_valid_year_count")),
    "inundation_change_class",
    "review_flag",
    "low_inundation_flag",
    "strong_increase_flag",
    "strong_decrease_flag",
    "low_valid_years_flag",
    "review_note"
  ) %>%
  dplyr::arrange(dplyr::desc(abs(.data$post_minus_pre_inundation_frequency_pct_points)))

readr::write_csv(plot_review_lut, plot_review_lut_path)
message("Wrote: ", plot_review_lut_path)


message("07i complete.")
