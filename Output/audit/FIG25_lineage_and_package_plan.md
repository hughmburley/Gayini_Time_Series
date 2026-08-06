# How Figure 25 was made, and what a package for Figures 17–20 and 25 would contain

**Read-only.** 6 August 2026 · `mode=ro`, `PRAGMA query_only=1` · nothing built, nothing written
outside this file. **This is the plan; the package is not assembled.**

Every step below was traced in the code and re-derived from the database. Nothing is quoted from a
prior document.

---

# Part 1 · Figure 25 in plain language

> **Figure 25.** *One point per paddock, with the registered expectation line and a shaded band of
> one residual standard deviation.*

**Each of the 64 dots is one paddock.** Its position left-to-right is how wet that paddock is; its
position up-and-down is how much cover it holds in its poorest patches. The line is what cover you
would expect at that wetness, and the shaded band is the ordinary amount of scatter around it.

## The horizontal axis — "how often this paddock floods"

**In one sentence: for each year, the share of the paddock that was under water; then averaged over
the 35 years.**

Step by step:

1. Two satellite-derived stacks are read — one saying **where water was seen** in each water year
   (`annual_wet_any_1988_2023_8058.tif`) and one saying **where the satellite could see at all**
   (`annual_valid_any_1988_2023_8058.tif`). Each has 35 annual layers on the 24.97 m analysis grid.
2. Both are sampled at the **795,602 census cell centres** that fall inside a mapped paddock and in
   non-treed country.
3. For each paddock in each year:
   **flood fraction = 100 × (cells seen wet) ÷ (cells the satellite could see).**
   This is *how much of the paddock was wet that year*, not how long it stayed wet.
4. The paddock's axis position is the **plain average of those 35 annual percentages**.

## The vertical axis — "cover in the poorest patches"

**In one sentence: for each year, the cover level that only the worst-covered 5% of the paddock
falls below; then averaged over the 35 years.**

Step by step:

1. One stack is read — **annual total vegetation cover**
   (`total_veg_annual_mean_8058.tif`), 35 layers, same grid. "Total" means green plus dry plant
   material together. Each year's layer is the average of the seasons that were usable that year.
2. It is sampled at the **same 795,602 cell centres**, so the two axes describe the same ground.
3. For each paddock in each year, the cells are ranked by cover and the **5th percentile** is taken —
   the level that 95% of the paddock exceeds. This is the *poorest patches* number.
4. The paddock's axis position is the **plain average of those 35 annual values**.

**The distinction that matters most.** This 5th percentile is taken **across space within one
year** — the worst-covered parts of the paddock this year. It is *not* the census "temporal" 5th
percentile, which is one cell's worst years across the record. The two are different quantities
with similar names, and the producer says so in its own header comment.

## The line and the band

**The line is not fitted in this figure.** It is read from the registry, already fitted, and the
producer refuses to run if the registry has moved:

**predicted cover floor = 52.652934 + 0.547838 × flood frequency**

- a paddock flooding 10 percentage points more often carries about **5.5 points** more cover in its
  poorest patches
- the relationship accounts for about half the variation between paddocks (**r = 0.71**)
- the **shaded band is ±6.6208 percentage points** — one residual standard deviation, the typical
  miss

**A paddock's residual is the plain subtraction:** its actual cover floor minus what the line
predicts for its wetness. Negative means less cover than its water would predict. That single
number is what Figure 20 maps and Figure 28 tabulates.

## Where each piece comes from

| piece | source | file · line |
|---|---|---|
| the two axes, per paddock per year | extraction from the four 8058 stacks | `scripts/12_zone_stratum/T2_gateB_extract.R:36-113` |
| → stored as | `fact_zone_veg_annual` (64 × 35 × 2 variants) | — |
| averaging to one point per paddock | mean over years | `scripts/12_zone_stratum/T10_gateC_residuals.py:44-47` |
| the fit, residuals and ranks | OLS across the 64 points | same file, `ols()` at `:35-42` |
| → written to | `Output/tables/T10_gateC_crosssectional_residuals.csv` | — |
| → promoted to | `fact_zone_floor_flood_residual` / `v_zone_floor_flood_residual` | `scripts/11_database/build_REG1_gateC_promote.py:15-18` |
| the line constants | `dim_headline_number`, read at render, never refitted | `build_adrian_pack_T1_F3_F5.R:260-266` |
| the figure | `F5_cover_vs_water_64_paddocks.png` | `build_adrian_pack_T1_F3_F5.R:255-330` |

## Upstream of the rasters

- **Cover** originates as **fractional cover** — separate green (PV) and dry (NPV) layers at 30 m on
  EPSG:3577 (`fc_pv_3577_wy1988_2023.tif`, `fc_total_veg_3577_wy1988_2023.tif`), an **ingested
  external product**, not computed here. Total veg = green + dry. Resampled **once**, bilinearly, to
  the 24.97 m EPSG:8058 grid.
- **Water** originates as **Landsat-derived surface water observations**, natively 25 m on
  EPSG:28355, resampled **once** by nearest neighbour to the same grid.

Two different native resolutions and two different projections meet on one analysis grid. That is
why the document warns against reading overlays at fine spatial detail.

## Verification — what I re-derived

Rebuilding both axes from `fact_zone_veg_annual` and comparing to the stored table:

| check | result |
|---|---|
| both axes = mean of 35 annual values, all 64 paddocks | **matches stored, all 64** |
| `predicted = 52.652934 + 0.547838 × mean_flood` | **matches stored, all 64** |
| `residual = mean_floor − predicted` | **holds to rounding** — stored columns are 2 dp; largest gap 0.010 (Mara 14), exactly one rounding unit |
| years per paddock | **35**, water years 1988–2022 |

Worked examples, live from the database:

| paddock | flood frequency | cover floor | residual |
|---|---:|---:|---:|
| Bala 26ca | 45.29% | 68.77% | −8.70 |
| Bala 29ca | 8.53% | 40.52% | −16.80 |
| Dinan 10 | 5.09% | 40.38% | −15.06 |

**One observation for the design seat, not a defect.** Figure 20's passage calls Dinan 10 Bala
29ca's *"hydrological twin — a grazed paddock of closely comparable flood frequency"*. They are
**5.09% and 8.53%** — 2nd and 4th driest of 64, so both are firmly in dry country, but one floods
about two-thirds more often than the other. The claim is defensible on rank and loose on value.

---

# Part 2 · Package plan for Figures 17, 18, 19, 20 and 25

## What each figure draws

| Fig | File | Draws | Data source |
|:--:|---|---|---|
| **17** | `T13_D1_part_state_map_and_scatter.png` | 115 paddock-parts classified by level and trend | `T13_gateC_classification.csv`, `fact_zone_community_part_classification` |
| **18** | `T13_D2_part_state_map_sensitivity.png` | the same classification at three cuts | `T13_gateC_classification.csv`, `T13_gateC_robustness.csv` |
| **19** | `M5_dual_grain_floor_and_flood.png` | cover floor and flood frequency at paddock and part grain | `fact_zone_veg_annual`, `fact_zone_community_veg_annual`, `fact_zone_community_flood_annual` |
| **20** | `M5b_paddock_residual_from_expectation.png` | each paddock's residual, mapped | `fact_zone_floor_flood_residual` |
| **25** | `F5_cover_vs_water_64_paddocks.png` | the 64 points, the line, the band | `fact_zone_floor_flood_residual` + the registered line |

**17 and 18 share one producer** (`build_T13_gateD_figures.R`); **19 and 20 share another**
(`build_T11_v2_dual_grain.R`); **25 is a third** (`build_adrian_pack_T1_F3_F5.R`).

## Proposed contents

### A · Source rasters — the three that carry both axes

| file | size | what it is |
|---|---:|---|
| `total_veg_annual_mean_8058.tif` | **581.0 MB** | 35 annual layers, total vegetation cover |
| `annual_wet_any_1988_2023_8058.tif` | 16.4 MB | 35 annual layers, water seen |
| `annual_valid_any_1988_2023_8058.tif` | 2.2 MB | 35 annual layers, satellite could see |
| `veg_regime_class_8058.tif` | 0.4 MB | community × wetness band per cell — the stratification behind 17/18/19 |

### B · Attribute tables — the residuals and the classification

| file | rows | what it is |
|---|---:|---|
| `T10_gateC_crosssectional_residuals.csv` | 64 | **the residual table** — per paddock: mean floor, mean flood, predicted, residual, rank |
| `T13_gateC_classification.csv` | 115 | per part: level, trend, community-scaled scores, state at every cut |
| `T13_gateC_robustness.csv` | — | the wet-year-removal check behind Figure 18's hatching |
| `T13_gateB_part_measures.csv` | — | the continuous measures beneath the classification |
| `T2_zone_denominator.csv` | 64 | per paddock: non-treed cell count and its minimum-support threshold |

### C · Geometry

`management_zones_epsg8058.gpkg` (0.2 MB) — the 64 paddock polygons the maps are drawn on.

### D · A README

Part 1 of this document, plus per-file provenance: registry id, checksum, producing script, and the
support and grain each file carries.

**Total ≈ 666 MB, of which 581 MB is one file.**

## Three decisions before it is built

1. **The 581 MB cover stack dominates the package.** Options: ship it whole; ship a single year as a
   worked example; or ship the extracted per-paddock table instead, which is what the figures
   actually consume and is a few hundred kilobytes. **Which depends on whether the recipient needs
   to re-derive the axes or to check them.**
2. **`T2_in_scope_points.csv` (65.6 MB)** is the 795,602 sampled cell centres — the exact bridge
   between raster and table, and the one file that makes the extraction reproducible. Include or not.
3. **Delivery format and destination** — a zip under `Output/`, as the Adrian pack is, or a folder.
   The pack convention is copy-from-registered-source with checksum verification on both sides, and
   I would follow it unless told otherwise.

**Nothing has been copied or built.** On a ruling I would assemble it the same way as PACK-1: copy
from registered sources, verify each checksum source-to-copy, and record the manifest.
