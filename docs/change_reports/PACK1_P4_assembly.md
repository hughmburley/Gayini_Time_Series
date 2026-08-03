# PACK-1 P4 — fifteen of sixteen items assembled; T3 and `00_START_HERE.md` held

**Status:** DRAFT · 3 August 2026 · filesystem writes to `Output/pack/` only · **no database write**
**Rulings applied:** design seat, 3 August §2 §3 §5, and the T2-format and DECIDE rulings
**Probe:** DB mtime 2026-08-03T17:37:09 · `dim_headline_number` 101 · `figure_asset` 297 · `raster_asset` 191 · `table_asset` 4 · `report_asset` 59 — unchanged across this gate, which opened no writable connection

---

## 1 · The two provisions, and the evidence they held

**Copy, never move.** Every source file is still in place: `source_still_present = 1` for all 15 packaged items, recorded per row in `PACK1_assembly_manifest.csv`.

**SHA-256 re-verified after each copy.** For every file the source was hashed before the copy and the pack copy hashed after it, both under the first-50-MB convention, and both recorded — `sha256_source` and `sha256_pack_copy`. **15 of 15 verified, 0 mismatches.** The script aborts before writing the manifest if any pair differs, so a silent partial assembly is not reachable.

## 2 · What is in the folder

**14 physical files carrying 15 items**, plus five manifests:

| folder | files | items |
|---|---|---|
| `01_maps/` | 6 | M1 M2 M3 M4 M5 M5b — **and F7** |
| `02_figures/` | 6 | F1 F2 F3 F4 F5 F6 |
| `03_tables/` | 2 | T1 (`.png`) · T2 (`.csv`) |

**F7 is not a separate file.** It is the right panel of `T13_D1_part_state_map_and_scatter.png`, which M4 also uses. The file is copied **once**, into `01_maps/`, and both items point at it — recorded in the manifest's `shares_file_with` column. Copying it twice would inflate the pack to 15 files and invite a reader to look for a difference that does not exist.

Total 4.2 MB.

## 3 · Two choices made, both reversible, both flagged

**Folder structure.** Spec P4 §4 says *"copy the 15 files into `Output/pack/files/`"* — a flat folder. The design seat's §3 ruling instead referred to *"a PNG table in `03_tables/`"*. I followed the design seat: `01_maps` / `02_figures` / `03_tables`, keyed on the item list's `type` column. Flagging the divergence from the written spec rather than reconciling it silently.

**Filenames are unchanged from source.** `T1_A_zone_map_named.png`, not `M1_the_property_and_its_paddocks.png`. Keeping registry paths and pack paths identical means no mapping can drift, and checksums are content-based so nothing depends on the name. But these names are opaque to a client reader, and the item→file mapping currently lives only in the manifest. **Renaming for legibility is a live option and should be decided with `00_START_HERE.md`**, which is the document that would carry the mapping either way.

## 4 · The 454 DECIDE rows — ruled, additively

`ship_flag = HOLD`, `hold_reason = 'not named by register v3; candidate addition, not selected'`, applied to all 454. None carried a prior `hold_reason`, so nothing was overwritten.

**The frozen input was not mutated.** `PACK1_input_manifest_FROZEN.csv` remains exactly as PACK-1 received it; the ruling is written to a new `PACK1_manifest_RESOLVED.csv`. The record of what was handed over and the record of what was decided are separate files, which is what makes the 10 August re-run able to tell them apart.

Resolved state: **531 HOLD · 4 SHIP · 0 DECIDE** across 535 rows. The 77 pre-existing HOLDs keep their own reasons — the T12 documented negative (38), the TaskU concurrent-write provisional (21), render-currency SUSPECT (15), and three Category C rows.

Note that the manifest's 4 SHIP rows are **not** the pack. The manifest is AUD-1's candidate pool; `PACK1_item_list.csv` is the pack. They answer different questions and should not be reconciled to each other.

## 5 · T2 ships as the CSV — the distinction from T1, recorded

Both are `type = table` and they ship in different formats, which will read as an inconsistency unless the reason is written down.

**T1 is four rows meant to be read.** The four conserved paddocks side by side; the point is that a reader looks at them and sees they are not alike. A rendered image delivers that in a meeting with nothing to open.

**T2 is 115 rows meant to be searched.** Every part of the property that is unusually low, improving or declining. Nobody reads it top to bottom — they look up their own paddock. That is a lookup table, and a CSV sorts and filters in the tool the reader already has. A 115-row PNG would be unreadable.

**Different jobs, different forms.** T2's caption must name it as a lookup table so a reader knows to search rather than read.

## 6 · What is deliberately absent

- **T3.** No file, no workbook sheet, and the item is now specified as a written page (`Gayini_what_we_dont_know.md`) drafted at the design seat from the 8 fragment rows, register v3 §1's *"what we cannot say"* paragraph, and the reference-state limitations. Its register caption is being rewritten first — the current *"Every limitation, what it means, and whether it can be fixed"* is the promise that cannot be kept.
- **`00_START_HERE.md`.** Held until T3 exists, because it must describe the folder it sits in. It is also the natural home for the item→file mapping and therefore the place the filename question gets settled.
- **`Gayini_Adrian_pack.xlsx`.** Not built. When it is, `How_we_know` queries its two numbers live — coverage and drift count travel together and neither is hardcoded.

## 7 · Version control

`.gitignore` gained a four-line negation, not the two-line form proposed: `Output/*` excludes the pack **directory**, and git cannot re-include a path inside an excluded directory, so `!Output/pack/` must come first, then `Output/pack/*` to re-exclude the contents, then the two `!…csv` / `!…md` rules. Verified with `git check-ignore`: the manifests are trackable, and `01_maps/`, `02_figures/`, `03_tables/` and any future `.xlsx` remain ignored.

## 8 · Nothing changed

No figure re-rendered, no registry row created or modified, no source file moved or deleted, no `git` operation on another lane's branch. The database was opened read-only and stands at 101 rows as found.
