# Rulings I and J — logged and prepared for P3's row assembly

**Date:** 3 August 2026 · **Prior:** `5d74610` · **No DB writes.**
Both rulings feed **P3's row assembly**; nothing else in Part 1 changes.

---

## Ruling I — L-T12-b admitted, rewritten. L-T12-a and L-T12-c stay excluded.

Your narrowing is right, and it is the distinction I should have drawn myself rather than deferring
the whole file: **what CLAUDE.md protects is the DEA cultivation *calls*** — the 2 `likely` + 40
`possible` zone-era classifications recorded as false positives. **A methodological lesson that names
no call carries none of that risk.**

### What L-T12-b actually says, so the rewrite is faithful

The pre-registered §2.5 falsification guard was **specified in advance, executed exactly as written,
and downgraded nothing** — because it tested the failure mode named in the *source documentation*
(flood green-up) rather than the mechanism actually operating (observation density). A
flood-correlation guard is **structurally blind** to an observation-density mechanism.

The row also records the other half, which is the part that makes it a *pair* rather than a
confession: **a second pre-registered guard in the same specification — a minimum-support rule — did
work**, and excluded the strongest apparent candidate on pixel count.

### The rewritten row, ready for P3 — names no task, no dataset, no call

> **A pre-registered falsification test aimed at the wrong hypothesis catches nothing.**
> In one case a guard was written into a specification in advance, executed exactly as written, and
> downgraded no cases — because it tested the failure mode named in the source documentation rather
> than the mechanism actually operating, and was structurally blind to it. Pre-registration protects
> against choosing a threshold after seeing the result; **it does not protect against testing the
> wrong proposition.** A second guard in the same specification, a minimum-support rule, did work and
> excluded the strongest apparent candidate. Both were pre-registered; only one was aimed correctly.

**Source:** `docs/Gayini_limitations_register_additions_T12.md`, row L-T12-b, rewritten under
Ruling I. No task name, no sensor, no land-cover class, no classification count.

**The pairing you identified is the point.** Beside T3 Gate B1 — where a pre-registered condition
*did* fire and was honoured, so no headline threshold was set — the sheet says both things: **one
pre-registered rule fired and was honoured; another was aimed wrongly and caught nothing.** Stronger
than either alone, and the honest version.

**L-T12-a and L-T12-c remain excluded whole.** Both name the dataset and the cultivation calls
directly. Ruling H otherwise unchanged.

## Ruling J — logged as I-42 and added to the standing rules

> **A check that ERRORS is not a check that CATCHES.** A fixture that makes the recompute crash proves
> only that the code path is reachable; drift detection requires a fixture that returns a **wrong
> value** the check must reject.

Recorded in CLAUDE.md immediately beside *"every check must be able to fail"* — which is where it
belongs, because it is the failure mode of that rule rather than a separate rule. Logged as **I-42**
and marked a **pack item T3 candidate row**, to sit beside the four proved-able-to-fail checks.

The worked case is on the record: the first page-3 fixture renamed `share_a` and raised
`sqlite3.OperationalError: no such column`. The build failed, so on a naive reading the check
"fired" — **but nothing had been detected; the query simply could not run.** The replacement moved
the value 34.59 → 51.40 by a data-level drift and was correctly rejected.

Worth stating plainly: this is why the three canaries are trustworthy rather than merely wired, and
it is the same family as I-40 — the record was there, the act was not.

## Running list of T3 candidate rows carrying an issue ID

| ID | row |
|---|---|
| I-36 | the reproduction test's exit string has mismatched denominators |
| I-37 | four numeral collisions — the eighteens, the six-of-nines, the two T3s, the three threes |
| I-40 | recording a decision is not executing it; asserting a fact is not verifying it — five instances |
| **I-42** | **a check that errors is not a check that catches** |

Plus the rewritten L-T12-b above. **Full assembly is P3's job** — these are collected and sourced,
not written up.

## STOP — awaiting Part 2 (P3)
