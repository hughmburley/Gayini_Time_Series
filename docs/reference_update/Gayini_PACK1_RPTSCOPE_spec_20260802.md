# PACK-1 / RPT-SCOPE — CC build spec

**Version:** v1 · 2 August 2026 · design seat
**Supersedes:** the ADR-1, T14, REP-4 and REP-5 rows of `Gayini_path_to_Aug10_tracker.xlsx` v3
**Deadline:** 10 August 2026. Six working days plus today. Sunday 9 August is contingency and stays empty.
**Written for:** two concurrent Claude Code sessions, LANE 1 and LANE 2, with disjoint write scopes.

---

## 0. What changed, and why this spec exists

Two decisions have been taken at the design seat and are not open for re-litigation inside a gate:

1. **The client report batch is scaled back from 78 documents to 32.** All four conserved
   paddocks and their sites, plus a small grazed comparison set chosen by a pre-registered rule
   (§4). Quality over coverage. The remaining 46 documents are post-deadline.
2. **The Adrian pack is the primary deliverable for 10 August.** Everything else is judged by
   whether it moves a named pack item.

A third decision is recorded in §6 and CC must read it before touching anything called T14.

**AUD-1 and REM-1 have already done work this spec would otherwise duplicate.** Nine of ten held
pack figures were verified clean and byte-identical on re-render; the constants test passed;
`table_asset` exists; two items were registered. **CC must not repeat any of it.** Gate 0 exists
to make sure it does not.

---

## 1. Concurrency discipline — read this before starting either lane

AUD-1 caught a live concurrent write (TaskU) and flagged 35 rows. That was a read-only audit and
it still cost a Gate D re-probe. Two writing sessions is a materially larger risk.

**The rule is sequenced write windows, not concurrent writes.**

| | LANE 1 (PACK-1) | LANE 2 (RPT-SCOPE) |
|---|---|---|
| Branch | `feature/pack1-assembly` | `feature/rptscope-contract` |
| Filesystem writes | `Output/pack/` only | `Output/tables/`, `Output/figures/` only |
| Database | **READ-ONLY** until Gate P4 | writes at Gate R2 and Gate R4 only |
| Registry tables touched | `table_asset`, `report_asset` (at P4 only) | `dim_headline_number`, `table_asset` |

**Mandatory protocol for both lanes:**

- Open SQLite `mode=ro` with `PRAGMA query_only=1` for every read. Only the two named write gates
  open a writable connection, and each holds it for a single short transaction.
- **Before and after every write gate**, record a probe: row counts of `dim_headline_number`,
  `figure_asset`, `raster_asset`, `table_asset`, `report_asset`, plus the DB file mtime. Write
  them into the gate's change report. A single probe at the start of a multi-hour task is not
  sufficient — that is the AUD-1 finding.
- If a probe shows the other lane has advanced a table this lane depends on, **STOP and report**.
  Do not reconcile silently.
- **LANE 2 Gate R2 must complete and be merged before LANE 1 Gate P4 begins.** If LANE 1 reaches
  P4 first, it waits. This is the only ordering constraint between the lanes.
- Neither lane runs `git` index operations on the other's branch. Human merges only.

---

## 2. Gate 0 — recon, both lanes, before any code is written

**This gate is the answer to "do not repeat ourselves". It is not optional and no code is written
until it is reviewed.**

Each lane produces `docs/change_reports/{lane}_gate0_recon.md` containing:

### 2.1 The reuse register

Walk `scripts/`, `R/` and `Output/` and produce a table: for every artefact this lane's spec asks
for, does something already exist that produces it or is it?

| required artefact | existing producer | existing output | verdict |
|---|---|---|---|
| … | script path or NONE | path + sha256 or NONE | REUSE / EXTEND / NEW |

**Hard rule: `NEW` requires a one-line justification naming what the existing candidate cannot do.**
"It would be cleaner" is not a justification. The repository already carries 143 registered
old-generation figures against 154 unregistered live ones, and 596 byte-identical duplicate
groups. Adding to that is a defect.

### 2.2 The already-done register

Explicitly list, with evidence, what AUD-1 / REM-1 already established, so this lane does not
re-derive it:

- which pack items are SHIP and on what evidence (`AUD1_manifest_delta_REM1.csv`)
- which figures were re-rendered byte-identical and therefore need no re-render
- which read their constants from `dim_headline_number` at render time
- what `table_asset` already holds

**Any step in this spec that Gate 0 shows is already done gets struck, not executed.** Report the
strike; do not do the work anyway "to be safe".

### 2.3 Environment facts

DB path, its sha256, table/view counts, `dim_headline_number` row count, git branch and HEAD, and
whether the working tree is clean. State them; do not assume them.

**STOP. Design-seat review before Gate P1 / R1.**

---

## 3. LANE 1 — PACK-1, the Adrian pack

**Input of record:** `Output/audit/AUD1_pack_manifest_draft.csv` (535 rows) and
`AUD1_manifest_delta_REM1.csv`. **Not** the stale `Gayini_Adrian_pack_contents.xlsx`, which names
`Gayini_reference_state_methods.md` as a client item and would ship pre-pin numbers under a client
cover.

**Source of truth for pack contents:** `Gayini_deliverables_register.md` v2, **with its item
arithmetic corrected** — see P1.

### Gate P1 — the corrected item list

Register v2 §6 says "one item of eighteen" and "ships with seventeen". Both are wrong: it carries
the stale workbook's total forward without recounting.

1. Produce the true list: **16 items** (M1, M2, M3, M4, M5, M5b · F1–F7 · T1, T2, T3), resolving to
   **14 distinct files** — F7 is the right panel of `T13_D1`, the same file as M4; T3 has no figure.
2. Emit `Output/pack/PACK1_item_list.csv`: one row per item with `item_id`, `type`, `file_path`,
   `sha256`, `registered_in`, `claim_supported`, `ship_flag`, `caption_status`.
3. Verify every `file_path` against disk and against the registry. Any disagreement is a STOP.

**Acceptance:** 16 rows, 14 distinct non-null paths, every path `exists=1`, no path under
`docs/` except where §3.1 rules it internal.

### Gate P2 — the four design-seat rulings, applied

These are decided. CC applies them and does not reopen them.

| item | ruling | action |
|---|---|---|
| **M3** | Ships as-is. T7 stays dropped; the recolour is presentational. | Set SHIP. Replace the caption per P3 — two clauses describe things the figure does not draw. |
| **T1** | The **`.csv` is the pack item**; the `.png` is its rendering. | `PACK1_item_list.csv` names the csv as T1; the png ships alongside as `T1_render`. Both registered. |
| **M4b** | Retained as a distinct item. | Add as `M4b` to the item list. Register v2 folds sensitivity into M4's hatching; the file exists, is registered, and shows a different thing. 17 items, 15 files. |
| **D1 / D2** | Internal apparatus. **Not pack items.** | Excluded. `Gayini_reference_state_methods.md` in particular must not ship — its §7 deficits predate the T8 pins. |

### Gate P3 — captions

Every item gets a caption that is true of the file as rendered. **Do not copy captions forward
from register v2 or the workbook** — both were written before the items were finished.

For each item, open the figure, read what it actually draws, and check the caption clause by
clause. Report a table: `item_id | caption_clause | drawn? | evidence`. Any clause that fails is
rewritten, and the rewrite is reported, not applied silently.

Two known failures to fix, not to rediscover: **M3** has two clauses describing undrawn content
and a saturating colour scale (note the saturation in the caption; do not re-render). **F6**'s
caption claims were re-verified by REM-1 after the PIN 1 fix — carry REM-1's wording, do not
re-derive.

### Gate P4 — the workbook and the folder — **WRITE GATE, waits on LANE 2 Gate R2**

1. Build `Output/pack/Gayini_Adrian_pack.xlsx` with sheets: `Start_here`, `By_question`,
   `Contents`, `Two_cautions`, `How_we_know`. Structure follows the existing workbook; **content is
   regenerated, not edited**, from `PACK1_item_list.csv` and the live database.
2. **Every number on `How_we_know` is queried live**, not typed. Current live state is
   `dim_headline_number` = 88 rows with 57 independently re-derived. The existing sheet says
   "re-derives **all** sixty-five", which is now false in kind, not merely stale — coverage fell
   from 96% to 65%. The sentence must name the covered subset, or the twelve REM-1 rows must have
   derivations written (LANE 2 Gate R4) before the claim of completeness is made.
3. `Start_here`'s opening claim takes its wording from the pin LANE 2 registers at Gate R2. **Do
   not use "within 1.5 to 3.3 percentage points"** — that range exists only inside the caveat of
   `ref_grazed_floor_gap_3pdk_periodwise`, which is deliberately unpinned and marked not to be
   revived.
4. Copy the 15 files into `Output/pack/files/`. Register the workbook in `report_asset` and any
   unregistered table components in `table_asset`. One transaction. Probe before and after.

**Acceptance:** every cell containing a number carries a `number_id` in an adjacent
`_provenance` column or a hidden provenance sheet · no sheet asserts a count that a live query
contradicts · the folder contains exactly the files named in `PACK1_item_list.csv`, no more · zip
built and hashed.

**STOP. Design-seat read-through end to end before anything leaves.**

---

## 4. LANE 2 — RPT-SCOPE, the scaled-back report set and the number contract

### Gate R1 — the report set, from a pre-registered rule

**The rule is stated here before the list is computed, and the list is a consequence of it.**

**Arm A — complete, no selection.** All four `No grazing` paddocks and every non-treed site in
them.

**Arm B — grazed comparison, by rule:**
- **B1** — every grazed paddock named in a register-v2 pack claim or caption.
- **B2** — the grazed paddock carrying the most reportable sites.

Applying the rule (design-seat prediction — CC recomputes and CC's answer stands):

| arm | paddock | why | reportable sites |
|---|---|---|---:|
| A | Bala 26ca | conserved | 3 |
| A | Bala 27ca | conserved · no sites · graceful degradation path | 0 |
| A | Bala 28ca | conserved | 8 |
| A | Bala 29ca | conserved · carries every reference-state result | 10 |
| B1 | Bala 15 | claim 6 — the strongest improver on the property is grazed; residual rank 1 | 0 |
| B1 | Dinan 10 | named in the F5 / M5b captions; residual rank 3, near-twin of 29ca on wetness | 0 |
| B2 | Dinan 8 | most reportable sites of any grazed paddock; Recovering in two communities | 4 |

**7 paddock reports · 25 site reports · 32 documents.** Emit
`Output/tables/RPTSCOPE_report_set.csv` with the rule that selected each row in a `selection_rule`
column. Any paddock in the set for a reason not in {A, B1, B2} is a defect.

Note for the builder: **three of seven paddocks have zero sites**, so the graceful-degradation path
is exercised by 43% of the set rather than by one edge case. It must work before the batch, not
after.

### Gate R2 — the number contract — **WRITE GATE**

This is the item that closes REP-PAGE4 permanently and unblocks the report builder.

1. Emit `Output/tables/RPTSCOPE_number_contract.csv`: **one row per number that report pages 1–5
   may draw**, carrying `page`, `panel`, `number_id`, `source_object`, `scope_filter`,
   `denominator`, `pixel_constant`, `support_level`, `period_label`. Numbers with no `number_id`
   are listed with `number_id = UNPINNED` and a note — that list is the handoff back to the design
   seat.
2. Register the contract in `table_asset`.
3. **Register one new pin: the annual three-paddock reference-grazed gap.** Computed from
   `fact_zone_veg_annual`, `series_variant = 'mean_of_seasons'`, reference = the three `No grazing`
   paddocks excluding Bala 29ca, grazed = median of the 60 `14-day grazing` paddocks, one value per
   water year across 35 years. Register `pinned_value` = the mean, `spread_min`/`spread_max` = the
   annual range.

   *Design-seat prediction to check: mean −2.07, range −7.04 to +4.99. The gap crosses zero. If
   CC's value differs, CC's stands and the disagreement is the finding.*

   This replaces claim 1's unpinned source. It is a stronger statement of the same claim: the three
   conserved paddocks sit about 2 pp below the grazed median on average and in some years sit above
   it. "Within 1.5 to 3.3 pp" was an artefact of averaging into five periods.

4. **Probe before and after. Merge this gate before LANE 1 reaches P4.**

**Acceptance:** every number on the five report pages resolves to a `number_id` or is explicitly
listed as UNPINNED · the new pin reproduces on a second independent run · no existing row modified
· `dim_headline_number` row count increases by exactly 1.

### Gate R3 — T14 as a robustness arm, not an analysis

**Read §6 before starting this gate.**

Compute the within-community floor~flood fit at part grain on `veg_p05_spatial` (115 parts,
`mean_of_seasons`, `n_pixels_valid >= 30`, `>= 25` years) and report it **as a sensitivity on T13's
level term**, not as a new classification.

Deliver one table, `Output/tables/T14_level_metric_sensitivity.csv`, and one paragraph:

- the three within-community fits, with n, slope, intercept, r
- per part: T13 `level_z`, the T14 residual z, and whether the part crosses the ±1.0 cut
- the recovering count under each definition

*Design-seat predictions to check: Aeolian n=17 slope −0.667 r −0.263 · Riverine n=37 slope +0.584
r +0.432 · Inland n=61 slope +0.351 r +0.659 · corr(T13 level_z, T14 residual z) = 0.829 · 12 of 115
parts cross the cut · recovering 8 → 5 · and the five that survive T14 are **not** the same five
that survive dropping the two wettest years — three parts survive both.*

**Do not register any T14 number as a pinned value. Do not redraw M4 or M4b. Do not alter
`fact_zone_community_part_classification`.** The output of this gate is a paragraph for the pack's
robustness text and nothing else.

**Report the Aeolian sign explicitly.** The within-community slope there is negative on a flood
range of 1.0–19.7%, which would draw an expectation line saying drier Aeolian country carries more
cover. That is why this is a sensitivity and not a metric.

### Gate R4 — derivations for the twelve REM-1 rows — **WRITE GATE, if time allows**

The twelve pins REM-1 registered have no independent derivation, which is why the reproduction test
fell to 57 of 88. Write derivations by an independent path and re-run
`test_T8_headline_reproduction.py`. If this gate does not land, LANE 1 P4 §2 must name the covered
subset instead of claiming completeness. **This gate is droppable; the honest sentence is not.**

---

## 5. Reporting, at every gate, both lanes

- A DRAFT change report in `docs/change_reports/`, named for the gate.
- **Finding → figure / check → number.** Every claim in the report carries the object it came from.
- The before/after concurrency probe.
- Any step struck at Gate 0 as already done, with the evidence.
- An explicit "nothing changed" where nothing changed. Silence is not a result.

---

## 6. Standing decisions CC must not reopen

- **The floor metric is `veg_p05_spatial`, pinned at T2.** `census_by_zone_stratum.veg_p05_mean` is
  the census **temporal** p05 and is a different quantity. They differ by up to 17 pp at part grain,
  in opposite directions by community. `T2_zone_annual_veg_extraction.md` §94: *these must never
  appear in the same figure or be compared numerically.* **Any gate that reaches for
  `veg_p05_mean` for a reference-state purpose is a STOP, not a judgement call.**
- **R6 is a cross-metric sensitivity, not a redefinition.** Gate E stays blocked. Nothing in the
  deck, the register or claim 4 changes.
- **PIN 2 is not revisited before 10 August.**
- **PIN 3** (the five-period trajectory) is permanently unpinned. Its reappearance anywhere is a
  regression.
- **T7 is dropped.** M3 ships as-is.
- **DECK-1 is cut** to a cover slide pointing at the pack folder.
- **T12 DEA cultivation calls never appear in a client deliverable**, at any confidence level.
- **No p-values on the annual series.** Thirty-five consecutive years are not independent.
- **Retiring a number in the registry does not retire it in the code.** PIN 1 was correctly recorded
  and still being drawn by two figure scripts for four days. Any gate that retires or supersedes a
  quantity must include a repository-wide scan for live code still querying the old path, and the
  scan result goes in the change report.

## 7. Standing rules

Additive only · **never re-run the Task H builder** · no `reset_file` · never delete or modify a
registered row · plot support and pixel support never merged in one figure · paths resolved from the
database and the machine, never assumed · source of truth is the database and the source rasters —
never a CSV, a data frame, a caption, or a previously registered figure · branch and PR with human
merge · commits authored by Hugh, no AI attribution trailers · rasters and large spatial data never
committed · a null or inconclusive result is a legitimate reportable outcome · **any number produced
at the design seat is a prediction to check, never a target — where CC's independently computed
value disagrees, CC's stands and the disagreement is the finding.**

## 8. If only one thing gets done

**LANE 1 Gate P4.** The pack workbook, regenerated from live queries, with correct item arithmetic
and no claim resting on an unpinned number. It is what Adrian actually receives, and every other
item on this board exists to fill it.
