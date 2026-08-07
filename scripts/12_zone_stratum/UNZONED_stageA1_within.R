# UNZONED Stage A1 - the within-patch replication on unzoned standard-grazing country.
#
# Amendment A1 section 2, quoted as authority. Ruling AS: estimation is in R.
# Input is the checksummed boundary CSV written by UNZONED_stageA1_boundary.py from
# the Gate 1 series. NO NEW EXTRACTION.
#
# THE CLUSTER IS THE PATCH. There is no paddock on this ground. The real-part estimate
# clusters on zone_fid; this one cannot, and that difference is stated on every output
# row rather than substituted silently.
#
# THREE PREDICTIONS ARE PRE-REGISTERED IN A1 section 2.5 AND DECLARED BELOW BEFORE THE
# FIT. They are predictions to check, not targets. Nothing is adjusted toward them.
#
# NO P-VALUES. summary() is never called on a model object.
#
# WHAT THIS IS NOT: not a reference set, not a control, not unmanaged ground, and no
# management or condition claim is made anywhere.

suppressPackageStartupMessages({
  library(nlme)
})

ROOT <- normalizePath(".", winslash = "/")
source(file.path(ROOT, "R", "gayini_fit.R"))
T <- file.path(ROOT, "Output", "tables")
CSV <- file.path(T, "UNZONED_stageA1_patch_year.csv")

Y <- "veg_p05_spatial"; X <- "inund_pct"; W <- "n_cells"
.ac1_pair <- function(v) stats::cor(v[-1], v[-length(v)])   # the WITHIN-1 definition

# ---- A1 section 2.5, recorded before the fits ------------------------------------
PRED <- list(
  pooled_slope   = list(v = 0.16, what = "pooled within slope near +0.16"),
  ordering       = list(v = "aeolian > riverine > inland", what = "community ordering"),
  share_positive = list(v = 1.00, what = "close to 100% of patches positive"))

cat(strrep("=", 78), "\n")
cat("UNZONED Stage A1 - within-patch response on unzoned standard-grazing country\n")
cat(strrep("=", 78), "\n")

sha <- gayini_sha256_first50_file(CSV)
side <- sub("\\s.*$", "", readLines(file.path(T, "UNZONED_stageA1_patch_year.sha256"))[1])
cat(sprintf("\n[boundary] %s\n           computed %s\n           sidecar  %s   %s\n",
            basename(CSV), substr(sha, 1, 32), substr(side, 1, 32),
            if (identical(sha, side)) "MATCHES" else "*** DIFFERS ***"))
if (!identical(sha, side)) stop("the analysis CSV is not the bytes Python checksummed - halting")

d <- utils::read.csv(CSV, stringsAsFactors = FALSE)
cat(sprintf("           %d patch-years, %d patches, %d water years\n",
            nrow(d), length(unique(d$patch_id)), length(unique(d$water_year))))

# ---- 2.1 per patch ----------------------------------------------------------------
cat("\n[2.1] per-patch slopes\n")
per <- do.call(rbind, lapply(split(d, d$patch_id), function(g) {
  if (nrow(g) < 3 || length(unique(g[[X]])) < 3) return(NULL)
  fit <- stats::lm(g[[Y]] ~ g[[X]])
  data.frame(patch_id = g$patch_id[1], community_short = g$community_short[1],
             n_cells = g[[W]][1], n_years = nrow(g),
             slope = unname(stats::coef(fit)[2]), r = stats::cor(g[[X]], g[[Y]]),
             ac1_resid = .ac1_pair(stats::residuals(fit)),
             ac1_floor = .ac1_pair(g[[Y]]), ac1_water = .ac1_pair(g[[X]]),
             stringsAsFactors = FALSE)
}))
q <- stats::quantile(per$slope, c(0, .25, .5, .75, 1))
cat(sprintf("  all %d patches   min %+.4f  Q1 %+.4f  median %+.4f  Q3 %+.4f  max %+.4f\n",
            nrow(per), q[1], q[2], q[3], q[4], q[5]))
cat(sprintf("  share positive %.4f   median r %.4f\n", mean(per$slope > 0), stats::median(per$r)))
for (cs in c("aeolian", "riverine", "inland")) {
  s <- per$slope[per$community_short == cs]
  cat(sprintf("    %-9s n %2d   median %+.4f   share positive %.3f   median r %.3f\n",
              cs, length(s), stats::median(s), mean(s > 0),
              stats::median(per$r[per$community_short == cs])))
}

# ---- 2.2 / 2.3 pooled within, clustered on the PATCH -------------------------------
cat("\n[2.2/2.3] pooled within estimator - cluster is the PATCH, not zone_fid\n")
f2k <- gayini_fit(CSV, Y, X, weights = W, cluster = "patch_id", unit = "patch_id",
                  demean = TRUE, n_boot = 2000L, label = "UNZONED A1 within, 2k draws")
f10k <- gayini_fit(CSV, Y, X, weights = W, cluster = "patch_id", unit = "patch_id",
                   demean = TRUE, n_boot = 10000L, label = "UNZONED A1 within, 10k draws")
cat(sprintf("  slope %+.4f   within R2 %.4f   n %d over %d patches\n",
            f2k$slope, f2k$r2, f2k$n_obs, f2k$n_units))
cat(sprintf("   2,000 draws  95%% [%+.4f, %+.4f]\n", f2k$boot_p2_5, f2k$boot_p97_5))
cat(sprintf("  10,000 draws  95%% [%+.4f, %+.4f]\n", f10k$boot_p2_5, f10k$boot_p97_5))
cat("  cluster = patch. The real-part within estimate clusters on zone_fid; there is no\n")
cat("  paddock on this ground, so the two intervals are not constructed alike.\n")

# ---- 2.4 serial correlation and the AR(1) refit ------------------------------------
cat("\n[2.4] serial correlation\n")
rho <- stats::median(per$ac1_resid)
cat(sprintf("  median residual lag-1 autocorrelation %+.4f  ->  effective n %.1f of %d years\n",
            rho, stats::median(per$n_years) * (1 - rho) / (1 + rho), max(per$n_years)))
cat(sprintf("  floor %+.4f   wetness %+.4f   (real parts: +0.364 / +0.477 / +0.172)\n",
            stats::median(per$ac1_floor), stats::median(per$ac1_water)))

dg <- d
for (i in split(seq_len(nrow(dg)), dg$patch_id)) {
  sw <- sum(dg[[W]][i])
  for (v in c(Y, X)) dg[[v]][i] <- dg[[v]][i] - sum(dg[[W]][i] * dg[[v]][i]) / sw
}
dg$patch_id <- factor(dg$patch_id)
g <- nlme::gls(stats::as.formula(sprintf("%s ~ %s - 1", Y, X)), data = dg,
               weights = nlme::varFixed(~ 1 / n_cells),
               correlation = nlme::corAR1(form = ~ water_year | patch_id), method = "REML")
gsl <- unname(stats::coef(g)[1]); gse <- sqrt(diag(stats::vcov(g)))[[1]]
phi <- unname(stats::coef(g$modelStruct$corStruct, unconstrained = FALSE))
moved <- abs(gsl - f2k$slope)
cat(sprintf("  gls AR(1) slope %+.4f  +/- 1.96 SE [%+.4f, %+.4f]  phi %.4f\n",
            gsl, gsl - 1.96 * gse, gsl + 1.96 * gse, phi))
cat(sprintf("  point estimate moved %.4f (%.1f%% of the OLS-within slope) - %s\n",
            moved, 100 * moved / f2k$slope,
            if (moved / f2k$slope < 0.10) "HOLDS" else "MOVED MATERIALLY - flagged"))
cat("  the gls interval is not the bootstrap interval widened: gls models serial\n")
cat("  correlation within a patch and treats patches as independent; the bootstrap\n")
cat("  resamples patches and carries no within-patch structure.\n")

# ---- 2.5 the three pre-registered predictions -------------------------------------
cat("\n[2.5] against the three predictions, recorded before the fits\n")
ord <- names(sort(sapply(c("aeolian", "riverine", "inland"),
                         function(cs) stats::median(per$slope[per$community_short == cs])),
                  decreasing = TRUE))
got_ord <- paste(ord, collapse = " > ")
p1 <- abs(f2k$slope - PRED$pooled_slope$v) <= 0.03
p2 <- identical(got_ord, PRED$ordering$v)
p3 <- mean(per$slope > 0) >= 0.95
cat(sprintf("  1  %-42s predicted %-28s got %+.4f      %s\n", PRED$pooled_slope$what,
            "+0.16 +/- 0.03", f2k$slope, if (p1) "HOLDS" else "DOES NOT HOLD"))
cat(sprintf("  2  %-42s predicted %-28s got %-16s %s\n", PRED$ordering$what,
            PRED$ordering$v, got_ord, if (p2) "HOLDS" else "DOES NOT HOLD"))
cat(sprintf("  3  %-42s predicted %-28s got %.4f       %s\n", PRED$share_positive$what,
            ">= 0.95", mean(per$slope > 0), if (p3) "HOLDS" else "DOES NOT HOLD"))
cat("  predictions are checked, never targeted; no result above is adjusted toward them.\n")

# ---- outputs ----------------------------------------------------------------------
per$estimator <- "within (patch fixed effects), per patch"
per$cluster <- "n/a - per-patch fit"
per$land_use_label <- "unzoned standard-grazing country"
utils::write.csv(per, file.path(T, "UNZONED_stageA1_per_patch_slopes.csv"), row.names = FALSE)

fits <- rbind(f2k, f10k,
  data.frame(label = "UNZONED A1 gls AR(1)",
             estimator = "within (patch fixed effects), AR(1) errors",
             y_variable = Y, x_variable = X, weighting = paste0("weighted by ", W),
             cluster = "AR(1) within patch_id", n_obs = nrow(dg),
             n_units = nlevels(dg$patch_id), slope = gsl, intercept = NA_real_,
             r = NA_real_, resid_sd = NA_real_, r2 = NA_real_,
             boot_p2_5 = gsl - 1.96 * gse, boot_p50 = gsl, boot_p97_5 = gsl + 1.96 * gse,
             boot_draws = 0L, source_csv = basename(CSV), source_sha256_first50 = sha,
             interval_status = "R-side stability check - NOT registered",
             stringsAsFactors = FALSE))
for (cs in c("aeolian", "riverine", "inland")) {
  sub <- d$community_short == cs
  fc <- gayini_fit(CSV, Y, X, weights = W, cluster = "patch_id", unit = "patch_id",
                   demean = TRUE, subset = sub, n_boot = 2000L,
                   label = paste0("UNZONED A1 within, ", cs))
  fits <- rbind(fits, fc)
  cat(sprintf("  pooled within, %-9s slope %+.4f  95%% [%+.4f, %+.4f]  n %d patches\n",
              cs, fc$slope, fc$boot_p2_5, fc$boot_p97_5, fc$n_units))
}
fits$land_use_label <- "unzoned standard-grazing country"
fits$unit_construction <- "8-connected component within one community, outside every management zone"
utils::write.csv(fits, file.path(T, "UNZONED_stageA1_fits.csv"), row.names = FALSE)

cat("\n", strrep("=", 78), "\n", sep = "")
cat(sprintf("STAGE A1 COMPLETE - %d of 3 pre-registered predictions hold. A2 not run.\n",
            sum(p1, p2, p3)))
