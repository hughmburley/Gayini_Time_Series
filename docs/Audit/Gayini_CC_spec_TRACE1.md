# Gayini CC spec — TRACE-1

**Which registered numbers can be re-derived, and which have no producer.**
Design seat, 10 August 2026. Read-only on the database. Registers nothing.

---

## 0 · Standing execution rule

Run to completion in one pass and report once. Do not ask before writing. Halt only on: a required
input absent after searching; unresolved repository divergence.

`mode=ro`, `PRAGMA query_only=1` on all reads. Recon first — `git fetch`, `git status`,
`git log --oneline -10`.

**This task reads and writes two files.** It registers nothing, renders nothing, re-derives nothing
and computes no new quantity. Every verdict comes from the filesystem, the registry or a live query
— **never from a caption, a previous summary, or this spec.**

---

## 1 · Why this runs now, and why it does not wait

The project is moving from an exploratory phase to a science article. The article will live in a new
repository, and the migration criterion is that **nothing migrates which cannot be re-derived inside
the new repository from migrated inputs**.

That criterion is only usable if we know, per number, whether a producer exists.

**I-29 is the known instance.** The reference-state deck's central five-period table — the 1988–92 /
1993–2002 / 2003–12 / 2013–18 / 2019–22 split — is produced by no script in the repository. That was
established by exhaustive search across all tracked text files on 28 July at T10 Gate A, it is still
open, and it was found by accident. **This task asks the same question of all 142 rows
deliberately.**

**This does not depend on which claims the article keeps.** That decision belongs to the design seat
and is not yet made. **Eligibility is prior to selection**: a number with no producer cannot be
selected regardless of how the spine falls. The two run in parallel and meet afterwards.

---

## 2 · Gate A — the trace · **STOP**

One row per `number_id` in `dim_headline_number`, **all 142**. For each, a verdict from exactly
three:

| verdict | meaning |
|---|---|
| `PRODUCED` | a named script exists on disk and demonstrably writes this row |
| `ORPHAN_SCRIPT` | a producer is named or inferable, but it does not exist, does not run, or does not write this row |
| `NO_PRODUCER` | exhaustive search finds nothing that produces it — the I-29 class |

### 2.1 · Trace by identity, never by value

**Resolution by value is not attribution** (I-56). Of 98 value-matches at FIGSEQ Part B, 51 matched
more than one pin: *"3"* matches ten, *"10"* and *"10%"* six each. A value-match establishes that a
number exists somewhere in the registry, not that a given script produced it, and a coincidence is
indistinguishable from a citation.

Follow the `number_id` and the registering call site. Where one script writes several numbers, name
them all — the mapping is many-to-one and reporting it as one-to-one would hide the concentration.

### 2.2 · The search must be exhaustive, and its method must be repeatable

Search **all tracked text files**, on the T10 Gate A pattern. **State the search method** — the
globs, the extensions, the exclusions — so the same search can be run again and compared. A search
whose scope is not stated cannot be distinguished from one that missed something.

### 2.3 · Do not rebuild any missing producer

T10 Gate A's instruction stands: **an absent derivation is a finding in its own right** and belongs
in the issues log. Report it; propose nothing. A producer rebuilt silently during an audit is a
producer nobody has reviewed.

---

## 3 · Reconcile against the coverage that already exists

`test_T8_headline_reproduction.py` covers 71 numbers and last reported **14 DRIFTED of 71**, every
one `recomputed = NOT RECOMPUTED`. Registration does not confer test coverage and nothing enforces
the second step after the first.

Report the **four-way split**:

| | covered by T8 | not covered |
|---|---|---|
| **traced to a producer** | | |
| **no producer** | | |

Within the covered cells, separate passing from drifted.

**Do not close a drift by copying the registration logic into the test.** CLAUDE.md requires an
independent re-derivation; a copied path passes by construction and proves nothing, which is
precisely the defect shape the test exists to catch. Where a genuine second derivation is needed,
say so and stop — building it is not this task.

---

## 4 · Three corrections from INVENTORY-1, folded in here

**`path_exists` is not evidence.** It read **1 on all seven** stale T12 land-cover rows. The flag
cannot notice that a path has aged, so it can report presence and never absence — the I-42 shape, in
a registry column. **Never consult it; check live.** Report how many of the 192 raster rows and 341
figure rows currently disagree with disk.

**`file_bytes` is NULL on 171 of 192 raster rows.** The registered total of 13.39 GB came from 21
rows, 13.03 GB of it from two LiDAR products. **Populate nothing** — report the count and record
that the registered volume figure has never been a computed quantity.

**Amend I-60; do not open a new entry.** The staging check that reported success while executing
nothing is **surface 2 recurring**. Ruling DS routes *edits* through a file; that was a *check* in a
chain, and so it sat outside the control. Record the amendment: **the file-routing rule extends to
any chained command whose result is relied upon**, not only to commands that write. The exit code is
not the check; querying the result is.

---

## 5 · Checks on this task's own checks

**A fixture that errors is not a fixture** (I-42). Any verification here must fail against a fixture
returning a **wrong verdict**, never against one that crashes. A check that cannot run has not
caught anything.

**Report coverage alongside verdict** (I-53). State how many of the 142 the trace actually examined,
not only what it concluded. A check that can return clean without having examined anything is
indistinguishable from a check that passed, and the only defence is asserting its own coverage.

**Deterministic emission** (I-46). `sorted()` on anything hash-ordered before it reaches a
checksummed artefact.

**Assert on the output, never on the intent** (I-53, general form). Verify the CSV that was written,
not the logic that wrote it.

---

## 6 · Outputs

```
Output/audit/
  TRACE1_number_producers.csv
  TRACE1_report.md
```

**`TRACE1_number_producers.csv`** — 142 rows:

| column | contents |
|---|---|
| `number_id` | the registry identifier |
| `verdict` | `PRODUCED` · `ORPHAN_SCRIPT` · `NO_PRODUCER` |
| `producer_path` | script that writes the row, or empty |
| `registering_call` | file and line of the registering call, or empty |
| `t8_coverage` | covered-passing · covered-drifted · uncovered |
| `search_evidence` | what was searched for and what was found |
| `notes` | free text |

**`TRACE1_report.md`**, in this order:

1. **The three verdict counts**, first line, with the coverage figure beside them
2. **The `NO_PRODUCER` list in full** — every row, not a sample
3. The `ORPHAN_SCRIPT` list, with what is missing in each case
4. The four-way reconciliation of §3
5. The three corrections of §4
6. The search method of §2.2, stated so it can be re-run

Un-ignore under Ruling BB if needed, in the shape of CL. **Verify with `git check-ignore -v`, not by
reading** — a re-include placed above the directory exclusion that governs it is inert, and
re-reading the file cannot distinguish the two (I-60). Confirm by result: `git status --porcelain`
and a dry-run `git add` staging exactly the intended paths.

---

## 7 · What this is not

It re-derives nothing. It registers nothing. It fixes no producer. It selects no claim for the
article, and it makes no judgement about which numbers matter.

**The `NO_PRODUCER` list is the deliverable.** If it is empty, that is the strongest possible result
and the report says so in one line.

**STOP at Gate A.** The design seat picks the subset for re-derivation once spine v2 exists.

---

**Rulings in force:** BB, CL, DA, DB, DP, DS.
**Named patterns in force:** I-29, I-42, I-46, I-53, I-56, I-60.
