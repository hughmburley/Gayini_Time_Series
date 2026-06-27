## -----------------------------------------------------------------------------
## Gayini remote sensing workflow
## gayini_interpretation_filters.R
## -----------------------------------------------------------------------------


## Purpose:
## Shared interpretation filters for review/deck outputs.


gayini_exclude_treed_plots <- function(x,
                                       flag_col = "ground_cover_exclusion_flag") {
  if (!flag_col %in% names(x)) {
    return(x)
  }

  x %>%
    dplyr::filter(is.na(.data[[flag_col]]) | .data[[flag_col]] == FALSE)
}


gayini_filter_ground_cover_interpretation <- function(x,
                                                      flag_col = "ground_cover_exclusion_flag") {
  gayini_exclude_treed_plots(x, flag_col = flag_col)
}


gayini_select_main_gc_metric <- function(x,
                                         metric_col = NULL,
                                         main_metric_values = c(
                                           "total_veg_pct",
                                           "delta_total_veg_pct",
                                           "Total vegetation",
                                           "total vegetation"
                                         )) {
  if (is.null(metric_col) || !metric_col %in% names(x)) {
    return(x)
  }

  x %>%
    dplyr::filter(.data[[metric_col]] %in% main_metric_values)
}


gayini_standardise_veg_group_labels <- function(x,
                                                column = "simplified_vegetation_group") {
  if (!column %in% names(x)) {
    return(x)
  }

  x %>%
    dplyr::mutate(
      "{column}" := dplyr::case_when(
        is.na(.data[[column]]) ~ NA_character_,
        stringr::str_detect(stringr::str_to_lower(.data[[column]]), "black box") ~ "Black Box / Lignum",
        stringr::str_detect(stringr::str_to_lower(.data[[column]]), "river red gum|woodland|forest") ~ "Floodplain Woodland / Forest",
        stringr::str_detect(stringr::str_to_lower(.data[[column]]), "grass|chenopod|open") ~ "Open Grassland / Chenopod",
        TRUE ~ as.character(.data[[column]])
      )
    )
}
