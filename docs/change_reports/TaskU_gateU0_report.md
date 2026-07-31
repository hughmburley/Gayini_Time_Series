# Task U · Gate U0 — Inventory and decode · **DRAFT**

**Spec:** `docs/LiDAR/TaskU_lidar_structural_lens_v1.1.md`, Gate U0
**Date:** 31 July 2026 · **Status:** DRAFT, at the Gate U0 STOP
**Scripts:** `scripts/14_lidar/U0_1_partner_decision.py`, `scripts/14_lidar/U0_inventory.py`
**Artefacts:** `Output/tables/taskU_gateU0_partner_decision.csv` ·
`Output/tables/taskU_gateU0_inventory.csv` (47 rows) ·
`Output/tables/taskU_gateU0_distributions.csv` (47 rows)

Read-only against `Input/gayini_lidar`. No raster written, nothing registered, no
existing table or view touched. Registration is Gate U1.

**This report states findings and points at the `Output/` artefacts. It is not the
home of any value** — every number below is reproducible from the three CSVs.

---

## 0 · Two corrections to the v1.1 spec header

Both originate in my own Gate U0 recon on v1, which v1.1 carried forward in good faith.

| v1.1 says | Actual | How the error arose |
|---|---|---|
| "61 files, **54 GeoTIFFs**, 178.0 GB" | 61 files, **47 GeoTIFFs**, 14 `.aux.xml` | I counted tif-vs-sidecar by eye from a listing and got the split wrong. 47 is asserted by `len(tifs)` in the inventory script, not by counting |
| `.aux.xml` sidecars are "zero-byte" | 1.2–2.4 KB each, **with content** | My listing rounded `Length/1MB` to 2 dp, so 2,397 B printed as `0`. My error, not the data's |

Total volume is **191,122,625,503 bytes** — 178.0 GiB, or 191.1 GB decimal. The
spec's "178.0 GB" is the GiB figure.

The acceptance criterion "All 54 files decoded" should read **47**.

---

## 1 · U0.1 — the 2021 partner · **the spec's two-branch rule does not cover the answer**

Artefact: `Output/tables/taskU_gateU0_partner_decision.csv`

Method: the three 10 m `bbh` files reprojected in memory onto one common EPSG:8058
10 m grid (6407 × 4375, origin snapped to a whole multiple of the resolution),
clipped to `gayini_boundary_8058` (spatial_007). **Nearest neighbour throughout** —
this gate answers a coverage question, and bilinear would bleed the 255 nodata into
the valid margin and inflate the very area being measured. Gate U1 does the
value-preserving bilinear reprojection separately.

Property polygon **85,910.8 ha**, which reproduces `TRUE_FARM_HA` exactly;
rasterised onto the 10 m grid it is 85,911.0 ha, a +0.2 ha rasterisation
difference. Pixel constant **0.01 ha/px**, derived from the resolution, never typed.

| Candidate | Mosaic valid ha | On-property ha | % of property | Property gap ha |
|---|---:|---:|---:|---:|
| 2009 `m5` | 216,436.9 | 85,899.8 | **99.99%** | 11.2 |
| 2021 `d4` | 128,778.6 | 51,180.6 | 59.57% | 34,730.4 |
| 2021 `d5` | 127,931.2 | 36,194.0 | 42.13% | 49,717.0 |
| **2021 `d4` ∪ `d5`** | 253,076.5 | **85,888.3** | **99.97%** | 22.7 |

**`d4` and `d5` are not the same data in two projections.** They are complementary
zone tiles of one 2021 capture that meet along a narrow seam:

- `d4`-valid only 125,145.3 ha · `d5`-valid only 124,297.8 ha · **both valid only 3,633.3 ha**
- in that 3,633 ha seam: 87.77% of pixels identical, 90.05% within ±1 FPC pp,
  r = 0.9014, mean `d4 − d5` = **+0.029 pp**, median 0

The seam agreement is what two independent resamplings of one source look like — a
mean difference of three hundredths of a percentage point with a zero median. The
non-overlap is not disagreement; it is different ground.

**Decision.** The spec's rule has two branches — *`d4` covers the property, use `d4`*;
or *`d4` leaves gaps `d5` fills, use `d5`*. Neither fires: `d4` alone leaves
34,730 ha of property uncovered and `d5` alone leaves 49,717 ha. Applying the
stated rule (**on-property coverage, not preference**) to its logical conclusion,
the 2021 partner is the **mosaic `d4` ∪ `d5`**, which reaches 99.97% of the
property. This is a third branch and it needs sign-off.

**The both-valid intersection — the denominator for every change statistic in Task U:**

> **85,882.6 ha**, 99.97% of the property, on-property, 2009 `m5` ∩ (2021 `d4` ∪ `d5`),
> at 10 m in EPSG:8058, pixel constant 0.01 ha/px.
> Single-partner alternatives, for the record: ∩ `d4` = 51,177.5 ha; ∩ `d5` = 36,191.4 ha.

For contrast, the withdrawn v1 preview figure was 114,631 ha — a **mosaic-extent**
number against `d4` only. It was never an on-property figure, which is why it
exceeds the property. Withdrawal confirmed and independently justified.

This is a far better position than either branch anticipated: **near-total property
coverage at both epochs**, so U-Q1 and U-Q2 run on essentially the whole farm rather
than on 42–60% of it.

**Cost of the union:** `d4` and `d5` are in different MGA zones, so one of them must
be reprojected into the other's frame — or, as Gate U1 will do, both go straight to
EPSG:8058 in a single warp each. No extra resampling generation is incurred by
mosaicking; the seam is handled by preferring one source and filling from the other.
Which source takes precedence in the 3,633 ha seam is a Gate U1 decision and will be
recorded.

---

## 2 · U0.2 / U0.3 — decode and headers

Artefact: `Output/tables/taskU_gateU0_inventory.csv`, one row per GeoTIFF, 47 rows.

Every filename parses against the QVF stem convention
`ss ii pp _ rREGION _ YYYY _ SSSPP _ rRES`. Stage meanings are transcribed verbatim
from the JRSRP table; **projection codes are resolved from each file's own CRS and
cross-checked against the code, and a mismatch aborts the run.** The file is the
authority — the JRSRP `filename_codes` page does not publish the projection table in
fetchable form.

| Code | EPSG | Confirmed from |
|---|---|---|
| `m5` | 28355 — GDA94 / MGA55 | file CRS |
| `d4` | 7854 — GDA2020 / MGA54 | file CRS |
| `d5` | 7855 — GDA2020 / MGA55 | file CRS |

**EPSG:7855 is new to the project** and joins 7854 on the CRS register. Sensors:
`l1` Leica ALS-50 (2009), `l4` Leica ALS-80 (2021), both `dr` discrete return.

Headers are exact for all 47 — driver, dimensions, band count, dtype, nodata, CRS,
transform, bounds, resolution, block shape, overview list. Read via **rasterio
1.5.0**; there is no GDAL CLI and no `osgeo` binding in this environment and none is
needed. Every row also carries the resampling method its stage will take at Gate U1
(nearest for `bb3`/`bb4`, bilinear otherwise).

**No file carries overviews.** Statistics were therefore never at risk of being read
from one, but the check is recorded per row (`has_overviews`) as the spec requires.

## 3 · U0.4 — tiered distributions

Artefact: `Output/tables/taskU_gateU0_distributions.csv`

| Tier | Files | Method | `recon_only` |
|---|---|---|---|
| Exact | 23 — 10 m `bbh` (3) + 5 m height percentiles (20) | full read | 0 |
| Decimated | 24 — the 50 cm products | systematic 2-D **block**-strided sample, never averaged | **1** |

Decimation design: take one block in 8 in **both** x and y, then one pixel in 4 in
both directions inside each sampled block. Sampling every Nth block in one direction
only would skip whole regions of floodplain; the 2-D pattern keeps coverage spatially
uniform. Nominal fraction 1/1024.

**The realised fraction is not the nominal fraction, and the CSV records both.**
The 2009 and `d4` files are square-tiled `[512, 512]` and realise 0.001024, within
5% of nominal. **The entire `d5` delivery is striped `[1, 120000]`** — one row per
block — so the block stride selects every 8th *row* and all columns, realising
**0.03125**, over 30× denser. The sample is still systematic and unbiased; only its
size differs. `sampling_fraction_actual` and a `block_sampling_uniform` flag are
stored per row, and **only the actual figure may be quoted.** A single nominal
constant asserted across all 24 rows would have been a stored number incapable of
noticing it was wrong.

**Every decimated row is `recon_only = 1` and may never become a registered number
reaching a deliverable.** Gate U4 reads at native resolution inside the property
clip, which is a far smaller problem.

### Headline distributions — FPC, exact, mosaic extent

| | 2009 `m5` | 2021 `d4` | 2021 `d5` |
|---|---:|---:|---:|
| valid px | 21,697,920 | 12,907,440 | 12,822,218 |
| mean FPC | 3.494 | 6.482 | **1.582** |
| % FPC = 0 | 80.30 | 69.66 | **91.09** |
| 90th pct | 13 | 27 | 0 |

The `d5` half of the 2021 capture is markedly less vegetated than the `d4` half.
This is a second, independent reason the v1 preview's +1.16 pp mean gain must not be
quoted: it compared the whole 2009 mosaic against **only the more vegetated half** of
2021. Cross-check on the 2009 figure: GDAL's own sidecar records
`STATISTICS_MEAN = 3.49506` at skipfactor 10 against our exact 3.4937.

---

## 4 · Four data defects that will bite later — none blocking

**D-U1 · The 2009 height products carry physically impossible values.** Every 2009
height percentile `bb8`–`bbe` maxes near **317–318 m** above ground, and `bb1`
(maximum return height) reaches 281.9 m. Black box tops out around 25 m. These are
unfiltered noise returns — birds, cloud, or range artefacts. 2021 `d4` maxes at
43–69 m, high but far less extreme. **Any height statistic must be screened before
use**, and the screen must be pre-registered, not tuned.

**D-U2 · The 2009 return classification carries no class information.** `bb4` in 2009
is **single-valued (1) everywhere it is valid**, while 2021 `d4` carries classes 3–9.
So `bb4` cannot be used to screen D-U1 at the 2009 epoch — the spec's note that
"`bb4` is available to screen if needed" holds for 2021 only. Screening 2009 must be
done on height thresholds or on `bb5` return density instead.

**D-U3 · The `d5` delivery uses an undeclared fill value of 254.** `bb3` and `bb4` in
`d5` run 1–254 with 254 dominant (`bb4` median 254, mean 211.5), while the same
products in 2009 and `d4` are cleanly single-valued or a small class set. Declared
nodata is 255. **254 would be read as data by any naive consumer.** The `d5` `bb3`
and `bb4` legends are unconfirmed and must not be used until this is resolved —
one line to Adrian alongside the vertical datum.

**D-U4 · Delivered products contain NaN and gross negative artefacts.**
`bbmd5` (2021 CSM) holds **79,596 non-finite pixels, 0.0496% of the sample**, inside
a float32 band whose declared nodata is −999 — so NaN is not the declared nodata and
propagates silently through any mean or percentile. `bbmd4`'s minimum is
**−1065.59 m** on a canopy surface model. The inventory now excludes non-finite
values and counts them; the negative artefacts need a floor at Gate U1.

None of these blocks Gate U1. All four are logged.

---

## 5 · U0.5 — checksums

`sha256_first50()` — SHA-256 of the first 50 MB in 1 MB chunks — plus file size in
bytes, for all 47 files, in the inventory CSV. This is the project's one convention;
the spec's v1 wording "SHA-256 for each" is superseded by v1.1 change 6.

**Stated limitation:** on a 26.9 GB file, a first-50-MB digest detects
**replacement, not corruption**. That is acceptable here precisely because these are
read-only inputs we never write. File size is stored alongside as a second,
independent tripwire.

## 6 · U0.6 — capture dates · **absent**

Searched: every non-GeoTIFF file in the delivery, and the TIFF tag block of all 47
rasters for any key or value matching date/time/acquisition/flight/capture/survey.

**Nothing found.** The 14 `.aux.xml` files are GDAL PAM sidecars containing
histograms and `STATISTICS_*` only — no provider metadata — and their filesystem
timestamps (23–29 July 2026) post-date the rasters, so they were generated locally
when someone opened the files, not shipped by JRSRP. There is no readme, no delivery
note, no project report, no XML metadata record.

**Flight month is unrecoverable from the delivery and becomes a question to Adrian**,
alongside the vertical datum. Per the spec, we do not gate on the answer. Trap T-3
therefore stands at year resolution: 2009 sits at the end of the Millennium Drought,
2021 follows the 2016 and 2020–21 floods, and Gate U2 conditions on water years
rather than months.

**One piece of vertical-datum evidence, offered as evidence and not as an answer.**
The `bb0` elevation ranges are 2009 55.74–84.81 m (mean 69.89), 2021 `d4`
57.94–87.26 m (mean 67.24), 2021 `d5` 65.40–85.74 m (mean 73.59). At this latitude
the AusGeoid separation is roughly +21 m, so ellipsoidal heights would sit near
77–108 m. The observed band is consistent with **orthometric (AHD-like)** heights at
all three. This does **not** settle which AusGeoid model, and it is not a datum
offset estimate — the three cover different ground, so the mean differences above
are geography, not datum. The stable-ground vertical offset is computed at Gate U3
item 5, on common ground, and nowhere else.

---

## 7 · U0.7 — product → question mapping

| Question | Primary | Secondary / check | Status |
|---|---|---|---|
| **U-Q1** Bala 29ca | `bbd` 95th-pct height (5 m), `bbh` FPC (10 m), both epochs | `bbb`/`bbc` percentiles; `bbm` CSM at 50 cm | **Fully served.** Runs on structure *and* cover |
| **U-Q2** Refugia concordance | `bbd` 95th-pct height (5 m) for the pre-registered [1.0, 3.0) m shrub class | `bbh`; sensitivity at [0.5, 2.0) and [1.5, 4.0) | **Fully served** |
| **U-Q3** Change and earthworks | `bb0` DEM at 50 cm, both epochs; `bbh` and height change | `bb1`, `bbm`; `bb5` density for sensor-effort context | **Served**, gated on the Gate U3 vertical offset |

**No question is unanswerable for want of a product.** The v1 STOP condition — *if
only `bbh` is present, ask Adrian for `bbn`* — does not fire, and v1.1 already voids it.

`bbn` (CHM) is absent at all three folders and is not needed: `bbd` at 5 m is the
primary height instrument and `bbm` the fine-detail check, per v1.1's own ordering.
Note that ordering is now doubly justified — `bbm` is not vegetation-filtered
(fences, powerlines, vehicles are in it) **and** it carries the D-U4 artefacts.

`bbi` (hillshade) is a visualisation derivative of `bb0` and serves no question;
it is inventoried but will not be reprojected at Gate U1.

---

## 8 · For the issues log

| Id | Item | Triage: does it change a number reaching a deliverable? |
|---|---|---|
| U-I1 | `read_registered_layer()` is mandated by CLAUDE.md and referenced in three script headers and four docs, but **is not defined anywhere in the repo**. Its three checks (resolve path from `spatial_layer_asset`, assert CRS, compare field list) were implemented inline in `U0_1_partner_decision.py` | No — but the convention is currently unenforceable. IMPROVE |
| U-I2 | `register_taskM_gateC_assets.py` uses `INSERT OR IGNORE`; Task U uses `INSERT OR REPLACE` throughout per v1.1 | No. IMPROVE, do not stop (v1.1 instruction) |
| U-I3 | Registered `field_list` for `gayini_boundary_8058` is `OBJECTID,Block,SHAPE_Leng,SHAPE_Area`; the file also carries `fid` and `geom`. The registered list is the attribute set, the file list includes the GPKG primary key and geometry column | No — the difference is structural, not a data mismatch. Note the convention |
| U-I4 | D-U1 to D-U4 above | Potentially yes at Gate U4. Each has a named mitigation |

---

## 9 · Acceptance criteria touched at this gate

- [x] 2021 partner settled on on-property coverage, rule stated, intersection named — **but the answer is a third branch and needs sign-off**
- [x] All **47** (not 54) files decoded against QVF, stage codes in plain English
- [x] Exact headers for all 47; exact distributions for the 10 m and 5 m tiers; decimation factor recorded — **nominal and realised** — and those rows marked `recon_only`
- [x] Checksums via `sha256_first50()` with file size, limitation stated
- [x] Capture-date metadata searched; result reported: **absent**
- [ ] EPSG:7854 and 7855 added to the CRS register — Gate U1, at registration
- [x] No existing table or view modified or dropped

---

## STOP — what is being asked

1. **Confirm the union.** `d4 ∪ d5` as the 2021 partner, and **85,882.6 ha** as the
   both-valid on-property denominator for Task U. This is a third branch of the U0.1
   rule; the spec's two branches both fail.
2. **Note the two spec-header corrections** — 47 GeoTIFFs, and the sidecars are not empty.
3. **Two one-line questions to Adrian**, neither gating: what vertical datum is each
   `bb0` in, and what are the flight months? Add a third: what is `254` in the `d5`
   `bb3`/`bb4` bands (D-U3)?
4. **Acknowledge D-U1** — 318 m "vegetation heights" in 2009 with no usable `bb4`
   class field to screen them. A pre-registered height screen is needed **before**
   U-Q1 computes anything, since U-Q1 now leans on height.
