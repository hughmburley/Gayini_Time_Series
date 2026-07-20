# Gate 1 — Recon report (Tier 2 · Task H, all-pixel census)

*Claude Code recon, 15 Jul 2026. Reported at Gate 1 before any analysis code. Superseded where it conflicts by `docs/tier2H_gate1_VERIFIED_20260715.md` (design-seat independent verification). Kept as-is for provenance.*

## Q1 — Do farm-wide fractional-cover source rasters exist locally? ✅ YES (the good answer)

Farm-wide FC source rasters are held locally in `Input/landsat_fractionalcover3/`. This is a **raster-processing job, not a data-acquisition problem** — Track B (the veg percentile raster, #6) is unblocked.

| Property | Value |
|---|---|
| Count | **153 rasters**, one consistent grid (all share extent/res — directly stackable) |
| Temporal span | **1987-12 → 2026-02**, seasonal (~4/yr) — covers the full 1988–2023 record and beyond |
| Grid | 1334 × 2134, **30 m**, GDA94 **Australian Albers (EPSG:3577)**, extent 1,064,985–1,129,005 × −3,837,005 to −3,796,985 (~64 × 40 km — contains the whole farm) |
| Bands | 3: **band1 = bare ground · band2 = green/PV · band3 = non-green/NPV** |

The `03_extract_fractional_cover_full_impl.R` script *extracts* these full rasters to plot polygons via `exact_extract` — the plot windows are a downstream product, not the source. The source is farm-wide.

**⚠️ New CRS in the mix (4th one):** FC is **EPSG:3577** (GDA94 Australian Albers) — distinct from 8058 (canonical), 28355 (stack), 9473 (`dim_plot` centroids). The percentile build reprojects 3577 → the 8058 census grid.

## Q4 — Total-veg band semantics ✅

Per `fractional_cover_bands.csv` (all `confirmed = TRUE`): **total veg (green + dead) = band2 (green/PV) + band3 (non-green/NPV)**; band1 (bare) excluded. Units = percent, **nodata = 255**. Across-series percentile must be computed over valid seasons per pixel (skip 255).

## Q2 — How the pipeline bridges 8058 ↔ 28355, and the exact 8058 grid

**Mechanism (this is the crux):** the current pipeline does **not** reproject the binary stack. `gayini_background_flood_frequency()` computes `wet_count`/`valid_count`/`freq` **in 28355**, masks freq to ≥25 valid years, then reprojects the **continuous frequency surface with `method="bilinear"`** to 8058 (and `valid_count` with `near`, used only for reconciliation accounting). The census `n_pixels` are 8058-grid counts, defined by **where the bilinear freq surface is non-NA**.

**Are `census_stratum` counts genuinely 8058-grid counts?** Yes. The *counting* happens entirely on the 8058 grid — no census arithmetic happens in 28355 (only the upstream frequency value does). Standardising on 8058 does **not** shift counts on CRS grounds.

**The canonical 8058 census grid** (`veg_regime_class_8058.tif`, measured with terra):

| | |
|---|---|
| CRS | **EPSG:8058** (GDA2020 / NSW Lambert) |
| Dims | **2422 rows × 4037 cols** |
| Resolution | **24.970268 m × 24.970268 m** (note: *not* 25 m — this is the terra-chosen res from the 28355→8058 reprojection) |
| Extent | xmin **8,982,659.6538** · xmax **9,083,464.6257** · ymin **4,324,576.4941** · ymax **4,385,054.4832** |
| Origin | **(5.264715, 0.749231)** |
| Pixel area | ≈ 0.06235 ha |
| Value set | 11,12,13,21,22,23,31,32,33 (9 focus) · 40 (treed context) · 50 (other/minor) |
| Valid cells | **1,080,157** |

## 🔴 The reconciliation trap (directly affects watch-item #2)

`veg_regime_class_8058.tif` is built from the **same bilinear `freq_8058` surface** as `census_stratum` (`10_build_veg_regime_checkerboard.R:102-122`). They reconcile at **diff = 0 by shared construction, not independent measurement.** So "does the reprojected stack reconcile to `census_stratum` at diff = 0" is really "does NN-on-binary match a bilinear-derived product" — **and it likely will not, for a *correct* implementation:**

- H3.0 mandates NN-resample the binary stack, then compute freq on 8058 — a **different mechanism** from the bilinear-continuous surface that produced today's counts.
- Bilinear sets a cell NA if *any* of its 4 source neighbours is NA, eroding the footprint by ~1 pixel ring at the farm boundary. NN keeps a cell if its single nearest source is valid. **Prediction: the NN census will be marginally *larger* than the current `census_stratum` — an edge ring the bilinear surface dropped. That is correct behaviour, not a grid bug.**
- Per-class *headline frequency values* will also move slightly (NN-per-layer-then-compute vs bilinear-smoothed-continuous), even though counts are near-preserved.

**Recommendation:** rebuild `veg_regime_class` + census under the NN mechanism as the **new canonical**, and **report the shift** (magnitude per class) rather than asserting diff = 0 against the old bilinear product. Grid *alignment* is still asserted hard via `compareGeom()`; the *count reconciliation* becomes "report the delta and explain it," per the CLAUDE.md "surface, don't absorb" rule.

## 🟡 Legal-value-set assertion needs correcting

The neutral `gayini_inundation_wet_rule.R` `{0,1,2}, 3=mask` describes the **per-scene** `landsat_inundation` product. But the annual stack Track A actually reprojects is already collapsed to **binary**: `annual_wet_any ∈ {0,1}`, `annual_valid_any ∈ {0,1}` (measured). So H3.0's assertion should check reprojected layers **⊆ {0,1}** (+NA) — writing it against `{0,1,2,3}` would pass vacuously and miss a corrupted layer.

## Q3 — Census store infra (recommendation, not built)

**The spec's "~240k pixels" is ~4.5× low** — the actual valid census is **1,080,157 pixels** (focus strata alone ≈ 989k). Correct this figure everywhere downstream.

Key insight: most census work needs **no giant table**. Track A (flood freq + F6 + per-year cut) is **raster zonal stats** on the reprojected 35-layer stack — 35 numbers per class, no per-pixel-per-year table. A tabular store is only needed for the pixel-level veg-vs-inundation scatter (H4/H5): ~1.08M rows × ~10 cols (pixel_id, class, flood_freq, veg percentiles) — trivial.

**Recommend Parquet** for that wide per-pixel census: columnar, compressed, typed, reads natively in R (`arrow`) and Python (pandas/pyarrow); kept **outside** the relational results DB (matches "never commit the census extraction"), registered as an asset. Reject CSV (size/types); reject a per-pixel-per-year long SQLite (~38M rows/var, and unnecessary given zonal stats cover the time-resolved cuts).

## Watch-item #3 (F6) — confirmed expectation
A census removes *spatial* sampling uncertainty but adds **zero temporal power** (still 35 annual observations). Verdict should **harden to 8 no-trend / 1 non-stationary / 0 directional** with the "thinly sampled" caveat gone. Any change = investigate as a bug.

## ⚠️ Two discrepancies to resolve before Gate 2 (not guessing)

1. **The Task F spec file to archive does not exist.** The spec/plan name `docs/Tier1_TaskF_spatial_resampling_spec_v2.md` — there is **no `Tier1_TaskF` spec** in `docs/`. Only `docs/tier1f_foundation_and_rebalance_change_report.md` (a change report), and CLAUDE.md's referenced `docs/Gayini_subsampling_approach.md` is **also absent**. The Task F *code* is present and untouched-able (`gayini_stratum_allocation` in `R/gayini_sampling_allocation.R`, `gayini_draw_monte_carlo` in `R/gayini_monte_carlo_sampling.R`). **Which doc is the "Task F spec" to archive?**
2. **`MIN_VALID` vocabulary is two different knobs.** The census support mask is `MIN_VALID_YEARS = 25` (of 35, applied in `gayini_background_flood_frequency`). Q3a's `MIN_VALID_COVERAGE = 40` is a within-year percent-coverage threshold at extraction. They must stay distinct — confirm which one the spec's "MIN_VALID_COVERAGE = 40, sensitivity line" refers to for the census.

## Proposed decisions for sign-off

| # | Decision |
|---|---|
| Q1 | Proceed — build 5 percentile rasters (5/10/20/30/50 of green+dead) from `Input/landsat_fractionalcover3`, 3577 → 8058 census grid. Track B is unblocked. |
| Q2/H3.0 | Reproject the 35-layer binary stack 28355 → 8058 with `method="near"` onto the exact `veg_regime_class_8058` grid; assert `compareGeom()` + layers ⊆ {0,1}; register in `raster_asset`. Rebuild census/class under NN as new canonical; **report the count shift vs the old bilinear product** rather than asserting diff = 0. |
| Q3 | Parquet for the per-pixel wide census (~1.08M rows), outside the results DB; time-resolved cuts via raster zonal stats. |
| Q4 | Total veg = band2 + band3; nodata 255; percentile across valid seasons per pixel. |
