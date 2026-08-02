# AUD-1 · Gate D — Pack gap report

**Task:** AUD-1 · read-only audit of `Output/`, pack reconciliation, manifest emission
**Spec:** `docs/reports/AUD1_v2_output_audit_and_manifest.md`
**Source of truth for pack contents:** `docs/reference_update/Gayini_deliverables_register.md` v2 (31 Jul)

**Audit window:** `audit_started_utc = 2026-08-01T03:42:25Z` → `audit_finished_utc = 2026-08-01T07:20:20Z`
Gate A disk/registry snapshot taken at `2026-08-01T03:44:10Z`.

Nothing was modified, deleted, moved, re-rendered or re-registered. SQLite opened `mode=ro` with
`PRAGMA query_only=1`. No git index operations. The five files in `Output/audit/` are the only new
files.

**State is reported, not repaired. There are no recommendations here about what to build or ship.**

Companion artefacts:

| File | Rows | What it is |
|---|---:|---|
| `AUD1_gateA_inventory.md` | — | the Gate A inventory report |
| `AUD1_gateA_disk.csv` | 2,679 | raw disk walk of `Output/`, hashed |
| `AUD1_gateA_registry.csv` | 541 | all registry rows, live `path_exists` re-tested |
| `AUD1_reconciliation.csv` | 3,167 | one row per artefact, categories A–H |
| `AUD1_pack_manifest_draft.csv` | 535 | **PACK-1's direct input** |

Reconciliation totals: **A 13 · B 519 · C 3 · D 2,625 · E 7**, with **G** on 88 rows,
**H** on 50 and **F** on 1,953. No row has a blank category.
Manifest: **SHIP 4 · HOLD 77 · DECIDE 454**.

---

## 1. Category C — register v2 claims that are untrue on disk

**Three claims. One is severe.**

### C-1 · Item T3 "What we do not know" — the limitations register does not exist

Register v2 lists **T3 · all claims · EXISTS (limitations register)** with the caption *"Every
limitation, what it means, and whether it can be fixed. Written so a reader can judge for themselves
how far to trust each result."*

**There is no limitations register in this repository, in any format, and git has never tracked one.**

Verified four ways: no `*limitation*.xls*` anywhere; `git ls-files` returns only three files; `git log
--all --diff-filter=A` shows those three as the only limitations files ever added; and the only
matches on disk are three **un-merged fragments** — `Gayini_limitations_register_additions_{T2,T6,T12}.md`
— which CLAUDE.md itself describes as *"staged and pending merge to v11"*. CLAUDE.md separately
asserts *"current: v10"*. **No v10 exists in the repo.**

This is the worst defect available under the spec's own ranking: a client-facing document asserting
something untrue, and specifically the item whose entire job is to tell a Nari Nari reader how far to
trust the rest of the pack. It serves *all* claims.

*Bounding the claim honestly:* this audit can only see the repository. If a v10 workbook exists in
project knowledge or elsewhere on the workstation, it is outside what this seat can verify. What is
established is that it is **not in the repo and has never been committed**.

### C-2 · Item T2 "The recovering and declining parts" — exists, unregistered

`Output/tables/T13_gateC_classification.csv` (22,196 B, 2026-07-30T07:52:16Z) is on disk and is the
right file. It appears in **no registry** — `figure_asset`, `report_asset`, `raster_asset`,
`census_asset` and `spatial_layer_asset` all return zero. Register v2 marks it EXISTS. Unregistered
artefacts cannot ship under REP-6.

### C-3 · Item T1 table component — exists, unregistered

Register v2 classes **T1 as a Table** and names `T1_conserved_paddock_comparison`. Two artefacts
carry that stem:

| Path | Bytes | Registered |
|---|---:|---|
| `Output/figures/T1_conserved_paddock_comparison.png` | 127,619 | yes (`adrian_pack_20260731`) |
| `Output/tables/T1_conserved_paddock_comparison.csv` | 760 | **no** |

The registered artefact is the **figure**; the **table** the register names is unregistered.
Surfaced to the manifest as two rows — the `.png` as SHIP, the `.csv` as HOLD. **Not resolved here.**

---

## 2. Category B — registered artefacts the register does not know about

**519 rows.** This is the "what do we already have that we have forgotten about" answer.

| Group | Count | Note |
|---|---:|---|
| **Old-generation figures** (MODIS / MER / gauge / RS_coverage, `db_build_20260701_114458`) | 143 | the generation the structure doc flagged for archiving; still registered, still present |
| Rasters (registered products) | 128 | census percentiles, flood zone, inundation stacks |
| Dashboards D1 / D2 / D3 | 78 | site 57, paddock 21, stratum 3 |
| **T12 DEA source rasters** (`Input/landsat_landcover/level3/LLC3_*.tif`) | 39 | **prohibited** in any client deliverable (CLAUDE.md); HOLD, never DECIDE |
| Live `Output/figures` (ladder + misc) | 35 | F1–F7 concept/data pairs, S-series, C1, H2/H6 |
| Reports | 34 | |
| TaskU LiDAR | 21 | provisional, `qa_status = REVIEW` |
| Diagnostics figures | 9 | |
| Other | 32 | incl. 5 machine-pinned absolute paths |

**The registry still tracks the wrong generation.** The structure doc's central finding holds and has
not moved: 143 old-generation figures remain registered while **154 live `Output/figures` files are
unregistered** (Category D). The inversion it described in July is intact.

**Five registry rows are pinned to one machine** (structure doc C12), including one pointing outside
this repository entirely:

```
D:\Github_repos\Gayini\Input\shapefiles.zip                                    (×4)
D:\Github_repos\Murrumbidgee_Gauge_Workflow\Output\database\gayini_murrumbidgee_gauges.sqlite
```

---

## 3. Category G — render-currency suspects, ranked

**88 suspects. Seven are register-v2 pack items — the highest-exposure defect class in this audit.**

The test used an **event calendar against file `mtime`**, not dependency resolution, because
dependency is unrecorded (see §8). `dependency_inferred = Y` on every G row.

| Event | UTC | Evidence |
|---|---|---|
| **T8 Gate A pins — ten headline numbers changed** | 2026-07-28 | `T8_before_after.csv`, 10 rows |
| T13 Gate D (M4, M4b) | 2026-07-30T08:20Z | commit 38e2598 |
| **QA-2a render assertion guard** | 2026-07-31T06:19:45Z | `R/gayini_assert_rendered.R` mtime |
| **`floor_flood` constants re-registered at 6 dp** | 2026-07-31T08:54:58Z | `floor_flood_precision_correction.md` |

The ten changed numbers are recorded exactly in
`Output/review_bundles/reference_state_T8_headline_number/outputs/T8_before_after.csv` — this is an
authoritative list, not an inference.

### Tier 0 — register-v2 pack items (7)

**Group A — rendered *before* the 28 July pins. Large value changes.**

| Item | File | mtime | Numbers that moved under it |
|---|---|---|---|
| **F6** | `T6_A_three_arm_grid.png` | 2026-07-27T09:50:28Z | `three_arm_floor_deficit_{not_grazed,unzoned_inferred,unzoned_plot}` −4.8 / 4.3 / 5.9 → **−0.92 / 1.17 / 1.32** |
| **F1** | `T2_E_paddock_trajectories.png` | 2026-07-27T06:43:10Z | `ref_grazed_floor_*` and `ref_grazed_mean_cover_*` |
| **F2** | `T2_E_paddock_trajectories_mean.png` | 2026-07-27T06:43:10Z | as F1 |
| **F4** | `T2_F_gap_decomposition.png` | 2026-07-27T06:43:12Z | as F1 |

**F6 is the most exposed artefact in the pack.** It was rendered the day before the three-arm
deficits changed, and they did not change slightly — the magnitudes fall by roughly 75–80%, and the
figure's register caption makes a directional claim ("*They sit at or above it in six of nine
comparisons*") that depends on them.

The `ref_grazed` family changes include a **sign flip**: `ref_grazed_mean_cover_riverine` −0.8 → **+1.41**,
and `ref_grazed_floor_aeolian` −19.6 → **−10.46**.

**Group B — rendered 62 seconds before the `floor_flood` precision correction.**

| Item | File | mtime | Gap to event |
|---|---|---|---|
| **M5** | `M5_dual_grain_floor_and_flood.png` | 2026-07-31T08:53:54Z | −64 s |
| **M5b** | `M5b_paddock_residual_from_expectation.png` | 2026-07-31T08:53:54Z | −64 s |
| **F5** | `F5_cover_vs_water_64_paddocks.png` | 2026-07-31T08:53:56Z | −62 s |

These three were rendered **after** the T11 v2 Gate C correction that established the constants
(commit 24e073e, 08:44Z) but **before** the commit that re-registered them at 6 dp (7162d2d, 08:55Z).
The commit message calls it *"precision correction, not a value change"* (0.547837594 → 0.547838),
so the display-level risk is low — **but F5 draws the expectation line and M5b draws the residual
from it, and neither has been machine-verified against the registered constants.** A 62-second gap is
not evidence of correctness; it is evidence that nobody has checked. This is exactly what QA-2b must
resolve by reading the drawn numbers.

### Tiers 1–4

| Tier | Count | Content |
|---|---:|---|
| 1 · live `Output/figures`, non-archive | 12 | `S_veg_water_{gam,qband}_p05/p50`, `S_veg_water_percentile_fan`, `T6_B_three_arm_mean`, `T6_A_three_arm_deck` |
| 2 · tables / reports | 12 | |
| 3 · other | 10 | |
| 4 · archive / review bundles | 47 | |

### Named check — the five-period trajectory (PIN 3) **has reappeared**

The spec requires flagging any artefact still displaying the five-period trajectory, whose
`pinned_value` is NULL and which was removed from the template: *"its reappearance anywhere is a
regression."*

**It has reappeared in register v2 itself — in claim 1, the pack's opening sentence.**

> `Gayini_deliverables_register.md:16-17` — *"**Three of the four conserved paddocks are
> indistinguishable from grazed ground** across thirty-five years — within **1.5 to 3.3 percentage
> points**."*

That range is `ref_grazed_floor_gap_3pdk_periodwise`:

```
number_id     ref_grazed_floor_gap_3pdk_periodwise
pinned_value  NULL          spread_min/max  NULL / NULL
period_label  1988-92/93-2002/2003-12/2013-18/2019-22      <- five periods
caveat        deck reports -1.5..-3.3 across the 5 periods (mean_of_seasons).
```

The number is **deliberately unpinned**, and the register's single most prominent claim rests on it.
**No pinned substitute exists** for the same quantity: the nearest pinned row,
`ref_grazed_floor_gap_4pdk_1988_92` = −13.07, is four paddocks over one period — a different
quantity, not a drop-in. The claim currently has no pinned source.

The same range propagates to the stale workbook's `Start_here` and `By_question` sheets.

### Named check — DEA cultivation language: **PASS**

No artefact or caption named by register v2 describes DEA cultivation calls as cultivated at any
confidence. The only occurrences are internal: the T12 change reports, the T12 limitations additions,
and the `tier2_T12_dea_landcover` review bundle. Register v2 is clean on this. The 39 DEA source
rasters and `fact_dea_cultivation_assessment.csv` carry the prohibition in their `defect_note` and are
HOLD in the manifest.

### Render guard coverage

**3,049 artefacts predate QA-2a** (`R/gayini_assert_rendered.R`, 2026-07-31T06:19:45Z) and have
**never been machine-checked for unrendered placeholders** — including **7 of the 16 register items**:

```
M1  2026-07-26T06:01:08Z    F1  2026-07-27T06:43:10Z    F2  2026-07-27T06:43:10Z
M3  2026-07-27T06:43:11Z    F4  2026-07-27T06:43:12Z    M2  2026-07-27T06:45:27Z
F6  2026-07-27T09:50:28Z
```

This is reported **separately from the constants test**, as instructed. M1, M2 and M3 are not G
suspects — no number they display has changed — but they are equally unchecked by the guard.

---

## 4. Category H — internal apparatus

**50 artefacts** matched the register v2 §5 machinery: `dim_headline_number` exports, the reproduction
test (`test_T8_headline_reproduction.py`), the pin-decision documents, `REG1`/`REG2` build scripts and
tables, the intercept spread correction, denominator tables, `gayini_assert_rendered.R`, and the
number-provenance audit.

**No H artefact is named by register v2. The §5 discipline is holding.** All 50 are HOLD in the
manifest.

**One near-miss, and it is the stale workbook's doing.** `Gayini_reference_state_methods.md` is
Category H — confirmed at Gate A on three independent lines (the workbook's own column says
*"Technical; not required to read the pack"* and *"Section 9 lists every headline number with…"*;
register v2 §5 rules that machinery internal; CLAUDE.md records its §7 community deficits as
predating the T8 pins). **The stale workbook names it as pack item D1 with status EXISTS.** Had PACK-1
been built from the workbook, the pack would have shipped its own scaffolding carrying pre-pin
numbers. Register v2 dropping it is correct.

It also exists as **two divergent unregistered copies**:

| Path | Bytes | mtime | SHA-256 |
|---|---:|---|---|
| `docs/reference_update/Gayini_reference_state_methods.md` | 22,944 | 2026-07-29T04:10Z | `a781de6c9c9253f0…` |
| `docs/Spec_audit/Gayini_reference_state_methods.md` | 14,989 | 2026-07-28T00:33Z | `78a4090d0640c023…` |

---

## 5. Item-set diff, and the true item count

**Register v2 lists 16 items** — 6 maps (M1, M2, M3, M4, M5, M5b), 7 figures (F1–F7), 3 tables
(T1, T2, T3).

§6 states *"One item of eighteen is not built"* and *"the pack ships with seventeen items"*.
**Both numbers are wrong.** The stale workbook lists exactly 18 (the 16, plus M4b, D1, D2, minus M5b).
The register dropped three items and added one, then **carried the workbook's total forward without
recounting**.

**Correct: 16 listed. 15 if M3 does not land.** This must be corrected before PACK-1 generates a
contents page, or the error reaches a client cover.

**Sharper still: 16 items resolve to 14 distinct files.** F7 is not a separate artefact — the register
defines it as *"right panel of `T13_D1`"*, the same file as M4. T3 has no file at all. PACK-1 should
expect 14 files for 16 items, not 16.

| Diff | Items | Status |
|---|---|---|
| In stale workbook, absent from register v2 | **M4b, D1, D2** | confirmed |
| In register v2, absent from workbook | **M5b** | confirmed |

**M4b — absorbed, not dropped.** `T13_D2_part_state_map_sensitivity.png` exists and is registered
(`T13_gateD_20260730`, live `path_exists = 1`). Register v2 folds sensitivity into M4's caption via
hatching; the workbook describes M4b as a *different* graphic — *"redrawn at a looser and stricter
cut… Hatching and the core outline are omitted"*. Two renderings of sensitivity, one still on disk.
Category B, DECIDE.

**D1 — internal apparatus.** See §4.

**D2** — `docs/reference_update/Gayini_questions_for_Adrian_20260729.md` exists, unregistered. The
tracker records the questions document as sent to Adrian on 31 July.

Both D-items live in `docs/`, outside `Output/`.

**The 74 / 76 count is not a defect.** Register v2 §5 asserts `dim_headline_number` = 74; live is 76.
The two extras are TaskU's, added today. **74 was correct on 31 July.** The workbook's "sixty-eight"
*is* stale.

---

## 6. Structure-doc drift — an abandoned reorganisation

`docs/Gayini_output_structure.md` (25 Jul) is not merely stale. **The migration it specifies was never
performed**, and it is simultaneously the standing rule for where new outputs go.

| Its claim | Live |
|---|---|
| 1,326 files · 1.57 GB | **2,679 files · 16.04 GB** |
| "BROKEN POINTERS 0 — `path_exists = TRUE` is honest" | **7 broken** |
| "Nothing lands at `figures/` root" (rule 3, acceptance 4) | **144 files at root** |
| Target dirs `figures/{ladder,site,paddock,stratum}`, `rasters/{inundation,veg,zones,intermediate}` | **none exist** |
| `_archive/{figures_modis_mer,rasters_pre_post,review_bundles_tier1}` | **none exist** |

**Undocumented but present:** `csv/`, `reports/`, `packages/`, `scratch_parity/`, `rasters/task_U/`,
`rasters/MER/`, `figures/{dashboards,maps,plots,report_figures,review,review_deck,review_refresh,Land_use,_archive}`,
`census/{_tmp,summaries}`, ~18 `diagnostics/` subdirectories.

**The newest work is the least compliant** — six of the seven newest pack items sit at `figures/` root,
the one location the doc forbids.

### A correction to the Gate A framing

Gate A reported that registered assets live under two roots. **More precisely: repo-root `figures/`
does not exist on disk at all.** Git tracks exactly 7 files there — all deleted in the working tree,
and all 7 are the broken pointers below. There is one live artefact root (`Output/`) plus `docs/` for
two named pack items. **PACK-1 has nothing to scan at repo-root `figures/`.**

---

## 7. Category E — broken pointers

**7 rows, all `figure_asset`, all stored `path_exists = 1` against live 0.**

```
figures/diagnostics/T12_DEA_persistence_fraction_full_1988_2025.png   T12_gateC
figures/diagnostics/T12_DEA_persistence_fraction_pilot_8yr.png        T12_gateC
figures/diagnostics/T12_DEA_farm_ctv_vs_flood_veg_1988_2025.png       T12_gateC
figures/diagnostics/T12_DEA_positive_control.png                      T12_gateC
figures/diagnostics/T12_DEA_sensor_era_gap.png                        T12_close
figures/diagnostics/T12_DEA_persistence_map.png                       T12_close
figures/diagnostics/T12_DEA_class_snapshots.png                       T12_close
```

These are the **T12 DEA documented negative** — recorded false positives that CLAUDE.md forbids in any
client deliverable. **The deletion is correct behaviour. The defect is that the registry still asserts
them present**, and `path_exists` is a stored historical assertion that cannot notice being wrong.
They show as deleted-unstaged in `git status`; nothing was touched here.

---

## 8. The provenance gap that weakens Category G

**No registry carries a `registration_ts` column.** Dating depends on `run_id` joined to
`workflow_run`, which holds **11 run_ids** against **31 in use**.

**114 registry rows have no derivable registration timestamp**, including every one of the newest pack
items — `adrian_pack_20260731` (F3, F5, pack item T1), `T11_v2_20260731` (M5, M5b),
`T13_gateD_20260730` (M4, M4b).

Every Category G verdict therefore rests on **file mtime against an event calendar**, with
`dependency_inferred = Y`. Where an artefact is undatable and predates nothing testable,
`render_currency = UNKNOWN` rather than CURRENT — 50 rows — which routes them to DECIDE.

**Nobody downstream should mistake this inference for provenance.** A figure whose mtime post-dates an
event has not been *verified* against it; it has merely not been *excluded*.

---

## 9. Duplicates (F) — 1,953 rows, 785 groups

**596 groups byte-identical, 189 divergent.** Most duplication is the review-bundle convention working
as designed (a bundle must be self-contained when zipped). The three cases the spec named:

**`T6_A_three_arm_grid` vs `T6_A_three_arm_deck` — two deliberate renderings, not a version conflict.**
Different files (440,145 B vs 275,233 B, different SHA-256), written one second apart in the same run
(2026-07-27T09:50:28Z / :29Z). `_grid` is register v2's F6; `_deck` is a deck-format variant of the
same content. Both are registered under `T6_gateE`. Both are G suspects (both predate the 28 July
pins). Three byte-identical copies of each exist across `figures/diagnostics/` and two review bundles.

**`D1_paddock_Bala_29ca_slide_data` vs `_a3_landscape_data` — two geometries, both archived.**
14 files, 6 distinct SHA-256. The divergence is **page geometry** (A3 landscape vs slide), not content
drift, and every `a3_landscape` variant sits under an `_archive/` path
(`Output/figures/_archive/taskL_pre_rollout_20260722/` and `Output/_archive/review_bundles/…`). The
live artefact is `Output/figures/dashboards/D1_paddock_Bala_29ca_slide_data.{png,pdf}`.

**`T2_B2_duration_map` — one file, three byte-identical copies, but not the specified product.**
Single SHA-256 (`8362c9d69c…`, 158,127 B, 2026-07-27T06:43:11Z). It is a valid image and is
registered. **It is not shippable as M3 as-is:** register v2 marks M3 **SPECIFIED**, pending the T7
recolour and vectorisation, and T7 is unstarted and named first-to-drop in the tracker. The file is
also guard-unchecked. Manifest verdict: **DECIDE**, not SHIP.

---

## 10. Concurrency summary

**Window:** 03:42:25Z → 07:20:20Z. **Gate A snapshot:** 03:44:10Z.

TaskU wrote inside the window and was observed directly, not inferred:

| Probe | `raster_asset` | `figure_asset` |
|---|---|---|
| 03:42:53Z | 184 | 285 |
| 03:43:36Z | **186** | 285 |
| **Gate D re-probe 07:13Z** | 186 | **286** |

The Gate D re-probe — added at the design seat's instruction — **caught a second advance a
single-point check would have missed**: TaskU progressed to **Gate U2** after the Gate A snapshot,
registering one figure (`Output/figures/task_U/U2_epoch_context_35yr.png`) and writing three tables.
Those four files are in the reconciliation, flagged, and excluded from the manifest.

**Rows flagged `concurrent_write = Y`: 35** — 31 TaskU-region rows plus the 4 post-snapshot arrivals.
This exceeds the spec's ~10 threshold and is flagged as required.

**A re-run was not recommended and the design seat agreed.** The contamination is confined to a single
`run_id` (`taskU_gateU1`/`U2`), in `Output/rasters/task_U/`, `Output/figures/task_U/` and
`Output/tables/taskU_*`. **No pack item, no Category A/C/G row and no register-v2 claim is affected.**
The run carries `qa_status = REVIEW` and is unshippable regardless. All TaskU rows are HOLD.

**The audit window is still open at the time of writing.** TaskU has further gates. Any consumer of
these artefacts should re-probe before treating the TaskU region as settled.

---

## 11. What the manifest says

`AUD1_pack_manifest_draft.csv` — **535 rows: SHIP 4, HOLD 77, DECIDE 454.** `ship_flag` was set
mechanically from the evidence; **no editorial judgement was applied about what belongs in the pack.**

| Item | Flag | Why |
|---|---|---|
| M1, M2, F3, T1 (png) | **SHIP** | A · CURRENT · registered · EXISTS · caption present |
| M3 | DECIDE | register status is SPECIFIED, not EXISTS — needs the T7 recolour |
| M4 / F7 | DECIDE | one file serves two items; render CURRENT |
| F1, F2, F4, F6 | HOLD | G — rendered before the 28 Jul pins |
| M5, M5b, F5 | HOLD | G — rendered 62 s before the `floor_flood` correction |
| T1 (csv), T2 | HOLD | C — named by the register, unregistered |
| T3 | HOLD | C — **no file exists** |
| 454 others | DECIDE | B candidates — the design seat's call |

**Only 4 of 16 register items clear every mechanical test.** Ten of the remaining twelve are held on
evidence recorded in this report; two are DECIDE.
