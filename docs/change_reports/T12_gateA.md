# T12 — Gate A · change report

**Task:** T12 — DEA Land Cover Level 3 extraction (`docs/reference_update/T12_dea_landcover_l3_extraction.md`, v2)
**Scope this session:** Gate A only (register the 38 rasters + source product + class dimension) → **STOP**. Gate C awaits spec **v3** (three Gate C amendments incoming) — not started on v2.
**Date:** 28 July 2026
**Writes:** additive only — `raster_asset` +38, `dim_source_product` +1, new table `dim_dea_landcover_class` +7, one `workflow_run` provenance row (`is_current=0`). **No pre-existing row modified; no `dea_` output in any pre-existing table; `dim_management_zone` history columns untouched (NULL 64/64).**
**Script:** `scripts/11_database/register_T12_gateA_rasters.py` (check/execute, idempotent; rasterio for bounds/res/crs, first-50-MB SHA-256).

---

## 1. What was registered

**`raster_asset` — 38 rows**, `raster_asset_id = raster_dea_l3_{1988..2025}` (distinct ids, no collision with existing products):

- `product = 'dea_landcover_l3'`, `crs = 'EPSG:7854'`, `crs_epsg = 7854`
- `resolution_x = resolution_y = 30.0`; `xmin/ymin/xmax/ymax = 747300 / 6154950 / 812970 / 6201300` (uniform, read per-file with rasterio)
- `checksum_sha256` first-50-MB convention; `path_exists = 1`; `qa_status = 'REVIEW'`; `run_id = 'T12_gateA'`
- `legend_status = 'confirmed'`, `legend_semantics = 'FAO LCCS v2 Level 3 categorical'`, `superseded_flag = 0`
- **`water_year` left NULL; the calendar year is in `period_label = 'calendar_{year}'`.** DEA is a calendar-year product; per spec §6, no DEA object carries a `water_year` value — kept out of the generic column too, to prevent the calendar/water-year confusion that section warns against.
- **`provenance_note` per row** records the 3577→7854 nearest-neighbour lineage via `odc.stac.load` from DEA Explorer STAC (dea-public-data S3), and the producer — **identical route, different producer per block**:
  - **1988–1999** (12 rows): produced by `scripts/13_dea_landcover/T12_supply_repull_1988_1999.py` (this session's supply step).
  - **2000–2025** (26 rows): produced by `Input/landsat_landcover/gayini_landuse.ipynb`.

**`dim_source_product` — +1 row** `dea_landcover_l3`, with the full §4 caveat text verbatim ("NOT cropping history … local datasets are authoritative") and the §4 `method_summary`. Table now 7 rows.

**`dim_dea_landcover_class` — new table, 7 rows**, one per LCCS Level 3 code including the three absent from our extent (124 NAV, 215 AS, 255 nodata), so a later reader is not misled into thinking the product has four classes:

| code | class_code | class_name | is_nodata |
|---|---|---|---|
| 111 | CTV | Cultivated terrestrial vegetation | 0 |
| 112 | NTV | Natural terrestrial vegetation | 0 |
| 124 | NAV | Natural aquatic vegetation | 0 (absent in extent) |
| 215 | AS | Artificial surface | 0 (absent in extent) |
| 216 | NS | Natural bare surface | 0 |
| 220 | Water | Water | 0 |
| 255 | nodata | No data | 1 (absent in extent) |

Every class caveat carries the mandated sentence: *"DEA Land Cover emits a class for every pixel regardless of how many usable observations that pixel had in that year; there is no confidence layer in v2.0.0, so absence of nodata is NOT evidence of adequate observation. This matters most for 1988–1999 (Landsat 5 TM only)."* — plus a per-class limitation.

## 2. Suspect-year flag — recorded, not set here

`suspect_year_flag` is a **Gate B fact-table** column, not a `raster_asset` column, so nothing was set at Gate A. **For the record:** the entire **1988–1999** block must carry `suspect_year_flag = 1` (Landsat-5-TM-only, single-sensor, lowest observation density — spec §2.6 v2), and the other §2.6 windows (2010; 2003–2011; 2011–2012; 1999–2003) apply as specified. Any Bala 29ca conclusion drawn from 1988–1999 is low-confidence by construction.

## 3. Verification — against the live SQLite (not prose)

Actual query output:

```
-- raster_asset row count by product --
     67  mer_inundation
     38  dea_landcover_l3
     33  landsat_inundation
     12  task_J_difference_pp
      5  total_veg_percentile_8058
      2  total_veg_annual_8058
      2  fc_seasonal_stack_3577
      2  annual_inundation_stack_8058
      1  veg_wet_response_8058
      1  veg_regime_class_8058
      1  veg_persistence_duration_8058
      1  unzoned_components_8058
      1  flood_zone_8058
   TOTAL: 166

-- dea_landcover_l3: count, distinct crs, period span --
   (38, 1, 'calendar_1988', 'calendar_2025')

-- dim_source_product --
   count: 7 ; dea row: ('dea_landcover_l3', 'DEA Land Cover Level 3 (ga_ls_landcover_class_cyear_3 v2.0.0)')

-- dim_dea_landcover_class --
   count: 7 ; codes 111,112,124,215,216,220,255

-- dim_management_zone history-column NULL check --
   cropping_history     NULL 64/64
   land_use_era         NULL 64/64
   irrigation_status    NULL 64/64
   history_source       NULL 64/64
   history_confidence   NULL 64/64
```

## 4. Idempotence

Registration run three times. Row counts identical each run (`raster_asset` 166→166, dea 38); the SHA-256 digest of all 38 `(id:checksum)` pairs is byte-stable across re-runs:

```
run N   : total=166 dea=38 digest=32246d48934b103c7f701db9fa6218941d93456b8891edb19cf87b463a48f0b3
run N+1 : total=166 dea=38 digest=32246d48934b103c7f701db9fa6218941d93456b8891edb19cf87b463a48f0b3
IDENTICAL row counts + checksums: True
```

## 5. Invariants held

- Additive only; no builder run; no `reset_file`; no pre-existing `raster_asset` row touched (distinct `raster_dea_l3_*` ids).
- `dim_management_zone` history columns NULL 64/64 (verified above).
- No `dea_` output written to any pre-existing table. The only new table is `dim_dea_landcover_class` (a `dea`-labelled dimension, per spec §4).

## 6. Next gate — held

**Gate B** (zonal/plot extraction into `fact_dea_landcover_zone_year` / `fact_dea_landcover_plot_year`, where `suspect_year_flag` is set) is next. **Do not begin Gate C** — spec **v3** with three Gate C amendments lands first. This session stops at Gate A per instruction.

## 7. Doc-sync deferred (tracked, not done here)

CLAUDE.md "Current state" now understates two counts: `spatial_layer_asset` 6→9 (Gate A0) and `raster_asset` 126→166 (25 populated + T12's 38; the 126 was already stale). Per instruction, CLAUDE.md is edited **once at T12 close** — tracked as issues-log **I-27**, to be folded into that single edit.

**STOP — Gate A complete and verified. Awaiting review; Gate B/C not started.**
