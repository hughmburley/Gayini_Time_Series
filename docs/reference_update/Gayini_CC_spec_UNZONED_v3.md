# Gayini CC spec — UNZONED v3

**The out-of-sample test, on two metrics that answer two different questions.**
Design seat, 10 August 2026. Supersedes `Gayini_CC_spec_UNZONED1.md` (9 August) and consolidates
`Gayini_CC_spec_UNZONED_v2.md` (6 August) with its amendment A1 (7 August). Additive only.

---

## 0 · Standing execution rule and state of play

Run each arm to completion and report once per arm, in the `RUN_` schema of Ruling DP. Every fork
carries a pre-registered rule; a fork with a rule is not a question. Do not ask before writing. If a
rule is clearly wrong for what you find, override it, state that you did and why, and keep going.

Halt only on: grid mismatch against `veg_regime_class_8058.tif`; a registry write that fails or
cannot be made atomic; a required input absent after searching; unresolved repository divergence; a
quantity that will not reproduce. An expected commit named in a brief is a prior to report against,
not a gate.

**This is post-deadline work. No client clock.** Prefer getting the unit right over getting it fast.

**Already done, and not reopened.** Gate 1 of v2 was accepted at commit `8545a5e`: the mask, the
patch construction, the size distributions, the component counts and the construction reproduction.
**93 supported patches** and `UNZONED_gate1_patch_series.npy` — the patches' annual series — exist.
Do not rebuild them. Verify they are present and their counts reproduce; if they are not, that is a
required input absent after searching.

**Two amendments to Gate 1's own record**, both design-seat errors, recorded so nothing downstream
inherits them: v1's stated unzoned median of 533 cells was wrong; Gate 1 measured **293**. v2's
pre-registered pooled offset of +1.9 pp was built on that wrong median; the corrected figure is
**+2.4 pp**, from 1.18 decades at −2.01 pp per decade.

---

## 1 · Why there are two arms, and why neither replaces the other

Two vegetation-floor metrics exist in this project and the prohibition on ever placing them in one
figure stands. What has not been written down is that **they enable different tests**, and the
choice between them is not a matter of preference.

| | `veg_p05_spatial` | `veg_p05_temporal_mean` |
|---|---|---|
| construction | 5th percentile **across a unit's cells**, within one water year | per-cell 5th percentile **across the record**, then averaged over the unit's cells |
| time axis | intact — one value per unit per year | none — one value per cell, no series |
| sensitivity to unit size | **direct.** A quantile over 95 cells is not the same quantity as one over 31,750 | **expected to be slight.** A mean's expectation does not shift with n |
| enables | within-unit response over time | size-robust between-place comparison |

**Amendment A1 led with the within-patch slope because the between-unit level test was compromised
by size** — 293 cells against 4,486. That reasoning was correct for the spatial floor and it does not
transfer to the temporal metric. **On the temporal metric the between-place test is available again**,
and v2 §2.3's size-matched subsetting is not required for it.

**The reverse also holds and is absolute: no within-unit slope can be computed on the temporal
metric.** It has no time axis. Arm B must use the spatial floor and cannot be modernised onto the
new one.

So: **Arm A** is the between-place scatter on the temporal metric, matching PARTSCATTER exactly.
**Arm B** is A1's within-patch replication on the spatial floor, unchanged in method.

**Arm A runs first because it is cheap, not because it is stronger.** A1 §2's within test remains the
strongest generalisation test this project can run, and the write-up order in §6 reflects that.

### 1.1 · The size-robustness claim is measured, not assumed

The table above says the temporal metric is *expected* to be slight. That is a design-seat claim and
I-40 applies: **check it before relying on it.**

On the **100 zoned parts already plotted in PARTSCATTER**, regress the part's
`veg_p05_temporal_mean` residual — against the PARTSCATTER smoother — on log₁₀ cell count, pooled and
by vegetation community. Report the slope in pp per decade of size, with r and n.

The comparable figures on the spatial floor, from `PARTREG_part_residuals.csv`, are: pooled −2.01
(r −0.17), Aeolian −7.64, Riverine −4.41, Inland −0.23.

**Pre-registered fork:**

- **If the pooled temporal slope is materially smaller in magnitude than −2.01** — the expectation —
  Arm A proceeds on all supported patches with no size matching, and the measured figure goes in the
  caption as the reason.
- **If it is comparable to −2.01**, the claim above is wrong. Say so plainly, run Arm A on all
  patches anyway, and **additionally** report the size-matched subset per v2 §2.3 rule 3, not fitting
  any community with fewer than ten surviving patches. Do not adjust any residual for size in either
  branch.

---

## 2 · What this ground is — naming, fixed

**12,048 ha carrying a vegetation-community label and 35 years of cover and water, never used in any
fit.** It was excluded for one reason: no management zone was drawn over it, so there was no polygon
to aggregate to.

**It is not a reference set and it is not unmanaged.** This is standard-grazing — set-stocking —
country. All fifteen standard-grazing monitoring plots sit here, and the UNSW annual report treats
set stocking as a designed, replicated treatment arm rather than an absence of management.

**The project term is "unzoned standard-grazing country".** Any wording that calls this land
unmanaged, ungrazed, a control or a reference is wrong and must not appear in any output, caption,
column name or file name.

It also matters for a second reason: **the standard-grazing arm has never been reported above plot
support**, because it has no paddock to belong to. Report how many of the 66 monitoring plots fall on
unzoned ground and how many of those are the fifteen standard-grazing plots. One spatial query, and
it is the join between this analysis and every plot-support result.

---

## 3 · Arm A — the between-place scatter on the temporal metric

Matches PARTSCATTER in unit, metric, axes, channels and caption structure, so the two read as a pair.

### 3.1 · Unit and data

Patches from Gate 1, cut community-pure. **Use the census parquet**, which covers unzoned cells — no
raster is opened and no new metric is computed.

**Support floor: 500 cells, the same floor PARTSCATTER used.** The two figures will be read side by
side and a different floor makes them incomparable. **Also report the count under v2 §2.2's rule** —
at least 25 water years in which at least 30 valid cells could be seen — and the count under a bare
33-cell threshold. Three numbers, one sentence each. If they differ materially that is a fact about
the unzoned ground's observability, not a nuisance.

At a median of 293 cells, **expect the 500-cell floor to remove a large share of the 93 patches.**
Report how many survive, by vegetation community, with area. **If fewer than ten survive in a
community, that community is not fitted and its points are drawn without a line** — the same rule
PARTSCATTER applies through EH, reached by a different route.

**If fewer than ten patches survive in total**, Arm A produces no figure. Report the counts, say the
unzoned ground does not support a between-place comparison at PARTSCATTER's floor, and go to Arm B.
That is a legitimate outcome and it is pre-registered here so it is not a judgement call in the
moment.

### 3.2 · Build

- **y:** mean over the patch's cells of each cell's temporal 5th percentile of total vegetation.
- **x:** the same water quantity, computed over the patch's own cells. Both axes on the same cells.
- **Colour:** vegetation community, from `gayini_veg_regime_classes()`.
- **Size:** cell count.
- **Opacity:** `veg_p05_within_sd`, the spread of the per-cell 5th percentile across the patch's own
  cells, **reversed: low spread → opaque, high spread → faint**, ramp floored at 0.45.

**Ruling EJ applies to the opacity channel.** Assert the direction on the built plot via
`ggplot_build()`, not on the source: correlation of alpha against spread ≤ −0.999, ramp endpoints
observed at 1.0 and 0.45, and the argmin/argmax of alpha paired with the argmax/argmin of spread.
Three assertions, because they catch different failures.

**Ruling EH governs every smoother.** A per-community line is fitted only where that community's
central 10th–90th percentile of the water axis spans a usable range. Min-to-max does not qualify.
Retain both measures as columns.

### 3.3 · Two figures

**Figure A1 — unzoned alone.** One point per patch, one smoother per qualifying community.

**Figure A2 — zoned and unzoned together.** PARTSCATTER's 100 parts and their smoothers, with the
unzoned patches **overlaid in a visually distinct shape** — not merely a different colour, since
colour carries community. **The unzoned points are not fitted and enter no smoother.** The caption
says so on the face. Both point sets carry the same size and opacity channels on the same scales.

### 3.4 · The registered-line problem — pre-registered, not discovered

v2 §4.1 computes residuals against **registered** lines: the 64-paddock fit
(`52.652934 + 0.547838 × mean_flood`) and the 115-part fit (`52.697196 + 0.547274 × mean_flood`).
**Both are fitted on `veg_p05_spatial`. Neither applies to the temporal metric.**

And **there is no registered line on the temporal metric.** PARTSCATTER's curves are display
smoothers, and no coefficient may be taken from one.

**Pre-registered rule: Arm A is descriptive.** Report where the unzoned points sit relative to the
zoned cloud — by vegetation community, as a median vertical offset in percentage points with its
sign and interquartile range, computed against the smoother's predicted value. **Label it a
descriptive offset, never a residual, and never claim it as a test.** Do not fit a line to the zoned
parts in order to create one; that is a separate registered build, not this task.

### 3.5 · Labels and caption

**Ruling EC in full.** Canonical labels from `Gayini_caption_register.md`, identical to PARTSCATTER's
so the two read as a pair. **"Vegetation community" written out.** **No internal identifiers on the
face** (EA). **Caption runs the full plot width.**

Structure follows PARTSCATTER — a subtitle saying what you are looking at, then a numbered footnote:

1. **What one point is**, and that these are contiguous tracts of unzoned standard-grazing country,
   not management units — cut where they change vegetation community.
2. **Why this many patches** — the floor, its count and area, and the alternative counts from §3.1.
3. **What cover means here** — measured for each cell across every season in the record rather than
   once a year; 5 to 140 measurements behind a cell.
4. **What the lines are** — display smoothers; no slope read from them, no significance test.
5. **Independence.** PARTSCATTER's sentence is not available: these patches have no parent paddock.
   State what is true instead — patches are contiguous tracts and neighbours may share conditions, so
   the shaded bands are display only and are, if anything, too narrow.
6. **Opacity** — in a solid point the average describes nearly every cell; in a faint one it
   describes few of them well. **Plus the concrete note**: two patches of very different size with the
   same internal spread are drawn equally solid, so the channel is not precision.
7. **What this does not say** — it describes how places differ from one another over the record, not
   what more water would do to any one place. **Arm B is where that question is answered.**

**Per-community `r`** in the legend with `n`, computed on the data and never off the smoother. Where
EH excludes a community, the legend reads *range too narrow to fit* in words and the value goes to
the support table with its suppression reason. **No R², no deviance explained.**

---

## 4 · Arm B — the within-patch replication · A1 §2, unchanged in method

Input: `UNZONED_gate1_patch_series.npy`. **No new extraction.** This arm uses `veg_p05_spatial` and
must not be moved onto the temporal metric.

**4.1 · Per patch.** Regress annual `veg_p05_spatial` on annual `inund_pct` across the patch's water
years. Report the slope distribution — min, quartiles, max, and the **share positive** — overall and
by vegetation community.

**4.2 · Pooled within estimator.** Demean both axes by patch, then fit pixel-weighted. This is the
quantity that compares to **+0.1613**.

**4.3 · Interval.** Clustered bootstrap, 2,000 and 10,000 draws. **There is no paddock here, so the
cluster is the patch.** State that on the output, and state that it differs from the real-part
estimate, which clusters on `zone_fid`. **Do not silently substitute a cluster.**

**4.4 · Serial correlation.** On the real parts, residual lag-1 autocorrelation median **+0.364**,
giving an effective n of about **16 of 35 years**. Report the same for the patches. Then refit the
pooled within estimator with an AR(1) error structure
(`nlme::gls`, `correlation = corAR1(form = ~ water_year | patch_id)`) and report both.
**Expect the interval to widen and the point estimate to hold. If the point estimate moves
materially, that is a finding and it stops for review.**

**4.5 · Pre-registered predictions, recorded before the fits are seen.** On the real parts, the
between-part and within-part community orderings invert:

| | between-part slope | within-part median |
|---|---:|---:|
| Aeolian Chenopod | −0.309 (spans zero) | **+0.350** |
| Riverine Chenopod | +0.348 (spans zero) | +0.218 |
| Inland Floodplain | +0.285 (excludes zero) | +0.140 |

If the response generalises, expect a pooled within slope near **+0.16**, a community ordering of
**Aeolian > Riverine > Inland**, and **close to 100% of patches positive**. Report what you find
against each of the three. **Predictions to check, not targets. No result is adjusted toward them.**

**4.6 · Between-unit prediction — secondary.** v2 §§4.1–4.4 run as written, on the spatial floor,
against both registered lines, all-patches and size-matched, with the community breakdown. The
pre-registered pooled offset is **+2.4 pp**, Inland near zero. v2 §2.3 rule 3 stands and is expected
to trigger — the real Inland IQR is 4,101–13,332 cells against an unzoned Inland Q3 of 1,825.
**Report the surviving count and do not fit fewer than ten.**

---

## 5 · What this must never say

**The within and between slopes are not two estimates of one number**, and never appear as a
comparison of accuracy. +0.161 and +0.547 answer different questions: how ground responds to water
over time, and how places differ from each other in the long run. Any sentence implying one corrects
the other is wrong. **Every figure and table carries which estimator produced its slope, on its
face.**

**The two floor metrics never appear in one figure or one table column pair**, and any output using
both across arms names which metric each number came from.

**No management claim.** This is standard-grazing country, but so is other ground, and nothing here
compares grazing regimes. It is a test of whether a fitted relationship generalises.

**No condition claim.** A residual is a departure from a fitted expectation. It is not condition and
it is not management.

**Do not call it a reference, a control, or unmanaged** (§2).

**Do not merge these patches with PARTSCATTER's 100 parts** in any table, figure or fit without the
unit construction stated on the face of it.

**Do not adjust any residual or offset for size** in either arm. The size figures are an expectation
to read against, never a correction to apply.

**No p-values anywhere.** Report slope, r, residual SD, share positive, and bootstrap quantiles.

---

## 6 · Outputs

- `UNZONED_patch_summary.csv` — one row per patch: id, vegetation community, n_cells, area_ha,
  n_components, **both** floor metrics named distinctly, mean water, within-patch slope, descriptive
  offset against the PARTSCATTER smoother, residual against each registered spatial line, support
  flags for each of the three rules.
- `UNZONED_regression_coefficients.csv` — every fit, with estimator (**within or between, named**),
  metric, weighting, subset, community, n and bootstrap interval, in the PARTREG coefficient-table
  schema so the tables can be stacked.
- `UNZONED_patches_epsg8058.gpkg` — patch polygons with the attribute table joined.
- Figures A1 and A2, registered through `gayini_write_and_register_figure()` in one transaction.
- **A data dictionary** on the PARTREG pattern: every column, its units, its support, its metric, its
  period. One page. This is the item that made the PARTREG pack handoverable.
- A findings note carrying every pre-registered prediction — §1.1's size-robustness fork, §4.5's
  three orderings, §4.6's +2.4 pp — against what actually happened.

**Write-up order in the findings note: Arm B first, Arm A second.** Arm A is the cheaper run and the
more legible figure; Arm B is the stronger test. The order of execution is not the order of argument.

**Every output carries its support level, its metric, its unit construction, its selection rule and
its period inside the file, not only in the filename.** Manifest and checksums on the PARTREG
pattern; **every table a findings note asserts from must be in the manifest**, including the
community-slope coefficients — the PARTREG pack omitted exactly that and it must not repeat here.

---

## 7 · Gates

**Arm A runs to completion and reports once.** No gate: it is descriptive, produces no registered
coefficient, and its one real fork (§1.1) carries a pre-registered rule.

**One STOP after Arm B §§4.1–4.5**, before §4.6. Report the slope distribution, the pooled within
estimate with both intervals, the AR(1) refit, and the three pre-registered predictions against what
happened. §4.6 then runs to completion and reports once.

**Ruling EB** — if another session is live on this repository, perform no git operation: write to
disk and stop. Committing falls to the session that is alone on the repo.

**Cultural sensitivity:** place and vegetation community names follow existing report-stream usage
exactly; introduce no new naming. Flag anything uncertain rather than deciding it.

---

## 8 · Ruling texts in force

Reject any citation of a ruling number for which you hold no issued text.

**AZ / CX** — `mean_flood` is the share of a unit's cells seen wet, mean over years. It is never
labelled a between-year frequency. AZ beats any conflicting spec.

**BB** — `Output/diag/*`, `Output/runs/*.md` and named tables are version-controlled for citability.
Un-ignore lines are targeted and verified with `git check-ignore -v`.

**CZ** — `number_id` at the point of quotation, not per table row.

**DA** — never "monotone in every community". Describe each community's own supported range.

**DB** — 795,602 of 988,831 non-treed cells are inside a management zone. The unit table and the
community table describe different populations and neither may stand in for the other.

**DP** — every run writes `Output/runs/RUN_<TASK>_<DATE>.md` in the fixed schema: decisions needed,
checks, overrides, disagreements, artefacts, not done, rulings.

**DS** — any edit containing an escape, a newline, or a multi-line string goes through a file, never
a shell heredoc. Parse-check before rendering.

**EA** — internal identifiers do not appear on client-facing figure faces. This covers issue codes,
ruling letters, `number_id`, `fit_id`, and repository paths.

**EB** — a session running concurrently with another on the same repository performs no git
operation: no add, no commit, no `.gitignore` edit, no un-ignore. It writes its output to disk and
stops there. Version-controlling those artefacts falls to the session that holds the repository, once
it is the only one holding it.

**EC** — every axis label on a client-facing figure names the quantity, the population it is computed
over, and the time step. No abbreviation of the quantity, no formula fragment in a parenthetical, and
no evaluative or interpretive wording. Where the full statement does not fit on the axis, the axis
carries the quantity and the subtitle carries population and time step, in the same words on every
figure showing that quantity. The same quantity is labelled identically across every product. A
figure that cannot be labelled precisely is not shipped until it can.

**EH** — a per-community smoother is fitted only where the community's central 10th–90th percentile
of the water axis spans a usable range; min-to-max does not qualify a fit. Both measures are retained
as columns so any exclusion is auditable. A range statistic that one point can fabricate is not a
test of range.

**EJ** — where a visual channel's direction carries meaning, the producer asserts the direction on
the built plot, not on the source. A correlation assertion alone is insufficient; the endpoints and
the mark-to-legend pairing are separate failures and need separate assertions.

**L-01** — units within a shared parent are not independent; intervals over them are display only.

**C10** — plot support and pixel support are both correct at different scales and must never be mixed
in one figure.

**I-40** — recording a decision is not executing it; asserting a fact is not verifying it.

**I-42** — a check that errors is not a check that catches. A construction assertion must be shown
able to fail on a deliberately corrupted fixture.
