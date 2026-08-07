# CC spec DIAG-1 v2 — regression diagnostics and the assumptions record

**Design seat · 7 August 2026.** Supersedes `Gayini_CC_spec_DIAG1.md` (v1, 6 August).
**Runs first; METHODS-REG v2 runs after it** and documents what this produces.

**What changed from v1**

| | change | § |
|---|---|---|
| 1 | **Estimation moves to R** under Ruling AS. v1 specified Python and predates the ruling | 0 |
| 2 | **All gates removed** under Ruling AX. Runs to completion, reports once | 0, 9 |
| 3 | **Stage B deleted.** FIG-2 recovered the draws and reproduced every registered percentile exactly | — |
| 4 | **§2.3's local-z is now required, not optional** — the single-page maps print raw pp per part | 2.3 |
| 5 | **Stage C is half-built** by WITHIN-1; what remains is the distributed lag and the skew check | 4 |
| 6 | **New Stage E: diagnose the within-unit fits**, which have had none and are now the finding | 5 |

---

## 0 · Standing conditions

**Ruling AS.** All estimation in R — every refit, every cross-validation, every form comparison.
Python retains data preparation and table assembly and writes a checksummed analysis CSV at the
boundary. `R/gayini_fit.R` is the shared function. **No `summary()` on a model object; no p-value can
print by accident.** Every row carries its estimator, its cluster, the input checksum, and
`interval_conditionality` under Ruling AW.

**Ruling AX.** No review gates. Runs to completion, reports once. **Halt conditions remain**: a
quantity that will not reproduce stops the run. **Registration remains gated** — this task registers
nothing and proposes nothing.

Read-only on the database. `mode=ro`, `PRAGMA query_only=1`. Recon first.

Outputs under `Output/diag/`. Producer `scripts/14_diag/` for preparation, `R/diag/` for fitting.
**Do not write to `report_figs.py`** — the report seat holds it. **Do not write to `Output/pack/**`**
— the deny rule holds and a task that appears to need to is a task that is wrong.

**No p-values and no significance tests of assumptions.** No Breusch–Pagan, no RESET, no
Shapiro–Wilk. Assumptions are reported as **effect sizes and pictures**. Normality is not diagnosed;
nothing rests on it.

---

## 1 · What this is for

A reviewer who asks whether the assumptions behind Figure 25 were ever checked. Adrian, who needs to
answer that in a room. The next session, which should not re-derive it.

**It is not a remodelling exercise.** It reports how the fitted relationships behave under scrutiny.
**It proposes no new model, refits nothing into production, and changes no published number.** An
argument for a different specification is recorded as an argument and stops there.

---

## 2 · Stage A — between-unit diagnostics

On the 115 across-year means in `Output/pack/PARTREG/tables/PARTREG_part_residuals.csv`, all three
periods.

### 2.1 · Reproduce before diagnosing — the halt condition

Refit weighted OLS in R and check against `PARTREG_S2_regression_coefficients.csv`:

| fit | expected |
|---|---|
| `S2_whole_full115` | slope **0.547274**, intercept **52.697196** |
| `S2_whole_record_common_unweighted` | slope **0.521378**, intercept **53.956357** |
| `S2_cropping_era_common` | slope **0.592241** |
| `S2_post_management_common` | slope **0.324225** |

**Design-seat reproduction was exact on the first two.** If yours is not, **stop and report** —
everything below would be diagnosing a different model.

**Show the check able to fail.** Perturb one weight in a scratch copy and confirm the assertion
fires.

### 2.2 · The standard four, per period, and by community

Residual against fitted · residual against the water axis · scale–location · leverage against
standardised residual with the cluster marked. Marker area ∝ cell count, colour by community, so the
panels are readable beside the figure they diagnose.

### 2.3 · Heteroscedasticity — and the column the shipped maps now need

The four quartile SDs are **registered** as `cap_residual_sd_water_quartile_1` … `_4`
(12.81 · 8.49 · 6.33 · 3.83 pp). **Cite the `number_id`s, not the values.** Reproduce them, and
repeat by period and within community. corr(|residual|, x) = −0.506.

**This is no longer a hypothetical need.** Pack v1.4 ships three single-page residual maps that
**print each part's residual in percentage points on the face**, which makes cross-map arithmetic
easy at exactly the point the caption warns against it. The wettest quarter carries 30% of the
driest quarter's scatter.

Emit `whole_record__residual_z_local` — residual divided by the local residual SD at that part's
wetness — in `Output/diag/DIAG1_local_z.csv`, joinable on `part_id`. **Additional, in a new table,
never a replacement, and the shipped GeoPackage and CSV are not edited.**

Report which parts move most between the pooled and local rankings. Design-seat: Mara 6 and Dinan 2
move from ranks 85 and 87 to 113 and 114 of 115.

### 2.4 · Influence, at the cluster that matters

**Drop-one-paddock refit, all 64.** Design-seat: range **0.4692 to 0.5867** against 0.547274; Bala
29ca alone moves it **−0.0781**, about twice the next paddock.

**Leave-one-out residuals** beside the in-sample ones for all 115. Design-seat, Bala 29ca:
Aeolian −24.85 → **−27.29**, Riverine −21.58 → **−23.74**, Inland +5.87 → **+4.45**.

**State the asymmetry plainly.** Bala 29ca is the most influential unit on the line against which
Bala 29ca is then judged. In-sample residuals for high-leverage units are shrunk toward zero; here
the correction makes the shortfall larger, so the reported figure is conservative. **Say it rather
than letting a reader find it.**

### 2.5 · Functional form, with cluster cross-validation

Linear, quadratic, √x, log(x+1), cubic. Compare on **leave-one-paddock-out predictive error**, not
in-sample R². Design-seat CV weighted RMSE: √x 8.481 · quadratic 8.553 · linear 8.572 · log 8.701 ·
cubic 8.805.

Then the same forms **within each community**, with the x range each spans:

| | n | x range | x² term | ΔR² from quadratic |
|---|---:|---|---:|---:|
| Aeolian | 17 | 1.0–19.7 | +0.306 | +0.106 |
| Riverine | 37 | 3.0–33.3 | +0.047 | +0.111 |
| **Inland** | 61 | **5.9–58.9** | **−0.0028** | **+0.006** |
| pooled | 115 | 1.0–58.9 | −0.0096 | +0.026 |

**The reading to check, not to assume:** pooled curvature and pooled steepness look like the same
artefact — three communities at different levels occupying different stretches of the water axis.
Inland alone spans the range and is effectively linear across it. **The bootstrap figure now supports
this independently**: Aeolian's observed slope is −0.309 against a bootstrap median of −0.625, so its
point estimate sits well off the centre of its own distribution while pooled and Inland medians sit
within 0.004 of theirs.

### 2.6 · The sensitivity that must reach the article

Whole-record residual for every part under linear, quadratic and √x. Design-seat, Bala 29ca:
Aeolian −24.85 / −21.66 / −21.53; Riverine −21.58 / −19.83 / −20.57; Inland +5.87 / +4.93 / +4.74.

Spearman between residual rankings by form: linear against √x **0.984**, worst three identical and
in order.

**The sentence: *who* is below expectation is robust to functional form; *by how much* is sensitive
to roughly ±3 pp at the dry end. Both halves appear together or neither does.**

---

## 3 · Stage B — deleted

**FIG-2 §5 recovered the draws and reproduced the registered 2.5th, 50th and 97.5th percentiles
exactly for `2.3_weighted`, `2.6_aeolian`, `2.6_riverine` and `2.6_inland`**, to better than 5e-7,
asserted before plotting. The 10,000-draw comparison was run earlier and moved the headline interval
from [+0.360, +0.750] to [+0.358, +0.749].

**Nothing remains to check. Do not re-run it.** Report the closure and cite
`FIG2_bootstrap_slope_distributions.png` and its producer.

---

## 4 · Stage C — the annual series, partly built

`PARTREG_part_year_floor_inund.csv`, 4,025 part-years. **WITHIN-1 already produced the
autocorrelations, the within-part slopes and the lag pair**, all reproduced 17 of 17 in R. Do not
re-derive them; read them and cite them.

**Already established, to be carried not recomputed:** residual lag-1 median **+0.364** → effective n
≈ **16 of 35 years**; floor autocorrelates at **+0.477** against wetness at **+0.172**; distributed
lag same-year **+0.1379**, previous-year **+0.1178**; within-part medians by community
+0.3505 / +0.2177 / +0.1402.

**What remains:**

**4.1 · The distributed-lag specification, under Ruling AT.** AT establishes that the persistence in
the cover series is a lagged ecological response, not error correlation, and that an AR(1) error
model absorbs it — +0.1613 → +0.1120 on the real parts, replicating at 31.8% on the unzoned patches.
**Fit the distributed lag properly as the specification that replaces AR(1)**: same-year and
one-year-lagged water, pooled and by community, with the long-run sum reported. Design-seat sum
**+0.2557**. Not registered.

**4.2 · Is the across-year mean a fair summary?** Skew of each part's 35 annual floor values, and how
far mean and median diverge. **Name the parts where they diverge materially** — the between-unit fit
uses the mean, so a part where the mean misrepresents its own series is a part whose position on
Figure 25 is misleading.

**4.3 · Two-year lag.** WITHIN-1 covered lag 1. Add lag 2, pooled and by community, and report where
the response stops.

**No management claim and no period comparison. This is an assumptions audit.**

---

## 5 · Stage E — diagnose the within-unit fits · **new, and the priority**

**Everything in v1 aimed at the between-unit fit. The within-unit fits have had no diagnostics at
all, and they are now the project's central result** — 115 of 115 positive, replicating 91 of 91 out
of sample.

Give them the treatment §2 gives the between fit:

- **Residual against fitted, and against demeaned water.** 4,025 points, so use bands or a density
  rather than raw points — the display convention applies.
- **Influence at the cluster.** Drop-one-paddock refits of the pooled within estimator, all 64.
  Report the range against +0.1613.
- **Functional form.** Does the within response saturate? **This is the question the between-unit fit
  could not answer**, and it is answerable here with the water axis actually moving.
- **Heteroscedasticity** in the within residuals, by demeaned water and by community.
- **State plainly that the within intervals ignore serial correlation** and are therefore too narrow,
  with the +0.364 median as the size of what is ignored.

**Then the same on the 3,253 unzoned patch-years**, clustering on the patch, saying so.

---

## 6 · Stage D — UNZONED

**Amended: A1 ran, A2 did not.** There is no unzoned between-unit fit and no unzoned residual, so
v1's "run Stage A over it" has nothing to run on for the between-unit half.

What exists: `UNZONED_stageA1_fits.csv`, `UNZONED_stageA1_per_patch_slopes.csv`, and 3,253
patch-years. **Stage E's within diagnostics cover them.** Report the between-unit half as not
applicable, and why.

The diagnostic code takes `(x, y, weights, cluster)` and does not care which set it is given. **Where
UNZONED has no paddock, say so on the output rather than substituting a cluster.**

---

## 7 · Outputs

| | |
|---|---|
| `Output/diag/DIAG1_diagnostics.md` | **the deliverable** — see §8 |
| `Output/diag/DIAG1_local_z.csv` | locally standardised residuals, joinable on `part_id` |
| `Output/diag/DIAG1_influence.csv` | drop-one-paddock slopes, leave-one-out residuals, leverage — between and within |
| `Output/diag/DIAG1_form_comparison.csv` | every form, pooled and per community, CV error, per-part residuals |
| `Output/diag/DIAG1_within_diagnostics.csv` | Stage E, both sets |
| `Output/diag/DIAG1_lag_fits.csv` | Stage C's distributed lag, lags 0–2 |
| `Output/diag/figures/` | the panels, per period and per estimand |
| `Output/diag/DIAG1_manifest.csv` | files, sizes, checksums |

**Every output carries its support level, its unit, its period, its weighting and its estimand in the
file, not only in the filename.** Estimand is new and non-negotiable: between-unit and within-unit
outputs must never be distinguishable only by filename.

---

## 8 · The document

Required, in order:

1. **What was fitted, and the reproduction result** — including that the check was shown able to fail
2. **Each assumption, what was found, and what it changes.** Not "heteroscedasticity was assessed"
   but "residual spread runs 12.8 pp on the driest quarter to 3.8 pp on the wettest, so the common
   colour scale overstates dry parts and understates wet ones — and pack v1.4's single-page maps
   print raw pp per part"
3. **The influence result and the Bala 29ca asymmetry**, stated against the project rather than for it
4. **The functional-form sensitivity**, rank robustness and magnitude sensitivity in one paragraph
5. **Stage E — the within fits**, and that they had no diagnostics until now
6. **What remains undiagnosed**
7. **An as-of date and the `number_id` for every registered value quoted.** Cite the id, never the
   value alone.

**Plain-language section leads.** A reviewer should read the first sentence of each section and know
what was found.

---

## 9 · What this must never do

- **Register or modify anything.** Not one row, not one annotation.
- **Write to `Output/pack/**`.** Denied by policy.
- **Replace a published residual.** The local-z and leave-one-out columns are additional and the
  document says so.
- **Propose a production refit.**
- **Present a between-unit and a within-unit slope as versions of one number.**
- **Compare period levels**, or place an interval on across-year spread.
- **Emit a p-value.**

**No gates. Report once.**
