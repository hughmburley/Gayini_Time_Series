# Change report — Tier 1 · Task C3 (F5 figures: one file per slide + inset fix)

**Branch:** `feature/tier1c2-f5-legibility` (folded into C2 — C2 was not yet merged into main).
**Date:** 2026-07-09
**Status:** acceptance gate PASSED.

## What this task is

A **presentation-only** re-carve of the F5 figures under a new standing rule:
**one figure = one file = one slide.** No data, sampling, or band changes — it
only splits, cleans, and re-registers the figures.

## Branch decision

Checked C2's merge status: `feature/tier1c2-f5-legibility` (commit `5630c1b`) was
**not** merged into `main` (main was at `e2c7864` = C1). Per the task instruction,
C3 was **folded into the existing C2 branch** rather than starting a new one.

## Changes (code only — committed)

- `R/gayini_stratified_sampling_figures.R` — split the F5 composite builder:
  - **new** `gayini_build_f5_fullfarm_map()` — the whole-farm map only (no tables/insets).
  - **new** `gayini_build_f5_band_reference()` — points matrix + tercile-break table.
  - `gayini_build_f5_data()` is now a thin back-compat wrapper emitting both files
    (so the merged F5 sampling script keeps working, and inherits the split).
- `R/gayini_f5_legibility_figures.R` — `gayini_build_f5c_paddock_zooms()` now
  reserves a title band (top) and caption band (bottom) as separate strips and
  draws the locator inset **inside the map band only**, so it can never overlap
  the title/subtitle/caption. Returns a logged `overlap_check`.
- `scripts/07_figures_dashboards/11_build_f5_legibility_views.R` — produces the
  two split files, retires the old composite, checks inset clearance, re-registers
  the manifest (steps F5 / F5ref / F5b / F5c), and packages `tier1c3_f5_figures.zip`.

No F5 data products changed.

## The three fixes

1. **Split the F5 map into single-slide files:**
   - `F5_fullfarm_map_data` — whole-property surface + band-coloured points +
     legend + scale bar + north arrow. **No tables.** (`fullfarm_has_tables == FALSE`.)
   - `F5_band_reference_data` — points-per-community × band matrix **and** the
     within-community tercile-break table ("bands are relative / they overlap").
   - `F5b_community_facets_data` — kept as one 3-panel small-multiple (one slide);
     confirmed legible at slide size.
   - `F5c_paddock_*` — already one-per-file; kept.
   The old `F5_stratified_sampling_map_data.*` composite is **retired** (deleted;
   the gate asserts it no longer exists).
2. **Inset placement fixed on every inset figure.** Reserved title/caption bands
   mean the locator inset sits in the map's NW corner, clear of all text.
   **Verified on Bala 29ca** (where it previously covered the paddock name) and
   logged for all 4 paddocks in `f5c_inset_overlap_check.csv` (4/4 clear).
3. **Slide-size sanity.** Each file is a single 16:9-friendly slide; nothing is
   cramped or cut off (full-farm 12.5×7.2, band reference 12.5×5.4, facets 13×4.6,
   paddocks 9×7).

## Acceptance gate — PASSED

- relative-band label present; `fullfarm_has_tables == FALSE`;
  `F5_band_reference_data.pdf` exists; `n_facet_panels == 3`;
  `nrow(paddock_choice_log) == 4`; `all(inset_overlap_check$clear)`;
  old composite absent; all single-slide files + the zip exist.

## Notes

- New standing convention (record in the ladder): **one figure = one file = one
  slide; insets never overlap captions** — apply to every figure from here on.
- Presentation-only; F5 data products and bands untouched.
- Paddock zooms (Bala 29ca, Dinan 8, Dinan 10, Bala 28ca) still seed the Nari Nari
  paddock-review panels.
