# CC spec DIAG-1 — regression diagnostics, bootstrap stability, and the assumptions record

**Design seat · 6 August 2026.** Runs alongside UNZONED on the methods seat.
Diagnoses the fits registered by PARTREG Stages 1 and 2, and — at Stage D — the UNZONED fits when
they exist.

**Log and keep moving.** Proof-of-concept work for the article. **The only condition that halts a
run is a quantity that will not reproduce** — and in this task that condition is load-bearing, since
Stage A opens by reproducing the registered coefficients from the shipped table.

---

## 0 · Standing conditions

Read-only on the database throughout. `mode=ro`, `PRAGMA query_only=1`. **This task registers
nothing and modifies nothing.** Recon first — `git fetch`, `git status`, `git log --oneline -10`.

**Its own producer script and its own output namespace.** `scripts/14_diag/DIAG1_*.py`,
outputs under `Output/diag/`. **Do not write to `report_figs.py`** — the report seat holds it.
Confirm that seat's worktree before any write anywhere.

**No p-values, and no significance tests of assumptions.** No Breusch–Pagan, no Shapiro–Wilk, no
RESET. Assumptions are reported as **effect sizes and pictures**: how large the departure is, where
it sits, and what it changes. A test statistic on 115 nested units would be a p-value wearing a
disguise.

**Normality is not diagnosed.** Nothing in this project rests on it.

---

## 1 · What this is for

Three audiences, one artefact:

- **A reviewer** who asks whether the assumptions behind Figure 25 were ever checked.
- **Adrian**, who needs to present the fit and answer that question in a room.
- **The next session**, which should not have to re-derive any of it.

**It is not a remodelling exercise.** DIAG-1 reports how the fitted relationships behave under
scrutiny. **It proposes no new model, refits nothing into production, and changes no published
number.** If a diagnostic argues for a different specification, that argument goes in the document
as an argument and stops there.

---

## 2 · Stage A — between-part diagnostics · **STOP**

On the 115 across-year means in `Output/pack/PARTREG/tables/PARTREG_part_residuals.csv`
(`whole_record__inund_mean`, `whole_record__floor_mean`, `n_pixels_part`, `zone_fid`), and on the
cropping-era and post-management columns.

### 2.1 · Reproduce before diagnosing — the halt condition

Refit weighted OLS from the table and check against `PARTREG_S2_regression_coefficients.csv`:

| | expected |
|---|---|
| `S2_whole_full115` | slope **0.547274**, intercept **52.697196** |
| `S2_whole_record_common_unweighted` | slope **0.521378**, intercept **53.956357** |
| `S2_cropping_era_common` | slope **0.592241** |
| `S2_post_management_common` | slope **0.324225** |

**Design-seat reproduction: exact on the first two.** If yours is not, **stop and report** — that
is a quantity that will not reproduce, and everything below would be diagnosing a different model.

**Show the check able to fail.** Perturb one weight in a scratch copy and confirm the assertion
fires. A check that cannot fire is indistinguishable from a check that passed.

### 2.2 · The standard four, per period, and by community

Residual against fitted · residual against the water axis · scale–location (√|standardised
residual| against fitted) · leverage against standardised residual with the cluster marked. Marker
area ∝ cell count and colour by community on every panel, matching the PARTREG figures — the
diagnostics must be readable beside the figure they diagnose.

### 2.3 · Heteroscedasticity, quantified not tested

Residual SD by water quartile. **Design-seat figures, whole record, to reproduce:**

| quartile | mean x | residual SD |
|---|---:|---:|
| driest 29 | 4.5% | **12.81 pp** |
| | 15.2% | 8.49 |
| | 26.9% | 6.33 |
| wettest 29 | 40.4% | **3.83 pp** |

corr(|residual|, x) = **−0.506**. Repeat for both other periods and within each community.

**The consequence this must state.** The residual maps and the GeoPackage carry one common colour
scale, and `PARTREG_S2_residual_maps_three_periods.png` sets its ticks at "one and two typical
misses (1 SD = 8.08 pp)". **There is no single typical miss.** Emit a
`whole_record__residual_z_local` column — residual divided by the local residual SD at that part's
wetness — as an **additional** column in a **new** table, `Output/diag/DIAG1_local_z.csv`, joinable
on `part_id`. **Do not edit the shipped GeoPackage or CSV.**

Report which parts move most between the pooled and local rankings. Design-seat: Mara 6 and Dinan 2
move from ranks 85 and 87 to 113 and 114 of 115.

### 2.4 · Influence, at the cluster that matters

- **Drop-one-paddock refit, all 64.** Report the slope range and the ten largest movers.
  Design-seat: range **0.4692 to 0.5867** against a full-sample 0.547274; **Bala 29ca alone moves it
  −0.0781**, roughly 40% of the bootstrap half-width and about twice the next paddock.
- **Leave-one-out residuals** as a column beside the in-sample ones, for all 115. Design-seat, Bala
  29ca whole record: Aeolian **−24.85 → −27.29**, Riverine **−21.58 → −23.74**, Inland **+5.87 →
  +4.45**.
- **State the asymmetry plainly in the document.** Bala 29ca is the most influential unit on the
  line against which Bala 29ca is then judged. In-sample residuals for high-leverage units are
  shrunk toward zero. Here the leave-one-out correction happens to make the shortfall larger, so the
  reported figure is conservative — **say that, rather than letting a reader discover it.**

### 2.5 · Functional form, with cluster cross-validation

Fit linear, quadratic, √x, log(x+1) and cubic, pixel-weighted, and compare on **leave-one-paddock-out
predictive error**, not in-sample R². Design-seat CV weighted RMSE: √x **8.481** · quadratic 8.553 ·
linear **8.572** · log 8.701 · cubic 8.805.

**Then fit the same forms within each community**, and report the x range each community actually
spans. Design-seat:

| | n | x range | x² term | ΔR² from quadratic |
|---|---:|---|---:|---:|
| Aeolian | 17 | 1.0–19.7 | +0.306 | +0.106 |
| Riverine | 37 | 3.0–33.3 | +0.047 | +0.111 |
| **Inland** | 61 | **5.9–58.9** | **−0.0028** | **+0.006** |
| pooled | 115 | 1.0–58.9 | −0.0096 | +0.026 |

**The reading to check, not to assume:** Inland is the only community spanning the water axis and is
effectively linear across it; the two communities that appear to bend cannot identify shape and
return x² terms of the opposite sign to the pooled fit. **Pooled curvature and pooled steepness look
like the same artefact — three communities at different levels occupying different stretches of the
water axis.** If your numbers support that, it unifies §3 of the findings note with the form
question. If they do not, report what you find.

### 2.6 · The sensitivity that must reach the article

Recompute the whole-record residual for every part under linear, quadratic and √x. Design-seat, Bala
29ca: Aeolian **−24.85 / −21.66 / −21.53**; Riverine **−21.58 / −19.83 / −20.57**; Inland **+5.87 /
+4.93 / +4.74**.

Report the **Spearman correlation between the residual rankings** under each form. Design-seat,
linear against √x: **0.984**, with the worst three identical and in the same order.

**The sentence this supports:** *who* is below expectation is robust to functional form; *by how
much* is sensitive to roughly ±3 pp at the dry end. **Both halves must appear together.**

**STOP and report before Stage B.**

---

## 3 · Stage B — bootstrap stability

Re-run the clustered bootstrap on `zone_fid` at **2,000 and 10,000 draws**, same procedure, seed
recorded, for every fit in `PARTREG_S2_regression_coefficients.csv`. Report both intervals side by
side.

**Nothing is registered and nothing is superseded.** The registered intervals stand. Design-seat
expectation, to be read against rather than aimed at: the 10,000-draw interval sits within about
±0.01 of the registered one, and the exercise demonstrates stability rather than improving accuracy.

**If any interval moves materially, that is the finding** — not the new number. It would mean 64
clusters cannot support the precision either figure is quoted at, and it goes to the design seat as
a ruling request before anything else happens.

**Also report, on the face of every interval:** the number of clusters (**64**), the method
(percentile), and that the draws resample paddocks rather than parts. Report slopes to two decimals
alongside the interval in the document text. The four-decimal agreement between the paddock-grain
and part-grain slopes is real and worth stating once, but it is more precise than a
[+0.36, +0.75] interval licenses and should not be repeated as though it were a comparison.

---

## 4 · Stage C — the annual series · **STOP before starting**

**The highest-value stage and the one needing data outside the pack**: the part × year table,
115 × 35 = 4,025 rows, `fact_zone_community_veg_annual` joined to the annual water stack.

Everything in Stages A and B is computed on across-year means. **The entire first stage of the
two-stage aggregation is currently undiagnosed.**

- **Lag-1 autocorrelation of each part's annual floor series, and of its annual water series.**
  Report the distribution across the 115. The project asserts in several documents that 35
  consecutive years are not 35 independent observations. **This is the number that substantiates
  it**, and its absence is the gap a reviewer is most likely to find.
- **Is the across-year mean a fair summary?** Report the skew of each part's 35 annual floor values
  and how far mean and median diverge. Where they diverge materially, name the parts.
- **Within-part response.** Regress each part's annual floor on its annual water — 115 fits — and
  report the slope distribution against the single between-part slope of 0.547. **These answer
  different questions and must never be presented as versions of one number.** The between-part fit
  describes how places differ; the within-part fits describe how a place responds. A saturating
  cover-to-water response, if one exists, is identifiable here and is not identifiable in Stage A.
- **Lag structure.** Same-year against one- and two-year-lagged water, reported as a slope and r per
  lag, pooled and by community.

**No management claim, and no period comparison.** This is an assumptions audit.

---

## 5 · Stage D — apply to UNZONED

When the UNZONED patch table exists, run Stages A and B unchanged over it. The diagnostic code must
take `(x, y, weights, cluster)` and not care which set it is given. Where UNZONED has no cluster,
say so on the output rather than substituting one.

---

## 6 · Outputs

| | |
|---|---|
| `Output/diag/DIAG1_diagnostics.md` | **the deliverable** — see §7 |
| `Output/diag/DIAG1_local_z.csv` | locally standardised residuals, joinable on `part_id`. Additional, never a replacement |
| `Output/diag/DIAG1_influence.csv` | drop-one-paddock slopes, leave-one-out residuals, leverage |
| `Output/diag/DIAG1_form_comparison.csv` | every form, pooled and per community, with CV error and per-part residuals under each |
| `Output/diag/DIAG1_bootstrap_stability.csv` | 2,000 against 10,000, every fit, seed recorded |
| `Output/diag/figures/` | the diagnostic panels, per period |
| `Output/diag/DIAG1_manifest.csv` | files, sizes, checksums, on the PARTREG pattern |

**Every output carries its support level, its unit, its period and its weighting in the file, not
only in the filename.**

---

## 7 · The document — what it must contain

`DIAG1_diagnostics.md` is the point of the task. It is written for a reviewer who has the figure and
one question.

Required, in this order:

1. **What was fitted, and the reproduction result** — including that the check was shown able to
   fail.
2. **Each assumption, what was found, and what it changes.** Not "heteroscedasticity was assessed"
   but "residual spread runs from 12.8 pp on the driest quarter to 3.8 pp on the wettest, so the
   common colour scale on the residual maps overstates dry parts and understates wet ones."
3. **The influence result and the Bala 29ca asymmetry**, stated against the project rather than for
   it.
4. **The functional-form sensitivity**, with the rank robustness and the magnitude sensitivity in
   the same paragraph.
5. **The bootstrap stability table.**
6. **What remains undiagnosed** — Stage C's items until Stage C runs, and the fact that the
   between-part fit cannot identify a within-part response.
7. **An as-of date and the `number_id` for every registered value quoted.** Cite the id, never the
   value alone.

**Plain-language section leads.** A reviewer should be able to read the first sentence of each
section and know what was found.

---

## 8 · What this must never do

- **Register or modify anything.** Not one row, not one annotation.
- **Edit the sealed pack.** `Output/pack/PARTREG/` is sealed and checksum-verified; DIAG-1 reads it
  and writes elsewhere.
- **Replace a published residual.** The local-z and leave-one-out columns are additional, in a new
  table, and the document says so.
- **Propose a production refit.** An argument for a different specification is an argument, recorded
  as one.
- **Compare period levels**, or place an interval on across-year spread.
- **Emit a p-value.**

---

## 9 · Gates

**Gate 1 · STOP** — after §2.1's reproduction and fail-check, before any diagnostic is computed.

**Gate 2 · STOP** — after Stage A, with the four panel sets and §2.3–2.6's tables.

**Gate 3 · STOP** — before Stage C, which needs data outside the pack and is the largest stage.

Stage B and Stage D run to completion and report once.
