# Reference-state figure text — verification record

**Read-only.** 4 August 2026 · SQLite `mode=ro`, `PRAGMA query_only=1` · nothing changed.
Verifies the final text for pack items F1, F2, F3, F6 = methods-document Figures 21, 22, 23, 26
(pp 37, 38, 39, 42). Written because **Ruling AB's Figure 26 footnote and §4.6's worked case both cite
values reproduced here**, and those citations need a source that is not a chat message.

**Result: every number in the four passages reproduces. Two sit on rounding boundaries, and one
label ambiguity resolves in the document's favour.**

---

## 1 · Figure 26 · the nine-value table — all nine confirm

Adjusted differences in percentage points against the rotational comparator, area-weighted over
wetness bands within stratum.

| arm | community | text | pinned | `number_id` |
|---|---|---:|---:|---|
| conserved | Aeolian | −10.5 | −10.46 | `ref_grazed_floor_aeolian` |
| conserved | Inland | +1.1 | 1.08 | `ref_grazed_floor_inland` |
| conserved | Riverine | −4.5 | −4.49 | `ref_grazed_floor_riverine` |
| unzoned, inferred | Aeolian | +6.0 | 5.99 | `three_arm_floor_deficit_unzoned_inferred_aeolian` |
| unzoned, inferred | Inland | −1.2 | −1.18 | `three_arm_floor_deficit_unzoned_inferred_inland` |
| **unzoned, inferred** | **Riverine** | **+7.9** | **7.95** | `three_arm_floor_deficit_unzoned_inferred_riverine` |
| unzoned, plot-confirmed | Aeolian | +10.2 | 10.16 | `three_arm_floor_deficit_unzoned_plot_aeolian` |
| unzoned, plot-confirmed | Inland | −1.8 | −1.81 | `three_arm_floor_deficit_unzoned_plot_inland` |
| unzoned, plot-confirmed | Riverine | +9.3 | 9.35 | `three_arm_floor_deficit_unzoned_plot_riverine` |

`n_units` for the inferred-standard arm in Inland Floodplain = **17**, confirming the limitation's
"seventeen".

### Rounding boundary 1 — Riverine inferred

**The text is correct and the registry appears to contradict it.**

| | value | rounds to 1 dp |
|---|---|---|
| **source** — area-weighted band mean, recomputed at DOC-1 Gate C | **7.947** | **+7.9** ✓ |
| pin — `dim_headline_number`, stored at 2 dp | 7.95 | **+8.0** ✗ |

Rounding the pin is rounding twice. A reader checking the text against the registry rather than
against source will read a defect that is not there. **This is the case Ruling AB §4.6(b) exists to
prevent.**

---

## 2 · Figure 22 · the mean-cover pair — both confirm

| quantity | text | found |
|---|---|---|
| adjusted, Aeolian conserved, mean cover | −2.3 | **−2.32** (`ref_grazed_mean_cover_aeolian`) |
| raw, Aeolian conserved, mean cover | −4.1 | **−4.050** |

The raw figure is the mean over 35 years of (arm `veg_mean` − the grazed zones' per-year median
`veg_mean`), from `fact_three_arm_stratum_veg_annual` (`regime_band = 'ALL'`,
`series_variant = 'mean_of_seasons'`) against `fact_zone_community_veg_annual`
(`grazing_excluded = 0`, `below_min_support = 0`) — the same method as the floor raw gap verified at
DOC-1 Gate C.

So the passage's *"−32.0 raw and −10.5 adjusted on the cover floor to −4.1 raw and −2.3 adjusted on
the mean"* holds on all four terms, and the pack caption's *"about 32 percentage points to about 4"*
holds.

Other communities on mean cover, for completeness: **Inland +1.095 · Riverine −2.455**.

### Rounding boundary 2 — the raw mean gap

**−4.050 sits exactly on the 1 dp boundary.** Round-half-away-from-zero gives **−4.1** (the text);
round-half-even gives −4.0. The text is correct under the convention used throughout the document.
Recorded so it is not "corrected" later.

---

## 3 · Figure 26's `n=2` against `n=1` — resolved, both labels correct

**Aeolian conserved `n = 2` is Bala 28ca and Bala 29ca.** Bala 28ca's Aeolian portion is
**10 pixels — 0.62 ha, 0.0% of the paddock.**

**That part is one of the three that fail the ≥ 30-valid-cell support rule.** The three, named:

| part | pixels | area |
|---|---:|---:|
| Bala 15 · Riverine | 23 | 1.43 ha |
| **Bala 28ca · Aeolian** | **10** | **0.62 ha** |
| Mara 3 · Aeolian | 1 | 0.06 ha |

Derived as the set difference between the census's focus parts and the 115 rows of
`Output/tables/T13_gateC_classification.csv`. These are exactly the three behind the document's
existing *"three of the 118 parts fall below the minimum support rule"*.

**So `n = 2` counts geometry and `n = 1: Bala 29ca` counts analysis. Both are right; the label needs
a key, not a correction.**

It also supplies the reason behind F1's *"the Aeolian panel therefore carries a single conserved
line, Bala 29ca's"* — true because the support rule drops a 10-pixel fragment, not because Bala 28ca
holds no Aeolian country.

**Carried to I-52:** `fact_three_arm_gap_decomposition.n_units` counts on geometry while the part
classification counts on support, so the two disagree wherever both are quoted. **No number moves** —
the fragment is 0.08% of the arm's Aeolian pixels.

---

## 4 · Figure 21 · composition claims — all confirm

Share of each conserved paddock's non-treed census pixels:

| paddock | Inland | Riverine | Aeolian |
|---|---:|---:|---:|
| Bala 26ca | **98.1%** (32,399) | 1.9% (636) | — |
| Bala 27ca | **100.0%** (23,908) | — | — |
| Bala 28ca | 83.1% (18,272) | 16.8% (3,704) | 0.0% (10) |
| Bala 29ca | 34.6% (12,687) | 33.1% (12,141) | 32.3% (11,848) |

*"near-equal proportion"*, *"98% Inland Floodplain"*, *"entirely Inland Floodplain"*, and both Bala
26ca and Bala 28ca holding a Riverine portion alongside their Inland one — all exact.

Bala 26ca's Riverine fragment is **636 px (39.7 ha)**, clearing the ≥ 30-cell rule comfortably, so
the note asking a reader to treat it as a fragment of a paddock rather than a paddock rests on the
right basis.

---

## 5 · §4.6's worked case — the three aggregations

Whole-property mean inundation, four post-management water years against the preceding thirty-one.
Water years 1988–2022, the last four post-management.

| aggregation | unit | post (4 yr) | pre (31 yr) |
|---|---|---:|---:|
| pixel-weighted `SUM(wet)/SUM(valid)` | **the property** | **43.64%** | **22.82%** |
| mean of paddock means (n = 64) | the average paddock | **45.97%** | **25.23%** |
| mean of stratum means, unweighted (n = 118) | the average stratum | 37.94% | 19.36% |

**Spread on the post figure: 8.0 points** (37.94 → 45.97).

The draft's *"43.6% pixel-weighted … and 46.0% as a mean of paddock means"* is confirmed to the
decimal, and matches the basis recorded at **I-38**.

**The third derivation's unit is now established** — the unweighted mean of 118 zone × community
stratum means — which is what Ruling AA required before it could be quoted. It answers "what does
the average stratum do", which is not the question §11.2 asks.

**This also corrects a DOC-2 verdict:** §11.2's 43.6 / 22.8 was reported UNVERIFIABLE at DOC-2 Gate C
because the basis could not be identified from the database and the pin registry. It is
**CONFIRMED, pixel-weighted**. The basis was recorded at I-38 in the issues log, which was not
searched.

---

## Values previously verified, carried not re-derived

Figure 23's series (+0.057 / r 0.22, mean −2.07, range −7.04 to +4.99, +0.919 / r 0.85, +0.273 /
r 0.77) were confirmed at DOC-1 Gate B. Figure 26's −32.0 raw and −10.5 adjusted, and the six-of-nine
and eight-of-nine counts, were confirmed at DOC-1 Gate C. Not re-run.

## Not verified here

The temporal claims — Bala 29ca's Inland part sitting below the band "in the late 1990s, the
mid-2000s and 2019", and the Aeolian and Riverine lines rising toward the band — are readings of the
plotted series and were not checked against the annual data.
