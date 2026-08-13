# Gayini — repo rebuild spec (REPO-REBUILD v2)

**Supersedes** REPO-REBUILD v1 and all earlier Gate A / Gate B instructions.
**Date** 13 August 2026. **Design seat** Hugh.

---

## 0 · What this job actually is

**Making sense of work already done.** Nothing here requires new analysis. The traces, the
provenance and the conventions all exist already — in the database, in the census parquet, in
the two metadata records. The job is to find them, reconcile them, and carry the live parts
into a clean repository.

If a step feels like it needs original analysis, it is probably a step that should be reading
something instead. Stop and say so.

### 0.1 Disk is king

Everything is a file: the `.sqlite`, the `.parquet`, the rasters, the scripts, the metadata
records. **Read the files.** Chat history, session memory and recollection are not evidence —
if a finding is not written to a file, it does not exist, and the next session will re-derive
it. That is the failure this project keeps hitting.

Two consequences:

- **A registry silence is a gap in the registry, never evidence of absence on disk.** Most of
  `scripts/` is not named in any registry. That does not make it excludable.
- **When two files disagree, the more recently maintained wins.** `CLAUDE.md` says "all 18"
  rasters are legend-confirmed; the database says 29 of 45 `confirmed`, 16 `unconfirmed`,
  counted 7 Aug 2026. **Read the column, not the sentence.** Assume other `CLAUDE.md` prose
  has decayed the same way.

### 0.2 Freeze the old repo. Refactor only in the new one.

The old repo gets **completion, not improvement**. Finish what is outstanding, tag it, stop.

Every restructure, rename, reorganisation, documentation pass and dependency cleanup happens
in the **new** repo. Do not refactor a repository you are about to stop using.

---

## 1 · Verified facts — do not re-derive

Confirmed independently on 13 Aug 2026. Recompute only if you suspect a change.

**The data spine is the pixel census parquet, not SQLite.** SQLite holds **no pixel-level
rows**; its largest table is 141,638. Every pixel-grain quantity is computed from
`Output/census/`. `census_asset` registers the parquet by path and checksum; it does not
contain it.

| Check | Result |
|---|---|
| `gayini_pixel_census_8058.parquet` SHA-256 | matches `census_asset` exactly |
| `gayini_pixel_zone_assignment.parquet` SHA-256 | matches `census_asset` exactly |
| Rows, each file | 1,080,157 = `SUM(census_stratum.n_pixels)`, 11 strata |
| Census | 1,080,157 cells · 67,349.3 ha |
| Non-treed (`treed_context_flag = 0 AND regime_band <> 'context'`) | 988,831 · 61,655.0 ha |
| Zoned non-treed | 795,602 · 49,606.9 ha |
| Unzoned non-treed | 193,229 · 12,048.1 ha |
| Unzoned by community | Inland 129,360 · Riverine 50,791 · Aeolian 13,078 |
| `veg_p05` range | [1.19, 91.85] — plain percent, no JRSRP offset |
| `zone_fid` distinct | 64 = `dim_management_zone` |

**Untracked/ignored reconciliation — settled by CC, no discrepancy.** 184 untracked
(13.5 MB), 64 ignored `.docx`/`.pdf` (23.9 MB) via `.gitignore:132`, 248 on disk (37.4 MB).
`du` and `git status` answer different questions.

**Builder currency — settled by CC.** Three copies exist; `feature/reports` is newest in
every file (8 Aug vs 4 Aug). The nested bundle is a superseded snapshot.

### 1.1 Standing conventions

| Convention | Value |
|---|---|
| Water year naming | by **start** year; WY1988–WY2022, 35 years |
| Cell side / area | 24.970268 m · 0.062351428 ha — **never 0.0625** (inflates by 0.238%) |
| Canonical grid | EPSG:8058 |
| Whole record / cropping era / post-management | 1988–2022 (35) · 1988–2013 (26) · 2018–2022 (**5, not 6**) |
| Transition | 2014–2017 sits in **no** period |
| Non-treed scope | 9 strata. `treed_context_flag = 0` **alone admits 10** |
| Vegetation grouping | 4-class `simplified_vegetation_group`; 5-class is retired |
| Analysis variant / cover metric | `mean_of_seasons` · `veg_p05_spatial` |

---

## 2 · Rules

1. **The old repo is private and goes to no one.** No sanitisation, no redaction, no
   withholding. Any decision made on "may be read by the funder" is void — that premise was
   wrong.
2. **Delete nothing, anywhere.** Not from the old repo, not during the copy.
3. **No `git merge`.** Additive extraction only. (CC was right to stop; the merge instruction
   in v1 was wrong.)
4. **New repo built fresh.** `git init`, first commit. Never clone-and-filter.
5. **Verify, don't assume.** Recompute registered figures from the source artefact and report
   both numbers. §1 was built this way.
6. **Report deltas, not inventories.**

---

## 3 · Stage 1 — Finish and freeze the old repo

### 3.1 Recover `feature/reports` — CC's counter-proposal, accepted

Extract all 115 files to `scripts/15_reports/` — their natural live path, not
`Output/archive/`. Additive, no merge, no conflict, no exposure for
`docs/Gayini_issues_log.md`. Two collision files to a branch-named subfolder. Leave the branch
in place as provenance.

`hold/r13-r9-r11` — no action; complete subset of `feature/reports`.
Task K branches — recover as originally specified. 14 files, zero collisions.

### 3.2 Commit the held files, unredacted

`Gayini_status_change_20260811.md` (including the `$20k` line at L151),
`David_wright_notes.md` / `.txt`, `Gayini_Notes.txt`, and the remaining 2 of 4 under
`docs/Audit/`. This repo goes to no one.

### 3.3 Leave the nested bundle where it is

Superseded snapshot, untracked, in a private archive. Moving it is refactoring, and §0.2 says
refactoring happens in the new repo. Not worth a step.

### 3.4 Tag and stop

Tag `archive/pre-rebuild-20260813`. Push. **After this, the old repo is read-only.**

**STOP. Report.**

---

## 4 · Stage 2 — Read the registries, report deltas

Read-only. Start from the registries because they are indexed; then check the filesystem for
what they miss.

`census_asset` (2) · `workflow_run` (14) · `source_file` (547) · `dim_headline_number` (156)
· `qa_check` (47) · `diagnostic_issue` (11) · `figure_asset` (352) · `raster_asset` (192) ·
`report_asset` (60) · `table_asset` (14) · `spatial_layer_asset` (9) ·
`spatial_review_flags` (9, for GA_016/029/006/007/022/066).

Report only:

- **Registry gaps.** Files on disk that matter and no registry names. Expect several — the
  parquet is registered but most of `scripts/` is not.
- **PARTREG.** `dim_headline_number` cites *"PARTREG coefficient tables"* as `source_object`
  for `cap_weighted_r2_whole_record` (0.472497), `_cropping_era` (0.467553),
  `_post_management` (0.335391). **No PARTREG table exists in SQLite.**
  `Gayini_metadata_ground_cover.md` §7 cites *"PARTREG Stage 1 §2.5, fits `2.5_p05`…`2.5_p50`"*.
  Find the code, the spec, and the coefficient outputs on disk. This is the core regression.
- **`pixel_census_data_contract/2026-07-16`** — `census_asset.schema_version` names it. Find
  it. It is an existing documentation artefact.
- **`workflow_run.repo_commit` is NULL on all 14 runs.** Recover where inferable; mandatory
  going forward.
- **Chain coverage.** §6 lineage records exist for ground cover and inundation. Mark every
  other chain covered or uncovered: PARTREG, report builder, LiDAR (Task U), DEA landcover
  (T12), gauge, zone-stratum (T1), biodiversity import.

**STOP. Report.**

---

## 5 · Stage 3 — Trace, both directions

Read-only. Scope from the registries; confirm against disk.

**Target A** — paddock report outputs. **Target B** — the workshop regression.

Traverse **both** directions from the spine:

- **Upstream** — producers of the pixel census parquet and of the SQLite tables
- **Downstream** — consumers, including `scripts/15_reports/` and the producers behind
  `figure_asset`, `table_asset`, `report_asset`

Backwards-only tracing drops the report builder, which reads from the database and writes to
none of it. That builder is the contract deliverable.

**Do not use `workflow_run.is_current` as an exclusion filter.** Verified counter-example:
`census_zone_assignment_8058` is the currently registered zone assignment and its `run_id` is
`T1_gateC`, which carries `is_current = 0`. Report `is_current = 0` reachability; never act
on it.

Output: entry points, execution order, inputs and outputs per stage, external raster
dependencies, companion database paths — and everything under `scripts/` reached by neither
trace. Write it to the tables in §5.1, not to prose.

### 5.1 Write the trace to the database, not to a markdown file

**The project has no script registry.** The data dictionary documents ten artefact classes —
tables, fields, metrics, views, QA rules, source files, spatial layers, rasters, known issues,
release checks — and code is the only thing with none. `source_file` holds 547 paths, zero of
them `.py` or `.R`. This is why the dependency graph gets re-derived every session: there is
nowhere to record it.

Create two tables **in the new repo's copy of the database** (the old repo is frozen, §0.2).
Follow existing conventions: `*_asset` naming, `checksum_sha256`, `path_exists`, `qa_status`,
`run_id`.

**`script_asset`** — one row per script

| field | content |
|---|---|
| `script_id` | stable slug |
| `path` | repo-relative |
| `language` | R / Python / JS |
| `purpose` | one line — what it does, not what it is called |
| `chain` | ground_cover · inundation · partreg · reports · lidar · t12_dea · gauge · zone_stratum · bio |
| `stage_order` | position within its chain |
| `entry_point` | boolean |
| `reached_by` | trace_A · trace_B · both · neither |
| `status` | live · superseded · unknown |
| `metadata_record` | the §6 document covering it, or NULL — this column *is* the documentation backlog |
| `checksum_sha256`, `path_exists`, `last_modified` | as elsewhere |
| `run_id`, `repo_commit` | **populate `repo_commit`; do not repeat the NULL habit** |
| `note` | free text |

**`script_io`** — one row per input or output, the edge table

| field | content |
|---|---|
| `script_id` | FK to `script_asset` |
| `direction` | input · output |
| `artefact_type` | parquet · sqlite_table · raster · csv · figure · report · gpkg · external |
| `artefact_ref` | path, or SQLite table name |
| `asset_id` | FK to `census_asset` / `raster_asset` / `table_asset` / `figure_asset` / `report_asset` / `source_file`, where one exists |
| `note` | free text |

Together these make the scope rule executable rather than interpretive: core is whatever
`script_io` connects to a registered input or a registered output, in either direction.

Register the build itself as a `workflow_run` row **with `repo_commit` populated**.

`script_asset.metadata_record` being NULL is the honest measure of how much of §6 remains to
write, and it should read NULL for PARTREG on the first pass.

**STOP. Report.**

---

## 6 · Stage 4 — Build the new repo, then refactor there

**Carry over:** all code reached by the Stage 3 traces · the pixel census parquet
(`Output/census/`) · inputs the traces identify (`selected_input_csv`, rasters, companion
databases) · outputs for the core analyses · `Gayini_Results.sqlite` (with `script_asset` and
`script_io` from §5.1), `.gpkg`, the data dictionary and its README · the metadata records · insight and findings summaries **named
individually by Hugh**.

**Exclude:** audit records, handoff specs, gate reports, status changes, working notes,
scoping and budget material, delivered bundles, superseded drafts, anything that is
effectively chat transcript.

**Then, and only in the new repo:** restructure directories, normalise naming, document, and
resolve the LFS question. `total_veg_annual_mean_8058.tif` is 609,233,006 bytes and the
parquet is 26.7 MB, so decide between LFS and the external-asset pattern `raster_asset`
already uses.

**Documentation standard — already exists, do not invent one.** `Gayini_metadata_*.md` §6:
per chunk, what it does, script and line numbers, inputs, parameters with reasoning, outputs
with counts, **and the check that passed together with what would have failed it.** Plus §7
decisions register and §8 known error sources. Where a choice is an unexamined habit rather
than a ruling, say so — the ground cover record does this for `quantile(type = 7)` and
8-connectivity, and it is the most useful thing in the document. **PARTREG first.**

**Acceptance test.** A student clones the new repo, follows the README, regenerates the
database from registered inputs, regenerates the outputs from the database, and rebuilds the
paddock reports — without the old repo, without asking Hugh, without touching anything
outside it.

**Report before the first commit:** total size, any file over 100 MB, proposed structure,
README rebuild instructions. **Do not push until approved.**

---

## 7 · Open questions — do not guess

1. Does the workshop regression live on `main`, on `feature/reports`, or on another unmerged
   branch?
2. Which insight and findings summaries go across? Named files only.
3. Do the companion biodiversity and gauge databases go to the student, given the sensitivity
   defaults in `README_Gayini_Results_database.md` and the six `spatial_review_flags`?
4. External rasters: copied, or pointers plus a fetch script?
