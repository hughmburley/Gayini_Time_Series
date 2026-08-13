# CC spec UNZONED — the standard-grazing country as an out-of-sample test

**Design seat · 6 August 2026.** Follows PARTREG Stages 1 and 2, which are sealed at
`Output/pack/PARTREG/`.

**Log and keep moving.** This is proof-of-concept work for the article, not a 10 August
deliverable. Anything unexpected is recorded in the run report and the work continues. **The only
condition that stops a run is a quantity that will not reproduce.**

---

## 1 · What this is, and what it is not

**12,048 ha of the property carries a vegetation-community label and 35 years of cover and water,
and has never been used in any fit.** It is excluded from every analysis so far for one reason: no
management zone was drawn over it, so there was no polygon to aggregate it to.

**It is not a reference set.** This is the standard-grazing — set-stocking — country. All fifteen
standard-grazing monitoring plots sit here, and the UNSW annual report describes set stocking as a
designed, replicated treatment arm rather than absence of management. **Any wording that calls this
land unmanaged, ungrazed or a control is wrong and must not appear in an output.**

**It is an out-of-sample test.** Every result the project holds — the registered expectation line,
the residuals, the part-grain slope — was fitted on the 57.7% of the property inside paddocks. This
ground touched none of it. **Predicting it is the first genuine test of whether the relationship
generalises.**

It also matters for a second reason: the standard-grazing arm has never been reported at anything
above plot support, precisely because it has no paddock to belong to. Figure 26 infers it from the
absence of a rotational zone. **This measures it directly.**

---

## 2 · Building the units

### 2.1 The mask

Non-treed census cells outside every management zone:

```
census non-treed  (treed_context_flag = 0 AND regime_band <> 'context')
  AND NOT inside management_zones_epsg8058
```

**Expected: 193,229 cells, 12,048 ha.** Design-seat count from `veg_regime_class_8058.tif` against
the zone layer. **Report your figure; if it differs, report both and continue.**

By community, expected: Aeolian 13,078 cells (815 ha) · Riverine 50,791 (3,167 ha) · Inland 129,360
(8,066 ha).

### 2.2 The unit

**Contiguous patches, cut by community.** Label connected components within each community
separately, so a patch is one community's contiguous ground — the same construction as a
paddock × community part, with contiguity standing in for the fence.

**Keep patches of 33 cells or more** — the smallest supported real part, so the two sets share a
support floor.

**Expected: 93 patches** — Aeolian 13, Riverine 25, Inland 55. Report your counts.

### 2.3 · The size problem — read this before choosing anything

**The y-axis is a percentile across a unit's cells, so it depends on unit size.** A 5th percentile
over 31,750 cells is not the same quantity as one over 95 cells. The unzoned patches have a median
of 533 cells against real parts running 33 to 32,399 with a much higher median.

**If the two sets differ systematically in size, the comparison measures unit size rather than
country.**

Required, in this order:

1. **Report both size distributions** — min, median, max, quartiles, for real parts and unzoned
   patches, overall and by community.
2. **Report the fit on all 93 patches.**
3. **Report the fit on the size-matched subset** — patches whose cell count falls inside the real
   parts' interquartile range. State how many survive.
4. **If the two fits differ materially, the size-matched one is the answer** and the difference is
   itself the finding. Report both either way.

**Do not pool the two sets into one regression.** They are different unit constructions and pooling
them would bury exactly the problem this section exists to surface.

---

## 3 · The two axes — identical construction to PARTREG

Per patch, per water year:

| axis | quantity |
|---|---|
| **y** | 5th percentile of total vegetation cover **across the patch's cells, within that water year** — the spatial floor, `veg_p05_spatial` construction |
| **x** | share of the patch's cells seen wet that year — `flood_frac_pct` construction |

Then average across years, whole record 1988–2022.

**The spatial floor, not the census temporal `veg_p05`.** They differ by up to 17 points at fine
grain and are never compared.

**Assert the construction against PARTREG.** Recompute one real part's series through this new code
path and check it against the stored `fact_zone_community_veg_annual` value. **If it does not match
to floating-point tolerance, stop** — that is a quantity that will not reproduce, and it is the one
condition that halts this run.

---

## 4 · The test — predict, do not refit

**4.1 · Apply the registered line.** `predicted = 52.652934 + 0.547838 × mean_flood`, read from
`dim_headline_number` and not refitted. Compute each patch's residual against it.

**Report:** mean residual, median, SD, and the distribution by community. **A mean near zero means
the relationship generalises to ground outside the management system.**

**4.2 · Then, separately, fit a line to the 93 patches** and report slope, intercept, r and residual
SD. **This is a description of the unzoned ground, not a replacement for the registered line, and
the output must say so.** Bootstrap by resampling patches with replacement, 2,000 draws — there is
no paddock to cluster on here, and that difference from PARTREG's clustering is worth stating on the
output.

**4.3 · Compare the two slopes** — unzoned patches against the 115 real parts. Report both with
their intervals. **Overlapping intervals is a result; do not read a difference into an overlap.**

**4.4 · By community.** The PARTREG finding is that all three community slopes sit below the pooled
slope, so the pooled line is steepened by between-community differences. **Report whether the same
pattern holds on this independent set.** If it does, that is strong corroboration of a finding
currently resting on one sample.

---

## 5 · Outputs

- `UNZONED_patch_summary.csv` — one row per patch: id, community, n_cells, area_ha, mean floor,
  mean water, across-year spread on both, predicted floor, residual, size-matched flag
- `UNZONED_regression_coefficients.csv` — every fit, with weighting, subset, community, n and
  bootstrap interval
- `UNZONED_patches_epsg8058.gpkg` — the patch polygons with the attribute table joined
- **One scatter**, unzoned patches against the registered line, coloured by community, with the 115
  real parts shown faintly behind for context. **Two symbols, clearly distinguished, never merged.**
- A short findings note

**Every output carries its support level, its unit construction and its period in the file, not only
in the filename.**

---

## 6 · What this must never say

**No management claim.** This ground is standard-grazing country, but so is other ground, and
nothing here compares grazing regimes. It is a test of whether a fitted relationship generalises.

**No condition claim.** A residual is a departure from a fitted expectation.

**Do not call it a reference, a control, or unmanaged.** If a label is needed, *"unzoned
standard-grazing country"* — the term the project already uses.

**Do not merge these patches with the 115 parts** in any table, figure or fit without the unit
construction stated on the face of it.

---

## 7 · Gate

**One STOP, after §3's assertion and §2.3's size distributions.** Report the patch counts, both size
distributions, and whether the construction check passed — before any fitting.

Everything after that runs to completion and reports once.
