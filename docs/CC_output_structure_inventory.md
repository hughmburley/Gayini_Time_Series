# Output / figures structure inventory + registration overlay

*Task spec for Claude Code. Design seat, 20 Jul 2026. Read-only recon to plan the output-folder migration. The figures tree is ~60 GB — metadata only (sizes + paths); **never read file contents or hash**. No changes, no builder, no DB writes.*

**Use Python** for the filesystem walk (cleanest — avoids the PowerShell encoding issues that blocked the hand-run script). Read-only throughout: nothing moved, deleted, or rebuilt. Report and stop; no commit required (CSVs land in the gitignored `Output/diagnostics/`).

---

## 1. Filesystem inventory (metadata only)

For `Output/` and its figures subtree, write CSVs to `Output/diagnostics/`:

- **Folder rollup to depth 3** — `folder, file_count, total_bytes, total_gb`, sorted by size.
- **Extension breakdown** — `ext, file_count, total_gb`, sorted by size.
- **Figures by immediate subfolder** — `subfolder, file_count, total_gb`.
- **Figures by ladder prefix** — `F1`–`F7`, `F5c`, `C1`, `D1`, `D2`, `D3`, `H2`, `H6`; everything else `(other)`: `prefix, file_count, total_mb, extensions_present`.
- **Largest 40 files** — `size_mb, last_write, path`.

## 2. DB registration overlay (read-only)

Join on-disk files against `raster_asset`, `figure_asset`, `census_asset`, `report_asset` by path (resolve paths from the DB; you have SQLite access — the PowerShell version could not do this step).

- Report a **tracked-vs-orphan crosstab** by folder and by extension.
- Confirm the figures gap: `figure_asset` = 139 old-generation rows, 0 current-ladder registered.
- Flag any registered asset whose file is **missing** on disk (broken pointer).

## 3. The 60 GB question

State plainly what accounts for the bulk. Classify the big folders/files into: **`fc_intermediate` cubes** · **duplicated review-bundle copies** · **multiple figure generations** · **other**. This is the finding that matters most — the last measured snapshot had *all* of Output at 1.57 GB, so 60 GB is a large jump and we need to know what drove it before migrating.

## 4. Report

Write the CSVs, **and report the headline numbers inline** in your reply — total sizes per root, top folders, the tracked/orphan split, and what the 60 GB is — so we can act without waiting on the files. Read-only; report and stop.

## 5. Guardrails

- Metadata only — never read file contents or hash the 60 GB.
- Read-only — no moves, deletes, builder runs, or DB writes.
- Resolve paths from the DB for the overlay; don't hardcode.
- Report and stop.
