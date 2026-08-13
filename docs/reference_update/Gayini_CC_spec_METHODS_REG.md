# CC spec METHODS-REG — the regression appendix

**Design seat · 7 August 2026.** Queued on the methods seat behind pack v1.3 and the inundation
metadata record.

**What this is.** A detailed appendix documenting every regression the project has run, written to
the same shape as the data-source provenance records so the three read as a set. Script paths,
parameters, registration status, diagnostics, decisions, and what has not been checked.

**What it is for.** The main methods document carries a high-level account. This appendix is what
that account points at. **A reviewer who asks "how exactly was that fitted, and what was checked"
should be able to answer the question from this document without reading code.**

**What it is not.** Not an analysis. **No fit is re-run, no number changes, nothing is registered.**
Every value is read from an existing table and cited to it.

**Methods document is sealed at V13.** This appendix is written now and folded into V14 after
10 August. Say so in the header; do not edit V13.

---

## 0 · Standing conditions

Read-only. `mode=ro`, `PRAGMA query_only=1`. Recon first.

Output `Output/metadata/Gayini_methods_appendix_regression.md`. Same conventions as the ground-cover
record: SEED-shaped section order where it fits, NA fields omitted, tables for parallel facts, short
paragraphs elsewhere.

**Every quantity cites a `fit_id`, a `number_id`, or the table and column it was read from.** A value
with no source does not appear.

---

## 1 · The two estimands — this section comes first and everything else refers back to it

**The project fits two families of regression that answer different questions, and the largest
misreading available in this work is to treat one as a version of the other.**

| | between-unit | within-unit |
|---|---|---|
| **question** | do wetter *places* carry higher cover floors? | does a given place carry a higher floor in wetter *years*? |
| **unit of observation** | one unit, its across-year means | one unit-year |
| **n** | 64 paddocks, or 115 parts | 4,025 part-years |
| **variation used** | differences between places | movement within a place over time |
| **whole-record slope** | **+0.5473** (`2.3_weighted`) | **+0.1613** (WITHIN-1, unregistered) |

**The ratio is 3.39.** The between-unit slope bundles soil, landscape position, community and
management history with water, because places that flood more differ from places that flood less in
more ways than their water. The within-unit slope holds all of that fixed by construction.

**Neither corrects the other.** The registered expectation line is a between-unit quantity and is
correct as such. **What it is not is a response coefficient**, and it will be read as one unless the
distinction is stated wherever a slope appears.

**Write this section so it can be lifted whole.** It is the part the main methods document most needs
and the part most likely to be paraphrased into error.

---

## 2 · Inventory — every fit, and whether it is registered

One table. Columns: `fit_id` or label · estimand family · unit · period · community scope ·
weighting · slope · interval · **registration status** · source table.

**Registration status is not decoration.** The R-side fits carry
`interval_status = "R-side stability check - NOT registered"` and must carry it here too. **A number
that appears in a methods appendix without its status has been laundered into a result.**

Cover at minimum:

- paddock-grain registered line — `floor_flood_slope_64pdk`
- part-grain pooled — `2.3_weighted`, `2.3_unweighted`
- central-tendency check — `2.4_median_weighted`, **with its numeral-collision note carried verbatim**
- percentile sweep — `2.5_p05` … `2.5_p50`
- community fits — `2.6_aeolian`, `2.6_riverine`, `2.6_inland`
- period fits — `S2_cropping_era_common`, `S2_post_management_common`, `S2_whole_full115`,
  `S2_whole_record_common_unweighted`
- within-unit — WITHIN-1 pooled, gls AR(1), between-part reproduction
- unzoned — UNZONED Stage A1 pooled at 2,000 and 10,000 draws, gls AR(1), three community fits

---

## 3 · Specification

**Model form.** Weighted least squares, one predictor, no transformation of either axis. State the
equation and both variables by their project names, `veg_p05_spatial` and `flood_frac_pct`.

**Aggregation order, stated exactly as the coefficient table does:** *OLS across parts of across-year
means of within-year across-cell quantities.* That sentence is the whole construction and is worth
its own line.

**Weighting.** Pixel count of the unit. Give the unweighted slope alongside — +0.521 against +0.547
at part grain — so the reader can see the weighting is not carrying the result.

**The within specification.** Unit fixed effects, implemented by demeaning both axes within unit.
State that this is algebraically the fixed-effects estimator and that no intercept is reported,
because each unit has its own.

**Support rules.** Part grain: at least 25 water years of at least 30 valid cells; 115 of 118 parts
qualify; the three that do not are named with their cell counts. Paddock grain:
`max(500, ceil(0.30 × zone_nontreed_px))`.

---

## 4 · Uncertainty

**Clustered bootstrap, percentile method.** Resample **paddocks** with replacement — `zone_fid` — not
parts. 2,000 draws for the registered fits; 10,000 as a stability check. Report the seed.

**State the cluster count.** 64 paddocks. **The number of clusters, not the number of draws, is what
bounds the precision**, and going from 2,000 to 10,000 moved the headline interval from
[+0.360, +0.750] to [+0.358, +0.749].

**The unzoned fits cluster on the patch**, because there is no paddock on that ground. **This is a
difference in variance structure, not a substitution**, and it is stated on every unzoned output.

**Why no p-values.** Write this properly, it is a methods-document question:

- 115 parts sit in 64 paddocks, so the nominal degrees of freedom are wrong in the cross-section
- residual lag-1 autocorrelation on the annual series has a median of **+0.364**, giving an effective
  n of about **16 of 35 years** — so they are wrong in time as well
- both corrections are large and neither is a small adjustment to a nominal statistic
- intervals from a clustered bootstrap are reported instead, and a test statistic on these units
  would be a p-value wearing a disguise

**Spread is never uncertainty.** The `*_spread_*` columns describe year-to-year movement. No interval
is placed on them. On 35 consecutive values a 2.5–97.5 range is the minimum and maximum under a false
label.

---

## 5 · Estimation lineage — as chunks

Same format as the ground-cover record: what it does · script · inputs · parameters · outputs with
counts · **the check that passed, and what would have made it fail.**

One chunk per stage: the T2 Gate B extraction that produced both grains; the part-grain pooled fit
and percentile sweep; the period fits and the common-set restriction; the residual computation and
its export; the within-unit fits; the R-side reproduction.

**The reproduction chunk carries the WITHIN-1 result in full.** Seventeen of seventeen design-seat
figures reproduced in R, including the four that had to agree first. **And it carries the failure and
its resolution**: the first run halted on three autocorrelation figures, and the cause was a
definition rather than a data difference — the pairwise sample correlation against R's `acf()`
1/n autocovariance form, which is biased toward zero on 35 points. Both estimators are now permanent
columns. **A halt that turned out to be a definitional ambiguity is exactly the kind of thing a
methods appendix should record, not tidy away.**

---

## 6 · Diagnostics — what was checked, and what it showed

**Report each as an effect size, not a test.** No Breusch–Pagan, no RESET, no normality test.

| check | result | source |
|---|---|---|
| **heteroscedasticity** | residual SD runs 12.81 → 8.49 → 6.33 → 3.83 pp across water quartiles; the wettest quarter carries 30% of the driest quarter's scatter | registered, `cap_residual_sd_water_quartile_1` … `_4` |
| **influence, at the cluster** | drop-one-paddock over all 64 gives a slope range of 0.4692 to 0.5867; Bala 29ca alone moves it −0.0781, about twice the next paddock | design-seat, unregistered |
| **functional form** | leave-one-paddock-out CV weighted RMSE: √x 8.481 · quadratic 8.553 · linear 8.572 · log 8.701 · cubic 8.805 | design-seat, unregistered |
| **curvature by community** | pooled quadratic lifts weighted R² 0.4725 → 0.4981; within Inland, which alone spans x from 5.9 to 58.9, the quadratic buys 0.006 | design-seat, unregistered |
| **rank robustness to form** | Spearman 0.984 between linear and √x residual rankings; worst three identical and in the same order | design-seat, unregistered |
| **magnitude sensitivity to form** | Bala 29ca whole-record residual: −24.85 linear, −21.66 quadratic, −21.53 √x | design-seat, unregistered |
| **serial correlation** | residual lag-1 median +0.364; the floor series autocorrelates at +0.477 against wetness at +0.172 | design-seat, unregistered |
| **out-of-sample** | 91 of 91 unzoned patches positive, on ground that entered no fit; 115 of 115 real parts positive | UNZONED Stage A1 |

**Two conclusions the diagnostics support and the appendix should state:**

**Pooled curvature and pooled steepness are the same artefact.** Three communities at different
levels occupying different stretches of the water axis force a single line both to steepen and to
bend. Inland alone is effectively linear across the full range.

**Who is below expectation is robust to functional form; by how much is not**, to roughly ±3 pp at
the dry end. Both halves appear together or neither does.

---

## 7 · Decisions register

Same two-part shape as the ground-cover record: ruled decisions with their citation, then
**unexamined defaults listed as habits because nothing cites them.**

Decisions to cover: p05 as the shipping metric, closed on the monotonic sweep rather than on
preference · pixel weighting · clustering on paddock not part · residuals against each period's own
line · the 2014–2017 transition exclusion · the common-set restriction, which drops none · no line
fitted to the eight conserved parts · the pooled line retained despite the community misspecification,
logged not corrected under the 6 August ruling.

**Record Ruling AT in full.** The gls AR(1) fits are retained and are not the headline within
estimate. The persistence in the cover series is a lagged ecological response, not error correlation:
the floor autocorrelates at +0.477 while wetness autocorrelates at +0.172, and a distributed lag puts
previous-year water at +0.1178 against same-year +0.1379. An AR(1) error model absorbs that response
and attenuates the same-year coefficient — +0.1613 to +0.1120 on the real parts, and the same
movement replicates at 31.8% on the unzoned patches. **Where serial correlation is modelled the
specification is a distributed lag, not AR(1) in the errors.** The lag estimates are not registered.

---

## 8 · Limitations, and §9 · Collisions

**Limitations.** The between-unit fit cannot identify a response. The pooled line is misspecified
across communities and a residual partly measures which community a part sits in. Chenopod community
slopes span zero because their wetness ranges are too narrow. Post-management rests on five water
years. Cover is not condition. No cause is attributed anywhere and none can be while the land-use
history is outstanding.

**Collisions.** `veg_p05_spatial` against census `veg_p05`. Part-grain against paddock-grain slopes —
same construction, different unit, not a refinement. Between-unit against within-unit slopes.
`2.4_median_weighted` against `2.5_p50`, which agree to four decimals by coincidence and whose
intercepts differ by 7.93 pp. **Cite the `fit_id`, never the value.**

---

## 9 · What has not been checked

**The section a reviewer will turn to first, so write it without defensiveness.**

DIAG-1 is specified and parked: the standard residual panels, leverage plots, and the local-spread
standardisation are not built. UNZONED Stage A2 has not run, so no residual has been computed on
unzoned ground. The distributed-lag specification under Ruling AT is not implemented. Within-part
fits ignore serial correlation, so their intervals are too narrow. `quantile(type = 7)` has never
been compared against another definition, and the choice is consequential at the small unit sizes the
unzoned work uses.

---

## 10 · The précis for the main methods document

**A second, separate output**: `Output/metadata/METHODS_REG_precis.md`, **500 words or under**, for
folding into V14.

It must carry: the two estimands and why they differ · the construction in one sentence · weighting
and clustering · why no p-values · that p05 was chosen on measured behaviour · the community
misspecification · and one line on what is not yet checked.

**It must not carry** a diagnostic table, a script path, or any unregistered figure. Those live in
the appendix. **Every claim in the précis points at a section of the appendix by number.**

---

## 11 · Gate

**One STOP after §1 and §2** — the two estimands and the inventory. If those two are right the rest
follows; if the estimand framing is wrong the whole document is wrong and it is cheaper to find out
at section two.

Everything after runs to completion and reports once.
