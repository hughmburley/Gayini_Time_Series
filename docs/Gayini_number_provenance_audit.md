# Gayini — number provenance audit

**Date:** 25 July 2026
**Purpose:** classify every number discrepancy encountered during the T1 design and build cycle, to establish whether the database is unstable or the questions were underspecified.
**Verdict:** the database returned a single consistent answer every time. **Zero discrepancies were caused by the DB disagreeing with itself.**

---

## The twelve discrepancies

| # | Claim | Competing values | Root cause | Category |
|---|---|---|---|---|
| 1 | EPSG:8058 rasters registered | 9 vs **18** | Read the census summary workbook's `Registered_rasters` sheet (filtered, 1 July) instead of `raster_asset` | Stale copy |
| 2 | `farm_area_total_ha` exists | absent vs **present** | Read `Gayini_Results_DB_summary.xlsx` (stale) instead of `PRAGMA table_info` | Stale copy |
| 3 | `figure_asset` row count | 139 vs **255** | Carried a July figure forward in prose | Stale copy |
| 4 | `raster_asset` extent populated | 0 of 98 vs **126 of 126** | Read QA row `raster_asset_crs_extent_populated`, dated 2026-07-01, **still sitting in the live DB** | Stale copy — inside the DB |
| 5 | `Area_MW` / `ManagmentZ` exist | absent vs **present** | Inspected `Gayini_Results.gpkg:management_zones` (EPSG:28355 companion) instead of `management_zones_epsg8058.gpkg` (the input) | Wrong object |
| 6 | Community flood-frequency gradient | 9 / 22 / 50 / 44 vs **6.08 / 12.91 / 27.99 / 33.80** | Plot support, post-conservation period vs pixel support, full 1988–2023 series | **Different measurement** |
| 7 | Floor : median climb ratio | 2.2× vs **2.41×** | Different flood-frequency bin scheme; scheme was never recorded | Unstated parameter |
| 8 | Refugia area at p05 ≥ 80 | 4,193.4 vs **4,179.29** ha | 0.0625 vs 0.062351428 ha/px | Unstated parameter |
| 9 | Pixels at p05 ≥ 80, "non-treed" | 67,095 vs **67,028** | `treed_context_flag = 0` (10 strata) vs `+ regime_band <> 'context'` (9 strata) | Unstated parameter |
| 10 | "~4,300 ha majority-green" | 4,179 / 4,474 / 6,458 ha | Three grids (24.97 m / 24.97 m / 30 m), two thresholds, two denominators | **Different measurement** |
| 11 | Zone identity verified | 27 of 64 vs **64 of 64** | Per-zone nearest-neighbour rule vs global bijection constraint — same data, different test | Underspecified test |
| 12 | Unzoned area | 12,179 vs 12,001 ha | In-chat point-in-polygon estimate vs zone-area subtraction assuming zones ⊆ mapped area | Different derivation |

## Tally

| Category | Count | What it means |
|---|---|---|
| Stale copy read as live | **4** | The DB was correct. A July artefact was consulted instead. |
| Wrong object | **1** | The DB was correct. The wrong file was opened. |
| Unstated parameter | **3** | The DB was correct. The question omitted a constant, a scope filter or a bin scheme. |
| Underspecified test / derivation | **2** | The DB was correct. Two different tests were run on the same data. |
| **Genuinely different measurements** | **2** | **#6 and #10. These are real scientific problems, not bookkeeping.** |

**Nobody ever asked the database the same question twice and got two answers.**

## What passed, and passed cleanly

The reconciliation checks that exist all hold, several to zero:

- `Σ n_pixels` across 11 strata = 1,080,157 — **diff 0**
- `Σ area_ha` = 67,349.332 ha — **diff 0.000**
- `pct_of_mapped` sums to **exactly 100%**; `pct_of_farm_total` to 78.394%
- Census parquet SHA-256 matches the registered value
- `compareGeom()` TRUE for 7 of 7 rasters tested against the canonical grid
- Gate A0 registration idempotent across two runs: 5 → 6 → 6, identical read-back
- Stored `veg_regime_class_8058` extent matches the file header to six decimal places

## The actual failure mode

Not instability, and not independent runs as such. **There was no single authority with a date on it**, so every session reconstructed facts from whatever artefact was nearest — and those artefacts were of mixed vintage. Four separate readers hit the same stale QA row.

The DB is not the problem. The DB is the only thing in this system that has been right every time.

## The five qualifiers

Most of the twelve collapse if a number never travels without all five:

1. **Support level** — pixel · paddock · stratum · property · plot · zone-month
2. **Scope filter** — the literal SQL, e.g. `treed_context_flag = 0 AND regime_band <> 'context'`
3. **Grid and pixel constant** — 24.970268 m → 0.062351428 ha/px
4. **Denominator** — mapped 67,349.332 ha or true farm 85,910.8 ha
5. **Period** — 1988–2023 full series, or post-conservation only

#6 needed qualifiers 1 and 5. #8 needed 3. #9 needed 2. #10 needed 3 and 4. All four would have been caught on sight.

## Recommended actions — small, additive

**Do not build a new database.** The DB has been correct at every check. Rebuilding it would be the most expensive possible response to a problem that is not located in it, and the builder is destructive.

| Action | Cost | Fixes |
|---|---|---|
| Mark or re-derive the QA/release rows dated 2026-07-01 | small | #4 and its class — a stale row inside the DB has now misled four readers |
| Add `computed_at` to QA rows and surface it wherever they are read | small | Makes staleness self-announcing rather than invisible |
| Stamp an as-of date per sheet on the contract snapshot, with "not authoritative for QA verdicts" | trivial | #1, #2, #3 |
| Store the five qualifiers as columns wherever a headline number lives | small | #7, #8, #9 — already begun: `pixel_area_ha` and `scope_filter_sql` in T3, `support_level` in T1 |
| T4 claim register: every manuscript number → object + query + five qualifiers | already planned | The whole class |

## The two that are not bookkeeping

**#6 — the 9 / 22 / 50 / 44 gradient.** In the spine and in `CLAUDE.md`, labelled "Support: stratum, pixel". Two of the four values match a plot-support post-period view; the other two match nothing found. This is a support merge in the spine itself. Spine chat, not a build fix.

**#10 — the three refugia lineages.** Three numbers near "4,300 ha" from three grids and two thresholds. Until T3 Gate A1 attributes the original, the published figure is unattributable. Retiring it is a legitimate outcome.

Everything else on the list is provenance hygiene. These two are numbers currently in the paper that are wrong or unsourced.
