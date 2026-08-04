# DOC-1 Gate A — the eight VERIFY flags answered from the code

**Read-only.** 4 August 2026 · input `docs/reports/Gayini_RS_methods_doc.docx` (Draft-v3 title block, current content) · v5 reserved for Gate C.
Every answer names the file and line. Numbers are Gate B work and are not verified here.

---

## 1 · §2 — FC algorithm version, cross-sensor calibration, Landsat 7 SLC-off · **UNVERIFIABLE from this repository**

No code in this repository computes fractional cover. The FC rasters are **ingested as an external product**, so the algorithm version, the cross-sensor calibration between Landsat 5/7/8/9, and the treatment of the post-2003 scan-line failure are not properties of any code here.

Searched repo-wide across `.py`, `.R` and `.md` for `SLC`, `scan.?line`, `slc_off`, `calibration`, `algorithm`, `JRSRP`, `Guerschman`, `fc_version`: **no hit describes any of the three.**

`dim_source_product` is the only provenance object and it is one line deep:

| product_id | method_summary | caveat |
|---|---|---|
| `landsat_fractional_cover` | "PV/NPV/bare ground fractional cover." | "Treed plots can confound ground-cover interpretation." |
| `landsat_inundation` | "Annual occurrence and daily inundation outputs." | "Annual occurrence is not hydroperiod." |

No version string, no DOI, no calibration statement, no SLC-off handling. **What would be needed:** the provider's product metadata. This cannot be closed from code and the VERIFY flag should stay until that metadata is obtained.

*Contrast:* `dea_landcover_l3` **does** carry a full product identifier (`ga_ls_landcover_class_cyear_3 v2.0.0`) and a method summary. The two headline products are documented to a lower standard than the one that produced a negative result.

## 2 · §3.1 — the band rule · **WITHIN-COMMUNITY TERCILES**

`R/gayini_ground_cover_response_functions.R:114` — *"then apply the per-community tercile breaks (`regime_band_breaks.csv` …)"*, with the breaks table carrying `tercile_1_pct`, `tercile_2_pct`, `freq_min_pct`, `freq_max_pct` per community (`R/gayini_f5_legibility_figures.R:104-105`).

**The document's conditional caveat is required and should become unconditional.** §3.1 currently says band membership is not comparable across communities *"if terciles were used"*. They were. A "high" band in Aeolian country and a "high" band in Inland Floodplain country are different flood-frequency ranges.

Consistent with §7.1, which already states this correctly for Figure 5: the absolute zones use fixed breaks at 10/25/50% *"unlike the within-community bands of Figure 2, which are relative and are not comparable across communities."*

## 3 · §6.1 — regression diagnostics · **NONE ARE COMPUTED, ANYWHERE**

`scripts/11_database/build_REG1_gateB_register.py` fits the line and computes: slope, intercept, residuals, SSE, residual SD at ddof 0/1/2, RSE, and SE(slope) = 0.0691.

Repo-wide search for `shapiro`, `breusch`, `leverage`, `hat_`, `cooks`: **zero hits.** Residual normality, constant variance across the flood-frequency range, and per-paddock leverage are not assessed in any script.

The flag is correct: they are unreported because they were never computed. **This is the one flag that cannot be closed by writing text** — it needs the diagnostics run, which is new analysis and out of scope for DOC-1.

What *does* exist is a different robustness check: three alternative fits (bivariate / +community / within-Inland) whose intercept spread is registered, with the `+community` intercept deliberately excluded from the spread as category-conditional rather than a comparable bound.

## 4 · §6.3 — the water-adjustment specification · **TWO-STAGE RESIDUAL FORM, CONTINUOUS WATER TERM**

`scripts/12_zone_stratum/build_T13_gateB_measures.py:46-47`:

```
ws,ws_se,wr,wres,wint = ols(fld, veg)      # stage 1: water_slope, current year
ta,ta_se,_,tares,_    = ols(yrs, wres)     # stage 2: trend_adj = residuals-on-year
```

Both questions in the flag are answered, and one answer is the *non-obvious* branch:

- **Not joint.** Water first, then the trend taken in the residuals — sequential, not `veg ~ flood + year`.
- **The water term is annual flood fraction, continuous** — `flood_frac`, not a wet/dry state.

As an equation, per unit *i* over years *t*:

$$\text{veg\_p05\_spatial}_{i,t} = a_i + b_i \cdot \text{flood\_frac}_{i,t} + e_{i,t}$$
$$e_{i,t} = c_i + d_i \cdot t + u_{i,t}$$

with `water_slope` = *b<sub>i</sub>* and the water-adjusted trend = *d<sub>i</sub>*.

**Method nuance the document must not lose:** a two-stage estimator's *d<sub>i</sub>* equals the year coefficient of the joint model only when flood and year are orthogonal within the unit. They are not in general. The document should describe this as *"the trend in what water does not explain"* rather than as *"controlling for water"*, which implies the joint form.

There is also a guard the document does not mention (line 78): units whose flood series has near-zero variance have `trend_adj` flagged **UNRELIABLE**, because stage 1 is then fitted on no variance.

## 5 · §6.5 — Pearson or Spearman, and the exclusion rule · **PEARSON; the exclusion is four rules, not one**

`scripts/03_inundation_products/20_run_census_veg_wet_response.R:142` — a hand-implemented `pearson_r()` over the raster stack. The plot-support companion also uses Pearson (`R/gayini_ground_cover_response_functions.R:17`, `stats::cor` default at line 190).

The axis is the **binary annual wet/dry state**, which the document states correctly, and the script's header explains why: no continuous per-pixel within-year intensity exists across the full record, so the binary state is the only full-record same-year axis available.

Exclusion is not a single "too few wet years" rule. A cell yields a defined *r* only if **all** of:

| rule | value | line |
|---|---|---|
| paired veg-years | `MIN_RESPONSE_YEARS = 25` | 53, 178 |
| non-degenerate variance both series | `sxx > 0 & syy > 0` | 178 |
| at least one wet **and** one dry year | `n_wet >= 1 & n_dry >= 1` | 158 |
| finite result | `is.finite(r)` | 178 |

Never-or-always-wet cells are separately flagged `no_flood_var` (181) and cloud-thinned cells `few_years` (182). At stratum level, `MIN_RESP_COVERAGE = 0.50` — if fewer than half a stratum's cells yield a defined *r*, the verdict becomes `coverage_limited` rather than a response.

**Undocumented entirely:** two seasonal reductions are computed — **A** (mean of available seasons, the base series) and **B** (JJA/SON, a cross-check), with B reported only where estimable and A recomputed on that same cell set for a like-for-like comparison. The document describes one series.

## 6 · §6.5 — the 0.20 threshold · **A REPORTING CONVENTION, AND THE RULE IS LARGER THAN THE DOCUMENT SAYS**

`R_RESPOND <- 0.20` carries the comment *"our default (flagged, Adrian Q3 family)"* (`20_run_census_veg_wet_response.R:54`; mirrored at `21_build_s26_response_matrix_figure.R:57` and `R/gayini_ground_cover_response_functions.R:61`). It is a chosen default, explicitly flagged for Adrian, **not derived**. The document's suspicion is correct.

But "responds" is **not** the 0.20 threshold alone. Line 218:

```
if (median_r >= R_RESPOND && sign_frac >= SIGN_FRAC) return("responds")
```

— a two-part rule, median *r* **and** sign-consistency. The plot-support variant adds a third condition; its own figure subtitle states *"median r >= 0.20, >= 70% sign-consistent, bootstrap CI excludes 0"*.

**This is a method described more simply than it is implemented.** A reader reproducing §6.5 as written would classify strata on the median alone and would get a different answer. Carried forward to Gate C.

## 7 · §6.6 — GAM specification and the sparse-tail rule · **ANSWERED; the sparse-tail rule is misdescribed**

**GAM** — `R/gayini_veg_water_census_panels.R:51-52`:

```
k_use <- min(10L, nuf - 1L)
g <- mgcv::gam(y ~ s(flood_freq_pct, k = k_use), data = s, method = "REML")
```

| element | value |
|---|---|
| basis | mgcv default — thin-plate regression spline (`bs = "tp"`); not set explicitly |
| basis dimension | `k = min(10, n_unique_flood_values − 1)` |
| smoothing selection | **REML** |
| weighting | **none** — no `weights=` argument anywhere |

**Sparse tail — 500 is right, the described behaviour is not.** Figure 6's producer is `scripts/03_inundation_products/28_build_veg_water_percentile_fan.R`, where `MIN_BIN_N <- 500L` (line 37). But line 108 is:

```
keep = cumprod(as.integer(n >= MIN_BIN_N)) == 1L
```

That is **cumulative truncation from the first failing bin outward**, not per-bin exclusion. One sparse bin in the middle of the range would discard every bin beyond it, including well-populated ones. The document says *"bins containing fewer than 500 cells are dropped"*, which describes a different and more permissive rule.

**A second threshold exists.** `scripts/03_inundation_products/24_build_figA_floor_gradient_density.R:40` uses `MIN_BIN_N <- 2000L` on 5-pp bins for a different GAM figure. The document states one sparse-tail rule; the codebase has two.

## 8 · §12.3 — next-steps priorities not agreed · **ACKNOWLEDGED, NOT VERIFIED**

Per the design-seat ruling, this flag is a statement about the document's own status rather than a checkable claim. Recorded as acknowledged. No verification attempted and none is possible: whether a priority ordering has been agreed is not a property of the code or the database.

## 9 · References — four unresolved sources · **UNVERIFIABLE from this repository**

The repository holds no bibliography. `dim_source_product` carries one-line method summaries and no citations for either headline product, so the Landsat fractional-cover algorithm citation and the water-observation product citation cannot be supplied from here either.

The Dawson et al. (2016) distance-to-reference paper — named in the spec as the design template for §6.1 and the one that matters most — appears **nowhere in the repository**: not in the reference list, not in any script comment, not in any doc. §6.1's method is a plain bivariate OLS with no code comment attributing it to a source.

All six citations require external sourcing.

---

## Cross-flag observations

**Two flags close only with new work, not new text.** Flag 3 needs the diagnostics computed; flags 1 and 9 need provider metadata and a bibliography. The other five are text corrections against code that already exists.

**Three method-versus-implementation gaps found while answering, all carried to Gate C:** the "responds" rule (flag 6), the sparse-tail rule (flag 7), and the two-stage estimator's meaning (flag 4). Each is a case where the document is simpler than the code and a reader reproducing the description would not reproduce the result.

**One thing the document asserts without a flag, now confirmed.** §7.1's trend test is implemented as described — `R/gayini_trend_test_functions.R`, Mann–Kendall primary (tau-b, tie-corrected, base R), Theil–Sen slope with CI, drop-two-largest-flood-years sensitivity, LOESS monotonicity check, OLS drawn for contrast only. **The document omits the significance level: `MK_P_ALPHA = 0.10`, not the conventional 0.05**, with `TS_CI_CONF = 0.90` set as its complement. With reported p-values of 0.24 to 1.00 no verdict turns on it, but an unstated non-standard alpha is exactly the kind of thing a reviewer asks about. The 9/0/0 verdict and the τ and p ranges are value claims and belong to Gate B.
