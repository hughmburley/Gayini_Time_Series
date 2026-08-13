# REP-CONS — Report consistency against the methods document

**Type:** READ-ONLY audit, then a bounded correction pass. No new analysis.
**Inputs:** the paddock and site reports in `Output/reports/`, and the current methods document in `docs/reports/` (v10 at the time of writing). Record filename, size, modified time and SHA-256 of the methods document in the Gate 0 output.
**Outputs:** `Output/audit/REPCONS_consistency.md`, and a corrected report batch if Gate C is authorised.
**Re-read this spec in full and echo the current gate verbatim before starting it.**

---

## Why this exists

Three deliverables go to the client together: the delivery pack, the methods document, and the report batch. Each has been checked internally. **None has been checked against the others.**

Two audits of the methods document (DOC-1, DOC-2) established the pattern worth carrying here: no quantity was ever found stated at two different *values*, but several were found stated on two different *bases* — a sample against a population standard deviation, a weighted against an unweighted mean, a raw observation record against an analysis window. Those are the errors to look for, because they survive a value check.

Two are already known and are the starting point rather than the finding.

---

## Two known discrepancies

**1 · The record window is stated three ways.**

| Source | States |
|---|---|
| Paddock and site reports | "full record 1988–2022" |
| Figure titles inside the reports and the methods document | "1988-2023" |
| Every trend pin in `dim_headline_number` | `period_label = '1988-2022'` |

The underlying series is the same; the labels are not. Methods document v10 now states that paddock-scale annual series and every trend computed from them run to water year 2022–23, and that figure titles carry a 1988–2023 label denoting the same span in calendar rather than water years.

**The reports should adopt the same convention:** water years 1988–89 to 2022–23, stated once in the scope footer, and not described as "the full record" where the census extends a year further.

Confirm the underlying series before changing any label. If the paddock annual series genuinely ends at a different point from the census, that is a finding rather than a labelling matter.

**2 · One number, two roundings, one page apart.**

The Bala 29ca paddock report gives the paddock thin-ground cover as **40.5%** in the header card and **41%** in the parts table. Both round the same value. Check every report for the same pattern: a quantity appearing in a header card and again in a table at a different precision.

---

## Gate 0 · Inventory · **STOP**

Report what exists: how many paddock reports, how many site reports, which units, and which are complete. Note any unit named in the methods document or the delivery pack that has no report.

Extract from every report into one table: each numeric claim, its unit, the section it sits in, and the field or view it should derive from. This is the same extraction pattern as `DOC1_extract_claims.py` and that producer should be reused rather than rewritten.

**STOP.** Report the counts before checking anything.

---

## Gate A · Reports against the methods document

For every quantity appearing in both, confirm they agree in **value, basis and precision**.

Known agreements, confirmed at DOC-2 and not to be re-derived: the part counts by community (Aeolian 17, Riverine 37, Inland Floodplain 61), Bala 29ca's flood frequency of 8.5% and rank of 61, and its three part-state classifications.

Priority checks, in order:

1. **The two known discrepancies above**, across the whole batch
2. **Paddock flood frequency and rank**, against `census_by_zone_stratum` pixel-weighted over non-treed strata — this is the basis the methods document uses, and an unweighted derivation gives visibly different ranks
3. **Thin-ground cover** — confirm the reports use the within-year spatial percentile throughout and never the census temporal one. These differ by roughly ten percentage points for the same paddock, and the project's standing rule is that neither is ever called "the floor" unqualified
4. **Part-level level, trend and classification**, against `T13_gateC_classification.csv`
5. **Residual from expectation**, against the registered constants — reports must read the registered line and not refit
6. **Area figures**, including whether treed area is stated separately and whether the scope footer's denominator matches the areas in the tables

Assign CONFIRMED, CONTRADICTED, BASIS MISMATCH or UNVERIFIABLE to every row. **Basis mismatch is its own verdict and is not a contradiction** — the number is right and its footing is unstated or different.

---

## Gate B · The reports against each other

Nobody has checked whether the reports are internally consistent as a set.

- Does a quantity computed the same way carry the same precision in every report?
- Where a report cites a property-wide comparator — "lowest of 17 on the property", "second-lowest of 37" — do those ranks agree across the batch and with the source table?
- Does the scope footer state the same convention in every report?
- Do the standing language rules hold everywhere: never the bare word "floor", DEA cultivation calls never described as cultivated at any confidence, and the five-period trajectory absent?

Report any report that departs from the batch convention, naming the report and the departure.

---

## Gate C · Correction pass · **authorised separately**

**Do not begin until Gates 0, A and B are reviewed.**

Corrections are confined to labelling, precision, scope statements and wording. **No number is recomputed and no figure is re-rendered.** If a value is wrong rather than mislabelled, report it and stop; that is a different task.

The reports are generated from a producer. **Correct the producer and re-run the batch** rather than editing documents individually, and state in the change report which producer was changed and how many documents were regenerated.

---

## Two things to hold throughout

**The reports are the best-written material in the project.** "The cover on the thinnest-covered twentieth of the paddock", "each kind of country has its own normal", the plain statement that averaging hides more than it shows — that register is deliberate and is what makes the reports usable by land managers. **Do not make them more technical in the name of consistency.** Where the methods document and a report describe the same thing at different registers, the report's wording stands and the methods document is the one that carries the formal definition.

**A wrong derivation produces confident, plausible, wrong contradictions.** DOC-2 recorded an instance where an unweighted basis produced four apparent contradictions in the most-quoted rank family in the project, and the document turned out to be right. Where a check disagrees with a report, establish the basis before reporting a contradiction.

---

## Standing rules

Read-only until Gate C · SQLite `mode=ro` with `PRAGMA query_only=1` · never re-run the builder · **run in your own git worktree** · commit straight to main per CLAUDE.md, explicit named paths only, never `git add -A` · **STOP at each gate** · confirm no Word lock files are present before Gate 0.
