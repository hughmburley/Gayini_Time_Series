# Amendment A1 to CC spec UNZONED v2 — Stage A leads with the within-patch response

**Design seat · 7 August 2026.** Amends §4 of `Gayini_CC_spec_UNZONED_v2.md`. Everything in §§1–3
and §§6–8 of v2 stands unchanged, and Gate 1 is accepted as reported at commit 8545a5e.

**Authority to act:** this amendment, quoted. Nothing else in v2 is reopened.

---

## 1 · Why §4 changes

Two facts arrived after v2 was written.

**The between-unit relationship is not the response.** Design-seat analysis of
`PARTREG_part_year_floor_inund.csv` (4,025 part-years, unregistered, to be reproduced by WITHIN-1):

| estimator | slope | 95% |
|---|---:|---|
| between parts — 115 across-year means | +0.5473 | [+0.358, +0.749] |
| **within parts — part fixed effects, pixel-weighted** | **+0.1613** | **[+0.143, +0.181]** |

A ratio of **3.39**. All 115 within-part slopes are positive; median within-part r is 0.443;
within-R² is 0.173. The between-part line bundles soil, position and community with water. **The
within slope is what an extra point of wetness buys the same ground.**

**And the size gap is worse than v2 assumed.** Gate 1 measured the unzoned median at **293 cells**
against the real parts' 4,486 — **1.18 decades**, not the 0.9 the pre-registered prediction used.
v2's §2.3 figure of +1.9 pp was built on v1's stated median of 533, which was itself wrong. **That
error is the design seat's.** The corrected pooled expectation is **+2.4 pp**.

So v2's §4 test — predict patch *means* from a line fitted on units roughly fifteen times larger —
is now the weaker of two available tests, and the confound it must survive has grown.

**A within-unit slope is far less sensitive to unit size than a p05 level is.** The level of a 5th
percentile depends directly on how many cells it is taken across; the slope of that level on water,
within the same unit over time, largely does not. **That is why the within test leads.**

---

## 2 · Stage A1 — the within-patch replication · **PRIMARY**

Input: `UNZONED_gate1_patch_series.npy`, the 93 supported patches' annual series. No new extraction.

**2.1 · Per patch.** Regress annual `veg_p05_spatial` on annual `inund_pct` across the patch's water
years. Report the slope distribution — min, quartiles, max, and **the share positive** — overall and
by community.

**2.2 · Pooled within estimator.** Demean both axes by patch, then fit pixel-weighted. This is the
quantity that compares to +0.1613.

**2.3 · Interval.** Clustered bootstrap, 2,000 and 10,000 draws. **There is no paddock here, so the
cluster is the patch** — state that on the output, and state that it differs from the real-part
estimate, which clusters on `zone_fid`. **Do not silently substitute a cluster.**

**2.4 · Serial correlation.** Design-seat measurement on the real parts: residual lag-1
autocorrelation median **+0.364**, giving an effective n of about **16 of 35 years**. Report the same
for the patches. Then refit the pooled within estimator with an AR(1) error structure
(`nlme::gls`, `correlation = corAR1(form = ~ water_year | patch_id)`) and report both. **Expect the
interval to widen and the point estimate to hold.** If the point estimate moves materially, that is
a finding and it stops for review.

**2.5 · By community — a pre-registered reversal.** On the real parts the between-part and
within-part community orderings invert:

| | between-part slope | within-part median |
|---|---:|---:|
| Aeolian Chenopod | −0.309 (spans zero) | **+0.350** |
| Riverine Chenopod | +0.348 (spans zero) | +0.218 |
| Inland Floodplain | +0.285 (excludes zero) | +0.140 |

**Recorded before the unzoned fits are seen.** If the response generalises, the unzoned patches
should show a pooled within slope near **+0.16**, a community ordering of **Aeolian > Riverine >
Inland**, and **close to 100% of patches positive**. Report what you find against each of the three.
**These are predictions to check, not targets, and no result is adjusted toward them.**

---

## 3 · Stage A2 — the between-unit prediction · **SECONDARY, unchanged in method**

v2 §§4.1–4.4 run exactly as written — both lines, all-patches and size-matched, community
breakdown — with two amendments:

- **The pre-registered pooled offset is +2.4 pp, not +1.9**, from 1.18 decades at −2.01 pp/decade.
  The Inland expectation stays near zero (−0.23 pp/decade within Inland).
- **The write-up subordinates it to A1.** It answers *does the between-place pattern extend to
  unzoned ground*, which is a real question and a weaker one. It is not the generalisation test.

v2 §2.3 rule 3 stands and is expected to trigger: the real Inland IQR is 4,101–13,332 cells against
an unzoned Inland Q3 of 1,825. **Report the surviving count and do not fit fewer than ten.**

---

## 4 · What this must never say

**The within and between slopes are not two estimates of one number, and never appear as a
comparison of accuracy.** +0.161 and +0.547 answer different questions: how ground responds to water
over time, and how places differ from each other in the long run. Any sentence implying one corrects
the other is wrong. Every figure and table carries which estimator produced its slope, on the face
of it.

**No management claim, no condition claim, no reference framing.** v2 §7 stands in full.

**No p-values.** Report slope, r, residual SD, share positive, and bootstrap quantiles.

---

## 5 · Gate

**One STOP after Stage A1**, before A2. Report the slope distribution, the pooled within estimate
with both intervals, the AR(1) refit, and the three pre-registered predictions against what
happened.

A2 then runs to completion and reports once.
