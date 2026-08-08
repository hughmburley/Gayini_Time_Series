# EXEMPLAR-1 - contrasting areas, each showing cover over time and water over time.
#
# WHAT THE CLIENT ASKED FOR, in his words: "examples of areas with different veg cover
# and inundation time series". Not a scatter. Not residual maps.
#
# THE RULINGS THAT SHAPE EVERY CHOICE HERE:
#
#   BW  Drawn from Output/tables/PARTREG_part_year_floor_inund.csv, NOT from the D1
#       dashboard cover panel. D1's cover trace is the mean of the 1-ha monitoring plots
#       inside the paddock while its water trace is the whole polygon - for Bala 29ca
#       that is a handful of hectares against ~16,000, sharing one x-axis and inviting
#       the reader to treat them as one place. That is a substantive C10 defect and is
#       not relabelled around. Here BOTH panels are the same cells, same years, pixel
#       support throughout.
#
#   BX  The cover panel plots veg_p50_spatial, the MEDIAN, never the p05 floor. Parts
#       run 33 to 32,399 cells, so a within-year spatial percentile is a different
#       statistic at each end of that range; the median is robust across it and is what
#       a lay reader means by "cover". The floor does not appear in this figure set.
#
#   BY  The water panel plots inund_pct - the share of this country's cells seen wet
#       within each year. It is NOT the headline between-year flood frequency, which
#       has no annual line by construction, and the caption says so in plain words.
#
#   BZ  Units are named for a lay audience: "the Inland Floodplain country in Bala 29ca".
#       Never "part", never a part_id, never a metric slug on the face.
#
# Registration is one transaction via gayini_write_and_register_figure(): ggsave, SHA-256
# and the registry row happen together, so a figure cannot exist unregistered.

suppressPackageStartupMessages({
  library(ggplot2); library(patchwork); library(DBI); library(RSQLite)
})

root <- normalizePath(".", winslash = "/")
source(file.path(root, "R/gayini_figure_register.R"))

SRC     <- file.path(root, "Output/tables/PARTREG_part_year_floor_inund.csv")
OUT_DIR <- file.path(root, "Output/figures/exemplars")
RUN_ID  <- "EXEMPLAR1_20260808"
MIN_CELLS <- 500L   # a client exemplar must be a real place, not 33 cells

stopifnot(file.exists(SRC))
d <- utils::read.csv(SRC, stringsAsFactors = FALSE)
stopifnot(nrow(d) == 4025L, length(unique(d$part_id)) == 115L)

## ---- Gate 2: which units -------------------------------------------------------
u <- do.call(rbind, lapply(split(d, d$part_id), function(g) data.frame(
  part_id = g$part_id[1], zone_name = g$zone_name[1], community = g$community[1],
  community_short = g$community_short[1], cells = g$n_pixels_part[1],
  water = mean(g$inund_pct), cover = mean(g$veg_p50_spatial),
  stringsAsFactors = FALSE)))
u$area_ha <- u$cells * (24.970268^2 / 1e4)   # DERIVED from the side, never typed

elig <- u[u$cells >= MIN_CELLS, ]
cat(sprintf("  %d of %d parts carry >= %d cells and are eligible\n",
            nrow(elig), nrow(u), MIN_CELLS))

pick <- do.call(rbind, lapply(split(elig, elig$community_short), function(g) {
  g <- g[order(g$water), ]
  mid <- which.min(abs(g$water - stats::median(g$water)))
  out <- g[c(1L, mid, nrow(g)), ]
  out$role <- c("driest", "middle", "wettest")
  out
}))
pick <- pick[order(match(pick$community_short, c("aeolian", "riverine", "inland")),
                   pick$water), ]

cat("\n-- Gate 2: the nine units, reported before anything is drawn --\n")
for (i in seq_len(nrow(pick))) with(pick[i, ], cat(sprintf(
  "  %-9s %-8s %-28s %7.0f ha  water %5.1f%%  cover %5.1f%%\n",
  community_short, role, zone_name, area_ha, water, cover)))

## ---- lay-audience naming (Ruling BZ) -------------------------------------------
LAY <- c(aeolian = "Aeolian Chenopod country",
         riverine = "Riverine Chenopod country",
         inland = "Inland Floodplain country")
lay_name <- function(cs, zn) sprintf("the %s in %s", LAY[[cs]], zn)

PAL <- c(aeolian = "#C79A3B", riverine = "#3B8A8F", inland = "#2165AC")
WATER <- "#2E6DB0"
INK <- "#26302E"; BODY <- "#5F6B67"; MUTED <- "#8A8378"

th <- function(base = 11) {
  theme_minimal(base_size = base) +
    theme(panel.grid.minor = element_blank(),
          panel.grid.major = element_line(colour = "#EFEBE0", linewidth = 0.4),
          axis.text = element_text(colour = MUTED),
          axis.title = element_text(colour = BODY),
          plot.title = element_text(colour = INK, face = "bold", size = base + 1),
          plot.subtitle = element_text(colour = BODY, size = base - 1.6),
          plot.caption = element_text(colour = MUTED, size = base - 3, hjust = 0),
          plot.title.position = "plot", plot.caption.position = "plot")
}

## ---- Gate 1: one figure per unit -----------------------------------------------
rows <- list()
for (i in seq_len(nrow(pick))) {
  p <- pick[i, ]
  g <- d[d$part_id == p$part_id, ]
  g <- g[order(g$water_year), ]
  nm <- lay_name(p$community_short, p$zone_name)
  col <- PAL[[p$community_short]]

  mean_cover <- mean(g$veg_p50_spatial)
  mean_water <- mean(g$inund_pct)

  # TOP - cover. One statistic only: the 35-year typical value.
  a <- ggplot(g, aes(water_year, veg_p50_spatial)) +
    geom_hline(yintercept = mean_cover, linetype = "dashed", colour = "grey60",
               linewidth = 0.4) +
    geom_line(colour = col, linewidth = 0.7) +
    geom_point(colour = col, size = 1.5) +
    scale_y_continuous(limits = c(0, 100)) +
    scale_x_continuous(breaks = seq(1990, 2020, 10)) +
    coord_cartesian(xlim = c(1987.5, 2022.5)) +
    # THE STATISTIC LIVES IN THE SUBTITLE, NOT ON THE PANEL. An in-panel annotation at
    # the series mean sat on top of the line here and behind the bars below; a subtitle
    # cannot collide with the data whatever the unit's values turn out to be.
    labs(subtitle = sprintf("Typical ground cover (green + dead) — 35-year average %.0f%%",
                            mean_cover),
         x = NULL, y = "Typical ground cover (%)") +
    th()

  # BOTTOM - water. Ruling BY: a share of ground within each year.
  b <- ggplot(g, aes(water_year, inund_pct)) +
    geom_hline(yintercept = mean_water, linetype = "dashed", colour = "grey60",
               linewidth = 0.4) +
    geom_col(fill = WATER, width = 0.68) +
    scale_y_continuous(limits = c(0, 100)) +
    # NEVER scale_x_continuous(limits=) here: a scale limit DROPS data, and with
    # geom_col the 1988 and 2022 bars extend past 1988/2022 and were silently deleted -
    # 2 of 35 years missing from every water panel. coord_cartesian zooms instead.
    scale_x_continuous(breaks = seq(1990, 2020, 10)) +
    coord_cartesian(xlim = c(1987.5, 2022.5)) +
    labs(x = "Water year", y = "Share under water (%)",
         subtitle = sprintf(
           "How much of this country went under water each year — 35-year average %.0f%%",
           mean_water)) +
    th()

  fig <- a / b +
    patchwork::plot_layout(heights = c(1, 1)) +
    patchwork::plot_annotation(
      title = sprintf("Ground cover and flooding: %s", nm),
      subtitle = sprintf("%s hectares within %s · every year from 1988 to 2022",
                         format(round(p$area_ha), big.mark = ","), p$zone_name),
      theme = th())

  path <- file.path(OUT_DIR, sprintf("EX1_%s_%s.png", p$community_short,
                                     gsub("[^A-Za-z0-9]+", "_", p$zone_name)))
  title <- sprintf("Ground cover and flooding over 35 years: %s", nm)
  caption <- paste0(
    "Support: pixel. Both panels describe the SAME cells over the same 35 water years - ",
    sprintf("the %s within %s, %s cells (%s ha). ",
            LAY[[p$community_short]], p$zone_name,
            format(p$cells, big.mark = ","), format(round(p$area_ha), big.mark = ",")),
    "Upper panel: the typical (median) total ground cover, green plus dead, across this ",
    "country's cells within each year. Lower panel: the share of this country's cells ",
    "seen under water within each year - this is NOT the headline flood frequency, ",
    "which counts wet years per cell and has no annual line. ",
    "Scope: non-treed ground, whole area, full record, 1988-2022.")

  r <- gayini_write_and_register_figure(
    plot = fig, path = path, title = title, caption = caption,
    support_level = "pixel", figure_level = "unit", run_id = RUN_ID,
    domain = "client_exemplars", recommended_use = "client report",
    provenance_note = paste(
      "EXEMPLAR-1 under Rulings BW/BX/BY/BZ. Source",
      "Output/tables/PARTREG_part_year_floor_inund.csv; cover is veg_p50_spatial",
      "(median within year across the unit's cells, Ruling BX - the p05 floor is",
      "deliberately absent), water is inund_pct (share of the unit's cells wet within",
      "the year, Ruling BY). Both panels are the same cells: no plot/pixel mixing."),
    width = 9, height = 7, dpi = 150)

  cat(sprintf("  [registered] %-44s %s\n", basename(path), substr(r$checksum_sha256, 1, 12)))
  rows[[length(rows) + 1L]] <- data.frame(
    figure = basename(path), unit_lay_name = nm, part_id = p$part_id,
    zone_name = p$zone_name, community = p$community, role = p$role,
    cells = p$cells, area_ha = round(p$area_ha, 3),
    mean_water_pct = round(p$water, 4), mean_cover_pct = round(p$cover, 4),
    support_level = "pixel",
    scope_filter = "treed_context_flag = 0 AND regime_band <> 'context'",
    pixel_constant = 24.970268^2 / 1e4, denominator = "the unit's own valid cells",
    period_label = "1988-2022", checksum_sha256_first50 = r$checksum_sha256,
    stringsAsFactors = FALSE)
}

sel <- do.call(rbind, rows)
stopifnot(!any(is.na(sel$support_level)), !any(is.na(sel$scope_filter)),
          !any(is.na(sel$pixel_constant)), !any(is.na(sel$denominator)),
          !any(is.na(sel$period_label)))
dir.create(file.path(root, "Output/tables"), showWarnings = FALSE, recursive = TRUE)
utils::write.csv(sel, file.path(root, "Output/tables/EXEMPLAR1_units.csv"),
                 row.names = FALSE)
cat(sprintf("\n  %d figures registered; selection written to Output/tables/EXEMPLAR1_units.csv\n",
            nrow(sel)))
