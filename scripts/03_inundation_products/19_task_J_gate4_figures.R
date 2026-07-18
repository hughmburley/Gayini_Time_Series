# ------------------------------------------------------------------------------
# Script: scripts/03_inundation_products/19_task_J_gate4_figures.R
# Purpose: Tier 1 · Task J · GATE 4 (part 2) — the four figures. Builds the six
#          diff rasters J-F2 needs (1994,1999,2004,2009,2014,2018) natively in
#          EPSG:28355, reprojects the CONTINUOUS diff to EPSG:8058 (bilinear) for
#          display only, and renders J-F1..J-F4 with the PINNED styling. Every
#          raster write is re-read from a fresh terra::rast() and asserted (ondisk
#          group). Descriptive; NOT an effect estimate.
# Workflow stage: 03_inundation_products (raster + figures) · Tier 1 Task J
# Styling PINNED (spec): gayini_theme_map(13) + gayini_change_scale_fill(60);
#   boundary #222f2d lw 0.6, paddocks #6d706b lw 0.16, ggsave 12 x 7.4 dpi 220.
# raster_asset registration DEFERRED — Task H is running concurrently and owns
#   raster_asset; Task J does not touch the DB (stated in the change report).
# Inputs : annual stack (28355); gayini_boundary / management_zones (8058, paddocks);
#          Output/tables/task_J_gate4_{law_summary,residual_ranking}.csv
# Outputs: Output/rasters/task_J/diff_pp_{C}_{28355,8058}.tif  (gitignored)
#          Output/figures/{maps,plots}/task_J/*.png            (gitignored)
#          Output/tables/task_J_gate4_raster_assertions.csv    (committable)
# ------------------------------------------------------------------------------

root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", getwd()), winslash = "/", mustWork = TRUE)
source(file.path(root_dir, "R", "inundation_pre_post_raster_functions.R"))
source(file.path(root_dir, "R", "gayini_plotting_helpers.R"))
source(file.path(root_dir, "scripts", "03_inundation_products", "internal", "task_J_prepost_placebo_impl.R"))
suppressPackageStartupMessages({
  library(terra); library(sf); library(dplyr); library(readr)
  library(ggplot2); library(patchwork); library(tidyterra); library(DBI); library(RSQLite)
})
sf::sf_use_s2(FALSE)

rasters_dir <- file.path(root_dir, "Output", "rasters")
spatial_dir <- file.path(root_dir, "Output", "spatial_8058")
tables_dir  <- file.path(root_dir, "Output", "tables")
taskj_rdir  <- file.path(rasters_dir, "task_J")
fig_map_dir <- file.path(root_dir, "Output", "figures", "maps", "task_J")
fig_plt_dir <- file.path(root_dir, "Output", "figures", "plots", "task_J")
for (d in c(taskj_rdir, fig_map_dir, fig_plt_dir)) dir.create(d, recursive = TRUE, showWarnings = FALSE)

DATES <- c(1994L, 1999L, 2004L, 2009L, 2014L, 2018L)   # J-F2 set: 5 independent placebos + real
REAL  <- 2018L

wet   <- terra::rast(file.path(rasters_dir, "inundation_annual_stack", "annual_wet_any_1988_2023.tif"))
valid <- terra::rast(file.path(rasters_dir, "inundation_annual_stack", "annual_valid_any_1988_2023.tif"))
boundary_8058 <- sf::st_read(file.path(spatial_dir, "gayini_boundary_epsg8058.gpkg"), quiet = TRUE)
paddocks_8058 <- sf::st_read(file.path(spatial_dir, "management_zones_epsg8058.gpkg"), quiet = TRUE)
bmask <- terra::rasterize(terra::vect(sf::st_transform(boundary_8058, terra::crs(wet))), wet[[1]], field = 1)

## ---------------- Part A: build 6 diff rasters, 28355 -> 8058, ondisk asserts ----
ondisk <- list(); diff28 <- list()
for (C in DATES) {
  b <- taskj_build_one_date(wet, valid, C)
  p28 <- file.path(taskj_rdir, sprintf("diff_pp_%d_28355.tif", C))
  wr <- taskj_write_and_assert(b$diff, p28, label = sprintf("diff%d_28355", C))
  ondisk[[length(ondisk) + 1]] <- wr$checks
  diff28[[as.character(C)]] <- wr$disk
  rm(b); gc()
}

# common 8058 display grid: project 2018, crop to boundary bbox + pad -> template
bb  <- sf::st_bbox(boundary_8058); pad <- 900
tmpl <- terra::crop(
  terra::project(diff28[["2018"]], "EPSG:8058", method = "bilinear"),
  terra::ext(bb[["xmin"]] - pad, bb[["xmax"]] + pad, bb[["ymin"]] - pad, bb[["ymax"]] + pad)
)
bvect <- terra::vect(boundary_8058)
diff85 <- list()
for (C in DATES) {
  p <- terra::mask(terra::project(diff28[[as.character(C)]], tmpl, method = "bilinear"), bvect)
  names(p) <- "diff_pp"
  p85 <- file.path(taskj_rdir, sprintf("diff_pp_%d_8058.tif", C))
  wr <- taskj_write_and_assert(p, p85, label = sprintf("diff%d_8058", C))
  ondisk[[length(ondisk) + 1]] <- wr$checks
  diff85[[as.character(C)]] <- wr$disk
}
ondisk_tbl <- dplyr::bind_rows(ondisk)
readr::write_csv(ondisk_tbl, file.path(tables_dir, "task_J_gate4_raster_assertions.csv"))
cat(sprintf("ondisk assertions: %d rows, all pass = %s\n", nrow(ondisk_tbl), all(ondisk_tbl$passed)))
stopifnot(all(ondisk_tbl$passed))

## ---------------- Part B: figures ----
# J-F1 — the 2018 difference map
jf1 <- ggplot() +
  tidyterra::geom_spatraster(data = diff85[["2018"]], ggplot2::aes(fill = diff_pp)) +
  geom_sf(data = paddocks_8058, colour = "#6d706b", linewidth = 0.16, fill = NA) +
  geom_sf(data = boundary_8058, colour = "#222f2d", linewidth = 0.6,  fill = NA) +
  gayini_change_scale_fill(60) +
  gayini_theme_map(13) +
  labs(title = "Post-minus-pre inundation change with paddock context",
       subtitle = "Between-year flood frequency change, percentage points",
       caption = paste("Red = less frequent post; blue = more frequent post.",
                       "Not hydroperiod or duration. Descriptive only: see J-F3."))
ggsave(file.path(fig_map_dir, "J-F1_2018_difference_map.png"), jf1, width = 12, height = 7.4, dpi = 220, bg = "white")

# J-F2 — six-panel ladder, one shared legend, identical +/-60 scale
mk_panel <- function(C) {
  g <- ggplot() +
    tidyterra::geom_spatraster(data = diff85[[as.character(C)]], ggplot2::aes(fill = diff_pp)) +
    geom_sf(data = paddocks_8058, colour = "#6d706b", linewidth = 0.10, fill = NA) +
    geom_sf(data = boundary_8058, colour = "#222f2d", linewidth = 0.45, fill = NA) +
    gayini_change_scale_fill(60) +
    gayini_theme_map(11) +
    labs(title = sprintf("%d  (post %d-%d)%s", C, C, C + 4L, if (C == REAL) "  — actual cuts" else ""))
  if (C == REAL) g <- g + theme(plot.background = element_rect(colour = "#1f2d2a", linewidth = 1.5, fill = NA))
  g
}
jf2 <- patchwork::wrap_plots(lapply(DATES, mk_panel), ncol = 3, guides = "collect") +
  patchwork::plot_annotation(
    title = "Placebo ladder: post-minus-pre change at five dates when nothing happened, plus 2018",
    caption = "No cuts occurred at any date except 2018. Identical ±60 pp scale on every panel; heavier border marks the real date.",
    theme = gayini_theme_map(13)) &
  theme(legend.position = "bottom")
ggsave(file.path(fig_map_dir, "J-F2_placebo_ladder_six_panel.png"), jf2, width = 13.5, height = 9.0, dpi = 220, bg = "white")

# J-F3 — the law (this figure carries the task)
rk <- readr::read_csv(file.path(tables_dir, "task_J_gate4_residual_ranking.csv"), show_col_types = FALSE) |>
  dplyr::mutate(logq = log(q_ratio))
ls <- readr::read_csv(file.path(tables_dir, "task_J_gate4_law_summary.csv"), show_col_types = FALSE) |>
  dplyr::filter(model == "primary_24placebo")
a <- ls$intercept; b <- ls$b_logq; rsd <- ls$resid_sd_ddof1_pp
r2 <- ls$r2; pred18 <- ls$pred_2018_pp; obs18 <- ls$obs_2018_pp; res18 <- ls$resid_2018_pp; rank18 <- ls$resid_2018_rank_of_25
xg <- seq(min(rk$logq), max(rk$logq), length.out = 120)
band <- data.frame(logq = xg, pred = a + b * xg, lo = a + b * xg - rsd, hi = a + b * xg + rsd)
pts_pl  <- rk |> dplyr::filter(!is_real)
pt_real <- rk |> dplyr::filter(is_real)
lab <- rk |> dplyr::filter(cut_year %in% c(2005, 2009, 2018))

jf3 <- ggplot() +
  geom_ribbon(data = band, aes(x = logq, ymin = lo, ymax = hi), fill = "#2f74b5", alpha = 0.10) +
  geom_line(data = band, aes(x = logq, y = pred), colour = "#1f2d2a", linewidth = 0.7) +
  geom_hline(yintercept = 0, colour = "grey80", linewidth = 0.3) +
  geom_point(data = pts_pl,  aes(x = logq, y = diff_pp), colour = "#6d706b", size = 2.2) +
  geom_point(data = pt_real, aes(x = logq, y = diff_pp), colour = "#b84a4a", size = 4, shape = 18) +
  ggrepel::geom_text_repel(data = lab, aes(x = logq, y = diff_pp,
                           label = sprintf("%d", cut_year)), size = 3.6, segment.colour = "grey60",
                           colour = "#1f2d2a", box.padding = 0.6, min.segment.length = 0) +
  annotate("text", x = min(rk$logq), y = max(rk$diff_pp), hjust = 0, vjust = 1, size = 3.7, colour = "#1f2d2a",
           label = sprintf("Law (24 placebos): diff = %+.2f %+.2f·log(q)\nR² = %.3f\n2018: predicted %+.2f, observed %+.2f\nresidual %+.2f pp — rank %d of 25",
                           a, b, r2, pred18, obs18, res18, rank18)) +
  labs(title = "The pre/post difference is largely set by how wet the two windows were",
       subtitle = "Each point a cut date; line + ±1 residual-SD band fitted on the 24 placebos only (2018 excluded)",
       x = "log(flow ratio, post ÷ pre)  —  gauge 410040",
       y = "Between-year flood frequency change (pp)",
       caption = paste0("2009 sits at almost the same flow as 2018 and falls well below it; 2005 is the one placebo above 2018, at the dry end.\n",
                        "Band is ±1 residual SD (descriptive spread) — NOT a confidence interval: only 5 of 25 dates are independent.")) +
  theme_minimal(base_size = 13, base_family = "Arial") +
  theme(plot.title = element_text(face = "bold", colour = "#1f2d2a"),
        plot.subtitle = element_text(colour = "#4d5652"),
        plot.caption = element_text(hjust = 0, colour = "grey35", size = rel(0.8)),
        panel.grid.minor = element_blank())
ggsave(file.path(fig_plt_dir, "J-F3_the_law.png"), jf3, width = 12, height = 7.4, dpi = 220, bg = "white")

# J-F4 — annual series: whole-farm annual wet EXTENT (per year) + flow, post-2018 shaded
wetf <- terra::mask(wet, bmask); validf <- terra::mask(valid, bmask)
wsum <- as.numeric(terra::global(wetf,   "sum", na.rm = TRUE)[, 1])
vsum <- as.numeric(terra::global(validf, "sum", na.rm = TRUE)[, 1])
con <- dbConnect(SQLite(), file.path(root_dir, "Output", "database", "Gayini_Results.sqlite"))
flow <- dbGetQuery(con, "SELECT water_year, mean_flow_mld FROM gauge_water_year_flow WHERE station_id='410040'")
dbDisconnect(con)
series <- data.frame(wy_start = 1988:2022, wet_extent_pct = 100 * wsum / vsum)
series$flow_mld <- flow$mean_flow_mld[match(series$wy_start + 1L, flow$water_year)]
shade <- data.frame(xmin = 2017.5, xmax = 2022.5)

p_ext <- ggplot(series, aes(wy_start, wet_extent_pct)) +
  geom_rect(data = shade, inherit.aes = FALSE, aes(xmin = xmin, xmax = xmax, ymin = -Inf, ymax = Inf), fill = "#2f74b5", alpha = 0.10) +
  geom_vline(xintercept = 2022, colour = "#b84a4a", linewidth = 0.4, linetype = "22") +
  geom_line(colour = "#2f74b5", linewidth = 0.8) + geom_point(colour = "#2f74b5", size = 1.6) +
  labs(title = "Whole-farm annual wet extent and flow, 1988–2022",
       subtitle = "Per-water-year wet extent (the between-year flood frequency is its multi-year window mean)",
       y = "Wet extent (% of farm wet that year)", x = NULL) +
  theme_minimal(base_size = 13, base_family = "Arial") +
  theme(plot.title = element_text(face = "bold", colour = "#1f2d2a"),
        plot.subtitle = element_text(colour = "#4d5652"), panel.grid.minor = element_blank(),
        axis.text.x = element_blank())
p_flow <- ggplot(series, aes(wy_start, flow_mld)) +
  geom_rect(data = shade, inherit.aes = FALSE, aes(xmin = xmin, xmax = xmax, ymin = -Inf, ymax = Inf), fill = "#2f74b5", alpha = 0.10) +
  geom_vline(xintercept = 2022, colour = "#b84a4a", linewidth = 0.4, linetype = "22") +
  geom_col(fill = "#4c78a8", width = 0.7) +
  labs(y = "Mean flow (ML/d), gauge 410040", x = "Water year (start year)",
       caption = "Shaded = post-2018 window (WY2018-19…WY2022-23); dashed line = WY2022-23. Extent is per-year spatial coverage, not the headline between-year frequency.") +
  theme_minimal(base_size = 13, base_family = "Arial") +
  theme(plot.caption = element_text(hjust = 0, colour = "grey35", size = rel(0.8)), panel.grid.minor = element_blank())
jf4 <- p_ext / p_flow + patchwork::plot_layout(heights = c(1, 0.9))
ggsave(file.path(fig_plt_dir, "J-F4_annual_series.png"), jf4, width = 12, height = 7.8, dpi = 220, bg = "white")

cat("\nWrote figures:\n")
for (f in c("J-F1_2018_difference_map.png", "J-F2_placebo_ladder_six_panel.png")) cat("  ", file.path(fig_map_dir, f), "\n")
for (f in c("J-F3_the_law.png", "J-F4_annual_series.png")) cat("  ", file.path(fig_plt_dir, f), "\n")
cat("  ", file.path(tables_dir, "task_J_gate4_raster_assertions.csv"), "\n")
cat("\nraster_asset registration DEFERRED (Task H owns raster_asset and is running concurrently).\n")
cat("================ GATE 4 FIGURES COMPLETE ================\n")
