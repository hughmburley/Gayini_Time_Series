# AUD-1 v2 — Output audit, pack reconciliation, and manifest emission

**Owner:** RS / CC · **Effort:** 4 h · **Target:** 2 Aug · **Blocks:** PACK-1, QA-2b, DECK-1
**Type:** READ-ONLY AUDIT. No builds, no re-renders, no registry writes, no file moves.
**Supersedes:** AUD-1 v1. **Re-read this spec in full and echo it verbatim at the start of every gate.**

**Changes in v2:** source-of-truth corrected to `Gayini_deliverables_register.md` v2 (31 Jul); the four v1 "known disagreements" are resolved by that register and become filename verifications instead; Gate D now emits `AUD1_pack_manifest_draft.csv` as PACK-1's direct input; concurrency protocol added (§Concurrency).

---

## Why this exists

Four inventories of the same work disagree:

| Source | Date | Standing |
|---|---|---|
| `Gayini_deliverables_register.md` **v2** | 31 Jul | **Source of truth for pack contents** |
| `Gayini_path_to_Aug10_tracker_2.xlsx` | 31 Jul | Source of truth for scheduling |
| `Gayini_Adrian_pack_contents.xlsx` | ~29 Jul | **STALE — do not treat as authority** |
| `Output/` on disk | live | The only thing that is actually true |

The register v2 already resolves what v1 of this spec listed as open disagreements: F3, F5 and pack-item T1 were built on 31 July and carry real filenames. The audit's job is therefore **not** to adjudicate between workbooks. It is to verify the register's filenames against disk and the registries, and to find what neither document knows about.

Second purpose, unchanged and higher value: **render currency.** Seventy-four numbers are registered and seventy-one reproduce; ten changed under the pins; `floor_flood` constants were re-registered at 6 dp on 31 July; the render assertion guard (`R/gayini_assert_rendered.R`) only landed on 31 July. A figure rendered before the number it displays was last changed will look entirely correct and be wrong. The register says it plainly: *every caption was written before the item it describes was finished, and several describe figures that have since changed.*

**Not in scope:** fixing anything, moving anything, rebuilding anything. This task reports state and emits a manifest.

---

## Concurrency — read before starting

This task may run alongside another CC session (currently TaskU, the LiDAR structural lens). TaskU **writes**: it registers rasters in `raster_asset`, figures via `write_and_register_figure()`, and vectors in `spatial_layer_asset`.

An audit is a point-in-time snapshot. If `Output/` and the registries change during the walk, the reconciliation table is a smear across time and its errors are undetectable afterwards. Therefore:

1. **Record `audit_started_utc` and `audit_finished_utc`** in the report header.
2. Flag any row whose file `mtime` **or** `registration_ts` falls inside that window as `concurrent_write = Y`. These rows are provisional and must be re-checked, not trusted.
3. **Do not `git add`, `git commit`, or touch the index.** If a concurrent session holds `index.lock`, wait — do not remove the lock file.
4. Open SQLite **read-only** (`file:...?mode=ro`). Do not begin a write transaction for any reason, including to test writability.
5. Write audit outputs **only** to `Output/audit/`. Confirm at Gate A that no other running task writes to that path.
6. If more than ~10 rows come back `concurrent_write = Y`, say so prominently and recommend a re-run once the other session finishes. A partly-smeared audit is worse than a late one.

---

## Gate A — Inventory the sources (read-only) · **STOP**

### A1 · Disk

Walk `Output/` recursively. Per file: path, filename, extension, bytes, mtime, SHA-256 (first 50 MB, house convention).

Report the tree with file counts and total size per subdirectory against `Gayini_output_structure.md`, and **flag directories present but undocumented, or documented but absent.** That doc has not been touched since 25 July and is itself a currency suspect.

### A2 · Registries

Pull all rows from `figure_asset`, `report_asset`, `raster_asset`, `census_asset`, `spatial_layer_asset`: asset id, path, product/type, registration timestamp, stored `path_exists`, checksum.

**Re-test `path_exists` live.** The stored flag is a historical assertion. Report stored-vs-live disagreements separately — a 1→0 flip means something moved or was deleted after registration.

### A3 · The register, the tracker, the stale workbook

Parse all three. For `Gayini_deliverables_register.md` v2, extract per item: ID, title, backtick filename, claims served, status.

Verify these filenames exist on disk and are registered — they are the ones the register asserts and the stale workbook does not know:

| Item | Filename asserted by register v2 |
|---|---|
| M4 | `T13_D1_part_state_map_and_scatter` |
| M5 | `M5_dual_grain_floor_and_flood` |
| M5b | `M5b_paddock_residual_from_expectation` |
| F3 | `F3_annual_gap_series` |
| F5 | `F5_cover_vs_water_64_paddocks` |
| pack T1 | `T1_conserved_paddock_comparison` |

Then **diff the item sets**, which differ in membership and not merely in status:

- In the stale workbook, absent from register v2: **M4b, D1, D2**
- In register v2, absent from the workbook: **M5b**
- The register states eighteen items and lists sixteen. Report the true count.

Two specific questions to answer with evidence:

- **D1** — the workbook names `Gayini_reference_state_methods.md` as an EXISTS pack item. Register v2 drops it. Does the file exist on the workstation? If yes, is it a pack item or internal apparatus? If no, the workbook cites a methods document that was never written.
- **M4b** — `T13_D2_part_state_map_sensitivity.png`. Does it exist? Register v2 folds sensitivity into M4's caption, which may mean M4b was absorbed rather than dropped.

**STOP.** Report the inventories and the item-set diff before reconciling.

---

## Gate B — Reconcile into one table

Emit `Output/audit/AUD1_reconciliation.csv`, one row per distinct artefact:

| Cat | Meaning | Implication |
|---|---|---|
| **A** | On disk + registered + named by register v2 | Ships — passes to PACK-1 and QA-2b |
| **B** | On disk + registered, not named by register v2 | **Candidate additions — the "what do we already have" answer** |
| **C** | Named by register v2, missing from disk or unregistered | **CRITICAL — a client-facing document asserts something untrue** |
| **D** | On disk, not registered | Provenance gap; unregistered figures cannot ship (REP-6) |
| **E** | Registered, missing from disk | Broken pointer |
| **F** | Duplicate or near-duplicate | Which is current? |
| **G** | Render-currency suspect | See Gate C |
| **H** | **Internal apparatus** | Must **not** reach the pack — see below |

Columns: `artefact_id`, `path`, `filename`, `category`, `bytes`, `mtime`, `sha256`, `registered`, `registry_table`, `registration_ts`, `path_exists_stored`, `path_exists_live`, `register_item_id`, `register_status`, `tracker_status`, `concurrent_write`, `defect_note`.

### Category H — internal apparatus

Register v2 §5 is explicit that a set of objects exists to make numbers trustworthy and **must not appear in a deliverable**: `dim_headline_number` (74 rows), the reproduction test (71 numbers), the three denominators and dominance counts, ddof conventions, `is_rollup` and the intercept spread correction, the six pin decisions, `assert_state` and the render guards.

Classify any artefact belonging to that machinery as **H**, and flag loudly if an H artefact is currently named by any pack document. A pack that ships its own scaffolding invites exactly the questions the register is trying to keep out of the room.

### Duplicates (F)

Group by filename stem after stripping `_v2`, `_v3`, `_YYYYMMDD`, `_final`, `_data`, `_slide`, `_a3_landscape`. Report every variant with mtime and size. Three known live cases:

- `T6_A_three_arm_grid` vs `T6_A_three_arm_deck` — register v2 F6 names `_grid`. What is `_deck`?
- `D1_paddock_Bala_29ca_slide_data` vs `_a3_landscape_data` — two geometries or divergent content?
- `T2_B2_duration_map` — the M3 source. Register v2 marks M3 **SPECIFIED**, needing the T7 recolour. Is the file on disk shippable as-is?

**Delete nothing. Move nothing.**

---

## Gate C — Render currency · **STOP**

For every artefact in A, B and D, test whether the render predates the numbers it displays.

1. Establish `last_constant_change_ts` — the most recent registration or update among the constants, views and tables the artefact depends on. Where dependency is unrecorded, use the most recent change to any registered constant in the same family and set `dependency_inferred = Y`.
2. Flag **G** where `mtime < last_constant_change_ts`.
3. Rank G by exposure: register-v2 pack items first, then report-stream figures, then everything else.

Named checks that must appear in the report:

- Artefacts rendered before the **31 Jul `floor_flood` precision correction** (constants re-registered at 6 dp).
- Artefacts touching any of the **ten headline numbers that changed under the pins**, cross-referenced to `dim_headline_number`.
- Artefacts predating **QA-2a** (`R/gayini_assert_rendered.R`, 31 Jul) — never machine-checked for unrendered placeholders.
- Any artefact still displaying the **five-period trajectory** (PIN 3, `pinned_value` NULL, removed from the template). Its reappearance anywhere is a regression per the report handoff §7.2.
- Any artefact or caption describing **DEA cultivation calls** as cultivated at any confidence. Recorded false positives; must not appear (report handoff §7.3).

**STOP.** The ranked G list is this task's highest-value output.

---

## Gate D — Emit the manifest and the gap report

### D1 · `Output/audit/AUD1_pack_manifest_draft.csv`

**This file is PACK-1's direct input. No retyping between the two tasks.**

One row per candidate pack artefact, drawn from categories A and B:

`pack_item_id`, `item_title`, `item_type` (map/figure/table/document), `source_path`, `sha256`, `registered`, `register_status`, `claims_served`, `ship_flag` (SHIP / HOLD / DECIDE), `hold_reason`, `render_currency` (CURRENT / SUSPECT / UNKNOWN), `caption_exists` (Y/N), `notes`.

Rules for `ship_flag`:

- **SHIP** — category A, render-currency CURRENT, registered, caption present in register v2.
- **HOLD** — any category C, E, G or H artefact, or any unregistered file. `hold_reason` mandatory.
- **DECIDE** — category B candidates, and anything where the evidence is genuinely ambiguous. Do not resolve these; the design seat does.

Set `ship_flag` mechanically from the evidence. **Do not exercise editorial judgement about what belongs in the pack** — that decision is the design seat's, and a manifest that has already made it silently is worse than one that surfaces the choice.

### D2 · `Output/audit/AUD1_pack_gap_report.md`

1. Category C list — every register-v2 claim untrue on disk, most exposed first.
2. Category B list — existing registered artefacts not in the register, grouped by what they show.
3. Category G ranked list.
4. Category H list, and whether any H artefact is currently pack-named.
5. Item-set diff findings: M4b, D1, D2, M5b, and the sixteen-versus-eighteen count.
6. Structure-doc drift.
7. Concurrency summary: window, and the count of `concurrent_write = Y` rows.

No recommendations on what to build or ship. State reports state.

---

## Acceptance criteria

- [ ] Every file under `Output/` appears exactly once in the reconciliation table
- [ ] Every registry row appears, with live `path_exists` re-tested
- [ ] Every register-v2 item mapped to a path or listed as unresolvable
- [ ] Categories A–H assigned to every row, none blank
- [ ] The six asserted filenames in A3 each verified
- [ ] Item-set diff reported; true item count stated
- [ ] D1 methods-document and M4b questions each answered with evidence
- [ ] Ranked category G list produced
- [ ] `AUD1_pack_manifest_draft.csv` emitted with `ship_flag` on every row
- [ ] `concurrent_write` populated; audit window stated
- [ ] **Nothing modified, deleted, moved, re-rendered or re-registered.** Audit outputs are the only new files.
- [ ] Re-run produces an identical reconciliation table apart from timestamps

---

## Standing rules

Read-only · SQLite opened `mode=ro` · **never re-run the builder** · paths resolved from the DB, never hardcoded · no git index operations · change report to `docs/change_reports/` · commits authored by Hugh, no AI attribution trailers.

## Identifiers

This task is **AUD-1**, in the tracker's `ADR-/REP-/BIO-/QA-` namespace. `T1`, `T2`, `T3` and `T7` each denote several different things across this project — build specs, pack items, figure filename prefixes, and report-stream tasks. Never use a bare `T`-number in this task's outputs. Always qualify: `pack item T1`, `figure prefix T1_`, `spec T1`.
