# PACK-1 P4 — the build, and the RT-1…RT-4 read-through

**Date:** 3 August 2026 · **Prior:** `add2088` (the P4 build) · **Supersedes** the DRAFT
`PACK1_P4_assembly.md`, which was written against the reverted item list and cites design-seat
rulings that were never issued (I-43).

**Probes.** P4 build: `101 / 297 / 191 / 4 / 59` → `101 / 297 / 191 / 5 / 60`
(`dim_headline_number` / `figure_asset` / `raster_asset` / `table_asset` / `report_asset`).
RT read-through: `101 / 297 / 191 / 5 / 60` → **unchanged**. The only database writes in the whole
of P4 are Ruling N's two rows — `report_asset` for the workbook, `table_asset` for the item list —
and the RT round re-wrote those same two rows via `INSERT OR REPLACE` without moving any count.

---

## 1 · Four statements in the spec are superseded by the build

Flagged rather than silently worked around, per *report the disagreement rather than choosing*. All
four were accepted at the design seat.

| spec | says | superseded by |
|---|---|---|
| §157 | `dim_headline_number` = **88 rows with 57 independently re-derived** | live **101 rows, 98 pinned, 81 re-derived (82.7%)**. The spec's figures predate R2's ten pins and the seven derivations wired at I-40 |
| §269 | the R4 fallback, *"fell to 57 of 88 … re-run"* | **void** — R4 is cut (below), and the coverage figure it keys on no longer exists |
| §165 | copy the files into **`Output/pack/files/`** | the assembled layout is **`01_maps` / `02_figures` / `03_tables`** plus the two root pages, which is what the frozen manifest's own column contract already described |
| §134, §165 | **"17 items, 15 files"** / *"copy the 15 files"* | **17 items, 17 files.** 15 → 16 at P1 (`T1_render` was ruled a shipped file and never added to the count — I-40's seventh instance), 16 → 17 when the T3 page became a written file under L8 |

**§6 scan.** The last bullet of spec §6 requires a repository-wide scan for live code still querying
any quantity this gate retires or supersedes. **P4 and the RT round retire no quantity** — no
`pinned_value`, `spread_*` or qualifier was changed, and no `number_id` was superseded — so the scan
is not triggered. Stated rather than left to inference.

## 2 · Three cuts, recorded

- **R3 — CUT** (it was conditional on a Saturday that does not exist).
- **R4 — CUT.** Its §269 fallback is void with it.
- **The BIO arm — CUT, formally.** Recorded here so it is not revived from an older doc.

## 3 · The build (P4-1 … P4-7)

**P4-1.** `Gayini_what_we_dont_know.md` written **verbatim** to the pack root; no prose edited. The
three folded resolutions are in it: the channel row cites **T3-I5**, the woody row carries the
verified **8.00% / 91.55%** census statement in place of the withdrawn 13.33%, and O4's
metric-sensitivity paragraph is marked as a design-seat computation with no committed producer.

**P4-2.** T3's register caption replaced, and the stale *"EXISTS (limitations register)"* corrected
to name the written page. Both changes carry a visible note.

**P4-3 — the diff arithmetic differs from the spec's prediction, and this is the precise report.**
Expected *"16 byte-identical, 1 new"*; got **17 byte-identical, 0 new**. Same end state: the T3 page
was written directly to its final location in the pack root **before** assembly, so it was already
present at diff time rather than arriving as a new file. 0 differing, 0 lost.

Two assembler fixes were required and are in `PACK1_assemble.py`:
a source that already lives in the pack root is **not** routed into a type folder (it is a page, not
a figure), and a file already at its destination is **not** copied onto itself (`WinError 32`).

**P4-4.** `00_START_HERE.md` and the workbook **Contents** sheet are both generated from
`PACK1_item_list.csv`. Verified **18 rows each, item and filename identical** — one source, so they
cannot disagree.

**P4-5 / P4-6 / Ruling N.** Five sheets, content regenerated. Every number on **How_we_know** is a
live query at build time — verified by reading the generator, not by assertion. Coverage and drift
travel in one sentence. Workbook and item list registered.

**P4-7.** See §5 — the rule changed at RT-1.

## 4 · I-44 — the self-referential count, found and fixed at P4

`How_we_know` reports registry counts, and the workbook's own registration changes them. The first
pass wrote **`registered tables` = 4** while the live value became **5** as the same script
committed. A stale number on the one sheet that must not carry one, produced by a generator that
was querying live **exactly as ruled**.

> **Live query is necessary but not sufficient: the query must run after every write the same build
> performs.**

Fixed by running to a fixed point and **demonstrating** it — sheet and live agree, and a further
pass changes nothing.

## 5 · RT-1 — the number check verified the citation list, not the sentence

**This is the substantive finding of the read-through, and it is logged as I-45.**

P4-7 resolved every `number_id` **listed in each cell's provenance column** and passed **38 of 38**.
Three cells quoted a number whose id was not listed, and the check was structurally blind to all
three — an unlisted number is not in the list it was checking:

| cell | the number written | id now added |
|---|---|---|
| By_question **Q3** | *"about 17 percentage points less cover than its dryness predicts"* | `t10_bala29ca_xsec_residual` (−16.8) |
| By_question **Q2** | all four flood ranks, one listed | `_bala28ca`, `_bala27ca`, `_bala29ca` |
| By_question **Q6** | *"five survive dropping the two wettest years"* | `t13_recovering_survive_drop2wettest` (5) |

**The rule is now: extract every number from the cell text as written and resolve each one.**
**38 → 153 numbers checked, 0 unresolved**, over the seven claims, the seven answers, the five
cautions, How_we_know and both parts of the T3 page.

Two further defects surfaced only because the rule changed:

1. **The first fixture did not fire.** Reverting Q3's provenance to its pre-RT-1 state still
   *passed*, because a project-wide declared-source table silently absorbed the uncited 17. A
   `DECLARED_UNCITED` state now rejects any **result** that a provenance-bearing cell quotes without
   citing, and the fixture then fires correctly:
   `*** DECLARED_UNCITED  By_question Q3 | 17 -> two-floor divergence, spec section 6 …`
   with the build stopping and the workbook **not** registered.
2. **PARAMS had to be split from RESULTS** to make that bite. CLAUDE.md's three-classes table
   already says a parameter *is* the spec while a motivating result is pollution; the check now
   encodes that distinction instead of treating every numeral alike. Without it the uncited test
   flagged 25 legitimate parameters and would have been switched off within a day.

**What the check does and does not guarantee**, stated so it is not over-read: it guarantees every
number written has at least one **named source**. Where two declared sources share a value, the
attribution is ambiguous; the CSV carries `n_matching_sources` per row and **87 of 153 are uniquely
attributed, 53 are covered but not uniquely attributed**. Names, identifiers and dates are reported
as `NAME_NOT_QUANTITY` (13) rather than dropped — a number that vanishes from the scan is exactly
what RT-1 caught.

**Verified independently this session from `T13_gateC_classification.csv`**, because claim 6 and
claim 7 quote them and the registry does not pin them: **3** parts Recovering at every cut
0.50–1.50, **2 of those 3 in Bala 29ca**, **5** surviving drop-two-wettest, **16** Declining of which
**12** are in the Bala group. And *"the second largest shortfall"* in Q3: Bala 29ca at **−16.8**
behind Bala 15 at **−17.62**. All confirmed.

## 6 · RT-2 — the third registry

`How_we_know` reported `figure_asset` and `table_asset` and not `report_asset`, which moved
**59 → 60** in the same transaction that moved `table_asset` **4 → 5** — the write I-44 was about.
A **`registered reports`** row is added, queried live like the others. Sheet and live now agree on
**297 / 5 / 60**. No database write was required.

## 7 · RT-3 — BLOCKED, and not drafted

**Ruling P's paragraph text is not in the read-through message.** RT-3 says *"Text as sent"*; no text
was sent. The message runs RT-2 → RT-3 → RT-4 with the paragraph absent, and a search of every
design-seat message in this session finds no other occurrence of Ruling P.

Per **I-43** — *a ruling is only a ruling if it can be quoted from a design-seat message* — the
paragraph is **not drafted here**, and `Gayini_what_we_dont_know.md` is unchanged. Writing an I-44
paragraph of my own composition into a page ruled *otherwise not to be edited*, under the authority
of a ruling whose text does not exist, is the precise failure I-43 was written for, and it reached a
client deliverable the last time it happened.

Everything else about RT-3 is ready: the insertion point after *"A check that errors is not a check
that catches"* is unambiguous, and the *"eight instances"* count is untouched.

## 8 · RT-4 — the zip is built and verified; the hash is NOT yet recorded

`scripts/13_pack/PACK1_zip.py` writes the zip **outside** `Output/pack/` so it cannot contain
itself, hashes it first-50-MB, and re-hashes **every member back out of the zip** so that *"it
zipped"* is not mistaken for *"it is intact"*.

```
Gayini_Adrian_pack_20260803.zip: 25 files, 4.47 MB
every member re-hashed OUT of the zip: 25/25 identical
sha256 (first 50 MB): 0f97694fee3054072daaf29bedec0525eb9a0e363f678ca21f893852fb0fd621
```

**Fixture, per Ruling J / I-42** — a member's pre-zip hash falsified, so the check must reject a
wrong **value**, not merely crash:

```
ABORT - 25 in, 25 out, 1 mismatched. Zip DELETED, nothing recorded.
```

**The hash is deliberately not written to `PACK1_assembly_manifest.csv`.** Recording it asserts
*"this is the delivered state"*, and the pack has an outstanding authorised amendment (RT-3). The
recording step sits behind `--record` and is one command once Ruling P's paragraph lands; the hash
above will change when it does, and is reported as provisional for that reason.

**Ordering note, stated rather than hidden:** the manifest lives inside the pack, so the copy sealed
in the zip necessarily predates the row recording that zip's hash. The repo copy is the authority.

## 9 · Ruling R — spec §6 echoed verbatim

> ## 6. Standing decisions CC must not reopen
>
> - **The floor metric is `veg_p05_spatial`, pinned at T2.** `census_by_zone_stratum.veg_p05_mean` is
>   the census **temporal** p05 and is a different quantity. They differ by up to 17 pp at part grain,
>   in opposite directions by community. `T2_zone_annual_veg_extraction.md` §94: *these must never
>   appear in the same figure or be compared numerically.* **Any gate that reaches for
>   `veg_p05_mean` for a reference-state purpose is a STOP, not a judgement call.**
> - **R6 is a cross-metric sensitivity, not a redefinition.** Gate E stays blocked. Nothing in the
>   deck, the register or claim 4 changes.
> - **PIN 2 is not revisited before 10 August.**
> - **PIN 3** (the five-period trajectory) is permanently unpinned. Its reappearance anywhere is a
>   regression.
> - **T7 is dropped.** M3 ships as-is.
> - **DECK-1 is cut** to a cover slide pointing at the pack folder.
> - **T12 DEA cultivation calls never appear in a client deliverable**, at any confidence level.
> - **No p-values on the annual series.** Thirty-five consecutive years are not independent.
> - **Retiring a number in the registry does not retire it in the code.** PIN 1 was correctly recorded
>   and still being drawn by two figure scripts for four days. Any gate that retires or supersedes a
>   quantity must include a repository-wide scan for live code still querying the old path, and the
>   scan result goes in the change report.

## 10 · Acceptance

| | |
|---|---|
| RT-1 three cells cited | **done** — Q3, Q2, Q6 |
| RT-1 rule changed to resolve numbers as written | **done — 38 → 153, 0 unresolved** |
| the new rule proved able to fail | **done** — fixture rejects a wrong value; build stops, workbook not registered |
| RT-2 third registry on the sheet | **done** — `registered reports` = 60, live |
| RT-3 Ruling P applied | **BLOCKED — text not sent. Not drafted (I-43)** |
| RT-4 zip built, verified, hashed | **done** — hash above, **not recorded**, pending RT-3 |
| probes either side | **unchanged, 101 / 297 / 191 / 5 / 60** |

**STOP.** Two things outstanding, both the design seat's: Ruling P's paragraph, and then
`PACK1_zip.py --record`.
