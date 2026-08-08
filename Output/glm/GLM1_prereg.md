# GLM-1 — pre-registration

**Written and committed BEFORE any model was fitted.** Spec §1: *"Fit first and look for
improvement afterwards and improvement will be found."* The commit hash of this file, as
committed with no model output in the repository, is reported in `GLM1_findings.md`.

Built to `docs/reference_update/Gayini_CC_spec_GLM1.md` plus **P5**, added by the design
seat on 7 August 2026 after DIAG-1 §8.6.

**Registers nothing. Proposes nothing. Changes no published number.** The registered
between-unit line stands as the descriptive expectation regardless of what this finds.
No p-values.

---

## The hypothesis

DIAG-1 found three things that may be one thing:

- residual SD runs **12.81 pp** on the driest water quartile to **3.83 pp** on the
  wettest — a ratio of **3.34** (`cap_residual_sd_water_quartile_1` … `_4`, as of
  7 Aug 2026)
- the **within-unit** response is concave: `log(x+1)` beat linear on
  leave-one-cluster-out CV in **both** independent sets — parts 10.784 → 10.336, unzoned
  patches 13.847 → 13.269, same ordering
- the findings note's "floor compression" mechanism

**All three are the signature of a response bounded at 100%.** Wet parts carry floors
near 75–80% and are compressed against the ceiling; dry parts sit mid-range with room to
vary. A proportion approaching its bound has intrinsically smaller variance.

---

## The criteria, fixed now

| # | criterion | threshold, fixed before fitting |
|---|---|---|
| **P1** | heteroscedasticity absorbed | Pearson-residual SD ratio across water quartiles falls from **3.34** to **below 1.8** |
| **P2** | saturation captured without a transform | logit-link model with a **linear** predictor matches or beats the best transformed linear model on leave-one-paddock-out CV RMSE, **on the response scale** |
| **P3** | bounds respected | **zero** fitted values outside [0, 100], against however many the linear model produces |
| **P4** | the finding survives | Spearman between GLM and linear residual rankings **≥ 0.95** |
| **P5** | **the bound is assumed, not tested** | **stated before the results, and no result reported as evidence about it** |

**P1 is the sharp test.** If residual spread is still strongly patterned by wetness on
the link scale, the bounded-response explanation is **wrong** and the heteroscedasticity
is something else — that is the result, not a failure.

**P4 is the one with consequences.** The paddock reports rank parts against an
expectation. If a better-specified model reranks them materially, then *who is below
expectation* is model-dependent, which is larger than heteroscedasticity and reaches
REPORT-2 directly. A low Spearman is reported prominently, not buried.

---

## P5 — the criterion that limits every other one

**Added by the design seat, 7 August 2026, and stated here before any result because
that is the whole point of it.**

DIAG-1 §8.6 recorded that the saturation found in the within-unit fits has an
alternative explanation: `veg_p05_spatial` is bounded above, and **a concave response is
what a bounded variable does near its ceiling.** Ecological saturation and ceiling
geometry predict the same curve.

**The quasi-binomial and beta models assume that ceiling.** It is built into the logit
link and into the mean–variance relationship. **No result from GLM-1 can therefore
distinguish ecological saturation from ceiling geometry — fitting the bound does not
test the bound.** A better fit under M1 or M2 is evidence that a bounded-response
specification is *sufficient*, and is not evidence that the flattening is ecological.

**What GLM-1 can establish:** whether a bounded-response specification is sufficient to
explain the heteroscedasticity, the concavity and the bounds **together**, with one
mechanism rather than three separate adjustments.

**What it cannot establish, and will not be reported as establishing:** that the
flattening is ecological. Testing that needs an **unbounded response** — a different
variable, not a different link — and is a separate task that GLM-1 does not attempt.

**P5 is met by construction if the statement above appears before the results in
`GLM1_findings.md` and no result is offered as evidence about the bound.** It is the one
criterion that cannot be met by a number.

---

## What is not a success criterion

**In-sample R² is not evidence.** A model with a different link and variance function has
an R² not comparable to the linear one. Reported, never compared on.

**A better-looking residual plot is not evidence** unless it comes with a simulation
envelope. An envelope shows what "bad" looks like *under the fitted model*; without one,
eyeballing rewards whichever model has the most shrunken residuals.

---

## The models, fixed now

- **M0 · linear**, the incumbent. Reproduce `S2_whole_full115` — slope 0.547274,
  intercept 52.697196. **Halt if it does not reproduce.**
- **M1 · quasi-binomial, logit link.** Response as a proportion in [0,1]. Weights = cell
  count **as a precision weight, not a binomial trial count** — the response is a
  percentile of a percentage, not successes out of cells, and the output says so.
- **M2 · beta regression**, continuous proportions. Requires the open interval (0,1);
  **exact 0 and 100 values are counted and reported before any adjustment is decided.**
  No silent squeezing.
- **M3 · GAM shape check**, `mgcv::gam`, `k = 4`, on the **within-unit** data (n = 4,025)
  where the saturation was found. **Not on the 17 Aeolian parts.** Inland between-unit
  (n = 61) admissible as a secondary check.
- **M4 · mvabund PIT-trap, if it wraps cleanly.** `block` requires balance: paddocks hold
  one to three parts and are unbalanced, so `block = zone_fid` will not take; part-years
  are 35 apiece and balanced. **If it does not wrap cleanly, say so and stop with
  M1–M3** — a convenience, not a requirement.

Both estimands, kept apart, every row carrying its own. **Within-unit is the primary
interest** — that is where the saturation was found.

---

## Anti-criteria — what would make me report failure

Recorded now so they cannot be renegotiated later:

1. P1 not met → the bounded-response explanation for the heteroscedasticity is **wrong**
   and is reported as wrong.
2. P4 below 0.95 → reported prominently as a finding with consequences for REPORT-2,
   **before** any discussion of model fit.
3. M2 requiring a boundary adjustment → the count of affected parts and the adjustment
   are reported in the results, not in a footnote.
4. Any model fitting better while reranking nothing → **"a methods-appendix paragraph,
   not a new result"**, in those words.
