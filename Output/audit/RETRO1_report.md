# RETRO-1 — what the project's record says about how the two seats worked

**Gate A: extraction. 11–12 August 2026.** Read-only. Registers nothing, changes no governance
document, proposes no rule, grades nothing.

**Chat exports were present on disk — but not the ones this task wanted.** Thirteen JSON exports
sit in `docs/Chats/`, all ChatGPT conversations from 25 June to 6 July 2026. Every one of them
contains **zero** occurrences of "Ruling", "CC spec", "Claude Code" or "CLAUDE.md" — they predate
the ruling system, which begins on 3 August. **The design-seat↔CC dialogue has no export at all.**
So §2.1's finding stands in a sharper form than it anticipated: the interface we most want to tune
is not merely under-recorded, it is the *only* interface with no record, while a superseded one is
fully archived.

**Rulings in force:** BB, CL, DA, DB, DP, DS. **Patterns honoured:** I-40, I-42, I-43, I-46, I-48,
I-53, I-56, I-58, I-60.

---

## 1 · Corpus bounds

| source | count | range | note |
|---|---:|---|---|
| Specs | **113** | 16 Jul – 11 Aug 2026 | 31 `CC_spec`, 42 `T*` task docs, 26 `Tier*`, 14 other `*_spec*` |
| Run / change / gate reports | **137** | 15 Jul – 10 Aug 2026 | `Output/{runs,audit,temporal,diag,glm,unzoned}`, `docs/change_reports` |
| Governance | **57 issue rows** (I-01 … I-60), 511 lines | 13 Jul – 10 Aug | plus 24 `CLAUDE.md` commits, 294 repository commits from 25 Jun |
| Chat exports | **13 JSON** (+13 md, 3 pdf) | 25 Jun – 6 Jul 2026 | ChatGPT only; see above |

**Coverage, stated alongside verdict (I-53).** 113 of 113 specs examined; 137 of 137 reports;
294 of 294 commits; 106 of 106 ruling identifiers; 57 of 57 issue rows. Nothing sampled.

**Two bounds worth naming.** Untracked files are outside the corpus — which excludes this task's own
spec and several current ones sitting in `docs/Audit/`. And the corpus is one project, one design
seat, one execution seat, one domain; §6 is the control on that and every candidate carries its
mechanism or is marked as lacking one.

---

## 2 · Rulings — pre-registered against reactive

**101 REACTIVE · 1 PRE_REGISTERED · 3 GOVERNANCE_FIRST · 1 UNRESOLVED, of 106 identifiers.**

Dated by pickaxe (`git log -S`) — the commit that first introduced the string — not by stated date.
A stated date is a claim; a commit is a record.

**Every ruling in the project dates from August 2026.** 105 of 106 fall between 3 and 11 August;
roughly a hundred rulings in nine days. The one pre-registered ruling is **AT**, in
`Gayini_CC_spec_DIAG1_v2.md`.

**The asymmetry is structural, not incidental.** A spec's *"Rulings in force: BB, CL, DA…"* line
restates rulings that already exist; it is never where one first appears. There is no artefact in
this repository in which a ruling is written *before* the run it governs. **On the evidence, a ruling
is by construction a spec defect caught late** — which is precisely the distinction §3.2 asked for,
and it lands almost entirely on one side.

### Concentration

| provoking task | reactive rulings |
|---|---:|
| LID-1 | **14** |
| EXEMPLAR-1 | **7** |
| RPT-SCOPE | 4 |
| P2 · P4 · TEMPORAL-1 · PARTSCATTER · UNZONED · SPAT-1 | 3 each |
| SCHEM-1 · XCHECK-1 · DASH3 | 2 each |
| P3 · PACK1 · M5 · PARTREG · DASH2 · FIGFIND-1 and others | 1 each |

Two tasks account for 21 of the keyed reactive rulings. **Why is Gate B's question**, and this
report does not answer it.

**One attribution caveat.** `provoking_task` is the task whose *commit* introduced the ruling string,
which is not always the task that provoked it. Ruling BE is keyed to EXEMPLAR-1 because that commit
carried it; it was issued during FIGFIND-1. Where the two differ, the record cannot separate them.

---

## 3 · Gates and controls that never fired

### Gates — the measure failed its own credibility check

**316 STOP gates across 113 specs.** My first firing test asked whether any report mentioning
`Gate X` also contained rejection language *anywhere* in that report. It marked **299 of 316** as
having fired. That is a coincidence test — the same error I-56 names for numbers, applied to
process — and I am reporting it as a failed method rather than as a result. Tightened to
500-character proximity it marks 265, with **51 never**.

**Neither number is evidence.** Reports do not record gate outcomes in any consistent form. This is
carried as `RETRO1-C14` with `NO_MECHANISM`.

**What *is* verifiable, by hand, is small and worth listing** — these are gates that demonstrably
changed what happened next:

- **DASH2 DZ check 4** — stopped the gate. A printed percentage divided by all classes where the
  sheet's scope was non-treed; three sheets corrected before release.
- **GLM-1** — paused mid-task with the model file written and never run; the commit says so on its
  face.
- **T10 Gate A** — produced I-29, the absent five-period derivation, and did not rebuild it.
- **Task F** — cancelled at review rather than gated.
- **UNZONED v3 Arm B** — stopped at its own STOP.
- **Ruling BE** — a design-seat challenge that withdrew an execution-seat claim before it shipped.

### Controls — enumerated from source, not inferred

| control | state |
|---|---|
| `magic_number`, `or_ignore`, `whole_digest` | **enforcing, and firing now** — lint run 11 Aug: FAIL, 80 new violations |
| `hash_order` | **advisory — reports 127, enforces 0** |
| `lint_baseline.json` | **suppresses pre-T5 debt by construction**; the lint fails on NEW violations only |
| `folder_scripts/archive_absent` | fires when the archive convention is **followed** — inverted polarity, recorded in CLAUDE.md |
| `scripts/10_downstream_optional` | permanently red (I-11); the suite exits 1 here every run |
| 12 other smoke checks | **never established as having fired** |
| `Edit(Output/pack/**)` deny rule | live; DATA-1 §0.1 routed around it by design |
| `test_T8_headline_reproduction` | fires — 72 of 153 pinned rows NOT RECOMPUTED at 10 Aug |
| RPT-SCOPE page-3 canary | fires |

**Only two controls in the entire repository have a recorded proof that they can fail.** The T8
`--break` fixture perturbs a pinned value by +5 on a temporary copy and is caught (−8.07 vs −13.07);
the page-3 canary was proven with a data-level drift that moved a value 34.59 → 51.40, after an
earlier fixture that merely *errored* was discarded as invalid (Ruling J). Everything else in the
table is either observed firing in the wild or unestablished.

**A finding inside the lint itself.** Of the four `or_ignore` violations reported on 11 August,
**three are comments prohibiting `INSERT OR IGNORE`** — including one I wrote on 8 August explaining
why the registrar deliberately does not use it. Several `magic_number` hits are comments documenting
the derivation of the constant. This is I-47 / Ruling AK — *a check must not match the record of a
correction* — recurring **inside the lint that enforces the convention the comments describe.** The
project's habit of writing corrections visibly and its substring-matching checks are in direct
conflict, and the conflict is live.

---

## 4 · Re-runs, and what preceded them

**104 of 137 reports show a re-run, re-render, amendment or supersession.** Stated cause, where the
record states it (a report may state more than one):

| stated cause | reports |
|---|---:|
| data finding | 42 |
| misread instruction | 36 |
| tooling failure | 28 |
| spec ambiguity | 15 |
| **unrecorded** | **33** |

**33 unrecorded is itself the finding about the reporting convention**, as §3.4 anticipated. No
section of the run-report format requires stating what preceded a re-run, so the cause survives only
where the author happened to narrate it. Classification here is keyword-based over report text and
is the weakest measure in this document; it is reported as a distribution, not as counts to be
quoted.

---

## 5 · CC's friction log

*First person. This section exists nowhere on disk. Friction, not fault.*

**Where an instruction was ambiguous, and what I assumed.**

INVENTORY-1 §5 banned identifiers from the body while the standing number rules require any quoted
result value to carry its `number_id`. Both cannot hold in the same sentence. I put the values in the
body in plain words and the identifiers in an appendix, and said so. TRACE-1 said "read-only, re-derives
nothing" while §3 asked me to separate passing from drifted T8 rows — obtainable only by running the
reproduction test. I ran it, established first that it opens the database `mode=ro` and mutates only a
temporary copy, and stated that I had run it. RETRO-1 §4 asks for the friction log and §0 says Gate B is
not mine; the boundary between *recording* friction and *interpreting* it is thin, and I have stayed on
the recording side even where the interpretation felt obvious.

**Where I made a judgement the spec did not cover.**

FIGFIND-1 directed me to copy the conserved-paddock dashboards and simultaneously to report label
defects without fixing them. Those instructions collided: the sheets carried a defect and were going in
front of the Nari Nari Tribal Council. I copied them as directed and put the warning at the top of the
index in plain language, on the reasoning that the design seat had ordered the copy and the reader
protection was mine to add. FIGFIND-1 §4's shortlist rule excluded unregistered figures, which would have
denied Adrian the community-grain figures he asked for; I excluded the D3 sheets as the rule required and
named the registered alternatives that cover the same grain. In INVENTORY-1 I declined to make the
CLAUDE.md edit Ruling BP asked for, because the number it specified was already stale twice over and the
concurrent seat was mid-write — writing 305 would have been wrong on arrival.

**Where a spec's stated aim and its acceptance criteria pointed different ways.**

FIGFIND-1 was scoped read-only, "no writes to the repository at all", and then instructed me to copy
files into the repository and write an index. I took the intent to be *no git operations and no
producers*, and did the writes. TRACE-1 §0 said "reads and writes two files" while §4 said to record an
I-60 amendment — a third file. §6 resolved it by listing the amendment as a section of the report, and I
followed §6. RETRO-1 §3.3 asks which gates never rejected anything; the corpus cannot answer it, so the
honest output is a failed method rather than a number, which is not the shape the section expects.

**Where I rejected an instruction, and on what grounds.**

Only once, and partially: Ruling BP above. Everything else I either executed or executed with a stated
assumption.

**Where I needed context from a previous session and did not have it.**

Constantly, and it is the largest single source of friction. Rulings BE, BK, BL, BM, BN and BP were
issued to me in chat; nothing on disk records their text, so this task could only date them by the commit
that happened to quote them, and Ruling BL had to be recovered from a code comment I wrote myself. Three
times a spec's stated premise was already false when I read it — 142 registry rows against 143 then 156;
"5 of 66 site dashboards" against 57; "chat exports, if present" where 13 were present but of a different
interface. None of these was an error by either seat. Each is the same mechanism: a premise written from a
view of the repository that several sessions were changing underneath it.

**Checking rather than complying, recorded plainly because it worked.**

Ruling BE is the clearest instance, and it went against me: I claimed two numbers on one sheet were
different measurements, the design seat challenged it, and the decomposition showed the gap was pure
scope and no value was wrong. The challenge was right and my inference was not. The same habit run the
other way caught the site-dashboard count, the registry drift, and — inside this task — my own gate
firing test, which produced a confident 299-of-316 that meant nothing. **What made all four surface was
re-deriving the premise rather than accepting it, and that costs about one query each time.**

---

## 6 · The chat↔disk boundary

The issues log names the mechanism four times without generalising it: **I-40** (recording a decision is
not executing it), **I-43** (a ruling with no quotable message), **I-48** (a spec quoting a document
nobody could open), **I-58** (an instruction misidentifying a gap slope as a floor trend, inside an
instruction written to prevent that class).

**Instances found in this extraction, beyond those four:**

- **101 of 106 rulings** enter the record only when some later commit happens to quote them.
- **1 ruling has no dated evidence at all** in the tracked corpus.
- **36 of 113 specs** carry at least one citation to a file that does not exist — **73 absent citations
  in total.** I-48 was known breached four times; measured across the whole corpus it is 36.
- **21 registered numbers** whose `decided_by` cites an untracked draft (TRACE-1).
- **The design-seat↔CC dialogue has zero exports**, while a superseded ChatGPT interface has 13.

**The candidate general form — that a fact crossing this boundary loses its provenance and arrives as an
assertion — is carried as `RETRO1-C03` with a stated mechanism. Gate A does not decide whether it
holds.** What Gate A can say is that the existing remedy is narrower than the problem: *cite the
`number_id`, never the value* covers numbers, and 36 absent spec citations and 101 unquotable rulings are
not numbers.

---

## 7 · Candidate learnings

Full table in `RETRO1_candidate_learnings.csv`. **15 candidates: 12 with a stated mechanism, 3 marked
`NO_MECHANISM` and carried, not deleted.**

| id | statement | n | side | mechanism |
|---|---|---:|---|---|
| C01 | A ruling is usable by a later session only if it can be quoted from a durable artefact | 1 | interface | stated |
| C02 | Rulings are issued during runs, not before them | 101 | interface | stated |
| C03 | A fact crossing chat→disk loses its provenance and arrives as an assertion | 4 | interface | stated |
| C04 | A substring check matches the record of a correction as though it were the error | 4 | tooling | stated |
| C05 | An advisory control is not a control | 2 | tooling | stated |
| C06 | A persisted verdict cannot notice it has aged | 7 | tooling | stated |
| C07 | Registration confers no test coverage | 43 | tooling | stated |
| C08 | A number can be registered with no producer committed | 21 | execution seat | stated |
| C09 | A spec can cite a document that does not exist, and both seats reason from it | 36 | design seat | stated |
| C10 | The exit code is not the check | 3 | tooling | stated |
| C11 | Where a re-run's cause is not required, it goes unrecorded | 33 | interface | stated |
| **C12** | Spec length ranges 23–637 lines with no association to outcome established | 113 | design seat | **NO_MECHANISM** |
| **C13** | Four recurring spec sections appear in a minority of specs | 113 | design seat | **NO_MECHANISM** |
| **C14** | A gate's firing cannot be established from the corpus by text search | 316 | interface | **NO_MECHANISM** |
| C15 | Checking rather than complying catches design-seat errors | 3 | interface | stated |

**By side:** interface 6, tooling 5, design seat 3, execution seat 1. **The interface and the tooling
carry eleven of fifteen** — which is a count, not a conclusion.

**C13 is deliberately weaker than §3.7 asked for.** I could measure whether a section was *present*; I
could not reliably measure whether a run *responded* to it, because responses are prose and are not keyed
to sections. Calling a section decorative on presence alone would be resolution by coincidence. The
measurement §3.7 wants needs run reports to cite the spec section they are answering — which does not
exist today and is a Gate B matter.

---

## 8 · Checks on this task's own checks

- **Coverage stated alongside verdict (I-53):** §1 gives examined-counts for every source; all totals.
- **Assert on the output (I-53):** each CSV is re-read after writing and checked — row count, sort order,
  unique keys, legal enumerated values, no empty required field. All passed.
- **Deterministic emission (I-46):** every table sorted on its key before writing; explicit `\n`
  terminator.
- **Keyed by identifier, never by value (I-56):** rulings by `ruling_id`, issues by `I-nn`, specs by path.
- **Three methods were wrong and were corrected mid-run, and the corrections are in the artefacts:**
  dating rulings by their file's creation date back-dated 41 of them to the issues log; parsing
  `--name-only` on blank lines silently dropped every file list and produced 53 spurious `UNRESOLVED`;
  scoring only `.md` as execution evidence left 7 rulings unresolved that had landed as code comments.
  **Each produced a confident, wrong, non-crashing answer** — the shape §7 and I-42 warn about, arising
  three times inside a task written to look for it.

---

## 9 · What this is not

It grades no spec and no seat. It does not determine whether a quiet control is sound or inert. It does
not decide what migrates.

**STOP at the end of Gate A. §9 — interpretation — is the design seat's.**
