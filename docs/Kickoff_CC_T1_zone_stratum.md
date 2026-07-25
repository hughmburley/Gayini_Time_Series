# Kick-off for Claude Code — T1 zone × stratum census join

**Date:** 25 July 2026
**Spec:** `T1_zone_stratum_census_join.md` **v2** — read it in full before doing anything
**Deadline context:** hard deadline in 2.5 weeks. Time is the binding constraint, not correctness of process. Do not gold-plate. Do not rebuild anything that exists.

---

## The one rule that matters most

**Nothing gets written until you have inventoried what already exists.**

This repo is at the end of a long project, not the start of one. Task F, Task H, Task J, Task M and the Tier-1 ladder have all already run. There is a very high chance that 60–80% of what T1 needs — the parquet reader, the stratum reconciliation, a point-in-polygon join, the SHA-256 helper, the additive-registration pattern, the figure writer — **already exists on `main` and works.**

Rewriting any of it is the single most expensive mistake available right now. It costs a day, produces a second implementation that will diverge from the first, and adds nothing.

So: **Gate 0 below is mandatory and it is read-only.** Do not skip it, do not compress it, and do not start it and then drift into writing code halfway through.

---

## Read first

In the repo:

- `CLAUDE.md` — repo conventions. **Note one conflict:** it says change reports stay local and uncommitted. The T1 v2 spec says commit them. **Follow the spec** — they are the cross-session memory now, because the SQLite is too large to live in project knowledge. Update `CLAUDE.md` to match as part of this task.
- `docs/Gayini_Results_database_overview.md`
- `docs/Gayini_pixel_census_data_contract.md` — the 16-column contract, and §8's `compareGeom()` requirement
- `docs/Gayini_output_structure.md` — where figures go, and the `_archive/` rule
- `docs/change_reports/` — **all of them.** These are the record of what has already been built. Read them before assuming anything is missing.

New, from the design seat:

- `T1_zone_stratum_census_join.md` **v2** — the spec. Its amendment log lists five corrections to v1; v1 is wrong on all five and must not be followed.
- `Gayini_Results_DB_contract_snapshot_20260725.xlsx` — a full text rendering of the live DB: every object, every column, the registries, the headline numbers, and sheet `18_GateA_findings` with the evidence behind the amendments. **Check this before querying the DB for structural facts** — it is faster and it is current as of today.

---

## Gate 0 — Inventory before code · read-only · **STOP**

No writes. No new files. No branches. Produce one short inventory note, then stop for review.

### 0.1 What code already exists that T1 would otherwise duplicate

Search `scripts/` and `R/` (and any `internal/` subfolders) for existing implementations of each of the following, and report **file, function name, and whether it is callable as-is, callable with arguments changed, or not reusable**:

| Need | Search terms |
|---|---|
| Read the census parquet | `parquet`, `arrow`, `read_parquet`, `census` |
| Reconcile to `census_stratum` | `census_stratum`, `reconcile`, `diff = 0` |
| Point-in-polygon / spatial join | `terra::extract`, `st_join`, `st_within`, `point.in.polygon`, `overlay` |
| **Existing plot→zone assignment** | `plot_management_overlay`, `management_overlay` |
| Raster zonal statistics | `zonal`, `terra::zonal`, `extract`, Task J scripts |
| SHA-256, first-50-MB convention | `sha256`, `digest`, `checksum`, `50` |
| Additive / idempotent registration | `INSERT OR REPLACE`, `register_`, `census_asset`, `raster_asset` |
| Figure write + register | `figure_asset`, `ggsave`, `register_figure` |
| Zone name parsing (`Bala 26ca` → `Bala`) | `zone_group`, `paddock`, `str_extract` |

**`plot_management_overlay` already exists in `Gayini_Results.gpkg`.** Something already assigns geometry to management zones. Find that code first — it is the closest existing analogue to T1 Gate C and it may be directly adaptable from 66 plots to 1.08M pixels.

### 0.2 What data and outputs already exist

- Query `census_asset`, `raster_asset`, `spatial_layer_asset`, `figure_asset` and report counts and `path_exists` failures.
- Confirm `Output/census/gayini_pixel_census_8058.parquet` exists and its checksum matches the registered value. **Do not rebuild the census.** It is registered, `qa_status = PASS`, verified 24 July 2026.
- Check whether `dim_management_zone`, `v_census_by_zone_stratum` or `gayini_pixel_zone_assignment.parquet` **already exist in any form** — including in `_archive/`, in a stale branch, or half-built from an abandoned run. If a partial version exists, report it; do not delete it and do not silently overwrite it.
- Report whether `management_zones_epsg8058.gpkg` exists on disk and what CRS its header declares.

### 0.3 Known landmines — confirm the current state of each

- `figure_asset` holds **139 rows from an unfiltered builder run on 1 July**. None of the current-ladder figures are registered. Do not treat those 139 as a model to copy.
- `scripts/_deprecated/` violates the `scripts/archive/` convention. Report whether it still exists. **Do not fix it in this task** — one concern per task.
- **`internal/` subfolders are live runtime wrappers**, `source()`d by the numbered scripts. Never archive them.
- `plot_rs_analysis_base.csv` is missing from the repo and blocks script `05`. Report whether it is still missing. Not T1's job to fix.
- `map_asset_index` has **two independent `rglob` scan sites** around line 2752. Any exclusion needs two edits, not one. Not T1's job, but know it exists.

### 0.4 Report format

One markdown file, `docs/change_reports/T1_gate0_inventory.md`, ≤ 2 pages:

1. **Reuse table** — for each of the nine needs in 0.1: the existing implementation, or "none found".
2. **Estimated new code** — how many new functions T1 actually requires, given what exists.
3. **Anything already built** that the spec assumes is missing.
4. **Any place the spec contradicts what you found**, with the evidence.

**STOP.** Wait for review. Point 4 is the valuable one — the spec was written from an uploaded snapshot, not from the repo, and it may be wrong about the code.

---

## Then run the spec

`T1_zone_stratum_census_join.md` v2, in order: **A0 → A → B → C → D**. Each of A0, A and D ends in a STOP for human review. Honour them.

Two of those gates exist specifically because v1 was wrong:

- **Gate A0** registers `management_zones_epsg8058.gpkg` in `spatial_layer_asset`. Until it runs, "resolve paths from the DB" and "input must be EPSG:8058" cannot both be satisfied — the only registered zone layer is EPSG:28355 behind an absolute Windows path into a zip.
- **Gate A step 5** must prove that `dim_spatial_unit`'s zone index refers to the same polygon as the gpkg `fid`, **using evidence other than the index itself**. The zone dimension came in through the MODIS context CSV, not the zone shapefile. v1 claimed this alignment was verified; it is not. If you cannot prove it, say so and proceed with `unit_id = NULL` and `unit_id_verified = 0`. That is the correct outcome, not a failure.

---

## Non-negotiables

These are all load-bearing. Every one of them is here because something went wrong.

- **Never re-run the builder.** `reset_file` rebuilds the DB from scratch and would destroy 12 Task H census rows it cannot reproduce. There is no version of "just re-run the builder" that is acceptable. Use additive `INSERT OR REPLACE`.
- **Additive only.** No deletes. Moves to `_archive/` only.
- **Idempotence is an acceptance criterion, not a nicety.** Run every registration step twice and show identical row counts and checksums.
- **Paths resolved from the DB**, never hardcoded.
- **Pixel area is `0.062351428` ha** (24.970268 m grid). Not 0.0625. The 25 m nominal inflates every area by 0.238% and has already contaminated one spec.
- **Nine non-treed strata** = `treed_context_flag = 0 AND regime_band <> 'context'`. The flag alone admits ten.
- **Four-CRS discipline:** 8058 canonical · 28355 inundation · 3577 FC source · 9473 plot centroids.
- **Never merge supports.** Every view carries `support_level` as a column, not a comment.
- **Report both area bases** — mapped 67,349.332 ha and true farm 85,910.8 ha. Never rebase one into the other.
- **Verify against data, not prose.** Including this document and including the spec. If a stated number disagrees with the table, the table wins and you report the discrepancy.

## Git — deliberately minimal

- **No branch. No PR. Commit directly to `main`.** Review happens at the STOP points.
- No AI attribution in commit messages — no `Co-Authored-By` trailers.
- Commit the code, the change report, and the small reconciliation tables. `Output/` is gitignored; do not try to commit the parquet or the rasters.
- Do not spend time on git housekeeping, history tidying, or rebases. It is not worth any of the remaining 2.5 weeks.

## Figures — six of them, and they gate the task

A gate does not close until its figure exists **and is registered in `figure_asset` in the same transaction that writes it.** Never write first and register later — that is exactly how 330 unregistered figures accumulated.

Output to `figures/diagnostics/` with the `T1_` prefix. Every caption states the support level. The full table is in the spec; the one that matters most is `T1_C_pixel_assignment_map.png`, because an 18% unzoned share looks identical in a table whether it is a real geometry gap or a join bug, and completely different on a map.

## Definition of done

- [ ] Gate 0 inventory delivered and reviewed
- [ ] Gates A0, A, D STOPs honoured with sign-off
- [ ] All acceptance criteria in the spec met, **verified against the tables** — not asserted in prose
- [ ] Idempotence demonstrated by an actual second run
- [ ] Six gate figures written and registered
- [ ] No existing table or view modified or dropped
- [ ] `docs/change_reports/T1_change_report.md` written and committed
- [ ] `CLAUDE.md` updated so its change-report rule no longer contradicts the spec

---

## If you get stuck

Stop and report rather than working around it. Specifically:

- If `management_zones_epsg8058.gpkg` is not 8058, **do not reproject.** Report and stop.
- If the census parquet checksum does not match, **do not rebuild it.** Report and stop.
- If a spec instruction cannot be satisfied because the repo differs from what the spec assumed, **report the contradiction rather than choosing an interpretation.** The spec was written from an uploaded snapshot; you are looking at the actual repo, and where you disagree you are probably right.
