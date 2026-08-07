# Pack v1.3 · T0 - reproduce the two unregistered caption numbers.
#
# Task list section T0. Both are design-seat Python figures computed from
# PARTREG_part_residuals.csv, both appear in deliverable caption text, and neither
# has a number_id. Ruling AS: the reproduction is in R.
#
# IF EITHER FAILS TO REPRODUCE THE CAPTION CLAUSE IS CUT, NOT SOFTENED. There is no
# time to adjudicate a disagreement today, so this script reports and stops on the
# failing clause rather than proposing an alternative definition.
#
# Where a definition is under-specified (weighted or unweighted SD; population or
# sample denominator; quantile type) the variants are COMPUTED AND PRINTED so the
# reader can see which definition the target was written under. That is diagnosis,
# not tuning: a variant is only accepted if it matches every value in the set.
#
# NO P-VALUES. Nothing here is a model.

ROOT <- normalizePath(".", winslash = "/")
source(file.path(ROOT, "R", "gayini_fit.R"))
CSV <- file.path(ROOT, "Output", "tables", "PARTREG_part_residuals.csv")

TARGET_Q5 <- c(66.7, 68.8, 72.5, 75.0, 75.0)     # Inland mean floor by wetness fifth
TARGET_SD <- c(12.81, 8.49, 6.33, 3.83)          # residual SD by water quartile
TOL_Q5 <- 0.05
TOL_SD <- 0.005

d <- utils::read.csv(CSV, stringsAsFactors = FALSE)
cat(strrep("=", 76), "\n")
cat("Pack v1.3 T0 - the two caption numbers\n")
cat(strrep("=", 76), "\n")
cat(sprintf("\n[input] %s\n        %d rows   sha256-first50 %s\n",
            basename(CSV), nrow(d), substr(gayini_sha256_first50_file(CSV), 1, 24)))

wmean <- function(v, w) sum(w * v) / sum(w)
band <- function(x, k) {
  br <- stats::quantile(x, seq(0, 1, length.out = k + 1), type = 7)
  br[1] <- -Inf; br[length(br)] <- Inf
  cut(x, breaks = br, labels = FALSE, include.lowest = TRUE)
}

# ---- 1 · Inland mean floor by wetness fifth ---------------------------------------
cat("\n[1] Inland mean floor by wetness fifth, pixel-weighted\n")
inl <- d[d$community_short == "inland", ]
inl$fifth <- band(inl$whole_record__inund_mean, 5)
got_q5 <- sapply(1:5, function(k) {
  s <- inl[inl$fifth == k, ]
  wmean(s$whole_record__floor_mean, s$n_pixels_part)
})
got_q5_unw <- sapply(1:5, function(k) mean(inl$whole_record__floor_mean[inl$fifth == k]))
n_q5 <- sapply(1:5, function(k) sum(inl$fifth == k))
cat(sprintf("  n Inland parts %d, bin sizes %s\n", nrow(inl), paste(n_q5, collapse = " / ")))
cat(sprintf("  target          %s\n", paste(sprintf("%.1f", TARGET_Q5), collapse = " · ")))
cat(sprintf("  pixel-weighted  %s\n", paste(sprintf("%.1f", got_q5), collapse = " · ")))
cat(sprintf("  unweighted      %s   (variant, for diagnosis only)\n",
            paste(sprintf("%.1f", got_q5_unw), collapse = " · ")))
ok_q5 <- all(abs(round(got_q5, 1) - TARGET_Q5) <= TOL_Q5)
cat(sprintf("  -> %s\n", if (ok_q5) "REPRODUCES" else "*** DOES NOT REPRODUCE ***"))

# ---- 2 · residual SD by water quartile --------------------------------------------
cat("\n[2] SD of the whole-record residual, within quartiles of whole-record wetness\n")
d$quart <- band(d$whole_record__inund_mean, 4)
sd_pop <- function(v) sqrt(sum((v - mean(v))^2) / length(v))
got_sd_samp <- sapply(1:4, function(k) stats::sd(d$whole_record__residual[d$quart == k]))
got_sd_pop <- sapply(1:4, function(k) sd_pop(d$whole_record__residual[d$quart == k]))
n_sd <- sapply(1:4, function(k) sum(d$quart == k))
cat(sprintf("  n parts %d, bin sizes %s\n", nrow(d), paste(n_sd, collapse = " / ")))
cat(sprintf("  target                %s\n", paste(sprintf("%.2f", TARGET_SD), collapse = " · ")))
cat(sprintf("  sample SD (n-1)       %s\n", paste(sprintf("%.2f", got_sd_samp), collapse = " · ")))
cat(sprintf("  population SD (n)     %s   (variant, for diagnosis only)\n",
            paste(sprintf("%.2f", got_sd_pop), collapse = " · ")))
ok_sd_samp <- all(abs(round(got_sd_samp, 2) - TARGET_SD) <= TOL_SD)
ok_sd_pop <- all(abs(round(got_sd_pop, 2) - TARGET_SD) <= TOL_SD)
ok_sd <- ok_sd_samp || ok_sd_pop
cat(sprintf("  -> %s%s\n",
            if (ok_sd) "REPRODUCES" else "*** DOES NOT REPRODUCE ***",
            if (ok_sd) paste0(" under the ", if (ok_sd_samp) "sample (n-1)" else "population (n)",
                              " denominator") else ""))
cat(sprintf("  the wettest quartile carries %.1f%% of the driest quartile's scatter\n",
            100 * (if (ok_sd_samp) got_sd_samp else got_sd_pop)[4] /
              (if (ok_sd_samp) got_sd_samp else got_sd_pop)[1]))

# ---- outputs -----------------------------------------------------------------------
res <- rbind(
  data.frame(number = "inland_floor_by_wetness_fifth",
             bin = paste0("fifth_", 1:5), n_units = n_q5,
             target = TARGET_Q5, got = round(got_q5, 4),
             agrees = abs(round(got_q5, 1) - TARGET_Q5) <= TOL_Q5, stringsAsFactors = FALSE),
  data.frame(number = "residual_sd_by_water_quartile",
             bin = paste0("quartile_", 1:4), n_units = n_sd,
             target = TARGET_SD,
             got = round(if (ok_sd_samp) got_sd_samp else got_sd_pop, 4),
             agrees = abs(round(if (ok_sd_samp) got_sd_samp else got_sd_pop, 2) - TARGET_SD) <= TOL_SD,
             stringsAsFactors = FALSE))
utils::write.csv(res, file.path(ROOT, "Output/tables/PACKv13_T0_caption_numbers.csv"),
                 row.names = FALSE)

cat("\n", strrep("=", 76), "\n", sep = "")
if (ok_q5 && ok_sd) {
  cat("BOTH REPRODUCE - both caption clauses stand, and both are registered next.\n")
} else {
  cat("A CLAUSE FAILS TO REPRODUCE. Per T0 it is CUT, not softened:\n")
  if (!ok_q5) cat("  - the Inland wetness-fifth clause comes out of the three-periods panel C caption\n")
  if (!ok_sd) cat("  - the residual-SD-by-quartile clause comes out of the residual-maps footer\n")
  quit(status = 1)
}
