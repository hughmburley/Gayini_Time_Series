# T1 Gate 0 — Inventory before code (read-only)

**Date:** 25 July 2026 · **Spec:** `T1_zone_stratum_census_join.md` v2 · **Status:** Gate 0 complete, **STOP for review**.
No code written, no DB touched, no branches. Structural facts read from `Gayini_Results_DB_contract_snapshot_20260725.xlsx`; file contents read directly from disk (gpkg, parquet, CSV) read-only.

---

## 1. Reuse table — the nine needs

| # | Need | Existing implementation (file : function / lines) | Reusability |
|---|---|---|---|
| 1 | Read census parquet | **Python:** `scripts/11_database/taskM_gateD_p05_distribution.py:57` DuckDB `read_parquet('…8058.parquet')` + aggregate — closest template. **R:** `arrow` already a dep (`scripts/03_inundation_products/15_build_pixel_census_parquet.R:236` writes it); reader is a bare `arrow::read_parquet()`. | **Reusable** (idiom/template present; no wrapper needed) |
| 2 | Reconcile to `census_stratum` | `scripts/03_inundation_products/09_build_pixel_census_view.R:224-306` — full recon accounting (`classified_valid_area_ha` + `masked_out_area_ha` vs `sum_stratum_area_ha`, diff, QA gate, computed `pixel_area_ha`). `R/gayini_pixel_census_functions.R:186` writes `census_stratum`. | **Callable w/ changes** (add zone dimension to the group-by) |
| 3 | Point-in-polygon / spatial join | `scripts/03_inundation_products/10_build_veg_regime_checkerboard.R:198-200` `sf::st_intersects(pc, management)` (point→management-zone); also `R/gayini_f5_legibility_figures.R:166` `st_within(pts, management)`, `R/gayini_dashboard_compose.R:202`. | **Callable w/ changes** (swap 66 centroids → 1.08 M census `(x_8058,y_8058)`; watch scale/perf) |
| 4 | Existing plot→zone assignment | `scripts/11_database/01_build_results_database.py:1684` builds `plot_management_overlay`; checkerboard `plot_zone_rows` at `10_…:200`. **This is the closest analogue to Gate C**, as the kick-off predicted. | **Callable w/ changes** |
| 5 | Raster zonal statistics | `terra::extract(…, fun=…)` widespread: `R/gayini_dashboard_compose.R:119`, `R/gayini_trend_test_functions.R:108`, `R/gayini_mer_raster_functions.R:762`. | **Present but not the right tool** — Gate C aggregation is tabular (group-by on the parquet), so need #2's path is used, not raster zonal |
| 6 | SHA-256, first-50-MB convention | `scripts/11_database/register_taskM_gateC_assets.py:96` `sha256_first50()` and `register_d2_site_dashboards.py:38` — **exact** builder convention (`50*1024*1024`, 1 MB chunks). | **Callable as-is.** ⚠ The R registrars (`31_register_gateE_assets.R:33`, `14`, `15`) use whole-file `digest::digest(algo="sha256")` — a *different* convention; matters only >50 MB, but use the Python `sha256_first50` to satisfy "builder convention" |
| 7 | Additive / idempotent registration | `scripts/11_database/register_taskM_gateC_assets.py` — full template: `check`/`execute` modes, idempotent `ALTER TABLE ADD COLUMN`, `INSERT OR IGNORE`, dry-run CSV, `workflow_run` insert, PK dedup. `register_d2_site_dashboards.py` is a leaner twin. | **Callable w/ changes.** ⚠ Spec says `INSERT OR REPLACE`; existing pattern is `INSERT OR IGNORE` (both idempotent; OR IGNORE will not update on a changed checksum) |
| 8 | Figure write + register | Write: `R/gayini_figure_manifest.R`, `gayini_plot_area_map()` (used by the checkerboard) for zone maps. Register: `register_taskM_gateC_assets.py::build_figure_rows` / `register_d2_site_dashboards.py` → `figure_asset` (cols `figure_asset_id,path,title,domain,metric_id,recommended_use,checksum_sha256,path_exists,qa_status,run_id`). | **Callable w/ changes.** ⚠ Spec demands **write + register in one transaction**; every existing path writes in R and registers later in Python — the same split that produced the unregistered backlog. "Same transaction" is genuinely **new integration work** |
| 9 | Zone name parse (`Bala 26ca`→`Bala`) | No dedicated parser. `stringr::str_extract`/`str_remove` idioms are everywhere (e.g. `07_figures_dashboards/06_refresh_main_deck_figures.R:397`). | **None found — trivial new** (`str_extract(zone_name, "^[A-Za-z]+")`; groups = Bala/Mara/Dinan) |

---

## 2. Estimated new code

Reuse is high (~60–75%, as the kick-off expected). Genuinely new, all small and mostly adapted:

- **Gate A0** — one `spatial_layer_asset` row for the 8058 gpkg (adapt the Python registrar).
- **Gate A** — the F5 identity check (MODIS `area_ha` ↔ gpkg per-`fid` area). New, ~30 lines. Plus additive backfill of `raster_asset` `xmin/…/ymax` for the 8058 products (values already read here; free).
- **Gate B** — `dim_management_zone` DDL + `INSERT OR REPLACE` (mechanical; zone-name parser is 1 line).
- **Gate C** — pixel→zone `st_intersects` at 1.08 M scale (adapt checkerboard) + assignment parquet sidecar + `v_census_by_zone_stratum` (adapt the `09` aggregation/recon).
- **Gate D** — `v_zone_stratum_treatment_contrast` (one SQL view).
- **Figures** — 6 maps/bars via `gayini_plot_area_map`; the **only** novel piece is write-and-register-in-one-transaction.

Net: ~4–6 small scripts. No new parquet reader, reconciler, SHA helper, registrar, or spatial-join engine is required — all exist.

---

## 3. Already built that the spec assumes missing

- **`management_zones_epsg8058.gpkg` is genuinely EPSG:8058** (header: `GDA2020 / NSW Lambert`, srs_id 8058), 64 features. Gate A0's precondition is satisfied — **no reproject**.
- **`Area_MW` and `ManagmentZ` exist** in that 8058 layer (see §4-C1). Spec F8 says neither does.
- **Zone text is already clean** — `ManagmentZ`/`Treatment`/`Plots` are unpadded strings; no NUL-strip needed for this input (§4-C2).
- **`plot_rs_analysis_base.csv` is present** at `Output/csv/canonical/plot_rs_analysis_base.csv` (on disk; `Output/` is gitignored, so absent from git, present locally). Kick-off/spec call it "missing, blocks 05."
- **Census parquet checksum already matches.** Computed first-50-MB SHA-256 = `6b23f6c0803b69af…46f966`, matches the registered `census_asset` prefix `6b23f6c0803b69af…`. File 25.49 MB (<50 MB, so first-50 == full file). Do not rebuild.
- **`sha256_first50` helper already exists** (§1-6) — the convention need not be re-derived.

Not built (spec is right): `dim_management_zone`, `v_census_by_zone_stratum`, `gayini_pixel_zone_assignment.parquet` — **none** exist (Objects sheet + disk sweep, incl. no `_archive/` or half-built remnant). `spatial_layer_asset` has 5 rows, no 8058 zone layer.

---

## 4. Where the spec contradicts the repo (evidence)

**C1 — HIGH. Amendment F8 inspected the wrong layer; it is false for the Gate A0 input.**
The 8058 gpkg (`management_zones_epsg8058`), which Gate A0 registers and Gate C mandates, has fields:
`fid, geom, OBJECTID_1, OBJECTID_2, ManagmentZ, Area_MW, Treatment, Plots`.
Verified rows: `fid=1 → ManagmentZ='Bala 26ca', Area_MW=2064.18, Treatment='No grazing', Plots='Sample'`. `Area_MW` spans **99.49–2712.56 ha, sum 55,347.73** — matching the spec's own Gate B figure range ("~99–2,713 ha") exactly.
F8's "neither field exists" describes `Gayini_Results.gpkg:management_zones` — a **different** layer (EPSG:28355, lowercase `management_zone/treatment/plots`), *not* the registered input. Consequence: (a) the Gate B rename rationale ("no `Area_MW` to read") is void — computing area from 8058 geometry is still the better choice, but the column *could* read `Area_MW`; (b) **more dangerous:** any Gate B/C code that reads `management_zone`/`treatment`/`plots` (lowercase) from the 8058 layer will fail — the real names are `ManagmentZ`/`Treatment`/`Plots`.

**C2 — MED. NUL-padding is a `Results.gpkg` artefact, absent from the 8058 input.**
In the 8058 layer, `Treatment` ∈ {`14-day grazing` (60), `No grazing` (4)} and `Plots` ∈ {`Sample` (19), NULL (45)} are clean; `Treatment = 'No grazing'` compares equal directly (verified). The spec's mandatory NUL-strip is a harmless no-op **for this input**. (Keep a defensive strip only if the code ever reads the 28355 `Results.gpkg` layer instead.)

**C3 — MED, and it is good news. F5 identity looks provable, not merely deferrable.**
`modis_context_units_summary.csv` carries a per-zone `area_ha` (zone_1 = 2062.52, zone_11 = 255.84, zone_12 = 1251.21…). For `management_zone_1` this is **2062.5 ha vs gpkg `fid=1` `Area_MW` 2064.2 ha — a 0.08% match.** So Gate A's independent-evidence check (area agreement per index↔`fid`) is likely to **CONFIRM** the alignment rather than fall back to `unit_id = NULL`. The spec frames the null outcome as the expected one; Gate A should actually run the area comparison across all 64 before assuming it. (The MODIS `source_name` column holds only the integer index "1"…"64", so the *name-match* evidence path fails — use area/centroid, not name.)

**C4 — context, corroborated. The "18% unzoned" expectation checks out.**
Zone `Area_MW` total 55,347.73 ha vs mapped census 67,349.332 ha → **~17.8% of mapped area outside zones**, consistent with the spec's 12,179 ha / 18% (from an unreproduced in-chat run). Reproduce independently in Gate C, but the magnitude is sound.

**Minor state corrections vs the kick-off/spec landmine list:**
- `figure_asset` currently has **255 rows** (Objects sheet), not "139." The 139 is stale; the `db_build_20260701` rows are already labelled `superseded` by the Gate C registrar. Don't treat 139 as current.
- `scripts/_deprecated/` **still exists** (`01_lag_diagnostics_inundation_gc.R`); `scripts/archive/` is **absent**, so the spine smoke test currently passes. Not T1's job — left untouched.
- ~~`raster_asset` extent columns confirmed empty (QA `raster_asset_crs_extent_populated`: 98/98 lack CRS+extent)~~. **CORRECTED at Gate A (see `T1_gateA_recon.md` §3):** this read the *QA table*, which is stale (dated 2026-07-01). Reading the *data* shows **0 of 126** rows have a NULL extent — all 18 crs_epsg=8058 rows are populated and match their headers. The backfill is a no-op. Lesson: the DB's own QA/release tables are stale artefacts; re-derive from data, never quote them as current.

---

**STOP.** Awaiting review before Gate A0.
