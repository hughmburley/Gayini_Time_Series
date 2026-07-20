# Tier 2 · Task H — all-pixel census (v2, Gate 1 closed)

> ⚠️ **SUPERSEDED — the authoritative Task H spec is [`Tier2_TaskH_all_pixel_census_v4.md`](Tier2_TaskH_all_pixel_census_v4.md).** Retained for lineage only; do not action. *(D1 fix, 20 Jul 2026.)*

*Supersedes v1 (`Tier2_TaskH_all_pixel_census.md`). Follows Adrian's 15 Jul direction (`Gayini_Adrian_comments_20260715.xlsx`) and the sequenced plan (`Gayini_sequential_task_list_20260715.md`). Item numbers (#n) refer to Adrian's table.*

**Gate 1 is CLOSED — signed off 15 Jul 2026.** Evidence: `docs/change_reports/tier2H_gate1_verified_20260715.md` (design-seat independent verification, measured against the actual rasters, the boundary vector, the live SQLite and the R source). Where that document conflicts with the Gate 1 recon report, it wins.

**Workflow: branch-and-PR into `main`, held for review. Do not merge. Stop and report after H3.0.**

---

## 0. What changed in v2 — read this first

| # | Change | Why |
|---|---|---|
| 1 | **Gate 1 removed** — all four questions answered, folded in below as facts. | Recon complete + independently verified. |
| 2 | **Q1 coverage CLOSED.** FC covers **100.0000%** of the farm. Southern edge has **+2,956 m** clearance. | Tested against `gayini_boundary.shp`. The v1 concern is dead — do not re-raise. |
| 3 | **Q4 encoding CLOSED.** Plain percent, **no +100 offset**, nodata **255**, EPSG:3577 proven from WKT. | Measured on 4 real files. The offset trap is not present. |
| 4 | **NN rebuild APPROVED, delta measured.** Footprint Δ **+0 px**, per-community counts Δ **+0**, tercile shift **≤1.3 pp**. | v1 asked for reconciliation; the answer is in hand. The "edge ring" does not exist. |
| 5 | **`MIN_VALID_COVERAGE` → `MIN_VALID_YEARS`.** v1 conflated two knobs. The census knob is **`MIN_VALID_YEARS = 25/35`**, and it is **non-binding** (drops 0.025%). | Correction C4. |
| 6 | **Legal-value assertion corrected.** `annual_valid_any` is `{1, 255}` — **there is no zero**. | v1 and the recon report both had this wrong. |
| 7 | **~240k → 1,080,157 pixels.** v1 was 4.5× low. | Measured; reconciles to `census_stratum` exactly. |
| 8 | **Corrections C1–C8 added** (§6), binding. | Found during verification. |
| 9 | **Infra decided: parquet.** | Recon recommendation accepted. |
| 10 | **`raster_asset` schema is already adequate** — populate, do not alter. | Verified: it has crs/extent/res/checksum/legend fields. |

---

## 1. Objective

First cut of the all-pixel (census) approach: replace *sampled* estimates with *every pixel* in each veg × wetness class. Deliver the census flood-frequency result (which removes the "thinly sampled / provisional" caveat by construction), plus a static total-veg percentile raster and the veg-vs-inundation census analysis.

**Additive only.** Nothing is deleted. The sub-sampling code (Task F: `gayini_stratum_allocation` in `R/gayini_sampling_allocation.R`, `gayini_draw_monte_carlo` in `R/gayini_monte_carlo_sampling.R`) stays on `main`, uncalled — archived in *emphasis*, not removed. It may be used again.

## 2. Scope decisions (do not re-litigate)

- **Percentile = across-the-whole-series, ONE value per pixel.** Not per-year. Five rasters: 5th / 10th / 20th / 30th / 50th of total veg (green + dead). A deliberate staged first cut — the annual version is a later re-run if the static result warrants it.
- **Consequence, accepted:** a static raster cannot feed the lag analysis (#3) or any time-resolved veg response. Those stay on the existing per-plot method. Not a gap — a sequencing choice.
- **Canonical CRS = EPSG:8058 (GDA2020 / NSW Lambert).** All census arithmetic, all new rasters, all products.
- **Out of scope:** the gauge × RS mixed-effects / residual model (#12) — research only, parked.

---

## 3. Established facts (Gate 1 verified — build against these, do not re-derive)

### 3.1 Fractional-cover source — CONFIRMED

153 NSW/JRSRP seasonal composites, `Input/landsat_fractionalcover3/lztmre_nsw_<period>_dp1a2_subset.tif`.

| Property | Value |
|---|---|
| Grid | 2134 × 1334 · **30 m** · single consistent extent, directly stackable |
| Extent (3577) | X 1,064,985 – 1,129,005 · Y −3,837,005 – −3,796,985 (64 × 40 km) |
| CRS | **EPSG:3577** (GDA94 Australian Albers) — **proven from file WKT** (`GDA94_Australian_Albers`, `Geocentric_Datum_of_Australia_1994`), not inferred. 9473 ruled out. Files are unlabelled (`crs_epsg = NA` in the catalogue); terra/GDAL resolve it correctly. |
| dtype | `uint8` |
| **nodata** | **255** — set in the file, identical across all 3 bands |
| Temporal | 153 composites, ~4/yr, **1987-12 → 2026-02** |

**Band semantics — CONFIRMED on real pixels:**

- **band1 = bare ground (BS)** — excluded from total veg
- **band2 = green / photosynthetic vegetation (PV)**
- **band3 = non-green / non-photosynthetic vegetation (NPV, "dead")**
- **`total_veg = band2 + band3`**
- **Units are plain percent. There is NO +100 offset.** Observed per-band range 0 – ~103.
- `PV + NPV + BS` sanity check **passes**: min 96 · max 111 · **mean 98.51 · median 99**; ~96.7% of valid pixels sum to 98–102 (expected unmixing residual).
- `band2 + band3` ≤ ~110 → **fits uint8, no overflow**. Exclude 255 before any percentile.

> The v1 "offset trap" warning is **resolved and closed**. Do not subtract 100. Assert the range anyway and fail loudly if pixels fall outside — but the assertion will pass.

### 3.2 Farm and census geometry — CONFIRMED

| Quantity | Value |
|---|---|
| **Farm area** (`gayini_boundary.shp` → 8058) | **85,910.8 ha** |
| **Mapped / valid census area** | **67,349.332 ha** (78.39% of farm) |
| **Unmapped** | **18,561.4 ha = 21.61%** |
| **Census pixels** | **1,080,157** (focus strata: 988,831) |
| **Census pixel** | **24.970268 m** · **0.0623514 ha** — *not 25 m* |
| FC coverage of farm | **100.0000%** — 0.0 ha outside. Clearance: S +2,956 m · W +3,122 m · E +4,540 m · N +3,809 m |

**Canonical 8058 census grid** (`veg_regime_class_8058.tif`):

```
CRS    EPSG:8058
Dims   4037 cols × 2422 rows
Res    24.970268 m
Extent X 8,982,659.6538 – 9,083,464.6257 · Y 4,324,576.4941 – 4,385,054.4832
Origin (5.264715, 0.749231)
Values 11,12,13,21,22,23,31,32,33 (9 focus) · 40 (treed context) · 50 (other/minor)
```

> Do **not** test FC coverage against the census *grid extent* — the grid is 100.8 × 60.5 km while the farm is 56.4 × 33.3 km, so the grid extends well beyond the property and the comparison gives a false alarm. Coverage is already settled against the boundary vector.

### 3.3 The 28355 → 8058 bridge — MECHANISM CONFIRMED

`R/gayini_stratified_sampling_functions.R:96-97`:

```r
freq_8058  <- terra::project(freq_supported, tcrs, method = "bilinear")
valid_8058 <- terra::project(valid_count,    tcrs, method = "near")
```

The existing chain:

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

**Consequences, both confirmed:**

1. **`veg_regime_class_8058.tif` and `census_stratum` reconcile at diff = 0 by shared construction, not independent measurement.** Same function, same threshold, same `regime_band_breaks.csv`. A `diff = 0` assertion against the old product is vacuous — do not use it as evidence the grid is right. Use `compareGeom()` for grid correctness and the delta table (§4.3) for mechanism.
2. **The tercile breaks themselves descend from the bilinear surface** (`gayini_community_regime_bands(freq_8058, …)`). The strata *definitions*, not just the counts, carry the smoothing.
3. The frequency **values** are computed in 28355; only the **counting** is on 8058.

### 3.4 The annual stack — MEASURED

`Output/rasters/inundation_annual_stack/annual_{wet,valid}_any_1988_2023.tif` — EPSG:28355, **25.0 m**, 35 layers, `uint8`, nodata **255**.

| Layer | Actual unique values |
|---|---|
| `annual_wet_any` | `{0, 1, 255}` |
| `annual_valid_any` | **`{1, 255}` — there is NO zero** (presence-only) |

- **`wet ⊆ valid` holds exactly** — observed masks identical across all 35 layers; 0 pixels wet-but-not-valid. So `freq` is genuinely bounded [0, 100] (measured min 0.00 / max 100.00).
- **`valid_count` ranges 22 – 35.** No pixel anywhere has fewer than 22 valid years.

### 3.5 `MIN_VALID_YEARS` is NON-BINDING

| | |
|---|---|
| Pixels with valid_count > 0 | 9,756,630 |
| Pixels with valid_count ≥ 25 | 9,754,212 |
| **Dropped by the threshold** | **2,418 px = 0.025%** |

**One pixel in 4,000.** Any threshold ≤ 22 is completely inert. Same shape as the Task F near-plot headroom finding: **not a feasibility constraint, a design-philosophy choice.**

### 3.6 Seven CRSs are in play, not four

| EPSG | Role | Objects |
|---|---|---|
| **8058** | **CANONICAL** | census grid; all Task H products |
| 28355 | source | annual stack (25.0 m); management zones |
| 3577 | source | FC rasters (30 m) |
| 9473 | source | `dim_plot` centroids |
| 7854 | source | `gayini_hectare_plots.shp` |
| 4283 | source | `gayini_boundary.shp`; vegetation units |
| 4326 | source | gauge sites |

> 3577 and 9473 are the **same projection, different datum** (~1.8 m apart) — which is why plot extraction worked silently. Do not assume it generalises: **3577 → 8058 is Albers → Lambert, a real reprojection.** Reproject to **new files only; never mutate originals.**

---

## 4. Work

### H1 · Quick wins (no dependencies)

- **Dashboard label fix (#21):** "Total vegetation (green cover)" → **"Total veg (green + dead)"**. It includes dead veg. All three dashboards.
- **Archive the Task F spec.** The v1 instruction pointed at `docs/Tier1_TaskF_spatial_resampling_spec_v2.md`, **which does not exist in the repo** — both files were chat-side and never committed. They are being handed over with this spec:
  - `Tier1_TaskF_spatial_resampling_spec_v2.md`
  - `Gayini_subsampling_approach.md`

  Commit **both** to `docs/archive/` with a `SUPERSEDED-BY: Gayini_sequential_task_list_20260715.md` header explaining the all-pixel pivot. This also fixes a **live dangling reference: `CLAUDE.md:56` points at `docs/Gayini_subsampling_approach.md`**, a file that isn't in the repo — in the document that *is* the cumulative memory system. **Do not delete; do not touch Task F code on `main`.**
- **Reconcile `scripts/_deprecated/`** (`01_lag_diagnostics_inundation_gc.R`) into `scripts/archive/` per CLAUDE.md:44. Additive move, not a delete.

### H2 · Total-veg percentile rasters (#6, #7)

Source and encoding are settled — see §3.1. No band investigation needed.

- **Build order — arithmetic natively, reproject once at the end.**
  1. Compute percentiles at **native 30 m in EPSG:3577**, pooling seasonal composites per pixel: `total_veg = band2 + band3`, nodata 255 excluded → **5 output rasters** (5th / 10th / 20th / 30th / 50th).
  2. **Then** reproject only those **5 outputs** to the 8058 census grid.
  - 5 reprojections instead of 153, and the percentile arithmetic runs on **unresampled source data**. Do **not** reproject 153 layers first.
  - Outputs are continuous (cover %), so **bilinear is appropriate on this step** — unlike the binary masks in H3.0, which are nearest-neighbour only. **Keep the two rules distinct; do not copy one to the other.**
- **Temporal window.** FC spans 1987-12 → 2026-02 (153). **Clip the percentile pool to the inundation window (WY1988–WY2023)** so the veg floor and flood frequency describe the same period. **State the window and the n retained.** A full-span variant, if produced, stays clearly labelled and secondary.
- **Resolution caveat — document it.** FC is natively **30 m**; the census grid is **24.970268 m**. The percentile rasters will be *reported* at 24.97 m but carry genuinely 30 m information. Record in the change report and the data dictionary: do not over-interpret fine spatial detail in the veg layer.
- **Grid discipline.** Final products land on **EPSG:8058**, on *exactly* the `veg_regime_class_8058.tif` grid (§3.2): identical CRS, extent, resolution **and origin**. **Assert with `terra::compareGeom()` before any zonal join** — silent misalignment produces plausible-looking wrong numbers, worse than a crash.
- **Register in `raster_asset`** with crs/extent/res/checksum populated (Deliverable-1 product). **The schema is already adequate — populate it, do not alter it.**
- **Rationale to record in the code header (#7):** lower percentiles are the *floor* of the system — "when the veg is really struggling, if there's still something left, that's a sign of a healthy ecosystem". **Resilience, not average condition** — a different question from mean cover.

### H3 · Track A — census inundation (#1, #2, #24)

No new data needed. Zonal statistics, not a build.

#### H3.0 · Bring the stack onto the canonical grid — **STOP AND REPORT AFTER THIS STEP**

Reproject the 35-layer `annual_wet_any` / `annual_valid_any` stack from 28355 onto the 8058 census grid **once**, write it as a new registered product (`raster_asset`, crs/extent populated), and have every downstream step consume that. Do not reproject repeatedly inside analysis code.

- **Resampling rule — non-negotiable: `method = "near"`.** Binary/categorical masks. **Never bilinear or cubic** — interpolation produces fractional "wet" values and silently corrupts every frequency count.
- **Legal-value assertions (corrected — v1 and the recon report both had this wrong):**
  - `annual_wet_any` ⊆ `{0, 1}` + NA
  - `annual_valid_any` ⊆ **`{1}`** + NA — **there is no zero**; a `{0,1}` assertion passes vacuously and would miss a corrupted layer
  - **255 must survive reprojection as NA, never as a value.** If nodata is dropped anywhere in the chain, a 255 entering `app(sum)` adds 255 per year and silently destroys every count. **Assert no 255 remains as a legal value post-reproject.**
- **Rebuild under NN as the new canonical — APPROVED.** Re-derive terciles from the NN surface; write new `regime_band_breaks`, `census_stratum` and `veg_regime_class` products.
  - **Additive:** keep the existing `veg_regime_class_8058.tif` and `census_stratum` registered and intact. Write NN products as **new registered assets**. Do not silently overwrite.
  - Originals in 28355 remain untouched.
- **Report the delta, do not assert diff = 0** against the old bilinear product — that check is vacuous (§3.3). The design seat has already measured the expected delta; **your numbers should land close to these**, and a material divergence is a bug to investigate:

  | Quantity | Expected Δ (NN − bilinear) |
  |---|---|
  | Supported pixels, 8058 grid | **+0** (9,754,316 both) |
  | Per-community px (Aeolian / Riverine / Inland) | **+0** (77,545 / 193,693 / 717,767) |
  | Freq value | mean **+0.0004 pp**, median 0.0000, sd 1.22 pp; 17.0% differ >1 pp, 1.0% >5 pp |
  | Tercile breaks | Aeolian t1 −0.071 / t2 +0.000 · Riverine t1 +0.434 / t2 +1.287 · Inland t1 +1.189 / t2 −0.168 |

  **There is no "edge ring" — the footprints are identical.** The NA regions are too sparse to erode.

  **Record the rationale:** NN preserves the integer ratio — freq lands on n/35 steps (5.714 = 2/35, 17.143 = 6/35, 34.286 = 12/35) because the measurement genuinely *is* "how many of ≤35 years were wet", granularity ~2.86 pp. **Bilinear smears 2/35 into 5.28 and manufactures precision the data does not have.** NN is the better estimator; the delta is negligible either way.

#### H3.1 (#1) · Census veg × wetness matrix (p18)

Annual flood frequency per class using **every pixel**, per year. Headline metric unchanged: **`100 × wet-valid-years ÷ valid-years`**. Wet-rule via the neutral `gayini_inundation_wet_rule.R` (`wet ∈ {1,2}`, `valid ∈ {0,1,2}`, `mask = 3`).

> Note the distinction: the neutral wet-rule describes the **per-scene** `landsat_inundation` product. The **annual stack** Track A consumes is already collapsed to the binary form in §3.4. Both are true; do not conflate the value sets.

#### H3.2 (#2) · F6 re-run on the census

Adrian's framing is **systematic vs stochastic**. Same robust test as the shut gate (Theil–Sen + Mann–Kendall, LOESS shape, drop-two-floods).

**Expectation, state it in the change report:** a census removes *spatial* sampling uncertainty but adds **zero temporal power** — systematic-vs-stochastic is a question about 35 annual observations regardless of pixel count. Expect the verdict to **harden to the existing answer** (**8 no-trend · 1 non-stationary · 0 directional**; episodic, climate-paced) with the "thinly sampled" caveat gone. **That is the win.** If the verdict *changes*, that is a red flag to investigate, not a result to celebrate.

#### H3.3 (#24) · Per-year cut

Analyse each year rather than only whole-record aggregates. Cheap; likely informative given the episodic signal.

#### `MIN_VALID_YEARS` (correction C4)

**The census knob is `MIN_VALID_YEARS = 25/35`**, not `MIN_VALID_COVERAGE = 40`. v1 conflated them. `MIN_VALID_COVERAGE = 40` is a within-year percent-coverage threshold at plot extraction — **leave it untouched in the extraction path**.

The sensitivity line is one sentence, and §3.5 supplies it: *"the threshold is non-binding; at 25/35 it removes 0.025% of observed pixels (2,418 of 9,756,630); valid_count ranges 22–35, so any threshold ≤22 is inert."*

Neither knob was ever formally signed off — 40 rode in on the bypassed Q3a gate. Flag both as live for the next Adrian touch; do not let "default" harden into "decided".

### H4 · Census veg vs inundation (#8)

- Per pixel: **static veg floor** (chosen percentile) vs **flood frequency**, across all valid pixels, grouped by veg × wetness class.
- Report per-class relationship strength. This is the static analogue of F7 — do **not** present it as the lag result.

### H5 · Census display convention (#18) — blocks every census figure

- All-pixel figures must **not** plot thousands of points: use a **kernel-density / hex-bin surface and/or a CI band around the trend**.
- The existing sqrt-x scatter (α ≈ 0.1 + binned mean ± 95% CI) is **already halfway there** — the binned-mean-and-band layer is exactly the convention. **Keep the plot-scale version; add** a census variant that swaps the point layer for hexbin/2-D density at ~1.08M points.
- Adrian has examples from his own work — request them rather than inventing a convention.

### Infrastructure (#11) — DECIDED

**Parquet** for the wide per-pixel census (~1.08M rows × ~10 cols: pixel_id, class, flood_freq, veg percentiles). Columnar, compressed, typed, reads natively in R (`arrow`) and Python. **Kept outside the relational results DB** (matches "never commit the census extraction"), registered as an asset.

Rejected: CSV (size/types); per-pixel-per-year long SQLite (~38M rows/var, and unnecessary — Track A's time-resolved cuts are raster zonal stats needing no giant table).

---

## 5. Numbers to propagate

- Census pixels **1,080,157** (**not ~240k** — v1 was 4.5× low). Focus strata **988,831**.
- Farm **85,910.8 ha** · mapped **67,349.332 ha** · unmapped **18,561.4 ha (21.61%)**.
- Census pixel **24.970268 m**, **0.0623514 ha**. The 28355 stack **is** genuinely 25.0 m.
- FC: 153 composites, 1987-12 → 2026-02; clip to WY1988–WY2023 and report n retained.

## 6. Corrections (binding)

| # | Object | Sev | Finding | Action |
|---|---|---|---|---|
| **C1** | `census_stratum.farm_area_ha` | **HIGH** | **MISNOMER.** Holds **67,349.332 ha** = the *mapped/valid* area, not the farm. True farm = **85,910.8 ha**. The field is 78.39% of the farm; the missing **21.61%** matches the known "~21.6% unmapped" exactly. | Add `mapped_area_ha` (67,349.332) and `farm_area_total_ha` (85,910.8); deprecate the old label in the dictionary. **Additive — do not drop the column.** **Audit any existing "% of farm" statement sourced from it.** |
| **C2** | `veg_regime_class_8058.tif` | **HIGH** | **NOT REGISTERED** in `raster_asset`. `raster_asset` = 100 rows (33 `landsat_inundation` + 67 `mer_inundation`), **all EPSG:28355 — not one 8058 raster is registered.** | Register it, plus the 5 percentile rasters and the reprojected 8058 stack. Schema is adequate; populate it. |
| **C3** | 153 FC rasters | MED | **NOT REGISTERED.** `product LIKE '%fraction%'` / `path LIKE '%lztmre%'` → empty. | Register the FC source product with the §3.1 legend semantics; set `legend_status = confirmed`. |
| **C4** | `MIN_VALID_COVERAGE` vs `MIN_VALID_YEARS` | **HIGH** | **Two knobs, conflated in v1.** See §3.5 and H3. | Census knob is `MIN_VALID_YEARS = 25/35`; sensitivity line there. Leave `MIN_VALID_COVERAGE = 40` in the extraction path. |
| **C5** | Data dictionary `metrics` sheet | MED | **STALE** — 39 rows vs `dim_metric` 43 live. Consistent with the known gap (`census_stratum`, `v_pixel_census_by_veg_regime` absent). | Regenerate from the live DB at end of Task H. `Gayini_analysis_variable_LUT_20260715.xlsx` supersedes it in the interim. |
| **C6** | "25 m" pixel | LOW | Census pixel is **24.970268 m** (0.0623514 ha). `dim_metric` caveat says "~0.0624 ha per 25 m pixel" — area right, "25 m" loose. | Say 24.97 m for the census grid; reserve "25 m" for the 28355 stack. |
| **C7** | FC catalogue metadata | LOW | **DRIFT** — catalogue says nodata unset + `legend_status="needs_check"` ×153; files have nodata **255** set. Catalogue says series ends 2025-12; `m202512202602` straddles to 2026-02. | Refresh the catalogue from the files. |
| **C8** | `inundation_annual_occurrence_pct` | MED | **NAME TRAP** — reads like the headline; is a within-year area metric. | Headline stays `100 × wet-valid-years ÷ valid-years`. LUT status: *LIVE — SECONDARY (never headline)*. |

---

## 7. Acceptance gate

1. ~~Recon reported and signed off (Gate 1).~~ **CLOSED 15 Jul 2026.**
2. **Everything analytical is EPSG:8058.** Veg percentile rasters and the reprojected annual stack align **exactly** to the `veg_regime_class_8058.tif` grid (CRS, extent, res, origin) — asserted via `compareGeom()`, not assumed. Originals unmutated; new products registered in `raster_asset` with crs/extent populated.
2a. Reprojection of the binary stack used **nearest-neighbour only**. Assertions pass: `wet_any ⊆ {0,1}+NA`, **`valid_any ⊆ {1}+NA`**, **no 255 surviving as a value**.
2b. **NN-vs-bilinear delta reported** against the §H3.0 expectation table. Divergence from the expected (+0 footprint, +0 per-community counts, ≤1.3 pp tercile shift) investigated, not absorbed. **`diff = 0` against the old product is NOT accepted as evidence** — it is vacuous by shared construction.
2c. **FC percentiles computed at native 30 m / 3577**, then reprojected once to 8058 — not the reverse. `PV+NPV+BS ≈ 100%` assertion in code (it will pass). Temporal pool clipped to WY1988–WY2023, **n reported**.
3. Headline metric = between-year flood frequency; `annual_occurrence_pct` never presented as headline.
4. 4-class `simplified_vegetation_group` only; no `vegetation_adrian_group` / `period` leakage; no pre/post language.
5. Wet-rule sourced from the neutral file.
6. **`MIN_VALID_YEARS = 25` flagged with the one-line sensitivity note** (§3.5). `MIN_VALID_COVERAGE = 40` untouched.
7. No census figure plots raw points at scale (H5 convention applied).
8. F6 census verdict reported against the expected **8/1/0** — divergence investigated, not celebrated.
9. Task F code untouched on `main`; **both** Task F docs committed to `docs/archive/` with superseded-by headers; `CLAUDE.md:56` dangling reference resolved; `scripts/_deprecated/` reconciled into `scripts/archive/`.
10. Corrections **C1–C8** actioned or explicitly deferred with reason.
11. Post-build guard (`gayini_assert_post_build_objects()`) passes; spine validation clean.
12. Branch-and-PR, **held — do not merge**.

## 8. Handoff

- **Stop and report after H3.0**, before anything is computed on top of the reprojected stack. Paste raw output for `compareGeom()`, the legal-value assertions, and the delta table.
- Review bundle → `Output/review_bundles/tier2H_all_pixel_census/`, zipped.
- Change report → `docs/change_reports/tier2H_all_pixel_census_<date>.md` (local, per convention). Commit code + small tables only — **never** the census extraction itself.
- Keep `docs/change_reports/tier2H_gate1_recon_20260715.md` (Claude Code's recon, provenance) **and** `docs/change_reports/tier2H_gate1_verified_20260715.md` (the authority). Additive.

## 9. Open questions (flag; do not guess)

- **Which percentile becomes canonical (#9)?** Compute all five, report which shows the strongest relationship with inundation, **recommend one** — the decision is Hugh's, and once made it is used consistently everywhere.
- **Adrian's own examples of the density/CI display convention (#18).**
- **C1 blast radius:** does any shipped figure or slide already quote a "% of farm" derived from `census_stratum.farm_area_ha`? Report; do not fix silently.
- **`MIN_VALID_YEARS` / `MIN_VALID_COVERAGE`** — neither formally signed off. For Adrian's next touch, now with §3.5 in hand (the threshold is non-binding, so this is a philosophy choice, not a constraint).

---
*Deliverable 1 (updated database) is the target this task feeds. Site reports (Deliverable 2) are the next task and are largely un-gated — do not start them here.*
