# CC spec UNZONED v2 — the standard-grazing country as an out-of-sample test

**Design seat · 6 August 2026.** Supersedes `Gayini_CC_spec_UNZONED.md` (v1, same date).
Follows PARTREG Stages 1 and 2, sealed at `Output/pack/PARTREG/`.

**Log and keep moving.** Proof-of-concept work for the article, not a 10 August deliverable.
Anything unexpected is recorded in the run report and the work continues. **The only condition
that stops a run is a quantity that will not reproduce.**

**What changed from v1**, in order of consequence:

| | change | §|
|---|---|---|
| 1 | The size confound is **pre-registered as a number**, per community, from the 115 real parts | 2.3 |
| 2 | The support floor uses the **same rule** as the 115, not a cell-count threshold | 2.2 |
| 3 | **Contiguity** named as a second unit difference, with a comparable baseline | 2.4 |
| 4 | Residuals computed against **both** the 64-paddock and the 115-part line | 4.1 |
| 5 | **Stage B — the three eras** added, gated behind Stage A | 5 |
| 6 | Data dictionary added to the required outputs | 6 |

---

## 1 · What this is, and what it is not

**12,048 ha of the property carries a vegetation-community label and 35 years of cover and water,
and has never been used in any fit.** It is excluded from every analysis so far for one reason: no
management zone was drawn over it, so there was no polygon to aggregate it to.

**It is not a reference set.** This is standard-grazing — set-stocking — country. All fifteen
standard-grazing monitoring plots sit here, and the UNSW annual report describes set stocking as a
designed, replicated treatment arm rather than absence of management. **Any wording that calls this
land unmanaged, ungrazed or a control is wrong and must not appear in an output.**

**It is an out-of-sample test.** Every result the project holds — the registered expectation line,
the residuals, the part-grain slope — was fitted on the 57.7% of the property inside paddocks. This
ground touched none of it. **Predicting it is the first genuine test of whether the relationship
generalises.**

It matters for a second reason: the standard-grazing arm has never been reported above plot support,
precisely because it has no paddock to belong to. Figure 26 infers it from the absence of a
rotational zone. **This measures it directly.** Report how many of the 66 monitoring plots fall on
unzoned ground and how many of those are the fifteen standard-grazing plots — that is the join
between this analysis and the plot-support results, and it costs one spatial query.

---

## 2 · Building the units

### 2.1 · The mask

Non-treed census cells outside every management zone:

```
census non-treed  (treed_context_flag = 0 AND regime_band <> 'context')
  AND NOT inside management_zones_epsg8058
```

**Expected: 193,229 cells, 12,048 ha.** Design-seat count from `veg_regime_class_8058.tif` against
the zone layer. **Report your figure; if it differs, report both and continue.**

By community, expected: Aeolian 13,078 cells (815 ha) · Riverine 50,791 (3,167 ha) · Inland 129,360
(8,066 ha).

Reconciliation the run report must carry: 49,607 ha zoned non-treed + 12,048 ha unzoned non-treed =
61,655 ha non-treed, the SCHEM-1 ladder's third rung. **If that does not close, the mask is wrong
and everything below is wrong with it.**

### 2.2 · The unit, and the support rule

**Contiguous patches, cut by community.** Label connected components within each community
separately, so a patch is one community's contiguous ground.

**Support: the same rule that selected the 115 parts — at least 25 water years in which at least 30
valid cells could be seen.** *(v1 said "33 cells or more". That was the smallest observed real part,
not the rule that selected them. Applying a cell-count threshold to one set and a
years-and-valid-cells rule to the other applies different selection to the two sets and breaks the
comparison this spec exists to make.)*

**Report both**: how many patches the correct rule keeps, and how many a bare ≥33-cell threshold
would have kept. If those differ materially, say so — it is a fact about the unzoned ground's
observability, not a nuisance.

**v1's expectation was 93 patches** — Aeolian 13, Riverine 25, Inland 55, under the cell-count rule.
Under the correct rule the count will differ. Report your counts; the v1 figures are a prediction to
check, not a target.

### 2.3 · The size problem — pre-registered, not merely flagged

**The y-axis is a percentile across a unit's cells, so it depends on unit size.** A 5th percentile
over 31,750 cells is not the same quantity as one over 95.

**The 115 real parts, cell counts:**

| set | n | min | Q1 | median | Q3 | max |
|---|---:|---:|---:|---:|---:|---:|
| all parts | 115 | 33 | **1,100** | 4,486 | **11,100** | 32,399 |
| Aeolian | 17 | 33 | 157 | 1,894 | 5,730 | 16,554 |
| Riverine | 37 | 43 | 495 | 1,232 | 4,032 | 22,565 |
| Inland | 61 | 588 | 4,101 | 8,452 | 13,332 | 32,399 |

v1's stated unzoned median of 533 cells sits **below the real parts' first quartile**. Only 15 of
115 real parts are that small — five Aeolian, ten Riverine, **none Inland**.

**The size sensitivity, measured on the 115 whole-record residuals** (`PARTREG_part_residuals.csv`,
OLS of `whole_record__residual` on log₁₀ `n_pixels_part`):

| set | slope, pp per decade of size | r | n |
|---|---:|---:|---:|
| pooled | **−2.01** | −0.17 | 115 |
| Aeolian | −7.64 | −0.53 | 17 |
| Riverine | −4.41 | −0.31 | 37 |
| **Inland** | **−0.23** | **−0.02** | 61 |

**The pooled figure is mostly community composition, not size.** Within Inland — 8,066 of the 12,048
unzoned hectares, and the majority of the patches — the size sensitivity is indistinguishable from
zero. **The out-of-sample test is cleanest exactly where most of the unzoned ground is.** Aeolian is
where it bites, on 17 real parts, and any Aeolian result must carry that.

**These are design-seat numbers: predictions to check, not corrections to apply.** They are
confounded with wetness — small parts may be systematically drier — and the two steep slopes rest on
17 and 37 points. **No size adjustment is made to any residual anywhere in this task.** The numbers
exist so that a result can be read against an expectation fixed before it was seen.

**Pre-registered prediction, recorded before the run.** If the unzoned patches are 0.9 decades
smaller than the real parts at the median and size alone drives the difference, the pooled residual
mean lands near **+1.9 pp** and the Inland residual mean near **0.0**. **A pooled offset near +1.9
with an Inland offset near zero is the size artefact. A pooled offset near zero, or an Inland offset
materially away from zero, is not.**

**Required, in this order:**

1. **Report both size distributions** — min, quartiles, median, max — for real parts and unzoned
   patches, **overall and by community**.
2. **Report the fit on all supported patches.**
3. **Report the size-matched fit per community**, not pooled: patches whose cell count falls inside
   **that community's** real-part interquartile range. State how many survive in each. **If a
   community has fewer than 10 surviving patches, report the count and do not fit it** — say so
   rather than fitting six points.
4. **If the all-patches and size-matched fits differ materially, the size-matched one is the
   answer** and the difference is itself the finding. Report both either way.

**Do not pool the two sets into one regression.** Different unit constructions; pooling buries
exactly the problem this section exists to surface.

### 2.4 · Contiguity — the second unit difference

A fence permits a paddock × community part to be several disjoint blobs. Connected-component
labelling does not. **The two sets therefore differ in fragmentation as well as size**, and v1's
"contiguity standing in for the fence" overstates the equivalence.

**Report the number of connected components per real part.** If more than about a fifth of the 115
are multi-component, **the comparison baseline becomes the single-component real parts**, and both
baselines are reported. If almost all are single-component, one sentence closes it.

---

## 3 · The two axes — identical construction to PARTREG

Per patch, per water year:

| axis | quantity |
|---|---|
| **y** | 5th percentile of total vegetation cover **across the patch's cells, within that water year** — the spatial floor, `veg_p05_spatial` construction |
| **x** | share of the patch's cells seen wet that year — `flood_frac_pct` construction |

Then average across years, whole record 1988–2022, 35 water years.

**The spatial floor, not the census temporal `veg_p05`.** They differ by up to 17 points at fine
grain and are never compared.

**Assert the construction against PARTREG.** Recompute one real part's full series through this new
code path and check it against the stored `fact_zone_community_veg_annual` value. **If it does not
match to floating-point tolerance, stop** — that is a quantity that will not reproduce, and it is
the one condition that halts this run. **Assert on the recomputed series, not on the intent of the
code path**: the check must be able to fail on mutated input, and the run report must show it doing
so on a deliberately corrupted fixture.

---

## 4 · Stage A — the test · **STOP after this**

### 4.1 · Apply the fitted lines. Do not refit.

Compute each patch's residual against **both**:

| line | coefficients | why |
|---|---|---|
| registered 64-paddock | `52.652934 + 0.547838 × mean_flood` | continuity with every published residual |
| 115-part | `52.697196 + 0.547274 × mean_flood` | the closer unit grain |

Read both from `dim_headline_number` / `PARTREG_S2_regression_coefficients.csv`; **neither is
refitted.** They differ by 0.0005 in slope, so this costs one column and removes the objection that
a paddock-grain line was applied to sub-paddock units.

**Report:** mean residual, median, SD and the distribution **by community**, for each line, on the
all-patches set and on each size-matched community subset. **A mean near zero means the relationship
generalises to ground outside the management system.** Read it against §2.3's pre-registered
prediction.

### 4.2 · Then, separately, describe the unzoned ground

Fit a line to the supported patches and report slope, intercept, r and residual SD. **This is a
description of the unzoned ground, not a replacement for the registered line, and the output must
say so on its face.**

Bootstrap: resample patches with replacement, 2,000 draws. **There is no paddock to cluster on, and
that difference from PARTREG's `zone_fid` clustering must be stated on the output** — patches near
one another are not independent, so this interval is, if anything, too narrow. Name that; do not
attempt to fix it.

**No p-values anywhere.**

### 4.3 · Compare the two slopes

Unzoned patches against the 115 real parts. Report both with their intervals. The real-part interval
is [+0.360, +0.750] — **wide, and overlapping intervals is a result. Do not read a difference into
an overlap.**

### 4.4 · By community — the corroboration test

The PARTREG counter-finding is that **all three community slopes sit below the pooled slope**, so
the pooled line is steepened by between-community differences in level and wetness rather than
within-community response to water. That finding currently rests on one sample.

**Report whether the same pattern holds on this independent set.** If it does, a finding resting on
one sample now rests on two, with different unit constructions — which is worth more than either
alone. Report the pattern; propose nothing.

---

## 5 · Stage B — the three eras · runs only after Stage A is seen

**This is the reason the task is worth more than a generalisation check**, and it is gated because a
null in Stage A does not stop it but a broken construction does.

Same three windows as PARTREG, same exclusion:

| period | water years | n |
|---|---|---:|
| cropping era | 1988–2013 | 26 |
| post-management | 2018–2022 | **5** |
| whole record | 1988–2022 | 35 |

2014–2017 sits in none of them. Control passed to the Nari Nari Tribal Council in 2013; the
irrigation bank cuts are dated 2018.

**What this tests.** PARTREG found the relationship flatter after 2018 (+0.592 → +0.324, intervals
overlapping, reported not claimed). The hypothesis carried in `Gayini_PARTREG_findings.md` §6 is
that cover became *less tied to water* because the cuts put water onto ground that had not been
watered for decades. **If the same flattening appears on ground outside the management system, the
weather explanation is live and the hypothesis weakens. If it does not, the hypothesis survives a
test it has not yet had.**

**Three constraints on how this is written up:**

- **It is not a clean control.** Unzoned ground is interleaved with zoned ground and hydrologically
  connected to it; the cuts may water some of it. This discriminates against the
  regional-climate explanation. It does not establish the management one.
- **Five water years, again.** The same weakness as PARTREG, stated the same way.
- **Relationships only. Period levels are never compared.** A slope is robust to how wet a window
  happened to be because both axes move together; a mean is not.

**Residuals against each period's own line**, exactly as PARTREG. Same rank-direction convention:
`residual_rank_1_is_largest_shortfall`.

---

## 6 · Outputs

- `UNZONED_patch_summary.csv` — one row per patch: id, community, n_cells, area_ha, n_components,
  mean floor, mean water, across-year spread on both, predicted floor **against each of the two
  lines**, residual against each, size-matched flag, support-rule flag
- `UNZONED_regression_coefficients.csv` — every fit, with weighting, subset, community, n and
  bootstrap interval, in the PARTREG coefficient-table schema so the two can be stacked
- `UNZONED_patches_epsg8058.gpkg` — the patch polygons with the attribute table joined
- **One scatter** — unzoned patches against the registered line, coloured by community, with the 115
  real parts shown faintly behind. **Two symbols, clearly distinguished, never merged.** Marker area
  ∝ cell count, as on the PARTREG figures, so the size difference is visible rather than stated.
- **A data dictionary**, on the PARTREG pattern: every column, its units, its support, its period,
  one page. *(v1 omitted this. The PARTREG dictionary is the item that made that pack handoverable.)*
- A short findings note, carrying the §2.3 pre-registered prediction and what actually happened.

**Every output carries its support level, its unit construction, its selection rule and its period
in the file, not only in the filename.**

**Manifest and checksums** on the PARTREG pattern. Every table that a findings note asserts from
must be in the manifest — including the community-slope coefficients. *(The PARTREG pack asserts its
community counter-finding from `PARTREG_part_regression_coefficients.csv`, which is not in
`PARTREG_manifest.csv`. Do not repeat that here.)*

---

## 7 · What this must never say

**No management claim.** This ground is standard-grazing country, but so is other ground, and
nothing here compares grazing regimes. It is a test of whether a fitted relationship generalises.

**No condition claim.** A residual is a departure from a fitted expectation.

**Do not call it a reference, a control, or unmanaged.** If a label is needed: *"unzoned
standard-grazing country"* — the term the project already uses.

**Do not merge these patches with the 115 parts** in any table, figure or fit without the unit
construction stated on the face of it.

**Do not adjust any residual for size.** §2.3's numbers are an expectation to read against, never a
correction to apply.

---

## 8 · Gates

**Gate 1 · STOP.** After §2's counts and §3's reproduction assertion. Report: the mask
reconciliation to 61,655 ha, the patch counts under both selection rules, both size distributions
overall and by community, the component counts on the real parts, the plot-overlay count, and
whether the construction check passed **and whether it was shown able to fail**. No fitting before
this is seen.

**Gate 2 · STOP.** After Stage A (§4), before Stage B. Report all fits and the residual distributions
against §2.3's pre-registered prediction.

**Stage B (§5) then runs to completion and reports once.**
