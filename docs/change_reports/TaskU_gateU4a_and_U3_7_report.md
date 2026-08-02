# Task U · U3.7, §1c and U-Q4a — and a mosaic bug of my own · **DRAFT**

**Spec:** `docs/LiDAR/TaskU_lidar_structural_lens_v1.2.md` + amendment log
**Date:** 2 August 2026 · **Status:** DRAFT
**Scripts:** `scripts/14_lidar/U3_7_offset_uniformity.py` ·
`U_1c_bala_dem_visual.R` · `U_1c_bala_dem_zoom.R` · `U4a_bala_structure.py`
**Artefacts:** `Output/tables/taskU_U3_7_offset_uniformity.csv` ·
`Output/tables/taskU_gateU4a_zonal_structure.csv` (354 rows)

R6 is reported separately, in the reference-state stream:
`docs/reference_update/Gayini_R6_bala_floor_flood_placement.md`.

---

## 0 · A bug in my own Gate U1 code · **U-I11** · found, fixed, re-run

**What was wrong.** `valid_of()` decided whether nodata was NaN by testing
`isinstance(nodata, float)`. **`np.float32(np.nan)` is not an instance of Python
`float`** — only `np.float64` is. The NaN branch therefore never fired for the float32
products, the test fell through to `a != nan`, which is **True everywhere**, and
`mosaic_r1()` treated the `d4` tile as valid across the entire grid. **The `d5` tile
contributed nothing to the 5 m height mosaic**, and the 5 m seam mask came out all-ones.

**How it surfaced.** Not from a check — from U-Q4a reporting 2021 height coverage of
**51,167 ha**, which is precisely the `d4`-only on-property figure from Gate U0.1
(51,180.6 ha). A number that matches another number it has no business matching.

**Blast radius, established by re-running rather than by reasoning:**

| Path | nodata convention | Affected? |
|---|---|---|
| 10 m FPC mosaic, all three denominators, co-registration | integer 255 | **No** — re-run reproduces every figure exactly |
| 50 cm DEM mosaic (run B) | explicit `np.isnan` | **No** — different code path |
| Gate U3 FPC verdict, U3.6, DEM offset | 10 m / 50 cm | **No** |
| **5 m height ladder, 2021** | `np.float32(nan)` | **Yes** — was `d4`-only |
| **5 m seam mask** | same | **Yes** — was all-ones |
| Gate U3 height-offset rows | read the 5 m rasters | **Yes** — sample was `d4`-only |
| R2 2021 exclusion count | same | **Yes** — marginally |

**After the fix**, verified by full re-run of `U1_common_frame.py`:

- 2021 `bbd` coverage **51,167 → 85,855 ha** (2009 is 85,880 ha)
- 5 m seam mask **all-ones → 1,483 ha**, which now agrees with the independently-computed
  10 m seam figure of 1,486.3 ha
- Task U both-valid denominator **85,882.6 ha** — unchanged, to the decimal
- Census ∩ LiDAR **67,268.0 ha** — unchanged
- Co-registration **r = 0.8973, peak (0,0)** — unchanged
- R2 at 2021, 50 m ceiling: **0 → 1 pixel (0.003 ha)**; at 30 m, 1,223 → 1,226 px

The R2 STOP condition still fires degenerately (ratio 218 rather than ∞) and the
design-seat clearance of it stands unchanged on the substance.

All 20 Task U rasters re-registered; `raster_asset` stayed at 186 rows with 20 upserted,
which is convergence demonstrated a fourth time.

**Why it is worth this much space.** The failure mode is not "NaN is tricky". It is that
a validity test **silently returned the permissive answer** — everything valid — rather
than erroring. `mosaic_r1` then did exactly what it was told. A test that cannot fail
loudly is the same class of defect as the stored QA verdict in the lineage doc and as
`INSERT OR IGNORE`: it looks like it worked.

---

## 1 · U3.7 — offset uniformity · **FAILS on all three tests**

The design seat's instinct was right, and the check earns its keep.

S1 recomputed at U3.7: n = 11,706, median **+0.3032 m**, MAD **0.0243 m**, p05–p95 spread
**0.1368 m** — reproducing Gate U3 exactly.

| Test | Result | vs pixel MAD (0.0243 m) |
|---|---|---|
| **1 · by 500 m block** | 47 blocks; block-offset median +0.3050 m, SD 0.0337 m, **p05–p95 spread 0.0925 m** | **3.8×** — not uniform |
| **2 · by tile provenance** | `d4`-only +0.3036 m (n 11,569) · `d5`-only **+0.2593 m** (n 137) · **step 0.0443 m** | **1.8×** — exceeds |
| **3 · linear trend** | +0.00267 m/km in x, **−0.00459 m/km in y**, **R² = 0.4064**; largest implied tilt **0.1345 m** over 29.3 km | **5.5×** — exceeds |

**The offset is not spatially uniform, and the structure is systematic, not noise.** A
plane in x and y explains **41% of the variance** in the stable-ground offset. The
implied tilt across the property is 13.5 cm — **nearly half the 30 cm calibration
itself**, and the same order as a real earthwork.

Per U3.7's own pre-registered instruction: **report the structure and stop. No corrected
surface is produced.** None has been.

Two qualifications on the reading:

- The `d4`→`d5` step rests on **137 S1 pixels** on the `d5` side. It is the weakest of
  the three tests and should not carry weight on its own. **No S1 pixels fall inside the
  seam at all**, so the seam itself is untested.
- The tilt is well supported (n = 11,706, R² = 0.41) but it is **not necessarily an
  artefact**. Twelve years including three major flood sequences on an actively
  depositing floodplain could produce real differential elevation change with a regional
  gradient. U3.7 cannot separate a datum tilt from real differential sedimentation —
  which is precisely why a scalar correction would have been wrong either way.

**Consequence for U-Q4c:** a scalar +0.303 m calibration is **not** sufficient. The
obvious remedy is a planar de-trend, and R² = 0.41 says it would help substantially — but
that is a new method decision, it is a design-seat call, and U-Q4c is deferred past
10 August in any case.

---

## 2 · §1c — the Bala DEM visual · prose only, as specified

Timeboxed, no metric, no derived surface, nothing registered. Four observations.

**The four "reference paddocks" are not neighbours.** 29ca sits at the far west, 28ca in
the middle, 26ca and 27ca ~30 km east. They have been compared as though they were a
block; they are strung along the floodplain.

**Absolute elevation cannot be read as flood susceptibility across this extent.** There
is a ~9 m regional fall west to east across the frame. 29ca is the *lowest* ground in
absolute terms and the *least* flooded — because elevation here tells you where you are
along the river, not how high you sit above the local floodplain.

**Engineered linear features are property-wide, not concentrated at 29ca.** The hillshade
shows a dense rectilinear grid of banks, channels and tracks across the whole scene — the
legacy of the Nimmie-Caira irrigation infrastructure. 29ca has them; so does everywhere
else. **I found no ring of banks enclosing 29ca that its neighbours lack.**

**The difference between 29ca and 28ca is in *natural* morphology, and it is striking.**
28ca is finely dissected by a dense anastomosing network of small natural channels across
its whole area. 29ca is comparatively smooth: one large relict meander and lake basin with
natural levees, and substantial featureless flats. That is the morphology of a place with
**fewer distributary channels reaching it** — which is what "hydrologically isolated"
looks like when it is natural rather than engineered.

**Answer to the reframed question — as a visual impression, not a test:** 29ca's isolation
**looks natural.** It comes from position and channel-network density, not from an
enclosing bank. This is consistent with R6 and does not depend on it. If the design seat
wants it turned into a claim, the properly specified test would be channel-network density
per paddock — which is out of scope and would need pre-registering.

*Process note:* the first attempt used a 151-cell focal median for de-trending and burned
50 minutes of CPU on one paddock. It was killed and replaced with an aggregate/resample
boxcar, visually equivalent and seconds to run. The timebox was treated as real.

---

## 3 · U-Q4a — structure at the four Bala paddocks

Per Gate U3, **every epoch is reported separately and nothing is differenced.** Per L-01,
every statistic is decomposed by community. Per-zone coverage fraction accompanies every
figure — and is **99.7–100% for every reference-paddock part**, so comparability is not in
question.

### The medians are degenerate, and that is itself the first finding

**Zonal median `bbd` (95th-percentile height) is 0.00 m in almost every zone × community ×
epoch — reference and grazed alike.** Zonal median FPC is 0.00 everywhere without
exception. The only non-zero medians anywhere are 28ca Inland (0.86 → 1.22 m) and 26ca
Inland 2021 (0.37 m).

This is Gate U3's 13.33% arriving at paddock grain: on non-treed chenopod country **there
is no woody structure at the median.** The spec's instruction to report zonal medians was
right and is honoured — but on this property the median is uninformative, so the zonal
**90th percentile** is reported beside it. Both are in the CSV; neither is substituted for
the other.

### The upper tail — where the signal is

Zonal p90 of `bbd`, metres, against the grazed distribution in the same community
(percentile of the grazed set in brackets):

| Community | epoch | grazed p90 median | 26ca | 27ca | 28ca | **29ca** |
|---|---|---:|---|---|---|---|
| Aeolian | 2009 | 0.00 | — | — | 0.00 (0%) | **0.00 (0%)** |
| | 2021 | 0.21 | — | — | 0.26 (62%) | **0.04 (38%)** |
| Riverine | 2009 | 0.00 | 0.00 (0%) | — | 0.00 (0%) | **0.62 (83%)** |
| | 2021 | 0.38 | 0.00 (0%) | — | 0.22 (40%) | **0.96 (77%)** |
| Inland | 2009 | 0.00 | 1.41 (84%) | 0.06 (61%) | 1.80 (96%) | **0.40 (61%)** |
| | 2021 | 0.30 | 1.72 (91%) | 0.92 (60%) | 3.60 (98%) | **0.79 (58%)** |

### The answer

> **The structural evidence does not support the clearing hypothesis. If anything it
> points mildly against it.**

A cleared-and-regrowing paddock should show **suppressed upper percentiles in 2009**
relative to comparable ground. Bala 29ca shows the opposite or the unremarkable:

- **Riverine — 83rd percentile of the grazed distribution in 2009**, 77th in 2021. More
  woody structure than three-quarters of the grazed paddocks in the same community, at
  the epoch where suppression should be clearest.
- **Inland — 61st percentile in 2009**, 58th in 2021. Middling.
- **Aeolian — 0th in 2009, 38th in 2021**, but the grazed p90 median is 0.00 in 2009, so
  the 2009 percentile is a tie at zero rather than a deficit.

And the inversion R6 found repeats here: **26ca is the structurally poorest of the four in
Riverine — p90 = 0.00, 0th percentile, at both epochs.**

`bbh` disagrees with `bbd` at 29ca Riverine — FPC p90 is 0.00 while `bbd` p90 is
0.62–0.96 m. That is not a contradiction: it is **low shrub, ~0.6–1.0 m, below FPC's
height threshold or too sparse for it.** Exactly the layer FPC misses and the height
percentiles catch, and exactly the layer R3's shrub class targets.

### What U-Q4a can and cannot conclude

**Can:** 29ca is not structurally depleted relative to comparable ground in any community,
at either epoch. Taken with R6 — where 29ca sits on or slightly above the floor-versus-
flood curve in all three communities — **there is no reference-state anomaly left for a
clearing hypothesis to explain.**

**Cannot:** rule out clearing. Chenopod shrubland cleared 60 years ago and never
re-treed would look like chenopod shrubland that was never cleared, at 5 m, in a height
product. The structural test has **low power against old clearing on treeless country**,
and that is a property of the country, not of the method. Ernest's answer would still
say something LiDAR cannot.

**Does not:** make any change claim. No epoch is differenced anywhere in this section.

---

## 4 · For the issues log

| Id | Item | Triage |
|---|---|---|
| **U-I11** | `valid_of()` used `isinstance(nodata, float)`, which is False for `np.float32(nan)`. Silently returned "all valid", so `d5` never entered the 5 m mosaic and the 5 m seam mask was all-ones | **Yes — changed numbers.** Fixed, re-run, blast radius established by re-running. The 10 m and 50 cm paths were unaffected and reproduce exactly |
| U-I12 | `dim_headline_number` grew 76 → 88 between two Task U registrations. Cause identified: `rem1_rerender_20260801` (`register_REM1_three_arm_community_pins.py`) added 12 T6 three-arm rows on 1 Aug from another workstream | No — not Task U, benign, Task U's two rows intact. Recorded so the jump is not re-investigated |
| U-I13 | No S1 stable-ground pixels fall inside the R1 seam, so the seam's own vertical behaviour is untested by U3.7 | Would matter if a planar de-trend is ever built |

## 5 · Status against the design seat's list

1. **U3.7** — done. **Fails**; structure reported; no corrected surface produced.
2. **R6** — done, reported to the reference-state stream.
3. **§1c** — done, prose, timeboxed.
4. **U-Q4a** — done.
5. **Findings note** — next.

**Deferred past 10 August as directed:** U-Q4b, U-Q4c, the Task J L10 question.
