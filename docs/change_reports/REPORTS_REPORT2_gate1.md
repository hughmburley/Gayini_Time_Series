# REPORTS — REPORT-2 Gate 1 · the parts page, corrected for water

**Session:** report batch, third concurrent seat · **Date:** 7 August 2026
**Builder:** v1.9 → **v2.0 pending** · **DB read-only.** No write attempted. Nothing under
`Output/pack/`, `Output/unzoned/` or `scripts/12_zone_stratum/` touched.

```
lint_builder.py        0 error · 0 warn                       exit 0
verify_batch.py        25 match · 7 changed · 0 missing        exit 0
check_scope_claims.py  clean (9 checks)                        exit 0
check_page_fill.py     no page at spill risk                   exit 0
tests/                 10 scope cases · 0 fail                 exit 0
```

**Not re-fingerprinted.** Gate 1 is a STOP; the manifest still records the pre-REPORT-2 build, so
the 7 CHANGED rows are the diff awaiting your read. Re-fingerprint belongs at Gate 2.

---

## 1. Everything checkable in the spec was checked, and it all holds

| claim | result |
|---|---|
| community sizes 17 / 61 / 37, 115 parts | **exact** |
| §1's table, all 17 rows, both ranks and wetness | **17 of 17 exact** |
| monotonic in wetness, no exceptions | **holds** — fallers 33.3–49.7%, risers 5.9–25.1%, no overlap |
| §5 · Bala 29ca Aeolian 1/17 and Riverine 2/37 on both columns | **holds** |
| §5 · Bala 29ca Inland alone moves, 10 → 48 | **holds** |
| §3.5 cell counts — Bala 15 · 23, Bala 28ca · 10, Mara 3 · 1 | **exact** |

The join is `(zone_fid, community)` — both objects carry the full community string, so no
short-name mapping is interposed and no part can be silently dropped. 115 of 115 matched.

**One reconciliation the spec did not ask for and which mattered.** The existing cover column
ranks from `fact_zone_community_part_classification.level`; the new one ranks from PARTREG. If
those disagreed, two columns on one row would be reading different objects. Checked: 115 of 115
identical ranks, `level` differing from `whole_record__floor_mean` by at most 0.0005. It is now
asserted at build time rather than confirmed once.

## 2. Applied

**§3.1** — the parts table gains **"For the water it gets"**. Both comparison columns stay; the
grid re-apportions to `[3400,1050,2150,2950,2950,2900]`, still summing exactly to the 15400 the
table declares. Ranks only in the new column, never percentage points.

**§3.2** — `waterPhrase()` is a lookup on rank position, transcribed from the ruling. No per-part
prose is composed anywhere.

**§3.3** — the drier-parts sentence, verbatim, following *"Each kind of country has its own
normal…"*.

**§3.4** — the guard sentence, verbatim, on the expectation page. I first restyled it to match the
surrounding *"It does / It does not"* register and reverted: fitting the register would have been
me writing client-facing text. It sits as its own paragraph instead.

**§2** — `Output/tables/REPORT2_part_ranks.csv`, 115 rows, ranks within community, rank 1 = worst
on both columns. **Registration as a table asset is session 1's and is not attempted here.**

## 3. The defect the first build produced, and what it says about the fix

The builder ignores `--paddocks` and rebuilds every unit record present. So the first Gate 1 run
rewrote all 32 documents against records that predated the new column — and three shipped
documents came out **wrong in the most favourable direction available**:

> Bala 29ca, Aeolian third — **rank 1 of 17, the worst of its community** — rendered as
> *"among the highest of 17 for its water"*.

Every comparison against `undefined` is false, so control fell past every branch of the if-chain
and reached the final `return`, which is the top label. Bala 28ca and Dinan 8 rendered the same way
on all their parts.

**This is the family you named on the `trend +{sl:.3f}` formatter: a formatter that only works on
the data it happened to meet.** The chain was exhaustive for a finite rank and silently
total-but-wrong for anything else. Fixed at the formatter, not by re-running the data:
`waterPhrase()` now throws on a rank that is missing, non-finite or outside `1..n`, and the build
halts rather than writing a document it cannot label.

Proven against the records that produced the wrong label:

```
Error: waterPhrase: Inland Floodplain has no usable water rank (rank_water=undefined, n_of=61).
       The unit record predates REPORT-2 — re-run report_data.py for this paddock.
```

That is a wrong-value fixture, not a crash fixture — the pre-fix behaviour was a plausible
sentence, not an exception.

## 4. The check (§5), and both directions it fires in

`check_scope_claims.py` gains check I: every label in every built parts table re-derived from
`REPORT2_part_ranks.csv`. The vocabulary is **transcribed a second time** rather than imported —
a check that imports the thing it checks tests only that the code ran.

Two new fixture cases, both rejected:

```
report2_direction_flip  exit 1  ERROR [REPORT-2] Bala 26ca
                        inland should read "among the highest of 61 for its water" ...
report2_missing_rank    exit 1  ERROR [REPORT-2] Bala 29ca
                        aeolian should read "lowest of 17 for its water" (rank 1 of 17) ...
```

The flip case is the one §2 calls the hardest error to catch downstream, and it is: every label
still reads as valid English.

## 5. GATE 1 — the two paddocks, read from the built documents

| | cover column (unchanged) | **for the water it gets** |
|---|---|---|
| **Dinan 10** · Inland, 5.9% wet | second-lowest of 61 | **about what its water predicts — 30th of 61** |
| **Bala 26ca** · Inland, 45.9% wet | 21st of 61 — ordinary | **among the lowest of 61 for its water** |

They fail in opposite directions and the template reads correctly on both. Dinan 10's other two
thirds barely move (Aeolian 2→2, Riverine 6→8), which is right — they are dry and the cover column
was not misreading them.

**One wording note for ratification.** §6 describes Bala 26ca's Inland third as *"third-worst"*.
It is rank 3 of 61, which the §3.2 lookup labels *"among the lowest of 61 for its water"*. I
followed the pre-registered vocabulary rather than §6's prose, per §3.2's own instruction that the
label is a lookup. If you want the exact ordinal at rank 3, that is a change to the table.

**13 labels across the 5 multi-part paddocks were checked against the CSV by an independent path;
0 mismatches.**

## 6. Three findings to rule on before Gate 2

**(a) §0 names files that do not exist in this stream.** `build_v2.js`, `make_figs2.py` and
`Gayini_report_stream_handoff_20260804.md` are absent; this builder is `report_build.js`,
`report_figs.py`, `Gayini_report_batch_CC_handoff.md` (v1.1). I mapped them. Worth knowing whether
the spec was written against a second report stream, because if one exists these changes have not
landed in it.

**(b) §3.5's diagnosis is inverted for Bala 28ca — and the real gap is the opposite one.**
Bala 28ca has **two supported parts and does have a parts page**; its 10-cell Aeolian sliver is
disclosed **nowhere**, because R-8's trace clause fires only on the single-community branch. Bala
15 and Mara 3 do lack a parts page, and R-8 (4 Aug, after this spec's companion) already discloses
their slivers on page 1 — *"with a trace of Riverine too small to report on separately"*. So:

| paddock | parts page | sliver disclosed today | what §3.5 needs |
|---|---|---|---|
| Bala 15 | no | yes, page 1, no count or area | add the count and the true area |
| Mara 3 | no | yes, page 1, no count or area | add the count and the true area |
| **Bala 28ca** | **yes** | **no — not at all** | the line, on the parts page it already has |

**(c) §3.5's fixed phrase "under a hectare" is false for Bala 15.** 23 cells × 0.062351428 =
**1.43 ha**. Bala 28ca is 0.62 ha and Mara 3 is 0.06 ha. §3.5 also says *"give the true area"*, so
the two instructions conflict; I will derive the area and let the phrasing follow it rather than
type the clause. None of the three is in Gate 1, so nothing has been built on this yet.

## 7. Also worth recording

- **Site reports are untouched** — 25 of 25 match. §3.4's guard did not reach them, so if Gate 3
  wants it there, that is a separate placement decision: the site reports do not draw the
  between-paddock expectation line, and a sentence about a line the page does not show would be
  its own kind of wrong.
- **The two comparison columns use different cut points** — the cover column breaks at 25/75, the
  new one at 10/25/75/90 per §3.2. Both are as specified; two adjacent columns with different
  vocabularies is a design observation, not a defect, and I have not touched the first.
- `dim_headline_number` now reads **139 rows**, against the 59 CLAUDE.md records. All four
  constants still assert at 1e-4 and all four canaries pass.
