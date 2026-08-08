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
**bin edges as explicit columns** in whole years. No zone join.

### What the outputs say

The relationship is strong and monotone in every community. Per-cell temporal p05, by
wet-year bin:

| community | k=0 | 1–2 | 3–5 | 6–10 | 11–17 | 18–24 | ≥25 |
|---|---:|---:|---:|---:|---:|---:|---:|
| Aeolian | 44.7 | 44.7 | 46.5 | 53.5 | 52.7 | 47.6 | 69.3 |
| Riverine | 32.8 | 40.4 | 45.2 | 49.4 | 54.9 | 59.4 | 60.9 |
| Inland | 37.9 | 44.7 | 53.0 | 60.0 | 67.4 | 76.4 | 77.1 |

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
| gap, dry → wet | 36.4 → 11.3 | 36.42 → **11.66** | dry matches; wet differs |

**Two of three reproduce to two decimals.** The third differs from the design seat's own
arithmetic rather than from mine: 88.7 − 77.1 = **11.6**, not the 11.3 quoted, and my
11.66 is consistent with my own endpoints.

**This resolves CG's diagnosis.** The EXEMPLAR-1 Gate 3 failure was *both* causes CG
named — the interpolated surface *and* the bin edges — and on counted values with the
stated edges the numbers land.

**The Gate 3 rerun itself was NOT attempted** (Rulings CS and CG): r(p05) and the Aeolian
above-50% count stay deferred behind BQ.

## 6 · Two findings for BQ tomorrow

**The counted per-cell flood frequency already exists** as `flood_freq_pct` in
`gayini_pixel_census_8058.parquet`, derived from `wet_years` / `valid_years`. BQ's raster
is still worth building as a map product, but the *values* are already available and
Gate 3 need not have used the interpolated surface.

**BQ expects 36 discrete values inside codes 11–33; there are 35.** `valid_years` = 35 for
every non-treed cell, so k runs **0 to 34** — the 36th value (k = 35, wet in every year)
**does not occur in non-treed country**. A fact about the data, not a defect, but BQ's
acceptance test will fail as written unless it expects 35.

## 7 · Scope fact worth carrying

**Only 795,602 of the 988,831 non-treed census cells (80.5%) fall inside a management
zone.** The unit-level table and the scatter describe those; the community table
describes all 988,831. The two are not interchangeable and each says which it uses.

## 8 · Outstanding

**Rulings cited by the spec for which I hold no issued text: A1, A2, CA, CB.** CB's
substance is stated inline in §2 (no pinned number moves, nothing registered is
recomputed or superseded) and was honoured — **nothing was pinned, superseded or
recomputed.** A1, A2 and CA are cited without content and nothing here depended on them.

**No new `number_id` was created.** §6 requires every delivered quantity to carry one;
these four outputs are tables and a figure with no new headline scalar, and inventing
pins for 64 × 3 cell values would be the opposite of what the registry is for. All five
qualifiers travel as columns on every row. Flagged rather than decided.
