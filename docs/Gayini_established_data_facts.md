# Gayini — Established data facts

*Project-scope reference. Last verified **16 July 2026**. Supersedes the 15 Jul and earlier 16 Jul versions.*

## How to use this document

**This is the single home for measured properties of the data.** If a fact is here, it has been measured against the actual files — not inferred from a catalogue, a filename, a convention, or a previous document. **Do not re-derive these at the start of a session. Do not re-litigate §10.**

Every entry carries **provenance**: how it was measured, so it can be re-verified in one command rather than re-argued.

> **The provenance rule has already paid for itself twice.** Two facts in the 15 Jul version were **n=4 generalisations** — measured on four FC scenes and written as project facts. Both were wrong across the full 140-scene pool, and both were caught *because the provenance line said "four files"*. **If a provenance line names a small n, treat the fact as provisional.**

**One fact, one home.** This doc owns *measured properties of the data*. It does not duplicate:

| For | Go to |
|---|---|
| Rules, conventions, workflow | `CLAUDE.md` |
| Table/field schema | `Gayini_Results_data_dictionary.xlsx` |
| What a variable **means** | `Gayini_analysis_variable_LUT_20260715.xlsx` |
| How we got here | `Gayini_project_lineage_and_learnings.md` |
| Census table schema | `Gayini_pixel_census_data_contract.md` |
| Current task | the live task spec |

If a number appears in two places and they disagree, **this doc wins** — then fix the other one.

### Changed in this version

| # | Change |
|---|---|
| 1 | **§4 CORRECTED (n=4 artefact).** `PV+NPV+BS` max is **147**, not 111. |
| 2 | **§4 CORRECTED (n=4 artefact).** nodata per scene: median **2.25%**, **mean 14.34%**, max **96.6%**, 22 scenes >30%. Not "0.56–1.08%". |
| 3 | **§5: §12's last open item CLOSED.** Context strata (Woodland, Other) are **also 35/35**. *Every* census pixel has full support. |
| 4 | **New §6: the seasonal structure.** JJA/SON is the **winter–spring growing season**, not post-flood green-up. p05 delta **+10.85 pp**, ~2× p50's. |
| 5 | **New §9: the floor is ~97% dead** — measured **paired**, not by subtracting marginal percentiles. And **~4,300 ha has a majority-green floor.** |
| 6 | **New §9: the lake** (346.9 ha, 91.4% inundation) and **`MIN_SEASONS = 50`'s dual job**. |
| 7 | **New §11 trap: percentiles do not subtract.** |
| 8 | **§3 CORRECTED:** the irrigation-bank cuts are **EPSG:4326 — the same as gauge_sites**. Still **seven** CRSs, not eight. An earlier claim of "an eighth CRS" was wrong. |
| 9 | New §7a: the Task H products (H2/H4/H6) and their measured properties. |

---

## 1. The property

| | |
|---|---|
| **Farm area** | **85,910.8 ha** |
| **Mapped / classified area** | **67,349.332 ha** (78.39% of farm) |
| **Unmapped** | **18,561.4 ha = 21.61%** |
| **Census pixels** | **1,080,157** — focus strata **988,831**, context **91,326** |

> ⚠️ **`census_stratum.farm_area_ha` is a MISNOMER** (C1). It holds **67,349.332** — the *mapped* area, not the farm. Anything computing "% of farm" from it understates the denominator by 21.6%.

*Provenance: `gayini_boundary.shp` → EPSG:8058, area sum. Mapped = `SELECT SUM(area_ha) FROM census_stratum`. The 21.61% reconciles with the independently known "~21.6% unmapped".*

## 2. The canonical grid

```
CRS    EPSG:8058 (GDA2020 / NSW Lambert)
Dims   4037 cols × 2422 rows
Res    24.970268 m        <- NOT 25 m
Extent X 8,982,659.6538 – 9,083,464.6257
       Y 4,324,576.4941 – 4,385,054.4832
Origin (5.264715, 0.749231)
Pixel  0.0623514 ha
Values 11,12,13,21,22,23,31,32,33 (focus) · 40 (treed context) · 50 (other/minor)
```

Reference raster: `veg_regime_class_8058.tif`. **Assert `terra::compareGeom()` against it before any zonal join.**

The census occupies roughly **rows 503–1836 of 2422** (max `pixel_id` = 7,408,646) — the farm sits mid-grid, and **the grid is not the farm** (§4).

> The 28355 stack **is** genuinely 25.0 m. Reserve "25 m" for that; the census grid is **24.97 m** (C6).

*Provenance: `terra` on `veg_regime_class_8058.tif`; independently reproduced via rasterio. Row span from the census parquet's `pixel_id` range.*

## 3. Coordinate systems — there are SEVEN

| EPSG | Role | Objects |
|---|---|---|
| **8058** | **CANONICAL** — all analysis | census grid, all Task H products, `gayini_vectors_8058.gpkg` |
| 28355 | source | annual inundation stack (25.0 m), management zones |
| 3577 | source | fractional-cover rasters (30 m) |
| 9473 | source | `dim_plot` centroids |
| 7854 | source | `gayini_hectare_plots.shp` |
| 4283 | source | `gayini_boundary.shp`, vegetation units |
| 4326 | source | gauge sites, **irrigation bank cuts** |

**3577 and 9473 are the same projection, different datum** (~1.8 m apart) — which is why plot extraction worked silently. Do not generalise: **3577 → 8058 is Albers → Lambert, a real reprojection.**

**Reproject to new files only. Never mutate originals.**

**`gayini_vectors_8058.gpkg`** now carries all seven vector layers reprojected to the canonical CRS, with a self-documenting `layer_provenance` table. Note: `vegetation_units` carries **2 invalid geometries, invalid before and after** — flagged, deliberately not repaired.

*Provenance: file WKT + `spatial_layer_asset` + the built gpkg's `layer_provenance`.*

## 4. Input — fractional cover (Track B source)

`Input/landsat_fractionalcover3/lztmre_nsw_<period>_dp1a2_subset.tif`

| | |
|---|---|
| Count | **153** seasonal composites, 4/yr, **1987-12 → 2026-02** |
| Naming | `m<YYYYMM><YYYYMM>` = season start/end. Seasons **DJF · MAM · JJA · SON** |
| Grid | 2134 × 1334, **30 m**, single consistent extent — directly stackable |
| CRS | **EPSG:3577** — *proven from file WKT*, not inferred. 9473 ruled out. |
| dtype | `uint8`, **nodata 255** (set in file, identical across all 3 bands) |
| Coverage | **100.0000% of the farm.** 0.0 ha outside. Clearance S +2,956 m · W +3,122 · E +4,540 · N +3,809 |

**Bands:** `band1` = bare ground (BS, excluded) · `band2` = green/PV · `band3` = non-green/NPV. **`total_veg = band2 + band3`.**

**Units are plain percent. There is NO +100 offset.** The offset trap was tested precisely because the JRSRP `dp1a2` convention *does* use it — this product does not.

> ⚠️ **CORRECTED — `PV+NPV+BS` reaches 147, not 111.** The 111 figure was measured on **four** scenes. Across all 140, **15 pixels of 349,648,690 (0.0000043%)** exceed the ~110 envelope — genuine JRSRP unmixing overshoot (`band1 = 0`, no 255 present, the *source* sum is itself 147). **Set to NA, not clamped.** Immaterial: 15 values in 350M, all high, so p05–p30 cannot move.

> ⚠️ **CORRECTED — nodata is NOT ~1% per scene.** That was four clean files. Across all 140, in the farm footprint: **min 0% · median 2.25% · mean 14.34% · max 96.578%**. **70 scenes <2%, 43 >10%, 22 >30%.** DJF 1989-90 is 96.6% obscured — effectively an absent scene. **The distribution is skewed, not ~1%.**

**FC → water-year mapping.** Water years are `1988-1989` … `2022-2023` — **35**. Assigning by **season midpoint** gives 4 seasons per water year → **140 retained of 153**; 13 dropped (2 before: DJF 1987-88, MAM 1988; 11 after).

> **`n_retained = 140` is a checkable acceptance number.** It tests the midpoint rule, the water-year reading and the file inventory in one figure.

> ⚠️ **Parse `end_date` as the LAST day of the end month.** Parsing it as the 1st put every JJA midpoint on **exactly 07-01** — the water-year boundary, **zero margin**, with JJA the only season that straddles it. A `>` vs `>=` would have flipped all 35. Fixed: midpoints DJF 15 Jan · MAM 15 Apr · JJA 16 Jul · SON 16 Oct; **minimum distance to any boundary is now 15 days**.

> ⚠️ **Do not test FC coverage against the census *grid extent*.** The grid is 100.8 × 60.5 km; the farm is 56.4 × 33.3 km. **Test against the boundary vector.**

*Provenance: 140-scene measurement (`tier2H_h2_nodata_by_scene.csv`, `tier2H_h2_fc_water_year_pool.csv`), superseding the earlier 4-file sample.*

## 5. Input — the annual inundation stack (Track A source)

`Output/rasters/inundation_annual_stack/annual_{wet,valid}_any_1988_2023.tif`

| | |
|---|---|
| CRS / res | **EPSG:28355**, **25.0 m**, 35 layers, `uint8`, nodata **255** |
| `annual_wet_any` | **`{0, 1, 255}`** |
| `annual_valid_any` | **`{1, 255}` — THERE IS NO ZERO** (presence-only) |

- **`wet ⊆ valid` holds exactly** — masks identical across all 35 layers. `freq` is genuinely bounded [0, 100].
- **Stack-wide**, `valid_count` runs 22–35: 35 yrs = 95.768%, 33 = 3.339%, 34 = 0.733%.
- **Within the census — focus AND context — `valid_count` = 35 for 100% of pixels.** Every sub-35 pixel lies outside the mapped communities. *(This closes the last item in the old §12.)*

**Assertions:** `wet ⊆ {0,1}+NA`, **`valid ⊆ {1}+NA`**, and **255 must survive reprojection as NA, never as a value**. A `{0,1}` assertion on `valid` passes vacuously. One 255 into `app(sum)` adds 255 per year and silently destroys every count.

*Provenance: `np.unique` across all 35 layers of both files; `n_valid_px` constant at 988,831 in `tier2H_h33_per_year_cut.csv`; context strata confirmed at H4.*

## 6. Two structures that drive everything

### 6a. The n/35 structure — EXACT for the census

Because **100%** of census pixels have 35 valid years, **`flood_freq_pct` takes exactly `k/35`, k ∈ [0,35] — 36 discrete values**, granularity **2.857 pp**. Not "overwhelmingly". Exactly.

- NN frequency lands on visible steps (5.714 = 2/35, 17.143 = 6/35, 34.286 = 12/35).
- **Quantile bands are unstable.** The Inland ⅓ break sits on a tie plateau with a **0.07 pp margin**; two computations differing by **138 px (0.019%)** gave breaks of 6/35 vs 7/35 and low-band sizes of **205,364 vs 238,732 — a 14% swing**.
- **Fixed constants are stable.** Absolute breaks at **10 / 25 / 50%** have **zero pixels on them by construction** — 3.5/35, 8.75/35, 17.5/35 are not integers. **A proof, not an observation.** Confirmed at H6: 0 collisions.

### 6b. The seasonal structure — JJA/SON is the GROWING season

Measured, farm pixels supported in both sub-pools (n = 959,674), Δ = (JJA+SON) − (DJF+MAM):

| | mean Δ | median | sd | q05 | q95 |
|---|---:|---:|---:|---:|---:|
| **p05** | **+10.85** | +10.2 | 7.78 | −0.5 | +24.5 |
| **p50** | **+5.62** | +5.0 | 3.75 | 0.0 | +13.0 |

**JJA/SON is winter–spring — the growing season in semi-arid SE Australia.** DJF/MAM is the summer dry-down. **This is not post-flood green-up:** the delta holds across ~the whole farm, and flooding touches only a fraction of pixels in any year. A farm-wide 11 pp signal **cannot** be flood-driven.

**p05 moves ~2× p50.** The whole seasonal distribution shifts, not just its upper tail — the **floor is the more seasonally sensitive statistic**, because summer dry-down sets it while the median is buffered by persistent dry matter.

**Consequences:**
- The under-observed seasons (JJA/SON lose ~21% vs DJF/MAM's ~7.7%) are the **high-cover** ones → **the pool is biased downward**.
- Pool composition ≈ **46.1% JJA+SON : 53.9% DJF+MAM** against 50:50 balanced.
- **Realised bias, measured: +0.467 pp on p05** (p50: +0.196). *Lower bound* — the balanced subsample (n = 23,070 = 2.4%) selects the least-cloudy pixels, which are the least biased.
- **Because summer is the low season, the across-series p05 ≈ the summer floor** — the true worst case. **That is the resilience rationale, not a defect.** Seasonal sensitivity is what makes it a floor rather than an average.

*Provenance: `tier2H_h2_seasonal_bias_test.csv`, `tier2H_h2_balanced_subsample.csv`.*

## 7. Derived — the census strata

`census_stratum` (11 rows) — **this table already exists. Do not rebuild it.**

| | low | mid | high | **total** |
|---|---:|---:|---:|---:|
| **Aeolian Chenopod** | 26,786 | 23,720 | 27,038 | **77,544** |
| **Riverine Chenopod** | 65,781 | 64,326 | 63,551 | **193,658** |
| **Inland Floodplain** | 238,328 | 239,666 | 239,635 | **717,629** |
| Floodplain Woodland *(context)* | | | | 86,375 |
| Other / minor *(context)* | | | | 4,951 |
| | | | | **1,080,157** |

**Band edges — within-community terciles, NOT comparable across communities:**

| | low/mid | mid/high | high max |
|---|---:|---:|---:|
| Aeolian | 0.18 | 5.71 | 76.02 |
| Riverine | 5.44 | 16.23 | 85.21 |
| Inland | 18.68 | 34.42 | 97.14 |

### 7a. Task H products — all EPSG:8058, all `compareGeom`-aligned, all registered

| Product | Notes |
|---|---|
| `annual_inundation_stack_8058` | 35 lyr × 2, NN-reprojected. **Footprint +0 vs bilinear**, per-community counts +0, value Δ mean ≈ 0. |
| `total_veg_p{05,10,20,30,50}_8058` | **FC-extent masked, NOT farm-masked** — see §9. |
| `flood_zone_8058` | 5 fixed zones, 0 break collisions. Reconciles to §9's crosstab at **max \|Δ\| = 0.047 pp** across all 20 cells — **two independent implementations** (R/terra and Python/rasterio). |
| `gayini_pixel_census_8058.parquet` | **26.7 MB, 1,080,157 × 16.** diff = 0 vs `census_stratum` for all 11 strata; `valid_years == 35` everywhere; monotone p05≤…≤p50, 0 violations; `pixel_id`→x/y round-trip **dx = dy = 0 m**; **155 nulls** per `veg_p*`. |

**The 155 nulls reconcile:** 111 FC pixels dropped at `MIN_SEASONS = 50` × (30/24.970268)² = **160** ≈ 155 (edge effects). **The lake contributes zero** — it has no `veg_regime_class`, so it was never in the census.

*Provenance: `tier2H_h6_qa.json`, `tier2H_h6_flood_zone_crosstab.csv`, the H4 contract assertions, and independent design-seat reproduction.*

## 8. The bilinear chain — how the strata were built

```
annual stack (28355, binary, 25.0 m)
  → wet_count / valid_count via terra::app(sum)      [EXACT integer arithmetic, in 28355]
  → freq = 100 * wet_count / valid_count             [in 28355]
  → support mask valid_count >= MIN_VALID_YEARS (25) [in 28355]
  → freq_8058 = project(freq_supported, 8058, BILINEAR)   ← the ONLY smoothing step
      ├→ 06_build_stratified_sampling_frame_f5.R : terciles OF freq_8058 → regime_band_breaks.csv
      ├→ 09_build_pixel_census_view.R:103        : census_stratum
      └→ 10_build_veg_regime_checkerboard.R:102  : veg_regime_class_8058.tif
```

1. **`veg_regime_class_8058.tif` and `census_stratum` reconcile at `diff = 0` by shared construction.** That check is **vacuous** — never accept it as evidence. *(The census parquet's diff = 0 against `census_stratum` **is** real: independent path.)*
2. The **tercile breaks themselves** are quantiles of the smoothed surface.
3. **Frequency values are computed in 28355; only the counting is on 8058.**

*Provenance: `R/gayini_stratified_sampling_functions.R:96-97`; call sites `09_…R:103`, `10_…R:102`.*

## 9. Measured properties

**Census community flood frequency (pixel support):** Aeolian **6.08** · Riverine **12.91** · Inland **27.99**.

**Per-stratum:**

| | low | mid | high |
|---|---:|---:|---:|
| Aeolian | 0.00 | 2.64 | 15.12 |
| Riverine | 1.95 | 9.64 | 27.56 |
| Inland | 9.22 | 27.34 | 47.31 |

**F6 census verdict: 9 no-trend / 0 non-stationary / 0 directional. RATIFIED.** Riverine low was the only change from the F5 gate (8/1/0) — a **40-point sparsity artefact**: 1,000 random 40-point draws from that census stratum give p<0.05 in **541 (54.1%)** against a nominal 5%; median 29/35 zero-years per draw (the F5 sample's 28 was typical); mean τ across draws **+0.258** vs census **+0.126**.

**Per-year focus-area flood extent: 0.04% (2006) → 84.67% (2022)** — a ~2,000× swing with no drift. Eight of 2001–09 below 8% (Millennium Drought).

**`MIN_VALID_YEARS = 25` is INERT for the census** — every census pixel has 35/35.

**`MIN_SEASONS = 50` (FC pool) does TWO jobs — record both:**
1. p05 needs n > 20 to be a percentile rather than the minimum, and 0.05n ≥ 2 → n ≥ 40 so one bad scene cannot set the floor. At n = 50, p05 is the 2nd–3rd smallest.
2. **It excludes open water.** Persistent water is persistent FC nodata → below threshold → NA. **It stops the product fabricating a veg floor over a lake.** Anyone lowering it to "recover pixels" will invent vegetation on water.

Drops **111 of 959,944** farm FC pixels (0.0116%).

**The lake — definitive.** **346.9 ha (5,564 cells)** at **(8,999,545, 4,349,484)**. **91.4% inundation** (near-permanent water). FC valid seasons **median 13 (range 5–49)** — all below `MIN_SEASONS`. `veg_regime_class` NA in all 5,564 cells. **Correctly NA in the veg products.**

**Aeolian low is 100.0% never-flooded** — max annual freq **0.0000%**. Flat zero series → its F6 "no trend" is **trivially true**. Report as vacuous, not evidence.

**41.59% of Aeolian Chenopod never flooded once in 35 years.**

### The floor is ~97% dead — measured paired

At the season that sets each pixel's total-veg floor (farm, n = 959,833):

| | median | mean | p95 |
|---|---:|---:|---:|
| total veg | **58.0** | 56.8 | 81.0 |
| green (PV) | **1.0** | 7.7 | 42.0 |
| **green fraction** | **3.0%** | 11.8% | **55.6%** |

**The median farm pixel's floor is ~97% dead material.** Still the resilience story — litter holds soil and catches seed — but it is **not** "the country stays green".

> **The distribution is heavily skewed, and the tail is the interesting part: ~4,300 ha (≈5% of the farm) has a floor that is MAJORITY GREEN** — land that stays green in its own worst season. That is a **refugia** map, and probably a better one than the median.

> ⚠️ **These are PAIRED figures.** An earlier "99% dead" came from subtracting marginal percentiles — **invalid** (§11).

**Veg percentile rasters are FC-extent masked, not farm-masked.** 4,089,889 data cells = **2,550 km²**, matching the 64 × 40 km FC extent; the farm is 859 km². **66.3% of valid pixels are not Gayini.** Grid median p05 = 58.206; **farm-masked median = 59.348**. Always report both.

**p05 varies 40.68 pp across the flood gradient** — flood frequency is a strong predictor of the veg floor.

**Seasonal-mixture gate (decides H4): PASS.** Mixture median **0.4571**, sd **0.0231**. Correlated with flooding (**r = −0.213**, ρ = −0.235, r² = 0.045 — wetter pixels attract more winter/spring cloud) but the magnitude is what matters: slope **10.89 pp** per unit f_warm × mixture range **0.0116** = **0.126 pp induced** into a **40.68 pp** signal = **0.31% confound**. The relationship is a **step** (flat to 25%, then a drop), not a gradient — so using the range is conservative.

**The staircase — bands are NOT comparable across communities:**

| | low | mid | high |
|---|---|---|---|
| Aeolian | never | ~1 yr | **~5 yrs** |
| Riverine | ~1 yr | **~3 yrs** | **~10 yrs** |
| Inland | **~3 yrs** | **~10 yrs** | ~17 yrs |

Riverine mid ≈ Inland low. Riverine high ≈ Inland mid. **Aeolian's wettest band is wetter than Inland's driest.** "Darker = wetter" is true *within* a community and **false across the map**. Put frequencies in legends, not band names.

**Absolute flood zones (fixed breaks, % within community):**

| Community | never | rarely <1:10 | occasionally 1:10–1:4 | regularly 1:4–1:2 | frequently >1:2 |
|---|---:|---:|---:|---:|---:|
| Aeolian | **41.59** | 36.67 | 17.41 | 3.59 | 0.74 |
| Riverine | 14.00 | 38.57 | 28.69 | 18.09 | 0.65 |
| Inland | 2.75 | 15.16 | 25.39 | **46.61** | 10.09 |
| Woodland *(context)* | 0.63 | 17.12 | 16.80 | 44.39 | **21.06** |
| **Other / minor** *(context)* | 0.87 | 7.55 | **40.44** | **50.76** | 0.38 |

Farm-wide (mapped): 7.4 / 21.0 / 24.8 / 38.2 / 8.6.

> **Floodplain Woodland is the wettest unit on the property** (21.1% frequently) — and **"Other / minor units" is 50.8% regularly + 40.4% occasionally**, among the wettest ground there is. Both sit as **unbanded context**, invisible in the 9-cell matrix.

## 10. SETTLED — do not re-open

| Question | Answer | Settled |
|---|---|---|
| Do farm-wide FC rasters exist? | **Yes.** 153, local, farm-wide. Raster math, not data acquisition. | Gate 1 |
| Does FC cover the southern edge? | **Yes — 100.0000%**, +2,956 m clearance. | Gate 1 |
| Is FC EPSG:3577 or 9473? | **3577**, proven from WKT. | Gate 1 |
| Does FC use the +100 offset? | **No.** Plain percent, nodata 255. | Gate 1 |
| Is `raster_asset`'s schema adequate? | **Yes.** Populate, don't alter. | Gate 1 |
| Census store format? | **Parquet**, external, registered — like rasters. | Spec §4.6 |
| Will NN change the census counts? | **No.** +0 footprint, +0 per-community. | H3.0 |
| Sub-sampling (Task F)? | **Cancelled, not gated.** Code frozen on `main`, uncalled. Evidence retiring it: **a 40-point design returns a false positive 54.1% of the time**. | Adrian 15 Jul |
| Band definitions? | **Option 2** — F5 `regime_band_breaks.csv` edges; all frequency arithmetic on NN. Reason: **stability**. | H3.0 |
| F6 census verdict? | **9 / 0 / 0. Ratified.** | H3.2 |
| Is 9/22/50 wrong? | **No — correct at plot support.** Do not "fix" it. | C10 |
| Is the 9/22/50 ↔ 6/13/28 gap placement bias? | **No — it is support.** | 16 Jul |
| `n_retained` for the FC pool? | **140 of 153.** 35 WY × 4 seasons; 2 before, 11 after. | H2 |
| Does the seasonal imbalance threaten H4? | **No — 0.31% confound.** Caveat stated, proceed. | H2 gate |
| Do context strata have full support? | **Yes — 35/35, all 91,326.** | H4 |
| What is the pale blob? | **A lake.** 346.9 ha, 91.4% inundation. Correctly NA. | H2 |

## 11. Known traps

### Percentiles do not subtract

`p05(total)` and `p05(PV)` are **marginal percentiles computed on different orderings** — the season setting the total floor is not necessarily the season setting the PV floor. **You cannot subtract them to get composition at the floor.** Doing so gave "99% dead"; the paired measurement gives **97%**, and the ratio is not constant (it reaches ~8% green on the lake rim, 55.6% at farm p95). **Measure paired: the value of the other band in the season that sets the target statistic.**

### The uint8 nodata trap

```
255 + 255  in uint8  =  254      <- wraps silently. Not an error.
255 +  50  in uint8  =   49
```

**A naive `band2 + band3` fabricates plausible total-veg values at every nodata pixel** — and 254 survives any check that only tests for negatives. **Mask 255 → NA *before* summing. Never sum raw bands.** Then assert [0, ~110] and **diagnose, don't widen**, if it fires (§4: it fires at 147, and that's real).

### Metric name traps — there are TWO

1. **`inundation_annual_occurrence_pct` is a WITHIN-YEAR area metric** despite its name. The headline is **between-year** = `100 × wet-valid-years ÷ valid-years`. (C8)
2. **Support is not encoded in any metric name.** (C10) — now partly fixed by `dim_metric.support`.

| Metric | Aeolian | Riverine | Inland |
|---|---:|---:|---:|
| within-year occurrence (plot) | 4.0 | 11.6 | 31.2 |
| **between-year, PLOT support** | **9.1** | **22.3** | **49.6** |
| **between-year, PIXEL support (census)** | **6.08** | **12.91** | **27.99** |

**Both between-year numbers are correct.** `annual_wet_any` ⟺ `occurrence_pct > 0` exactly — a plot is wet if **any** of its ~16 pixels is, so P(any of 16) ≫ P(one pixel).

**The gap is support, not placement — tested.** Real 1-ha polygons recomputed from the census give 7.86 / 18.20 / 42.34 against random 1-ha windows at 10.75 / 18.01 / 35.80 (identical method). Against the null of *n* random windows the plots sit at the **17.0th / 54.7th / 93.1st** percentile — **all within chance**.

> **Residual caveat:** n = 16–22 plots cannot resolve a modest bias. "No demonstrable bias" ≠ "no bias".
>
> **Method note:** the design-seat reconstruction runs ~15% below the DB because of pixel inclusion at polygon edges. The comparison above is **like-for-like**, so it cancels. **Never compare across methods** — doing so produced a spurious "99.8th percentile, placement bias" before it was caught.

**Never mix supports in one figure.** Label plot means *"at site scale (1 ha, any-water rule)"* and census means *"per 25 m pixel"*.

### Other traps

- **4-class `simplified_vegetation_group` is canonical.** The 5-class `vegetation_adrian_group` must never be used in analysis.
- **Wet rule:** the per-scene product is `wet ∈ {1,2}`, `3` = masked. The **annual stack is already binary** (§5). Don't conflate.
- **Binary masks reproject with `method="near"` only.** Continuous surfaces (cover %) use bilinear. **Never copy one rule to the other.**
- **The grid is not the farm.** Grid 100.8 × 60.5 km; farm 56.4 × 33.3 km. Veg percentile rasters are FC-extent masked — **66.3% of their valid pixels are not Gayini**. Render and summarise to the **data extent**, and report farm-masked figures separately.
- **Multi-band float GeoTIFFs are not images.** Windows viewers render them blank. That says nothing about the data. A genuinely empty raster compresses to near-nothing.
- **Aeolian low's F6 row is degenerate**: `mk_tau = NA`, `loess_direction = increasing` on a flat-zero series, arbitrary `dropped_flood_years`. Verdict right; row reads misleadingly.
- **`Inland mid mk_p_drop2floods = 0.0456` is NOT a finding.** 9 strata × drop-2 = 9 tests → 0.45 false positives expected; and dropping the two late floods (2016, 2022) mechanically leaves a declining remainder.
- **Pre/post framing is retired** for two reasons: the uncertain date (**now fixed by Adrian's cut dates**) and the estimator destroying the annual signal (**stands**). A naive pre/post at 2018 gives **+11.33 pp** — but **drop 2022 alone and it is −1.58 pp**. The sign flips on one year.

## 12. NOT established — open

- **Which veg percentile becomes canonical (5/10/20/30/50)?** Compute all five, recommend one. **Hugh's decision.** Note: p05's seasonal sensitivity is a *consideration*, not a strike — since summer is the low season, across-series p05 ≈ the summer floor = the true worst case, which is the resilience rationale.
- **Should green-at-floor be a registered product?** It varies 3% → 56% across the farm and may be a stronger resilience metric than total-veg-at-floor. Currently a one-off diagnostic, not a parquet column. **For Adrian.**
- **`MIN_VALID_YEARS = 25` / `MIN_VALID_COVERAGE = 40`** — neither formally signed off. (`MIN_SEASONS = 50` was, 2026-07-16.)
- **Band definitions round 2** — tie-aware or absolute thresholds are the proper long-run fix. Gated on Adrian, post-presentation.
- **C1 blast radius** — does any shipped figure or slide quote a "% of farm" from `census_stratum.farm_area_ha`?

---

## Re-verification

| Fact | Check |
|---|---|
| FC band semantics | read ≥3 files, per-band min/max + `b1+b2+b3` histogram on valid pixels |
| FC nodata distribution | **all 140** — a 4-file sample gives the wrong answer |
| FC coverage | `gayini_boundary.shp` → 3577, intersect FC extent, report ha outside |
| Stack value sets | `unique()` across all 35 layers, both files |
| Census valid-years | `n_valid_px` in `tier2H_h33_per_year_cut.csv` — constant 988,831 |
| Census totals | `SELECT SUM(n_pixels), SUM(area_ha) FROM census_stratum` |
| Farm area | `gayini_boundary.shp` → 8058, sum area |
| Grid | `terra::rast('veg_regime_class_8058.tif')` |
| Flood zones | reclassify NN freq at 10/25/50, cross-tab by community |

**If a check disagrees with this document, the document is wrong — fix it here first, then downstream.**
