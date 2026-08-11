# RETRO-1 Gate B — the learnings that travel

**Design seat, 12 August 2026.** Interpretation of RETRO-1 Gate A, which extracted and did not judge.
Written to drop into the new repository's `CLAUDE.md` as a working-practice section.

**Provisional pending HANDOFF-1.** The rules below are settled; the file paths and control names they
reference are not, because the new repository's contents are not yet decided.

---

## What this is

Nine rules, each with the mechanism that makes it true and the count of times this project produced
an instance. **A rule without a stated mechanism is a description of one team's habits and does not
travel** — six candidates were discarded or held on exactly that test, and the discards are recorded
in §4 so nobody re-derives them.

Two seats: a **design seat** that specifies and reviews, and an **execution seat** that builds. The
rules are about the interface between them and about the controls either seat relies on. **Nothing
here is domain-specific.** It applies to any arrangement where one party writes instructions in a
conversation and another party executes them against a repository.

---

## 1 · The interface rules

### R1 · A ruling is usable by a later session only if it can be quoted from a durable artefact

*Mechanism: sessions share no memory. An assertion whose source cannot be retrieved cannot be
distinguished by the next session from one that was never made.*

**Evidence:** of 106 ruling identifiers, 101 entered the record only because some later commit
happened to quote them; one has no dated evidence anywhere in the tracked corpus. One ruling had to
be recovered from a code comment the execution seat had written itself.

**Practice.** A decision that governs future work is written to a file in the repository at the time
it is made, or it is not a decision. Chat is where rulings are *discussed*; it is not where they
*live*.

---

### R2 · Rulings are issued during runs, not before them — so a "rulings in force" list prevents nothing

*Mechanism: a spec's rulings block restates decisions that already exist. No artefact exists in which
a ruling is written before the run it governs, so on the evidence every ruling is a spec defect
caught late.*

**Evidence:** 101 reactive against 1 pre-registered, across 106 identifiers, all inside a nine-day
window. Concentrated — two tasks accounted for 21 of the keyed reactive rulings.

**Practice.** Keep the block only if it can carry something new. **A spec's rulings section must
contain at least one decision issued *for that run*, or be omitted.** A block that only restates is
decoration, and decoration in a control position is worse than no control, because it reads as
coverage.

---

### R3 · A fact crossing from conversation to repository loses its provenance and arrives as an assertion

*Mechanism: the receiving side has the claim and not its source, so a transcription error, a
staleness, and a correct statement are indistinguishable on arrival.*

**Evidence, measured across the corpus:** 36 of 113 specs cite at least one file that does not
exist — 73 absent citations in total. 21 registered numbers cite an untracked draft as their
authority. Three times a spec's stated premise was already false when it was read, in each case
because several sessions were changing the repository underneath it.

**Practice.** The existing remedy — *cite the identifier, never the value* — is correct and covers
only numbers. Generalise it: **cite the artefact, never the recollection.** Before a spec is issued,
every file it names is confirmed to exist; every premise it states is either re-derived or marked as
an assumption to be checked first. **The receiving seat re-derives the premise rather than accepting
it.** In this project that habit cost about one query per instance and caught four errors, including
one of the execution seat's own.

---

### R4 · Where a re-run's cause is not required, it goes unrecorded

*Mechanism: report formats determine what survives. A field nobody must fill is filled only when the
author happens to feel like narrating.*

**Evidence:** 104 of 137 reports show a re-run, amendment or supersession; 33 state no cause at all.
The stated causes that do survive — data finding, misread instruction, tooling failure, spec
ambiguity — cannot be compared against the 33 in any useful way.

**Practice.** A run report states what preceded the re-run, in one line, from a fixed short list. Not
for blame — for the distribution, which is the only way to tell a spec problem from a data problem
at scale.

---

## 2 · The control rules

**The governing finding, and the reason this section exists:** across the entire repository, **only
two controls had a recorded proof that they could fail** — a value-perturbation fixture on the
reproduction test, and a data-drift fixture on one canary. Neither is a smoke check.

Everything else was observed firing in the wild or never established at all. Of **14 smoke checks,
12 were never established as having fired**; the two that were both fire pathologically — one
permanently red, and one with inverted polarity that fires when the archive convention is *followed*.
Separately, one advisory rule reported 127 findings and enforced none.

### R5 · A check that cannot fail is not a check, and a check that errors is not a check that catches

*Mechanism: a check returning clean because it did not run is indistinguishable from one that
examined everything and found nothing. Nothing in the output separates them.*

**Practice.** Every control ships with a **wrong-answer fixture** — one that makes the check return a
*false verdict*, not one that crashes it. A fixture that merely errors was correctly discarded in
this project as invalid. **A control with no such proof is listed as unproven, not as passing.**

**The convergence form is stronger where it is available:** remove the evidence and the verdict must
*move*; restore it and the verdict must *return*. A check that has frozen its answer passes a
stability test and fails this one.

---

### R6 · An advisory control is not a control

*Mechanism: a finding with no consequence changes no behaviour. It accumulates instead.*

**Practice.** Every rule either enforces or is deleted. A baseline that suppresses existing debt is
legitimate — it makes the rule enforce on *new* violations — but a permanently advisory rule is a
report nobody reads.

---

### R7 · A persisted verdict cannot notice it has aged

*Mechanism: a stored flag records a check's result at one moment. Nothing revisits it, so it can
report presence and never absence.*

**Evidence:** a `path_exists` column read true on seven registry rows eleven days after the files had
moved. The defect was in one table and not in the convention — the parallel table was clean — which
is exactly why it survived.

**Practice.** **Never consult a stored existence flag; check live.** More generally, a cached verdict
is evidence about the past. If a decision depends on the present state, query the present state.

---

### R8 · The exit code is not the check

*Mechanism: a shell pipeline reports the status of its last stage, laundering everything upstream. A
malformed check inside a chain errors, the chain continues, and the result is never queried.*

**Evidence:** a verification step inside a chained command used an invalid option, errored, and the
chain proceeded to commit unverified. The commit happened to be correct; nothing detected that it had
not been confirmed.

**Practice.** **Any command whose result is relied upon is issued separately and its output is
queried.** Not only commands that write — commands that *check*. Confirming afterwards is what
establishes the result; the chain establishes nothing.

---

### R9 · A substring check matches the record of a correction as though it were the error

*Mechanism: the text describing a prohibited pattern contains the prohibited pattern.*

**Evidence:** three of four violations reported by one lint were comments *prohibiting* the construct
— including one written days earlier to explain why a registrar deliberately avoids it. Other
violations were comments documenting a constant's derivation.

**Practice.** Checks that match on text exclude comments and documentation, or they punish the habit
of writing corrections down. **A project that documents its reasoning and checks by substring are in
direct conflict**, and the conflict is silent until someone reads the violation list closely.

---

## 3 · The two registry rules

### R10 · Registration confers no test coverage, and nothing enforces the second step after the first

**Evidence:** 43 registered numbers had a producer and no test. Coverage lagged registration and the
gap widened as the registry grew.

**Practice.** Registering a value and proving it reproducible are two acts. Track them as two
columns, and report the gap as a standing figure rather than discovering it during an audit.

**A corollary this project learned the hard way:** do not close a coverage gap by copying the
registration logic into the test. A copied path passes by construction and proves nothing — it is the
defect shape the test exists to catch.

---

### R11 · A number can be registered with no producer committed

*Mechanism: computing a value inside a session, registering the result, and committing no script
leaves the value in the database and its derivation nowhere.*

**Evidence:** 21 registered numbers matched no script, no document and no table in the entire tracked
corpus, and cited an untracked draft as their authority. A further 18 resolved only into code that
*reads* them — a consumer proves a number is used and proves nothing about where it came from.
**39 of 156 registered numbers had no demonstrated producer.**

**The pattern is live, not historical.** A separate 13-row batch sat in exactly this state during the
audit and was rescued only because a producer was committed hours later, by a different session, for
its own reasons.

**Practice.** **A value is registered in the same commit as the script that produces it, or it is not
registered.** The migration test is the honest one: *nothing travels that cannot be re-derived inside
the destination from what travelled with it.*

---

## 4 · What was considered and did not travel

Recorded so it is not re-derived. **None of these is false — each simply has no stated mechanism, and
a rule without one is a description of this team's habits.**

| candidate | why it does not travel |
|---|---|
| Spec length ranged 23–637 lines | No association with outcome established. Length is a preference |
| Four recurring spec sections appear in a minority of specs | Presence was measurable; *response* to a section was not, because responses are prose and not keyed to sections. Calling a section decorative on presence alone is resolution by coincidence |
| A gate's firing can be established from the corpus | **It cannot.** A text-proximity test marked 299 of 316 gates as having fired and meant nothing. Only six firings were verifiable by hand |

**The third deserves its own line, because it is a real open problem rather than a discarded
measure.** With 316 declared STOP gates and six demonstrable firings, **the gate discipline in this
project is largely unvalidated.** A quiet gate may be correctly quiet, and the corpus cannot tell the
two apart. **Do not treat gate count as evidence of rigour.** Establishing otherwise would require
run reports to record gate outcomes in a fixed form — which is the cheap fix, and is R4 again.

---

## 5 · The finding that is not a rule

Three of the audit's own methods produced **confident, wrong, non-crashing** answers before they were
caught — inside a task written specifically to look for that shape. Each was corrected mid-run and
each correction is in the artefacts.

**Two things follow.** First, R5 is not a rule about other people's code. Second, the arrangement
that surfaced all three — and the four premise errors before them — was **re-deriving the premise
rather than accepting it**, in both directions, including when it went against the seat doing the
checking.

That is the practice worth carrying above any individual rule here, and it is the cheapest one on
the list.

---

*Compiled from RETRO-1 Gate A, 11–12 August 2026: 113 specs, 137 reports, 57 issue rows, 294 commits,
106 ruling identifiers, all examined, nothing sampled. Gate A extracted; this page interprets.*
