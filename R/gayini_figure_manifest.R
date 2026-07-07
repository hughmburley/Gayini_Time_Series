## -----------------------------------------------------------------------------
## Gayini remote sensing workflow
## gayini_figure_manifest.R
## -----------------------------------------------------------------------------

## Purpose:
## Figure manifest, contact sheet and Task 15 QA helpers.


gayini_task15_manifest_row <- function(root_dir,
                                       figure_id,
                                       priority,
                                       figure_title,
                                       output_path,
                                       source_script,
                                       source_data,
                                       deck_section,
                                       intended_slide = NA_character_,
                                       status = "created",
                                       reason_if_skipped = NA_character_,
                                       caption_suggestion = NA_character_,
                                       caveat_text = NA_character_,
                                       qa_status = "pass",
                                       qa_notes = NA_character_) {
  tibble::tibble(
    figure_id = figure_id,
    priority = priority,
    figure_title = figure_title,
    output_path = gayini_relative_path(root_dir, output_path),
    source_script = source_script,
    source_data = source_data,
    deck_section = deck_section,
    intended_slide = intended_slide,
    status = status,
    reason_if_skipped = reason_if_skipped,
    caption_suggestion = caption_suggestion,
    caveat_text = caveat_text,
    qa_status = qa_status,
    qa_notes = qa_notes
  )
}


gayini_task15_skip_row <- function(root_dir,
                                   figure_id,
                                   priority,
                                   figure_title,
                                   source_script,
                                   source_data,
                                   deck_section,
                                   reason_if_skipped,
                                   caveat_text = NA_character_) {
  gayini_task15_manifest_row(
    root_dir = root_dir,
    figure_id = figure_id,
    priority = priority,
    figure_title = figure_title,
    output_path = NA_character_,
    source_script = source_script,
    source_data = source_data,
    deck_section = deck_section,
    status = "missing_input",
    reason_if_skipped = reason_if_skipped,
    caption_suggestion = NA_character_,
    caveat_text = caveat_text,
    qa_status = "warning",
    qa_notes = reason_if_skipped
  )
}


gayini_task15_write_manifest <- function(manifest, path) {
  gayini_ensure_dir(path, path_is_file = TRUE)
  readr::write_csv(manifest, path)
  message("Wrote: ", path)
  invisible(manifest)
}


gayini_task15_deck_asset_register <- function(manifest) {
  manifest |>
    dplyr::filter(.data$status %in% c("created", "updated")) |>
    dplyr::transmute(
      asset_id = paste0("TASK15_", stringr::str_replace_all(.data$figure_id, "[^A-Za-z0-9]+", "_")),
      output_path = .data$output_path,
      title = .data$figure_title,
      deck_section = .data$deck_section,
      priority = .data$priority,
      replacement_use = .data$caption_suggestion,
      caveat_text = .data$caveat_text,
      qa_status = .data$qa_status,
      notes = .data$qa_notes
    )
}


gayini_task15_write_contact_sheet <- function(manifest,
                                              root_dir,
                                              output_path,
                                              priority_filter = "P0",
                                              tile_width = 520,
                                              tile_height = 340,
                                              columns = 3L) {
  if (!requireNamespace("magick", quietly = TRUE)) {
    warning("Package magick is unavailable; contact sheet was not written.", call. = FALSE)
    return(NA_character_)
  }

  rows <- manifest |>
    dplyr::filter(
      .data$priority %in% priority_filter,
      .data$status %in% c("created", "updated"),
      !is.na(.data$output_path)
    ) |>
    dplyr::mutate(abs_path = file.path(root_dir, .data$output_path)) |>
    dplyr::filter(file.exists(.data$abs_path))

  if (nrow(rows) == 0L) {
    warning("No figure files available for contact sheet.", call. = FALSE)
    return(NA_character_)
  }

  make_tile <- function(row) {
    image <- magick::image_read(row$abs_path)
    image <- magick::image_background(image, "white", flatten = TRUE)
    image <- magick::image_resize(image, paste0(tile_width, "x", tile_height - 52, ">"))
    image <- magick::image_extent(
      image,
      geometry = paste0(tile_width, "x", tile_height - 52),
      gravity = "center",
      color = "white"
    )

    canvas <- magick::image_blank(tile_width, tile_height, color = "white")
    canvas <- magick::image_composite(canvas, image, offset = "+0+52")
    label <- paste0(row$figure_id, "  ", row$figure_title)
    label <- stringr::str_trunc(label, width = 76)
    canvas <- magick::image_annotate(
      canvas,
      text = label,
      size = 18,
      color = "#1f2d2a",
      gravity = "northwest",
      location = "+10+10",
      weight = 700
    )
    magick::image_border(canvas, color = "#d9d9d9", geometry = "1x1")
  }

  tile_list <- lapply(seq_len(nrow(rows)), function(i) make_tile(rows[i, ]))
  tiles <- do.call(c, tile_list)
  montage <- magick::image_montage(
    tiles,
    tile = paste0(columns, "x"),
    geometry = "+12+12",
    bg = "white"
  )

  info <- magick::image_info(montage)
  title <- magick::image_blank(info$width, 72, color = "white")
  title <- magick::image_annotate(
    title,
    text = paste0("Gayini Task 15 refreshed ", paste(priority_filter, collapse = "/"), " figures"),
    size = 28,
    color = "#1f2d2a",
    gravity = "west",
    location = "+18+0",
    weight = 700
  )

  sheet <- magick::image_append(c(title, montage), stack = TRUE)
  gayini_ensure_dir(output_path, path_is_file = TRUE)
  magick::image_write(sheet, path = output_path)
  message("Wrote: ", output_path)
  output_path
}


gayini_task15_metric_table <- function(root_dir, input_paths) {
  current_values <- tibble::tribble(
    ~metric, ~current_deck_value,
    "Total 1 ha monitoring plots", 66,
    "Ground-cover interpretation plots", 57,
    "Treed / flagged plots", 9,
    "Annual inundation years", 10,
    "Plots wetter post-2019", 34,
    "Much wetter plots", 10,
    "Wetter plots", 24,
    "Mean annual inundation change", 9.2,
    "Mean total vegetation change", 0.9,
    "MER / annual directions agree", 48,
    "MER / annual review flags", 12,
    "MER / annual near-zero plots", 6
  )

  plot_base <- readr::read_csv(input_paths[["plot_base_csv"]], show_col_types = FALSE)
  gc_interp <- readr::read_csv(input_paths[["ground_cover_interpretation_csv"]], show_col_types = FALSE)
  mer_compare <- if (!is.na(input_paths[["mer_comparison_csv"]]) && file.exists(input_paths[["mer_comparison_csv"]])) {
    readr::read_csv(input_paths[["mer_comparison_csv"]], show_col_types = FALSE)
  } else {
    tibble::tibble()
  }

  treed_or_flagged <- plot_base |>
    dplyr::mutate(
      treed_plot_flag = as.logical(.data$treed_plot_flag),
      ground_cover_exclusion_flag = as.logical(.data$ground_cover_exclusion_flag),
      review_flag = dplyr::coalesce(.data$treed_plot_flag, FALSE) |
        dplyr::coalesce(.data$ground_cover_exclusion_flag, FALSE)
    )

  refreshed_values <- tibble::tribble(
    ~metric, ~refreshed_value,
    "Total 1 ha monitoring plots", dplyr::n_distinct(plot_base$plot_id),
    "Ground-cover interpretation plots", dplyr::n_distinct(gc_interp$plot_id),
    "Treed / flagged plots", sum(treed_or_flagged$review_flag, na.rm = TRUE),
    "Annual inundation years", {
      vals <- unique(stats::na.omit(plot_base$n_annual_inundation_years))
      if (length(vals) == 0L) NA_real_ else max(vals)
    },
    "Plots wetter post-2019", sum(plot_base$inundation_change_class %in% c("much_wetter_post", "wetter_post"), na.rm = TRUE),
    "Much wetter plots", sum(plot_base$inundation_change_class == "much_wetter_post", na.rm = TRUE),
    "Wetter plots", sum(plot_base$inundation_change_class == "wetter_post", na.rm = TRUE),
    "Mean annual inundation change", mean(plot_base$post_minus_pre_inundation_frequency_pct_points, na.rm = TRUE),
    "Mean total vegetation change", mean(gc_interp$delta_total_veg_pct, na.rm = TRUE),
    "MER / annual directions agree", if (nrow(mer_compare) > 0L) sum(stringr::str_detect(mer_compare$direction_agreement, "^agree"), na.rm = TRUE) else NA_real_,
    "MER / annual review flags", if (nrow(mer_compare) > 0L) sum(mer_compare$review_flag != "no_flag", na.rm = TRUE) else NA_real_,
    "MER / annual near-zero plots", if (nrow(mer_compare) > 0L) sum(mer_compare$direction_agreement == "agree_near_zero" | mer_compare$review_flag == "near_zero", na.rm = TRUE) else NA_real_
  )

  current_values |>
    dplyr::left_join(refreshed_values, by = "metric") |>
    dplyr::mutate(
      difference = .data$refreshed_value - .data$current_deck_value,
      status = dplyr::case_when(
        is.na(.data$refreshed_value) ~ "not_recomputed",
        abs(.data$difference) <= dplyr::if_else(stringr::str_detect(.data$metric, "Mean"), 0.15, 0.01) ~ "matches",
        TRUE ~ "differs"
      ),
      notes = dplyr::case_when(
        .data$status == "matches" ~ "Matches current deck value after recomputation from curated tables.",
        .data$status == "not_recomputed" ~ "Required source table was unavailable.",
        stringr::str_detect(.data$metric, "^MER / annual") ~ "Differs because Task 15 recomputed this check from Output/csv/MER/mer_vs_annual_occurrence_raster_comparison_by_plot.csv. The packaged agreement summary still reports the current deck values; Adrian should confirm which MER comparison source should drive the deck.",
        TRUE ~ "Differs from current deck value; review whether this reflects input updates, grouping, filtering or a coding issue."
      )
    )
}
