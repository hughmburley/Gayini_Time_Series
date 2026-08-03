# AUD-1 — Output folder audit and pack reconciliation

**Owner:** RS / CC · **Effort:** 4 h · **Target:** 2 Aug · **Blocks:** ADR-1, QA-2b, DECK-1
**Type:** READ-ONLY AUDIT. No builds, no rebuilds, no re-renders, no registry writes.

---

## Why this exists

Three inventories of the same work now disagree with each other:

- `Output/` on the workstation — what actually exists
- the DB registries (`figure_asset`, `report_asset`, `raster_asset`, `census_asset`) — what is provenance-tracked
- `Gayini_Adrian_pack_contents.xlsx` Contents sheet — what a client is told exists

Four confirmed disagreements are listed in §2. There are almost certainly more, because nothing has ever reconciled all three. QA-2b (render and caption audit, 5 Aug) assumes a known file list as its input; **it cannot start until this audit produces one.**

The second purpose is render currency. Ten headline numbers changed under the pinning work, and `floor_flood` constants were re-registered at 6 dp on 31 July. Any figure rendered *before* the constant it displays was last changed may show a superseded number while looking entirely correct. That class of defect is invisible to a file-existence check and is the one most likely to reach a client.

**Not in scope:** fixing anything. This task produces a reconciliation table and a ranked defect list. Repairs are separate tasks, prioritised after the list exists.

---

## Gate A — Inventory the three sources (read-only) · **STOP**

### A1 · Disk

Walk `Output/` recursively. For every file record: path, filename, extension, bytes, mtime, and SHA-256 (first 50 MB, house convention). Do not open or modify anything.

Report the directory tree with file counts and total size per subdirectory, against `Gayini_output_structure.md`. **Flag any directory not described in that document, and any directory the document describes that does not exist.** The structure doc has not been touched since 25 July and is a currency suspect in its own right.

### A2 · Registries

From the DB, pull every row of `figure_asset`, `report_asset`, `raster_asset`, `census_asset`. Record: asset id, path, product/type, registration timestamp, `path_exists` as stored, and any checksum held.

Then **re-test `path_exists` live**. The stored flag is a historical assertion, not a current fact. Report stored-vs-live disagreements separately — a row that flipped from 1 to 0 means something moved or was deleted after registration.

### A3 · The pack and the tracker

Parse `Gayini_Adrian_pack_contents.xlsx` (Contents sheet: ID, Item, File, Status) and `Gayini_path_to_Aug10_tracker_2.xlsx` (Tasks sheet: ID, Task, Status).

Extract every filename referenced in either. Note that some pack `File` cells hold prose rather than a path (`"T11 — pending"`, `"in T13_D1 (right panel)"`, `"limitations register"`). Resolve these by hand where possible and list the unresolvable ones — an item whose file cannot be identified cannot be shipped or QA'd.

**STOP.** Report the three inventories with counts before any reconciliation.

---

## Gate B — Reconcile into one table

Produce `Output/audit/AUD1_reconciliation.csv`, one row per distinct artefact, with a category:

| Cat | Meaning | Action implied |
|---|---|---|
| **A** | On disk + registered + in pack | Ship — passes to QA-2b |
| **B** | On disk + registered, not in pack | **Candidate pack addition — the answer to "what do we already have"** |
| **C** | In pack, missing from disk or unregistered | **CRITICAL — the pack asserts something untrue** |
| **D** | On disk, not registered | Provenance gap; unregistered figures cannot ship (REP-6) |
| **E** | Registered, missing from disk | Broken pointer |
| **F** | Duplicate or near-duplicate | Which is current? |
| **G** | Render-currency suspect | See Gate C |

Columns: `artefact_id`, `path`, `filename`, `category`, `bytes`, `mtime`, `sha256`, `registered` (Y/N), `registry_table`, `registration_ts`, `path_exists_stored`, `path_exists_live`, `in_adrian_pack` (Y/N), `pack_item_id`, `pack_status_claimed`, `tracker_status`, `defect_note`.

### Duplicate detection (category F)

Group by filename stem after stripping trailing version and date tokens (`_v2`, `_v3`, `_20260731`, `_final`, `_data`, `_slide`, `_a3_landscape`). Within each group report every variant with its mtime and size.

Two known live cases to resolve explicitly, because both have shipped in something:

- `T6_A_three_arm_grid.png` vs `T6_A_three_arm_deck.png` — pack item F6 names `_grid`. What is `_deck`, and is it superseded?
- `D1_paddock_Bala_29ca_slide_data.png` vs `D1_paddock_Bala_29ca_a3_landscape_data.png` — same content, two page geometries, or divergent?

**Do not delete anything.** Report only.

---

## Gate C — Render currency (the subtle defect class) · **STOP**

For every figure and report in categories A, B and D, test whether the render predates the numbers it displays.

1. Establish `last_constant_change_ts` — the most recent registration or update timestamp among the constants, views or tables the artefact depends on. Where dependency is not recorded, use the most recent change to any registered constant in the same family (`floor_flood`, the classification thresholds, the regression constants from REG-1/REG-2) and mark the row `dependency_inferred = Y`.
2. Flag category **G** where `mtime < last_constant_change_ts`.
3. Rank G rows by exposure: **in the Adrian pack first**, then report-stream figures, then everything else.

Specific checks that must appear by name in the report:

- Every artefact rendered before the **31 July `floor_flood` precision correction**. Constants were re-registered at 6 dp; anything rendered earlier may display a rounded or superseded value.
- Every artefact touching any of the **ten headline numbers that changed under the pins**. Cross-reference the pinned-number registry (`How_we_know` sheet reports 68 numbers registered, 10 changed).
- Every artefact predating the **QA-2a render assertion guard** (`R/gayini_assert_rendered.R`, 31 July). Renders before that date were produced without the guard and have never been machine-checked for unrendered placeholders.

**STOP.** The ranked G list is the highest-value output of this task. Report before proceeding.

---

## Gate D — Pack gap report

A short markdown report, `Output/audit/AUD1_pack_gap_report.md`:

1. **Category C list** — every pack claim that is not true on disk, one line each, most exposed first.
2. **Category B list** — existing, registered artefacts *not* currently in the pack, grouped by what they show, with a one-line note on whether each is worth adding. This is the "what do we already have" answer.
3. **Category G list** — ranked render-currency suspects.
4. **Unresolvable pack references** — items whose `File` cell cannot be mapped to a real path.
5. **Structure-doc drift** — directories present but undocumented, or documented but absent.

No recommendations on what to build. This task reports state; sequencing decisions happen in the design seat.

---

## Known disagreements to verify, not assume

These four are already identified from the workbooks alone. Confirm each against disk and registry — do not take either workbook's word:

| Item | Pack Contents says | Tracker says | Verify |
|---|---|---|---|
| T1 (conserved paddocks table) | pending / NEEDS BUILDING | DONE 31 Jul | Which is true on disk? |
| F3 (gap year by year) | pending / DATA EXISTS | DONE 31 Jul | " |
| F5 (cover vs water, 64 paddocks) | pending / DATA EXISTS | DONE 31 Jul | " |
| M5 (cover and water side by side) | "T11 — pending" / SPECIFIED | T11 v2 DONE, **plus M5b** | M5b appears in no pack row — does the file exist? |

Also confirm: **M3** (`T2_B2_duration_map.png`, marked REBUILD PENDING) depends on T7, which the tracker names *first to drop*. Report whether the current file on disk is shippable as-is, because if T7 drops, that file either ships or M3 leaves the pack.

And: pack item **D1** names `Gayini_reference_state_methods.md` as EXISTS. It is **absent from the Claude project copy**. Confirm whether it exists on the workstation. If it does, the project sync is incomplete; if it does not, the pack references a methods document that was never written — which would be the single most serious category C defect in the pack.

---

## Acceptance criteria

- [ ] Every file under `Output/` appears exactly once in the reconciliation table
- [ ] Every registry row appears, with live `path_exists` re-tested
- [ ] Every pack Contents row mapped to a path or listed as unresolvable
- [ ] Categories A–G assigned to every row, none blank
- [ ] The four known disagreements each resolved with evidence
- [ ] D1 methods-document question answered
- [ ] Ranked category G list produced
- [ ] **Nothing modified, deleted, moved, re-rendered or re-registered.** Audit outputs are the only new files.
- [ ] Re-run produces an identical reconciliation table apart from timestamps

---

## Standing rules

Read-only · additive only if anything were to be written, which it is not · **never re-run the builder** · paths resolved from the DB, never hardcoded · four-CRS discipline not relevant here but do not reproject anything · change report to `docs/change_reports/` · no AI attribution in commits.

## Note on identifiers

This task is **AUD-1**, deliberately in the tracker's `ADR-/REP-/BIO-/QA-` namespace and not the `T-` namespace. `T1`, `T2` and `T3` currently each denote at least three different things across the project (build specs, Adrian pack items, and figure filename prefixes). Do not use bare `T`-numbers in this task's outputs — always qualify as `pack item T1`, `figure prefix T1_`, or `spec T1`.
