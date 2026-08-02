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
| 11 of 13 manifest rows moved to **SHIP** | `Output/audit/AUD1_manifest_delta_REM1.csv` (13 rows) | Gate P1 `ship_flag` is **read from this file**, not re-decided |
| `table_asset` created and populated | live: 2 rows — `table_t13_gatec_classification` (115), `table_t1_conserved_paddock_comparison` (4) | T1 csv and T2 are **already registered**; P1 must not re-register them |
| M3 moved DECIDE → SHIP, render CURRENT | delta row `M3` | matches the P2 ruling; no re-render |
| T1: csv is `HOLD`, png is `SHIP` | delta rows `T1 (source, NOT the pack item)` and `T1` | **⚠ conflicts with the P2 ruling** — see §4.2 |
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

### 4.2 ⚠ P2's item arithmetic does not reconcile with itself

Spec §3 P1 says **16 items → 14 files**. Spec §3 P2's M4b row then says **"17 items, 15 files"**.
P4 §4 says copy **15 files**. So the spec's own acceptance criterion at P1 (*"16 rows, 14 distinct
paths"*) is contradicted by P2 and P4. Reading it as sequential — P1 builds 16/14, P2 adds M4b to
make 17/15 — is the only consistent reading, but then **P1's stated acceptance can never pass as
written**. Flagged, not resolved.

### 4.3 ⚠ P2's T1 ruling contradicts the AUD-1 delta

P2 rules *"the `.csv` is the pack item; the `.png` is its rendering"*. The delta file records the
opposite: `T1` (the **png**) `ship_flag_after = SHIP`, while `T1 (source, NOT the pack item)` (the
**csv**) is `HOLD` — and its label explicitly says the csv is *not* the pack item.

The ruling is a design-seat decision and stands. But it **inverts an already-registered flag**, so
P1 cannot simply read `ship_flag` from the delta for T1. Naming it here so it is not silently
reconciled.

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
   allows. **This retires §1's concurrency machinery**: with a single writer there is no interleaving
   to guard against, no branch handoff, and the "LANE 1 waits at P4" rule is satisfied by
   construction. The before/after probes are **kept** — they still catch an external writer, which
   is what caught TaskU during AUD-1.
2. **Branch policy — RULED: CLAUDE.md governs. Commit straight to `main`**, STOP at each gate, no
   feature branches, no PRs. Spec §7's "branch and PR with human merge" is superseded by the
   standing rule adopted 28 July, under which every task since has run.

**One contradiction I have resolved myself**, flagged not asked: §1's write-scope table says LANE 1
writes `Output/pack/` only and LANE 2 `Output/tables/`, `Output/figures/` only — but §2 and §5
require change reports in `docs/change_reports/`. Read as the table governing **data** writes, with
change reports always permitted. This report is written on that reading.

## 6. Nothing changed

No code written. No DB write. No file modified. `docs/change_reports/PACK1_RPTSCOPE_gate0_recon.md`
is the only artefact created by this gate.

## STOP — design-seat review before Gate P1 / R1.
