# REPORTS — Gate 2 CLOSED · builder v1.5

**Session:** report batch, third concurrent seat · **Date:** 4 August 2026
**Worktree:** `D:\Github_repos\Gayini_reports` on `feature/reports`
**Builder:** v1.4 → **v1.5** · **DB read-only throughout.** No write attempted.

```
lint_builder.py           0 error · 0 warn                exit 0
verify_batch.py           32 match · 0 changed · 0 missing exit 0
check_scope_claims.py     clean (§8.4 re-run)             exit 0
check_page_fill.py        0 above 92% · 12 below 70%      exit 0
tests/  caption branches · page-fill fires · canaries can fail · scope claims fire
                          10 assertions · 4 files · 0 fail
```

R-6 and §8.1 were batched into **one** verification and **one** re-fingerprint, as directed.

---

## §8.1 — resolved, and the defect was not where §8.1 said it was

### The registered slopes are correct

All three reproduce from `Output/tables/T10_annual_gap_series.csv` to the rounding of their
pinned values:

| series | from the artefact | registered | diff | r (artefact / registered) |
|---|---|---|---|---|
| `A_all4` | 0.2727 | 0.273 | −0.0003 | 0.7700 / 0.770 |
| `B_excl29ca` | 0.0571 | 0.057 | +0.0001 | 0.2224 / 0.222 |
| **`C_29ca`** | **0.9193** | **0.919** | **+0.0003** | 0.8457 / 0.846 |

**0.919 needed no explaining.** It is the slope of the registered T10 series, exactly. The
design-seat re-derivations (0.858 / 0.860 / 0.864) were fitted to a *differently constructed*
gap series — a different grazed-baseline aggregation — and, as you said, that is an
aggregation-order difference rather than an arithmetic error. It did not steer the check: the
artefact was fitted first and compared afterwards.

### The defect was that the figure drew a line from one series over points from another

§8.1 records this as benign — *"the figure currently draws the registered slope and the text
quotes it; only the annual points are derived."* It is not benign. The builder derived its own
gap series, and against the registered series it differs by a **mean of 4.70 pp, up to 8.69 pp**.

`fig_gap` anchors the line's intercept to the mean of whatever points it is given, so the drawn
line was **neither series** — registered slope, derived intercept. And it annotates two
client-facing numbers off that line:

| Bala 29ca, page 4 | 1988 | 2022 |
|---|---|---|
| as drawn | **41** points below | **10** points below |
| registered series `C_29ca` | **45** points below | **14** points below |
| understated by | 4.7 pp | 4.7 pp |

The closure *rate* was right throughout — 0.919 pp a year, the headline. The *levels* were
understated by about five points at both ends of a 35-year narrative about a closing gap.

**Fix.** Where a registered slope is asserted, the points now come from the artefact that slope
was fitted to. Where none is asserted, the series is derived here and the figure fits its own
line to its own points — internally consistent and claiming no registered value. That is one
paddock in the 32-set:

```
Bala 29ca   T10_annual_gap_series.csv :: C_29ca
the other 6 derived: paddock floor minus grazed baseline, this module
```

`fig_gap` needed no change: anchoring the intercept to the points' mean *becomes* the correct
OLS intercept once the points are the ones the slope was fitted to. The drawn points now carry
their own slope of **0.9193** against the registered 0.919, and the endpoints read 45 → 14.
`gap_source` is recorded per unit so the provenance is in the record, not in this document.

### A gate stop for registration, not for this build

**The annual gap series has no home in the database.** No table, no view; `sqlite_master` has
nothing matching, and no asset row references the CSV by any path or id. `T10_annual_gap_series.csv`
is its only home and it is **unregistered**, yet a client figure now depends on it.

I took the dependency deliberately: the alternative was to keep drawing a registered slope over
points it was not fitted to. **Registration is session 1's** — additive, new `run_id`. The loader
returns `None` and falls back to the derived series with `gap_source` saying so, rather than
silently drawing nothing, if the artefact ever goes missing.

---

## R-6 — cell size, applied to five phrasings not two

Rendered to **two decimal places** from `PIXEL_SIDE_M`, not to the nearest metre.

You said two places say 25 m. **There are five distinct phrasings, across all seven paddock
reports — 19 text sites in total.** Site reports carry no grid reference at all, correctly: they
use the site-footprint rule.

| phrasing | documents |
|---|---|
| `Paddock flood frequency is measured across every 24.97 m cell` (scope footer) | 7 |
| `the 24.97-metre grid covering the whole paddock` | 3 |
| `measured across every 24.97-metre cell in the paddock` | 3 |
| `every 24.97 m cell, 35 years` (table, two rows) | 3 × 2 |

The comment at the constant was updated with the code — it had said *"rounded for the reader"*,
which after R-6 would have been a comment disagreeing with its own code, which is D1-I3.

**V8's internal disagreement is reported, not reconciled.** §3 says 24.97 m, §11 says 25 m, and
V8 carries both. With this change the reports agree with V8 §3 — where a grid should be defined.
For the RS stream.

---

## §8.4 — re-run, not inherited, and now repeatable

Your point taken: the claim was made in a sandbox against a snapshot by the seat that wrote it,
and should not survive a seat change on its own authority. It is now `check_scope_claims.py`,
run against the **built documents**.

```
band areas reconcile  Bala 15      528.428 ha vs   528.428 ha   diff 0.0000
                      Bala 26ca   2059.779 ha vs  2059.779 ha   diff 0.0000
                      Bala 27ca   1490.698 ha vs  1490.698 ha   diff 0.0000
                      Bala 28ca   1370.859 ha vs  1370.859 ha   diff 0.0000
                      Bala 29ca   2286.801 ha vs  2286.801 ha   diff 0.0000
                      Dinan 10     841.058 ha vs   841.058 ha   diff 0.0000
                      Dinan 8     2671.322 ha vs  2671.322 ha   diff 0.0000
two-flood-rules sentence present in all 32 documents
0 error · 0 warn
```

**§8.4's claims hold.** Band areas reconcile to 0.0000 ha in all seven — its own stated result —
`"the property"` is used only as a countable set, and no sentence pairs a paddock-support flood
figure with a site-support one.

**The checker is proven to fire**, because a checker that has only ever agreed with the thing it
checks has not been shown to disagree with anything:

```
none            exit 0  OK
property_area   exit 1  OK   "the property" given an area          -> rejected
band_area       exit 1  OK   bands +40 ha, no longer summing       -> rejected
two_rules       exit 1  OK   the required sentence removed         -> rejected
```

**One false positive, fixed at the boundary rather than by loosening the rule.** The first
version flattened the docx and reported Bala 29ca's parts table: the *Area* cell (`739 ha`) and
the *comparison* cell (`lowest of 17 on the property`) are different columns, and `17 on the
property` is a countable set — correct usage. Matching across a boundary that is not a boundary
in the source is **I-47's shape at one remove**, so the extractor now preserves cell and
paragraph boundaries.

---

## `test_T8_headline_reproduction.py` — no drift, and the test cannot say so

Run before the batch, per §3 item 1. It **exits 1**, and that exit means less than it appears to.

```
T8 reproduction: 17 DRIFTED of 81 checked
```

**All 17 read `recomputed=NOT RECOMPUTED`. Not one is a wrong value.** 64 of 81 reproduce; the
other 17 have no recompute path implemented — three-arm deficits, the two Task U denominators,
`t13_recovering_survive_drop2wettest`, `cropping_history_null_count`,
`three_arm_standard_at_or_above_count`.

**All 11 numbers this batch depends on are in the reproduced 64** — the four constants, the four
canaries, and the three `t10_gap_annual_slope_*` values. Checked by name against the output.

**The finding for session 1: the test reports absence as drift.** §3 says it *"exits non-zero on
drift"*; it exits non-zero on *no recompute path*, which is a different condition. As written a
real drift would arrive as an eighteenth line among seventeen standing ones — *a check that
fires is not necessarily a check that found something* (I-47, Ruling AK). It is permanently red,
so I-11 applies. **Not this module's to fix**; recorded here and worth an issues-log row against
`scripts/11_database`.

---

## Verification — one pass, one re-fingerprint

**Prediction recorded before running: 7 CHANGED, 25 match.** Result: exactly that. §8.1 changed
a figure, not document text, so only R-6's paddock-report edits moved a fingerprint.

Every change block in all 7 was classified against the cumulative known set (the v1.4 documents
were overwritten, so the diff is against the delivered v1.0 and accounts for every prior change):

| blocks | class |
|---|---|
| 19 | cell size — R-6 |
| 8 | map caption — C1 render, v1.3 |
| 6 | network sentence — v1.1 |
| 0 | anything else |

Bala 29ca shows **one** block, the cell size — confirming §8.1 touched the figure only. **No
number changed in any document.** Only then:

```
re-fingerprinted 32 documents at version 1.5
7 fingerprint(s) moved · 0 document(s) new
inventory: 5 C1 · 25 D2
```

Also fixed: the two node-dependent tests raised a raw traceback when `node` was off PATH. They
now STOP with a message — a test that cannot run must not resemble one that passed.

---

## Still open

- **Scope-lock string** read from `RPTSCOPE_number_contract.csv` rather than the constant in
  `report_build.js` (§3 item 3) — the one §3 item not yet done.
- **Methods document** (§4) — one section per figure family, eleven families.
- **Figure registration** (§5) — session 1, additive, new `run_id`. Now with a second item:
  `T10_annual_gap_series.csv` needs registering, since a client figure depends on it.
- **Per-paddock output folders** — queued, not started, awaiting your written ruling.
- The 12 pages below 70% are warnings and yours; no layout was adjusted to chase them.
