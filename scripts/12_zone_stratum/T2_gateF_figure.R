#!/usr/bin/env Rscript
# T2 Gate F - the reference-gap DECOMPOSITION (deck-grade). A single "gap narrows"
# number hides the mechanism; this shows ref_change_pp beside grazed_change_pp per
# community so the three distinct stories are visible at a glance:
#   Aeolian  - gap narrows because the REFERENCE side rose (+14.8 pp)
#   Riverine - gap narrows because the GRAZED side FELL (-9.0 pp)
#   Inland   - gap holds; both sides drifted down together
# Panel B: the same narrowing appears in both flood and non-flood years (gap_change_pp),
# so it is not a flood-year-only artefact.
# Change = late (>=2013) minus early (<=1997), pp. Reference sits BELOW grazed (gap<0).

suppressPackageStartupMessages({library(ggplot2); library(patchwork); library(DBI); library(RSQLite)})
root <- normalizePath(".", winslash = "/")
source(file.path(root, "R/gayini_figure_register.R"))
fig_dir <- file.path(root, "Output/figures/diagnostics")

con <- DBI::dbConnect(RSQLite::SQLite(), file.path(root, "Output/database/Gayini_Results.sqlite"))
d <- DBI::dbGetQuery(con, "SELECT * FROM v_reference_gap_decomposition")
DBI::dbDisconnect(con)
d$comm <- vapply(strsplit(d$community, " "), `[`, character(1), 1)

allc <- d[d$window == "all" & d$flood_class == "all", ]
dec <- rbind(
  data.frame(comm = allc$comm, side = "Reference (No grazing)", change = allc$ref_change_pp),
  data.frame(comm = allc$comm, side = "Grazed (median)",        change = allc$grazed_change_pp))
dec$side <- factor(dec$side, levels = c("Reference (No grazing)", "Grazed (median)"))
lab <- allc[, c("comm", "gap_change_pp", "n_ref_paddocks", "n_grazed_zones")]

pA <- ggplot(dec, aes(comm, change, fill = side)) +
  geom_col(position = position_dodge(width = 0.75), width = 0.68) +
  geom_hline(yintercept = 0, colour = "grey40", linewidth = 0.3) +
  geom_text(data = lab, inherit.aes = FALSE, aes(comm, y = pmax(0, 0) + 16,
            label = sprintf("gap change\n%+.1f pp", gap_change_pp)),
            size = 3.1, fontface = "bold", colour = "grey20") +
  geom_text(data = lab, inherit.aes = FALSE, aes(comm, y = -14,
            label = sprintf("n_ref=%d  n_grz=%d", n_ref_paddocks, n_grazed_zones)),
            size = 2.7, colour = "grey40") +
  scale_fill_manual(values = c("#238b45", "#bdbdbd"), name = NULL) +
  labs(title = "A. Gap-change decomposition: which side moved (pp, 1988-97 -> 2013-22)",
       x = NULL, y = "change in veg_p05_spatial (pp)") +
  theme_minimal(base_size = 11) + theme(legend.position = "top")

fb <- d[d$window == "all" & d$flood_class %in% c("flood", "non_flood"), ]
fb$flood_class <- factor(fb$flood_class, levels = c("flood", "non_flood"))
pB <- ggplot(fb, aes(comm, gap_change_pp, fill = flood_class)) +
  geom_col(position = position_dodge(width = 0.7), width = 0.6) +
  geom_hline(yintercept = 0, colour = "grey40", linewidth = 0.3) +
  scale_fill_manual(values = c("#4292c6", "#f0a860"),
                    labels = c("flood years", "non-flood years"), name = NULL) +
  labs(title = "B. Gap change by flood class - narrowing is not a flood-year-only effect",
       x = NULL, y = "gap change (pp)") +
  theme_minimal(base_size = 11) + theme(legend.position = "top")

p <- pA / pB + plot_layout(heights = c(1.4, 1)) +
  plot_annotation(
    title = "T2 F - Reference-gap decomposition (veg_p05_spatial floor, by community)",
    caption = paste0(
      "Support: pixel (aggregation_unit = community_window; min 30 px/cell). Change = late",
      " (WY>=2013) minus early (WY<=1997). Reference paddocks sit BELOW grazed in all three",
      " communities (gap < 0); bars show how each SIDE moved. veg_p05_spatial is a within-",
      "year spatial percentile, not the census floor. Cropping history unavailable =>",
      " conserved-vs-grazed, not conserved-vs-formerly-cropped. Source: v_reference_gap_decomposition."),
    theme = theme(plot.caption = element_text(hjust = 0, size = 8)))

gayini_write_and_register_figure(
  p, file.path(fig_dir, "T2_F_gap_decomposition.png"),
  title = "T2 F reference-gap decomposition",
  caption = paste("Support: pixel. ref_change vs grazed_change per community shows the",
                  "gap-narrowing mechanism differs (Aeolian ref rises; Riverine grazed falls;",
                  "Inland holds); narrowing persists in flood and non-flood years."),
  support_level = "pixel", figure_level = "deliverable", run_id = "T2_gateF",
  provenance_note = "From v_reference_gap_decomposition; conserved-vs-grazed only.",
  width = 11, height = 9)
cat("[done] T2_F_gap_decomposition.png\n")
