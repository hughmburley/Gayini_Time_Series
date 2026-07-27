# T1 — Gate C: pixel→zone join, `v_census_by_zone_stratum`, reconciliation

**Date:** 26 July 2026 · **Spec:** `T1_zone_stratum_census_join.md` v3, Gate C · **Status:** complete, reconciled at diff = 0. **STOP.**
Scripts: `T1_gateC_pre_spatial_checksums.py`, `T1_gateC_assign.R`, `build_T1_gateC_zone_stratum.py`, `T1_gateC_figures.R`. Artefacts: `Output/census/gayini_pixel_zone_assignment.parquet`, `Output/tables/T1_gateC_reconciliation.csv`, `Output/figures/diagnostics/T1_C_*.png`.

## Two pre-steps (as directed)

- **Content integrity on all six spatial layers.** `checksum_sha256` + `path_exists` were on `spatial_006` only; filled the other five with first-50-MB SHA-256 — two hashes cover five rows (`shapefiles.zip` for spatial_001–004, the gauge sqlite for spatial_005). Now 6/6. `read_registered_layer()` can check content integrity on every row.
- **Baseline fails closed on growth.** `lint_guardrails.py` now prints the baseline count every run and **errors if it exceeds `BASELINE_LOCK` (15)**. Growing the baseline requires bumping the constant in code — a visible, reviewable change — so nobody can silently append a suppression. (Demonstrated: a 16th entry → exit 1.)

## The join — reused, not rewritten

`T1_gateC_assign.R` adapts `10_build_veg_regime_checkerboard.R:198-200` (`sf::st_intersects(points, management)`, first match) from 66 plot centroids to the **1,080,157 census pixels**. Both inputs EPSG:8058, no reprojection. **4.7 s.**

- **zoned 885,292 · unzoned 194,865 · total 1,080,157.**
- My unzoned count is **194,865 — identical to the in-chat prior**, reproduced independently. No material difference to flag.
- Unzoned pixels are **retained with `zone_fid = NULL`** and surfaced as an explicit `unzoned` class (11 rows in the view). Never dropped.

## Products

- **Sidecar parquet** `gayini_pixel_zone_assignment.parquet` (`pixel_id`, `zone_fid` only), registered in `census_asset` (`census_zone_assignment_8058`, `n_rows` 1,080,157, first-50-MB SHA-256). The primary census parquet is **not** widened.
- **`census_by_zone_stratum`** (new table, 381 rows) + **`v_census_by_zone_stratum`** (view). **Area from `gayini_params.PIXEL_AREA_HA`** (= 0.062351428…), never a literal — the lint caught and I fixed one bare `1080157` that had slipped into a column-label string in my own build script (the lint working as intended). Every view row carries `support_level = 'pixel'` and `aggregation_unit = 'zone_stratum'` (the composite term was split — see Notes).

## Reconciliation — diff = 0

- **`Σ zoned + unzoned = 1,080,157`, diff = 0.**
- **Area per stratum vs `census_stratum`: max diff 0.0005 ha** (< 0.1 ha; pure rounding). View area sums to 67,349.33 ha (the mapped basis).
- **Unzoned area — three ways, and "zones ⊆ mapped" is now measured, not assumed:**

  | basis | unzoned area (ha) | what it is |
  |---|---|---|
  | (A) pixel count × `PIXEL_AREA_HA` | **12,150.11** | mapped census pixels outside every zone |
  | (B) mapped − Σ zone geometry (`area_ha_computed`) | **12,138.20** | holds only if zones ⊆ mapped |
  | (C) 194,865 × 0.0625 | ~~12,179.06~~ | **withdrawn** — the same count with the wrong constant, *not* an independent estimate |

  (A) − (B) = **11.91 ha = 0.0216 % of zone geometry**: zone polygons extend only ~0.02 % beyond the mapped census area. So the "zones are a subset of mapped area" assumption is **measured** (negligibly false), not untested. (C) was never a second opinion — it was the pixel count × the 25 m nominal, exactly the error `gayini_params` now prevents.

## Figures (via `write_and_register_figure()`, `support_level='pixel'`)

- **`T1_C_pixel_assignment_map.png`** — zoned (grey) vs unzoned (magenta) `geom_bin2d` density in EPSG:8058. The unzoned form **coherent solid blocks** (whole areas outside the management-zone set) plus thin **boundary slivers** (edge pixels whose centroid falls just outside a polygon) — decisively a real geometry gap, **not scattered join-bug noise**. (`geom_hex` needs the absent `hexbin` package; `geom_bin2d` used instead. Mixing `geom_sf` with a raw-coord `geom_hex` misaligned them — fixed by plotting both in projected metres with `coord_equal`.)
- **`T1_C_reconciliation_bar.png`** — stacked zoned 885,292 + unzoned 194,865 = Σ 1,080,157, **diff = 0 annotated**.

## Notes / small judgment calls

- **Support term split into two columns** (spec correction, applied to this view now so Gate D inherits it): `support_level = 'pixel'` (closed ladder — what the support *is*, keeps T5 4.4's mixed-support detector enumerable) **and** `aggregation_unit = 'zone_stratum'` (free text — what it is aggregated *to*). The earlier composite `'pixel_within_zone_stratum'` conflated the two and would have forced a hardcoded synonym list. The figures' `'pixel'` was already right.
- Idempotent: `build` re-run → identical 381 rows, diff = 0. Intermediates in `Output/census/_tmp/` (gitignored).
- **Snapshot regenerated:** `docs/Gayini_Results_DB_contract_snapshot_20260726.xlsx` (as-of 09:21 UTC) — 93 objects, `census_by_zone_stratum`/`v_census_by_zone_stratum` = 381, `census_asset` = 2, `figure_asset` = 261.

## Open for Gate D

`v_census_by_zone_stratum` is the substrate for Gate D's `v_zone_stratum_treatment_contrast` (ungrazed−grazed `veg_p05_delta` beside `flood_freq_delta`, nine non-treed strata). Grazed/ungrazed rows per zone×stratum are present and populated.

**STOP.** Regenerated workbook: `docs/Gayini_Results_DB_contract_snapshot_20260726.xlsx`.
