# Tier 0 — change report

**Task:** `tier0-annual-stack` — build the annual analysis foundation
**Branch:** `feature/tier0-annual-stack` (pushed to origin; PR to `main` pending, do-not-merge)
**Date:** 2026-07-07
**Commits:** `e713419` → `0940b84` → `4eaf25f` → `f00a135` (on top of `0da0bfb`)

All three acceptance gates passed: **0.1 = 14/14, 0.2 = 4/4, 0.3 = 6/6.**

---

## A. Committed to git (5 files across 4 commits)

### Step A — repo hygiene · commit `e713419`
- `.gitignore` — **+8 lines**: Tier 0 guard block (`Output/rasters/`, `Output/database/*.sqlite`, `Output/database/*.gpkg`, `data_intermediate/`, `*.img`, `*.tif`). Confirmed no guarded paths were already tracked.

### Sub-step 0.1 — unified annual stack · commit `0940b84`
- `scripts/03_inundation_products/05_build_unified_annual_stack.R` — **new (+23)**: thin `GAYINI_ROOT` wrapper.
- `scripts/03_inundation_products/internal/05_build_unified_annual_stack_impl.R` — **new (+279)**: enumerates 35 `lo_*.img` sources, cross-checks against `stg_canonical_annual_inundation`, derives `wet_any`/`valid_any` (wet rule `>0`), assigns EPSG:28355 to untagged MGA-zone-55 sources, nearest-neighbour resamples to the 25 m reference grid, writes two 35-layer GeoTIFFs + manifest, runs the background cross-check, and idempotently registers both stacks in `raster_asset`.

### Sub-step 0.2 — raster metadata + legend · commit `4eaf25f`
- `R/raster_catalog_functions.R` — **+59 lines**: added `gayini_infer_metric_id()`, an ordered rule-based filename→metric_id parser (12 generalizing families, no per-file hardcoding).
- `scripts/01_prepare_inputs/03_populate_raster_metadata.R` — **new (+194)**: reads CRS/extent for every `raster_asset` via terra, adds `crs_epsg` column, writes CRS/extent/resolution + metric_id back to the DB, and emits the legend confirmation sheet.

### Sub-step 0.3 — analysis-spine view · commit `f00a135`
- `scripts/11_database/01_build_results_database.py` — **+69 lines**: `CREATE VIEW v_plot_year_analysis_spine` (plot × water-year spine: 4 inundation metrics pivoted from `fact_plot_year` + water-year-mean ground cover + `dim_plot` attributes), plus a `view_purpose` entry, an `expected_key` entry, and a critical `qa_check` (`v_plot_year_analysis_spine_shape`) feeding `v_database_release_checks`.

---

## B. Generated artifacts (gitignored — NOT committed, reproducible from the code above)

| File | Notes |
|---|---|
| `Output/rasters/inundation_annual_stack/annual_wet_any_1988_2023.tif` | 35-layer wet stack (~17 MB) |
| `Output/rasters/inundation_annual_stack/annual_valid_any_1988_2023.tif` | 35-layer valid stack (~3 MB) |
| `Output/csv/annual_stack_manifest.csv` | 35 rows |
| `Output/csv/annual_stack_crosscheck.csv` | 26 rows (14 exact-match vs background) |
| `Output/reports/legend_confirmation_for_adrian.md` | 3 product families flagged |
| `Output/database/Gayini_Results_data_dictionary.xlsx` | regenerated to include the new view + release check |
| `data_intermediate/terra_tmp/annual_stack/` | 120 transient per-year temp rasters (safe to delete) |

Per the standing decision, these `Output/` artefacts stay gitignored/reproducible-from-code (repo policy blanket-ignores `Output/`).

---

## C. Database state changes — `Output/database/Gayini_Results.sqlite` (gitignored; mutated in place)

- **0.1:** +2 rows in `raster_asset` (`stack_annual_wet_any_1988_2023`, `stack_annual_valid_any_1988_2023`) → 98→100.
- **0.2:** added column `raster_asset.crs_epsg`; populated `crs_epsg`/`crs`/extent/resolution for all 100 assets; filled `metric_id` for 82 assets → 100% coverage.
- **0.3:** created view `v_plot_year_analysis_spine`; +1 `qa_check` row (`v_plot_year_analysis_spine_shape`, critical, PASS).

**Durability caveat:** the Python builder does `path.unlink()` + full rebuild and cannot read CRS (no GDAL at build time). So B's 0.1 registration and 0.2 CRS/metric_id population are **post-build mutations a rebuild wipes**. Required order after any rebuild: builder → `03_populate_raster_metadata.R` → `05_build_unified_annual_stack.R`. The 0.3 view lives in the builder and survives rebuilds.

---

## D. Out-of-repo change

- `~/.claude/settings.json` — added `"attribution": { "commit": "", "pr": "" }` (suppresses the Co-Authored-By trailer and generated-with footer on future commits/PRs).

---

## E. Key findings surfaced

1. **Wet-rule / legend (for Adrian):** `lo_*.img` values are `{0,1,2}` with no NA cells; `>0 = wet` treats **value 2 as wet** (`legend_status = unconfirmed`). Flagged in the legend sheet, not changed silently.
2. **Mixed source grid:** 25 m ×27, 30 m ×3, 10 m ×5; 32/35 files untagged but GDA94/MGA-zone-55 → assigned EPSG:28355 (lossless), then nearest-neighbour resampled to 25 m.
3. **Cross-check:** vs `background_strict`, 14/26 overlapping years match to the exact cell (median 0%); remaining divergences are nearest-vs-max resampling, not wet-rule errors.

---

## F. Not part of Tier 0 (noted for completeness)

- Untracked `docs/Gayini_remote_sensing_reference_workbook_{verified,expanded}_20260707.xlsm` appeared during the session but were **not written by this work** (user-side Excel activity); left untouched.
