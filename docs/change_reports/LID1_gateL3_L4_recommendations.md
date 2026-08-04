# LID-1 Gates L3 and L4 — recommendations

**Date:** 4 August 2026 · **Amended 4 August with Rulings AG–AJ.** L3 and L4 remain recommendations;
the two findings in §0 are now APPLIED. **The only database write is Ruling AG's 14-row
`legend_semantics` UPDATE** — `raster_asset` 191 → 191, no other registry touched.

**Ruling AD honoured.** `Output/audit/Gayini_LiDAR_section_handoff_to_methods.md` **has not been
opened**, and neither has `Output/audit/CC_handover_DOC1_gates_BCDE.md`. Everything below is written
from the artefacts: the delivery inventory, the 20 registered rasters, the 18 Task U tables, the
registry, and `Gayini_RS_methods_doc_V6.docx`. Both files are moved to `docs/reference_update/` and
committed with this report, not before it.

---

## 0 · Two findings that arrived while preparing L3 and L4

### 0.1 · Fourteen registered `legend_semantics` strings carry a stale pre-U-I11 number

**This is Y1's defect again, inside the registry.** Every height raster's semantics string reads:

> *"Excluded 218 px / 0.545 ha in 2009 and **0 px in 2021**, on-property."*

The artefact `taskU_gateU1_r2_screen.csv` reads **1 px / 0.0025 ha** at 2021, and **U-I15 already
records the change** — *"R2's 2021 exclusion moved 0 → 1 px after U-I11."* The issue was logged; the
14 strings were not updated.

**It matters more than the number does.** The value is trivial — one pixel, 25 m². But these are the
strings going to Adrian under Ruling AF, and they are the plain-English semantics that Ruling X made
the basis for `DATA_HANDOVER`. **Sending a known-stale string for confirmation converts a stale
number into a confirmed one.**

**APPLIED under Ruling AG, 4 August.** One transaction, `UPDATE` not `INSERT` so the row count
cannot move, probes either side (`raster_asset` 191 → 191), the corrected values read from
`taskU_gateU1_r2_screen.csv` rather than typed, and a visible note on each of the 14 rows naming
U-I15 as the source of the change. Verified: **0 rows assert the stale count, 14 assert the corrected
one, 14 carry the note.**

*The first verification of this write was wrong and reported 14 stale rows over correct data* — it
matched the fragment `0 px in 2021`, which **the correction note itself quotes on purpose**. The note
is the record; the sentence is the claim. The check now matches the whole sentence and converges on a
re-run rather than failing.

### 0.2 · `bb8` is absent from the `d5` tile, and that is why 2021 z55 has 15 files

The stage grid from `taskU_gateU0_inventory.csv`: 16 stage codes present, `bbn` absent everywhere,
and **`bb8` present at 2009 and `d4` but not `d5`**. This is already correctly recorded — Gate U1
excluded `bb8` from the height ladder, and the lens spec's product table marks it `❌` for `d5`.

**But the summary §2 does not say so.** It lists *"`bb8`/`bb9`/`bba`/…​ height percentiles"* as
delivered products and names only `bbn` as absent. A reader would conclude seven height percentiles
were available; six were usable. **APPLIED under Ruling AH, 4 August**, and recorded in the U-I11 entry as the third instance of one
shape: **the artefact was right and the prose describing it was not.**

---

## 1 · Gate L3 — the methods-doc section

**Placement confirmed from the document itself.** §11.4 *Measurement constraints* opens with
**"Cover is not condition. Species, structure and ecological condition are not observable in these
products."** That is the limitation the section answers, and it is the last thing a reader meets
before §12. A standalone section between §11 and §12, pushing implications and positioning back one,
is right.

**Do not write it here.** What follows is what it can support, with sources.

### L3-0 · What Task U was, and why the section is in the document — **first**

*Verbatim, Ruling AI:*

> Task U used finished JRSRP LiDAR raster products as an interpretive lens on the Landsat results.
> It was not a LiDAR analysis: it consumed delivered rasters, did not touch point clouds, and
> generated no LiDAR product of its own. Point-cloud processing, canopy height model generation,
> biomass and gap-probability modelling were out of scope throughout.
>
> Two Landsat products agreeing is circular. A Landsat product and a LiDAR product agreeing is
> corroboration. That distinction is the entire value of the task.

**My L3 omitted this and it was the omission that mattered** — without it a reader does not know why
the section is in the document at all.

### L3-8 · The two-epoch trap goes next, before the epochs are named

2009 and 2021 with management changing in 2019 invites a before-and-after reading, and the section
must refuse it in its opening rather than its caveats:

> Two acquisitions twelve years apart measure change between two dates. They cannot attribute it, and
> one date falling after a management change does not make them a controlled comparison. The sensor
> changed between them, and the capture dates within each year are unrecoverable.

### L3-1 · The delivery

**47 GeoTIFFs in three epoch/zone folders, 178.0 GiB / 191.1 GB decimal** — verified against both the
inventory and the filesystem. 14 `.aux.xml` sidecars are locally generated, not shipped by JRSRP.

| folder | epoch | code | EPSG | files | GiB |
|---|---|---|---|---|---|
| `Gayini_2009_GDA1994_z55` | 2009 | `m5` | 28355 | 16 | 86.83 |
| `Gayini_2021_GDA2020_z54` | 2021 | `d4` | 7854 | 16 | 60.42 |
| `Gayini_2021_GDA2020_z55` | 2021 | `d5` | 7855 | 15 | 30.75 |

**2021 is two complementary MGA-zone tiles of one capture, not one dataset in two projections.**
Projection is resolved from each file's own CRS and cross-checked against the filename code; a
mismatch aborts. **The file is the authority, not the naming convention.**

**Two sensors: Leica ALS-50 (`l1`, 2009) and Leica ALS-80 (`l4`, 2021)**, both discrete return.

**Present by stage code:** `bb0` DEM · `bb1` max height · `bb2` intensity · `bb3` ground mask ·
`bb4` classification · `bb5` first-return density (all 50 cm) · `bb8`–`bbe` seven height percentiles
(5 m) · `bbh` FPC (10 m) · `bbi` hillshade · `bbm` CSM (50 cm).
**Absent:** `bbn` pit-free CHM — immaterial, since `bbm` is DEM-subtracted and the percentiles give
height above ground directly. **`bb8` absent from `d5`** — see §0.2.

### L3-2 · The frame

**One warp to EPSG:8058, into new files. No original mutated.** EPSG:7854 and 7855 are new to the
project; the CRS discipline list now holds **six**.

**The three denominators, and the section must say they are never interchanged:**

| name | value | what it is for |
|---|---|---|
| Property | 85,910.8 ha | **context only** — never a statistical denominator |
| **Task U both-valid** | **85,882.6 ha** | every change statistic |
| **Census ∩ LiDAR** | **67,268.002 ha** | anything crossing a census product with a LiDAR product |

Both-valid is **99.97% of the property** and the section should not round it — the 28.2 ha shortfall
is what makes it a measured figure. **The LiDAR reaches 18,533 ha further than the Landsat census
does**, which is why a concordance statistic must be computed on the intersection.

**Co-registration: r = 0.897298 at zero offset, peak at (0,0)** — recomputed independently at Gate L1
across all 25 offsets; a one-pixel shift in any direction costs 0.107–0.115 of r.

**Seam: `d4` takes precedence, `d5` fills, never averaged**, and the seam is written out as a mask —
**1,486.33 ha on-property at 10 m**, 1,482.69 ha at 5 m. Within it, 87.77% of pixels are identical
and the mean `d4 − d5` difference is +0.029 pp: **one dataset tiled, not two agreeing.**

**Per Ruling AE, one line the section needs:** the R6 fits use **988,829 px** — all non-treed country
— while the paddock-part analysis uses **795,600 px**, only zoned land. A reader will meet both.

### L3-3 · The central methodological problem, stated as such

**The sensor changed between epochs**, 2009 sits at the end of the Millennium Drought and 2021
follows two flood years, and **capture dates are unrecoverable**.

**The verdict: whole-of-property FPC change is not interpretable.** The change-detection floor is
**9.659 pp** at 500 m grain against an observed mean of **+0.2569 pp** — **a factor of 38**.

**The floor's name is load-bearing and the section must not shorten it.** It is a *change-detection
floor on vegetated ground at 500 m grain*. It conflates sensor difference with real ecological
change, it is derived from the treed-stable control, and it is an **upper bound on the sensor
effect, never an estimate of it**. It is never written as a "sensor floor".

**No change below 9.659 pp is claimed anywhere.**

The step itself is measurable and does not scale: property-median first-return density rose
**1.0622 → 1.4672** (+38.1%), and regressing FPC offset on density difference gives R² = 0.0120 and
0.000088 with slopes of **opposite sign**. **No correction is derivable and none was proposed.**

### L3-4 · What was tested and what was not

**A question deferred is a stated scope, not a gap — and it must be stated.**

| question | status |
|---|---|
| **U-Q1** does structure explain the Bala 29ca anomaly | **run** — and its reading is open, see L3-6 |
| **U-Q2** are the persistent-floor refugia woody or ground-layer | **not run, deferred.** Its two decision rules (R3 shrub class `bbd` ∈ [1.0, 3.0) m; R5 census-pixel inclusion at coverage ≥ 0.99) **are already pre-registered** |
| **U-Q3** does 2009→2021 change show land use | **nulls**; the difference-DEM component deferred |

### L3-5 · The measured woody extent — both figures, or neither

**This is the one quantitative LiDAR result that bears on a limitation the assessment already
states, and it bears on it by bounding it.**

| | numerator | denominator | value |
|---|---|---|---|
| **measured woody cover** | LiDAR FPC > 0 at either epoch, 11,449.25 ha | Task U both-valid 85,882.6 ha | **13.33%** |
| **woody community share** | census cells in Floodplain Woodland / Forest, 86,375 px = 5,385.6 ha | mapped census area 67,349.332 ha | **8.00%** |

**They are not comparable and neither supersedes the other** — different numerators *and* different
denominators. Crossing them yields 17.00% and 6.27%, which appear in no document and must not.

**Both, or neither.** The bounding statement: *the drought floor is measured on country that is
roughly 87% non-woody by area, so at most that share of the property could have a woody explanation
for its floor.*

**Per Ruling AA, the section must quote 13.33% with its denominator inline** — *11,449.25 ha of
85,882.6 ha both-valid* — because it has no `number_id` to cite.

### L3-6 · The stated non-result

**The section must say this plainly rather than omitting the question.**

Landsat fractional cover and LiDAR structure measure different things. **LiDAR FPC is projected
foliage cover above a height threshold — effectively woody. Landsat `total_veg` is PV + NPV surface
cover including grass and litter. They never share an axis and are never differenced.**

The reading of the Bala 29ca anomaly is **exploratory**: the two instruments disagree, **the metric
question predates the LiDAR work**, and **no conclusion in either direction is offered**. R6's
residuals are computed on the census temporal p05 while the deficit they are compared against is
computed on `veg_p05_spatial`; on the pinned metric the residuals are −29.04 and −18.67 rather than
+1.57 and +9.61, with the Aeolian community fit reversing sign. **The anomaly is neither confirmed
nor dissolved, and the question is open.**

### L3-7 · §12.3 is stale and should not be left so

Current text, `Gayini_RS_methods_doc_V6.docx` §12.3, first next step:

> *"**Structural comparison against LiDAR.** Test spatial concordance between the persistence surface
> of Figure 10 and an independent structural measure…"*

**That reads as a step requiring data.** The data is held, processed, warped to the analysis grid,
checksummed and registered; **the analysis is what is outstanding**, and its decision rules are
already pinned. That is a materially different statement to a client.

**§12.2's row is already correct** — *"LiDAR acquired; comparison not yet performed"* — so §12.3 is
out of step with the gap table two pages earlier.

**Recommended wording:**

> **Structural comparison against LiDAR — data held, analysis outstanding.** Two LiDAR epochs are
> processed onto the analysis grid and registered. The concordance test between the persistence
> surface and an independent structural measure is specified and its decision rules pre-registered;
> it has not been run. Its scope is already bounded: FPC > 0 covers 13.33% of the property
> (11,449.25 ha of 85,882.6 ha both-valid), so at most that share can carry a woody explanation.

---

## 2 · Gate L4 — the handover package

### L4-4 · The cultural governance flag — this leads the recommendation

> **Fifty-centimetre terrain reveals channels, earthworks and scarring that a Landsat product does
> not. This requires Nari Nari Tribal Council review before anything leaves. It is a governance
> decision, not a technical one, and it is not mine or the project's to make.**

It applies most sharply to the two `bb0` DEMs and to any derived hillshade or difference surface.
**Nothing in this package should be transmitted until that review has happened**, and the review
should see the DEMs themselves, not a description of them.

### L4-1 · Which rasters go, at what resolution, and the volume

**178 GiB of source is not a deliverable. The processed EPSG:8058 products are — all 20, at
`DATA_HANDOVER` per Ruling X.**

| grid | files | size |
|---|---|---|
| 0.5 m | 2 (`bb0` DEM, both epochs) | 12,429 MiB |
| 5 m | 15 (12 height percentiles, 2 R2 exclusion masks, 1 seam mask) | 328 MiB |
| 10 m | 3 (2 FPC, 1 seam mask) | 2 MiB |
| **total** | **20** | **12.46 GiB — 7.0% of the source delivery** |

**The two DEMs are 97% of the volume**, and they are also the governance-sensitive layers.

> **The deferral path, stated explicitly (Ruling AJ).** If the Nari Nari review defers the two 50 cm
> DEMs, **the remaining 18 files are 330 MiB and proceed by ordinary means. Nothing waits.**
> The package is designed to be granted in part: **a review that can defer part of a package is
> easier to grant than one that must approve all of it**, and the 97% figure is what makes the
> decision tractable rather than blocking.

### L4-2 · README specification

The README must state, on its face:

1. **CRS** — EPSG:8058 (GDA2020 / NSW Lambert), one warp from source, no original mutated. Source
   CRSs were 28355 (2009 `m5`), 7854 (2021 `d4`), 7855 (2021 `d5`).
2. **Pixel constants** — 0.5 m / 5 m / 10 m as delivered per product; areas at 10 m use 0.01 ha/px.
   **These are LiDAR grids and are not the 24.970268 m census grid.**
3. **Epochs and sensors** — 2009 Leica ALS-50, 2021 Leica ALS-80, both discrete return.
   **Capture dates within each year are unrecoverable.**
4. **Stage codes in plain English** — `bb0` DEM · `bb9`/`bba`/`bbb`/`bbc`/`bbd`/`bbe` height
   percentiles p05/p25/p50/p75/p95/p99 · `bbh` FPC · plus the seam and R2 exclusion masks.
5. **The three denominators**, with which is for what, and that they are never interchanged.
6. **`qa_status = REVIEW` on its face**, on the first page, not in a footer.
7. **What has not been validated** — no field validation; legend semantics stated but unconfirmed
   against the JRSRP definitions on 16 of 20 products; vertical datum of each DEM unresolved;
   the +0.303 m vertical offset **withdrawn** as a scalar calibration because it is not spatially
   uniform; **no change below the 9.659 pp change-detection floor is claimed**.
8. **The non-comparability rule** — LiDAR FPC and Landsat `total_veg` never share an axis and are
   never differenced.

### L4-3 · The GeoPackage — none exists

Gate U5 item 2 produced none, none is on disk, and **`spatial_layer_asset` holds no Task U layer.**
That is correct rather than an omission: it is an **import registry**, so a Task U build output
registered there would be a category error. **Recorded as a stated absence, not a gap to fill.**

### L4-AF · The email to Adrian — the cheapest open item

**16 semantics strings, one query, one message**, converting 16 caveats into 16 confirmations. The
strings are in `raster_asset.legend_semantics` for the rows where `legend_status = 'unconfirmed'`:
2 × `bbh` FPC (10 m), 12 × height percentiles `bb9`/`bba`/`bbb`/`bbc`/`bbd`/`bbe` at both epochs
(5 m), 2 × `bb0` DEM (50 cm).

**Correct the 14 stale strings first (§0.1).** Sending them as they stand asks Adrian to confirm a
number the project already knows is wrong.

Three questions are already embedded in the strings and should be pulled to the top of the message,
because they are the ones only he can answer:

1. **Flight months for each epoch — ask this first and do not bury it (Ruling AJ). It is the
   cheapest improvement available to the whole task.** Each epoch has two candidate water years, and
   which one it falls in changes the context by more than any analysis could recover: the 2009 farm
   floor is **30.87 or 51.71** (a 20.8 pp spread, percentile 0.0 or 5.9) and the 2021 gauge flow
   **3,505 or 15,290 ML/day** (a factor of 4.4, percentile 47.1 or **100.0**). **Direction survives;
   magnitude does not.** One answer removes the spread from every change statement in the task.
2. **Vertical datum of each `bb0`** — ellipsoidal, or AHD via AusGeoid98 / 09 / 2020? The semantics
   string says *"VERTICAL DATUM UNRESOLVED"*, and every elevation statement depends on it.
3. **What `254` means** in the `d5` `bb3` / `bb4` classification bands.

The confirmation question itself is narrow: *does each string describe the product correctly, and is
the FPC non-comparability statement right?* — not a review of the analysis.

---

## STOP — end of Gates L3 and L4

Both are recommendations. **Nothing was built and nothing entered the database.**

**Applied since first issue:** AG (14 semantics rows corrected) · AH (the `bb8` clause, and the
U-I11 entry now records three instances of one shape) · AI (L3-0 added first, verbatim) ·
AJ (the deferral path made explicit, flight months lifted above the datum question).

**Comparison against the design seat's handoff, now on the record.** Reached separately and agreeing:
placement, the two-epoch trap leading, both woody figures or neither, the crossed 17.00% and 6.27%
appearing nowhere, the inline denominator, the §12.3 rewording, governance leading L4, and the
GeoPackage absence as a stated absence. **Three disagreements, two of them the handoff's** — it did
not quote or name the 9.659 pp floor, and carried no volume figure — **and one mine**, the omission
of what Task U was and was not, now L3-0.

**Design seat's:**

1. **L4-4** — the Nari Nari review is a governance decision and nothing ships before it. The
   deferral path is now explicit so the review can be granted in part.
2. **The email to Adrian**, with flight months first. The 14 strings are correct as of this commit
   and safe to send.
