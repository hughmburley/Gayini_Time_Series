# CLAUDE.md — Gayini remote-sensing environmental-change assessment

Project memory for Claude Code. Authoritative rules and pointers; keep it concise (loaded in full every session). Detailed context lives in the docs referenced at the bottom — read them when a task touches their area.

## What this project is

A spatially explicit remote-sensing assessment of flooding and vegetation on Gayini (Nimmie-Caira, lower Murrumbidgee), built as a **figure ladder** — simplest first, the probability surface last and gated on evidence. The 1 ha monitoring plots are **anchors, not the analysis unit**; the analysis operates on areas/strata.

## Current state

- **F1–F7 are merged on `main`** (F7 = ground-cover response within strata), plus the pixel census and the veg × wetness checkerboard.
- **D1 paddock/site/stratum dashboards** are in trial, held at the gate for review — not committed.
- **F6 gate is shut:** 8 no-trend · 1 non-stationary · 0 directional. The system is flood-pulse driven, not trending → the trend/change surface (F9) is **retired**; the static F5 background flood-frequency surface **is** the flood-probability product.
- Next planned: an **F5 sampling rebalance + F6 re-run** (proportional allocation, ~100 Monte-Carlo draws), and a repo audit.

## Standing conventions — do not re-litigate

- **One coordinate system:** everything analytical is **EPSG:8058** (GDA2020 / NSW Lambert). Reproject to new files or on read; never mutate originals.
- **One headline metric, end to end:** *between-year annual flood frequency* = `100 × wet-valid-years ÷ valid-years`. Community means: Aeolian 9% · Riverine 22% · Inland Floodplain 50% · Woodland/Forest 44% (context, treed, excluded).
- **Figure pair per step:** a concept explainer + the data figure. **One figure = one file = one slide.** Insets/legends never overlap titles/captions.
- **Review bundle per task:** after the acceptance gate passes, copy deliverables to `Output/review_bundles/tier1{X}_{name}/` and zip.
- **Workflow:** gated task specs → **branch-and-PR into `main`, human-reviewed before merge**. Stop at the acceptance gate; the review-bundle zip is what gets opened. Do not merge; hand back for the human to merge.
- **Simplest first; surface gated:** no probability surface unless a trend is real *and* roughly stationary. "No robust trend" is a legitimate, reportable result.

## Hard rules (verifiable — the acceptance gate should assert these)

- **Vegetation grouping: use the 4-class `simplified_vegetation_group`** (join `dim_plot`). NEVER use the legacy 5-class `vegetation_adrian_group`, and never let the pre/post `period` column leak into analysis outputs.
- **Metric discipline:** the headline (flood frequency) *defines strata*; the DB field **`annual_occurrence_pct` is the SECONDARY "wet-extent coverage" metric, not the headline** — despite the word "occurrence." Never present it as the headline.
- **CRS gotcha:** `dim_plot` centroid columns (`centroid_x/y`) are **EPSG:9473** (GDA2020 Australian Albers), *not* 8058 — reproject centroids before any spatial join or raster extraction.
- **Grazing is metadata**, not a covariate, in the current analysis.

## Database

`Output/database/Gayini_Results.sqlite` is authoritative (relational); `.gpkg` is the map companion; rasters are external, registered in `raster_asset`.

- **Consume via views, not raw `fact_*` tables.** Start at `v_plot_year_analysis_spine` (the modelling spine) and `v_pixel_census_by_veg_regime` (sampling substrate).
- **Post-build mutations exist:** the Python builder rebuilds the DB from scratch (unlink + rebuild, no GDAL), so the unified annual stack, raster metadata, and the pixel census are applied *after* the build and **must be re-run in this exact order after any full rebuild: `builder → 05_build_unified_annual_stack → 03_populate_raster_metadata → 09_build_pixel_census_view`** (05 registers the `stack_annual_*` rows whose CRS/legend 03 then completes; 09 reads the annual stack). A DB missing `raster_asset` rows or `v_pixel_census_by_veg_regime` has not had its post-build steps applied.
- Check `v_database_release_checks` and `v_current_qa_issues` before trusting a fresh build.

## What is retired / archived (do not revive)

- **Pre/post framing** (2019/2020 management split) is retired — no pre/post products or figures. Pre/post code is archive-only.
- **MER** is renamed to "annual maximum observed wet footprint" and kept **supplementary** only.
- **Archive convention:** archived scripts go to `scripts/archive/` (the smoke test enforces it is absent from the active handoff). Reconcile any `scripts/_deprecated/` into `scripts/archive/`.

## Adrian gate (open decisions — build with documented defaults, flag them)

- **Q1** — comparison design: stratified sample near plots vs community-wide; sets the near-plot neighbourhood radius (caps small-stratum sample sizes).
- **Q2** — vegetation units & gradient: three non-treed communities as dry→wet (use the headline 9/22/50), treed set aside.
- **Q3** — water metric & end product: Q3a = valid-coverage masking threshold (default `MIN_VALID_COVERAGE = 40`); Q3b = is "no robust trend" acceptable to report.

## Canonical docs (read when relevant — source of truth, not this file)

- `Gayini_Figure_Driven_Project_Ladder.docx` — **the single source of truth** (conventions, ladder, gate result, Adrian questions). If it and this file disagree, the ladder wins.
- `docs/Gayini_Results_database_overview.md` — database structure and how to consume it.
- `docs/archive/Gayini_subsampling_approach.md` — **ARCHIVED** stratified Monte-Carlo resampling design; superseded by the all-pixel census (`docs/Gayini_sequential_task_list_20260715.md`). Task F code stays on `main`, uncalled.
- `docs/Tier1_Task*.md` — the executed/queued task specs (A–E and beyond).

## Notes for Claude Code

- Don't duplicate here what auto memory (`MEMORY.md`) already infers from the code; keep this file to authoritative rules and pointers.
- Reports/change logs stay local (not committed) by standing preference; commit code only unless told otherwise.
