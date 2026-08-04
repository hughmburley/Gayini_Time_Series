# Gayini LiDAR (Task U) — summary of work, findings and provenance

**Version:** v1.0 · 2 August 2026
**Status:** DRAFT pending cross-check against code and data by CC
**Task U:** closed at `main:c4b4fb7`. Closeout in progress.
**Specs:** `docs/LiDAR/TaskU_lidar_structural_lens_v1.2.md` + amendment log (R5, R6, U3.6, U3.7)
**Superseded specs:** `docs/archive/LiDAR/` (v1, v1.1) — retained, not deleted

---

## How to read the provenance tags

Every quantitative claim carries a tag and a source. **This document is written to be
checked, not trusted.**

| Tag | Meaning |
|---|---|
| **[DS‑V]** | Verified at the design seat by independent recomputation from the delivered rasters or CSVs, on a separate code path from CC's |
| **[CC]** | Reported by CC in a committed change report; **not** independently verified at the design seat |
| **[DB]** | Registered in `Gayini_Results.sqlite` and verifiable against the live database |

Where [DS‑V] and [CC] agree, both are noted. **A disagreement is a stop, not a
reconciliation.**

---

## 1 · What Task U was, and what it was not

Task U used JRSRP LiDAR products as an **interpretive lens on the Landsat results**. It
was never a LiDAR analysis. It consumed finished raster products; it did not touch point
clouds, and it generated no LiDAR product of its own.

The project's central caveat (**spine S6**) is that Landsat fractional cover measures
**cover, not structure**, and therefore cannot separate land-use change from ecological
condition. LiDAR is the only dataset the project holds that measures structure directly.
Two Landsat products agreeing is circular; a Landsat product and a LiDAR product agreeing
is corroboration. That distinction was the entire value of the task.

**Three questions, ranked at the design seat:**

- **U‑Q1** — does structure explain the Bala 29ca reference-state anomaly?
- **U‑Q2** — are the persistent-floor refugia woody or ground-layer? *(not run, deferred)*
- **U‑Q3** — does 2009→2021 change show land use? *(nulls; DEM component deferred)*

**Out of scope throughout:** point-cloud/`.laz` processing, generating CHM/FPC/DEM from
returns, biomass, LAI, gap-probability modelling, PDAL, lidR.

---

## 2 · The delivery

`D:\Github_repos\Gayini\Input\gayini_lidar` — **61 files: 47 GeoTIFFs + 14 `.aux.xml`
sidecars** (GDAL PAM, locally generated 23–29 July, **not shipped by JRSRP**).
**178.0 GiB / 191.1 GB decimal.** [CC]

Three epoch/zone folders. **2021 is delivered as two complementary MGA-zone tiles of one
capture**, not as one dataset in two projections:

| Folder | Epoch | Code | EPSG (from file CRS) | Files | GiB |
|---|---|---|---|---|---|
| `Gayini_2009_GDA1994_z55` | 2009 | `m5` | 28355 GDA94/MGA55 | 16 | 86.83 |
| `Gayini_2021_GDA2020_z54` | 2021 | `d4` | 7854 GDA2020/MGA54 | 16 | 60.42 |
| `Gayini_2021_GDA2020_z55` | 2021 | `d5` | 7855 GDA2020/MGA55 | 15 | 30.75 |

*(GiB column corrected 4 August 2026, LID-1 Y2: was 88.9 / 61.4 / 27.5. `taskU_gateU0_inventory.csv` and the filesystem independently give 86.83 / 60.42 / 30.75. File counts and the 178.0 GiB / 191.1 GB totals were already exact.)*

[CC] · Projection resolved from each file's own CRS, cross-checked against the filename
code; mismatch aborts. **The file is the authority, not the naming convention.**

**Sensors: `l1` Leica ALS‑50 (2009), `l4` Leica ALS‑80 (2021)**, both `dr` discrete
return. This sensor step-change is the central methodological problem of the task.

**Products:** `bb0` DEM, `bb1` max height, `bb2` intensity, `bb3` ground mask, `bb4`
classification, `bb5` first-return density (all 50 cm); `bb8`/`bb9`/`bba`/`bbb`/`bbc`/
`bbd`/`bbe` height percentiles (5 m); `bbh` FPC (10 m); `bbi` hillshade, `bbm` CSM (50 cm).
**`bbn` (pit-free CHM) absent** — immaterial, since `bbm` is DEM-subtracted and the
percentiles give height above ground directly. [CC]

**Capture dates: unrecoverable.** No readme, no delivery note, no dated TIFF tags. [CC]
This is the single largest unresolved limitation — see §7.

---

## 3 · Method — gates and pre-registered rules

Six gates, each ending in an explicit STOP referred to the design seat. Every decision
rule was pinned **before** the number it governs existed.

| Rule | Content | Outcome |
|---|---|---|
| **R1** | Seam precedence: `d4` first, `d5` fills, **never average**; seam written as a mask | Applied |
| **R2** | Physical-plausibility height ceiling **50 m**, both epochs, one screen, sensitivity at 30/50/80 | Applied; STOP fired degenerately, cleared |
| **R3** | Shrub class `bbd` ∈ [1.0, 3.0) m, sensitivity at [0.5,2.0)/[1.5,4.0) | Not exercised — U‑Q2 not run |
| **R5** | U‑Q4b census-pixel inclusion at coverage ≥ 0.99 | Not exercised — U‑Q2 not run |
| **R6** | Floor-vs-flood placement of the Bala paddocks, within community, pixel support | Applied — see §6 |
| **U3.6** | Density-scaling test; a correction is never applied silently | Applied; **no scaling found** |
| **U3.7** | Offset uniformity; report structure and stop | Applied; **failed** |

**Three denominators, never interchangeable:**

| Name | Value | Use |
|---|---|---|
| Property | 85,910.8 ha | **Context only.** Never a statistical denominator |
| **Task U both-valid** | **85,882.6 ha** | Every change statistic |
| **Census ∩ LiDAR** | **67,268.0 ha** | U‑Q4b concordance (unused) |

Task U both-valid: **8,588,260 px × 0.01 ha** = 85,882.6 ha, on-property,
2009 `m5` ∩ (2021 `d4` ∪ `d5`), 10 m, EPSG:8058. **[DS‑V]** — reproduced exactly from
`taskU_bbh_fpc_{2009,2021}_8058_10m.tif`, agreeing with [CC] and [DB]. Census ∩ LiDAR is **[DB]** — registered as `taskU_denominator_census_x_lidar_ha` = 67,268.002, verified live at LID-1 *(tag upgraded from [CC], LID-1 Y5)*.

**99.97% of the property. Do not round to "the whole property"** — the 28.2 ha shortfall
is what makes it a measured figure.

**CRS:** all products warped once to **EPSG:8058**, new files, no original mutated.
EPSG:7854 and 7855 are new to the project; the discipline list now holds **six**
(8058, 28355, 3577, 9473, 7854, 7855).

---

## 4 · Frame quality — the work is sound

**Co-registration: r = 0.897298 at zero offset, peak at (0,0). PASS.** **[DS‑V]** —
recomputed independently, agreeing with [CC] to six decimals. Surface unimodal and
near-symmetric; a one-pixel shift in any direction costs ~0.11 of r.

**Seam:** `d4` ∩ `d5` = **3,633.3 ha** mosaic extent, **1,486.33 ha on-property** at 10 m
and **1,482.69 ha** at 5 m. **[DS‑V]** from the delivered seam masks. Within the seam,
87.77% of pixels identical, mean `d4 − d5` = **+0.029 pp**, median 0 [CC] — one dataset
tiled, not two agreeing.

**R2 exclusions:** 2009 **218 px / 0.545 ha**; 2021 **1 px / 0.0025 ha** (50 m ceiling,
on-property). [CC] The 318 m artefacts found at Gate U0 are almost entirely off-property.

**Coverage after the U‑I11 fix:** 2009 height **85,880 ha**, 2021 **85,855 ha**. **[DS‑V]**
from the delivered 5 m rasters — confirms the fix landed.

---

## 5 · Findings

### F1 · Only 13.33% of the property carries any woody LiDAR cover — **the S6 finding**

> **11,449.25 ha of 85,882.6 ha = 13.3313%** reads FPC > 0 at either epoch.

**[DS‑V]** — recomputed from the delivered rasters, agreeing with [CC] exactly.

The drought floor, the project's headline metric, is therefore measured on country that is
**87% non-woody by area**. The floor is overwhelmingly a **ground-layer** signal, not a
canopy one — which **weakens the S6 cover-versus-condition caveat across most of the
property**.

It does not settle it. U‑Q2, which would test whether persistent floor concentrates
*inside* that 13.33%, was not run. But it **bounds the question in advance: at most 13.33%
of the property could have a woody explanation for its floor.**

### F2 · The Bala 29ca reference-state anomaly dissolves — **R6**

Within-community fits of floor against **long-run census flood frequency** (not annual wet
fraction), pixel support, 988,829 non-treed pixels: [CC]

*(LID-1 Y4, 4 August: **988,829 stands and is not a transcription slip.** The standing non-treed scope is 988,831 px; `R6_bala_floor_flood_placement.py:128` filters `(comm_code > 0) & np.isfinite(p05) & np.isfinite(flood)`, and **exactly 2 non-treed pixels are non-finite in `veg_p05`** — verified against `total_veg_p05_8058.tif` at LID-1. The difference is the stated finite-value filter, an instance of I-T3-I2's NaN class.)*

| Community | n px | slope | r | residual SD |
|---|---:|---:|---:|---:|
| Aeolian | 77,544 | 0.2585 | 0.189 | 12.34 |
| Riverine | 193,658 | 0.5133 | 0.457 | 12.06 |
| Inland | 717,627 | 0.5303 | 0.659 | 10.64 |

> **Bala 29ca's residual is positive in all three communities: +1.57, +9.61, +1.15.** [CC]
> Conditioned on flood frequency within community, **it is not deficient at all.**

The raw 42 pp reference–grazed gap is a **composition-and-hydrology artefact**. 29ca floods
at roughly **one fifth** its neighbours' rate — 13.9% against 66–81% in WY2021, the wettest
year in the gauge record [CC] — and it is a three-community mosaic.

**Frame as confirmatory:** flood frequency sets the floor; 29ca is dry; its floor is where
the project's own headline mechanism predicts. **The result that appeared to threaten the
headline is an ordinary instance of it**, and the cleanest L‑01 demonstration the project
has.

All four of 29ca's residuals sit **well under 1 SD** of the fits' own scatter. That is the
point — they are unremarkable.

### F3 · LiDAR structure agrees, from the other direction — **U‑Q4a**

Zonal `bbd` (95th-percentile height) medians are **0.00 m almost everywhere**, reference
and grazed alike — F1 arriving at paddock grain. Zonal p90 reported beside them, neither
substituted for the other. Every epoch reported separately; **nothing differenced.**

Zonal p90 `bbd`, 29ca against the grazed distribution in the same community: **[DS‑V]**
recomputed from `taskU_gateU4a_zonal_structure.csv`.

| Community | 2009 | 2021 |
|---|---|---|
| Aeolian | 0.00 m (tie at zero) | 0.04 m (41st) |
| Riverine | **0.62 m (83rd)** | 0.96 m (77th) |
| Inland | 0.40 m (61st) | 0.79 m (58th) |

**Zero-inflation caveat (design-seat C4), quantified: 65.7% of the 35 grazed Riverine
zones read p90 = 0.00 in 2009.** **[DS‑V]** So "83rd percentile" is a rank in a
two-thirds-zero distribution. The honest statement: **29ca is one of the minority of
Riverine zones carrying any non-zero p90 structure at all in 2009** — which is the
opposite of the suppressed 2009 canopy a cleared-and-regrowing paddock should show.

> **Verdict: the structural evidence does not support the clearing hypothesis and points
> mildly against it.**

**The low-power caveat travels with this and must not be dropped.** Chenopod shrubland
cleared sixty years ago and never re-treed looks like shrubland never cleared, at 5 m, in
a height product. **The clearing hypothesis is not disproved — it is no longer needed.**
Ernest's land-use history would still say something LiDAR cannot.

### F4 · The four reference paddocks are not a block — **§1c**

They are **~30 km apart**, strung along the floodplain, spanning three communities and a
**~9 m regional fall**. [CC] They were analysed as one condition with four replicates.
**They are not one condition.**

**This is the physical explanation for T2 Gate E**, which found the within-reference
spread exceeds the reference-versus-grazed contrast in 6 of 9 strata (I‑02). Gate E
established *that* distance-to-reference was undefined; §1c establishes *why*.

Corollary trap: **absolute elevation cannot be read as flood susceptibility across this
extent.** 29ca is the *lowest* ground in absolute terms and the *least* flooded, because
over 30 km elevation tells you where you are along the river, not how high you sit above
the local surface.

29ca's hydrological isolation **looks natural** — position and channel-network density,
not an enclosing bank; the engineered grid is property-wide. Recorded as a **visual
impression, not a test.** Source: a timeboxed prose-only DEM inspection, no metric, no
derived surface, nothing registered.

### F5 · Two null results, stated as findings

**Whole-of-property FPC change is not interpretable.** Change-detection floor **9.659 pp**
at 500 m grain against an observed mean of **+0.2569 pp** — a factor of 38. **[DS‑V]**
both figures recomputed from `taskU_gateU3_stable_ground.csv` and the rasters.

**The floor's name is load-bearing.** It is a **change-detection floor on vegetated
ground, 500 m grain**. It conflates sensor difference with real ecological change; it is
S2-derived; it is an **upper bound** on the sensor effect, **not an estimate of it**. The
sensor effect alone is **unbounded above zero** on vegetated ground with the controls this
delivery permits. **It is never written or registered as a "sensor floor."**

**Height change is not separable from drought recovery.** Both controls failed, in
opposite directions: [CC]

- **S1 bare stable (124.3 ha)** has no dynamic range — only 0.46% of its pixels read
  non-zero FPC at either epoch. It bounds an *additive* offset at zero and nothing else.
- **S2 treed stable (4,799.1 ha)** is **not stable**. Gate U2 established that nothing
  vegetated on this property is stable across these dates: 2009 is the drought trough,
  2021 follows the 2016 and 2020–21 floods. Black box grew.

Both nulls were **pre-authorised as legitimate outcomes** and are reported as findings,
not omitted.

### F6 · The vertical offset is real but **not spatially uniform** — U3.7 failed

Stable-ground `bb0` offset, S1: **median +0.3032 m, MAD 0.0243 m, n = 12,397.**
**[DS‑V]** from `taskU_gateU3_stable_ground.csv`.

That looked like a clean calibration. **U3.7 shows it is not:** [CC]

| Test | Result | vs MAD |
|---|---|---|
| 500 m blocks | spread 0.0925 m | 3.8× |
| `d4`→`d5` step | 0.0443 m (n = 137 on the `d5` side) | 1.8× |
| Linear tilt | 0.1345 m over 29.3 km, **R² = 0.4064** | 5.5× |

A plane explains **41% of the variance**, and the implied tilt is **nearly half the 30 cm
calibration itself**. **+0.303 m is withdrawn as a scalar calibration.** No corrected
surface was produced, as U3.7 pre-registered.

**The tilt may not be an artefact.** Twelve years and three flood sequences on an actively
depositing floodplain could produce real differential elevation change with a regional
gradient. U3.7 cannot separate that from a datum tilt — which is precisely why a scalar
correction would have been wrong under either reading. Open, post-deadline, and
scientifically interesting in its own right.

### F7 · The sensor step-change has a magnitude but no usable model

Property-median `bb5` first-return density rose **1.0622 → 1.4672**, ~40% more returns per
unit area at the second epoch [CC] — the ALS‑50 → ALS‑80 step made quantitative, and the
mechanism by which the sensor confound would operate.

*(corrected 4 August 2026, LID-1 Y1: was **1.4855**, computed on `d4`-only 2021 data before the U-I11 re-run and never refreshed. The artefact `taskU_gateU1_r2_density_diagnostic.csv` reads 1.4672. The qualitative claim is unchanged — 1.0622 → 1.4672 is +38.1%, still ~40% — and U3.6 regresses on block density differences rather than this median, so no conclusion moves.)*

**It does not scale.** U3.6 regression of FPC offset on density difference: R² = **0.0120**
(S1) and **0.000088** (S2), with slopes of **opposite sign**. [CC] **No correction is
derivable and none was proposed.** The hazard U3.6 was written to manage — a silently
applied density correction — did not arise.

---

## 6 · Open observations, deliberately not investigated

**U‑I14 · Bala 26ca Riverine.** R6 residual **−17.41 pp** (−1.44 SD, n = 636 px) and
U‑Q4a zonal p90 **0.00 m, 0th percentile at both epochs.**

**Design-seat correction, 2 August:** these are **not two independent lines of evidence.**
They measure the same ground: **[DS‑V]**

| Source | 26ca Riverine part |
|---|---|
| R6 | 636 census px × 0.06235 = **39.7 ha** |
| U‑Q4a `bbd` | 15,900 px × 0.0025 = **39.75 ha** |
| U‑Q4a `bbh` | 3,960 px × 0.01 = **39.6 ha** |

**Two instruments on one 40 ha fragment, agreeing** — which says the fragment is genuinely
poor, and nothing about the paddock. **26ca's Inland part is 2,016.3 ha, R6 residual
+0.59, zonal p90 at the 84th percentile in 2009 and the 91st in 2021** **[DS‑V]** — among
the strongest zones in that community. The Riverine part is **1.9% of the paddock.**

> **No reference paddock carries a paddock-level deficit.** 26ca's negative residual is
> confined to 1.9% of its area.

The conclusion that follows is unaffected and gets **stronger** with the correction: a rule
written to exclude "the anomalous reference paddock" would now be operating on evidence
that dissolves under L‑01. **That is the strongest argument yet for writing the rule before
looking again.**

**Not investigated before 10 August.**

---

## 7 · What the LiDAR could not say

- **Flight months are unrecoverable.** Each epoch has two candidate water years. At the
  2009 capture, farm `veg_p05_spatial` is **30.87 or 51.71** — a 20.8 pp spread; at 2021,
  gauge flow is **3,505 or 15,290 ML/day** — a factor of 4.4. [CC] Direction survives
  (2009 low, 2021 typical-to-high, confirming the drought/post-flood expectation);
  **magnitude does not.** Worst case is percentile 0.0 against percentile 100.0, one of
  four admissible readings.
- **No stable vegetated ground exists between these two dates.** A property of the
  delivery, not a method defect (U‑I10).
- **The vertical offset is not spatially uniform** (F6).
- **`bbh` has 13.33% dynamic range on-property** (U‑I9) — the weakest LiDAR product here.
- **Old clearing on treeless country is close to invisible** at 5 m in a height product.
- **No roads/hardstand/infrastructure layer exists in the repo**; S1 is a Landsat-derived
  proxy (U‑I8).

---

## 8 · Corrections applied during the work — check each landed

| Id | Correction | Where |
|---|---|---|
| **C1** | The R2 density diagnostic rules out a sparse-return artefact; it does **not** establish that "something genuinely tall was there". Nothing on Gayini is 318 m | Gate U1 report §5 |
| **C2** | S2 and the observed woody subset are **not independent** — S2 is ~42% of the set it is compared against. Verdict rests on the 38× margin alone | Gate U3 report §4(b) |
| **C3** | The 13.33% promoted from limitation to **finding** | Gate U3 report §3 |
| **C4** | Riverine 2009 percentile carries the zero-inflation caveat (65.7% at zero) | `TaskU_gateU4a_and_U3_7_report.md` §184-190 *(corrected 4 Aug, LID-1 Y3: read "U-Q4a, bridging note"; no document of that name exists. The caveat landed at the cited lines. **65.7% has no committed home and is deliberately not registered** — a descriptive share inside a caveat, not a headline quantity, and Task U is closed. Independently recomputed at LID-1 as 23 of 35 = 65.7%.)* |
| **C6** | +0.303 m **withdrawn** as a scalar calibration; superseded reading retained visibly | Gate U3 report §6 |
| **C7** | U‑I11's log entry leads with the **diagnosis** — a validity test that silently returned the permissive answer — not the mechanism | Issues log |
| **U‑I14** | The 26ca signal is two instruments on one 40 ha fragment, not two independent lines | §6 above; **pending in both stream documents** |

**Design-seat defects owned:** the Gate U3 item 1 stable-ground derivation was **circular**
(selecting on FPC = 0 at both epochs forces the difference to zero) and would have
manufactured a false pass — U‑I7. The R2 3× STOP condition divides by zero when one epoch
has no exclusions — U‑I5. The v1.2 header instruction to *delete* v1 and v1.1 contradicted
additive-only. The closeout spec said seven CRSs; it is six.

**Build defect:** **U‑I11** — `valid_of()` tested `isinstance(nodata, float)`, false for
`np.float32(nan)`, so the NaN branch never fired and `d5` never entered the 5 m mosaic.
Surfaced because U‑Q4a reported 2021 height coverage of 51,167 ha — the `d4`-only figure.
Blast radius established **by re-running, not by reasoning**: 10 m and 50 cm paths
unaffected and reproduce exactly; only the 5 m height rows moved.

---

## 9 · Registered artefacts

**`raster_asset`** — 20 Task U rasters (`run_id = taskU_gateU1`): `bbh` both epochs, six
height stages both epochs, `bb0` both epochs, 2 seam masks, 2 R2 exclusion masks. Each row
carries checksum (`sha256_first50` + file size), source CRS, epoch, stage code, resolution,
plain-English semantics and legend string. `legend_status` unconfirmed on FPC and height.
The `bbh` rows record that **LiDAR FPC is not comparable to Landsat `total_veg`**.

**`dim_headline_number`** — 2 denominators registered; **10 further rows ruled and pending
insertion** at closeout C1.

**`figure_asset`** — 2 figures.

**`Output/tables/`** — all Task U tables, gitignored but **regenerable** from committed
scripts; chain is `Input/gayini_lidar` → `U1_common_frame.py` + `U1b_dem_warp.py` → the
rest. Confirmed at closeout C4 with no exceptions.

**Documents:** `docs/LiDAR/TaskU_findings_note.md` ·
`docs/change_reports/TaskU_gate*.md` · `docs/reference_update/{Gayini_R6_bala_floor_flood_placement,Gayini_LiDAR_implications_for_reference_state}.md`

---

## 10 · Deferred past 10 August

U‑Q2 refugia concordance (R3 and R5 already pinned) · U‑Q4c difference DEM and earthworks
· the planar de-trend question raised by U3.7 · whether the tilt is real sedimentation ·
the seam's own vertical behaviour, untested because no S1 pixels fall inside it (U‑I13) ·
`read_registered_layer()`, mandated by CLAUDE.md and referenced in seven places but
**undefined in the repo** (U‑I1) · Adrian's three open questions: vertical datum of each
`bb0`, flight months, and what `254` means in the `d5` `bb3`/`bb4` bands.

**Task J note:** L10 is blocked on **provenance** — Jana's confirmation of what the
shapefile represents — which a difference DEM does not supply. The "unblock" is weaker
than it first appeared.

---

## 11 · Cross-check instructions for CC

**Read-only. Do not modify this document; report discrepancies.**

1. **Every [CC] tag** — confirm against the committed change report and the `Output/`
   table it came from. Name the file and the row for each.
2. **Every [DS‑V] tag** — recompute independently. These were computed at the design seat
   from the uploaded rasters and CSVs on a separate code path. **If your value differs,
   stop and report both.** Do not reconcile.
3. **Every [DB] tag** — verify against the live SQLite, `mode=ro`, `PRAGMA query_only=1`.
4. **§8** — confirm each correction actually landed in the named document. **U‑I14 is
   expected to be outstanding** in both stream documents.
5. **§9** — verify the counts: `raster_asset` rows with `run_id = taskU_gateU1`,
   `dim_headline_number` Task U rows, `figure_asset` rows.
6. **§3's rules** — confirm each pinned rule is quoted correctly from the spec and its
   amendment log, and that R3 and R5 are recorded as pinned-but-unexercised.
7. **Any number here that is not in a committed artefact** — report it. A number in a
   summary with no source is the defect this document exists to prevent.

**Report as a discrepancy table:** claim, this document's value, the artefact's value,
verdict. **Do not edit the numbers here.** Corrections come back to the design seat.
