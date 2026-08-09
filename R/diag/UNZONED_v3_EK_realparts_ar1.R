# Ruling EK - the AR(1) sensitivity, run on the OTHER side of the comparison.
#
# EK (10 Aug 2026): where a sensitivity analysis is run on one side of a stated
# comparison, it is run on the other side before either result is reported. An estimate
# that moves under a refit is a finding only once the comparator has been put through the
# same refit.
#
# THE PROBLEM EK FIXES. Arm B refitted the unzoned within estimator with AR(1) errors and
# the point estimate fell 31.8%. The comparator, the real parts' +0.1613, had no such
# refit - so the drop was uninterpretable. It could be a property of annual floor series
# everywhere, or something about unzoned patches, and nothing in hand distinguished them.
#
# SAME SPECIFICATION, both sides: demeaned within estimator, pixel-weighted, then refit
# with corAR1(form = ~ water_year | <unit>). The only difference is the unit - part_id
# here, patch_id there - which is the thing being compared.
#
# Ruling EM applies here too: a year counts only if it has >= 30 valid cells. Filtering
# on nulls alone would admit a spatial percentile computed over a handful of cells.
#
# OLS-within leads either way. AR(1) is a sensitivity, never a correction, and section 5
# stands: the within and between slopes are not two estimates of one number.

suppressPackageStartupMessages({library(nlme)})

root <- normalizePath(".", winslash = "/")
OUTD <- file.path(root, "Output", "unzoned")
SRC <- file.path(root, "Output/tables/PARTREG_part_year_floor_inund.csv")
UNZ <- file.path(OUTD, "UNZONED_v3_armB_ar1_fit.csv")
stopifnot(file.exists(SRC), file.exists(UNZ))

MIN_CELLS_YEAR <- 30
REAL_PUBLISHED <- 0.1613     # the comparator as the spec states it

d <- utils::read.csv(SRC, stringsAsFactors = FALSE)
cat(sprintf("\n  real-part series: %d rows, %d parts, %d water years\n",
            nrow(d), length(unique(d$part_id)), length(unique(d$water_year))))

before <- nrow(d)
d <- d[d$n_valid >= MIN_CELLS_YEAR & !is.na(d$veg_p05_spatial) & !is.na(d$inund_pct), ]
cat(sprintf("  Ruling EM filter (>= %d valid cells): %d -> %d rows (dropped %d)\n",
            MIN_CELLS_YEAR, before, nrow(d), before - nrow(d)))

# demean BY PART, pixel-weighted - the same estimator, unit swapped
d$xd <- d$inund_pct - ave(d$inund_pct, d$part_id, FUN = mean)
d$yd <- d$veg_p05_spatial - ave(d$veg_p05_spatial, d$part_id, FUN = mean)
w <- d$n_pixels_part
ols <- sum(w * d$xd * d$yd) / sum(w * d$xd * d$xd)

cat(sprintf("\n  OLS-within, real parts (recomputed) : %+.6f\n", ols))
cat(sprintf("  the spec's stated comparator        : %+.4f   (%s)\n", REAL_PUBLISHED,
            if (abs(ols - REAL_PUBLISHED) < 0.005) "reproduces" else "DIFFERS - report it"))

d <- d[order(d$part_id, d$water_year), ]
d$part_id <- factor(d$part_id)
m <- nlme::gls(yd ~ xd - 1, data = d,
               correlation = nlme::corAR1(form = ~ water_year | part_id),
               weights = nlme::varFixed(~ I(1 / n_pixels_part)),
               method = "REML")
b <- unname(stats::coef(m)["xd"])
se <- unname(sqrt(diag(stats::vcov(m)))[1])
ci <- b + c(-1, 1) * 1.959964 * se
phi <- unname(stats::coef(m$modelStruct$corStruct, unconstrained = FALSE))

move <- b - ols
rel <- 100 * move / ols
cat(sprintf("  GLS AR(1), real parts               : %+.6f   phi %+.4f\n", b, phi))
cat(sprintf("  point estimate moves %+.4f (%+.1f%%)\n", move, rel))

u <- utils::read.csv(UNZ, stringsAsFactors = FALSE)
cat(sprintf("\n  == the EK comparison ==\n"))
cat(sprintf("  %-14s %10s %10s %8s %8s\n", "side", "OLS-within", "GLS AR(1)", "move %", "phi"))
cat(sprintf("  %-14s %+10.4f %+10.4f %+8.1f %+8.4f\n", "unzoned patches",
            u$ols_within_slope[1], u$slope[1], u$point_estimate_move_pct[1], u$ar1_phi[1]))
cat(sprintf("  %-14s %+10.4f %+10.4f %+8.1f %+8.4f\n", "real parts", ols, b, rel, phi))

gap <- abs(rel - u$point_estimate_move_pct[1])
verdict <- if (gap < 10) {
  paste("COMPARABLE - both sides fall by a similar proportion, so the AR(1) sensitivity",
        "is a property of annual floor series generally, not of unzoned ground. Report",
        "it once as a caveat on BOTH, and the OLS-within comparison stands undisturbed.")
} else {
  paste("NOT COMPARABLE - the two sides move by materially different proportions, so the",
        "unzoned patches carry different serial structure from the paddock parts. That is",
        "itself a finding about the ground and belongs in the note.")
}
cat(sprintf("\n  difference in the proportional move: %.1f pp  ->  %s\n", gap,
            if (gap < 10) "COMPARABLE" else "NOT COMPARABLE"))
cat(paste(strwrap(verdict, 92), collapse = "\n  "), "\n")

out <- data.frame(
  side = c("unzoned patches", "real parts (comparator)"),
  unit = c("patch_id", "part_id"),
  n_obs = c(u$n_obs[1], nrow(d)), n_units = c(u$n_units[1], nlevels(d$part_id)),
  ols_within_slope = c(u$ols_within_slope[1], ols),
  gls_ar1_slope = c(u$slope[1], b),
  ar1_phi = c(u$ar1_phi[1], phi),
  move_pct = c(u$point_estimate_move_pct[1], rel),
  gls_ci_lo = c(u$ci_lo[1], ci[1]), gls_ci_hi = c(u$ci_hi[1], ci[2]),
  metric = "veg_p05_spatial",
  estimator = "within (unit fixed effects), demeaned, pixel-weighted",
  correlation_structure = "corAR1(form = ~ water_year | unit)",
  ruling = "EK (10 Aug 2026)",
  headline_estimator = "OLS-within leads; AR(1) is a sensitivity, never a correction",
  verdict = verdict,
  period_label = "1988-2022 (35 water years)", support_level = "pixel",
  stringsAsFactors = FALSE)
utils::write.csv(out, file.path(OUTD, "UNZONED_v3_EK_ar1_both_sides.csv"),
                 row.names = FALSE)
cat(sprintf("\n  [wrote] UNZONED_v3_EK_ar1_both_sides.csv\n"))
