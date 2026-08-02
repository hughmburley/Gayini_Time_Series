# Task U — LiDAR as a structural lens on the Landsat results

**Subsidiary to:** `Gayini_science_spine_v1.docx`
**Version:** v1.2 · 31 July 2026 — supersedes v1.1, which superseded v1. Delete both.
**Depends on:** T1 (zone × stratum join), T2 Gate E (persistence surface), the all-pixel census (Task H)
**Blocks:** nothing — this is corroboration, not critical path
**Data:** `D:\Github_repos\Gayini\Input\gayini_lidar` — 61 files: **47 GeoTIFFs** + 14 `.aux.xml` sidecars (GDAL PAM, locally generated, not shipped). **178.0 GiB / 191.1 GB decimal.**

> **This is the last spec revision.** Further findings go to the change reports and the
> issues log, not into new spec versions. The gate structure and the three questions have
> not changed across any revision and will not.

## Amendment log — v1.2 is not reissued; amendments are made in place and dated

| Date | Amendment | Source |
|---|---|---|
| 1 Aug 2026 | **R5** added — U‑Q4b census-pixel inclusion at coverage ≥ 0.99, sensitivity at ≥ 0.5 and = 1.0 | Design-seat Gate U1 STOP, D3 |
| 1 Aug 2026 | **Gate U3 item 6 (U3.6)** added — density-scaling test, from the 1.0622 → 1.4855 `bb5` step | Design-seat Gate U1 STOP, C2 |
| 1 Aug 2026 | Gate U1 recorded **cleared end to end**; the R2 3× STOP condition cleared as a division-by-zero artefact (30 m sweep gives 1.38×). R2 itself unchanged | Design-seat Gate U1 STOP, D1 |
| 1 Aug 2026 | Header instruction "delete v1 and v1.1" **withdrawn** — it contradicted this spec's own additive-only standing rule. Both are archived under `docs/archive/LiDAR/` | Design-seat Gate U1 STOP, D4 |
| 1 Aug 2026 | **R6** added — floor-versus-flood placement of the four Bala paddocks on the census curve, within community, pixel support, run **before** U‑Q4a. Carries the reference-set pre-registration hazard | Design-seat Gate U2 response, §1a / §2 |
| 1 Aug 2026 | **U‑Q4a reframed** — the question is "is 29ca's hydrological isolation natural or engineered?", not "structural or hydrological". Aim the structure test at the R6 residual | Design-seat Gate U2 response, §1b |
| 1 Aug 2026 | **§1c DEM visual** added to Gate U3 as a timeboxed, prose-only inspection — no metric, no derived surface, nothing registered | Design-seat Gate U2 response, §1c |
| 1 Aug 2026 | **Gate U3 accepted.** Floor pinned at **9.7 FPC pp at 500 m grain** but renamed: it is a **change-detection floor on vegetated ground**, S2-derived, an **upper bound** on the sensor effect and never a "sensor floor". The sensor effect alone is unbounded above zero on vegetated ground | Design-seat Gate U3 STOP, D1 |
| 1 Aug 2026 | **U3.7** added — spatial-uniformity check on the vertical offset, by block, by `d4`/`d5` tile provenance, and for linear tilt. Must pass before any difference DEM is interpreted | Design-seat Gate U3 STOP, D3 |
| 1 Aug 2026 | **Scope cut.** U‑Q4b, U‑Q4c and the Task J L10 question are **deferred past 10 August**, one line each in the findings note. Remaining work: U3.7, R6, §1c, U‑Q4a, findings note. **Hard stop end of Monday 3 August.** No new pre-registered rules after this gate — R1–R6 plus U3.6 and U3.7 is the closed set. No new spec versions | Design-seat Gate U3 STOP, §3 |
| 1 Aug 2026 | Gate U3 report §4(b) softened — S2 is ~42% of the woody set it was compared against, so the two are not independent samples; the verdict rests on §4(a)'s 38× margin alone. §3's 13.33% promoted from caveat to finding | Design-seat Gate U3 STOP, C2 / C3 |

---

## Changelog — v1.1 → v1.2

All changes originate in CC's Gate U0 recon, `docs/change_reports/TaskU_gateU0_report.md`.

| # | v1.1 said | v1.2 says | Why |
|---|---|---|---|
| 1 | 54 GeoTIFFs, 7 zero-byte sidecars, 178.0 GB | **47 GeoTIFFs, 14 sidecars with content**, 178.0 GiB / 191.1 GB | Miscount and a rounding artefact in the v1 recon, carried forward in good faith |
| 2 | `d4` **or** `d5` — two branches | **`d4` ∪ `d5`** — the union | They are complementary zone tiles of one capture, not one dataset in two projections. The rule (*coverage, not preference*) is unchanged; the premise was wrong |
| 3 | Denominator TBD | **85,882.6 ha** named, plus two further denominators pinned below | 99.97% of the property. Do not round to "the whole property" |
| 4 | Seam handling "a Gate U1 decision" | **Pinned: `d4` precedence, never average**, seam written as a mask | Averaging creates a 3,633 ha strip with distinct noise properties inside a spatial analysis |
| 5 | — | **Physical-plausibility height ceiling pre-registered** at 50 m | D‑U1: 2009 height percentiles reach 318 m above ground |
| 6 | "`bb4` available to screen if needed" | **2021 `d4` footprint only** | D‑U2: 2009 `bb4` is single-valued; D‑U3: `d5` `bb4` is quarantined |
| 7 | — | **`bbm` valid range and NaN handling pinned** | D‑U4: NaN outside declared nodata, and a −1065 m minimum on a canopy surface model |
| 8 | U‑Q4b denominator implicit | **Census ∩ LiDAR, computed and named separately** | LiDAR reaches 85,882.6 ha; the census maps 67,349 ha. Leaving this implicit is a rebasing error |

---

## Spine anchor

| | |
|---|---|
| **Serves** | Spine **S6** (the cover-versus-condition boundary), the reference-state finding of 27 July, and Adrian's 24 July §5.2 |
| **Claim under test** | That an independent structural sensor either corroborates or contradicts three Landsat-derived conclusions: (1) that Bala 29ca is recovering from pre-record disturbance, (2) that the persistent-floor refugia are a real feature rather than a spectral artefact, (3) that 2018–19 earthworks are visible on the ground |
| **Why we are doing this** | The project's central caveat is that Landsat fractional cover measures **cover, not structure**. LiDAR is the only dataset we hold that measures structure directly. Two Landsat products agreeing is circular; a Landsat product and a LiDAR product agreeing is genuine corroboration, and that distinction is the entire value of this task. |
| **What would falsify it** | If the two epochs cannot be made comparable — sensor step-change indistinguishable from real change on stable ground — no change claim survives and the task reduces to a single-date structural description. A legitimate outcome, reported as such. |
| **Spine return** | Strengthens or weakens S6, and supplies an independent line on the reference-state finding that does not depend on Ernest's land-use table |

---

## Scope guard

**This is not a LiDAR analysis.** We consume JRSRP's finished raster products and nothing else.

**Out of scope:** point-cloud or `.laz` processing; generating canopy height models, FPC, DEMs or
any other product from returns; biomass; LAI; gap-probability modelling. Adrian is the LiDAR expert
and the products are his. If a question needs a product we do not have, **ask him, do not build it.**

**In scope:** read the delivered rasters, reproject once into the project frame, clip to the
property, compute zonal and concordance statistics against objects that already exist in
`Gayini_Results.sqlite`, and register the outputs.

---

## The delivery

Three epoch/zone folders. **2021 is delivered as two complementary MGA-zone tiles of one capture.**

| Folder | Epoch | Code | EPSG (from the file CRS) | Files | GiB |
|---|---|---|---|---|---|
| `Gayini_2009_GDA1994_z55` | 2009 | `m5` | 28355 — GDA94 / MGA55 | 16 | 88.9 |
| `Gayini_2021_GDA2020_z54` | 2021 | `d4` | 7854 — GDA2020 / MGA54 | 16 | 61.4 |
| `Gayini_2021_GDA2020_z55` | 2021 | `d5` | 7855 — GDA2020 / MGA55 | 15 | 27.5 |

Projection codes are resolved from each file's own CRS and cross-checked against the filename code;
a mismatch aborts the run. **The file is the authority.** EPSG:7854 and 7855 are new to the project
and join the CRS register at Gate U1.

Sensors: `l1` Leica ALS‑50 (2009), `l4` Leica ALS‑80 (2021), both `dr` discrete return.

**On-property coverage**, three 10 m `bbh` files on a common EPSG:8058 grid, clipped to
`gayini_boundary_8058` (property 85,910.8 ha, reproducing `TRUE_FARM_HA` exactly):

| Candidate | On-property ha | % of property | Gap ha |
|---|---:|---:|---:|
| 2009 `m5` | 85,899.8 | 99.99% | 11.2 |
| 2021 `d4` | 51,180.6 | 59.57% | 34,730.4 |
| 2021 `d5` | 36,194.0 | 42.13% | 49,717.0 |
| **2021 `d4` ∪ `d5`** | **85,888.3** | **99.97%** | 22.7 |

`d4` and `d5` meet along a **3,633 ha seam** where 87.77% of pixels are identical, 90.05% within
±1 FPC pp, r = 0.9014, mean `d4 − d5` = **+0.029 pp**, median 0. That is one dataset tiled, not two
datasets agreeing. **The marginal difference between the tiles — `d5` 91.1% zero-FPC against `d4`
69.7% — is geography, not calibration.** The seam is the only common ground and they agree there.
No tile-level adjustment is warranted and none may be applied.

### Products present

| Stage | Plain English | 2009 | `d4` | `d5` | Res |
|---|---|---|---|---|---|
| `bb0` | Raster **DEM** | ✅ | ✅ | ✅ | 50 cm |
| `bb1` | Gridded **maximum height** of returns above ground | ✅ | ✅ | ✅ | 50 cm |
| `bb2` | Intensity at that maximum height | ✅ | ✅ | ✅ | 50 cm |
| `bb3` | Mask of pixels with ≥ 1 ground return | ✅ | ✅ | ⚠ D‑U3 | 50 cm |
| `bb4` | **Classification** of non-ground returns | ⚠ D‑U2 | ✅ | ⚠ D‑U3 | 50 cm |
| `bb5` | First-return density | ✅ | ✅ | ✅ | 50 cm |
| `bb8`/`bb9` | 1st / 5th percentile height | ✅ | ✅ | ❌ / ✅ | 5 m |
| `bba`/`bbb`/`bbc` | 25th / 50th / 75th percentile height | ✅ | ✅ | ✅ | 5 m |
| `bbd`/`bbe` | **95th** / 99th percentile height | ✅ | ✅ | ✅ | 5 m |
| `bbh` | **Foliage Projective Cover (%)** | ✅ | ✅ | ✅ | 10 m |
| `bbi` | Hillshade of `bb0` — serves no question, not reprojected | ✅ | ✅ | ✅ | 50 cm |
| `bbm` | **Canopy Surface Model**, DEM subtracted | ⚠ D‑U4 | ⚠ D‑U4 | ⚠ D‑U4 | 50 cm |
| `bbn` | Canopy Height Model (pit-free) | ❌ | ❌ | ❌ | — |

`bbn` is absent and does not matter. `bbd` at 5 m is the **primary height instrument**; `bbm` is the
fine-detail check only — it is not vegetation-filtered (fences, powerlines, vehicles are in it) and
it carries the D‑U4 artefacts.

---

## The three denominators — name the right one every time

Task U carries three, and they are not interchangeable. Every figure, table and sentence states
which it uses.

| Name | Value | Used for |
|---|---|---|
| **Property** | 85,910.8 ha | Context only. Never a statistical denominator here |
| **Task U both-valid** | **85,882.6 ha** — on-property, 2009 `m5` ∩ (2021 `d4` ∪ `d5`), 10 m, EPSG:8058, 0.01 ha/px | Every **change** statistic: U‑Q4a deltas, U‑Q4c |
| **Census ∩ LiDAR** | **To be computed at Gate U1 and named** | U‑Q4b concordance, and anything crossing a census product with a LiDAR product |

The census maps **67,349 ha**; the LiDAR reaches 85,882.6 ha. **The LiDAR covers more of the
property than the Landsat census does.** Any concordance statistic must therefore be computed on
the intersection and reported against it — never against the property, never against 85,882.6 ha,
never against 67,349 ha. Compute it once, register it, quote it every time.

Do not round 99.97% to "the whole property." The 22.7 ha gap is what makes it a measured figure.

---

## Four traps

**T‑1 · Multiple datums and zones.** GDA94/MGA55, GDA2020/MGA54, GDA2020/MGA55. The GDA94 → GDA2020
shift is roughly 1.8 m: 0.18 of a 10 m pixel and tolerable for FPC, **3.6 of a 50 cm pixel and not
tolerable for a difference DEM**. Reproject to EPSG:8058 into new files, on read, one warp each.
Never mutate an original.

**T‑2 · The sensor changed.** ALS‑50 to ALS‑80: different point density, scan pattern and return
discrimination. **No change number leaves Gate U3 until the stable-control test has run.**

**T‑3 · The two dates are not equivalent points in the record.** 2009 sits at the end of the
Millennium Drought; 2021 follows the 2016 and 2020–21 floods. A woody gain may be drought recovery
rather than land-use change. Flight months are **unrecoverable from the delivery** — no readme, no
delivery note, no dated TIFF tags — so T‑3 stands at year resolution and Gate U2 conditions on water
years. A question to Adrian, not a gate.

**T‑4 · FPC is not `total_veg`.** LiDAR FPC is projected foliage cover above the model's height
threshold, effectively woody. Landsat `total_veg = PV + NPV` is surface cover including grass and
litter. **Never on a shared axis, never differenced.**

Standing rule: every number carries **support level, scope filter, pixel constant, denominator and
period label.**

---

## Pre-registered decision rules

Pinned before any number exists. Set from external knowledge, not from the data. **None may be
tuned, and none may be swapped for a better-behaving alternative after the fact.**

### R1 · Seam precedence

`d4` takes precedence throughout the 3,633 ha seam. `d5` fills only where `d4` is absent.
**Never average.** Averaging would create a 3,633 ha strip whose noise properties differ from
everywhere else, inside an analysis whose entire purpose is detecting spatial pattern. Write the
seam out as a mask and register it, so any later finding can be tested for seam sensitivity.

### R2 · Physical-plausibility height ceiling — D‑U1

> **50 m above ground.** Any pixel whose value in any height product exceeds it has its height data
> set to NA **across the whole height stack for that epoch**, and is counted. Applied **identically
> at both epochs.** Sensitivity reported at 30 / 50 / 80 m; the primary is not swapped.

Justification is vegetation ecology, not the observed distribution: river red gum on the
Murrumbidgee frontage reaches 40–45 m, so a tighter ceiling would clip genuine canopy at both
epochs — 2021's own maxima run 43–69 m. Nothing in this system exceeds 50 m. The questions of
interest live at 0–5 m, which is precisely why the ceiling is set generously and defensibly rather
than tightly.

**Two conditions.** Report the excluded area per epoch **before** using screened data. **STOP and
report** if the screen removes more than 1% of the property at either epoch, or if the two epochs
differ by more than roughly threefold. Separately, report whether excluded pixels correlate with low
`bb5` return density — as a **diagnostic** on whether this is a sparse-return artefact, **not** as a
second filter. One screen, simply stated.

*Why this is less alarming than it looks:* U‑Q1 is a between-paddock contrast **within** each epoch.
A noise process affecting 2009 broadly cancels in that contrast. Report zonal **medians**, not means.

### R3 · Shrub class — carried unchanged from v1.1

> Shrub class = `bbd` (95th percentile height, 5 m) in **[1.0, 3.0) m**, post-R2 screen. Endpoints
> from Adrian's description of the lignum layer, **not tuned to the data**. Sensitivity at
> [0.5, 2.0), [1.0, 3.0), [1.5, 4.0). If the height distribution shows a natural break, report it
> **beside** the primary, not instead of it.
>
> Concordance reported as the contingency table plus **both conditionals** — P(shrub | refugia) and
> P(refugia | shrub) — never a single agreement percentage. The marginals are skewed enough that one
> number would mislead.

### R5 · U‑Q4b census-pixel inclusion — *added by amendment, 1 August 2026 (design seat, Gate U1 STOP D3)*

> A census pixel enters the U‑Q4b contingency table if its LiDAR coverage fraction is
> **≥ 0.99**. Sensitivity reported at **≥ 0.5** and **= 1.0**. **The primary is not
> swapped for a better-agreeing alternative.**

Pinned before any concordance number existed. Reasoning, on the record as completeness
rather than tuning: a partially-covered census pixel has its shrub fraction computed on
the covered part and applied to the whole, and partially-covered pixels sit on the
property boundary — river frontage, roads, the edge — which is systematically unlike the
interior. That is a boundary artefact entering a spatial concordance statistic. Cost is
**4,838 pixels, 0.45% of the census.** Not `= 1.0`, because exact equality on
area-weighted floats is brittle and buys only 299 further pixels.

**The registered denominator stays threshold-free.** R5 governs *table membership*, not
the denominator. Report both; never quote one as the other.

### R6 · Floor-versus-flood placement of the Bala paddocks — *added by amendment, 1 August 2026 (design seat, Gate U2 response §1a)*

> Fit the floor-versus-flood-frequency relationship on the all-pixel census at **pixel
> support**, **within community**, using the **census long-run flood frequency** — not
> annual wet fraction. Place all four Bala reference paddocks on that fit and report
> **each paddock's residual**, signed, with its community and n.
>
> Reported whatever the sign. The fit is **not re-specified after seeing the residuals**,
> and no paddock is excluded from the fit on the basis of its residual. Report the fit's
> own scatter so a residual can be read against it.

**Run R6 before U‑Q4a. It is a database query and needs no LiDAR.**

The point: the spine already says flood frequency sets the drought floor, and that p05
rises ~2.2× faster than p50 across the gradient. Bala 29ca floods at roughly one fifth its
neighbours' rate. **A low floor there is what the spine predicts** — so the reference-state
anomaly may be an ordinary instance of the project's own published result rather than a
rival hypothesis to clearing. If 29ca sits **on** the curve, dryness accounts for the
deficit and there is no anomaly left to explain. If it sits **below**, *the residual* — not
the raw 42 pp gap — is what the LiDAR structure test should be aimed at.

**Variable trap.** The Gate U2 Bala table is **annual wet fraction in a single water year**.
The census gradient is **long-run flood frequency over 35 years**. Different variables, different
scales; they must never be substituted for one another. Any statement placing 29ca on the
census curve uses the census variable.

**Pre-registration hazard, on the record before the numbers exist.** Dropping 29ca from the
reference set would raise the reference floor and narrow the reference-versus-grazed gap — a
convergence-favourable move made after seeing the data, on a project that pre-registered
specifically to guard against that pressure. **No change to the reference set is made inside
Task U.** If R6's residuals suggest one, it returns to the design seat as a decision, must be
justified on a rule stated independently of its effect on the answer, and **both versions
reported**.

### R4 · Defect handling — D‑U2, D‑U3, D‑U4

- **`bb4` class screening is available on the 2021 `d4` footprint only.** 2009 `bb4` is
  single-valued and carries no class information; `d5` `bb4` is quarantined under D‑U3. State this
  scope limit wherever class screening is used.
- **`d5` `bb3` and `bb4` are quarantined** — `legend_status` unconfirmed, not used, pending Adrian's
  answer on the undeclared 254 fill. This costs nothing: `bb4` was only ever a screening aid and
  `d4`'s is clean.
- **`bbm` valid range `[−2, +50]` m.** Outside is NA and counted. **NaN is treated as nodata
  explicitly**, not left to propagate through means and percentiles — the declared nodata is −999
  and NaN is not it. `bbm` remains a secondary check only.

---

## The three questions, ranked

**U‑Q1 · Does structure explain Bala 29ca?** *(highest value — do this first)*

The 27 July finding: three of four reference paddocks track the grazed median within 1.5–3.3 pp for
thirty-five years; Bala 29ca alone sits 42 pp below at the start, closing to 18 pp. Every
reference-state result traces to that one paddock. The stated reading is recovery from clearing or
cropping predating the satellite record — untestable on Landsat, waiting on Ernest.

LiDAR tests it on **structure and height**, not cover. A cleared-and-regrowing paddock has a height
signature: suppressed upper percentiles in 2009, rising by 2021, and an even-aged structure distinct
from uncleared neighbours. If Bala 29ca carries markedly lower woody structure than Bala 26ca /
27ca / 28ca in 2009 and gains relative to them by 2021, that is independent structural corroboration
from a sensor that cannot be confused with cover. If it carries the *same* structure, the clearing
reading is in trouble and a 42 pp floor gap needs another explanation.

**U‑Q2 · Are the persistent-floor refugia structural or not?**

Concordance between the T2/T3 persistence surface and the R3 shrub class. Both outcomes are
publishable and mean opposite things:

- **Refugia coincide with woody structure** → the floor is partly measuring structure, S6 **bites harder**
- **Refugia coincide with open ground** → the floor is genuine ground-layer persistence, S6 **weakens**

Report as concordance only. **This is not validation.** Neither sensor is ground truth for the
other and no wording may imply one confirms the other's correctness.

**U‑Q3 · What does 2009 → 2021 change show about land use?**

FPC and height change, subject to T‑2 and T‑3. Difference DEM from `bb0`, present at both epochs at
50 cm. Adrian's original idea was to show what Nari Nari have built; it has a second use —
**Task J's matched DiD is blocked on Jana for bank geometry (L10), and a difference DEM would supply
cut locations independently.**

Vertical datum is the live risk. The `bb0` ranges (2009 55.7–84.8, `d4` 57.9–87.3, `d5` 65.4–85.7 m)
are consistent with orthometric AHD-like heights — AusGeoid separation here is roughly +21 m, so
ellipsoidal would sit near 77–108 m — but this does **not** settle which model, and the differences
between the three are geography, not datum. **Never interpret an absolute elevation difference.**
Calibrate on stable ground at Gate U3 item 5 and nowhere else.

---

## Gates

Gate U0 is **complete**, committed at `main:13bdf6b`, report at `docs/change_reports/TaskU_gateU0_report.md`.

### Gate U1 — Common frame · **STOP**

1. Reproject only what the three questions need to **EPSG:8058**, one warp each, into new files.
   Bilinear for continuous, nearest for classified. `bbi` is not reprojected. Record the rasterio call.
2. **Mosaic 2021 under R1.** Write and register the seam mask.
3. Clip to the property. Report mosaic-extent and on-property areas separately; never rebase one
   against the other.
4. **Compute and name the Census ∩ LiDAR denominator.** Register it.
5. **Apply R2 and report the excluded area per epoch before proceeding.** Honour the STOP conditions.
6. **Co-registration check.** Correlate the epochs on the both-valid intersection; report r. Test a
   shift series (±1, ±2 px in x and y); report whether r peaks at zero offset. If it does not, the
   layers are misaligned and Gate U3 cannot proceed.
7. Register in `raster_asset`, **additive only, `INSERT OR REPLACE`**, each row carrying checksum,
   size, source CRS, resolution, epoch, stage code, plain-English semantics and a legend string.
   `legend_status` starts unconfirmed; `d5` `bb3`/`bb4` stay unconfirmed under R4. The `bbh` row
   records that FPC is **not** comparable to Landsat `total_veg`. Add EPSG:7854 and 7855 to the CRS
   register.

**STOP.** Report the two new denominators, the R2 exclusions and the co-registration result before
computing anything.

### Gate U2 — Place both dates in the Landsat record

No new data. From the existing database, for **2009** and **2021**: annual flood frequency and
inundation state per community; `veg_p05` and `veg_p50` against the 35-year distribution — low,
typical or high?; gauge flow from station 410040; and the same for the four Bala reference paddocks,
since U‑Q1 depends on them.

One table, one figure: the 35-year cover and flood series with both years marked. Marked at **water
year**, not month — flight months are unrecoverable. **Every later interpretation of change is
conditioned on this table.**

### Gate U3 — Sensor step-change test · **STOP**

Mandatory. No change number may be reported before this passes.

1. Identify stable surfaces: sealed and formed roads, hardstand, building footprints, tracks. Use
   existing layers where available; otherwise derive and say how.
2. Report FPC **and height** distributions on stable ground at both epochs. The difference should be
   near zero. Report mean, median, spread.
3. Report the same on treed areas expected to be stable — mature black box well away from earthworks.
4. **Verdict with a number:** the estimated sensor-attributable offset, and the magnitude below
   which nothing can be claimed. If that floor exceeds the observed mean change, whole-of-property
   change is not interpretable and only large, spatially coherent, locally-contrasted changes may be
   discussed.
5. For `bb0`, report the stable-ground **vertical** offset separately, on common ground. That is the
   difference-DEM calibration and the gate on U‑Q4c.

6. **U3.6 · Density-scaling test.** *Added by amendment, 1 August 2026 (design seat,
   Gate U1 STOP C2).* Gate U1 measured the property-median `bb5` first-return density at
   **1.0622 (2009)** against **1.4855 (2021)** — roughly **40% more returns per unit area
   at the second epoch.** That is the ALS‑50 → ALS‑80 step-change made quantitative, and
   it is the mechanism by which T‑2 would operate: FPC is derived from return ratios, so
   more returns per pixel changes gap-detection probability.

   Report the stable-ground FPC offset **alongside** the local `bb5` density difference,
   and test whether the offset **scales** with the density difference across stable-ground
   samples. If it does, report the relationship and the residual scatter — that is the
   sensor effect **identified** rather than merely bounded, and it would let U‑Q4c survive
   with a *stated correction* instead of dying at the floor. If it does not scale, say so
   plainly; the Gate U3 floor stands unmodified and U‑Q4c is limited to large, spatially
   coherent, locally-contrasted change.

   **A correction derived here is never applied silently.** If one is warranted it returns
   to the design seat as a decision — with the relationship, the residual scatter and the
   sample — before any corrected number is computed.

**STOP.** This is a science decision, not a build step.

### Gate U4 — The three questions

In order. U‑Q4a alone is a sufficient outcome if time runs out.

**U‑Q4a — Bala 29ca.** *Reframed by amendment, 1 August 2026 (design seat, Gate U2 response
§1b).* The question is **not** "structural or hydrological" — those are not separable on this
property. Dryness here can be manufactured: banks and levees built to keep water off cropped
country is precisely what Task J is about, so if 29ca was cropped, its low inundation may be a
**consequence** of the management history rather than an alternative to it. A paddock flooding
at 13.9% in the wettest year in the gauge record while its three neighbours reach 66–81% is
either topographically high or hydrologically isolated, and those look very different in a DEM.
The question is:

> **Is Bala 29ca's hydrological isolation natural or engineered?**

Run **R6** first; aim the structure test at the R6 residual, not at the raw 42 pp gap.

Zonal statistics for all 64 management zones at both epochs: FPC, height
percentiles, difference. **Report zonal medians, and report per-zone LiDAR coverage fraction
alongside every statistic** — a paddock at 60% coverage is not comparable to one at 100%. Report the
four reference paddocks explicitly against each other and against the grazed distribution,
stratum-controlled where the strata support it. Table and figure. State whether the structural
evidence supports, contradicts, or is **silent** on the clearing hypothesis. Silence is an acceptable
answer and must not be dressed up.

**U‑Q4b — Refugia concordance.** Apply R3. Cross-tabulate the persistence surface against the shrub
class **on the Census ∩ LiDAR denominator**. Aggregate LiDAR **up** to the census grid by
area-weighted mean; never interpolate the census down. Report the contingency table, both
conditionals, the sensitivity sweep, and which direction the result points for S6. **No language
implying validation.**

**U‑Q4c — Change and earthworks.** FPC and height change maps thresholded at the Gate U3 floor.
Difference DEM calibrated on stable ground, offset reported, with a check of whether the 2018
bank-cut locations are visible. If they are, say what that means for Task J's L10 blocker — **as a
description of what the earthworks are, not as a causal claim.**

### Gate U5 — Products and registration

1. **Figures**, five at most, deck palette. Not viridis for primary maps; T7 rule — pale to emerald,
   emerald at the maximum, never yellow at either end. North arrow, scale bar, and a caption naming
   epoch, sensor, stage, resolution and **which denominator**.
2. **A GeoPackage for Adrian**: FPC and shrub class at both epochs, change surface, seam mask,
   management zones, persistence surface — all EPSG:8058, openable in QGIS.
3. Register figures via `write_and_register_figure()`, vectors in `spatial_layer_asset`.
4. **A findings note** to the design seat, plain language: per question, what the LiDAR says, what it
   cannot say, whether it moves S6.

---

## Acceptance criteria

- [x] 2021 partner settled on on-property coverage — the **union**, 85,888.3 ha, 99.97%
- [x] All **47** files decoded against QVF with stage codes in plain English
- [x] Exact headers for all 47; exact distributions at 10 m and 5 m; **nominal and realised**
      decimation recorded for 50 cm, those rows `recon_only`
- [x] Checksums via `sha256_first50()` with file size, limitation stated
- [x] Capture-date metadata searched; result reported: absent
- [ ] EPSG:7854 and 7855 on the CRS register
- [ ] **All three denominators computed, registered and named** — Task U both-valid, Census ∩ LiDAR, property-as-context
- [ ] R1 applied; seam mask written and registered; no averaging anywhere
- [ ] R2 applied identically at both epochs, exclusions reported per epoch before use, STOP conditions honoured
- [ ] R3 applied exactly as pinned, sensitivity beside the primary and not substituted for it
- [ ] R4 applied: `d5` `bb3`/`bb4` quarantined, `bbm` range enforced, NaN counted not propagated
- [ ] Per-zone LiDAR coverage fraction reported alongside every zonal statistic
- [ ] Co-registration verified, r reported, shift series peaking at zero offset
- [ ] Gate U2 table delivered before any change interpretation
- [ ] Gate U3 verdict carries a numeric change floor and a separate vertical offset for `bb0`
- [ ] Concordance reported with both conditionals, never a single agreement percentage
- [ ] No figure or table places LiDAR FPC and Landsat `total_veg` on a shared axis or differences them
- [ ] No wording anywhere implies either sensor validates the other
- [ ] `INSERT OR REPLACE` throughout
- [ ] Re-run produces identical outputs
- [ ] No existing table or view modified or dropped
- [ ] Change report in `docs/change_reports/`, committed

## Standing rules

Additive only · **never re-run the Task H builder** · no `reset_file` · paths resolved from the
machine and the database, never assumed · **commit to `main` at each gate STOP and report the SHA**
(CLAUDE.md, 28 July) · no AI attribution in commits · plot support and pixel support never merged ·
a null or inconclusive result is a legitimate reportable outcome

## Open questions to Adrian — none gating

1. Vertical datum of each `bb0` — ellipsoidal, or AHD via AusGeoid98 / 09 / 2020?
2. Flight months at each epoch.
3. What is `254` in the `d5` `bb3` / `bb4` bands (D‑U3)?

## If only one thing gets done

**U‑Q4a — Bala 29ca.** It needs Gates U0, U1 and U3 and nothing else, it does not depend on Ernest,
and with the height products present it tests the clearing hypothesis on structure rather than cover
alone. It is also the question most robust to D‑U1, being a within-epoch between-paddock contrast.
