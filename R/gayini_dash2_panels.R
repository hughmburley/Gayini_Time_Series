# gayini_dash2_panels.R - DASH2 additions. ADDITIVE ONLY (Ruling BL).
#
# Nothing here replaces a v1 panel. gayini_build_dashboard() gains an optional `v2`
# argument that defaults to NULL, so every existing call renders exactly as before and
# the 21 D1_paddock_* sheets are untouched.
#
# WHAT CHANGES IN v2, and why it is a data fix rather than a label fix: v1's cover panel
# is the mean of the monitoring plots inside the paddock - a few hectares - while its
# water panel is the whole polygon. They share an x-axis and describe different ground.
# v2 draws BOTH from the paddock's census cells, so the two panels are the same cells.
#
# The theme, palette, date scale and arrangement are the v1 ones, reused not rebuilt.

suppressPackageStartupMessages({library(ggplot2)})

DASH2_PARTYEAR <- file.path("Output", "tables", "PARTREG_part_year_floor_inund.csv")


## Ruling EC and spec 2.8: ONE sentence, defined once, used by the dashboards AND by
## TEMPORAL-1, so the two products cannot drift into two descriptions of one method.
## Plain register - no capitals-as-emphasis, no "TEMPORAL", no "140 SEASONAL composites".
GAYINI_SEASONAL_BASIS_SENTENCE <- paste(
  "Cover is measured for each cell across all seasons in the record rather than once a",
  "year; the number of measurements behind a cell ranges from 5 to 140.")


## One paddock's annual series, built on ITS CENSUS CELLS ----
##
## Water is sum(wet_pixels) / sum(valid_pixels) across the paddock's parts - an exact
## pooled share, not a weighted average of shares. Cover is the area-weighted mean of
## the parts' within-year medians; a percentile cannot be pooled exactly, and the
## approximation is named on the panel rather than hidden.
gayini_dash2_unit_series <- function(zone_fid, part_year = NULL) {
  d <- if (is.null(part_year)) utils::read.csv(DASH2_PARTYEAR, stringsAsFactors = FALSE)
       else part_year
  g <- d[d$zone_fid == zone_fid, , drop = FALSE]
  if (nrow(g) == 0) return(NULL)
  s <- split(g, g$water_year)
  out <- do.call(rbind, lapply(names(s), function(y) {
    x <- s[[y]]
    data.frame(year = as.integer(y),
               freq_pct = 100 * sum(x$wet_pixels) / sum(x$valid_pixels),
               cover_pct = stats::weighted.mean(x$veg_p50_spatial, x$n_pixels_part),
               n_cells = sum(x$n_pixels_part),
               n_parts = nrow(x), stringsAsFactors = FALSE)
  }))
  out[order(out$year), ]
}


## v2 flooding panel - same geometry as v1, corrected labels (spec 3.1) ----
gayini_dash2_flood_panel <- function(series, base_size = 10, unit_note = NULL,
                                     date_lim = NULL, date_breaks = NULL) {
  cols <- gayini_dashboard_cols()
  mean_freq <- mean(series$freq_pct, na.rm = TRUE)
  series$date <- gayini_year_to_date(series$year)
  ggplot2::ggplot(series, ggplot2::aes(x = date, y = freq_pct)) +
    ggplot2::geom_hline(yintercept = mean_freq, linetype = "dashed",
                        colour = "grey55", linewidth = 0.4) +
    ggplot2::annotate("text", x = min(series$date), y = mean_freq, vjust = -0.5, hjust = 0,
                      size = base_size / 3.6, colour = "grey45",
                      label = sprintf("35-yr mean %.0f%%", mean_freq)) +
    ggplot2::geom_line(colour = cols[["flood"]], linewidth = 0.6) +
    ggplot2::geom_point(colour = cols[["flood"]], size = 1.1) +
    gayini_series_date_scale(date_lim, date_breaks) +
    ggplot2::scale_y_continuous(limits = c(0, 100)) +
    ## Spec 3.1: the "(wet / valid years)" parenthetical is GONE - the denominator is
    ## cells, not years. The plain-English half was already correct and stays.
    ggplot2::labs(title = "How much of the paddock went under water each year",
                  subtitle = paste0("Share of the paddock's census cells wet that year",
                                    if (!is.null(unit_note)) paste0(" - ", unit_note) else ""),
                  x = NULL, y = "Share under water (%)") +
    gayini_dashboard_theme(base_size)
}


## v2 cover panel - the paddock's cells, one value per water year (spec 2) ----
gayini_dash2_cover_panel <- function(series, base_size = 10, unit_note = NULL,
                                     date_lim = NULL, date_breaks = NULL) {
  cols <- gayini_dashboard_cols()
  series$date <- gayini_year_to_date(series$year)
  ggplot2::ggplot(series, ggplot2::aes(x = date, y = cover_pct)) +
    ggplot2::geom_line(colour = cols[["total_veg"]], linewidth = 0.6) +
    ggplot2::geom_point(colour = cols[["total_veg"]], size = 1.1) +
    gayini_series_date_scale(date_lim, date_breaks) +
    ggplot2::scale_y_continuous(limits = c(0, 100)) +
    ggplot2::labs(title = "Typical ground cover (green + dead)",
                  subtitle = paste0("Measured across every census cell in the paddock",
                                    if (!is.null(unit_note)) paste0(" - ", unit_note) else ""),
                  x = NULL, y = "Cover (%)") +
    gayini_dashboard_theme(base_size)
}


## Label overrides applied to REUSED v1 panels, after the fact ----
##
## These are ggplot layers added on top, so the v1 functions are not edited at all.
##
## SPEC 3.2 IS OVERRIDDEN AND NOT APPLIED - see gayini_dash2_box_fix(). Spec 3.4 IS
## applied, because in v2 the gauge is fed the cell-based series and its quantity really
## is a share of cells.
gayini_dash2_box_fix <- function(p) {
  ## Spec 3.2 asked for "Share of cells wet, mean over years (%)". The panel plots
  ## flood_frequency_pct = 100 * wet_years / valid_years at PLOT support - a genuine
  ## BETWEEN-YEAR frequency, already correctly labelled. Applying the AZ/CX wording here
  ## would introduce the very error AZ exists to prevent, in reverse. The y-axis is left
  ## alone; only the p-value goes (spec 3.6).
  p + ggplot2::labs(caption = NULL)
}

gayini_dash2_gauge_fix <- function(p) {
  ## Spec 3.4: in v2 this gauge summarises the cell-based series, so the AZ/CX wording
  ## is correct here.
  p + ggplot2::labs(x = "Share of cells wet, mean over years (%)")
}

## Spec 3.5's checkerboard footnote. The map panel is a cowplot COMPOSITE (it carries a
## farm-locator inset), so labs(caption=) on it is inert - the first attempt added a
## caption that never rendered. The note is placed on the sheet HEADER instead, via
## gayini_dash2_header_note(), which is drawn by cowplot::draw_label and does render.
gayini_dash2_map_note <- function()
  ## short enough to sit on the header line without running off the sheet; the full
  ## statement lives in the run note and in the client README
  paste("Checkerboard bands: per-community terciles cut on the interpolated surface -",
        "the only route to balanced strata; 4.9% of cells move under the counted one.")

gayini_dash2_resp_fix <- function(p, subset_pct = NA_real_, subset_n = NA_integer_,
                                  unit_n = NA_integer_, unit_mean = NA_real_,
                                  subset_mean = NA_real_) {
  ## Ruling DZ check 3 / spec 3.3: the x-axis is NOT touched. It draws per-cell
  ## flood_freq_pct counted on the 8058 grid - a genuine between-year frequency.
  ##
  ## The y NAME is set by scale_y_continuous(), and labs(y=) LOSES to a scale name.
  ## The scale is mutated in place, which keeps its expansion; ggproto is reference
  ## semantics, so this edits the panel's own scale without touching the closed file.
  ## RULING DV: one common y-scale across every sheet in the set, so panels can be read
  ## against each other. 0-100 is the natural common range for a cover percentage.
  for (sc in p$scales$scales) {
    if ("y" %in% sc$aesthetics) {
      sc$name <- "5th-percentile ground cover, per cell (%)"   # Ruling EC
      sc$limits <- c(0, 100)
    }
  }

  ## RULING DU + the Ruling DZ check-4 correction. The panel's own subtitle printed the
  ## subset share against ALL classes, while the sheet's scope is non-treed - which is
  ## why three sheets read 56 / 54 / 33 where the non-treed denominator gives 61 / 65 /
  ## 34.6. The corrected share is written here, and the population difference is stated
  ## rather than left for the reader to infer.
  if (is.finite(subset_pct)) {
    p$labels$subtitle <- paste(strwrap(paste0(
      "This panel describes only the ", format(subset_n, big.mark = ","),
      " cells of this paddock's main plant community - ",
      sprintf("%.0f%%", subset_pct), " of the paddock. Grey = those cells; ",
      "line = trend; diamond = this unit. ",
      sprintf("It is wet %.0f%% of years, while the paddock as a whole is wet %.0f%% - ",
              subset_mean, unit_mean),
      "both are right; they describe different ground."), width = 104),
      collapse = "\n")
  }

  ## Ruling DT: no sentence about correspondence or a pending correction on a
  ## client-facing face. The basis statement stays; the email sentence goes to the run
  ## record. Ruling DX: the tercile sentence moves here, into the footnote block, with
  ## "interpolated surface" and "balanced strata" off the face.
  p$labels$caption <- paste0(
    p$labels$caption, "\n",
    paste(strwrap(paste(
      GAYINI_SEASONAL_BASIS_SENTENCE,
      "Wetness bands on the map are cut separately for each plant community, and a small",
      "share of cells falls either side of a band edge if the alternative water surface",
      "is used."), width = 118), collapse = "\n"))
  p
}


## Ruling DW: drop the unit marker from the "Where it sits" boxplot ----
##
## The marker is gayini_unit_flood_frequency() - the WHOLE POLYGON on the native 28355
## stack - while the top panel and the gauge are now the paddock's census cells on 8058.
## They do not reconcile: Dinan 10 reads 10.1% against a top panel of 5.1%, Bala 29ca
## 10.3% against 8.5%. Redefining the marker to the cell-based value would reconcile it
## arithmetically, but the boxplot cloud is PLOT support (66 monitoring plots), so that
## would put a pixel number on a plot cloud - reintroducing on this sheet the very
## support mix DASH2 exists to remove. Under DW's pre-registered fork the marker is
## REMOVED and the boxplots stand as community context.
gayini_dash2_drop_marker <- function(p) {
  before <- length(p$layers)
  keep <- vapply(p$layers, function(L) {
    cls <- class(L$geom)[1]
    if (cls == "GeomPoint" && is.data.frame(L$data) && nrow(L$data) == 1L) return(FALSE)
    lab <- L$aes_params$label
    if (cls == "GeomText" && !is.null(lab) &&
        any(grepl("this unit", as.character(lab), fixed = TRUE))) return(FALSE)
    TRUE
  }, logical(1))
  p$layers <- p$layers[keep]
  if (before - length(p$layers) != 2L)
    stop("Ruling DW: expected to drop exactly 2 marker layers, dropped ",
         before - length(p$layers))
  p$labels$subtitle <- paste(strwrap(paste(
    "Community context from the monitoring plots. This paddock is not marked: its own",
    "value is a census-cell figure and these boxes are plot measurements."),
    width = 62), collapse = "\n")
  p
}


## Register a sheet that gayini_save_figure() has just written ----
##
## WHY NOT gayini_write_and_register_figure() DIRECTLY (stated override, spec 5): that
## function does its own ggsave with the DEFAULT device, while the dashboards render
## through ragg::agg_png. Routing the composed sheet through it would change the
## renderer and therefore the sheet's appearance, which spec 1 forbids - panel geometry
## and fonts stay as they are. So the WRITE stays with gayini_save_figure and this does
## the REGISTER half, reusing gayini_sha256_first50 and the identical INSERT OR REPLACE
## column set. It is called immediately after the write inside gayini_build_dashboard,
## so a v2 sheet still cannot exist unregistered.
gayini_dash2_register <- function(path, title, caption, run_id, support_level = "pixel",
                                  figure_level = "unit", provenance_note = NA_character_,
                                  db_path = file.path("Output", "database", "Gayini_Results.sqlite"),
                                  root = normalizePath(".", winslash = "/")) {
  if (!grepl(tolower(support_level), tolower(caption), fixed = TRUE))
    stop("caption must state the support level '", support_level, "'")
  checksum <- gayini_sha256_first50(path)
  abs_path  <- gsub("\\\\", "/", normalizePath(path, winslash = "/"))
  rel_path  <- sub(paste0(gsub("\\\\", "/", root), "/"), "", abs_path, fixed = TRUE)
  slug <- gsub("[^A-Za-z0-9]+", "_", tools::file_path_sans_ext(basename(path)))
  fid  <- paste0("figure_", tolower(slug))

  con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  DBI::dbBegin(con)
  tryCatch({
    DBI::dbExecute(con,
      "INSERT OR REPLACE INTO figure_asset
         (figure_asset_id, path, title, domain, metric_id, recommended_use,
          checksum_sha256, path_exists, qa_status, run_id, superseded_flag,
          framing_label, provenance_note, caption, support_level, figure_level)
       VALUES (?,?,?,?,NULL,?,?,1,'REVIEW',?,0,?,?,?,?,?)",
      params = list(fid, rel_path, title, "client_deliverables", "client report",
                    checksum, run_id, "census_8058", provenance_note, caption,
                    support_level, figure_level))
    DBI::dbCommit(con)
  }, error = function(e) { DBI::dbRollback(con); stop(e) })
  invisible(list(figure_asset_id = fid, path = rel_path, checksum_sha256 = checksum))
}
