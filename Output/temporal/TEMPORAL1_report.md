# TEMPORAL-1 completion — report

**8 August 2026.** Built to `docs/reference_update/Gayini_CC_spec_TEMPORAL1_completion.md`
under Rulings CS, CT, CV and the standing execution rule. Additive only.

**No instance was in flight.** `Output/temporal/` did not exist, no producer or output was
on disk, and no commit mentioned TEMPORAL-1. Clean start, nothing resumed.

---

## 1 · The reuse audit (spec §1)

| component | status |
|---|---|
| per-cell temporal percentiles | **reused** — `veg_p05` / `veg_p50` already columns in `gayini_pixel_census_8058.parquet` |
| cell → unit assignment | **reused** — `gayini_pixel_zone_assignment.parquet` |
| zonal aggregation | **reused** — a groupby on that join; no zonal-statistics machinery re-created |
| the X axis | **reused** — `v_zone_floor_flood_residual.mean_flood`, the published 64-paddock value |
| the scatter | **new y on an existing shape** |

**Nothing was built fresh** — against an allowance of two. **No raster was opened at any
point.** The census parquet already carries per-cell flood frequency counted from
`wet_years` / `valid_years`, so Ruling CS's fallback was never needed.

## 2 · The Y basis (spec §3) — SEASONAL, read from the code

`scripts/05_ground_cover/02_build_total_veg_percentile_rasters.R`:

- **Computed over 140 seasonal composites** — 4 per water year × 35 water years, asserted
  in the producer itself (`POOL ASSERT PASSED: 140 composites, 35 water years, 4 seasons
  each`), from 153 source composites on EPSG:3577 at 30 m.
- **`MIN_SEASONS <- 50L`**, and the code records the reasoning: p05 needs n ≥ 40 to be a
  percentile rather than the minimum, and at n = 50 it is the 2nd–3rd smallest value.
- **What it excludes, measured:** on the farm footprint **111 pixels of 959,944 (0.0116%)**
  fall below 50 valid seasons. Inside the non-treed census specifically, **exactly 2 cells
  of 988,831** lose their percentile — **Ruling BT reproduces exactly.**
- **Per-cell valid-season n, farm footprint:** min **5**, p05 107, median **118**, max
  **140**; 0.0269% of cells have the full 140.

**Ruling CT therefore governs and overrides §3.** §3 says draw on the annual basis; CT
says produce on the existing seasonal rasters, label every output explicitly, and defer
the annual build. **Every output carries a `y_basis` column stating the seasonal basis in
full.** The annual-basis rasters were not built.

**Flag for the design seat, per §3:** the shipped percentile figures and the client's
written description are on **different bases**. That correction needs an email and the
email is the design seat's to write.

## 3 · One pre-registered rule overridden

**§2 calls X "the published unit-level between-year flood frequency". It is not.**
`v_zone_floor_flood_residual.mean_flood` is the quantity behind
`figure_f5_cover_vs_water_64_paddocks`, and **Ruling AZ established what that is: the
share of the paddock's cells seen wet, mean over years (%)** — a within-year share
averaged across years, not a between-year frequency.

I used the published value, because §2 also requires point-by-point reconciliation
against the figure the client has already seen and forbids new water construction — both
of which the published value satisfies. **I labelled it per Ruling AZ, not per §2.** The
figure's x-axis and every table column say *share of the paddock's cells seen wet, mean
over years*.

## 4 · The four outputs

**1 · `TEMPORAL1_unit_level.csv`** — 64 paddocks, **0 NULLs**, with community shares,
published wetness, `veg_p05_temporal_mean`, `veg_p50_temporal_mean`, cell count, and the
five qualifiers as columns. Version-controlled under BB/CL.

**2 · `Output/figures/temporal/TEMPORAL1_paddock_temporal_p05_vs_water.png`** — registered
in one transaction, `figure_asset` **318**, checksum `eb68dd67657e`. 64 points, coloured
by dominant community, sized by cell count, pixel support throughout, no p-values. The
trend is a display smoother and no coefficient is taken from it.

**3 · `TEMPORAL1_reconciliation.csv`** — the 64 units with published wetness,
`veg_p05_spatial` and `veg_p05_temporal_mean` side by side. **Table only**, with the
prohibition restated in a column on every row.

**4 · `TEMPORAL1_community_by_floodbin.csv`** — 21 rows, per community × wet-year bin,
**bin edges as explicit columns** in whole years, with a `LOW SUPPORT` flag on the three
rows under 1,000 cells. No zone join.

**Companion (Ruling DD) · `TEMPORAL1_wet_end_sensitivity.csv`** — the k ≥ 25 rows
recomputed without near-permanent water. **Additive; the published rows are unchanged.**

### What the outputs say (wording per Ruling DA)

**The relationship is clear and monotone in Inland Floodplain, which carries 16,626
cells at the wet end. Riverine rises across its supported range. Aeolian is ragged, and
its wet end rests on 60 cells.** Per-cell temporal p05 by wet-year bin, with cell counts
beneath — because the counts are the reading:

| community | k=0 | 1–2 | 3–5 | 6–10 | 11–17 | 18–24 | ≥25 |
|---|---:|---:|---:|---:|---:|---:|---:|
| **Aeolian** | 44.7 | 44.7 | 46.5 | 53.5 | **52.7** | **47.6** | **69.3** |
| *n cells* | 46,530 | 15,545 | 8,300 | 4,447 | 2,151 | **511** | **60** |
| **Riverine** | 32.8 | 40.4 | 45.2 | 49.4 | 54.9 | 59.4 | **60.9** |
| *n cells* | 66,838 | 42,506 | 34,538 | 32,081 | 14,232 | 3,394 | **69** |
| **Inland** | 37.9 | 44.7 | 53.0 | 60.0 | 67.4 | 76.4 | 77.1 |
| *n cells* | 19,711 | 47,878 | 76,927 | 154,624 | 246,258 | 155,603 | 16,626 |

**Aeolian falls through k = 6–24 — 53.5 → 52.7 → 47.6 — before a 60-cell final bin lifts
it to 69.3.** Sixty cells is 3.7 ha; Riverine's top bin is 69 cells, 4.3 ha. Neither
supports a statement about wet Aeolian or wet Riverine country.

**Three of the 21 rows carry a `LOW SUPPORT` flag** (under 1,000 cells) with their area in
hectares, so the caveat travels in the table rather than only in this document.

**The two cover metrics differ substantially at unit level**: `veg_p05_temporal_mean`
minus published `veg_p05_spatial` runs **−24.21 to +10.53 pp, median −9.10**. They are
different metrics and the reconciliation table is the only place they meet.

**L-01 reproduces independently:** 14 of 64 paddocks fall below 75% single-community
dominance — the exact count `CLAUDE.md` records. Dominance median is 97.8%, minimum
34.6%. 55 of 64 paddocks are Inland-dominant.

## 5 · The design-seat endpoints reproduce — on counted values with the stated edges

Ruling CG said the bin edges were **k = 0** exactly for the dry row and **k ≥ 25** for the
wet row. Using those edges on the **counted** per-cell flood frequency:

| Inland | predicted | measured | |
|---|---:|---:|---|
| p05, dry → wet | 37.9 → 77.1 | **37.88 → 77.06** | matches |
| p50, dry → wet | 74.3 → 88.7 | **74.30 → 88.71** | matches |
| gap, dry → wet | 36.4 → 11.3 → **11.7** | 36.42 → **11.66** | matches once corrected |

**All three reproduce.** The gap row appeared to differ until Ruling CW resolved it: the
quoted 11.3 was a transcription error, the computed value was 11.7, and the measured
11.66 stands. It was flagged because it disagreed with the design seat'''s own arithmetic
(88.7 − 77.1 = 11.6), not with mine — which is what a transcription error looks like from
the outside. **No output was corrected.**

**This resolves CG's diagnosis.** The EXEMPLAR-1 Gate 3 failure was *both* causes CG
named — the interpolated surface *and* the bin edges — and on counted values with the
stated edges the numbers land.

**The Gate 3 rerun itself was NOT attempted** (Rulings CS and CG): r(p05) and the Aeolian
above-50% count stay deferred behind BQ.

## 5b · Ruling A1's Gate 2 — the open-water exclusion, verified rather than asserted

A1 requires this verified. It is, and **it returns a finding.**

**942 non-treed census cells are wet in 90% or more of the 35 years. 940 of them keep a
temporal percentile; MIN_SEASONS = 50 removes 2.** The threshold does **not** scrub
near-permanent water out of the non-treed veg map.

That does not contradict the producer's justification, which was verified on a ~347 ha
lake — but **that lake lies entirely outside the veg map.** Where open water is mapped as
water the mechanism never had to act; inside the census its extent is 2 cells. Consistent
with Ruling BT, and now quantified at the wet end rather than in total.

**Consequence for reading the wet bins:** the k ≥ 25 rows contain cells wet in most years
that are *not* excluded as open water. They are chenopod and floodplain classes by the veg
map's own reckoning, but nobody should assume open water has been removed from the wet end
of these tables.

## 5c · Ruling DD — the wet end without near-permanent water. **Prediction falsified.**

DD predicted that removing the 940 near-permanent-water cells would **raise** the wet-end
p05, because open water reads as low fractional cover, which would make the published
relationship conservative. **It does the opposite, and DD says the opposite direction is
the more important result, so it goes first.**

| k ≥ 25 | published | excl. near-permanent | Δ | cells removed |
|---|---:|---:|---:|---:|
| Aeolian | 69.32 | 69.32 | **0.00** | **0** |
| Riverine | 60.85 | 60.85 | **0.00** | **0** |
| Inland | 77.06 | **77.00** | **−0.05** | 940 |

**All 942 near-permanent cells are Inland.** The Aeolian and Riverine wet-end rows — the
60- and 69-cell rows DA flagged — contain none at all, so their thinness is not an
open-water problem.

**Why the direction reverses: the removed cells are better covered than the bin they sit
in, not worse.** Their mean temporal p05 is **77.96** against the bin's **77.06**. They do
not read as open water in the fractional-cover product, which is the same conclusion A1's
Gate 2 reached from the other side — the veg map does not classify them as water, and the
cover product does not see them as water either.

**So the concern that open water inflates or deflates the wet end is not supported.** The
effect is −0.05 pp on 77.06, which is negligible in either direction, and the sign is
opposite to the one predicted. The published rows stand unchanged; the sensitivity is a
companion table (`TEMPORAL1_wet_end_sensitivity.csv`), not a replacement.

**Two counts are reported separately** because collapsing them would mislead: **942 rows**
fall at or above 90% wetness in Inland's k ≥ 25 bin, but only **940** carry a percentile —
the other 2 are the MIN_SEASONS cells, which the published mean had already skipped. Only
the 940 move the number.

## 6 · Two findings for BQ tomorrow

**The counted per-cell flood frequency already exists** as `flood_freq_pct` in
`gayini_pixel_census_8058.parquet`, derived from `wet_years` / `valid_years`. BQ's raster
is still worth building as a map product, but the *values* are already available and
Gate 3 need not have used the interpolated surface.

### Ruling DC — the text BR must put in the README

DC strengthens BT's replacement text. **Recording the required wording here so tomorrow's
pass carries it verbatim; the README is not edited tonight**, because BR rewrites that
same document and two passes over one client-facing file is how two generations of text
end up in it.

> The open-water exclusion **does not operate within the non-treed census**. 942 cells are
> wet in 90% or more of the 35 water years and **940 retain a temporal percentile**;
> `MIN_SEASONS = 50` removes 2. The producer's justification was verified on a ~347 ha
> lake lying **wholly outside the veg footprint**, so the mechanism was never exercised
> where the analysis reads. **Any claim that the temporal metric resolves the open-water
> limitation is withdrawn — it inherits it.** Nobody may read the k ≥ 25 rows as having
> had open water removed.

The README's current sentence — that `MIN_SEASONS = 50` "excludes permanent water" — is
**false as it stands** and is the thing this replaces.

**BQ's acceptance test is amended by Ruling CY to expect 35 distinct values, not 36.**
`valid_years` = 35 for every non-treed cell, so k runs **0 to 34** — the 36th value
(k = 35, wet in every year) **does not occur in non-treed country**. CY directs this be
recorded in the README as a fact about the country, not as a tolerance. **Not written into
the README tonight**, because BR rewrites that same document tomorrow and the two belong in
one pass.

**Ruling DF — the 571-against-490 count.** On counted values **571** Aeolian non-treed
cells sit above 50% flood frequency (identical under `>` and `>=`; exactly k ≥ 18),
against **490** measured on the interpolated raster at EXEMPLAR-1 Gate 3. **This is
recorded as confirming CG's prediction and is not the Gate 3 rerun.** Gate 3 stays
deferred behind BQ. When it runs it reports r(p05) against the counted values and states
explicitly **which surface each figure in the record was computed on** — the two are now
known to differ and no figure may be quoted without naming its surface.

## 7 · Scope fact, carried under Ruling DB

**Only 795,602 of the 988,831 non-treed census cells (80.5%) fall inside a management
zone.** The unit-level table and the scatter describe **those 795,602**; the community
table describes **all 988,831**.

**Under Ruling DB this travels with the numbers, not only with the table.** Any document
quoting the unit-level table carries it, and **no deliverable may present a number from one
population as though it covered the other.** The 193,229 non-treed cells outside every
paddock are real country and are absent from the scatter entirely.

## 8 · Outstanding

**A1, A2, CA and CB were issued after the run and are now held.** Compliance checked
against the text rather than assumed:

- **A1** — published water value unchanged, no new water construction; metric named
  `veg_p05_temporal_mean`; unit is the paddock, 64 points coloured by community, no site
  panel; reconciliation table present. **All satisfied.** Its Gate 2 open-water requirement
  was the one thing not done, and §5b now does it — with a finding.
- **A2** — the community-level table was produced, as A2 requires.
- **CA** — governs the scatter only. The EXEMPLAR-1 time-series figures are untouched and
  correctly keep their year axis.
- **CB** — honoured: **nothing was pinned, superseded or recomputed**, and the two-metric
  prohibition is enforced on the figure and restated per row in the reconciliation table.

**No new `number_id` was created, and Ruling CZ ratifies that.** §6's requirement applies
to headline scalars reaching a deliverable, not to every cell of a 64-row table. All five
qualifiers travel as columns. **If REPORT-2 or any deliverable quotes a single value out of
these tables, that value gets a `number_id` at the point of quotation, with the table and
this commit as its source.**

**Ruling CW closes the endpoint reconciliation:** the design seat's 11.3 was a transcription
error, the computed value was 11.7, and the measured 11.66 stands. No correction to any
output.

**Ruling CX makes the X label standing:** `mean_flood` is the share of the paddock's cells
seen wet, mean over years, per Ruling AZ, and is never labelled a between-year flood
frequency in any output, caption or column header. Where a spec conflicts with AZ on this,
AZ wins.
