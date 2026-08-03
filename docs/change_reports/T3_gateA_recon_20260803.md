# T3 Gate A — recon (read-only) · change report

**Task:** T3 — Persistent vegetation surfaces and the always-green threshold
**Spec:** `docs/T3_always_green_threshold.md` v3 · 27 July 2026
**Gate:** A — Recon · **STOP**
**Date:** 3 August 2026 · `run_id = T3_gateA`
**Scope of writes:** two figures + their two `figure_asset` rows. **No analysis object created, no table or view modified, no builder run.** `v_always_green_sweep` remains absent; T3 is still unbuilt.

---

## 1. What was verified, and against what

All six Gate A items pass. Geometry was read from **file headers via `terra`**, never from the registry; counts were read from the **census parquet**, never from a prior session's summary or from prose.

| # | Item | Verdict | Evidence |
|---|---|---|---|
| 1 | Five percentile rasters resolve from `raster_asset` | **PASS** | `product = 'total_veg_percentile_8058'` → exactly 5 rows, all `path_exists = 1`, all present on disk |
| 2 | Geometry matches `veg_regime_class_8058.tif` | **PASS** | `compareGeom(crs+ext+rowcol+res)` = TRUE ×5; extent and res vectors **bit-identical** (`identical()` = TRUE) |
| 3 | `legend_semantics` reported verbatim | **PASS** | §3 below; 30 m caveat is registered and travels with every T3 area figure |
| 4 | Pooled over 140 seasonal composites, not 153 | **PASS** | Confirmed from the pool CSV and the builder's hard assert — not from the legend prose |
| 5 | 155 nulls / 153 treed / 2 non-treed | **PASS, with a predicate correction** | §5 below |
| 6 | Constants from `gayini_params.PIXEL_AREA_HA` | **PASS** | `validate()` returns PASS on all four DB checks |

**Assets (all `crs_epsg = 8058`, `legend_status = 'confirmed'`, `run_id = tier2H_h2`, `qa_status = REVIEW`):**
`raster_vegpct_p05` · `p10` · `p20` · `p30` · `p50` → `Output/rasters/veg_percentiles_8058/total_veg_p{05,10,20,30,50}_8058.tif`

**Grid:** EPSG:8058 (GDA2020 / NSW Lambert), 2422 × 4037 cells, res 24.970268001081827 m, extent x [8982659.653817, 9083464.625737] y [4324576.494071, 4385054.483169], origin (5.264715, 0.749231). All five are `FLT4S`, `NAflag = NaN`.

## 2. Registry staleness — spec F7 confirmed, and the row counts have moved again

`raster_asset` is **186 rows**, with `xmin` / `crs_epsg` / `path_exists` populated on **186 of 186**. The 2026-07-01 QA row asserting "98 of 98 raster assets lack CRS/extent" remains stale and remains wrong. **No backfill needed.**

Live DB shape vs the two documents that describe it:

| | live (3 Aug) | `CLAUDE.md` | T3 spec v3 |
|---|---|---|---|
| tables / views | **92 / 34** | 86 / 30 | — |
| `raster_asset` | **186** | 166 | 126 |
| `figure_asset` | **287** (289 after this gate) | 278 | — |
| `dim_headline_number` | **88** | 59 | — |

The DB is the authority. Both documents are renderings and both have drifted; neither was used to establish a fact here.

## 3. Legend, verbatim (`raster_vegpct_p05`)

> `5th percentile. Across-series percentile of TOTAL VEG (green/PV band2 + non-green/NPV band3, plain percent, nodata 255 masked to NA BEFORE summing). Pooled over 140 seasonal FC composites = WY1988-1989..WY2022-2023 (4 seasons/WY, by season midpoint). Computed at native 30 m in EPSG:3577, then reprojected once to the 8058 census grid with method='bilinear' (continuous surface). CAVEAT: natively 30 m, reported on the 24.97 m census grid - do not over-interpret fine spatial detail. Low percentiles measure the FLOOR (resilience), not average condition.`

p10/p20/p30/p50 are identical apart from the leading ordinal.

## 4. Pooling depth — 140, confirmed independently of the legend

- `Output/diagnostics/tier2H_h2_fc_water_year_pool.csv`: 153 composites found, **140 retained**, 13 dropped (2 before WY1988-1989, 11 after WY2022-2023); **35 water years, 4 seasons in every one**; JJA/SON/DJF/MAM = 35 each.
- `Input/landsat_fractionalcover3/` holds **153** matching `.tif` files.
- `scripts/05_ground_cover/02_build_total_veg_percentile_rasters.R:210-217` hard-`stop()`s unless `n_retained == 140`, 35 water years, 4 seasons/WY. **The 140 is an enforced acceptance number, not a comment.**

The 153 figure is the raw composite count. The spec is right that it must not be read as pooling depth.

## 5. Nulls — the spec's counts are exact; the spec's word "null" is not

**The nulls are float `NaN`, not SQL `NULL`.** A literal `veg_p05 IS NULL` test matches **0 of 1,080,157 rows** — it would pass silently while leaving all 155 NaN pixels in every count, and would drag `MIN`/`MAX`/`AVG` to `NaN`. Consistent with the rasters' `NAflag = NaN`.

**The correct predicate is `(veg_p05 IS NULL OR isnan(veg_p05))`.** Every T3 query from Gate B1 onward uses it.

With that predicate the spec's figures reproduce exactly:

| check | spec | measured |
|---|---|---|
| `veg_p05` non-null | 1,080,002 | **1,080,002** |
| nulls, all-pixel | 155 | **155** |
| in treed Woodland (class 40) | 153 | **153** |
| in Inland Floodplain high (class 33) | 2 | **2** |
| identical pattern across all five columns | yes | **yes — 0 disagreeing rows on all four pairwise comparisons** |
| nulls inside `non_treed` | 2 | **2** |

**The 2 non-treed nulls are not a defect.** `pixel_id` 4668780 and 4668781 are **adjacent in x**, at **94.29%** and **97.14%** between-year flood frequency with `valid_years = 35`. Persistent water is persistent FC nodata, so the pair accumulates too few valid seasons to clear `MIN_SEASONS = 50` and correctly becomes NA rather than being given a fabricated veg floor. That is job (ii) of `MIN_SEASONS` — open-water masking — working as designed.

**Scope counts also reproduce:** `non_treed` = **988,831** px across **9** strata · `all_pixel` = **1,080,157** · `treed_context_flag = 0` alone = **993,782** px across **10** strata (admits `Other / minor units`, 4,951 px). Ranges excluding NaN: `veg_p05` [1.185929, 91.847214] all-pixel and [1.185929, 88.659775] non-treed; **`veg_p50` max = 97.000**, confirming amendment E — the spine's 97.00 is the p50 maximum, not p05.

## 6. Constants

`gayini_params.validate()` → **PASS** on all four DB checks. `PIXEL_AREA_HA` = `PIXEL_SIDE_M ** 2 / 1e4` = **0.06235142839918241**, derived and never typed. `MAPPED_AREA_HA` 67,349.332 · `TRUE_FARM_HA` 85,910.8 · `TOTAL_CENSUS_PX` 1,080,157. Scope filters come from `SCOPE_NON_TREED` / `SCOPE_ALL_PIXEL`. Registered `resolution_x` (24.970268001081827) differs from `PIXEL_SIDE_M` by 1.08e-9, inside the module's own 1e-4 tolerance.

---

## 7. Carry-forward findings

**F1 — Option 3 already exists; it was built under T2 Gate B2.** Gate A2 recommends the duration count "as a T2 by-product". That has happened. `raster_asset` holds **`raster_veg_persistence_duration_8058`** (`Output/rasters/veg_duration_8058/`, `run_id = T2_gateB2`, `path_exists = 1`), a 10-band surface carrying `veg_valid_years`, `inund_valid_years`, `n_above_{50,60,70,80}` and `pct_above_{50,60,70,80}` (years where annual total-veg mean exceeds the threshold), set NA below 10 valid years. Its own legend already reads *"Distinct from T3 veg_p05."*
**Consequence:** Gate A2 is no longer a build-or-defer choice — it is a three-way comparison between three surfaces that all exist. The spec's instruction *"do not implement option 3 in T3"* is satisfied by construction, and T3 must not duplicate it.

**F2 — the `IS NULL` predicate trap** (§5). Any T3 or downstream query filtering `veg_p05 IS NULL` is silently wrong: it matches nothing and silently admits 155 NaN pixels. Applies to every percentile column and to any other NaN-encoded float column in the census parquet.

**F3 — the total-cover Context table reproduces exactly.** Read-only pre-check, **not** Gate B1, using `PIXEL_AREA_HA` and `SCOPE_NON_TREED`:

| p05 ≥ | pixels | area (ha) | spec | mean flood freq | spec |
|---|---|---|---|---|---|
| 50 | 656,536 | 40,935.96 | 40,935.96 ✓ | 29.81 | 29.81 ✓ |
| 65 | 321,499 | 20,045.92 | 20,045.92 ✓ | 38.38 | 38.38 ✓ |
| 75 | 133,123 | 8,300.41 | 8,300.41 ✓ | 47.86 | 47.86 ✓ |
| 80 | 67,028 | 4,179.29 | 4,179.29 ✓ | 49.34 | 49.34 ✓ |

`all_pixel` ≥50 → 744,408 px / 46,414.90 ha; ≥80 → 88,462 px / 5,515.73 ha. Both match. v1's values (41,338 / 20,339 / 8,355 / 4,193) are not reproduced and cannot be hit by accident.

**F4 — two spec-vs-repo disagreements. Reported, not silently resolved.**
- **Figure output path.** The spec sends gate figures to `figures/diagnostics/`. That directory does not exist; the live convention is **`Output/figures/diagnostics/`**, which is where the two Gate A figures were written. The spec should be amended.
- **Checksum convention in the producing script.** `scripts/05_ground_cover/02_build_total_veg_percentile_rasters.R:623-626` registers with `digest::digest(file=, algo="sha256")` — the **whole-file** convention `CLAUDE.md` forbids for asset registration. **No live error:** all five files are ~18 MB, so whole-file and first-50-MB hashes are byte-identical (verified on p05 — both `e0d8ab54…`, matching the registered value). The divergence is **latent** and would bite on any registered file over 50 MB. T3's own registrations use `sha256_first50()` / `gayini_sha256_first50()`.

**F5 — raster statistics are not census statistics.** The 8058 grid is 2422 × 4037 = 9,777,614 cells; the census footprint is 1,080,157 px, **11.0%** of them. Raster-wide `veg_p05` max is **95.99** against the census's 91.85 (all-pixel) and 88.66 (non-treed) — the excess is off-property. **Every T3 area figure comes from the census scope; none from raster statistics.**

---

## 8. Figures written and registered

Both via `gayini_write_and_register_figure()` — `ggsave` → **first-50-MB SHA-256** → `INSERT OR REPLACE` into `figure_asset`, one transaction. `support_level = 'pixel'`, `figure_level = 'diagnostic'`, `run_id = 'T3_gateA'`. Both captions state the support level and the 30 m native-resolution caveat.

| `figure_asset_id` | path | checksum (first 12) | shows |
|---|---|---|---|
| `figure_t3_a_percentile_alignment` | `Output/figures/diagnostics/T3_A_percentile_alignment.png` | `88da12451095` | The six registered extents superimposed, plus the non-NA data extent, the census footprint and the farm boundary inside the full grid |
| `figure_t3_a_null_map` | `Output/figures/diagnostics/T3_A_null_map.png` | `bb4d2548429b` | All 155 nulls by stratum; the 2 non-treed called out with their flood frequencies |

Gate A passes if all six extents coincide, and if 153 nulls sit in the treed stratum with 2 isolated. Both hold — and the alignment case is **stronger than "coincide"**: the extents are bit-identical, which is why the alignment figure draws six rectangles and shows one. That is stated on the figure and in its caption.

*Render note: the alignment figure was rendered twice. The first attempt pre-scaled the extent rectangles to km while `geom_sf` drew the boundary in metres, putting the two layers on incompatible axes and collapsing the plot. Fixed by keeping every layer in EPSG:8058 metres and converting to km in the axis labels only. Registered checksum is the corrected render.*

## 9. What is open

- **Gate A1** (read the Task M green-share result and align) and **Gate A2** (pin the persistence metric; settle 3 vs 4 reference paddocks) are both **STOP** gates and both still open. Gate A1's input, `Output/tables/taskM_green_at_floor_area.csv`, is present (4,210 bytes, 24 Jul) and was deliberately not read at this gate.
- **F1 changes what Gate A2 is asking.** The choice is now between three built surfaces, not two built and one hypothetical.
- **F4's two spec amendments** need a decision: figure path, and whether to correct the producing script's checksum call (latent, not urgent — issues-log triage: it does not currently change a number that reaches a deliverable).
