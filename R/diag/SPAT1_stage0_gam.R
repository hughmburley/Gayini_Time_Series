# SPAT-1 Stage 0 - the GAM fitted alongside the OLS, FOR SHAPE ONLY.
#
# Spec: docs/spatial/Gayini_CC_spec_SPAT1.md section 3.
#
# THE OLS IS THE REGISTERED EXPECTATION. This GAM is reported alongside it and is NOT used
# to compute Stage A's residuals, so the residual field carries no smoother's flexibility.
# If a GAM's wiggle were absorbed into the residuals, the variogram would then be measuring
# what the smoother failed to fit as well as what the country does, and the two could not
# be told apart.
#
# NO P-VALUES (section 7). Reported: effective degrees of freedom, residual SD, and the
# correlation between fitted and observed - plus the fitted curve on a grid, so the shape
# can be inspected rather than described.
#
# Data crosses from python as a CSV because this R installation has no arrow.

suppressPackageStartupMessages({library(mgcv)})

root <- normalizePath(".", winslash = "/")
OUT <- file.path(root, "Output", "spatial")
SRC <- file.path("C:/Users/HUGHPC~1/AppData/Local/Temp/claude",
                 "d--Github-repos-Gayini",
                 "00d60f21-fee6-4bc8-a50a-2623689d36ac/scratchpad/SPAT1_gam_input.csv")
stopifnot(file.exists(SRC))

d <- utils::read.csv(SRC, stringsAsFactors = FALSE)
cat(sprintf("[gam] %s cells\n", format(nrow(d), big.mark = ",")))
stopifnot(nrow(d) == 988829L)

rows <- list()
curves <- list()
for (cs in c("aeolian", "riverine", "inland")) {
  g <- d[d$community_short == cs, ]
  m <- mgcv::bam(veg_p05 ~ s(flood_freq_pct, bs = "tp", k = 10), data = g,
                 method = "fREML", discrete = TRUE)
  fit <- as.numeric(stats::fitted(m))
  res <- g$veg_p05 - fit
  edf <- sum(m$edf)
  rows[[length(rows) + 1L]] <- data.frame(
    fit_id = paste0("SPAT1_stage0_gam_", cs), scope = cs,
    estimator = "GAM (thin-plate spline, k=10) at PIXEL grain - FOR SHAPE ONLY",
    metric = "veg_p05_temporal_mean", n_cells = nrow(g),
    edf_total = edf, resid_sd = stats::sd(res),
    r_fitted_vs_observed = stats::cor(fit, g$veg_p05),
    used_for_residuals = "NO - Stage A residuals come from the OLS",
    stringsAsFactors = FALSE)
  xs <- seq(min(g$flood_freq_pct), max(g$flood_freq_pct), length.out = 120)
  pr <- as.numeric(stats::predict(m, newdata = data.frame(flood_freq_pct = xs)))
  curves[[length(curves) + 1L]] <- data.frame(community = cs, flood_freq_pct = xs,
                                              gam_fitted = pr, stringsAsFactors = FALSE)
  cat(sprintf("  %-9s n %9s  edf %5.2f  resid sd %6.3f  r %+.4f\n", cs,
              format(nrow(g), big.mark = ","), edf, stats::sd(res),
              stats::cor(fit, g$veg_p05)))
}

co <- do.call(rbind, rows)
co$support_level <- "pixel"
co$period_label <- "1988-2022 (35 water years)"
co$ci_lo <- "interval_pending_spat1_stage_a"
co$ci_hi <- "interval_pending_spat1_stage_a"
co$interval_reason <- paste(
  "WITHHELD ON PURPOSE, as for the OLS: an interval at pixel grain before Stage A would",
  "treat ~1M spatially autocorrelated cells as independent observations.")
utils::write.csv(co, file.path(OUT, "SPAT1_stage0_gam_coefficients.csv"),
                 row.names = FALSE)

cv <- do.call(rbind, curves)
utils::write.csv(cv, file.path(OUT, "SPAT1_stage0_gam_curves.csv"), row.names = FALSE)
cat("  [wrote] SPAT1_stage0_gam_coefficients.csv, SPAT1_stage0_gam_curves.csv\n")

# does the straight line depart from the shape anywhere it is supported?
ols <- utils::read.csv(file.path(OUT, "SPAT1_stage0_coefficients.csv"),
                       stringsAsFactors = FALSE)
cat("\n[shape] largest gap between the GAM curve and the OLS line, per community\n")
for (cs in c("aeolian", "riverine", "inland")) {
  o <- ols[ols$scope == cs, ]
  k <- cv[cv$community == cs, ]
  gap <- k$gam_fitted - (as.numeric(o$intercept) + as.numeric(o$slope) * k$flood_freq_pct)
  i <- which.max(abs(gap))
  cat(sprintf("  %-9s max |gap| %5.2f pp at %5.1f%% wet   (mean |gap| %.2f pp)\n",
              cs, abs(gap[i]), k$flood_freq_pct[i], mean(abs(gap))))
}
