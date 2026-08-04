# LID-1 Gate L1 — verify the summary

**Date:** 4 August 2026 · **Read-only.** `mode=ro` + `PRAGMA query_only=1` throughout.
**Probe open = close:** `dim_headline_number` 101 · `figure_asset` 297 · `raster_asset` 191 ·
`table_asset` 5 · `report_asset` 60 · `spatial_layer_asset` 9. DB mtime unchanged
(`2026-08-04 11:53:16`). **No write of any kind.**

---

## 0 · BLOCKING — the document Gate L1 executes does not exist

> *"`Gayini_LiDAR_TaskU_summary.md` §11 already specifies its cross-check. **Execute it as
> written.**"*

**There is no file of that name anywhere in the repository.** The only occurrence of the string
`Gayini_LiDAR_TaskU_summary` in the entire repo is inside the LID-1 spec itself. Nor does any Task U
document carry a §11 cross-check: the nearest §11 is `TaskU_gateU1_report.md` §11, *"Run B — the
50 cm DEM · complete"*, and a repo-wide search for *cross-check*, *discrepancy table* or the spec's
column headers (`claim · document value · artefact value · verdict`) returns nothing matching.

The spec's other section references do not resolve either. It cites *"summary §5 F2"*, *"§8"* and
*"§9"*, implying a document of eleven-plus numbered sections. The two candidates have six sections
(`TaskU_findings_note.md`) and five (`Gayini_LiDAR_implications_for_reference_state.md`).

**This is the fourth time a gate has rested on an artefact asserted to exist** — after Ruling L4's
"re-run, do not rewrite" against a producer that had never been saved (I-40, sixth instance, design
seat), and I-43's two unquotable rulings. **I have not reconstructed the cross-check**, because
inventing the instruction and then executing it would make the verification unfalsifiable.

**What I did instead**, all four additions being fully executable: L1-1 to L1-4 below, plus a Rule 2
compliance scan, which was not asked for and which found the largest item in this report.

**What is owed:** either the summary document, or §11's list of claims to check. Everything below
stands independently of it.

---

## 1 · Rule 2 is being violated right now, in two committed documents

Not a Gate L1 item. Found while locating the F2 numbers, and it outranks everything else here.

Rule 2 states the R6 / F2 result *"may not appear as a finding, a conclusion, or a qualification on
any reference-state claim."* **It currently appears as the headline conclusion of both
reference-state stream documents:**

| document | what it says | committed |
|---|---|---|
| `Gayini_LiDAR_implications_for_reference_state.md` §3 | title: ***"The reference-state anomaly has dissolved — a result, not a loss"***; body: ***"R6 closes it.** 29ca's residual is **positive in all three communities: +1.57, +9.61, +1.15**"*; and *"The result that appeared to threaten the headline turns out to be an ordinary instance of it"* | 2 Aug, `2677ccf` |
| `TaskU_findings_note.md` §1 | title: ***"The reference-state anomaly no longer needs explaining"***; same three values; bottom line: *"What it did was **remove the one result that appeared to contradict the project's headline**"* | 2 Aug, `c4b4fb7` |

**The correction already exists and was never propagated.** `Gayini_R6_metric_review_20260802.md`
— committed **3 August**, one day *after* both documents — states it explicitly:

> *"R6 compares a residual computed on the census metric against a 42 pp deficit computed on the
> spatial metric. **That is the prohibited comparison, and it is the sole basis for 'the anomaly has
> dissolved.'**"*

and gives the re-run on the pinned metric: Bala 29ca **−29.04 (−2.60 SD)** Aeolian and **−18.67
(−1.93 SD)** Riverine, against R6's +1.57 and +9.61 — with the Aeolian community fit **reversing
sign**, +0.259 (r 0.19) on census p05 against **−0.667 (r −0.26)** on spatial p05.

**Neither stream document was amended.** Grep for `veg_p05_spatial`, *metric review* or *prohibited
comparison* in either returns **zero**.

> **This is I-40's shape, ninth instance: the review was written, the propagation was not.** The
> record is correct and the documents a reader reaches first are not.

**Reported, not fixed.** Both documents are the design seat's stream, and amending a conclusion in
them is not a CC act. **Recommendation: amend both at the top, visibly, before either is read
again** — the implications note's §3 is currently the second thing in the document.

---

## 2 · L1-1 — 13.33% and 8.00% are different quantities. Confirmed, both re-derived

| | numerator | denominator | value |
|---|---|---|---|
| **woody community share** | census cells in Floodplain Woodland / Forest — **86,375 px = 5,385.6 ha** | mapped census area **67,349.332 ha** (equivalently 1,080,157 px) | **8.00%** |
| **measured woody cover** | LiDAR FPC > 0 at either epoch — **11,449 ha** (`TaskU_gateU3_report.md` §3) | Task U both-valid **85,882.6 ha** (`taskU_denominator_both_valid_ha`, registered) | **13.33%** |

Both reproduce to the stated precision. **They are not comparable and neither supersedes the other**
— different numerators *and* different denominators. The denominators differ by **18,533.3 ha, 27.5%**:
the LiDAR reaches further than the census does.

Crossing them, which is the invalid comparison, gives figures that appear in no document and should
not: LiDAR woody over the mapped census area is **17.00%**; census woody over both-valid is **6.27%**.

### The mis-diagnosis, logged — and it was two people, not one

The spec asks me to log the design seat's mis-diagnosis. Accurate as far as it goes, and incomplete:
**I ran that check and reached the same wrong conclusion.** At P3 §7 I wrote *"The 13.33% woody-cover
row is **WITHDRAWN. It does not reproduce**"* and *"**Nothing in the database yields 13.33%**"*, and
logged it as I-40's eighth instance with the source named as the design seat.

The census statement I put in its place is correct and stays. The withdrawal reasoning was not:

- **The check could not see what it was looking for.** `census_by_zone_stratum` is a Landsat census
  product. A LiDAR measurement is not in it and cannot be, so the query could return only *absent* —
  which is not the same as *wrong*. **I-42's shape exactly: a check that cannot fail informatively is
  not a check.**
- ***"Nothing in the database yields 13.33%"* was literally true and materially misleading.** Its
  denominator, 85,882.6 ha, **is** in the database, registered as
  `taskU_denominator_both_valid_ha`, and I did not look for it.
- **Naming the source as the design seat was the part I got right and the part that made it worse** —
  attributing it upward closed the question instead of opening it.

**The 13.33% figure is reinstated as a Task U result with its own denominator.** I-40's eighth
instance stands as logged for the census statement, and this correction is recorded against it.

---

## 3 · L1-2 — ruled, not inserted. I-40 again

Summary §9 (as quoted in the spec) records *"2 denominators registered; 10 further rows ruled and
pending insertion at closeout C1."*

**Live state: 101 rows, exactly 2 of them Task U.**

| number_id | pinned_value | support |
|---|---|---|
| `taskU_denominator_both_valid_ha` | **85,882.6** | pixel |
| `taskU_denominator_census_x_lidar_ha` | **67,268.002** | pixel |

**The 10 further rows were ruled and were not inserted.** No row in `dim_headline_number` carries a
Task U source, decision note or caveat beyond those two. **Not inserted, per the spec.** I-40's
shape, tenth instance — and it means every Task U number other than the two denominators is
currently **unpinned, uncovered by `test_T8_headline_reproduction.py`, and quotable only from a
change report** — which the project's own rule forbids as a home for a value.

**Consequence for Gate L2 that the design seat should know before ruling:** the 13.33% of §2 above
is one of those unpinned numbers. It can be classified `METHODS_DOC` as a bounding statement, but it
cannot be cited by `number_id` because it has none.

---

## 4 · L1-3 — U-I14 outstanding in both stream documents. Confirmed, with a caveat that changes its weight

**Confirmed present and open in both**, and in the issues log and the gate report:

| document | where |
|---|---|
| `Gayini_LiDAR_implications_for_reference_state.md` | §4 · *"Bala 26ca · **open, named, not investigated**"* |
| `TaskU_findings_note.md` | §5 · *"open observation, not investigated … neither built on"* |
| `Gayini_issues_log.md` | I-14 row · *"OPEN, named, not investigated"* |
| `TaskU_gateU4a_and_U3_7_report.md` | §U-I14 · *"Not investigated before 10 August"* |

The framing is right: two instruments on one 40 ha fragment is not two independent lines.

**But one of the two lines is computed on the prohibited metric, and it does not survive the
re-run.** U-I14's R6 leg is *"a residual of **−17.41 pp**"*. The R6 metric review's table gives
Bala 26ca Riverine as **−17.41 on census p05 and −1.34 on `veg_p05_spatial`** — the same collapse
that dissolves the Bala 29ca claim, in the same direction.

> **U-I14 is weaker than recorded.** Not two lines agreeing on a small sample, but **one structural
> observation, plus an R6 residual that mostly disappears on the pinned metric.** Recorded here so it
> is picked up on purpose — which is what U-I14 exists for.

---

## 5 · L1-4 — 16 of 20 rasters carry an unconfirmed legend, not 14

The spec says *"Unconfirmed on FPC and height rows."* That is 12 height + 2 FPC = 14. **The measured
count is 16: the two 50 cm DEMs are unconfirmed too.**

| `legend_status` | n | which |
|---|---|---|
| **`unconfirmed`** | **16** | 2 × `bb0_dem` (2009, 2021) · 12 × height `bb9/bba/bbb/bbc/bbd/bbe` p05–p99 (2009, 2021) · 2 × `bbh_fpc` (2009, 2021) |
| `confirmed` | 4 | 2 × `r2_excluded` · 2 × `seam_mask` |

All 20 are `run_id = taskU_gateU1`, `qa_status = REVIEW`, `crs_epsg = 8058`, and **all 20 carry a
checksum.**

**This binds Gate L2 hard.** The spec's `HOLD` rule is *"anything with an unconfirmed legend"*, and
the `DATA_HANDOVER` rule requires *"plain-English semantics"*. On the rule as written, **16 of the 20
rasters — including both FPC layers and every height percentile — are `HOLD`, and only the four mask
layers can reach `DATA_HANDOVER`.** That is a materially smaller handover than L4-1 anticipates, and
it is a ruling I should not make alone. Flagged now rather than at L2.

---

## 6 · Also established, for L2/L4 (no classification made yet)

- **Figures: 2**, both registered — `figure_u2_epoch_context_35yr`, `figure_u3_sensor_step_change`.
- **Vector: none.** `spatial_layer_asset` holds 9 rows, none from Task U, and no Task U GeoPackage is
  present. Correct either way — it is an import registry, so a Task U build output registered there
  would be a category error (L4-3 answered: **no GeoPackage exists**).
- **Documents: 8** — 5 gate reports, the findings note, the implications note, the lens spec v1.2.

---

## STOP — end of Gate L1

**Three things are the design seat's before L2 can run:**

1. **The summary document, or §11's claim list.** Without it the cross-check is not executable and
   will not be reconstructed.
2. **Rule 2 remediation in the two stream documents** — currently live, and the correction has
   existed since 3 August.
3. **The L1-4 consequence:** on the rule as written, 16 of 20 rasters are `HOLD` and the handover is
   four mask layers. Confirm or amend the rule before I classify.

Nothing in Gate L1 changed a number, a row, or a file outside this report.
