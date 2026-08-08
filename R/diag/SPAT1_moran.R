# SPAT1_moran.R - is there spatial dependence in the between-unit residuals?
#
# THE EXPOSURE, in the design seat's words: clustering is on the paddock and adjacent
# paddocks are treated as independent. If residuals are spatially autocorrelated at
# scales ABOVE the paddock, the effective number of independent units is below 64 and
# every interval in the project is too narrow, including the registered one.
#
# FOUR DESIGN DECISIONS, each of which could produce a wrong answer on its own:
#
# 1. EVERY STATISTIC IS COMPUTED TWICE - all pairs, and cross-paddock pairs only. Two
#    parts of one paddock are neighbours BY CONSTRUCTION; they were cut from one polygon
#    and the bootstrap already treats them as a single unit. Moran's I over all pairs
#    would find that and report it as a discovery. Only the cross-paddock number
#    answers the question that was asked.
#
# 2. TWO RESPONSE VARIABLES - the raw residual and DIAG-1's residual_z_local. Residual
#    variance falls from 12.81 pp to 3.83 pp across the wetness gradient, and wetness on
#    a floodplain is strongly spatially organised. Moran's I on the raw residual cannot
#    tell autocorrelation from a spatially patterned VARIANCE. The locally standardised
#    residual removes the gradient, so a signal that survives it is about the residual's
#    LEVEL rather than its spread.
#
# 3. TWO WEIGHT DEFINITIONS - polygon adjacency and inverse centroid distance. Both are
#    reported. A conclusion that holds under one and not the other is a conclusion about
#    the weights.
#
# 4. NO P-VALUE. The permutation distribution is reported as a distribution - its mean,
#    SD and quantiles - and the observed value's standardised distance from it. That is
#    an effect size. No test is performed and no threshold is applied.
#
# The remedy, if this fires, is a spatial block bootstrap replacing the paddock
# bootstrap. THAT IS A DESIGN-SEAT DECISION AND IS NOT IMPLEMENTED HERE.

source(file.path("R", "diag", "DIAG1_common.R"))

N_PERM <- 9999L
SEED <- 20260807L

CSV_B <- file.path(DIAG_ANA, "DIAG1_between_parts.csv")
CSV_C <- file.path(DIAG_ANA, "SPAT1_part_centroids.csv")
CSV_P <- file.path(DIAG_ANA, "SPAT1_pairs.csv")
SHA <- gayini_sha256_first50_file(CSV_P)

CE <- read.csv(CSV_C, stringsAsFactors = FALSE)
PR <- read.csv(CSV_P, stringsAsFactors = FALSE)
# Defensive, and it has already fired once: a Python boolean column arrives as the
# CHARACTER "True"/"False" and as.numeric() turns it into NA without erroring. Assert
# the flag columns are usable rather than discovering it as an empty weight matrix.
for (cc in c("adjacent", "same_paddock", "same_community")) {
  if (is.character(PR[[cc]])) PR[[cc]] <- PR[[cc]] %in% c("True", "TRUE", "1")
  PR[[cc]] <- as.logical(as.integer(PR[[cc]]))
  stopifnot(!anyNA(PR[[cc]]))
}
stopifnot(sum(PR$adjacent) > 0, sum(!PR$same_paddock) > 0)
PW <- read.csv(file.path(DIAG_OUT, "DIAG1_between_pointwise.csv"), stringsAsFactors = FALSE)
LZ <- read.csv(file.path(DIAG_OUT, "DIAG1_local_z.csv"), stringsAsFactors = FALSE)

ID <- CE$part_id
n <- length(ID)
stopifnot(n == 115L)
i_of <- setNames(seq_len(n), ID)

dg_say("=== SPAT-1 - spatial dependence in the between-unit residuals ===")
dg_say("  115 parts, EPSG:8058, %d unordered pairs, %d permutations",
       nrow(PR), N_PERM)

# ------------------------------------------------------- weight matrix builders ----

#' Build a symmetric weight matrix from the pair table, then row-standardise.
#'
#' Row-standardisation is applied AFTER any masking, so a part whose only neighbours
#' were within its own paddock ends up with an all-zero row and is dropped rather than
#' silently contributing a zero to the numerator with a full denominator.
build_W <- function(value, mask = rep(TRUE, nrow(PR))) {
  W <- matrix(0, n, n)
  k <- which(mask & value > 0)
  ii <- i_of[PR$part_i[k]]; jj <- i_of[PR$part_j[k]]
  W[cbind(ii, jj)] <- value[k]
  W[cbind(jj, ii)] <- value[k]
  W
}

row_standardise <- function(W) {
  rs <- rowSums(W)
  keep <- rs > 0
  W[keep, ] <- W[keep, , drop = FALSE] / rs[keep]
  list(W = W, keep = keep)
}

#' Moran's I with the isolates dropped, not zero-weighted.
moran <- function(W, keep, x) {
  x <- x[keep]; W <- W[keep, keep, drop = FALSE]
  rs <- rowSums(W); k2 <- rs > 0
  x <- x[k2]; W <- W[k2, k2, drop = FALSE]
  W <- W / rowSums(W)
  m <- length(x)
  z <- x - mean(x)
  list(I = (m / sum(W)) * as.numeric(t(z) %*% W %*% z) / sum(z^2), m = m, W = W, z = z)
}

#' Permutation distribution: reassign the SAME residual values to different locations.
perm_dist <- function(W, z, n_perm = N_PERM, seed = SEED) {
  set.seed(seed)
  m <- length(z); S0 <- sum(W)
  out <- numeric(n_perm)
  for (b in seq_len(n_perm)) {
    zz <- z[sample.int(m)]
    zz <- zz - mean(zz)
    out[b] <- (m / S0) * as.numeric(t(zz) %*% W %*% zz) / sum(zz^2)
  }
  out
}

# ------------------------------------------------------------------ the schemes ----
ADJ <- as.numeric(PR$adjacent)
IDW <- ifelse(PR$distance_m > 0, 1 / PR$distance_m, 0)
IDW[PR$distance_m > 10000] <- 0        # 10 km cutoff, stated on every output row

SCHEMES <- list(
  list(id = "adjacency_all",         v = ADJ, mask = rep(TRUE, nrow(PR)),
       label = "shares a boundary (1 m tolerance), all pairs"),
  list(id = "adjacency_cross_paddock", v = ADJ, mask = !PR$same_paddock,
       label = "shares a boundary, WITHIN-PADDOCK PAIRS EXCLUDED"),
  list(id = "inv_distance_all",      v = IDW, mask = rep(TRUE, nrow(PR)),
       label = "1/distance between centroids, 10 km cutoff, all pairs"),
  list(id = "inv_distance_cross_paddock", v = IDW, mask = !PR$same_paddock,
       label = "1/distance, 10 km cutoff, WITHIN-PADDOCK PAIRS EXCLUDED")
)

PERIODS <- c("whole_record", "cropping_era", "post_management")
PLABEL <- c(whole_record = "1988-2022", cropping_era = "1988-2013",
            post_management = "2018-2022")

# response variables, both keyed on part_id
resp <- list()
for (p in PERIODS) {
  d <- PW[PW$period == p, ]
  resp[[paste0(p, "|residual")]] <- setNames(d$residual, d$part_id)[ID]
  resp[[paste0(p, "|residual_z_local")]] <- setNames(d$residual_z_local, d$part_id)[ID]
}

rows <- list(); dists <- list()
for (s in SCHEMES) {
  W0 <- build_W(s$v, s$mask)
  rs <- row_standardise(W0)
  for (key in names(resp)) {
    p <- sub("\\|.*", "", key); vname <- sub(".*\\|", "", key)
    mo <- moran(W0, rs$keep, resp[[key]])
    pd <- perm_dist(mo$W, mo$z)
    q <- unname(stats::quantile(pd, c(0.025, 0.5, 0.975)))
    rows[[length(rows) + 1L]] <- data.frame(
      weights_id = s$id, weights_definition = s$label,
      response = vname, period = p, period_label = PLABEL[[p]],
      n_units_used = mo$m, n_units_dropped_no_neighbour = n - mo$m,
      morans_I = mo$I,
      expectation_under_no_dependence = -1 / (mo$m - 1),
      perm_mean = mean(pd), perm_sd = stats::sd(pd),
      perm_p2_5 = q[1], perm_p50 = q[2], perm_p97_5 = q[3],
      standardised_distance_from_perm_mean = (mo$I - mean(pd)) / stats::sd(pd),
      n_permutations = N_PERM, stringsAsFactors = FALSE)
    if (vname == "residual" || p == "whole_record")
      dists[[paste(s$id, key, sep = "|")]] <- pd
  }
  r1 <- rows[[length(rows) - 5L]]   # this scheme's whole-record raw-residual row
  dg_say("  %-28s n used %3d  I(residual, whole record) %+.4f   perm mean %+.4f sd %.4f",
         s$id, sum(rs$keep), r1$morans_I, r1$perm_mean, r1$perm_sd)
}

MI <- do.call(rbind, rows)
MI <- dg_stamp(MI, "pixel", "part (paddock x community)", NA, "unweighted (Moran's I is not a weighted statistic; the RESIDUALS being tested come from a pixel-weighted fit)",
               "BETWEEN-UNIT residual - spatial dependence diagnostic. Not an estimate of any relationship",
               "none - the point of the test is that the paddock cluster may be too small", SHA)
MI$period_label <- PLABEL[MI$period]
MI$no_p_value_note <- paste(
  "NO P-VALUE IS COMPUTED. The permutation distribution is reported as a distribution and",
  "the observed value's standardised distance from its mean is an effect size, not a test.")
write.csv(MI, file.path(DIAG_OUT, "SPAT1_morans_i.csv"), row.names = FALSE, na = "")

dg_say("")
dg_say("-- Moran's I, whole record --")
dg_say("  %-30s %-18s %5s %9s %9s %8s", "weights", "response", "n", "I", "perm mean", "sd-dist")
for (j in which(MI$period == "whole_record"))
  dg_say("  %-30s %-18s %5d %+9.4f %+9.4f %8.2f", MI$weights_id[j], MI$response[j],
         MI$n_units_used[j], MI$morans_I[j], MI$perm_mean[j],
         MI$standardised_distance_from_perm_mean[j])

# ------------------------------------------------- the correlogram: where it decays ----
# Binary weights inside a distance band. This is what answers "the distance at which it
# decays" - a single I over one neighbour definition cannot.

dg_say("")
dg_say("-- correlogram: Moran's I by distance band, cross-paddock pairs only --")
BANDS <- list(c(0, 2000), c(2000, 4000), c(4000, 6000), c(6000, 8000), c(8000, 10000),
              c(10000, 15000), c(15000, 20000), c(20000, 30000), c(30000, 60000))
crows <- list()
for (vname in c("residual", "residual_z_local")) {
  x <- resp[[paste0("whole_record|", vname)]]
  for (bd in BANDS) {
    m <- (!PR$same_paddock) & PR$distance_m >= bd[1] & PR$distance_m < bd[2]
    if (sum(m) < 20) next
    W0 <- build_W(rep(1, nrow(PR)), m)
    rs <- row_standardise(W0)
    mo <- moran(W0, rs$keep, x)
    pd <- perm_dist(mo$W, mo$z, n_perm = 1999L)
    crows[[length(crows) + 1L]] <- data.frame(
      response = vname, band_lower_m = bd[1], band_upper_m = bd[2],
      n_pairs = sum(m), n_units_used = mo$m, morans_I = mo$I,
      perm_mean = mean(pd), perm_sd = stats::sd(pd),
      perm_p2_5 = unname(stats::quantile(pd, 0.025)),
      perm_p97_5 = unname(stats::quantile(pd, 0.975)),
      standardised_distance_from_perm_mean = (mo$I - mean(pd)) / stats::sd(pd),
      n_permutations = 1999L, stringsAsFactors = FALSE)
    if (vname == "residual")
      dg_say("  %5.1f-%4.1f km  pairs %4d  units %3d   I %+.4f   sd-dist %+6.2f",
             bd[1] / 1000, bd[2] / 1000, sum(m), mo$m, mo$I,
             (mo$I - mean(pd)) / stats::sd(pd))
  }
}
CG <- do.call(rbind, crows)
CG <- dg_stamp(CG, "pixel", "part (paddock x community)", "1988-2022",
               "unweighted; binary weights inside the band",
               "BETWEEN-UNIT residual - spatial correlogram, cross-paddock pairs only",
               "none - testing whether the paddock cluster is too small", SHA)
write.csv(CG, file.path(DIAG_OUT, "SPAT1_correlogram.csv"), row.names = FALSE, na = "")

# ------------------------------------------------- how far does a paddock reach? ----
# A factual statement the design seat can act on without this task choosing a remedy.
cross <- PR[!PR$same_paddock, ]
adj_d <- cross$distance_m[cross$adjacent == 1 | cross$adjacent == TRUE]
dg_say("")
dg_say("-- scale reference --")
dg_say("  cross-paddock ADJACENT pairs: %d, centroid separation median %.1f km (max %.1f km)",
       length(adj_d), stats::median(adj_d) / 1000, max(adj_d) / 1000)
dg_say("  cross-paddock pairs within  2 km: %d;  within 5 km: %d;  within 10 km: %d of %d",
       sum(cross$distance_m < 2000), sum(cross$distance_m < 5000),
       sum(cross$distance_m < 10000), nrow(cross))

# How many paddocks would a block of the observed range contain? Reported as a factual
# input to sizing a spatial block, NOT as a recommended block size - choosing the
# remedy is a design-seat decision and this task does not make it.
pk <- unique(CE$zone_fid)
pcx <- tapply(CE$centroid_x_8058, CE$zone_fid, mean)[as.character(pk)]
pcy <- tapply(CE$centroid_y_8058, CE$zone_fid, mean)[as.character(pk)]
pd_m <- as.matrix(stats::dist(cbind(pcx, pcy)))
scale_rows <- do.call(rbind, lapply(c(2000, 3000, 4000, 5000, 6000, 8000), function(r) {
  k <- rowSums(pd_m > 0 & pd_m <= r)
  data.frame(radius_m = r, mean_paddocks_within = mean(k), median_paddocks_within = stats::median(k),
             max_paddocks_within = max(k), paddocks_with_none = sum(k == 0),
             implied_blocks_if_grouped_at_this_radius = length(pk) / (1 + mean(k)),
             stringsAsFactors = FALSE)
}))
scale_rows$n_paddocks <- length(pk)
scale_rows$note <- paste("Paddock centroid = mean of its parts' centroids. A factual input to",
                         "sizing a spatial block. NOT a recommended block size: choosing the",
                         "remedy is a design-seat decision and SPAT-1 does not make it.")
scale_rows <- dg_stamp(scale_rows, "paddock", "paddock (zone_fid)", "geometry only",
                       "unweighted", "GEOMETRY ONLY - no estimate", "none", SHA)
write.csv(scale_rows, file.path(DIAG_OUT, "SPAT1_scale_reference.csv"), row.names = FALSE, na = "")
for (j in seq_len(nrow(scale_rows)))
  dg_say("  within %.0f km a paddock has %.1f other paddocks (median %.0f, max %.0f); %d have none",
         scale_rows$radius_m[j] / 1000, scale_rows$mean_paddocks_within[j],
         scale_rows$median_paddocks_within[j], scale_rows$max_paddocks_within[j],
         scale_rows$paddocks_with_none[j])

# permutation draws kept so the figure draws the distribution rather than a summary
saveRDS(dists, file.path(DIAG_ANA, "SPAT1_perm_draws.rds"))

# ------------------------------------------------------------ verifying the statistic ----
# SPAT-1 measures something no earlier task measured, so there is no design-seat figure
# to reproduce. That is not a reason to ship an unverified estimator. Three checks:
#
#   1. an INDEPENDENT CODE PATH - the same I from an explicit double loop over pairs,
#      required to agree with the matrix form to 1e-12. Same discipline as gayini_fit's
#      cross-check of its hand-computed slope against coef(lm()).
#   2. the permutation mean must land on -1/(m-1), the known expectation under no
#      dependence. If the permutation machinery were wrong this would drift.
#   3. A FIXTURE THAT MOVES THE VALUE - rewire the neighbours at random, keeping the
#      same residuals and the same number of links. If I stays high the statistic is
#      reporting something about the residuals alone and the weights are doing nothing.

dg_say("")
dg_say("-- verifying the statistic --")

W0 <- build_W(ADJ, !PR$same_paddock)
rs <- row_standardise(W0)
mo <- moran(W0, rs$keep, resp[["whole_record|residual"]])

# 1. independent code path
loop_I <- local({
  W <- mo$W; z <- mo$z; m <- length(z)
  num <- 0; S0 <- 0
  for (a in seq_len(m)) for (b in seq_len(m)) {
    if (W[a, b] != 0) { num <- num + W[a, b] * z[a] * z[b]; S0 <- S0 + W[a, b] }
  }
  (m / S0) * num / sum(z^2)
})
dg_check("moran_independent_code_path", "Moran's I, matrix form against an explicit pair loop",
         mo$I, loop_I, 1e-12, note = "verification")
dg_say("  matrix form %.10f   pair loop %.10f   difference %.2e",
       mo$I, loop_I, abs(mo$I - loop_I))

# 2. permutation mean lands on the known expectation
pd <- perm_dist(mo$W, mo$z)
dg_check("perm_mean_equals_expectation", "permutation mean against -1/(m-1)",
         -1 / (mo$m - 1), mean(pd), 3 * stats::sd(pd) / sqrt(N_PERM), note = "verification")
dg_say("  permutation mean %+.5f   expectation -1/(m-1) = %+.5f",
       mean(pd), -1 / (mo$m - 1))

# 3. the fixture: same residuals, same link count, neighbours rewired at random
set.seed(20260808L)
n_links <- sum(PR$adjacent & !PR$same_paddock)
fake <- rep(0, nrow(PR))
fake[sample(which(!PR$same_paddock), n_links)] <- 1
Wf <- build_W(fake, !PR$same_paddock)
rsf <- row_standardise(Wf)
mof <- moran(Wf, rsf$keep, resp[["whole_record|residual"]])
pdf_ <- perm_dist(mof$W, mof$z, n_perm = 1999L)
sd_fake <- (mof$I - mean(pdf_)) / stats::sd(pdf_)
dg_say("  FIXTURE: %d links rewired at random, same residuals", n_links)
dg_say("    real neighbours  I %+.4f  (%.2f SD from its permutation mean)",
       mo$I, (mo$I - mean(pd)) / stats::sd(pd))
dg_say("    random neighbours I %+.4f  (%.2f SD)", mof$I, sd_fake)
dg_check("FIXTURE_rewired_neighbours", "random neighbours must NOT reproduce the real I",
         mo$I, mof$I, 0.05, note = "verification fixture", fixture = TRUE)
if (abs(mof$I - mo$I) < 0.05)
  stop("SPAT-1 HALT: randomly rewired neighbours reproduced the observed Moran's I. ",
       "The statistic is not responding to the weights and the finding is not spatial.")
dg_say("    the check fired as intended: the statistic collapses without real geography")

d <- dg_write_checks(file.path(DIAG_OUT, "SPAT1_checks.csv"))
real <- d[!d$expected_to_disagree, ]
dg_say("  checks: %d of %d agree (plus %d fixture row that correctly disagrees)",
       sum(real$agrees), nrow(real), sum(d$expected_to_disagree))
dg_say("")
dg_say("[wrote] SPAT1_morans_i.csv (%d rows), SPAT1_correlogram.csv (%d rows)",
       nrow(MI), nrow(CG))
