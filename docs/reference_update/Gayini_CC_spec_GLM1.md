# CC spec GLM-1 — does a bounded-response model do better?

**Design seat · 7 August 2026.** Post-deadline exploratory work. Runs after DIAG-1 and METHODS-REG.
Ruling AX: runs to completion, reports once. Ruling AS: all estimation in R.

**Registers nothing. Proposes nothing. Changes no published number.** The registered between-unit
line stands as the descriptive expectation regardless of what this finds.

---

## 0 · Why this exists

DIAG-1 found three things that may be one thing:

- residual SD runs **12.81 pp** on the driest water quartile to **3.83 pp** on the wettest, a ratio
  of **3.34**
- the **within-unit** response is concave — `log(x+1)` beat linear on leave-one-cluster-out CV in
  **both** independent sets, real parts 10.784 → 10.336 and unzoned patches 13.847 → 13.269, same
  ordering
- the findings note's "floor compression" mechanism

**The hypothesis to test: all three are the signature of a response bounded at 100%.** Wet parts
carry floors near 75–80% and are compressed against the ceiling; dry parts sit mid-range with room to
vary. A proportion approaching its bound has intrinsically smaller variance.

If that is right, a model with a logit link and a proportion-shaped mean–variance relationship should
absorb the heteroscedasticity, produce the saturation without a transform, and respect the bounds.

**Reference for the choice of link:** Warton, D.I. & Hui, F.K.C. (2011), "The arcsine is asinine: the
analysis of proportions in ecology", *Ecology* 92(1): 3–10, doi:10.1890/10-0340.1. It argues against
the arcsine for proportional data and proposes the logit for non-binomial proportions, partly because
the arcsine can produce nonsensical predictions, and stresses checking for overdispersion.

**Reference for the resampling:** Warton, D.I., Thibaut, L. & Wang, Y.A. (2017), "The PIT-trap — a
model-free bootstrap procedure for inference about regression models with discrete, multivariate
responses", *PLoS One* 12(7): e0181790.

---

## 1 · Pre-registration — write this section and commit it BEFORE fitting anything

**This is the point of the task.** Fit first and look for improvement afterwards and improvement will
be found. Commit §1 to git as its own commit, with the hash reported, before any model runs.

### 1.1 · What would count as the bounded-response story being right

| # | criterion | threshold, fixed now |
|---|---|---|
| **P1** | heteroscedasticity absorbed | Pearson-residual SD ratio across water quartiles falls from **3.34** to **below 1.8** |
| **P2** | saturation captured without a transform | logit-link model with **linear** predictor matches or beats the best transformed linear model on leave-one-paddock-out CV RMSE, **on the response scale** |
| **P3** | bounds respected | **zero** fitted values outside [0, 100], against however many the linear model produces |
| **P4** | the finding survives | Spearman between GLM and linear residual rankings **≥ 0.95** |

**P1 is the sharp test.** If residual spread is still strongly patterned by wetness on the link
scale, the bounded-response explanation is **wrong** and the heteroscedasticity is something else —
report that as the result, not as a failure.

**P4 is the one with consequences.** The paddock reports rank parts against an expectation. If a
better-specified model reranks them materially, then *who is below expectation* is model-dependent,
which is a larger problem than heteroscedasticity and reaches REPORT-2 directly. **A low Spearman is
a finding that must be reported prominently, not buried.**

### 1.2 · What is not a success criterion

**In-sample R² is not evidence.** A model with a different link and variance function has an R² that
is not comparable to the linear one. Report it, never compare on it.

**A better-looking residual plot is not evidence** unless it comes with a simulation envelope. An
envelope shows what "bad" looks like under the fitted model; without one, eyeballing rewards
whichever model has the most shrunken residuals.

---

## 2 · The models

All pixel-weighted by cell count. All clustered on `zone_fid` for the between-unit fits, `part_id`
for within-unit.

**M0 · linear, the incumbent.** Reproduce `S2_whole_full115` — slope 0.547274, intercept 52.697196.
**Halt if it does not reproduce.**

**M1 · quasi-binomial, logit link.** Response as a proportion in [0,1]. Weights = cell count, used as
precision weights. **State plainly in the output that this is a precision weight and not a binomial
trial count** — the response is a percentile of a percentage, not successes out of cells, and the
distinction must not be silently elided.

**M2 · beta regression** (`betareg` or `glmmTMB` with a beta family). **Designed for continuous
proportions and arguably the more correct object than M1.** Requires the open interval (0,1) —
**check for exact 0 and 100 values first and report the count** before deciding on any adjustment.
Do not silently squeeze.

**M3 · GAM shape check**, `mgcv::gam`, `k = 4`, on the **within-unit** data where n = 4,025 and the
saturation was found. **Not on the 17 Aeolian parts** — k=4 on 17 points fits noise and will produce
a shape you then have to argue your way out of. Inland between-unit at n=61 is admissible as a
secondary check.

**M4 · mvabund, if it takes the fit.** `manyany` accepts most fixed-effects models with `predict` and
`family` methods, so a quasi-binomial fit may wrap. If it does, run the PIT-trap. **Note the `block`
argument requires balance:** paddocks hold one to three parts and are unbalanced, so `block =
zone_fid` will not take directly; part-years are 35 apiece and balanced, so `block = part_id` on the
within-unit data should. **If it does not wrap cleanly, say so and stop with M1–M3** — this is a
convenience, not a requirement, and our own cluster bootstrap already handles unbalanced clusters.

---

## 3 · Both estimands, kept apart

**Between-unit**, 115 parts, and **within-unit**, 4,025 part-years, then the 3,253 unzoned
patch-years as the out-of-sample replication.

**A between-unit and a within-unit coefficient are never presented as versions of one number**, on
any output of this task. Every row carries its estimand.

**Report the within-unit results as the primary interest.** That is where the saturation was found
and where the bounded-response story makes its strongest prediction.

---

## 4 · The comparison table

One table, every model, every estimand:

link · variance function · CV RMSE on the response scale · Pearson-residual SD by water quartile and
their ratio · fitted values outside bounds · Spearman against M0's residual ranking · slope
reported back on the response scale at three wetness levels (10%, 30%, 50%).

**That last column is the interpretability bridge.** A logit coefficient means nothing in a room.
"At 10% wetness an extra point of water buys X pp of floor; at 50% it buys Y" is the same model
stated so it can be said aloud, and it is how any of this would reach a report.

---

## 5 · Outputs

`Output/glm/GLM1_findings.md` · `GLM1_model_comparison.csv` · `GLM1_prereg.md` (committed first) ·
`GLM1_response_scale_effects.csv` · `Output/glm/figures/` — envelope residual plots per model, and
the GAM shape with its confidence band.

Every output carries support level, unit, period, weighting, **estimand**, and
`interval_conditionality` under Ruling AW.

Worth checking whether Warton's `ecostats` package — companion to *Eco-Stats* (Springer, 2022) —
provides the simulation-envelope diagnostics; **confirm the current API rather than assuming function
names.** If it does not, build the envelope by simulation from the fitted model directly.

---

## 6 · The report

1. **The pre-registration commit hash**, and P1–P4 stated before the results.
2. **Each criterion: met or not met, with the number.**
3. **What this changes** — and if the answer is nothing, say so. A model that fits better and reranks
   nothing is a methods-appendix paragraph, not a new result.
4. **What it would change if adopted**, specifically for the paddock reports and the residual maps.
5. **The honest limitation**: a better-specified between-unit model is still a between-unit model and
   still cannot identify a response. Fixing the link does not fix the estimand.

**No p-values. No registration. No production refit.**
