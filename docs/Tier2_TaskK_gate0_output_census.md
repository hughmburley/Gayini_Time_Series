# Task K — Gate 0: independent Output census

*Design seat, 17 July 2026. Execution: Claude Code, branch-and-PR, held for human review.*

**Read first:** `docs/Gayini_output_structure.md` (contract), `docs/Gayini_established_data_facts.md` (§10 settled — do not re-open).

---

## 0. What this task is

Produce an **independent census of `Output/`** and a report a human reads before anything moves.

**This gate is READ-ONLY.** No file is created, moved, renamed or deleted inside `Output/`. No row is written to any database. The builder is **not** run.

The design seat has already produced numbers (§4 below) from a **17 Jul CSV snapshot** and an **uploaded copy** of `Gayini_Results.sqlite`. Neither is the live disk. **Your job is to re-derive them independently and disagree where the data disagrees.** A confirmation is useful; a contradiction is more useful.

**Do not fix anything you find.** Report it. Fixes are later gates.

## 1. Standing rules

- **ADDITIVE ONLY.** Nothing deleted. `_archive/` is a move, never a delete — and no moves happen in this gate anyway.
- **Verify against data, not reports.** A report is a claim; a table is evidence. Every finding ships the table it came from.
- Canonical CRS **EPSG:8058**.
- Claude never appears as git author or co-author. No AI attribution in commit messages.
- Commit **code and small results tables only** — never rasters or large spatial files.
- Archive convention is `scripts/archive/`, **not** `scripts/_deprecated/`.
- Stop at each gate. Do not proceed past a gate without human review.

## 2. Deliverables

| # | Path | What |
|---|---|---|
| 1 | `Output/diagnostics/taskK_gate0_census_<date>.csv` | one row per file, full flag set (§3) |
| 2 | `Output/diagnostics/taskK_gate0_registry_join_<date>.csv` | one row per registered asset × join outcome |
| 3 | `Output/diagnostics/taskK_gate0_checksum_verify_<date>.csv` | one row per checksummed asset |
| 4 | `Output/diagnostics/taskK_gate0_folder_shape_<date>.csv` | one row per folder |
| 5 | `Output/diagnostics/taskK_gate0_qa.json` | machine-readable verdicts (§5) |
| 6 | `docs/change_reports/taskK_gate0_<date>.md` | **the report we read** (§6) |

All six are committed. They are small tables and markdown.

## 3. The census — one row per file under `Output/`

Walk `Output/` recursively. **Include everything** — dotfiles, `.gitkeep`, `_archive/`, zips, aux.xml. Nothing filtered.

Columns:

| Column | Definition |
|---|---|
| `rel_path` | POSIX, relative to repo root, e.g. `Output/figures/F1_x.png` |
| `folder`, `name`, `ext`, `size_bytes` | |
| `modified_utc` | ISO 8601 |
| `sha256` | full-file. If cost is a problem, hash `< 50 MB` fully and record `sha256_status = skipped_large` for the rest — **say which in the report** |
| `depth` | count of `/` in `rel_path` |
| `registered_in` | `figure_asset` / `raster_asset` / `report_asset` / `census_asset` / `NULL`. **All four tables.** |
| `asset_id` | the registry PK, or NULL |
| `duplicate_name_group` | files sharing a `name` get a shared group id; else NULL |
| `content_duplicate_group` | files sharing a `sha256`; else NULL |
| `workstream` | §3.1 |
| `essential` | §3.2 |
| `essential_reason` | §3.2 — **mandatory whenever `essential != no`** |

### 3.1 `workstream` — who produced it

Derive from path and filename. Allowed values:

`ALL_PIXEL` · `LADDER` · `MER` · `MODIS` · `RS_coverage` · `background_scenarios` · `pre_post` · `tier1_bundles` · `old_deck` · `repo_audits` · `hydrology` · `ground_cover` · `infrastructure` · `unclassified`

The design seat's rules classify **79% (1,054 of 1,326)**; **272 remain `unclassified`**, concentrated in `Output/diagnostics/`, `Output/logs/`, `Output/csv/inundation/`.

**Do not force those 272 into a bucket to make the number look good.** `unclassified` is a legitimate, expected value and a finding in its own right. Report the residue by folder and propose rules only where a rule is genuinely evident. **If your rules classify markedly more or fewer than 79%, that is itself a finding — report the delta and the rule that caused it.**

### 3.2 `essential` — is anything live depending on it

**This is the flag that decides what migrates to the clean repo. It is not the same question as `workstream`, and conflating the two is the trap this gate exists to catch.**

Values: `yes` · `no` · `unknown`

Mark `essential = yes` if **any** of:

1. **In the builder's `CSV_INPUTS`** — `scripts/11_database/01_build_results_database.py:109-126`. Sixteen hardcoded paths; **the builder throws if one is absent.** Parse the dict from source; do not retype the list. → `essential_reason = builder_csv_input`
2. **Registered in `raster_asset` or `census_asset` with `crs_epsg = 8058`** — the canonical Task H products. → `canonical_8058_product`
3. **A current-ladder figure** — prefix `F1`–`F7`, `F5b`, `F5c`, `F5d`, `C1`, `D1`, `D2`, `D3`, `H2`, `H6`. → `current_ladder_figure`
4. **Resolved by `gayini_output_paths.R`** — `gayini_task15_input_specs()` lists candidate paths per logical input. Any candidate that **exists on disk and is the first existing candidate** is live. → `path_module_resolved`
5. **The census parquet, the SQLite, the gpkg, the 8058 vector gpkg.** → `core_store`

Mark `essential = unknown` where a file is referenced by code you cannot statically resolve, or where you are not sure. **`unknown` is strongly preferred over a guess.**

Everything else: `essential = no`.

> 🔴 **The trap, stated plainly.** `workstream = MER` does **not** imply `essential = no`.
> Four MER CSVs and two MODIS CSVs are in `CSV_INPUTS` and feed live staging tables:
> ```
> Output/csv/MER/mer_annual_max_by_plot.csv
> Output/csv/MER/mer_period_summary_by_plot.csv
> Output/csv/MER/mer_period_summary_by_vegetation_group.csv
> Output/csv/MER/mer_vs_annual_occurrence_raster_comparison_by_plot.csv
> Output/csv/MODIS/03_modis_ground_cover_context_full.csv
> Output/csv/MODIS/modis_context_units_summary.csv
> Output/csv/review_deck/mer_metric_comparison_table.csv
> ```
> MER **figures and rasters** are a superseded generation. Four MER **CSVs** are load-bearing.
> **Verify this independently. If you find it false, say so loudly** — it is the single most consequential claim in this spec.

**Report the `workstream` × `essential` crosstab.** Every `essential = yes` cell in a dead workstream is a migration blocker and must be listed by name.

## 4. Claims to test

Re-derive each. Report **measured vs claimed** and mark `MATCH` / `DIFFER`. **`DIFFER` is a valid, useful outcome — do not tune your method to force `MATCH`.**

### 4.1 Disk

| # | Claim |
|---|---|
| D1 | 1,326 files · 158 folders · 1.569 GB |
| D2 | `Output/figures` = 300 files in 21 folders; **131 at root, 169 in subfolders** |
| D3 | Ladder-prefixed files anywhere = **330**; at `figures/` root = **122** |
| D4 | The 330 collapse to **101 distinct stems** (161 pdf · 155 png · 14 svg; A/B/C are layout variants of one artefact) |
| D5 | **D2 site dashboards = 5 distinct sites**: `GA_001, GA_003, GA_019, GA_032, GA_052`. Target 66. **Deck claims 66.** |
| D6 | C1 = 21 paddocks (+1 farm-wide) · D1 = 4 · F5c = 4 · D3 = 3 strata |
| D7 | `fc_intermediate` = 6 files, 0.759 GB, **48.4%** of Output, **0 registry rows** |
| D8 | duplicate filenames = 382 files, 102.3 MB |
| D9 | 13 folders hold exactly one file; **16 hold zero** (pure wrappers); 47 (30%) hold ≤2 |
| D10 | Every `Output/figures` subfolder file is dated **≤ 9 Jul**; everything after is at root. Sole exception `review/redesigned_dashboards.zip` (9 Jul) = a zip of 27 Jun content |

### 4.2 Registry

| # | Claim |
|---|---|
| R1 | registered across all four tables = **287** (`figure_asset` 139 · `raster_asset` 109 · `report_asset` 38 · `census_asset` 1) |
| R2 | orphan = **1,039 (78%)** |
| R3 | **broken pointers = 0** — every registered path exists on disk |
| R4 | `figure_asset` has exactly **one** `run_id`: `db_build_20260701_114458`. **0 of 139 are ladder-prefixed.** All 330 ladder figures unregistered. |
| R5 | `raster_asset` has **split provenance**: 98 `db_build_*`, 6 `tier2H_h2`, 2 `tier2H_h30`, 1 `tier2H_h6`, **2 NULL** |
| R6 | `veg_regime_class_8058.tif` **is now registered** → facts §11 trap **C2 is stale** |
| R7 | `spatial_layer_asset` holds **5 absolute `D:\` paths**; `spatial_005` points into a **different repo** (`Murrumbidgee_Gauge_Workflow`) |
| R8 | `map_asset_index` is stale (C11) — compare its counts to `figure_asset`/`raster_asset`/`report_asset` and report the drift |

### 4.3 Builder — read the source, do not run it

| # | Claim | Where |
|---|---|---|
| B1 | `main()` calls **`reset_file(SQLITE_PATH)`** → `path.unlink()`. **The DB is deleted and rebuilt from scratch every run.** | `:3157`, `:250` |
| B2 | Asset discovery is **unfiltered `rglob("*")`** over `csv, figures, reports, rasters, diagnostics`. No exclusion. The 139 is a **stale snapshot**, not a filter. | `:1463` |
| B3 | **`map_asset_index` has a SECOND independent `rglob`.** An exclusion is **two edits, not one.** | `:2752` |
| B4 | Routing is by suffix: **PNG/JPG → `figure_asset`, PDF → `report_asset`.** So **161 ladder PDFs would register as *reports*.** | `:1518-1521` |
| B5 | **`census_asset` appears 0 times in the builder.** A rebuild drops it entirely. | grep |
| B6 | A rebuild cannot reproduce **12 rows**: 5 veg percentiles, `veg_regime_class_8058`, `flood_zone_8058`, 2×8058 stack, 2×28355 stack (`run_id` NULL), + `census_asset`. `crs_epsg`/`product`/`legend_status` are lost with them. | |

**B1 and B5 together are why the builder must not be run in this gate.** If you find B1 false — that the builder upserts rather than resets — **that is a major finding; report it and stop.**

### 4.4 Code

| # | Claim |
|---|---|
| C1 | Nine functions default to `out_dir = "Output/figures"` across `gayini_descriptive_figures.R`, `gayini_sampling_design_map.R`, `vector_prep_functions.R`. **Rule 3 of §4 is violated by a default argument.** |
| C2 | `gayini_output_paths.R` is a **fallback resolver**, not a contract: multi-candidate, first-existing-wins, logs `found_fallback`. **This is why drift never surfaced.** It already emits a `checks` tibble with `status` — the smoke test is most of the way written. |
| C3 | `scripts/_deprecated/01_lag_diagnostics_inundation_gc.R` exists → **violates the `scripts/archive/` convention.** Report whether a smoke test should have caught it. |
| C4 | `GAYINI_ROOT` defaults to hardcoded `D:/Github_repos/Gayini` in `09_qa/*` |
| C5 | Both `09_qa` checks validate **retired pre/post products** (facts §11) — QA is testing dead things |
| C6 | Two shadow figure registries exist, neither feeding the DB: `gayini_gradient_helpers.R:166` writes `Output/figures/figures_manifest.csv` (`step, kind, path, inputs, crs`); `gayini_figure_manifest.R` has a **richer** schema (`figure_id, priority, deck_section, intended_slide, caption, caveat, qa_status`) — **closer to what §4 rule 1 wants than `figure_asset` is** |
| C7 | Figure dirs written by code but **absent from disk**: `06_MER_inundation`, `12_lag_diagnostics` — dead writers |
| C8 | **`Output/csv/canonical/plot_rs_analysis_base.csv` IS present** (24 Jun, loaded, 66 rows in `stg_canonical_plot_rs_analysis_base`). A standing note calls it missing from the main RS repo — **confirm whether that note refers to a different location, and report.** |

## 5. Checksum verify — the check that has never run

`raster_asset` carries ~100 SHA-256 checksums and **nothing has ever verified them** (contract §5). Run it now, read-only, as the pre-migration baseline.

For every row in all four asset tables with a non-null checksum: recompute, compare, emit `asset_id, table, path, exists, checksum_recorded, checksum_actual, ok`.

**A failure here is a finding about the existing DB, independent of Task K. Do not fix it. Report it.**

Note the builder hashes with `sha256(path, max_bytes=50*1024*1024)` — **first 50 MB only**. If a recorded checksum is truncated-file and you compare against a full-file hash, **every raster over 50 MB will mismatch spuriously.** Match the builder's method, and **state in the report which method each comparison used.** This is a real trap: 5 veg percentile rasters are ~17 MB (safe) but `fc_intermediate` holds 381 MB and 353 MB files.

## 6. The report — `docs/change_reports/taskK_gate0_<date>.md`

Written for a human deciding what happens next. Lead with what's wrong.

1. **Verdict** — one line: is the design seat's picture (§4) correct?
2. **DIFFER table** — every claim that failed, measured vs claimed, and why. **This section first if non-empty.**
3. **Broken pointers** — the number. Non-negotiable baseline for later gates.
4. **Checksum verify** — pass/fail, method used, any truncation caveat.
5. **`workstream` × `essential` crosstab** — plus every `essential = yes` file sitting in a dead workstream, **listed by name**. These are the migration blockers.
6. **The `unclassified` residue** — how many, which folders, what rule would help.
7. **Folder shape** — total, single-file, zero-file, ≤2-file; deepest chains; worst files-per-folder.
8. **Builder hazards** — B1–B6 confirmed or refuted, each with the line number you read.
9. **Gate A readiness** — the design seat proposes archiving **431 files / 43 folders / 0 registry rows**: `review_bundles/tier1*` (274 files, 32 folders), `rasters/inundation_background` (138, 6), `figures/review_refresh` (19, 5). Expected after: **1,326 → 895 files, 158 → 115 folders.** **Confirm or refute the `0 registered` claim for all 431 — this is the claim the entire gate rests on.** If even one carries a registry row, say so.
10. **What you could not determine** — explicitly. `unknown` beats a guess.

## 7. Out of scope

- Moving, renaming, deleting **anything**
- Running the builder
- Writing to any DB
- Fixing the builder, the path module, the `out_dir` defaults, `_deprecated/`, C11, C12
- Registering the 330
- Building missing dashboards (site 5→66, paddock 4→21, stratum 3→9) — **that gap is Deliverable 2 and is gated. This task makes it visible; it does not close it.**
- Editing the deck

## 8. Acceptance

1. Six deliverables exist and are committed.
2. **`git status` shows no modification, move or deletion under `Output/`** other than the new `diagnostics/taskK_gate0_*` files.
3. `Gayini_Results.sqlite` **byte-identical** before and after — record its SHA-256 at start and end of the run and put **both** in the report.
4. Every §4 claim marked `MATCH` or `DIFFER`, none silently skipped.
5. Every `essential != no` row carries an `essential_reason`.
6. Report leads with DIFFERs if any exist.
7. Branch-and-PR. **Held.** No merge.
