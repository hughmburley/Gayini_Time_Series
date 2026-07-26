# T5 Gate 1 (+ Gate 2.4 pulled forward) — guardrails that fail

**Date:** 26 July 2026 · **Spec:** `docs/T5_guardrails_and_checks.md` v1 · **Status:** Gate 1 complete + Gate 2.4 snapshot generator. **STOP before T1 Gate C.** Rest of Gate 2 (QA views, `computed_at`, `v_qa_freshness`) deferred to after Gate C.
New: `R/gayini_params.R`, `scripts/lib/gayini_params.py`, `scripts/utils/lint_guardrails.py`, `scripts/utils/lint_baseline.json`, `scripts/utils/build_db_contract_snapshot.py`. Edited: `run_spine_smoke_test.R`, `register_T1_gateA0_zone_layer.py`, `T1_gateB1_figures.R`, `CLAUDE.md`.

---

## Two Gate B1 fixes (as directed)

1. **Figures `support_level = 'paddock'`, not `'zone'`.** The ladder is a closed vocabulary (that is what makes the column machine-checkable / the mixed-support detector possible); a management zone *is* a paddock (CLAUDE.md: "paddock — management zone, 99–2713 ha"). All four figures re-registered idempotently; the "zone/management-zone" precision moved into titles and captions.
2. **CLAUDE.md "Spatial layers" table → three objects.** The 8058 input (caps, registered, analysis input), the registered source shapefile `CA0561_ManagementZones.shp` (caps, EPSG:28355), and the `Gayini_Results.gpkg` companion (lowercase — the builder's import normalisation — NUL-padded, **build output, unregistered, cross-check only, never an analysis input**). Noted that registering the companion would be a category error (`spatial_layer_asset` is an import registry), so `read_registered_layer()` refusing it is correct.

## Gate 1.1 — single source of constants

`gayini_params.{R,py}`. `PIXEL_AREA_HA` is **derived** from `PIXEL_SIDE_M` (`= 0.06235142839918…`), never typed. Both run a **load-time DB self-check**: query `raster_asset.resolution_x`, `census_stratum.farm_area_ha`/`farm_area_total_ha`, `census_asset.n_rows` and **error on disagreement** (warn only if the DB is absent). Both pass against the live DB.

## Gate 1.2/1.3 — three lints, wired into the smoke test

`scripts/utils/lint_guardrails.py` (called from `run_spine_smoke_test.R`; fails the run on any **new** violation). The banned-literal list is imported from `gayini_params.MAGIC_LITERALS` — single source.

- **magic_number** — a banned bare literal (`0.0625 · 0.062351428 · 24.970268 · 67349 · 85910 · 1080157 · 988831 · 993782`) outside the param modules, anywhere under `scripts/`/`R/`.
- **or_ignore** — `INSERT OR IGNORE` in `scripts/11_database/` or any `*register*` file.
- **whole_digest** — `digest::digest(file=…)` (whole-file, wrong convention) in the same registrar scope.

**Baseline (`lint_baseline.json`, 15 entries).** Pre-T5 debt that cannot be rewritten now without invalidating already-registered checksums (the Task-M registrars' `OR IGNORE`, the gate-E whole-file `digest`) is baselined; the lint fails only on **new** violations, so the legacy debt stays visible and tracked without blocking the smoke test. Pay it down when each owning asset is next re-registered. **My own new violation was fixed, not baselined:** `register_T1_gateA0_zone_layer.py` `INSERT OR IGNORE INTO workflow_run` → `INSERT OR REPLACE`.

Current baseline (for the record): magic_number ×5 (`15_build_pixel_census_parquet.R:40`, `29_build_s12…:72`, `30_fix_d2…:20`, `taskM_gateD_M2_method.R:42`, `gayini_pixel_census_functions.R:185`); or_ignore ×9 (`01_build_results_database.py`, `register_d2_site_dashboards.py`, `register_taskM_gateC/D_assets.py`); whole_digest ×1 (`31_register_gateE_assets.R:34`).

## Gate 1.4 — every lint demonstrated to fail (recorded output)

```
[fixture-test] lints that fired on the broken fixtures: ['magic_number', 'or_ignore', 'whole_digest']
    FIRED [magic_number] scripts/_lint_fixture_magic.py:1  area = 0.0625  # banned literal
    FIRED [or_ignore]    scripts/11_database/register__lint_fixture.py:1  INSERT OR IGNORE INTO t …
    FIRED [whole_digest] scripts/11_database/register__lint_fixture.py:2  digest::digest(file=p)
[fixture-test] all three lints fire on a broken fixture: True
[fixture-test] fixtures removed.
```
The lints are also proven to fire on *real* code: they correctly identify the 15 baselined legacy violations (a lint that only ever passes has not been tested).

## Gate 2.4 — snapshot generator (pulled forward)

`scripts/utils/build_db_contract_snapshot.py` regenerates `docs/Gayini_Results_DB_contract_snapshot_<date>.xlsx` straight from the live DB, so it cannot drift the way the hand-maintained copy did. **Every sheet header carries its own as-of timestamp**; the two QA-derived sheets carry a red *"POINT-IN-TIME — re-derive before acting"* banner.

Regenerated now: **`docs/Gayini_Results_DB_contract_snapshot_20260726.xlsx`** (as-of 2026-07-26). 14 sheets incl. `05_Dim_management_zone` (64 zones) and `06_T1_zone_identity`. Headline counts for independent verification: **91 objects · `dim_management_zone` 64 · `spatial_layer_asset` 6 · `figure_asset` 259 · census `n_rows` 1,080,157**. Run it at the end of every task Gate C.

## Acceptance (Gate 1 slice) + deferrals

- [x] `gayini_params.{R,py}`; `PIXEL_AREA_HA` derived; load-time DB self-check.
- [x] Three lints in the smoke test; each demonstrated to fail on a fixture (output above).
- [x] `build_db_contract_snapshot.py` stamps an as-of date on every sheet.
- [x] Two Gate B1 fixes applied.
- [ ] **Deferred to after T1 Gate C** (per your instruction): 2.1 QA verdicts → live views, 2.2 `computed_at` + `v_qa_freshness`, 2.3 mark the 1-July rows superseded; and Gates 3–4.

**STOP.** Regenerated workbook: `docs/Gayini_Results_DB_contract_snapshot_20260726.xlsx`.
