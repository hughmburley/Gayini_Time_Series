# REPORTS — R-8 · composition prose

**Session:** report batch, third concurrent seat · **Date:** 5 August 2026
**Builder:** v1.5 → **v1.6** · **DB read-only.** No write attempted. **Not shipped, not re-fingerprinted.**

```
lint_builder.py        0 error · 0 warn                       exit 0
check_scope_claims.py  clean across 89 (R-8 checks added)     exit 0
check_page_fill.py     343 pages · 0 above 92% · 124 below 70% exit 0
tests/                 12 assertions · 4 files · 0 fail        exit 0
verify_batch.py        30 match · 2 changed · 0 missing        (manifest covers the original 32)
```

The 2 CHANGED are Bala 15 and Bala 28ca — the two R-8-affected paddocks that are in the
original 32. Mara 3 and Bala 8/11 are not in it.

---

## 1. Implemented as specified

Page 1 now counts **the parts that reach the part-classification support rule** — exactly the
rows page 3 shows. Derived from the set difference between composition and parts, so no paddock
is named in code:

```python
_classified = {p['community'] for p in parts}
r['trace_communities'] = [c for c in composition
                          if c['short'] != 'Woodland' and c['community'] not in _classified]
```

Exactly 3 of 64 changed, and they are the three you named:

| | before | after |
|---|---|---|
| **Bala 28ca** | spans **3** kinds of country — 83% Inland Floodplain · 17% Riverine · **0% Aeolian**. | spans **2** kinds of country — 83% Inland Floodplain · 17% Riverine. *A few cells of Aeolian fall inside the boundary, too few to report on separately.* |
| **Bala 15** | is **entirely** Inland Floodplain country, so the figures… | is **almost entirely** Inland Floodplain country, **with a trace of Riverine too small to report on separately.** |
| **Mara 3** | is **entirely** Inland Floodplain country, so the figures… | is **almost entirely** Inland Floodplain country, **with a trace of Aeolian too small to report on separately.** |

Bala 28ca's page 1 now says two, and its parts table has two rows. They cannot disagree: both
read `fact_zone_community_part_classification`.

**Your Mara 3 claim is exact.** Its Aeolian is **one 24.97 m cell — 0.0624 ha**, which is
`PIXEL_AREA_HA` to five decimals. Bala 15's Riverine is 23 cells (1.43 ha); Bala 28ca's Aeolian
is 10 cells (0.62 ha).

---

## 2. Two corrections to the ruling

### 2.1 It affects 3 of 64, not 6 — 61 unaffected, not 58

Under the support-rule criterion the ruling specifies, the affected set is exactly Bala 15,
Bala 28ca and Mara 3. The other three sub-1% paddocks **reach the rule and are classified parts**:

| | share | classified part? |
|---|---|---|
| Bala 8/11 · Riverine | 0.20% | **yes** |
| Dinan 4 · Aeolian | 0.64% | **yes** |
| Dinan 7 · Aeolian | 0.77% | **yes** |

So they keep their percentages and get no trailing clause, which is what the rule requires. The
"58 of 64" looks like it came from my *"6 of 64 name a community below 1%"* figure rather than
from the support-rule criterion — those are different sets, and the difference is the whole point
of choosing the support rule over a percentage cut. **The rule is implemented as written.**

### 2.2 The rule as written does not stop every percentage that rounds to zero

`Bala 8/11` came out of R-8 reading:

> spans 2 kinds of country — **100% Inland Floodplain · 0% Riverine**.

Its Riverine **reaches the support rule** (3.1 ha, a classified part), so it is legitimately one
of the two kinds and page 3 shows it. But 99.8% renders as 100% and 0.2% renders as 0% — two
kinds of country summing to 100 and 0. R-8's stated intent — *"stops printing a percentage that
rounds to zero"* — plainly covers this, but its mechanism does not, because the mechanism keys on
the support rule and this community passes it.

Bounded at both ends, since both mislead:

```
spans 2 kinds of country — over 99% Inland Floodplain · under 1% Riverine.
```

**1 of 64.** Found by the R-8 check I added, on its first run against the full set — not by
reading. Flagged for ratification rather than held behind it, per the transfer note. If you would
rather it read differently, only this one sentence changes.

---

## 3. A silent reordering avoided

`parts` arrives ordered by community name; `composition` was ordered share-descending; **they
differ for 15 of 64**. Driving page 1 from `parts` without re-sorting would have silently
reordered the listing in those 15 documents — a change nobody ruled on, arriving as fifteen
CHANGED fingerprints to explain. `comp` is sorted share-descending, so the established order is
preserved and only the ruled change appears in the diff.

---

## 4. Register differences in your examples — not adopted, flagged

Your illustrations differ from the current register in three ways beyond the counting rule. I
implemented the rule and the trailing clause verbatim, and kept the register, because these
ripple past the sentence:

| | your example | current | if changed |
|---|---|---|---|
| count | *"spans **two** kinds"* | `spans 2 kinds` | 37 multi-community documents |
| separator | *"83% Inland Floodplain **and** 17% Riverine Chenopod"* | `83% Inland Floodplain · 17% Riverine` | 37 documents |
| community name | *"Riverine **Chenopod**"*, *"Aeolian **Chenopod**"* | `Riverine`, `Aeolian` | page 1, the parts table, the composition figure and the site reports — `short` is used throughout |

The third is the substantive one: `short` is the label everywhere, so lengthening it is a
register change across the whole batch, not one sentence. Say the word and I'll do any or all of
the three; I did not want to infer them from an illustration.

---

## 5. R-8 made testable, and a defect it found immediately

`check_scope_claims.py` gains check E, enforced **against the document** because the claim is
about what a reader sees:

- page 1's *"spans N kinds"* must equal the classified part count;
- no community printed at 0%;
- *"is entirely"* never used while a trace exists;
- a trace must be named in a trailing clause.

Proven to fire — the fixture suite is now six cases, all correct:

```
none  exit 0 OK · property_area exit 1 OK · band_area exit 1 OK
two_rules exit 1 OK · r8_count exit 1 OK · r8_zero_pct exit 1 OK
```

`r8_count` injects the pre-R-8 defect exactly: page 1 claiming three kinds over a two-row parts
table. It is rejected.

---

## 6. Word lock files were crashing three checkers

While you had `Gayini_paddock_report_Bala_1.docx` open, Word wrote `~$yini_paddock_report_Bala_1.docx`
— 162 bytes, not a zip, and matching `*.docx`. `check_scope_claims`, `check_page_fill` and
**`fingerprint_batch`** all enumerate that directory; the first two died on `BadZipFile`, and the
third would have written the lock file into the manifest as a document.

New `docxset.built_docx()` excludes `~$`, used by all five call sites. **These tools run against
a directory a human reads from, so a check must not fail because someone is looking at the
output** — and the manifest must never acquire a phantom entry because of it.

---

## 7. State

**89 documents. Not shipped. Not re-fingerprinted** — still pending your read of the 12-unit
sample, which is unchanged except that **Bala 8/11 now also carries the percentage fix**, making
it worth a look for two reasons rather than one.

R-8 moved 4 of 64 paddock reports: Bala 15, Bala 28ca, Mara 3 (composition prose) and Bala 8/11
(percentage rendering). No site report changed. No number changed anywhere.
