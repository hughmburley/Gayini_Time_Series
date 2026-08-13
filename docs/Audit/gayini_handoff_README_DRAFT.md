# Gayini floodplain vegetation — satellite time series

Long-term satellite analysis of ground cover and inundation on the Gayini / Nimmie-Caira property,
lower Murrumbidgee floodplain, New South Wales. Thirty-five water years, 1988–2022.

This repository holds the **pipelines that build the analysis substrate**, the documentation needed
to run them, and worked examples of how that substrate is summarised. It is a working repository, not
a software package.

> **Internal.** Contains material relating to Country managed by the Nari Nari Tribal Council. Review
> with NNTC is required before any external sharing or publication of outputs. Place and community
> names follow existing usage in the project documentation — introduce no new naming.

---

## What this is

Three pipelines. Each is re-runnable as new years of imagery accumulate.

| | pipeline | produces |
|---|---|---|
| **1** | Fractional cover → seasonal composites → per-pixel temporal percentile stack | the percentile rasters, including the cover floor (p05) |
| **2** | Inundation scenes → annual wet and valid layers | the layers everything counts from |
| **3** | Census join | one row per pixel, assigned to zone, part, paddock and community — 1,080,157 rows |

**The census is the source of truth.** Almost every downstream number is a summary of it. A counted
flood-frequency raster is also built from pipeline 2 as a **map product** — it is not an analysis
input, and its per-cell values already exist in the census.

## What this is not

**There is no general zonal-summary component.** Summarising a new metric over a new polygon set
means writing a loader. Three worked examples are in `examples/`, at three different polygon grains,
each recording its support level. They are examples of a pattern, not a library — read them, then
write your own against the census.

This is also not a portable pipeline. CRS, grid and property boundary are hard-coded for Gayini
throughout. Running it elsewhere is a rewrite, not a configuration change.

---

## Requirements

R with `terra`, `sf`, `data.table`, `arrow`. Python 3.11+ with `rasterio`, `geopandas`, `pandas`,
`pyarrow`, `numpy`.

Large rasters are read through windowed streaming rather than loaded whole. Expect the percentile
build to want disk more than memory.

---

## Data

**Data does not live in this repository.** The rasters and the census Parquet are far too large.

Vector layers are included, in `Input/shapefiles/` — management zones, vegetation classes, property
boundary, hectare plots. About 461 KB in total.

Everything else must be fetched:

<!-- FILL BEFORE SHARING: where the data lives, and who to ask for access. -->
**Location:** _to be supplied._

`data/README.md` lists every required input with its size, CRS, and expected path.

### Read this before touching the vector layers

**The four supplied layers are in four different coordinate reference systems**, and every one
declares its own correctly:

| layer | CRS |
|---|---|
| Management zones | GDA94 / MGA zone 55 |
| Hectare plots | GDA2020 / MGA zone 54 |
| Vegetation classes | geographic, unprojected |
| Property boundary | geographic, unprojected |

**Never assume a shared CRS because the layers arrive together.** Two are projected in *different MGA
zones* — treating one as the other displaces it by several hundred kilometres. Two use different
datums, about 1.8 m apart, which is sub-pixel at 25 m but roughly 2% of the edge of a 1-hectare plot.

Read each layer's own `.prj` and reproject explicitly to the analysis grid, **EPSG:8058**. The
pipelines do this; anything you write must too.

None of the shapefiles carries a `.cpg`, so character encoding is assumed rather than declared. All
attribute values in all four layers were verified as pure ASCII, so nothing is at risk today — but if
you edit an attribute table, that guarantee no longer holds.

---

## Running it

Run in order. Each stage reads the previous stage's output.

1. **Pipeline 2** — annual wet and valid layers
2. **Pipeline 1** — percentile stack
3. **Pipeline 3** — census join

`INDEX.md` lists every script, which pipeline it belongs to, and the tables, rasters and registered
numbers it writes. **If a script's listed outputs do not appear after a run, that is a real failure**
— the index is generated from the code, not written by hand.

Some file paths are constructed at run time and cannot be resolved by reading the code. Verify a
change by running the pipeline, not by tracing it.

---

## Read this before quoting any number

**`docs/key_takeaways.md`** is the most useful document here. It covers what the analysis found, what
it tested and did *not* find, and — most importantly — the traps that silently produce wrong numbers.

A sample of what is in there, because each has produced a wrong answer at least once and none throws
an error:

- Percentiles do not subtract. Measure paired.
- In uint8, `255 + 255 = 254`. Mask nodata before summing bands, or the data fabricates cover.
- The seasonal minimum threshold does two jobs. Lowering it invents vegetation over open water.
- Mapped area (67,349 ha) is not property area (85,911 ha). State your denominator every time.
- Plot support and pixel support give different, equally correct numbers for the same quantity.

Other documentation:

| file | contents |
|---|---|
| `docs/methods_V13.docx` / `.pdf` | full methods. **Frozen deliverable** — versioned, not edited here |
| `docs/established_facts.md` | settled constants, grids, counts |
| `docs/data_contract.md` | the census schema and its guarantees |
| `CONTRIBUTING.md` | working practice, and why the number rules exist |

**Section 11 of the methods document** rests on figures whose producing code was not located during
the handover audit. Anything concerning paddock ranks, all-paddock counts, or the Dinan 10 paddock
should be re-derived before it is quoted. `docs/key_takeaways.md` §6 names the specific quantities.

---

## `sidelines/`

Work that is off the main line: the LiDAR structural analysis, the CSIRO condition comparison, the
reference-state stream. Each carries a note saying what it did and why it sits outside the pipelines.
**Unsupported.** Kept because the results are informative — several are useful negative results — not
because the code is maintained.

---

## Provenance

Analysis and code by Hugh Burley, produced under contract to UNSW for the Nari Nari Tribal Council
and the Biodiversity Conservation Trust, 2026.

The full development history is preserved in a separate archived repository, private and available on
request. This repository begins at its first commit by design: it holds the load-bearing subset of a
much larger working tree.

Data sources are third-party and carry their own terms. See `ATTRIBUTION.md` for authorship, sources,
and reuse.
