# WITHIN-1 - reproduce the design-seat within-part analysis in R.
#
# Ruling AS (7 Aug 2026): all statistical estimation is in R from here. This is the
# first task under it. Input is PARTREG_part_year_floor_inund.csv, 4,025 rows,
# 115 parts x 35 years, written by the Python side and registered as
# table_partreg_part_year_floor_inund.
#
# EVERY DESIGN-SEAT FIGURE IS A TARGET AND A DISAGREEMENT IS A HALT, NOT A NOTE.
# The targets are declared below, before anything is fitted, and each is checked
# against a stated tolerance.
#
# NO P-VALUES. summary() is never called on a model object anywhere in this file.
#
# THE WITHIN AND BETWEEN SLOPES ARE NOT TWO ESTIMATES OF ONE NUMBER. +0.161 is what
# an extra point of wetness buys the SAME ground over time; +0.547 is how places
# DIFFER from each other in the long run. Every row carries its estimator.

suppressPackageStartupMessages({
  library(nlme)
  library(DBI)
  library(RSQLite)
})

ROOT <- normalizePath(".", winslash = "/")
source(file.path(ROOT, "R", "gayini_fit.R"))
CSV <- file.path(ROOT, "Output", "tables", "PARTREG_part_year_floor_inund.csv")
OUT <- file.path(ROOT, "Output", "tables")

Y <- "veg_p05_spatial"; X <- "inund_pct"; W <- "n_pixels_part"

# ---- targets, declared before the fitting ---------------------------------------
TARGETS <- list(
  share_positive      = list(v = 1.000,  tol = 0.001,  what = "share of within-part slopes positive"),
  median_within_r     = list(v = 0.443,  tol = 0.002,  what = "median within-part r"),
  pooled_within_slope = list(v = 0.1613, tol = 0.0010, what = "pooled within slope, pixel-weighted"),
  boot_lo             = list(v = 0.143,  tol = 0.004,  what = "within 95% lower, clustered on zone_fid"),
  boot_hi             = list(v = 0.181,  tol = 0.004,  what = "within 95% upper, clustered on zone_fid"),
  between_slope       = list(v = 0.5473, tol = 0.0010, what = "between-part slope"),
  ratio               = list(v = 3.39,   tol = 0.02,   what = "between / within ratio"),
  within_r2           = list(v = 0.173,  tol = 0.002,  what = "within R-squared"),
  ac1_resid_median    = list(v = 0.364,  tol = 0.004,  what = "median residual lag-1 autocorrelation"),
  n_eff               = list(v = 16,     tol = 1.0,    what = "effective n of 35 years"),
  ac1_floor           = list(v = 0.477,  tol = 0.004,  what = "median lag-1 autocorrelation of the floor"),
  ac1_water           = list(v = 0.172,  tol = 0.004,  what = "median lag-1 autocorrelation of wetness"),
  lag_same_year       = list(v = 0.138,  tol = 0.002,  what = "same-year slope with lagged water added"),
  lag_prev_year       = list(v = 0.118,  tol = 0.002,  what = "previous-year slope"),
  med_aeolian         = list(v = 0.350,  tol = 0.002,  what = "within-part median slope, Aeolian"),
  med_riverine        = list(v = 0.218,  tol = 0.002,  what = "within-part median slope, Riverine"),
  med_inland          = list(v = 0.140,  tol = 0.002,  what = "within-part median slope, Inland"))

.ac1_pair <- function(v) stats::cor(v[-1], v[-length(v)])   # the design seat's definition

RESULTS <- new.env(parent = emptyenv())
report <- function(key, got) {
  t <- TARGETS[[key]]
  ok <- is.finite(got) && abs(got - t$v) <= t$tol
  assign(key, list(got = got, target = t$v, tol = t$tol, ok = ok, what = t$what), envir = RESULTS)
  cat(sprintf("  %-46s target %8.4f   got %8.4f   %s\n",
              t$what, t$v, got, if (ok) "AGREES" else "*** DISAGREES ***"))
  invisible(ok)
}

cat(strrep("=", 78), "\n")
cat("WITHIN-1 - reproducing the design-seat within-part analysis in R\n")
cat(strrep("=", 78), "\n")

# ---- the boundary check: the CSV is the registered bytes ------------------------
sha <- gayini_sha256_first50_file(CSV)
con <- dbConnect(SQLite(), file.path(ROOT, "Output/database/Gayini_Results.sqlite"), flags = SQLITE_RO)
reg <- dbGetQuery(con, "SELECT checksum_sha256, n_rows FROM table_asset
                        WHERE table_asset_id = 'table_partreg_part_year_floor_inund'")
dbDisconnect(con)
cat(sprintf("\n[boundary] %s\n           file %s\n           registry %s   %s\n",
            basename(CSV), substr(sha, 1, 24), substr(reg$checksum_sha256[1], 1, 24),
            if (identical(sha, reg$checksum_sha256[1])) "MATCHES" else "*** DIFFERS ***"))
if (!identical(sha, reg$checksum_sha256[1]))
  stop("the analysis CSV is not the registered bytes - halting")

d <- utils::read.csv(CSV, stringsAsFactors = FALSE)
cat(sprintf("           %d rows, %d parts, %d water years\n",
            nrow(d), length(unique(d$part_id)), length(unique(d$water_year))))
stopifnot(nrow(d) == reg$n_rows[1])

# ---- 1 · per-part slopes ---------------------------------------------------------
cat("\n[1] per-part slopes and correlations\n")
per <- do.call(rbind, lapply(split(d, d$part_id), function(g) {
  fit <- stats::lm(g[[Y]] ~ g[[X]])
  data.frame(part_id = g$part_id[1], zone_fid = g$zone_fid[1],
             community_short = g$community_short[1], n_pixels_part = g[[W]][1],
             n_years = nrow(g), slope = unname(stats::coef(fit)[2]),
             r = stats::cor(g[[X]], g[[Y]]),
             # TWO lag-1 autocorrelation estimators, both carried permanently.
             # .ac1_pair is the sample correlation of the lagged pairs, cor(v[-1], v[-n]);
             # the *_acf columns are R's acf(), the 1/n autocovariance form, which is
             # biased toward zero on a 35-point series. The design-seat targets were
             # computed with the PAIRWISE form - established by all three matching it to
             # under 3e-4 while none matched acf(). Both are kept so the ambiguity that
             # cost this run a halt cannot recur silently.
             ac1_resid = .ac1_pair(stats::residuals(fit)),
             ac1_floor = .ac1_pair(g[[Y]]),
             ac1_water = .ac1_pair(g[[X]]),
             ac1_resid_acf = stats::acf(stats::residuals(fit), lag.max = 1, plot = FALSE)$acf[2],
             ac1_floor_acf = stats::acf(g[[Y]], lag.max = 1, plot = FALSE)$acf[2],
             ac1_water_acf = stats::acf(g[[X]], lag.max = 1, plot = FALSE)$acf[2],
             stringsAsFactors = FALSE)
}))
report("share_positive", mean(per$slope > 0))
report("median_within_r", stats::median(per$r))
cat(sprintf("  slope distribution: min %.4f  Q1 %.4f  median %.4f  Q3 %.4f  max %.4f\n",
            min(per$slope), stats::quantile(per$slope, .25), stats::median(per$slope),
            stats::quantile(per$slope, .75), max(per$slope)))

# ---- 2 · pooled within estimator --------------------------------------------------
cat("\n[2] pooled within estimator, part fixed effects, pixel-weighted\n")
fw <- gayini_fit(CSV, Y, X, weights = W, cluster = "zone_fid", unit = "part_id",
                 demean = TRUE, n_boot = 2000L, label = "WITHIN-1 pooled within")
report("pooled_within_slope", fw$slope)
report("within_r2", fw$r2)
report("boot_lo", fw$boot_p2_5)
report("boot_hi", fw$boot_p97_5)

# ---- 3 · between-part, for contrast (NOT a competing estimate) --------------------
cat("\n[3] between-part estimator - a DIFFERENT question, not a rival estimate\n")
agg <- do.call(rbind, lapply(split(d, d$part_id), function(g)
  data.frame(part_id = g$part_id[1], zone_fid = g$zone_fid[1],
             community_short = g$community_short[1], n_pixels_part = g[[W]][1],
             floor_mean = mean(g[[Y]]), inund_mean = mean(g[[X]]), stringsAsFactors = FALSE)))
AGGCSV <- file.path(OUT, "WITHIN1_part_means.csv")
utils::write.csv(agg, AGGCSV, row.names = FALSE)
fb <- gayini_fit(AGGCSV, "floor_mean", "inund_mean", weights = "n_pixels_part",
                 cluster = "zone_fid", unit = "part_id", demean = FALSE,
                 n_boot = 2000L, label = "WITHIN-1 between-part")
report("between_slope", fb$slope)
report("ratio", fb$slope / fw$slope)

# ---- 4 · serial correlation and the effective n -----------------------------------
cat("\n[4] serial correlation\n")
report("ac1_resid_median", stats::median(per$ac1_resid))
rho <- stats::median(per$ac1_resid)
report("n_eff", 35 * (1 - rho) / (1 + rho))
report("ac1_floor", stats::median(per$ac1_floor))
report("ac1_water", stats::median(per$ac1_water))
cat(sprintf("  ESTIMATOR NOTE: the same three under R's acf() (1/n form) are %.4f / %.4f / %.4f
",
            stats::median(per$ac1_resid_acf), stats::median(per$ac1_floor_acf),
            stats::median(per$ac1_water_acf)))
cat("  acf() is biased toward zero on 35 points; both forms are columns in the output CSV.
")

# ---- 5 · lagged water -------------------------------------------------------------
cat("\n[5] adding previous-year water\n")
d <- d[order(d$part_id, d$water_year), ]
d$inund_lag1 <- ave(d[[X]], d$part_id, FUN = function(v) c(NA, utils::head(v, -1)))
dl <- d[stats::complete.cases(d[, c(Y, X, "inund_lag1")]), ]
dm <- dl
for (i in split(seq_len(nrow(dm)), dm$part_id)) {
  sw <- sum(dm[[W]][i])
  for (v in c(Y, X, "inund_lag1"))
    dm[[v]][i] <- dm[[v]][i] - sum(dm[[W]][i] * dm[[v]][i]) / sw
}
cf <- stats::coef(stats::lm(dm[[Y]] ~ dm[[X]] + dm$inund_lag1, weights = dm[[W]]))
report("lag_same_year", unname(cf[2]))
report("lag_prev_year", unname(cf[3]))

# ---- 6 · by community - the ordering that inverts ---------------------------------
cat("\n[6] within-part median slope by community (between-part ordering inverts)\n")
for (cs in c("aeolian", "riverine", "inland")) {
  m <- stats::median(per$slope[per$community_short == cs])
  report(paste0("med_", cs), m)
}

# ---- 7 · the addition: gls with an AR(1) error structure --------------------------
cat("\n[7] gls refit with AR(1) errors - the addition Ruling AS asks for\n")
dg <- d[stats::complete.cases(d[, c(Y, X)]), ]
for (i in split(seq_len(nrow(dg)), dg$part_id)) {
  sw <- sum(dg[[W]][i])
  for (v in c(Y, X)) dg[[v]][i] <- dg[[v]][i] - sum(dg[[W]][i] * dg[[v]][i]) / sw
}
dg$part_id <- factor(dg$part_id)
g <- nlme::gls(stats::as.formula(sprintf("%s ~ %s - 1", Y, X)), data = dg,
               weights = nlme::varFixed(~ 1 / n_pixels_part),
               correlation = nlme::corAR1(form = ~ water_year | part_id),
               method = "REML")
gsl <- unname(stats::coef(g)[1])
gse <- sqrt(diag(stats::vcov(g)))[[1]]
phi <- unname(stats::coef(g$modelStruct$corStruct, unconstrained = FALSE))
cat(sprintf("  gls AR(1) slope %.4f   +/- 1.96 SE [%.4f, %.4f]   estimated phi %.4f\n",
            gsl, gsl - 1.96 * gse, gsl + 1.96 * gse, phi))
cat(sprintf("  OLS-within slope %.4f, clustered 95%% [%.4f, %.4f]\n",
            fw$slope, fw$boot_p2_5, fw$boot_p97_5))
moved <- abs(gsl - fw$slope)
cat(sprintf("  point estimate moved by %.4f (%.1f%% of the OLS-within slope) - %s\n",
            moved, 100 * moved / fw$slope,
            if (moved / fw$slope < 0.10) "HOLDS" else "MOVED MATERIALLY - stops for review"))
cat("  NOTE: these two intervals are NOT the same interval widened. The clustered\n")
cat("  bootstrap resamples paddocks, so it carries correlation BETWEEN parts; the gls\n")
cat("  models serial correlation WITHIN a part and treats the 115 parts as independent.\n")
cat("  Different variance structures - neither is the other with a correction applied.\n")

# ---- outputs and the verdict ------------------------------------------------------
utils::write.csv(per, file.path(OUT, "WITHIN1_per_part_slopes.csv"), row.names = FALSE)
fits <- rbind(fw, fb,
  data.frame(label = "WITHIN-1 gls AR(1)", estimator = "within (unit fixed effects), AR(1) errors",
             y_variable = Y, x_variable = X, weighting = paste0("weighted by ", W),
             cluster = "AR(1) within part_id", n_obs = nrow(dg), n_units = nlevels(dg$part_id),
             slope = gsl, intercept = NA_real_, r = NA_real_, resid_sd = NA_real_, r2 = NA_real_,
             boot_p2_5 = gsl - 1.96 * gse, boot_p50 = gsl, boot_p97_5 = gsl + 1.96 * gse,
             boot_draws = 0L, source_csv = basename(CSV),
             source_sha256_first50 = sha,
             interval_status = "R-side stability check - NOT registered", stringsAsFactors = FALSE))
utils::write.csv(fits, file.path(OUT, "WITHIN1_fits.csv"), row.names = FALSE)

chk <- do.call(rbind, lapply(ls(RESULTS), function(k) {
  r <- get(k, envir = RESULTS)
  data.frame(check = k, what = r$what, target = r$target, got = r$got,
             tolerance = r$tol, agrees = r$ok, stringsAsFactors = FALSE) }))
chk <- chk[order(chk$agrees, chk$check), ]
utils::write.csv(chk, file.path(OUT, "WITHIN1_reproduction_checks.csv"), row.names = FALSE)

cat("\n", strrep("=", 78), "\n", sep = "")
bad <- chk[!chk$agrees, ]
cat(sprintf("REPRODUCTION: %d of %d design-seat figures agree\n", sum(chk$agrees), nrow(chk)))
if (nrow(bad)) {
  cat("\nDISAGREEMENTS - a disagreement is a halt, not a note:\n")
  for (i in seq_len(nrow(bad)))
    cat(sprintf("  %-46s target %.4f  got %.4f  (tol %.4f)\n",
                bad$what[i], bad$target[i], bad$got[i], bad$tolerance[i]))
  stop("WITHIN-1 HALTS: the R reproduction disagrees with the design-seat analysis.")
}
cat("all figures reproduce within tolerance\n")
