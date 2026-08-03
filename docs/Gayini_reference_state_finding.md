# Reference-state analysis — consolidated finding

**Date:** 27 July 2026
**Question asked:** Adrian's 24 July direction (§5.3) — are formerly-cropped paddocks on a trajectory toward the condition of the conserved ("pink") paddocks?
**Answer:** The question cannot be answered as posed, and the reason is specific and fixable.
**Evidence:** T1, T2, T6 — all queryable from `Gayini_Results.sqlite`.

---

## The headline

**Three of the four reference paddocks are indistinguishable from grazed paddocks on the vegetation floor, across the entire 35-year record. The fourth, Bala 29ca, is a 42-percentage-point outlier — and it produces every "reference state" finding the project has reported.**

| Period | Reference ×4 | gap | Reference ×3 | gap | Bala 29ca | gap |
|---|---|---|---|---|---|---|
| 1988–1992 | 68.1 | **−13.1** | 77.8 | **−3.3** | 38.9 | **−42.3** |
| 1993–2002 | 58.8 | −11.4 | 68.0 | −2.2 | 31.2 | −39.0 |
| 2003–2012 | 57.0 | −7.9 | 63.1 | −1.8 | 38.8 | −26.2 |
| 2013–2018 | 65.4 | −5.7 | 69.6 | −1.6 | 53.0 | −18.2 |
| 2019–2022 | 63.9 | −5.6 | 68.0 | −1.5 | 51.6 | −18.0 |

*Floor = `veg_p05_spatial`, mean of seasons. Reference = the four `No grazing` zones. Grazed = median of the 60 14-day zones. Source: `v_zone_veg_annual`.*

Read the middle column pair. **Without Bala 29ca, the reference paddocks track the grazed median within 1.5–3.3 pp for thirty-five years.** There is no reference-versus-grazed difference to build a trajectory on.

## Two things this kills

**The reference-grazed gap predates conservation management by thirty years.** It is present in 1988–92 at −13.1 pp. Management changed in 2018–19. Whatever produces the gap, it is not conservation management, and it is not grazing exclusion — the exclusion had not happened yet.

**The convergence also predates the intervention.** The gap narrows monotonically from 1988 onward: −13.1 → −11.4 → −7.9 → −5.7 → −5.6. It is not a post-2019 response. Attributing it to conservation management would be wrong by three decades.

## What the outlier actually is

Bala 29ca is not merely low. It is:

- **−42.3 pp below the grazed median in 1988–92**, closing to −18.0 pp by 2019–22 — a 24 pp recovery over 35 years
- the paddock holding **13 of the 24 reference monitoring plots (54%)**, so the ground-truth network's picture of "reference condition" is over half this one paddock
- the source of **93%** of Riverine-low's reference pixels in T1's matched contrast, which produced the +7.5 pp "grazing effect" that collapsed under zone support
- the **only** reference paddock present in Aeolian, where it reads 29.4% floor against a grazed 61.4%

Every reference-state result in this project traces back to it.

**The most plausible reading is that Bala 29ca is recovering from historical disturbance** — clearing, cropping or something similar — that predates the satellite record. A 35-year monotonic recovery from a very low base is what that looks like. If so, it is not a reference state at all; it is the most degraded paddock on the property, slowly improving.

**This is testable and the data is already identified.** Ernest's land-use history would settle it. `dim_management_zone.cropping_history` and the four other RESERVED columns exist and are NULL, waiting for exactly this.

## Supporting findings, consistent with the above

**The reference paddocks are not less vegetated — they are more variable.** On *mean* cover they match grazed almost exactly (Aeolian −3.0, Riverine −0.8, Inland **+1.8** pp); on the *floor* they sit far below (−19.6, −11.7, +1.1). Same average cover, much lower worst-season cover. Source: `fact_three_arm_gap_decomposition`.

**Within-reference spread exceeds the treatment contrast in 6 of 9 strata** — every Riverine and every Inland Floodplain band. The reference paddocks disagree with each other more than they collectively differ from grazed. A fixed distance-to-reference target is undefined in those strata.

**Grazing intensity does not order the floor.** Once wetness is controlled by stratum, the inferred-standard-grazing arm sits *at or above* the 14-day arm in 6 of 9 strata, and the plot-confirmed subset in 8 of 9. Either grazing intensity does not register, or the unzoned land is less grazed rather than more. Source: `fact_three_arm_stratum_veg_annual`.

**All four reference paddocks are in the Bala group** (Bala 4 / Mara 0 / Dinan 0), so any whole-farm reference-versus-grazed contrast is confounded with property block as well as with wetness.

## What this means for the design

Distance-to-reference, as specified, requires a reference set that is (a) internally consistent, (b) distinguishable from the treated set, and (c) a plausible target condition. **The pink paddocks satisfy none of the three.** Three are statistically identical to grazed ground; the fourth is a degraded outlier.

Four ways forward, in order of what the data supports:

1. **Report the finding as it stands.** *"Conserved" is a management category, not a condition state — three of four conserved paddocks are indistinguishable from grazed ground on a 35-year record, and the fourth is an outlier recovering from something that predates the record.* Defensible now, needs no new data, and it is a genuine methodological contribution.
2. **Get Ernest's land-use history.** If Bala 29ca was cleared or cropped, the whole picture resolves: it is a recovery trajectory, not a reference state, and it becomes the project's most interesting single paddock rather than its most confusing.
3. **Redefine reference environmentally, not by management.** Compare each place to environmentally-similar sites rather than to a management category. This is HCAS's premise, and CSIRO HCAS 3.3 (1988–2024, 90 m, annual) is already flagged for integration and matches the Landsat span.
4. **Abandon reference-state framing.** The wetness gradient organises the floor far more strongly than any management category does. That is the finding the data best supports, and it is the one the client can act on.

Options 1 and 4 are available today. Option 2 is one email. Option 3 is a redesign.

## What would change the answer

| Data | Would resolve |
|---|---|
| **Ernest's land-use history** | Whether Bala 29ca is a degraded recovering paddock. Decisive. |
| **Stocking rates / DSE per ha** | Whether "14-day" and "standard" differ in intensity at all — the T6 ordering |
| **Nari Nari on the unzoned land** | Whether the unzoned area is grazed more, less, or not at all |

All three are conversations, not computations. None requires further analysis.

## Standing caveats

- Landsat fractional cover measures **cover, not condition** — it cannot distinguish native from introduced, or structure from health.
- Aeolian reference is **n = 1** (Bala 29ca). No community-level claim can rest on it.
- The unzoned arm is **inferred** to be standard grazing from plot locations; 8 of 15 standard-grazing plots fall on it.
- **7 of 15 standard-grazing plots, and 18,562 ha (21.6%) of the property, sit outside the mapped census** and have never been in any analysis.
