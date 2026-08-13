# CC spec ANNUAL-1 — the relationship, year by year

**Design seat · 7 August 2026.** Post-deadline. Runs **after SPAT-1 and GLM-1**, not before.
Ruling AX: runs to completion, reports once. Ruling AS: all estimation in R.

**Registers nothing. Proposes nothing. Changes no published number.**

---

## 0 · The output namespace — settle this first

**Everything this task produces lives under `Output/annual/`**, and nothing it produces goes anywhere
else. The project already has `Output/pack/`, `Output/diag/`, `Output/glm/`, `Output/unzoned/`,
`Output/figures/`, `Output/tables/` and `Output/metadata/`, and a 35-year task is the one most likely
to spray files across them.

```
Output/annual/
  ANNUAL1_findings.md            the deliverable
  ANNUAL1_prereg.md              committed BEFORE fitting
  tables/
    ANNUAL1_year_fits.csv        one row per water year
    ANNUAL1_support_audit.csv    every year, admitted or excluded, with the reason
    ANNUAL1_part_year_residuals.csv
    ANNUAL1_slope_series_context.csv
    ANNUAL1_inputs.csv           every input with its first-50-MB SHA-256
    ANNUAL1_manifest.csv         files, sizes, checksums, the five-column audit
  figures/
    ANNUAL1_F1_slope_series.png
    ANNUAL1_F2_exemplar_maps.png
```

**Follow DIAG-1's manifest discipline exactly**: every table carries support level, unit, period,
weighting and **estimand** as columns, and the manifest fails the run if one does not. That audit
caught a missing-column defect on DIAG-1's first pass and it will catch one here.

**Add `Output/annual/*.md` and `Output/annual/*.csv` to the un-ignore list** under Ruling BB — this
document will be cited by METHODS-REG and a cited artefact must be in the repository. Figures stay
gitignored.

---

## 1 · The estimand — a third quantity, and it is never a version of the other two

| | question | unit | n |
|---|---|---|---|
| between-unit, registered | do wetter **places** carry higher floors, over the long run? | 115 parts, across-year means | 115 |
| within-unit, WITHIN-1 | does a place carry a higher floor in wetter **years**? | 4,025 part-years, unit FE | 4,025 |
| **annual cross-section, this task** | **in year *t*, do wetter parts carry higher floors?** | **115 parts, one year** | **115 × 35** |

**+0.547 and +0.161 are not comparable to any number this task produces**, and the mean of the 35
annual slopes is not the between-unit slope on means. Report the relationship between them once, as
a fact about the construction, and never as agreement or disagreement.

**Every table, every figure and every sentence carries `estimand = annual_cross_section`.** Given
this project's label-error history, that is the highest-risk failure available here.

---

## 2 · Pre-registration — commit before fitting

`ANNUAL1_prereg.md`, its own commit, hash reported, **before any model runs.**

### 2.1 · The support rule

Some years are degenerate. **WY2006 ran 0.0% property-wide inundation on the non-treed scope**; with
no variation on the water axis the slope is not identified, and a rule invented after seeing which
years look odd is not a rule.

Fix now, before fitting:

| | admitted if |
|---|---|
| **x range** | the interquartile range of `flood_frac_pct` across the 115 parts is **≥ 5 percentage points** in that year |
| **x mass** | at least **20 of 115 parts** exceed 5% wet |
| **completeness** | all 115 parts have a non-null floor and a non-null wetness that year — `fact_zone_community_veg_annual` is complete on `mean_of_seasons`, so this should never bind; **report it if it does** |

**Every year is listed in `ANNUAL1_support_audit.csv` with its statistics and its verdict, admitted
or not.** An excluded year is reported, never dropped silently. **The count of admitted years goes in
the findings document's first paragraph.**

### 2.2 · What is not done

**No trend is fitted to the 35 slopes.** F6 settled that variation across this record is episodic and
climate-paced, not directional; 35 non-independent points do not overturn it. The slopes are
described, not regressed.

**No p-value.** No test of whether any year's slope differs from any other's.

**No period comparison of levels.** The standing rule holds: relationships only.

**No GLM.** OLS in the first instance. **If GLM-1's P1 fails, the link choice would have been wrong
in 35 places rather than one** — that is why this runs second.

---

## 3 · The fits

For each admitted water year, weighted OLS across the 115 parts: floor that year on wetness that
year, pixel-weighted by part cell count, clustered on `zone_fid` for intervals.

`ANNUAL1_year_fits.csv`, one row per year: slope · intercept · r · weighted R² · residual SD ·
n parts · x range and IQR · property-scale wetness that year · bootstrap interval · cluster count ·
`interval_conditionality` under Ruling AW.

**Also fit within each community**, and report the x range each spans that year. Expect the chenopod
fits to be unidentified in most years — **that is the finding from DIAG-1 repeating annually, not a
new problem**, and it should be reported as consistency rather than as failure.

---

## 4 · The mechanism test — the reason this is worth doing

The findings note holds that **flooding compresses the conditional distribution** rather than lifting
typical cover: the p05→p50 gap roughly halves from rarely- to frequently-flooded pixels.

**That predicts the annual cross-sectional slope is flatter in wet years and steeper in dry ones.**
The current design cannot test it. This one can.

Report the annual slope against property-scale wetness that year — as a scatter with the years
labelled, and as a correlation. **State the prediction in `ANNUAL1_prereg.md` before fitting**, and
report the result whichever way it falls.

**Two competing readings to keep apart, and neither is to be assumed:**

- **compression** — in wet years everything's floor lifts, so the spatial gradient flattens
- **range** — in wet years the water axis simply spans more, and slope changes with leverage rather
  than with ecology

**These are separable.** Report the x range and the residual SD alongside each slope, and say which
reading the pattern supports, or that it cannot distinguish them.

---

## 5 · Figures — two, not thirty-five

**F1 · the slope series.** 35 points, one per admitted year, with intervals. Excluded years shown as
gaps with a note, not omitted. Property-scale wetness on a second panel beneath, same x axis, so the
co-variation in §4 is readable directly.

**F2 · three exemplar maps**, not thirty-five. **Chosen by a rule stated in the pre-registration**:
the driest admitted year, the wettest admitted year, and the year whose property wetness is closest
to the median. One common residual colour scale across all three, and it must be **this task's own
scale, not the pack's ±32.3633** — a different estimand gets a different scale, and the caption says
so.

**An atlas of 35 maps is not a deliverable.** If per-year residuals are wanted later they are in
`ANNUAL1_part_year_residuals.csv`.

---

## 6 · The literature this sits in

`ANNUAL1_findings.md` carries a short positioning section. The relevant family is **Residual Trend
Analysis (RESTREND)**, introduced by Evans & Geerken (2004) and reviewed for its limits by Wessels,
van den Bergh & Scholes (2012), *Remote Sensing of Environment* 125: 10–22.

**State the mapping honestly, because it is not the obvious one.** RESTREND fits the
vegetation–climate regression **per pixel over time** and then tests the residuals for trend — that
is the *within-unit* estimand, so the precedent is for WITHIN-1's shape, **not** for this task's
annual cross-sections. This task is a repeated cross-section, which is a different design.

**And record the criterion.** Wessels et al. (2012) suggest RESTREND is only valid where the
vegetation–climate relationship is strong, at **R² > 0.3**. Our within-unit R² is **0.174** linear
and **0.241** under the log form, with median per-part r of 0.443. **By the published standard for
this method family, most of our parts fall below the validity threshold.**

That is a caution, and it **independently supports the project's existing refusal to attribute cause
from residuals.** Carry it into METHODS-REG.

---

## 7 · The report

1. **The pre-registration commit hash**, the support rule, and the count of admitted years
2. **The slope series**, described — range, where the extremes sit, whether they are the years you
   would guess
3. **The mechanism test**, with compression and range kept apart
4. **The community fits**, including how many years each was unidentified in
5. **What this cannot show** — it is a between-unit quantity in every year, so it cannot identify a
   response in any of them
6. **The literature positioning**, including the R² > 0.3 criterion and that we fall below it

**Plain-language section leads.** Every registered value cited by `number_id`.
