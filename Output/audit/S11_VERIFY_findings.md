# S11-VERIFY — the ten quantities of §4, `Gayini_S11_spatial_structure_draft.md`

**Read-only.** 5 August 2026 · SQLite `mode=ro`, `PRAGMA query_only=1` · no writes, no renders.
Source document committed at `docs/reference_update/Gayini_S11_spatial_structure_draft.md`.

**Nothing below is taken from `Gayini_locating_results_in_country_note.md`.** That note records its own
property-wide scan as *"a design-seat pilot, unregistered, and a prediction to check — not a result"*, so
every quantity here was recomputed from the database or from `Output/tables/T13_gateC_classification.csv`.

**Basis throughout:** non-treed census pixels — `treed_context_flag = 0 AND regime_band <> 'context'` —
and `PIXEL_AREA_HA = 0.062351428`.

---

## Result

**Eight of ten verify as written. One is contradicted. One rests on a false premise. Two more are
correct in their values and wrong in what they assert about them.**

| # | Quantity | Verdict | Registered? |
|:--:|---|---|---|
| 1 | Dominance distribution 25 / 17 / 8 / 5 / 9 | **CONFIRMED** | partly — 3 of 5 bins |
| 2 | The nine mixed paddocks, named | **CONFIRMED** | count only |
| 3 | Bala 29ca's three shares | **CONFIRMED** | **no** — reproduces |
| 4 | Bala 29ca part deficits, ranks, trends | **CONFIRMED** | deficits and trends yes; ranks no |
| 5 | Bala 29ca whole floor and trend | values **CONFIRMED**, relationship **FALSE** | values yes |
| 6 | Dinan 10 whole-paddock adjusted trend and rank | value **CONFIRMED**, rank **INVERTED** | **no** |
| 7 | Dinan 10 Riverine part trend | **CONTRADICTED** | **no** |
| 8 | Dinan 10 part areas | **CONFIRMED** | **no** — reproduces |
| 9 | Bala 27ca single-community share | **CONFIRMED** | **no** — reproduces |
| 10 | Grain of the headline conserved-vs-grazed number | **premise FALSE** | yes, with spreads |

---

## 7 · Dinan 10's Riverine part trend — CONTRADICTED

| | |
|---|---|
| draft | **+0.737** |
| `fact_zone_community_part_classification` | `trend_adj` **+0.2313** · `trend_raw` **+0.4549** |
| `T13_gateC_classification.csv` | identical |

**+0.737 appears nowhere.** Searched every part trend (`trend_raw`, `trend_adj`, `trend_z`, `level`) across
all 115 parts, every `pinned_value` in `dim_headline_number`, and every zone-level
`water_adjusted_floor_trend`. No match within ±0.005.

**The standing claim survives the value.** The part ranks **4th of 37** Riverine parts by adjusted trend
(Mara 1 +0.571, Bala 29ca +0.470, Bala 28ca +0.372, Dinan 10 +0.231) and its registered T13 state is
**Recovering**. "Among the strongest on the property" is defensible; the number attached to it is not.

## 6 · Dinan 10's rank — the value is right and the direction is inverted

`fact_zone_floor_temporal`, zone_fid 57: `water_adjusted_floor_trend` = **0.0198** → +0.020 ✓ ·
`rank_by_adjusted` = **55** ✓. Both match the draft as written. Neither carries a `number_id`.

**But `rank_by_adjusted` is ASCENDING.** Sorted by adjusted trend, Dinan 10 is 55th from the bottom —
**10th from the top of 64**.

| | |
|---|---|
| paddocks with a negative adjusted trend | **54 of 64** |
| median adjusted trend | **−0.1484** |
| lowest / highest | Dinan 7 −0.7036 / Bala 15 +0.6459 |

*"+0.020 percentage points a year, ranking 55th of 64 — indistinguishable from no change"* places a rank
next to a near-zero value in a way that reads as *near the bottom*. **On this property near-zero is
comparatively high**: +0.020 is in the top sixth.

## 5 · "is a mean over" is false, and §4.3 already forbids it

Every value is correct and registered. The relationship asserted between them is not.

| | parts | unweighted mean | area-weighted | draft says whole is |
|---|---|---|---|---|
| cover floor | 29.4 · 67.3 · 34.6 | **43.76** | 44.2 | **40.5** |
| trend | +0.560 · −0.216 · +0.564 | **+0.303** | +0.293 | **+0.682** |

The whole-paddock figures are not aggregates of the parts on any weighting. **§4.3 of the same document
states the rule:** *"The 5th percentile of a combined area is not the mean of the 5th percentiles of its
parts, so percentiles are recomputed at each support rather than aggregated upward."*

**The conclusion survives the mechanism.** 40.5 still describes none of 29 / 67 / 35. It is separate
computations on a combined area, not an average of the parts.

## 10 · The grain complaint is false as written

§11.4: *"the headline conserved-versus-grazed difference is registered at paddock grain rather than at
paddock-by-community grain."*

| number | value | grain | support | spread |
|---|---|---|---|---|
| `three_arm_floor_deficit_not_grazed` | −0.92 | **9 strata (area-weighted)** | **stratum** | [−4.82, −0.92] |
| `ref_grazed_floor_aeolian` | −10.46 | **community (area-weighted band mean)** | **stratum** | [−19.65, −11.17] |
| `ref_grazed_floor_riverine` | −4.49 | community (area-weighted band mean) | stratum | [−11.70, −4.38] |
| `ref_grazed_floor_inland` | +1.08 | community (area-weighted band mean) | stratum | [1.07, 1.08] |
| `ref_grazed_gap_annual_ref3_excl29ca_mean` | −2.073 | **zone** | **zone** | [−7.038, +4.987] |

**The community and stratum family is already registered at ecological grain with spread recorded.** Only
the annual gap series sits at paddock grain. The section names "the headline conserved-versus-grazed
difference" without saying which, and the complaint holds only for the last row.

---

## The eight that verify

**1 · Dominance across 64 zones — 25 / 17 / 8 / 5 / 9, and 14 below 75%.** Exact.
Registered: `reg2_paddocks_single_community` 25 · `reg2_paddocks_lt60_dominance` 9 ·
`reg2_paddocks_lt75_dominance` 14. **The 90–100 (17), 75–90 (8) and 60–75 (5) bins are unregistered.**

**2 · The nine below 60%**, in ascending dominance:

| paddock | dominance | area |
|---|---:|---:|
| Bala 29ca | 34.6% | 2,286.8 ha |
| Dinan 3 | 46.9% | 598.0 ha |
| Mara 8 | 50.1% | 235.9 ha |
| Dinan 8 | 52.7% | 2,671.3 ha |
| Mara 13 | 54.7% | 114.4 ha |
| Mara 2 | 57.5% | 123.8 ha |
| Dinan 11 | 57.8% | 595.8 ha |
| Dinan 13 | 57.9% | 1,260.2 ha |
| Bala 6 | 58.4% | 2,021.7 ha |

**3 · Bala 29ca** — Inland **34.6%** (791.1 ha) · Riverine **33.1%** (757.0 ha) · Aeolian **32.3%** (738.7 ha).

**4 · Bala 29ca's parts** — every value confirmed:

| part | level | community median | deficit | rank (1 = lowest) | trend_raw | T13 state |
|---|---:|---:|---:|---|---:|---|
| Aeolian | 29.39 | 61.51 | **−32.12** | **1 of 17** | **+0.5601** | Recovering |
| Riverine | 34.61 | 59.51 | **−24.90** | **2 of 37** | **+0.5637** | Recovering |
| Inland | 67.28 | 73.08 | **−5.80** | 10 of 61 | **−0.2160** | **Declining** |

Deficits and trends are registered (`t10_bala29ca_*_level_deficit`, `t10_bala29ca_*_floor_trend`); **the
ranks are not.**

**Wording flag:** the draft calls the Inland part *"unremarkable"*. That is a class name in the T13 scheme,
and this part's registered state is **Declining**.

**8 · Dinan 10's areas** — Aeolian **547.4 ha** (65.1%) · Inland **234.8 ha** (27.9%) · Riverine **58.9 ha**
(7.0%) · whole **841.1 ha**. The draft's 547 / 235 / 59 of 841 and "seven per cent" are exact, and
841.1 − 58.9 = **782.2 ha** supports "782 hectares".

**9 · Bala 27ca** — **100.0%** Inland Floodplain, **1,490.7 ha**. "Roughly two in five paddocks are of this
kind" = 25/64 = **39%** ✓.

---

## Registrable

Everything unregistered that reproduces can be pinned: Bala 29ca's three shares and three within-community
ranks; Dinan 10's three part areas, whole area, whole-paddock adjusted trend and its rank; Dinan 10's
Riverine part trend and its standing; Bala 27ca's share and area; the three unregistered dominance bins;
and the two distribution facts the corrected text leans on — 54 of 64 negative, median −0.148.

**Unverifiable: none.** Every quantity either reproduced or was contradicted by a value that did.
