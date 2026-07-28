# CLAUDE.md — Gayini remote-sensing environmental-change assessment

Project memory for Claude Code. Authoritative rules and pointers; keep it concise (loaded in full every session). Detailed context lives in the docs referenced at the bottom — read them when a task touches their area. **The "Session start" section below is mandatory, not optional.**

## Session start — do this before writing any code

**Recon before code, every time — this is a default, not a per-task instruction.**

1. **Load these docs first** (under `docs/`; they hold traps this file doesn't spell out):
   `Gayini_project_lineage_and_learnings.md` (the **trap index** — read before any repo-structure, archiving, builder, or registry work), plus the canonical docs listed at the bottom.
2. **Establish state from named sources — never assumption or a prior session's summary.**
   Read the DB tables/views, the docs above, and git. For any code-touching task, read and summarise back the specific files you will modify and **STOP for review before writing.**
3. **Verify prose against data.** Prose claims here have been wrong repeatedly (support mislabels, stale snapshots). Cross-check any claim against the DB/tables independently before acting. `DIFFER` is a valid finding — never tune a method to force a match.

**Never re-run the builder to "fix" the DB.** The builder resets from scratch (unlink + rebuild). It does not reproduce the manually-registered products — the 9 EPSG:8058 Task H rasters (`veg_regime_class`, 5× `total_veg_percentile`, `flood_zone`, 2× `annual_inundation_stack`), `census_asset`, and `dim_metric.support` — those come only from the post-build sequence under **Database**. Re-running without re-applying that sequence **loses them** (≈12 unreproducible Task H rows). **Additive-only:** move to `_archive/`, never delete. A non-destructive registration strategy is required before any builder re-run.

**Invariants not covered elsewhere (honour by default; detail in the lineage doc):**

- `internal/` subfolders are **live runtime wrappers** — `source()`d by the numbered scripts. Never archive them.
- `map_asset_index` has **two independent `rglob` scan sites** — an `_archive/` exclusion needs **both** edited.
- `MIN_SEASONS = 50` does **two jobs** (makes p05 a true percentile *and* excludes open water) — don't change it without understanding both. Distinct from the census's `MIN_VALID_YEARS = 25`.
- **Machine identity** comes from an external signal (hostname, or a genuinely differing path) — never from a path the model assumes is workstation-vs-laptop.
- `figure_asset`: the **11 Gate E figures are registered** (`run_id='gateE_20260721'`, G7) — the current-ladder set (S12/S21/S24/S25/S26, veg-water scatters, percentile fan, Fig A). The **pre-Gate-E rows remain an old-generation snapshot** and need reconciliation against disk before being trusted. D4 is partially closed.

---

## Provenance discipline — numbers, their homes, and their qualifiers

Twelve number discrepancies were found during the T1 cycle (`docs/Gayini_number_provenance_audit.md`). **None came from the database disagreeing with itself.** Every one came from reading a stale copy, opening the wrong object, or asking an underspecified question. These rules exist because prose versions of them were already present and were violated anyway — including by their own author.

### The database is the authority. Nothing else is.

- **Never establish a fact from a workbook, a change report, a spec, or a prior chat.** Those are renderings. Re-derive from the DB.
- **This includes the DB's own QA and release tables.** A row asserting "98 of 98 raster assets lack CRS/extent", dated 2026-07-01, is still present while all 126 are populated. It misled four separate readers. Once `v_qa_freshness` exists (T5 Gate 2), read QA verdicts through it — anything older than the newest `workflow_run` reports STALE.
- `Gayini_Results_DB_contract_snapshot_*.xlsx` is authoritative for **object existence, schema and row counts**. It is **not** authoritative for QA verdicts. Check the as-of date on the sheet.
- **Project knowledge silently corrupts binaries** — every byte ≥ 0x80 becomes the UTF-8 replacement character. `.sqlite`, `.parquet` and `.gpkg` cannot live there; `.xlsx` and `.md` survive. That is why the snapshot workbook exists.

### `Output/` is the record; `docs/` is never a result

Task M's Gate A inventory found **33 of 43 stale floor-claim sites in `docs/`**, while the definition-complete statements sat in `Output/diagnostics/`. The computation wrote an honest record into `Output/`; `docs/` then propagated the number without its definition. This file was the end of that chain.

- **A number in `docs/` must cite the `Output/` artefact that produced it** — path, and registered asset id where one exists.
- **A change report states findings and where they live. It must never be the only home for a value.**
- **If a number cannot name its `Output/` artefact, write the pointer and omit the value.**

### No number travels without its five qualifiers

Store them as columns, never as prose:

1. **support_level** — pixel · paddock · stratum · property · plot · zone_month
2. **scope_filter_sql** — the literal filter, e.g. `treed_context_flag = 0 AND regime_band <> 'context'`
3. **pixel_area_ha** — the constant used
4. **denominator_ha** — mapped 67,349.332 or true farm 85,910.8
5. **period_label** — `1988-2023`, `post_conservation`, or similar

Eight of the twelve discrepancies would have been caught on sight. The `9 / 22 / 50` flood-frequency numbers alone have three legitimate values across two qualifiers — see C10 under Standing conventions.

### Constants come from `gayini_params`, never from a literal

`R/gayini_params.R` and `scripts/lib/gayini_params.py` are the only place a project constant may appear. `PIXEL_AREA_HA` is **derived** from `PIXEL_SIDE_M`, never typed. A smoke-test lint fails the run on a bare `0.0625`, `0.062351428`, `24.970268`, `67349`, `85910`, `1080157`, `988831` or `993782` anywhere else.

**`0.0625` is wrong.** The census grid is 24.970268 m → `0.062351428` ha/px. The 25 m nominal inflates every area by 0.238% and has already contaminated one spec and one manuscript figure.

### Scope: nine strata, not ten

`treed_context_flag = 0` **alone admits ten strata** — it lets `Other / minor units` in (4,951 px, 308.7 ha). Non-treed means `treed_context_flag = 0 AND regime_band <> 'context'` (988,831 px of 1,080,157).

### Registration: `INSERT OR REPLACE`, never `OR IGNORE`

`OR IGNORE` does not error and does not duplicate, so it looks idempotent — but it never updates a changed checksum. That makes the acceptance test *"re-run twice, identical checksums"* **pass while the DB is wrong**. `register_taskM_gateC_assets.py` uses `OR IGNORE`; do not propagate it when copying that template's structure.

**Idempotence is tested by convergence, not stability.** Mutate an input, re-run, confirm the DB moves to the new checksum. A test that only checks stability cannot distinguish converged from frozen.

### One checksum convention

First-50-MB SHA-256 (`50*1024*1024`, 1 MB chunks), as in `sha256_first50()`. The R registrars' whole-file `digest::digest(algo="sha256")` is a **different** convention and must not be used for asset registration — including inside `write_and_register_figure()`.

### Figures: write and register in one transaction

Figures went unregistered at scale because every path wrote in R and registered later in Python, so the two steps could land in different sessions. **R owns both halves** via `write_and_register_figure()` (ggsave → SHA-256 → `INSERT OR REPLACE` via RSQLite, one call). `register_taskM_gateC_assets.py` remains the template for rasters and parquet.

`figure_asset` carries `support_level` and `figure_level` (added T1 Gate B1). Every caption states the support level.

### Spatial layers: read through the registry

Use `read_registered_layer(layer_name)` — resolves the path from `spatial_layer_asset`, asserts the CRS, and compares the file's actual fields to the registered `field_list`. **Three management-zone objects exist and they differ — do not conflate them:**

| | `management_zones_8058` (spatial_006) | `management_zones` source shp (spatial_004) | `Gayini_Results.gpkg:management_zones` |
|---|---|---|---|
| CRS | EPSG:8058 — **the analysis input** | EPSG:28355 — registered source (`CA0561_ManagementZones.shp` in `shapefiles.zip`) | EPSG:28355 |
| Fields | `OBJECTID_1,OBJECTID_2,ManagmentZ,Area_MW,Treatment,Plots` (caps) | same caps ESRI names | `source_feature_id,management_zone,treatment,plots` (lowercase) |
| Text | clean | clean | **NUL-padded** |
| Status | registered, analysis input | registered import | **build output, unregistered — cross-check only, never an analysis input** |

The lowercase names are the **builder's normalisation on import**; the gpkg companion is a build output, so it is correctly registered *nowhere* (`spatial_layer_asset` is an import registry — `import_status`, `invalid_geometry_count_*`; a build-output row there is a category error). `read_registered_layer()` refusing it is correct. A spec once declared `Area_MW` non-existent after inspecting the lowercase companion instead of the caps input.

### Every check must be able to fail

When you add a check, **prove it fires on a deliberately broken fixture and record the failure output in the change report.** A check that has never failed has not been tested; it has only been run.

Two live illustrations of why:

- The 1 July QA row above returns PASS/FAIL from a stored snapshot rather than from the data, so it cannot notice being wrong. Verdicts that are derivable should be **views that compute**, not rows that persist.
- `folder_scripts/archive_absent` in the smoke test has **inverted polarity** against the stated archive convention — see Known tooling conflicts (B5).

---

## What this project is

A spatially explicit remote-sensing assessment of flooding and vegetation on Gayini (Nimmie-Caira, lower Murrumbidgee), built as a **figure ladder** — simplest first, the probability surface last and gated on evidence. The 1 ha monitoring plots are **anchors, not the analysis unit**; the analysis operates on areas/strata.

## Current state

- **The project pivoted from sampling to an all-pixel census at the 15 July 2026 Adrian review.** Two Adrian deliverables are in final stages:
  - **Task H — all-pixel census (1,080,157 pixels, 11 strata): analytically complete and reconciled** (parquet ↔ `census_stratum` at diff = 0). Paper-trail defects (data is sound): **D1 RESOLVED** — spec v4 **is** committed and clean on `main`; **D2 FIXED** (21 Jul) — `pct_of_farm` now divides by the true farm (85,910.8 ha), with an explicit `pct_of_mapped` added (the 67,349.332 ha basis kept for the S12 "66.44% of mapped" trap); **D8 FIXED** (Task M) — see the floor definition below; D3–D6 lower. None require re-running the census.
  - **Task J — 2018 bank-cut pre/post: analytically complete**, sole blocker an unsent email to Jana (cut-date provenance L07, bank geometry L10). Suggestive, not causal. See the limitations register.
- **F1–F7 merged on `main`**, plus the pixel census and the veg × wetness checkerboard. D1/D2/D3 dashboards in trial, held at the gate.
- **F6 census verdict: 9 no-trend · 0 non-stationary · 0 directional.** Supersedes the provisional plot-support 8/1/0 — the lone non-stationary (Riverine low) was a 40-point sparsity artefact (54.1% false-positive across 1,000 draws). Conclusion unchanged and strengthened: flood-pulse driven, not trending → no probability surface; the static F5 background flood-frequency surface **is** the flood-probability product. *(Deck ratification of 9/0/0 with Adrian is the open I.2 item — confirm status.)*
- **T1 (zone × stratum census join) in build.** Gate 0 inventory, Gate A0 (8058 zone layer registered as `spatial_006`) and Gate A recon complete; Gate B in progress. See `docs/T1_zone_stratum_census_join.md` (v3) and the change reports.

### The two floor findings are different findings — never conflate them

**D8 (FIXED, Task M).** `green_at_floor()` measures the **green share of remaining cover** (`100 × PV ÷ total_veg > 50`, paired at each pixel's total-veg p05) — **not** total cover (`veg_p05 ≥ 50`). The majority-green-floor area lives with its full definition columns in `Output/tables/taskM_green_at_floor_area.csv`. **Quote it from there, not from here.**

The earlier **~4,300 ha is withdrawn**: it was a mismatched 8058-pixel conversion of the native-30 m count. The grid mismatch only ever explained the 6,458 ↔ 4,474 ha pixel-area pair — **never** the gap to any `veg_p05` figure, which was a different variable altogether.

**The total-cover floor** (`veg_p05` percentile sweep, T3) is a separate product with separate numbers. Any caption, table or slide touching either must name which variable it uses. This is the single most-confused pair of numbers in the project.

### Novel findings

A vegetation floor that is **mostly dead material at the median** — the *green share* of cover is ~3% (so ~97% non-green); this is a statement about **green share**, not about `veg_p50` or total cover — with a **majority-green-floor** tail (the refugia signal; green share > 50%; area and definition in `Output/tables/taskM_green_at_floor_area.csv`, not restated here). Community-structured lag response strengthening dry→wet. Headline caveat (confirmed): Landsat FC measures **cover, not structure** — it cannot separate land-use change from ecological condition. Adrian has pre-authorised a null as publishable.

**On deck:** deck restatement against the census (stocktake done — 36 slides), site reports (Deliverable 2, at 5 of 66), CSIRO HCAS 3.3 integration, output-folder restructure, T3/T4/T5.

## Standing conventions — do not re-litigate

- **One coordinate system:** everything analytical is **EPSG:8058** (GDA2020 / NSW Lambert). Reproject to new files or on read; never mutate originals.
- **One headline metric, end to end:** *between-year annual flood frequency* = `100 × wet-valid-years ÷ valid-years`. **The metric is one; the SUPPORT is two — always state which (C10).**
  - **Plot support** (~1 ha, **any-pixel rule**: a plot is wet if *any* of its ~16 pixels is wet; 66 plots) — *"how often does a 1-ha site see any water"*: Aeolian **9%** · Riverine **22%** · Inland Floodplain **50%** · Woodland/Forest 44% (context, treed, excluded).
  - **Pixel support** (24.97 m census pixel; all-pixel census, Tier2H) — *"how often is a 25 m pixel wet"*: Aeolian **6.1%** · Riverine **12.9%** · Inland Floodplain **28.0%**.
  - Both are correct and both are between-year. The 1.5–1.8× gap is `P(any of ~16 pixels) ≫ P(one pixel)`, **not** a within-year/between-year confusion (the within-year `annual_occurrence_pct` means are 4.0 / 11.6 / 31.2 — a different metric again, see C8). Never compare across supports, and never relabel one as the other.
  - **A third variant exists:** `v_inundation_change_by_vegetation_group` gives 8.4 / 21.1 / 38.5 / 38.9 — plot support restricted to the **post-conservation period**. Same metric, same support, different `period_label`.
  - `dim_metric.support` already stores these rules verbatim. **It is NULL on 36 of 45 rows** — populated for 7 pixel metrics and 2 plot metrics. Treat an unpopulated `support` as unknown, not as either.
  - **Known defect:** the science spine's S2 labels the plot-support 9 / 22 / 50 values "Support: stratum, pixel." The numbers are right; the label is wrong. Spine-chat fix, not a build fix.
- **Support levels are never merged.** Not plotted together, not compared numerically, not summed. A view combining two supports sets `support_level = 'mixed'` and carries a `mixed_support_note`. Plot and pixel support can **invert**: Task J's "two placebos beat 2018" at plot support became rank 2 of 25 at pixel support.
- **Figure pair per step:** a concept explainer + the data figure. **One figure = one file = one slide.** Insets/legends never overlap titles/captions.
- **Census display convention (H5):** never plot 1.08 M raw points — use hexbin / 2-D density or a CI band. **Never a naive large-N CI:** 1,080,157 pixels are spatially autocorrelated, not independent observations.
- **Review bundle per task:** after the acceptance gate passes, copy deliverables to `Output/review_bundles/tier{N}{X}_{name}/` and zip.
- **Workflow (standing git rule, adopted 28 Jul 2026 — supersedes the branch/PR flow above):** **commit straight to `main`, no draft branches, no PRs.** Per gate: **run `git fetch/status/log` at session start** and report branch tracking + whether `main` moved; do the work; **commit and push to `main` at each gate STOP** and report the SHA — pushing is backup, needs no approval, is never batched or deferred. **The in-chat gate review is the substantive gate; the GitHub merge was ceremony.** Still stop at each acceptance gate. **Never** force-push, rebase already-pushed work, commit rasters / the SQLite / large spatial data, or add AI-attribution trailers — **commits are authored solely by Hugh.** (The earlier branch-and-handback flow is retired; issues-log I-28.)
- **Simplest first; surface gated:** no probability surface unless a trend is real *and* roughly stationary. "No robust trend" is a legitimate, reportable result.

## Hard rules (verifiable — the acceptance gate should assert these)

- **Vegetation grouping: use the 4-class `simplified_vegetation_group`** (join `dim_plot`). NEVER use the legacy 5-class `vegetation_adrian_group`, and never let the pre/post `period` column leak into analysis outputs.
- **Metric discipline:** the headline (flood frequency) *defines strata*; the DB field **`annual_occurrence_pct` is the SECONDARY "wet-extent coverage" metric, not the headline** — despite the word "occurrence." Never present it as the headline.
- **Four-CRS discipline** (reproject before any join/extraction; confusing them is a live trap):
  - **EPSG:8058** — canonical analysis grid (all census products).
  - **EPSG:28355** — the native inundation stack (genuinely 25.0 m).
  - **EPSG:3577** — FC source rasters (30 m, before the single reproject to 8058).
  - **EPSG:9473** — `dim_plot` centroid columns (`centroid_x/y`) — *not* 8058; reproject centroids first.
- **FC band semantics — gate now CLOSED on the canonical grid.** All 18 `crs_epsg = 8058` rasters carry `legend_status = 'confirmed'` (percentiles, annual, inundation stack, flood zone, regime class, wet response, Task J difference). The JRSRP percentage-plus-100 offset does **not** apply to them; census `veg_p05` ranges [1.19, 91.85], confirming plain percent. FC arithmetic remains gated for any product **not** on the 8058 grid until its `legend_status` is confirmed.
- **Grazing is metadata**, not a covariate, in the current analysis.

## Database

`Output/database/Gayini_Results.sqlite` is authoritative (relational); `.gpkg` is the map companion; per-pixel data lives in an **external parquet** (never in SQLite), registered via `census_asset`; rasters are external, registered in `raster_asset`.

Current shape (verified 28 Jul 2026, post-T12): 85 tables, 30 views, `raster_asset` 166 rows (18 at EPSG:8058 + 38 DEA at EPSG:7854, all extents populated), `figure_asset` 278, `report_asset` 59, `spatial_layer_asset` 9 (spatial_007/008/009 = 8058 boundary/plots/communities), `census_asset` 2.

**T12 DEA Land Cover objects (documented negative — see below):** `dim_source_product` row `dea_landcover_l3`; `dim_dea_landcover_class` (7 LCCS codes); `fact_dea_landcover_{zone,plot,community,farm}_year`; `fact_dea_cultivation_assessment` (`rule_version='T12_prereg_v2_20260728'`); view `v_dea_zone_landuse_summary`; 38 DEA rasters in `raster_asset` (`product='dea_landcover_l3'`, EPSG:7854, calendar-year). **T12 closed as a documented negative:** DEA CTV carries no usable land-use signal at Gayini (§2.7 fired — no separated persistence mode, 2 `likely` zones < 5, farm swing 7.58×), and the 2 `likely` + 40 `possible` zone-era calls are **recorded false positives — never describe them as cultivated (§2.8).** DEA does **not** fill `cropping_history` (still NULL 64/64, now with evidence). See `docs/change_reports/T12_*.md` and `docs/Gayini_limitations_register_additions_T12.md`.

- **Consume via views, not raw `fact_*` tables.** Start at `v_plot_year_analysis_spine` (the modelling spine, 66×35) and `v_pixel_census_by_veg_regime` (census substrate).
- **The builder is destructive** (see Session start). The Python builder rebuilds from scratch (unlink + rebuild, no GDAL), so post-build steps **must be re-run in this exact order after any full rebuild:**
  `builder → 05_build_unified_annual_stack → 03_populate_raster_metadata → 09_build_pixel_census_view → 11_reproject_annual_stack_8058_nn → 01_prepare_inputs/05_populate_metric_support`
  (05 registers the `stack_annual_*` rows whose CRS/legend 03 completes; 09 reads the annual stack; 11 registers the EPSG:8058 NN stack; `05_populate_metric_support` re-adds `dim_metric.support`, absent from the builder's METRICS list). **This sequence is necessary but, post-Task-H, not sufficient:** the Task H products (the 5 percentile rasters, `flood_zone_8058`, `veg_regime_class_8058`, and `census_asset`) are additional manual registrations — confirm their re-registration steps from the Task H spec/change reports before any rebuild. **Also post-dating the builder:** the T1 additive schema changes (`figure_asset.support_level/figure_level`, `spatial_layer_asset.checksum_sha256/path_exists/field_list`) and `spatial_006`. A DB missing `raster_asset` rows, `v_pixel_census_by_veg_regime`, `census_asset`, or `dim_metric.support` has not had its post-build steps applied.
- `v_database_release_checks` and `v_current_qa_issues` are **point-in-time rows, not live computations** — several date from 2026-07-01 and are contradicted by current data. Re-derive before trusting them (see Provenance discipline).

## What is retired / archived (do not revive)

- **Pre/post *framing*** (2019/2020 management split) is retired — no pre/post products or figures in the main ladder; that pre/post code is archive-only. **Distinct from Task J:** the 2018 bank-cut pre/post is a separate, additive, Adrian-requested deliverable — do not archive it as "the retired pre/post."
- **Task F** (Monte-Carlo sampling rebalance) — **CANCELLED at the 15 July review** (superseded by the all-pixel census), not merely gated. Code stays on `main`, uncalled, additive-only; spec archived with a superseded header. Sub-sampling may be reused later.
- **MER** renamed to "annual maximum observed wet footprint" and kept **supplementary** only.
- **The ~4,300 ha refugia figure** — withdrawn (see D8 above). Do not reintroduce it from any older doc or deck.
- **Archive convention:** archived scripts go to `scripts/archive/` — but see the smoke-test conflict below.

## Known tooling conflicts (unresolved — human call with Adrian)

- **Archive convention contradicts the smoke test (B5).** The convention says archived scripts go to `scripts/archive/`, but `run_spine_smoke_test.R:104-112` (`folder_scripts/archive_absent`) **hard-fails if `scripts/archive/` exists.** The check's polarity is inverted against the convention it supposedly enforces. So `scripts/_deprecated/01_lag_diagnostics_inundation_gc.R` cannot be reconciled into `scripts/archive/` without breaking spine validation. Left untouched pending an Adrian decision; **do not modify the smoke test** to force it. (Deferred as B5 in the Task F spec.)

## Adrian gate

**Resolved by the 15 July review / census pivot** (do not reopen): Q1 near-plot radius — superseded by the all-pixel census. Q3a `MIN_VALID_COVERAGE = 40` — census uses `MIN_VALID_YEARS = 25` instead; the 40 rode in on a bypassed gate, left untouched in the extraction path. Q3b "is no-trend reportable" — **yes**, Adrian pre-authorised a null. Q2 vegetation units — three non-treed communities dry→wet, treed set aside (unchanged).

**Currently open (build with documented defaults, flag them):**

- **Deck ratification of the F6 census 9/0/0** — the open I.2 item.
- **Band definitions, round 2 (option 3):** tie-aware / absolute thresholds are the proper long-run fix; option 2 (F5 `regime_band_breaks.csv` edges) is a first-cut for stability. Gated on Adrian, post-presentation. H6 absolute flood-frequency zones are the candidate replacement.
- **Which percentile becomes canonical** — compute all five, recommend one; Hugh's decision.
- **Which floor threshold becomes canonical** (T3 Gate D) — a science decision that sets a number in the abstract; stays a STOP.
- **Nari Nari panel rendering** — recommend absolute zones (H6), single 5-class sequential map, plain-language legend.
- **Density/CI display convention** — request Adrian's own examples (#18).
- **CSIRO HCAS 3.3 integration** — flagged in Adrian's 15 July workbook; compare with inundation (independent), never with ground cover (circular — appendix consistency-check only).

## Canonical docs (read when relevant — source of truth, not this file)

- `Gayini_Figure_Driven_Project_Ladder.docx` — conventions, ladder, gate result. If it and this file disagree, the ladder wins on convention; on current state, this file's "Current state" is newer.
- `docs/Gayini_project_lineage_and_learnings.md` — **the trap index / cross-session memory.** Read at session start.
- `docs/Gayini_number_provenance_audit.md` — the twelve discrepancies, classified. Read before quoting any headline number.
- `docs/Gayini_sequential_task_list_20260715.md` — the post-pivot sequenced plan.
- `docs/Tier2_TaskH_all_pixel_census_v4.md` — the authoritative census spec (committed on `main`; D1 resolved).
- `docs/Gayini_pixel_census_data_contract.md` — the parquet H4 schema (columns: `flood_freq_pct`, `veg_p05..p50`; **no per-pixel total-veg column**).
- `docs/Gayini_established_data_facts.md` — settled numbers (community flood-freq means, flood-zone crosstab, refugia).
- `docs/Gayini_output_structure.md` — output-folder contract and migration plan.
- `docs/Gayini_Results_database_overview.md` — database structure and how to consume it.
- `docs/Gayini_Results_DB_contract_snapshot_*.xlsx` — full text rendering of the DB (objects, schema, registries, headline numbers). Survives project knowledge; regenerate at each Gate C.
- `docs/Gayini_limitations_register_*.xlsx` — Task J evidence register (current: v10).
- `docs/T1_zone_stratum_census_join.md` · `docs/T3_always_green_threshold.md` · `docs/T5_guardrails_and_checks.md` — current task specs. Each carries an amendment log; read it, because earlier versions were wrong.
- `docs/archive/Gayini_subsampling_approach.md` — **ARCHIVED** Monte-Carlo design; superseded by the census.
- `docs/Tier*_Task*.md` — executed/queued task specs.

## Notes for Claude Code

- Don't duplicate here what auto memory (`MEMORY.md`) infers from the code; keep this file to authoritative rules and pointers.
- **Commit change reports and the lineage/learnings doc** to `docs/` — they are the cross-session memory a fresh instance relies on. Other transient/ad-hoc reports may stay local. *(This supersedes the earlier "commit code only" preference.)*
- **A change report is not a home for a value** — it states findings and points at the `Output/` artefact. See Provenance discipline.
- **When a spec and this file disagree, report the disagreement rather than choosing.** Both have been wrong; the DB has not.
