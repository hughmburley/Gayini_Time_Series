####################################################################################################


## GAYINI REMOTE SENSING PROJECT


## Tier 1 · shared flooding-gradient vocabulary (community order + colours) and
## database loaders for the descriptive figures (F2-F4) and later rungs.


## The analysis is organised around the THREE non-treed communities as a dry->wet
## gradient (mean annual occurrence, verified from the spine):
##   Aeolian Chenopod Shrublands            ~4%   (dry)
##   Riverine Chenopod Shrublands           ~12%  (a bit wetter)
##   Inland Floodplain Shrublands / Swamps  ~31%  (wet)
## Floodplain Woodland / Forest (treed, ~27%) is shown as MUTED CONTEXT only —
## canopy confounds ground cover, so it is excluded from the analytical focus.


####################################################################################################


## Community order + colours (define ONCE; F3/F4 and later rungs reuse) ----

## Dry -> wet gradient order, treed context community last.
gayini_gradient_levels <- function() {
  c(
    "Aeolian Chenopod Shrublands",
    "Riverine Chenopod Shrublands",
    "Inland Floodplain Shrublands / Swamps",
    "Floodplain Woodland / Forest"
  )
}

## The three non-treed focus communities, in gradient order.
gayini_focus_levels <- function() {
  gayini_gradient_levels()[1:3]
}

GAYINI_CONTEXT_COMMUNITY <- "Floodplain Woodland / Forest"

## Dry -> wet colour ramp for the three focus communities; muted grey for the
## treed context community.
gayini_gradient_palette <- function() {
  c(
    "Aeolian Chenopod Shrublands"           = "#C2A25A",  # dry ochre
    "Riverine Chenopod Shrublands"          = "#5AB4AC",  # a bit wetter (teal)
    "Inland Floodplain Shrublands / Swamps" = "#2166AC",  # wet (blue)
    "Floodplain Woodland / Forest"          = "#9C9C9C"   # muted context (treed)
  )
}

## Short labels for compact axes / strips.
gayini_gradient_short_labels <- function() {
  c(
    "Aeolian Chenopod Shrublands"           = "Aeolian Chenopod (dry)",
    "Riverine Chenopod Shrublands"          = "Riverine Chenopod",
    "Inland Floodplain Shrublands / Swamps" = "Inland Floodplain (wet)",
    "Floodplain Woodland / Forest"          = "Woodland / Forest (context)"
  )
}

## Wet / dry / masked cell colours for the F2 occurrence-strip concept.
gayini_occurrence_cell_palette <- function() {
  c(
    "wet"    = "#2166AC",
    "dry"    = "#E8D9A0",
    "masked" = "#BDBDBD"
  )
}

## Sequential occurrence ramp (0 -> 100%) for the F3 heatmap.
gayini_occurrence_ramp <- function() {
  c("#F7FBFF", "#DEEBF7", "#C6DBEF", "#9ECAE1", "#6BAED6", "#4292C6", "#2171B5", "#08519C", "#08306B")
}

## Add a gradient-ordered factor + focus/context flags to any table carrying
## simplified_vegetation_group.
gayini_apply_gradient_order <- function(df, group_col = "simplified_vegetation_group") {
  df[[group_col]] <- factor(as.character(df[[group_col]]), levels = gayini_gradient_levels())
  df$is_focus_community <- as.character(df[[group_col]]) %in% gayini_focus_levels()
  df
}


## Database loaders ----

gayini_results_db_path <- function(root = getwd()) {
  file.path(root, "Output", "database", "Gayini_Results.sqlite")
}

gayini_connect_results_db <- function(root = getwd()) {
  path <- gayini_results_db_path(root)
  gayini_stop_if_missing(path, label = "results SQLite database")
  DBI::dbConnect(RSQLite::SQLite(), path)
}

## Headline occurrence metric — BETWEEN-YEAR annual wet frequency ----
##
## For each plot: 100 x wet-valid years / valid years. This is the annual flood
## probability the F8-F9 probability surface is built toward, so it is the SINGLE
## metric that runs the whole ladder (F2 -> F9). Aeolian ~9%, Riverine ~22%,
## Inland Floodplain ~50%, Woodland/Forest ~44% (context).
##
## The spine's `annual_occurrence_pct` (within-year wet COVERAGE, averaged) is
## retained as a clearly-named SECONDARY "wet extent" metric — not the headline.

gayini_plot_between_year_frequency <- function(spine) {
  spine |>
    dplyr::group_by(.data$plot_id, .data$simplified_vegetation_group, .data$treed_plot_flag) |>
    dplyr::summarise(
      valid_years = sum(.data$annual_valid_any == 1, na.rm = TRUE),
      wet_years   = sum(.data$annual_valid_any == 1 & .data$annual_wet_any == 1, na.rm = TRUE),
      wet_extent_coverage_pct = mean(.data$annual_occurrence_pct, na.rm = TRUE),  # secondary
      .groups = "drop"
    ) |>
    dplyr::mutate(
      flood_frequency_pct = 100 * .data$wet_years / .data$valid_years            # headline
    )
}

## Site-wide annual series consistent with the between-year headline: the share
## of plots inundated (wet at least once) in each water year.
gayini_site_share_plots_wet <- function(spine) {
  spine |>
    dplyr::group_by(.data$water_year) |>
    dplyr::summarise(
      pct_plots_wet = 100 * mean(.data$annual_wet_any == 1, na.rm = TRUE),
      .groups = "drop"
    )
}


## The modelling spine (one row per plot x water year).
gayini_load_spine <- function(root = getwd()) {
  con <- gayini_connect_results_db(root)
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  DBI::dbGetQuery(con, "SELECT * FROM v_plot_year_analysis_spine") |>
    tibble::as_tibble()
}

## Per-plot annual inundation series (carries valid_coverage_pct, support_class).
gayini_load_inundation_timeseries <- function(root = getwd()) {
  con <- gayini_connect_results_db(root)
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  DBI::dbGetQuery(con, "SELECT * FROM v_plot_timeseries_inundation_annual") |>
    tibble::as_tibble()
}


## Figures-manifest helpers ({step}_{concept|data} convention) ----

## One row: step (F2/F3/F4...), kind (concept|data), path, inputs, crs.
gayini_manifest_row <- function(step, kind, path, inputs, crs = "n/a", root = getwd()) {
  tibble::tibble(
    step   = step,
    kind   = kind,
    path   = as.character(tryCatch(fs::path_rel(path, start = root), error = function(e) path)),
    inputs = inputs,
    crs    = crs
  )
}

## Merge new rows into Output/figures/figures_manifest.csv, replacing any prior
## rows for the same steps (idempotent) and keeping rows from other steps (F1).
gayini_update_figures_manifest <- function(new_rows, root = getwd()) {
  manifest_path <- file.path(root, "Output", "figures", "figures_manifest.csv")
  gayini_ensure_dir(manifest_path, path_is_file = TRUE)

  if (file.exists(manifest_path)) {
    existing <- readr::read_csv(manifest_path, show_col_types = FALSE)
    existing <- existing[!(existing$step %in% unique(new_rows$step)), , drop = FALSE]
    combined <- dplyr::bind_rows(existing, new_rows)
  } else {
    combined <- new_rows
  }

  combined <- combined |> dplyr::arrange(.data$step, .data$kind, .data$path)
  readr::write_csv(combined, manifest_path)
  message("Wrote: ", manifest_path)
  combined
}
