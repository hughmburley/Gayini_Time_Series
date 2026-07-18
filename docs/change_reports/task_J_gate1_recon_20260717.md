# Task J — Gate 1 recon (report, then STOP)

**Branch:** `tier1j-prepost-placebo` (off `main`). No analysis code written. Recon verified against the rasters and DB themselves, not the catalogue.

**Verdict: all five recon items PASS. No drift from `Gayini_established_data_facts.md` §5. Cleared to proceed to Gate 2 on sign-off.** Two decisions need a nod (MIN_VALID thresholds; how to treat the 5th veg polygon).

---

## 1. Annual stack vs §5 — verified from the rasters

`Output/rasters/inundation_annual_stack/annual_{wet,valid}_any_1988_2023.tif`

| property | §5 says | measured | ✓ |
|---|---|---|---|
| CRS | EPSG:28355 | 28355 (both files) | ✓ |
| res | 25.0 m | 25 × 25 | ✓ |
| layers | 35 | 35 | ✓ |
| dtype | uint8 | INT1U | ✓ |
| grid | — | 2418 × 4035 = 9,756,630 cells | ✓ |
| `wet ⊆ {0,1}+NA` | yes | 0 layers violate | ✓ |
| **`valid ⊆ {1}+NA` (no zero)** | yes | 0 layers violate — values are exactly `{1}`+NA, **never 0** | ✓ |
| `wet ⊆ valid` exactly | yes | **0** wet-but-not-valid pixels across all 35 layers | ✓ |
| valid_count 22–35, 95.768% at 35 | yes | table below matches to the digit | ✓ |

valid_count (per-pixel, whole tile): 35 → 95.768%, 34 → 71,490, 33 → 325,789, 32/31/30 small, 25 → 2,418, 24 → 2,416, 23 → 1, 22 → 1. Min 22, median 35. **Identical to §5.**

Note: the `valid` raster's NAflag reports as `NaN` in terra metadata, but per-layer reads return exactly `{1}`+NA — NA handling is correct on read. The 255→NA discipline still has to be re-asserted around every `app(sum)`/mask/write in Gate 2; this only confirms the inputs are clean.

## 2. Layer → water-year mapping — the load-bearing check

Layer **names** carry the water year directly. Read from the file:

- Layer 1 = `1988-1989` → WY1988-89 (start year **1988**) ✓
- Layer 31 = `2018-2019` → WY2018-19 (start year **2018**, the real cut) ✓
- Layer 35 = `2022-2023` → WY2022-23 (start year **2022**) ✓

Convention confirmed: **water years start 1 July, labelled by start year**. Layer index for start-year `C` = **`C − 1987`**. No off-by-one. (For C=2018: PRE = layers 1–29, TRANSITION = layer 30 = `2017-2018` dropped, POST = layers 31–35.)

## 3. MIN_VALID — proposed, with failure counts

Post window is always 5 years; shortest pre window is 5 (C=1994). Distribution of valid-years **within the 2018 windows**, whole tile (n=9,756,630):

- POST (of 5): 5→9,750,178 · 4→4,034 · 3→2,418. None below 3.
- PRE (of 29): min 17, median 29, 95.768% at 29.

**Proposed thresholds (spec default): POST ≥ 4 of 5, PRE ≥ 80%.** Whole-tile failures at 2018:

- fail POST ≥4: 2,418 px (0.0248%)
- fail PRE ≥80% (≥24/29): 4,836 px (0.0496%)
- fail **either**: 4,836 px (**0.0496%**)

**Within the mapped communities: 0 pixels fail — valid_count = 35 for 100% of the 1,080,230 pixels.** The failing pixels are all outside the mapped communities (tile-edge / persistent-obscuration cells). This matches §5 exactly and confirms MIN_VALID barely bites. Whole-farm stats must be clipped to the boundary polygon (satellite `valid_any` is 1 across essentially the whole rectangular tile, so `valid>0` is **not** a farm mask).

**Recommendation:** adopt POST ≥4/5, PRE ≥80% as-is. It is defensible and near-inert on the analysis footprint.

## 4. Vector inputs — present, readable, CRS as read

| input | rows | CRS read | note |
|---|---|---|---|
| `gayini_boundary_epsg8058.gpkg` | 1 | **8058** | area = **85,910.8 ha** ✓ |
| `management_zones_epsg8058.gpkg` | **64** | 8058 | spec says 64 ✓ (CLAUDE.md's "64 zones") |
| `vegetation_communities_epsg8058.gpkg` | **5** | 8058 | see decision below |
| `Input/shapefiles/cuts.shp` | **1,158** | **4326** | ✓; single col `Date` |

**Veg polygons — decision needed.** The gpkg has **5** `simplified_vegetation_group` values; `dim_plot` carries exactly **4** (Inland Floodplain 22 plots, Riverine 19, Aeolian 16, Woodland/Forest 9). The 5th, **"Other / minor units", is 308.2 ha (0.46%** of the 67,360.9 ha mapped) and appears on no plot. **Recommendation:** report `diff_pp_<community>` for the 4 canonical classes only (per spec "4-class canonical"); carry "Other / minor units" as a separate residual line in J-T1 if wanted, never folded into the 4. The whole-farm mean (boundary-clipped, 85,910.8 ha) still includes it and the ~21.6% unmapped area.

## 5. Gauge series — 410040, with the alignment nailed numerically

`gauge_water_year_flow`, station **410040** (Downstream Maude Weir): 36 rows, `water_year` 1989–2024; `mean_flow_mld` **non-null for 35** (1989–2023); 2024 = NA (`outside_active_record`). The 35 non-null years cover every window the ladder needs.

**Water-year labelling — confirmed by reproducing the reference CSV, not by inspection.** The table stores the **end** year (WY1988-89 → `water_year` 1989). So gauge label = raster **start-year + 1**. Verified for C=2018:

- PRE (start 1988–2016 → gauge 1989–2017): **5783.5** ML/d — reference CSV `flow_pre` = 5783.5 ✓
- POST (start 2018–2022 → gauge 2019–2023): **6817.2** ML/d — reference CSV `flow_post` = 6817.2 ✓

The un-shifted alternative (HYP B) gives 5592.0 / 5236.7 — wrong. **The +1 shift is mandatory when joining flow to windows.** Redbank 410041 not used (settled, L30). `daily_flow_wide` not used (L34/L35). Delivery fraction table `gauge_kingsford_flow_ratios_water_year` present with `ratio_downstream_over_upstream` and `insufficient_overlap_flag` (a Gate 4 input).

---

## Decisions requested before Gate 2

1. **MIN_VALID:** adopt POST ≥ 4/5 and PRE ≥ 80% (fails 0 pixels inside mapped communities; 0.05% tile-wide). OK?
2. **5th veg polygon:** report the 4 canonical communities for `diff_pp_<community>`; keep "Other / minor units" (308 ha) as a separate residual line, not inside the 4. OK?

Everything else in Gate 1 matches the source-of-truth doc with zero drift. **STOPPING here for sign-off before writing any analysis code.**
