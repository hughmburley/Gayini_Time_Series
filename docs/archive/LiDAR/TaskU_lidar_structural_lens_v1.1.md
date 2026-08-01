> **ARCHIVED v1.1 — superseded by `docs/LiDAR/TaskU_lidar_structural_lens_v1.2.md`.**
> Retained as the provenance chain for the Gate U0 findings that produced the supersession, and because the withdrawn preview figures are recorded here where they can be recognised rather than re-quoted.
> **Never a source for a number.** v1.2 is the only live version; the gate structure and the three questions are identical across all three.

# Task U — LiDAR as a structural lens on the Landsat results

**Subsidiary to:** `Gayini_science_spine_v1.docx`
**Version:** v1.1 · 31 July 2026 — supersedes v1 of the same date
**Depends on:** T1 (zone × stratum join), T2 Gate E (persistence surface), the all-pixel census (Task H)
**Blocks:** nothing — this is corroboration, not critical path
**Data:** `D:\Github_repos\Gayini\Input\gayini_lidar` — 61 files, 54 GeoTIFFs, 178.0 GB

---

## Changelog — v1 → v1.1

v1 was written against two 10 m previews totalling 11.8 MB. CC's Gate U0 recon found the full
JRSRP product suite. The **gate structure and the three questions are unchanged.** What changed:

| # | v1 said | v1.1 says | Why |
|---|---|---|---|
| 1 | Two epoch folders | **Three** — 2009 z55, 2021 z54, 2021 z55 | 2021 delivered in two MGA zones; the partner choice is now an open question and is the first computation of Gate U0 |
| 2 | Preview: 114,631 ha, r = 0.822, +1.16 pp | **Withdrawn** | Computed against `d4` without knowledge of `d5`, on an unnamed denominator. Unquotable under the five-qualifier rule regardless of whether it proves correct |
| 3 | "If only `bbh` is present, ask Adrian for `bbn`" | **STOP condition void** — does not fire | `bbm` (CSM) at both epochs at 50 cm, plus seven height percentiles at 5 m. No question is unanswerable for want of a product |
| 4 | Preview table "When" row | **Corrected** — the 2009 and 2021 columns were swapped | Cosmetic, but it is the row a later reader would trust |
| 5 | "branch and PR with human review" | **Commit to `main`, report the SHA at each STOP** | Inherited from T3 without checking against CLAUDE.md (28 July), which is the live rule. Stale-copy defect, owned |
| 6 | "Compute SHA-256 for each" | **`sha256_first50()` plus file size** | CLAUDE.md forbids whole-file digests for asset registration; full-file over 178 GB is hours of I/O |
| 7 | five and six on the CRS list | **EPSG:7854 and 7855 are new to the project** | Decoded from the file CRS, not the naming convention. Update the CRS register |
| 8 | — | **Pre-registered shrub-height rule added** (§ U‑Q2) | A height threshold that determines an area figure triggers the project's hard pre-registration requirement |
| 9 | — | **Statistics decimation policy added** (Gate U0) | 178 GB of exact descriptive statistics buys nothing ten days from deadline |
| 10 | — | **Capture-date metadata request added** (Gate U0) | A year label is not a date; flight month materially changes trap T‑3 |

---

## Spine anchor

| | |
|---|---|
| **Serves** | Spine **S6** (the cover-versus-condition boundary), the reference-state finding of 27 July, and Adrian's 24 July §5.2 |
| **Claim under test** | That an independent structural sensor either corroborates or contradicts three specific Landsat-derived conclusions: (1) that Bala 29ca is recovering from pre-record disturbance, (2) that the persistent-floor refugia are a real feature rather than a spectral artefact, (3) that 2018–19 earthworks are visible on the ground |
| **Why we are doing this** | The project's central caveat is that Landsat fractional cover measures **cover, not structure**, and therefore cannot separate land-use change from ecological condition. LiDAR is the only dataset we hold that measures structure directly. Two Landsat products agreeing is circular; a Landsat product and a LiDAR product agreeing is genuine corroboration, and that distinction is the entire value of this task. |
| **What would falsify it** | If the two epochs cannot be made comparable — sensor step-change indistinguishable from real change on stable ground — then no change claim survives and the task reduces to a single-date structural description. That is a legitimate outcome, reported as such. |
| **Spine return** | Either strengthens or weakens S6, and supplies an independent line on the reference-state finding that does not depend on Ernest's land-use table |

---

## Scope guard

**This is not a LiDAR analysis.** We consume JRSRP's finished raster products and nothing else.

**Out of scope:** point-cloud or `.laz` processing; generating canopy height models, FPC, DEMs or
any other product from returns; biomass; LAI; gap-probability modelling; anything requiring PDAL
or lidR. Adrian is the LiDAR expert and the products are already his. If a question needs a
product we do not have, **the answer is to ask him, not to build it.**

**In scope:** read the delivered rasters, reproject once into the project frame, clip to the
property, compute zonal and concordance statistics against objects that already exist in
`Gayini_Results.sqlite`, and register the outputs.

---

## The delivery

Three epoch/zone folders. **2021 is delivered twice, in two MGA zones.**

| Folder | Epoch | Proj code | EPSG (read from the files) | Files | GB |
|---|---|---|---|---|---|
| `Gayini_2009_GDA1994_z55` | 2009 | `m5` | 28355 — GDA94 / MGA55 | 16 | 88.9 |
| `Gayini_2021_GDA2020_z54` | 2021 | `d4` | 7854 — GDA2020 / MGA54 | 16 | 61.4 |
| `Gayini_2021_GDA2020_z55` | 2021 | `d5` | 7855 — GDA2020 / MGA55 | 15 | 27.5 |

Footprints at 10 m `bbh`:

- 2009 `m5` — 6000 × 4000, 196000–256000 E, 6158000–6198000 N (EPSG:28355)
- 2021 `d5` — 6000 × 4000, 196000–256000 E, 6158010–6198010 N (EPSG:7855) — **same footprint as 2009, offset 10 m in y**
- 2021 `d4` — 3200 × 4200, 744000–776000 E (EPSG:7854) — a different, smaller box

Products present, decoded against the JRSRP stage table:

| Stage | Plain English | 2009 z55 | 2021 z54 | 2021 z55 | Res |
|---|---|---|---|---|---|
| `bb0` | Raster **DEM**, NN interpolation of classified ground points | ✅ | ✅ | ✅ | 50 cm |
| `bb1` | Gridded **maximum height** of returns above ground | ✅ | ✅ | ✅ | 50 cm |
| `bb2` | Intensity of the return at that maximum height | ✅ | ✅ | ✅ | 50 cm |
| `bb3` | Mask of pixels with ≥ 1 ground return | ✅ | ✅ | ✅ | 50 cm |
| `bb4` | **Classification** of non-ground returns | ✅ | ✅ | ✅ | 50 cm |
| `bb5` | First-return density | ✅ | ✅ | ✅ | 50 cm |
| `bb8` / `bb9` | 1st / 5th percentile of return heights above ground | ✅ | ✅ | ❌ / ✅ | 5 m |
| `bba` / `bbb` / `bbc` | 25th / 50th / 75th percentile height | ✅ | ✅ | ✅ | 5 m |
| `bbd` / `bbe` | **95th** / 99th percentile height | ✅ | ✅ | ✅ | 5 m |
| `bbh` | **Foliage Projective Cover (%)**, Fisher et al. 2020 | ✅ | ✅ | ✅ | 10 m |
| `bbi` | GDALDEM hillshade of `bb0` | ✅ | ✅ | ✅ | 50 cm |
| `bbm` | **Canopy Surface Model** — all non-ground returns, DEM subtracted | ✅ | ✅ | ✅ | 50 cm |
| `bbn` | Canopy Height Model (pit-free, Khosravipour) | ❌ | ❌ | ❌ | — |

**`bbn` is absent and it does not matter.** `bbm` is already DEM-subtracted and gives height above
ground directly, and the seven 5 m percentiles give it robustly. But note what `bbm` is: **all**
non-ground returns interpolated, which means fences, powerlines, vehicles and pits are in it, and
it is not vegetation-filtered the way `bbn` would be. For the 1–3 m shrub question the **5 m
height percentiles are the primary instrument and `bbm` is the fine-detail check**, not the
reverse. `bb4` is available to screen if needed.

Sensors: `l1` Leica ALS‑50 (2009), `l4` Leica ALS‑80 (2021). Both `dr`, discrete return.

---

## Four traps

**T‑1 · Multiple datums and zones.** GDA94/MGA55, GDA2020/MGA54 and GDA2020/MGA55 across three
folders. **EPSG:7854 and 7855 are new to the project** and must be added to the CRS register.
Projection was decoded from the file CRS, not the naming convention — the files are the authority.
The GDA94 → GDA2020 shift is roughly 1.8 m: 0.18 of a 10 m pixel and tolerable for FPC, **3.6 of a
50 cm pixel and not tolerable for a difference DEM**. Reproject to **EPSG:8058** into new files, on
read. Never mutate an original. Minimise resampling generations: prefer the product that has been
reprojected fewest times.

**T‑2 · The sensor changed.** ALS‑50 to ALS‑80 means different point density, scan pattern and
return discrimination. **No change number leaves Gate U3 until the stable-control test has run.**
Same failure mode as Landsat → Sentinel step-change, treated with the same suspicion.

**T‑3 · The two dates are not equivalent points in the record.** 2009 sits at the end of the
Millennium Drought. 2021 follows the 2016 and 2020–21 flood years. A woody gain between them may be
drought recovery rather than land-use change. **The Landsat series settles this** — 35 years of
flood and cover for both dates. Condition on them before interpreting anything. Flight *month*
sharpens this considerably and should be recovered if the metadata carries it.

**T‑4 · FPC is not `total_veg`.** LiDAR FPC is projected foliage cover above the model's height
threshold — effectively woody. Landsat `total_veg = PV + NPV` is surface cover including grass and
litter. **Never on a shared axis, never differenced.** The reason LiDAR is useful is that it
carries information Landsat cannot.

Standing rule throughout: every number carries **support level, scope filter, pixel constant,
denominator and period label.**

---

## The three questions, ranked

**U‑Q1 · Does structure explain Bala 29ca?** *(highest value — do this first)*

The 27 July finding: three of four reference paddocks track the grazed median within 1.5–3.3 pp for
thirty-five years, and Bala 29ca alone sits 42 pp below at the start, closing to 18 pp. Every
reference-state result traces to that one paddock. The stated reading is recovery from clearing or
cropping predating the satellite record — currently untestable, waiting on Ernest.

LiDAR tests it directly, and with the height products present it tests it **on structure and height,
not FPC alone**, which is a sharper instrument than v1 could plan for. A cleared-and-regrowing
paddock has a height signature: suppressed upper percentiles in 2009, rising by 2021, and an
even-aged structure distinct from its uncleared neighbours. If Bala 29ca carries markedly lower
woody structure than Bala 26ca / 27ca / 28ca in 2009 and gains relative to them by 2021, that is
independent structural corroboration from a sensor that cannot be confused with cover. If it carries
the *same* structure, the clearing reading is in trouble and a 42 pp floor gap needs another
explanation.

**U‑Q2 · Are the persistent-floor refugia structural or not?**

Concordance between the T2/T3 persistence surface and LiDAR structure. Both outcomes are publishable
and they mean opposite things:

- **Refugia coincide with woody structure** → the persistent floor is largely canopy, the floor is
  partly measuring structure, and the S6 caveat **bites harder**.
- **Refugia coincide with open ground** → the floor is genuine ground-layer persistence independent
  of woody structure, and the S6 caveat **weakens**.

**Pre-registered decision rule — pinned 31 July 2026, before any number exists:**

> Shrub class = `bbd` (95th percentile height, 5 m) in **[1.0, 3.0) m**. Endpoints taken from
> Adrian's description of the lignum layer, **not tuned to the data**. Sensitivity reported at
> [0.5, 2.0), [1.0, 3.0) and [1.5, 4.0). **The primary is not swapped for a better-agreeing
> alternative.** If the height distribution shows a natural break, report it — but report it beside
> the primary, not instead of it.
>
> Concordance is reported as the contingency table plus **both conditionals**, P(shrub | refugia)
> and P(refugia | shrub), never as a single agreement percentage. The marginals are skewed enough
> that one number would mislead.

Report as concordance only. **This is not validation.** Neither sensor is ground truth for the
other and no wording may imply that one confirms the other's correctness.

**U‑Q3 · What does 2009 → 2021 change show about land use?**

- **FPC and height change** — woody thickening or thinning, subject to T‑2 and T‑3.
- **Difference DEM** — `bb0` is present at both epochs at 50 cm, so this is live. Adrian's original
  idea was to show what Nari Nari have built. It has a second use: **Task J's matched DiD is blocked
  on Jana for bank geometry (L10), and a difference DEM would supply cut locations independently.**

The vertical datum is now the live risk, not a hypothetical. The JRSRP wiki flags ellipsoid-versus-
geoid heights and three AusGeoid models as unresolved. **Never interpret an absolute elevation
difference.** Calibrate on stable ground, report the residual offset, treat only departures from it
as signal. Ask Adrian what vertical datum each `bb0` is in — one line, do not gate on the answer.

---

## Gates

Recon first. No code before the gate spec is echoed. Change report as a DRAFT at every gate.

### Gate U0 — Inventory and decode · **STOP**

**U0.1 — settle the 2021 partner first.** Before the full decode. Three files, ~14 MB: the 10 m
`bbh` from each folder. Reproject all three to EPSG:8058, clip to the property boundary, and report
per candidate the **on-property valid area** and the fraction of the property covered. Report
whether `d4` and `d5` are the same data in two projections or genuinely different coverage.

**The decision rule is on-property coverage, not preference.** If `d4` covers the property fully,
use `d4` and keep `d5` as a check — `d5` is almost certainly a JRSRP reprojection of `d4`, and
stacking a second resampling under ours is avoidable. If `d4` leaves property gaps that `d5` fills,
`d5` becomes the partner and the extra generation is accepted and recorded. State the chosen
partner and the resulting **both-valid intersection area**, which is the denominator for every
change statistic in this task.

**U0.2 — full decode.** All 54 GeoTIFFs, one row each: platform, instrument, product, region,
epoch, **stage code and its plain-English meaning**, projection code and resolved EPSG, resolution,
file size.

**U0.3 — per-raster metadata, exact for all 54:** driver, dimensions, band count, dtype, nodata,
CRS, transform, bounds, resolution. Record the rasterio call; there is no GDAL CLI in this
environment and none is needed.

**U0.4 — value distributions, tiered.** Exact for the 10 m `bbh` (3 files) and the 5 m percentiles
(20 files). Decimated for the 50 cm products (31 files, ~176 GB) by **strided subsampling, not
averaged overviews** — these distributions are zero-spiked and averaging smears the spike, which is
the one statistic that matters on a floodplain. Note whether overviews exist; do not read stats from
them. Record the decimation factor in the change report and in every registration row. **A
decimated statistic is recon-only and may never become a registered number reaching a deliverable.**
Gate U4 reads at native resolution within the property clip, which is a far smaller problem.

**U0.5 — checksums.** `sha256_first50()` plus file size. State in the change report that on a
26.9 GB file this detects replacement, not corruption — acceptable, because these are read-only
inputs we never write.

**U0.6 — capture dates.** Search the folders for any provider metadata carrying **flight dates
within year** — project reports, XML, readme, delivery notes. "2009" and "2021" are year labels, and
on a floodplain a March flight and a September flight see different ground. If absent, say so; it
becomes a one-line question to Adrian alongside the vertical datum.

**U0.7 — mapping.** State which of U‑Q1, U‑Q2, U‑Q3 each product serves, and name any question that
cannot be answered with what is on disk.

**STOP.**

### Gate U1 — Common frame · **STOP**

1. Reproject the products needed for the three questions to **EPSG:8058** into new files. Bilinear
   for continuous surfaces, nearest for classified (`bb3`, `bb4`). Record source CRS, target CRS,
   resampling method and the rasterio call. **Do not reproject the whole 178 GB** — only what the
   questions need.
2. Clip to the property boundary. **Report both mosaic-extent and on-property areas.** Never report
   a LiDAR statistic on the mosaic extent.
3. Restate the both-valid intersection from U0.1 after clipping.
4. **Co-registration check.** Correlate the two epochs on the intersection and report r. Test a
   shift series (±1, ±2 pixels in x and y) and report whether r peaks at zero offset. If it does
   not, the layers are misaligned and Gate U3 cannot proceed.
5. Register in `raster_asset`, **additive only, `INSERT OR REPLACE`** — the `register_taskM_gateC`
   template's `INSERT OR IGNORE` must not propagate; log that to the issues log as an IMPROVE and do
   not stop for it. Each row carries checksum, size, source CRS, resolution, epoch, stage code,
   plain-English semantics and a legend string. `legend_status` starts unconfirmed. The `bbh` row
   must record that FPC is **not** comparable to Landsat `total_veg`.

**STOP.** Report the intersection area and the co-registration result before computing anything.

### Gate U2 — Place both dates in the Landsat record

No new data. Query the existing database and report, for **2009** and **2021** separately:

- annual flood frequency / inundation state for that water year, per community
- `veg_p05` and `veg_p50` for that year against the 35-year distribution — low, typical or high?
- gauge flow context from station 410040
- the same figures for the four Bala reference paddocks, since U‑Q1 depends on them

One table and one figure: the 35-year cover and flood series with 2009 and 2021 marked. If flight
months were recovered at U0.6, mark those instead of year midpoints. **Every later interpretation of
change is conditioned on this table.**

### Gate U3 — Sensor step-change test · **STOP**

Mandatory. No change number may be reported before this passes.

1. Identify stable-reference surfaces: sealed and formed roads, hardstand, building footprints,
   tracks. Use existing layers where available; otherwise derive and say how.
2. Report the FPC **and height** distributions on stable ground in both epochs. On genuinely stable
   ground the difference should be near zero. Report mean, median and spread.
3. Report the same on treed reference areas expected to be stable — mature black box stands well
   away from earthworks.
4. **Give a verdict with a number:** the estimated sensor-attributable offset, and the magnitude
   below which nothing can be claimed. If that floor exceeds the observed mean change, whole-of-
   property change is not interpretable and only large, spatially coherent, locally-contrasted
   changes may be discussed.
5. For `bb0`, report the stable-ground vertical offset separately. That is the difference-DEM
   calibration and it is the gate on U‑Q4c.

**STOP.** Present the verdict and wait. This is a science decision, not a build step.

### Gate U4 — The three questions

Run in order. U‑Q4a alone is a sufficient outcome if time runs out.

**U‑Q4a — Bala 29ca.** Zonal statistics for all 64 management zones at both epochs: FPC, the height
percentiles, and the difference. Report the four reference paddocks explicitly against each other
and against the grazed distribution, stratum-controlled where the strata support it. Deliver as a
table and a figure. State clearly whether the structural evidence supports, contradicts, or is
silent on the clearing hypothesis. **Silence is an acceptable answer and must not be dressed up.**

**U‑Q4b — Refugia concordance.** Apply the pre-registered rule above. Cross-tabulate the T2/T3
persistence surface against the shrub class on the both-valid intersection. Aggregate LiDAR **up**
to the census grid by area-weighted mean — never interpolate the census down. Report the
contingency table, both conditionals, the sensitivity sweep, and which direction the result points
for S6. **No language implying validation.**

**U‑Q4c — Change and earthworks.** FPC and height change maps, thresholded at the Gate U3 floor.
Difference DEM calibrated on stable ground, offset reported, with a check of whether the 2018
bank-cut locations are visible. If they are, say what that means for Task J's L10 blocker — **as a
description of what the earthworks are, not as a causal claim.**

### Gate U5 — Products and registration

1. **Figures**, five at most, in the deck palette. Not viridis for the primary maps; the T7 rule
   applies — pale to emerald, emerald at the maximum, never yellow at either end. Each carries north
   arrow, scale bar, and a caption naming epoch, sensor, product stage, resolution and denominator.
2. **A GeoPackage for Adrian**: FPC and the shrub class at both epochs, the change surface,
   management zones, and the persistence surface, all in EPSG:8058. He must be able to open it in
   QGIS and put his own layers over it.
3. Register figures via `write_and_register_figure()` and vectors in `spatial_layer_asset`.
4. **A findings note** to the design seat, plain-language: for each question, what the LiDAR says,
   what it cannot say, and whether it moves S6.

---

## Acceptance criteria

- [ ] The 2021 partner (`d4` or `d5`) settled on on-property coverage, with the rule stated and the both-valid intersection area named
- [ ] All 54 files decoded against QVF with stage codes translated to plain English
- [ ] Exact headers for all 54; exact distributions for 10 m and 5 m products; decimation factor recorded for 50 cm and those rows marked recon-only
- [ ] Checksums via `sha256_first50()` with file size, and the limitation stated
- [ ] Capture-date metadata searched for and the result reported either way
- [ ] EPSG:7854 and 7855 added to the CRS register
- [ ] Co-registration verified with r reported and the shift series peaking at zero offset
- [ ] Gate U2 table delivered before any change interpretation
- [ ] Gate U3 verdict carries a numeric change floor, and a separate vertical offset for `bb0`
- [ ] Shrub-class rule applied exactly as pre-registered, with the sensitivity sweep reported beside the primary and not substituted for it
- [ ] Concordance reported with both conditionals, never a single agreement percentage
- [ ] No figure or table places LiDAR FPC and Landsat `total_veg` on a shared axis or differences them
- [ ] No wording anywhere implies either sensor validates the other
- [ ] Mosaic-extent and on-property areas both reported; never rebased against each other
- [ ] `INSERT OR REPLACE` throughout; no `INSERT OR IGNORE`
- [ ] Re-run produces identical outputs
- [ ] No existing table or view modified or dropped
- [ ] Change report in `docs/change_reports/`, committed

## Standing rules

Additive only · **never re-run the Task H builder** · no `reset_file` · paths resolved from the
machine and the database, never assumed · **commit to `main` at each gate STOP and report the SHA**
(CLAUDE.md, 28 July — the in-chat gate review is the substantive gate) · no AI attribution in
commits · plot support and pixel support never merged · a null or inconclusive result is a
legitimate reportable outcome

## If only one thing gets done

**U‑Q4a — Bala 29ca.** It needs Gates U0, U1 and U3 and nothing else, it does not depend on Ernest,
and with the height products present it now tests the clearing hypothesis on structure rather than
cover alone.
