# RPT-SCOPE R1b — claim audit to full coverage, and the third arm

**Date:** 3 August 2026 · **Prior:** `aadd621` · **READ-ONLY. NO DB WRITES.**
**Producer:** `scripts/12_zone_stratum/build_RPTSCOPE_R1b_claim_audit_extend.py` (append-only).

---

## 1. R1b-1 — coverage is now complete, and checkable

`Output/tables/RPTSCOPE_claim_audit.csv` — **22 rows**, appended only; the ten R1 rows were not
re-audited.

| declared | covered | missing |
|---|---|---|
| register v3 §1 claims | **7 of 7** | — |
| `By_question` cells | **7 of 7** | — |
| **14 claims → 22 audit rows** | | some claims decompose into >1 checkable assertion |

**States: 6 PINNED · 14 SOURCED · 1 DERIVED · 1 UNSUPPORTED.**

**UNSUPPORTED did not rise above one**, so the scope signal did not fire. The single row remains
BYQ-Q2c, the "within 1.5 to 3.3 pp" range still live in the workbook's Q2 cell.

### Everything that could be checked, reproduced

| claim | computed | stated |
|---|---|---|
| REG-C2a 29ca's improvement, slope | +0.919 pp/yr | +0.919 |
| REG-C4a 82% of the improvement survives water adjustment | **81.6%** | 82 |
| BYQ-Q3a 17 pp shortfall, second largest | **16.80**, rank **2** of 64 | 17, second |
| BYQ-Q1 cropping history empty | **64 of 64 NULL** | 64 of 64 |
| BYQ-Q4 standard grazing at or above rotational | **6 of 9** | 6 of 9 |
| BYQ-Q5 water explains about half | r² = **0.504** | ~0.50 |
| BYQ-Q6 three to fifteen parts improving | **3 to 15** | 3 to 15 |

**Two `agrees = 0` values are rounding, not disagreement.** REG-C4a (81.6 vs 82) and BYQ-Q3a
(16.80 vs 17) both round to the stated figure. The `agrees` column uses a flat ±0.051 tolerance,
which is over-strict for claims stated as whole numbers — the same class as the half-ulp tolerance
error corrected on 31 July. **Read those two as agreeing at the precision the claim states.**

### ⚠ One claim needs narrowing — REG-C5

*"Three of four conserved paddocks sit almost entirely in the property's easiest country."*
Ranking all 64 paddocks by mean flood frequency (1 = wettest):

| paddock | rank of 64 |
|---|---|
| Bala 26ca | **3** |
| Bala 28ca | **6** |
| Bala 27ca | **31** |
| Bala 29ca | **61** |

**Two are unambiguously in the easiest country. Bala 27ca is rank 31 — the middle of the
property, not the easy end.** The claim is directionally right and overstated by one paddock. The
defensible form is *"two of the four sit in the wettest tenth, a third is middling, and only
Bala 29ca is at the dry end"* — which still carries the argument that the set is not
representative. **Flagged for the design seat; not rewritten here.**

### Two claims that are not numbers, marked as such

- **REG-C2b** *"Bala 29ca produces every reference-state result the project has"* — **DERIVED**.
  True, but not reducible to one query; it rests on C1 (no trend once 29ca is set aside) plus 29ca's
  rank-2 residual. Carried as an interpretation, not a measurement.
- **REG-C2a's "predates by thirty years"** — the **slope** is pinned and reproduces; *"thirty
  years"* is an interpretation of where the series starts (1988) against when management changed
  (2019). Marked in the note so it is not mistaken for a computed quantity.

**BYQ-Q7a and Q7b were not independently recomputed.** Q7a's 43.6% / 22.8% inundation pair is a
register statement with no `number_id`; Q7b's 24 placebo dates come from Task J, which is complete
but blocked on Jana. Both are SOURCED with the gap stated rather than papered over.

**BYQ-Q5 duplicates REG-C3** — one quantity (r² = 0.504) asserted in two places. Noted so P4 does
not register it twice.

## 2. R1b-2 — the fraction, corrected

**18 unzoned reportable plots of 57 = 31.6%.** My "a fifth" was wrong.

**The "18%" is not the area share either.** Checked: unzoned country by area is
`total_no_management_zone_ha` 30,711.6 / `TRUE_FARM_HA` 85,910.8 = **35.7%**. The stray *18* is
**18,561.5 ha** — `property_outside_mapped_ha`, an area, not a percentage.

**Logged as I-37**: the numeral 18 names three different objects here — 18 unzoned reportable
plots, 18 *zoned* 14-day reportable plots, and 18,561.5 ha outside the mapped census. Three readers
reached for it and none of the three readings matched. Rule recorded: state the unit and the
denominator in the same sentence.

## 3. R1b-3 — the third arm is excluded by construction, and now says so

**Confirmed exactly.** The 18 unzoned reportable plots split **15 Standard grazing · 3 14-day**.

Read from `plot_paddock.plot_treatment` — **not** `grazing_treatment`, which is derived from the
zone join and is therefore NULL for all 18. That is the trap: the obvious column reports nothing
for precisely the rows in question.

| `plot_treatment` | zoned | unzoned |
|---|---|---|
| No grazing | 21 | 0 |
| 14-day grazing | 18 | **3** |
| **Standard grazing** | **0** | **15** |

**Every Standard-grazing reportable plot on the property is unzoned. Not one is zoned.** So the
third arm — the one T6 exists to measure because it has never been measured — has **zero paddock
parents**, and a report set built by nesting sites under paddocks excludes it **completely, by
construction**.

Two `EXCLUDED` rows are now in `RPTSCOPE_report_set.csv` (34 rows: 7 paddock + 25 site + 2
exclusion), carrying the reason and the date. **A stated exclusion, not an artefact of a join.**

## 4. R1b-4 — R2's pin list carries five candidates, not three

| # | candidate | state | evidence |
|---|---|---|---|
| a | annual three-paddock reference-grazed gap | spec R2 §3 | replaces claim 1's unpinned source |
| b | Riverine reference-set internal spreads 36.5 / 19.2 / 28.2 | SOURCED | vs differences 0.9 / 9.0 / 10.9 |
| c | six-of-seven restricted stratum count | **SOURCED** — confirmed at R1b | the restriction is the truer statement |
| **d** | **five of eight recovering parts survive drop-two-wettest** (REG-C6b) | SOURCED | drawn in claim 6 and M4, unpinned |
| **e** | **82% of Bala 29ca's improvement survives water adjustment** (REG-C4a) | SOURCED | 81.6%, drawn in Q3 and claim 4, unpinned |

**d and e are new from R1b's extended coverage** — both are load-bearing client-facing numbers with
no `number_id`. **None registered at R1b.**

## 5. The UNSUPPORTED queue

**One row.** BYQ-Q2c — the `By_question` Q2 cell's *"within 1.5 to 3.3 percentage points"*,
sourced only from the caveat of the permanently unpinned `ref_grazed_floor_gap_3pdk_periodwise`
(PIN 3). Register v3 removed it; it survives in the workbook that P4 rebuilds. **R2 candidate (a)
is its replacement.**

## 6. Probes

| | `dim_headline_number` | `figure_asset` | `raster_asset` | `table_asset` | `report_asset` |
|---|---|---|---|---|---|
| R1b open | 88 | 287 | 186 | 2 | 59 |
| R1b close | 88 | 287 | 186 | 2 | 59 |

DB mtime `2026-08-02 12:09:44` unchanged at both ends. **No writable connection opened.**

## STOP — end of R1b.
