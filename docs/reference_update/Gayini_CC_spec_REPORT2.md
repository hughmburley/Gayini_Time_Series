# CC spec REPORT-2 — the parts page, corrected for water

**Design seat · 7 August 2026.** For the report stream. Amends the paddock report template and
rebuilds. Companion to `Gayini_report_stream_handoff_20260804.md`.

**This is a labelling correction, not an analysis.** Every value it needs already exists in
`PARTREG_part_residuals.csv`, which is registered and shipped in pack v1.2. **Nothing is refitted,
no residual is recomputed, and no number changes.** What changes is which registered number the
reports rank on, and what they say about it.

---

## 0 · Standing conditions

Report seat. `build_v2.js`, `make_figs2.py`. **The methods seat holds pack v1.3 today** — confirm
its worktree before any write, and do not touch `Output/pack/`, `Output/unzoned/` or anything under
`scripts/12_zone_stratum/`.

Read-only on the database. `mode=ro`, `PRAGMA query_only=1`. Recon first.

Additive-only. Existing reports are superseded by rebuild, not deleted.

---

## 1 · The finding this corrects

The parts page carries a column headed **"Compared with the same country elsewhere"**. It ranks each
part's cover floor against other parts of the same vegetation community. **It does not hold wetness
constant.**

Within Inland Floodplain the floor rises about +0.285 percentage points per point of wetness
(`2.6_inland`, interval +0.18 to +0.40, r 0.62), across a range running from 6% to 59%. So a dry
Inland part carries a low floor for a reason that has nothing to do with how it is faring. The
column reads that as poor country.

**The error runs in both directions and its sign is set by wetness.** Seventeen parts in sixteen
paddocks move more than thirty percentile points between the two rankings:

| paddock | community | wetness | floor rank | water-adjusted rank |
|---|---|---:|---:|---:|
| Bala 28ca | Inland | 49.7% | 45 / 61 | **5 / 61** |
| Bala 18 | Inland | 45.9% | 59 / 61 | 25 / 61 |
| Bala 20 | Inland | 42.1% | 55 / 61 | 27 / 61 |
| Mara 21 | Riverine | 33.3% | 33 / 37 | 19 / 37 |
| Mara 8 | Inland | 40.9% | 37 / 61 | 14 / 61 |
| Mara 21 | Inland | 44.0% | 26 / 61 | 4 / 61 |
| Bala 23 | Inland | 40.6% | 33 / 61 | 13 / 61 |
| Bala 12 | Inland | 40.3% | 25 / 61 | 6 / 61 |
| Dinan 3 | Inland | 25.1% | 30 / 61 | 52 / 61 |
| Mara 2 | Inland | 20.8% | 9 / 61 | 32 / 61 |
| Bala 6 | Inland | 15.8% | 34 / 61 | 61 / 61 |
| Dinan 10 | Inland | 5.9% | **2 / 61** | 30 / 61 |
| Bala 5 | Inland | 17.2% | 11 / 61 | 45 / 61 |
| Bala 1 | Inland | 15.6% | 24 / 61 | 59 / 61 |
| Bala 29ca | Inland | 15.9% | 10 / 61 | 48 / 61 |
| Bala 2 | Inland | 11.3% | 19 / 61 | 60 / 61 |
| Mara 11 | Inland | 8.2% | 7 / 61 | 54 / 61 |

**A verification you can run on this table before touching anything.** Every part that falls in rank
is wet — 33% to 50%. Every part that rises is dry — 5.9% to 25%. The ordering is monotonic in
wetness with no exceptions. If your reproduction does not show that, something is wrong with the
join, not with the finding.

**Two of the sixteen are conserved paddocks**, Bala 28ca and Bala 29ca. Bala 28ca moves 45 → 5. That
belongs to the reference-state stream as well as to this one; report it, interpret nothing.

---

## 2 · Source of truth

`Output/pack/PARTREG/tables/PARTREG_part_residuals.csv`, whole-record columns only.

| quantity | column |
|---|---|
| cover floor | `whole_record__floor_mean` |
| wetness | `whole_record__inund_mean` |
| departure from expectation | `whole_record__residual` |
| join keys | `part_id`, `zone_fid`, `paddock_name`, `community_short` |

**Ranks are computed within community, across all 115 supported parts** — not within the paddock,
not across the property. The shipped `residual_rank_1_is_largest_shortfall` ranks across all 115 and
is **not** the column the report needs. Compute the within-community rank and emit it as a derived
table, `Output/tables/REPORT2_part_ranks.csv`, registered as a table asset. **Do not register 115
individual ranks as headline numbers.**

**Direction is in the name, both columns, rank 1 = worst.** That matches the existing convention and
the existing floor column. A silent direction flip here would be the hardest error in this project to
catch downstream.

---

## 3 · The template changes

### 3.1 · The parts table gains a column

| This part of the paddock | Area | Cover on the thinnest twentieth | Compared with the same country elsewhere | **For the water it gets** | Over 35 years |

**Both comparison columns stay.** The first is what the ground actually carries; the second is what
it carries relative to its water. Neither replaces the other and the report must not imply that one
corrects the other.

**Ranks in both columns. Never percentage points in the new one.** A 5 pp shortfall in wet country
and a 15 pp shortfall in dry country are not comparable quantities — the typical miss runs from
about 12.8 pp on the driest quarter of the property to 3.8 pp on the wettest. Ranks within community
sidestep that. Percentage points would import it.

### 3.2 · The label vocabulary — pre-registered, not composed per part

Rank position within community, rank 1 = largest shortfall:

| position | wording |
|---|---|
| lowest, or 2nd | "lowest of N for its water" · "second-lowest of N for its water" |
| bottom 10% | "among the lowest of N for its water" |
| 10–25% | "low for its water — Nth of M" |
| 25–75% | "about what its water predicts — Nth of M" |
| 75–90% | "high for its water — Nth of M" |
| top 10% | "among the highest of N for its water" |

**CC does not write per-part prose.** The label is a lookup on rank position. Composed wording is how
a caption acquires a claim nobody ruled on.

### 3.3 · One sentence in the narrative

On the parts page, following the existing *"Each kind of country has its own normal…"*:

> Within one kind of country, the drier parts carry less cover in their poorest patches. So the
> first comparison reflects how wet a part is as much as how it is faring. The second allows for
> that.

### 3.4 · The expectation page gains a guard

The **"For how dry it is"** page draws the between-paddock expectation line. A reader will take its
slope as what water buys. It is not that quantity, and the quantity it is mistaken for is about
three times smaller.

Add, in the page's own voice:

> This line describes how paddocks differ from one another over the long run. It is not what an
> extra point of flooding would add to this paddock. That is a different and smaller number.

**No figure is given.** The within-place response is unregistered and stays out of a deliverable.

### 3.5 · The three reports that present as undivided

Bala 15, Bala 28ca and Mara 3 each hold a second part below support — Riverine 23 cells, Aeolian 10,
Aeolian 1. Their reports currently have no parts page at all, which reads as a paddock with one kind
of country rather than one with a sliver too small to summarise.

**Add a single line to each**, on the page where the parts page would sit:

> A second kind of country is mapped here, too small to report — N cells, under a hectare.

Give the true area. **Do not add a parts page for one part.**

---

## 4 · What must never happen

- **No refit, no recomputation of any residual.** Values are read from the shipped CSV.
- **No size adjustment**, and no adjustment of any kind to a residual.
- **No condition claim.** A part that is "high for its water" is not in good condition. It carries
  more cover than the fitted line predicts, and the reports already say what that does and does not
  mean. That caveat stays.
- **No management claim.** No column, label or sentence attributes any part's position to grazing,
  conservation status or anything else.
- **Do not rank within the paddock.** Three parts ranked against each other would produce a
  first, second and third in every paddock and invite exactly the reading the whole part-grain
  argument exists to prevent.
- **Do not compare across communities.** An Inland rank of 30/61 and an Aeolian rank of 5/17 are
  positions in different distributions.

---

## 5 · QA

**Pass 3 of the QA2 audit applies in full.** Every rank, count and label in a rebuilt report is
checked against `REPORT2_part_ranks.csv` by an independent path. Qualitative labels are checked, not
accepted because the lookup produced them.

**Two specific checks:**

- The monotonicity in §1 — every faller wet, every riser dry.
- Bala 29ca. Its Aeolian third sits at the 53rd wetness percentile of its community, so it should
  read rank 1 of 17 on **both** columns. Its Riverine third should read 2 of 37 on both. Only its
  Inland third moves, 10 → 48. **If Bala 29ca's two dry thirds move, the join is wrong.**

---

## 6 · Gates

**Gate 1 · STOP.** Rebuild **two** paddocks only: **Dinan 10** and **Bala 26ca**. They fail in
opposite directions — Dinan 10's Inland third goes from "second-lowest of 61" to ordinary, Bala
26ca's from "ordinary" to third-worst. If the template reads correctly on both, it reads correctly.
Report both, and do not proceed.

**Gate 2 · STOP.** The remaining 35 multi-part paddocks, plus the three sub-support reports.

**Gate 3.** The 27 single-community paddocks and the 66 site reports need only §3.4's guard
sentence. Run to completion, report once.

---

## 7 · If time runs short

The fallback, in order of what to protect:

1. **§3.4's guard sentence, everywhere.** One line, no data join, and it closes the largest
   misreading available in the whole report set.
2. **The 16 paddocks in §1's table.** Their labels are wrong in a way a reader will act on. If the
   second column cannot be built, add a caveat sentence to those parts pages saying the comparison
   is on cover alone and does not allow for how wet each part is.
3. Everything else.

**A report that ships with the single column and no caveat is the outcome to avoid.** Dinan 10's
"second-lowest of 61" and Bala 26ca's "ordinary" are both wrong in the direction a manager would act
on, and both are in files already drafted.
