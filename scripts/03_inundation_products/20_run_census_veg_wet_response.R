# ------------------------------------------------------------------------------
# Script: scripts/03_inundation_products/20_run_census_veg_wet_response.R
# Purpose: Tier 2 · Task H · Gate E (G1b) — the PER-PIXEL same-year veg x wet
#          response census. For every census focus pixel, over 35 water years:
#          the temporal correlation of annual total-veg against the annual
#          BINARY wet/dry state (from the NN 8058 annual stack). Summarised to
#          the 9 focus strata (S26 matrix) and the 3 communities (S24 singles).
#
#          WHY BINARY (the reframe's resolved fork, signed off): the project
#          deliberately made between-year annual flood frequency the HEADLINE and
#          demoted within-year "occurrence" to a labelled secondary (lineage §5),
#          so NO continuous within-year per-pixel intensity exists across the full
#          record. The only full-record per-pixel inundation signal is the binary
#          annual wet/dry state — which is therefore the correct same-year axis.
#          This answers: "does a pixel's cover differ in flood years vs dry years?"
#          It is NOT the plot version's continuous within-year occurrence axis; the
#          difference is deliberate and stated.
#
#          BASE series = reduction A (mean-of-available seasons, G1a). CROSS-CHECK
#          = reduction B (JJA/SON). Because B thins in cloudy years, B is reported
#          ONLY on the pixel set where B is estimable (>= MIN_RESPONSE_YEARS paired
#          years), with A recomputed on that SAME set for a like-for-like delta.
#
# Workflow stage: 03_inundation_products · Tier 2 Task H, Gate E, G1b (alongside 12)
# Run mode: analysis (per-pixel raster correlation + zonal summary) · additive · read-only DB
# Key inputs:
#   - Output/rasters/veg_annual_8058/total_veg_annual_mean_8058.tif      (A: 35 lyr, 8058; G1a)
#   - Output/rasters/veg_annual_8058/total_veg_annual_jja_son_8058.tif   (B: 35 lyr, 8058; G1a)
#   - Output/rasters/inundation_annual_stack_8058/annual_{wet,valid}_any_1988_2023_8058.tif (NN, 8058)
#   - Output/rasters/veg_regime_class_8058.tif                           (strata partition, footprint)
#   - Output/csv/f7_response_summary.csv                                 (PLOT-support same-year benchmark)
# Key outputs (additive; Output/ gitignored; NOT registered here — that is G7):
#   - Output/diagnostics/tier2H_g1b_census_veg_wet_response_by_stratum.csv   (9 cells; S26)
#   - Output/diagnostics/tier2H_g1b_census_veg_wet_response_by_community.csv  (3 rows; S24)
#   - Output/rasters/veg_annual_8058/census_veg_wet_response_r_meanseason_8058.tif (per-pixel r, A)
#   - Output/diagnostics/tier2H_g1b_qa.json
#
# HONESTY / DISCIPLINE:
#   - PIXEL support. The pixel counts are NOT independent n — census pixels are
#     spatially (and temporally) autocorrelated. Report counts as coverage, never as
#     degrees of freedom. Caveat written into the CSV header.
#   - This is a RESULT, not a reconciliation. If a stratum comes back weaker or
#     sign-inconsistent vs the plot r-values, that is the census finding — surfaced,
#     not tuned away. Plot-vs-pixel inversions are real and expected (C10).
#   - Structure-vs-condition limit stands: Landsat FC measures cover, not ecological
#     condition; a tight interval over ~1M pixels does not lift that.
#   - Read-only rasters/DB. Nothing existing is overwritten. STOP at the table.
# ------------------------------------------------------------------------------

## 0. Constants ----

FOCUS_CODES        <- c(11L, 12L, 13L, 21L, 22L, 23L, 31L, 32L, 33L)
MIN_RESPONSE_YEARS <- 25L    # paired veg-years a pixel needs for a same-year r (census MIN_VALID_YEARS convention)
R_RESPOND          <- 0.20   # our default (flagged, Adrian Q3 family): stratum median |r| to "respond"
SIGN_FRAC          <- 0.70   # ... and this share of pixels must agree in sign
MIN_RESP_COVERAGE  <- 0.50   # if < this share of a stratum's pixels yield a defined r, verdict is coverage-limited


## 1. Sources ----

root_dir <- normalizePath(Sys.getenv("GAYINI_ROOT", getwd()), winslash = "/", mustWork = TRUE)

source(file.path(root_dir, "R", "gayini_helpers.R"))
source(file.path(root_dir, "R", "gayini_output_helpers.R"))
source(file.path(root_dir, "R", "gayini_output_paths.R"))
source(file.path(root_dir, "R", "gayini_gradient_helpers.R"))
source(file.path(root_dir, "R", "gayini_stratified_sampling_functions.R"))  # focus / band levels
source(file.path(root_dir, "R", "gayini_veg_regime_functions.R"))           # code -> community x band

suppressPackageStartupMessages({
  library(terra)
  library(dplyr)
})
terra::terraOptions(progress = 0)

rasters_dir     <- file.path(root_dir, "Output", "rasters")
diagnostics_dir <- file.path(root_dir, "Output", "diagnostics")
csv_dir         <- file.path(root_dir, "Output", "csv")

veg_a_tif <- file.path(rasters_dir, "veg_annual_8058", "total_veg_annual_mean_8058.tif")
veg_b_tif <- file.path(rasters_dir, "veg_annual_8058", "total_veg_annual_jja_son_8058.tif")
stack_dir <- file.path(rasters_dir, "inundation_annual_stack_8058")
wet_tif   <- file.path(stack_dir, "annual_wet_any_1988_2023_8058.tif")
val_tif   <- file.path(stack_dir, "annual_valid_any_1988_2023_8058.tif")
class_tif <- file.path(rasters_dir, "veg_regime_class_8058.tif")
plot_csv  <- file.path(csv_dir, "f7_response_summary.csv")
for (p in c(veg_a_tif, veg_b_tif, wet_tif, val_tif, class_tif))
  gayini_stop_if_missing(p, label = basename(p))

focus_communities <- gayini_focus_levels()
band_levels       <- gayini_regime_band_levels()
classes           <- gayini_veg_regime_classes()
class_lut <- classes |>
  dplyr::transmute(code, community, regime_band = band,
                   stratum = paste(community, band, sep = " | "))


## 2. Load + grid discipline + year alignment ----

message("\n================ G1b · load + align ================")
veg_a <- terra::rast(veg_a_tif)
veg_b <- terra::rast(veg_b_tif)
wet   <- terra::rast(wet_tif)
val   <- terra::rast(val_tif)
class_r <- terra::rast(class_tif); levels(class_r) <- NULL; terra::coltab(class_r) <- NULL

## compareGeom across ALL inputs against the canonical grid (silent misalignment
## produces plausible wrong numbers — assert, do not assume).
for (nm in c("veg_a", "veg_b", "wet", "val")) {
  r <- get(nm)
  ok <- terra::compareGeom(r, class_r, lyrs = FALSE, crs = TRUE, ext = TRUE,
                           rowcol = TRUE, res = TRUE, stopOnError = FALSE)
  stopifnot(isTRUE(ok), terra::nlyr(r) == 35L)
}
message("  compareGeom(all inputs, veg_regime_class_8058) = TRUE · 35 layers each.")

## Align by WATER-YEAR NAME, not positional order.
wy <- names(veg_a)
stopifnot(all(grepl("^[0-9]{4}-[0-9]{4}$", wy)), length(wy) == 35L)
reorder_to <- function(r, target) {
  if (identical(names(r), target)) return(r)
  stopifnot(setequal(names(r), target))
  r[[match(target, names(r))]]
}
veg_b <- reorder_to(veg_b, wy)
wet   <- reorder_to(wet, wy)
val   <- reorder_to(val, wy)
message("  year alignment: all four stacks reordered to ", wy[1], " .. ", wy[35], " by name.")


## 3. Build the per-pixel binary wet/dry state x ----
##    x = wet where valid==1, else NA. wet subseteq valid, valid is presence-only {1,NA}.
##    For census focus pixels valid==1 for all 35 yr (facts §5), so x is complete {0,1}.

x <- terra::ifel(val == 1, wet, NA)
names(x) <- wy


## 4. Per-pixel pairwise-complete Pearson r over 35 yr (a raster op — NOT a 37.8M-row table) ----
##    Data contract §4: the rasters ARE the time dimension. r per pixel -> ONE r raster.

pearson_r <- function(y) {
  ## co-mask: keep only years where BOTH x and y are present, per pixel.
  xm <- terra::ifel(is.na(y), NA, x)
  ym <- terra::ifel(is.na(x), NA, y)
  n  <- terra::app(!is.na(xm) & !is.na(ym), "sum")
  mx <- terra::app(xm, "mean", na.rm = TRUE)
  my <- terra::app(ym, "mean", na.rm = TRUE)
  dx <- xm - mx; dy <- ym - my
  sxy <- terra::app(dx * dy, "sum", na.rm = TRUE)
  sxx <- terra::app(dx * dx, "sum", na.rm = TRUE)   # = x variance * n ; 0 => never/always wet
  syy <- terra::app(dy * dy, "sum", na.rm = TRUE)   # = y variance * n ; 0 => flat cover
  r   <- sxy / sqrt(sxx * syy)
  ## wet-dry effect size (interpretable companion to r): mean veg in wet yrs - dry yrs.
  y_wet <- terra::ifel(xm == 1, ym, NA); y_dry <- terra::ifel(xm == 0, ym, NA)
  n_wet <- terra::app(!is.na(y_wet), "sum"); n_dry <- terra::app(!is.na(y_dry), "sum")
  wetdry <- terra::app(y_wet, "mean", na.rm = TRUE) - terra::app(y_dry, "mean", na.rm = TRUE)
  wetdry <- terra::ifel(n_wet >= 1 & n_dry >= 1, wetdry, NA)
  list(r = r, n = n, sxx = sxx, syy = syy, wetdry = wetdry)
}

message("\n================ G1b · per-pixel response (base = A mean-of-season) ================")
A <- pearson_r(veg_a)
message("  computing cross-check (B = JJA/SON) ...")
B <- pearson_r(veg_b)


## 5. Extract to a focus-pixel frame and summarise ----
##    Pull class + both response fields for the focus footprint; filter and group.

fr <- terra::values(c(class_r, A$r, A$n, A$sxx, A$syy, A$wetdry, B$r, B$n))
colnames(fr) <- c("code", "rA", "nA", "sxxA", "syyA", "wetdry", "rB", "nB")
fr <- as.data.frame(fr)
fr <- fr[fr$code %in% FOCUS_CODES & !is.na(fr$code), ]
fr <- dplyr::left_join(fr, class_lut, by = "code")

## Defined-r flags (base A): needs enough paired years AND non-degenerate x and y.
fr$defA <- fr$nA >= MIN_RESPONSE_YEARS & fr$sxxA > 0 & fr$syyA > 0 & is.finite(fr$rA)
fr$defB <- fr$nB >= MIN_RESPONSE_YEARS & is.finite(fr$rB)
## Exclusion reasons (mutually informative; a never-flood pixel has sxxA == 0).
fr$no_flood_var <- fr$nA >= MIN_RESPONSE_YEARS & fr$sxxA == 0            # never (or always) wet -> no same-year contrast
fr$few_years    <- fr$nA <  MIN_RESPONSE_YEARS                          # veg too sparse (cloud)

q <- function(v, p) if (sum(!is.na(v))) as.numeric(stats::quantile(v, p, names = FALSE, na.rm = TRUE)) else NA_real_

summarise_group <- function(df, keys) {
  df |>
    dplyr::group_by(dplyr::across(dplyr::all_of(keys))) |>
    dplyr::group_modify(function(g, key) {
      rA  <- g$rA[g$defA]
      wd  <- g$wetdry[g$defA]
      ## B like-for-like: on pixels estimable in B, compare A and B on the SAME set.
      bset <- g$defB & g$defA
      tibble::tibble(
        n_pixels_focus      = nrow(g),
        n_pixels_response   = length(rA),
        resp_coverage_pct   = round(100 * length(rA) / nrow(g), 2),
        n_never_flood       = sum(g$no_flood_var),
        n_few_veg_years     = sum(g$few_years),
        median_r            = round(stats::median(rA, na.rm = TRUE), 4),
        mean_r              = round(mean(rA, na.rm = TRUE), 4),
        sign_frac_pos       = round(mean(rA > 0, na.rm = TRUE), 4),
        r_p10 = round(q(rA,0.10),4), r_p25 = round(q(rA,0.25),4), r_p50 = round(q(rA,0.50),4),
        r_p75 = round(q(rA,0.75),4), r_p90 = round(q(rA,0.90),4),
        wet_minus_dry_veg_pts = round(stats::median(wd, na.rm = TRUE), 3),
        ## robustness cross-check (restricted, like-for-like)
        n_pixels_B          = sum(bset),
        median_r_B          = round(stats::median(g$rB[bset], na.rm = TRUE), 4),
        median_r_A_on_Bset  = round(stats::median(g$rA[bset], na.rm = TRUE), 4)
      )
    }) |>
    dplyr::ungroup()
}

verdict_of <- function(median_r, sign_frac, resp_cov) {
  if (is.na(median_r) || is.na(sign_frac)) return("undetermined")
  if (resp_cov < 100 * MIN_RESP_COVERAGE)  return("coverage_limited")  # e.g. stratum rarely/never floods
  if (median_r >= R_RESPOND && sign_frac >= SIGN_FRAC)                  return("responds")
  if (sign_frac > (1 - SIGN_FRAC) && sign_frac < SIGN_FRAC)            return("mixed")
  "weak_or_none"
}

by_stratum <- summarise_group(fr, c("community", "regime_band", "stratum")) |>
  dplyr::mutate(community = factor(community, levels = focus_communities),
                regime_band = factor(regime_band, levels = band_levels)) |>
  dplyr::arrange(community, regime_band)
by_stratum$verdict <- mapply(verdict_of, by_stratum$median_r, by_stratum$sign_frac_pos,
                             by_stratum$resp_coverage_pct)

by_community <- summarise_group(fr, "community") |>
  dplyr::mutate(community = factor(community, levels = focus_communities)) |>
  dplyr::arrange(community)
by_community$verdict <- mapply(verdict_of, by_community$median_r, by_community$sign_frac_pos,
                               by_community$resp_coverage_pct)


## 6. Attach the PLOT-support same-year benchmark (labelled reference, NOT a target) ----

if (file.exists(plot_csv)) {
  pv <- readr::read_csv(plot_csv, show_col_types = FALSE) |>
    dplyr::transmute(community = as.character(community), regime_band = as.character(regime_band),
                     plot_median_r_veg = round(median_r_veg, 4),
                     plot_sign_frac = round(sign_frac_pos, 4),
                     plot_verdict = as.character(verdict), plot_n = n_plots)
  by_stratum <- by_stratum |>
    dplyr::mutate(community = as.character(community), regime_band = as.character(regime_band)) |>
    dplyr::left_join(pv, by = c("community", "regime_band"))
  pv_comm <- readr::read_csv(plot_csv, show_col_types = FALSE) |>
    dplyr::group_by(community = as.character(community)) |>
    dplyr::summarise(plot_median_r_veg = round(stats::median(median_r_veg, na.rm = TRUE), 4),
                     plot_n = sum(n_plots), .groups = "drop")
  by_community <- by_community |>
    dplyr::mutate(community = as.character(community)) |>
    dplyr::left_join(pv_comm, by = "community")
  message("  attached plot-support same-year benchmark (labelled reference).")
} else {
  message("  NOTE: f7_response_summary.csv absent — plot-support benchmark column omitted.")
}


## 7. Write the two committed tables (with the autocorrelation caveat in the header) ----

CAVEAT <- paste0(
  "# Tier2H G1b · per-pixel same-year veg x wet(binary) response census. SUPPORT = PIXEL (census, 24.97 m). ",
  "Pixel counts are COVERAGE, NOT independent n (census pixels are spatially + temporally autocorrelated). ",
  "Intensity axis = annual BINARY wet/dry (NOT the plot version's continuous within-year occurrence) - deliberate. ",
  "Base r = reduction A (mean-of-available seasons); median_r_B / _A_on_Bset = JJA/SON cross-check on B-estimable px only ",
  "(B thins in cloudy WYs; MIN_RESPONSE_YEARS=", MIN_RESPONSE_YEARS, "). plot_* cols = PLOT-support benchmark (reference, not a target). ",
  "'no_flood' pixels never got wet in 35 yr -> same-year contrast undefined (a result, not a gap). ",
  "FC measures cover, not ecological condition; tight intervals do not lift that limit.")

write_with_caveat <- function(df, path) {
  con <- file(path, open = "wt"); writeLines(CAVEAT, con); close(con)
  readr::write_csv(df, path, append = TRUE, col_names = TRUE)
  message("Wrote: ", path)
}
strat_path <- file.path(diagnostics_dir, "tier2H_g1b_census_veg_wet_response_by_stratum.csv")
comm_path  <- file.path(diagnostics_dir, "tier2H_g1b_census_veg_wet_response_by_community.csv")
write_with_caveat(by_stratum, strat_path)
write_with_caveat(by_community, comm_path)

## Write the per-pixel base-A response raster (candidate G7 product; masked to focus).
r_focus <- terra::mask(A$r, terra::app(class_r, function(v) ifelse(v %in% FOCUS_CODES, 1, NA)))
r_out <- file.path(rasters_dir, "veg_annual_8058", "census_veg_wet_response_r_meanseason_8058.tif")
terra::writeRaster(r_focus, r_out, overwrite = TRUE, datatype = "FLT4S")
message("Wrote: ", gayini_relative_path(root_dir, r_out))


## 8. Console readout ----

message("\n================ H · CENSUS veg x wet(binary) same-year response — BY COMMUNITY (S24) ================")
print(as.data.frame(by_community[, c("community","n_pixels_focus","n_pixels_response","resp_coverage_pct",
                                     "median_r","sign_frac_pos","wet_minus_dry_veg_pts","median_r_B",
                                     "median_r_A_on_Bset","verdict",
                                     intersect("plot_median_r_veg", names(by_community)))]), row.names = FALSE)
message("\n================ BY STRATUM (S26 · 9 cells) ================")
print(as.data.frame(by_stratum[, c("community","regime_band","n_pixels_focus","n_pixels_response",
                                   "resp_coverage_pct","n_never_flood","median_r","sign_frac_pos",
                                   "wet_minus_dry_veg_pts","median_r_B","median_r_A_on_Bset","verdict",
                                   intersect("plot_median_r_veg", names(by_stratum)),
                                   intersect("plot_verdict", names(by_stratum)))]), row.names = FALSE)


## 9. QA json ----

qa <- list(
  step = "G1b per-pixel same-year veg x wet(binary) response census",
  generated_by = "scripts/03_inundation_products/20_run_census_veg_wet_response.R",
  gate = "Tier2 Task H · Gate E · G1b (STOP at the table, before any figure)",
  method = list(
    statistic = "per-pixel pairwise-complete Pearson r(annual total-veg, annual binary wet/dry) over 35 WY",
    intensity_axis = "annual BINARY wet/dry (full-record); NOT continuous within-year occurrence (deliberate, lineage §5)",
    base_series = "reduction A (mean-of-available seasons)",
    cross_check = "reduction B (JJA/SON) on B-estimable pixels only; A recomputed on same set (like-for-like)",
    min_response_years = MIN_RESPONSE_YEARS,
    verdict_thresholds = list(R_RESPOND = R_RESPOND, SIGN_FRAC = SIGN_FRAC,
                              MIN_RESP_COVERAGE = MIN_RESP_COVERAGE, flagged_for_adrian = TRUE)),
  support = "PIXEL (census). Pixel counts are coverage, not independent n (spatial + temporal autocorrelation).",
  framing = "This is a RESULT. Plot-vs-pixel inversions vs the plot r-values are real and are reported, not reconciled.",
  by_community = lapply(seq_len(nrow(by_community)), function(i) as.list(by_community[i, ])),
  by_stratum   = lapply(seq_len(nrow(by_stratum)),   function(i) as.list(by_stratum[i, ])),
  outputs = list(
    by_stratum_csv = "Output/diagnostics/tier2H_g1b_census_veg_wet_response_by_stratum.csv",
    by_community_csv = "Output/diagnostics/tier2H_g1b_census_veg_wet_response_by_community.csv",
    response_r_raster = gayini_relative_path(root_dir, r_out)),
  not_registered = "raster/table NOT registered here — registration is G7 (non-destructive)",
  next_step = "STOP for review. Figures (matrix-first S26 -> S24) are G5, a separate gate.")
jsonlite::write_json(qa, file.path(diagnostics_dir, "tier2H_g1b_qa.json"),
                     auto_unbox = TRUE, pretty = TRUE, digits = 6)


## 10. Summary — STOP at the table ----

message("\n==================== G1b COMPLETE — STOP AT THE TABLE ====================")
message("By-community (S24): Output/diagnostics/tier2H_g1b_census_veg_wet_response_by_community.csv")
message("By-stratum  (S26): Output/diagnostics/tier2H_g1b_census_veg_wet_response_by_stratum.csv")
message("Per-pixel r raster: ", gayini_relative_path(root_dir, r_out))
message("Support = PIXEL. Counts are coverage, not independent n. This is the census result, not a reconciliation.")
message("NOT registered (G7). NEXT: figures (G5, matrix-first) — a separate gate. STOP for review.")
