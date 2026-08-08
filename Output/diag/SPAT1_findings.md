# SPAT-1 — is there spatial dependence the paddock cluster does not absorb?

**As of 8 August 2026.** Commissioned by the design seat, 7 August, off DIAG-1 §8.2.
Estimation in R under Ruling AS; run to completion without gates under Ruling AX.

**Registers nothing. Proposes nothing. Changes no published number.** The remedy — a
spatial block bootstrap replacing the paddock bootstrap — **is a design-seat decision
and is not implemented here.**

**No p-value is computed.** The permutation distribution is reported as a distribution,
and the observed value's standardised distance from its mean is an effect size, not a
test. No threshold is applied and no result is called significant.

---

## 1 · The answer

**Yes. Residual dependence reaches past the paddock, in every period, under both weight
definitions. The effective number of independent units is below 64.**

The sharp test excludes within-paddock pairs. Two parts of one paddock are neighbours by
construction — they were cut from the same polygon and the bootstrap already treats them
as a single unit — so a Moran's I over all pairs would find that and report it as a
discovery. Only the cross-paddock number answers the question that was asked.

| weights | response | n | Moran's I | perm. mean | SD from mean |
|---|---|---:|---:|---:|---:|
| shares a boundary, **cross-paddock only** | raw residual | 90 | **+0.2670** | −0.0113 | **2.68** |
| shares a boundary, cross-paddock only | residual_z_local | 90 | +0.1290 | −0.0109 | 1.34 |
| 1/distance, 10 km cutoff, **cross-paddock only** | raw residual | 115 | **+0.0988** | −0.0086 | **3.38** |
| 1/distance, cross-paddock only | residual_z_local | 115 | +0.0657 | −0.0086 | 2.32 |
| shares a boundary, all pairs | raw residual | 111 | +0.1520 | −0.0110 | 1.86 |
| 1/distance, all pairs | raw residual | 115 | +0.1270 | −0.0083 | 3.75 |

Whole record. 9,999 permutations. Full table including all three periods in
`SPAT1_morans_i.csv`.

**Excluding within-paddock pairs makes the adjacency statistic larger, not smaller**
(+0.152 → +0.267). Whatever this is, it is not the paddock showing through.

---

## 2 · It decays at about 4 km — roughly one paddock out

The correlogram is what answers "the distance at which it decays"; a single I over one
neighbour definition cannot.

| band | pairs | Moran's I (raw) | SD from mean | I (`residual_z_local`) |
|---|---:|---:|---:|---:|
| 0–2 km | 32 | **+0.3553** | +1.98 | +0.2317 |
| 2–4 km | 231 | **+0.1307** | +2.03 | +0.1085 |
| 4–6 km | 312 | +0.0458 | +0.89 | +0.0298 |
| 6–8 km | 394 | −0.0057 | +0.07 | +0.0009 |
| 8–10 km | 371 | +0.0682 | +1.48 | +0.1031 |
| 10–15 km | 1,028 | −0.0334 | −0.84 | −0.0334 |
| 15–20 km | 1,056 | **−0.1366** | **−4.27** | −0.1493 |
| 20–30 km | 1,626 | −0.0080 | +0.05 | −0.0370 |
| 30–60 km | 1,440 | +0.0464 | +2.01 | +0.0717 |

**The positive dependence is short-range: strong inside 2 km, halved by 2–4 km, gone by
4–6 km.** For scale, cross-paddock *adjacent* pairs have a median centroid separation of
3.4 km. The range is about the distance to a neighbouring paddock and no further.

**The 15–20 km band is strongly negative and should not be read as a second scale of
clustering.** A large negative I at intermediate-to-long range with a positive return at
the longest distances is the standard correlogram signature of a **broad gradient across
the property** — opposite ends differ systematically, so mid-range pairs straddle the
gradient and far pairs re-pair its two ends. It is one trend seen three times, not three
findings.

---

## 3 · About half the raw signal is the variance gradient, not the level — except recently

DIAG-1 established that residual spread runs 12.81 pp on the driest water quartile to
3.83 pp on the wettest (`cap_residual_sd_water_quartile_1` … `_4`, as of 7 Aug 2026).
Wetness on a floodplain is strongly spatially organised. **Moran's I on a raw residual
therefore cannot tell autocorrelation from a spatially patterned *variance*** — so
everything was run twice, on the raw residual and on DIAG-1's `residual_z_local`, which
divides each residual by the SD of its own wetness quartile.

| period | raw residual | `residual_z_local` |
|---|---:|---:|
| whole record | +0.2670 (2.68 SD) | +0.1290 (**1.34 SD**) |
| cropping era | +0.2428 (2.45 SD) | +0.1063 (**1.12 SD**) |
| post-management | +0.3726 (3.69 SD) | +0.3133 (**3.13 SD**) |

Cross-paddock adjacency. **For the whole record and the cropping era, standardising
locally roughly halves the statistic** — so a substantial part of what the raw number
picks up is the spatially organised variance, not correlation in the level.

**Post-management is different: the signal survives standardisation almost intact.** In
2018–2022 the dependence is in the residual's level, not its spread. That period is five
years and the least reliable of the three, so it is flagged rather than interpreted.

**Under the inverse-distance weights the signal survives standardisation in every
period** (2.32 / 2.56 / 4.25 SD). So local standardisation attenuates the finding; it
does not remove it.

---

## 4 · What it means for the intervals

**Every interval the project reports on between-unit quantities is too narrow**, because
the paddock bootstrap resamples 64 units that are not 64 independent pieces of
information. How much too narrow is not estimated here — that requires choosing the
remedy, which is the design seat's.

**One clarification on scope, because the commission named "the registered one".** No
bootstrap interval is registered in `dim_headline_number`. The slope rows —
`partreg_s1_slope_115parts`, `partreg_s2_slope_cropping_era`,
`partreg_s2_slope_post_management`, `floor_flood_slope_64pdk` — pin a point value and
carry a `spread` that is an **alternative-definition range** (weighted against
unweighted), not a sampling interval. The bootstrap intervals live in
`PARTREG_S2_regression_coefficients.csv` (`boot_slope_p2_5` / `_p50` / `_p97_5`,
`boot_cluster = zone_fid`) and in the shipped pack. **So the exposure is real and applies
to every reported interval, but it does not touch a registered value**: the registry pins
points, not intervals.

**The within-unit intervals are a separate question and are not addressed here.** SPAT-1
tested between-unit residuals only.

### Sizing input, offered without a recommendation

If blocks were formed at the observed range, this is what they would contain
(`SPAT1_scale_reference.csv`):

| radius | mean other paddocks within | median | max | paddocks with none |
|---|---:|---:|---:|---:|
| 2 km | 0.3 | 0 | 2 | 45 |
| 3 km | 1.1 | 1 | 4 | 21 |
| **4 km** | **2.8** | **2** | **7** | **3** |
| 5 km | 4.2 | 4 | 10 | 0 |
| 6 km | 6.0 | 6 | 12 | 0 |

At the ~4 km range the correlogram indicates, a paddock has a median of 2 neighbours
inside it. **That is the scale of the problem: units of roughly 3 paddocks rather than
1, so on the order of 20–25 effective clusters rather than 64.** That arithmetic is
offered as an order of magnitude to judge whether the remedy is worth building, not as a
result — grouping rules, overlap and edge handling all change it.

---

## 5 · Method, stated so it can be disagreed with

- **Units.** 115 parts, whole-record between-unit residuals from
  `DIAG1_between_pointwise.csv`, which reproduce the shipped residuals to 9×10⁻¹⁴ pp.
- **Weights, definition 1.** Polygon adjacency: two parts are neighbours if their
  geometries intersect after a **1 m buffer**. Raster-derived polygons rarely touch
  exactly; 1 m on a 24.970268 m grid is well under one cell and cannot join parts that
  are genuinely apart. 163 adjacent pairs, of which **110 are cross-paddock**.
- **Weights, definition 2.** Inverse centroid distance, `1/d`, with a **10 km cutoff**.
- Both row-standardised **after** masking, so a part whose only neighbours were inside
  its own paddock ends with an empty row and is **dropped rather than silently
  contributing zero to the numerator against a full denominator**. Under cross-paddock
  adjacency that drops 25 parts, leaving 90; the count is on every output row.
- **Permutation.** The same residuals reassigned to different locations, 9,999 times
  (1,999 for the correlogram bands). Reported as mean, SD, and 2.5/50/97.5 percentiles.
- **Four parts have no adjacency neighbour at all** — `27_inland`, `27_riverine`,
  `30_inland`, `31_aeolian` — and are dropped from the adjacency statistics only.

### The statistic itself was verified, because nothing here reproduces a prior number

SPAT-1 measures something no earlier task measured, so there is no design-seat figure to
check against. That is not a reason to ship an unverified estimator. Three checks
(`SPAT1_checks.csv`):

1. **An independent code path.** The same I computed by an explicit double loop over
   pairs agrees with the matrix form to **1.1×10⁻¹⁶**. Same discipline as `gayini_fit`
   cross-checking its hand-computed slope against `coef(lm())`.
2. **The permutation mean lands on its known expectation.** −0.01128 observed against
   −1/(m−1) = −0.01124.
3. **A fixture that moves the value.** The 110 links were rewired at random — same
   residuals, same number of links, no real geography. **Moran's I collapses from
   +0.2670 (2.68 SD) to −0.0043 (0.09 SD).** The statistic is responding to where the
   parts actually are, not to the residuals alone. Had it stayed high the run would have
   halted with the finding withdrawn.

**What would make this wrong.** If the residual field carries a smooth broad-scale trend
(§2 suggests it does), a short-range positive I can be induced by that trend alone rather
than by local dependence. Distinguishing them needs a model with the trend removed, which
is a different task. The finding is robust to weight definition and to local
standardisation under inverse distance; it is **not** robust to that alternative
explanation, and that is stated rather than left out.

---

## 6 · Outputs

| file | what |
|---|---|
| `SPAT1_findings.md` | this document |
| `SPAT1_morans_i.csv` | 24 rows: 4 weight schemes × 2 responses × 3 periods |
| `SPAT1_correlogram.csv` | 18 rows: 9 distance bands × 2 responses |
| `SPAT1_scale_reference.csv` | paddocks within a radius, for sizing a block |
| `SPAT1_inputs.csv` | inputs and boundary files with first-50-MB SHA-256 |
| `analysis/SPAT1_part_centroids.csv` | 115 centroids, EPSG:8058 |
| `analysis/SPAT1_pairs.csv` | 6,555 pairs with distance, adjacency, same-paddock flag |
| `figures/SPAT1_F1_correlogram_and_moran.png` | correlogram, permutation distribution, Moran scatter |
| `figures/SPAT1_F2_residual_map_with_links.png` | the 110 cross-paddock links, drawn by contribution to I |

**Producers.** `scripts/14_diag/SPAT1_prepare.py` (geometry; no estimation) →
`R/diag/SPAT1_moran.R` (all estimation) → `scripts/14_diag/SPAT1_figures.py` (drawing
only).

**One incidental finding, recorded because it will be met again.** The part polygons in
`PARTREG_part_residuals.gpkg` are **undissolved cell-level geometry** — 115 parts explode
to **503,084 rings**. Adjacency and centroids come out correctly and the analysis is
unaffected, but any choropleth of that layer renders every part in one flat tone and
takes minutes. F2 is drawn as a graph for that reason. Worth dissolving before the layer
is used for a map again.
