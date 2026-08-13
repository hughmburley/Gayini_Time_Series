# Task K Gate A - recovered archive manifest

**Recovered 13 August 2026** from `origin/tier2k-gateA-archive`, commit `dc13650`, dated
19 July 2026. Extracted with `git show`; the branch was never merged and is left in place
as the provenance.

## Relationship to Gate 0

This branch contains Gate 0's commit plus two more files. The six Gate 0 files here are
byte-identical to those in `../taskK_gate0/`; both folders are kept whole so each reads as
its own branch's state.

## What the work established

The Gate A move: **431 dead-generation output files across 43 folders, archived rather than
deleted.** The gate rested on a single claim - that none of the 431 carried a registry row -
and Gate 0's registry join is what tested it.

`taskK_gateA_moved_manifest_20260719.csv` is the record of what moved and where, 431 rows.
It is the only account of that move, and without it an archived file cannot be traced back
to where it came from.

## Files

| file | what |
|---|---|
| `taskK_gateA_20260719.md` | the Gate A change report |
| `taskK_gateA_moved_manifest_20260719.csv` | 431 rows: every file moved, source and destination |
| the six `taskK_gate0_*` files | Gate 0's outputs, identical to `../taskK_gate0/` |
