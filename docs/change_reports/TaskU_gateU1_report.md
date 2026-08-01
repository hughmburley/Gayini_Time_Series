# Task U · Gate U1 — Common frame · **DRAFT**

**Spec:** `docs/LiDAR/TaskU_lidar_structural_lens_v1.2.md`, Gate U1
**Date:** 1 August 2026 · **Status:** DRAFT, at the Gate U1 STOP
**Scripts:** `scripts/14_lidar/U1_common_frame.py` (run A) ·
`scripts/14_lidar/U1_register.py` · `scripts/14_lidar/U1b_dem_warp.py` (run B)
**Artefacts:** `Output/rasters/task_U/` (18 rasters) ·
`Output/tables/taskU_gateU1_{facts,coregistration,r2_screen,r2_density_diagnostic,registration_dryrun}.csv`

Additive only. No existing table or view modified or dropped — verified by diffing
`sqlite_master` against a pre-run copy of the database: **125 objects before, 125
after, none dropped, none added beyond the four `raster_asset` columns**, and the
166 pre-existing `raster_asset` rows untouched.

**This report states findings and points at the `Output/` artefacts. It is not the
home of any value.**

---

## 1 · Headline — everything the STOP asks for

| | | |
|---|---|---|
| **Task U both-valid denominator** | **85,882.6 ha** | on-property, 2009 `m5` ∩ (2021 `d4` ∪ `d5`), 10 m, EPSG:8058, 0.01 ha/px |
| **Census ∩ LiDAR denominator** | **67,268.0 ha** | area-weighted, threshold-free, on the 24.970268 m census grid |
| **Co-registration** | **r = 0.8973 at zero offset, peak at (0, 0)** | **PASS** |
| **R2 exclusions** | **2009: 218 px / 0.545 ha · 2021: 0 px / 0.000 ha** | 0.0006% and 0.0000% of the property |
| **R2 STOP conditions** | 1% not triggered · **3× triggered, degenerately** | see §5 — this is the one thing needing a decision |

The both-valid figure **reproduces the Gate U0.1 value exactly** (85,882.6 ha), by an
independent code path on a different grid construction. That is a reproducibility
check, not a coincidence.

---

## 2 · What was warped, and what was not

One warp per source into EPSG:8058, new files, no original mutated. Recorded call:

```
rasterio.warp.reproject(source=rasterio.band(src,1), destination=<ndarray>,
    src_transform, src_crs, src_nodata, dst_transform, dst_crs=EPSG:8058,
    dst_nodata, resampling=<method>)
```

| Product | Res | Method | Files out | Serves |
|---|---|---|---|---|
| `bbh` FPC | 10 m | bilinear | 2 (one per epoch) | all three questions |
| `bb9`/`bba`/`bbb`/`bbc`/`bbd`/`bbe` heights | 5 m | bilinear | 12 | U-Q1, U-Q2 (R3's `bbd`) |
| R1 seam mask | 10 m + 5 m | — | 2 | seam-sensitivity testing |
| R2 exclusion mask | 5 m | — | 2 | audit trail for the screen |
| `bb5` return density | 50 cm → 5 m | average | 0 (diagnostic only) | R2 density diagnostic |
| `bb0` DEM | 50 cm | bilinear | run B, streaming | Gate U3 item 5, U-Q4c |

**Not warped, deliberately:** `bbi` (hillshade — serves no question); `bb3`/`bb4`
(a screening aid only; 2009's carries no class information under D-U2 and `d5`'s is
quarantined under D-U3/R4); `bbm` (secondary check only, carries D-U4, deferred with
`bb0`).

**`bb8` is excluded from the height ladder.** It exists at 2009 and `d4` but **not at
`d5`**. Including it would make the two epochs compositionally different — precisely
the thing a change comparison must not be. The ladder is the six percentiles present
at both epochs across all tiles: 5th, 25th, 50th, 75th, 95th, 99th.

**Run B is split out** because `bb0` is 55 GiB across the three tiles and only Gate U3
item 5 and U-Q4c need it. It produces no numbers and no interpretation, so splitting
it does not carry anything past this STOP. It streams block-by-block through a
`WarpedVRT` — a 50 cm float32 raster over the 859 km² property is 3.4 Gpx, 13.7 GB per
epoch, and cannot be held in memory.

---

## 3 · Areas — mosaic extent and on-property, never rebased against each other

On the EPSG:8058 10 m frame:

| Layer | Mosaic-extent ha | On-property ha |
|---|---:|---:|
| 2009 `bbh` | 216,436.9 | 85,899.8 |
| 2021 `bbh` (R1 mosaic) | 253,076.5 | 85,888.3 |
| **both-valid** | 215,825.5 | **85,882.6** |
| R1 seam (`d4` ∧ `d5`) | 3,633.3 | 1,486.3 |

The property is **85,910.8 ha** — context only, never a statistical denominator here.
Both-valid reaches **99.97%** of it. Per the spec, that is not rounded to "the whole
property"; the **28.2 ha** shortfall is what makes it a measured figure.

**R1 applied as pinned.** `d4` takes precedence throughout the seam, `d5` fills only
where `d4` is absent, and nothing anywhere is averaged. The seam is written out at
both 10 m and 5 m and registered, so any later finding can be tested for seam
sensitivity. Of the 3,633.3 ha seam, **1,486.3 ha falls on-property** — 1.7% of the
Task U denominator, small enough not to dominate anything and large enough to be
worth testing against.

### Census ∩ LiDAR — the third denominator

The census maps **67,349.3 ha** (1,080,157 px). The LiDAR both-valid mask, aggregated
**up** to the census grid by area-weighted mean — never the census interpolated down —
gives:

> **67,268.0 ha**, area-weighted and threshold-free. **99.88%** of what the census maps.

Thresholded counts, recorded as context for pinning U-Q4b's binary rule and **not** as
the denominator: coverage ≥ 0.5 → 1,079,661 px (67,318.4 ha); ≥ 0.99 → 1,074,823 px
(67,016.7 ha); = 1.0 → 1,074,524 px (66,998.1 ha).

The registered value uses no threshold, because a threshold is a tunable and this is a
denominator. **U-Q4b still needs a binary per-census-pixel rule pinned before it
computes a contingency table** — that is a decision, flagged in §7.

Both denominators are registered in `dim_headline_number` as
`taskU_denominator_both_valid_ha` and `taskU_denominator_census_x_lidar_ha`, each
carrying its scope filter, pixel constant, period label, support level and the caveat
that the two are not interchangeable.

---

## 4 · Co-registration — PASS

Pearson r between the epochs' FPC on the on-property both-valid intersection, 2021
shifted against a fixed 2009, in whole 10 m pixels:

| | dx=−2 | dx=−1 | **dx=0** | dx=+1 | dx=+2 |
|---|---:|---:|---:|---:|---:|
| dy=−2 | 0.6140 | 0.6397 | 0.6561 | 0.6414 | 0.6160 |
| dy=−1 | 0.6450 | 0.7209 | 0.7865 | 0.7240 | 0.6466 |
| **dy=0** | 0.6611 | 0.7828 | **0.8973** | 0.7907 | 0.6645 |
| dy=+1 | 0.6441 | 0.7194 | 0.7852 | 0.7240 | 0.6461 |
| dy=+2 | 0.6149 | 0.6405 | 0.6555 | 0.6396 | 0.6139 |

**r peaks at exactly (0, 0)**, the surface is unimodal, and it is near-symmetric in
both axes (dy=−1 and dy=+1 differ by 0.0013; dx=−1 and dx=+1 by 0.0079). A one-pixel
shift in any direction costs ~0.11 of r. There is no sub-pixel bias visible at this
grain. **Gate U3 may proceed.**

Note this r is *not* comparable to the 0.822 in the withdrawn v1 preview: different
partner, different denominator, different frame.

---

## 5 · R2 — the pre-registered height ceiling, and its one STOP condition

Applied at **50 m above ground**, identically at both epochs, ORed across the whole
six-stage height stack, with excluded pixels set to NA across the entire stack for
that epoch. Exclusions reported here **before** any screened data is used.

| Epoch | 30 m | **50 m (primary)** | 80 m |
|---|---:|---:|---:|
| 2009 | 1,690 px · 4.225 ha · 0.0049% | **218 px · 0.545 ha · 0.0006%** | 157 px · 0.393 ha · 0.0005% |
| 2021 | 1,223 px · 3.058 ha · 0.0036% | **0 px · 0.000 ha · 0.0000%** | 0 px · 0.000 ha · 0.0000% |

**The 318 m artefacts found at Gate U0 are almost entirely off-property.** On the
property, the pre-registered ceiling removes **half a hectare** at 2009 and nothing at
2021. D-U1 is real but its footprint inside the analysis area is negligible.

### The STOP condition that fired, and why it is degenerate

> `> 1% of property at either epoch` — **not triggered** (0.0006%, 0.0000%)
> `epochs differ by more than ~3×` — **TRIGGERED**, ratio = ∞

The ratio is infinite because the 2021 denominator is **zero**, not because the epochs
disagree meaningfully. 0.545 ha against 0.000 ha is a difference of half a hectare in
85,910. The condition was written to catch a screen that bites one epoch far harder
than the other — a genuine sensor-asymmetry signal. It cannot distinguish that from
division by zero.

**The sensitivity sweep answers the question the condition was asking.** At the 30 m
ceiling, where both epochs are non-zero, the exclusions are **4.225 ha (2009) against
3.058 ha (2021) — a ratio of 1.38**, entirely unremarkable. The epochs are not
asymmetric; 2021 simply has nothing above 50 m on the property.

I have **not** overridden the condition. It is reported as triggered, the reading above
is offered, and §7 asks you to clear it.

### R2 density diagnostic — a diagnostic, not a second filter

| Epoch | median `bb5` first-return density, excluded | kept | n excluded / kept |
|---|---:|---:|---|
| 2009 | **1.4918** | 1.0622 | 218 / 34,353,234 |
| 2021 | — (none excluded) | 1.4855 | 0 / 20,468,719 |

**The excluded pixels sit on *higher* return density than the ground they were taken
from, not lower.** They are therefore *not* a sparse-return artefact — they are places
the sensor saw well and something genuinely tall was there. 218 pixels at 5 m is 0.545
ha, consistent with a handful of built structures (silo, tank stand, comms mast,
powerline tower). No second filter is applied and none is warranted; R2 stays one
screen, simply stated.

---

## 6 · Registration

18 rasters into `raster_asset` and 2 denominators into `dim_headline_number`,
**`INSERT OR REPLACE` throughout**. `raster_asset` 166 → 184;
`dim_headline_number` 74 → 76.

Four nullable columns added to `raster_asset`: `file_bytes`, `source_crs`,
`epoch_label`, `stage_code`. The spec's acceptance criterion requires every row to
record source CRS and stage code; CLAUDE.md requires qualifiers to be **columns, never
prose**. Storing them in `provenance_note` would have satisfied the letter and broken
the rule.

`legend_status` starts **unconfirmed** on the FPC and height products. The `bbh` rows
carry, verbatim in `legend_semantics`, that LiDAR FPC is **not comparable** to Landsat
`total_veg` and must never share an axis with it or be differenced against it. The
seam and R2 masks are `confirmed` — their legend is a definition, not a measurement.

**Idempotence tested by convergence, not stability** (CLAUDE.md). One registered
checksum was deliberately overwritten with `DELIBERATELY_WRONG`, the registrar re-run,
and the row confirmed to have **moved back to the correct value** with no duplicate
rows (184 before and after). `INSERT OR IGNORE` would have left the wrong value in
place and still passed a stability test — which is the U-I2 failure mode, now
demonstrated rather than asserted.

**CRS register.** There is no CRS register *table* in the database; the register is
CLAUDE.md's four-CRS discipline list. **`CLAUDE.md` has been edited** — one additive
change adding EPSG:7855, noting `d4`'s second use of 7854, and recording that the
LiDAR spans three CRSs with 2021 as two complementary tiles. This is the only edit to
CLAUDE.md in this gate and it is flagged here because editing project memory is not a
routine act.

---

## 7 · STOP — what is being asked

1. **Clear or uphold the R2 3× STOP condition.** It fired on a division by zero
   (0.545 ha vs 0.000 ha). At the 30 m ceiling the same comparison is 1.38×. My
   reading is that the condition's intent — catch a screen biting one epoch far
   harder — is not met, and the gate should clear. **Your call, not mine.**
2. **Confirm the two denominators**: Task U both-valid **85,882.6 ha**, Census ∩ LiDAR
   **67,268.0 ha**. Both are registered and pinned.
3. **Pin U-Q4b's binary coverage rule.** The registered Census ∩ LiDAR denominator is
   threshold-free, but a contingency table needs a per-census-pixel yes/no. The
   candidates and their counts are in §3. This should be pinned **now**, before any
   concordance number exists, for the same reason R2 and R3 were.
4. **Note the CLAUDE.md edit** (§6) and the spec archiving below.

## 8 · Deviations from the spec

**"Delete both" — not done.** v1.2's header instructs deleting v1 and v1.1. CLAUDE.md's
standing rule is **additive-only: move to `_archive/`, never delete** — and v1.2's own
standing rules restate "Additive only". Both superseded specs are in
`docs/archive/LiDAR/` with the three-line header the convention requires, naming what
superseded them and what they are retained for. They are also the provenance chain for
the Gate U0 findings that caused the supersession. **Reporting rather than choosing**,
per CLAUDE.md — say the word and I will delete them.

## 9 · For the issues log

| Id | Item | Triage |
|---|---|---|
| U-I5 | The R2 3× STOP condition divides by zero when one epoch has no exclusions. If this pattern is reused, express it as an absolute-difference-or-ratio test | No number changes. IMPROVE |
| U-I6 | `raster_asset` gained four columns. Any consumer doing `SELECT *` positionally will shift | No — additive nullable columns; no existing consumer found doing this |
| U-I1 | Still open: `read_registered_layer()` remains undefined; its contract is implemented inline in both Gate U1 scripts | IMPROVE |

---

## 10 · Acceptance criteria touched

- [x] EPSG:7854 and 7855 on the CRS register (CLAUDE.md, §6)
- [x] All three denominators computed, registered and named
- [x] R1 applied; seam mask written at 10 m and 5 m and registered; **no averaging anywhere**
- [x] R2 applied identically at both epochs, exclusions reported per epoch **before** use
- [~] R2 STOP conditions honoured — 1% clear; **3× fired and is referred, not overridden**
- [x] Co-registration verified, r reported, shift series **peaks at zero offset**
- [x] `INSERT OR REPLACE` throughout; convergence demonstrated
- [x] No existing table or view modified or dropped — verified against a pre-run copy
- [ ] Re-run produces identical outputs — run A is deterministic and was run twice with
      identical facts; **run B not yet complete**
- [x] Change report in `docs/change_reports/`, committed
