# ------------------------------------------------------------------------------
# Script: scripts/03_inundation_products/29_build_s12_stratum_coverage_figure.R
# Purpose: Tier 2 · Task H · Gate E (G5) — S12: the stratum COVERAGE bar, simplified.
#          The old F5d_pixel_census had two facets — pixel area (coverage) AND
#          sampling density (points / 1000 ha). The census DISSOLVES the density
#          question (that was the "wet end is provisional" worry), so S12 keeps ONLY
#          the coverage half as a clean all-pixel bar and DROPS the sampling facet.
#
#          HELD TRAP (do not "fix"): Inland Floodplain = 717,629 / 1,080,157 =
#          66.44% of the MAPPED farm — "two-thirds of the mapped farm", on the
#          MAPPED basis (67,349 ha), exactly as written. The C1 instinct would
#          wrongly rebase it to the true farm (85,910.8 ha); it is correct as a
#          statement about the mapped area. Labelled "mapped" so it cannot be misread.
#
# Workflow stage: 03_inundation_products · Tier 2 Task H, Gate E, G5 (S12 simplify)
# Run mode: figure render (read-only DB query of the census view) · additive
# Key inputs:
#   - Output/database/Gayini_Results.sqlite :: v_pixel_census_by_veg_regime
# Key outputs (additive; Output/ gitignored; NOT registered — that is G7):
#   - Output/figures/S12_stratum_coverage_data.{png,pdf}
#
# NOTES:
#   - Palette = C1 checkerboard community hues (canonical deck palette), matching the rest of
#     the Gate E set (the old F5d used the F7-gradient palette — the deck's second palette).
#   - Coverage shown as % of MAPPED farm (= 100 × n_pixels / Σ n_pixels), labelled "mapped".
#     Sidesteps the D2 mislabel by computing + labelling the basis directly, not trusting the
#     view's "pct_of_farm" name.
#   - Read-only. STOP after render (last Gate E figure; then G6 cleanups + G7 registration).
# ------------------------------------------------------------------------------

## 1. Sources ----

root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", getwd()), winslash = "/", mustWork = TRUE)
source(file.path(root_dir, "R", "gayini_helpers.R"))
source(file.path(root_dir, "R", "gayini_output_helpers.R"))
source(file.path(root_dir, "R", "gayini_gradient_helpers.R"))
source(file.path(root_dir, "R", "gayini_veg_regime_functions.R"))
source(file.path(root_dir, "R", "gayini_descriptive_figures.R"))

suppressPackageStartupMessages({ library(DBI); library(RSQLite); library(dplyr); library(ggplot2) })

figures_dir <- file.path(root_dir, "Output", "figures")
db_path <- file.path(root_dir, "Output", "database", "Gayini_Results.sqlite")
gayini_stop_if_missing(db_path, label = "Gayini_Results.sqlite")

focus     <- gayini_focus_levels()
short     <- gayini_gradient_short_labels()
comm_hue  <- gayini_veg_regime_classes() |> dplyr::filter(.data$band == "mid") |>
  (\(x) stats::setNames(x$colour, x$community))()
CONTEXT_GREY <- "#9E9E9E"


## 2. Query the census view (read-only) + compute mapped-basis coverage ----

con <- dbConnect(SQLite(), db_path)
d <- dbGetQuery(con, "SELECT community, regime_band, treed_context_flag, n_pixels, area_ha
                      FROM v_pixel_census_by_veg_regime")
dbDisconnect(con)

total_px <- sum(d$n_pixels)
d <- d |>
  dplyr::mutate(is_context = treed_context_flag == 1L,
                pct_mapped = 100 * n_pixels / total_px,
                comm_short = ifelse(community %in% names(short), short[community], community),
                stratum = ifelse(is_context, paste0(comm_short, " · (context)"),
                                 paste0(comm_short, " · ", regime_band)),
                fill = ifelse(community %in% names(comm_hue), comm_hue[community], CONTEXT_GREY))

## Held-trap check: Inland must be 66.44% of mapped (verify against data, don't assume).
inland_pct <- sum(d$pct_mapped[grepl("Inland", d$community)])
inland_px  <- sum(d$n_pixels[grepl("Inland", d$community)])
stopifnot(round(inland_pct, 2) == 66.44, total_px == 1080157L, inland_px == 717629L)
message(sprintf("Held trap verified: Inland = %d / %d = %.2f%% of MAPPED farm.",
                inland_px, total_px, inland_pct))

## Order top→bottom: Aeolian low/mid/high, Riverine, Inland, then context.
ord <- d |>
  dplyr::mutate(cix = match(community, c(focus, "Floodplain Woodland / Forest", "Other / minor units")),
                bix = match(regime_band, c("low", "mid", "high", "context"))) |>
  dplyr::arrange(cix, bix)
d$stratum <- factor(d$stratum, levels = rev(ord$stratum))   # rev so Aeolian low is at TOP


## 3. Build — single coverage bar, sampling-density facet dropped ----

x_max <- max(d$pct_mapped)
p <- ggplot2::ggplot(d, ggplot2::aes(x = pct_mapped, y = stratum)) +
  ggplot2::geom_col(ggplot2::aes(fill = I(fill), alpha = I(ifelse(is_context, 0.5, 1))), width = 0.72) +
  ggplot2::geom_text(ggplot2::aes(label = sprintf("%.1f%%  ·  %s ha", pct_mapped,
                                                  formatC(area_ha, format = "d", big.mark = ","))),
                     hjust = -0.06, size = 2.8, colour = "grey20") +
  ## held-trap callout: the three Inland bars (below) sum to 66.44% of mapped.
  ## Placed in the empty upper-right (clear of the short Aeolian/Riverine bars).
  ggplot2::annotate("text", x = x_max * 0.52, y = 10.0,
                    label = "The three Inland Floodplain bars sum to\n66.44% of the MAPPED farm  (717,629 / 1,080,157 px)\n— “two-thirds of the mapped farm”, as written",
                    hjust = 0, vjust = 0.5, size = 3.0, fontface = "bold", colour = "#2E6DB0", lineheight = 1.0) +
  ggplot2::scale_x_continuous(name = "Coverage — % of the MAPPED farm (67,349 ha)",
                              expand = ggplot2::expansion(mult = c(0, 0.28)),
                              breaks = seq(0, 25, 5)) +
  ggplot2::scale_y_discrete(name = NULL) +
  ggplot2::labs(
    title = "S12 · How much of the mapped farm each stratum covers (all-pixel census)",
    subtitle = paste0("The sampling-density question the old slide asked (points / 1,000 ha) is DISSOLVED by the census — dropped. ",
                      "Coverage only.\nHELD TRAP: Inland Floodplain is 66.44% of the MAPPED farm — “two-thirds of the mapped farm”, ",
                      "on the mapped basis (67,349 ha), as written."),
    caption = paste0(
      "All-pixel census, EPSG:8058, 24.97 m. Bars = each stratum's share of the MAPPED farm (100 × n_pixels / 1,080,157). ",
      "Context rows (treed Woodland, Other) shown greyed.\n",
      "“Mapped” is deliberate: the mapped/classified area is 67,349 ha of the 85,910.8 ha farm (78.4%). The 66.44% is a share of MAPPED, ",
      "not of the whole farm — do not rebase it. Source: v_pixel_census_by_veg_regime.")) +
  ggplot2::theme_minimal(base_size = 11) +
  ggplot2::theme(
    plot.title = ggplot2::element_text(face = "bold", size = 12.5),
    plot.subtitle = ggplot2::element_text(size = 9, colour = "grey30", margin = ggplot2::margin(b = 8)),
    plot.caption = ggplot2::element_text(size = 7.4, colour = "grey40", hjust = 0, margin = ggplot2::margin(t = 10)),
    plot.caption.position = "plot", plot.title.position = "plot",
    panel.grid.major.y = ggplot2::element_blank(), panel.grid.minor = ggplot2::element_blank(),
    axis.text.y = ggplot2::element_text(size = 9.5))


## 4. Save ----

paths <- gayini_save_figure(p, figures_dir, "S12_stratum_coverage", kind = "data",
                            width = 10.4, height = 5.6, dpi = 300)

message("\n==================== S12 COMPLETE — STOP FOR REVIEW ====================")
message("Coverage figure: ", paths$png)
message("Sampling-density facet dropped; coverage bar kept. Held trap: Inland = 66.44% of MAPPED (as written).")
message("Distinct from the old F5d_pixel_census. NOT registered (G7). STOP: review, then G6 + G7.")
