# Task J — Gate 5 (register cross-reference and close-out) — report, then STOP

**Branch:** `tier1j-prepost-placebo`. This closes Task J: it finalises the "What must not be claimed" block to the pixel-support finding, records the register diff (edited human-side), and cross-references the method to Task H. Descriptive only; **not** an effect estimate. The register rewrite itself (`Gayini_limitations_register_20260716_v2.xlsx`) was done human-side; this report is not editing it.

## What Task J built (Gates 1–4, all on `main`-bound branch, human-reviewed per gate)

- **Gate 1** recon: stack/vectors/gauge verified against the rasters and DB; the 255-nodata trap and layer→water-year mapping confirmed (layer index C−1987), gauge +1 shift proven by reproducing the reference CSV.
- **Gate 2** single-date 2018 build: whole-farm `diff_pp = +9.30 pp`; all input/product assertions pass; MIN_VALID inert within the farm.
- **Gate 3** placebo ladder (25 dates): shape tracks the plot-support reference (Pearson 0.938); flow join exact; the `diff = −100` drought-onset evidence recorded.
- **Gate 4** the law: fit on the 24 pixel placebos, 2018 residual ranked, heteroscedasticity evidenced, four figures rendered.

## The finding (final, pixel support)

`diff_pp = −1.44 + 19.62·log(q_ratio)`, R² = 0.864, residual sd 4.16 pp (ddof=1, pre-registered). 2018 predicted +1.78, observed +9.30, **residual +7.51 pp = 1.80 sd — rank 2 of 25**, one placebo (2005) above. This is a genuine, publishable result **about the method**: the pre/post difference is largely set by how wet the two windows happened to be, and the estimator throws residuals of this size at dates when nothing happened.

## What must not be claimed — FINAL (pixel support)

*Supersedes the plot-support version in the spec. The two lines flagged at Gate 4 are now finalised; "ordinary" is retired.*

- ❌ "The cuts increased inundation." Not identifiable — the cuts span essentially the whole farm, so there is no untreated control region (**L01, L02, L03, L12**).
- ❌ "The 2018 difference map shows a management effect." A law fitted only on dates when nothing happened predicts most of 2018 (+1.78 of the +9.30) (**L26**).
- ❌ Any p-value or CI from the placebo spread. Consecutive dates share four of five post-years; 25 dates is not 25 tests, only **5** are independent (**L27**).
- ❌ "The unexplained residual is the cuts." It is uniform, and uniform is unattributable. Delivery is a live alternative and **cannot be ruled out — permanently** (Redbank/Maude fraction 0.650→0.729; Redbank 1993–2006 gap unrecoverable) (**L29, L30, L33**).
- ❌ **RETIRED — "The 2018 residual is ordinary / within the usual placebo range."** At pixel support it is the **second-largest of the 25 dates tested** (+7.51 pp, 1.80 sd). Do not call it ordinary.
- ❌ "Being second-largest, the 2018 residual is suggestive of a cuts effect." It is not: not identifiable (**L03**); uniform and unattributable with delivery unresolved (**L33**); 1.80 sd is measured against 24 **non-independent** placebos and is not a significance statement (**L27**); one placebo (2005, nothing happened) still exceeds it; and the residuals are heteroscedastic, so the pooled sd is not comparable across flow regimes (**L43**).
- ✅ "Inundation was higher in 2018–2022 than in 1988–2017" — **only** shown beside the drop-2022 number, which reverses the sign.
- ✅ "The pre/post difference is largely determined by how wet the two windows were; R² = 0.86 across 25 dates."
- ✅ "The 2018 flow-adjusted residual is the second-largest of 25 dates tested; one placebo (2005) exceeds it and the near-flow-twin placebo (2009, almost identical flow) sits ~2.2× below it — larger than typical for this estimator, but neither unique nor significant, and consistent with flow plus an unresolved delivery contribution."

## Register diff (edited human-side; recorded here for provenance)

- **L33 — rewritten to the pixel-support result.** Was: plot support, 2018 residual +6.27 pp (1.59 sd), 3rd of 25, exceeded by 2009 (+8.04, 2.04 sd) and 1994 (−7.37, 1.86 sd), framed "ordinary." Now: pixel support, +7.51 pp (1.80 sd), **2nd of 25**, exceeded by one placebo (2005, +8.67, 2.08 sd); 2009 collapses to +3.37 pp (0.81 sd, rank 11). "Ordinary" **retired**.
- **L43 — added (new): heteroscedasticity of the placebo residuals.** Dry windows (q<0.6): residual sd 5.13, mean |diff| 21.82. Wet (q≥0.6): residual sd 2.30, mean |diff| 3.78. `corr(|residual|,|diff_pp|) = +0.566` (multiplicative error). Pooled sd (4.16) is not comparable across regimes → sd-unit ranks carry this caveat. **The rank (2 of 25) is pre-registered on the pooled sd and is NOT re-scaled** (a post-hoc regime split re-scaled after seeing the answer would defeat the placebo design; under such scaling 2018 would be rank 1, which is exactly why it is not used).
- **Evidence source for both:** `Output/tables/task_J_gate4_{law_summary,residual_ranking,heteroscedasticity}.csv`.

## Cross-reference — Task J and Task H are the same method, twice in one project

**The placebo ladder (Task J) and the H3.2 sample-power draws (Task H) are the same method: a many-draws null showing that an estimator manufactures signal when it is trusted naively.** Task J runs the pre/post estimator at 24 dates when nothing happened and finds large "differences"; Task H's ~1000 sample-power draws (`tier2H_h32_sample_power_{summary,1000draws}.csv`, 54.1% false-positive rate, retiring the 8/1/0 trend flag) run the trend estimator against a null and find the same. Two independent instances in one project of the same discipline — build the null the method implies, then read the real result against it, not against zero.

## Handoff / status

- **Nothing committed** (TortoiseGit is yours). Staged for Task J across Gates 1–5: scripts 16/17/18/19 + `internal/task_J_prepost_placebo_impl.R`; the Gate 2/3/4 result CSVs (`git add -f`); the five change reports. PNGs and rasters stay gitignored.
- **`raster_asset` registration still DEFERRED** — Task H owns it and is live.
- The two Task-H CSVs in the tree (`tier2H_h32_sample_power_*`) are **not** Task J and are not staged here — they belong to Task H's change reports / register.
- Task J is a bounded, one-time run of the retired pre/post framing to answer a specific question and close it — not a revival of pre/post as a project direction.

**STOP — full task review before anything goes to Adrian.**
