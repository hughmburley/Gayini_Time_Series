# SCHEM-1 · verification before drawing

**Read-only.** 6 August 2026 · `mode=ro`, `PRAGMA query_only=1` · nothing rendered, nothing
registered. Spec: `docs/reference_update/Gayini_CC_spec_SCHEM1.md`, committed `b168d24`.

Every statement below was taken from the producer source or read directly off the file on disk.
Nothing is quoted from the spec or from a prior document.

---

## 0 · Input inventory — `Output/pack/DATA/`

Built 6 August. 11 files, 649 MB. Copied from registered sources, both sides verified by full
SHA-256. Inventory and checksums in `DATA_manifest.csv`.

| | file | role in this task |
|---|---|---|
| rasters | `total_veg_annual_mean_8058.tif` (581 MB, 35 bands) | the cover chain, and the inset's distribution |
| | `annual_wet_any_1988_2023_8058.tif` (35 bands) | water chain numerator |
| | `annual_valid_any_1988_2023_8058.tif` (35 bands) | water chain denominator |
| | `veg_regime_class_8058.tif` | defines the census extent — **the 21.6% step** |
| tables | `T10_gateC_crosssectional_residuals.csv` (64) | the scatter itself |
| | `T2_in_scope_points.csv` (795,602) | the join — both chains sampled here |
| | `T2_zone_denominator.csv` (64) | the min-support rule |
| | three T13 tables | the part-grain branch (Figures 17–18) |
| geometry | `management_zones_epsg8058.gpkg` (64) | — |

**This makes the spec's input-assembly step unnecessary for everything except one thing.** The
**temporal** floor — the other half of the §3 inset — is not in the folder. It lives in
`Output/census/gayini_pixel_census_8058.parquet` (registered `census_pixel_8058`, 1,080,157 rows).
That is the only input still to be reached for.

---

## 1 · `veg_p05_spatial` — **CONFIRMED, exactly as the spec states**

`scripts/12_zone_stratum/T2_gateB_extract.R:55-70`. The extraction matrix `M` has one column per
water year. Inside the loop over columns `j` — that is, **within one water year** — the values are
grouped by zone and:

```r
q <- function(x, p) as.numeric(stats::quantile(x, p, type = 7, names = FALSE))
veg_p05_spatial = as.numeric(tapply(vv, z, q, 0.05))
```

**5th percentile of cover across the unit's pixels, within one water year, one value per unit per
year.** Type 7. The time axis is intact: 35 values per unit.

The same construction is applied at the paddock × community grain at **line 80**, from the same
extraction and inside the same year loop. **PARTREG's dependency holds.**

The script's own header, line 8, states the rule and names the trap:

> `veg percentiles are WITHIN-zone WITHIN-year SPATIAL percentiles (veg_p05_spatial), never the
> census temporal veg_p05.`

The database agrees: `fact_zone_veg_annual` holds **4,356 rows over 64 zones × 35 years × 2
variants** — a value per unit per year, not one per unit.

---

## 2 · Resampling — **CONFIRMED, with one addition the diagram should absorb**

| chain | call | file · line |
|---|---|---|
| cover, 3577 → 8058 | `terra::project(ann_mean_3577, class_r, method = "bilinear")` | `05_ground_cover/04_build_annual_total_veg_stack_8058.R:184` |
| water, 28355 → 8058 | `terra::project(wet_28355, class_r, method = "near")` | `03_inundation_products/11_reproject_annual_stack_8058_nn.R:111-112` |

Both producers state the reason in comments, in the spec's own terms — `04:14` *"bilinear
(continuous cover %, NOT the binary mask rule)"*, and `02_build_total_veg_percentile_rasters.R:39`
*"H3.0's method='near' applies to BINARY masks only."*

**The addition.** The water chain resamples **twice with nearest, not once.** Before the 28355 → 8058
step, `03_inundation_products/internal/05_build_unified_annual_stack_impl.R:96,118-119` projects the
native observations with `method="near"` and then resamples them onto a **pinned 25 m reference
grid**, also `near`, recording `resample_method = "nearest"` in its metadata. The cover chain really
is a single resample from native; the water chain is two.

*Consequence for the diagram: "resample once" is true of cover and not of water. Either say
"nearest neighbour throughout" on the water side, or draw the pinned 25 m grid as its own step.*

---

## 3 · Three resolutions and three CRSs — **CONFIRMED, read off the files**

| | file | EPSG | resolution | bands |
|---|---|---|---|---|
| fractional cover, native | `fc_total_veg_3577_wy1988_2023.tif` | **3577** | **30.0 m** | 140 (seasonal) |
| inundation, native | `annual_wet_any_1988_2023.tif` | **28355** | **25.0 m** | 35 (annual) |
| census grid | `veg_regime_class_8058.tif` | **8058** | **24.970268001081827 m** | 1 |

The near-collision the diagram exists to prevent is real and it is **0.029732 m** — the inundation
source is exactly 25.0, the census grid is 24.970268. The two cover rasters and the two water
rasters on the census grid all carry the identical 8058 resolution to the last decimal.

**One detail worth putting on the face:** cover is **seasonal** at source (140 bands = 4 × 35) and
becomes annual by averaging the usable seasons; water is **already annual** at source (35 bands).
The spec's chain has the seasonal → annual step on the cover side only, which is correct.

---

## 4 · The 21.6% — **cause confirmed, location differs**

The cause is exactly as the spec says. It is **not** where the spec puts it.

`veg_regime_class_8058.tif` covers a 4,037 × 2,422 grid of 9,777,614 cells, of which **1,080,157
carry a class** — 11 classes, matching `census_stratum` to the pixel. At `PIXEL_AREA_HA` that is
**67,349.3 ha of the 85,910.8 ha property = 78.4%**, and `MAPPED_AREA_HA = 67349.332` in
`R/gayini_params.R:14` is that number.

**So the 21.6% is lost the moment a cell needs a vegetation-community label — at the definition of
the census itself, upstream of and independent of any paddock cut.** The paddock × community cut is
a later and *larger* loss, and marking the 21.6% there would put a correct number on the wrong step.

The full ladder, all four rungs verified:

| step | pixels | ha | of property | what is dropped |
|---|---:|---:|---:|---|
| property boundary | — | 85,910.8 | 100% | — |
| **census** — has a community label | 1,080,157 | 67,349.3 | **78.4%** | **no community label — the 21.6%** |
| non-treed, 9 strata | 988,831 | 61,655.0 | 71.8% | treed context 86,375 px · Other/minor 4,951 px |
| **inside a management zone → Figure 25** | **795,602** | **49,606.9** | **57.7%** | 193,229 px of non-treed ground in no paddock |

**Figure 25 rests on 57.7% of the property, not 78.4%.** If the diagram prints 78.4% beside this
chain it overstates the footprint by 20.7 points. Both numbers are true of different steps.

---

## 5 · The finding the spec did not anticipate — **Figure 25 is paddock grain, not part grain**

§1's chain routes everything through *"cut by PADDOCK × COMMUNITY · 118 parts · 115 with sufficient
record"* and ends *"ONE POINT PER PART on the Figure 25 scatter."*

**Figure 25 is one point per paddock.** The file is `F5_cover_vs_water_64_paddocks.png`; the
producer reads `v_zone_floor_flood_residual`; `fact_zone_floor_flood_residual` has **64 rows**;
`T10_gateC_crosssectional_residuals.csv` has 64.

The two grains are **parallel outputs of one extraction**, not sequential steps:

```
              T2_gateB_extract.R, one pass over 795,602 points
                              |
        +---------------------+---------------------+
        |                                           |
  grain 1: zone x year                    grain 2: zone x community x year
  fact_zone_veg_annual                    fact_zone_community_veg_annual
  4,356 rows · 64 paddocks                8,142 rows · 118 parts
        |                                           |
  T10 -> residuals -> FIGURE 25            T13 -> classification (115)
                                                -> FIGURES 17, 18
```

The spec's part numbers are themselves correct — **118 distinct zone × community pairs exist and
115 are classified** — they simply sit on the other branch. (64 × 3 = 192; 118 is the count of
pairs that actually occur.)

**This changes the diagram's structure, not its content.** The community cut belongs as a *branch*
off the join, feeding Figures 17–18, with Figure 25's line continuing straight to paddock grain —
or it comes out and the schematic stays on the Figure 25 chain alone. **Design-seat call; nothing
drawn until it is made.**

---

## 6 · The naming question — reported, not resolved

**The annual quantity has a code name and no registered one.**

- In code it is **`flood_frac_pct`** — a column of `fact_zone_veg_annual`, computed at
  `T2_gateB_extract.R:112` as `100 * wet_pixels / valid_pixels` for one unit in one year.
- It has **no `dim_metric` row.** No `metric_id`, no registered plain-language label. Fifteen
  inundation metrics are registered and none of them is this one.
- Its **35-year mean** does have registered wording. `dim_headline_number` calls it **"mean annual
  flood frequency"** (`bala29ca_mean_flood_freq`, `ref_paddock_flood_rank_*`, and
  `floor_flood_intercept_64pdk`'s grain line *"paddock floor on mean annual flood frequency"*). The
  column name for it is `mean_flood`.

**So the vocabulary names the destination and not the ingredient** — which is exactly the step this
schematic draws.

**Two collisions to avoid when the name is chosen.** Both are live and both are registered:

| | what it is | why it is not this |
|---|---|---|
| `inundation_annual_occurrence_pct` — *"Annual inundation occurrence"* | **plot** support, any-pixel rule, 66 plots | different support and a different rule; CLAUDE.md already forbids presenting it as the headline |
| `census_flood_frequency_pct` — *"Census between-year flood frequency (pixel support)"* | wet-**years** ÷ valid-years, one value per pixel over the record | a per-pixel long-run property with **no time axis** — the water-side twin of the temporal/spatial floor confusion |

Naming the annual quantity "flood frequency" would collide with the third row. **The honest short
form is what the code computes: the share of the unit's pixels seen wet that year.** A candidate
that keeps the distinction visible on the diagram — *"how much was under water, that year"* over
`flood_frac_pct`, mirroring *"the poorest patches, that year"* over `veg_p05_spatial` — but the
choice is the design seat's, and it should be made once and then registered, because the quantity
currently has no registered name at all.

---

## Summary

| | claim | verdict |
|:--:|---|---|
| 1 | `veg_p05_spatial` = 5th percentile across pixels within one year, one value per unit per year | **CONFIRMED** — line 66, and line 80 for parts |
| 2 | bilinear for cover, nearest for the wet mask | **CONFIRMED** — plus water resamples twice, not once |
| 3 | 30 m/3577 · 25.0 m/28355 · 24.970268 m/8058 | **CONFIRMED** — read off the files |
| 4 | the 21.6% is lost for want of a community label | **cause CONFIRMED, location DIFFERS** — it happens at census definition, not at the paddock × community cut. Figure 25's own footprint is 57.7% |
| 5 | *(not in the spec)* Figure 25 is one point per part | **Figure 25 is one point per paddock.** The part grain is a parallel branch feeding Figures 17–18 |
| 6 | the annual x-axis quantity's name | `flood_frac_pct` in code, **no registered name**; only its 35-year mean is named, as *"mean annual flood frequency"* |

**Nothing drawn.** Items 4 and 5 change what the diagram says and how it is shaped.
