# STATUS-1 — focus report

**Date:** 3 August 2026 · **Type:** read-only delta · **Baseline:** `Output/audit/AUD1_gateA_disk.csv` (2026-08-01T03:42Z, 2,679 rows)
**Seven days to 10 August.** Sunday 9 Aug is contingency, so ~6 working days.

**Concurrency notice.** `Gayini_Results.sqlite` was written *during* this session (mtime 2026-08-03T14:16:50). Two read-only probes ten minutes apart returned `dim_headline_number` 88 then 98, and `table_asset` 2 then 4. Another session holds the DB. Counts below are the later probe. Nothing was written by this task.

---

## 1 · Delta since AUD-1

Current tree: 2,729 files under `Output/`. **51 added · 1 removed · 16 modified.**

| direction | count | where |
|---|---|---|
| added | 51 | `tables` 18 · `rasters/persistence_8058` 11 · `figures/diagnostics` 10 · `audit` 7 · `figures/task_U` 2 · `pack` 2 · `rasters/fc_intermediate` 1 |
| removed | 1 | `Gayini_path_to_Aug10_tracker_1.xlsx` (superseded by `_2`) |
| modified | 16 | `rasters/task_U` 8 · `tables` 4 · `figures/diagnostics` 3 · `database` 1 |

The three modified diagnostics are `T6_A_three_arm_grid`, `T6_A_three_arm_deck`, `T6_B_three_arm_mean` — the REM-1 defect fix, expected. The additions are T3 Gates A–E and Task U.

**Registry, now vs AUD-1:**

| table | AUD-1 | now | Δ |
|---|---|---|---|
| `figure_asset` | 285 | 297 | +12 |
| `raster_asset` | 186 | 191 | +5 |
| `report_asset` | 59 | 59 | — |
| `spatial_layer_asset` | 9 | 9 | — |
| `census_asset` | 2 | 2 | — |
| `table_asset` | 2 (REM-1) | 4 | +2 |
| `dim_headline_number` | 88 | **98** | **+10** |

Schema now 93 tables / 35 views. `dim_headline_number` has 3 rows with `pinned_value` NULL.

**`path_exists` disagreements — one new, seven rows.** All 7 are `figure_asset` rows for T12 DEA diagnostics deleted from the tree in commit `fd2aedb` ("registry rows deliberately left"). They still carry `path_exists = 1` while the files are gone. Every other registry resolves cleanly on disk (191 / 59 / 9 / 2 / 4 all present).

---

## 2 · PACK-1 status

**`Output/pack/` exists but holds no pack.** Two files only:

- `PACK1_input_manifest_FROZEN.csv` — byte-identical to `AUD1_pack_manifest_draft.csv`
- `PACK1_input_delta_FROZEN.csv`

Against the checklist: **0 of 14 files packaged** · no `00_START_HERE.md` · no packaged checksums to compare · **the 454 `DECIDE` rows are unresolved** (frozen manifest is 535 rows: 4 SHIP, 77 HOLD, 454 DECIDE — unchanged from the draft).

All fourteen source files do exist on disk — verified individually. Nothing is missing upstream; only the assembly is absent.

**Where the lane got to:** inputs frozen, then RPT-SCOPE R2 built the final pin list (14 rows) and **4 rows hit the spec §6 STOP, so the write was held** (`c9dd748`). PACK-1 is stopped at a deliberate gate awaiting a ruling, not stalled.

**Contamination check on `Gayini_Adrian_pack_contents.xlsx`:**

1. **Still in `Output/` root — yes**, where an assembly step could pick it up. It is also **open in Excel right now** (`~$Gayini_Adrian_pack_contents.xlsx` lock file present), so it may be being edited concurrently.
2. **Anything it asserts in the assembled pack — no**, because no pack is assembled.
3. **Files it names copied where they should not be — no.** `Gayini_reference_state_methods.md` exists at exactly one path, `docs/reference_update/`. It has not been copied toward a client location.

Its stale claims are confirmed as AUD-1 described: M3 REBUILD PENDING, M5 SPECIFIED, F3/F5 DATA EXISTS, T1 NEEDS BUILDING (four built items shown pending); lists M4b/D1/D2; does not know M5b; names `Gayini_reference_state_methods.md` as client item D1.

**Tracker still carries the wrong total.** README row 4: *"17 of 18 pack items now exist."* Register v3 corrected this to **sixteen items resolving to fourteen files**. Not fixed.

---

## 3 · Tracker reconciliation

Tracker v3 was rebuilt 31 July evening; five commits have landed since.

**Done but not marked done**

- **T7** (P16, NOT STARTED, "first to drop") — **substantially delivered by T3 Gate E.** `T3_persistence_polygons_8058.gpkg` plus 8 persistence rasters and an overlay README are on disk. That is the GeoPackage T7 was to produce.
- The tracker's stated reason for dropping T7 — *"its stated purpose needs T3, which is not built"* — **is now false.** T3 ran through Gate E (`2a7ba15` → `b459f76`). The conclusion still holds, but for the opposite reason: T7 is redundant because T3 built it, not because T3 blocks it.

**Still genuinely outstanding**

ADR-1 (P1, at a held gate) · REP-PAGE4 (P2, BLOCKED) · QA-2b (P3) · T14 (P4) · BIO-X1, BIO-X2 (P5/6) · REP-2, REP-4, REP-5 (P7/8/9) · BIO-1, BIO-2 (P10/11) · REP-6 (P12) · RECON-1 (P13) · DECK-1 (P14) · QA-1 (P15).

REP-2 and REP-4 are marked IN PROGRESS. On disk they are **not started**: no `P_*` or `S_*` figure exists anywhere in the tree, and `Output/reports/Client_Reports/` holds only the two reference drafts (Bala 29ca, GA_036).

**Overtaken or no longer needed**

- T7 (above).
- The "17 of 18" arithmetic in the tracker README and the judgement-call row that depends on T3 being unbuilt.

---

## 4 · The gaps that matter, ranked by exposure

**1 · T3 "What we do not know" — the file does not exist, in any format.** Unchanged since AUD-1 finding C-1. Git has never tracked a limitations register; the v10 xlsx (43 rows) is gitignored and lives only in project knowledge. What exists on disk is three **un-merged** staging fragments — `Gayini_limitations_register_additions_{T2,T6,T12}.md` — and **none of them covers the reference-state work the pack is about.** Register v3 §3 tells a reader this item EXISTS. Exposure is maximal: a named deliverable that cannot be opened, on the one item whose job is to say how far to trust everything else.

**2 · The report batch — 0 of 25 built, and the scope is stated two different ways.** No parameterisation layer, no figures, two reference drafts. Worse, the target is ambiguous: CLAUDE.md says **57 site + 21 paddock = 78**; the handoff and tracker say **4 paddock + 21 site (REP-4) then 60 grazed paddock (REP-5) = 85**. These are different deliverables and nobody has ruled between them. This is the contract item.

**3 · QA-2b — not started, and its method is known broken.** The timestamp screen produced six false positives out of seven and missed the one real defect (114 registry rows have no derivable registration timestamp). Scheduled 5 August against a pack that does not yet exist.

**4 · The stale workbook is live in `Output/` root and currently open in Excel.** Low effort to neutralise, non-trivial exposure while an assembly step is pending.

**5 · Seven `figure_asset` rows assert `path_exists = 1` for deleted files.** Small, but it is exactly the class of defect the project's provenance discipline exists to catch.

---

## 5 · Recommended focus

**Six working days. The schedule does not fit and should be cut now rather than at the end.**

| # | do this | why it matters | cost |
|---|---|---|---|
| 1 | **REP-2 then REP-4** — parameterisation layer, then the 25 documents. Rule the 78-vs-85 scope question *first*. | The contract deliverable, at zero. Nothing else on this list ships a client document. | 3–4 d, and it needs REP-PAGE4 unblocked |
| 2 | **Write T3 as Markdown in the repo. Do not chase the gitignored v10.** Merge the three existing fragments, add the reference-state rows. | Closes the only pack item a reader is promised and cannot open. It is also the honest home for the "what we cannot say" material register v3 §1 already drafts. | 0.5 d |
| 3 | **Resolve the 4 held pins, then assemble PACK-1.** All 14 files exist; the blocker is a ruling plus 454 `DECIDE` rows. | This is what Adrian actually receives on the 10th. | 0.5 d after the ruling |
| 4 | **QA-2b, narrowed** to items built *before* the render guard existed — anything newer asserts itself. Drop the timestamp screen; it has a 6-of-7 false-positive rate. | Every caption in register v3 was written before the item it describes was finished. | 0.5 d narrowed, vs 1 d as scoped |
| 5 | **Retire the stale workbook and the 7 dead registry rows** in whatever commit touches `Output/` next. | Cheap, and removes a live contamination path. | <1 h |

**Drop, and say so out loud:**

- **REP-5 — the 60 grazed paddock reports.** Sixty documents at P9 targeted 7 August, when the builder that makes them is unwritten and REP-4's 25 have not started. This cannot happen. Ship the 25 well; offer the 60 as a post-deadline batch.
- **T7.** Already delivered by T3 Gate E. Remove it from the board rather than leaving it as a decision still to be taken.
- **DECK-1 (reference-state deck v4)**, and **BIO-2 / RECON-1**. Adrian review material and biodiversity-deck reconciliation — neither reaches Nari Nari or BCT by the 10th. T14 is the one analysis item worth protecting only if REP page 4 is otherwise wrong.

**The judgement in one line:** the pack is close and the reports are not. Everything above ranks the reports first, and the three items that make the pack honest — T3, the pins, a narrowed QA-2b — second. The rest should go.
