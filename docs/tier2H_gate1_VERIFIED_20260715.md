# Tier 2 · Task H — Gate 1 VERIFIED findings & corrections

*Design-seat independent verification, 15 Jul 2026. Every claim below was measured against the actual rasters, the boundary vector, the live `Gayini_Results.sqlite`, and the R source — not taken from the recon report or the raster catalogue. Supersedes the corresponding sections of the Gate 1 recon report.*

**Gate 1 is SIGNED OFF.** Proceed to Gate 2. Corrections C1–C8 below are binding.

---

## 1. Q1 — FC coverage: CLOSED, no clip

Tested `gayini_boundary.shp` against the FC extent directly (not a figure, not the catalogue).

| | |
|---|---|
| Farm total (boundary vector, projected to 8058) | **85,910.8 ha** |
| Inside FC extent | **85,910.8 ha — 100.0000%** |
| Outside FC | **0.0 ha** |
| Edge clearance | S **+2,956 m** · W +3,122 m · E +4,540 m · N +3,809 m |

The southern-edge concern in the spec (§Gate 1 Q1) is **resolved and closed**. No clipping. No affected strata. Do not re-raise it.

Note for the record: comparing FC to the *census grid extent* is the wrong test and gives a false alarm — the census grid is 100.8 × 60.5 km while the farm is only 56.4 × 33.3 km. The grid extends well beyond the property. Test against the boundary vector.

## 2. Q4 — FC band semantics: CLOSED, no offset trap

Measured on 4 files spanning the series (`m198712198802`, `m199403199405`, `m201306201308`, `m202512202602`).

| Element | Confirmed value |
|---|---|
| Band 1 | Bare ground (BS) — **excluded** from total veg |
| Band 2 | Green / photosynthetic vegetation (PV) |
| Band 3 | Non-green / non-photosynthetic vegetation (NPV, "dead") |
| dtype | `uint8` |
| nodata | **255** — set in the file, identical across all 3 bands |
| Offset | **NONE.** Values are plain percent. |
| Legal range | 0 – ~103 observed per band |
| CRS | **EPSG:3577 CONFIRMED** from file WKT (`GDA94_Australian_Albers`, `Geocentric_Datum_of_Australia_1994`) — proven, not inferred. 9473 ruled out. |

**`PV + NPV + BS` sanity check: PASSES.** min 96 · max 111 · **mean 98.51 · median 99**; 96.5–96.9% of valid pixels sum to 98–102. That is the expected unmixing residual for a plain-percent product. If it were the +100-offset variant the sum would be ~400.

`total_veg = band2 + band3` ≤ ~110 → **fits uint8, no overflow**. Exclude 255 before any percentile.

**Action:** write this into `raster_asset.legend_semantics` and flip `legend_status` to `confirmed`.

## 3. Q2 — the bridge mechanism: CONFIRMED, and it goes further than reported

Verified in source. `R/gayini_stratified_sampling_functions.R:96-97`:

```r
freq_8058  <- terra::project(freq_supported, tcrs, method = "bilinear")
valid_8058 <- terra::project(valid_count,    tcrs, method = "near")
```

The actual chain:

```
annual stack (EPSG:28355, binary, 25.0 m)
  → wet_count / valid_count via terra::app(sum)        [EXACT integer arithmetic, in 28355]
  → freq = 100 * wet_count / valid_count               [in 28355]
  → support mask valid_count >= MIN_VALID_YEARS (25)   [in 28355]
  → freq_8058 = project(freq_supported, 8058, BILINEAR)   ← the only smoothing step
      ├→ 06_build_stratified_sampling_frame_f5.R  : terciles OF freq_8058 → regime_band_breaks.csv
      ├→ 09_build_pixel_census_view.R:103         : census_stratum
      └→ 10_build_veg_regime_checkerboard.R:102   : veg_regime_class_8058.tif
```

**The recon report's reconciliation-trap catch is CONFIRMED and is correct.** `veg_regime_class_8058.tif` and `census_stratum` call the *same* `gayini_background_flood_frequency()` with the same `MIN_VALID_YEARS` and read the *same* `regime_band_breaks.csv`. `diff = 0` is shared construction, not independent measurement. Good catch.

**It goes one step further than the report said:** the **tercile breaks themselves** are quantiles of the bilinear-smoothed surface (`gayini_community_regime_bands(freq_8058, ...)`). So the strata definitions — not just the counts — descend from the bilinear step.

**Correction to the report's Q2 answer:** the report says "no census arithmetic happens in 28355 (only the upstream frequency value does)." The *counting* is on 8058, but the **frequency values are computed entirely in 28355** and only then smoothed across. That is the arithmetic the spec asked to have surfaced.

## 4. The bilinear-vs-NN delta: MEASURED. Rebuild is safe.

I ran both estimators end-to-end on the real stack, onto the exact 8058 census grid.

**Footprint — on the 8058 grid:**

| | |
|---|---|
| NN supported px | 9,754,316 |
| BILINEAR supported px | 9,754,316 |
| **Difference** | **+0 (0.000%)** |
| in NN not BL | 0 |
| in BL not NN | 0 |

**The predicted "edge ring" does not exist.** The report's prediction that "the NN census will be marginally larger — an edge ring the bilinear surface dropped" is **wrong**. Footprints are byte-identical. Reason: the NA regions are negligible (see §5), so there is nothing for bilinear to erode.

**Per-community pixel counts: identical (+0)** under both methods — Aeolian 77,545 · Riverine 193,693 · Inland 717,767.

**Frequency values where both defined (n = 9,754,316):** mean delta **+0.0004 pp** (no bias) · median **0.0000** · sd 1.22 pp · 17.0% differ by >1 pp · 1.0% by >5 pp. Variance: NN 17.904 vs BL 17.827 — bilinear shrinks variance as expected, by 0.4%.

**Tercile break shift (NN − BILINEAR), percentage points:**

| Community | t1 (low/mid) | t2 (mid/high) | px |
|---|---|---|---|
| Aeolian Chenopod | −0.071 | +0.000 | +0 |
| Riverine Chenopod | +0.434 | +1.287 | +0 |
| Inland Floodplain | +1.189 | −0.168 | +0 |

**Verdict: adopt NN. The delta is negligible and the NN estimator is better science.**

- Published counts do not move. Footprint identical. Per-community counts identical. Band breaks move ≤1.3 pp, and because terciles are 1/3-by-construction, per-band counts stay ~equal regardless — only pixels within ~1 pp of a break swap band.
- **NN preserves the integer ratio; bilinear manufactures false precision.** NN freq values land on n/35 steps (5.714 = 2/35, 17.143 = 6/35, 20.000 = 7/35, 34.286 = 12/35) because the underlying measurement genuinely *is* "how many of ≤35 years were wet" — granularity ~2.86 pp. Bilinear smears 2/35 into 5.28 or 5.71 depending on neighbours, inventing precision the data does not have.

**Revised instruction (supersedes the design-seat's earlier "do not rebuild canonical" hold):** the hold was a demand for measurement, and the measurement clears it. Proceed with the NN rebuild. Still do it **additively**: keep the existing `veg_regime_class_8058.tif` registered, write the NN products as new registered assets, re-derive terciles from the NN surface, and **ship the delta table above in the change report**. Do not silently overwrite.

## 5. MIN_VALID_YEARS is NON-BINDING — this reframes old Q3a

Measured across all 35 layers of the real stack:

| | |
|---|---|
| `valid_count` range | **22 – 35** (of 35). No pixel anywhere has fewer than 22. |
| Pixels with valid_count > 0 | 9,756,630 |
| Pixels with valid_count ≥ 25 | 9,754,212 |
| **Dropped by the threshold** | **2,418 px = 0.025%** |

**MIN_VALID_YEARS = 25 drops one pixel in 4,000.** Any threshold ≤ 22 is completely inert. This is the same shape as the Task F near-plot headroom finding: **not a feasibility constraint, a design-philosophy choice.** The sensitivity line the spec asks for is one sentence: *"the threshold is non-binding; at 25/35 it removes 0.025% of observed pixels."*

**Invariant confirmed:** wet ⊆ valid holds exactly — the observed masks are identical across all 35 layers; 0 pixels are wet-but-not-valid. So `freq` is genuinely bounded [0, 100] (measured min 0.00 / max 100.00). The code comment at `gayini_stratified_sampling_functions.R:35-36` is accurate.

## 6. Legal-value-set assertion — the report's version is wrong

Measured on the real stack:

| Layer | Actual unique values | Report claimed |
|---|---|---|
| `annual_wet_any_1988_2023` | `{0, 1, 255}` | `{0,1}` ✓ |
| `annual_valid_any_1988_2023` | **`{1, 255}` — there is NO zero** | `{0,1}` ✗ |

Both are `uint8`, `nodata = 255`, EPSG:28355, 25.0 m, 35 layers.

`valid_any` is presence-only: 1 where observed, 255 (nodata) otherwise. Assert precisely:

- `wet_any` ⊆ `{0, 1}` + NA
- `valid_any` ⊆ `{1}` + NA
- **255 must survive reprojection as NA, never as a value.** If nodata is dropped anywhere in the chain, a 255 entering `app(sum)` adds 255 per year and silently destroys every count. Assert no 255 remains as a legal value post-reproject.

## 7. Corrections (binding)

| # | Object | Sev | Finding | Action |
|---|---|---|---|---|
| **C1** | `census_stratum.farm_area_ha` | **HIGH** | **MISNOMER.** Holds **67,349.332 ha** = the *mapped/valid* area. True farm = **85,910.8 ha**. The field is 78.39% of the farm; the missing **21.61%** matches the known "~21.6% unmapped" exactly. | Add `mapped_area_ha` (= 67,349.332) and `farm_area_total_ha` (= 85,910.8); deprecate the old label in the dictionary. Additive — do not drop the column. **Audit any existing "% of farm" statement sourced from it.** |
| **C2** | `veg_regime_class_8058.tif` | **HIGH** | **NOT REGISTERED** in `raster_asset`. The canonical substrate is absent. `raster_asset` = 100 rows (33 `landsat_inundation` + 67 `mer_inundation`), **all EPSG:28355 — not one 8058 raster is registered.** | Register it, plus the 5 percentile rasters and the reprojected 8058 stack, with crs/extent/res/checksum populated. |
| **C3** | 153 FC rasters | MED | **NOT REGISTERED.** `product LIKE '%fraction%'` / `path LIKE '%lztmre%'` → empty. | Register the FC source product with the §2 legend semantics. |
| **C4** | `MIN_VALID_COVERAGE` vs `MIN_VALID_YEARS` | **HIGH** | **Two knobs; the spec conflated them.** `census_stratum.valid_year_threshold = 25` is the census support mask (a real DB field). `MIN_VALID_COVERAGE = 40` is a within-year percent-coverage threshold at plot extraction. The spec asks for a sensitivity line on the 40 but justifies it with "pixels with widely varying **valid-year** counts" — the other knob. | For the census the live knob is **`MIN_VALID_YEARS = 25/35`** — sensitivity line goes there (see §5: non-binding, 0.025%). Leave `MIN_VALID_COVERAGE = 40` untouched in the extraction path. Neither was ever formally signed off; 40 rode in on the bypassed Q3a gate. |
| **C5** | Data dictionary `metrics` sheet | MED | **STALE** — 39 rows vs `dim_metric` 43 in the live DB. | Regenerate from the live DB at end of Task H. `Gayini_analysis_variable_LUT_20260715.xlsx` supersedes it in the interim. |
| **C6** | "25 m" pixel | LOW | The 8058 census pixel is **24.970268 m** (0.0623514 ha), not 25 m. The 28355 stack **is** genuinely 25.0 m. | Say 24.97 m for the census grid; reserve "25 m" for the 28355 stack. |
| **C7** | FC catalogue metadata | LOW | **DRIFT** — catalogue says nodata unset + `legend_status="needs_check"` ×153; files have `nodata = 255` set. Catalogue says series ends 2025-12; `m202512202602` straddles to 2026-02. | Refresh the catalogue from the files. |
| **C8** | `inundation_annual_occurrence_pct` | MED | **NAME TRAP** — reads like the headline; is a within-year area metric. | Headline stays `100 × wet-valid-years ÷ valid-years`. Status set to *LIVE — SECONDARY (never headline)* in the LUT. |

**Also:** `raster_asset`'s **schema is fully adequate** — it already has `crs`, `crs_epsg`, `resolution_x/y`, `xmin/ymin/xmax/ymax`, `checksum_sha256`, `path_exists`, `qa_status`, `legend_status`, `legend_semantics`. **No schema change needed.** Populate, don't alter.

**Also:** `scripts/_deprecated/` still exists (`01_lag_diagnostics_inundation_gc.R`). CLAUDE.md:44 requires reconciling it into `scripts/archive/`. Additive move, not a delete.

## 8. Task F spec — not missing, chat-side

Both files exist in the Claude.ai Project and were never committed:

- `Tier1_TaskF_spatial_resampling_spec_v2.md` (10,508 bytes)
- `Gayini_subsampling_approach.md` (7,920 bytes)

**Live bug:** `CLAUDE.md:56` references `docs/Gayini_subsampling_approach.md`, **which does not exist in the repo** — a dangling pointer in the file that *is* the cumulative memory system. Committing both to `docs/archive/` with the `SUPERSEDED-BY: Gayini_sequential_task_list_20260715.md` header fixes the reference and completes H1. **Do not delete; do not touch Task F code on `main`.**

## 9. Numbers to propagate

- Census pixels: **1,080,157** (not ~240k — the spec is 4.5× low). Focus strata: 988,831.
- Mapped area: **67,349.332 ha**. Farm: **85,910.8 ha**. Unmapped: **18,561.4 ha = 21.61%**.
- Census pixel: **24.970268 m**, **0.0623514 ha**.
- 8058 grid: 4037 × 2422 · extent X 8,982,659.6538–9,083,464.6257 · Y 4,324,576.4941–4,385,054.4832 · origin (5.264715, 0.749231).
- CRSs in play: **seven** — 8058 (canonical) · 28355 (stack, mgmt zones) · 3577 (FC) · 9473 (`dim_plot` centroids) · 7854 (plot polygons) · 4283 (boundary, veg units) · 4326 (gauges).
- FC temporal: 153 composites, 1987-12 → 2026-02. Clip the percentile pool to the inundation window (WY1988–WY2023) and **report n retained**.
