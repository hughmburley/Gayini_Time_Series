# T7 Gate 0 — DEA Land Cover Level 3 extraction · recon note

**Task:** T7 — DEA Land Cover Level 3 extraction (`docs/reference_update/T7_dea_landcover_l3_extraction.md`, v1 · 28 Jul 2026)
**Gate:** 0 (inventory and recon, read-only) · **STOP**
**Date:** 28 July 2026
**Author seat:** CC (build)
**Writes performed:** none to the database; no branch commit. This note is the only new file.
**Toolchain:** R 4.6.1 `terra`/`sf` for rasters/vectors; Python 3.12 `sqlite3` for the DB. (No `rasterio`/GDAL/`arrow` present — not needed at Gate 0.)

---

## Verdict at a glance

| # | Gate 0 item | Result |
|---|---|---|
| 1 | Folder inventory, year range, **missing years** | 26 files, **2000–2025**. **1988–1999 absent (12 years).** |
| 2 | Per-file CRS/pixel/origin/dims/dtype/nodata, uniformity | **Fully uniform.** EPSG:7854, 30 m, 2189×1545, uint8, one extent. No header nodata flag set. |
| 3 | **Resampling integrity** (distinct values ⊆ {111,112,124,215,216,220,255}) | **PASS.** Global set = {111,112,216,220}. No unexpected value. NN reprojection confirmed. **No hard stop.** |
| 4 | Native EPSG:3577 available? | **QUESTION FOR HUMAN** — see §4. Supplied files already resampled 3577→7854 once. |
| 5 | Every year covers the full property boundary | **PASS.** Boundary bbox ⊂ raster extent, all 26 years; zero nodata pixels ⇒ wall-to-wall valid. |
| 6 | `fact_zone_veg_annual` overlap for §2.5 falsification | WY 1988–2022 vs DEA cal 2000–2025 ⇒ **23 overlapping years** per alignment. Ample. |
| 7 | `dim_management_zone` history cols NULL 64/64 | **PASS.** All five columns NULL on all 64 rows. |

**Two findings require a human decision before Gate A** (both in §8): the 1988–1999 gap that removes the two earliest eras (§1), and the input-path/registry mismatch for the 8058 boundary/plots/community vectors (§5b).

---

## 1. Folder inventory

`D:\Github_repos\Gayini\Input\landsat_landcover\level3`

- **File count:** 26 GeoTIFFs (+ 2 style files: `LLC3_colourscheme.lyrx`, `ga_ls_landcover_class_cyear_3_style.qml`).
- **Naming pattern:** `LLC3_{YYYY}_MGA54.tif` (MGA54 = MGA zone 54 = EPSG:7854). *Note: different from the pilot's naming; same grid.*
- **Year range:** **2000–2025, continuous** (no gaps within that span).
- **File sizes:** 331 KB (2011) – 703 KB (2022); typical ~0.5–0.6 MB. Small because categorical uint8 compresses well.

### Missing years — the load-bearing finding

The task exists to test the pre-record disturbance hypothesis, and §1 of the spec is explicit: *"Bala 29ca's deficit is largest in **1988–1992** and closes monotonically thereafter … **The 1988–2012 years are the reason this task exists.**"*

- **Present from the target window (1988–2012):** 2000–2012 → **13 of 25 years.**
- **Missing:** **1988–1999 → 12 years, entirely absent.**
- The single most important sub-window, **1988–1992, has zero files.**

DEA Land Cover v2.0.0 (`ga_ls_landcover_class_cyear_3`) has an annual record back to **1988**, so these years should be obtainable from source. Their absence here is a supply gap, not a product limit.

**Consequence for the pre-registered eras (§2.3):**

| Era | Years present / total | Status under §2.4 |
|---|---|---|
| **1988–1992** | **0 / 5** | `dea_indeterminate` (0 valid years) — **uncomputable** |
| **1993–2002** | **3 / 10** (2000–02) | `dea_indeterminate` (< 5 valid years) |
| 2003–2012 | 10 / 10 | computable |
| 2013–2018 | 6 / 6 | computable |
| 2019–2022 | 4 / 4 | computable |
| 2023–2025 | 3 / 3 | computable (this is the floor window §2.2) |

The two eras that the reference-state finding actually turns on (**1988–1992** and **1993–2002**) fall out as indeterminate under the pre-registered rule. **The task as specified cannot address the window it was created to address unless the 1988–1999 years are supplied.** This is a genuine STOP item, not a caveat to work around.

## 2. Per-file characteristics — fully uniform

Every one of the 26 files:

| Property | Value |
|---|---|
| CRS | **EPSG:7854** (GDA2020 / MGA zone 54) — matches the pilot |
| Dimensions | 2189 × 1545 |
| Pixel size | 30 m × 30 m |
| Origin (xmin / ymax) | 747300.0 / 6201300.0 — matches the pilot exactly |
| Extent | xmin 747300, xmax 812970, ymin 6154950, ymax 6201300 (identical across all 26) |
| Data type | uint8 (`INT1U`) |
| Nodata | **No nodata flag set in header** (`terra::NAflag` = NaN). The v2.0.0 convention value 255 does not occur anywhere (see §3). |

**No file departs from the rest on any property.** Nothing to flag under item 2.

**Nodata note for Gate B:** because no header nodata is set *and* 255 never occurs inside the clip, the `level3 ≠ 255` denominator (§2.1) will include every pixel and `n_pixels_nodata` will be 0 within these rasters. The rasters are a filled bounding rectangle around the property, not a boundary-masked cutout — masking to zone/plot/boundary geometry at Gate B is what restricts to the property.

## 3. Resampling integrity check — PASS (no hard stop)

Distinct pixel values were tabulated with `terra::freq` over **all 26 files**.

- **Per file:** every year contains exactly {111, 112, 216, 220}.
- **Global set across the series:** **{111, 112, 216, 220}** — i.e. CTV, NTV, NS, Water.
- Not present anywhere: 124 (NAV), 215 (AS), 255 (nodata).
- **⊆ {111, 112, 124, 215, 216, 220, 255}? YES.**
- **Unexpected values: none.**

Only valid LCCS Level 3 codes are present, which — per §1 of the spec — is the evidence that the 3577→7854 reprojection used **nearest-neighbour**. No interpolated/intermediate value (e.g. 113, 118) appears in any year. **The series does not need rebuilding on integrity grounds.** The acceptance criterion "distinct pixel values ⊆ {…}" is satisfied.

## 4. Native EPSG:3577 — QUESTION FOR HUMAN (spec Gate 0 item 4)

The supplied files have already been resampled once (**DEA native 3577 → 7854, nearest-neighbour**). Gate B will reproject *vectors to the raster*, so no *second* raster resampling is planned — the integrity check passing means the one resampling that happened was clean. Sampling from native 3577 would nonetheless avoid ever compounding a resampling error and is the spec's stated preference *if available*.

**Observed provenance clues (not yet inspected in depth):** a notebook `Input/landsat_landcover/gayini_landuse.ipynb` and a sibling `Input/landsat_landcover/level4/` folder exist and likely document how the 7854 rasters were produced (DEA STAC/sandbox pull → reproject). These would show whether native 3577 tiles were retained.

**→ Decision needed:** are DEA-native EPSG:3577 tiles or continental mosaics available (or re-pullable)? If yes, the spec prefers building from them. If no, proceeding from the clean 7854 series is acceptable given the integrity pass — record the decision either way.

## 5. Coverage and inputs

### 5a. Property coverage — PASS

Property boundary (`gayini_boundary`, 8058) reprojected to 7854, bbox **748433 / 804330 / 6161371 / 6194994**, sits fully inside the raster extent **747300 / 812970 / 6154950 / 6201300** with margin on all four sides. This holds for all 26 years (identical extents). Combined with zero nodata pixels, **every year provides full valid coverage of the property.** No year fails item 5.

### 5b. Input vectors — registry/path mismatch to resolve before Gate B

The spec §3 names 8058 inputs `management_zones_epsg8058.gpkg`, `gayini_hectare_plots_epsg8058.gpkg`, `gayini_boundary_epsg8058.gpkg`, `vegetation_communities_epsg8058.gpkg`, and says *"resolve paths from `spatial_layer_asset`, not hardcoded."* What is actually on disk / in the registry:

| Input | In `spatial_layer_asset`? | Reality |
|---|---|---|
| Management zones (8058) | **Yes — `spatial_006`**, `Output/spatial_8058/management_zones_epsg8058.gpkg`, EPSG:8058, 64 features, `path_exists=1` | ✔ resolvable as the spec intends |
| Property boundary (8058) | **No** | 8058 version exists only as a **layer inside `Input/gayini_vectors_8058.gpkg`** (unregistered). Registered `gayini_boundary` (`spatial_002`) is EPSG:**4283** in `shapefiles.zip`. |
| Plots (66, 8058) | **No** | Layer `plots` inside `gayini_vectors_8058.gpkg`. Registered `plots_source` (`spatial_001`) is EPSG:**7854** in `shapefiles.zip`. |
| Vegetation communities (5, 8058) | **No** | Layer `vegetation_communities` inside `gayini_vectors_8058.gpkg`. Registered `vegetation_units` (`spatial_003`) is EPSG:4283, and is the **20-feature** units layer, not the 5-feature community layer. |

`Input/gayini_vectors_8058.gpkg` layers: `gayini_boundary` (1), `vegetation_units` (20), `plots` (66), `management_zones` (64), `irrigation_bank_cuts` (1158), `vegetation_communities` (5), `gauge_sites` (6), `layer_provenance` — all GDA2020 / NSW Lambert (8058).

**→ Decision needed before Gate B:** either (a) register the 8058 boundary/plots/community layers into `spatial_layer_asset` first (the T1 Gate A0 pattern — additive, one row each), or (b) resolve them from the unregistered `gayini_vectors_8058.gpkg`, or (c) reproject the registered 4283/7854 shapefiles. Option (a) is most consistent with the "paths from the DB" rule and with how the zone layer was handled. *This is not blocking for Gate 0; it is the first thing Gate A/B must settle.*

## 6. `fact_zone_veg_annual` overlap for the §2.5 falsification test

- `fact_zone_veg_annual`: **water years 1988–2022** (35 years), **64 zones**, two `series_variant`s — `mean_of_seasons` (2,240 rows) and `jja_son` (2,116). Carries `flood_frac_pct`, `veg_mean`, `veg_p05_spatial`. The spec's §2.5/§3 comparator (`series_variant='mean_of_seasons'`) is present.
- **DEA calendar years:** 2000–2025.
- **Overlap** (per §6 of the spec, both candidate alignments must be reported):
  - `water_year = dea_calendar_year`: **cal 2000–2022 → 23 matched years.**
  - `water_year = dea_calendar_year − 1`: **DEA cal 2001–2023 → WY 2000–2022 → 23 matched years.**
- Either alignment gives 23 zone-year-matched points per zone — ample for `corr(dea_ctv_pct, flood_frac_pct)` and `corr(dea_ctv_pct, veg_mean)`. Note the falsification test can only run **2000 onward**; the pre-2000 years (were they supplied) would have **no** veg/flood comparator beyond 1988, so the test naturally covers only the 2000–2022 intersection regardless.

## 7. `dim_management_zone` history columns — baseline PASS

64 rows. NULL counts:

| Column | NULL / total |
|---|---|
| `cropping_history` | 64 / 64 |
| `land_use_era` | 64 / 64 |
| `irrigation_status` | 64 / 64 |
| `history_source` | 64 / 64 |
| `history_confidence` | 64 / 64 |

All five RESERVED columns are NULL on every row — the baseline the acceptance check (§4, §7) must preserve to the end of the task.

### Idempotence baseline (clean)

- `dim_source_product`: 6 rows (`MER, MODIS, daily_landsat_inundation, gauge, landsat_fractional_cover, landsat_inundation`). **No `dea_landcover_l3` row.** Columns match the spec §4 block exactly (`product_id, product_name, sensor_family, method_summary, caveat`).
- `raster_asset`: **0** DEA/landcover rows.
- **No `dea_`-prefixed tables or views exist.** Gate A/B/D start from a clean slate — the "re-run twice, identical checksums" idempotence proof has a clean baseline.

---

## 8. STOP — items needing human sign-off before Gate A

1. **1988–1999 missing (12 years).** This removes the `1988–1992` and `1993–2002` eras (indeterminate under §2.4) — precisely the window §1 says the task exists to test. **Options:** (a) supply/re-pull 1988–1999 from DEA source before proceeding; (b) proceed on 2000–2025 with the pre-1993–2002 eras formally reported as indeterminate and the deck told the pre-record window is untestable from this data. Recommend (a) if the years are obtainable, since the task's core question is otherwise unanswerable.
2. **Native EPSG:3577 availability (§4).** Confirm whether native tiles exist / are re-pullable; if so the spec prefers building from them. Otherwise record the decision to proceed from the clean 7854 series (integrity passed).
3. **8058 vector registry (§5b).** Decide how Gate B resolves boundary/plots/community inputs — recommend registering the three 8058 layers into `spatial_layer_asset` first, per the T1 Gate A0 precedent.

## 9. Note — spec name collision (non-blocking)

`docs/reference_update/Gayini_reference_state_specs_T7_T11.md` also defines a task numbered **"T7 — Persistence surface: recolour, overlay, vectorise"**, unrelated to DEA Land Cover. The authoritative live T7 is the standalone `T7_dea_landcover_l3_extraction.md` (this note follows it). The T7_T11 bundle's "T7" appears superseded/renumbered by the DEA task. Flagging so a later reader does not act on the wrong T7; **not a Gate 0 blocker.**

---

**Gate 0 complete. No database writes performed. STOPping for review per the spec.**
