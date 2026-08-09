# UNZONED v3 section 1.1 - is the temporal metric actually size-robust?
#
# The spec's table says veg_p05_temporal_mean is "expected to be slight" in its
# sensitivity to unit size, and that expectation is what licenses Arm A to run without
# v2 section 2.3's size-matched subsetting. I-40 applies: that is a design-seat claim,
# so it is MEASURED here before anything relies on it.
#
# METHOD. On the 100 zoned parts already plotted in PARTSCATTER, take each part's
# residual against the PARTSCATTER smoother and regress it on log10(cell count). Slope
# is reported in pp per DECADE of size. Pooled and by vegetation community.
#
# TWO RESIDUAL DEFINITIONS, because the comparator was built on the other one.
#   per_community  the literal reading of section 1.1 - residual against the part's OWN
#                  community smoother, which is what PARTSCATTER actually draws.
#   pooled_line    residual against a SINGLE smoother over all 100 parts. PARTREG's
#                  -2.01 comparator is a residual against one pooled line, so only this
#                  definition is like-for-like with it. Reporting just the first would
#                  compare two differently-constructed residuals and call it a match.
#
# Aeolian gets a diagnostic smoother here even though EH forbids DRAWING one for it on
# the figure. EH governs a fitted line on a client-facing face; this is a device to
# remove any water dependence before looking at size, no coefficient reaches a
# deliverable, and n = 12 is stated beside the number.
#
# The comparator itself is RECOMPUTED from PARTREG_part_residuals.csv rather than quoted
# from the spec - same reason.

suppressPackageStartupMessages({library(stats)})

root <- normalizePath(".", winslash = "/")
OUT  <- file.path(root, "Output", "unzoned")
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

SRC <- file.path(root, "Output/temporal/PARTSCATTER_scatter_input.csv")
PR  <- file.path(root, "Output/tables/PARTREG_part_residuals.csv")
stopifnot(file.exists(SRC), file.exists(PR))

d <- utils::read.csv(SRC, stringsAsFactors = FALSE)
stopifnot(nrow(d) == 100L)
d$log10_cells <- log10(d$n_cells)

# ---- residuals, both definitions ----------------------------------------------------
# ggplot's geom_smooth(method = "loess", formula = y ~ x) uses stats::loess defaults,
# span 0.75 and degree 2. Matched here so the residual is against the drawn curve.
fit_resid <- function(df) {
  m <- stats::loess(veg_p05_temporal_mean ~ mean_share_cells_wet, data = df,
                    span = 0.75, degree = 2)
  df$veg_p05_temporal_mean - stats::predict(m, newdata = df)
}

d$resid_per_community <- NA_real_
for (cs in unique(d$community_short)) {
  k <- d$community_short == cs
  d$resid_per_community[k] <- fit_resid(d[k, ])
}
d$resid_pooled_line <- fit_resid(d)
stopifnot(!any(is.na(d$resid_per_community)), !any(is.na(d$resid_pooled_line)))

# ---- the size regression ------------------------------------------------------------
size_slope <- function(df, ycol, scope) {
  y <- df[[ycol]]
  if (length(y) < 3L || stats::sd(df$log10_cells) == 0)
    return(data.frame(scope = scope, residual_definition = ycol, n = length(y),
                      slope_pp_per_decade = NA_real_, r = NA_real_,
                      log10_cells_min = min(df$log10_cells),
                      log10_cells_max = max(df$log10_cells)))
  cf <- stats::coef(stats::lm(y ~ df$log10_cells))
  data.frame(scope = scope, residual_definition = ycol, n = length(y),
             slope_pp_per_decade = unname(cf[2]),
             r = stats::cor(y, df$log10_cells),
             log10_cells_min = min(df$log10_cells),
             log10_cells_max = max(df$log10_cells))
}

rows <- list()
for (ycol in c("resid_per_community", "resid_pooled_line")) {
  rows[[length(rows) + 1L]] <- size_slope(d, ycol, "pooled")
  for (cs in c("aeolian", "riverine", "inland"))
    rows[[length(rows) + 1L]] <- size_slope(d[d$community_short == cs, ], ycol, cs)
}
res <- do.call(rbind, rows)

# ---- the comparator, RECOMPUTED not quoted ------------------------------------------
p <- utils::read.csv(PR, stringsAsFactors = FALSE)
# PARTREG_part_residuals.csv is WIDE - one column block per period, not a period column.
# The whole-record block is the comparator; the era blocks are a sensitivity test and
# would answer a different question.
rcol <- "whole_record__residual"
ncol_ <- "n_pixels_part"
ccol <- "community_short"
stopifnot(all(c(rcol, ncol_, ccol) %in% names(p)), nrow(p) == 115L)
p$log10_cells <- log10(p[[ncol_]])

comp <- list()
cf <- stats::coef(stats::lm(p[[rcol]] ~ p$log10_cells))
comp[[1]] <- data.frame(scope = "pooled", residual_definition = "SPATIAL floor comparator",
                        n = nrow(p), slope_pp_per_decade = unname(cf[2]),
                        r = stats::cor(p[[rcol]], p$log10_cells),
                        log10_cells_min = min(p$log10_cells),
                        log10_cells_max = max(p$log10_cells))
for (cs in c("aeolian", "riverine", "inland")) {
  q <- p[p[[ccol]] == cs, ]
  if (nrow(q) >= 3L) {
    cf <- stats::coef(stats::lm(q[[rcol]] ~ q$log10_cells))
    comp[[length(comp) + 1L]] <- data.frame(
      scope = cs, residual_definition = "SPATIAL floor comparator", n = nrow(q),
      slope_pp_per_decade = unname(cf[2]), r = stats::cor(q[[rcol]], q$log10_cells),
      log10_cells_min = min(q$log10_cells), log10_cells_max = max(q$log10_cells))
  }
}
res <- rbind(res, do.call(rbind, comp))

# ---- the pre-registered fork --------------------------------------------------------
# Like-for-like: the pooled slope on the POOLED-LINE residual against the spatial
# comparator, which is also a pooled-line residual.
temporal <- res$slope_pp_per_decade[res$scope == "pooled" &
                                      res$residual_definition == "resid_pooled_line"]
spatial <- res$slope_pp_per_decade[res$scope == "pooled" &
                                     res$residual_definition == "SPATIAL floor comparator"]
ratio <- abs(temporal) / abs(spatial)
branch <- if (ratio < 0.5) "EXPECTATION HELD" else "EXPECTATION FAILED"

res$fork_branch <- branch
res$fork_rule <- paste("materially smaller in magnitude than the spatial comparator",
                       "= |temporal| < 0.5 x |spatial| on the like-for-like pooled",
                       "residual; otherwise Arm A additionally reports the size-matched",
                       "subset per v2 section 2.3 rule 3")
res$support_level <- "pixel"
res$unit <- "paddock x community part (zoned)"
res$period_label <- "1988-2022 (35 water years)"
res$metric <- ifelse(res$residual_definition == "SPATIAL floor comparator",
                     "veg_p05_spatial", "veg_p05_temporal_mean")

utils::write.csv(res, file.path(OUT, "UNZONED_v3_size_robustness.csv"),
                 row.names = FALSE)

cat("\n== section 1.1 - size sensitivity, pp per decade of cell count ==\n")
print(res[, c("metric", "residual_definition", "scope", "n", "slope_pp_per_decade", "r")],
      row.names = FALSE, digits = 4)
cat(sprintf("\n  like-for-like pooled: temporal %+.3f vs spatial %+.3f  -> ratio %.2f  -> %s\n",
            temporal, spatial, ratio, branch))
cat(sprintf("  spec quoted the spatial comparator as -2.01; recomputed %+.3f  (%s)\n",
            spatial, if (abs(spatial + 2.01) < 0.05) "reproduces" else "DIFFERS - report it"))
