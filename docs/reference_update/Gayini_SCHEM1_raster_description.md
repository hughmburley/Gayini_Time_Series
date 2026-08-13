# The input rasters — verified description for SCHEM-1

**Design seat · 6 August 2026.** Every property below was **read off the file**, not taken from a
document. Where a number differs from something already written down, the file wins and it is
flagged.

Three rasters were inspected directly. The fourth — the 581 MB cover stack — is described from its
producer and CC's verification, and the two properties that matter are marked for confirmation.

---

## 1 · What the reader needs to understand, in four sentences

**Two satellite records, measured independently, brought onto one grid.**

**Cover** says how much plant material is on the ground — green and dry together — as a percentage
of each cell, four times a year, since 1988.

**Water** says whether each cell was seen under water at any point in a water year, as a yes or no,
for each of 35 years.

**They start life at different resolutions in different map projections and are resampled onto one
common grid**, so that a cover value and a water value can describe the same square of ground.

---

## 2 · The common grid — all four rasters, identical

Verified identical across all files inspected, to the last decimal.

| | |
|---|---|
| **Projection** | EPSG:8058 — GDA2020 / NSW Lambert |
| **Cell size** | **24.970268001081827 m** |
| **Grid** | 4,037 columns × 2,422 rows = **9,777,614 cells** |
| **Cell area** | 0.062351428 ha |
| **Extent** | X 8,982,659.7 – 9,083,464.6 · Y 4,324,576.5 – 4,385,054.5 |
| **No-data** | 255 |

**The grid is much larger than the property.** 9.78 million cells cover the extent; the property
occupies about a ninth of them. **The grid is not the farm** — a point the schematic should make
once, because every "% of grid" figure is meaningless.

---

## 3 · Cover — `total_veg_annual_mean_8058.tif`

**Plain terms: how much plant material covers each 25-metre square, once a year, for 35 years.**

| | |
|---|---|
| **What it measures** | total vegetation cover = green (photosynthetic) **plus** dry or dead (non-photosynthetic) material, as a percentage of the cell |
| **Bands** | 35, one per water year 1988–89 to 2022–23 |
| **Each band is** | the mean of that water year's usable seasons |
| **Origin** | JRSRP seasonal fractional cover — an **ingested external product**, not computed here |
| **Native form** | 30 m, EPSG:3577 (Australian Albers), **140 seasonal bands** = 4 × 35 |
| **Resampled** | **once**, **bilinear**, to the 24.97 m EPSG:8058 grid |
| **Values** | plain percent. Census range [1.19, 91.85] |
| **Size** | 581 MB — 99% of the data package |

**Two things to state on the face of the diagram.**

**Bilinear, because cover is continuous.** A cell can legitimately be 62.4% covered, so interpolating
between neighbours is meaningful.

**Values above 100% exist and are not clamped.** They are bilinear-resampling overshoot, flagged
rather than truncated. A reader who samples this raster will meet them.

> **⚠ To confirm from the file when it is available:** the two properties above — 35 bands, and the
> seasonal-to-annual averaging — are from the producer and CC's trace, not read off the raster as the
> other three were.

---

## 4 · Water — two rasters, a numerator and a denominator

**Plain terms: was this square seen under water this year, yes or no — and could the satellite see
it at all.**

### `annual_wet_any_1988_2023_8058.tif` — the numerator

| | |
|---|---|
| **Bands** | **35**, named `1988-1989` … `2022-2023` — the band names are in the file |
| **Type** | `uint8`, values **{0, 1, 255}** — verified across all 35 bands |
| **Meaning** | 1 = water observed at **any point** in that water year · 0 = never observed wet · 255 = no data |
| **Native form** | 25.0 m, EPSG:28355 (MGA Zone 55), Landsat-derived surface-water observations |
| **Resampled** | **nearest neighbour throughout** — see §5 |

### `annual_valid_any_1988_2023_8058.tif` — the denominator

| | |
|---|---|
| **Bands** | 35, same names, same footprint |
| **Type** | `uint8`, values **{1, 255}** — verified across all 35 bands |
| **Meaning** | 1 = the satellite could see this cell that year · 255 = no data |

### **A finding: the denominator never excludes anything**

**The valid stack contains no zeros. In any band. Anywhere.** Its only values are 1 and 255, and its
no-data footprint is byte-identical to the wet stack's.

So within the census, **valid = 100.0% in every one of the 35 years**, and

> flood fraction = 100 × wet ÷ valid

reduces in practice to **wet ÷ cells-that-exist**.

**This is not a defect** — the denominator is the right construction, it is what makes the metric
robust to cloud or scene gaps, and it would bite in a record with worse coverage. **But the diagram
should not imply the denominator is doing work it is not.** Draw it as the guard it is, not as a
correction that fires.

*(Worth a check against the native 28355 stack before publication: if zeros exist there and vanish
on reprojection, that is a property of the resampling, not of the data.)*

---

## 5 · Nearest neighbour — and the water chain resamples twice

**Nearest, because water is a yes/no.** Bilinear on a binary mask invents half-wet cells that were
never observed. This is a standing project rule and it belongs on the diagram's face.

**The count differs between chains, and the diagram must not say "once" on both sides:**

| chain | steps |
|---|---|
| **cover** | native 30 m / 3577 → **one** bilinear resample → 24.97 m / 8058 |
| **water** | native observations → **near** → pinned **25.0 m** reference grid → **near** → 24.97 m / 8058 |

**Two nearest-neighbour steps, not one.** Label the water side *"nearest neighbour throughout"* and
draw the pinned 25 m grid as its own box.

---

## 6 · The stratification raster — `veg_regime_class_8058.tif`

**Plain terms: which kind of country each square is, and how wet a part of that country.**

One band, `uint8`, eleven classes. **Verified counts, read off the file:**

| code | class | cells | ha |
|---|---|---:|---:|
| 11 / 12 / 13 | **Aeolian** Chenopod Shrublands — low / mid / high wetness | 26,786 / 23,720 / 27,038 | **4,835.0** |
| 21 / 22 / 23 | **Riverine** Chenopod Shrublands — low / mid / high | 65,781 / 64,326 / 63,551 | **12,074.9** |
| 31 / 32 / 33 | **Inland Floodplain** Shrublands and Swamps — low / mid / high | 238,328 / 239,666 / 239,635 | **44,745.2** |
| 40 | Floodplain Woodland and Forest — **treed context, excluded** | 86,375 | 5,385.6 |
| 50 | Other / minor units — excluded | 4,951 | 308.7 |
| 255 | **no class — 8,697,457 cells** | — | — |

**The three focus communities sum to exactly 988,831 cells.** The eleven classes sum to exactly
1,080,157. **Both match the registered census counts to the pixel.**

**The wetness bands are part of the class code, not a separate layer.** Each community is split into
three long-run wetness bands — that is the "veg × wetness matrix". It is already built, and it is
what makes within-stratum comparison possible.

---

## 7 · The footprint ladder — for the face of the diagram

This is the honest answer to *"what are the gaps across the property"*. Four rungs, each verified.

| step | cells | ha | of property | what drops here |
|---|---:|---:|---:|---|
| Property boundary | — | **85,910.8** | 100% | — |
| **Has a vegetation-community label** | 1,080,157 | **67,349.3** | **78.4%** | **21.6% — no community mapping** |
| Non-treed, nine focus strata | 988,831 | **61,655.0** | 71.8% | treed 86,375 · other 4,951 |
| **Inside a management zone → Figure 25** | **795,602** | **49,606.9** | **57.7%** | 193,229 non-treed cells in no paddock |

**Figure 25 rests on 57.7% of the property.** Not 78.4%. The two numbers are both true, of different
steps, and printing the wrong one beside the Figure 25 chain overstates the footprint by 20.7
points.

---

## 8 · The annual water series — verified, and usable on the diagram

Computed here directly from the two stacks over the non-treed census. **This is the x-axis
ingredient, at property scale.**

| | |
|---|---|
| **Mean over 35 years** | **23.3%** |
| **Driest** | **2006–07 at 0.0%** — no cell seen wet |
| **Wettest** | **2022–23 at 84.7%** |
| Other extremes | 2016–17 · 65.8% · 2010–11 · 59.6% · 2003–04 · 0.4% |

**The range is the argument for the whole method.** From essentially nothing to five-sixths of the
property, year to year, with no trend — which is why cover has to be compared *at like wetness*
rather than between periods.

This also reconciles with the methods document's *"under 1% to nearly 90%"*, computed on a
different footprint.

---

## 9 · The plain-language labels

Both axes are **within-year, across-space** quantities. The labels should make that parallel visible
at a glance:

| | plain language | code | registered? |
|---|---|---|---|
| **y** | *the poorest patches, that year* | `veg_p05_spatial` | yes |
| **x** | *how much was under water, that year* | `flood_frac_pct` | **no — nothing registered** |

**`flood_frac_pct` has no registered name and PARTREG will quote it 4,025 times.** Register it with
this label, and record the two collisions it must not be confused with:
`census_flood_frequency_pct`, a per-pixel long-run property with no time axis, and
`inundation_annual_occurrence_pct`, which is plot support on an any-pixel rule.

**"Flood frequency" is the destination, not the ingredient** — it is the 35-year mean of this
quantity. The diagram draws the ingredient becoming the destination, so the two need different
names.
