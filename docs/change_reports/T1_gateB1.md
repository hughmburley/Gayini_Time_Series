# T1 — Gate B1: additive schema + `write_and_register_figure()` + A0/A/B figures

**Date:** 26 July 2026 · **Spec:** `T1_zone_stratum_census_join.md` v3, Gate B1 + the 25 Jul refinement · **Status:** complete. **STOP before Gate C** (and, per the forward plan, T5 Gate 1 comes first).
Scripts: `scripts/11_database/T1_gateB1_schema_migrations.py`, `scripts/12_zone_stratum/T1_gateB1_read_field_lists.R`, `R/gayini_figure_register.R`, `scripts/12_zone_stratum/T1_gateB1_figures.R`, `scripts/12_zone_stratum/T1_gateB1_guard_fixture_test.R`. Evidence: `Output/tables/T1_gateB1_field_lists.csv`, `Output/figures/diagnostics/T1_*.png`.

---

## 1–2 · Schema ALTERs (additive, idempotent)

Five columns added; re-run adds 0.

- `figure_asset += support_level TEXT, figure_level TEXT`
- `spatial_layer_asset += checksum_sha256 TEXT, path_exists INTEGER, field_list TEXT`

**No backfill of the 255 existing `figure_asset` rows** (out of scope) — verified 0 populated. Post-build chain: these ALTERs are already recorded in `CLAUDE.md`; `T1_gateB1_schema_migrations.py` is idempotent and *is* the re-application.

## 3 · `spatial_006` checksum migrated out of `note` — RECOMPUTED, not transcribed

The first-50-MB SHA-256 was **recomputed from the file** (`e7a3b436…0c5225`) and **matches** the value that had been sitting in `note` — so the transcribed value is now, for the first time, actually checked. `checksum_sha256` and `path_exists=1` are in their own columns; `note` trimmed to provenance only.

## 4 · `field_list` for all six layers — and a discrepancy worth flagging

Populated from each layer's **actual registered-file fields**, in file order (`read_registered_layer`'s contract is to compare the file's real fields to `field_list`):

| id | layer | field_list (registered file) |
|---|---|---|
| spatial_001 | plots_source | `Gayini.Nam,Vegetation,Treatment` |
| spatial_002 | gayini_boundary | `OBJECTID,Block,SHAPE_Leng,SHAPE_Area` |
| spatial_003 | vegetation_units | `OBJECTID,formation,class,condition,…,Vegetation` (20) |
| spatial_004 | management_zones (28355) | **`OBJECTID_1,OBJECTID_2,ManagmentZ,Area_MW,Treatment,Plots`** |
| spatial_005 | gauge_sites | `station_id,station_name,…` (12) |
| spatial_006 | management_zones_8058 | `OBJECTID_1,OBJECTID_2,ManagmentZ,Area_MW,Treatment,Plots` |

**Flag (MED): `spatial_004` is not the lowercase companion.** Its registered file is `Input/shapefiles.zip::CA0561_ManagementZones.shp`, which carries the **capitalised ESRI names** — the same schema as `spatial_006`, because both derive from that shapefile. The **lowercase** fields the Gate B1 instruction expected (`source_feature_id,management_zone,treatment,plots`) belong to `Gayini_Results.gpkg:management_zones` — a **separate, unregistered** object. So `field_list` on `spatial_004` is caps (matching its actual file). The CLAUDE.md "spatial layers" table contrasts `management_zones_8058` (caps) with the *gpkg companion* (lowercase); it does **not** describe `spatial_004`. If you want the lowercase companion tracked, it needs its own `spatial_layer_asset` row — a separate change, not this gate's.

## 5 · `write_and_register_figure()` — R owns both halves, one convention

`R/gayini_figure_register.R`. ggsave → first-50-MB SHA-256 → `INSERT OR REPLACE` into `figure_asset`, one call, one transaction (`dbBegin`/`dbCommit`/rollback).

- **The R first-50-MB SHA-256 is byte-identical to the Python `sha256_first50`** — verified on the 8058 gpkg: both give `e7a3b436…0c5225`. **No `digest::digest(file=…)` whole-file** — the old R convention is not used, so no third convention is created.
- **The caption-support guard can fail, and fails closed.** `T1_gateB1_guard_fixture_test.R` feeds a caption that names no support level; the guard `stop()`s (`caption must state the support level 'zone'`), **no PNG is written and no row is inserted**. (First draft of the guard also accepted the bare word "support"; tightened to require the support token itself.)

## 6 · The four A0/A/B gate figures — written and registered

All in `Output/figures/diagnostics/`, `support_level='zone'`, `figure_level='diagnostics'`, captions state the support; checksums in `figure_asset` match the files; re-run is idempotent (4 rows, not 8).

| figure | passes because |
|---|---|
| `T1_A0_zone_layer_extent.png` | 64 zones sit inside the census-grid extent, no offset (both EPSG:8058) |
| `T1_A_zone_map_named.png` | legible **paddock names** (not indices); the 4 green `No grazing` zones are Bala 26ca/27ca/28ca/29ca (= fids 1–4) |
| `T1_A_identity_margin.png` | residuals hug a tight **0.131–0.151 pp** band (a scrambled permutation would be ragged); fids 9/21 marked, and sit at the margin floor in the lower panel |
| `T1_B_area_source_vs_computed.png` | points just below the 1:1 line; the systematic ≈ −0.25% projection offset is annotated |

**Judgment call to confirm:** I used `support_level='zone'`. The canonical support ladder (CLAUDE.md) is pixel · paddock · stratum · property · plot · zone_month — **`zone` is not on it.** Management zones *are* paddocks (the labels are paddock names), so `paddock` would be ladder-consistent; I chose `zone` as the more precise T1 term for figures about the zone layer itself. One-line change + idempotent re-register if you prefer `paddock`.

---

## Acceptance (Gate B1 slice)

- [x] `figure_asset` has `support_level`, `figure_level`; ALTERs in the post-build chain; 255 existing rows **not** backfilled.
- [x] `spatial_layer_asset` has `checksum_sha256`, `path_exists`, `field_list`; `spatial_006` migrated (checksum recomputed + matches); all six `field_list` populated.
- [x] `write_and_register_figure()` uses first-50-MB SHA-256 (= Python), one transaction; guard proven to fire on a broken fixture.
- [x] Four gate figures written **and** registered with `support_level`/`figure_level`/caption; idempotent; checksums match files.

**STOP.** Next per the forward plan: **T5 Gate 1** (`gayini_params` + the three lints + fixture tests) **before** T1 Gate C — so the `0.0625` vs `0.062351428` error is structurally impossible before areas are computed at scale.
