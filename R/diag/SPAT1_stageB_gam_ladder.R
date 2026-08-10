# SPAT-1 Stage B - the GAM ladder, per Ruling EU.
#
# WHY THIS EXISTS. Stage 0 measured the straight line departing from the GAM at the wet
# end. Averaging x within a block and averaging y within a block are not the same
# operation when y is a nonlinear function of x, and the discrepancy grows with block
# size. So a climbing OLS ladder is exactly what a curved relationship produces even with
# no scale effect at all, and the OLS ladder alone cannot tell the two apart.
#
# THE COMPARABLE SCALAR. A GAM has no single slope, so each rung's GAM is summarised by
# its AVERAGE MARGINAL EFFECT - the mean of dy/dx over that rung's own observed x, by
# central differences on the fitted curve. That is the quantity an OLS slope estimates
# when the relationship is straight, so the two ladders are directly comparable.
#
# READING: if the OLS ladder moves and the GAM ladder is flat, the movement is curvature.
# If both move together, it is not.
#
# k is kept small and scaled to the rung, because the coarse rungs carry few units and a
# k=10 basis on 40 blocks would fit noise. edf is reported so the flexibility actually
# used is visible rather than assumed.

suppressPackageStartupMessages({library(mgcv)})

root <- normalizePath(".", winslash = "/")
OUT <- file.path(root, "Output", "spatial")
units <- utils::read.csv(file.path(OUT, "SPAT1_ladder_block_units.csv"),
                         stringsAsFactors = FALSE)
resid_src <- file.path("C:/Users/HUGHPC~1/AppData/Local/Temp/claude",
                       "d--Github-repos-Gayini",
                       "00d60f21-fee6-4bc8-a50a-2623689d36ac/scratchpad/SPAT1_gam_input.csv")
stopifnot(file.exists(resid_src))

ame_of <- function(m, xs) {
  # average marginal effect: mean dy/dx over the observed x, by central differences
  h <- max(diff(range(xs)) / 500, 1e-4)
  d <- (as.numeric(stats::predict(m, newdata = data.frame(flood_freq_pct = xs + h))) -
        as.numeric(stats::predict(m, newdata = data.frame(flood_freq_pct = xs - h)))) /
    (2 * h)
  mean(d)
}

rows <- list()

# ---- rung 0, the pixel census -------------------------------------------------------
px <- utils::read.csv(resid_src, stringsAsFactors = FALSE)
for (cs in c("aeolian", "riverine", "inland")) {
  g <- px[px$community_short == cs, ]
  m <- mgcv::bam(veg_p05 ~ s(flood_freq_pct, bs = "tp", k = 10), data = g,
                 method = "fREML", discrete = TRUE)
  rows[[length(rows) + 1L]] <- data.frame(
    rung = "rung 0 (pixel census)", block_m = 24.970268, community = cs,
    n_units = nrow(g), k_basis = 10, edf = sum(m$edf),
    ame = ame_of(m, g$flood_freq_pct), stringsAsFactors = FALSE)
}

# ---- the fitted rungs ----------------------------------------------------------------
for (bm in sort(unique(units$block_m))) {
  u <- units[units$block_m == bm, ]
  for (cs in c("aeolian", "riverine", "inland")) {
    g <- u[u$community_short == cs, ]
    if (nrow(g) < 15) next
    k <- max(4, min(8, floor(nrow(g) / 10)))
    m <- mgcv::gam(y ~ s(x, bs = "tp", k = k), data = g, method = "REML")
    h <- max(diff(range(g$x)) / 500, 1e-4)
    d <- (as.numeric(stats::predict(m, newdata = data.frame(x = g$x + h))) -
          as.numeric(stats::predict(m, newdata = data.frame(x = g$x - h)))) / (2 * h)
    rows[[length(rows) + 1L]] <- data.frame(
      rung = sprintf("%.0f m", bm), block_m = bm, community = cs,
      n_units = nrow(g), k_basis = k, edf = sum(m$edf), ame = mean(d),
      stringsAsFactors = FALSE)
  }
}

gl <- do.call(rbind, rows)
gl$estimand <- paste("average marginal effect of the fitted GAM - the mean of dy/dx over",
                     "the rung's own observed x, directly comparable to an OLS slope")
gl$metric <- "veg_p05_temporal_mean"
gl$support_level <- "pixel, aggregated to block x vegetation community"
gl$period_label <- "1988-2022 (35 water years)"
gl$eu_note <- paste("Ruling EU: read beside SPAT1_ladder_slopes.csv. If the OLS ladder",
                    "moves and this one is flat, the movement is aggregation-induced",
                    "curvature bias rather than a scale effect.")
utils::write.csv(gl, file.path(OUT, "SPAT1_ladder_gam.csv"), row.names = FALSE)

cat("\n[EU] the two ladders side by side - OLS slope vs GAM average marginal effect\n")
ols <- utils::read.csv(file.path(OUT, "SPAT1_ladder_slopes.csv"), stringsAsFactors = FALSE)
ols <- ols[ols$subset == "all", ]
for (cs in c("aeolian", "riverine", "inland")) {
  a <- ols[ols$community == cs, ]; a <- a[order(a$block_m), ]
  b <- gl[gl$community == cs, ]; b <- b[order(b$block_m), ]
  cat(sprintf("  %-9s OLS  %s\n", cs,
              paste(sprintf("%s:%+.3f", sub(" .*", "", a$rung), a$slope), collapse = "  ")))
  cat(sprintf("  %-9s GAM  %s\n", "",
              paste(sprintf("%s:%+.3f", sub(" .*", "", b$rung), b$ame), collapse = "  ")))
  sp_o <- max(a$slope) - min(a$slope)
  sp_g <- max(b$ame) - min(b$ame)
  FLAT <- 0.15
  # Both spreads are read. An earlier version tested the OLS spread first and returned
  # "both flat" for a community whose GAM ladder moved by 0.335 - the verdict has to look
  # at the ladder it is making a claim about.
  verdict <- if (sp_o <= FLAT && sp_g <= FLAT) {
    "BOTH LADDERS FLAT - scale-invariant on a neutral unit"
  } else if (sp_o > FLAT && sp_g <= sp_o / 2) {
    "the OLS movement is largely CURVATURE, not scale"
  } else if (sp_o <= FLAT && sp_g > FLAT) {
    paste("the OLS slope is flat while the GAM's average marginal effect is NOT -",
          "the straight line's slope survives aggregation while the SHAPE it is",
          "approximating does not. Neither a clean scale effect nor clean curvature")
  } else {
    "BOTH LADDERS MOVE TOGETHER - not explained by curvature"
  }
  cat(sprintf("  %-9s spread across the ladder: OLS %.3f, GAM %.3f\n", "", sp_o, sp_g))
  cat(sprintf("  %-9s -> %s\n\n", "", verdict))
}
cat(sprintf("  [wrote] SPAT1_ladder_gam.csv  %d rows\n", nrow(gl)))
