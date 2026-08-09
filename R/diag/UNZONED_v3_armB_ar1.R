# UNZONED v3, Arm B section 4.4 - the pooled within estimator refitted with an AR(1)
# error structure.
#
# Spec: docs/reference_update/Gayini_CC_spec_UNZONED_v3.md section 4.4.
#
# WHY. The per-patch residuals carry a median lag-1 autocorrelation of +0.399, so 35
# consecutive water years are not 35 independent observations - the effective n is about
# 15. The bootstrap in section 4.3 handles clustering BY PATCH but treats each patch's
# 35 years as exchangeable within the patch, which they are not.
#
# WHAT IS AND IS NOT COMPARABLE. The GLS interval is MODEL-BASED and asymptotic; the
# section 4.3 interval is a CLUSTER BOOTSTRAP. They answer different questions and their
# widths are not a like-for-like comparison - a narrower GLS interval is not evidence
# that serial correlation does not matter. Both are reported side by side with that
# stated, and neither is presented as a correction of the other.
#
# The spec's expectation is that the interval widens and the POINT ESTIMATE HOLDS, and
# that a material move in the point estimate is a finding that stops for review.

suppressPackageStartupMessages({library(nlme)})

root <- normalizePath(".", winslash = "/")
OUTD <- file.path(root, "Output", "unzoned")
SRC <- file.path(OUTD, "UNZONED_v3_armB_patch_year.csv")
FITS <- file.path(OUTD, "UNZONED_v3_armB_within_fits.csv")
stopifnot(file.exists(SRC), file.exists(FITS))

d <- utils::read.csv(SRC, stringsAsFactors = FALSE)
f <- utils::read.csv(FITS, stringsAsFactors = FALSE)
stopifnot(nrow(d) == 3253L)

# demean BY PATCH, exactly as the python within estimator does
d$xd <- d$inund_pct - ave(d$inund_pct, d$patch_id, FUN = mean)
d$yd <- d$veg_p05_spatial - ave(d$veg_p05_spatial, d$patch_id, FUN = mean)
d <- d[order(d$patch_id, d$water_year), ]
d$patch_id <- factor(d$patch_id)

ols <- f$slope[f$scope == "pooled"]
cat(sprintf("\n  OLS within (section 4.2, recomputed in python): %+.6f\n", ols))

# variance proportional to 1/n_cells  ->  weight proportional to n_cells
m <- nlme::gls(yd ~ xd - 1, data = d,
               correlation = nlme::corAR1(form = ~ water_year | patch_id),
               weights = nlme::varFixed(~ I(1 / n_cells)),
               method = "REML")

b <- unname(stats::coef(m)["xd"])
se <- unname(sqrt(diag(stats::vcov(m)))[1])
ci <- b + c(-1, 1) * 1.959964 * se
phi <- unname(stats::coef(m$modelStruct$corStruct, unconstrained = FALSE))

boot_lo <- f$boot10000_p2_5[f$scope == "pooled"]
boot_hi <- f$boot10000_p97_5[f$scope == "pooled"]

cat(sprintf("  GLS AR(1) within                             : %+.6f\n", b))
cat(sprintf("  estimated AR(1) phi                          : %+.4f\n", phi))
cat(sprintf("  GLS model-based 95%%   [%+.4f, %+.4f]  width %.4f\n",
            ci[1], ci[2], diff(ci)))
cat(sprintf("  cluster bootstrap 95%% [%+.4f, %+.4f]  width %.4f  (10,000 draws)\n",
            boot_lo, boot_hi, boot_hi - boot_lo))

move <- b - ols
rel <- 100 * move / ols
cat(sprintf("\n  point estimate moves %+.4f (%+.1f%%)\n", move, rel))
material <- abs(rel) >= 10
cat(sprintf("  spec 4.4 expects the point estimate to HOLD and the interval to WIDEN.\n"))
cat(sprintf("    point estimate : %s\n",
            if (material) "MOVED MATERIALLY - this is a finding and it STOPS for review"
            else "held"))
cat(sprintf("    interval       : %s\n",
            if (diff(ci) > (boot_hi - boot_lo)) "widened"
            else "NARROWED - but see the note: these are not comparable interval types"))

out <- data.frame(
  label = "UNZONED v3 within, GLS AR(1)",
  scope = "pooled",
  estimator = "within (patch fixed effects), demeaned, pixel-weighted, AR(1) errors",
  metric = "veg_p05_spatial",
  y_variable = "veg_p05_spatial", x_variable = "inund_pct",
  weighting = "varFixed(~1/n_cells) - variance inversely proportional to cell count",
  correlation_structure = "corAR1(form = ~ water_year | patch_id)",
  n_obs = nrow(d), n_units = nlevels(d$patch_id),
  slope = b, std_error = se, ci_lo = ci[1], ci_hi = ci[2], ar1_phi = phi,
  ols_within_slope = ols,
  point_estimate_move = move, point_estimate_move_pct = rel,
  interval_type = "MODEL-BASED asymptotic, NOT a cluster bootstrap",
  interval_comparability_note = paste(
    "the section 4.3 interval is a cluster bootstrap over patches and this one is",
    "model-based; their widths are not a like-for-like comparison and a narrower GLS",
    "interval is not evidence that serial correlation does not matter"),
  boot10000_lo = boot_lo, boot10000_hi = boot_hi,
  land_use_label = "unzoned standard-grazing country",
  period_label = "1988-2022 (35 water years)",
  support_level = "pixel",
  stringsAsFactors = FALSE)
utils::write.csv(out, file.path(OUTD, "UNZONED_v3_armB_ar1_fit.csv"), row.names = FALSE)
cat(sprintf("\n  [wrote] UNZONED_v3_armB_ar1_fit.csv\n"))
