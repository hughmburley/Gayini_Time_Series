# T1 — Gate A0 + Gate A recon

**Date:** 25 July 2026 · **Spec:** `T1_zone_stratum_census_join.md` v3 · **Status:** Gate A0 executed (additive); Gate A read-only recon complete. **STOP for review.**
Scripts: `scripts/11_database/register_T1_gateA0_zone_layer.py`, `scripts/12_zone_stratum/T1_gateA_recon.R`. Recon artefacts: `Output/tables/T1_gateA_{zone_areas,identity_margin,raster_geom}.csv`.

---

## Gate A0 — 8058 zone layer registered (additive, idempotent)

One row added to `spatial_layer_asset`:

| field | value |
|---|---|
| `spatial_layer_asset_id` | `spatial_006` |
| `path` | `Output/spatial_8058/management_zones_epsg8058.gpkg` (relative) |
| `layer_name` | `management_zones_8058` |
| `source_crs = target_crs` | `EPSG:8058` (read from gpkg header) |
| `feature_count` | 64 · `geometry_type` MULTIPOLYGON |
| `import_status` | `registered` · `run_id` `T1_gateA0` |

- **Idempotent:** ran `execute` twice → 5→6 rows, then 6→6, identical row read-back. `INSERT OR REPLACE` on the PK.
- The EPSG:28355 row `spatial_004` (absolute zip path) is **untouched**.
- SHA-256 (first-50-MB builder convention) = `e7a3b436cb96936a09e674f2feaa9e6862c4a36cfb5bed4e6ad7aba6080c5225`.

**Schema-vs-spec flag (HIGH-visibility, LOW-risk):** the spec says register `SHA-256` and `path_exists`, but `spatial_layer_asset` has **no `checksum_sha256` and no `path_exists` column**. Altering that table is not sanctioned (only `figure_asset` ADD COLUMN is, per Gate B1). Both values are recorded in the free-text `note` column instead — same provenance, no schema change. Flagging in case a later gate expects to read them as columns.

---

## Gate A — recon findings (read-only)

**1 · Paths from the DB.** Both resolve and exist on disk: `census_asset` → parquet (`path_exists=1`), `spatial_006` → zone gpkg. No `path_exists=0`.

**2 · Census parquet.** **1,080,157 rows** ✓. **16 columns, exactly the H4 contract** (`pixel_id, x_8058, y_8058, veg_regime_class, community, regime_band, treed_context_flag, wet_years, valid_years, flood_freq_pct, flood_zone, veg_p05..p50`) — no missing, no extra. Checksum **matches** the registered value. Not rebuilt.

**3 · Raster geometry (terra headers, not the registry).** All seven 8058 products (`veg_regime_class_8058`, `flood_zone_8058`, `total_veg_p05/10/20/30/50_8058`) are EPSG:8058, res 24.970268 m, extent `xmin 8982659.65 / ymin 4324576`, 2422×4037. **`compareGeom()` vs `veg_regime_class_8058` = TRUE for all 7** (data contract §8).
- **The step-3 backfill is a no-op.** `raster_asset` has **0** rows with a NULL extent (all 126, and all 18 crs_epsg=8058 rows, are populated); stored `veg_regime_class_8058` extent matches the header exactly (dxmin=dxmax=0). The F7 / QA `raster_asset_crs_extent_populated` "98 of 98 lack extent" is **stale** (dated 2026-07-01, before the Task H / gate-E registrations backfilled them). No `raster_asset` write was made — which also removes the tension with the "no existing table modified" acceptance criterion.

**3b · compareGeom across ALL 18 crs_epsg=8058 rasters (the extra, for T2).** `T1_gateA_raster_geom_all18.csv`. **12 / 18 share the census grid exactly** (2422×4037). The **6 FALSE are the `task_J_difference_pp` rasters** — same CRS (8058) and resolution (24.970268 m) but a smaller **clipped extent** (1454×2275, the 2018 bank-cut AOI). That is **by design, not a defect**: Task J is a spatial subset and does not claim the full census grid. **T2's dependency `total_veg_annual_8058` (both layers) is grid-aligned** (TRUE), as are `veg_wet_response_8058` and the `annual_inundation_stack_8058` pair. So T2's Gate A inherits no unverified grid assumption; the only non-matches are the deliberately-clipped Task J products.

**4 · Zone layer.** 64 features, EPSG:8058. `Treatment` ∈ {`14-day grazing` 60, `No grazing` 4}; `Plots` ∈ {`Sample` 19, NULL 45}. **No NUL padding** — the defensive `[[:cntrl:]]` strip changed nothing and `Treatment == 'No grazing'` compares equal directly (confirms C2).

**5 · Zone identity — the margin test (vs `area_ha_computed`). The gate's key result.**

Every MODIS zone `i` was compared, by area, to its assumed partner `fid = i` and to all 63 others:
- **Assumed-partner error is uniform and tiny: 0.13–0.15% for all 64 zones.** MODIS `area_ha[i]` matches the 8058 geometry area of `fid = i` to the projection-offset floor, across the board.
- **62 / 64 zones: the assumed partner is the nearest match.** Only **2** (`idx 21`, `idx 30`) have a marginally closer competitor (`fid 9` at 0.081%, `fid 53` at 0.114%) — these are genuine **area-twins** (21≈9, 30≈53), where a different zone is coincidentally 0.03–0.06 pp closer, though the assumed partner still matches to ~0.14%.
- **Under a strict "unique nearest by ≥2 pp margin" rule, 27 / 64 pass.** The other 37 have a same-size paddock within 2% of their area, so area alone is not a *unique* key for them.

**Interpretation.** Two readings, both true, and they must not be conflated:
- **Globally, the identity mapping `management_zone_i ↔ fid i` is strongly proven.** A permuted mapping cannot produce all 64 assumed pairs matching to <0.15% — most would be off by whole-zone area differences (up to 50 pp were seen against wrong partners). The uniform sub-0.15% match *is* the proof.
- **Per-zone, area is a weak unique discriminator** because paddock areas cluster. The 2 % competitor flag catches 37 zones and the 2 area-twins; that is a limitation of the *evidence*, not a sign the mapping is wrong.

**Consequence for the analysis (de-risking):** the grazed/ungrazed contrast that S4/S5 needs reads `Treatment` **straight from the gpkg** (verified clean in step 4), **not** from `dim_spatial_unit`. So `unit_id` is a labelling FK, not load-bearing for Gate C/D — leaving it NULL on the ambiguous zones does not block the science.

**Decision needed at this STOP — how Gate B should populate `unit_id` / `unit_id_verified`:**
- **(a)** Verify all 64 on the global-consistency argument (uniform 0.14% match + 62/64 assumed-nearest), recording the 2 area-twins (21↔9, 30↔53) as the only genuine ambiguities and disambiguating them via `plot_management_overlay` RAP-plot membership (the spec's option-3 evidence — covers the ~19 sampled zones); **or**
- **(b)** Apply the strict per-zone rule literally: 27 verified (`unit_id_verified=1`), 37 left `unit_id=NULL, unit_id_verified=0` and named. Safe, but under-verifies a mapping that is almost certainly wholly correct.

Recommendation: **(a)** — the global evidence is decisive and the strict rule discards it — but this is your call. `unit_id_margin_pct` will carry the per-zone margin either way for audit.

**6 · Area fields (`Area_MW` vs `area_ha_computed`).** Systematic offset: `area_ha_computed` is **0.21–0.28% smaller** than `Area_MW` for every zone (median −0.25%); sums 55,211.1 ha (computed) vs 55,347.7 ha (`Area_MW`). A uniform, single-signed offset = `Area_MW` was computed in a slightly different projection. **Reported, not corrected** (per spec). Gate B keeps both columns + `area_ha_diff_pct`.

**7 · Land-use fields.** Scanned every table and view for `crop|land_use|landuse|history|irrig|former`: **0 columns.** Confirms Ernest's land-use table does not yet exist; the five RESERVED Gate B columns are created empty by design.

---

## Open items into Gate B

- **Your decision on the `unit_id` verification policy (a vs b above).**
- Nothing blocks Gate B otherwise: zone attributes clean, areas computed, rasters geom-verified, parquet contract-clean.

**STOP.** Awaiting review before Gate B.
