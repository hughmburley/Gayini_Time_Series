# Gayini raster companion — 8 August 2026

For Adrian. **13 raster files**, plus a `figures_for_adrian/` folder placed
here separately — see the note at the end. Everything here is a copy; nothing was moved,
renamed or re-derived, and every source file is still where it was.

`DATA1_manifest.csv` carries every file with its size, first-50-MB SHA-256, band count,
CRS, cell size, extent and year span. Each raster was verified against its source by
checksum, not by the copy command returning success.

**This README was corrected on 9 August.** Two claims in the version you may already hold
were wrong and are withdrawn below: that the flood-frequency values were "exact inside the
footprint", and that `MIN_SEASONS = 50` "excludes permanent water". Both corrections are
marked where they occur.

**Nothing in this folder is registered or new.** These are the existing products.

---

## Start here — the four things that are not obvious in QGIS

### 1 · The bands ARE named inside the TIF. You do not have to count.

The 35-band stacks carry internal band descriptions, `1988-1989` through `2022-2023`.
QGIS shows them in the band dropdown. **An off-by-one is therefore not silent** — check
the name rather than the index.

**35 bands = 35 water years, WY1988 to WY2022.** Band *n* is water year 1987 + *n*.

> **On "1988–2023".** The filenames and the plot-locator map's subtitle both say
> 1988–2023, which reads like 36 years. It is not. A water year spans two calendar
> years, so 35 water years run from 1988-1989 to 2022-2023 — a calendar span of
> 1988 to 2023. **The data is 35 years and matches the analysis convention exactly.**
> The label is ambiguous, not wrong, and it has not been changed.

### 2 · `veg_regime_class_8058.tif` — the footprint everything rests on

11 classes, plus 255 as nodata. **Codes are community × 10 + wetness band.**

| code | community | wetness band | band range (% of years wet) | pixels |
|---:|---|---|---|---:|
| 11 | Aeolian Chenopod Shrublands | low | 0.00 – 0.18 | 26,786 |
| 12 | Aeolian Chenopod Shrublands | mid | 0.18 – 5.71 | 23,720 |
| 13 | Aeolian Chenopod Shrublands | high | 5.71 – 76.02 | 27,038 |
| 21 | Riverine Chenopod Shrublands | low | 0.00 – 5.44 | 65,781 |
| 22 | Riverine Chenopod Shrublands | mid | 5.44 – 16.23 | 64,326 |
| 23 | Riverine Chenopod Shrublands | high | 16.23 – 85.21 | 63,551 |
| 31 | Inland Floodplain Shrublands / Swamps | low | 0.00 – 18.68 | 238,328 |
| 32 | Inland Floodplain Shrublands / Swamps | mid | 18.68 – 34.42 | 239,666 |
| 33 | Inland Floodplain Shrublands / Swamps | high | 34.42 – 97.14 | 239,635 |
| 40 | Floodplain Woodland / Forest | *context* | — | 86,375 |
| 50 | Other / minor units | *context* | — | 4,951 |
| 255 | nodata | — | — | 8,697,457 |

**The wetness bands are per-community terciles, so the boundaries differ between
communities** — Aeolian "high" starts at 5.71% where Inland "high" starts at 34.42%.
They are not comparable across communities as levels.

**The non-treed selection is `treed_context_flag = 0 AND regime_band <> 'context'`**,
which is codes **11–33 only: 988,831 pixels of 1,080,157.**

> **The trap, and it is worth one line.** Filtering on `treed_context_flag = 0` *alone*
> gives **993,782** pixels, not 988,831 — it admits code 50, *Other / minor units*
> (4,951 px, 308.7 ha), which is flagged non-treed but is still a context class. Ten
> strata instead of nine. Both halves of the rule are needed.

`legend_status = confirmed` in the registry for this raster, so its class semantics are
settled and cover arithmetic on it is not gated.

### 3 · `annual_valid_any` looks broken when you open it. It is not.

It holds **only the values 1 and 255** — no zeros anywhere, in any of the 35 bands.
Checked across the whole stack, not sampled.

**It is a safeguard, not a filter.** Within the census footprint every cell is
observable in every water year, so the denominator of the flood-frequency calculation
never actually bites. The layer exists so the calculation *has* a denominator and so any
future gap would be caught, not because it currently removes anything. 255 is nodata
(20,944 cells outside the footprint).

### 4 · The temporal percentiles are on a SEASONAL basis, and the description you were
### sent says otherwise

`veg_percentiles_8058/total_veg_p05..p50_8058.tif` are computed across the **140 seasonal
composites** — four per water year across 35 water years — with `MIN_SEASONS = 50`. The
number of seasons behind each cell runs from **5 to 140**, median **118**.

**They are not computed on the 35-value annual basis.** The written description you were
sent describes an annual basis. **That description is wrong for these files, and a
correction is coming to you separately.** The two are close relatives, not the same
object, and the difference has not yet been quantified — the matched annual-basis build is
outstanding.

### `MIN_SEASONS = 50` — what it actually does here

It makes p05 a true percentile rather than an artefact of a short series. That part
holds.

**The previous version of this README said it "excludes permanent water". That claim is
withdrawn.** Measured inside the census, the threshold removes **2 cells of 988,831** — at
90.2% and 95.4% flood frequency.

**The open-water exclusion does not operate within the non-treed census.** 942 cells are
wet in 90% or more of the 35 water years and **940 of them keep a temporal percentile**.
The mechanism was verified when it was chosen, on a ~347 ha lake — but **that lake lies
wholly outside the vegetation footprint**, so it was never exercised where the analysis
reads. **Any claim that these percentiles resolve the open-water limitation is withdrawn:
they inherit it.**

**This does not put any published value in doubt.** Those 940 cells were measured, and
they are **well covered rather than water-like** — their mean temporal 5th-percentile
cover is **77.96%**, against **77.06%** for the wettest group as a whole. Removing them
moves that group's value by **−0.05 percentage points**, and moves the Aeolian and
Riverine figures not at all, because **every one of the 942 cells is Inland Floodplain**.
**No correction to any published value is warranted.**

---

## Two flood-frequency surfaces, and which one to use

**Use `flood_frequency_counted_8058.tif`.** It is new in this folder and it is the surface
every number in the analysis derives from.

`100 × wet water years ÷ valid water years`, per cell. Because every census cell is
observable in all 35 water years, its values are exactly *k*/35 and only **35 distinct
values** occur inside the vegetation classes — *k* runs 0 to 34. **No cell in the
non-treed country is wet in all 35 years.** That is a fact about this country, not a
rounding tolerance.

### `background_flood_frequency_8058.tif` — the older surface, and its correction

**The previous version of this README said values were "exact inside the footprint".
That claim is withdrawn.**

That surface was **counted on the native EPSG:28355 grid and then interpolated onto the
8058 census grid**. The analysis chain does the opposite: it reprojects the binary wet and
valid bands **nearest neighbour** and counts on 8058. Interpolating a ratio and counting a
ratio are not the same operation, and inside the census they disagree:

| | |
|---|---|
| agree exactly | **24.95%** of cells |
| differ by more than 1 percentage point | **28.89%** |
| standard deviation of the difference | **1.48 pp** |
| largest difference | **30.05 pp** |

Measured on the 988,831 non-treed census cells.

**It changes the map, not just the decimals.** Re-cutting the five flood zones from the
interpolated surface moves **5.62%** of non-treed census cells into a different zone, and
shrinks the never-flooded class from **79,065** cells to **52,934** — a third of it.

Both surfaces are in this folder so the difference can be seen. **The counted one is
correct for anything quantitative.** The older surface also covers the full raster window
rather than the census footprint, and outside the property boundary its denominator does
vary, so values beyond the boundary are indicative only.

Range 0–100, `float32`, nodata `NaN`.

---

## What is in the folder

| file | what |
|---|---|
| `flood_frequency_counted_8058.tif` | **the flood-frequency surface to use**, counted on the 8058 grid, 1 band |
| `background_flood_frequency_8058.tif` | the older interpolated surface, retained for comparison — see above |
| `flood_zone_8058.tif` | flood frequency cut into 5 absolute zones — see below |
| `veg_regime_class_8058.tif` | the 11 community × wetness classes above |
| `inundation_annual_stack_native_28355/` | the source stack **before any reprojection**, EPSG:28355 at 25.0 m |
| `inundation_annual_stack_8058/` | the same stack on the census grid — **what the analysis reads** |
| `veg_percentiles_8058/` | temporal cover percentiles p05, p10, p20, p30, p50 |

**`flood_zone_8058.tif` is a different banding from the one inside
`veg_regime_class`.** It is 5 zones on **absolute** breaks at 0 / 10 / 25 / 50%, the
same everywhere:

| code | label |
|---:|---|
| 0 | never |
| 1 | rarely (< 1:10) |
| 2 | occasionally (1:10 – 1:4) |
| 3 | regularly (1:4 – 1:2) |
| 4 | frequently (> 1:2) |

The community classes use **per-community terciles** instead. The two answer different
questions and should not be overlaid as if they were the same scheme.

### The one file not on the canonical grid, deliberately

`inundation_annual_stack_native_28355/` is **EPSG:28355 at a genuine 25.0 m** — it is the
original, before the single nearest-neighbour reprojection onto the census grid.
Everything else here is **EPSG:8058 (GDA2020 / NSW Lambert) at 24.970268 m**.

**The 25 m nominal is not the census cell.** Using 0.0625 ha/px instead of the true
0.062351428 ha/px inflates every area by 0.238%.

Both versions are included because "the flood frequency data" could reasonably mean
either, and sending both is cheaper than guessing.

---

## Not in the folder, and why

**`total_veg_annual_mean_8058.tif`** — 35 bands, WY1988–WY2022, EPSG:8058, **609.2 MB**,
`sha256_first50 = 6596151995b4…`. **Already shared by Drive link.** Not copied: it would
duplicate itself inside the same tree for no benefit. Listed here so this folder is a
complete account of what has been sent.

Its checksum is the **first 50 MB only** — the project convention — so it identifies the
file but does not verify it end to end. Every file that *is* in this folder is under
50 MB, so for those the same convention covers the whole file.

---

## Two things stated rather than assumed

**Provenance of the inundation source.** The per-observation water-detection method
behind the annual wet/valid stack **is not documented in this repository.** The project
docs reference Thomas & Kingsford (2015) as a candidate NDWI-style classifier and note
Kingsford as a co-author on the inundation-mapping methodology, and a task to write the
actual recipe down is recorded but unclosed. **So it is not established here whether
this stack originates with UNSW.** If it does, you may already hold it. Please say so
rather than assuming either way — the two method notes present
(`Gayini_pre_post_inundation_method_note_20260613.docx`,
`MER_inundation_method_note_20260623.md`) cover derived products, not the source
classifier.

**`background_flood_frequency_8058.tif` is not in `raster_asset`.** Every other raster
in this folder is registered with a checksum; this one is not. It is produced by
`scripts/03_inundation_products/06_build_stratified_sampling_frame_f5.R` and its
checksum is recorded in `DATA1_manifest.csv`, but it has no registry row. Flagged
because it is the file that was asked for.

---

## `figures_for_adrian/` — not part of the raster companion

That folder was placed here separately, after the 12 rasters were copied and verified.
It holds 14 figures plus its own index.

**It has now been verified (Ruling CR) and the result is in `DATA1_manifest.csv`:
14 of 14 figures are byte-identical to their sources in `Output/figures/`. None is
stale, and none is missing a source.** Its index states that the figures were "copied
unchanged... nothing here was rebuilt or re-rendered for this folder", and that claim is
independently confirmed by checksum rather than taken on trust.

The fifteenth file, `FIGFIND1_index.md`, is the index itself — not a figure, so no
`Output/figures/` source is expected for it, and it exists nowhere else in the
repository.

Nothing in that folder was deleted, moved or renamed.

The 12 rasters and their checksums are unaffected.
