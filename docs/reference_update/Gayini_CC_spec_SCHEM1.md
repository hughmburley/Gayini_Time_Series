# SCHEM-1 · The methods schematic — how Figure 25's two axes are built

**Design seat · 6 August 2026.** For Adrian's deck and for the methods document.

**Purpose.** Adrian is presenting a high-level workflow and ending on something like Figure 25. He
needs to be able to say, in plain terms, exactly how both axes were computed. This schematic is that
answer — one image, no prose required.

**Audience is twofold** and the design must serve both: a remote-sensing scientist who wants the
chain to be exact, and a Nari Nari / BCT audience who need to know what the numbers mean. **Plain
language on the face, precision in the caption.**

---

## 1 · What it draws

Two parallel chains, top to bottom, converging on one scatter.

```
   LEFT CHAIN — ground cover                RIGHT CHAIN — water

   Landsat 5/7/8/9                          Landsat 5/7/8/9
   seasonal fractional cover                open-water classification
   JRSRP · 30 m · EPSG:3577                 25.0 m · EPSG:28355
            |                                        |
   total vegetation = green + dry                wet / valid
   per season, 1988–2023                     per year, 35 years
            |                                        |
   resample to census grid                   resample to census grid
   24.97 m · EPSG:8058                       24.97 m · EPSG:8058
   BILINEAR  (continuous)                    NEAREST  (binary mask)
            |                                        |
            +------------------+---------------------+
                               |
                   cut by PADDOCK x COMMUNITY
                   64 zones x 3 communities = 118 parts
                   115 with sufficient record
                               |
            +------------------+---------------------+
            |                                        |
   for each part, each year:                for each part, each year:
   5th percentile of cover                  share of pixels wet
   ACROSS ITS PIXELS                        ACROSS ITS PIXELS
   = "the poorest patches, that year"       = "how much was under water"
            |                                        |
   35-year series per part                  35-year series per part
            |                                        |
            +------------------+---------------------+
                               |
                    average across years
                               |
                      ONE POINT PER PART
                    on the Figure 25 scatter
```

## 2 · The five things the schematic must make unmissable

**1 · Both axes are computed on the same unit and the same grid.** That is the whole reason the
scatter is legitimate. Show the join explicitly.

**2 · The two resampling rules differ, and why.** Cover is a continuous surface, so **bilinear**.
Water is a binary mask, so **nearest neighbour**. Bilinear on a mask invents half-wet pixels. This
is a standing project rule and it belongs on the face of the diagram, not in a footnote.

**3 · The grid is 24.97 m, not 25 m.** The inundation source is genuinely 25.0 m; the census grid is
24.970268 m. Both numbers appear in the diagram and the difference is labelled, because they look
like the same number and are not.

**4 · Percentile across space, within a year.** Draw it: a small inset showing one part's pixels in
one year, with the 5th percentile marked on their distribution. **This is the single most
misunderstood step** — see §3.

**5 · Where the property is lost.** The census covers 67,349 ha of 85,911 — 78.4%. The 21.6% gap is
unmapped for *vegetation community*, not missing cover data. Mark it on the "cut by paddock ×
community" step, because that is where it happens.

## 3 · The inset that does the most work — two floors, one name

The project holds two 5th-percentile metrics and they are routinely confused. **The schematic should
show both and mark which one Figure 25 uses.**

| | **Spatial floor — used here** | **Temporal floor — not used here** |
|---|---|---|
| Computed | across a unit's pixels, within one year | across one pixel's years, over the whole record |
| Gives | **one number per unit per year — a 35-value series** | one number per pixel, for the record |
| Plain terms | *the poorest patches of this paddock, this year* | *the worst this spot ever got* |
| Time axis | **intact** | **collapsed** |

**Why Figure 25 uses the spatial floor** — and this is the justification to give Adrian:

> The temporal floor is a single value for the whole record. It cannot be recomputed for a shorter
> window and compared, because changing the window changes the quantity — it is not the same number
> at a different time. The spatial floor keeps the time axis, so the same measurement can be made
> every year, in any window, and compared. **Every sensitivity test we can run depends on it.**

They differ by as much as 17 percentage points at fine grain, in opposite directions in different
communities. **They are never compared and never appear in the same figure.**

## 4 · Style

Follow `Gayini_presentation_design_system.md`. Plain-language labels on the face, technical
identifiers in small grey beneath — *"the poorest patches, that year"* over `veg_p05_spatial`, not
instead of it. Cover chain in the warm palette, water chain in the blue, the join in the deep
petrol-teal.

Landscape, sized for both a slide and the methods document's landscape run.

## 5 · Registration

New figure, additive. Registered title in the question pattern used since FIG-BUILD. Goes into the
methods document at §4, where the two floors are defined — not into §9 or §10.
