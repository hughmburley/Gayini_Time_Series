# PACK-1 / RPT-SCOPE — Gate 0 recon (both lanes)

**Spec:** `docs/reference_update/Gayini_PACK1_RPTSCOPE_spec_20260802.md` v1 · 2 Aug 2026
**Date:** 2 August 2026 · **Status:** DRAFT — no code written, no DB write, read-only throughout.
**Deviation, flagged:** the spec asks for `{lane}_gate0_recon.md` per lane. This is **one session
covering both lanes**, so one combined report. See §5 — lane assignment is an open question.

**Every read used `mode=ro` + `PRAGMA query_only=1`.** No writable connection was opened.

---

## 1. §2.3 Environment facts — stated, not assumed

| fact | value |
|---|---|
| DB path | `Output/database/Gayini_Results.sqlite` |
| DB size | 83,365,888 bytes |
| DB mtime | 2026-08-02 12:09:44 |
| sha256 (first 50 MB) | `64298ac0f1cf4a4b2666f8e706aacd60370a0ea7df20d22ac316b64dc5996b4e` |
| tables / views | **92 / 34** |
| `dim_headline_number` | **88** ✓ matches the spec's stated live state |
| `figure_asset` | 287 |
| `raster_asset` | 186 |
| `table_asset` | **2** |
| `report_asset` | 59 |
| git branch | `main`, level with `origin/main` (0/0) |
| HEAD | `ecbaa62` — *Deliverables register v2 → v3* |
| working tree | **NOT clean** — 7 deleted `figures/diagnostics/T12_DEA_*.png` unstaged, plus ~20 untracked docs/dirs |

**`main` has moved 13 commits since this session last touched it** (31 Jul → 2 Aug): Task U Gates
U0–U3, REM-1 Gates B–E, closeout C2, register v3. All six of the 31 July commits are still
ancestors of HEAD — nothing was rebased away.

This is the **concurrency probe baseline** for both lanes.

---

## 2. §2.2 The already-done register — what must NOT be re-derived

| established | evidence | consequence for this spec |
|---|---|---|
| **9 rows moved to SHIP** (8 HOLD→SHIP + 1 DECIDE→SHIP); 10 rows *are* SHIP after | `Output/audit/AUD1_manifest_delta_REM1.csv` — **13 rows**, sha `a877329a…`, untracked | Gate P1 `ship_flag` is **read from this file**, not re-decided |
| `table_asset` created and populated | live: 2 rows — `table_t13_gatec_classification` (115), `table_t1_conserved_paddock_comparison` (4) | T1 csv and T2 are **already registered**; P1 must not re-register them |
| M3 moved DECIDE → SHIP, render CURRENT | delta row `M3` | matches the P2 ruling; no re-render |
| T1: csv `HOLD → HOLD`, png `SHIP → SHIP` | delta rows `T1 (source, NOT the pack item)` and `T1` | see §4.3 — a **later** design-seat ruling, not a REM-1 one |
| 9 of 10 held figures byte-identical on re-render | AUD-1 Gate A | **no re-render at P3**; open to read, do not rebuild |
| constants test passed | REM-1 | do not re-run as a "check" |

## 3. §2.1 Reuse register

**No existing producer** was found for any PACK-1 or RPT-SCOPE artefact — `git grep -il` over
`scripts/` and `R/` returns nothing for `RPTSCOPE`, `T14`, `PACK1` or `pack_manifest`.

| required artefact | existing producer | existing output | verdict |
|---|---|---|---|
| `Output/pack/PACK1_item_list.csv` | NONE | NONE (`Output/pack/` does not exist) | **NEW** — no artefact enumerates pack items with sha + ship_flag + caption_status; the AUD-1 manifest is 535 rows of *all* outputs, not the 16-item list |
| `Output/pack/Gayini_Adrian_pack.xlsx` | NONE | `Output/Gayini_Adrian_pack_contents.xlsx` (5 sheets) | **EXTEND** — reuse sheet structure; spec §3 P4 requires content regenerated from live queries |
| the 15 pack files | various, all built | all on disk, verified by AUD-1 | **REUSE** — copy only |
| `Output/tables/RPTSCOPE_report_set.csv` | NONE | NONE | **NEW** — no artefact expresses the report set as a rule-selected list |
| `Output/tables/RPTSCOPE_number_contract.csv` | NONE | NONE | **NEW** — nothing maps report page/panel → `number_id` |
| the new 3-paddock gap pin | NONE as a pin | `T10_annual_gap_series.csv` **has the series** (`B_excl29ca`, 35 rows) | **EXTEND** — the annual series exists and is committed; R2 aggregates it and registers, it does not recompute the series |
| `Output/tables/T14_level_metric_sensitivity.csv` | NONE | NONE | **NEW** — no within-community floor~flood fit exists at part grain |
| derivations for 12 REM-1 rows | `scripts/11_database/test_T8_headline_reproduction.py` | test at 57 of 88 | **EXTEND** — add `recompute_*` paths, same pattern as `recompute_t13()` |

**One reuse worth naming:** R2's pin is an aggregation of a series already committed at T10 Gate B,
not a new computation. That is the difference between EXTEND and NEW here.

---

## 4. Findings that change what the spec asks for

### 4.1 ⚠ Register **v3** landed after the spec was written — several steps are candidate strikes

The spec cites "register v2" throughout. **v3 exists**, committed at `ecbaa62`:

| | file | version | mtime |
|---|---|---|---|
| live | `docs/reference_update/Gayini_deliverables_register.md` | **v3** | 2 Aug **13:19** |
| stale copy | `docs/reports/Gayini_deliverables_register.md` | v2 | 31 Jul 20:59 |

The spec file's own mtime is **10:50 on 2 Aug** — so it was written **before v3 landed**. v3's
changelog states it already did four things this spec asks CC to do:

| spec step | v3 changelog | candidate verdict |
|---|---|---|
| P1 — "§6 says eighteen / seventeen. Both are wrong" | *"(4) §6 item arithmetic corrected: sixteen items, not eighteen"* | **likely STRIKE** — but see §4.2, the counts still disagree |
| P4 §3 — "do not use *within 1.5 to 3.3 pp*" | *"(1) Claim 1 split: the unpinned '1.5 to 3.3 pp' range removed"* | **likely STRIKE** in the register; still applies to the workbook |
| P3 — M3's two undrawn clauses | *"(2) M3 caption rewritten to describe the figure as rendered; SPECIFIED → EXISTS"* | **likely STRIKE** — verify the rewrite covers both clauses |
| P4 §2 — "re-derives all sixty-five" is false | *"(3) §5 counts updated to 88 rows / 57 of 71 independently re-derived"* | **PARTIAL** — fixed in the register, **not** in the workbook, which is what P4 builds |

**Not struck unilaterally.** Per §2.2 these need evidence, and the spec says report the strike. I
have read v3's changelog, not yet audited v3's §6 line by line. That audit is the first thing after
this STOP.

**Second-order risk:** the stale v2 at `docs/reports/` is I-17's discrepancy class #1 — two dated
copies of one artefact. A later session told to read "the register" can reach the wrong one.
Recommend archiving it; not touched here.

### 4.2 RESOLVED — item arithmetic

Raised as a self-contradiction (P1 said 16→14, P2 said 17/15, P4 said 15 files). **RULED 3 Aug: a
spec error, not an ambiguity. M4b is in the item list from the start.** P1 builds **17 items → 15
distinct files**, and P1's acceptance criterion is now *"17 rows, 15 distinct non-null paths"*.
P2's M4b row is a confirmation, not an addition; P4's "copy 15 files" was already correct.

### 4.3 ⚠ RESTATED — two design-seat rulings on T1, in opposite directions, same day

**The original 4.3 said REM-1 ruled against P2. That was wrong and is withdrawn** — REM-1 did
decline to rule. But the conflict is real and sits elsewhere, so the finding stands restated:

| source | mtime | says |
|---|---|---|
| `table_asset.provenance_note` (REM-1) | — | *"WHICH ONE IS THE PACK ITEM IS A DESIGN-SEAT DECISION, **deliberately not made here**"* |
| spec §3 **P2** | 2 Aug **10:50** | *"the **`.csv`** is the pack item; the `.png` is its rendering"* |
| `AUD1_manifest_delta_REM1.csv` `reason_detail` | 2 Aug **17:59** | *"HOLD is a RULING, NOT A DEFECT: design seat 2 Aug — **the `.png` is pack item T1**; this `.csv` stays registered as the source but does not go in the pack"* |

REM-1 handed the question up, exactly as stated. **It was then answered twice, seven hours apart,
in opposite directions** — and the delta's answer is the later one. The spec's P2 and the delta's
`reason_detail` cannot both govern.

**Not reconciled.** P1 needs one answer. Flagged for the design seat.

### 4.4 The user named a workbook the spec rules stale

`Output/Gayini_Adrian_pack_contents.xlsx` was given as a key reference. Spec §3 says it is **not**
the input of record — it names `Gayini_reference_state_methods.md` as a client item, which would
ship pre-pin numbers. **Treated as structural reference only** (sheet layout for P4), never as
content. The inputs of record are the two AUD-1 CSVs, both present.

### 4.5 R1's site counts already reproduce exactly

Independent query, `plot_paddock` excluding `Floodplain Woodland / Forest`:

| paddock | sites | spec |
|---|---|---|
| Bala 29ca | 10 | 10 ✓ |
| Bala 28ca | 8 | 8 ✓ |
| Dinan 8 | 4 | 4 ✓ |
| Bala 26ca | 3 | 3 ✓ |
| Bala 27ca · Bala 15 · Dinan 10 | 0 | 0 ✓ |

**25 site reports + 7 paddock reports = 32 documents** — the spec's arithmetic holds. The four
`grazing_excluded = 1` paddocks confirm Arm A. Arm B1 still requires auditing register-v2 claims and
captions for named grazed paddocks; not done at Gate 0.

---

## 5. Two questions raised at this gate — both RULED, 3 Aug

1. **Lane assignment — RULED: both lanes, sequentially, in this session.** Order follows the
   spec's own constraint (R2 before P4): **R1 → R2 → P1 → P2 → P3 → P4**, then R3, then R4 if time
   allows. It satisfies "LANE 1 waits at P4" by construction and needs no branch handoff.

   **AMENDED 3 Aug — the earlier claim that this "retires §1's concurrency machinery" was wrong and
   is withdrawn. There is a second writer and it is ACTIVE.** TaskU landed Gates U0–U3 in the 13
   commits since 31 July, including U3 *after* AUD-1's own Gate D re-probe — visible as
   `figure_asset` 287 here against Gate D's 286. **Probes stay, and any movement at a write gate is
   a STOP, not a reconcile.** One such event already occurred during this gate: see §4.6.
2. **Branch policy — RULED: CLAUDE.md governs. Commit straight to `main`**, STOP at each gate, no
   feature branches, no PRs. Spec §7's "branch and PR with human merge" is superseded by the
   standing rule adopted 28 July, under which every task since has run.

**One contradiction I have resolved myself**, flagged not asked: §1's write-scope table says LANE 1
writes `Output/pack/` only and LANE 2 `Output/tables/`, `Output/figures/` only — but §2 and §5
require change reports in `docs/change_reports/`. Read as the table governing **data** writes, with
change reports always permitted. This report is written on that reading.

### 4.6 Concurrency event during this gate — filesystem only, DB verifiably unmoved

Between the Gate 0 recon and the B2 housekeeping step, `docs/reports/Gayini_deliverables_register.md`
**moved** to `docs/archive/Gayini_deliverables_register_superseded.md` — same 12,613 bytes, same
31 Jul mtime. Both paths are untracked, so git records nothing and the move left no trace to find
later.

**Re-probed immediately.** DB mtime `2026-08-02 12:09:44` — **identical** to the Gate 0 baseline;
`dim_headline_number` 88, `figure_asset` 287, `raster_asset` 186, `table_asset` 2, `report_asset` 59
— **all unchanged**. `origin/main...main` 0/0. So the event is filesystem-only and touched no
registered object.

**Reported, not reconciled silently** — which is the §1 rule and the reason A4 amends the "single
writer" claim. B2 was completed rather than repeated: the file was already moved, so the missing
half — the superseded-by header naming v3 and `ecbaa62` — was added to it in place.

*Note: the archived filename carries neither the version nor the date (`..._superseded.md`, not
`..._v2_20260731_superseded.md`). Left as found rather than moved a second time during an active
concurrency window. Flagged.*

### 4.7 ⚠ B1 — the reproduction denominator. Both quoted figures are wrong.

**Taken from the test's own exit**, per the ruling — not from v3, not from AUD-1, not from the spec:

```
T8 reproduction: 14 DRIFTED of 71 checked        (exit 1)
```

Cross-read against the registry itself:

| quantity | value | object read |
|---|---|---|
| `dim_headline_number` rows | **88** | live `COUNT(*)` |
| rows with `pinned_value NOT NULL` — what the test iterates | **85** | live `COUNT(*)` |
| deliberately unpinned | 3 | live |
| pinned rows **with** an independent derivation | **71** | test exit, `checked` |
| pinned rows **without** one | **14** | test exit, `fails` |
| of the 71 checked, **real value drifts** | **0** | every one of the 14 reads `NOT RECOMPUTED` |

**The honest sentence is: 71 of 85 pinned numbers re-derive independently, and all 71 that can be
checked reproduce. 14 pins have no derivation path.**

- **v3's "57 of 71" is wrong on the numerator.** 71 is the count that *reproduces*, not the denominator.
- **The spec's "88 rows with 57 independently re-derived" is wrong on both**, and its "coverage fell
  from 96% to 65%" does not follow. Coverage is **71/85 = 84%** of pinned rows, or 71/88 = 81% of the
  registry. It did not fall — the 71 is unchanged since 31 July; the *denominator* grew as REM-1 and
  TaskU added pins.
- **Nothing has drifted.** The failures are missing derivations, not wrong numbers. That distinction
  is the whole of the difference between "the registry is unreliable" and "the registry is incomplete".

**Consequence for R4, which the spec understates:** there are **14** rows needing derivations, not
twelve — the twelve `three_arm_*` REM-1 pins **plus two `taskU_denominator_*` pins** registered after
the spec was written. R4's scope grows by two.

## 6. Nothing changed

No code written. No DB write. No file modified. `docs/change_reports/PACK1_RPTSCOPE_gate0_recon.md`
is the only artefact created by this gate.

## STOP — design-seat review before Gate P1 / R1.
