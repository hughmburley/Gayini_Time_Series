# Task U — LiDAR as a structural lens on the Landsat results

**Subsidiary to:** `Gayini_science_spine_v1.docx`
**Version:** v1 · 31 July 2026
**Depends on:** T1 (zone × stratum join), T2 Gate E (persistence surface), the all-pixel census (Task H)
**Blocks:** nothing — this is corroboration, not critical path
**Data:** `/input/Gayini_LiDAR` (resolve the real path from the machine; do **not** assume a drive letter)

---

## Spine anchor

| | |
|---|---|
| **Serves** | Spine **S6** (the cover-versus-condition boundary), the reference-state finding of 27 July, and Adrian's 24 July §5.2 |
| **Claim under test** | That an independent structural sensor either corroborates or contradicts three specific Landsat-derived conclusions: (1) that Bala 29ca is recovering from pre-record disturbance, (2) that the persistent-floor refugia are a real feature rather than a spectral artefact, (3) that 2018–19 earthworks are visible on the ground |
| **Why we are doing this** | The project's central caveat is that Landsat fractional cover measures **cover, not structure**, and therefore cannot separate land-use change from ecological condition. Every limitation in the register traces back to it. LiDAR is the only dataset we hold that measures structure directly. Two Landsat products agreeing is circular; a Landsat product and a LiDAR product agreeing is genuine corroboration, and that distinction is the entire value of this task. |
| **What would falsify it** | If the two epochs cannot be made comparable — sensor step-change indistinguishable from real change on stable ground — then no change claim survives and the task reduces to a single-date structural description. That is a legitimate outcome, reported as such. |
| **Spine return** | Either strengthens or weakens S6, and supplies an independent line on the reference-state finding that does not depend on Ernest's land-use table |

---

## Scope guard — read this before anything else

**This is not a LiDAR analysis.** We consume JRSRP's finished raster products and nothing else.

**Explicitly out of scope:** point-cloud or `.laz` processing; generating canopy height models, FPC, DEMs or any other derived product from returns; biomass; LAI; gap-probability modelling; anything requiring PDAL, lidR, or a change to the processing chain. Adrian is the LiDAR expert on this project and the products are already his. If a question needs a product we do not have, **the answer is to ask him, not to build it.**

**In scope:** read the delivered rasters, reproject them once into the project frame, clip to the property, compute zonal and concordance statistics against objects that already exist in `Gayini_Results.sqlite`, and register the outputs.

If a gate cannot be completed without stepping outside this guard, STOP and say so.

---

## What we already know from the 10 m previews

Two files were inspected at the design seat on 31 July 2026. Treat these as the expected shape of the delivery, not as the delivery itself.

`apl1dr_rgayini_2009_bbhm5_r10m.tif` and `apl4dr_rgayini_2021_bbhd4_r10m.tif`, decoded against the JRSRP QVF convention (https://jrsrp.gitlab.io/sys/meta_info/lidar_filename_codes/):

| Component | 2009 | 2021 |
|---|---|---|
| Platform (`ss`) | `ap` — airborne | `ap` |
| Instrument (`ii`) | `l1` — **Leica ALS‑50** | `l4` — **Leica ALS‑80** |
| Product (`pp`) | `dr` — discrete return | `dr` |
| Where | `rgayini` — region mosaic | `rgayini` |
| When | `2021` — single-year capture | `2009` |
| Stage (`sss`) | `bbh` — **Foliage Projective Cover (%)** | `bbh` |
| Projection (`pp`) | `m5` → **EPSG:28355** GDA94 / MGA55 | `d4` → **EPSG:7854** GDA2020 / MGA54 |
| Resolution | `r10m` — 10 m | `r10m` |

Measured properties: uint8, nodata 255, values 0–100, single band.

| | 2009 | 2021 |
|---|---|---|
| Grid | 6000 × 4000 | 3200 × 4200 |
| Valid area | 216,979 ha | 129,074 ha |
| Mean FPC (own footprint) | 3.49 | 6.48 |
| % FPC = 0 | 80.3 | 69.7 |
| % FPC ≥ 10 | 11.7 | 20.8 |

On the **114,631 ha both-valid intersection**, after nearest-neighbour reprojection of 2009 onto the 2021 grid:

- Pearson r = **0.822** — co-registration is sound and both layers describe the same structure
- Mean change **+1.16 pp**, median 0, p05 −7, p95 +15
- **7.9%** of pixels gained more than 10 pp; **3.2%** lost more than 10 pp
- Class transitions concentrate on the diagonal (73.1% stay in 0–5%; 6.8% stay in 20–50%)

**None of that is yet a finding.** See the traps.

---

## Four traps, each of which has sunk a comparison like this before

**T‑1 · The epochs are in different datums and different zones.** GDA94/MGA55 against GDA2020/MGA54. The GDA94 → GDA2020 shift is roughly 1.8 m — 0.18 of a 10 m pixel, tolerable for FPC, **not** tolerable for a difference DEM at 1 m. Reproject both to **EPSG:8058** once, into new files, on read. Never mutate an original. This makes five and six on the project's CRS list; state the source CRS in every registration row.

**T‑2 · The sensor changed.** ALS‑50 to ALS‑80 means different point density, scan pattern and return discrimination. A +1.16 pp mean FPC gain is exactly the magnitude a sensor difference produces. **No change number leaves Gate U3 until the stable-control test has run.** This is the same failure mode as Landsat → Sentinel masquerading as real change, and it is treated with the same suspicion.

**T‑3 · The two dates are not equivalent points in the record.** 2009 sits at the end of the Millennium Drought. 2021 follows the 2016 and 2020–21 flood years. A woody FPC gain between them may be drought recovery rather than land-use change. **The Landsat series is the instrument that settles this** — we have 35 years of flood and cover for both dates and must condition on them before interpreting anything. This is the reciprocal use of the two datasets and it is not optional.

**T‑4 · FPC is not `total_veg`.** LiDAR FPC is projected foliage cover of vegetation intercepted above the model's height threshold — effectively woody. Landsat `total_veg = PV + NPV` is surface cover including grass and litter. **They are complementary, not comparable, and must never be plotted on a shared axis or differenced.** The whole reason LiDAR is useful here is that it carries information Landsat cannot.

Standing rule that applies throughout: every number carries **support level, scope filter, pixel constant, denominator and period label**. The both-valid intersection is a new denominator and must be named every time it is used.

---

## The three questions, ranked

**U‑Q1 · Does structure explain Bala 29ca?** *(highest value — do this first)*

The 27 July finding: three of four reference paddocks track the grazed median within 1.5–3.3 pp for thirty-five years, and Bala 29ca alone sits 42 pp below at the start of the record, closing to 18 pp. Every reference-state result the project has reported traces to that one paddock. The stated most-plausible reading is recovery from clearing or cropping that predates the satellite record — currently untestable, waiting on Ernest.

**LiDAR tests it directly.** If Bala 29ca carries markedly lower woody FPC than Bala 26ca / 27ca / 28ca in 2009, and gains between 2009 and 2021 relative to them, that is independent structural corroboration of the clearing hypothesis from a sensor that cannot be confused with cover. If it carries the *same* woody structure as its neighbours, the clearing reading is in trouble and we need a different explanation for a 42 pp floor gap.

This is four polygons and two rasters. It is the cheapest high-value thing in the task.

**U‑Q2 · Are the persistent-floor refugia structural or not?**

Concordance between the T2/T3 persistence surface and LiDAR FPC. Both outcomes are publishable and they mean opposite things:

- **Refugia coincide with high woody FPC** → the persistent floor is largely woody canopy (lignum, black box), the floor is partly measuring structure, and the S6 caveat **bites harder**.
- **Refugia coincide with low woody FPC** → the persistent floor is genuine ground-layer persistence independent of woody structure, and the S6 caveat **weakens**.

Report as concordance statistics only. **This is not validation.** Neither sensor is ground truth for the other and no wording may imply that one confirms the other's correctness.

**U‑Q3 · What does 2009 → 2021 change show about land use?**

Two products, if the data supports them:

- **FPC change** — woody thickening or thinning, subject to T‑2 and T‑3.
- **Difference DEM** — if a `bb0` DEM exists at both epochs, the earthworks. Adrian's original 2009/2021 difference-DEM idea was to show what Nari Nari have built. It has a second use we did not anticipate: **Task J's matched DiD is blocked on Jana for bank geometry (L10), and a difference DEM would supply cut locations independently.** That is a real unblock and worth the attempt.

The vertical datum is the risk. The JRSRP wiki flags ellipsoid-versus-geoid heights and three AusGeoid models as an unresolved standardisation problem. **Never interpret an absolute elevation difference.** Calibrate on stable ground — roads, hardstand, building pads — report the residual offset, and treat only departures from that offset as signal.

---

## Gates

Recon first. No code before the gate spec is echoed. Change report as a DRAFT at every gate.

### Gate U0 — Inventory and decode · **STOP**

Do not reproject, clip, or compute anything.

1. Resolve the actual path to the LiDAR directory from the machine, not from an assumption. Report it.
2. Recursive listing: every file, size, and total volume.
3. **Decode every filename against the QVF convention** and produce a table with one row per file: platform, instrument, product, region, epoch, **stage code and its plain-English meaning**, projection code and resolved EPSG, resolution, file size.
4. For each raster: driver, dimensions, band count, dtype, nodata, CRS, transform, bounds, resolution, valid-pixel count and area, and the value distribution (min, max, deciles, count at zero, count at nodata). Compute SHA‑256 for each.
5. **Answer explicitly: is a height product present?** `bbn` (CHM), `bbm` (CSM), or the height percentiles `bb8` / `bb9` / `bba` / `bbb` / `bbc` / `bbd` / `bbe`. Also: is `bb0` (DEM) present at both epochs? Is `bb4` (return classification) present?
6. State which of U‑Q1, U‑Q2, U‑Q3 each available product can serve, and **name any question that cannot be answered with what is on disk.**

**STOP.** If only `bbh` is present, the 1–3 m lignum-height test as Adrian described it cannot be run and we ask him for `bbn` before proceeding to U‑Q2b.

### Gate U1 — Common frame · **STOP**

1. Reproject every product to **EPSG:8058** into new files under the project's raster output path. Bilinear for continuous surfaces, nearest for classified. Record source CRS, target CRS, resampling method and the reprojection command in the change report.
2. Clip to the property boundary. **Report both the mosaic-extent area and the on-property area.** Never report a LiDAR statistic on the mosaic extent.
3. Compute the **both-valid intersection** across the two epochs and state its area in hectares. That figure is the denominator for every change statistic in this task.
4. **Co-registration check.** Correlate the two epochs on the intersection and report r. Test a small shift series (±1, ±2 pixels in x and y) and report whether r peaks at zero offset. If it does not, the layers are misaligned and Gate U3 cannot proceed.
5. Register every reprojected product in `raster_asset`, additive only, with checksum, source CRS, resolution, epoch, stage code, plain-English semantics and a legend string. **`legend_status` starts unconfirmed.** Semantics for `bbh` are "Foliage Projective Cover, percent, JRSRP `bbh`, Fisher et al. 2020" — and the row must record that this is **not** comparable to Landsat `total_veg`.

**STOP.** Report the intersection area and the co-registration result before computing anything.

### Gate U2 — Place both dates in the Landsat record

No new data. Query the existing database and report, for **2009** and **2021** separately:

- annual flood frequency / inundation state for that water year, per community
- `veg_p05` and `veg_p50` for that year against the 35-year distribution — is each date a low, typical or high year?
- the gauge flow context from station 410040
- the same figures for the four Bala reference paddocks specifically, since U‑Q1 depends on them

Deliver a short table and one figure: the 35-year cover and flood series with 2009 and 2021 marked. **Every later interpretation of change is conditioned on this table.** If 2009 is a drought year and 2021 a post-flood year — which is expected — then say so plainly and carry it into every change statement.

### Gate U3 — Sensor step-change test · **STOP**

Mandatory. No change number may be reported before this passes.

1. Identify stable-reference surfaces on the property: sealed and formed roads, hardstand, building footprints, tracks. Use existing layers where available; otherwise derive from persistently-zero FPC in both epochs and say how.
2. Report the FPC distribution on stable ground in both epochs. **On genuinely stable ground the difference should be near zero.** Report the mean, median and spread of the difference there.
3. Report the same on treed reference areas expected to be stable — mature black box stands well away from earthworks.
4. **Give a verdict with a number:** the estimated sensor-attributable offset, and the magnitude of change below which nothing can be claimed. If that floor exceeds the observed mean change, then the whole-of-property FPC change is not interpretable and only large, spatially coherent, locally-contrasted changes may be discussed.

**STOP.** Present the verdict and wait. This is a science decision, not a build step.

### Gate U4 — The three questions

Run in order. U‑Q1 alone is a sufficient outcome if time runs out.

**U‑Q4a — Bala 29ca.** Zonal statistics of FPC (and height, if present) for all 64 management zones at both epochs, and the difference. Report the four reference paddocks explicitly against each other and against the grazed distribution, stratum-controlled where the strata support it. Deliver the four-paddock comparison as a table and a figure. State clearly whether the structural evidence supports, contradicts, or is silent on the clearing hypothesis. **Silence is an acceptable answer and must not be dressed up.**

**U‑Q4b — Refugia concordance.** Cross-tabulate the T2/T3 persistence surface against FPC classes on the both-valid intersection. Aggregate LiDAR **up** to the census grid by area-weighted mean — never interpolate the census down. Report the contingency table, the marginal distributions and a concordance statistic, with the denominator named. Report which direction the result points for S6. **No language implying validation.**

**U‑Q4c — Change and earthworks.** FPC change map, thresholded at the Gate U3 floor. If `bb0` exists at both epochs: difference DEM, calibrated on stable ground, offset reported, and a check of whether the 2018 bank-cut locations are visible. If they are, say what that means for Task J's L10 blocker — **as a description of what the earthworks are, not as a causal claim.**

### Gate U5 — Products and registration

1. **Figures**, five at most, in the deck palette. Not viridis for the primary maps; the T7 rule applies — pale-to-emerald with emerald at the maximum, never yellow at either end. Each carries north arrow, scale bar, and a caption naming the epoch, the sensor, the product stage, the resolution and the denominator.
2. **A GeoPackage for Adrian** at the project's spatial output path: FPC both epochs (or a class polygonisation), the change surface, management zones, and the persistence surface, all in EPSG:8058. He must be able to open it in QGIS and put his own layers over it.
3. Register figures via `write_and_register_figure()` and vectors in `spatial_layer_asset`. Additive only.
4. **A findings note** to the design seat, plain-language, stating for each of the three questions: what the LiDAR says, what it cannot say, and whether it moves S6.

---

## Acceptance criteria

- [ ] Every file in the delivery decoded against the QVF convention, with stage codes translated to plain English
- [ ] Height-product presence answered explicitly, yes or no, by stage code
- [ ] All products reprojected to EPSG:8058 into new files; no original mutated
- [ ] Both-valid intersection area computed and used as the stated denominator for every change statistic
- [ ] Co-registration verified with r reported and the shift series peaking at zero offset
- [ ] Gate U2 table delivered before any change interpretation
- [ ] Gate U3 verdict carries a numeric floor below which no change is claimed
- [ ] No figure or table places LiDAR FPC and Landsat `total_veg` on a shared axis or differences them
- [ ] No wording anywhere implies either sensor validates the other
- [ ] Mosaic-extent and on-property areas both reported; never rebased against each other
- [ ] Every registered row records source CRS, stage code, semantics and checksum
- [ ] Re-run produces identical outputs
- [ ] No existing table or view modified or dropped
- [ ] Change report in `docs/change_reports/`, committed

## Standing rules

Additive only · **never re-run the Task H builder** · no `reset_file` · paths resolved from the database and the machine, never assumed · branch and PR with human review · no AI attribution in commits · plot support and pixel support never merged · a null or an inconclusive result is a legitimate reportable outcome

## If only one thing gets done

**U‑Q4a — Bala 29ca.** It needs Gates U0, U1 and U3 and nothing else, it does not depend on Ernest, and it speaks to the question the reference-state finding left open.
