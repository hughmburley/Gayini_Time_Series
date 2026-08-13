# Task K Gate 0 - recovered Output census

**Recovered 13 August 2026** from `origin/tier2k-gate0-output-census`, commit `8778962`,
dated 19 July 2026. Extracted with `git show`; the branch was never merged and is left in
place as the provenance.

## Why this was invisible

The branch predates the 28 July "commit straight to main, no PRs" rule. It is not an
ancestor of `main`, so its work never appeared in the repository anyone reads. HANDOFF-1
found this while trying to reconcile against it.

## What the work established

An independent, read-only census of everything under `Output/` on 19 July 2026:

- **1,351 files**, each with size, SHA-256, folder depth and duplicate grouping
- an **`essential` flag** on every row - 168 essential, 1,183 not - with a mandatory reason,
  derived from the builder's hardcoded `CSV_INPUTS`, not from folder names
- a **registry join** showing which files carry a registry row and which do not
- a **folder-shape** analysis, 173 rows
- a **checksum verification** pass, 286 rows - the check that had never been run

## A caveat that matters for migration

These `essential` flags describe files under `Output/`. They say almost nothing about which
*tracked* files migrate: only 3 tracked files carry a flag at all, and none disagrees with
HANDOFF-1's classification. The two populations barely intersect.

## Files

| file | rows | what |
|---|---|---|
| `taskK_gate0_census_20260719.csv` | 1,351 | the census, one row per file |
| `taskK_gate0_registry_join_20260719.csv` | 287 | census against the registries |
| `taskK_gate0_folder_shape_20260719.csv` | 172 | folder-level shape |
| `taskK_gate0_checksum_verify_20260719.csv` | 285 | checksum verification |
| `taskK_gate0_qa.json` | - | QA summary |
| `taskK_gate0_20260719.md` | - | the change report |
