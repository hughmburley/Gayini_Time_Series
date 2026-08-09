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

gayini_dash2_resp_fix <- function(p) {
  ## Spec 3a. The x-axis is NOT touched: it draws per-cell flood_freq_pct counted on the
  ## 8058 grid, which is a genuine between-year frequency and is correctly labelled.
  ##
  ## The y NAME is set by scale_y_continuous(), and labs(y=) LOSES to a scale name - the
  ## first attempt did exactly that and the axis still read "Vegetation floor - veg_p05".
  ## The scale is mutated in place instead, which keeps its limits and expansion; ggproto
  ## objects are reference semantics, so this edits the panel's own scale.
  for (sc in p$scales$scales) {
    if ("y" %in% sc$aesthetics) sc$name <- "Cover in the poorest seasons (%)"
  }
  ## Spec 3a: state the SEASONAL basis. Appended to the panel's own caption rather than
  ## replacing it - the existing lines carry the sparse-tail and autocorrelation notes.
  ## wrapped: an unwrapped line ran off the right edge of the sheet
  p$labels$caption <- paste0(
    p$labels$caption, "\n",
    paste(strwrap(paste(
      "Cover here is a per-cell TEMPORAL percentile over 140 SEASONAL composites",
      "(per-cell n 5 to 140), not the 35-value annual basis. A correction on this point",
      "is going to the client separately."), width = 118), collapse = "\n"))
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
