# CC spec TEMPORAL-1 — the same analysis on the temporal metric

**Design seat · 7 August 2026. Priority task.** Adrian has reviewed the schematic and is not
confident presenting the current cover metric on 10 August. This runs the identical analysis on the
metric he would have built himself.

**Ruling AX is suspended for this task only.** Five gates below. The reason is time, not doubt: a
wrong assumption discovered at the end costs the weekend, and one of the gates guards a defect that
would silently invert the headline result.

**Additive only. Nothing existing is replaced, edited, deleted or re-run.** Every output is a new
file in a new namespace. `Output/pack/**` is unwritable by policy and nothing here needs it.

---

## 0 · What the disagreement actually is

**Water — no disagreement, and this is provable.** Adrian's quantity is per-cell flood frequency:
wet years ÷ valid years per cell, then averaged over cells. Ours is `flood_frac_pct`: wet cells ÷
valid cells within a year, then averaged over years. **With a constant denominator these commute**,
and the inundation record establishes the denominator is constant — the valid layer holds only 1 and
255, no zeros, and `valid_pixels` equals the unit's non-treed cell count in 2,240 of 2,240
zone-years. **Gate 1 proves this numerically or finds that it doesn't hold.**

**Cover — a real difference.** Ours takes the 5th percentile *across cells within a year*, then
averages over years: *how bad is the worst ground here, this year.* His takes a percentile *across
years within a cell*, then averages over cells: *how low does this ground fall in its bad years.*
Different operators, different order, genuinely different quantities.

**His version is more robust to unit size than ours.** Parts run from 33 to 32,399 cells. A 5th
percentile of 33 cells is near-enough the second-lowest value — the `quantile(type = 7)` exposure the
ground-cover record lists as unexamined and consequential at small n. A per-cell temporal percentile
*averaged* over cells is stable at any unit size. **This is not a concession; it is true, and the
report should say so.**

---

## 1 · Namespace and naming

```
Output/temporal/
  TEMPORAL1_findings.md
  rasters/
    total_veg_annual_p05_temporal_8058.tif     new
    total_veg_annual_p50_temporal_8058.tif     new
    annual_valid_years_count_8058.tif          the support count, new
  tables/
    TEMPORAL1_gate1_water_reconciliation.csv
    TEMPORAL1_part_metrics.csv
    TEMPORAL1_regression_coefficients.csv
    TEMPORAL1_part_residuals.csv
    TEMPORAL1_metric_comparison.csv
    TEMPORAL1_inputs.csv
    TEMPORAL1_manifest.csv
  figures/
```

**Suffix every new quantity `_temporal`.** `veg_p05_temporal_annual`, `veg_p50_temporal_annual`.
**Never `veg_p05` unqualified** — that name already collides between the spatial floor and the
census temporal percentile, and this task adds a third member to the set.

Add `Output/temporal/*.md` and `Output/temporal/*.csv` to the un-ignore list under Ruling BB.

DIAG-1's manifest discipline: every table carries support level, unit, period, weighting and
**estimand** as columns; the manifest fails the run if one is missing.

---

## 2 · Gate 1 · The water reconciliation — run in parallel, do not wait on it

**Ordering, amended.** Run this **alongside Gate 2, not before it.** Nothing in the cover chain reads
its result, and the cover chain is the urgent one — Adrian's concern is entirely the cover axis; he
asked for the flood raster to make example maps, not because he queried the water metric.

**Its halt condition still stands.** If the two constructions disagree by more than rounding, stop
everything: the denominator is not behaving as the inundation record says, and that is a larger
finding than this task. But a *passing* Gate 1 does not need to be waited on.

Compute, per part, **Adrian's construction**: for each census cell, wet years ÷ valid years across
the 35 annual layers; then the unweighted mean of that over the part's cells.

Compare against the existing `whole_record__inund_mean` in `PARTREG_part_residuals.csv`.

Report **max absolute difference, mean absolute difference, and the correlation across all 115
parts**, into `TEMPORAL1_gate1_water_reconciliation.csv`.

**Expected: differences at rounding scale.** The inundation record notes a 4-dp storage asymmetry
worth up to 5 × 10⁻⁵.

**STOP and report the numbers.** If they agree, that is a one-line message to Adrian today and the
water axis needs no further work. **If they do not agree, stop entirely** — the denominator is not
behaving as the record says, and that is a larger finding than this task.

---

## 3 · Gate 2 · Build the temporal rasters — and the trap that must not be walked into

From `total_veg_annual_mean_8058.tif`, 35 bands, on the census grid. Per cell, across the 35 annual
values: **p05 and p50**, `quantile(type = 7)`, `na.rm = TRUE`.

### 3.1 · The open-water problem — read this before writing code

**`MIN_SEASONS = 50` on the existing percentile rasters does two jobs, and the second one is the
one that matters here.** The decisions register: it *"does two jobs — makes p05 a true percentile
**and** excludes open water."*

**A temporal percentile across 35 annual layers has no equivalent rule unless one is written.**
Permanently-wet cells — river channel, lagoons, the Nimmie-Caira watercourses — carry near-zero
cover in every year. Their temporal p05 is near zero and it is *real*, not missing.

**Those cells sit disproportionately in the wettest parts.** Admit them and the wettest parts acquire
artificially low floors, which would **flatten or invert the headline relationship**. The result
would look like a substantive disagreement with the spatial metric and would be an artefact of a
missing exclusion.

**Required.** Apply the same open-water exclusion the existing percentile rasters achieve. Read
`02_build_total_veg_percentile_rasters.R` and reproduce its effective exclusion rather than inventing
one. Report **how many census cells it removes, and their distribution across the three
communities** — if the removal is concentrated in Inland Floodplain, that is the trap confirmed and
worth stating.

### 3.2 · The support rule

A minimum of **25 of 35 years** non-NA per cell, mirroring the part-grain rule already in use. Emit
`annual_valid_years_count_8058.tif` so the support surface is inspectable, and report the cell count
excluded.

**STOP.** Report: cells excluded by open water, cells excluded by support, cells surviving, and the
three community counts against the record's 13,078 / 50,791 / 129,360.

---

## 4 · Gate 3 · Extract to parts

For each of the 118 parts, the **unweighted mean over its cells** of the per-cell temporal p05, and
separately of the per-cell temporal p50.

**Unweighted over cells is correct here** and differs from the spatial chain — every cell contributes
one value, there is no within-year percentile to weight. Say so on the output.

`TEMPORAL1_part_metrics.csv`: `part_id`, `zone_fid`, community, `n_pixels_part`, `n_cells_used`,
`veg_p05_temporal_annual`, `veg_p50_temporal_annual`, and the Gate 1 water value.

**Support parity.** Use the same 115-part admissible set as PARTREG so the two runs are comparable.
Report the three excluded parts and whether they would qualify under this metric.

**STOP.** Report the 115 values' range, and a scatter of `veg_p05_temporal_annual` against the
existing `whole_record__floor_mean`, with the correlation. **This is the first sight of whether the
two metrics describe the same country.**

---

## 5 · Gate 4 · The regressions — identical pipeline, new y

Run the **existing PARTREG Stage 2 procedure unchanged**, substituting the y variable. Weighted OLS,
pixel-weighted by part cell count, clustered on `zone_fid`, 2,000 bootstrap draws, percentile method,
seed recorded. **Do not re-derive the procedure — call the same `R/gayini_fit.R` path.**

Four fits per metric, both metrics:

| fit | y |
|---|---|
| pooled, 115 parts | `veg_p05_temporal_annual`, then `veg_p50_temporal_annual` |
| Aeolian · Riverine · Inland | each metric |

`TEMPORAL1_regression_coefficients.csv`, same columns as `PARTREG_part_regression_coefficients.csv`
plus a `metric` column. `interval_conditionality` under Ruling AW.

**STOP.** Report the pooled slope and interval for each metric against the registered +0.5473
[+0.360, +0.750].

---

## 6 · Gate 5 · The comparison that decides what Adrian presents

`TEMPORAL1_metric_comparison.csv` — one row per part, all three metrics, both residual sets.

Three numbers decide it:

| | |
|---|---|
| **slope agreement** | temporal against spatial, with intervals |
| **ranking agreement** | **Spearman between residual rankings.** Do the same parts sit below expectation? |
| **the worst three** | are they the same parts in the same order? Spatial gives Bala 29ca Aeolian, Bala 29ca Riverine, Bala 26ca Inland |

**If the rankings agree, the finding survives a change of metric and that is the strongest result
available** — Adrian presents the version he would have built, and the other stands as robustness.

**If they disagree, that is more important than either fit**, it must lead the report, and no figure
from either metric should be presented on Monday without saying so.

**Two figures**, on the existing producers' pattern: the three-periods scatter equivalent for the
temporal metric, and the residual map. **Own colour scale, not the pack's ±32.3633** — different
metric, different scale, and the caption says so.

---

## 7 · What the temporal metric cannot do — state this plainly in the findings

**It collapses time, so there is no annual series.** A per-cell temporal percentile yields **one
value per part for the whole record**.

- **WITHIN-1 is not reproducible on it.** There is no within-unit response to estimate, and the
  saturation result — 115/115 positive, replicating 91/91 out of sample — has no temporal-metric
  equivalent.
- **ANNUAL-1 is not reproducible on it.**
- **Periods are possible but degrade.** Computing the temporal percentile within the cropping era
  (26 years) is sound; within post-management (**5 years**) the p05 is essentially the minimum of
  five values. **Compute p50 by period; do not compute p05 by period**, and say why.

**This is the honest trade.** The temporal metric is more robust to unit size and matches Adrian's
practice; the spatial metric supports estimands the temporal one cannot. **Both are correct
measurements of different things** and the report says so without ranking them.

---

## 8 · The report

**Lead with cover.** Adrian's concern is the cover axis; the water reconciliation confirms something
he did not query and belongs near the end.

1. **The three metrics side by side at part level** — the first sight of whether they describe the
   same country
2. **The ranking agreement — the number that matters most**
3. The four fits per metric against the registered line
4. The open-water exclusion: cells removed and where
5. §7's limits, stated as a trade rather than a defence
6. What would need to change downstream if the temporal metric became primary
7. **Gate 1's water reconciliation**, as a footnote confirming the water axis is arithmetically his
   own construction

**No registration. No p-values. Nothing existing modified.**
