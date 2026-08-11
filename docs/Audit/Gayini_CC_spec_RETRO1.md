# Gayini CC spec — RETRO-1

**What the project's own record says about how the two seats worked.**
Design seat, 10 August 2026. Read-only. Registers nothing. Two gates.

---

## 0 · Standing execution rule

Run Gate A to completion in one pass and report once. Do not ask before writing. Halt only on: a
required input absent after searching; unresolved repository divergence.

`mode=ro`, `PRAGMA query_only=1` on all reads. Recon first — `git fetch`, `git status`,
`git log --oneline -10`.

**Gate B is not CC's.** Stop at the end of Gate A and report. Nothing in this task registers a
number, changes a governance document, or proposes a rule.

---

## 1 · Why this runs, and why it runs before the migration

The article moves to a new repository. That repository gets a `CLAUDE.md`, a spec template and a
settings file on its first day. **Whatever we have learned about working well has to be written down
before that day, or the new repo inherits the current habits unexamined** — including the ones that
cost us time.

This task builds the evidence for that. It does not draw the conclusions.

**The corpus is unusually good for this.** Sixty-odd I-series entries, each with a worked case and
most caught internally before a client saw them. Very few projects hold a record like that. The risk
is the opposite of the usual one: not too little evidence, but **over-generalising from one project,
one design seat and one execution seat**. §6 is the control on that and is not optional.

---

## 2 · The corpus — define it once, here

Four sources. **Report the count and date range of each before extracting anything**, so the corpus
is bounded and the same bound can be re-applied later.

| source | location | note |
|---|---|---|
| **Specs** | `Gayini_CC_spec_*.md` and the earlier `T*_*.md` / `Tier2_Task*.md` task documents | The instruction side |
| **Run reports** | task reports, change reports, gate verifications under `Output/` and `docs/` | The execution side |
| **Governance** | the ruling registry, `Gayini_issues_log.md`, `CLAUDE.md` and its history | The decision side |
| **Chat exports** | JSON exports, if present on disk at run time | The dialogue side — see §2.1 |

### 2.1 · The chat exports, and what to do if they are absent

The design-seat↔CC dialogue lived mostly in chat and is not version-controlled. **If exports are
present on disk, treat them as ordinary corpus** — extraction from them is mechanical and in scope.
**If they are absent, run Gate A without them and say so in one line at the top of the report.**

Do not wait for them, and do not estimate what they would have contained.

**Record the gap as a finding either way**: the interface we most want to tune is the one least
recorded. That is worth stating whether or not this run can close it.

---

## 3 · Gate A — extraction · **STOP**

Counts and tables only. **No assessment of whether anything was good.**

### 3.1 · The spec inventory

One row per spec: identifier, date issued, line count, gate count, whether it names a ruling set,
whether it names a STOP, whether every document it cites existed in the repository on its issue date
(**I-48** — known breached four times, twice by the design seat; count it across the whole corpus,
do not carry the four).

### 3.2 · Rulings, split pre-registered against reactive

**This is the highest-value item in the task.**

A ruling issued **before** a task ran is a decision made in advance. A ruling issued **during** a
task is a spec defect caught late. Split the registry on that basis using issue dates against task
run dates, and **key every reactive ruling to the task that provoked it**.

Report the distribution. If reactive rulings concentrate on a few tasks or a few spec shapes, say
which — **but do not say why.** Cause is Gate B.

Where a ruling's date or provoking task cannot be established, record it as unresolved rather than
inferring. **A ruling is only a ruling if it can be quoted** (I-43); the same applies to its
provenance.

### 3.3 · Gates that never rejected anything

For every STOP gate in the corpus, whether it ever returned a rejection, a re-run, or a change to
the following step.

**A gate that has never stopped a task is indistinguishable from a gate that does not work** —
I-42's shape applied to process rather than to code. Report the count and list them. Draw no
conclusion: some gates are correctly quiet.

### 3.4 · Re-runs, and what preceded them

Every task that ran more than once. For each, what the record says preceded the re-run: a data
finding, a spec ambiguity, a misread instruction, a tooling failure, or unrecorded.

**Classify only where the record states it.** Where it does not, `unrecorded` is the correct answer
and is itself a finding about the reporting convention.

### 3.5 · Controls that never fired

Every lint, deny rule, assertion and canary in the repository, with whether it has ever fired.

A control that has never fired is either perfect or inert. **This task does not determine which** —
it produces the list. Note where a control is known to have been proven able to fail on a fixture,
because that distinguishes the two and the project already holds several such proofs.

### 3.6 · Spec shape against outcome

Length, section count and gate count of each spec, against the reactive-ruling count and re-run
count keyed to it.

**Report the association and nothing more.** Whether longer specs help or merely feel safer is a
Gate B question, and the sample is small.

### 3.7 · Which spec sections were acted on

For each recurring spec section — standing conditions, spine anchor, what-this-is-not, acceptance
criteria, rulings-in-force — how often the run report demonstrably responded to it.

**Some sections may be decorative.** Knowing which, before the new template is written, is the point
of the task.

---

## 4 · CC's own friction log — first person, and only CC holds it

A separate section of the report, written in the first person. **This is the one part of the corpus
that exists nowhere on disk.**

- Where an instruction was ambiguous, and what was assumed
- Where a judgement was made that the spec did not cover — INVENTORY-1's *"One judgement I made"* is
  the shape, and that section was more useful than most of the document
- Where an instruction was rejected, and on what grounds
- Where a spec's stated aim and its acceptance criteria pointed different ways
- Where context from a previous session was needed and not available

**Report friction, not fault.** No self-criticism, no apology. A friction point is information about
the interface, not about either seat.

**Checking rather than complying is explicitly worth preserving** — it has caught design-seat errors
more than once. Record instances of it plainly; they are evidence the interface works, not evidence
of trouble.

---

## 5 · The chat↔disk boundary — a class the log already holds

The issues log names one mechanism four times without generalising it, and the generalisation is the
most transferable thing in the corpus:

| entry | instance |
|---|---|
| **I-40** | recording a decision is not executing it |
| **I-43** | a ruling without a quotable message |
| **I-48** | a spec quoting a document nobody could open; both seats reasoned from the quotation for a session |
| **I-58** | an instruction misidentifying `+0.919` as a floor trend when it is a gap slope — **inside an instruction written to prevent that class** |

**The candidate general form: a fact crossing the chat↔disk boundary loses its provenance and
arrives as an assertion.**

The existing remedy — cite the `number_id`, never the value — is correct and **partial**: it covers
numbers, and not rulings, quoted documents or prior context.

**Gate A's job is to count the instances**, across the whole corpus, including any not currently
carrying an I-number. **Gate B decides whether the general form holds.** Do not assume it.

---

## 6 · The control against over-generalising

This is a corpus of one project, one design seat, one execution seat, one domain.

**For every candidate learning the extraction surfaces, record whether a mechanism can be stated.**

- *A ruling needs a quotable message* has one — memory is not shared across sessions. **Keep.**
- *Specs should run about 400 lines* has none. It is a description of this project's habits.
  **Discard.**

Where no mechanism can be stated, the row is marked `NO_MECHANISM` and carried anyway. **Do not
delete it** — Gate B may find a mechanism the extraction could not see. But it does not travel to
the new repository without one.

---

## 7 · Checks on this task's own checks

- **Coverage alongside verdict** (I-53): how many specs, reports and rulings were actually examined,
  not only what was concluded. A check that returns clean without examining anything is
  indistinguishable from one that passed.
- **Deterministic emission** (I-46): `sorted()` on anything hash-ordered before it reaches a
  checksummed artefact.
- **Assert on the output** (I-53, general form): verify the emitted tables, not the logic that built
  them.
- **Never resolve by value** (I-56): key rulings, issues and numbers by identifier throughout.

---

## 8 · Outputs

```
Output/audit/
  RETRO1_spec_inventory.csv
  RETRO1_rulings_timeline.csv
  RETRO1_gates_and_controls.csv
  RETRO1_candidate_learnings.csv
  RETRO1_report.md
```

**`RETRO1_candidate_learnings.csv`** is the row that carries to the new repository:

| column | contents |
|---|---|
| `candidate_id` | assigned in this run |
| `statement` | the learning, one sentence |
| `evidence` | the specs, rulings or issues it rests on, by identifier |
| `instance_count` | how many times the corpus shows it |
| `mechanism` | the stated mechanism, or `NO_MECHANISM` |
| `source_side` | design seat · execution seat · interface · tooling |

**`RETRO1_report.md`**, in this order:

1. The corpus bounds of §2, and whether chat exports were present
2. The rulings split of §3.2 — pre-registered against reactive, with the concentration
3. The gates and controls that never fired
4. The re-run classification
5. **CC's friction log** (§4), first person
6. The chat↔disk instance count (§5)
7. The candidate learnings table, with the `NO_MECHANISM` rows kept visible

Un-ignore under Ruling BB if needed, in the shape of CL. **Verify with `git check-ignore -v`, not by
reading** (I-60), and confirm by result — `git status --porcelain` plus a dry-run `git add` staging
exactly the intended paths.

---

## 9 · Gate B — interpretation · **design seat, not CC**

Gate B decides which candidate learnings are real, which are this project's habits, and what each
implies for the new repository's `CLAUDE.md`, spec template and settings.

**It is stated here so the boundary is explicit, not so CC runs it.**

The reason is structural, not a matter of trust: **asking the specified party to grade the specifier
has an obvious bias, and the output would be unusable.** CC holds §4, which the design seat cannot
write. The design seat holds §9, which CC cannot write. Neither section is the other's to complete.

---

## 10 · What this is not

It changes no governance document. It writes no rule. It grades no spec and no seat. It does not
determine whether a quiet control is sound or inert. It does not decide what migrates.

**The candidate learnings table and the friction log are the deliverables.**

**STOP at the end of Gate A.**

---

**Rulings in force:** BB, CL, DA, DB, DP, DS.
**Named patterns in force:** I-40, I-42, I-43, I-46, I-48, I-53, I-56, I-58, I-60.
