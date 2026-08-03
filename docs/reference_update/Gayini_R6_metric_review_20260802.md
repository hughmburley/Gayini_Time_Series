# R6 metric review — which p05 is the reference-state floor?

**Version:** v1 · 2 August 2026 · design seat
**Status:** REVIEW OF A DRAFT. R6 is not adopted; nothing here changes a registered number.
**Reviews:** `Gayini_R6_bala_floor_flood_placement.md` (DRAFT, 2 Aug),
`Gayini_LiDAR_implications_for_reference_state.md` §2–3
**Bottom line:** R6 and the reference-state stream measure different quantities. On the
stream's pinned metric, R6's conclusion reverses. The metric question is real and predates
R6; it should not be settled before 10 August.

---

## 1. What R6 actually measures — verified

R6's "observed p05" is `census_by_zone_stratum.veg_p05_mean`: the **census temporal**
percentile — what a pixel holds 95% of the time, averaged across pixels. Confirmed by exact
reproduction from the database:

| R6 states | recomputed |
|---|---|
| Bala 26ca Riverine — n 636, flood 13.34, p05 26.86 | 636, 13.34, **26.86** |
| Bala 29ca Aeolian — 11,848, 2.82, 46.77 | 11,848, 2.82, **46.77** |
| Bala 29ca Riverine — 12,141, 6.38, 50.30 | 12,141, 6.38, **50.30** |
| Bala 29ca Inland — 12,687, 15.92, 55.77 | 12,687, 15.92, **55.77** |

**The reference-state stream uses `veg_p05_spatial`** — a within-year percentile across pixels,
measuring patchiness. T2, T10, T13, the deck and the paddock reports all use it.

The two differ at part grain by up to 17 pp, in opposite directions by community:

| Bala 29ca part | census `veg_p05` | `veg_p05_spatial` | difference |
|---|---|---|---|
| Aeolian | 46.77 | 29.39 | +17.38 |
| Riverine | 50.30 | 34.61 | +15.69 |
| Inland | 55.77 | 67.28 | −11.51 |

`T2_zone_annual_veg_extraction.md` §94, verbatim: *"These must never appear in the same figure
or be compared numerically."*

R6 compares a residual computed on the census metric against a 42 pp deficit computed on the
spatial metric. That is the prohibited comparison, and it is the sole basis for "the anomaly
has dissolved."

## 2. The decisive test

R6's own logic — within-community fit of floor on long-run census flood frequency — re-run on
`veg_p05_spatial`:

| part | R6 (census p05) | same logic, spatial p05 |
|---|---|---|
| Bala 29ca Aeolian | +1.57 | **−29.04  (−2.60 SD)** |
| Bala 29ca Riverine | +9.61 | **−18.67  (−1.93 SD)** |
| Bala 29ca Inland | +1.15 | +0.68 |
| Bala 26ca Riverine | −17.41 | −1.34 |
| Bala 26ca Inland | +0.59 | −6.92 |
| Bala 27ca Inland | −2.02 | −3.42 |
| Bala 28ca Riverine | +6.37 | −0.25 |
| Bala 28ca Inland | +2.39 | −2.38 |

**On the pinned metric, Bala 29ca is 2.6 and 1.9 SD below its community fit in two of three
communities. The anomaly does not dissolve.**

The community fits themselves disagree, including on sign in Aeolian:

| community | slope on census p05 | slope on spatial p05 |
|---|---|---|
| Aeolian | +0.259 (r 0.19) | **−0.667 (r −0.26)** |
| Riverine | +0.513 (r 0.46) | +0.584 (r 0.43) |
| Inland | +0.530 (r 0.66) | +0.351 (r 0.66) |

**Caveat on this computation.** The re-run fits at **part level** (n = 17 / 37 / 61 parts)
where R6 fits at **pixel level** (n = 77,544 / 193,658 / 717,627). Different support, so these
are not the exact spatial analogue of R6's residuals. The metric is nevertheless doing the
work: the input levels differ by 15–17 pp before any fitting. Design-seat computation,
unregistered — **a prediction to check, not a target.**

## 3. Why this is a structural problem, not a correction

**The pre-registration guard has become unenforceable as written.** It requires the
redefinition be justified "on grounds stated independently of its effect on the answer." The
effect is now known: the census metric dissolves the anomaly, the spatial metric keeps it.
Anyone choosing from here is choosing the answer, and good faith does not repair that.

**The escape is that the choice was already made.** T2 pinned `veg_p05_spatial` with a stated
reason recorded at the time (§147: the floor is where the flooding signal lives, and it is
harder to manufacture by a land-use switch than mean cover), before any of this existed.
Appealing to that prior decision is legitimate *because* it predates the result.

## 4. Rulings

1. **The metric was pinned at T2. It stands.** R6 does not replace it. Gate E remains blocked
   and the trajectory work does not resume on R6.
2. **R6 is registered as a cross-metric sensitivity**, not a redefinition. It says something
   real and worth reporting: the two floor definitions disagree about Bala 29ca. That satisfies
   the guard's "both versions must be reported."
3. **Nothing in the deck, the deliverables register or claim 4 changes.** "Genuinely low and
   genuinely improving" holds on the pinned metric.
4. **§1c is accepted in full and is independent of the metric question.** The four reference
   paddocks are ~30 km apart, span communities and a ~9 m regional fall, and differ fivefold in
   wet fraction. They were analysed as one condition with four replicates and they are not one
   condition. This is the physical mechanism behind Gate E and belongs in the deck.
5. **The S6 finding is accepted** — 13.33% of the property carries woody cover, so the floor is
   overwhelmingly a ground-layer signal. It bounds the untested refugia question in advance.

## 5. The larger question, for after 10 August

**R6 may be using the better metric.** The spine's mechanism — p05 rising ~2.2× faster than p50
across the flood gradient — was established on the **census temporal** p05 in Task H. The
reference-state stream then built on `veg_p05_spatial`. That is a pre-existing inconsistency
which R6 has surfaced rather than created, and it deserves a real answer.

Eight days from a deadline is the wrong moment to answer it, and the answer must not be chosen
knowing which paddock it exonerates.

**Post-deadline, the honest procedure:** state the criteria for choosing between the two
metrics *before* recomputing anything; have someone outside the stream review the criteria; then
compute. If that is not possible, report both and say the choice is open.

## 6. On exploratory status — carried from the design seat

Landsat fractional cover and LiDAR structure measure different things. Neither the R6
placement nor U-Q4a's structural reading is a settled result, and this remains an exploratory
phase. **No snap conclusion in either direction** — the anomaly is neither confirmed nor
dissolved, and the honest position before 10 August is that the reference set is heterogeneous
for physical reasons (§1c, solid) and that the metric question is open (§5).

## 7. What I could not check

R6 fits at pixel support over 988,829 census pixels. The design-seat database snapshot holds
zone-stratum aggregates only, so **R6's fits themselves were not verified** — only its inputs,
which reproduce exactly. The re-run in §2 is the part-grain analogue, not a replication.
