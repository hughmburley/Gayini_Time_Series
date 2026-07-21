# Gayini — pixel census data contract

*Design-seat spec, 15 July 2026. Input to Task H **H4**. Build to this; do not improvise the schema.*

**Facts referenced here live in `Gayini_established_data_facts.md`. Do not re-derive them.**

---

## 1. The decision — parquet, external, registered

**The census is an external asset registered in the database. It does not go into `Gayini_Results.sqlite`.**

This is not a new architecture. It is the existing one, applied to a new type. The README already states: *"Rasters are stored externally and registered in `raster_asset`; raster binaries are not stored in SQLite or GeoPackage."* The database has **four** asset-registry tables — `raster_asset`, `figure_asset`, `report_asset`, `spatial_layer_asset`. The census is the fifth type.

| | Decision |
|---|---|
| **Store** | **Parquet** — `Output/census/gayini_pixel_census_8058.parquet` |
| **Index** | a `census_asset` row in `Gayini_Results.sqlite` |
| **CSV** | an **export function**, not a store. Generate on demand. |
| **Second database** | **No.** |

**Why no second SQLite:** two databases means two sets of release checks, two dictionaries, two things to keep in sync. Correction **C5** is already this failure at small scale — the shipped dictionary drifted to 39 rows against `dim_metric`'s 43, and that is *metadata*. Do not take that bet with 1.08M rows.

**Why CSV is not the store:** ~150–200 MB, loses types, slow to read, and a second maintained copy will diverge from the parquet. **The parquet is the single source.** Provide `gayini_export_census_csv()` for anyone who needs a flat file.

**SQL is still available:** `arrow` in R gives dplyr verbs over parquet directly; DuckDB can query it in place with no import. Neither requires a second database.

## 2. `pixel_id` — the terra cell index. Not a counter.

```
pixel_id = (row - 1) * ncol + col        # row-major, 1-based, terra::cells() convention
ncol = 4037, nrow = 2422  ->  max = 9,777,614   # fits int32
```

**Why this and not a sequential counter:**

- **Deterministic** — the same pixel gets the same ID on every rebuild.
- **Reconstructible** — `pixel_id` → row/col → x/y from the grid definition alone.
- **It joins straight back to any raster on the canonical grid** — the percentile rasters, the H6 zone raster, the 35-layer NN stack — with **no spatial join**. An arbitrary counter gives none of this.

> **This makes correction C2 load-bearing.** The ID is only meaningful alongside a registered grid definition, and `veg_regime_class_8058.tif` is still **not in `raster_asset`**. Register it before or alongside the census build, with crs/extent/res/origin/checksum populated.

**Assert on build:** `pixel_id` is unique; `max(pixel_id) <= 9777614`; round-tripping `pixel_id` → x/y reproduces `x_8058`/`y_8058` to within half a pixel.

## 3. Column specification

One row per **valid census pixel**. Expected **1,080,157 rows**.

| Column | Type | Definition |
|---|---|---|
| `pixel_id` | int32 | terra cell index on the 8058 grid. **Primary key.** |
| `x_8058` | float64 | cell centre easting, EPSG:8058 |
| `y_8058` | float64 | cell centre northing, EPSG:8058 |
| `veg_regime_class` | int8 | 11,12,13,21,22,23,31,32,33,40,50 |
| `community` | factor | 4-class `simplified_vegetation_group` — **canonical** |
| `regime_band` | factor | `low` / `mid` / `high` / `context` |
| `treed_context_flag` | bool | woodland/forest = context only |
| `wet_years` | int8 | count of wet-valid years, 0–35 |
| `valid_years` | int8 | count of valid years. **= 35 for 100% of focus pixels** (verified). Kept explicit: it is the headline's denominator, context strata are unverified, and a future rebuild could change it. |
| `flood_freq_pct` | float32 | **HEADLINE** = `100 * wet_years / valid_years`. For focus pixels this is **exactly `k/35`, k ∈ [0,35] — 36 discrete values**, granularity 2.857 pp. |
| `flood_zone` | int8 | H6 absolute zone, 0–4 |
| `veg_p05` | float32 | 5th percentile of total veg (green+dead), across series |
| `veg_p10` | float32 | 10th percentile |
| `veg_p20` | float32 | 20th percentile |
| `veg_p30` | float32 | 30th percentile |
| `veg_p50` | float32 | 50th percentile |

~16 columns × 1.08M rows → **15–30 MB** as parquet.

**Nullability:** the `veg_p*` columns are null where FC has no valid seasons for that pixel (155 per column — permanently-wet Woodland context pixels below `MIN_SEASONS`). Report the null count per percentile column — do not silently drop those rows, and do not fill them.

> ⚠️ **D7 — nulls are stored as float `NaN`, not parquet `NULL`.** A consumer testing `WHERE veg_p05 IS NULL` gets **0 rows**; use `isnan()` (DuckDB/SQL) or `is.na()` (R/arrow) instead. Functionally correct — the NaN rows are the below-`MIN_SEASONS` context pixels — but the SQL `IS NULL` idiom silently misses them.

### Coordinates — store 8058 only

**Do not store LAT/LONG.** There are already **seven** CRSs in play; a lat/long column adds an eighth representation whose main practical use is being wrong — geographic coordinates invite area and distance calculations that silently misreport (the LUT already flags 4283 as *"must be projected before any area calculation"*).

Store `x_8058` / `y_8058`. If a display need arises (Nari Nari maps, Google Earth), derive lon/lat **at export**, clearly suffixed (`lon_4283`, `lat_4283`), never as the stored canonical.

## 4. Do NOT build a per-pixel-per-year table

1,080,157 × 35 = **37.8M rows per variable**. Do not build it.

> **The rasters *are* the time dimension.** The 35-layer NN 8058 stack (`annual_inundation_stack_8058`) is literally the per-pixel-per-year store, it is already registered in `raster_asset`, and Track A's time-resolved cuts are **raster zonal statistics** on it. Duplicating it into a table buys nothing and creates a second copy to keep in sync.

If a time series is later needed for a subset of pixels: take their `pixel_id`s from the wide table, convert to row/col, and extract from the stack.

## 5. This satisfies the sub-sampling requirement

`pixel_id` + `x_8058`/`y_8058` + `community` + `regime_band` is **everything** needed to draw a reproducible sample later and pull its series from the stack. Nothing more is required.

**Task F code stays frozen on `main`, uncalled** (`gayini_stratum_allocation`, `gayini_draw_monte_carlo`). Additive-only. The census schema is sample-ready by construction; that is the extent of the commitment.

## 6. `census_asset` registration

Follow the `raster_asset` pattern. Minimum fields:

| Field | Note |
|---|---|
| `census_asset_id` | |
| `path` | relative, `Output/census/…` |
| `product` | e.g. `pixel_census_8058` |
| `crs_epsg` | 8058 |
| `grid_reference` | the `raster_asset_id` of `veg_regime_class_8058.tif` — **the ID is meaningless without it** |
| `n_rows` | 1,080,157 |
| `checksum_sha256` | |
| `path_exists`, `qa_status`, `run_id` | as per `raster_asset` |
| `schema_version` | this contract's version |

**Post-build mutation — idempotent, re-run after any full DB rebuild.** Add to the post-build chain alongside the existing raster registrations.

## 7. Acceptance

1. Row count = **1,080,157**; `pixel_id` unique; no NULL `pixel_id`.
2. `SELECT community, regime_band, COUNT(*)` reconciles to **`census_stratum` at diff = 0** for all 11 strata. *(This one is a real check — `census_stratum` was built by an independent path.)*
3. `flood_freq_pct` bounded [0, 100]; equals `100 * wet_years / valid_years` to float tolerance.
4. **`valid_years == 35` for every focus-stratum row** (verified 100.000%; the 95.768% figure was stack-wide and does not apply to the census). Context strata (Woodland, Other) are **unverified** — report their distribution rather than asserting.
5. `pixel_id` → x/y round-trip within half a pixel of `x_8058`/`y_8058`.
6. `flood_zone` cross-tab reconciles to the expected table in spec v4 §4.7.
7. `veg_p05 <= veg_p10 <= veg_p20 <= veg_p30 <= veg_p50` per row (monotone) — assert it; a violation means a percentile bug.
8. Null counts reported per `veg_p*` column.
9. Registered in `census_asset` with `grid_reference` populated.
10. **Never committed to git** — `Output/` is gitignored. Commit the code and the small reconciliation table only.

## 8. Build order

H2 (percentile rasters) must land first — the `veg_p*` columns depend on them.

```
H2   5 percentile rasters, 3577 @ 30 m -> reproject to 8058    [NOT STARTED]
     ** mask 255 -> NA BEFORE summing band2+band3: 255+255 in uint8 = 254, silently **
H6   flood_zone raster (reclassify NN freq, fixed breaks)      [cheap]
H4   assemble the census parquet from:
       veg_regime_class_8058.tif   -> pixel_id, class, community, band
       NN 8058 stack                -> wet_years, valid_years, flood_freq_pct
       5 percentile rasters         -> veg_p05..p50
       zone raster                  -> flood_zone
     assert compareGeom() across ALL of them before any join
```

**Every input must pass `terra::compareGeom()` against `veg_regime_class_8058.tif` before extraction.** Silent misalignment produces plausible-looking wrong numbers — worse than a crash.
