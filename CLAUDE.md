# CLAUDE.md — Gayini remote-sensing environmental-change assessment

Project memory for Claude Code. Authoritative rules and pointers; keep it concise (loaded in full every session). Detailed context lives in the docs referenced at the bottom — read them when a task touches their area. **The "Session start" section below is mandatory, not optional.**

## Session start — do this before writing any code

**Recon before code, every time — this is a default, not a per-task instruction.**
1. **Load these docs first** (under `docs/`; they hold traps this file doesn't spell out):
   `Gayini_project_lineage_and_learnings.md` (the **trap index** — read before any repo-structure,
   archiving, builder, or registry work), plus the canonical docs listed at the bottom.
2. **Establish state from named sources — never assumption or a prior session's summary.**
   Read the DB tables/views, the docs above, and git. For any code-touching task, read and
   summarise back the specific files you will modify and **STOP for review before writing.**
3. **Verify prose against data.** Prose claims here have been wrong repeatedly (support mislabels,
   stale snapshots). Cross-check any claim against the DB/tables independently before acting.
   `DIFFER` is a valid finding — never tune a method to force a match.

**Never re-run the builder to "fix" the DB.** The builder resets from scratch (unlink + rebuild).
It does not reproduce the manually-registered products — the 9 EPSG:8058 rasters
(`veg_regime_class`, 5× `total_veg_percentile`, `flood_zone`, 2× `annual_inundation_stack`),
`census_asset`, and `dim_metric.support` — those come only from the post-build sequence under
**Database**. Re-running without re-applying that sequence **loses them** (≈12 unreproducible
Task H rows). **Additive-only:** move to `_archive/`, never delete. A non-destructive registration
strategy is required before any builder re-run.

**Invariants not covered elsewhere (honour by default; detail in the lineage doc):**
- `internal/` subfolders are **live runtime wrappers** — `source()`d by the numbered scripts. Never archive them.
- `map_asset_index` has **two independent `rglob` scan sites** — an `_archive/` exclusion needs **both** edited.
- `MIN_SEASONS = 50` does **two jobs** (makes p05 a true percentile *and* excludes open water) — don't change it without understanding both.
- **Machine identity** comes from an external signal (hostname, or a genuinely differing path) — never from a path the model assumes is workstation-vs-laptop.
- `figure_asset` holds a **stale 1-July snapshot** (139 old-generation rows, 0 current-ladder) — verify against disk before trusting it. *(Update or drop this line once the figure registry is rebuilt.)*

## What this project is

A spatially explicit remote-sensing assessment of flooding and vegetation on Gayini (Nimmie-Caira, lower Murrumbidgee), built as a **figure ladder** — simplest first, the probability surface last and gated on evidence. The 1 ha monitoring plots are **anchors, not the analysis unit**; the analysis operates on areas/strata.

## Current state

- **The project pivoted from sampling to an all-pixel census at the 15 July 2026 Adrian review.** Two Adrian deliverables are in final stages:
  - **Task H — all-pixel census (1,080,157 pixels, 11 strata): analytically complete and reconciled** (parquet ↔ `census_stratum` at diff = 0). Six paper-trail defects remain (data is sound): **D1** — spec v4 not committed to `main` (confirmed absent on disk); **D2** — the C1 area-basis correction never landed, so `pct_of_farm` reports % of *mapped* area (67,349.332 ha), not true farm (85,910.8 ha), high by ×1.276; D3–D6 lower. None require re-running the census.
  - **Task J — 2018 bank-cut pre/post: analytically complete**, sole blocker an unsent email to Jana (cut-date provenance L07, bank geometry L10). Suggestive, not causal. See the limitations register.
- **F1–F7 merged on `main`**, plus the pixel census and the veg × wetness checkerboard. D1/D2/D3 dashboards in trial, held at the gate.
- **F6 census verdict: 9 no-trend · 0 non-stationary · 0 directional.** Supersedes the provisional plot-support 8/1/0 — the lone non-stationary (Riverine low) was a 40-point sparsity artefact (54.1% false-positive across 1,000 draws). Conclusion unchanged and strengthened: flood-pulse driven, not trending → no probability surface; the static F5 background flood-frequency surface **is** the flood-probability product. *(Deck ratification of 9/0/0 with Adrian is the open I.2 item — confirm status.)*
- **Novel findings:** a vegetation floor (~97% dead at the median) with ~4,300 ha staying majority-green as refugia; community-structured lag response strengthening dry→wet. Headline caveat (confirmed): Landsat FC measures cover, not structure — it cannot separate land-use change from ecological condition. Adrian has pre-authorised a null as publishable.
- **On deck:** deck restatement against the census (stocktake done — 36 slides), site reports (Deliverable 2, at 5 of 66), CSIRO HCAS 3.3 integration, output-folder restructure.

## Standing conventions — do not re-litigate

- **One coordinate system:** everything analytical is **EPSG:8058** (GDA2020 / NSW Lambert). Reproject to new files or on read; never mutate originals.
- **One headline metric, end to end:** *between-year annual flood frequency* = `100 × wet-valid-years ÷ valid-years`. **The metric is one; the SUPPORT is two — always state which (C10).**
  - **Plot support** (~1 ha, **any-pixel rule**: a plot is wet if *any* of its ~16 pixels is wet; 66 plots) — *"how often does a 1-ha site see any water"*: Aeolian **9%** · Riverine **22%** · Inland Floodplain **50%** · Woodland/Forest 44% (context, treed, excluded).
  - **Pixel support** (24.97 m census pixel; all-pixel census, Tier2H) — *"how often is a 25 m pixel wet"*: Aeolian **6.1%** · Riverine **12.9%** · Inland Floodplain **28.0%**.
  - Both are correct and both are between-year. The 1.5–1.8× gap is `P(any of ~16 pixels) ≫ P(one pixel)`, **not** a within-year/between-year confusion (the within-year `annual_occurrence_pct` means are 4.0 / 11.6 / 31.2 — a different metric again, see C8). Never compare across supports, and never relabel one as the other.
- **Figure pair per step:** a concept explainer + the data figure. **One figure = one file = one slide.** Insets/legends never overlap titles/captions.
- **Census display convention (H5):** never plot 1.08 M raw points — use hexbin / 2-D density or a CI band. **Never a naive large-N CI:** 1,080,157 pixels are spatially autocorrelated, not independent observations.
- **Review bundle per task:** after the acceptance gate passes, copy deliverables to `Output/review_bundles/tier{N}{X}_{name}/` and zip.
- **Workflow:** gated task specs → **branch-and-PR into `main`, human-reviewed before merge**. Stop at the acceptance gate; the review-bundle zip is what gets opened. Do not merge; hand back for the human to merge. **No AI authorship in commits** (no `Co-Authored-By:` trailers).
- **Simplest first; surface gated:** no probability surface unless a trend is real *and* roughly stationary. "No robust trend" is a legitimate, reportable result.

## Hard rules (verifiable — the acceptance gate should assert these)

- **Vegetation grouping: use the 4-class `simplified_vegetation_group`** (join `dim_plot`). NEVER use the legacy 5-class `vegetation_adrian_group`, and never let the pre/post `period` column leak into analysis outputs.
- **Metric discipline:** the headline (flood frequency) *defines strata*; the DB field **`annual_occurrence_pct` is the SECONDARY "wet-extent coverage" metric, not the headline** — despite the word "occurrence." Never present it as the headline.
- **Four-CRS discipline** (reproject before any join/extraction; confusing them is a live trap):
  - **EPSG:8058** — canonical analysis grid (all census products).
  - **EPSG:28355** — the native inundation stack (genuinely 25.0 m).
  - **EPSG:3577** — FC source rasters (30 m, before the single reproject to 8058).
  - **EPSG:9473** — `dim_plot` centroid columns (`centroid_x/y`) — *not* 8058; reproject centroids first.
- **FC band semantics:** the JRSRP percentage-plus-100 offset convention may apply; treat FC arithmetic as gated until `legend_status` is confirmed for the products in use.
- **Grazing is metadata**, not a covariate, in the current analysis.

## Database

`Output/database/Gayini_Results.sqlite` is authoritative (relational); `.gpkg` is the map companion; per-pixel data lives in an **external parquet** (never in SQLite), registered via `census_asset`; rasters are external, registered in `raster_asset`.

- **Consume via views, not raw `fact_*` tables.** Start at `v_plot_year_analysis_spine` (the modelling spine, 66×35) and `v_pixel_census_by_veg_regime` (census substrate).
- **The builder is destructive** (see Session start). The Python builder rebuilds from scratch (unlink + rebuild, no GDAL), so post-build steps **must be re-run in this exact order after any full rebuild:**
  `builder → 05_build_unified_annual_stack → 03_populate_raster_metadata → 09_build_pixel_census_view → 11_reproject_annual_stack_8058_nn → 01_prepare_inputs/05_populate_metric_support`
  (05 registers the `stack_annual_*` rows whose CRS/legend 03 completes; 09 reads the annual stack; 11 registers the EPSG:8058 NN stack; `05_populate_metric_support` re-adds `dim_metric.support`, absent from the builder's METRICS list). **This sequence is necessary but, post-Task-H, not sufficient:** the Task H products (the 5 percentile rasters, `flood_zone_8058`, `veg_regime_class_8058`, and `census_asset`) are additional manual registrations — confirm their re-registration steps from the Task H spec/change reports before any rebuild. A DB missing `raster_asset` rows, `v_pixel_census_by_veg_regime`, `census_asset`, or `dim_metric.support` has not had its post-build steps applied.
- Check `v_database_release_checks` and `v_current_qa_issues` before trusting a fresh build.

## What is retired / archived (do not revive)

- **Pre/post *framing*** (2019/2020 management split) is retired — no pre/post products or figures in the main ladder; that pre/post code is archive-only. **Distinct from Task J:** the 2018 bank-cut pre/post (below) is a separate, additive, Adrian-requested deliverable on its own branch — do not archive it as "the retired pre/post."
- **Task F** (Monte-Carlo sampling rebalance) — **CANCELLED at the 15 July review** (superseded by the all-pixel census), not merely gated. Code stays on `main`, uncalled, additive-only; spec archived with a superseded header. Sub-sampling may be reused later.
- **MER** renamed to "annual maximum observed wet footprint" and kept **supplementary** only.
- **Archive convention:** archived scripts go to `scripts/archive/` — but see the smoke-test conflict below.

## Known tooling conflicts (unresolved — human call with Adrian)

- **Archive convention contradicts the smoke test (B5).** The convention says archived scripts go to `scripts/archive/`, but `run_spine_smoke_test.R:104-112` (`folder_scripts/archive_absent`) **hard-fails if `scripts/archive/` exists.** So `scripts/_deprecated/01_lag_diagnostics_inundation_gc.R` cannot be reconciled into `scripts/archive/` without breaking spine validation. Left untouched pending an Adrian decision; **do not modify the smoke test** to force it. (Deferred as B5 in the Task F spec.)

## Adrian gate

**Resolved by the 15 July review / census pivot** (do not reopen): Q1 near-plot radius — superseded by the all-pixel census. Q3a `MIN_VALID_COVERAGE = 40` — census uses `MIN_VALID_YEARS = 25` instead; the 40 rode in on a bypassed gate, left untouched in the extraction path. Q3b "is no-trend reportable" — **yes**, Adrian pre-authorised a null. Q2 vegetation units — three non-treed communities dry→wet, treed set aside (unchanged).

**Currently open (build with documented defaults, flag them):**
- **Deck ratification of the F6 census 9/0/0** — the open I.2 item.
- **Band definitions, round 2 (option 3):** tie-aware / absolute thresholds are the proper long-run fix; option 2 (F5 `regime_band_breaks.csv` edges) is a first-cut for stability. Gated on Adrian, post-presentation. H6 absolute flood-frequency zones are the candidate replacement.
- **Which percentile becomes canonical** — compute all five, recommend one; Hugh's decision.
- **Nari Nari panel rendering** — recommend absolute zones (H6), single 5-class sequential map, plain-language legend.
- **Density/CI display convention** — request Adrian's own examples (#18).
- **CSIRO HCAS 3.3 integration** — flagged in Adrian's 15 July workbook; compare with inundation (independent), never with ground cover (circular — appendix consistency-check only).

## Canonical docs (read when relevant — source of truth, not this file)

- `Gayini_Figure_Driven_Project_Ladder.docx` — conventions, ladder, gate result. If it and this file disagree, the ladder wins on convention; on current state, this file's "Current state" is newer.
- `docs/Gayini_project_lineage_and_learnings.md` — **the trap index / cross-session memory.** Read at session start.
- `docs/Gayini_sequential_task_list_20260715.md` — the post-pivot sequenced plan.
- `docs/Tier2_TaskH_all_pixel_census_v4.md` — the authoritative census spec *(D1: commit this)*.
- `docs/Gayini_pixel_census_data_contract.md` — the parquet H4 schema (columns: `flood_freq_pct`, `veg_p05..p50`; **no per-pixel total-veg column**).
- `docs/Gayini_established_data_facts.md` — settled numbers (community flood-freq means, flood-zone crosstab, refugia).
- `docs/Gayini_output_structure.md` — output-folder contract and migration plan.
- `docs/Gayini_Results_database_overview.md` — database structure and how to consume it.
- `docs/Gayini_limitations_register_*.xlsx` — Task J evidence register (current: v10).
- `docs/archive/Gayini_subsampling_approach.md` — **ARCHIVED** Monte-Carlo design; superseded by the census.
- `docs/Tier*_Task*.md` — executed/queued task specs.

## Notes for Claude Code

- Don't duplicate here what auto memory (`MEMORY.md`) infers from the code; keep this file to authoritative rules and pointers.
- **Commit change reports and the lineage/learnings doc** to `docs/` — they are the cross-session memory a fresh instance relies on. Other transient/ad-hoc reports may stay local. *(This supersedes the earlier "commit code only" preference — see note to Hugh.)*