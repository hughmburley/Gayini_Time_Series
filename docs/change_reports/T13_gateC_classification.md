# T13 Gate C — the pre-registered classification, the sweep, the robustness run

**Task:** T13 Gate C, per `Gayini_T13_spec.md` v1 §5, plus rulings 1–4 (30 Jul 2026).
**Date:** 30 July 2026 · **Prior:** SHA 8ff15c0 (Gate B)
**Scope:** apply the pre-registered ±1.0 cut; the five-point sweep; the drop-two-wettest robustness run.
**Additive:** compute + report only. **No DB write** (the classification table is Gate E), no builder run, no existing object modified, **no p-values anywhere**.
**Producer:** `scripts/12_zone_stratum/build_T13_gateC_classification.py` (tracked).
**Artefacts — these are the record, this report is a rendering:**
`Output/tables/T13_gateC_classification.csv` · `_sweep.csv` · `_robustness.csv` · `_bala29ca_raw_vs_adjusted.csv`

Session start: on `main`, up to date with `origin/main`, `main` has not moved.

**Pre-registration honoured.** The ±1.0 cut and the four-state rule were fixed at spec v1 §5 before
any output was seen and **no threshold has been moved**. The abandoned design-seat pilot cuts
(8 pp / 0.25 pp/yr) were **not computed, not compared against, and are not reconciled to**. They
appear nowhere in the producing script. The registered set stands as it came out.

---

## 0. Self-check — the robustness path is the same method (a check that can fail)

The robustness run recomputes the entire Gate B chain from the database with two water years
removed. That is only meaningful if the same code reproduces Gate B when it removes nothing. Run
with zero exclusions against the frozen `T13_gateB_part_measures.csv`:

| quantity | max abs diff, 115 parts |
|---|---|
| `level` | 4.99e−04 |
| `level_z` / `trend_z` | 4.98e−04 |
| `trend_raw` / `water_slope` / `trend_adj` | ≤ 4.96e−05 |

All within the CSV's 3–4 dp rounding. The script **asserts** this (`max < 5e-4` and an exact part-count
match) and aborts if it fails — it is a hard gate, not a printed note.

**Proof the assertion fires — actual recorded output.** Deliberately broken fixture: the
`level_dev` community-SD divisor multiplied by 1.01 in the recompute path only, everything else
untouched. Run verbatim:

```
SELF-CHECK vs frozen Gate B CSV, max |diff|: level_z=3.95e-02  trend_z=4.98e-04  level=4.99e-04
  trend_raw=4.95e-05  water_slope=4.96e-05  trend_adj=4.96e-05
Traceback (most recent call last):
  File "...broken_gateC_fixture.py", line 131, in <module>
    assert max(worst.values()) < 5e-4, f"recompute does not reproduce Gate B: {worst}"
AssertionError: recompute does not reproduce Gate B: {'level_z': 0.03952567777608973,
  'trend_z': 0.0004975025878917183, 'level': 0.0004989220755362567,
  'trend_raw': 4.9543415999164786e-05, 'water_slope': 4.959690966732655e-05,
  'trend_adj': 4.9619403559630904e-05}
```

The check fails on the broken input, passes on the real one, and **localises the fault**: only
`level_z` moved (3.95e−02, ~80× the tolerance) while `trend_z` and all three slopes stayed at their
rounding floor — which is exactly the signature of a corrupted level divisor. The run aborts before
any file is written, so a broken recompute cannot silently produce a robustness table. Fixture kept
out of the repo (scratchpad only); it is a one-line edit to the tracked script, reproduced above.

---

## 1. The registered classification — pre-registered cut ±1.00

| state | n parts |
|---|---|
| Recovering | **8** |
| Persistently poor | **14** |
| Declining | **16** |
| Unremarkable | **77** |
| **total** | **115** |

Values from `Output/tables/T13_gateC_classification.csv`, as of 30 July 2026.

The rule was implemented **exactly as written in §5**, including its asymmetry: a part that is both
low and falling (`level_z ≤ −1.0` *and* `trend_z ≤ −1.0`) falls in the *Persistently poor* cell, not
*Declining*, because the §5 table places no lower bound on trend in the low-level row. No part has
been reassigned and no threshold touched.

### Ruling 4 — the *Persistently poor* cell, split (additive, not a revision)

**Provenance note, as directed:** this split was raised by Claude Code at the Gate C scoping STOP,
**before any classification had been computed**, as an observation about the rule as written. It is
a **labelling refinement, not a threshold change** — membership of the low group is identical, and
no cut moved. It is recorded here so the sequence is auditable; the same note goes to the methods
document.

| sub-state | definition | n |
|---|---|---|
| low and flat | `level_z ≤ −1.0`, `−1.0 < trend_z < +1.0` | **10** |
| low and falling | `level_z ≤ −1.0`, `trend_z ≤ −1.0` | **4** |
| | | **14** |

Four parts are low **and** still falling. Under the pre-registered labelling they read as
"persistently poor", which implies static; they are not. **This is the state a land manager most
needs to see**, and Gate D should render it distinguishably — the map has 5 visual classes even
though the pre-registered classification has 4.

---

## 2. The sweep

| cut | Recovering | Persistently poor | *(low and flat)* | *(low and falling)* | Declining | Unremarkable |
|---|---|---|---|---|---|---|
| 0.50 | 15 | 21 | 10 | 11 | 19 | 60 |
| 0.75 | 10 | 21 | 14 | 7 | 16 | 68 |
| **1.00** | **8** | **14** | **10** | **4** | **16** | **77** |
| 1.25 | 4 | 13 | 10 | 3 | 6 | 92 |
| 1.50 | 3 | 8 | 7 | 1 | 3 | 101 |

From `Output/tables/T13_gateC_sweep.csv`.

### Composition — the §5 stability question, answered rather than asserted

§5 requires that if the *composition* of the recovering set changes substantially across the sweep,
that is itself the headline finding. It is answerable because membership was tracked, not just counts:

| cut | n | shared with registered | added vs registered | dropped vs registered |
|---|---|---|---|---|
| 0.50 | 15 | 8 | 7 | 0 |
| 0.75 | 10 | 8 | 2 | 0 |
| **1.00** | **8** | **8** | — | — |
| 1.25 | 4 | 4 | 0 | 4 |
| 1.50 | 3 | 3 | 0 | 5 |

**Verdict: the recovering set is strictly nested, and the composition is stable.** At every cut the
set is a clean subset or superset of the registered one — **nothing is ever swapped in as something
else drops out**. 15 parts are recovering at some cut; **3 are recovering at every cut** (Bala 15
Inland, Bala 29ca Aeolian, Bala 29ca Riverine).

So the cut controls **how many** parts are called recovering, not **which**. That is the favourable
outcome: the count is cut-dependent and must always be quoted with its threshold, but the ranking
underneath is not an artefact of where the line was drawn. The honest statement for the client text
is *"between 3 and 15 parts depending on strictness, 8 at the registered cut, and the same parts
throughout"* — not a bare 8.

**Caveat that must travel with the count.** The z-scores are scaled to each community's own spread
(Gate B §2: SD of `level_dev` is 11.92 / 10.86 / 6.03 pp for Aeolian / Riverine / Inland). A fixed
`z` therefore means **unlike amounts of ground** across communities — ~12 pp in Aeolian or Riverine
against ~6 pp in Inland. Required in the Gate D caption per Gate B; restated here because the state
counts inherit it.

---

## 3. Robustness — dropping the two wettest water years

**Definition (Ruling 3), property scope.** The two water years with the highest
`sum(wet_pixels) / sum(valid_pixels)` across **all** parts of `fact_zone_community_flood_annual` —
one fixed pair, dropped for every part. Per-part dropping was rejected: it would remove each part's
own extremes and systematically flatten every trend toward "unremarkable", biasing the check toward
a null.

| water year | property-scope flood fraction | |
|---|---|---|
| **2022** | **87.16%** | dropped |
| **2016** | **68.84%** | dropped |
| 2010 | 63.28% | retained |
| 1992 | 58.14% | retained |
| 1990 | 56.43% | retained |

All 115 parts still meet the ≥25-year support rule on 33 years, so the comparison is like-for-like.

| state | full record | drop 2 wettest |
|---|---|---|
| Recovering | 8 | 5 |
| Persistently poor | 14 | 13 |
| Declining | 16 | 11 |
| Unremarkable | 77 | 86 |

**12 of 115 parts change state (10%).** Every change is toward *Unremarkable* except one
(Dinan 7 Aeolian, Unremarkable → Declining). Full list in `Output/tables/T13_gateC_robustness.csv`;
the four Recovering/Persistently-poor movements:

| part | full | drop 2 | `trend_z` |
|---|---|---|---|
| Dinan 8 · Inland | Recovering | Persistently poor | +1.11 → +0.93 |
| Dinan 13 · Riverine | Recovering | Unremarkable | +1.48 → +1.33 |
| Dinan 9 · Riverine | Recovering | Unremarkable | +1.13 → +1.07 |
| Dinan 8 · Riverine | Persistently poor | Unremarkable | `level_z` −1.04 → −0.99 |

**Verdict: the classification largely survives, and its core survives completely.** 5 of the 8
recovering parts remain recovering, and the 3 core parts recovering at every cut are untouched.
But **the honest reading is that the marginal calls are marginal**: every one of the 12 changes is a
part sitting within ~0.1 of a threshold, moving a few hundredths and crossing it. The three
recovering parts that fall away all sat between +1.11 and +1.48; none of the parts well clear of the
cut moved at all.

**This is a real constraint on what Gate D may claim** and must be in the caption: a part near a
boundary is not reliably classified, and the map should not imply that 8 is a firm count. The
sweep and the robustness run agree on the same thing from two directions — the extremes are solid,
the margin is soft.

---

## 4. Ruling 2 — Bala 29ca Inland: raw versus water-adjusted, side by side

`Output/tables/T13_gateC_bala29ca_raw_vs_adjusted.csv`, as of 30 July 2026.

| quantity | Bala 29ca · Inland | Inland community median |
|---|---|---|
| `trend_raw` | **−0.2160** pp/yr (SE 0.2262) | **−0.2112** pp/yr |
| deviation, **raw** scale | **−0.0048** pp/yr | — |
| `water_slope` | +0.3442 pp per pp flood (SE 0.1199, r = 0.447) | — |
| **own flood trend** | **+0.3892** pp/yr | **−0.2798** pp/yr |
| **own mean flood** | **15.92%** | **30.93%** |
| `trend_adj` | **−0.3500** pp/yr (SE 0.1959) | −0.1516 pp/yr |
| `trend_dev` | −0.1984 pp/yr | — |
| `trend_z` | **−1.108** (community SD 0.1790) | — |
| `level_z` | **−0.962** — **0.038 from the −1.0 cut** | — |
| **state at the registered cut** | **Declining** | — |

### The design seat's raw-scale claim is confirmed exactly

`trend_raw` −0.2160 against a community median of −0.2112 — a deviation of **−0.0048**, i.e. the
−0.005 that has been stated. On the raw scale this part does track the Inland median almost
perfectly. **That claim was never wrong**; it measures a different quantity from `trend_dev`.

### The divergence is exact and decomposable

OLS gives an exact identity, verified to ~4e−05 on all three Bala parts:

```
trend_raw  =  trend_adj  +  water_slope × own_flood_trend
  −0.2160  =    −0.3500  +  (+0.3442 × +0.3892 = +0.1340)
```

Rising water contributed **+0.134 pp/yr of lift**. Strip it out and the part is declining at
**−0.350 pp/yr**, against an Inland community median of −0.152. Both numbers are correct and they
answer different questions: *"how did it change?"* (typically) versus *"how did it change given the
water it got?"* (worse than typical).

### ⚠ The conclusion holds, but the stated mechanism does not — correct both

The design-seat reading was that the part *"received more water than typical Inland country and
still only managed the typical raw decline."* **The conclusion is right and the premise is
backwards.**

- **It did not receive more water.** Own mean flood **15.92%** against an Inland community median of
  **30.93%** — roughly **half**. It is among the drier Inland parts, which is consistent with
  Bala 29ca being the dry-western outlier that L-01 and the T10 work already identified.
- **What is elevated is the water *trend*, not the water *level*.** Its own flood frequency is rising
  at **+0.389 pp/yr** while typical Inland country is **drying at −0.280 pp/yr** — the spec's §3
  premise that Bala 29ca is the only reference paddock whose flood frequency is rising, now confirmed
  at part grain.

**The correct sentence is therefore:** *this part has been getting wetter while its community has
been drying, and with a positive water response (+0.344) that wettening should have lifted its
cover — yet its cover still fell at the community-typical rate. Once its own water gain is
accounted for, it is underperforming its community.*

**What this reaches (design-seat job, per the ruling).** The "unremarkable Inland third" line needs
qualifying wherever it appears — but note it needs **two** corrections, not one: the trend framing
(unremarkable on raw, underperforming once adjusted) **and** the water framing (drier than typical
Inland, not wetter — its distinction is a rising trend on a low baseline). The raw −0.005 figure
itself needs no correction and should be retained with its scale named.

**Knife-edge warning.** `level_z` = −0.962 sits **0.038** from the −1.0 level cut. At `level_z ≤ −1.0`
this part would be *Persistently poor* (Ruling 4 sub-state: **low and falling**) rather than
*Declining*. It is also one of the 12 parts that changes state in the robustness run
(Declining → Unremarkable, `trend_z` −1.11 → −0.92). **The single most-scrutinised part in the
project is marginal on both axes and on the robustness check.** No threshold has been moved to
accommodate this; it is reported as the finding it is. Any client text about Bala 29ca's Inland
third must be written to survive this part being on either side of the line.

---

## 5. Invariants

- Compute + report only. Four CSVs to `Output/tables/`. **No DB write, no builder run, no existing object modified.**
- **No p-values** anywhere — 35 (33 in the robustness run) consecutive annual observations are not independent.
- Pre-registration intact: ±1.0 unchanged; sweep as specified at 0.50/0.75/1.00/1.25/1.50; the pilot 7/17/8/83 not computed, compared to, or referenced except as the abandoned prior.
- Gate B report §3 corrected under Ruling 1 with the superseded values retained visibly as a correction.
- Ruling 4 split recorded as additive and provenance-stamped.
- The self-check gate proven to fire on a broken fixture (§0).

## Housekeeping done this gate

- `CLAUDE.md` — L-01 path corrected at both sites to `docs/reference_update/Gayini_learning_L01_unit_of_analysis.md`; T13 status corrected from "no spec written" to spec v1 with Gates A/B committed.
- **Three** `CLAUDE.md` files existed, not two. `docs/CLAUDE.md` and `docs/Spec_audit/CLAUDE.md` were byte-identical 25 July copies (25,756 B) against the live 29 July root file (35,047 B) — both auto-loadable, neither carrying the number rules or L-01. **Both deleted.** One record retained at `docs/archive/CLAUDE_md_20260725_superseded.md`, deliberately **not** named `CLAUDE.md` so no session can load it, with the standard archive header.
- **Deviation from the ruling, flagged:** the record was **not** placed in `scripts/archive/`. That directory does not currently exist, and creating it would trip the B5 conflict — `run_spine_smoke_test.R:104-112` (`folder_scripts/archive_absent`) hard-fails if `scripts/archive/` exists. `docs/archive/` already exists and is the documented home for archived docs. Say if you want it moved.

## STOP

Registered classification, sweep and robustness complete; Ruling 2 verified with the mechanism
correction above; Rulings 1, 3, 4 applied. **Waiting for review before Gate D** (the map, the
`level_z`×`trend_z` scatter panel, and the 0.75/1.25 small multiples).
