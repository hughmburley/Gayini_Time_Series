# DIAG-1 — regression diagnostics and the assumptions record

**As of 7 August 2026.** Built to `docs/reference_update/Gayini_CC_spec_DIAG1_v2.md`.
Estimation in R under Ruling AS; run to completion without gates under Ruling AX.

**This document registers nothing, proposes nothing, refits nothing into production and
changes no published number.** Where it argues for a different specification, the
argument is recorded as an argument and stops there.

**Registered values quoted below carry their `number_id` and this document's as-of
date.** Everything else is a diagnostic computed here and is not registered:
`cap_residual_sd_water_quartile_1` · `_2` · `_3` · `_4` are the only registered numbers
this document quotes.

---

## 1 · What was fitted, and does it reproduce

**Yes — exactly, to better than 5×10⁻⁶ on every coefficient, and the residuals that
shipped are the residuals the refit produces.**

The fit being diagnosed is: each part's across-year mean cover floor
(`veg_p05_spatial`) against its across-year mean wetness (`flood_frac_pct` — the share
of the part's cells seen wet, within each year, averaged over years), 115 parts,
pixel-weighted by cell count, clustered on the paddock, in each of three periods.

| fit | expected | refitted in R | |
|---|---|---|---|
| `S2_whole_full115` slope | 0.547274 | 0.547274 | agrees |
| `S2_whole_full115` intercept | 52.697196 | 52.697196 | agrees |
| `S2_whole_record_common_unweighted` slope | 0.521378 | 0.521378 | agrees |
| `S2_whole_record_common_unweighted` intercept | 53.956357 | 53.956357 | agrees |
| `S2_cropping_era_common` slope | 0.592241 | 0.592241 | agrees |
| `S2_post_management_common` slope | 0.324225 | 0.324225 | agrees |

The coefficients agreeing is not the same as the *residuals* agreeing — a residual could
have been written from a different fit than the one whose coefficients were stored. So
the shipped `*__residual` columns were checked directly against the refit: the largest
disagreement across all three periods is **9.2×10⁻¹⁴ pp**, which is floating-point
noise. The maps print the residuals this refit produces.

**Of 54 quantities checked across all stages, 54 agree.** The full ledger is in
`DIAG1_reproduction_checks_stageA.csv`, `_stageC.csv` and `_stageE.csv`, each row
carrying its target, what was obtained, the tolerance and the spec section.

### The check was shown able to fail

A check that has never failed has not been tested; it has only been run. And under
Ruling J, a check that *errors* is not a check that *catches* — the fixture has to move
a **value**, not break a code path.

One weight was doubled in a scratch copy — `n_pixels_part` on the Bala 29ca / Aeolian
part, 11,848 → 23,696. **No y or x value was altered.** The slope moved
0.547274 → **0.587506**, which is **8,046 times the tolerance**, and the assertion
rejected it and stopped the run. The verbatim failure is in `DIAG1_fixture_2_1.txt`.

---

## 2 · Heteroscedasticity — the assumption that is plainly violated, and what it costs

**Residual spread runs from 12.81 pp on the driest quarter of the country to 3.83 pp on
the wettest — the wettest quarter carries 30% of the driest quarter's scatter. A common
colour scale therefore overstates dry parts and understates wet ones, and pack v1.4's
single-page maps print raw percentage points per part.**

The four values reproduce the registered ones exactly: **12.811 · 8.486 · 6.334 ·
3.833 pp** — `cap_residual_sd_water_quartile_1` through `cap_residual_sd_water_quartile_4`
(`dim_headline_number`), as of 7 August 2026. corr(|residual|, wetness) = **−0.506**.

**A note on those four registered numbers.** Their registered `spread_min` values
(12.59 · 8.34 · 6.22 · 3.77) are exactly the **population** SD of the same four groups,
where the pinned values are the **sample** SD. The registered spread on those numbers is
the n versus n−1 divisor and nothing else. Recording it here so it is not rediscovered
later as a discrepancy.

The pattern holds in every period, and is not an artefact of the whole record:

| period | Q1 (driest) | Q2 | Q3 | Q4 (wettest) |
|---|---:|---:|---:|---:|
| whole record | 12.81 | 8.49 | 6.33 | 3.83 |
| cropping era | 13.30 | 8.99 | 6.59 | 4.12 |
| post-management | 11.32 | 10.02 | 8.08 | 6.19 |

**Within a community it does not hold, and that is informative.** Inland runs
4.52 / 6.44 / 3.50 / 3.66 and Riverine 14.00 / 7.93 / 8.80 / 7.62 — neither is
monotone. The clean gradient in the pooled table is substantially *between* communities
occupying different stretches of the water axis, not a within-community property of
wetter ground. Same reading as §4 below, arrived at independently.

### What this changes: `residual_z_local`

`DIAG1_local_z.csv` carries `whole_record__residual_z_local` — each part's residual
divided by the SD of residuals in its own wetness quartile — joinable on `part_id`.

**It is an additional column in a new table. It replaces no published residual, and the
shipped GeoPackage and CSV were not edited.**

It matters because it reorders the map. **35 of 115 parts move 10 or more places**
between the pooled and local rankings; the extremes move +28 and −24. Mara 6 / Inland
goes from rank 85 to 113 of 115 and Dinan 2 / Inland from 87 to 114 — both are wet parts
whose modest raw shortfall is large *for how wet they are*. Neither would draw a
reader's eye on a map scaled in raw percentage points.

---

## 3 · Influence — and the Bala 29ca asymmetry, stated against the project

**Bala 29ca is the most influential unit on the line against which Bala 29ca is then
judged.**

Dropping each of the 64 paddocks in turn moves the whole-record slope across
**0.4692 to 0.5867** against 0.547274. Bala 29ca alone accounts for **−0.0781** — about
**2.2 times** the next largest mover (Dinan 8, −0.0348). The same one-paddock dominance
appears in both other periods (`DIAG1_influence.csv`).

Leave-one-out residuals were computed by deleting the **whole paddock**, not the single
part. Deleting one part leaves its two siblings still pulling the line, which understates
how much the fit borrowed from them; deleting the paddock is the honest test. For Bala
29ca:

| | in-sample | with its paddock removed |
|---|---:|---:|
| Aeolian | −24.85 | **−27.29** |
| Riverine | −21.58 | **−23.74** |
| Inland | +5.87 | **+4.45** |

**The direction of that correction is the point.** In-sample residuals for
high-leverage units are shrunk toward zero because the unit helped place the line it is
measured against. Here removing that pull makes both Bala 29ca shortfalls **larger**, so
**the published figures are the conservative ones** — the reference-state shortfall is
understated by roughly 2 pp, not overstated. This is said here rather than left for a
reader to find. It holds broadly: **95 of 115 parts** have a larger absolute residual
once their own paddock is removed.

Highest leverage is Bala 26ca / Inland at h = 0.130, which is a large, wet part rather
than an unusual one.

---

## 4 · Functional form — who versus by how much

**Who is below expectation is robust to functional form; by how much is sensitive to
roughly ±3 pp at the dry end. Both halves travel together or neither does.**

On leave-one-paddock-out predictive error — not in-sample R², which always rewards the
more flexible form — the five candidates rank **√x 8.481 · quadratic 8.553 · linear
8.572 · log(x+1) 8.701 · cubic 8.805 pp**. The entire spread across all five is 0.32 pp
against a residual SD of 8.08 pp, so no form is meaningfully better than the linear one
that shipped. The Spearman correlation between residual rankings under linear and √x is
**0.984**, and the three worst-off parts are identical and in the same order
(`62_riverine`, `04_aeolian`, `04_riverine`). Magnitudes move: Bala 29ca's Aeolian
shortfall reads −24.85 under linear, −21.66 under quadratic and −21.53 under √x — a
3.3 pp spread that is entirely a dry-end effect, since its Inland part spans only 1.1 pp
across the same three forms.

**The pooled curvature is mostly three communities at three levels.** Aeolian spans
1.0–19.7% wet, Riverine 3.0–33.3, Inland 5.9–58.9. Inland alone spans the range and its
quadratic term is **−0.0028** with ΔR² of just **+0.006** — effectively straight across
the whole axis. Aeolian's is **+0.306** on 17 points over a 19-point-wide span, which is
a curve fitted to a corner. The pooled quadratic term (−0.0096, ΔR² +0.026) sits between
them. The bootstrap figure supports this independently: Aeolian's observed between-unit
slope is **−0.3085** against a bootstrap median of −0.625, so its point estimate sits
well off the centre of its own distribution, where the pooled and Inland medians sit
within 0.004 of theirs (carried from `FIG2_bootstrap_slope_distributions.png` and its
producer `scripts/12_zone_stratum/FIG2_bootstrap_distribution.py`; not recomputed here,
because a different RNG stream would not reproduce the same draws).

**This is a reading to check, not a conclusion**, and nothing downstream is changed on
the strength of it.

---

## 5 · The annual series

**Most of Stage C was already built by WITHIN-1 and reproduced 17 of 17 there. Those
values are carried, not re-derived** (`DIAG1_carried_from_WITHIN1.csv`): residual lag-1
autocorrelation +0.364 → effective n ≈ 16 of 35 years; floor autocorrelates at +0.477
against wetness at +0.172; within-part medians by community +0.3505 / +0.2177 / +0.1402.

### The distributed lag (§4.1)

Fitted properly as the specification that **replaces** the AR(1) error model rather than
sitting beside it. Ruling AT established that the persistence is a lagged ecological
response, not error correlation; AR(1) *absorbs* it into the error term, where the
distributed lag *puts it in the specification* and lets it be read.

Pooled, within-unit, pixel-weighted: same-year **+0.1379**, one year back **+0.1178**,
**long-run sum +0.2557**. By community the response is far larger and shorter-lived in
Aeolian (+0.4141 / +0.1534) than Inland (+0.1306 / +0.1157). **Not registered.**

### Two years back (§4.3) — the response stops at one year

Adding lag 2 pooled gives **+0.1316 / +0.1164 / +0.0227**: the two-year term is 20% of
the one-year term and 17% of the same-year term. By community it changes sign —
Aeolian **−0.1328**, Riverine −0.0326, Inland +0.0281 — which is not a two-year memory
but the fit trading off against strongly correlated neighbouring years. **The usable
response is same-year plus one year back.**

### Is the across-year mean a fair summary? (§4.2)

**The mean is a fair summary of the floor. It is not a fair summary of the water — and
the water axis is the one that carries the slope.**

Each part's 35 annual floor values are left-skewed (median g₁ = −0.78; 105 of 115
parts below zero): dry years pull the mean below the median, by a median of 1.29 pp
and up to 4.60 pp (Mara 18 / Inland). Eleven parts diverge by more than 3 pp.

Replacing both axes with medians moves the slope 0.5473 → 0.3449, which looks alarming
until it is decomposed — swapping both axes at once conflates two changes:

| | slope | vs published |
|---|---:|---:|
| both axes on means (published) | 0.5473 | — |
| **median** floor, mean water | 0.5851 | +0.0378 |
| mean floor, **median** water | 0.3275 | **−0.2198** |
| both axes on medians | 0.3449 | −0.2024 |

**Almost all of the movement is on the water axis, not the cover axis.** Wetness is
strongly right-skewed (median g₁ = +1.34) because big flood years are rare and large, so
its mean and median are genuinely different quantities. The floor summary is nearly
irrelevant to the slope (+0.04) and its residual rankings are essentially unchanged
(Spearman 0.984). Substituting median wetness would change the estimand, not correct it,
and **no change is proposed.** But a reader who assumes "mean wetness" and "typical
wetness" are interchangeable will misread the axis, and the axis label should keep saying
*mean over years*.

---

## 6 · Stage E — the within-unit fits, diagnosed for the first time

**These fits are the project's central result — 115 of 115 positive, replicating 91 of
91 out of sample — and until now they had no diagnostics at all. They survive the
treatment §2 gives the between-unit fit, and on the two counts where the between fit is
weakest they are markedly stronger.**

### They barely depend on any one paddock

Dropping each of the 64 paddocks in turn moves the pooled within slope across
**0.1576 to 0.1643** against 0.161271 — a total span of **4.2%** of the slope, from
−2.3% to +1.9%. The same operation on the between-unit slope spans **21.5%**, from
−14.3% to +7.2%.

**Bala 29ca moves the within slope by −0.0013, or −0.8%.** It is not among the five
largest movers. The paddock that dominates the between-unit fit, and whose confound is
the project's most-qualified result, is close to irrelevant to the within-unit one.
**The central result does not rest on Bala 29ca.**

### The within response saturates — the question the between fit could not answer

The between-unit comparison could not separate curvature from three communities sitting
at three levels on three stretches of the axis. Within units, the water axis actually
moves, and the answer is clean. On leave-one-cluster-out predictive error:

| form | 115 parts | 93 unzoned patches |
|---|---:|---:|
| linear | 10.784 | 13.847 |
| quadratic | 10.552 | 13.417 |
| √x | 10.464 | 13.445 |
| **log(x+1)** | **10.336** | **13.269** |
| cubic | 10.470 | 13.261 |

**A concave form beats linear on both sets, and it replicates across two independently
constructed unit definitions.** The improvement is 4.2% of CV error on the parts against
1.1% for the best form on the between-unit fit — where the concave forms also won, so
the same shape appears at both grains. Within-unit R² rises 0.174 → 0.241 on the parts
and 0.116 → 0.188 on the patches. On the patches, cubic edges log(x+1) by 0.008 pp,
which is noise; log(x+1) is the more defensible of the two and both say the same thing.

**No refit is proposed.** The published within slope stands. What this establishes is
that the response *does* flatten at high wetness, which the between-unit fit could not
show, and that a linear within slope is an average over a curve rather than a constant.

### Heteroscedasticity, and it is a different pattern

Within residual SD by demeaned-water quartile is **10.82 / 12.11 / 12.12 / 8.09** on the
parts and 10.37 / 11.87 / 12.38 / 9.00 on the patches — humped, not the monotone decline
of the between-unit fit. Spread is smallest in the unit's own driest and wettest years
and largest in the middle. This is not the same phenomenon as §2 and should not be
described with the same sentence.

By community the within slope runs Aeolian +0.4209, Riverine +0.2100, Inland +0.1544
(parts) and Aeolian +0.1483, Riverine +0.2909, Inland +0.2005 (patches). **The
community ordering does not replicate across the two unit definitions**, though the sign
does, everywhere.

### The serial-correlation statement — checked, and it needs qualifying

**Spec §5 asks this document to state plainly that the within intervals ignore serial
correlation and are therefore too narrow. Checked rather than asserted, that is not true
of the published interval, and it is recorded here as a disagreement with the spec
rather than quietly followed or quietly dropped.**

Three resampling schemes, same estimator, same data, 2,000 draws each:

| what is resampled | 95% interval | width |
|---|---|---:|
| rows, independently (panel structure destroyed) | [0.1489, 0.1736] | 0.0247 |
| whole parts | [0.1439, 0.1810] | 0.0371 |
| **whole paddocks — the published scheme** | **[0.1432, 0.1811]** | **0.0379** |

The published paddock-clustered interval is **54% wider** than one that ignores serial
dependence. Resampling a whole paddock keeps each part's entire 35-year series intact,
so the block bootstrap already absorbs arbitrary within-unit dependence, serial
correlation included. The spec's concern is real but applies to a different family:
the AR(1) GLS fit reports [0.1020, 0.1220] around a different point estimate (0.1120),
and *that* interval is narrow.

**The honest statement is the narrower one:** the published within intervals carry
sampling variation clustered on the paddock, and they do not carry the ingested
products' own classification and calibration error (Ruling AW) — which is a real
omission, and a larger one than serial correlation.

### The unzoned patches (§6)

`DIAG1_unzoned_between_not_applicable.csv` records this formally. **The between-unit
half is not applicable**: UNZONED amendment A1 ran and A2 did not, so there is no
unzoned between-unit fit and no unzoned residual — no fitted line to diagnose, no
leverage to compute, no residual to standardise. That is an absent input, not a skipped
diagnostic.

Stage E's within diagnostics cover all 3,253 patch-years, clustered on `patch_id`.
**These units are not nested in management zones and no paddock cluster was substituted
for the one that does not exist.** Every row of every patch output says so in a
`cluster_note` column.

---

## 7 · Stage B — closed, and not re-run

FIG-2 §5 recovered the bootstrap draws and reproduced the registered 2.5th, 50th and
97.5th percentiles exactly for `2.3_weighted`, `2.6_aeolian`, `2.6_riverine` and
`2.6_inland`, to better than 5×10⁻⁷, asserted before plotting. The 10,000-draw
comparison had already moved the headline interval from [+0.360, +0.750] to
[+0.358, +0.749]. **Nothing remained to check and nothing was re-run.** See
`FIG2_bootstrap_slope_distributions.png` and
`scripts/12_zone_stratum/FIG2_bootstrap_distribution.py`.

---

## 8 · What remains undiagnosed

Stated so the next reader does not have to infer it from what is absent.

1. **Measurement error in either axis.** Both are modelled satellite products with
   published validation error that nothing in this project propagates. Every interval
   emitted here carries `interval_conditionality` saying so (Ruling AW). This is the
   largest unquantified term in the whole analysis and it is larger than anything in
   this document.
2. **Spatial autocorrelation between parts.** Clustering is on the paddock; two
   *adjacent* paddocks are treated as independent. Nothing here tests that, and the
   effective number of independent units is certainly below 64.
3. **Normality.** Not diagnosed, by instruction, and nothing rests on it — no p-value
   or parametric interval is emitted anywhere in DIAG-1.
4. **The unit definition itself.** L-01 stands: 14 of 64 paddocks fall below 75%
   single-community dominance. Splitting by community addresses it, but the *part* is
   still a fence-and-community intersection, not an ecological unit.
5. **Why the community ordering of within slopes does not replicate** between the
   zoned parts and the unzoned patches. Both sets say every unit responds positively;
   they disagree on which community responds most.
6. **Whether the saturation in §6 is ecological or an artefact of the floor metric.**
   `veg_p05_spatial` is bounded above, so a concave response is what a bounded variable
   does near its ceiling. Distinguishing the two needs an unbounded response variable,
   which this project does not have.
7. **The three periods are diagnosed separately and never compared.** The comparison
   rule is unchanged: relationships only, never levels.

---

## 9 · Outputs

All under `Output/diag/`. Every table carries its support level, unit, period, weighting
and **estimand** as columns — `DIAG1_manifest.py` fails the run if one does not, and it
caught `DIAG1_within_pointwise.csv` missing all five on the first pass.

| file | what |
|---|---|
| `DIAG1_diagnostics.md` | this document |
| `DIAG1_local_z.csv` | locally standardised residuals, joinable on `part_id` (§2.3) |
| `DIAG1_influence.csv` | drop-one-paddock slopes, cluster-deleted residuals, leverage |
| `DIAG1_form_comparison.csv` | every form, pooled and per community, CV error, per-part residuals |
| `DIAG1_within_diagnostics.csv` | Stage E, both sets |
| `DIAG1_lag_fits.csv` | the distributed lag, lags 0–2, pooled and by community |
| `DIAG1_heteroscedasticity.csv` | quartile SDs by period and within community |
| `DIAG1_between_pointwise.csv` | 345 rows: fitted, residual, leverage, both deletion rules |
| `DIAG1_within_pointwise.csv` | 7,278 rows: both within sets |
| `DIAG1_part_series_summary.csv` | §4.2 skew and mean-versus-median, per part |
| `DIAG1_mean_vs_median_summary.csv` | the four-way decomposition in §5 |
| `DIAG1_carried_from_WITHIN1.csv` | values read from WITHIN-1, not recomputed |
| `DIAG1_unzoned_between_not_applicable.csv` | the §6 absence, recorded |
| `DIAG1_reproduction_checks_stage{A,C,E}.csv` | 54 checks, each with target and tolerance |
| `DIAG1_fixture_2_1.txt` | the fixture that made the §2.1 check fail |
| `DIAG1_inputs.csv` | every input and boundary file with its first-50-MB SHA-256 |
| `DIAG1_manifest.csv` | 30 files, sizes, checksums, §7 column audit |
| `figures/` | 10 panels |

**Producers.** `scripts/14_diag/DIAG1_prepare.py` (boundary CSVs; no estimation) →
`R/diag/DIAG1_stageA.R`, `DIAG1_stageC.R`, `DIAG1_stageE.R` (all estimation, sharing
`R/diag/DIAG1_common.R` and `R/gayini_fit.R`) → `scripts/14_diag/DIAG1_figures.py`
(drawing only) → `scripts/14_diag/DIAG1_manifest.py`.

`summary()` is never called on a model object anywhere in the R. **No p-value is emitted
and no significance test of any assumption was run** — no Breusch–Pagan, no RESET, no
Shapiro–Wilk. Assumptions are reported as effect sizes and pictures.

The database was opened read-only (`mode=ro`, `PRAGMA query_only=1`) for the four
registered quartile SDs and nothing else. `Output/pack/**` was not written.
