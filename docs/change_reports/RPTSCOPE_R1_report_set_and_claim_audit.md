# RPT-SCOPE Gate R1 — the report set and the claim audit

**Spec:** `Gayini_PACK1_RPTSCOPE_spec_20260802.md` v1 + design-seat rulings 3 Aug.
**Date:** 3 August 2026 · **Prior:** `afc9078`
**Scope:** D1 report set · D2 claim audit · B1 reproduction status · input freeze.
**R1 WRITES NO DB ROWS.** Every read `mode=ro` + `PRAGMA query_only=1`.
**Producers:** `scripts/12_zone_stratum/build_RPTSCOPE_R1.py` · `scripts/11_database/build_RPTSCOPE_reproduction_status.py`

---

## 0. Inputs frozen — the delta moved under both of us

A second CC session rewrote `AUD1_manifest_delta_REM1.csv` at **2 Aug 17:59**, after the design
seat's copy was taken. Both inputs are now frozen and **P1 reads only the frozen copies**:

| frozen copy | source | sha256 | source mtime | rows |
|---|---|---|---|---|
| `Output/pack/PACK1_input_delta_FROZEN.csv` | `AUD1_manifest_delta_REM1.csv` | `a877329a6e2b1791efe2caff5f4b09dd3bf14e15ddc9780334851bda18d42642` | 2026-08-02 17:59:59 | **13** |
| `Output/pack/PACK1_input_manifest_FROZEN.csv` | `AUD1_pack_manifest_draft.csv` | `9712f0f967ab81dc109d575392ede346f9fe391659968e2defea9705fe15e06e` | 2026-08-01 17:18:28 | 535 |

**Both counts recorded, per the ruling — the disagreement is the finding, not an error by either
party.** The design seat counted **12 rows** and that was correct for the file as it stood; this
session counts **13** and that is correct for the file as it now is. Divergence of the live file
from these shas later is a **reportable finding, not something to re-sync**.

## 1. RULING RECORDED — T1 is the CSV. Final.

**decided_by: design seat, this session · 3 August 2026.**

- Register v3 classes item **T1 as a Table**. A Table item whose shipped artefact is a PNG is
  internally inconsistent, and Adrian checks numbers.
- **`Output/tables/T1_conserved_paddock_comparison.csv` IS pack item T1.**
- The `.png` ships alongside as **`T1_render`**, in the same folder, listed in the contents as the
  rendering of T1 — **not** as a separate item.
- Both are already registered. Neither needs re-registering.
- Counts unchanged: **17 items, 15 files.** `T1_render` is not a seventeenth item.

**The delta's contrary line is unattributed and is not to be followed.** `reason_detail` on the
`T1 (source, NOT the pack item)` row asserts *"design seat 2 Aug — the .png is pack item T1"*. **No
such ruling was issued.** REM-1's own `table_asset.provenance_note` correctly records the question
as *"a design-seat decision, deliberately not made here"*. The delta's line post-dates that and
attributes a decision that does not exist. Recorded here so P1 does not follow it.

## 2. B1 SETTLED — from the per-row table, not the summary string

`Output/tables/RPTSCOPE_reproduction_status.csv`, 88 rows, one line per registered number.

### The four counts, stated explicitly

| count | value |
|---|---|
| rows registered in `dim_headline_number` | **88** |
| rows carrying a pinned value | **85** |
| rows the test **iterates** | **85** |
| rows that **recompute and agree** | **71** |

Status breakdown: **71 REPRODUCES · 14 NO_DERIVATION_PATH · 3 NOT_PINNED_deliberate**.

**Reading B is correct, and the arithmetic settles it: 14 + 71 = 85 = the pinned rows.** Had
Reading A held, 57 rows would carry `REPRODUCES`. None do. **57 appears nowhere in the data.**

> **Coverage = 71 of 85 pinned rows = 84%** (71/88 = 81% of registered rows).
> **Value drifts = 0.** Every one of the 14 failures is a missing derivation path.

**v3's "57 of 71" is wrong**, and so is the spec's "57 of 88". Coverage did not *fall*: the 71 is
unchanged since 31 July; the denominator grew as REM-1 and TaskU added pins.

**The sentence for `How_we_know`,** which is true under any reading and is the important half:
*no registered number has moved — every failure is a missing derivation, not a wrong value.*

**The test's summary string is defective** and is logged as **I-36**: `checked` counts only rows
with a derivation path, while `fails` counts both drifts and missing paths, so the two have
different denominators and the missing-path rows are not a subset of the checked ones. **Rule
meanwhile: never quote the exit string; quote the status table.** Fix is one line but edits a green
test during a delivery window — post-deadline.

## 3. D1 — the report set

`Output/tables/RPTSCOPE_report_set.csv` — **7 paddock + 25 site = 32 documents**. Every row carries
`selection_rule` ∈ {A, B1, B2}; asserted in the producer.

| arm | paddocks | sites |
|---|---|---|
| **A** — every `No grazing` paddock, complete | Bala 26ca, 27ca, 28ca, 29ca | 3 · 0 · 8 · 10 |
| **B1** — grazed, named in a register-v3 claim or pack caption | Bala 15 (claim 6, residual rank 1), Dinan 10 (F5/M5b captions, rank 3) | 0 · 0 |
| **B2** — grazed, most reportable sites | Dinan 8 | 4 |

**Three of seven paddocks have zero sites**, so the graceful-degradation path is exercised by 43%
of the set. It must work before the batch.

### ⚠ A trap in the B2 rule, found by the count coming out wrong

The first run produced **21 sites, not 25**. Cause: **18 reportable plots have `zone_name IS NULL`
— they sit in no management zone at all, and that bucket is the single largest group**, larger than
Bala 29ca's 10. `max()` over "grazed paddocks by site count" therefore selected the **unzoned
bucket**, which is not a paddock, and B2 contributed nothing.

`zone_name IS NOT NULL` is now load-bearing in the producer, commented as such. **B2 correctly
resolves to Dinan 8 (4 sites)** and the total is 25. Worth noting beyond R1: **18 non-treed
monitoring plots are outside every management zone** — that is a fifth of the reportable plot set
and it belongs in the report stream's scoping.

## 4. D2 — the claim audit

`Output/tables/RPTSCOPE_claim_audit.csv` — **4 PINNED · 5 SOURCED · 1 UNSUPPORTED**. Every SOURCED
row carries the query that produced it.

| claim | state | computed | stated | agrees |
|---|---|---|---|---|
| REG-C1a no trend, +0.06 pp/yr | PINNED | 0.057 | 0.06 | ✓ |
| REG-C1b r = 0.22 | PINNED | 0.222 | 0.22 | ✓ |
| REG-C3 water explains about half | PINNED | r² = 0.504 | ~0.50 | ✓ |
| REG-C6a eight recovering | PINNED | 8 | 8 | ✓ |
| REG-C6b five survive drop-two | SOURCED | 5 | 5 | ✓ |
| REG-C6c strongest improver is grazed (Bala 15, rank 1) | SOURCED | rank 1 | 1 | ✓ |
| REG-C7 12 of 16 declining in Bala | SOURCED | 12 | 12 | ✓ |
| BYQ-Q2a spread > difference in six of nine strata | SOURCED | 6 | 6 | ✓ |
| BYQ-Q2b restricted to >1 conserved paddock | SOURCED | **6 of 7** | 6 of 7 | ✓ |
| BYQ-Q2c "within 1.5 to 3.3 pp" | **UNSUPPORTED** | — | 1.5–3.3 pp | ✗ |

### The Q2 probe — method check passed, and the truer statement confirmed

*Six of nine* reproduces **exactly** from `v_zone_stratum_contrast_bala_robust`, and is **not** in
`dim_headline_number` → **SOURCED**. F6's caption draws it, so it is **drawn but unpinned**.

**"Six of the seven strata with more than one conserved paddock" is the truer statement and is
confirmed** — but with one correction to the reason. The three failing strata are all Aeolian, and
**two** of them have `n_ungrazed = 1` so their spread is 0.0 by construction. **The third, Aeolian
high, has `n_ungrazed = 2`** — spread 3.4 pp against a difference of 22.6 pp. It fails **on merit,
not by construction.** So the restriction removes two degenerate strata, not three, and the claim
strengthens from 6/9 (67%) to **6/7 (86%)**.

### Riverine — Gate E in numbers. Candidate pin for R2, NOT registered here.

| Riverine band | internal spread among conserved | conserved−grazed difference |
|---|---|---|
| high | **36.5** pp | 0.9 pp |
| low | **19.2** pp | 9.0 pp |
| mid | **28.2** pp | 10.9 pp |

All six values reproduce exactly. The reference set's internal disagreement is 3–40× the signal it
is meant to measure. **Added to R2's pin list. Not registered at R1.**

## 5. The UNSUPPORTED queue — design-seat decisions required

**One claim, and it is live in a client-facing sheet.**

- **BYQ-Q2c** — the `By_question` Q2 answer cell still reads *"the conserved paddocks track the
  grazed median **within 1.5 to 3.3 percentage points**"*. That range exists only inside the caveat
  of `ref_grazed_floor_gap_3pdk_periodwise`, which is **permanently unpinned (PIN 3)**; spec §6
  calls its reappearance a regression and P4 §3 forbids the wording. Register v3 already removed it
  from the register — **it survives in the workbook**, which is what P4 rebuilds.
  **Replacement is R2's new pin** (the annual three-paddock gap). Flagged, not rewritten at R1.

## 6. Concurrency probes

| | `dim_headline_number` | `figure_asset` | `raster_asset` | `table_asset` | `report_asset` | DB mtime |
|---|---|---|---|---|---|---|
| Gate 0 baseline | 88 | 287 | 186 | 2 | 59 | 2026-08-02 12:09:44 |
| R1 close | 88 | 287 | 186 | 2 | 59 | 2026-08-02 12:09:44 |

**No movement.** R1 opened no writable connection.

## 7. Nothing changed in the database

Three CSVs written to `Output/tables/`, two frozen inputs to `Output/pack/`, one issues-log row
(I-36). **No DB row created, modified or deleted.**

## STOP — end of R1.
