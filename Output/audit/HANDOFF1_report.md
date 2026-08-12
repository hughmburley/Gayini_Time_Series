# HANDOFF-1 Gate A — what travels, what stays, what is orphaned

**12 August 2026.** Read-only. Moves nothing, copies nothing, creates no repository, registers no
number. The database was opened `mode=ro` with `PRAGMA query_only=1`.

**Rulings in force:** BB, CL, DA, DB, DP, DS. **Patterns honoured:** I-42, I-46, I-53, I-56, I-60.

---

## 1 · The closure ratio — the headline

**13 of 881 tracked files, 1.5%.**

That is not a rounding of a bigger number. The four pipelines are carried by thirteen files:
five entry scripts and eight R function libraries, none of which sources anything further. The
libraries are leaves — `gayini_helpers.R`, `gayini_veg_regime_functions.R` and the rest contain zero
`source()` calls between them. Everything the pipelines consume beyond that is **data**, which is
untracked by design.

| entry point | selected script | evidence | reaches |
|---|---|---|---:|
| **EP1** percentile stack | `scripts/05_ground_cover/02_build_total_veg_percentile_rasters.R` | header names Task H H2 and the five across-series percentile rasters on the 8058 grid | 5 |
| **EP2** flood frequency | `scripts/03_inundation_products/05_build_unified_annual_stack.R` | builds `annual_wet_any` / `annual_valid_any`, the layers everything counts from | 5 |
| **EP2b** counted surface | `scripts/03_inundation_products/BQ_build_counted_flood_frequency.py` | Ruling BQ as amended by CY | 1 |
| **EP3** census join | `scripts/03_inundation_products/15_build_pixel_census_parquet.R` | header cites the data contract and the 1,080,157-row Parquet | 6 |
| **EP4** zonal summary | **no such script exists** | see below | — |

Adding the documents and data §5 requires brings the migrating set to **21 tracked files, 365 KB**.

### Two things the entry-point selection turned up

**EP2 is two things wearing one name.** The spec describes a single "counted flood-frequency surface,
plus annual wet and valid layers". The counted surface's own header says it is *"a MAP PRODUCT for
the client and a VERIFICATION ARTEFACT… NOT an analysis input — the counted per-cell values already
exist as `flood_freq_pct` in `gayini_pixel_census_8058.parquet`, which stays the source of truth."*
So the analysis chain runs through the annual stack into the census Parquet, and the counted surface
hangs off the side. Both are listed; only the first is load-bearing.

**EP4 does not exist as runnable code, and this is the most important thing in the report.** There is
no general "any metric over any polygon set, with support recorded" script. What exists instead is a
family of task-specific loaders — `T2_gateC_load.py`, `T6_gateC_load.py`,
`T2_gateF_gap_decomposition.py`, `PARTREG_stage*.py` and others — each hard-wired to its own metric,
its own polygon set and its own output table, plus extraction helpers in `R/` used by the figure
code. **A student handed the other three pipelines cannot produce a zonal summary of a new metric
without writing one.** The capability is described in documents and does not exist as a component.

### The constants discipline is not enforced at the entry points

**None of the four entry scripts references `gayini_params`** — the file CLAUDE.md names as the only
place a project constant may appear. The lint enforces it repository-wide, but the pipelines that
define the numbers do not import it.

---

## 2 · Verdicts

| verdict | files | note |
|---|---:|---|
| `MIGRATE` | **21** | 13 closure + 8 documents required by §5 · **365 KB** |
| `ARCHIVE` | **782** | real work, referenced by something, no pipeline reaches it |
| `ORPHAN` | **75** | nothing references it and no document names it |
| `UNRESOLVED` | **3** | design seat rules |
| `IP_HOLD` | **0** | see §5 |

**881 of 881 tracked files classified. 13 examined by traversal, 881 by reference index.**

**On `ORPHAN`.** The spec requires two negatives and both are checked: nothing references the file
*and* no tracked document names it. A first pass tested only document citations and returned 261
orphans — it had conflated *outside this closure* with *referenced by nothing*, which is the
resolve-by-coincidence error. Corrected, it is 75. **Several are this week's own audit outputs**
(`INVENTORY_20260809.md`, four `RUN_*` notes, several `DOC*`/`FIG*` findings). They are orphans by
the letter of the rule — nothing cites them yet — not by merit. Recency is not evidence either way,
as §4 says, so they are reported as the rule found them.

---

## 3 · The Task K reconciliation — it cannot be done, and why

**Task K Gate 0 ran, and its outputs are not on `main`.** Commits `8778962` (Gate 0) and `dc13650`
(Gate A) live only on `origin/tier2k-gate0-output-census` and `origin/tier2k-gateA-archive`. Neither
is an ancestor of HEAD. The census — 1,351 rows with `essential` flags, plus the registry join,
folder shape and checksum verification — is **absent from the working tree and invisible to anyone
reading the repository**. They date from before the 28 July "commit straight to main, no PRs" rule.

I recovered the census from the branch (`git show origin/tier2k-gate0-output-census:…`) and loaded
all 1,351 flags: **168 essential, 1,183 not.**

**The reconciliation §2 asks for is then almost empty, by construction: only 3 tracked files carry a
Task K flag at all, and none disagrees.** Task K censused files under `Output/`; HANDOFF-1 classifies
*tracked* files, which are overwhelmingly code and documents. The two populations barely intersect.

That is not a null result. It means **Task K's `essential` flags say nothing about what migrates**,
and the design seat should not expect them to. The disagreements §2 hoped for cannot exist.

---

## 4 · Blockers

### Reached but missing — 63 paths, checked live

Never read from `path_exists`. The pipelines reference 63 paths that are not on disk. Most are
gitignored data — expected, and not blockers. **The ones that matter are the polygon sets and the
census Parquet**, because §5 requires them to travel and they are not in the repository to copy:

`CA0561_ManagementZones.shp` · `Gayini_Vegetation-classes-use.shp` · `gayini_boundary.shp` ·
`gayini_hectare_plots.shp` · `gayini_pixel_census_8058.parquet`

These exist outside the repo (the Parquet is at `Output/census/`, gitignored). **The migration must
source them from disk, not from git**, and someone has to be told where.

Two `Output/csv/` inputs referenced by the ground-cover chain are absent from disk entirely and are
listed in the manifest.

### Dynamic paths — 65 expressions

Recorded as `UNRESOLVED_PATH`, not guessed and not executed. They are `file.path()` and f-string
constructions inside the closure files. None is a blocker on its own; together they mean **a static
manifest cannot be complete**, and the copy step should be verified by running the pipelines, not by
trusting this list.

### Essential-but-dead

None identifiable. Establishing it needs Task K's workstream flags joined to tracked files, and §3
shows that join is empty.

---

## 5 · IP_HOLD — empty, and that is the finding

**No file in the closure carries generalisation.** The thirteen are Gayini-specific working code:
hard-coded CRS, hard-coded grid, hard-coded property boundary. §6 asks that if the closure reveals a
pipeline is *already* partly generalised, that be reported — **it does not**. Nothing was
un-generalised and nothing was built.

The commercial asset — the portable, config-driven form — **does not exist in this repository**, so
there is nothing to hold back. The boundary is intact because the work was never done.

---

## 6 · Database objects, at table and view level

**130 objects: 5 read by the pipelines, 13 registry or dimension tables, 112 that no pipeline reads.**

Read by the four pipelines: `census_asset` · `census_stratum` · `raster_asset` ·
`v_plot_timeseries_inundation_annual` · `v_plot_year_analysis_spine`.

**The pipelines touch 4% of the database.** The remaining 112 are dashboard, report, pack and
task-specific fact tables. No object referenced by the closure is missing from the file.

**No extraction is proposed and none was performed.** The builder was not run, nothing was reset, and
no clean rebuild is suggested under any name — it destroys manually registered rows and there is no
non-destructive path. Whether the handoff carries the whole archived file or a derived subset is the
design seat's call, and this list exists so that call can be made.

---

## 7 · UNRESOLVED — all three

| file | why |
|---|---|
| `R/diag/UNZONED_v3_armA_figures.R` | substantive Country / cultural-sensitivity references beyond a footer notice |
| `scripts/13_dea_landcover/T12_close_figures.R` | same, and T12 is the documented land-use negative whose outputs never reach a client deliverable |
| `scripts/13_dea_landcover/register_T12_close_figures.py` | as above |

**A first pass returned 16.** It matched the bare word "sensitive" and the `dim_plot` **column name**
`cultural_sensitivity` — a schema field called cultural_sensitivity is not culturally sensitive
content. Narrowed to substantive references, it is 3. Returning them unresolved is the intended
outcome, not an incomplete run.

---

## 8 · Checks on this task's own checks

**Wrong-verdict fixtures, 4 of 4 pass.** Each returns a false *answer* if the closure is broken; none
crashes it (I-42).

| fixture | expected | got |
|---|---|---|
| one entry point only | closure must shrink | 13 → 6 |
| no entry points | closure must be empty | 0 |
| restored | closure must return | 13 |
| untracked entry point | must reach nothing, and say so | 0, reported |

Fixtures 1–3 are the convergence pair the Gate B learnings call the stronger form: remove the
evidence and the answer moves, restore it and the answer returns. A closure that had frozen its
answer passes a stability test and fails this one.

**Coverage stated (I-53):** 881 of 881 tracked files classified; 13 reached by traversal; 130
database objects; 1,351 Task K flags loaded; 63 missing paths and 65 dynamic expressions recorded.

**Assert on the emitted manifest (I-53):** the CSV is re-read after writing and checked for row count
against `git ls-files`, sort order, legal verdicts, and a mandatory `reason` on every non-`MIGRATE`
row. All passed.

**Deterministic emission (I-46):** every table sorted before writing, explicit `\n` terminator.
**Matched by path, never by value (I-56):** imports resolved to tracked paths; ambiguous basenames
resolved by folder proximity, and ambiguity is recorded rather than guessed.

**Two of my own rules were wrong and were corrected mid-run**, both the same shape — a confident,
non-crashing, wrong answer: the `ORPHAN` test checked one negative instead of two (261 → 75), and the
sensitivity test matched a column name (16 → 3).

---

## 9 · What could not be determined

- **Whether the 75 orphans are dead or merely uncited.** The rule cannot tell, and the spec forbids
  using recency or folder as evidence. They are listed, not judged.
- **Whether the 782 `ARCHIVE` files divide into superseded and one-off.** Nothing in the corpus
  records which.
- **Whether the pipelines actually run.** Nothing was executed. The closure is static; the 65 dynamic
  paths mean a static manifest cannot be complete, and the copy should be verified by running.
- **Essential-but-dead**, for the reason in §4.

---

## 10 · What this is not

It did not create the handoff repository, move, copy, rename or delete a file, run any analysis,
register any number or render any figure. It did not harden reproducibility and it generalised
nothing.

**It does not decide the three `UNRESOLVED` rows.**

**STOP at the end of Gate A.**
