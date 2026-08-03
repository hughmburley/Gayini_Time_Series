# PACK-1 P1 — item list amended: M4b dropped, T1 restated as the render

**Status:** DRAFT · 3 August 2026 · filesystem write to `Output/pack/` only; **no database write**
**Rulings applied:** design seat, 3 August §2 and §3
**Probe:** DB mtime 2026-08-03T17:37:09 · `dim_headline_number` 101 · `figure_asset` 297 · `table_asset` 4 · `report_asset` 59 — unchanged across this gate

---

## 1 · What changed

`Output/pack/PACK1_item_list.csv`: **18 rows → 16 rows.**

| ruling | action |
|---|---|
| §2 | `M4b` (`T13_D2_part_state_map_sensitivity.png`) removed — sensitivity is folded into M4's caption, and every shipped item must have a caption of its own |
| §3 | `T1`'s shipped path swapped from `Output/tables/T1_conserved_paddock_comparison.csv` to `Output/figures/T1_conserved_paddock_comparison.png`; `sha256` and `registered_in` swapped with it; the `T1_render` row dropped as now redundant |

`T1` keeps `type = table` — register v3 classes it by content, not file format.

## 2 · The arithmetic resolves exactly

**16 items over 14 distinct paths**, matching register v3 §6 without residue:

- 16 item_ids: M1 · M2 · M3 · M4 · M5 · M5b · F1–F7 · T1 · T2 · T3
- 14 distinct paths: F7 shares `T13_D1_part_state_map_and_scatter.png` with M4; T3 has no file
- **No disagreement to report.** The count that P1 could not close, closes.

## 3 · Every checksum re-verified against disk

All 15 file-bearing rows recomputed from disk under the first-50-MB SHA-256 convention and compared to the listed value: **15 of 15 OK, 0 differences, 0 missing.** This is the pre-copy half of the copy/verify provision; the post-copy half runs at assembly.

## 4 · One inconsistency with §3's stated reasoning — FLAG, not reconciled

§3 rules T1 to the `.png` partly because *"this pack contains no other data file — shipping one would invite the question of why the other thirteen items are not also supplied as data."*

**After the amendment the pack still contains one data file: `T2` ships as `Output/tables/T13_gateC_classification.csv`.** So the premise does not hold, and T2 now sits in exactly the position T1 was moved out of.

No `.png` rendering of T2 exists. The only alternatives on disk are the same `.csv` in a review bundle and a `.md` rendering at `Output/review_bundles/t13_paddock_part_classification/reports/T13_gateC_classification.md`.

Three ways it could go — **not chosen here**, per *flag, don't choose*:

1. **T2 ships as the `.csv`** and §3's reasoning is narrowed to T1's specific case (a rendered table already existed; for T2 one does not).
2. **T2 gets a `.png` rendering built** to match T1 — new work, small, but it is a render inside an assembly window.
3. **T2 ships as the `.md`** — readable without opening a spreadsheet, but inconsistent with T1's treatment.

The item list currently carries option 1 by inheritance, not by decision.

## 5 · T3 is untouched and still blocks assembly

The `T3` row remains as found — `ship_flag = SHIP`, `caption_status = "TEXT_ONLY - no file; the item is a table rendered in the workbook"`, `file_path` null. It is **not** amended here because §4 of the ruling requires the design seat to answer first. See the separate finding: **no such table and no such workbook sheet exists.**

**Assembly does not proceed while this row stands.**

## 6 · Nothing else changed

No figure re-rendered. No registry row written. No file copied or moved. `Output/pack/` still contains no assembled pack — the two frozen input manifests and this item list only.
