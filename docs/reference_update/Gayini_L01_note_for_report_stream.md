# For the report stream — a defect to handle before the paddock batch runs

**From:** reference-state stream (T1/T2/T6/T8/T9/T10)
**Date:** 29 July 2026
**Concerns:** the 21 paddock reports, and any site report that quotes a paddock-level figure
**Urgency:** before the batch, not after. Cheap now, expensive once 21 reports are out.
**Source:** `Gayini_learning_L01_unit_of_analysis.md`

---

## The short version

Management zones were drawn for grazing rotation, not for ecology. Where a paddock spans more
than one vegetation community, a single paddock-level number averages across unlike country and
describes no real place.

**Fourteen of the 64 paddocks are below 75% single-community dominance. Nine are below 60%.**
For those, a headline figure in a paddock report is an average over country that behaves
differently, and it can be actively misleading rather than merely imprecise.

This is not a hypothetical. It produced a wrong claim in our own change report yesterday, on
the flagship result of a completed task — see §4.

---

## 1. The affected paddocks

| paddock | dominance | composition |
|---|---|---|
| Bala 29ca | 35% | Inland 35 · Riverine 33 · Aeolian 32 |
| Dinan 3 | 47% | Inland 47 · Riverine 28 · Aeolian 25 |
| Mara 8 | 50% | Aeolian 50 · Riverine 33 · Inland 17 |
| Dinan 8 | 53% | Riverine 53 · Aeolian 39 · Inland 9 |
| Mara 13 | 55% | Riverine 55 · Inland 43 · Aeolian 3 |
| Mara 2 | 57% | Inland 57 · Riverine 43 |
| Dinan 11 | 58% | Riverine 58 · Inland 21 · Aeolian 21 |
| Dinan 13 | 58% | Riverine 58 · Inland 37 · Aeolian 5 |
| Bala 6 | 58% | Inland 58 · Riverine 42 |
| Dinan 9 | 61% | Inland 61 · Aeolian 21 · Riverine 18 |
| Dinan 4 | 62% | Inland 62 · Riverine 37 · Aeolian 1 |
| Dinan 5 | 63% | Inland 63 · Riverine 37 |
| Dinan 10 | 65% | Aeolian 65 · Inland 28 · Riverine 7 |
| Mara 1 | 69% | Inland 69 · Riverine 31 |

The remaining 50 are 75% or above, and 25 are single-community. **Check your 21 against this
list** — if none of your reports covers a paddock here, this note costs you nothing.

Shares are of non-treed in-scope pixels, from `census_by_zone_stratum`, computed 28 July.

## 2. Why it matters more than it sounds

The three communities are not on the same footing. Property-median vegetation floor:

| community | median floor | median trend |
|---|---|---|
| Inland Floodplain | 73.1% | −0.211 pp/yr |
| Aeolian Chenopod | 61.5% | +0.222 pp/yr |
| Riverine Chenopod | 59.5% | −0.282 pp/yr |

They differ by more than most management effects, and they are moving in **opposite
directions**. So a paddock that is half Inland and half Riverine has a headline number sitting
between two figures that mean different things, and a trend that is the average of a decline
and a rise.

Worked example — Bala 29ca, the most-mixed paddock:

| part | floor | vs that community's median | trend |
|---|---|---|---|
| Aeolian third | 29.4% | −32.1, lowest of 17 | **+0.560** |
| Riverine third | 34.6% | −24.9, 2nd of 37 | **+0.564** |
| Inland third | 67.3% | −5.8, 10th of 61 | **−0.216** |
| **whole paddock** | **40.5%** | — | **+0.682** |

Two-thirds of that paddock is among the worst country of its kind on the property and
recovering strongly. One third is ordinary and drifting down like everywhere else. The
paddock-level figures — 40.5% and +0.682 — describe neither.

## 3. What we suggest, in ascending order of effort

**Minimum — state the composition.** One line in every paddock report: *"This paddock is 58%
Riverine chenopod and 42% Inland floodplain country. The figures below are averages across
both."* Costs a lookup and a sentence, and it converts a misleading number into a qualified one.

**Better — report the mixed paddocks by part.** For the fourteen above, give the figures per
community as well as the whole-paddock average. The data already exists at that grain:
`fact_zone_community_veg_annual` (paddock × community × year), and
`T10_gateC_percommunity.csv` in `Output/tables/` holds all 115 paddock-parts with level, trend,
and each part's rank against its own community — built 28 July with a tracked producer script.

**Best, if there is time — compare like with like.** A part's floor means little against the
property average and a lot against the median for the same community. "The Riverine part of
this paddock sits well below other Riverine country" is a statement a land manager can check
and act on. "This paddock is below the property average" mostly restates which communities it
contains.

## 4. Why we are confident this is worth your time

We made this exact error ourselves, twice, in one week.

The first was in an analysis: a paddock-level contrast that looked like a grazing effect turned
out to be block structure. The second was worse, because we had already learned the lesson. Our
T10 change report nominated a comparison between Bala 29ca (ungrazed) and Dinan 10 (grazed) as
*"the sharpest management-relevant contrast the project has produced"* — their paddock-level
adjusted trends were +0.556 against +0.020.

Decomposed, it dissolved. Their Riverine country behaves almost identically (+0.845 against
+0.737 relative to community median), Dinan 10 is actually **ahead** in Inland, and the
paddock-level gap was composition: Bala 29ca is a third Riverine, Dinan 10 is 7% Riverine and
65% Aeolian. The claim was withdrawn and a supersede banner added to the earlier report.

If it can pass an internal review with a full audit trail, it can pass into a client report.

## 5. What we are not asking for

Not a rebuild, not a new analysis, and not a delay. The 10 August deliverable is yours and it
takes precedence. If the only thing that fits is the one-line composition statement, that is a
real improvement and we would rather have that than nothing.

We also are not asking you to adopt the classification work we have been doing on paddock-parts
— that is unregistered, uses hand-chosen thresholds, and is not fit to quote. Only the
composition shares and the per-part figures in §3 are settled and safe to use.

## 6. Contacts and provenance

Anything quoted here traces to `Gayini_Results.sqlite`. Composition from
`census_by_zone_stratum`; per-part levels and trends from `fact_zone_community_veg_annual`
(`series_variant = 'mean_of_seasons'`, minimum 30 pixels per cell, 25+ years).
Full reasoning in `Gayini_learning_L01_unit_of_analysis.md`; the paddock-part substrate is
`Output/tables/T10_gateC_percommunity.csv` (115 rows).
