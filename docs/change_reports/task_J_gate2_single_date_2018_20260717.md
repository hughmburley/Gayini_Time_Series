# Task J — Gate 2 (single-date 2018 build) — report, then STOP

**Branch:** `tier1j-prepost-placebo`. Build is descriptive only; **not** an effect estimate. No placebo ladder, no figures — those are Gates 3–4. Every assertion below passed (`stopifnot` on all); exit 0.

**Code (committable):**
- `scripts/03_inundation_products/internal/task_J_prepost_placebo_impl.R` — reusable per-date builder + assertions (Gate 3 calls the same functions).
- `scripts/03_inundation_products/16_task_J_gate2_single_date_2018.R` — the Gate 2 driver.

**Results tables (small; commit via `git add -f`):**
- `Output/tables/task_J_gate2_2018_summary.csv`
- `Output/tables/task_J_gate2_2018_by_community.csv`
- `Output/tables/task_J_gate2_2018_assertions.csv`

**Raster (gitignored — never committed):** `Output/rasters/task_J/diff_pp_2018_28355.tif` (native EPSG:28355, FLT4S).

---

## Window mapping (load-bearing) — printed and asserted

Layer index rule `C − 1987`, verified against layer **names**:

```
PRE   layers 1..29   WY1988-89 .. WY2016-17   (29 years)
TRAN  layer  30      WY2017-18                 DROPPED (name asserted == "2017-2018")
POST  layers 31..35  WY2018-19 .. WY2022-23    (5 years)
```

`taskj_windows()` asserts contiguity (`max(pre)+1 == tran`, `tran+1 == min(post)`, `length(post)==5`) and index bounds, so an off-by-one fails loudly rather than shifting the window.

## Assertions (actual output, not a "passed" claim)

**Inputs (on the window layers used):** all 10 PASS. The non-vacuous one holds — `annual_valid_any` value set is exactly **`{1}`** (asserted `=={1}`, not `⊆{0,1}`); 255 absent from both wet and valid; **0** wet-but-not-valid pixels. Value sets asserted *before* any sum, so the fast `app("sum")` is 255-safe.

**Products:** all 7 PASS. `freq_pre` 0..100, `freq_post` 0..100, `diff` −96.552..100; 0 pixels with `wet_count > valid_count`; 0 pixels with frequency but no valid years.

**On-disk re-read (Gate-1 note A — writes are the hazard, not reads):** the diff raster was re-read from a fresh `terra::rast()` after `rm(build)`. On-disk range −96.552..+100; sentinel `-9999` **absent as a value**; **NA count preserved exactly (4,836 == 4,836)**. The nodata landed as NA, not as a value. The NaN-NAflag hazard did not bite this write.

## Headline numbers (2018, descriptive)

| quantity | value |
|---|---|
| **whole-farm mean `diff_pp`** (boundary-clipped) | **+9.296 pp** |
| contributing pixels | 1,377,989 *(EPSG:28355 grid, internal support)* |
| plot-support comparator (reference CSV, C=2018) | +11.473 pp — Gate 3 does the formal shape match |

Per-community mean `diff_pp` (4 canonical, then Other as a residual line):

| community | diff_pp | n_px (28355) | line |
|---|---|---|---|
| Riverine Chenopod Shrublands | +12.154 | 193,676 | canonical |
| Inland Floodplain Shrublands / Swamps | +10.780 | 717,759 | canonical |
| Aeolian Chenopod Shrublands | +7.524 | 77,518 | canonical |
| Floodplain Woodland / Forest | +5.642 | 86,334 | canonical |
| Other / minor units | +9.589 | 4,943 | residual |

All communities read wetter in 2018–2022 than in 1988–2017 — this is a *description of two windows*, not an effect (see "What must not be claimed"; the drop-2022 reversal and the placebo law come at Gates 3–4). Do not compare the per-community pp values against each other (L19). The **4 canonical** pixel counts sum to **1,075,287**; adding Other (4,943) gives 1,080,230 = the mapped-community total. The farm total (1,377,989) is larger because the boundary includes the ~21.6% unmapped area — and that implied unmapped fraction (21.61%) matches §1's independently measured 21.61% exactly, an independent confirmation the boundary clip is right.

## MIN_VALID (POST ≥ 4/5, PRE ≥ 80%) — provably inert on the farm

- failing pixels, whole tile: **4,836** *(28355 grid)*
- failing pixels, within the boundary clip: **0**

Confirms the Gate-1 prediction exactly: 4,836 = two full tile-spanning columns (2 × raster height 2,418), a tile-edge artefact outside the irregular farm polygon. **MIN_VALID drops nothing inside the analysis footprint and needs no further mention.**

## CRS / area discipline (Gate-1 note B)

All statistics computed **natively on the EPSG:28355 grid**; the binary layers were never reprojected. Every pixel count above is labelled with its CRS and is **internal support only**. **No hectares or "% of farm" are quoted off the 28355 grid** — the 28355 25.0 m grid and the 8058 24.97 m census grid differ by ~+0.23% in area (MGA55 transverse-Mercator scale factor ~3° west of the 147°E central meridian), so 28355 pixel counts must not be converted to area. Area/`% of farm` figures, if ever needed, come from EPSG:8058 or the vectors.

## Not done here (correctly deferred)

Placebo ladder (Gate 3), the `~ log(q_ratio)` law and figures (Gate 4), reproject-to-8058 of the diff surface + `raster_asset` registration (tied to the figures step), and the limitations-register update (Gate 5). The existing `pre_post_comparison` products are 28355 over WY2014–2025 on a 2013→2019→2026 window — not full-record, and not the same thing as this task's output (L18).

**STOP — holding for sign-off before the placebo ladder.**
