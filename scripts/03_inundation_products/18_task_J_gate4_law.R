# ------------------------------------------------------------------------------
# Script: scripts/03_inundation_products/18_task_J_gate4_law.R
# Purpose: Tier 1 · Task J · GATE 4 (part 1) — THE LAW. Fit diff_pp ~ a+b*log(q_ratio)
#          on the 24 PIXEL placebos only (never 2018), predict 2018, and rank the
#          out-of-sample residual against the in-sample placebo residuals. Emits the
#          law summary, the full 25-date residual ranking, and the heteroscedasticity
#          evidence. Descriptive; NOT an effect estimate.
# Workflow stage: 03_inundation_products · Tier 1 Task J · additive · no rasters
# PRE-REGISTERED at Gate-4 sign-off: rank is by the POOLED residual sd (ddof=1).
#   The residuals are heteroscedastic (evidenced below) — that is recorded as a
#   CAVEAT on the sd framing, NOT acted on. No re-ranking, no regime-scaling, no
#   refit after seeing the answer (that is exactly what the placebo design prevents).
# NO p-value or CI from the placebo spread: consecutive dates share 4 of 5 post
#   years; 25 dates is not 25 tests, only 5 are independent.
# Inputs : Output/tables/task_J_gate3_J_T1.csv
# Outputs (small; committable via git add -f):
#   Output/tables/task_J_gate4_law_summary.csv
#   Output/tables/task_J_gate4_residual_ranking.csv
#   Output/tables/task_J_gate4_heteroscedasticity.csv
# ------------------------------------------------------------------------------

root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", getwd()), winslash = "/", mustWork = TRUE)
tables_dir <- file.path(root_dir, "Output", "tables")
suppressPackageStartupMessages({ library(dplyr); library(readr) })

REAL_CUT_YEAR <- 2018L
WET_Q_CUTOFF  <- 0.60   # regime split for the heteroscedasticity CAVEAT only (post-hoc, not used to rank)

jt1 <- readr::read_csv(file.path(tables_dir, "task_J_gate3_J_T1.csv"), show_col_types = FALSE)
jt1 <- jt1 |> dplyr::arrange(cut_year) |> dplyr::mutate(logq = log(q_ratio))
placebo <- jt1 |> dplyr::filter(!is_real)
real    <- jt1 |> dplyr::filter(is_real)
stopifnot(nrow(placebo) == 24, nrow(real) == 1)

## --- PRIMARY LAW (24 placebos) ---
fit <- lm(diff_pp ~ logq, data = placebo)
a <- unname(coef(fit)[1]); b <- unname(coef(fit)[2]); r2 <- summary(fit)$r.squared
res_placebo <- resid(fit)
resid_sd_ddof1 <- sd(res_placebo)          # PRE-REGISTERED denominator (ddof=1)
sigma_ddof2    <- summary(fit)$sigma       # regression residual standard error (ddof=2), reported for reference

pred2018 <- as.numeric(predict(fit, newdata = real))
obs2018  <- real$diff_pp
resid2018_pp <- obs2018 - pred2018
resid2018_sd <- resid2018_pp / resid_sd_ddof1

## --- FULL RANKING across all 25 (2018 out-of-sample) ---
jt1 <- jt1 |> dplyr::mutate(
  predicted      = a + b * logq,
  residual_pp    = diff_pp - predicted,
  residual_sd_ddof1 = residual_pp / resid_sd_ddof1,
  abs_residual   = abs(residual_pp)
) |> dplyr::arrange(dplyr::desc(abs_residual)) |>
  dplyr::mutate(residual_rank = dplyr::row_number())

rank2018 <- jt1$residual_rank[jt1$is_real]
n_placebo_exceed <- sum(abs(placebo$diff_pp - (a + b * placebo$logq)) > abs(resid2018_pp))

cat("================ GATE 4 · THE LAW (pixel, 24 placebos) ================\n")
cat(sprintf("diff_pp = %+.4f %+.4f * log(q_ratio)  ;  R^2 = %.4f\n", a, b, r2))
cat(sprintf("residual sd (ddof=1, PRE-REGISTERED denominator) = %.4f pp ; sigma(ddof=2)=%.4f\n",
            resid_sd_ddof1, sigma_ddof2))
cat(sprintf("2018: predicted %+.4f  observed %+.4f  residual %+.4f pp = %.2f sd\n",
            pred2018, obs2018, resid2018_pp, resid2018_sd))
cat(sprintf(">>> 2018 |residual| RANK = %d of 25 ; placebos exceeding 2018 = %d of 24\n",
            rank2018, n_placebo_exceed))

## --- ROBUSTNESS (a) two-variable ; (b) 5 independent windows ---
fit2 <- lm(diff_pp ~ logq + n_pre_years, data = placebo)
pred2018_2v <- as.numeric(predict(fit2, newdata = real)); sd2 <- sd(resid(fit2))
indep <- jt1 |> dplyr::filter(cut_year %in% c(1994,1999,2004,2009,2014)); stopifnot(nrow(indep)==5)
fit_i <- lm(diff_pp ~ logq, data = indep)
pred2018_i <- as.numeric(predict(fit_i, newdata = real)); sd_i <- sd(resid(fit_i))

law_summary <- dplyr::tibble(
  model = c("primary_24placebo", "two_var_24placebo", "independent_5"),
  intercept = c(a, coef(fit2)[1], coef(fit_i)[1]),
  b_logq    = c(b, coef(fit2)["logq"], coef(fit_i)[2]),
  b_n_pre_years = c(NA, coef(fit2)["n_pre_years"], NA),
  r2 = c(r2, summary(fit2)$r.squared, summary(fit_i)$r.squared),
  resid_sd_ddof1_pp = c(resid_sd_ddof1, sd2, sd_i),
  pred_2018_pp = c(pred2018, pred2018_2v, pred2018_i),
  obs_2018_pp  = obs2018,
  resid_2018_pp = c(resid2018_pp, obs2018-pred2018_2v, obs2018-pred2018_i),
  resid_2018_sd_ddof1 = c(resid2018_sd, (obs2018-pred2018_2v)/sd2, (obs2018-pred2018_i)/sd_i),
  resid_2018_rank_of_25 = c(rank2018, NA, NA),
  n_placebo_exceed_2018 = c(n_placebo_exceed, NA, NA)
) |> dplyr::mutate(dplyr::across(where(is.numeric), ~round(.x, 4)))
readr::write_csv(law_summary, file.path(tables_dir, "task_J_gate4_law_summary.csv"))

ranking_out <- jt1 |> dplyr::transmute(
  residual_rank, cut_year, q_ratio = round(q_ratio,4), diff_pp = round(diff_pp,4),
  predicted = round(predicted,4), residual_pp = round(residual_pp,4),
  residual_sd_ddof1 = round(residual_sd_ddof1,3), is_real
) |> dplyr::arrange(residual_rank)
readr::write_csv(ranking_out, file.path(tables_dir, "task_J_gate4_residual_ranking.csv"))

## --- HETEROSCEDASTICITY (CAVEAT ON the sd framing — evidenced, NOT acted on) ---
placebo <- placebo |> dplyr::mutate(residual_pp = diff_pp - (a + b*logq),
                                    regime = ifelse(q_ratio < WET_Q_CUTOFF, "dry_q_lt_0.6", "wet_q_ge_0.6"))
het <- placebo |> dplyr::group_by(regime) |>
  dplyr::summarise(n_placebos = dplyr::n(),
                   residual_sd_ddof1 = round(sd(residual_pp), 3),
                   mean_abs_diff_pp  = round(mean(abs(diff_pp)), 3),
                   max_residual_pp   = round(max(residual_pp), 3),
                   max_residual_date = cut_year[which.max(residual_pp)], .groups = "drop")
corr_absres_absdiff <- cor(abs(placebo$residual_pp), abs(placebo$diff_pp))

# scaling-free comparison (needs no error model): among WET-post placebos (comparable to 2018)
wet_pl <- placebo |> dplyr::filter(regime == "wet_q_ge_0.6")
max_wet_res <- max(wet_pl$residual_pp); max_wet_date <- wet_pl$cut_year[which.max(wet_pl$residual_pp)]
dry_pl <- placebo |> dplyr::filter(regime == "dry_q_lt_0.6")
max_dry_res <- max(dry_pl$residual_pp); max_dry_date <- dry_pl$cut_year[which.max(dry_pl$residual_pp)]

het_out <- dplyr::bind_rows(
  het,
  dplyr::tibble(regime = "ALL_placebos", n_placebos = 24L,
                residual_sd_ddof1 = round(resid_sd_ddof1,3),
                mean_abs_diff_pp = round(mean(abs(placebo$diff_pp)),3),
                max_residual_pp = round(max(placebo$residual_pp),3),
                max_residual_date = placebo$cut_year[which.max(placebo$residual_pp)])
)
het_out$corr_absresid_absdiff <- round(corr_absres_absdiff, 3)
het_out$note <- "CAVEAT on sd framing only; pooled sd used to rank (pre-registered); NOT re-scaled"
readr::write_csv(het_out, file.path(tables_dir, "task_J_gate4_heteroscedasticity.csv"))

cat("\n---- HETEROSCEDASTICITY (caveat on the sd framing; NOT acted on) ----\n")
print(as.data.frame(het), row.names = FALSE)
cat(sprintf("corr(|residual|, |diff_pp|) = %+.3f  (multiplicative error)\n", corr_absres_absdiff))
cat(sprintf("Scaling-free: largest WET-post placebo residual = %+.2f pp (C=%d); 2018 = %+.2f pp = %.1fx it\n",
            max_wet_res, max_wet_date, resid2018_pp, resid2018_pp/max_wet_res))
cat(sprintf("             largest DRY-post placebo residual = %+.2f pp (C=%d)  <- the one date above 2018 overall\n",
            max_dry_res, max_dry_date))
cat("\nWrote:\n  ", file.path(tables_dir, "task_J_gate4_law_summary.csv"),
    "\n  ", file.path(tables_dir, "task_J_gate4_residual_ranking.csv"),
    "\n  ", file.path(tables_dir, "task_J_gate4_heteroscedasticity.csv"), "\n")
cat("\n================ GATE 4 LAW COMPLETE ================\n")
