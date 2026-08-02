# AUD-1 · Gate A — Inventory report

**Task:** AUD-1 (read-only audit of `Output/`, pack reconciliation, manifest emission)
**Spec:** `docs/reports/AUD1_v2_output_audit_and_manifest.md`
**Gate:** A — Inventory the sources · STOP
**Status at time of writing:** Gate A reviewed and accepted by the design seat; TaskU quarantine
approved (PROCEED), audit scope approved for EXTENSION to repo-root `figures/` and `docs/`.

**Audit window:** `audit_started_utc = 2026-08-01T03:42:25Z` → Gate A snapshot closed
`2026-08-01T03:44:10Z`. Window remains open; registries to be re-probed at Gate D.

Nothing was modified, moved, deleted, re-rendered or re-registered. SQLite opened `mode=ro`
with `PRAGMA query_only=1` throughout. No git index operations.

Companion artefacts, written with this report:

- `Output/audit/AUD1_gateA_disk.csv` — the raw disk walk, 2,679 rows (`Output/` only, as taken)
- `Output/audit/AUD1_gateA_registry.csv` — all 541 registry rows with live `path_exists` re-test

---

## Concurrency — a live write was caught, and it is bounded

TaskU wrote **inside** the audit window. This was observed directly, not inferred:

| Probe | `raster_asset` | DB mtime |
|---|---|---|
| 03:42:53Z | **184** | — |
| 03:43:36Z | **186** | 03:43:36Z |
| 03:43:40Z / :44 / :48 | 186 (stable) | 03:43:36Z (stable) |

`taskU_gateU1` went 18 → 20 rasters mid-walk, and added **2 rows to `dim_headline_number`**
(`decided_by = 'spec docs/LiDAR/TaskU_lidar_structural_lens_v1.2.md Gate U1 items 3-4; built by
CC 2026-08-01'`). The DB has since stabilised.

**The smear is bounded and fully identifiable.** Only **2 files** under `Output/` have an mtime
inside the window — `Output/tables/taskU_gateU1_registration_dryrun.csv` and the SQLite itself.
TaskU's 20 raster *files* were written 02:43–02:53Z, **before** the window; only its *registration*
landed inside it. Every affected row carries `run_id = 'taskU_gateU1'` and lives in
`Output/rasters/task_U/` or `Output/tables/taskU_*`.

Rows carrying `concurrent_write = Y`: **24** (20 `raster_asset` + 2 `dim_headline_number` + 2 files).
This exceeds the spec's ~10 threshold and is flagged prominently as required. A re-run was **not**
recommended, because the contamination is confined to a single `run_id` in a directory no pack item
touches, and `taskU_gateU1` is `qa_status = REVIEW` and therefore unshippable regardless.

**Design-seat ruling: PROCEED with quarantine.** The 24 rows are carried with
`concurrent_write = Y`, excluded from the pack manifest, and the region marked provisional.
**Amendment:** the window stays open and TaskU has later gates, so the registries are to be
**re-probed at Gate D** and any rows appearing after the Gate A snapshot flagged. A single-point
concurrency check at the start of a multi-hour task is not sufficient.

`Output/audit/` did not exist and no other task writes there. No `index.lock` at any point.

---

## A1 · Disk

**2,679 files · 16.04 GB** under `Output/`, all hashed (SHA-256 first-50 MB, house convention).

| Top-level | Files | Size |
|---|---:|---:|
| rasters | 295 | 14,971 MB |
| review_bundles | 560 | 317 MB |
| _archive | 495 | 260 MB |
| tables | 83 | 220 MB |
| figures | 685 | 211 MB |
| reports | 120 | 109 MB |
| census / database / csv / spatial_8058 / diagnostics / scratch_parity / logs / root | 441 | 338 MB |

### `Gayini_output_structure.md` — the migration it specifies never happened

This is not staleness. It is an abandoned reorganisation, and it is recorded as such.

- Its measured baseline states **1,326 files · 1.57 GB**; live is **2,679 files · 16.04 GB** (10× the bytes).
- It asserts **"BROKEN POINTERS 0 … `path_exists = TRUE` is honest"**; live is **7** (see A2).
- **Documented but absent — none of the target structure exists:** `figures/ladder/`,
  `figures/site/`, `figures/paddock/`, `figures/stratum/`, `rasters/inundation/`, `rasters/veg/`,
  `rasters/zones/`, `rasters/intermediate/`, `_archive/figures_modis_mer/`,
  `_archive/rasters_pre_post/`, `_archive/review_bundles_tier1/`.
- **Present but undocumented:** `csv/`, `reports/`, `packages/`, `scratch_parity/`,
  `rasters/task_U/`, `rasters/MER/`,
  `figures/{dashboards,maps,plots,report_figures,review,review_deck,review_refresh,Land_use,_archive}`,
  `census/{_tmp,summaries}`, and ~18 `diagnostics/` subdirectories.
- Its rule 3 and acceptance criterion 4 — **"Nothing lands at `figures/` root"** — is violated by
  **144 files**, including *six of the seven newest pack items*. The newest work is the least compliant.

---

## A2 · Registries

**541 rows:** `figure_asset` 285 · `raster_asset` 186 · `report_asset` 59 ·
`spatial_layer_asset` 9 · `census_asset` 2.

CLAUDE.md's stated shape has drifted: **91 tables / 34 views** live vs 86/30 documented;
`figure_asset` 285 vs 278; `raster_asset` 186 vs 166; `dim_headline_number` **76** vs 59.

### Live `path_exists` re-test — 7 disagreements, all `stored=1 → live=0`, all `figure_asset`

```
figures/diagnostics/T12_DEA_persistence_fraction_full_1988_2025.png   T12_gateC
figures/diagnostics/T12_DEA_persistence_fraction_pilot_8yr.png        T12_gateC
figures/diagnostics/T12_DEA_farm_ctv_vs_flood_veg_1988_2025.png       T12_gateC
figures/diagnostics/T12_DEA_positive_control.png                      T12_gateC
figures/diagnostics/T12_DEA_sensor_era_gap.png                        T12_close
figures/diagnostics/T12_DEA_persistence_map.png                       T12_close
figures/diagnostics/T12_DEA_class_snapshots.png                       T12_close
```

These are the seven files showing as deleted-unstaged in `git status`. They are the **T12 DEA
documented negative** — the recorded-false-positive material CLAUDE.md says must never reach a
client deliverable. **The files being deleted is correct behaviour; the registry still asserting
them present is the defect.** Category E. Not touched.

These paths resolve to **repo-root `figures/`, not `Output/figures/`** — registered assets live
under two different roots, which the structure doc does not contemplate. This is itself a finding,
not something to normalise away.

### Registration-timestamp gap — material for Gate C

There is **no `registration_ts` column** in any registry — only `run_id`, dated via `workflow_run`.
`workflow_run` holds just **11 run_ids**; the registries use **31**.

**20 run_ids covering 114 registry rows have no derivable registration timestamp** — including
every one of the newest pack items: `adrian_pack_20260731` (F3, F5, pack item T1),
`T11_v2_20260731` (M5, M5b), `T13_gateD_20260730` (M4, M4b).

Design-seat ruling: Gate C uses an **event calendar against file `mtime`**, not per-artefact
dependency resolution, with `dependency_inferred = Y` on every row so dated, and the 114 undatable
count reported prominently so inference is never mistaken for provenance.

---

## A3 · Register v2 · tracker · stale workbook

### The six asserted filenames — all six verified. No Category C.

| Item | Asserted filename | Disk | Registered | run_id |
|---|---|---|---|---|
| M4 | `T13_D1_part_state_map_and_scatter` | yes, `Output/figures/` | yes | `T13_gateD_20260730` |
| M5 | `M5_dual_grain_floor_and_flood` | yes | yes | `T11_v2_20260731` |
| M5b | `M5b_paddock_residual_from_expectation` | yes | yes | `T11_v2_20260731` |
| F3 | `F3_annual_gap_series` | yes | yes | `adrian_pack_20260731` |
| F5 | `F5_cover_vs_water_64_paddocks` | yes | yes | `adrian_pack_20260731` |
| pack item T1 | `T1_conserved_paddock_comparison` | yes — `.png` **and** `.csv` | png only | `adrian_pack_20260731` |

All carry live `path_exists = 1`, `superseded_flag = 0`, and a non-null caption.

**Pack item T1 exists as two artefacts** — a `.png` and a `.csv`, with only the `.png` registered,
while register v2 classes the item as a **Table**. Not resolved here; surfaced to the manifest as
**DECIDE**.

### Item-set diff — the spec's expectation is confirmed

- **In stale workbook, absent from register v2:** M4b, D1, D2 — confirmed
- **In register v2, absent from workbook:** M5b — confirmed
- **True count: register v2 lists 16 items** (6 maps M1–M5b · 7 figures F1–F7 · 3 tables T1–T3).

§6 states *"One item of eighteen is not built"* and *"ships with seventeen items"*. **Both numbers
are wrong.** The stale workbook lists exactly 18 (the 16, plus M4b, D1, D2, minus M5b). The register
dropped three items and added one but **carried the workbook's total forward without recounting**.
Correct figures: **16 listed; 15 if M3 does not land.** This must be corrected in the register
before PACK-1 generates a contents page from it, or the error propagates onto a client cover page.

### D1 — answered

`Gayini_reference_state_methods.md` **exists**, in **two divergent copies**, and **neither is
registered**:

| Path | Bytes | mtime | SHA-256 |
|---|---:|---|---|
| `docs/reference_update/Gayini_reference_state_methods.md` | 22,944 | 2026-07-29 14:10 | `a781de6c9c9253f0…` |
| `docs/Spec_audit/Gayini_reference_state_methods.md` | 14,989 | 2026-07-28 10:33 | `78a4090d0640c023…` |

**Verdict: internal apparatus (Category H), not a pack item** — and a render-currency suspect.
Three independent lines agree: the workbook's own column says *"Technical; not required to read the
pack"* and *"Section 9 lists every headline number with…"*, which is precisely the
`dim_headline_number` machinery register v2 §5 rules internal; and CLAUDE.md records that its §7
community deficits **predate the T8 pins**. Register v2 dropping it is correct and consistent with
§5. **The workbook naming it EXISTS as a client pack item is the defect** — it would ship pre-pin
numbers under a client cover.

D2 (`Gayini_questions_for_Adrian_20260729.md`) exists at `docs/reference_update/`, unregistered.
Both D-items sit in `docs/`, outside `Output/`.

### M4b — answered

`T13_D2_part_state_map_sensitivity.png` **exists and is registered** (`T13_gateD_20260730`, live
`path_exists = 1`), with a copy in `Output/review_bundles/t13_paddock_part_classification/`.

**It was absorbed at caption level, not dropped — but it survives as a distinct artefact.**
Register v2 folds sensitivity into M4's caption via hatching (*"Solid colour means the result holds
when the two wettest years are removed; hatched means it does not"*), whereas the workbook describes
M4b as a different graphic entirely: *"the classification redrawn at a looser and stricter cut…
Hatching and the core outline are omitted."* Two different renderings of sensitivity.
→ **Category B candidate.**

### The 74 / 76 count — a concurrency artefact, not a register defect

Register v2 §5 asserts `dim_headline_number` = **74 rows**; live is **76**. The two extras are
TaskU's, added today. **74 was correct when the register was written on 31 July.** Not recorded as
Category C. (The workbook's "Sixty-eight numbers" *is* stale, as expected.)

**PIN 3 located** for Gate C: three `pinned_value IS NULL` rows are the five-period trajectory —
`ref_grazed_floor_gap_3pdk_periodwise`, `bala29ca_floor_gap_periodwise`,
`bala29ca_floor_gap_periodwise_jja_son`. The `floor_flood` 31 July precision correction is confirmed
on `floor_flood_slope_64pdk` (0.547838) and `floor_flood_intercept_64pdk` (52.652934), both citing
`docs/change_reports/floor_flood_precision_correction.md`.

### Tracker

`Gayini_path_to_Aug10_tracker_2.xlsx` (v3, mtime 03:06Z — outside the window) confirms the Gate C
inputs: the `floor_flood` precision correction, the QA-2a render guard, T11 v2, and pack items
T1/F3/F5 all landed **31 July**. ADR-1 states *"17 of 18 items now exist"* — inheriting the same
wrong total.

---

## The four Gate A findings carried forward as named gap-report items

1. **The structure doc's migration never happened** — 1,326 files / 1.57 GB documented against
   2,679 / 16.04 GB live, and none of the target directories exist. An abandoned reorganisation.
2. **The seven broken pointers are the T12 DEA figures** — documented-negative material that must
   never reach a client. Deletion was correct; the registry assertion is the defect. Category E.
3. **Register v2's item arithmetic is wrong** — 16 listed, not 18; 15 if M3 does not land. Must be
   corrected before PACK-1 generates a contents page.
4. **Pack item T1 exists as two artefacts** — `.png` and `.csv`, only the `.png` registered, while
   the register calls it a Table. Surfaced as DECIDE; not resolved.

Two further findings of standing:

- **114 registry rows cannot be dated**, including all six newest pack items. This weakens Gate C
  and must be stated prominently wherever Category G is reported.
- **Registered assets live under two roots** (`Output/` and repo-root `figures/`), plus named pack
  items in `docs/`. The reconciliation carries a `root` column so this stays visible.
