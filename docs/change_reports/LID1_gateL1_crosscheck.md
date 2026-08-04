# LID-1 Gate L1 — §11 cross-check of the Task U summary

**Date:** 4 August 2026 · **Read-only.** `mode=ro` + `PRAGMA query_only=1`.
**Probe open = close:** `dim_headline_number` 101 · `figure_asset` 297 · `raster_asset` 191 ·
`table_asset` 5 · `report_asset` 60 · `spatial_layer_asset` 9. DB mtime unchanged. **No write.**
**Supersedes §0 of `LID1_gateL1_verification.md`** — the summary was absent when I searched and is
present now; that blocker is void and everything else in that report stands.

**Executed as written.** No number in the summary was edited. Recomputation used a separate code
path from the design seat's: `rasterio` directly against the 20 registered rasters, and `pandas`
against the Task U tables, all of which are present on disk (20/20 rasters, 18 tables, the 178 GiB
delivery).

---

## 1 · Discrepancy table

**Five discrepancies. One is material and has propagated into five documents.**

| # | claim | this document | the artefact | verdict |
|---|---|---|---|---|
| **D1** | §5 F7 · property-median `bb5` density at 2021 | **1.4855** | **1.4672** — `taskU_gateU1_r2_density_diagnostic.csv` row `epoch=2021` | **DIFFER — stale pre-U-I11 value** |
| **D2** | §2 · GiB by folder | **88.9 / 61.4 / 27.5** | **86.83 / 60.42 / 30.75** — `taskU_gateU0_inventory.csv`, confirmed independently against the filesystem | **DIFFER on all three** |
| **D3** | §9 · *"`legend_status` unconfirmed on FPC and height"* | implies **14** | **16** — both `bb0` DEM rows are unconfirmed too | **DIFFER** |
| **D4** | §8 C4 · *"U-Q4a, bridging note"*, 65.7% | landed there | correction landed in `TaskU_gateU4a_and_U3_7_report.md` §184-190; **no document named "bridging note" exists**, and **65.7% appears in no committed artefact** | **PARTLY — value correct, provenance absent** |
| **D5** | §5 F2 · *"988,829 non-treed pixels"* | **988,829** | **988,831** — standing non-treed scope, `census_by_zone_stratum` | **DIFFER by 2 px** |

### D1 in full — the one that matters

`TaskU_gateU1_report.md` line 180 records 2021 as *median 1.4855, 0 excluded, **20,468,719** kept.*
The live artefact records *median **1.4672**, 1 excluded, **34,343,805** kept.*

**The kept-pixel count is the U-I11 signature.** 20,468,719 × 0.0025 ha = **51,171.8 ha** — §8's own
*"2021 height coverage of 51,167 ha — the `d4`-only figure"*, the number that surfaced the bug.
34,343,805 × 0.0025 = **85,859.5 ha**, post-fix. **1.4855 was computed on `d4`-only 2021 data and
was never refreshed after the re-run.**

It has propagated to five documents: `TaskU_gateU1_report.md` (×2), `TaskU_gateU3_report.md`,
`TaskU_gateU2_response_to_CC.md`, `TaskU_lidar_structural_lens_v1.2.md` amendment log, and this
summary.

**The qualitative claim survives and the number does not.** 1.0622 → 1.4672 is **+38.1%**, still
*"~40% more returns per unit area"*, and U3.6's conclusion — no derivable correction — is untouched
because U3.6 regresses on block density differences, not on this median. **§8's blast-radius
statement is the reason this was missed:** *"only the 5 m height rows moved"* is true, and the R2
density diagnostic **is** a 5 m row. It moved, and the prose that quoted it did not.

**Recommendation: correct to 1.4672 in all five, and record that the U-I11 blast-radius sweep
checked rasters and not the prose derived from them.** That is I-40's shape once more — the re-run
happened, the propagation did not.

---

## 2 · [DS-V] — recomputed independently. **Nine of nine agree, most of them exactly**

Per §11 item 2 a difference would be a stop. **There is none.**

| claim | document | my recomputation | source |
|---|---|---|---|
| Task U both-valid | 8,588,260 px → **85,882.6 ha** | 8,588,260 px → **85,882.6 ha** | `bbh_fpc_{2009,2021}_8058_10m.tif`, `~mask` intersection |
| F1 woody extent | **11,449.25 ha = 13.3313%** | **11,449.25 ha = 13.3313%** | same two rasters, FPC > 0 either epoch |
| co-registration | **r = 0.897298** at (0,0), peak at (0,0) | **0.897298**, peak (0,0); one-pixel shift costs 0.107–0.115 | `taskU_gateU1_coregistration.csv`, all 25 offsets |
| seam on-property | **1,486.33 ha** @10 m · **1,482.69 ha** @5 m | 148,633 px × 0.01 = **1,486.33** · 593,077 × 0.0025 = **1,482.69** | the two seam masks |
| coverage post-U-I11 | 2009 **85,880** · 2021 **85,855 ha** | **85,880.2** · **85,854.6 ha**, identical across all six height stages | the twelve 5 m height rasters |
| F3 zonal p90, six values | 0.00 / 0.04 (41st) · 0.62 (83rd) / 0.96 (77th) · 0.40 (61st) / 0.79 (58th) | **all six exact**; ranks 41.2 / 82.9 / 77.1 / 61.4 / 57.9 | `taskU_gateU4a_zonal_structure.csv` |
| zero-inflation (C4) | **65.7% of 35** | **23 of 35 = 65.7%** | same |
| F5 floor and observed | **9.659 pp** vs **+0.2569 pp**, factor 38 | 9.6587 vs 0.2569, **37.6×** | `taskU_gateU3_facts.csv` |
| F6 offset | median **+0.3032**, MAD **0.0243**, n **12,397** | exact, all three | `taskU_gateU3_stable_ground.csv` row 47 |
| U-I14 three areas | **39.7 / 39.75 / 39.6 ha**; Inland **2,016.3 ha**, +0.59, 84th/91st | 636 px → 39.65 · 15,900 → 39.75 · 3,960 → 39.60; Inland `bbd` **2,016.31**, residual **+0.5861**, **84.2nd / 91.2nd** | R6 table + U4a table |

---

## 3 · [CC] — verified against the committed report and the `Output/` table. **All agree**

| claim | source row |
|---|---|
| §5 F2 — three community fits: slopes 0.2585 / 0.5133 / 0.5303, r 0.189 / 0.457 / 0.659, residual SD 12.34 / 12.06 / 10.64, n 77,544 / 193,658 / 717,627 | `taskU_R6_bala_floor_flood_placement.csv`, `kind = fit`, all twelve exact |
| §5 F2 — 29ca residuals **+1.57 / +9.61 / +1.15**, *"all well under 1 SD"* | same, `zone_name = Bala 29ca`: 1.5668 / 9.6111 / 1.1457 at **0.127 / 0.797 / 0.108 SD** |
| §5 F6 — U3.7: blocks 0.0925 (3.8×) · `d4`→`d5` 0.0443, n = 137 (1.8×) · tilt 0.1345 over 29.3 km, R² 0.4064 (5.5×) | `taskU_U3_7_offset_uniformity.csv`; R² 0.406404 and extent 29.33 km in the `linear_trend` note |
| §5 F7 — U3.6 R² **0.0120** / **0.000088**, slopes of opposite sign | `taskU_gateU3_density_scaling.csv`: 0.011986 / 0.000088, +0.010241 / −0.040887 |
| §4 — R2 exclusions 218 px / 0.545 ha and 1 px / 0.0025 ha | `taskU_gateU1_r2_screen.csv`, `is_primary = 1` |
| §7 — 2009 farm floor **30.87 or 51.71**; 2021 gauge **3,505 or 15,290 ML/day**; worst case percentile **0.0 vs 100.0** | `taskU_gateU2_epoch_context.csv`: 30.8745 / 51.7124 (20.8 pp), 3,504.68 / 15,290.20 (**4.36×**), gauge ranks 0.0 and 100.0 |
| §2 — **61 files = 47 GeoTIFFs + 14 sidecars**, **178.0 GiB / 191.1 GB**, folders 16 / 16 / 15 | `taskU_gateU0_inventory.csv` **and** the filesystem, independently. **Only the GiB split differs — D2** |

---

## 4 · [DB] — verified live. **Agree, with one wording defect**

- **`raster_asset`: 20 rows at `run_id = taskU_gateU1`** ✓ — `bbh` ×2, six height stages ×2, `bb0`
  ×2, 2 seam masks, 2 R2 exclusion masks. Exactly as §9 states.
- **Row contents are as claimed and better than claimed:** checksum + `file_bytes`, `source_crs`,
  `epoch_label`, `stage_code`, resolution, extent, and a plain-English `legend_semantics` — the
  `bbh` row does carry *"not comparable to Landsat total_veg"*. ✓
- **`dim_headline_number`: 2 Task U rows** ✓ — 85,882.6 and 67,268.002. **The 10 further rows were
  ruled and are not inserted** (L1-2, unchanged). Not inserted here.
- **`figure_asset`: 2** ✓.
- **`legend_status` — D3.** §9 says *"unconfirmed on FPC and height."* **16 of 20 are unconfirmed:
  2 FPC + 12 height + 2 `bb0` DEM.** The four `confirmed` are the seam and R2 masks.

---

## 5 · §8 — did each correction land?

| id | verdict |
|---|---|
| **C1** 318 m is not "something tall was there" | **LANDED** — `TaskU_gateU1_report.md` §5 |
| **C2** S2 ~42% of the compared set, not independent | **LANDED** — `TaskU_gateU3_report.md` §4(b) |
| **C3** 13.33% promoted to a finding | **LANDED** — `TaskU_gateU3_report.md` §3 |
| **C4** Riverine 2009 zero-inflation caveat | **PARTLY — D4.** The caveat landed in `TaskU_gateU4a_and_U3_7_report.md` (*"a rank in a heavily zero-inflated distribution"*, *"a tie at zero rather than a deficit"*). **The named location "bridging note" does not exist** — the only document containing that phrase is this summary. **65.7% is in no committed artefact.** I recomputed it as 23/35 and it is correct; it has no home |
| **C6** +0.303 m withdrawn as a scalar calibration | **LANDED** — `TaskU_gateU3_report.md` §6 |
| **C7** U-I11 log entry leads with the diagnosis | **LANDED** — issues log |
| **U-I14** two instruments on one 40 ha fragment | **OUTSTANDING IN BOTH, as expected.** Both stream documents still read *"Two independent products…"*, uncorrected |

---

## 6 · §3 — the pinned rules are quoted correctly

R1 (`d4` precedence, never average, seam as a mask) · R2 (50 m ceiling, sensitivity 30/50/80) ·
R3 (`bbd` ∈ [1.0, 3.0) m, sensitivity [0.5,2.0)/[1.5,4.0)) · R5 (coverage ≥ 0.99) · R6 · U3.6 ·
U3.7 — **each matches `TaskU_lidar_structural_lens_v1.2.md` and its amendment log**, and **R3 and R5
are correctly recorded as pinned-but-unexercised**.

**The three denominators are quoted correctly**, and Census ∩ LiDAR is correctly [CC]-only in the
document while being [DB]-registered at 67,268.002 — worth upgrading its tag to [DB].

---

## 7 · §11 item 7 — numbers with no committed source

Two, both correct on recomputation and neither locatable in an artefact:

1. **65.7%** (C4 / F3 zero-inflation) — see D4.
2. **~9 m regional fall** and **~30 km apart** in F4 — sourced to *"a timeboxed prose-only DEM
   inspection, no metric, no derived surface, nothing registered"*, which the document itself says.
   **Correctly self-declared, so not a defect** — recorded so it is not mistaken for a measurement.

---

## 8 · Observations that are not discrepancies

- **22.7 ha vs 28.2 ha.** The spec's 22.7 is the gap to the 2021 `d4 ∪ d5` extent (85,888.3 ha); the
  summary's 28.2 is the gap to both-valid (85,882.6 ha). **Different quantities, both correct.**
  Recorded so neither is "fixed" into the other.
- **F6's n is 12,397 at Gate U3 and 11,706 at U3.7**, whose note says *"recomputed at U3.7, identical
  definition"*. **A 5.6% different sample for a definition called identical.** Median and MAD agree
  to four decimals, so nothing downstream moves — but the word "identical" is doing work it has not
  earned.
- **The R6 fit universe is 988,829 px; the paddock-part universe is 795,600 px.** Different scopes,
  correctly so — the fits use all non-treed country, the parts only zoned land. Worth one line in any
  methods text, since a reader will meet both.

---

## STOP — end of Gate L1

**The work verifies.** Nine of nine [DS-V] claims reproduce independently, most to the last decimal;
every [CC] tag traces to a named row; the DB matches. That is a better result than any document in
this project has returned on a first cross-check.

**Design seat's, before L2:**

1. **D1 — the 1.4672 correction across five documents**, plus the note that the U-I11 sweep checked
   rasters and not the prose.
2. **D2 — the folder GiB split.**
3. **D3 — the `HOLD` consequence.** 16 of 20 unconfirmed means, on the rule as written, four mask
   layers reach `DATA_HANDOVER` and everything of interest is `HOLD`. Confirm or amend before I
   classify.
4. **D4/D5** — the missing "bridging note" and the 988,829 / 988,831 two-pixel difference.
5. **Rule 2 remediation** in the two stream documents, still outstanding from the previous report.
