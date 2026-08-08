# CLAUDE.md — Gayini remote-sensing environmental-change assessment

Project memory for Claude Code. Authoritative rules and pointers; keep it concise (loaded in full every session). Detailed context lives in the docs referenced at the bottom — read them when a task touches their area. **The "Session start" section below is mandatory, not optional.**

*Rewritten 29 July 2026. Supersedes the 25 July version. Changes: current state advanced through T1/T2/T6/T8/T9/T10/T12; `dim_headline_number` and the three number rules added; L-01 added; the report deliverable added; canonical-docs list rebuilt against the 29 July archive sweep.*

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
- `figure_asset` **pre-Gate-E rows remain an old-generation snapshot** (`run_id = 'db_build_20260701_114458'`, 139 rows) and need reconciliation against disk before being trusted. Rows carrying a task `run_id` are current.

---

## Provenance discipline — numbers, their homes, and their qualifiers

Twelve number discrepancies were found during the T1 cycle (`docs/Gayini_number_provenance_audit.md`). **None came from the database disagreeing with itself.** Every one came from reading a stale copy, opening the wrong object, or asking an underspecified question. These rules exist because prose versions of them were already present and were violated anyway — including by their own author.

### The database is the authority. Nothing else is.

- **Never establish a fact from a workbook, a change report, a spec, or a prior chat.** Those are renderings. Re-derive from the DB.
- **This includes the DB's own QA and release tables.** A row asserting "98 of 98 raster assets lack CRS/extent", dated 2026-07-01, is still present while all rows are populated. It misled four separate readers. Once `v_qa_freshness` exists (T5 Gate 2), read QA verdicts through it — anything older than the newest `workflow_run` reports STALE.
- `Gayini_Results_DB_contract_snapshot_*.xlsx` is authoritative for **object existence, schema and row counts**. It is **not** authoritative for QA verdicts. Check the as-of date on the sheet.
- **Project knowledge silently corrupts binaries** — every byte ≥ 0x80 becomes the UTF-8 replacement character. `.sqlite`, `.parquet` and `.gpkg` cannot live there; `.xlsx` and `.md` survive. That is why the snapshot workbook exists.
- **Project knowledge is a rendering too, and it drifts.** On 29 July it held a 5.8 KB CLAUDE.md against this file's 25.7 KB, T1/T2/T3 at v1 against v3/v2/v3, and an `established_data_facts` half the live length — and it misled a design-seat session into auditing documents that no longer existed in that form. **Refreshing project knowledge is part of any commit that changes a canonical doc.** Never diff against it; diff against the repo.

### The three number rules

Result numbers are the project's most reliable source of drift, because a spec is re-read in full at every gate and a number printed in one is re-injected every time. Measured 29 July: live docs range from 0.9 to 7.4 result-numbers per KB. The rules:

1. **A spec cites a `number_id`, not a value.** Every result number that reaches a deliverable lives in **`dim_headline_number`** (59 rows). A spec that needs one writes `see ref_grazed_floor_riverine (dim_headline_number)`. Parameters and acceptance criteria are exempt — see the classes below.
2. **Any document quoting a result value carries an as-of date and the `number_id`.** Without both it is a prediction, and the document says so in its header. `Gayini_locating_results_in_country_note.md` is the model.
3. **A document named in `dim_headline_number.decided_by` is never archived.** Those files are the provenance chain for every pinned number; they live in `docs/decisions/` and the archive sweep does not touch them. Currently: `T8_gateA_pin_decisions.md`, `T8_T9_T10_gateA_decisions.md`.

Three classes of number, only one of which is the problem:

| Class | Example | Verdict |
|---|---|---|
| **Parameter / contract** | `MIN_SEASONS = 50`, EPSG:8058, `PIXEL_AREA_HA`, 1,080,157 px | **Required.** These *are* the spec |
| **Acceptance criterion** | "values reproduce X within rounding" | **Required, and must name the `Output/` artefact.** T3 v3 does this correctly, and names v1's wrong values so they cannot be matched by accident |
| **Motivating result** | "the gap is −13.1 pp", "r = 0.710" | **Pollution.** Replace with a `number_id` |

**Worked failure, 28 July.** `Gayini_reference_state_methods.md` was written at 00:33 quoting community floor deficits of −19.6 / −11.7 / +1.1. The T8 pin decisions were taken at 07:02 the same day and pinned −10.46 / −4.49 / +1.08. The doc's values are the `spread_min` of a range it could not yet know existed. Nothing was done wrong; the document simply outlived its own accuracy by seven hours.

### `Output/` is the record; `docs/` is never a result

Task M's Gate A inventory found **33 of 43 stale floor-claim sites in `docs/`**, while the definition-complete statements sat in `Output/diagnostics/`. The computation wrote an honest record into `Output/`; `docs/` then propagated the number without its definition. This file was the end of that chain.

- **A number in `docs/` must cite the `Output/` artefact that produced it** — path, and registered asset id where one exists.
- **A change report states findings and where they live. It must never be the only home for a value.**
- **If a number cannot name its `Output/` artefact, write the pointer and omit the value.**

### No number travels without its five qualifiers

Store them as columns, never as prose:

1. **support_level** — pixel · paddock · stratum · property · plot · zone · zone_month
2. **scope_filter_sql** — the literal filter, e.g. `treed_context_flag = 0 AND regime_band <> 'context'`
3. **pixel_area_ha** — the constant used
4. **denominator_ha** — mapped 67,349.332 or true farm 85,910.8
5. **period_label** — `1988-2023`, `post_conservation`, or similar

Eight of the twelve discrepancies would have been caught on sight. `dim_headline_number` stores all five as columns, plus `spread_min`/`spread_max` — **the full range the value takes under defensible alternatives.** A number whose spread is wide is not a wrong number; it is an under-specified one, and the spread is the honest report.

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

### A check must not match the record of a correction

**Match the whole claim, not a substring of it. The note is the record; the sentence is the claim.**
This project writes corrections **visibly** — superseding headers, `*(corrected …, was X)*` notes,
retained superseded values — so a fragment match will find the quoted old value **inside the note
documenting its replacement** and report corrected data as still wrong (I-47, Ruling AK). The
convention is right and generates this failure mode by construction, which is why the rule sits
beside it.

**Ruling J's distinction from the other direction:** J says a check that *errors* is not a check that
*catches*. This says **a check that *fires* is not necessarily a check that *found* something.**

### Deterministic emission

**Any artefact whose checksum is compared must be emitted in a deterministic order.** Sets, dicts
and anything hash-ordered get `sorted()` before emission — Python randomises string hashing per
process, so an unsorted set makes a build output differ between runs from identical inputs (I-46,
Ruling V). `lint_guardrails.py`'s `hash_order` lint reports these; it is **advisory**, not enforcing,
because 97 sites exist and only those feeding a checksummed artefact matter. Triage before enforcing.

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

The lowercase names are the **builder's normalisation on import**; the gpkg companion is a build output, so it is correctly registered *nowhere* (`spatial_layer_asset` is an import registry — a build-output row there is a category error). `read_registered_layer()` refusing it is correct. A spec once declared `Area_MW` non-existent after inspecting the lowercase companion instead of the caps input.

### Every check must be able to fail

When you add a check, **prove it fires on a deliberately broken fixture and record the failure output in the change report.** A check that has never failed has not been tested; it has only been run.

**A check that ERRORS is not a check that CATCHES (Ruling J, 3 Aug 2026).** A fixture that makes the recompute crash proves only that the code path is reachable. **Drift detection requires a fixture that returns a WRONG VALUE the check must reject.** Worked case: a page-3 canary fixture that renamed a view column made the recompute raise `no such column` — discarded as invalid and replaced with a data-level drift (doubling a paddock's census pixels) that moved the value 34.59 → 51.40 and was correctly rejected. Same family as I-40: the record was there, the act was not.

Two live illustrations: the 1 July QA row returns PASS/FAIL from a stored snapshot rather than from the data, so it cannot notice being wrong — verdicts that are derivable should be **views that compute**, not rows that persist. And `folder_scripts/archive_absent` in the smoke test has **inverted polarity** against the archive convention (see Known tooling conflicts).

---

## What this project is

A spatially explicit remote-sensing assessment of flooding and vegetation on Gayini (Nimmie-Caira, lower Murrumbidgee), 1988–2023, for the Nari Nari Tribal Council via BCT and UNSW. Built as a **figure ladder** — simplest first, the probability surface last and gated on evidence. The 1 ha monitoring plots are **anchors, not the analysis unit**; the analysis operates on areas/strata/pixels.

**Deadline: 10 August 2026.** The primary deliverable is client-facing reports, not a manuscript.

## Current state (29 July 2026)

**Complete and merged:** Task H all-pixel census (1,080,157 px, 11 strata; parquet ↔ `census_stratum` diff = 0) · Task J 2018 bank-cut placebo (descriptive, not causal; sole blocker an unsent email to Jana — cut-date provenance L07, bank geometry L10) · F1–F7 · T1 zone × stratum join · T2 per-zone annual veg extraction · T5 Gate 1 · T6 third grazing arm · T8 pinned-number registry · T9 (closed at Gate A) · T10 through Gate C plus amendment A1 · T12 (closed as a documented negative) · D2 site dashboards (57 non-treed) · Task L rollout (21 paddock dashboards, veg×water panels, 20 paddock own-clouds).

**Open:** T3 (persistence surfaces, unbuilt) · T4 (deferred post-deadline) · T5 Gates 2–4 (deferred) · T7 (persistence recolour/vectorise, needs the LiDAR) · T11 (choropleths) · T13 (spec v1 written, `docs/reference_update/Gayini_T13_spec.md`; Gates A and B committed, Gate C in build — pre-registered classification, see §2/§5 of the spec before touching any threshold).

**Not started — the deadline item:** **57 site reports + 21 paddock reports.** Templates built and proven (`GA_036` 2-page site, `Bala 29ca` 4-page paddock; A4 landscape docx → PDF). Rollout is unstarted; `report_asset` holds evidence tables only.

**Dashboards:** site 57/57 · paddock 21/21 · stratum 3/9 · `F5c_paddock` flood-frequency 4/21.

**Decks:** `Gayini_Veg_samples_ALLPIXEL_v7` (39 slides, current) · `Gayini_reference_state_review_v3` (22 slides — **needs rebuild, ten numbers changed under T8**).

### The findings that constrain everything downstream

- **F6 census verdict: 9 no-trend · 0 non-stationary · 0 directional.** Supersedes the provisional plot-support 8/1/0 — the lone non-stationary (Riverine low) was a 40-point sparsity artefact (54.1% false-positive across 1,000 draws). Flood-pulse driven, not trending → no probability surface; the static F5 background flood-frequency surface **is** the flood-probability product.
- **The signal is in the floor.** p05 rises ~2.2× faster than p50 across the flood-frequency gradient. p05 is the shipping metric; p50 is nearly flat-high and undersells the flood signal. **This closes the "which percentile is canonical" question.**
- **"Conserved" is a management category, not a condition state.** Three of the four reference paddocks are indistinguishable from grazed ground across the full 35-year record; the fourth (Bala 29ca) is the outlier that produces every reference-state result, and its deficit is substantially explained by dryness. The reference–grazed gap **predates conservation management by ~30 years** and the convergence is monotonic from 1988, so it cannot be attributed to grazing exclusion. Distance-to-reference as originally specified is undefined in 6 of 9 strata.
- **Shared headline with the biodiversity deck: water, not management, organises this country.**
- **Headline caveat (confirmed):** Landsat FC measures **cover, not structure** — it cannot separate land-use change from ecological condition. Adrian has pre-authorised a null as publishable.

### L-01 — the management zone is not an ecological unit

**Read before writing any paddock-grain number.** Management zones were drawn for grazing rotation; they do not follow vegetation boundaries. A number computed at paddock grain averages across whatever ecological contexts the fence encloses, and where a paddock spans several communities that average describes no real place. 14 of 64 paddocks are below 75% single-community dominance. Bala 29ca is the extreme case (Inland 35% / Riverine 33% / Aeolian 32%) and its parts behave oppositely. A "sharpest management contrast" between two paddocks dissolved on decomposition — the difference was composition, not behaviour. **Decompose by community before attributing anything to a fence line.** Full note: `docs/reference_update/Gayini_learning_L01_unit_of_analysis.md`.

### The two floor findings are different findings — never conflate them

**D8 (FIXED, Task M).** `green_at_floor()` measures the **green share of remaining cover** (`100 × PV ÷ total_veg > 50`, paired at each pixel's total-veg p05, on the native 30 m EPSG:3577 grid) — **not** total cover (`veg_p05 ≥ 50`). The majority-green-floor area lives with its full definition columns in `Output/tables/taskM_green_at_floor_area.csv`. **Quote it from there, not from here.**

The earlier **~4,300 ha is withdrawn**: a mismatched 8058-pixel conversion of the native-30 m count. The grid mismatch only ever explained the 6,458 ↔ 4,474 ha pixel-area pair — **never** the gap to any `veg_p05` figure, which is a different variable altogether.

**The total-cover floor** (`veg_p05` percentile sweep, T3) is a separate product with separate numbers. Any caption, table or slide touching either must name which variable it uses. This is the single most-confused pair of numbers in the project.

## Standing conventions — do not re-litigate

- **One coordinate system:** everything analytical is **EPSG:8058** (GDA2020 / NSW Lambert). Reproject to new files or on read; never mutate originals.
- **One headline metric, end to end:** *between-year annual flood frequency* = `100 × wet-valid-years ÷ valid-years`. **The metric is one; the SUPPORT is two — always state which (C10).**
  - **Plot support** (~1 ha, **any-pixel rule**: a plot is wet if *any* of its ~16 pixels is wet; 66 plots): Aeolian **9%** · Riverine **22%** · Inland **50%** · Woodland/Forest 44% (context, treed, excluded).
  - **Pixel support** (24.97 m census pixel): Aeolian **6.1%** · Riverine **12.9%** · Inland **28.0%**.
  - Both are correct and both are between-year. The 1.5–1.8× gap is `P(any of ~16 pixels) ≫ P(one pixel)`, **not** a within-year/between-year confusion (the within-year `annual_occurrence_pct` means are 4.0 / 11.6 / 31.2 — a different metric again, C8). Never compare across supports, and never relabel one as the other.
  - **A third variant exists:** `v_inundation_change_by_vegetation_group` gives 8.4 / 21.1 / 38.5 / 38.9 — plot support restricted to the **post-conservation period**. Same metric, same support, different `period_label`.
  - `dim_metric.support` stores these rules verbatim but is **NULL on 36 of 45 rows**. Treat an unpopulated `support` as unknown, not as either.
- **Support levels are never merged.** Not plotted together, not compared numerically, not summed. A view combining two supports sets `support_level = 'mixed'` and carries a `mixed_support_note`. Plot and pixel support can **invert**: Task J's "two placebos beat 2018" at plot support became rank 2 of 25 at pixel support.
- **Figure pair per step:** a concept explainer + the data figure. **One figure = one file = one slide.** Insets/legends never overlap titles/captions.
- **Census display convention (H5):** never plot 1.08 M raw points — use hexbin / 2-D density or a CI band. **Never a naive large-N CI:** 1,080,157 pixels are spatially autocorrelated, not independent observations.
- **Review bundle per task:** after the acceptance gate passes, copy deliverables to `Output/review_bundles/tier{N}{X}_{name}/` and zip.
- **Git (standing rule, adopted 28 Jul 2026):** **commit straight to `main`, no draft branches, no PRs.** Per gate: run `git fetch/status/log` at session start and report branch tracking and whether `main` moved; do the work; **commit and push to `main` at each gate STOP** and report the SHA. Pushing is backup — it needs no approval and is never batched or deferred. **The in-chat gate review is the substantive gate; the GitHub merge was ceremony.** Still stop at each acceptance gate. **Never** force-push, rebase already-pushed work, commit rasters / the SQLite / large spatial data, or add AI-attribution trailers — **commits are authored solely by Hugh.**
- **Git staging (adopted 2 Aug 2026): never `git add -A` or `git add .`** Stage **explicit named paths only.** Concurrent sessions share one worktree, and a blanket add sweeps another session's untracked work into your commit under your message. **This has happened twice** (2 Aug: a TaskU commit absorbed REM-1's in-progress change report and three issues-log rows; a second session committed between REM-1's gates). Nothing was lost either time — which is why the rule is being written now rather than after something is.
  **Concurrent sessions:** if two CC sessions must run at once, the second uses `git worktree add` to get its own directory and branch. **One worktree, one session, when writes are involved.**
- **Registered-row amendments, by field class (Ruling F, 3 Aug 2026).** Spec §7's *never modify a registered row* is **refined, not overridden**. **Amendable in place** under explicit design-seat direction, and logged: `caveat` · `decision_note` · `label` — these carry meaning *about* a number, not the number. **Never amendable — a change is a NEW ROW and a supersession:** `pinned_value` · `spread_min` · `spread_max` · `support_level` · `scope_filter` · `pixel_constant` · `denominator` · `period_label` · `source_object` · `number_id`. The 31 July `floor_flood_*` precision correction remains the single genuine one-off against that second list.
- **A ruling is only a ruling if it can be quoted (I-43, 3 Aug 2026).** If a decision cannot be quoted from a design-seat message, it is a **proposal** and it stops at a STOP. Two artefacts have asserted rulings that were never issued — the AUD-1 delta's `reason_detail` on T1, and the P4 assembly report's "3 August §2 §3 §5" — and the second propagated into the assembled pack folder.
- **Simplest first; surface gated:** no probability surface unless a trend is real *and* roughly stationary. "No robust trend" is a legitimate, reportable result.

## Hard rules (verifiable — the acceptance gate should assert these)

- **Vegetation grouping: use the 4-class `simplified_vegetation_group`** (join `dim_plot`). NEVER use the legacy 5-class `vegetation_adrian_group`, and never let the pre/post `period` column leak into analysis outputs.
- **Metric discipline:** the headline (flood frequency) *defines strata*; the DB field **`annual_occurrence_pct` is the SECONDARY "wet-extent coverage" metric, not the headline** — despite the word "occurrence." Never present it as the headline.
- **Four-CRS discipline** (reproject before any join/extraction; confusing them is a live trap):
  - **EPSG:8058** — canonical analysis grid (all census products).
  - **EPSG:28355** — the native inundation stack (genuinely 25.0 m).
  - **EPSG:3577** — FC source rasters (30 m, before the single reproject to 8058).
  - **EPSG:9473** — `dim_plot` centroid columns (`centroid_x/y`) — *not* 8058; reproject centroids first.
  - *(**EPSG:7854** — GDA2020/MGA54. The 38 T12 DEA rasters, **and** the 2021 LiDAR `d4` tile. Not an analysis grid.)*
  - *(**EPSG:7855** — GDA2020/MGA55. The 2021 LiDAR `d5` tile only. Added Task U Gate U1. Not an analysis grid.)*
  - **The LiDAR delivery spans three of these** — 28355 (2009 `m5`), 7854 (2021 `d4`), 7855 (2021 `d5`) — and 2021 is **two complementary MGA-zone tiles of one capture**, not one dataset in two projections. Mosaic under Task U's R1 (`d4` precedence, never averaged).
- **FC band semantics — gate CLOSED on the canonical grid.** All 18 `crs_epsg = 8058` rasters carry `legend_status = 'confirmed'`. The JRSRP percentage-plus-100 offset does **not** apply to them; census `veg_p05` ranges [1.19, 91.85], confirming plain percent. FC band max is 147, not 111. FC arithmetic remains gated for any product **not** on the 8058 grid until its `legend_status` is confirmed.
- **Grazing is metadata**, not a covariate, in the current analysis.

## Client deliverables — reports

The 57 site + 21 paddock reports are the contract deliverable. Rules baked into the template:

- **Scope lock in every footer:** non-treed ground, whole paddock, full record. Treed sites are dropped from reporting entirely (66 → 57 sites; Bala 29ca's children 13 → 10).
- **Headline cover metric is `veg_p05_spatial`**, not the census temporal p05. **Two p05 objects exist and must never be called by the same name.**
- **Site and paddock flood-frequency rules differ**, and the footer says so.
- **Cover is described as "how much and how green", never as a condition score.** Recovery narratives attribute no cause.
- **Sensitivity notice** — *Internal review · culturally sensitive — review with Nari Nari Tribal Council* — in the title block and run-head of every document.
- **A standing "what we don't know" panel** absorbs the missing land-use history rather than blocking on it.
- **T12 DEA cultivation results never appear in a client deliverable.** Documented negative; the 2 `likely` + 40 `possible` zone-era calls are recorded false positives.

**Rendering traps (cost hours; do not rediscover):**
- Every docx table must use `TableLayoutType.FIXED` with an explicit `width` on each cell, and the column grid must sum exactly to the declared table width. Word ignores `columnWidths` without fixed layout; **LibreOffice honours them, so the failure is invisible until opened in Word.**
- An image paragraph must **never** carry `spacing: { line: N }` — it clamps the line box and squashes the picture to ~⅓ height while the XML extents stay correct.
- matplotlib: **never** `bbox_inches='tight'` — it silently changes the aspect ratio and breaks the doc builder's width-to-height calculation. Declare `figsize` and set `subplots_adjust` explicitly.

## Database

`Output/database/Gayini_Results.sqlite` is authoritative (relational); `.gpkg` is the map companion; per-pixel data lives in an **external parquet** (never in SQLite), registered via `census_asset`; rasters are external, registered in `raster_asset`.

Current shape (verified 29 Jul 2026): **86 tables, 30 views**, `raster_asset` 166, `figure_asset` 278, `report_asset` 59, `spatial_layer_asset` 9, `census_asset` 2, `dim_management_zone` 64, `dim_metric` 45, **`dim_headline_number` 59**.

**`dim_headline_number` is the pinned-number registry** (built T8, 28 Jul). One row per headline number, carrying `source_object`, `grain`, `aggregation_order`, `series_variant`, `scope_filter`, `period_label`, `denominator`, `pixel_constant`, `support_level`, `pinned_value`, `spread_min`/`spread_max`, `caveat`, `decided_by`, `decision_note`. Rows with `pinned_value` NULL are deliberately unpinned and carry the reason. `test_T8_headline_reproduction.py` re-derives the pinned values by an independent code path and fails on drift; it runs standalone and is **not** wired into the smoke test (that suite carries permanently-red checks — wiring in would buy the appearance of coverage rather than coverage).

**T12 DEA objects (documented negative):** `dim_source_product` row `dea_landcover_l3`; `dim_dea_landcover_class` (7 LCCS codes); `fact_dea_landcover_{zone,plot,community,farm}_year`; `fact_dea_cultivation_assessment` (`rule_version='T12_prereg_v2_20260728'`); view `v_dea_zone_landuse_summary`; 38 DEA rasters. DEA CTV carries no usable land-use signal at Gayini and does **not** fill `cropping_history` (still NULL 64/64, now with evidence).

- **Consume via views, not raw `fact_*` tables.** Start at `v_plot_year_analysis_spine` (the modelling spine, 66×35) and `v_pixel_census_by_veg_regime` (census substrate).
- **TWO OBJECTS ARE BOTH CALLED "THE CENSUS" AND THEY SIT ON DIFFERENT WATER SURFACES (Ruling DM, 9 Aug 2026). Name them, never say "the census" alone:**
  - **the census VIEW** — `v_pixel_census_by_veg_regime`, 11 rows. Its only water content is `band_freq_lo_pct` / `band_freq_hi_pct`, the per-community tercile boundaries, and those were cut on the **INTERPOLATED** surface (`background_flood_frequency_8058.tif`, counted on 28355 then resampled). `veg_regime_class_8058.tif`'s band **membership** was assigned the same way.
  - **the census PARQUET** — `Output/census/gayini_pixel_census_8058.parquet`, 1,080,157 rows. Its `flood_freq_pct` is **COUNTED on the 8058 grid** from `inundation_annual_stack_8058`, verified 9 Aug to agree with `flood_frequency_counted_8058.tif` to 0.00e+00 on every cell. **This is the analysis source of truth for water.**
  - **Audited 9 Aug (Ruling DR, closed with no correction required): no registered headline number, figure or table takes a water QUANTITY from the view.** The view's only water content is `band_freq_lo_pct` / `band_freq_hi_pct`, and those reach **exactly two consumers** — the class raster's band assignment, and the client README's class table. **Both are marked.** Its other consumers (`29_build_s12_stratum_coverage_figure.R`, `30_fix_d2_census_view_farm_basis.R`) take **areas and counts, not water**. The interpolated surface is retained, never deleted, and is not used for anything quantitative.
  - **The tercile boundaries are a documented design trade-off, not a defect (Ruling DQ).** Balanced strata are unreachable on the counted surface — 35 distinct values, 25,000–50,000 cells on every candidate boundary, a recut landing on 41.6 / 30.2 / 28.2% instead of thirds. The measured size of the choice: **4.9%** of non-treed cells change band under the same breaks on the counted surface, **9.8%** under a full recut (Riverine 14.8%, Aeolian 14.0%, Inland 8.0%). `veg_regime_class_8058.tif` does not move before 10 August; **any future recut is a separate ruling** weighing balanced strata against surface consistency.
- **The builder is destructive** (see Session start). Post-build steps **must be re-run in this exact order after any full rebuild:**
  `builder → 05_build_unified_annual_stack → 03_populate_raster_metadata → 09_build_pixel_census_view → 11_reproject_annual_stack_8058_nn → 01_prepare_inputs/05_populate_metric_support`
  **This sequence is necessary but, post-Task-H, not sufficient:** the Task H products (5 percentile rasters, `flood_zone_8058`, `veg_regime_class_8058`, `census_asset`) are additional manual registrations — confirm their re-registration steps from the Task H spec before any rebuild. **Also post-dating the builder:** the T1 additive schema changes (`figure_asset.support_level/figure_level`, `spatial_layer_asset.checksum_sha256/path_exists/field_list`), `spatial_006`, and every T2/T6/T8/T10/T12 object. A DB missing `raster_asset` rows, `v_pixel_census_by_veg_regime`, `census_asset`, `dim_metric.support` or `dim_headline_number` has not had its post-build steps applied.
- `v_database_release_checks` and `v_current_qa_issues` are **point-in-time rows, not live computations** — several date from 2026-07-01 and are contradicted by current data. Re-derive before trusting them.

## What is retired / archived (do not revive)

- **Pre/post *framing*** (2019/2020 management split) is retired — no pre/post products or figures in the main ladder; that code is archive-only. **Distinct from Task J:** the 2018 bank-cut pre/post is a separate, additive, Adrian-requested deliverable — do not archive it as "the retired pre/post."
- **Task F** (Monte-Carlo sampling rebalance) — **CANCELLED at the 15 July review**, not merely gated. Code stays on `main`, uncalled, additive-only; spec archived with a superseded header. Sub-sampling may be reused later.
- **The F9 trend/change surface** — retired. No directional signal exists to extrapolate.
- **MER** renamed to "annual maximum observed wet footprint" and kept **supplementary** only.
- **The ~4,300 ha refugia figure** — withdrawn (D8). Do not reintroduce it from any older doc or deck.
- **The five-period gap split** — no producing script exists anywhere in the repo (I-29). Superseded by the T10 Gate B annual gap series and marked so in `dim_headline_number`. **Not to be revived.**
- **Archive convention:** archived scripts go to `scripts/archive/` — but see the smoke-test conflict below.
- **Archived docs live in `docs/archive/`** with a three-line header naming what superseded them and what they are retained for. **`docs/decisions/` is never archived** (number rule 3).

## Known tooling conflicts

- **Archive convention contradicts the smoke test (B5).** `run_spine_smoke_test.R:104-112` (`folder_scripts/archive_absent`) **hard-fails if `scripts/archive/` exists**, while the convention says archived scripts go there. So `scripts/_deprecated/01_lag_diagnostics_inundation_gc.R` cannot be reconciled without breaking spine validation. **Do not modify the smoke test to force it.** The check was written for a handoff that should ship no archived code; the convention has since changed. The correct fix asserts the real invariant — *no active script `source()`s anything under `scripts/archive/`* — rather than the folder's absence. Human call; use `lint_guardrails.py` exit 0 as the acceptance signal meanwhile.
- **The smoke test is permanently red** (I-11): exits 1 on `structure/folder_scripts/10_downstream_optional` missing, plus three `outputs` warnings. **A permanently-red test is ignored exactly like a permanently-green one.** Resolve or retire it post-deadline.

## Adrian gate

**Resolved — do not reopen:** Q1 near-plot radius (superseded by the census) · Q3a `MIN_VALID_COVERAGE = 40` (census uses `MIN_VALID_YEARS = 25`) · Q3b "is no-trend reportable" (**yes**, pre-authorised) · Q2 vegetation units (three non-treed communities dry→wet, treed set aside) · **which percentile is canonical (p05, settled by the Task L diagnostics)**.

**Currently open (build with documented defaults, flag them):**

- **Deck ratification of the F6 census 9/0/0** — open I.2 item.
- **Band definitions, round 2:** tie-aware / absolute thresholds are the long-run fix; H6 absolute flood-frequency zones are the candidate replacement. Post-presentation.
- **Which floor threshold becomes canonical** (T3 Gate D) — sets a number in the abstract; stays a STOP.
- **Reference definition** — narrow set / per-stratum / environmentally defined (HCAS 3.3) / report heterogeneity as the finding. **Pre-register the decision rule before computing any trajectory number.** This is the standing guard against management pressure shaping the metric.
- **Nari Nari panel rendering** — recommend absolute zones (H6), single 5-class sequential map, plain-language legend.
- **CSIRO HCAS 3.3 integration** — compare with inundation (independent), never with ground cover (circular — appendix consistency-check only).
- **Sentinel-2 extension** beyond WY2022–23 — Landsat-only first; a sensor step change could masquerade as real change.

## External blockers

- **Ernest** — was the drier western part of Bala 29ca cleared or cropped? Fills `dim_management_zone.cropping_history` and four RESERVED columns. T12 already failed to answer this from satellite; there is no second route.
- **Jana** — 2018 cut-date provenance (L07) and bank geometry (L10). Sole remaining blocker on Task J.
- **Adrian's LiDAR shrub-height model** — unblocks the refugia × structure two-sensor test (T7 produces the GeoPackage).

Build what the data supports and name the gap in the caption. **Do not gate on any of these.**

## Canonical docs (read when relevant — source of truth, not this file)

- `docs/Gayini_project_lineage_and_learnings.md` — **the trap index / cross-session memory.** Read at session start.
- `docs/Gayini_number_provenance_audit.md` — the twelve discrepancies, classified. Read before quoting any headline number.
- `docs/Gayini_established_data_facts.md` — settled measured properties, with provenance lines.
- `docs/Gayini_issues_log.md` — open build/process defects and the triage rule (*does this change a number that reaches a deliverable?*).
- `docs/reference_update/Gayini_learning_L01_unit_of_analysis.md` — paddock grain vs ecological unit.
- `docs/Gayini_science_spine_v1.docx` — the manuscript story. **Wins on narrative framing;** this file wins on current state. *(The Figure-Driven Project Ladder is archived — it was the pre-census framing.)*
- `docs/Gayini_reference_state_methods.md` — reference-state design and its limits. **Its §7 community deficits predate the T8 pins; re-derive from `dim_headline_number`.**
- `docs/Gayini_pixel_census_data_contract.md` — the parquet H4 schema.
- `docs/Gayini_output_structure.md` — output-folder contract. Migration itself is **parked** (I-16); §4 remains the standing rule for where new outputs go.
- `docs/Gayini_Results_database_overview.md` — DB structure and how to consume it. **Regenerate — it states 66/20 against a live 86/30.**
- `docs/Gayini_Results_DB_contract_snapshot_*.xlsx` — full text rendering of the DB. Survives project knowledge; regenerate at each Gate C, **and delete predecessors on write** (I-17: multiple dated copies of one artefact is discrepancy class #1).
- `docs/Gayini_limitations_register_*.xlsx` — scientific limitations (current: v10; T2/T6/T12 additions staged and pending merge to v11).
- `docs/decisions/` — pin and gate decisions. **Never archived** (number rule 3).
- `docs/T3_always_green_threshold.md` (v3) · `docs/T4_spine_evidence_workbook.md` (deferred) · `docs/T5_guardrails_and_checks.md` (v2) · `docs/Gayini_reference_state_specs_T7_T11.md` · `docs/Gayini_T10_v2_spec.md` + `_amendment_A1_gateC.md` — current task specs. Each carries an amendment log; read it, because earlier versions were wrong.
- `docs/archive/` — superseded specs and completed task cards. **Never a source for a number.**

## Notes for Claude Code

- **NEVER EDIT THROUGH A SHELL HEREDOC WHEN THE EDIT CONTAINS AN ESCAPE (Ruling DS, 9 Aug 2026).** Any edit containing an escape sequence, a newline, or a quoted string spanning more than one line is **written to a file and applied from that file**. **Parse-check before rendering.** A chained heredoc silently mangles `\n` — it produced a file that still parsed but held a literal line break inside a string, and it did so **three times in two days**. Verifying the content afterwards remains the backstop, but it is no longer the primary defence: **a check that fires three times in two days is a control in the wrong place.** See I-60, second surface.

- Don't duplicate here what auto memory (`MEMORY.md`) infers from the code; keep this file to authoritative rules and pointers.
- **Commit change reports and the lineage/learnings doc** to `docs/` — they are the cross-session memory a fresh instance relies on. Other transient reports may stay local.
- **A change report is not a home for a value** — it states findings and points at the `Output/` artefact.
- **When a spec and this file disagree, report the disagreement rather than choosing.** Both have been wrong; the DB has not.
- **Flag, don't choose.** Every significant error in this project was caught at a STOP — the wrong gpkg, the twin degeneracy, the Bala confound, the >100 FC values. The flagging is not the drag; the drag was treating every flag as equally urgent. Use the issues-log triage rule.
