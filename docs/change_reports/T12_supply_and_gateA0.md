# T12 — supply step + Gate A0 · change report

**Task:** T12 — DEA Land Cover Level 3 extraction (`docs/reference_update/T12_dea_landcover_l3_extraction.md`, v2 · 28 Jul 2026; supersedes archived T7 v1)
**Scope this session:** supply step (re-pull 1988–1999) → Gate A0 (register 8058 vectors) → **STOP**. Gates A–E await review.
**Date:** 28 July 2026
**Writes performed:** 12 new rasters supplied to `Input/`; 3 rows added to `spatial_layer_asset` (additive); issues-log + archive housekeeping. **No `dea_` objects created; `dim_management_zone` history columns untouched.** Not committed to git — handed back at this STOP for review.
**Toolchain:** installed the minimal DEA download stack into the base Python 3.12.10 (Windows); `dea_tools` deliberately omitted (plotting only). R 4.6.1 `terra`/`sf` for raster/vector checks; Python `sqlite3` for registration. **Resolved versions (pinned in `scripts/13_dea_landcover/requirements.txt`), 28 Jul 2026:** `pystac-client==0.9.0`, `odc-stac==0.5.2`, `odc-geo==0.5.3`, `rasterio==1.5.0` (bundled GDAL 3.12.1), `xarray==2026.7.0`; load-bearing transitives `odc-loader==0.6.4`, `pystac==1.15.2`, `pyproj==3.7.2`. The pull is not reproducible without these pins.

---

## 1. Provenance of the existing 26 files (reported before running anything)

`Input/landsat_landcover/gayini_landuse.ipynb` produced them via DEA's Explorer STAC API → DEA public S3 (`aws_unsigned`) → `odc.stac.load(collection="ga_ls_landcover_class_cyear_3", crs="EPSG:7854", resolution=30, groupby="solar_day", bbox=[143.7,-34.7,144.4,-34.3])` → `write_cog` per year → `LLC3_{year}_MGA54.tif`. odc.stac's default resampling is **nearest** (consistent with the Gate 0 integrity pass). **`start_date` was hard-set to `2000-01-01`** — the sole reason 1988–1999 were absent. No product limitation.

## 2. Supply step — 1988–1999 re-pulled by the same route

Decision 1 (RE-PULL, time-boxed) executed. `scripts/13_dea_landcover/T12_supply_repull_1988_1999.py` reproduces the notebook **exactly**, changing only the date window to `1988-01-01/1999-12-31`. Same bbox, same `crs="EPSG:7854"`, `resolution=30`, `groupby="solar_day"`, NN default, `ds["level3"]` → `LLC3_{year}_MGA54.tif`, same folder. Homogeneity prioritised over avoiding a resample, as instructed — not pulled by any other route.

- STAC returned **24 items → 12 timesteps (1988–1999)**. GeoBox byte-identical to the existing series: `Affine(30, 0, 747300; 0, −30, 6201300)`, 2189×1545, EPSG:7854.
- **12 files written:** `LLC3_1988` … `LLC3_1999`.

### Gate 0 integrity re-check on the new files only (spec Gate 0 item 3)

`scripts/13_dea_landcover/T12_gate0_supply_integrity_check.R`:

| Check | Result |
|---|---|
| Global distinct values across 1988–1999 | **{111, 112, 216, 220}** — ⊆ {111,112,124,215,216,220,255} |
| Unexpected value (hard-stop trigger) | **none** — no hard stop; NN confirmed |
| CRS / grid / res / dtype uniform | all EPSG:7854 / 2189×1545 / 30 m / INT1U |
| `terra::compareGeom` vs existing series | **TRUE** for all 12 |
| **Full folder now** | **38 files, 1988–2025 contiguous, zero missing years** |

Well within the end-of-29-July cutoff. Decision 2 (native EPSG:3577 = NO) stands; the 3577→7854 nearest-neighbour lineage will be recorded in `raster_asset.provenance_note` at Gate A.

**Suspect-year note (spec §2.6, v2):** the whole 1988–1999 block is Landsat-5-TM-only and must carry `suspect_year_flag = 1` when Gate B builds the fact tables; any Bala 29ca conclusion drawn from this window is low-confidence by construction.

## 3. Gate A0 — 8058 vector inputs registered (additive)

Decision 3, option (a). The three standalone EPSG:8058 layers the spec §3 names **already existed** as single-layer gpkgs in `Output/spatial_8058/` (siblings of `spatial_006`), so no copy or reproject was needed — they were registered directly, mirroring `register_T1_gateA0_zone_layer.py`.

`scripts/13_dea_landcover/T12_gateA0_verify_vectors.R` (verify + facts) → `scripts/11_database/register_T12_gateA0_vectors.py` (register):

| id | layer_name (alias) | path | CRS | features | geom | validity | field_list |
|---|---|---|---|---|---|---|---|
| `spatial_007` | `gayini_boundary_8058` | `Output/spatial_8058/gayini_boundary_epsg8058.gpkg` | 8058 | 1 | MULTIPOLYGON | valid (0 invalid) | `OBJECTID,Block,SHAPE_Leng,SHAPE_Area` |
| `spatial_008` | `gayini_hectare_plots_8058` | `Output/spatial_8058/gayini_hectare_plots_epsg8058.gpkg` | 8058 | 66 | POLYGON | valid (0 invalid) | `Gayini.Nam,Vegetation,Treatment,plot_id` |
| `spatial_009` | `vegetation_communities_8058` | `Output/spatial_8058/vegetation_communities_epsg8058.gpkg` | 8058 | 5 | MULTIPOLYGON | valid (0 invalid) | `simplified_vegetation_group` |

Each carries SHA-256 (first-50-MB convention), `path_exists=1`, `import_status='registered'`, `run_id='T12_gateA0'`, and a provenance `note`. Aliases are distinct from the pre-existing 4283/7854 rows (`gayini_boundary`, `plots_source`, `vegetation_units`) to avoid `layer_name` lookup collisions — the same reason `spatial_006` used `management_zones_8058`. The 4283/7854 shapefile rows were **not** substituted.

- **`spatial_layer_asset`: 6 → 9 rows.** Second `execute` run: **9 → 9, checksums stable** — idempotent.
- Pre-existing `spatial_001/002/003` untouched.
- **`dim_management_zone` history columns still NULL 64/64.** No `dea_` object exists yet (Gate A registers the rasters + `dim_source_product` + `dim_dea_landcover_class`, out of scope here).

## 4. Housekeeping

- **Archived** `T7_dea_landcover_l3_extraction.md` (v1) → `docs/archive/` with a superseded-by header. Not deleted (additive-only).
- **Issues log** — added: **C-13** (T7 duplicate-identifier collision → renumbered T12; resolved), **C-14** (§2.4 v1 indeterminate rule bug → corrected v2; caught before any number existed), **I-26** (`irrigation_bank_cuts`, 1,158 features, unregistered Task J input — log, do not fix, per Gate A0).

## 5. Correction absorbed (from the design seat)

The §2.5 falsification test now spans **35 matched years, not 23** — `fact_zone_veg_annual` covers WY1988–2022, so every supplied DEA year from 1988 on has a veg/flood comparator. This roughly doubles the test's power and is the primary reason for the re-pull. (My Gate 0 note's "23 years" reflected only the 2000–2025 subset then present.)

## 6. State for the next gate

- Rasters ready: 38 files, 1988–2025, EPSG:7854, uniform grid, integrity-clean.
- Vector inputs resolvable from the DB: zones `spatial_006`, boundary `spatial_007`, plots `spatial_008`, communities `spatial_009`.
- **Gate A** (next, on review): register the 38 rasters in `raster_asset` (`product='dea_landcover_l3'`, provenance_note = 3577→7854 NN lineage), insert `dim_source_product` + `dim_dea_landcover_class`.
- **Follow-up (not this session):** CLAUDE.md "Current state" records `spatial_layer_asset` at 6 rows; now 9. Flagging rather than editing CLAUDE.md mid-review.

**STOP — supply step and Gate A0 complete. Awaiting review before Gate A.**
