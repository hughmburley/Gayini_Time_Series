# Gayini CC spec — HANDOFF-1

**The manifest for the handoff repository: what travels, what stays, what is orphaned.**
Design seat, 11 August 2026. Read-only. Moves nothing, copies nothing, deletes nothing.

---

## 0 · Standing execution rule

Run Gate A to completion in one pass and report once. Do not ask before writing. Halt only on: a
required input absent after searching; unresolved repository divergence.

`mode=ro`, `PRAGMA query_only=1` on all reads. Recon first — `git fetch`, `git status`,
`git log --oneline -10`.

**This task writes a manifest and nothing else.** It registers no number, renders no figure, runs no
analysis, and does not create the new repository. Every classification comes from the filesystem, a
live query, or a parsed import — **never from a caption, a folder name, a previous summary, or this
spec.**

---

## 1 · Why this runs, and the cap it runs under

The funded engagement is closed. Remaining work is **unpaid, capped at two to three days total**
across three deliverables, of which this is one. The `Gayini_Time_Series` repository has grown past
the point where a newcomer can find the load-bearing parts, and it is about to be handed to a PhD
student in Richard Kingsford's group via Adrian Fisher.

**The output of this task is a list, not a migration.** The design seat decides what travels; the
copy itself is a separate and much smaller act. **Do not create the new repository and do not move
files** — a migration performed before the list is reviewed cannot be un-reviewed.

**Scale is the point.** The value here is exhaustive traversal: following every import, source and
read call from a handful of entry points until the closure stops growing. That is not a judgement
task and it is not one a human does reliably at this size. **Where a judgement is required, this spec
supplies the rule; where the rule does not decide, the file goes to `UNRESOLVED` and the design seat
rules on it.** Do not invent a criterion.

---

## 2 · Build on what exists — do not redo it

**Task K Gate 0 already produced** a `workstream × essential` crosstab, a broken-pointer count, a
folder-shape analysis, and a candidate archive set of 431 files across 43 folders with a claimed zero
registry rows.

**Reconcile against it; do not re-derive it from scratch.** Report where this run's classification
disagrees with Task K's `essential` flag, in both directions, with the file named. Those
disagreements are the interesting output — a file marked essential then and orphaned now, or the
reverse, is either drift or a stale flag, and either way the design seat needs to see it.

Where Task K's classification and the dependency closure of §3 conflict, **the closure wins and the
disagreement is reported.** A flag set by hand months ago is weaker evidence than a parsed import.

---

## 3 · Gate A — dependency closure from the four entry points · **THE CORE**

The handoff repository exists to let someone reproduce four pipelines. Everything else is
downstream of that.

**The four entry points:**

1. Fractional cover → seasonal composites → per-pixel temporal percentile stack
2. Inundation scenes → counted flood-frequency surface, plus annual wet and valid layers
3. The census join — every pixel assigned to zone, part, paddock and community, emitted as Parquet
4. Zonal summary — any metric over any polygon set, with support recorded

**Identify the actual entry script for each**, by reading the code, not by filename. State which
script you selected and on what evidence. If an entry point has no single script — if it is three
scripts run in sequence, or a notebook, or does not exist as runnable code at all — **say so plainly
and name what does exist.** A pipeline described in a document but absent from the repository is a
finding, and it is the most important kind this task can return.

**Then compute the transitive closure.** From each entry point, follow:

- Python `import` and `from` statements resolving to repo-local modules
- R `source()`, and library calls resolving to repo-local files
- File reads and writes with literal or constructible paths
- Config, parameter and constants files
- SQL against `Gayini_Results.sqlite` — record **table and view names**, not just the file

Iterate until the set stops growing. **Report the closure size against the repository total** — that
ratio is the headline of this task.

**Where a path is constructed dynamically** and cannot be resolved statically, record it as
`UNRESOLVED_PATH` with the constructing expression. Do not guess, and do not execute the script to
find out.

---

## 4 · Classify everything the closure did not reach

Every remaining tracked file gets exactly one verdict:

| verdict | meaning |
|---|---|
| `MIGRATE` | in the closure, or required by §5 |
| `ARCHIVE` | real work, superseded or one-off; stays in the old repo, which is preserved |
| `ORPHAN` | no pipeline reaches it and no document cites it |
| `IP_HOLD` | would otherwise migrate, but §6 excludes it |
| `UNRESOLVED` | the rules here do not decide. Design seat rules |

**`ORPHAN` requires two negatives, both checked**: nothing imports it, and no tracked document
references it by name. A file cited in a methods document but reached by no code is not an orphan —
it is a documentation dependency, and it migrates.

**Do not treat recency, folder depth or filename as evidence.** A file in `_deprecated/` that the
closure reaches is `MIGRATE`; a file in the top-level scripts folder that nothing reaches is
`ORPHAN`. The folder name is a claim, not a measurement.

---

## 5 · What migrates besides code

**Documents.** The handover note, the README, the attribution statement, the established-data-facts
document, the census data contract, and the analysis variable lookup. Distilled governance only —
the number rules and the named failure patterns, not the dashboard and report governance, which has
no counterpart in a student's project.

**Data.** The census Parquet, the pixel–zone assignment, the counted flood-frequency surface, the
annual wet and valid stacks, and the polygon sets the four pipelines read. **Report each with its
size on disk, measured, not from any registry column** — `file_bytes` is NULL on 171 of 192 raster
rows and the registered volume figure has never been a computed quantity.

**Figures: almost none.** A handful that the handover note refers to, and only those. 341 registered
figures, 578 loose images and 336 paddock-report panels do not travel. Name the ones that do.

**The database — read §7 before classifying anything here.**

---

## 6 · The IP boundary — what must not travel

The portable, config-driven, site-agnostic form of these pipelines is **the commercial asset and is
explicitly out of scope**, paid or unpaid.

**The rule for this task:** Gayini-specific working code migrates as it is. **Anything that
generalises it does not** — configuration layers, site-agnostic wrappers, parameterised boundary or
CRS handling, packaging, and any abstraction whose purpose is to run this on a second property.

Mark such files `IP_HOLD`, listed separately with a one-line reason each.

**Do not build any of it.** If the closure reveals that a pipeline is *already* partly generalised,
report that; do not un-generalise it, and do not extend it.

**No NNTC material, no culturally sensitive layer, and no output identifying places on Country
migrates without review.** Where you are unsure whether a file falls in that class, `UNRESOLVED` —
flag it rather than deciding it.

---

## 7 · The database

`Gayini_Results.sqlite` **cannot be rebuilt.** The builder destroys manually registered rows, and no
non-destructive registration path exists. **Do not run the builder, do not `reset_file`, do not
propose a clean rebuild under any name.**

For this task, the database is classified at **table and view level, not file level**:

- Which tables and views the four pipelines actually read, from §3's SQL capture
- Which of those are the pinned-number registry and its dimension tables
- Which are dashboard, report or pack infrastructure with no pipeline reading them

**Report the counts and the list. Propose no extraction and perform none.** The design seat decides
whether the handoff carries the whole archived file or a derived subset, and that decision needs this
list to exist first.

---

## 8 · Blockers, stated separately

Two classes get their own section, because they are what stops a migration mid-flight:

**Essential-but-dead.** Any file in the closure that sits in a workstream Task K marked dead, or that
no current process maintains. Name each.

**Reached but missing.** Any path the closure requires that does not exist on disk. Check live —
**never consult `path_exists`**, which read 1 on all seven stale land-cover rows and cannot report
absence.

---

## 9 · Checks on this task's own checks

- **Coverage alongside verdict** (I-53). State how many tracked files were classified against the
  repository total, and how many the closure examined. A classification returning clean without
  having traversed anything is indistinguishable from one that passed.
- **A fixture that errors is not a fixture** (I-42). Any verification here must fail against a
  fixture returning a **wrong verdict**, not one that crashes.
- **Never resolve by identity of value** (I-56). Match files by path, imports by resolved module.
- **Deterministic emission** (I-46). `sorted()` before anything reaches a checksummed artefact.
- **Assert on the emitted manifest**, not on the logic that built it.

---

## 10 · Outputs

```
Output/audit/
  HANDOFF1_manifest.csv
  HANDOFF1_db_objects.csv
  HANDOFF1_report.md
```

**`HANDOFF1_manifest.csv`** — one row per tracked file:

| column | contents |
|---|---|
| `path` | repo-relative |
| `verdict` | `MIGRATE` · `ARCHIVE` · `ORPHAN` · `IP_HOLD` · `UNRESOLVED` |
| `reached_by` | which of the four entry points, or empty |
| `depth` | steps from the entry point in the closure |
| `cited_by` | tracked documents naming this file |
| `taskK_essential` | Task K's flag, for the reconciliation |
| `size_bytes` | measured on disk |
| `reason` | one line, required for every row that is not `MIGRATE` |

**`HANDOFF1_report.md`**, in this order:

1. **The closure ratio** — files reached against repository total — and the per-entry-point breakdown
2. **Any entry point with no runnable script**, named
3. The five verdict counts, with total migrating size
4. **The Task K disagreements**, both directions
5. Blockers (§8), both classes
6. `IP_HOLD` list with reasons
7. Database objects by class (§7)
8. `UNRESOLVED` list — every row, not a sample
9. What could not be determined, stated as such

Un-ignore under Ruling BB if needed, in the shape of CL. **Verify with `git check-ignore -v`, not by
reading** (I-60), and confirm by result — `git status --porcelain` plus a dry-run `git add` staging
exactly the intended paths.

---

## 11 · What this is not

It does not create the handoff repository. It does not move, copy, rename or delete a file. It runs
no analysis, registers no number, renders no figure, and touches the database only to read. It does
not harden reproducibility, and it does not generalise or package anything.

It does not decide the `UNRESOLVED` rows. **Returning them unresolved is success**, not an
incomplete run.

**The closure ratio and the `UNRESOLVED` list are the deliverables.**

**STOP at the end of Gate A.**

---

**Rulings in force:** BB, CL, DA, DB, DP, DS.
**Named patterns in force:** I-42, I-46, I-53, I-56, I-60.
**Supersedes:** the MIGRATE-1 sketch of 10 August, which assumed a funded window.
