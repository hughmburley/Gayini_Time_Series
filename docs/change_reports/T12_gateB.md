# T12 — Gate B · change report

**Task:** T12 — DEA Land Cover Level 3 extraction (`docs/reference_update/T12_dea_landcover_l3_extraction.md`, **v3**; Gate B is byte-identical v2→v3 — all v3 changes are Gate C only).
**Scope this session:** Gate B only (zonal/plot/farm/community extraction). Gate C is a **STOP** gate and additionally requires the v3 §2.9 persistence-fraction and §2.10 positive-control diagnostics — **not started.**
**Date:** 28 July 2026
**Writes:** additive only — four new `dea_`-prefixed fact tables. No pre-existing table/view/column modified or dropped; no `dea_cultivation_class` computed (Gate D); `dim_management_zone` history columns untouched (NULL 64/64).
**Script:** `scripts/13_dea_landcover/T12_gateB_extract.R` (check/execute, idempotent). Paths resolved from `spatial_layer_asset` (spatial_006/007/008/009), not hardcoded.

---

## 1. Method (spec Gate B)

- **Vectors reprojected to the raster CRS (8058 → 7854); the categorical raster never resampled.** `terra::project` on each layer, then rasterize to the DEA grid.
- **All-touched OFF — pixel-centroid containment** (`terra::rasterize(..., touches = FALSE)`), so shares are comparable to the census convention.
- **`n_pixels_nodata` retained explicitly** — 255 never occurs, so it is 0 for every row. Per §2.1: the geometry mask, not a nodata value, restricts to the property; `n_pixels_nodata = 0` is **not** evidence of complete observation (there is no confidence layer; §2.6 v3).
- **Pixel area = 0.09 ha, derived from `res()`** (30 m grid) — **not** the census `0.062351428` ha/px. DEA is a genuinely different (30 m) grid; using the census constant here would be wrong.
- **`suspect_year_flag` set from the year alone** (§2.6): flag = 1 for **1988–2012**, 0 for 2013–2025; `suspect_reason` composes the applicable GA limitations per year (1988–1999 L5-TM-only; 1999–2003 single-sensor; 2003–2011 SLC-off; 2011–2012 L7-only; 2010 rainfall/flood). No §2.4 thresholds applied.

## 2. Tables built (additive)

| Table | Key | Rows | support_level |
|---|---|---|---|
| `fact_dea_landcover_zone_year` | (zone_fid, dea_calendar_year) | **2432** (64×38) | `pixel_within_zone_dea_l3` |
| `fact_dea_landcover_plot_year` | (plot_id TEXT, dea_calendar_year) | **2508** (66×38) | `pixel_within_plot_dea_l3` |
| `fact_dea_landcover_community_year` | (community, dea_calendar_year) | **190** (5×38) | `pixel_within_community_dea_l3` |
| `fact_dea_landcover_farm_year` | (dea_calendar_year) | **38** | `pixel_within_property_dea_l3` |

Zone and plot tables carry the exact §4 column set; `plot_id` is **TEXT** (`GA_015` etc., not an integer — the gpkg stores plot codes). `dea_calendar_year` only; **no `water_year` column anywhere** (§6).

**Design decision to flag — farm/community placement.** §4/Gate B offered *"same tables using reserved sentinel keys, or separate views — CC's call."* Chosen: **separate `dea_`-prefixed tables**, a third option. Reasons: (a) each table then carries exactly one `support_level`, honouring the project's support-purity rule and removing any risk of a consumer summing farm/community rows with real zones under a shared `zone_fid`; (b) *separate views* was infeasible — communities and the whole-property total do **not** decompose from the zone table (unzoned area exists; communities cut across zones), so each needed its own raster extraction. Additive and reversible; flagged for review.

## 3. Validation

**Pilot reconciliation — byte-perfect.** Against `docs/reference_update/T7_pilot_dea_zone_year_2013_2025.csv` at zone-year grain, all 8 pilot years:

```
matched 512/512 pilot zone-years | max |CTV diff| = 0.0000 pp | max |n diff| = 0 px
```

The zonal extraction reproduces the design seat's pilot exactly. Farm-level CTV 2014 = 44.97%, 2016 = 47.56% also match the §1 property table exactly.

**The 6.7% figure — a support distinction, reported not tuned.** §1(c)'s "farm mean of 6.7%, 28 of 64 paddocks above 5%" is the **unweighted mean across the 64 paddocks** of each paddock's 2023–25 CTV floor, **not** the area-weighted property share:

```
unweighted mean of 64 paddock 2023-25 floors = 6.72%   (= spec S1(c) "6.7%")
paddocks with 2023-25 floor > 5%             = 28      (= spec S1(c) "28 of 64")
area-weighted property 2023-25 CTV           = 10.57%  (= mean of the pilot table shares)
```

Both reconcile exactly to the spec; the apparent 6.7 ↔ 10.57 gap is `unweighted paddock mean` vs `area-weighted property share` — the same support/aggregation class as C10. **No method was tuned to force a match.** The zone floor (per §2.2, mean over 2023–25 per zone) that feeds Gate D is the 6.72%-basis quantity.

**Other checks:** every table's class shares sum to 100 ± 0.01 (0 violations); `n_pixels_nodata` max 0; `support_level` and `source_product_id` non-NULL on every row; `suspect_reason` NULL iff `suspect_year_flag = 0` (0 mismatches).

## 4. Invariants + idempotence

- `dim_management_zone` history columns NULL 64/64 (verified post-write).
- No `dea_cultivation_class` computed (Gate D only). No pre-existing object modified/dropped; the four fact tables are the only new objects.
- Idempotent: `execute` run three times → row counts stable (2432/2508/190/38), zone-table value digest stable.

## 5. Carry-forward for Gate C (held — STOP + needs v3 diagnostics)

- **1988–1999 is flagged suspect and is low-confidence by construction** (L5-TM-only; §2.6). Any Bala 29ca reading from that window must be reported as such.
- Gate C (v3) requires: **§2.9** persistence as a *fraction of valid years* (full 1988–2025 vs 8-yr pilot, never merged; §2.9.3 effect-size rule for a separated mode); **§2.10** off-property positive control (raster extent − property − 500 m buffer, `scope='off_property_control'`, one panel, hard scope stop); §2.7 stopping rule on the fraction. Gate C is a **human STOP**.

**STOP — Gate B complete and verified. Gate C not started (awaits review; v3 diagnostics pending).**
