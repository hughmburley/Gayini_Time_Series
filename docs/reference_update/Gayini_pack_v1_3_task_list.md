# Pack v1.3 to Adrian — task list, 7 August 2026

**Design seat.** One working day. Pack v1.2 is sealed and is not edited; v1.3 is a new pack that
supersedes it by manifest.

**What v1.3 is.** The three-periods figure rebuilt with the community lines and the C/A/B order, the
residual maps with a corrected footer, the part-residual geodata, and two data-source metadata
documents. Nothing is re-analysed. No number changes.

---

## Critical path

```
T0  reproduce two caption numbers      ── blocks T2
T1  metadata drafts (veg, inundation)  ── longest, start first, runs parallel
T2  figure rebuild + captions          ── blocks T4
T3  geodata staging                    ── parallel, low risk
T4  pack assembly, manifest, checksums
T5  covering note
```

**T1 is the long pole and has no dependency. It starts first.** T0 is twenty minutes and unblocks
the captions.

---

## T0 · Reproduce the two unregistered caption numbers · **blocks T2**

Both are design-seat Python figures computed from `PARTREG_part_residuals.csv`. Both appear in
caption text. Neither has a `number_id`.

| number | caption | derivation |
|---|---|---|
| Inland mean floor by wetness fifth: 66.7 · 68.8 · 72.5 · 75.0 · 75.0 | three-periods, panel C | pixel-weighted mean `whole_record__floor_mean` within Inland, binned on `whole_record__inund_mean` quintiles |
| residual SD by water quartile: 12.81 · 8.49 · 6.33 · 3.83 pp | residual maps, footer | SD of `whole_record__residual` within quartiles of `whole_record__inund_mean` |

Reproduce in R. Report agreement. **Register both** — they are quoted in a deliverable, so the
five-qualifier rule applies: support level, scope filter, pixel constant, denominator, period label.

**If either fails to reproduce, the caption clause is cut, not softened.** There is no time to
adjudicate a disagreement today.

---

## T1 · Two metadata documents · **start first**

`Output/metadata/Gayini_metadata_ground_cover.md` and
`Output/metadata/Gayini_metadata_inundation.md`.

### Format

**SEED-shaped, not SEED-compliant.** Follow the section order of the NSW SVTM ISO 19115 export so
Adrian reads something familiar, then add the three sections a derived product needs and a published
dataset does not. **Say this in the header** — these are internal provenance documents, not a
metadata lodgement, and must not be mistaken for one.

**Omit any field that would be NA.** SEED's export prints empty rows; ours does not. A document of
empty fields teaches the reader to skim.

**Markdown throughout.** Tables for anything with more than two parallel facts. Dot points for
lists. Short paragraphs elsewhere. No section longer than a screen.

### Sections, in order

**1 · Title, abstract, edition.** What the product is in four sentences. Edition and date.

**2 · Purpose and status.** What it is used for in this project, and what it is not used for.

**3 · Source data.** Table: sensor or provider, native resolution, native CRS, number of layers,
temporal extent, licence or access route.

**4 · Spatial reference and resolution.** Every CRS the chain touches, with its role. Canonical
EPSG:8058 (GDA2020 / NSW Lambert). Cell side 24.970268 m, 0.062351428 ha. **Note explicitly that
25.0 m is not 24.970268 m** — that is the point SCHEM-1 makes and it belongs here too.

**5 · Temporal extent.** Water-year definition. Record start and end. Which years are excluded from
which analysis and why.

**6 · Processing lineage — as chunks.** The novel section, and the one Adrian will use. One numbered
chunk per processing step, each with:

- **What it does**, one sentence in plain language
- **Script**, path and function
- **Inputs**, named
- **Parameters**, including resampling method and any threshold
- **Outputs**, named, with cell or row counts
- **The check that passed**, and what would have made it fail

Read as a notebook: step, code reference, result. **Every count must reconcile to the SCHEM-1
footprint ladder**, and the document states the reconciliation rather than assuming it.

**7 · Decisions register.** Table: decision, alternative not taken, reason, where it is ruled. Every
row cites a document or a ruling. **A decision with no citation is not a decision, it is a habit** —
list it as an unexamined default instead.

**8 · Known error sources and caveats.** Table: what can go wrong, how large it is, whether it is
bounded or unbounded, and what it would affect. Numbers where they exist.

**9 · Collisions.** Quantities in this project whose names invite confusion with the ones documented
here, and how to tell them apart. Cite `number_id` or variable name, never a value.

**10 · Related figures.** The SCHEM-1 and SCHEM-2 schematics draw this chain. **Cite them; do not
redraw.** State that the metadata and the schematic must agree, and that the schematic is the
picture while this is the record.

**11 · Contact and maintenance.** Responsible party, update frequency, where the authoritative copy
lives.

### Content each document must carry

**Ground cover** — do not omit any of these:

- Landsat 5 / 7 / 8 / 9 fractional cover, JRSRP, 30 m, EPSG:3577, 140 seasonal layers → 35 annual
- total vegetation = green + dry, averaged over usable seasons
- **bilinear** resampling to the census grid, because cover is a continuous surface
- **`veg_p05_spatial` and the census `veg_p05` are two different quantities** — across cells within
  one year, against across years within one cell. They differ by up to 17 points at fine grain and
  are never compared. This is the single most confusable pair in the project
- **cover is not condition and not structure.** Landsat cannot separate a recovering shrubland from
  a pasture at the same cover
- **the land-use confound**: the same cover value can be irrigated cropping early in the record and
  native chenopod later. A trend in cover may be a trend in land use
- sensor changes across the record, including the SLC-off period
- **DEA Land Cover CTV tracks observation density, not cultivation, and must never appear in any
  deliverable** (T12 §2.8)

**Inundation** — do not omit any of these:

- open-water classification, 25.0 m, EPSG:28355, already annual, 35 layers
- **nearest neighbour at both resampling steps**, because blending a mask invents half-wet cells
- the two-step resample: onto the pinned 25 m reference grid, then onto the census grid
- the any-observation denominator saturates, so every cell is seen every year — **the denominator is
  a safeguard, not a filter**
- **`flood_frac_pct` has no registered name** (SCHEM-1 §9) and PARTREG quotes it 4,025 times.
  Register it in this task, with the two collisions recorded: `census_flood_frequency_pct`, a
  per-pixel long-run property with no time axis, and `inundation_annual_occurrence_pct`, which is
  plot support on an any-pixel rule
- **the storage-precision asymmetry** found at UNZONED Gate 1: `fact_zone_community_flood_annual`
  stores `flood_frac_pct` rounded to four decimals, maximum deviation 4.999e-05 across 4,130
  part-years, while `fact_zone_veg_annual` stores the same derived quantity at full double
  precision. Immaterial at that size; recorded because it is an asymmetry between grains
- property-scale range: mean 23.3% over 35 years, driest 2006–07 at 0.0%, wettest 2022–23 at 84.7%

### Gate

**One STOP after the first document.** Design seat reviews it before the second is written, so the
shape is settled once rather than twice.

---

## T2 · Figure rebuild · **blocked by T0**

**Three periods** — `PARTREG_S2_three_periods_115_parts.png`, rebuilt:

- panel order **C, A, B**
- community lines added to panel C, from registered fits `2.6_aeolian`, `2.6_riverine`,
  `2.6_inland`. **The two chenopod lines are styled lighter and dotted**; both intervals span zero
  and a solid line asserts more than the data carries
- title answers its own question; subtitle as in the caption register
- opacity legend removed; marker-size note on panel C only
- footer trimmed to the five blocks in the caption register
- spread-ratio paragraph moves to the methods document

**Residual maps** — `PARTREG_S2_residual_maps_three_periods.png`: panels unchanged, footer replaced
per the caption register. **This edit is not optional.** The current wording invites a reader to
treat 8.08 pp as the typical miss everywhere, which overstates dry parts and understates wet ones.

**`PARTREG_S1_floor_vs_flood_115_parts.png` is not in v1.3.** Its panel A duplicated panel C. The
percentile sweep moves to the methods document; the registered-line comparison survives as a caption
line in panel C.

All caption text comes from `Gayini_caption_register.md`. **The register is the source; the figure
script does not hold its own copy.**

---

## T3 · Geodata

- `PARTREG_part_residuals.gpkg` — 115 parts, EPSG:8058, cell-accurate. **The cell-accurate set, not
  the render-only set.** Two objects exist and shipping the simplified one under an accurate name
  would be handing over a simplification
- `PARTREG_part_residuals.csv` with join keys
- `PARTREG_part_residuals_DATA_DICTIONARY.md`
- a QGIS layer style keyed on `whole_record__residual`, if it costs under twenty minutes

---

## T4 · Assembly

`PACK1_assemble.py` pattern. Manifest with SHA-256 verified both sides. **Every table a caption or a
metadata document asserts from must be in the manifest** — including the community-slope
coefficients, which v1.2 asserted from and did not ship.

v1.3 supersedes v1.2 by manifest. v1.2 is not edited and not deleted.

---

## T5 · Covering note

One page. What changed from v1.2 and why. Three items:

- the figure that was two figures is now one, reordered, with community lines
- the residual-map footer correction and what it means for reading the map
- two metadata documents, new

**And one paragraph that is not in any deliverable**, marked design-seat provisional and
unregistered: the within-place response to water is smaller than the between-place slope, the ratio
is about three, and the work quantifying it is specified and parked. Adrian should be able to answer
that question if it is asked on Monday without anything unregistered reaching a figure.

---

## What is not in scope today

UNZONED Stage A2. DIAG-1. The distributed-lag work under Ruling AT. The `M5b` caption staleness —
flagged in the findings note, not edited, because v1.2 is sealed.

**If T1 runs long, it ships as one document rather than two.** Ground cover first — it carries the
`veg_p05_spatial` collision and the land-use confound, which are the two things most likely to be
misread.
