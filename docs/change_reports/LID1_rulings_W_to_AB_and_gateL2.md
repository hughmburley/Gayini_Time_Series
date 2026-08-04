# LID-1 — Rulings W to AB applied · Gate L2 classification

**Date:** 4 August 2026 · **Probe open = close:** `dim_headline_number` 101 · `figure_asset` 297 ·
`raster_asset` 191 · `table_asset` 5 · `report_asset` 60. **No database write.** Gate L2 reads
`mode=ro` + `PRAGMA query_only=1` and writes one CSV.

---

## 1 · Ruling W — Rule 2 remediation

The superseding block is inserted **verbatim**, immediately after each title, in both documents:

- `docs/reference_update/Gayini_LiDAR_implications_for_reference_state.md`
- `docs/LiDAR/TaskU_findings_note.md`

**No section below it was touched.** §3 still reads *"The reference-state anomaly has dissolved"* and
§1 still reads *"no longer needs explaining"* — a retracted conclusion that is still readable is
worth more than one quietly reworded, and a reader now meets the retraction first.

**Logged as I-40's ninth instance, source named as the design seat.**

## 2 · Ruling X — the amended legend rule, and what it changes

Accepted and applied. `legend_status = unconfirmed` means *not checked against the JRSRP
definitions*, not *semantics absent* — and the script asserts the distinction rather than assuming
it: every one of the 20 rows was verified to carry a non-empty `legend_semantics`, a checksum and a
resolved `crs_epsg` before being classified.

**Consequence: `DATA_HANDOVER` goes from 4 mask layers to all 20 rasters** — both FPC, all twelve
height percentiles, both 50 cm DEMs, both seam masks, both R2 exclusion masks.

**The email to Adrian.** 16 semantics strings need confirmation: 2 × `bbh` FPC, 12 × height
percentiles `bb9/bba/bbb/bbc/bbd/bbe` at both epochs, 2 × `bb0` DEM. They are in
`raster_asset.legend_semantics` and can be pulled with one query. The four already confirmed are the
seam and R2 masks.

## 3 · Ruling Y — the five discrepancies

**Y1 — 1.4855 → 1.4672, corrected in all five documents**, each with a visible note naming the cause.
`TaskU_gateU1_report.md`'s 2021 table row also carried the pre-fix counts and is corrected:
*0 / 20,468,719* → **1 / 34,343,805**, with the excluded median 1.3561 restored.

Added to the **U-I11** log entry, as ruled:

> **THE BLAST-RADIUS SWEEP CHECKED RASTERS AND NOT THE PROSE DERIVED FROM THEM.** *"Only the 5 m
> height rows moved"* was true — and the R2 density diagnostic **is** a 5 m row. **A re-run is not
> complete until the sentences that quote its outputs have been re-read.**

**Y2 — folder split corrected** to 86.83 / 60.42 / 30.75 GiB with a visible note. Counts and totals
were already exact.

**Y3 — C4's location corrected** to `TaskU_gateU4a_and_U3_7_report.md` §184-190. **65.7% is
deliberately not registered**, and the row says why.

**Y4 — 988,829 STANDS. It is not a transcription slip, and the ruling's conditional applies.**

`R6_bala_floor_flood_placement.py:128` filters `(comm_code > 0) & np.isfinite(p05) &
np.isfinite(flood)`. Recomputed directly from `veg_regime_class_8058.tif` and
`total_veg_p05_8058.tif` at LID-1:

| | px |
|---|---|
| non-treed scope, codes 11–33 | **988,831** |
| …of which `veg_p05` is non-finite | **2** |
| non-treed **and** `isfinite(p05)` | **988,829** |

**The two pixels are a stated finite-value filter**, an instance of T3-I2's NaN class — not a slip.
Annotated in the summary rather than changed. Which filter, and why, is now on the page.

**Y5 — Census ∩ LiDAR upgraded [CC] → [DB]**, registered at 67,268.002 and verified live.

## 4 · Ruling Z — U-I14 downgraded, still open

The I-14 row now leads with the downgrade and keeps the superseded framing visibly:

> **ONE observation, not two lines agreeing.** The R6 leg is **−17.41 on census p05 against −1.34 on
> `veg_p05_spatial`** — the same collapse, same direction, as the Bala 29ca claim. What remains is
> one structural observation on a 40 ha fragment (**1.9% of the paddock**) plus a residual that
> mostly disappears on the pinned metric.

**Stays OPEN.**

## 5 · Ruling AA — the ten stay unpinned

Logged as I-40's tenth instance. **Not inserted.** The consequence is carried on the affected rows of
the L2 output:

> Every Task U quantity except the two denominators is unpinned and outside
> `test_T8_headline_reproduction.py`. The 13.33% ships as a bounding statement in `METHODS_DOC` and
> **must quote its denominator inline — 11,449.25 ha of 85,882.6 ha both-valid — because there is no
> `number_id` to cite.**

## 6 · Ruling AB — the attribution rule

Added to the issues log's standing rules, in I-40's family:

> **ATTRIBUTING AN ERROR CORRECTLY DOES NOT RESOLVE IT.** An error logged against the design seat is
> still an **open question about the artefact**, not a closed one about the person. **Log the
> attribution AND the recheck.**

With the 13.33% as its worked case, and the reinstatement recorded against I-40's eighth instance.

---

## 7 · Gate L2 — the classification

`Output/tables/LID1_shippability.csv`, from `scripts/14_lidar/LID1_gateL2_shippability.py`.
**55 artefacts, each classified exactly once.**

| | n | |
|---|---|---|
| **`DATA_HANDOVER`** | **20** | every registered raster |
| **`METHODS_DOC`** | **25** | 2 denominators · 2 figures · 15 tables · 5 documents · the GeoPackage absence |
| **`INTERNAL_ONLY`** | **10** | 3 tables · 7 documents |
| **`HOLD`** | **0** | reserved for L1 cross-check failures, and **no artefact failed** — nine of nine [DS-V] reproduced |

**Acceptance, all asserted in code rather than claimed:** every artefact classified exactly once ·
no `DATA_HANDOVER` row without a checksum and a resolved CRS (asserted per row before classification)
· `DATA_HANDOVER` restricted to registered rasters · every row carries a non-empty caveat.

### What travels with what

- **Every raster:** REVIEW status · the two-epoch trap · *LiDAR FPC is not comparable to Landsat
  `total_veg`, must never share an axis with it or be differenced against it*.
- **The 16 unconfirmed:** *semantics stated but unconfirmed against JRSRP — read the semantics string,
  not the band name*.
- **Both DEMs additionally:** *50 cm terrain reveals channels, earthworks and scarring that no Landsat
  product does — **requires Nari Nari review before release***, and *+0.303 m is withdrawn as a scalar
  calibration*.
- **Everything `INTERNAL_ONLY`:** the Rule 2 caveat verbatim.

### The `METHODS_DOC` / `INTERNAL_ONLY` line

Drawn on *method or stated non-result* against *interpretation open*:

- **Methods and non-results ship** — the spec and its seven pinned rules, the three denominators, the
  co-registration pass, the R2 screen, the epoch context and unrecoverable capture dates, **both
  nulls** (U3.6's non-derivable correction, U3.7's non-uniform offset, the two failed stable-ground
  controls), and the 13.33% as a bounding statement.
- **Interpretation open does not** — R6's table, the U-Q4a zonal structure, the Gate U4a report, the
  two stream notes, the summary, and both R6 documents. **F2 and everything downstream of it.**

The one judgement worth flagging: **`taskU_gateU3_facts.csv` is `METHODS_DOC` while
`taskU_gateU4a_zonal_structure.csv` is `INTERNAL_ONLY`**, although both feed findings. The facts table
carries the 13.33% *with its denominator*, which is a bounding statement about scope; the zonal table
carries the structural reading that F3 turns into a reference-state argument. If you disagree, the
zonal table is the row to move.

---

## STOP — end of Gate L2

Gate L3 (methods-doc recommendation) and L4 (handover package) are report-only and not started.
**One item is a governance decision, not a technical one, and it sits above both:** the 50 cm DEMs
require Nari Nari review before anything leaves. It is on the DEM rows now and will lead the L4
recommendation.
