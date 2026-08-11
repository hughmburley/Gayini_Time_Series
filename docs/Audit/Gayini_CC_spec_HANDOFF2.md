# Gayini CC spec — HANDOFF-2

**The migration: copy the manifest into a new tree, then prove it builds.**
Design seat, 12 August 2026. Copies only. Moves nothing, deletes nothing, modifies nothing in the
source repository.

**Blocked on HANDOFF-1.** Do not start this until the manifest exists and the design seat has signed
off on its `UNRESOLVED` rows. If HANDOFF-1 has not run, halt and say so.

---

## 0 · Standing execution rule

Three gates, each ending in a **STOP**. Run to the STOP, report, wait. This task is the only one in
the project that creates a second tree, and a wrong copy is harder to notice than a wrong number.

`mode=ro`, `PRAGMA query_only=1` on every read of `Gayini_Results.sqlite`. Recon first — `git fetch`,
`git status`, `git log --oneline -10`.

**The source repository is the archive and is now immutable.** Every operation here is a **copy**. Do
not use `move` or `rename` in any form; do not delete from the source; do not modify the source's
`.gitignore`, its database, or any tracked file. If a migration step appears to require changing the
source, that is a finding — report it and stop.

---

## 1 · The destination, and what it is for

A working tree on disk at a path the design seat supplies. **Not a GitHub repository** — the client
creates that afterwards, privately. **Not a clone.**

**Fresh `git init`.** A clone would inherit 294 commits, every file ever committed, and a
`.gitignore` encoding decisions about 43 folders that will not exist here. The working tree would be
clean and the history would not.

The lost authorship history is a real cost and is paid with one line in the README: *the full
development history is preserved in the archived `Gayini_Time_Series` repository, private, available
on request.* **Do not attempt to import selected history.** Partial history is worse than none — it
implies completeness it does not have.

**Write a new `.gitignore` from scratch. Ten lines or so.** Do not copy the source's. Verify it with
`git check-ignore -v` and by result — `git status --porcelain` plus a dry-run `git add` — never by
reading it (I-60).

Working name `gayini-floor`; the design seat may rename before the repository is created. **Do not
hard-code the directory name anywhere inside the tree.**

---

## 2 · Gate A — plan the copy · **STOP**

**Produce the copy plan and copy nothing.**

Read HANDOFF-1's manifest. Every `MIGRATE` row maps to a destination path. Report:

- The count and total size of files to be copied
- The destination tree, as a listing
- Any `MIGRATE` row whose source file is **absent from disk** — checked live, never via a stored
  existence flag, which read true on seven rows eleven days after the files moved (R7)
- Any destination collision — two source paths mapping to one destination
- Any `UNRESOLVED` row still unresolved. **These do not travel.** List them; do not decide them

**The intended shape**, subject to what the manifest returns:

```
README.md              clone to running pipeline
ATTRIBUTION.md         authorship, sources, reuse terms
CLAUDE.md              working rules, distilled
docs/                  methods (frozen), key takeaways, established facts, data contract
R/  scripts/           the dependency closure — the four pipelines
data/README.md         what to fetch, from where, how big, what CRS
outputs/               small tabular outputs only
sidelines/             off-mainline work, unsupported
```

**Where the manifest and this shape disagree, the manifest wins and the disagreement is reported.**

### 2.1 · Data does not travel

**No raster, stack or large Parquet is copied.** TRACE-1 measured 15.64 GB on disk; GitHub rejects
single files above 100 MB and degrades well below a gigabyte. The census Parquet alone is 1,080,157
rows.

Instead, **generate `data/README.md` from measured properties, not from a registry column** —
`file_bytes` is NULL on 171 of 192 raster rows and has never been a measurement of the whole. For
each required input: filename, size on disk, CRS, and a placeholder for the location the design seat
will supply.

**Rasters and Parquet are excluded by `.gitignore` as well as by omission**, so a later accidental
`git add` cannot pull 15 GB into the tree.

### 2.2 · The database

`Gayini_Results.sqlite` **cannot be rebuilt** — the builder destroys manually registered rows and no
non-destructive registration path exists. **Do not run the builder, do not `reset_file`, do not
propose a clean rebuild under any name.**

For Gate A, using HANDOFF-1's table-level classification: report which tables and views the four
pipelines read, their combined size, and whether the whole file is under 100 MB. **Propose nothing
and extract nothing.** If a subset is needed, that is a design-seat decision and a separate task.

### 2.3 · The frozen methods document

`Gayini_RS_methods_doc_V13.docx` is 10.6 MB and does not diff. It travels as a **frozen versioned
deliverable** — the `.docx` and a PDF, both named for their version — and is **not** a living
document in this repository.

**One blocker, and it is specific.** Section 11, *Spatially structured vegetation response*, is built
on the 21 `s11_*` numbers that TRACE-1 found have no producer anywhere in the tracked corpus and cite
an untracked draft as their authority. Every figure in that section is affected: the paddock
community shares, the dominance bands, the adjusted-trend ranks, the 54-of-64 count, the −0.148
median.

**Report the status of `docs/reference_update/Gayini_S11_spatial_structure_draft.md`** — present and
untracked, or absent. **Do not commit it, do not rebuild the numbers, and do not edit the methods
document.** The design seat rules on whether Section 11 travels as it stands, travels flagged, or
waits.

---

## 3 · Gate B — copy, and write the four documents · **STOP**

Only after Gate A sign-off.

**Copy every approved `MIGRATE` row.** Preserve relative structure within `R/`, `scripts/` and
`docs/`. **Verify each copy by checksum against its source** and report any mismatch; a silent
truncation on a large file is exactly the failure this catches.

Then write four documents, generated from the manifest wherever possible so they cannot drift:

**`README.md`** — what this is, what it is not, the four pipelines named, run order, where the data
comes from, and the archived-history line from §1. Written for a competent GIS analyst who has never
seen the project.

**`INDEX.md`** — **derived from the manifest, not written by hand.** One row per script: path, which
pipeline reaches it, closure depth, and **the artefacts it writes** — tables, rasters, and
`number_id`s. Keying the index on outputs rather than descriptions is what makes it checkable: a
script whose listed outputs do not appear after a build is caught immediately. A hand-written index
becomes stale within a month and there is measured precedent — 36 of 113 specs in the source
repository cite at least one file that does not exist.

**`ATTRIBUTION.md`** — authorship, the funding and client relationship, third-party data sources with
their own terms, and a plain statement that reuse terms are to be confirmed in writing. **No reuse
grant is made here**; the design seat supplies the wording.

**`CLAUDE.md`** — the nine rules from `Gayini_RETRO1_gateB_learnings.md`, plus the number rules: five
qualifiers on every registered value, additive-only, and the two-metric prohibition. **Not the source
`CLAUDE.md`**, whose database summary was stale on six counts and which encodes dashboard and report
governance with no counterpart here.

### 3.1 · `sidelines/`

Off-mainline work travels **only if the manifest marks it so**, into `sidelines/`, each item with a
one-line README stating what it did, why it is off the main line, and that it is unsupported.
Expected: the LiDAR structural work, the LOOC-B condition work, the reference-state stream.

**Not gists.** Nothing here is published. Same repository, honestly labelled, no implication of
maintenance.

### 3.2 · The IP boundary holds through the copy

Per HANDOFF-1 §6: Gayini-specific working code travels as it is; anything that generalises it does
not. **Copy no file the manifest marked `IP_HOLD`, and generalise nothing during the copy.** If a
copied script is already partly configuration-driven, copy it unchanged — do not extend it and do not
un-generalise it.

**No NNTC material and no output identifying places on Country travels without review.** Anything
uncertain stays behind and is listed.

---

## 4 · Gate C — the build gate · **the actual test**

Only after Gate B reports clean.

**The migration is done when the new tree builds, not when its file list looks right.**

From the new tree, with the data mounted at the path `data/README.md` describes, **run one pipeline
end to end and compare a produced number against the archive.** Prefer the census join or the
flood-frequency surface — both are upstream, both are read by everything else.

Report:

- Which pipeline was run, and its entry script
- Whether it completed
- The produced value and the archived value, and whether they agree
- **Every import, `source()` or file read that failed** — each one is a file the closure missed

**A failure here is the task working.** It means a producer did not travel, and finding that now is
the entire point. **Report it; do not fix it by copying additional files from the source without
design-seat sign-off** — an unreviewed file arriving through a build failure defeats the manifest.

**Do not weaken the test to make it pass.** Not a smaller extent, not a stubbed input, not a relaxed
tolerance. If the pipeline cannot run — because the data is not mounted, or a required input is
absent — say so and stop. **An honest "could not run" is a result; a doctored pass is not.**

### 4.1 · What Gate C proves

A number reproducible only by a *consumer* fails this test, and should. 39 of 156 registered numbers
in the source have no demonstrated producer — 21 with nothing at all, 18 resolving only into code
that reads them. **The build gate is where R11 is enforced rather than merely stated.**

---

## 5 · Checks on this task's own checks

- **Every copy verified by checksum**, source against destination. Assert on the written file, never
  on the copy logic (I-53).
- **Coverage alongside verdict** (I-53): how many manifest rows were processed against the manifest
  total, at every gate.
- **A fixture that errors is not a fixture** (I-42): the copy verification must fail against a
  **corrupted** destination file, not only against a missing one.
- **Deterministic emission** (I-46): `sorted()` on every listing before it reaches a report or an
  index.
- **Check live, never via a stored flag** (R7) for every existence question in this task.
- **No chained checks** (R8): any command whose result is relied upon is issued separately and its
  output queried. A pipeline reports its last stage's status and launders everything upstream.

---

## 6 · Outputs

```
Output/audit/
  HANDOFF2_copy_plan.csv        source, destination, size, checksum, gate
  HANDOFF2_gateA_report.md
  HANDOFF2_gateB_report.md
  HANDOFF2_gateC_build.md
```

Written to the **source** repository under Ruling BB, in the shape of CL. Verify the un-ignore with
`git check-ignore -v` and by result (I-60).

**Do not commit the destination tree.** `git init` and stage nothing. The client creates the GitHub
repository and makes the first commit.

---

## 7 · What this is not

It does not create a GitHub repository, push anything, or make a commit in the destination. It moves
no file, deletes nothing, and modifies nothing in the source. It re-derives no number, registers
nothing, runs no analysis beyond the single build of Gate C, and hardens no reproducibility beyond
what the copy carries.

It does not decide `UNRESOLVED` rows, does not rule on Section 11, and does not generalise or package
anything.

**A clean Gate C on one pipeline is the deliverable. A failed Gate C with the missing files named is
equally a deliverable** — and is the more useful of the two.

**STOP at each gate.**

---

**Rulings in force:** BB, CL, DA, DB, DP, DS.
**Named patterns in force:** I-42, I-46, I-53, I-56, I-60.
**Learnings in force:** R7 (no stored existence flags), R8 (the exit code is not the check), R11 (a
number travels only with its producer).
**Blocked on:** HANDOFF-1 manifest, and design-seat sign-off on its `UNRESOLVED` rows.
