# Change report — Tier 1 · Task C2 (F5 legibility views)

**Branch:** `feature/tier1c2-f5-legibility`
**Date:** 2026-07-09
**Status:** acceptance gate PASSED.

## What this task is

A **presentation-only** pass on F5. It adds **no new sampling or analysis** — it
re-renders the finished F5 result so the **within-community (relative)** regime
banding reads clearly for Adrian and Nari Nari. The regime bands are
within-community terciles, so "high" is a *different absolute frequency* in each
community and the bands overlap (Aeolian high ≈ 5.7–76%, Inland low ≈ 0–18.7%);
a naive read across communities would mislead. These views make that explicit.

## Files added / changed (code only — committed)

- **New** `R/gayini_f5_legibility_figures.R` — product loader, community-facet
  builder, paddock chooser, paddock-zoom builder, shared relative-band legend.
- **New** `scripts/07_figures_dashboards/11_build_f5_legibility_views.R` — run script.
- **Changed** `R/gayini_stratified_sampling_figures.R` (presentation only):
  - `gayini_regime_band_legend_title()` → `"Regime band (within-community, relative)"`,
    now used by the F5 map legend (source-of-truth label; F5 inherits it on re-run).
  - `gayini_tercile_table_plot()` — the tercile-break table, printed on band figures.
  - `gayini_build_f5_data()` gains an optional `breaks_df` arg → prints the
    tercile table + uses the relative legend title. Back-compatible (default NULL).

No data products were altered — `stratified_sample_points.gpkg`,
`background_flood_frequency_8058.tif`, `regime_band_breaks.csv` are read-only here.

## Outputs (gitignored — reproducible)

- `Output/figures/F5_stratified_sampling_map_data.{png,pdf}` — re-rendered with the
  relative legend + the tercile-break table.
- `Output/figures/F5b_community_facets_data.{png,pdf}` — 3 self-contained panels
  (one per focus community), each annotated with its own terciles.
- `Output/figures/F5c_paddock_<name>_data.{png,pdf}` — 4 paddock zooms with a
  property-scale locator inset each.
- `Output/diagnostics/f5c_paddock_choice_log.csv` — full paddock ranking, chosen flagged.
- `Output/review_bundles/tier1c2_f5_legibility.zip`.

## The three legibility fixes

1. **Relative-band labelling.** Every band figure's legend now reads
   *"Regime band (within-community, relative)"*, and the per-community
   tercile-break table is printed on the F5 map ("Bands are RELATIVE … they
   OVERLAP across communities").
2. **F5b community facets.** One self-contained panel per focus community — the
   surface clipped to that community, its points by band, and its three tercile
   breakpoints annotated. Because each panel is a single community, the bands
   can't be read across communities.
3. **F5c paddock zooms.** 4 management zones chosen by
   **score = n_points × n_communities × n_bands** (point density × community/band
   spread), logged in full:

   | rank | paddock | n_points | n_comm | n_band | score |
   |---|---|---|---|---|---|
   | 1 | Bala 29ca | 63 | 3 | 3 | 567 |
   | 2 | Dinan 8 | 44 | 2 | 3 | 264 |
   | 3 | Dinan 10 | 18 | 1 | 3 | 54 |
   | 4 | Bala 28ca | 11 | 2 | 2 | 44 |

   Each zoom: surface + points by band + heavy paddock outline + light neighbours
   + a property-scale locator inset. Built reusably — these seed the future Nari
   Nari paddock-review panels.

## Acceptance gate — PASSED

- relative-band label present (`grepl("within-community|relative", legend_label)`);
- `n_facet_panels == 3`, each with its own terciles annotated;
- `nrow(paddock_choice_log) == 4 (≥ 3)`, chosen with logged rationale;
- all re-rendered/new band figures + the review-bundle zip exist.

## Notes

- Bands are within-community relative **by design**. Q1 to Adrian may switch to
  absolute — if so it's a one-line change in F5 and these views inherit it.
- Presentation only: no re-sampling, no re-banding, no change to F5 data products.
